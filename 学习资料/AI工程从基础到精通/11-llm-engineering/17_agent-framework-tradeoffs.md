# Agent 框架权衡——LangGraph vs CrewAI vs AutoGen vs Agno

> 每个框架都在推销相同的演示（研究 Agent 构建一份报告），并且隐藏相同的 bug（状态 Schema 与编排层产生冲突）。选择其抽象层与你的问题形态匹配的框架；其余的都是你需要写两次的胶水代码。

**类型：** 学习
**语言：** Python
**前置条件：** Phase 11 · 09（函数调用）、Phase 11 · 16（LangGraph）
**时间：** 约 45 分钟

## 问题所在

你有一个需要不止一次 LLM 调用的任务。可能是一个研究工作流（计划、搜索、总结、引用）。可能是一个代码审查管道（解析差异、批评、打补丁、验证）。可能是一个预订航班、写邮件和提交报销报告的多轮对话助手。你选择一个框架。

三天后，你发现框架的抽象层有泄漏。CrewAI 给你角色，但当「研究员」需要将结构化计划交给「写手」时会和你对着干。AutoGen 给你 Agent 之间的对话，但没有一等状态，所以你的检查点只是对话日志的一个 pickle 对象。LangGraph 给你状态图，但强迫你在知道 Agent 会做什么之前就命名每一次转换。Agno 给你一个单 Agent 原语，当你试图扇出到三个并行工作者时它会尖叫。

解决方案不是「选择最好的框架」。而是将框架的核心抽象层与你的问题形态匹配起来。本课绘制了这张地图。

## 核心概念

![Agent 框架矩阵：核心抽象 vs 问题形态](../assets/framework-matrix.svg)

四个框架主导了 2026 年的格局。它们的核心抽象层并不相同。

| 框架 | 核心抽象 | 最适合 | 最不适合 |
|-----------|------------------|----------|-----------|
| **LangGraph** | `StateGraph`——类型化状态、节点、条件边、检查点器。 | 具有显式状态和人机协作中断的工作流；需要时间旅行调试的生产级 Agent。 | 拓扑未知的松散、角色驱动的头脑风暴。 |
| **CrewAI** | `Crew`——角色（目标、背景故事）、任务、流程（顺序或分层）。 | 角色扮演或人物驱动的具有简短线性/分层计划的工作流。 | 超出团队对话历史的任何有状态内容；复杂分支。 |
| **AutoGen** | `ConversableAgent` 对——两个或更多 Agent 轮流对话直到满足退出条件。 | 多 Agent *对话*（师生、提议者-批评者、执行者-审查者），其中思考从对话中涌现。 | 具有已知 DAG 的确定性工作流；任何需要跨重启持久化状态的内容。 |
| **Agno** | `Agent`——单个 LLM + 工具 + 记忆，可组合成团队。 | 快速构建的单 Agent 和轻量团队；强大的多模态和内置存储驱动。 | 具有自定义归约器的深度、显式分支图。 |

### 「抽象」到底意味着什么

框架的核心抽象是你在宣讲架构时在白板上画的东西。

- **LangGraph** → 你画一个图。节点是步骤，边是转换，每个点的状态对象是类型化的。思维模型是状态机。
- **CrewAI** → 你画一个组织架构图。每个角色有一个职位描述，一个管理者路由任务。思维模型是一个小型专家团队。
- **AutoGen** → 你画一个 Slack 私信。两个 Agent 互相发消息；如果需要主持人，第三个加入。思维模型是聊天。
- **Agno** → 你画一个带工具的单个框。把框并排放置就组成一个团队。思维模型是「开箱即用的 Agent」。

### 状态问题

状态是大多数框架选择在生产环境中出问题的地方。

- **LangGraph。** 类型化状态（`TypedDict` 或 Pydantic 模型），每字段归约器，一等检查点器（SQLite/Postgres/Redis）。恢复、中断和时间旅行是内置的。*（参见 Phase 11 · 16。）*
- **CrewAI。** 状态作为字符串通过 `context` 字段在任务间流动，或通过 `output_pydantic` 结构化传递。开箱即用没有持久化的 per-crew 存储；如果团队必须能在重启后存活，你需要自己加上。
- **AutoGen。** 状态是对话历史和任何用户定义的 `context`。对话记录会持久化；任意工作流状态不会，除非你编写适配器。
- **Agno。** 内置存储驱动（SQLite、Postgres、Mongo、Redis、DynamoDB），通过 `storage=` 附加到 `Agent`——对话会话和用户记忆会自动持久化。不是完整的图检查点器；是会话存储。

