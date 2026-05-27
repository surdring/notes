# 函数调用深入剖析 —— OpenAI、Anthropic、Gemini

> 三家前沿提供商在 2024 年收敛到了同一个工具调用循环，但在其他所有方面都分道扬镳了。OpenAI 使用 `tools` 和 `tool_calls`。Anthropic 使用 `tool_use` 和 `tool_result` 块。Gemini 使用 `functionDeclarations` 和唯一 ID 关联。本课将三者并排对比，使在一个提供商上发布的代码在移植时不会出问题。

**类型：** 构建
**语言：** Python（标准库，Schema 翻译器）
**前置知识：** Phase 13 · 01（工具接口）
**时间：** ~75 分钟

## 学习目标

- 陈述 OpenAI、Anthropic 和 Gemini 函数调用负载之间的三个形态差异（声明、调用、结果）。
- 将一个工具声明翻译为三种提供商格式，并预测严格模式约束的差异点。
- 在每个提供商中使用 `tool_choice` 来强制、禁止或自动选择工具调用。
- 了解每个提供商的硬性限制（工具数量、Schema 深度、参数长度）以及违反限制时各自发出的错误信号。

## 问题

函数调用请求的形态因提供商而异。2026 年生产栈中的三个具体例子：

**OpenAI Chat Completions / Responses API。** 你传入 `tools: [{type: "function", function: {name, description, parameters, strict}}]`。模型的响应包含 `choices[0].message.tool_calls: [{id, type: "function", function: {name, arguments}}]`，其中 `arguments` 是一个 JSON 字符串，你必须对其进行解析。严格模式（`strict: true`）通过约束解码强制 Schema 合规。

**Anthropic Messages API。** 你传入 `tools: [{name, description, input_schema}]`。响应以 `content: [{type: "text"}, {type: "tool_use", id, name, input}]` 的形式返回。`input` 已经是解析好的对象，而非字符串。你回复一个新的 `user` 消息，其中包含 `{type: "tool_result", tool_use_id, content}` 块。

**Google Gemini API。** 你传入 `tools: [{functionDeclarations: [{name, description, parameters}]}]`（嵌套在 `functionDeclarations` 下）。响应以 `candidates[0].content.parts: [{functionCall: {name, args, id}}]` 的形式到达，其中 `id` 在 Gemini 3 及以上版本中是唯一的，用于并行调用关联。你回复 `{functionResponse: {name, id, response}}`。

相同的循环。不同的字段名、不同的嵌套、不同的字符串 vs 对象约定、不同的关联机制。一个在 OpenAI 上编写天气 Agent 的团队，移植到 Anthropic 需要两天，再移植到 Gemini 又需要一天，仅仅是为了管道代码。

本课构建一个翻译器，将三种格式统一为一个规范的工具声明，并在边缘进行路由。Phase 13 · 17 将此模式推广为 LLM 网关。

## 核心概念

### 公共结构

每个提供商都需要五样东西：

1. **工具列表。** 每个工具的名称、描述和输入 Schema。
2. **工具选择（Tool Choice）。** 强制指定工具、禁止工具，或让模型自行决定。
3. **调用输出。** 命名工具和参数的结构化输出。
4. **调用 ID。** 将响应关联到正确的调用（对并行调用至关重要）。
5. **结果注入。** 将结果与调用关联的消息或块。

### 形态差异，逐字段对比

| 方面 | OpenAI | Anthropic | Gemini |
|--------|--------|-----------|--------|
| 声明信封 | `{type: "function", function: {...}}` | `{name, description, input_schema}` | `{functionDeclarations: [{...}]}` |
| Schema 字段 | `parameters` | `input_schema` | `parameters` |
| 响应容器 | 助理消息上的 `tool_calls[]` | 类型为 `tool_use` 的 `content[]` | 类型为 `functionCall` 的 `parts[]` |
| 参数类型 | 字符串化 JSON | 已解析对象 | 已解析对象 |
| ID 格式 | `call_...`（OpenAI 生成） | `toolu_...`（Anthropic） | UUID（Gemini 3+） |
| 结果块 | 角色 `tool`，`tool_call_id` | 带有 `tool_result`、`tool_use_id` 的 `user` | 带有匹配 `id` 的 `functionResponse` |
| 强制调用工具 | `tool_choice: {type: "function", function: {name}}` | `tool_choice: {type: "tool", name}` | `tool_config: {function_calling_config: {mode: "ANY"}}` |
| 禁止工具 | `tool_choice: "none"` | `tool_choice: {type: "none"}` | `mode: "NONE"` |
| 严格 Schema | `strict: true` | Schema 即 Schema（始终强制执行） | 请求级的 `responseSchema` |

