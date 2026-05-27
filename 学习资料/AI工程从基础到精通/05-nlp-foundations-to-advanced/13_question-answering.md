# 问答系统

> 三种系统塑造了现代问答。抽取式找到文本片段。检索增强将它们建立在文档之上。生成式产生答案。每个现代 AI 助手都是这三者的混合体。

**类型：** 构建
**语言：** Python
**前置要求：** 第 5 阶段 · 11（机器翻译），第 5 阶段 · 10（注意力机制）
**时间：** 约 75 分钟

## 问题

用户输入"When did the first iPhone launch?"，期望得到"June 29, 2007。"而不是"Apple 的历史漫长而丰富。"也不是一个孤立存在的"2007"，没有句子。一个直接、有根据、正确的答案。

过去十年，三种架构主导了问答。

- **抽取式问答。** 给定一个问题和已知包含答案的段落，找到答案片段在段落中的起始和结束索引。SQuAD 是经典基准。
- **开放域问答。** 不给定段落。先检索相关段落，然后抽取或生成答案。这是今天每个 RAG 流水线的基础。
- **生成式/闭卷问答。** 大型语言模型从其参数记忆中回答。无检索步骤。推理最快，事实最不可靠。

2026 年的趋势是混合式：检索最佳的几个段落，然后提示一个生成模型基于这些段落回答。这就是 RAG，第 14 课将深入覆盖检索的部分。本课构建问答部分。

## 概念

![问答架构：抽取式、检索增强、生成式](../assets/qa.svg)

**抽取式。** 用 Transformer（BERT 系列）将问题和段落一起编码。训练两个头来预测答案的起始和结束标记索引。损失是对有效位置的交叉熵。输出是段落中的一个片段。从不幻觉（构造上保证），从不处理段落无法回答的问题（构造上保证）。

**检索增强（RAG）。** 两个阶段。首先，检索器从语料库中找到 top-`k` 段落。其次，阅读器（抽取式或生成式）使用这些段落产生答案。检索器-阅读器分离使两者可以独立训练和评估。现代 RAG 通常在两者之间加入重排器。

**生成式。** 一个仅解码器 LLM（GPT、Claude、Llama）从学习的权重中回答。无检索步骤。在常见知识上表现出色，在罕见或最近的事实上灾难性失败。幻觉率与事实在预训练数据中的频率呈负相关。

## 构建

### 步骤 1：使用预训练模型的抽取式问答

```python
from transformers import pipeline

qa = pipeline("question-answering", model="deepset/roberta-base-squad2")

passage = (
    "Apple Inc. released the first iPhone on June 29, 2007. "
    "The device was announced by Steve Jobs at Macworld in January 2007."
)
question = "When was the first iPhone released?"

answer = qa(question=question, context=passage)
print(answer)
```

```python
{'score': 0.98, 'start': 57, 'end': 70, 'answer': 'June 29, 2007'}
```

`deepset/roberta-base-squad2` 在 SQuAD 2.0 上训练，该数据集包含不可回答的问题。默认情况下，`question-answering` 流水线即使模型的空答案得分更高，也会返回得分最高的片段——它*不会*自动返回空答案。要获得显式的"无答案"行为，在流水线调用中传入 `handle_impossible_answer=True`：流水线仅在空答案得分超过所有片段得分时才返回空答案。无论哪种方式，始终检查 `score` 字段。

### 步骤 2：检索增强流水线（概览）

```python
from sentence_transformers import SentenceTransformer
import numpy as np

encoder = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2")

corpus = [
    "Apple Inc. released the first iPhone on June 29, 2007.",
    "Macworld 2007 featured the iPhone announcement by Steve Jobs.",
    "Android launched in 2008 as Google's mobile operating system.",
    "The first iPod was released in 2001.",
]
corpus_embeddings = encoder.encode(corpus, normalize_embeddings=True)


def retrieve(question, top_k=2):
    q_emb = encoder.encode([question], normalize_embeddings=True)
    sims = (corpus_embeddings @ q_emb.T).squeeze()
    order = np.argsort(-sims)[:top_k]
    return [corpus[i] for i in order]


def answer(question):
    passages = retrieve(question, top_k=2)
    combined = " ".join(passages)
    return qa(question=question, context=combined)


print(answer("When was the first iPhone released?"))
```

两阶段流水线。稠密检索器（Sentence-BERT）通过语义相似度找到相关段落。抽取式阅读器（RoBERTa-SQuAD）从组合的 top 段落中提取答案片段。在小语料库上工作。对于百万文档级别的语料库，使用 FAISS 或向量数据库。

### 步骤 3：带 RAG 的生成式问答

```python
def rag_generate(question, llm):
    passages = retrieve(question, top_k=3)
    prompt = f"""Context:
{chr(10).join('- ' + p for p in passages)}

Question: {question}

Answer using only the context above. If the context does not contain the answer, say "I don't know."
"""
    return llm(prompt)
```

提示模式很重要。明确告诉模型基于上下文回答，并在上下文不足时返回"I don't know"，这可以将幻觉率降低 40-60%，相比朴素的提示方式。更精细的模式会添加引用、置信度分数和结构化提取。

### 步骤 4：反映真实世界的评估

SQuAD 使用**完全匹配（EM）**和**标记级 F1**。EM 是归一化后的严格匹配（小写、去除标点、移除冠词）——预测要么完全匹配，要么得 0 分。F1 在预测和参考答案之间的标记重叠上计算，并给予部分分数。两者都低估改写："June 29, 2007"与"June 29th, 2007"通常 EM 为 0（序数词破坏了归一化），但由于标记重叠仍能获得可观的 F1。

