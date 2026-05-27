# 信息检索与搜索

> BM25 精确但脆弱。稠密检索覆盖面广但遗漏关键词。混合是 2026 年的默认方案。其他一切都是调优。

**类型：** 构建
**语言：** Python
**前置要求：** 第 5 阶段 · 02（词袋模型 + TF-IDF），第 5 阶段 · 04（GloVe、FastText、子词）
**时间：** 约 75 分钟

## 问题

用户输入"what happens if someone lies to get money"，期望找到实际涵盖这一点的法条："Section 420 IPC。"关键词搜索完全找不到它（没有共享词汇）。语义搜索如果嵌入未在法律文本上训练，也会遗漏。真正的搜索必须同时处理两者。

信息检索是每个 RAG 系统、每个搜索栏、每个文档站模糊查找下的流水线。2026 年在生产中有效的架构不是单一方法。而是一系列互补方法的链条，每种方法弥补前一种方法的失败。

本课构建每个组件，并指出每种方法弥补了哪些失败。

## 概念

![混合检索：BM25 + 稠密 + RRF + 交叉编码器重排](../assets/retrieval.svg)

四个层次。选择你需要的。

1. **稀疏检索（BM25）。** 快速，对精确匹配精确，对语义糟糕。在倒排索引上运行。数百万文档上每次查询低于 10ms。让你找到法规引用、产品代码、错误消息、命名实体。
2. **稠密检索。** 将查询和文档编码为向量。最近邻搜索。捕捉改写和语义相似性。遗漏差一个字符的精确关键词匹配。使用 FAISS 或向量数据库，每次查询 50-200ms。
3. **融合。** 合并稀疏和稠密的排序列表。倒数排序融合（RRF）是简单的默认选择，因为它忽略原始分数（它们生活在不同尺度上），只使用排名位置。当你知道某个信号在你的领域中占主导时，加权融合是一个选项。
4. **交叉编码器重排。** 从融合结果中取 top-30。运行交叉编码器（查询 + 文档一起输入，对每对评分）。保留 top-5。交叉编码器每对比双编码器慢，但准确得多。你通过只在 top-30 上运行来分摊成本。

三重检索（BM25 + 稠密 + 学习式稀疏如 SPLADE）在 2026 年基准测试中优于双重检索，但需要学习式稀疏索引的基础设施。对大多数团队来说，双重检索加交叉编码器重排是最佳平衡点。

## 构建

### 步骤 1：从零实现 BM25

```python
import math
import re
from collections import Counter

TOKEN_RE = re.compile(r"[a-z0-9]+")


def tokenize(text):
    return TOKEN_RE.findall(text.lower())


class BM25:
    def __init__(self, corpus, k1=1.5, b=0.75):
        if not corpus:
            raise ValueError("corpus must not be empty")
        self.corpus = [tokenize(d) for d in corpus]
        self.k1 = k1
        self.b = b
        self.n_docs = len(self.corpus)
        self.avg_dl = sum(len(d) for d in self.corpus) / self.n_docs
        self.df = Counter()
        for doc in self.corpus:
            for term in set(doc):
                self.df[term] += 1

    def idf(self, term):
        n = self.df.get(term, 0)
        return math.log(1 + (self.n_docs - n + 0.5) / (n + 0.5))

    def score(self, query, doc_idx):
        q_tokens = tokenize(query)
        doc = self.corpus[doc_idx]
        dl = len(doc)
        freq = Counter(doc)
        score = 0.0
        for term in q_tokens:
            f = freq.get(term, 0)
            if f == 0:
                continue
            numerator = f * (self.k1 + 1)
            denominator = f + self.k1 * (1 - self.b + self.b * dl / self.avg_dl)
            score += self.idf(term) * numerator / denominator
        return score

    def rank(self, query, top_k=10):
        scored = [(self.score(query, i), i) for i in range(self.n_docs)]
        scored.sort(reverse=True)
        return scored[:top_k]
```

两个值得了解的参数。`k1=1.5` 控制词频饱和；更高意味着更多权重放在词项重复上。`b=0.75` 控制长度归一化；0 忽略文档长度，1 完全归一化。默认值是 Robertson 在原始论文中的推荐值，很少需要调整。

### 步骤 2：使用双编码器的稠密检索

```python
from sentence_transformers import SentenceTransformer
import numpy as np


def build_dense_index(corpus, model_id="sentence-transformers/all-MiniLM-L6-v2"):
    encoder = SentenceTransformer(model_id)
    embeddings = encoder.encode(corpus, normalize_embeddings=True)
    return encoder, embeddings


def dense_search(encoder, embeddings, query, top_k=10):
    q_emb = encoder.encode([query], normalize_embeddings=True)
    sims = (embeddings @ q_emb.T).flatten()
    order = np.argsort(-sims)[:top_k]
    return [(float(sims[i]), int(i)) for i in order]
```