### 分支问题

每个非平凡的 Agent 都会分支。谁决定分支很重要。

- **LangGraph**——你决定，通过条件边。路由是一个带有命名分支的 Python 函数。分支在编译后的图中是一等的；检查点器记录走了哪个分支。
- **CrewAI**——在分层模式中由管理者决定；在顺序模式中由你在构建时决定。路由隐含在任务列表中；管理者的提示词之外没有一等的「if」。
- **AutoGen**——Agent 通过对话决定。分支从谁接下来发言中涌现。`GroupChatManager` 选择下一个发言者；你可以手写 `speaker_selection_method`，但默认是 LLM 驱动的。
- **Agno**——Agent 通过接下来调用哪个工具决定。团队有协调者/路由器/协作者模式；超出这范围的分支是开发者的责任。

### 可观测性问题

- **LangGraph**——通过 LangSmith 或任何 OTel 导出器使用 OpenTelemetry。每个节点转换是一个追踪跨度；检查点同时也是可重放的追踪。LangSmith 是第一方选项；Langfuse/Phoenix 也有适配器。
- **CrewAI**——自 2025 年底起具有一等 OpenTelemetry；集成 Langfuse、Phoenix、Opik、AgentOps。
- **CrewAI**——自 2025 年底起具有一等 OpenTelemetry；集成 Langfuse、Phoenix、Opik、AgentOps。
- **AutoGen**——通过 `autogen-core` 集成 OpenTelemetry；AgentOps 和 Opik 有连接器。追踪粒度是每个 Agent 消息，而非每个节点。
- **Agno**——内置 `monitoring=True` 标志加 OpenTelemetry 导出器；与 Langfuse 紧密集成以进行会话追踪。

### 成本与延迟

四个框架都增加了每次调用的开销（框架逻辑、验证、序列化）。开销递增的大致顺序：Agno ≈ LangGraph < CrewAI ≈ AutoGen。差异主要取决于框架做了多少额外的 LLM 路由。CrewAI 的分层管理者花费 token 决定谁下一个上场；AutoGen 的 `GroupChatManager` 也是如此。LangGraph 只在你编写 `llm.invoke` 的地方花费 token。Agno 的单 Agent 路径很轻薄。

当每次运行的成本很重要时，优先使用显式路由（LangGraph 边、AutoGen 的 `speaker_selection_method`）而非 LLM 选择的路由。

### 互操作性

- **LangGraph** ↔ **LangChain** 工具、检索器、LLM。一等 MCP 适配器（工具以 MCP 服务器形式导入）。
- **CrewAI** ↔ 工具继承自 `BaseTool`；LangChain 工具、LlamaIndex 工具和 MCP 工具都可以适配接入。通过 `allow_delegation=True` 实现团队间委托。
- **AutoGen** → `FunctionTool` 包装任何 Python 可调用对象；MCP 适配器可用。与 AG2 生态系统紧密耦合用于 Agent 间模式。
- **Agno** → `@tool` 装饰器或 BaseTool 子类；MCP 适配器；工具可以跨 Agent 和团队共享。

## 技能指南

> 你能用一句话解释为什么某个框架适合某个 Agent 问题。

构建前检查清单：

1. **画出形态。** 这是一个图（类型化状态、命名转换）？一个角色扮演（专家交接工作）？一个聊天（Agent 对话直到完成）？一个带工具的单个 Agent？
2. **决定谁做分支。** 开发者决定的分支 → LangGraph。管理者 Agent 决定的 → CrewAI 分层模式。从聊天中涌现的 → AutoGen。由工具调用决定的 → Agno。
3. **检查状态预算。** 你需要从检查点恢复吗？时间旅行？运行中间的人工中断？如果需要，LangGraph 是默认选择；Agno 会话涵盖对话范围的状态。
4. **检查成本预算。** LLM 选择的路由每轮花费额外的 token。如果 Agent 每天运行数千次，优先使用显式路由。
5. **预估框架开销。** 每个框架都是另一个依赖。如果任务是两次 LLM 调用和一个工具，写 30 行纯 Python；没有框架比没有框架更便宜。

拒绝在你能画出图、组织图、聊天或 Agent 框之前就去拿框架。拒绝选择一个强迫你为了你实际需要的东西而与它的状态模型斗争的框架。

## 决策矩阵

