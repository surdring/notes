# Reflexion：语言强化学习

> 基于梯度的强化学习需要数千次试验和一个 GPU 集群来修复一种故障模式。Reflexion（Shinn 等人，NeurIPS 2023）用自然语言完成：每次失败试验后，Agent 写下一段反思，将其存储在情景记忆中，并在下一次试验中以该记忆为条件。这是 Letta 的休眠计算、Claude Code 的 CLAUDE.md 学习以及 pro-workflow 的 learn-rule 背后的模式。

**类型：** 构建
**语言：** Python（标准库）
**前置要求：** Phase 14 · 01（Agent 循环），Phase 14 · 02（ReWOO）
**时间：** ~60 分钟

## 学习目标

- 说出 Reflexion 的三个组件（Actor、Evaluator、Self-Reflector）以及情景记忆的作用。
- 实现一个带有二元评估器、反思缓冲区和全新重试的标准库 Reflexion 循环。
- 在标量、启发式和自我评估的反馈来源之间为给定任务做出选择。
- 解释为什么语言强化能捕捉到基于梯度的强化学习需要数千次试验才能修复的错误。

## 问题

一个 Agent 在任务上失败了。在标准强化学习中，你会运行数千次额外的试验，计算梯度，更新权重。昂贵、缓慢，而且大多数生产级 Agent 没有为每次失败提供训练预算。

Reflexion（Shinn 等人，arXiv:2303.11366）提出了一个不同的问题：如果 Agent 只是思考它为什么失败，并在提示词中带着那个思考再试一次呢？没有权重更新。没有梯度。只是在试验之间存储自然语言。

结果：在 ALFWorld 上它击败了 ReAct 和其他未微调的基线。在 HotpotQA 上它比 ReAct 有所改进。在代码生成（HumanEval/MBPP）上它当时达到了最先进水平。所有这些都没有一次梯度步骤。

## 概念

### 三个组件

```
Actor（执行者）         ：生成轨迹（ReAct 风格的循环）
Evaluator（评估器）     ：对轨迹评分 —— 二元、启发式或自我评估
Self-Reflector（自我反思器）：写下关于失败的自然语言反思
```

外加一个数据结构：

```
Episodic memory（情景记忆）：先前反思的列表，添加到下一次试验的提示词之前
```

一次试验运行执行者。评估器对其评分。如果分数较低，自我反思器生成一段反思（"我选错了工具，因为我误以为问题问的是 X，而其实问的是 Y"）。反思进入情景记忆。下一次试验从零开始，但能看到反思。

### 三种评估器类型

1. **标量（Scalar）** —— 外部二元信号。ALFWorld 成功或失败。HumanEval 测试通过或失败。最简单，信号最高。
2. **启发式（Heuristic）** —— 预定义的失败签名。"如果 Agent 连续两次产生相同的动作，标记为卡住。""如果轨迹超过 50 步，标记为低效。"
3. **自我评估（Self-evaluated）** —— LLM 对自己的轨迹评分。在没有真实标签时使用。信号较弱；适合与工具锚定验证配合使用（第 05 课 —— CRITIC）。

2026 年的默认做法是混合使用：有标量时用标量，没有时用自我评估，启发式作为安全护栏。

### 为什么这能泛化

Reflexion 与其说是一种新算法，不如说是一个命名模式。几乎每个生产级"自愈"Agent 都运行某种变体：

- Letta 的休眠计算（第 08 课）：一个独立的 Agent 反思过去的对话并写入记忆块。
- Claude Code 的 `CLAUDE.md` / "保存记忆"模式：反思被捕获为学习内容，添加到未来会话之前。
- pro-workflow 的 `/learn-rule` 命令：修正被捕获为显式规则。
- LangGraph 的反思节点：一个节点评分输出并路由到 refine（如果需要）。

所有这些都源于同一个洞察：自然语言是一个足够丰富的媒介，可以在运行之间传递"我从失败中学到了什么"。

### 何时有效，何时无效

Reflexion 在以下情况有效：

- 存在明确的失败信号（测试失败、工具错误、错误答案）。
- 任务类别可重复（相同类型的问题可以再次提出）。
- 反思有空间改进轨迹（足够的行动预算）。

Reflexion 在以下情况无效：

