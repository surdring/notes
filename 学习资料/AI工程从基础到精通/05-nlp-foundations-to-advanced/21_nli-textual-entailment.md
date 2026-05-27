# 自然语言推理——文本蕴含

> "t 蕴含 h" 意味着阅读 t 的人类会得出 h 为真的结论。NLI 是预测蕴含 / 矛盾 / 中立的任务。表面枯燥，在生产中是承重结构。

**类型：** 学习
**语言：** Python
**前置要求：** 第 5 阶段 · 05（情感分析），第 5 阶段 · 13（问答）
**时间：** 约 60 分钟

## 问题

你构建了一个摘要器。它生成了一个摘要。你怎么知道摘要不包含幻觉？

你构建了一个聊天机器人。它回答了"yes。"你怎么知道答案是否被检索到的段落支持？

你需要按主题分类 10,000 篇新闻文章。你没有训练标签。你能复用模型吗？

这三个问题都归结为自然语言推理。NLI 询问：给定前提 `t` 和假设 `h`，`h` 是被 `t` 蕴含，矛盾，还是中立（无关）？

- **幻觉检查：** `t` = 源文档，`h` = 摘要论断。非蕴含 = 幻觉。
- **接地问答：** `t` = 检索检索到的段落，`h` = 生成的答案。非蕴含 = 编造。
- **零样本分类：** `t` = 文档，`h` = 口语化标签（"This is about sports"）。蕴含 = 预测标签。

一个任务，三种生产用途。这就是为什么每个 RAG 评估框架底层都搭载一个 NLI 模型。

## 概念

![NLI：三分类，前提 vs 假设](../assets/nli.svg)

**三种标签。**

- **蕴含。** `t` → `h`。"The cat is on the mat" 蕴含 "There is a cat."
- **矛盾。** `t` → ¬`h`。"The cat is on the mat" 矛盾 "There is no cat."
- **中立。** 任一方向均无推理。"The cat is on the mat" 对于 "The cat is hungry" 是中立的。

**不是逻辑蕴含。** NLI 是*自然*语言推理——典型人类读者会得出的推论，不是严格逻辑。"John walked his dog" 在 NLI 中蕴含 "John has a dog"，但严格一阶逻辑只有在公理化所有权时才承认它。

**数据集。**

- **SNLI** (2015)。57 万人工标注对，以图像说明为前提。领域窄。
- **MultiNLI** (2017)。43.3 万对，跨 10 个体裁。2026 年标准训练语料库。
- **ANLI** (2019)。对抗 NLI。人类专门写了旨在打破现有模型的样本。更难。
- **DocNLI, ConTRoL** (2020-21)。文档长度前提。测试多跳和长程推理。

**架构。** Transformer 编码器（BERT、RoBERTa、DeBERTa）读取 `[CLS] premise [SEP] hypothesis [SEP]`。`[CLS]` 表示馈入 3 路 softmax。在 MNLI 上训练，在留出基准上评估，在分布内对上达到 90%+ 准确率。

**通过 NLI 进行零样本分类。** 给定文档和候选标签，将每个标签转换为假设（"This text is about sports"）。为每个计算蕴含概率。选择最大者。这就是 HuggingFace `zero-shot-classification` pipeline 背后的机制。

## 构建

### 步骤 1：运行预训练 NLI 模型

```python
from transformers import pipeline

nli = pipeline("text-classification",
               model="facebook/bart-large-mnli",
               top_k=None)

premise = "The cat is sleeping on the couch."
hypothesis = "There is a cat in the room."

result = nli({"text": premise, "text_pair": hypothesis})[0]
print(result)
# [{'label': 'entailment', 'score': 0.97},
#  {'label': 'neutral', 'score': 0.02},
#  {'label': 'contradiction', 'score': 0.01}]
```

对于生产 NLI，`facebook/bart-large-mnli` 和 `microsoft/deberta-v3-large-mnli` 是默认开源选择。DeBERTa-v3 在排行榜上领先。

### 步骤 2：零样本分类

```python
zs = pipeline("zero-shot-classification", model="facebook/bart-large-mnli")

text = "The stock market rallied after the central bank cut interest rates."
labels = ["finance", "sports", "politics", "technology"]

result = zs(text, candidate_labels=labels)
print(result)
# {'labels': ['finance', 'politics', 'technology', 'sports'],
#  'scores': [0.92, 0.05, 0.02, 0.01]}
```

默认模板是 "This example is about {label}。"用 `hypothesis_template` 自定义。无需训练数据。无需微调。开箱即用。

### 步骤 3：RAG 的真实性检查

```python
def is_faithful(answer, context, threshold=0.5):
    result = nli({"text": context, "text_pair": answer})[0]
    entail = next(s for s in result if s["label"] == "entailment")
    return entail["score"] > threshold
```

这是 RAGAS 真实性的核心。将生成的答案拆分为原子论断。对检索上下文检查每个论断。报告蕴含的比例。

### 步骤 4：手写 NLI 分类器（概念）

