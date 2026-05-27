# 词性标注与句法分析

> 语法曾一度不被重视。然后每个 LLM 流水线都需要验证结构化提取，它又回来了。

**类型：** 构建
**语言：** Python
**前置要求：** 第 5 阶段 · 01（文本处理），第 2 阶段 · 14（朴素贝叶斯）
**时间：** 约 45 分钟

## 问题

第 01 课承诺词形还原需要一个词性标签。不知道 `running` 是动词，词形还原器就无法将其还原为 `run`。不知道 `better` 是形容词，就无法还原为 `good`。

那个承诺隐藏了整个子领域。词性标注分配语法类别。句法分析恢复句子的树结构：哪个词修饰哪个词，哪个动词支配哪些论元。经典 NLP 花了二十年时间完善这两者。然后深度学习将它们折叠成了预训练 Transformer 之上的一个标记分类任务，研究社区就转向了。

但应用社区没有。每个结构化提取流水线在底层仍然使用词性和依存树。LLM 生成的 JSON 需要根据语法约束进行验证。问答系统使用依存分析来分解查询。机器翻译质量评估器检查分析树的对齐。

值得了解。本课介绍标签集、基线和那个临界点——在那之后你就不再从零实现，而是直接调用 spaCy。

## 概念

**词性标注** 为每个标记分配一个语法类别。**宾夕法尼亚树库（PTB）** 标签集是英文默认标准。36 个标签，其区分在非专业读者看来过于精细：`NN` 单数名词，`NNS` 复数名词，`NNP` 专有名词单数，`VBD` 动词过去式，`VBZ` 动词第三人称单数现在式，等等。**通用依存（UD）** 标签集更粗粒度（17 个标签），且与语言无关；它已成为跨语言工作的默认标准。

```
The/DET cats/NOUN were/AUX running/VERB at/ADP 3pm/NOUN ./PUNCT
```

**句法分析** 生成一棵树。两种主要风格：

- **成分分析。** 名词短语、动词短语、介词短语相互嵌套。输出是一棵以词为叶子节点的非终结符类别（NP、VP、PP）树。
- **依存分析。** 每个词有一个它所依赖的中心词，标有语法关系。输出是一棵树，每条边是一个（中心词、依存词、关系）三元组。

依存分析在 2010 年代胜出，因为它能干净地跨语言泛化，尤其适用于自由语序语言。

```
running 是 ROOT
cats 是 running 的 nsubj
were 是 running 的 aux
at 是 running 的 prep
3pm 是 at 的 pobj
```

## 构建

### 步骤 1：最常见标签基线

能工作的最笨的词性标注器。对每个词，预测它在训练中最常出现的标签。

```python
from collections import Counter, defaultdict


def train_mft(train_examples):
    word_tag_counts = defaultdict(Counter)
    all_tags = Counter()
    for tokens, tags in train_examples:
        for token, tag in zip(tokens, tags):
            word_tag_counts[token.lower()][tag] += 1
            all_tags[tag] += 1
    word_best = {w: c.most_common(1)[0][0] for w, c in word_tag_counts.items()}
    default_tag = all_tags.most_common(1)[0][0]
    return word_best, default_tag


def predict_mft(tokens, word_best, default_tag):
    return [word_best.get(t.lower(), default_tag) for t in tokens]
```

在 Brown 语料库上，这个基线达到约 85% 的准确率。不算好，但这是任何正经模型都不应低于的下限。

### 步骤 2：二元 HMM 标注器

建模序列的联合概率：

```
P(tags, words) = ∏ P(tag_i | tag_{i-1}) * P(word_i | tag_i)
```

两张表：转移概率（给定前一个标签的当前标签），发射概率（给定标签的当前词）。两者都通过计数加 Laplace 平滑来估计。用维特比算法（在标签格上的动态规划）解码。