L2 归一化嵌入使点积等于余弦相似度。`all-MiniLM-L6-v2` 是 384 维，快速，对大多数英语检索足够强。对于多语言工作，使用 `paraphrase-multilingual-MiniLM-L12-v2`。对于最高准确率，使用 `bge-large-en-v1.5` 或 `e5-large-v2`。

### 步骤 3：倒数排序融合

```python
def reciprocal_rank_fusion(rankings, k=60):
    scores = {}
    for ranking in rankings:
        for rank, (_, doc_idx) in enumerate(ranking):
            scores[doc_idx] = scores.get(doc_idx, 0.0) + 1.0 / (k + rank + 1)
    fused = sorted(scores.items(), key=lambda x: x[1], reverse=True)
    return [(score, doc_idx) for doc_idx, score in fused]
```

`k=60` 常量来自原始 RRF 论文。更高的 `k` 使排名差异的贡献更平坦；更低的 `k` 使顶部排名占主导。60 是发布的默认值，很少需要调整。

### 步骤 4：混合搜索 + 重排

```python
from sentence_transformers import CrossEncoder

reranker = CrossEncoder("cross-encoder/ms-marco-MiniLM-L-6-v2")


def hybrid_search(query, bm25, encoder, dense_embeddings, corpus, top_k=5, pool_size=30, reranker=reranker):
    sparse_ranking = bm25.rank(query, top_k=pool_size)
    dense_ranking = dense_search(encoder, dense_embeddings, query, top_k=pool_size)
    fused = reciprocal_rank_fusion([sparse_ranking, dense_ranking])[:pool_size]

    pairs = [(query, corpus[doc_idx]) for _, doc_idx in fused]
    scores = reranker.predict(pairs)
    reranked = sorted(zip(scores, [doc_idx for _, doc_idx in fused]), reverse=True)
    return reranked[:top_k]
```

三个阶段组合。BM25 找到词汇匹配。稠密找到语义匹配。RRF 合并两个排名，不需要分数校准。交叉编码器使用查询-文档对一起处理 top-30，捕捉双编码器遗漏的细粒度相关性。保留 top-5。

### 步骤 5：评估

| 指标 | 含义 |
|--------|---------|
| Recall@k | 在存在正确文档的查询中，它出现在 top-k 中的频率？ |
| MRR（平均倒数排名） | 第一个相关文档排名的倒数的平均值。 |
| nDCG@k | 考虑相关性等级，不仅仅是二元相关/不相关。 |

对于 RAG 具体而言，检索器的 **Recall@k** 是最重要的数字。如果正确的段落不在检索集合中，你的阅读器无法回答。

调试技巧：对于失败的查询，对比稀疏和稠密的排名。如果一方找到了正确文档而另一方没有，你就有词汇不匹配（修复：添加缺失的那一半）或语义歧义（修复：更好的嵌入或重排器）。

## 使用

2026 年技术栈：

| 规模 | 技术栈 |
|-------|-------|
| 1k-100k 文档 | 内存 BM25 + `all-MiniLM-L6-v2` 嵌入 + RRF。无独立数据库。 |
| 100k-10M 文档 | FAISS 或 pgvector 用于稠密 + Elasticsearch/OpenSearch 用于 BM25。并行运行。 |
| 10M+ 文档 | Qdrant / Weaviate / Vespa / Milvus 支持混合。在 top-30 上交叉编码器重排。 |
| 最佳质量前沿 | 三重（BM25 + 稠密 + SPLADE）+ ColBERT 延迟交互重排 |

无论选择什么，为评估留出预算。在基准测试端到端 RAG 准确率之前先基准测试检索召回率。阅读器无法修复检索器遗漏的内容。

### 2026 年生产 RAG 的来之不易的经验

