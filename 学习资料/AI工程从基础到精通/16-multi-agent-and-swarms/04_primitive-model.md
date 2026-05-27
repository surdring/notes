# 多 Agent 原语模型

> 2026 年发布的每个多代理框架——AutoGen、LangGraph、CrewAI、OpenAI Agents SDK、Microsoft Agent Framework——都是四维设计空间中的一个点。四个原语（Primitive），仅此而已：代理、交接（Handoff）、共享状态、编排者（Orchestrator）。本课从零构建它们，在所有四个上运行一个玩具系统，然后将每个主要框架映射到相同的轴，这样你可以用一段话解读任何新版本。

**类型：** 学习
**语言：** Python（标准库）
**前置知识：** 第 14 阶段（Agent 工程）、第 16 阶段 · 01（为什么需要多 Agent）
**时间：** 约 60 分钟

## 问题

每六个月就有一个新的多代理框架发布。2023 年 AutoGen。2024 年 CrewAI。2024 年 LangGraph 和 OpenAI Swarm。2025 年 4 月 Google ADK。2026 年 2 月 Microsoft Agent Framework RC。每个新闻稿都声称是「正确的抽象」。

如果你试图一个一个地学习它们，你会筋疲力尽。API 看起来不同。文档对于「代理」的定义各执一词。一个框架称其共享内存为「黑板（Blackboard）」，另一个称为「消息池（Message Pool）」，第三个称为「StateGraph」。你开始怀疑这个领域只是在搅动。

其实不是。在营销之下，四个原语是稳定的。学习它们一次，用一段话解读每个新框架。

## 概念

### 四个原语

1. **代理（Agent）**——一个系统提示加工具列表。无状态；每次运行从其系统提示和当前消息历史开始。
2. **交接（Handoff）**——从一个代理到另一个代理的结构化控制转移。机械上，是一个返回新代理的工具调用，或是一个跟随条件的图边（Graph Edge）。
3. **共享状态（Shared State）**——多个代理可以读取（有时写入）的任何数据结构。消息池、黑板、键值存储、向量记忆。
4. **编排者（Orchestrator）**——决定谁下一个发言的任何组件。选项：显式图（确定性）、LLM 发言人选择器（软选择）、最后一个发言人的交接调用（OpenAI Swarm），或针对队列的调度器（集群架构）。

这就是整个设计空间。每个框架为每个轴选择默认值；其余是表层语法。

### 每个 2026 框架如何映射到它

| 框架 | 代理 | 交接 | 共享状态 | 编排者 |
|------|------|------|---------|--------|
| OpenAI Swarm / Agents SDK | `Agent(instructions, tools)` | 工具返回 Agent | 调用者负责 | LLM 的下一个交接调用 |
| AutoGen v0.4 / AG2 | `ConversableAgent` | GroupChat 上的发言人选择器 | 消息池 | 选择器函数（LLM 或轮询） |
| CrewAI | `Agent(role, goal, backstory)` | `Process.Sequential / Hierarchical` | 任务输出链式传递 | 管理者 LLM 或静态顺序 |
| LangGraph | 节点函数 | 图边 + 条件 | `StateGraph` 归约器 | 确定性图 |
| Microsoft Agent Framework | agent + orchestration patterns | 模式特定 | thread / context | 模式特定 |
| Google ADK | agent + A2A card | A2A task | A2A artifacts | host 决定 |

表面差异看起来巨大。底层：相同的四个旋钮。

### 为什么这很重要

一旦你看到原语，框架比较就变成一个简短的检查清单：

- 编排者信任 LLM 进行路由（Swarm），还是在代码中固定路由（LangGraph）？
- 共享状态是全量历史（GroupChat）还是投影（StateGraph 归约器）？
- 代理能否修改彼此的提示（CrewAI 管理者），还是只能交接（Swarm）？

这三个问题回答了 80% 的哪个框架适合给定问题。你不再选购「最好的多代理框架」，而是开始为你真正关心的轴进行设计。

### 无状态洞察

除共享状态外，每个原语都是无状态的。代理是 (prompt, tools) 的函数。交接是一个函数调用。编排者是一个调度器。**系统中唯一有状态的东西是共享状态。** 所有有趣的 Bug 都在那里：记忆投毒（Memory Poisoning，第 15 课）、消息排序、版本控制、写入竞争。

隐藏共享状态的框架（Swarm）将问题推给调用者。集中式管理的框架（LangGraph checkpoint、AutoGen pool）使其可检查，但将协调成本转移到共享状态实现上。

### 单个原语的解剖

#### 代理

```
Agent = (system_prompt, tools, model, optional_name)
```

没有记忆。没有状态。拥有相同系统提示和工具的两个代理是可互换的。所有看起来像每个代理状态的东西，实际上在共享状态或交接协议中。

#### 交接

```
Handoff = (from_agent, to_agent, reason, payload)
```

三种实现占主导：

- **函数返回**——工具返回下一个代理。这是 OpenAI Swarm 模式。代理在其工具 Schema 中携带路由。
- **图边（Graph Edge）**——LangGraph。边是声明式的。LLM 产生一个值；条件选择下一个节点。
- **发言人选择（Speaker Selection）**——AutoGen GroupChat。一个选择器函数（有时本身就是 LLM 调用）读取池并选择下一个发言人。

#### 共享状态

```
SharedState = { messages: [], artifacts: {}, context: {} }
```

至少，一个消息列表。通常更多：结构化工件（CrewAI Task 输出）、类型化上下文（LangGraph 归约器）、外部记忆（MCP、向量数据库）。

