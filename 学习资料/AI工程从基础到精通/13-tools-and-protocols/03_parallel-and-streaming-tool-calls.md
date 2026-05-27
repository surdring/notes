# 并行工具调用与含工具的流式处理

> 三个独立的天气查询以串行方式执行是三次往返。以并行方式运行它们，总时间压缩为最慢的单次调用时间。如今每个前沿提供商都能在单个回合中发出多个工具调用。收益是真实存在的，但管道代码也很微妙。本课涵盖两半内容：并行扇出（Parallel Fan-Out）和流式参数重组（Streaming Argument Reassembly），重点讲解 ID 关联的陷阱。

**类型：** 构建
**语言：** Python（标准库，线程池 + 流式测试程序）
**前置知识：** Phase 13 · 02（函数调用深入剖析）
**时间：** ~75 分钟

## 学习目标

- 解释 `parallel_tool_calls: true` 为什么存在，以及何时禁用它。
- 在并行扇出期间将流式参数块关联到正确的工具调用 ID。
- 将部分 `arguments` 字符串重组成完整的 JSON，而不提前解析。
- 运行一个三城市天气基准测试，演示串行与并行的延迟差异。

## 问题

如果没有并行调用，一个回答"班加罗尔、东京和苏黎世的天气如何"的 Agent 会这样做：

```
user -> LLM
LLM -> call get_weather(Bengaluru)
host -> run executor, reply with result
LLM -> call get_weather(Tokyo)
host -> run executor, reply with result
LLM -> call get_weather(Zurich)
host -> run executor, reply with result
LLM -> final text answer
```

三次 LLM 往返，每次还要加上执行器延迟。大约是理想墙钟时间的 4 倍。

使用并行调用：

```
user -> LLM
LLM -> call get_weather(Bengaluru); call get_weather(Tokyo); call get_weather(Zurich)
host -> run all three executors concurrently, reply with three results
LLM -> final text answer
```

一次 LLM 往返。执行器时间是三次调用的最大值而非总和。在 OpenAI、Anthropic 和 Gemini 上的生产基准测试显示，扇出工作负载的墙钟时间减少了 60% 到 70%。

代价是关联复杂度。当三个调用以乱序完成时，你的结果必须携带匹配的 `tool_call_id`，以便模型将它们对齐。当结果流式返回时，你必须在执行之前将部分参数片段组装成完整的 JSON。Gemini 3 添加唯一 ID 的部分原因就是为了解决一个真实世界的问题：对同一工具的两个并行调用无法区分。

## 核心概念

### 启用并行

- **OpenAI。** `parallel_tool_calls: true` 默认开启。设为 `false` 强制串行。
- **Anthropic。** 通过 `disable_parallel_tool_use: false` 实现并行（Claude 3.5 及以上默认）。设为 `true` 切换为串行。
- **Gemini。** 始终具备并行能力；`tool_config.function_calling_config.mode = "AUTO"` 让模型自行决定。

当工具之间有顺序依赖（`create_file` 然后 `write_file`）、当一个调用的输出是另一个调用的输入、或者当速率限制器无法处理扇出时，应禁用并行。

### ID 关联

模型发出的每个调用都有一个 `id`。宿主返回的每个结果都必须包含相同的 id。没有这个，结果就是模糊的。

- **OpenAI。** 每个 tool 角色消息上的 `tool_call_id`。
- **Anthropic。** 每个 `tool_result` 块上的 `tool_use_id`。
- **Gemini。** 每个 `functionResponse` 上的 `id`（Gemini 3 及以上；Gemini 2 按名称匹配，这对于同名的并行调用会出问题）。

### 并发运行调用

宿主在自己的线程、协程或远程 worker 上运行每个调用的执行器。最简单的测试程序使用线程池；生产环境使用 asyncio 配合 `asyncio.gather` 或结构化并发。完成顺序是不可预测的——id 是标识符。