- **80% 的 RAG 失败追溯到摄入和分块，而不是模型。** 团队花数周更换 LLM 和调优提示，而检索器在每三个查询中就悄悄地返回错误的上下文。首先修复分块。
- **分块策略比分块大小更重要。** 固定大小分割破坏了表格、代码和嵌套标题。句子感知是默认选择；语义或基于 LLM 的分块对技术文档和产品手册有回报。
- **父文档模式。** 检索小的"子"块以获得精确性。当来自同一父节的多个子块出现时，交换为父块以保留上下文。这持续提升答案质量，无需重新训练。
- **k_rerank=3 通常是最优的。** 超过这个数的每个额外块都会增加标记成本和生成延迟，却不提升答案质量。如果 k=8 对你仍然明显优于 k=3，说明重排器表现不佳。
- **HyDE / 查询扩展。** 从查询生成假设性答案，嵌入它，然后检索。弥合短问题和长文档之间的措辞差距。无需训练的免费精确率提升。
- **上下文预算低于 8K 标记。** 在该限制内持续命中意味着重排器阈值太松。
- **版本化一切。** 提示、分块规则、嵌入模型、重排器。任何漂移都会静默破坏答案质量。基于忠实性、上下文精确率和未回答率的 CI 门控在用户看到之前阻止回归。
- **三重检索（BM25 + 稠密 + 学习式稀疏如 SPLADE）优于双重检索**，在 2026 年基准测试中，尤其对混合专有名词和语义的查询。当基础设施支持 SPLADE 索引时上线。

根据 2026 年行业测量，适当的检索设计可将幻觉减少 70-90%。大多数 RAG 性能提升来自更好的检索，而不是模型微调。

## 交付

保存为 `outputs/skill-retrieval-picker.md`：

```markdown
---
name: retrieval-picker
description: 为给定语料库和查询模式选择检索技术栈。
version: 1.0.0
phase: 5
lesson: 14
tags: [nlp, retrieval, rag, search]
---

给定需求（语料库大小、查询模式、延迟预算、质量门槛、基础设施约束），输出：

1. 技术栈。仅 BM25、仅稠密、混合（BM25 + 稠密 + RRF）、混合 + 交叉编码器重排，或三重（BM25 + 稠密 + 学习式稀疏）。
2. 稠密编码器。指定具体模型名称。匹配语言、领域和上下文长度。
3. 重排器。如果使用，指定具体的交叉编码器模型。标记重排器在 top-30 上增加 30-100ms 延迟。
4. 评估计划。Recall@10 是检索器的主要指标。MRR 用于多答案场景。先基线，增量改进对照基线测量。

拒绝在包含命名实体、错误代码或产品 SKU 的语料库上推荐纯稠密，除非用户有证据表明稠密能处理精确匹配。拒绝在高风险检索（法律、医疗）中跳过重排，因为最终 top-5 决定了用户的答案。
```

## 练习

1. **简单。** 在 500 文档语料库上实现上述 `hybrid_search`。测试 20 个查询。比较仅 BM25、仅稠密和混合在 Recall@5 上的表现。
2. **中等。** 添加 MRR 计算。对于每个有已知正确文档的测试查询，找到正确文档在 BM25、稠密和混合排名中的排名。报告每种方法的 MRR。
3. **困难。** 使用 MultipleNegativesRankingLoss（Sentence Transformers）在你的领域上微调稠密编码器。从 500 个查询-文档对构建训练集。比较微调前后的召回率。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| BM25 | 关键词搜索 | Okapi BM25。通过词频、IDF 和长度对文档评分。 |
| 稠密检索 | 向量搜索 | 将查询 + 文档编码为向量，找到最近邻。 |
| 双编码器 | 嵌入模型 | 独立编码查询和文档。查询时速度快。 |
| 交叉编码器 | 重排器模型 | 将查询 + 文档一起编码。慢但准确。 |
| RRF | 排序融合 | 通过求和 `1/(k + rank)` 组合两个排名。 |
| Recall@k | 检索指标 | 相关文档出现在 top-k 中的查询比例。 |

## 扩展阅读

- [Robertson and Zaragoza (2009). The Probabilistic Relevance Framework: BM25 and Beyond](https://www.staff.city.ac.uk/~sbrp622/papers/foundations_bm25_review.pdf)——BM25 的权威论述。
- [Karpukhin et al. (2020). Dense Passage Retrieval for Open-Domain QA](https://arxiv.org/abs/2004.04906)——DPR，经典双编码器。
- [Formal et al. (2021). SPLADE: Sparse Lexical and Expansion Model](https://arxiv.org/abs/2107.05720)——弥合与稠密差距的学习式稀疏检索器。
- [Cormack, Clarke, Büttcher (2009). Reciprocal Rank Fusion outperforms Condorcet and individual Rank Learning Methods](https://plg.uwaterloo.ca/~gvcormac/cormacksigir09-rrf.pdf)——RRF 论文。
- [Khattab and Zaharia (2020). ColBERT: Efficient and Effective Passage Search](https://arxiv.org/abs/2004.12832)——延迟交互检索。