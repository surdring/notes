# 多语言 NLP

> 一个模型，100+ 语言，对其中大多数零训练数据。跨语言迁移是 2020 年代实用的奇迹。

**类型：** 学习
**语言：** Python
**前置要求：** 第 5 阶段 · 04（GloVe、FastText、子词），第 5 阶段 · 11（机器翻译）
**时间：** 约 45 分钟

## 问题

英语有数十亿标注样本。乌尔都语有数千。迈蒂利语几乎为零。任何服务于全球受众的实用 NLP 系统必须能在任务特定训练数据不存在的长尾语言上工作。

多语言模型通过在多种语言上同时训练一个模型来解决这个问题。共享表示让模型能够将在高资源语言中学到的技能迁移到低资源语言上。在英语情感分析上微调模型，它对乌尔都语开箱即用地产生令人惊讶的好情感预测。这就是零样本跨语言迁移，它重塑了 NLP 向世界交付的方式。

本课指出了权衡、经典模型，以及多语言工作中新手团队最容易踩坑的一个决策：选择迁移的源语言。

## 概念

![通过共享多语言嵌入空间的跨语言迁移](../assets/multilingual.svg)

**共享词汇。** 多语言模型使用在所有目标语言文本上训练的 SentencePiece 或 WordPiece 分词器。词汇是共享的：相同的子词单元在相关语言之间表示相同的词素。英语和意大利语中的 `anti-` 得到相同的标记。

**共享表示。** 一个在多种语言上通过掩码语言建模预训练的 Transformer 学习到：不同语言中语义相似的句子产生相似的隐藏状态。mBERT、XLM-R 和 NLLB 都表现出这一点。英语中 "cat" 的嵌入聚集在法语 "chat" 和西班牙语 "gato" 的嵌入附近，完整的句子嵌入也是如此。

**零样本迁移。** 在一种语言（通常是英语）的标注数据上微调模型。在推理时，在任何模型支持的语言上运行它。不需要目标语言标签。对类型学上相近的语言结果强，对远距离的语言较弱。

**少样本微调。** 添加 100-500 个目标语言标注样本。在分类任务上准确率跃升至英语基线的 95-98%。这是多语言 NLP 中性价比最高的杠杆。

## 模型

| 模型 | 年份 | 覆盖范围 | 备注 |
|-------|------|-------|-------|
| mBERT | 2018 | 104 种语言 | 在 Wikipedia 上训练。第一个实用的多语言 LM。低资源语言上弱。 |
| XLM-R | 2019 | 100 种语言 | 在 CommonCrawl 上训练（远大于 Wikipedia）。设定跨语言基线。Base 270M，Large 550M。 |
| XLM-V | 2023 | 100 种语言 | XLM-R 配 1M 标记词汇（vs 250k）。低资源语言上更好。 |
| mT5 | 2020 | 101 种语言 | 用于多语言生成的 T5 架构。 |
| NLLB-200 | 2022 | 200 种语言 | Meta 的翻译模型；包括 55 种低资源语言。 |
| BLOOM | 2022 | 46 种语言 + 13 种编程 | 开放的 176B 多语言 LLM。 |
| Aya-23 | 2024 | 23 种语言 | Cohere 的多语言 LLM。阿拉伯语、印地语、斯瓦希里语上强。 |

按用例选择。分类任务用 XLM-R-base 作为合理默认值。生成任务根据是翻译还是开放生成选择 mT5 或 NLLB。LLM 风格工作搭配 Aya-23 或 Claude，使用显式多语言提示。

## 源语言决策（2026 年研究）

大多数团队默认用英语作为微调源。最近研究（2026）表明这常常是错误的。

语言相似度比原始语料大小更好地预测迁移质量。对斯拉夫语目标，德语或俄语通常优于英语。对印度语目标，印地语通常优于英语。**qWALS** 相似度指标（2026，基于 World Atlas of Language Structures 特征）量化了这一点。**LANGRANK**（Lin et al., ACL 2019）是一种独立且更早的方法，从语言相似度、语料大小和谱系相关性组合中对候选源语言进行排序。

实用规则：如果你的目标语言有一个类型学上相近的高资源近亲，先尝试在该近亲上微调，然后与英语微调对比。

## 构建

### 步骤 1：零样本跨语言分类

