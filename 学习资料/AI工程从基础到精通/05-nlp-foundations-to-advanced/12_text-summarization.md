# 文本摘要

> 抽取式系统告诉你文档说了什么。生成式系统告诉你作者的意思。不同的任务，不同的陷阱。

**类型：** 构建
**语言：** Python
**前置要求：** 第 5 阶段 · 02（词袋模型 + TF-IDF），第 5 阶段 · 11（机器翻译）
**时间：** 约 75 分钟

## 问题

一篇 2000 词的新闻文章出现在你的信息流中。你需要 120 个词来捕捉它。你可以从文章中挑选三个最重要的句子（抽取式），或者用自己的话重写内容（生成式）。两者都叫摘要。它们是完全不同的问题。

抽取式摘要是一个排序问题。给每个句子打分，返回 top-`k`。输出始终语法正确，因为是逐字提取的。风险是遗漏分散在文章各处的信息。

生成式摘要是一个生成问题。一个 Transformer 在输入条件下生成新文本。输出流畅且有压缩性，但可能幻觉出源文中不存在的事实。风险是自信的编造。

本课构建两者，以及每种方法特有的失败模式。

## 概念

![抽取式 TextRank vs 生成式 Transformer](../assets/summarization.svg)

**抽取式。** 将文章视为一个图，节点是句子，边是相似度。在图上运行 PageRank（或类似算法）对句子进行打分，分数反映了它们与所有其他句子的关联程度。得分最高的句子就是摘要。经典实现是 **TextRank**（Mihalcea 和 Tarau, 2004）。

**生成式。** 在文档-摘要对上微调一个 Transformer 编码器-解码器（BART、T5、Pegasus）。推理时，模型读取文档并通过交叉注意力逐标记生成摘要。Pegasus 特别使用了一种间隙句子预训练目标，使其在摘要任务上表现出色，且无需大量微调。

使用 **ROUGE**（面向召回的要点评估替身）进行评估。ROUGE-1 和 ROUGE-2 评分基于一元和二元词重叠。ROUGE-L 评分基于最长公共子序列。越高越好，但 40 ROUGE-L 是"好"，50 是"卓越"。每篇论文都报告三者。使用 `rouge-score` 包。

## 构建

### 步骤 1：TextRank（抽取式）

```python
import math
import re
from collections import Counter


def sentence_split(text):
    return re.split(r"(?<=[.!?])\s+", text.strip())


def similarity(s1, s2):
    w1 = Counter(s1.lower().split())
    w2 = Counter(s2.lower().split())
    intersection = sum((w1 & w2).values())
    denom = math.log(len(w1) + 1) + math.log(len(w2) + 1)
    if denom == 0:
        return 0.0
    return intersection / denom


def textrank(text, top_k=3, damping=0.85, iterations=50, epsilon=1e-4):
    sentences = sentence_split(text)
    n = len(sentences)
    if n <= top_k:
        return sentences

    sim = [[0.0] * n for _ in range(n)]
    for i in range(n):
        for j in range(n):
            if i != j:
                sim[i][j] = similarity(sentences[i], sentences[j])

    scores = [1.0] * n
    for _ in range(iterations):
        new_scores = [1 - damping] * n
        for i in range(n):
            total_out = sum(sim[i]) or 1e-9
            for j in range(n):
                if sim[i][j] > 0:
                    new_scores[j] += damping * sim[i][j] / total_out * scores[i]
        if max(abs(s - ns) for s, ns in zip(scores, new_scores)) < epsilon:
            scores = new_scores
            break
        scores = new_scores

    ranked = sorted(range(n), key=lambda k: scores[k], reverse=True)[:top_k]
    ranked.sort()
    return [sentences[i] for i in ranked]
```

两点值得说明。相似度函数使用对数归一化的词重叠，这是 TextRank 的原始变体。TF-IDF 向量的余弦相似度也可以。阻尼因子 0.85 和迭代次数是 PageRank 的默认值。

### 步骤 2：使用 BART 进行生成式摘要

```python
from transformers import pipeline

summarizer = pipeline("summarization", model="facebook/bart-large-cnn")

article = """(长新闻文章文本)"""

summary = summarizer(article, max_length=120, min_length=60, do_sample=False)
print(summary[0]["summary_text"])
```

BART-large-CNN 在 CNN/DailyMail 语料库上进行了微调。它开箱即用地产生新闻风格的摘要。对于其他领域（科学论文、对话、法律），使用相应的 Pegasus 检查点或在目标数据上微调。

### 步骤 3：ROUGE 评估

```python
from rouge_score import rouge_scorer

scorer = rouge_scorer.RougeScorer(["rouge1", "rouge2", "rougeL"], use_stemmer=True)
scores = scorer.score(reference_summary, generated_summary)
print({k: round(v.fmeasure, 3) for k, v in scores.items()})
```

始终使用词干提取。不用它，"running"和"run"会被视为不同的词，ROUGE 就会低估分数。

### 超越 ROUGE（2026 年摘要评估）

ROUGE 作为主导的摘要指标已经二十年了，在 2026 年仅靠它是不够的。对 NLG 论文的大规模元分析显示：

- **BERTScore**（上下文嵌入相似度）在 2023 年逐渐普及，现在大多数摘要论文中与 ROUGE 一起报告。
- **BARTScore** 将评估视为生成：通过预训练 BART 在给定源文下为摘要分配的可能性来评分。
- **MoverScore**（上下文嵌入上的地球移动距离）在 2025 年摘要基准测试中达到最高排名，因为它比 ROUGE 更好地捕捉了语义重叠。
- **FactCC** 和**基于 QA 的真实性**在 2021-2023 年常见，现在常被 **G-Eval** 取代（一个 GPT-4 提示链，通过思维链推理对连贯性、一致性、流畅性、相关性进行评分）。
- **G-Eval** 和类似的 LLM 评委方法在评分标准设计良好时，与人类判断匹配约 80%。