### 你实际会遇到的上限

- **OpenAI。** 每个请求 128 个工具。Schema 深度 5。参数字符串 <= 8192 字节。严格模式要求不使用 `$ref`，不重叠使用 `oneOf`/`anyOf`/`allOf`，每个属性都列在 `required` 中。
- **Anthropic。** 每个请求 64 个工具。Schema 深度实际上无界，但实际限制为 10。没有严格模式标志；Schema 是契约，模型倾向于遵守。
- **Gemini。** 每个请求 64 个函数。Schema 类型是 OpenAPI 3.0 子集（与 JSON Schema 2020-12 有轻微差异）。自 Gemini 3 起并行调用支持唯一 ID。

### `tool_choice` 行为

每种模式都支持的三种模式，名称不同。

- **Auto。** 模型选择工具或文本。默认。
- **Required / Any。** 模型必须调用至少一个工具。
- **None。** 模型不得调用工具。

另外每个提供商还有一种独有的模式：

- **OpenAI。** 按名称强制指定工具。
- **Anthropic。** 按名称强制指定工具；`disable_parallel_tool_use` 标志区分单调用和多调用。
- **Gemini。** `mode: "VALIDATED"` 将每个响应路由通过 Schema 验证器，无论模型意图如何。

### 并行调用

OpenAI 的 `parallel_tool_calls: true`（默认）在一条助理消息中发出多个调用。你全部运行它们，然后用一条包含每个 `tool_call_id` 对应条目的批量 tool 角色消息回复。Anthropic 历史上是单调用；`disable_parallel_tool_use: false`（自 Claude 3.5 起默认）启用了多调用。Gemini 2 允许并行调用但不提供稳定的 ID；Gemini 3 添加了 UUID，使乱序响应可以干净地关联。

### 流式处理

三者都支持流式工具调用。传输格式不同：

- **OpenAI。** `tool_calls[i].function.arguments` 的增量块逐步到达。你一直累积，直到 `finish_reason: "tool_calls"`。
- **Anthropic。** Block-start / block-delta / block-stop 事件。`input_json_delta` 块承载部分参数。
- **Gemini。** `streamFunctionCallArguments`（Gemini 3 新增）发出带有 `functionCallId` 的块，使多个并行调用可以交错传输。

Phase 13 · 03 深入讲解并行 + 流式重组的细节。本课聚焦于声明和单调用形态。

### 错误与修复

无效参数的报错看起来也不同。

- **OpenAI（非严格）。** 模型返回 `arguments: "{bad json}"`，你的 JSON 解析失败，你注入错误消息并重新调用。
- **OpenAI（严格）。** 验证在解码期间发生；不可能出现无效 JSON，但可能出现 `refusal`。
- **Anthropic。** `input` 可能包含意外字段；Schema 是建议性的。在服务端验证。
- **Gemini。** OpenAPI 3.0 特性：对象字段上的 `enum` 被静默忽略；自行验证。

### 翻译器模式

代码中的一个规范工具声明长这样（你可以选择形态）：

```python
Tool(
    name="get_weather",
    description="Use when ...",
    input_schema={"type": "object", "properties": {...}, "required": [...]},
    strict=True,
)
```

三个小函数将其翻译为三种提供商形态。`code/main.py` 中的程序正是这样做的，然后将一个假的工具调用通过每个提供商的响应形态进行往返。不需要网络——本课教授的是形态，而不是 HTTP。

生产团队将此翻译器包装在 `AbstractToolset`（Pydantic AI）、`UniversalToolNode`（LangGraph）或 `BaseTool`（LlamaIndex）中。Phase 13 · 17 交付一个网关，在任何一家提供商前面暴露一个 OpenAI 形态的 API。

## 使用它