```python
from transformers import AutoTokenizer, AutoModelForSequenceClassification
import torch

tok = AutoTokenizer.from_pretrained("joeddav/xlm-roberta-large-xnli")
model = AutoModelForSequenceClassification.from_pretrained("joeddav/xlm-roberta-large-xnli")


def classify(text, candidate_labels, hypothesis_template="This text is about {}."):
    scores = {}
    for label in candidate_labels:
        hypothesis = hypothesis_template.format(label)
        inputs = tok(text, hypothesis, return_tensors="pt", truncation=True)
        with torch.no_grad():
            logits = model(**inputs).logits[0]
        entail_score = torch.softmax(logits, dim=-1)[2].item()
        scores[label] = entail_score
    return dict(sorted(scores.items(), key=lambda x: -x[1]))


print(classify("I love this product!", ["positive", "negative", "neutral"]))
print(classify("मुझे यह उत्पाद पसंद है!", ["positive", "negative", "neutral"]))
print(classify("J'adore ce produit !", ["positive", "negative", "neutral"]))
```

一个模型，三种语言，相同的 API。在 NLI 数据上训练的 XLM-R 通过蕴含技巧很好地迁移到分类任务。

### 步骤 2：多语言嵌入空间

```python
from sentence_transformers import SentenceTransformer
import numpy as np

model = SentenceTransformer("sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2")

pairs = [
    ("The cat is sleeping.", "Le chat dort."),
    ("The cat is sleeping.", "El gato está durmiendo."),
    ("The cat is sleeping.", "Die Katze schläft."),
    ("The cat is sleeping.", "The dog is barking."),
]

for eng, other in pairs:
    emb_eng = model.encode([eng], normalize_embeddings=True)[0]
    emb_other = model.encode([other], normalize_embeddings=True)[0]
    sim = float(np.dot(emb_eng, emb_other))
    print(f"  {eng!r} <-> {other!r}: cos={sim:.3f}")
```

翻译在嵌入空间中靠近。不同的英语句子更远。这就是跨语言检索、聚类和相似度工作的基础。

### 步骤 3：少样本微调策略

```python
from transformers import TrainingArguments, Trainer
from datasets import Dataset


def few_shot_finetune(base_model, base_tokenizer, examples):
    ds = Dataset.from_list(examples)

    def tokenize_fn(ex):
        out = base_tokenizer(ex["text"], truncation=True, max_length=128)
        out["labels"] = ex["label"]
        return out

    ds = ds.map(tokenize_fn)
    args = TrainingArguments(
        output_dir="out",
        per_device_train_batch_size=8,
        num_train_epochs=5,
        learning_rate=2e-5,
        save_strategy="no",
    )
    trainer = Trainer(model=base_model, args=args, train_dataset=ds)
    trainer.train()
    return base_model
```

对于 100-500 个目标语言样本，`num_train_epochs=5` 和 `learning_rate=2e-5` 是安全的默认值。更高的学习率会导致多语言对齐崩溃，变成一个仅英语的模型。

## 真正有效的评估

- **在留出集合上的每语言准确率。** 不是聚合。聚合隐藏了长尾。
- **与单语言基线的基准测试。** 对于有足够数据的语言，从头训练的单语言模型有时优于多语言模型。要测试。
- **实体级别测试。** 目标语言中的命名实体。多语言模型通常对拉丁字母以外文字的分词表现较弱。
- **跨语言一致性。** 两种语言中相同含义应产生相同的预测。衡量差距。

## 使用

2026 年技术栈：

| 任务 | 推荐 |
|-----|-------------|
| 分类，100 种语言 | XLM-R-base (~270M) 微调 |
| 零样本文本分类 | `joeddav/xlm-roberta-large-xnli` |
| 多语言句子嵌入 | `sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2` |
| 翻译，200 种语言 | `facebook/nllb-200-distilled-600M`（见第 11 课） |
| 多语言生成 | Claude、GPT-4、Aya-23、mT5-XXL |
| 低资源语言 NLP | XLM-V 或在相关高资源语言上的领域特定微调 |

如果性能很重要，始终为目标语言微调留出预算。零样本是起点，不是最终答案。

### 分词税（低资源语言出问题的地方）

多语言模型在所有语言之间共享一个分词器。该词汇表是在以英语、法语、西班牙语、中文、德语为主的语料库上训练的。对于主导语言之外的任何语言，三种税静默叠加：

- **繁衍税。** 低资源语言文本分词的标记数是英语的很多倍。一句印地语可能需要等效英语句子 3-5 倍的标记。这 3-5 倍吃掉你的上下文窗口、训练效率和延迟。
- **变体恢复税。** 每个拼写错误、变音符号变体、Unicode 归一化不匹配或大小写变化在嵌入空间中变成冷启动无关序列。模型无法学习母语者认为是常识的正字法对应关系。
- **容量溢出税。** 税 1 和税 2 消耗上下文位置、层深度和嵌入维度。留给实际推理的空间系统性地小于高资源语言从同一模型获得的。

