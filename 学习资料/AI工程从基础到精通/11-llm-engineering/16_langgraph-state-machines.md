# LangGraph——用于 Agent 的状态机

> 手动编写的 ReAct 循环是一个 `while True`。用 LangGraph 编写的 ReAct 循环是一个可以设置检查点、中断、分支和时间旅行的图。Agent 没有改变。围绕它的框架变了。

**类型：** 构建
**语言：** Python
**前置条件：** Phase 11 · 09（函数调用）、Phase 11 · 14（模型上下文协议）
**时间：** 约 75 分钟

## 问题所在

你发布了一个函数调用 Agent。它在三轮对话中运行正常，然后出了问题：模型尝试了一个返回 500 的工具，用户在任务中途改变了主意，或者 Agent 决定在没有人工签署的情况下退款订单。`while True:` 循环没有钩子。你不能暂停它，不能回退它，也不能分支到「如果模型选择了另一个工具会怎样」。一旦你将这个 Agent 发布到演示版之外，它就变成了一个要么成功要么失败的黑箱。

一旦你明白过来，下一步就显而易见。Agent 已经是一个状态机——系统提示词加消息历史加待处理的工具调用加下一个操作。将状态机显式化：节点表示「模型思考」、「工具运行」、「人类批准」，边表示它们之间的条件转换。一旦图变成显式的，框架就免费获得了四个能力：检查点（Checkpointing）（在步骤之间保存状态）、中断（Interrupts）（为人类暂停）、流式传输（Streaming）（流式输出 token 和中间事件）以及时间旅行（Time-travel）（回退到先前状态并尝试不同分支）。

LangGraph 是交付这种抽象层的库。它不是 LangChain 意义上的 Agent 框架（「这是一个 AgentExecutor，祝你好运」）。它是一个具有一等状态、一等持久化和一等中断功能的图运行时。Agent 循环是你画出来的东西，而不是你手动写出来的东西。

## 核心概念

![LangGraph StateGraph：节点、边和检查点器](../assets/langgraph-stategraph.svg)

一个 `StateGraph` 有三样东西。

1. **状态（State）。** 一个在图中流动的类型化字典（TypedDict 或 Pydantic 模型）。每个节点接收完整状态并返回部分更新，LangGraph 使用每个字段的*归约器（Reducer）*进行合并——对于应该累积的列表使用 `operator.add`，默认为覆盖。
2. **节点（Nodes）。** Python 函数 `state -> partial_state`。每个节点是一个离散步骤：「调用模型」、「运行工具」、「摘要」。
3. **边（Edges）。** 节点之间的转换。静态边只去一个地方。条件边带有一个路由函数 `state -> next_node_name`，以便图可以根据模型输出进行分支。

你编译图。编译绑定拓扑、附加检查点器（可选的，但对生产环境至关重要），并返回一个可运行对象。你使用初始状态和 `thread_id` 调用它。执行的每一步都会持久化一个检查点，以 `(thread_id, checkpoint_id)` 为键。

### 四个超能力

**检查点（Checkpointing）。** 每次节点转换都将新状态写入存储（测试用内存，生产环境用 Postgres/Redis/SQLite）。通过使用相同的 `thread_id` 再次调用图来恢复。图从其暂停的地方继续。

**中断（Interrupts）。** 使用 `interrupt_before=["human_review"]` 标记节点，执行在该节点运行之前停止。状态被持久化。你的 API 向用户响应「等待审批」。稍后对同一 `thread_id` 发起请求并使用 `Command(resume=...)` 恢复执行。

**流式传输（Streaming）。** `graph.stream(state, mode="updates")` 在状态增量发生时产出它们。`mode="messages"` 流式传输模型节点内的 LLM token。`mode="values"` 产出完整快照。你选择在 UI 中展示什么。

**时间旅行（Time-travel）。** `graph.get_state_history(thread_id)` 返回完整的检查点日志。将任何先前的 `checkpoint_id` 传递给 `graph.invoke`，你就可以从那个点分叉。非常适合调试（「如果模型选择了工具 B 会怎样？」）和重放生产轨迹的回归测试。

### 归约器是重点

每个状态字段都有一个归约器。大多数默认值都可以正常工作——新值覆盖旧值。但消息列表需要 `operator.add`，这样新消息会追加而不是替换。并行边通过归约器合并它们的更新。如果两个节点都更新了 `messages` 而你忘记使用 `Annotated[list, add_messages]`，第二个会静默获胜，你会丢失一半的对话轮次。归约器是库中唯一的微妙之处；把它弄对，其余的自然组合在一起。

### 四个节点的 ReAct 图

一个生产级 ReAct Agent 是四个节点和两条边：

