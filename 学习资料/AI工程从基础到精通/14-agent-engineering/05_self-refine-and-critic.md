# Self-Refine 与 CRITIC：迭代输出改进

> Self-Refine（Madaan 等人，2023）在循环中使用一个 LLM 扮演三个角色 —— 生成、反馈、精炼。在 7 项任务上平均提升 +20 个绝对百分点。CRITIC（Gou 等人，2023）通过将验证路由到外部工具来强化反馈步骤。2026 年，这个模式以"评估器-优化器"（Anthropic）或护栏循环（OpenAI Agents SDK）的形式出现在每个框架中。

**类型：** 构建
**语言：** Python（标准库）
**前置要求：** Phase 14 · 01（Agent 循环），Phase 14 · 03（Reflexion）
**时间：** ~60 分钟

## 学习目标

- 陈述 Self-Refine 的三个提示词（生成、反馈、精炼），并解释为什么历史对精炼提示词很重要。
- 解释 CRITIC 的关键洞察：LLM 在没有外部锚定（grounding）的情况下进行自我验证是不可靠的。
- 实现一个带有历史记录和可选外部验证器的标准库 Self-Refine 循环。
- 将此模式映射到 Anthropic 的"评估器-优化器"工作流和 OpenAI Agents SDK 的输出护栏。

## 问题

一个 Agent 产生了一个几乎正确的答案。可能一行代码有语法错误。可能摘要太长。可能计划遗漏了一个边界情况。你想要的是：Agent 批判自己的输出，然后修复它。

Self-Refine 表明这可以用一个模型完成，无需训练数据，无需强化学习。但有一个陷阱：LLM 在硬事实上的自我验证表现很差。CRITIC 指出了修复方法 —— 通过外部工具（搜索、代码解释器、计算器、测试运行器）路由验证步骤。

这两篇论文共同定义了 2026 年迭代改进的默认做法：生成、验证（尽可能外部化）、精炼，当验证器通过时停止。

## 概念

### Self-Refine（Madaan 等人，NeurIPS 2023）

一个 LLM，三个角色：

```
generate(task)            -> output_0
feedback(task, output_0)  -> critique_0
refine(task, output_0, critique_0, history) -> output_1
feedback(task, output_1)  -> critique_1
refine(task, output_1, critique_1, history) -> output_2
...
stop when feedback says "no issues" or budget exhausted.
```

关键细节：`refine` 看到完整历史 —— 所有先前的输出和批判 —— 因此不会重复错误。论文对此做了消融实验：去掉历史，质量急剧下降。

头条数字：在 7 项任务（数学、代码、缩写、对话）上平均提升 +20 个绝对百分点，包括 GPT-4。无需训练，无需外部工具，单模型。

### CRITIC（Gou 等人，arXiv:2305.11738，v4 2024年2月）

Self-Refine 的弱点：反馈步骤是一个 LLM 对自己评分。对于事实性声明，这是不可靠的（一个幻觉对于产生它的模型来说通常看起来很可信）。CRITIC 将 `feedback(task, output)` 替换为 `verify(task, output, tools)`，其中 `tools` 包括：

- 事实性声明的搜索引擎。
- 代码正确性的代码解释器。
- 算术的计算器。
- 领域特定的验证器（单元测试、类型检查器、linter）。

验证器生成一个基于工具结果的结构化批判。精炼器然后以这个批判为条件。

头条数字：CRITIC 在事实性任务上优于 Self-Refine，因为批判有锚定基础。在没有外部验证器的任务上（创意写作、格式化），CRITIC 退化为 Self-Refine。

### 停止条件

两种常见形态：

1. **验证器通过。** 外部测试返回成功。在有条件时优先（单元测试、类型检查器、护栏断言）。
2. **无反馈发出。** 模型说"输出没问题。"更便宜但不可靠；配合最大迭代次数上限。

2026 年默认做法：组合使用。"如果验证器通过 OR 模型说没问题 AND iterations >= 2 OR iterations >= max_iterations 则停止。"

### 评估器-优化器（Anthropic，2024）

Anthropic 2024 年 12 月的文章将此命名为五种工作流模式之一。两个角色：

- 评估器（Evaluator）：对输出评分并产生批判。
- 优化器（Optimizer）：根据批判修订输出。

循环直到评估器通过。这就是 Anthropic 框架下的 Self-Refine/CRITIC。Anthropic 添加的关键工程细节：评估器和优化器提示词应显著不同，这样模型不会只是例行盖章通过。

### OpenAI Agents SDK 输出护栏