一个常见 bug：按调用列表顺序而不是完成顺序回复结果。这通常没问题，因为模型只关心 `tool_call_id`，但如果一个结果被丢弃或重复，乱序提交会使调试更加困难。最好按完成顺序回复，附带显式的 id。

### 流式工具调用

当模型流式输出时，`arguments` 以片段形式到达。三个并行调用的三个独立的块流在传输中交错。你需要每个 id 一个累加器。

各提供商的形态：

- **OpenAI。** 每个块是 `choices[0].delta.tool_calls[i].function.arguments`（部分字符串）。块携带 `index`（调用列表中的位置）。你按 index 累积，在第一次出现时读取 `id`，当 `finish_reason = "tool_calls"` 时解析 JSON。
- **Anthropic。** 流事件为 `message_start`，然后每个块有一个 `content_block_start`，类型为 `tool_use`（包含 id、name、空 input）。`content_block_delta` 事件携带 `input_json_delta` 块。`content_block_stop` 关闭每个块。
- **Gemini。** `streamFunctionCallArguments`（Gemini 3 及以上）发出带有 `functionCallId` 的块，使调用可以干净地交错。在 Gemini 3 之前，流式处理一次返回一个完整的调用。

### 部分 JSON 和提前解析陷阱

在 `arguments` 完成之前不能解析它。部分 JSON，如 `{"city": "Beng`，是无效的，会引发异常。正确的闸门是提供商的调用结束信号：OpenAI 的 `finish_reason = "tool_calls"`、Anthropic 的 `content_block_stop`，或 Gemini 的流结束事件。只有在这时才能尝试 `json.loads`。更稳健的方法是使用增量 JSON 解析器，在结构完成时产生事件；OpenAI 的流式指南推荐这种做法，用于显示实时的"思考中"指示器。大括号计数作为完整性测试不可靠（引号内的大括号或转义内容会导致误报），只应作为非正式的调试启发式方法使用。

### 乱序完成

```
call_A: fast API, returns first
call_B: slow API, returns second
call_C: median API, returns third
```

宿主回复仍然必须引用这些 id：

```
[{role: "tool", tool_call_id: "call_A", content: ...},
 {role: "tool", tool_call_id: "call_B", content: ...},
 {role: "tool", tool_call_id: "call_C", content: ...}]
```

在 OpenAI 或 Anthropic 上，回复中的顺序不影响正确性。Gemini 接受任何顺序，只要 id 匹配即可。

### 基准测试：串行 vs 并行

`code/main.py` 中的测试程序模拟了三个执行器，延迟分别为 400、600 和 800 毫秒。串行运行总耗时 1800 毫秒。并行运行耗时 max(400, 600, 800) = 800 毫秒。差异是常量而非比例的，因此节省的时间随工具数量增加而增长。

真实世界的注意事项：并行调用会给下游 API 带来压力。向一个受速率限制的服务发起 10 路扇出将会失败。Phase 13 · 17 介绍网关级背压（Backpressure）；重试语义计划在未来的 Phase 中介绍。

### 流式扇出的墙钟时间

如果模型本身是流式的，你可以在一个调用的参数完成后立即开始执行，而不必等待所有调用完成。这是 OpenAI 记录的一种优化，但并非所有 SDK 都暴露。本课的测试程序做到了这点：一旦模拟流产生一个完整的参数对象，宿主就立即启动该调用。

## 使用它

`code/main.py` 有两半。第一半使用 `concurrent.futures.ThreadPoolExecutor` 依次和并行运行三个模拟天气调用，并打印墙钟时间。第二半重放一个假的流式响应——三个并行调用的 `arguments` 块在一个流上交错——并使用 `StreamAccumulator` 按 id 重组它们。没有 LLM，没有网络，只有重组逻辑。

需要关注的点：

- 串行计时器在相同的假延迟上达到 1.8 秒。并行计时器达到 0.8 秒。
- 累加器通过按 id 缓冲来处理乱序到达的块，仅当每个调用的 JSON 完成时才解析。
- 执行器在一个 id 的参数完成后立即启动，而不是等所有流结束后才启动。

