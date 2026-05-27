# 交接与例程——无状态编排

> OpenAI 的 Swarm（2024 年 10 月）将多 Agent 编排提炼为两个原语：**例程（Routine）**（指令 + 工具作为系统提示）和**交接（Handoff）**（一个返回另一个 Agent 的工具）。没有状态机，没有分支 DSL——LLM 通过调用正确的交接工具来路由。OpenAI Agents SDK（2025 年 3 月）是生产级继任者。Swarm 本身仍然是最清晰的概念参考——其全部源代码只有几百行。该模式具有病毒式传播性，因为 API 表面大致是「agent = prompt + tools；handoff = 返回 agent 的函数」。局限性：无状态，所以记忆是调用者的问题。

**类型：** 学习 + 构建
**语言：** Python（标准库）
**前置知识：** 第 16 阶段 · 04（原语模型）
**时间：** 约 60 分钟

## 问题

每个多代理框架都想让你学习它的 DSL：LangGraph 的节点和边，CrewAI 的 crews 和 tasks，AutoGen 的 GroupChat 和 managers。这些 DSL 是真正的抽象，但它们让事情感觉比需要的更重。

Swarm 推向相反的方向：使用模型已有的工具调用能力。交接变成工具调用。编排者是当前持有对话的代理。状态机隐含在代理的系统提示中。

## 概念

### 两个原语

**例程（Routine）。** 一个定义代理角色和可用工具的系统提示。把它想象成一组有范围的指令：「你是一个分流代理；如果用户询问退款，交接给退款代理。」

**交接（Handoff）。** 代理可以调用的一个工具，它返回一个新的 Agent 对象。Swarm 运行时检测到 Agent 返回值并切换下一轮的活跃代理。

这就是整个抽象。

```
def transfer_to_refunds():
    return refund_agent  # Swarm 看到 Agent 返回 → 切换活跃代理

triage_agent = Agent(
    name="triage",
    instructions="将用户路由到正确的专员。",
    functions=[transfer_to_refunds, transfer_to_sales, transfer_to_support],
)
```

分流代理的系统提示使其根据用户消息选择正确的交接。LLM 的工具调用完成路由。

### 为什么它具有病毒式传播性

- **小 API。** 学习两个概念。
- **使用模型已有的能力。** 工具调用已经是各提供商的成熟生产级能力。
- **没有状态机负担。** 你不描述图；代理的提示描述了它们交接给谁。

### 无状态权衡

Swarm 在运行之间显式无状态。框架在运行期间保持消息历史，但不持久化任何内容。记忆、连续性、长时间运行的任务——都是调用者的问题。

在生产中（OpenAI Agents SDK，2025 年 3 月），这是主要改变的事情之一：SDK 添加了内置的会话管理、护栏和追踪，同时保留了交接原语。

### 什么时候 Swarm/交接合适

- **分流模式。** 前线代理将用户路由到专员。
- **基于技能的交接。** 「如果任务需要代码，调用程序员；如果它需要研究，调用研究员。」
- **简短、有边界的对话。** 客户支持、FAQ 到工单、简单工作流。

### 什么时候 Swarm 挣扎

- **带共享记忆的长会话。** 交接将会话状态重置为新代理的提示加上历史。没有调用者管理的记忆就没有跨代理的持久状态。
- **并行执行。** 交接是一次一个——活跃代理切换。并行性需要调用者协调多个 Swarm 运行。
- **审计与重放。** 无状态运行难以精确重放；LLM 的交接选择不是确定性的。

### OpenAI Agents SDK（2025 年 3 月）

生产级继任者添加了：

- **会话状态。** 跨运行的持久线程。
- **护栏（Guardrails）。** 输入/输出验证钩子。
- **追踪（Tracing）。** 每次工具调用和交接都被记录。
- **交接过滤器（Handoff Filter）。** 控制交接时什么上下文被传递。

交接原语存续；生产人体工程学被添加到其周围。