OpenAI Agents SDK 将此模式作为"输出护栏"提供。护栏是一个在 Agent 产生最终输出后运行的验证器。如果护栏触发（引发 `OutputGuardrailTripwireTriggered`），输出被拒绝，Agent 可以重试。护栏可以调用工具（CRITIC 风格）或是纯函数（Self-Refine 风格）。

### 2026 陷阱

- **盖章循环（Rubber-stamp loops）。** 相同的模型使用相同的提示词风格进行生成和批判，会收敛到"看起来不错"。使用结构上不同的提示词，或使用更小更便宜的模型进行批判。
- **过度精炼。** 每次精炼都增加延迟和令牌。预算 1-3 次；超过后升级到人工审查。
- **简单任务上的 CRITIC。** 如果没有外部验证器，CRITIC 退化为 Self-Refine；不要为存根验证器付出延迟代价。

## 构建

`code/main.py` 在一个玩具任务上实现 Self-Refine 和 CRITIC：根据主题生成一个简短的项目符号列表。验证器检查格式（3 个要点，每个 60 字符以内）。CRITIC 添加一个外部"事实验证器"，惩罚已知的幻觉。

组件：

- `generate` —— 脚本化生成器。
- `feedback` —— LLM 风格的自我批判。
- `verify_external` —— CRITIC 风格的锚定验证器。
- `refine` —— 根据历史重写输出。
- 停止条件 —— 验证器通过或最多 4 次迭代。

运行：

```
python3 code/main.py
```

比较 Self-Refine 与 CRITIC 的运行结果。CRITIC 捕捉到一个 Self-Refine 遗漏的事实错误，因为外部验证器具有自我批判器所没有的锚定基础。

## 使用

Anthropic 的评估器-优化器是 Claude 友好语言中的这个模式。OpenAI Agents SDK 的输出护栏是 CRITIC 形态的（护栏可以调用工具）。LangGraph 提供的反思节点读起来像 Self-Refine。Google 的 Gemini 2.5 Computer Use 添加了一个每步骤安全评估器，这是 CRITIC 的一个变体：每个动作在提交前被验证。

## 交付物

`outputs/skill-refine-loop.md` 根据任务形态、验证器可用性和迭代预算配置一个评估器-优化器循环。生成生成器、评估器/验证器和优化器的提示词，以及停止策略。

## 练习

1. 使用 max_iterations=1 运行玩具。CRITIC 仍然有帮助吗？
2. 将外部验证器替换为有噪声的（随机 30% 误报）。循环会做什么？这是 2026 年大多数护栏技术栈的现实。
3. 实现"生成器-批判器在不同模型上"的变体：大模型生成，小模型批判。它是否胜过同一模型？
4. 阅读 CRITIC 第 3 节（arXiv:2305.11738 v4）。说出三个验证工具类别并为每个给出一个示例。
5. 将 OpenAI Agents SDK 的 `output_guardrails` 映射到 CRITIC 的验证器角色。SDK 哪些地方做错了，哪些地方做对了？

## 关键术语

| 术语 | 常见说法 | 实际含义 |
|------|----------|----------|
| Self-Refine | "能自我修复的 LLM" | 在一个模型中生成 -> 反馈 -> 精炼循环，带历史记录 |
| CRITIC | "工具锚定验证" | 用外部验证器（搜索、代码、计算、测试）替换反馈 |
| Evaluator-Optimizer（评估器-优化器） | "Anthropic 工作流模式" | 两个角色 —— 评估器评分，优化器修订 —— 循环至收敛 |
| Output guardrail（输出护栏） | "事后检查" | Agent 产生输出后运行的 OpenAI Agents SDK 验证器 |
| Verify step（验证步骤） | "批判阶段" | 承载核心作用的决策：锚定还是自评 |
| Refine history（精炼历史） | "模型已经尝试过什么" | 添加到精炼提示词之前的先前输出 + 批判；去掉历史则质量崩溃 |
| Rubber-stamp loop（盖章循环） | "自我认同失败" | 相同提示词的批判返回"看起来不错"；通过结构上不同的提示词修复 |
| Stop condition（停止条件） | "收敛测试" | 验证器通过 OR 无反馈且达到迭代上限；永远不要单一条件 |

## 扩展阅读

- [Madaan et al., Self-Refine (arXiv:2303.17651)](https://arxiv.org/abs/2303.17651) — 经典论文
- [Gou et al., CRITIC (arXiv:2305.11738)](https://arxiv.org/abs/2305.11738) — 工具锚定验证
- [Anthropic, Building Effective Agents](https://www.anthropic.com/research/building-effective-agents) — 评估器-优化器工作流模式
- [OpenAI Agents SDK docs](https://openai.github.io/openai-agents-python/) — 作为 CRITIC 形态验证器的输出护栏