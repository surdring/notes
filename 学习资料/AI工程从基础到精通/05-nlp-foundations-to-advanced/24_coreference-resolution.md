# 共指消解

> "She called him. He did not answer. The doctor was at lunch." 三个指称指向两个人，谁也没有被点名。共指消解弄明白谁是谁。

**类型：** 学习
**语言：** Python
**前置要求：** 第 5 阶段 · 06（NER），第 5 阶段 · 07（词性标注与句法分析）
**时间：** 约 60 分钟

## 问题

从一篇 300 词的文章中提取对 Apple Inc. 的每一次提及。当文章说"Apple"时容易。当它说"the company"、"they"、"Cupertino's technology giant"或"Jobs's firm"时就很难。如果不将这些提及解析为同一实体，你的 NER pipeline 会遗漏 60-80% 的提及。

共指消解将所有指称同一现实世界实体的表达链接到一个聚类中。它是表面 NLP（NER、解析）和下游语义（信息抽取、问答、摘要、知识图谱）之间的粘合剂。

为什么在 2026 年重要：

- 摘要："The CEO announced..." vs "Tim Cook announced..."——摘要应该明确指出 CEO 的名字。
- 问答："Who did she call?" 需要解析 "she"。
- 信息抽取：知识图谱中将 "PER1 founded Apple" 和 "Jobs founded Apple" 作为独立条目的是错误的。
- 多文档信息抽取：合并跨文章的关于同一事件的提及是跨文档共指。

## 概念

![共指聚类：提及 → 实体](../assets/coref.svg)

**任务。** 输入：一篇文档。输出：提及（span）的聚类，每个聚类指称一个实体。

**提及类型。**

- **命名实体。** "Tim Cook"
- **名词短语。** "the CEO", "the company"
- **代词。** "he", "she", "they", "it"
- **同位语。** "Tim Cook, Apple's CEO,"

**架构。**

1. **基于规则（Hobbs, 1978）。** 使用句法树规则进行代词消解。好的基线。在代词上令人惊讶地难以击败。
2. **提及对分类器。** 对每对提及 (m_i, m_j)，预测它们是否共指。通过传递闭包聚类。2016 年前的标准。
3. **提及排序。** 对每个提及，对候选先行词（包括"无先行词"）进行排序。选择最顶部的。
4. **基于 Span 的端到端（Lee et al., 2017）。** Transformer 编码器。枚举所有达到长度上限的候选 span。预测提及分数。对每个 span 预测先行词概率。贪心聚类。现代默认方法。
5. **生成式（2024+）。** 向 LLM 提示："List every pronoun in this text and its antecedent。"在简单情况下表现良好，在长文档和罕见指称上挣扎。

**评估指标。** 五种标准指标（MUC、B³、CEAF、BLANC、LEA），因为没有任何单一指标能捕捉聚类质量。报告前三者的平均值作为 CoNLL F1。2026 年 CoNLL-2012 上的最先进水平：约 83 F1。

**已知难点。**

- 定指描述指向前几页引入的实体。
- 桥接指代（"the wheels" → 之前提到的汽车）。
- 中文和日语等语言中的零指代。
- 预指（代词在指称之前）："When **she** walked in, Mary smiled."

## 构建

### 步骤 1：预训练神经共指模型（AllenNLP / spaCy-experimental）

```python
import spacy
nlp = spacy.load("en_coreference_web_trf")   # 实验性模型
doc = nlp("Apple announced new products. The company said they would ship soon.")
for cluster in doc._.coref_clusters:
    print(cluster, "->", [m.text for m in cluster])
```

在较长文档上，你会得到类似：
- 聚类 1：[Apple, The company, they]
- 聚类 2：[new products]

### 步骤 2：基于规则的代词消解器（教学）

见 `code/main.py` 的仅标准库实现：

1. 提取提及：命名实体（大写 span）、代词（字典查找）、定指描述（"the X"）。
2. 对每个代词，查看前 K 个提及并按以下方式评分：
   - 性别/数量一致（启发式）
   - 新近性（越近越好）
   - 句法角色（主语优先）
3. 链接最高评分的先行词。

无法与神经模型竞争。但它展示了搜索空间和端到端模型必须做出的决策。

### 步骤 3：使用 LLM 进行共指消解

```python
prompt = f"""Text: {text}

List every pronoun and noun phrase that refers to a person or company.
Cluster them by what they refer to. Output JSON:
[{{"entity": "Apple", "mentions": ["Apple", "the company", "it"]}}, ...]
"""
```

两个需要注意的失败模式。第一，LLM 过度合并（"him" 和 "her" 指称两个不同的人）。第二，LLM 在长文档中静默丢弃提及。始终通过 span 偏移检查来验证。