## 交付成果

本课产出 `outputs/skill-parallel-call-safety-check.md`。给定一个工具注册中心，该技能审计哪些工具可以安全并行化、哪些有顺序依赖、以及哪些会压垮下游速率限制——返回一个修订后的注册中心，带每个工具的 `parallel_safe` 标志。

## 练习

1. 运行 `code/main.py`，改变模拟延迟。确认并行/串行比例近似为 `max/sum`（实际运行因线程调度、序列化和程序开销而略有偏差）。在什么延迟分布下并行不再重要？

2. 扩展累加器，通过丢弃其缓冲区并发出 `cancelled` 事件来处理"调用在流中途被取消"的情况。哪个提供商明确记录了这种情况？查阅 Anthropic 的 `content_block_stop` 语义和 OpenAI 的 `finish_reason: "length"` 行为。

3. 将线程池替换为 `asyncio.gather`。对两者进行基准测试。你应该在异步上看到小幅优势，因为上下文切换成本更低，但仅当执行器执行真实 I/O 时才会体现。

4. 选择两个不应该并行化的工具（例如 `create_file` 然后 `write_file`）。向注册中心添加一个 `ordering_dependency` 图，并在该图上对并行扇出进行门控。这是依赖感知调度的最小机制，后续的 Agent 工程 Phase 会将其正式化。

5. 阅读 OpenAI 的并行函数调用部分和 Anthropic 的 `disable_parallel_tool_use` 文档。找出 Anthropic 推荐禁用并行的一种真实世界工具类型。（提示：对同一资源的后果性变更。）

## 关键术语

| 术语 | 人们的说法 | 实际含义 |
|------|----------------|------------------------|
| 并行工具调用（Parallel Tool Calls） | "一回合扇出" | 模型在单个助理消息中发出多个工具调用 |
| `parallel_tool_calls` | "OpenAI 的标志" | 启用或禁用多调用输出 |
| `disable_parallel_tool_use` | "Anthropic 的反向标志" | 主动退出标志；默认是启用并行 |
| 工具调用 ID（Tool Call ID） | "关联句柄" | 每个调用的标识符，结果消息必须回显 |
| 累加器（Accumulator） | "流式缓冲区" | 按 id 的部分 `arguments` 块的字符串缓冲区 |
| 乱序完成（Out-of-Order Completion） | "最快者优先" | 并行调用以不可预测的顺序完成；id 是粘合剂 |
| 依赖图（Dependency Graph） | "顺序约束" | 输出会馈入其他工具输入的工具；不能并行化 |
| 提前解析陷阱（Parse-Early Trap） | "JSON.parse 崩溃" | 尝试解析不完整的 `arguments` 字符串 |
| `streamFunctionCallArguments` | "Gemini 3 特性" | 带有每个调用唯一 id 的流式参数块 |
| 完成顺序回复（Completion-Order Reply） | "不等所有都完成" | 结果在到达时即回复，按 id 标识 |

## 延伸阅读

- [OpenAI — Parallel function calling](https://platform.openai.com/docs/guides/function-calling#parallel-function-calling) —— 默认行为和主动退出标志
- [Anthropic — Tool use: implementing tool use](https://docs.anthropic.com/en/docs/agents-and-tools/tool-use/implementing-tool-use) —— `disable_parallel_tool_use` 和结果批处理
- [Google — Gemini function calling parallel section](https://ai.google.dev/gemini-api/docs/function-calling) —— Gemini 3 起支持 ID 关联的并行调用
- [OpenAI — Streaming responses with tools](https://platform.openai.com/docs/api-reference/responses-streaming) —— OpenAI 流的块式参数重组
- [Anthropic — Streaming messages](https://docs.anthropic.com/en/api/messages-streaming) —— 带 `input_json_delta` 的 `content_block_delta`