1. `agent`——使用当前消息历史调用 LLM。返回助手消息（可能包含 tool_calls）。
2. `tools`——执行最后一条助手消息中的任何 tool_calls，将工具结果作为工具消息追加。
3. 一条从 `agent` 出发的条件边，如果最后一条消息有 tool_calls 则路由到 `tools`，否则路由到 `END`。
4. 一条从 `tools` 回到 `agent` 的静态边。

仅此而已。你在大约 40 行代码中获得完整的 ReAct 循环（思考 → 操作 → 观察 → 思考 → …），带有检查点、中断和流式传输。

### StateGraph vs Send（扇出）

`Send(node_name, state)` 让节点可以派发并行子图。例如：Agent 决定同时查询三个检索器。每个 `Send` 触发目标节点的并行执行；它们的输出通过状态归约器合并。这就是 LangGraph 在不使用线程原语的情况下表达编排器-工作者模式的方式。

### 子图

一个已编译的图可以作为节点存在于另一个图中。外部图看到一个节点；内部图有自己的状态和自己的检查点。这就是团队构建监督者-工作者 Agent 的方式：监督者图将用户意图路由到特定领域的工作者子图。

## 动手构建

### 步骤 1：状态和节点

```python
from typing import Annotated, TypedDict
from langchain_core.messages import AnyMessage, HumanMessage, AIMessage
from langgraph.graph import StateGraph, END
from langgraph.graph.message import add_messages
from langgraph.prebuilt import ToolNode
from langgraph.checkpoint.memory import MemorySaver

class State(TypedDict):
    messages: Annotated[list[AnyMessage], add_messages]

def agent_node(state: State) -> dict:
    response = llm.invoke(state["messages"])
    return {"messages": [response]}

def should_continue(state: State) -> str:
    last = state["messages"][-1]
    return "tools" if getattr(last, "tool_calls", None) else END

tool_node = ToolNode(tools=[search_web, read_file])

graph = StateGraph(State)
graph.add_node("agent", agent_node)
graph.add_node("tools", tool_node)
graph.set_entry_point("agent")
graph.add_conditional_edges("agent", should_continue, {"tools": "tools", END: END})
graph.add_edge("tools", "agent")

app = graph.compile(checkpointer=MemorySaver())
```

`add_messages` 是使消息列表累积而非覆盖的归约器。忘记使用它是 LangGraph 中最常见的 bug。

### 步骤 2：使用线程运行

```python
config = {"configurable": {"thread_id": "user-42"}}
for event in app.stream(
    {"messages": [HumanMessage("find the Anthropic headquarters address")]},
    config,
    stream_mode="updates",
):
    print(event)
```

每次更新是一个 dict `{node_name: state_delta}`。你的前端可以将其流式传输到 UI，使用户看到「agent 正在思考… 调用 search_web… 获取结果… 正在回答。」

### 步骤 3：添加人机协作中断

标记一个节点，使执行在该节点运行之前暂停。

```python
app = graph.compile(
    checkpointer=MemorySaver(),
    interrupt_before=["tools"],  # 每次工具调用前暂停
)

state = app.invoke({"messages": [HumanMessage("delete the production database")]}, config)
# state["__interrupt__"] 已设置。检查提议的工具调用。
# 如果批准：
from langgraph.types import Command
app.invoke(Command(resume=True), config)
# 如果拒绝：写入拒绝消息并恢复
app.update_state(config, {"messages": [AIMessage("Blocked by human reviewer.")]})
```

状态、检查点和线程在中断期间都会持久化。除了执行期间，没有任何内容保存在内存中。

### 步骤 4：用于调试的时间旅行

```python
history = list(app.get_state_history(config))
for snapshot in history:
    print(snapshot.values["messages"][-1].content[:80], snapshot.config)

# 从先前的检查点分叉
target = history[3].config  # 回退三步
for event in app.stream(None, target, stream_mode="values"):
    pass  # 从那个点重新向前回放
```

传入 `None` 作为输入会从给定检查点回放；传入值会在恢复前将其作为更新追加到该检查点的状态中。这就是你在不重新运行整个对话的情况下重现一个失败的 Agent 运行的方式。

### 步骤 5：为生产环境更换检查点器

```python
from langgraph.checkpoint.postgres import PostgresSaver

with PostgresSaver.from_conn_string("postgresql://...") as checkpointer:
    checkpointer.setup()
    app = graph.compile(checkpointer=checkpointer)
```

SQLite、Redis 和 Postgres 都已提供。`MemorySaver` 用于测试。任何需要在重启后持久化的东西都需要真实的存储。

## 技能指南

> 你将 Agent 构建为图，而不是 `while True` 循环。

在使用 LangGraph 之前，做一个 60 秒的设计：