```python
import math


def train_hmm(train_examples, alpha=0.01):
    transitions = defaultdict(Counter)
    emissions = defaultdict(Counter)
    tags = set()
    vocab = set()

    for tokens, ts in train_examples:
        prev = "<BOS>"
        for token, tag in zip(tokens, ts):
            transitions[prev][tag] += 1
            emissions[tag][token.lower()] += 1
            tags.add(tag)
            vocab.add(token.lower())
            prev = tag
        transitions[prev]["<EOS>"] += 1

    return transitions, emissions, tags, vocab


def log_prob(table, given, key, smooth_denom, alpha):
    return math.log((table[given].get(key, 0) + alpha) / smooth_denom)


def viterbi(tokens, transitions, emissions, tags, vocab, alpha=0.01):
    tags_list = list(tags)
    n = len(tokens)
    V = [[0.0] * len(tags_list) for _ in range(n)]
    back = [[0] * len(tags_list) for _ in range(n)]

    for j, tag in enumerate(tags_list):
        em_denom = sum(emissions[tag].values()) + alpha * (len(vocab) + 1)
        tr_denom = sum(transitions["<BOS>"].values()) + alpha * (len(tags_list) + 1)
        tr = log_prob(transitions, "<BOS>", tag, tr_denom, alpha)
        em = log_prob(emissions, tag, tokens[0].lower(), em_denom, alpha)
        V[0][j] = tr + em
        back[0][j] = 0

    for i in range(1, n):
        for j, tag in enumerate(tags_list):
            em_denom = sum(emissions[tag].values()) + alpha * (len(vocab) + 1)
            em = log_prob(emissions, tag, tokens[i].lower(), em_denom, alpha)
            best_prev = 0
            best_score = -1e30
            for k, prev_tag in enumerate(tags_list):
                tr_denom = sum(transitions[prev_tag].values()) + alpha * (len(tags_list) + 1)
                tr = log_prob(transitions, prev_tag, tag, tr_denom, alpha)
                score = V[i - 1][k] + tr + em
                if score > best_score:
                    best_score = score
                    best_prev = k
            V[i][j] = best_score
            back[i][j] = best_prev

    last_best = max(range(len(tags_list)), key=lambda j: V[n - 1][j])
    path = [last_best]
    for i in range(n - 1, 0, -1):
        path.append(back[i][path[-1]])
    return [tags_list[j] for j in reversed(path)]
```

二元 HMM 在 Brown 上达到约 93% 的准确率。从 85% 到 93% 的跃升主要来自转移概率——模型学到了 `DET NOUN` 常见而 `NOUN DET` 罕见。

### 步骤 3：现代标注器为何比这更好

转移 + 发射概率是局部的。它们无法捕捉到 `saw` 在 "I bought a saw" 中是名词，而在 "I saw the movie" 中是动词。一个带有任意特征（后缀、词形、前后词、词本身）的 CRF 可以达到约 97%。BiLSTM-CRF 或 Transformer 达到约 98%+。

这项任务的上限由标注者分歧决定。在宾夕法尼亚树库上，人类标注者一致率约为 97%。超过 98% 的模型可能在过拟合测试集。

### 步骤 4：依存分析概览

从零实现完整的依存分析超出本课范围；经典的教材讲解在 Jurafsky 和 Martin 的书中。需要了解的两种经典家族：

- **基于转移的** 分析器（arc-eager、arc-standard）行为类似移进-归约分析器：它们读取标记、将其推入栈中，并应用创建弧的归约动作。贪心解码速度快。经典实现是 MaltParser。现代神经元版本：Chen 和 Manning 的基于转移的分析器。
- **基于图的** 分析器（Eisner 算法、Dozat-Manning 双仿射）对每条可能的中心词-依存词边打分，选择最大生成树。速度较慢但更准确。

对于大多数应用工作，调用 spaCy：

```python
import spacy

nlp = spacy.load("en_core_web_sm")
doc = nlp("The cats were running at 3pm.")
for token in doc:
    print(f"{token.text:10s} tag={token.tag_:5s} pos={token.pos_:6s} dep={token.dep_:10s} head={token.head.text}")
```

```
The        tag=DT    pos=DET    dep=det        head=cats
cats       tag=NNS   pos=NOUN   dep=nsubj      head=running
were       tag=VBD   pos=AUX    dep=aux        head=running
running    tag=VBG   pos=VERB   dep=ROOT       head=running
at         tag=IN    pos=ADP    dep=prep       head=running
3pm        tag=NN    pos=NOUN   dep=pobj       head=at
.          tag=.     pos=PUNCT  dep=punct      head=running
```

从下往上阅读 `dep` 列，句子的语法结构便自然呈现。

