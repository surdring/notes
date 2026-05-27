# LangGraph：有状态图与持久执行

> LangGraph 是 2026 年级别低层有状态编排的参考标准。Agent 是一个状态机；节点是函数；边是转换；状态是不可变的，并在每一步后设置检查点。从任何故障中精确恢复，从离开的位置继续。

**类型：** 学习 + 构建
**语言：** Python（标准库）
**前置要求：** Phase 14 · 01（Agent 循环），Phase 14 · 12（工作流模式）
**时间：** ~75 分钟

## 学习目标

- 描述 LangGraph 的核心模型：带不可变状态的状态机、函数节点、条件边和步骤后检查点。
- 说出文档强调的四个能力：持久执行、流式传输、人在回路中、综合记忆。
- 解释 LangGraph 支持的三种编排拓扑：监督者（supervisor）、对等（swarm）、层级（nested subgraphs）。
- 实现一个带有不可变状态、条件边和检查点/恢复周期的标准库状态图。

## 问题

Agent 和工作流共享一个问题：当一个 40 步的运行在第 38 步失败时，你想要从第 38 步恢复，而不是重新开始。二等的状态模型让运维人员围绕一个假设总是全新运行的库拼凑重试逻辑。

LangGraph 的设计答案：状态是一个一等类型化对象，变更是显式的，检查点在每个节点后持久化。恢复是一个 `load_state(session_id)` 调用。

## 概念

### 图

一个图由以下定义：

- **状态类型。** 每个节点读取和变更的类型化字典（或 Pydantic 模型）。
- **节点。** 纯函数 `(state) -> state_update`。更新在返回后合并到状态中。
- **边。** 节点之间的条件或直接转换。
- **入口和出口。** `START` 和 `END` 哨兵节点标记边界。

示例：一个带有 `classify`、`refund`、`bug`、`sales`、`done` 节点的 Agent —— 一个作为图实现的路由工作流。

### 持久执行

每个节点返回后，运行时序列化状态并将其写入检查点器（SQLite、Postgres、Redis、自定义）。在第 N 步失败时，运行时可以 `resume(session_id)` 并以精确的状态从第 N+1 步继续。

LangGraph 文档明确强调了这很重要的生产用户：Klarna、Uber、J.P. Morgan。重点不是图的形状，而是图形状加上检查点使恢复变得廉价。

### 流式传输

每个节点可以产生部分输出。图将每个节点的增量事件流式传输给调用者，使 UI 在图运行时更新。

### 人在回路中

在节点之间检查和修改状态。实现方式：在关键节点前暂停，将状态呈现给人类，接受修改，恢复。检查点器使这变得容易，因为状态已经被序列化。

### 记忆

短期（在一次运行内 —— 状态中的对话历史）和长期（跨运行 —— 通过检查点器加上独立的长期存储持久化）。LangGraph 通过工具与外部记忆系统（Mem0、自定义）集成。

### 三种拓扑

1. **监督者。** 中心路由 LLM 分发到专家子 Agent。`langgraph-supervisor` 中的 `create_supervisor()`（尽管 2026 年 LangChain 团队建议通过工具调用直接进行以获得更多上下文控制）。
2. **蜂群 / 对等。** Agent 通过共享工具面直接交接。没有中心路由器。
3. **层级。** 监督者管理下级监督者，实现为嵌套子图。

### 此模式出错的地方

- **检查点太小。** 只检查点对话轮次会导致工具状态和记忆写入无法恢复。完整状态必须序列化。
- **非确定性节点。** 恢复假设节点输入产生相同的状态更新。随机种子、墙钟时间、外部 API 必须被捕获。
- **条件边过度使用。** 每条边都是有条件的图是一个无法推理的状态机。偏好带偶尔分支的线性链。

## 构建

`code/main.py` 实现一个标准库有状态图：

- `State` —— 带有 `messages`、`step`、`route`、`output`、`human_approval` 的类型化字典。
- `Node` —— 接受状态并返回更新字典的可调用对象。
- `StateGraph` —— 节点 + 边 + 条件边 + 运行 + 恢复。
- `SQLiteCheckpointer`（内存模拟） —— 每个节点后序列化状态；`load(session_id)` 恢复。
- 一个演示图：分类 -> 分支（退款 / bug / 销售） -> 人工把关 -> 发送。

运行：

```
python3 code/main.py
```

轨迹显示第一次运行在人工把关处失败、持久化、然后恢复产生最终输出。

## 使用

- **LangGraph** —— 参考标准，生产就绪。使用 `create_react_agent`、`create_supervisor`，或构建你自己的图。
- **AutoGen v0.4**（第 14 课） —— 高并发场景的 Actor 模型替代方案。
- **Claude Agent SDK**（第 17 课） —— 带内置会话存储的托管实验环境。
- **自定义** —— 当你需要对状态形状或检查点器后端进行精确控制时。

## 交付物

`outputs/skill-state-graph.md` 在任何目标运行时中生成一个 LangGraph 形态的有状态图，连接检查点和恢复。

## 练习

1. 当分类置信度低于阈值时，添加从 `classify` 到 `end` 的条件边。在人类手动设置 `route` 后恢复运行。
2. 将 SQLite 类模拟替换为真实的 SQLite 检查点器。测量每步序列化开销。
3. 实现并行边：两个节点并发运行，通过自定义归并器合并。不可变状态在这里带来了什么价值？
4. 阅读 `langgraph-supervisor` 参考。将玩具移植到 `create_supervisor`。比较轨迹形态。
5. 添加流式传输：每个节点在运行时产生部分状态。在增量到达时打印它们。

## 关键术语

| 术语 | 常见说法 | 实际含义 |
|------|----------|----------|
| State graph（状态图） | "Agent 即状态机" | 类型化状态 + 节点 + 边 + 归并器 |
| Checkpointer（检查点器） | "持久化后端" | 每个节点后序列化状态；支持恢复 |
| Reducer（归并器） | "状态合并器" | 将当前状态与节点更新组合的函数 |
| Conditional edge（条件边） | "分支" | 由状态函数选择的边 |
| Subgraph（子图） | "嵌套图" | 在另一个图内部作为节点使用的图 |
| Durable execution（持久执行） | "从失败中恢复" | 在最后一个成功节点以精确状态重启 |
| Supervisor（监督者） | "路由 LLM" | 专家子 Agent 的中心分发器 |
| Swarm（蜂群） | "P2P Agent" | Agent 通过共享工具交接；无中心路由器 |

## 扩展阅读

- [LangGraph overview](https://docs.langchain.com/oss/python/langgraph/overview) — 参考文档
- [langgraph-supervisor reference](https://reference.langchain.com/python/langgraph/supervisor/) — 监督者模式 API
- [AutoGen v0.4, Microsoft Research](https://www.microsoft.com/en-us/research/articles/autogen-v0-4-reimagining-the-foundation-of-agentic-ai-for-scale-extensibility-and-robustness/) — Actor 模型替代方案
- [Claude Agent SDK overview](https://platform.claude.com/docs/en/agent-sdk/overview) — 会话存储和子 Agent