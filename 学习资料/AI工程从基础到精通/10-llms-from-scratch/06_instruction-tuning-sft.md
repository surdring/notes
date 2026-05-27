# 指令微调（SFT）

> 基础模型预测下一个 token。仅此而已。它不遵循指令、回答问题或拒绝有害请求。SFT 是 token 预测器与有用助手之间的桥梁。你与之对话过的每个模型——Claude、GPT、Llama Chat——都经历了这一步。

**类型：** 构建
**语言：** Python（使用 numpy）
**前置要求：** 第 10 阶段，第 04 课（预训练迷你 GPT）
**时间：** 约 90 分钟

## 学习目标

- 实现监督微调（SFT），将基础语言模型转换为遵循指令的助手
- 使用带有 system、user 和 assistant 角色的对话模板格式化训练数据，并在非助手 token 上掩码损失
- 解释为什么 SFT 是必要的：基础模型延续文本而非回答问题
- 通过在留存指令集上比较基础模型和微调模型的响应来评估 SFT 质量

## 问题

你在第 04 课中训练了一个模型。它可以在给定序列时预测下一 token。喂给它"The transformer architecture"，它可能延续为"has revolutionized natural language processing." 对于一个下一 token 预测器来说，这令人印象深刻。

现在试试这个：喂给它 "What is the capital of France?" 基础模型不会回答"Paris"。它延续模式。它可能产生 "What is the capital of Germany? What is the capital of Spain?" 因为它从包含问题列表的文档中学到了。或者它可能产生 "is a question that many people ask"，因为那是一个合理的下一 token 延续。模型没有*回答*的概念。它只知道*延续*。

这就是 GPT-3（基础模型，2020 年 6 月发布）和 ChatGPT（指令微调，2022 年 11 月发布）之间的差距。相同的架构。相同的预训练。区别在于 20,000 到 100,000 个精心制作的（指令，响应）对，教会了模型遵循对话模式。

斯坦福 Alpaca 证明了你不需要数百万个示例。2023 年 3 月，他们仅用 GPT-3.5 生成的 52,000 个指令-响应对微调了 Llama 7B。总成本：600 美元。结果是一个能够遵循指令、回答问题和进行对话的聊天机器人。不如 ChatGPT，但对于 600 美元和几个小时的训练来说，惊人地接近。

Meta 的 Llama 2 Chat 在其初始 SFT 阶段仅使用了约 27,000 个高质量示例。关键洞察：质量比数量更重要。熟练标注者编写的 27,000 个示例胜过从互联网抓取的 100 万个噪声示例。

## 概念

### SFT 实际做了什么

监督微调继续了与预训练相同的训练循环——前向传播、计算损失、反向传播、更新权重——但在不同类型的数据上。你训练的不再是原始文本，而是结构化对话：

```json
{
  "system": "You are a helpful assistant.",
  "user": "What is the capital of France?",
  "assistant": "The capital of France is Paris."
}
```

模型已经知道巴黎是法国的首都。它在预训练期间从 Wikipedia、教科书和网页中学到了这一点。SFT 不教模型新的事实。它教模型一种新的*行为*：当你看到一个问题时，产生一个答案。当你看到一个指令时，产生一个完成。当你看到一个有害请求时，产生一个拒绝。

这样想：预训练给模型知识。SFT 给模型礼貌。

### 数据格式

三种格式主导行业。每种用不同的分隔符编码相同的信息——谁说了什么。

**Alpaca 格式**（斯坦福，2023 年 3 月）：

```json
{
  "instruction": "用三句话总结以下文章。",
  "input": "欧洲央行提高了利率……",
  "output": "欧洲央行将利率提高了 25 个基点……"
}
```

简单且广泛使用。`input` 字段是可选的——许多指令不需要额外上下文。斯坦福以 600 美元使用 GPT-3.5 生成了 52,000 个这种格式的示例。这启动了开源指令微调运动。

**ShareGPT 格式**（社区，2023 年）：

```json
{
  "conversations": [
    {"from": "system", "value": "你是一个有帮助的助手。"},
    {"from": "human", "value": "什么导致了潮汐？"},
    {"from": "gpt", "value": "潮汐是由月球的引力引起的……"},
    {"from": "human", "value": "它们多久发生一次？"},
    {"from": "gpt", "value": "大多数沿海地区每天经历两次高潮和两次低潮……"}
  ]
}
```