生产建议：报告 ROUGE-L 用于遗留对比，BERTScore 用于语义重叠，G-Eval 用于连贯性和事实性。用 50-100 个人工标注的摘要进行校准。

### 步骤 4：真实性问题

生成式摘要容易产生幻觉。抽取式摘要的幻觉风险要低得多，因为输出是从源文逐字提取的，但如果源句子被去语境化、过时或顺序错乱，它们仍然可能误导。这是生产系统在合规相关内容中仍然偏爱抽取式方法的最大原因。

需要命名的幻觉类型：

- **实体替换。** 源文说"John Smith"。摘要说"John Brown"。
- **数字漂移。** 源文说"25,000"。摘要说"25 million"。
- **极性翻转。** 源文说"拒绝了提议"。摘要说"接受了提议"。
- **事实编造。** 源文没有提到 CEO。摘要说 CEO 批准了。

有效的评估方法：

- **FactCC。** 一个在源句子和摘要句子之间的蕴含关系上训练的二分类器。预测事实/非事实。
- **基于 QA 的真实性。** 向 QA 模型提问，答案在源文中。如果摘要支持不同的答案，则标记。
- **实体级 F1。** 比较源文和摘要中的命名实体。仅在摘要中出现的实体可疑。

对于任何面向用户且事实性重要的内容（新闻、医疗、法律、金融），抽取式是更安全的默认选择。生成式需要在循环中加入真实性检查。

## 使用

2026 年技术栈：

| 用例 | 推荐 |
|---------|-------------|
| 新闻，3-5 句摘要，英语 | `facebook/bart-large-cnn` |
| 科学论文 | `google/pegasus-pubmed` 或调优的 T5 |
| 多文档，长篇幅 | 任何有 32k+ 上下文的 LLM，带提示 |
| 对话摘要 | `philschmid/bart-large-cnn-samsum` |
| 抽取式，构造上低幻觉风险 | TextRank 或 `sumy` 的 LSA / LexRank |

在 2026 年，当计算不是约束时，带长上下文的 LLM 经常击败专用模型。权衡在于成本和可复现性；专用模型给出更一致的输出。

## 交付

保存为 `outputs/skill-summary-picker.md`：

```markdown
---
name: summary-picker
description: 选择抽取式或生成式，指定库和真实性检查。
version: 1.0.0
phase: 5
lesson: 12
tags: [nlp, summarization]
---

给定一个任务（文档类型、合规要求、长度、计算预算），输出：

1. 方法。抽取式或生成式。用一句话解释原因。
2. 起始模型/库。给出名称。`sumy.TextRankSummarizer`、`facebook/bart-large-cnn`、`google/pegasus-pubmed` 或一个 LLM 提示。
3. 评估计划。ROUGE-1、ROUGE-2、ROUGE-L（使用 rouge-score 带词干提取）。如果是生成式，加上真实性检查。
4. 一个需要探索的失败模式。实体替换是生成式新闻摘要中最常见的；标记源实体未出现在摘要中的样本。

拒绝在没有真实性门槛的情况下对医疗、法律、金融或受监管内容使用生成式摘要。将超过模型上下文窗口的输入标记为需要分块 map-reduce 摘要（不仅仅是截断）。
```

## 练习

1. **简单。** 在 5 篇新闻文章上运行 TextRank。将 top-3 句子与参考摘要进行比较。测量 ROUGE-L。在 CNN/DailyMail 风格的文章上你应该看到 30-45 ROUGE-L。
2. **中等。** 实现实体级真实性：从源文和摘要中提取命名实体（spaCy），计算源文实体在摘要中的召回率和摘要实体相对于源文的精确率。高精确率和低召回率意味着安全但简洁；低精确率意味着幻觉实体。
3. **困难。** 在 50 篇 CNN/DailyMail 文章上比较 BART-large-CNN 和 LLM（Claude 或 GPT-4）。报告 ROUGE-L、真实性（通过实体 F1）和每篇摘要的成本。记录每种方法在哪里胜出。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| 抽取式 | 挑选句子 | 从源文逐字返回句子。从不幻觉。 |
| 生成式 | 重写 | 在源文条件下生成新文本。可能幻觉。 |
| ROUGE | 摘要指标 | 系统输出与参考答案之间的 n-gram / LCS 重叠。 |
| TextRank | 基于图的抽取式 | 在句子相似度图上的 PageRank。 |
| 真实性 | 它是否正确 | 摘要中的论断是否被源文支持。 |
| 幻觉 | 编造内容 | 摘要中源文不支持的内容。 |

## 扩展阅读

- [Mihalcea and Tarau (2004). TextRank: Bringing Order into Texts](https://aclanthology.org/W04-3252/)——抽取式经典论文。
- [Lewis et al. (2019). BART: Denoising Sequence-to-Sequence Pre-training](https://arxiv.org/abs/1910.13461)——BART 论文。
- [Zhang et al. (2019). PEGASUS: Pre-training with Extracted Gap-sentences](https://arxiv.org/abs/1912.08777)——Pegasus 和间隙句子目标。
- [Lin (2004). ROUGE: A Package for Automatic Evaluation of Summaries](https://aclanthology.org/W04-1013/)——ROUGE 论文。
- [Maynez et al. (2020). On Faithfulness and Factuality in Abstractive Summarization](https://arxiv.org/abs/2005.00661)——真实性全景论文。