## 使用

每个生产级 NLP 库都将词性和依存分析器作为标准流水线的一部分。

- **spaCy**（`en_core_web_sm` / `md` / `lg` / `trf`）。快速、准确，集成了分词 + NER + 词形还原。`token.tag_`（Penn）、`token.pos_`（UD）、`token.dep_`（依存关系）。
- **Stanford NLP（stanza）。** Stanford 的 CoreNLP 后继者。在 60+ 语言上达到最优水平。
- **trankit。** 基于 Transformer，UD 准确率高。
- **NLTK。** `pos_tag`。可用但慢，较旧。适合教学。

### 这在 2026 年仍然重要的场景

- **词形还原。** 第 01 课需要词性来正确进行词形还原。始终如此。
- **LLM 输出的结构化提取。** 验证生成的句子是否遵守语法约束（如主谓一致、必需的修饰语）。
- **方面级情感分析。** 依存分析告诉你哪个形容词修饰哪个名词。
- **查询理解。** "movies directed by Wes Anderson starring Bill Murray" 通过句法分析分解为结构化约束。
- **跨语言迁移。** UD 标签和依存关系与语言无关，使得对新语言进行零样本结构化分析成为可能。
- **低计算流水线。** 如果你无法部署 Transformer，词性 + 依存分析 + 地名词典能让你走得很远。

## 交付

保存为 `outputs/skill-grammar-pipeline.md`：

```markdown
---
name: grammar-pipeline
description: 为下游 NLP 任务设计经典词性 + 依存流水线。
version: 1.0.0
phase: 5
lesson: 07
tags: [nlp, pos, parsing]
---

给定一个下游任务（信息提取、重写验证、查询分解、词形还原），你输出：

1. 使用的标签集。Penn Treebank 用于仅英文的遗留流水线，Universal Dependencies 用于多语言或跨语言。
2. 库。spaCy 用于大多数生产场景，stanza 用于学术级多语言，trankit 用于最高 UD 准确率。给出具体的模型 ID。
3. 集成模式。展示调用库并消费所需属性（`.pos_`、`.dep_`、`.head`）的 3-5 行代码。
4. 需要测试的失败模式。名动歧义（`saw`、`book`、`can`）和介词短语附着歧义是经典陷阱。采样 20 个输出并肉眼检查。

拒绝推荐自己编写分析器。从零构建分析器是研究项目，不是应用任务。将任何消费词性标签但未处理大小写变体的流水线标记为脆弱。
```

## 练习

1. **简单。** 在一个小型标注语料库（如 NLTK 的 Brown 子集）上使用最常见标签基线，测量留存句子上的准确率。验证约 85% 的结果。
2. **中等。** 训练上述二元 HMM，报告每个标签的精确率/召回率。HMM 最容易混淆哪些标签？
3. **困难。** 使用 spaCy 的依存分析从 1000 句样本中提取主-谓-宾三元组。在 50 个手工标注的三元组上评估。记录提取失败的地方（通常是被动语态、并列结构和省略主语）。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| 词性标签 | 词的类别 | 语法类别。PTB 有 36 个；UD 有 17 个。 |
| 宾夕法尼亚树库 | 标准标签集 | 英文专用。细粒度的动词时态和名词数。 |
| 通用依存 | 多语言标签集 | 比 PTB 粗粒度；语言中立；跨语言工作的默认标准。 |
| 依存分析 | 句子树 | 每个词有一个中心词，每条边有一个语法关系。 |
| 维特比 | 动态规划 | 给定发射和转移概率，找到最高概率的标签序列。 |

## 扩展阅读

- [Jurafsky and Martin——Speech and Language Processing，第 8 章和第 18 章](https://web.stanford.edu/~jurafsky/slp3/)——关于词性和分析的经典教材。
- [Universal Dependencies 项目](https://universaldependencies.org/)——每个多语言分析器使用的跨语言标签集和树库集合。
- [spaCy 语言特征指南](https://spacy.io/usage/linguistic-features)——关于 `Token` 暴露的每个属性的实用参考。
- [Chen and Manning (2014). A Fast and Accurate Dependency Parser using Neural Networks](https://nlp.stanford.edu/pubs/emnlp2014-depparser.pdf)——将神经元分析器带入主流的论文。