支持多轮对话。"from" 字段按惯例使用 "human" 和 "gpt"，无论实际模型是什么。Vicuna 是在从用户分享的 ChatGPT 记录中抓取的 70,000 个 ShareGPT 对话上训练的。

**ChatML 格式**（OpenAI，被许多开源模型使用）：

```
<|im_start|>system
你是一个有帮助的助手。<|im_end|>
<|im_start|>user
法国的首都是什么？<|im_end|>
<|im_start|>assistant
法国的首都是巴黎。<|im_end|>
```

使用特殊 token（`<|im_start|>`、`<|im_end|>`）来分隔角色。这些 token 在微调期间被加入分词器的词汇表。Qwen、Yi 和许多其他模型使用 ChatML。

所有三种格式完成相同的事情：它们告诉模型"这是指令，这是响应，学习这个模式。"

### 为什么它有效

模型已经从预训练中知道了语言。它见过数十亿个问题后跟答案、指令后跟完成、以及人与人间对话的示例。这些模式已经编码在权重中。

SFT 集中了这种潜在能力。模型不再需要从上下文中判断它应该回答问题还是延续文档，SFT 显式地在对话模式上训练。几千个示例之后，模型学会了：当你看到助手角色标记时，产生一个有帮助的响应。

这就是为什么 27,000 个示例就足够了。你不是在教模型英语。你不是在教它关于世界的事实。你是在教它一个简单的行为：响应指令。知识已经在那里了。

### 损失掩码

在 SFT 中，你只计算助手 token 上的损失。用户提示和系统消息不贡献损失——模型不需要学习*生成*用户输入。它只需要学习*响应*它们。

实现：创建一个与输入序列相同形状的掩码张量。将助手 token 位置设为 1，所有其他位置设为 0。在求和之前将损失乘以掩码。这意味着模型仍然通过前向传播"看到"整个上下文以用于注意力，但只在预测助手 token 上被训练。

### Chat Template 问题

这是大多数人感到困惑的地方。SFT 模型是在精确的 token 序列上训练的：`<|im_start|>user\nWhat is X?<|im_end|>\n<|im_start|>assistant\n`。如果你在推理时发送不同的 token 序列，模型的行为偏离训练分布并表现得不可预测。

错误地应用对话模板是模型产生该格式中从未见过 token 的胡言乱语、或以错误语言响应、或完全忽略指令的最常见原因。在将提示馈送到 SFT 模型之前，始终验证分词后的提示与训练时完全使用相同的特殊 token 和换行符。

## 构建

`code/main.py` 使用带损失掩码的 Alpaca 格式数据在玩具模型上实现了 SFT 训练循环。

## 交付

保存为 `outputs/prompt-sft-data-curator.md`。

## 练习

1. **简单。** 使用 Alpaca 格式格式化 10 个指令-响应对。微调小型 GPT 模型并验证它在 5 个留存指令上产生助手式响应。
2. **中等。** 比较在 SFT 期间使用和不使用损失掩码。不带掩码训练会产生什么行为？
3. **困难。** 创建有 5 个来自 OpenHermes 的指令-响应对的迷你 SFT 数据集，5 个你写的。训练两个模型——一个在 OpenHermes 对上，一个在你的对上。比较它们响应新指令的质量。

## 关键术语

| 术语 | 含义 |
|------|------|
| SFT | 监督微调：在指令-响应对上训练。 |
| 对话模板 | 将角色消息转换为 token 序列的规则。 |
| 损失掩码 | 仅对助手 token 计算损失；忽略用户提示。 |
| Alpaca | 斯坦福的 52K 指令数据集，通过 GPT-3.5 生成。 |
| ShareGPT | 从用户分享的 ChatGPT 记录中抓取的对话数据集。 |
| ChatML | OpenAI 的消息标记格式：`<\|im_start\|>` / `<\|im_end\|>`。 |
| 基础模型 | 预训练模型，在 SFT 或对齐之前。 |

## 扩展阅读

- [Ouyang et al. (2022). Training language models to follow instructions with human feedback](https://arxiv.org/abs/2203.02155)——InstructGPT 论文，定义了 SFT + RLHF 管道。
- [Taori et al. (2023). Stanford Alpaca: An Instruction-following LLaMA model](https://crfm.stanford.edu/2023/03/13/alpaca.html)——使用 GPT-3.5 生成的 52K 示例，成本 $600。
- [Zhou et al. (2023). LIMA: Less Is More for Alignment](https://arxiv.org/abs/2305.11206)——仅 1,000 个高质量示例就可以进行有效对齐。