`code/main.py` 定义一个规范的 `Tool` 数据类和三个翻译器，输出 OpenAI、Anthropic 和 Gemini 的声明 JSON。然后它将每种形态的手工制作提供商响应解析为相同的规范调用对象，演示了表面之下的语义完全相同。运行它并将三种声明并排对比。

需要关注的点：

- 三个声明块仅在信封和字段名称上有所不同。
- 三个响应块在调用所在位置（顶层 `tool_calls`、`content[]` 块、`parts[]` 条目）有所不同。
- 一个 `canonical_call()` 函数从所有三种响应形态中提取 `{id, name, args}`。

## 交付成果

本课产出 `outputs/skill-provider-portability-audit.md`。给定一个基于某一提供商的函数调用集成，该技能生成一份可移植性审计：它依赖了哪些提供商限制，哪些字段需要重命名，以及移植到其他每个提供商时会出什么问题。

## 练习

1. 运行 `code/main.py`，验证三种提供商声明 JSON 都序列化了相同的底层 `Tool` 对象。修改规范工具，添加一个枚举参数，确认只有 Gemini 翻译器需要处理 OpenAPI 的特性。

2. 为每个提供商添加一个 `ListToolsResponse` 解析器，用于提取模型在 `list_tools` 或发现调用后返回的工具列表。OpenAI 原生没有这个功能；注意这种不对称性。

3. 实现 `tool_choice` 转换：将规范的 `ToolChoice(mode="force", tool_name="x")` 映射到所有三种提供商形态。然后映射 `mode="any"` 和 `mode="none"`。查阅本课的差异对照表。

4. 选择三家提供商中的一家，从头到尾阅读其函数调用指南。找出其 Schema 规范中其他两家不支持的一个字段。候选：OpenAI 的 `strict`、Anthropic 的 `disable_parallel_tool_use`、Gemini 的 `function_calling_config.allowed_function_names`。

5. 编写一个测试向量：一个参数违反声明 Schema 的工具调用。通过每个提供商的验证器（第 01 课中标准库版本可作为代理）运行它，记录触发了哪些错误。记录在生产环境中你会选择哪家提供商来实现严格性。

## 关键术语

| 术语 | 人们的说法 | 实际含义 |
|------|----------------|------------------------|
| 函数调用（Function Calling） | "工具使用" | 提供商级 API，用于结构化工具调用输出 |
| 工具声明（Tool Declaration） | "工具规范" | 名称 + 描述 + JSON Schema 输入负载 |
| `tool_choice` | "强制/禁止" | Auto / required / none / specific-name 模式 |
| 严格模式（Strict Mode） | "Schema 强制执行" | OpenAI 标志，通过约束解码使输出匹配 Schema |
| `tool_use` 块 | "Anthropic 调用形态" | 内联内容块，包含 id、name、input |
| `functionCall` 部分 | "Gemini 调用形态" | 一个 `parts[]` 条目，包含 name、args 和 id |
| 参数作为字符串（Arguments-as-string） | "字符串化 JSON" | OpenAI 将 args 返回为 JSON 字符串而非对象 |
| 并行工具调用（Parallel Tool Calls） | "一回合扇出" | 单个助理消息中的多个工具调用 |
| 拒绝（Refusal） | "模型拒绝" | 严格模式下仅有的拒绝块，替代工具调用 |
| OpenAPI 3.0 子集 | "Gemini Schema 特性" | Gemini 使用类 JSON Schema 方言，与标准有微小差异 |

## 延伸阅读

- [OpenAI — Function calling guide](https://platform.openai.com/docs/guides/function-calling) —— 包含严格模式和并行调用的权威参考
- [Anthropic — Tool use overview](https://docs.anthropic.com/en/docs/agents-and-tools/tool-use/overview) —— `tool_use` 和 `tool_result` 块语义
- [Google — Gemini function calling](https://ai.google.dev/gemini-api/docs/function-calling) —— 并行调用、唯一 ID 和 OpenAPI 子集
- [Vertex AI — Function calling reference](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/multimodal/function-calling) —— Gemini 的企业级接口
- [OpenAI — Structured outputs](https://platform.openai.com/docs/guides/structured-outputs) —— 严格模式 Schema 强制执行细节