# 命名实体识别

> 把名称提取出来。听起来很简单——直到你遇到模糊的边界、嵌套实体和领域术语。

**类型：** 构建
**语言：** Python
**前置要求：** 第 5 阶段 · 02（词袋模型 + TF-IDF），第 5 阶段 · 03（词嵌入）
**时间：** 约 75 分钟

## 问题

"Apple sued Google over its iPhone search deal in the US." 五个实体：Apple（组织）、Google（组织）、iPhone（产品）、search deal（可能）、US（地理位置）。一个好的 NER 系统能正确提取所有实体及其类型。一个差的系统会漏掉 iPhone，把苹果公司与苹果水果搞混，把"US"标记为人名。

NER 是每个结构化提取流水线底层的工作引擎。简历解析、合规日志扫描、医疗记录脱敏、搜索查询理解、聊天机器人回复的事实基础、法律合同提取。你几乎看不见它，却始终依赖它。

本课从经典路径（基于规则、HMM、CRF）走向现代路径（BiLSTM-CRF，再到 Transformer）。每一步都解决了前一步的特定局限。模式本身就是课程。

## 概念

**BIO 标注**（或 BILOU）将实体提取转化为序列标注问题。将每个标记标注为 `B-TYPE`（实体开始）、`I-TYPE`（实体内部）或 `O`（不属于任何实体）。

```
Apple    B-ORG
sued     O
Google   B-ORG
over     O
its      O
iPhone   B-PRODUCT
search   O
deal     O
in       O
the      O
US       B-GPE
.        O
```

多标记实体的链式标注：`New B-GPE`，`York I-GPE`，`City I-GPE`。理解 BIO 的模型可以提取任意长度的片段。

架构演进：

- **基于规则。** 正则表达式 + 地名词典查找。对已知实体精确率高，对新实体覆盖率为零。
- **HMM。** 隐马尔可夫模型。给定标签的标记发射概率，标签到标签的转移概率。维特比解码。在有标注数据上训练。
- **CRF。** 条件随机场。类似 HMM，但是判别式模型，因此可以混合任意特征（词形、大小写、相邻词）。到 2026 年仍是在低资源部署场景下的经典生产级主力。
- **BiLSTM-CRF。** 用神经元特征替代手工特征。LSTM 从两个方向读取句子，顶层的 CRF 层强制一致的标签序列。
- **基于 Transformer。** 用标记分类头微调 BERT。准确率最高。计算量最大。

## 构建

### 步骤 1：BIO 标注辅助函数

```python
def spans_to_bio(tokens, spans):
    labels = ["O"] * len(tokens)
    for start, end, label in spans:
        labels[start] = f"B-{label}"
        for i in range(start + 1, end):
            labels[i] = f"I-{label}"
    return labels


def bio_to_spans(tokens, labels):
    spans = []
    current = None
    for i, label in enumerate(labels):
        if label.startswith("B-"):
            if current:
                spans.append(current)
            current = (i, i + 1, label[2:])
        elif label.startswith("I-") and current and current[2] == label[2:]:
            current = (current[0], i + 1, current[2])
        else:
            if current:
                spans.append(current)
                current = None
    if current:
        spans.append(current)
    return spans
```

```python
>>> tokens = ["Apple", "sued", "Google", "over", "iPhone", "sales", "."]
>>> labels = ["B-ORG", "O", "B-ORG", "O", "B-PRODUCT", "O", "O"]
>>> bio_to_spans(tokens, labels)
[(0, 1, 'ORG'), (2, 3, 'ORG'), (4, 5, 'PRODUCT')]
```

### 步骤 2：手工特征

对于经典（非神经元）NER，特征是关键。有用的特征：

```python
def token_features(token, prev_token, next_token):
    return {
        "lower": token.lower(),
        "is_upper": token.isupper(),
        "is_title": token.istitle(),
        "has_digit": any(c.isdigit() for c in token),
        "suffix_3": token[-3:].lower(),
        "shape": word_shape(token),
        "prev_lower": prev_token.lower() if prev_token else "<BOS>",
        "next_lower": next_token.lower() if next_token else "<EOS>",
    }


def word_shape(word):
    out = []
    for c in word:
        if c.isupper():
            out.append("X")
        elif c.islower():
            out.append("x")
        elif c.isdigit():
            out.append("d")
        else:
            out.append(c)
    return "".join(out)
```

`word_shape("iPhone")` 返回 `xXxxxx`。`word_shape("USA-2024")` 返回 `XXX-dddd`。大小写模式对专有名词有很强的信号指示作用。

### 步骤 3：简单的基于规则 + 词典基线

