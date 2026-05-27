# Transformer 之前的文本生成——N-gram 语言模型

> 如果一个词令人惊讶，模型就是差的。困惑度把惊讶量化成一个数字。平滑让这个数字保持有限。

**类型：** 构建
**语言：** Python
**前置要求：** 第 5 阶段 · 01（文本处理），第 2 阶段 · 14（朴素贝叶斯）
**时间：** 约 45 分钟

## 问题

在 Transformer 之前，在 RNN 之前，在词嵌入之前，语言模型通过计数前 `n-1` 个词后面跟着某个词的频率来预测下一个词。计数 "the cat" → "sat" 47 次，"the cat" → "jumped" 12 次，"the cat" → "refrigerator" 0 次。归一化得到概率分布。

这就是 n-gram 语言模型。从 1980 年到 2015 年，它运行着每一个语音识别器、每一个拼写检查器和每一个基于短语的机器翻译系统。当你需要廉价设备端语言建模时，它仍然在运行。

有趣的问题是：对于未见过的 n-gram 该怎么办。基于原始计数的模型对所有没见过的东西分配零概率，这是灾难性的，因为句子很长，几乎每个长句子都包含至少一个未见过的序列。五十年的平滑研究解决了这个问题。Kneser-Ney 平滑是最终成果，现代深度学习继承了这个经验传统。

## 概念

![N-gram 模型：计数、平滑、生成](../assets/ngram.svg)

**N-gram 概率：** `P(w_i | w_{i-n+1}, ..., w_{i-1})`。固定 `n`（三元模型的 n=3，四元模型的 n=4）。通过计数计算：

```text
P(w | context) = count(context, w) / count(context)
```

**零计数问题。** 任何在训练中未见过的 n-gram 概率为零。2007 年对 Brown 语料库的一项研究发现，即使是 4-gram 模型，留出的 4-gram 中有 30% 在训练中未见过。没有平滑，你无法在任何真实文本上评估。

**平滑方法，按复杂程度排序：**

1. **拉普拉斯（加一）。** 每个计数加 1。简单，对罕见事件表现很差。
2. **Good-Turing。** 基于频率的频率，将概率质量从高频事件重新分配给未见事件。
3. **插值。** 用可调权重组合 n-gram、(n-1)-gram 等估计。
4. **回退。** 如果 n-gram 计数为零，回退到 (n-1)-gram。Katz 回退对此进行了归一化。
5. **绝对折扣。** 从所有计数中减去固定折扣 `D`，重新分配给未见事件。
6. **Kneser-Ney。** 绝对折扣加上对低阶模型的巧妙选择：使用*延续概率*（一个词出现在多少个上下文中）而不是原始频率。

Kneser-Ney 的洞察很深。"San Francisco" 是一个常见二元组。一元组 "Francisco" 大多出现在 "San" 之后。朴素的绝对折扣会给 "Francisco" 很高的一元概率（因为计数高）。Kneser-Ney 注意到 "Francisco" 只出现在一个上下文中，因此降低其延续概率。结果：以 "Francisco" 结尾的新二元组会得到适当的低概率。

**评估：困惑度。** 在留出测试集上，每词平均负对数似然的指数。越低越好。困惑度 100 意味着模型就像在 100 个词中均匀选择一样困惑。

```text
perplexity = exp(- (1/N) * Σ log P(w_i | context_i))
```

## 构建

### 步骤 1：三元组计数

```python
from collections import Counter, defaultdict


def train_ngram(corpus_tokens, n=3):
    ngrams = Counter()
    contexts = Counter()
    for sentence in corpus_tokens:
        padded = ["<s>"] * (n - 1) + sentence + ["</s>"]
        for i in range(len(padded) - n + 1):
            ctx = tuple(padded[i:i + n - 1])
            word = padded[i + n - 1]
            ngrams[ctx + (word,)] += 1
            contexts[ctx] += 1
    return ngrams, contexts


def raw_probability(ngrams, contexts, context, word):
    ctx = tuple(context)
    if contexts.get(ctx, 0) == 0:
        return 0.0
    return ngrams.get(ctx + (word,), 0) / contexts[ctx]
```

输入是分词后的句子列表。输出是 n-gram 计数和上下文计数。`<s>` 和 `</s>` 是句子边界。

### 步骤 2：拉普拉斯平滑

```python
def laplace_probability(ngrams, contexts, vocab_size, context, word):
    ctx = tuple(context)
    numerator = ngrams.get(ctx + (word,), 0) + 1
    denominator = contexts.get(ctx, 0) + vocab_size
    return numerator / denominator
```

每个计数加 1。进行了平滑，但过度分配质量给未见事件，同时也损害了已知罕见事件。

### 步骤 3：Kneser-Ney（二元组，插值式）

```python
def kneser_ney_bigram_model(corpus_tokens, discount=0.75):
    unigrams = Counter()
    bigrams = Counter()
    unigram_contexts = defaultdict(set)

    for sentence in corpus_tokens:
        padded = ["<s>"] + sentence + ["</s>"]
        for i, w in enumerate(padded):
            unigrams[w] += 1
            if i > 0:
                prev = padded[i - 1]
                bigrams[(prev, w)] += 1
                unigram_contexts[w].add(prev)

    total_unique_bigrams = sum(len(ctx_set) for ctx_set in unigram_contexts.values())
    continuation_prob = {
        w: len(ctx_set) / total_unique_bigrams for w, ctx_set in unigram_contexts.items()
    }

    context_totals = Counter()
    for (prev, w), count in bigrams.items():
        context_totals[prev] += count

    unique_follow = defaultdict(set)
    for (prev, w) in bigrams:
        unique_follow[prev].add(w)

    def prob(prev, w):
        count = bigrams.get((prev, w), 0)
        denom = context_totals.get(prev, 0)
        if denom == 0:
            return continuation_prob.get(w, 1e-9)
        first_term = max(count - discount, 0) / denom
        lambda_prev = discount * len(unique_follow[prev]) / denom
        return first_term + lambda_prev * continuation_prob.get(w, 1e-9)

    return prob
```