两种拓扑：**全量池**（每个代理看到每条消息）和**投影（Projected）**（代理看到角色限定的视图）。全量池简单但扩展性差。投影池可扩展但需要预先的模式设计。

#### 编排者

```
Orchestrator = ({state, last_speaker}) -> next_agent
```

四种风格：

- **静态（Static）**——图在构建时固定（LangGraph 确定性、CrewAI Sequential）。
- **LLM 选择（LLM-Selected）**——LLM 读取池并选择下一个发言人（AutoGen、CrewAI Hierarchical）。
- **交接驱动（Handoff-Driven）**——当前代理通过调用交接工具决定（Swarm）。
- **队列驱动（Queue-Driven）**——工作者从共享队列中拉取；没有显式的下一个发言人（集群架构、Matrix）。

### 框架之间有什么变化

一旦原语固定，剩余的設計決策是：

- **记忆策略（Memory Strategy）**——临时的 vs 持久检查点（LangGraph checkpointer）。
- **安全边界（Safety Boundary）**——谁可以批准交接（人类在循环中，Human-in-the-Loop）。
- **成本核算（Cost Accounting）**——每个代理的 token 预算。
- **可观测性（Observability）**——追踪交接、持久化状态以供重放。

全部可以在原语之上实现。它们都不是新的原语。

## 构建

`code/main.py` 用约 150 行标准库 Python 实现了四个原语。没有真实的 LLM——每个代理都是一个脚本化策略，因此焦点保持在协调结构上。

文件导出：

- `Agent`——一个包含名称、系统提示、工具、策略函数的数据类。
- `Handoff`——返回新代理的函数。
- `SharedState`——线程安全的消息池。
- `Orchestrator`——三种变体：`StaticOrchestrator`、`HandoffOrchestrator`、`LLMSelectorOrchestrator`（模拟）。

演示通过所有三种编排者类型运行相同的三代理管道（研究 → 编写 → 审查），最后打印消息池。你可以看到输出只在*谁选择下一个*方面不同；代理和共享状态在各次运行中完全相同。

运行：

```
python3 code/main.py
```

预期输出：三次编排者运行，每种模式一次。每次打印最终消息池。如果研究员决定提前完成，交接驱动的运行会到达更少的代理——这是 LLM 路由权衡的缩影。

## 实践

`outputs/skill-primitive-mapper.md` 是一个技能，读取任何多代理代码库或框架文档并返回四原语映射。在新框架发布时运行它，在深入阅读文档之前获得一段话的理解。

## 交付

在采用新框架之前，为其编写原语映射。如果你做不到，说明文档不完整，或者框架正在发明第五个原语（罕见——检查是否有你没见过的共享状态变体）。

将映射固定在你的架构文档中。当新团队成员加入时，在 API 文档之前先发送映射给他们。当框架版本变更时，对比映射而非变更日志。

## 练习

1. 用不同的代理策略运行 `code/main.py` 三次。观察编排者的选择如何改变哪些代理运行。
2. 实现第四种编排者类型：队列驱动型，其中代理从共享状态中轮询工作。可能发生什么死锁，你如何检测？
3. 阅读 LangGraph 快速入门（https://docs.langchain.com/oss/python/langgraph/workflows-agents）并将其重写为四个原语。LangGraph 的哪些抽象是 1:1 映射，哪些是便利包装？
4. 阅读 OpenAI Swarm cookbook（https://developers.openai.com/cookbook/examples/orchestrating_agents）。识别 Swarm 使四个原语中哪一个最符合人体工程学，哪个它推给了调用者。
5. 找到表中一个完全隐藏共享状态的框架。解释当代理需要跨交接进行协调而不重新读取历史时，什么会出问题。

## 关键术语

| 术语 | 人们说的 | 实际含义 |
|------|---------|---------|
| Agent | 「带有工具的 LLM」 | `(system_prompt, tools, model)` 三元组。无状态。 |
| Handoff | 「控制转移」 | 命名下一个代理和可选有效载荷的结构化调用。三种实现：函数返回、图边、发言人选择。 |
| Shared state | 「记忆」/「上下文」 | 多代理系统中唯一有状态的部分。消息池或黑板。 |
| Orchestrator | 「协调器」 | 决定谁下一个运行的任何组件。静态图、LLM 选择器、交接驱动或队列驱动。 |
| Primitive | 「抽象」 | 每个框架参数化的四个轴之一。不是框架特性。 |
| Message pool | 「共享聊天历史」 | 全量历史共享状态。易于推理，扩展性差。 |
| Projected state | 「限定视图」 | 共享状态的角色特定视图。可扩展，需要模式设计。 |
| Speaker selection | 「谁下一个发言」 | 编排者模式，一个函数（通常是 LLM）从组中挑选下一个代理。 |

## 扩展阅读

- [OpenAI cookbook：编排 Agents——例程与交接](https://developers.openai.com/cookbook/examples/orchestrating_agents) — 交接驱动编排的最清晰阐述
- [AutoGen 稳定文档](https://microsoft.github.io/autogen/stable/) — GroupChat + 发言人选择是 LLM 选择编排的参考
- [LangGraph 工作流与代理](https://docs.langchain.com/oss/python/langgraph/workflows-agents) — 图边编排和基于归约器的共享状态
- [CrewAI 介绍](https://docs.crewai.com/en/introduction) — 角色-目标-背景故事代理，顺序/层次化流程
- [AG2（社区 AutoGen 延续）](https://github.com/ag2ai/ag2) — 微软将 v0.4 转入维护后的活跃 AutoGen v0.2 线