### 步骤 4：评估

标准的 conll-2012 脚本计算 MUC、B³、CEAF-φ4 并报告平均值。对于内部评估，从标注测试集上的 span 级精确率和召回率开始，然后添加提及链接 F1。

## 陷阱

- **单元素爆炸。** 某些系统将每个提及报告为独立的聚类。B³ 是宽容的。MUC 惩罚这一点。始终检查所有三个指标。
- **长上下文中的代词。** 性能在超过 2,000 标记的文档上下降约 15 F1。谨慎分块。
- **性别假设。** 硬编码的性别规则在非二元指称、组织、动物上失败。使用学习到的模型或中性评分。
- **LLM 在长文档上漂移。** 单次 API 调用无法可靠地在 50+ 段落中聚类提及。使用滑动窗口 + 合并。

## 使用

2026 年技术栈：

| 场景 | 选择 |
|-----------|------|
| 英语，单文档 | `en_coreference_web_trf`（spaCy-experimental）或 AllenNLP 神经共指 |
| 多语言 | 在 OntoNotes 或 Multilingual CoNLL 上训练的 SpanBERT / XLM-R |
| 跨文档事件共指 | 专门的端到端模型（2025-26 最先进） |
| 快速 LLM 基线 | GPT-4o / Claude 带结构化输出共指提示 |
| 生产对话系统 | 基于规则的后备 + 神经主力 + 关键槽位的人工审核 |

2026 年部署的集成模式：先运行 NER，运行共指，将共指聚类合并到 NER 实体中。下游任务看到每个聚类一个实体，而非每个提及一个实体。

## 交付

保存为 `outputs/skill-coref-picker.md`：

```markdown
---
name: coref-picker
description: 选择共指消解方法、评估计划和集成策略。
version: 1.0.0
phase: 5
lesson: 24
tags: [nlp, coref, information-extraction]
---

给定用例（单文档 / 多文档、领域、语言），输出：

1. 方法。基于规则 / 神经基于 span / LLM 提示 / 混合。一句话原因。
2. 模型。如果是神经方法，命名的检查点。
3. 集成。操作顺序：分词 → NER → 共指 → 下游任务。
4. 评估。留出集合上的 CoNLL F1（MUC + B³ + CEAF-φ4 平均）+ 20 个文档上的人工聚类审核。

拒绝对超过 2,000 标记的文档使用纯 LLM 共指，除非使用滑动窗口合并。拒绝任何在没有提及级精确率-召回率报告的情况下运行共指的 pipeline。标记在人口多样性文本中部署性别启发式系统。
```

## 练习

1. **简单。** 在 5 个手工构造的段落上运行 `code/main.py` 中基于规则的消解器。对照 ground truth 衡量提及链接准确率。
2. **中等。** 在一篇新闻文章上使用预训练神经共指模型。将聚类与你自己的手工标注对比。它在哪些地方失败了？
3. **困难。** 构建共指增强的 NER pipeline：先 NER，然后通过共指聚类合并。在 100 篇文章上衡量相对仅 NER 的实体覆盖改进。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| 提及 | 一个指称 | 指称一个实体的文本片段（名称、代词、名词短语）。 |
| 先行词 | "it" 指称的东西 | 后一个提及与之共指的先前提及。 |
| 聚类 | 实体的提及 | 全部指称同一现实世界实体的提及集合。 |
| 回指 | 向后引用 | 后一个提及指向前一个（"he" → "John"）。 |
| 预指 | 向前引用 | 前一个提及指向后一个（"When he arrived, John..."）。 |
| 桥接 | 隐式引用 | "I bought a car. The wheels were bad."（那辆车的 wheels。） |
| CoNLL F1 | 排行榜上的数字 | MUC、B³、CEAF-φ4 F1 分数的平均值。 |

## 扩展阅读

- [Jurafsky & Martin, SLP3 第 26 章 — Coreference Resolution and Entity Linking](https://web.stanford.edu/~jurafsky/slp3/26.pdf)——经典教材章节。
- [Lee et al. (2017). End-to-end Neural Coreference Resolution](https://arxiv.org/abs/1707.07045)——基于 span 的端到端。
- [Joshi et al. (2020). SpanBERT](https://arxiv.org/abs/1907.10529)——改善共指消解的预训练。
- [Pradhan et al. (2012). CoNLL-2012 Shared Task](https://aclanthology.org/W12-4501/)——基准。
- [Hobbs (1978). Resolving Pronoun References](https://www.sciencedirect.com/science/article/pii/0024384178900064)——基于规则的经典。