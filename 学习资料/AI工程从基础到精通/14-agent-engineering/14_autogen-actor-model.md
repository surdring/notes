# AutoGen v0.4：Actor 模型与 Agent 框架

> AutoGen v0.4（Microsoft Research，2025 年 1 月）围绕 Actor 模型重新设计 Agent 编排。异步消息交换、事件驱动 Agent、故障隔离、天然并发。该框架现在处于维护模式，而 Microsoft Agent Framework（2025 年 10 月公开预览）成为继任者。

**类型：** 学习 + 构建
**语言：** Python（标准库）
**前置要求：** Phase 14 · 01（Agent 循环），Phase 14 · 12（工作流模式）
**时间：** ~75 分钟

## 学习目标

- 描述 Actor 模型：Agent 作为 Actor，消息作为唯一的进程间通信（IPC），每个 Actor 的故障隔离。
- 说出 AutoGen v0.4 的三个 API 层 —— Core、AgentChat、Extensions —— 以及每层的用途。
- 解释为什么将消息传递与处理解耦能提供故障隔离和天然并发。
- 在 Python 中实现一个标准库 Actor 运行时，并将在其上移植一个双 Agent 代码审查流程。

## 问题

大多数 Agent 框架是同步的：一个 Agent 生成，一个 Agent 消费，在一个调用栈中。故障崩溃整个栈。并发是后来加上去的。分布需要重写。

AutoGen v0.4 的答案：Actor 模型。每个 Agent 是一个带有私有收件箱的 Actor。消息是唯一的交互方式。运行时将传递与处理解耦。故障隔离到单个 Actor。并发是天然的。分布只是不同的传输方式。

## 概念

### Actor

一个 Actor 有：

- 一个私有状态（永远不直接从外部触碰）。
- 一个收件箱（消息队列）。
- 一个处理函数：`receive(message) -> effects`，其中 effects 可以是"回复"、"发送给另一个 Actor"、"生成新 Actor"、"更新状态"、"停止自身"。

两个 Actor 不能共享内存。它们只能发送消息。

### AutoGen v0.4 中的三个 API 层

1. **Core。** 低层 Actor 框架。`AgentRuntime`、`Agent`、`Message`、`Topic`。异步消息交换，事件驱动。
2. **AgentChat。** 任务驱动的高层 API（替代 v0.2 的 ConversableAgent）。`AssistantAgent`、`UserProxyAgent`、`RoundRobinGroupChat`、`SelectorGroupChat`。
3. **Extensions。** 集成 —— OpenAI、Anthropic、Azure、工具、记忆。

### 为什么解耦很重要

在 v0.2 模型中，调用 `agent_a.chat(agent_b)` 会同步阻塞 agent_a，直到 agent_b 返回。在 v0.4 中，`send(agent_b, msg)` 将消息放入 agent_b 的收件箱并返回。运行时稍后传递。三个后果：

- **故障隔离。** Agent B 崩溃不会使 Agent A 崩溃 —— 运行时在 B 的处理函数中捕获失败并决定做什么（记录日志、重试、死信）。
- **天然并发。** 许多消息同时飞行；Actor 并发处理它们的收件箱。
- **分布就绪。** 收件箱 + 传输是相同的抽象，无论 Actor 是进程内还是在另一台主机上。

### 拓扑

- **RoundRobinGroupChat。** Agent 按固定轮换轮流执行。
- **SelectorGroupChat。** 一个选择器 Agent 根据对话上下文选择下一个谁去。
- **Magentic-One。** 用于 Web 浏览、代码执行、文件处理的参考多 Agent 团队。构建在 AgentChat 之上。

### 可观测性

内置 OpenTelemetry 支持。每条消息发出一个 span；工具调用携带 `gen_ai.*` 属性，遵循 2026 年 OTel GenAI 语义约定（第 23 课）。

### 状态：维护模式