1. **命名节点。** 每个离散的决策或产生副作用的操作都是一个节点。「Agent 思考」、「工具运行」、「审批者批准」、「响应流式传输」。如果你列不出它们，说明任务还没有形成 Agent 形态。
2. **声明状态。** 最小的 TypedDict，为每个列表字段配备归约器。不要把一切都塞进 `messages`；将特定于任务的字段（一个工作中的 `plan`、一个 `budget` 计数器、一个 `retrieved_docs` 列表）提升到顶层。
3. **画出边。** 静态边，除非下一步取决于模型输出。每条条件边都需要一个带有命名分支的路由函数。
4. **预先选择检查点器。** 测试用 `MemorySaver`，其他任何情况用 Postgres/Redis/SQLite。不要在没有检查点器的情况下发布——没有检查点器意味着不能恢复、不能中断、不能时间旅行。
5. **在工具运行之前决定中断，而非之后。** 审批放在进入产生副作用的节点的边上，以便在造成损害之前取消；验证放在模型输出的边上，以便以低成本拒绝错误调用。
6. **默认开启流式传输。** `mode="updates"` 用于 UI，`mode="messages"` 用于模型节点内的 token 级流式传输，`mode="values"` 用于评估时的完整快照。

拒绝发布没有检查点器的 LangGraph Agent。拒绝发布在副作用*之后*才中断的 Agent。拒绝发布没有使用 `add_messages` 作为其归约器的 `messages` 字段。

## 练习

1. **简单。** 使用一个计算器工具和一个网页搜索工具实现上述四节点 ReAct 图。验证 `list(app.get_state_history(config))` 对两轮对话至少返回四个检查点。
2. **中等。** 添加一个在 `agent` 之前运行的 `planner` 节点，将结构化的 `plan: list[str]` 写入状态。让 `agent` 将计划步骤标记为已完成。如果 `plan` 在检查点恢复时丢失（归约器错误），测试应失败。
3. **困难。** 构建一个监督者图，使用 `Send` 在三个子图（`researcher`、`writer`、`reviewer`）之间路由。每个子图有自己的状态和检查点器。在外部图上添加 `interrupt_before=["writer"]`，使人类可以批准研究简报。确认从先前检查点的时间旅行仅重新运行分叉的分支。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|-----------------------|
| StateGraph | 「LangGraph 的图」 | 编译前添加节点和边的构建器对象。 |
| 归约器（Reducer） | 「字段如何合并」 | 当节点返回对该字段的更新时应用的函数 `(old, new) -> merged`；默认是覆盖，`add_messages` 是追加。 |
| 线程（Thread） | 「对话 ID」 | 一个 `thread_id` 字符串，限定一个会话的所有检查点范围。 |
| 检查点（Checkpoint） | 「暂停的状态」 | 节点转换后完整图状态的持久化快照，以 `(thread_id, checkpoint_id)` 为键。 |
| 中断（Interrupt） | 「为人类暂停」 | `interrupt_before` / `interrupt_after` 在节点边界停止执行；使用 `Command(resume=...)` 恢复。 |
| 时间旅行（Time-travel） | 「从先前步骤分叉」 | `graph.invoke(None, config_with_old_checkpoint_id)` 从该检查点开始向前回放。 |
| Send | 「并行子图派发」 | 一种构造函数，节点可以返回它以派生目标节点的 N 个并行执行。 |
| 子图（Subgraph） | 「作为节点的已编译图」 | 作为节点用于另一个图中的已编译 StateGraph；保留其自己的状态作用域。 |

## 进一步阅读

- [LangGraph documentation](https://langchain-ai.github.io/langgraph/)——StateGraph、归约器、检查点器和中断的权威参考。
- [LangGraph concepts: state, reducers, checkpointers](https://langchain-ai.github.io/langgraph/concepts/low_level/)——本课使用的思维模型，直接来自源头。
- [LangGraph Persistence and Checkpoints](https://langchain-ai.github.io/langgraph/concepts/persistence/)——Postgres/SQLite/Redis 存储、检查点命名空间和线程 ID 的详细信息。
- [LangGraph Human-in-the-loop](https://langchain-ai.github.io/langgraph/concepts/human_in_the_loop/)——`interrupt_before`、`interrupt_after`、`Command(resume=...)` 以及编辑状态模式。
- [Yao et al., "ReAct: Synergizing Reasoning and Acting in Language Models" (ICLR 2023)](https://arxiv.org/abs/2210.03629)——每个 LangGraph Agent 实现的模式；阅读它以理解推理轨迹的原理。
- [Anthropic — Building effective agents (Dec 2024)](https://www.anthropic.com/research/building-effective-agents)——优先选择哪些图形状（链、路由器、编排器-工作者、评估器-优化器）以及何时选择。
- Phase 11 · 09（函数调用）——每个 LangGraph Agent 节点重用的工具调用原语。
- Phase 11 · 14（模型上下文协议）——通过 MCP 适配器插入 LangGraph `ToolNode` 的外部工具发现。
- Phase 11 · 17（Agent 框架权衡）——何时选择 LangGraph 而非 CrewAI、AutoGen 或 Agno。