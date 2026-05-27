# RAG 的分块策略

> 分块配置对检索质量的影响与嵌入模型的选择一样大（Vectara NAACL 2025）。分块弄错了，再多的重排也救不了你。

**类型：** 构建
**语言：** Python
**前置要求：** 第 5 阶段 · 14（信息检索），第 5 阶段 · 22（嵌入模型）
**时间：** 约 60 分钟

## 问题

你把一份 50 页的合同放进 RAG 系统。用户问："What is the termination clause?"检索器返回了封面页。为什么？因为模型在 512 标记的分块上训练，而终止条款位于第 20 页，跨越了分页符，没有本地关键词将其与查询联系起来。

修复方法不是"买更好的嵌入模型"。修复方法是分块。多大？重叠？在哪里分割？带周围上下文？

2026 年 2 月的基准测试显示了令人惊讶的结果：

- Vectara 2026 年研究：递归 512 标记分块击败语义分块，准确率 69% → 54%。
- SPLADE + Mistral-8B 在 Natural Questions 上：重叠提供了零可测量的收益。
- 上下文悬崖：响应质量在约 2,500 标记的上下文处急剧下降。

"显然"的答案（语义分块、20% 重叠、1000 标记）往往是错的。本课为六种策略构建直觉，并告诉你何时使用哪种。

## 概念

![在一个段落上可视化的六种分块策略](../assets/chunking.svg)

**固定分块。** 每 N 个字符或标记分割。最简单的基线。在句子中间断开。压缩好，连贯性差。

**递归。** LangChain 的 `RecursiveCharacterTextSplitter`。先尝试在 `\n\n` 上分割，然后是 `\n`，然后 `.`，然后是空格。干净地回退。2026 年默认选择。

**语义。** 嵌入每个句子。计算相邻句子之间的余弦相似度。在相似度低于阈值的地方分割。保持主题连贯性。更慢；有时产生妨碍检索的微小 40 标记片段。

**句子。** 在句子边界上分割。每块一个句子或 N 个句子的窗口。在约 5k 标记以内匹配语义分块，成本只是一小部分。

**父文档。** 存储小的子块用于检索*并*存储较大的父块用于上下文。通过子块检索；返回父块。优雅降级：糟糕的子块仍然返回合理的父块。

**延迟分块（2024）。** 先在标记级别对整个文档进行嵌入，然后将标记嵌入池化为分块嵌入。保留跨块上下文。适用于长上下文嵌入器（BGE-M3、Jina v3）。更高的计算量。

**上下文检索（Anthropic，2024）。** 在每个分块前加上 LLM 生成的关于其在文档中位置的摘要（"此块是第 3.2 节，终止条款..."）。在 Anthropic 自己的基准测试中检索改进 35-50%。索引昂贵。

### 击败每个默认值的规则

将分块大小与查询类型匹配：

| 查询类型 | 分块大小 |
|------------|-----------|
| 事实型（"CEO 叫什么？"） | 256-512 标记 |
| 分析型 / 多跳 | 512-1024 标记 |
| 整节理解 | 1024-2048 标记 |

NVIDIA 2026 年基准测试。分块应大到足以包含答案加上本地上下文，小到使检索器的 top-K 返回聚焦于答案而非上下文噪声。

## 构建

### 步骤 1：固定和递归分块

```python
def chunk_fixed(text, size=512, overlap=0):
    step = size - overlap
    return [text[i:i + size] for i in range(0, len(text), step)]


def chunk_recursive(text, size=512, seps=("\n\n", "\n", ". ", " ")):
    if len(text) <= size:
        return [text]
    for sep in seps:
        if sep not in text:
            continue
        parts = text.split(sep)
        chunks = []
        buf = ""
        for p in parts:
            if len(p) > size:
                if buf:
                    chunks.append(buf)
                    buf = ""
                chunks.extend(chunk_recursive(p, size=size, seps=seps[1:] or (" ",)))
                continue
            candidate = buf + sep + p if buf else p
            if len(candidate) <= size:
                buf = candidate
            else:
                if buf:
                    chunks.append(buf)
                buf = p
        if buf:
            chunks.append(buf)
        return [c for c in chunks if c.strip()]
    return chunk_fixed(text, size)
```