2026 年初：AutoGen v0.7.x 对于研究和原型开发是稳定的。Microsoft 已将活跃开发转移到 Microsoft Agent Framework（2025 年 10 月 1 日公开预览；1.0 正式版目标 2026 年 Q1 末）。AutoGen 模式可以干净地向前移植 —— Actor 模型是持久的思想。

## 构建

`code/main.py` 实现一个标准库 Actor 运行时：

- `Message` —— 带有 `sender`、`recipient`、`topic`、`body` 的类型化载荷。
- `Actor` —— 抽象类，带有 `receive(message, runtime)`。
- `Runtime` —— 带共享队列的事件循环、传递、故障隔离。
- 一个双 Actor 演示：`ReviewerAgent` 审查代码，`ChecklistAgent` 运行检查清单；它们交换消息直到达成共识。

运行：

```
python3 code/main.py
```

轨迹显示消息传递、一个 Actor 中的模拟故障不会使另一个崩溃，以及在共享结论上收敛。

## 使用

- **AutoGen v0.4/v0.7**（维护） —— 对研究、原型开发、多 Agent 模式稳定。
- **Microsoft Agent Framework**（公开预览） —— 前瞻路径；在更新后的 API 中保持相同的 Actor 模型思想。
- **LangGraph 蜂群拓扑**（第 13 课） —— 通过共享工具交接的类似模式。
- **自定义 Actor 运行时** —— 当需要特定传输（NATS、RabbitMQ、gRPC）时。

## 交付物

`outputs/skill-actor-runtime.md` 为给定的多 Agent 任务生成最小 Actor 运行时加团队模板（RoundRobin 或 Selector）。

## 练习

1. 添加死信队列：当处理函数引发异常时，暂存失败消息以供人工检查。DLQ 在你的玩具中被命中的频率如何？
2. 实现 `SelectorGroupChat`：一个选择器 Actor 根据对话状态选择处理下一条消息的人。
3. 添加分布式传输：将进程内队列替换为 HTTP 之上的 JSON 服务器，使 Actor 可以在独立进程中运行。
4. 为每条消息连接一个 OTel span（或一个无操作替身）。按照第 23 课发出 `gen_ai.agent.name`、`gen_ai.operation.name`。
5. 阅读 AutoGen v0.4 的架构文章。将你的玩具移植到真实的 `autogen_core` API。你跳过了哪些在生产中很重要的东西？

## 关键术语

| 术语 | 常见说法 | 实际含义 |
|------|----------|----------|
| Actor | "Agent" | 私有状态 + 收件箱 + 处理函数；无共享内存 |
| Message（消息） | "事件" | 类型化载荷；Actor 交互的唯一方式 |
| Inbox（收件箱） | "邮箱" | 每个 Actor 的待处理消息队列 |
| Runtime（运行时） | "Agent 主机" | 路由消息和隔离故障的事件循环 |
| Topic（主题） | "通道" | Actor 之间命名的发布-订阅路由 |
| Fault isolation（故障隔离） | "让它崩溃" | 一个 Actor 失败不会使其他 Actor 崩溃 |
| RoundRobinGroupChat | "固定轮换团队" | Agent 按顺序轮流执行 |
| SelectorGroupChat | "上下文路由团队" | 选择器选择下一个谁去 |
| Magentic-One | "参考团队" | 用于 Web + 代码 + 文件的多 Agent 小队 |

## 扩展阅读

- [AutoGen v0.4, Microsoft Research](https://www.microsoft.com/en-us/research/articles/autogen-v0-4-reimagining-the-foundation-of-agentic-ai-for-scale-extensibility-and-robustness/) — 重新设计文章
- [LangGraph overview](https://docs.langchain.com/oss/python/langgraph/overview) — 图形状替代方案
- [OpenTelemetry GenAI semantic conventions](https://opentelemetry.io/docs/specs/semconv/gen-ai/) — AutoGen 默认发出的 span