```python
ORG_GAZETTEER = {"Apple", "Google", "Microsoft", "OpenAI", "Meta", "Amazon", "Netflix"}
GPE_GAZETTEER = {"US", "USA", "UK", "India", "Germany", "France"}
PRODUCT_GAZETTEER = {"iPhone", "Android", "Windows", "ChatGPT", "Claude"}


def rule_based_ner(tokens):
    labels = []
    for token in tokens:
        if token in ORG_GAZETTEER:
            labels.append("B-ORG")
        elif token in GPE_GAZETTEER:
            labels.append("B-GPE")
        elif token in PRODUCT_GAZETTEER:
            labels.append("B-PRODUCT")
        else:
            labels.append("O")
    return labels
```

生产级地名词典包含从 Wikipedia 和 DBpedia 抓取的上百万条目。覆盖面很广。但消歧（Apple 指公司还是水果）效果很差。这也是统计模型胜出的原因。

### 步骤 4：CRF 步骤（概览，非完整实现）

从零写一个完整的 CRF 如果没有概率论基础，50 行代码也无法讲清楚。使用 `sklearn-crfsuite`：

```python
import sklearn_crfsuite

def to_features(tokens):
    out = []
    for i, tok in enumerate(tokens):
        prev = tokens[i - 1] if i > 0 else ""
        nxt = tokens[i + 1] if i + 1 < len(tokens) else ""
        out.append({
            "word.lower()": tok.lower(),
            "word.isupper()": tok.isupper(),
            "word.istitle()": tok.istitle(),
            "word.isdigit()": tok.isdigit(),
            "word.suffix3": tok[-3:].lower(),
            "word.shape": word_shape(tok),
            "prev.word.lower()": prev.lower(),
            "next.word.lower()": nxt.lower(),
            "BOS": i == 0,
            "EOS": i == len(tokens) - 1,
        })
    return out


crf = sklearn_crfsuite.CRF(algorithm="lbfgs", c1=0.1, c2=0.1, max_iterations=100, all_possible_transitions=True)
X_train = [to_features(s) for s in sentences_tokenized]
crf.fit(X_train, bio_labels_train)
```

`c1` 和 `c2` 分别是 L1 和 L2 正则化。`all_possible_transitions=True` 让模型自己学到非法序列（如 `I-ORG` 跟在 `O` 后面）是不太可能的，这就是 CRF 如何在不显式编写约束的情况下强制执行 BIO 一致性。

### 步骤 5：BiLSTM-CRF 的增益

特征变成可学习的。输入：标记嵌入（GloVe 或 fastText）。LSTM 从左到右和从右到左读取。拼接后的隐藏状态通过 CRF 输出层。CRF 仍然强制标签序列一致性；LSTM 替代了手工特征，用可学习的特征取而代之。

```python
import torch
import torch.nn as nn


class BiLSTM_CRF_Head(nn.Module):
    def __init__(self, vocab_size, embed_dim, hidden_dim, n_labels):
        super().__init__()
        self.embed = nn.Embedding(vocab_size, embed_dim)
        self.lstm = nn.LSTM(embed_dim, hidden_dim, bidirectional=True, batch_first=True)
        self.fc = nn.Linear(hidden_dim * 2, n_labels)

    def forward(self, token_ids):
        e = self.embed(token_ids)
        h, _ = self.lstm(e)
        emissions = self.fc(h)
        return emissions
```

对于 CRF 层，使用 `torchcrf.CRF`（pip install pytorch-crf）。相对于手工 CRF 的增益是可衡量的，但除非你有数万条标注句子，否则增益比你预期的要小。

## 使用

spaCy 开箱即用地提供生产级 NER。

```python
import spacy

nlp = spacy.load("en_core_web_sm")
doc = nlp("Apple sued Google over its iPhone search deal in the US.")
for ent in doc.ents:
    print(f"{ent.text:20s} {ent.label_}")
```

```
Apple                ORG
Google               ORG
iPhone               ORG
US                   GPE
```

注意 `iPhone` 被标注为 `ORG` 而非 `PRODUCT`——spaCy 的小模型对产品实体的覆盖较弱。大模型（`en_core_web_lg`）效果更好。Transformer 模型（`en_core_web_trf`）效果更好。

Hugging Face 用于基于 BERT 的 NER：

```python
from transformers import pipeline

ner = pipeline("ner", model="dslim/bert-base-NER", aggregation_strategy="simple")
print(ner("Apple sued Google over its iPhone in the US."))
```

```
[{'entity_group': 'ORG', 'word': 'Apple', ...},
 {'entity_group': 'ORG', 'word': 'Google', ...},
 {'entity_group': 'MISC', 'word': 'iPhone', ...},
 {'entity_group': 'LOC', 'word': 'US', ...}]
```

`aggregation_strategy="simple"` 将连续的 B-X、I-X 标记合并为一个片段。没有它，你得到的是标记级别的标签，需要自己手动合并。

### 基于 LLM 的 NER（2026 年的选择）

零样本和少样本 LLM NER 现在在许多领域已经可以与微调模型相媲美，并且在标注数据稀缺时表现明显更好。