### 步骤 2：语义分块

```python
def chunk_semantic(text, encoder, threshold=0.6, min_chars=200, max_chars=2048):
    sentences = split_sentences(text)
    if not sentences:
        return []
    embs = encoder.encode(sentences, normalize_embeddings=True)
    chunks = [[sentences[0]]]
    for i in range(1, len(sentences)):
        sim = float(embs[i] @ embs[i - 1])
        current_len = sum(len(s) for s in chunks[-1])
        if sim < threshold and current_len >= min_chars:
            chunks.append([sentences[i]])
        else:
            chunks[-1].append(sentences[i])

    result = []
    for group in chunks:
        text_group = " ".join(group)
        if len(text_group) > max_chars:
            result.extend(chunk_recursive(text_group, size=max_chars))
        else:
            result.append(text_group)
    return result
```

在你的领域上调优 `threshold`。太高 → 碎片化。太低 → 一个巨大的块。

### 步骤 3：父文档

```python
def chunk_parent_child(text, parent_size=2048, child_size=256):
    parents = chunk_recursive(text, size=parent_size)
    mapping = []
    for p_idx, parent in enumerate(parents):
        children = chunk_recursive(parent, size=child_size)
        for child in children:
            mapping.append({"child": child, "parent_idx": p_idx, "parent": parent})
    return mapping


def retrieve_parent(child_query, mapping, encoder, top_k=3):
    child_embs = encoder.encode([m["child"] for m in mapping], normalize_embeddings=True)
    q_emb = encoder.encode([child_query], normalize_embeddings=True)[0]
    scores = child_embs @ q_emb
    top = np.argsort(-scores)[:top_k]
    seen, parents = set(), []
    for i in top:
        if mapping[i]["parent_idx"] not in seen:
            parents.append(mapping[i]["parent"])
            seen.add(mapping[i]["parent_idx"])
    return parents
```

关键洞察：去重父块。多个子块可能映射到同一个父块；全部返回会浪费上下文。

### 步骤 4：上下文检索（Anthropic 模式）

```python
def contextualize_chunks(document, chunks, llm):
    context_prompts = [
        f"""<document>{document}</document>
Here is the chunk to situate: <chunk>{c}</chunk>
Write 50-100 words placing this chunk in the document's context."""
        for c in chunks
    ]
    contexts = llm.batch(context_prompts)
    return [f"{ctx}\n\n{c}" for ctx, c in zip(contexts, chunks)]
```

索引上下文化后的分块。在查询时，检索受益于额外的周围信号。

### 步骤 5：评估

```python
def recall_at_k(queries, corpus_chunks, encoder, k=5):
    chunk_embs = encoder.encode(corpus_chunks, normalize_embeddings=True)
    hits = 0
    for q_text, gold_idxs in queries:
        q_emb = encoder.encode([q_text], normalize_embeddings=True)[0]
        top = np.argsort(-(chunk_embs @ q_emb))[:k]
        if any(i in gold_idxs for i in top):
            hits += 1
    return hits / len(queries)
```

始终进行基准测试。你语料库的"最佳"策略可能与任何博客文章都不一致。

## 陷阱

- **仅在事实型查询上评估分块。** 多跳查询揭示出非常不同的赢家。使用按查询类型分层的评估集。
- **语义分块没有最小尺寸。** 产生 40 标记的片段，妨碍检索。始终强制执行 `min_tokens`。
- **重叠作为 cargo cult。** 2026 年研究发现重叠通常提供零收益，并将索引成本翻倍。测量，不要假设。
- **没有最小/最大强制执行。** 5 个标记或 5000 个标记的分块都会破坏检索。钳制。
- **跨文档分块。** 绝不让一个分块跨越两个文档。始终按文档分块，然后合并。