三个活动部件。`continuation_prob` 捕捉"这个词出现在多少个不同的上下文中？"（Kneser-Ney 的创新）。`lambda_prev` 是折扣释放的质量，用于加权回退。最终概率是折扣主项加上加权延续项。

### 步骤 4：带采样的文本生成

```python
import random


def generate(prob_fn, vocab, prefix, max_len=30, seed=0):
    rng = random.Random(seed)
    tokens = list(prefix)
    for _ in range(max_len):
        candidates = [(w, prob_fn(tokens[-1], w)) for w in vocab]
        total = sum(p for _, p in candidates)
        r = rng.random() * total
        acc = 0.0
        for w, p in candidates:
            acc += p
            if r <= acc:
                tokens.append(w)
                break
        if tokens[-1] == "</s>":
            break
    return tokens
```

按概率比例采样。每次不同种子给出不同输出。对于类似束搜索的输出，在每一步选择最大概率（贪心）并添加一个小的随机调节旋钮（温度）。

### 步骤 5：困惑度

```python
import math


def perplexity(prob_fn, sentences):
    total_log_prob = 0.0
    total_tokens = 0
    for sentence in sentences:
        padded = ["<s>"] + sentence + ["</s>"]
        for i in range(1, len(padded)):
            p = prob_fn(padded[i - 1], padded[i])
            total_log_prob += math.log(max(p, 1e-12))
            total_tokens += 1
    return math.exp(-total_log_prob / total_tokens)
```

越低越好。对于 Brown 语料库，一个调优良好的 4-gram KN 模型困惑度大约在 140。一个 Transformer LM 在相同测试集上能达到 15-30。差距大约 10 倍。这个差距就是为什么领域向前发展了。

## 使用

- **经典 NLP 教学。** 你能接触到的最清晰的平滑、最大似然估计和困惑度。
- **KenLM。** 生产级 n-gram 库。在需要低延迟的语音和机器翻译系统中用作重评分器。
- **设备端自动补全。** 键盘中的三元模型。现在仍然在用。
- **基线。** 在宣布你的神经 LM 好之前，总是先计算 n-gram LM 的困惑度。如果你的 Transformer 没有以大幅优势击败 KN，那就出了什么问题。

## 交付

保存为 `outputs/prompt-lm-baseline.md`：

```markdown
---
name: lm-baseline
description: 在训练神经语言模型之前构建可复现的 n-gram 语言模型基线。
phase: 5
lesson: 16
---

给定一个语料库和目标用途（下一个词预测、重评分、困惑度基线），输出：

1. N-gram 阶数。通用英语用三元，语料库大用四元，语音重评分用五元。
2. 平滑。默认使用修正 Kneser-Ney；拉普拉斯仅用于教学。
3. 库。生产用 `kenlm`，教学用 `nltk.lm`，仅在学习时自己从头写。
4. 评估。在留出数据上的困惑度，确保训练集和测试集之间分词一致。

拒绝报告使用不同分词的系统之间的困惑度比较——困惑度数字仅在相同分词下可比较。标记测试集中的OOV率；KN 对 OOV 处理较差，除非你在训练时预留了特殊的 <UNK> 标记。
```

## 练习

1. **简单。** 在 1000 句莎士比亚语料库上训练三元 LM。生成 20 个句子。它们会是局部合理但全局不连贯的。这是经典演示。
2. **中等。** 在留出的莎士比亚数据上为你的 KN 模型实现困惑度。与拉普拉斯对比。你应该看到 KN 的困惑度低 30-50%。
3. **困难。** 构建一个三元拼写校正器：给定一个拼写错误的词及其上下文，生成修正候选并按 LM 下的上下文概率排序。在 Birkbeck 拼写语料库（公开）上评估。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| N-gram | 词序列 | `n` 个连续标记的序列。 |
| 平滑 | 避免零值 | 重新分配概率质量，使未见事件获得非零概率。 |
| 困惑度 | LM 质量指标 | 留出数据上的 `exp(-平均对数概率)`。越低越好。 |
| 回退 | 回退到更短的上下文 | 如果三元计数为零，使用二元。Katz 回退对此进行了形式化。 |
| Kneser-Ney | n-gram 的最佳平滑 | 绝对折扣 + 低阶模型的延续概率。 |
| 延续概率 | KN 特有 | `P(w)` 按词 `w` 出现的上下文数量加权，而非原始计数。 |

## 扩展阅读

- [Jurafsky and Martin — Speech and Language Processing, 第 3 章 (2026 草稿)](https://web.stanford.edu/~jurafsky/slp3/3.pdf)——n-gram LM 和平滑的权威论述。
- [Chen and Goodman (1998). An Empirical Study of Smoothing Techniques for Language Modeling](https://dash.harvard.edu/handle/1/25104739)——确立 Kneser-Ney 为最佳 n-gram 平滑器的论文。
- [Kneser and Ney (1995). Improved Backing-off for M-gram Language Modeling](https://ieeexplore.ieee.org/document/479394)——原始 KN 论文。
- [KenLM](https://kheafield.com/code/kenlm/)——快速生产级 n-gram LM，在 2026 年仍用于延迟敏感应用。