### Swarm vs GroupChat

两者都使用 LLM 驱动的路由，但它们在**谁选择下一个**上不同：

- GroupChat：一个选择器（函数或 LLM）从外部选择下一个发言者。
- Swarm：当前代理通过调用交接工具选择其继任者。

Swarm 是「代理决定接下来是什么」；GroupChat 是「管理者决定接下来是什么」。Swarm 的决策存在于活跃代理的工具调用中；GroupChat 的存在于 `GroupChatManager` 中。

## 构建

`code/main.py` 从零实现 Swarm：一个 Agent 数据类，一个交接机制（工具返回 Agent），以及一个检测代理切换的运行循环。

演示：一个分流代理路由到退款、销售或支持专员。每个专员有自己的工具。运行循环打印每次交接。

运行：

```
python3 code/main.py
```

## 实践

`outputs/skill-handoff-designer.md` 为给定任务设计交接拓扑：存在哪些代理，它们可以调用哪些交接，什么上下文被传递。

## 交付

检查清单：

- **交接日志。** 每次交接写入一个带有来源代理、目标代理、上下文快照的追踪事件。
- **上下文传递规则。** 决定交接时什么移动：全量历史（昂贵）、最近 N 条消息或摘要。
- **交接护栏。** 交接给具有不同工具权限的专员必须经过认证——否则提示注入可以强制不必要的交接。
- **循环检测。** 两个代理来回交接是常见失败；用简单的最近 K 环检查来检测。
- **回退代理。** 如果交接目标不存在，回退到安全默认。

## 练习

1. 运行 `code/main.py`，分流到退款代理。确认第二轮的活动代理是退款代理。
2. 添加循环检测规则：如果同两个代理连续交接了 3 次，强制退出。设计回退方案。
3. 阅读 OpenAI Agents SDK 文档中的交接过滤器。实现「交接时摘要」版本：发出代理在接收代理接手前将上下文压缩为要点摘要。
4. 比较 Swarm 交接与 GroupChatManager 选择器。哪种模式使提示注入更严重，为什么？
5. 阅读 Swarm cookbook（https://developers.openai.com/cookbook/examples/orchestrating_agents）。识别 OpenAI Agents SDK 更改或保留的 Swarm 的一个显式设计决策。

## 关键术语

| 术语 | 人们说的 | 实际含义 |
|------|---------|---------|
| Routine | 「代理提示」 | 系统提示 + 工具列表。定义角色和可用交接。 |
| Handoff | 「转移到另一个代理」 | 活跃代理可以调用的一个返回新 Agent 的工具。运行时切换活跃代理。 |
| Stateless | 「运行之间无记忆」 | Swarm 不持久化任何内容；记忆是调用者的责任。 |
| Active agent | 「当前谁在发言」 | 当前持有对话的代理。交接改变它。 |
| Context transfer | 「交接时移动什么」 | 接收代理看到什么历史的策略：完整、最近 N 条或摘要。 |
| Handoff loop | 「代理乒乓」 | 失败模式，两个代理不断互相交接。 |
| OpenAI Agents SDK | 「生产级 Swarm」 | 2025 年 3 月继任者；在交接原语之上添加会话、护栏、追踪。 |
| Handoff filter | 「交接门控」 | SDK 特性，在交接边界检查和修改上下文。 |

## 扩展阅读

- [OpenAI cookbook — 编排 Agents：例程与交接](https://developers.openai.com/cookbook/examples/orchestrating_agents) — 参考阐述
- [OpenAI Swarm 仓库](https://github.com/openai/swarm) — 原始实现，保留为概念参考
- [OpenAI Agents SDK 文档](https://openai.github.io/openai-agents-python/) — 带有会话和追踪的生产级继任者
- [Anthropic Claude 交接笔记](https://docs.anthropic.com/en/docs/claude-code) — Claude Code 子代理如何通过 `Task` 使用类交接模式