- Agent 第一次尝试就成功了。
- 失败是外部性的（网络断连、工具损坏）—— 对"网络断连了"的反思对未来的运行没有帮助。
- 反思变成迷信 —— 存储关于一次性不稳定运行的叙述。

2026 年陷阱：记忆腐烂。反思不断累积；有些已过时或错误；随着情景缓冲区增长，重新运行变得更慢。缓解措施：定期压缩（第 06 课）、反思的 TTL，或独立的休眠清理 Agent（Letta）。

## 构建

`code/main.py` 在一个玩具谜题上实现 Reflexion：生成一个求和为目标值的 3 元素列表。执行者发出候选列表；评估器检查求和；自我反思器写下一行关于错误原因的内容。反思进入情景记忆以供下一次试验使用。

组件：

- `Actor` —— 一个脚本化策略，在看到反思时改进。
- `Evaluator.binary()` —— 通过/失败，基于目标和。
- `SelfReflector` —— 生成关于失败的一行诊断。
- `EpisodicMemory` —— 具有 TTL 语义的有界列表。

运行：

```
python3 code/main.py
```

轨迹显示三次试验。试验 1 失败，存储反思，试验 2 看到反思并改进但仍然失败，试验 3 成功。与无反思的基线运行对比 —— 它卡在试验 1 的答案上。

## 使用

LangGraph 将反思作为节点模式发布。Claude Code 的 `/memory` 命令和 pro-workflow 的 `/learn-rule` 将情景缓冲区外部化为 markdown 文件。Letta 的休眠计算在空闲时运行自我反思器，使主要 Agent 保持低延迟。OpenAI Agents SDK 不直接提供 Reflexion；你通过一个按分数拒绝轨迹的自定义 Guardrail 和一个跨运行存活的 memory `Session` 来构建它。

## 交付物

`outputs/skill-reflexion-buffer.md` 创建并维护一个带有反思捕获、TTL 和去重的情景缓冲区。给定一个任务类别和一次失败，它发出一段真正有助于下一次试验的反思（而非泛泛的"要更小心"）。

## 练习

1. 从二元切换到返回距离度量的标量评估器（距离目标有多远）。收敛更快吗？
2. 为反思添加 10 次试验的 TTL。在此之后，较旧的反思是帮助还是妨碍？
3. 实现启发式评估器：如果相同动作重复，将试验标记为卡住。这与自我反思器如何交互？
4. 使用忽略反思的对抗性执行者运行 Reflexion。强制执行者注意到反思的最小反思提示词工程是什么？
5. 阅读 Reflexion 论文第 4 节关于 AlfWorld 的内容。概念上重现 130% 成功率改进：与普通 ReAct 相比的关键差异是什么？

## 关键术语

| 术语 | 常见说法 | 实际含义 |
|------|----------|----------|
| Reflexion | "自我修正" | Shinn 等人 2023 —— 执行者、评估器、自我反思器加情景记忆 |
| Verbal reinforcement（语言强化） | "无梯度的学习" | 添加到下一次试验提示词之前的自然语言反思 |
| Episodic memory（情景记忆） | "每个任务的反思" | 一个任务类别的先前反思的有界缓冲区 |
| Scalar evaluator（标量评估器） | "二元成功信号" | 来自真实标签的通过/失败或数值分数 |
| Heuristic evaluator（启发式评估器） | "基于模式的检测器" | 预定义的故障签名（如卡住循环、步数过多） |
| Self-evaluator（自我评估器） | "对自己的轨迹进行 LLM 评估" | 在没有真实标签时的低信号回退 —— 与工具锚定验证配合使用 |
| Memory rot（记忆腐烂） | "过时的反思" | 情景缓冲区填满过时条目；通过压缩/TTL 修复 |
| Sleep-time reflection（休眠反思） | "异步自我反思" | 将自我反思器从热路径上移开，使主要 Agent 保持快速 |

## 扩展阅读

- [Shinn et al., Reflexion: Language Agents with Verbal Reinforcement Learning (arXiv:2303.11366)](https://arxiv.org/abs/2303.11366) — 经典论文
- [Letta, Sleep-time Compute](https://www.letta.com/blog/sleep-time-compute) — 生产中的异步反思
- [Anthropic, Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) — 将情景缓冲区作为上下文的一部分管理
- [LangGraph overview](https://docs.langchain.com/oss/python/langgraph/overview) — 反思节点模式