| 问题形态 | 推荐框架 | 原因 |
|---------------|---------------------|-----|
| 具有类型化状态、人工审批、长时间运行的工作流 DAG | LangGraph | 一等状态、检查点器、中断、时间旅行。 |
| 具有不同角色的研究/写作管道 | CrewAI（顺序）或 LangGraph 子图 | 在 CrewAI 中表达每个任务的角色很便宜；当分支变得复杂时升级到 LangGraph。 |
| 提议者-批评者或师生对话 | AutoGen | 双 Agent 聊天是其原生形态。 |
| 具有工具、会话、记忆的单 Agent | Agno | 最薄的设置，内置存储和记忆。 |
| 具有归约器的数千个并行扇出 | LangGraph + `Send` | 唯一具有一等并行派发原语的框架。 |
| 快速原型，不承诺任何框架 | 纯 Python + 提供商 SDK | 没有框架是最快的框架。 |

## 练习

1. **简单。** 取同一个任务——「研究 Anthropic 的总部，写一份 200 词的简报，引用来源」——并在 LangGraph（四个节点：plan、search、write、cite）和 CrewAI（三个角色：researcher、writer、editor）中实现。报告每次运行的 token 成本和代码行数。
2. **中等。** 在 AutoGen（researcher ↔ writer 对话，editor 通过 `GroupChat` 加入）和 Agno（单个 Agent 带 `search_tools` 和 `write_tools`，加会话存储）中构建同一任务。对四种实现按以下维度排名：(a) 每次运行成本，(b) 崩溃后恢复的能力，(c) 在写入步骤之前注入人工审批的能力。
3. **困难。** 构建一个决策树脚本 `pick_framework.py`，接受简短的问题描述（JSON：`{has_typed_state, has_roles, has_dialogue, has_parallel_fanout, needs_resume}`），并返回带有单句理由的推荐。在你自行设计的六个案例上进行验证。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|-----------------------|
| 编排（Orchestration） | 「Agent 如何协调」 | 决定哪个节点/角色/Agent 下一个运行的层。 |
| 持久化状态（Durable state） | 「重启后恢复」 | 在进程死亡后仍然存活的状态，附加到检查点或会话存储。 |
| LLM 选择的路由 | 「让模型决定」 | 每个轮次由规划 LLM 选择下一步；灵活但每次决策都消耗 token。 |
| 显式路由（Explicit routing） | 「开发者决定」 | Python 函数或静态边选择下一步；便宜且可审计。 |
| Crew | 「一个 CrewAI 团队」 | 角色 + 任务 + 流程（顺序或分层）绑定成一个可运行单元。 |
| GroupChat | 「AutoGen 的多 Agent 聊天」 | 由 N 个 Agent 组成的有管理的对话，带发言者选择器。 |
| Team (Agno) | 「多 Agent Agno」 | 在一组 Agent 上的路由/协调/协作模式。 |
| StateGraph | 「LangGraph 的图」 | 类型化状态、节点、条件边、检查点器原语。 |

## 进一步阅读

- [LangGraph documentation](https://langchain-ai.github.io/langgraph/)——StateGraph、检查点器、中断、时间旅行。
- [CrewAI documentation](https://docs.crewai.com/)——Crews、Flows、Agents、Tasks、Processes。
- [AutoGen documentation](https://microsoft.github.io/autogen/)——ConversableAgent、GroupChat、teams、tools。
- [Agno documentation](https://docs.agno.com/)——Agent、Team、Workflow、storage、memory。
- [Anthropic — Building effective agents (Dec 2024)](https://www.anthropic.com/research/building-effective-agents)——框架无关的模式库（提示词链式调用、路由、并行化、编排器-工作者、评估器-优化器）。
- [Yao et al., "ReAct: Synergizing Reasoning and Acting" (ICLR 2023)](https://arxiv.org/abs/2210.03629)——每个框架都在装扮的原语。
- [Wu et al., "AutoGen: Enabling Next-Gen LLM Applications via Multi-Agent Conversation" (2023)](https://arxiv.org/abs/2308.08155)——AutoGen 的设计论文。
- [Park et al., "Generative Agents: Interactive Simulacra of Human Behavior" (UIST 2023)](https://arxiv.org/abs/2304.03442)——CrewAI 风格角色栈所基于的角色扮演基础。
- Phase 11 · 16（LangGraph）——本课进行基准测试的框架。
- Phase 11 · 19（Reflexion）——一种清晰映射到 LangGraph 但在 CrewAI 中很笨拙的模式。
- Phase 11 · 22（生产可观测性）——如何为你选择的框架添加仪器化。