实用症状：你的模型在印地语上正常训练，loss 曲线看起来正确，评估困惑度看起来合理，但生产输出有微妙错误。形态在句子中间崩溃。罕见屈折无法恢复。**你无法用更多数据来弥补一个破损的分词器。**

缓解措施：选择覆盖你要的目标语言的分词器（XLM-V 的 1M 标记词汇是直接修复）；在训练前在留出的目标文本上验证分词繁衍率；对真正的长尾文字使用字节级回退（SentencePiece 的 `byte_fallback=True`，GPT-2 风格的字节级 BPE），这样永远不会有 OOV。

## 交付

保存为 `outputs/skill-multilingual-picker.md`：

```markdown
---
name: multilingual-picker
description: 为多语言 NLP 任务选择源语言、目标模型和评估计划。
version: 1.0.0
phase: 5
lesson: 18
tags: [nlp, multilingual, cross-lingual]
---

给定需求（目标语言、任务类型、每种语言可用的标注数据），输出：

1. 微调的源语言。默认英语；如果目标语言有类型学上相近的高资源语言，检查 LANGRANK 或 qWALS。
2. 基础模型。XLM-R（分类）、mT5（生成）、NLLB（翻译）、Aya-23（生成式 LLM）。
3. 少样本预算。如果可用，从 100-500 个目标语言样本开始。仅当标注不可行时才零样本。
4. 评估计划。每语言准确率（非聚合）、跨语言一致性、非拉丁文字上的实体级 F1。

拒绝发布没有每语言评估的多语言模型——聚合指标隐藏长尾失败。标记分词覆盖率低的文字（阿姆哈拉语、提格里尼亚语、许多非洲语言），需要配备字节回退的模型（SentencePiece 带 byte_fallback=True，或 GPT-2 风格的字节级分词器）。
```

## 练习

1. **简单。** 在英语、法语、印地语和阿拉伯语各 10 个句子上运行零样本分类流水线。报告每种语言的准确率。你应该看到法语的强表现、印地语的体面表现、阿拉伯语的表现不一。
2. **中等。** 使用 `paraphrase-multilingual-MiniLM-L12-v2` 在小型混合语言语料库上构建跨语言检索器。英语查询，浅任何语言的文档。衡量 recall@5。
3. **困难。** 为印地语分类任务比较英语源和印地语源的微调。在两种方式下用 500 个目标语言样本进行少样本微调。报告哪种源产生更好的印地语准确率以及好多少。这就是 LANGRANK 论文的缩影。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| 多语言模型 | 一个模型，多种语言 | 跨语言的共享词汇和参数。 |
| 跨语言迁移 | 在一种语言训练，在另一种运行 | 在源语言微调，在目标语言评估，无目标语言标签。 |
| 零样本 | 无目标语言标签 | 不在目标语言上微调直接迁移。 |
| 少样本 | 少量目标标签 | 100-500 个目标语言样本用于微调。 |
| mBERT | 第一个多语言 LM | 在 Wikipedia 上预训练的 104 语言 BERT。 |
| XLM-R | 标准跨语言基线 | 在 CommonCrawl 上预训练的 100 语言 RoBERTa。 |
| NLLB | Meta 的 200 语言 MT | No Language Left Behind。包括 55 种低资源语言。 |

## 扩展阅读

- [Conneau et al. (2019). Unsupervised Cross-lingual Representation Learning at Scale](https://arxiv.org/abs/1911.02116)——XLM-R 论文。
- [Pires, Schlinger, Garrette (2019). How Multilingual is Multilingual BERT?](https://arxiv.org/abs/1906.01502)——启动跨语言迁移研究方向的分析论文。
- [Costa-jussà et al. (2022). No Language Left Behind](https://arxiv.org/abs/2207.04672)——NLLB-200 论文。
- [Üstün et al. (2024). Aya Model: An Instruction Finetuned Open-Access Multilingual Language Model](https://arxiv.org/abs/2402.07827)——Aya，Cohere 的多语言 LLM。
- [Language Similarity Predicts Cross-Lingual Transfer Learning Performance (2026)](https://www.mdpi.com/2504-4990/8/3/65)——qWALS / LANGRANK 源语言论文。