- **零样本提示。** 给 LLM 一个实体类型列表和一个示例模式。要求 JSON 输出。开箱即用；在新领域上准确率中等。
- **ZeroTuneBio 风格的提示。** 将任务分解为候选提取 → 含义解释 → 判断 → 重新检查。多阶段提示（非单次提示）能显著提升生物医学 NER 的准确率。同样的模式适用于法律、金融和科学领域。
- **带 RAG 的动态提示。** 每次推理调用时从少量标注种子集中检索最相似的标注样本；实时构建少样本提示。在 2026 年的基准测试中，这比静态提示将 GPT-4 生物医学 NER F1 提升了 11-12%。
- **按实体类型分解。** 对于长文档，一次性提取所有实体类型的单次调用会随着文本增长而失去召回率。按实体类型分别进行一轮提取。推理成本更高，准确率显著更高。这是临床笔记和法律合同的标准模式。

截至 2026 年的生产建议：在收集训练数据之前，先从一个 LLM 零样本基线开始。通常 F1 已经足够好，你根本不需要微调。

### 经典 NER 仍然胜出的场景

即使有了 LLM，经典 NER 在以下场景仍胜出：

- 延迟预算低于 50ms。
- 你有数千条标注样本，需要 98% 以上的 F1。
- 领域有一个稳定的本体，预训练的 CRF 或 BiLSTM 可以很好地迁移。
- 监管要求需要本地部署的非生成式模型。

### 它失败的地方

- **领域偏移。** 在 CoNLL 上训练的 NER 应用于法律合同时效果比地名词典还差。在你的领域上进行微调。
- **嵌套实体。** "Bank of America Tower" 同时是一个 ORG 和一个 FACILITY。标准 BIO 无法表示重叠的片段。你需要嵌套 NER（多轮或基于片段的模型）。
- **长实体。** "United States Federal Deposit Insurance Corporation." 标记级模型有时会将其分割。使用 `aggregation_strategy` 或后处理。
- **稀疏类型。** 医学 NER 标签如 DRUG_BRAND、ADVERSE_EVENT、DOSE。通用模型无法识别。Scispacy 和 BioBERT 是这些场景的起点。

## 交付

保存为 `outputs/skill-ner-picker.md`：

```markdown
---
name: ner-picker
description: 为给定的提取任务选择合适的 NER 方法。
version: 1.0.0
phase: 5
lesson: 06
tags: [nlp, ner, extraction]
---

给定一个任务描述（领域、标签集、语言、延迟、数据量），输出：

1. 方法。基于规则 + 地名词典、CRF、BiLSTM-CRF 或 Transformer 微调。
2. 起始模型。给出名称（spaCy 模型 ID、Hugging Face 检查点 ID，或"自定义，从头训练"）。
3. 标注策略。BIO、BILOU 或基于片段。用一句话说明理由。
4. 评估。使用 `seqeval`。始终报告实体级 F1（非标记级）。

拒绝为少于 500 个标注样本的情况推荐微调 Transformer，除非用户已经有预训练的领域模型。将嵌套实体标记为需要基于片段或多轮模型。如果用户提到"生产规模"且标签未修改自 CoNLL-2003，要求进行地名词典审查。
```

## 练习

1. **简单。** 实现 `bio_to_spans`（`spans_to_bio` 的反函数），并在 10 个句子上验证往返一致性。
2. **中等。** 在 CoNLL-2003 英文 NER 数据集上训练上述 sklearn-crfsuite CRF。使用 `seqeval` 报告每个实体的 F1。典型结果：约 84 F1。
3. **困难。** 在领域特定的 NER 数据集（医学、法律或金融）上微调 `distilbert-base-cased`。与 spaCy 小模型对比。记录数据泄漏检查，写下让你感到意外的发现。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| NER | 提取名称 | 将标记片段标注为类型（PERSON、ORG、GPE、DATE...）。 |
| BIO | 标注方案 | `B-X` 开始，`I-X` 继续，`O` 排除在外。 |
| BILOU | 更好的 BIO | 增加 `L-X`（最后）和 `U-X`（单元），边界更清晰。 |
| CRF | 结构化分类器 | 不仅建模发射概率，还建模标签间的转移。强制执行有效序列。 |
| 嵌套 NER | 重叠实体 | 一个片段与它的子片段是不同的实体。BIO 无法表示这种情况。 |
| 实体级 F1 | 正确的 NER 指标 | 预测片段必须与真实片段完全匹配。标记级 F1 会高估准确率。 |

## 扩展阅读

- [Lample et al. (2016). Neural Architectures for Named Entity Recognition](https://arxiv.org/abs/1603.01360)——BiLSTM-CRF 论文。经典之作。
- [Devlin et al. (2018). BERT: Pre-training of Deep Bidirectional Transformers](https://arxiv.org/abs/1810.04805)——引入了成为标准的标记分类模式。
- [spaCy 语言特征——命名实体](https://spacy.io/usage/linguistic-features#named-entities)——关于 `Doc.ents` 和 `Span` 每个属性的实用参考。
- [seqeval](https://github.com/chakki-works/seqeval)——正确的评估指标库。始终使用它。