见 `code/main.py` 的仅标准库玩具实现：前提和假设通过词重叠 + 否定检测进行对比。无法与 Transformer 模型竞争——但它展示了任务的形状：两个文本输入，3 路标签输出，loss = `{蕴含, 矛盾, 中立}` 上的交叉熵。

## 陷阱

- **仅假设捷径。** 模型仅凭假设在 SNLI 上就能达到约 60% 的预测准确率，因为 "not"、"nobody"、"never" 与矛盾相关。检测标签泄漏的强基线。
- **词重叠启发式。** 子序列启发式（"每个子序列都被蕴含"）通过 SNLI 但在 HANS/ANLI 上失败。使用对抗基准。
- **文档长度降级。** 单句 NLI 模型在文档长度前提上下降 20+ F1。对长上下文使用 DocNLI 训练的模型。
- **零样本模板敏感性。** "This example is about {label}" vs "{label}" vs "The topic is {label}" 可以使准确率波动 10+ 点。调优模板。
- **领域不匹配。** MNLI 在通用英语上训练。法律、医疗和科学文本需要领域特定 NLI 模型（如 SciNLI、MedNLI）。

## 使用

2026 年技术栈：

| 用例 | 模型 |
|---------|-------|
| 通用 NLI | `microsoft/deberta-v3-large-mnli` |
| 快速 / 边缘 | `cross-encoder/nli-deberta-v3-base` |
| 零样本分类（轻量） | `facebook/bart-large-mnli` |
| 文档级 NLI | `MoritzLaurer/DeBERTa-v3-large-mnli-fever-anli-ling-wanli` |
| 多语言 | `MoritzLaurer/multilingual-MiniLMv2-L6-mnli-xnli` |
| RAG 幻觉检测 | RAGAS / DeepEval 中的 NLI 层 |

2026 年元模式：NLI 是文本理解的万能胶。每当你需要" A 支持 B 吗？"或" A 矛盾 B 吗？"——在另一次 LLM 调用之前先求助于 NLI。

## 交付

保存为 `outputs/skill-nli-picker.md`：

```markdown
---
name: nli-picker
description: 为分类 / 真实性 / 零样本任务选择 NLI 模型、标签模板和评估设置。
version: 1.0.0
phase: 5
lesson: 21
tags: [nlp, nli, zero-shot]
---

给定用例（真实性检查、零样本分类、文档级推理），输出：

1. 模型。命名的 NLI 检查点。原因与领域、长度、语言相关。
2. 模板（如果是零样本）。口语化模式。示例。
3. 阈值。决策规则的蕴含截止值。基于校准的原因。
4. 评估。留出标注集上的准确率、仅假设基线、对抗子集。

拒绝在没有 100 样本标注健全性检查的情况下发布零样本分类。拒绝在文档长度前提上使用句子级 NLI 模型。标记任何声称 NLI 解决幻觉的说法——它减少幻觉；不消除幻觉。
```

## 练习

1. **简单。** 在 20 个手工构造的 (前提, 假设, 标签) 三元组上运行 `facebook/bart-large-mnli`，覆盖所有三类。衡量准确率。添加对抗"子序列启发式"陷阱（"I did not eat the cake" vs "I ate the cake"）看是否被破坏。
2. **中等。** 在 100 个 AG News 标题上比较零样本模板 `"This text is about {label}"` vs `"The topic is {label}"` vs `"{label}"`。报告准确率波动。
3. **困难。** 构建 RAG 真实性检查器：原子论断分解 + 每论断 NLI。在 50 个带黄金上下文的 RAG 生成答案上评估。衡量 vs 人工标签的假阳性率和假阴性率。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| NLI | 自然语言推理 | 前提-假设关系的 3 分类。 |
| RTE | 识别文本蕴含 | NLI 的更早名称；相同任务。 |
| 蕴含 | "t 蕴含 h" | 典型读者在给定 t 时会得出 h 为真的结论。 |
| 矛盾 | "t 排除 h" | 典型读者在给定 t 时会得出 h 为假的结论。 |
| 中立 | "未决定" | 从 t 到 h 任一方向均无推理。 |
| 零样本分类 | 作为分类器的 NLI | 将标签口语化为假设，选择最大蕴含。 |
| 真实性 | 答案是否被支持？ | (检索上下文, 生成答案) 上的 NLI。 |

## 扩展阅读

- [Bowman et al. (2015). A large annotated corpus for learning natural language inference](https://arxiv.org/abs/1508.05326)——SNLI。
- [Williams, Nangia, Bowman (2017). A Broad-Coverage Challenge Corpus for Sentence Understanding through Inference](https://arxiv.org/abs/1704.05426)——MultiNLI。
- [Nie et al. (2019). Adversarial NLI](https://arxiv.org/abs/1910.14599)——ANLI 基准。
- [Yin, Hay, Roth (2019). Benchmarking Zero-shot Text Classification](https://arxiv.org/abs/1909.00161)——NLI 作为分类器。
- [He et al. (2021). DeBERTa: Decoding-enhanced BERT with Disentangled Attention](https://arxiv.org/abs/2006.03654)——2026 年的 NLI 主力。