## 使用

2026 年技术栈：

| 场景 | 策略 |
|----------|----------|
| 首次构建，不熟悉的语料库 | 递归，512 标记，无重叠 |
| 事实型 QA | 递归，256-512 标记 |
| 分析型 / 多跳 | 递归，512-1024 标记 + 父文档 |
| 大量交叉引用（合同、论文） | 延迟分块或上下文检索 |
| 对话 / 对话语料库 | 轮次级分块 + 说话者元数据 |
| 短话语（推文、评论） | 一篇文档 = 一个块 |

从递归 512 开始。在 50 查询评估集上衡量 recall@5。从那里调优。

## 交付

保存为 `outputs/skill-chunker.md`：

```markdown
---
name: chunker
description: 为给定语料库和查询分布选择分块策略、大小和重叠。
version: 1.0.0
phase: 5
lesson: 23
tags: [nlp, rag, chunking]
---

给定语料库（文档类型、平均长度、领域）和查询分布（事实型 / 分析型 / 多跳），输出：

1. 策略。递归 / 句子 / 语义 / 父文档 / 延迟 / 上下文。原因。
2. 分块大小。标记数。原因与查询类型相关。
3. 重叠。默认 0；如果 >0 需合理说明。
4. 最小/最大强制执行。`min_tokens`、`max_tokens` 守卫。
5. 评估计划。50 查询分层评估集上的 Recall@5（事实型、分析型、多跳）。

拒绝任何没有最小/最大分块大小强制执行的分块策略。拒绝高于 20% 的重叠而没有消融实验证明它有帮助。标记没有最小标记下限的语义分块建议。
```

## 练习

1. **简单。** 用固定（512, 0）、递归（512, 0）和递归（512, 100）对一个 20 页文档进行分块。比较分块数量和边界质量。
2. **中等。** 在 5 个文档上构建 30 查询评估集。衡量递归、语义和父文档的 recall@5。哪个胜出？是否与博客文章匹配？
3. **困难。** 实现上下文检索。衡量相对基线递归的 MRR 改进。报告索引成本（LLM 调用次数）vs 准确率增益。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| 分块 | 文档的一块 | 被嵌入、索引和检索的子文档单元。 |
| 重叠 | 安全边界 | 相邻块之间共享的 N 个标记；在 2026 年基准中通常无用。 |
| 语义分块 | 智能分块 | 在相邻句子嵌入相似度下降处分割。 |
| 父文档 | 双层检索 | 检索小子块，返回更大父块。 |
| 延迟分块 | 嵌入后再分块 | 在标记级别嵌入完整文档，池化为分块向量。 |
| 上下文检索 | Anthropic 的技巧 | 索引前在每个分块前加上 LLM 生成的摘要。 |
| 上下文悬崖 | 2500 标记墙 | 在 RAG 中约 2.5k 上下文标记处观察到的质量下降（2026 年 1 月）。 |

## 扩展阅读

- [Yepes et al. / LangChain — Recursive Character Splitting 文档](https://python.langchain.com/docs/how_to/recursive_text_splitter/)——生产中的默认选择。
- [Vectara (2024, NAACL 2025). Chunking configurations analysis](https://arxiv.org/abs/2410.13070)——分块与嵌入选择同样重要。
- [Jina AI — Late Chunking in Long-Context Embedding Models (2024)](https://jina.ai/news/late-chunking-in-long-context-embedding-models/)——延迟分块论文。
- [Anthropic — Contextual Retrieval](https://www.anthropic.com/news/contextual-retrieval)——使用 LLM 生成的上下文前缀实现 35-50% 检索改进。
- [NVIDIA 2026 chunk-size benchmark — Premai 总结](https://blog.premai.io/rag-chunking-strategies-the-2026-benchmark-guide/)——按查询类型的分块大小。