对于生产级问答：

- **答案准确率**（LLM 判断或人工判断，因为指标无法捕捉语义等价）。
- **引用准确率。** 引用的段落是否实际支持答案？通过生成引用和检索段落之间的字符串匹配即可轻松自动检查。
- **拒绝校准。** 当答案不在检索到的段落中时，系统是否正确地说"I don't know"？衡量错误置信率。
- **检索召回率。** 在评估阅读器之前，衡量检索器是否将正确段落放入了 top-`k`。阅读器无法修复缺失的段落。

### RAGAS：2026 年生产评估框架

`RAGAS` 专为 RAG 系统构建，是 2026 年上线的默认选择。它在不需要黄金参考答案的情况下对四个维度进行评分：

- **忠实性。** 答案中的每个论断是否来自检索到的上下文？通过基于 NLI 的蕴含度量。你的主要幻觉指标。
- **答案相关性。** 答案是否回答了问题？通过从答案生成假设性问题并与真实问题比较来衡量。
- **上下文精确率。** 在检索到的块中，有多少比例实际上相关？低精确率 = 提示中的噪声。
- **上下文召回率。** 检索到的集合是否包含所有需要的信息？低召回率 = 阅读器无法成功。

无参考答案评分让你可以在没有精选黄金答案的情况下，对实时生产流量进行评估。在其上叠加 LLM 评委来处理完全匹配指标无用的开放式问题。

`pip install ragas`。插入你的检索器 + 阅读器。每个查询得到四个标量。监控回归。

## 使用

2026 年技术栈。

| 用例 | 推荐 |
|---------|-------------|
| 给定段落，找到答案片段 | `deepset/roberta-base-squad2` |
| 在固定语料库上，不接受闭卷 | RAG：稠密检索器 + LLM 阅读器 |
| 在文档存储上实时 | 带混合（BM25 + 稠密）检索器 + 重排器的 RAG（第 14 课） |
| 对话式问答（追问） | 带对话历史的 LLM + 每轮 RAG |
| 高度事实性、受监管领域 | 在权威语料库上的抽取式；绝不单独使用生成式 |

抽取式问答在 2026 年已不流行，因为带 LLM 的 RAG 能处理更多情况。但在需要字面引用的场景中它仍然在线上运行：法律研究、合规监管、审计工具。

## 交付

保存为 `outputs/skill-qa-architect.md`：

```markdown
---
name: qa-architect
description: 选择问答架构、检索策略和评估计划。
version: 1.0.0
phase: 5
lesson: 13
tags: [nlp, qa, rag]
---

给定需求（语料库大小、问题类型、事实性约束、延迟预算），输出：

1. 架构。抽取式、带抽取式阅读器的 RAG、带生成式阅读器的 RAG 或闭卷 LLM。一句话原因。
2. 检索器。无、BM25、稠密（指定编码器名称）或混合。
3. 阅读器。SQuAD 调优模型、LLM 名称，或"领域微调的 DistilBERT"。
4. 评估。EM + F1 用于抽取式基准；答案准确率 + 引用准确率 + 拒绝校准用于生产。说明你要测量什么以及如何测量。

拒绝为监管或合规敏感问题提供闭卷 LLM 答案。拒绝任何没有检索召回率基线的问答系统（你无法在不了解检索器是否找到正确段落的情况下评估阅读器）。将需要多跳推理的问题标记为需要专门的多跳检索器，如 HotpotQA 训练的系统。
```

## 练习

1. **简单。** 在 10 个 Wikipedia 段落上设置上述 SQuAD 抽取式流水线。手工制作 10 个问题。测量答案正确的频率。如果段落和问题干净，你应该看到 7-9 个正确。
2. **中等。** 添加拒绝分类器。当 top 检索分数低于阈值（如 0.3 余弦相似度）时，返回"I don't know"而不是调用阅读器。在留存集上调优阈值。
3. **困难。** 在你选择的 10,000 文档语料库上构建 RAG 流水线。使用 RRF 融合实现混合检索（BM25 + 稠密）（见第 14 课）。测量有和没有混合步骤时的答案准确率。记录哪种问题类型受益最大。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| 抽取式问答 | 找到答案片段 | 在给定段落中预测答案的起始和结束索引。 |
| 开放域问答 | 在语料库上问答 | 不给段落；必须先检索再回答。 |
| RAG | 检索然后生成 | 检索增强生成。检索器 + 阅读器流水线。 |
| SQuAD | 经典基准 | 斯坦福问答数据集。EM + F1 指标。 |
| 幻觉 | 编造的答案 | 阅读器输出不被检索上下文支持。 |
| 拒绝校准 | 知道何时安静 | 系统在无法回答时正确地说"I don't know"。 |

## 扩展阅读

- [Rajpurkar et al. (2016). SQuAD: 100,000+ Questions for Machine Comprehension of Text](https://arxiv.org/abs/1606.05250)——基准论文。
- [Karpukhin et al. (2020). Dense Passage Retrieval for Open-Domain QA](https://arxiv.org/abs/2004.04906)——DPR，问答的经典稠密检索器。
- [Lewis et al. (2020). Retrieval-Augmented Generation for Knowledge-Intensive NLP Tasks](https://arxiv.org/abs/2005.11401)——命名 RAG 的论文。
- [Gao et al. (2023). Retrieval-Augmented Generation for Large Language Models: A Survey](https://arxiv.org/abs/2312.10997)——全面的 RAG 综述。