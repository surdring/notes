# OpenTelemetry GenAI —— 端到端工具调用链路追踪

> 一个 Agent 调用了五个工具、三个 MCP 服务器和两个子 Agent。你需要一条跨越所有这一切的链路。OpenTelemetry GenAI 语义约定（Semantic Conventions，稳定属性从 v1.37 起）是 2026 年的标准，原生被 Datadog、Langfuse、Arize Phoenix、OpenLLMetry 和 AgentOps 支持。本课列出必需的属性，讲解 span 层级（Agent → LLM → 工具），并提供一个你可以插入任何 OTel 导出器的标准库 span 发射器。

**类型：** 构建
**语言：** Python（标准库，OTel span 发射器）
**前置要求：** Phase 13 · 07（MCP 服务器），Phase 13 · 08（MCP 客户端）
**时间：** ~75 分钟

## 学习目标

- 列出 LLM span 和工具执行 span 的必需 OTel GenAI 属性。
- 构建涵盖 Agent 循环、LLM 调用、工具调用和 MCP 客户端分发的链路层级。
- 决定捕获什么内容（选择加入）vs 脱敏什么内容（默认）。
- 将 spans 发送到本地收集器（Jaeger、Langfuse），无需重写工具代码。

## 问题

2026 年 2 月的一次调试：用户报告"我的 Agent 有时需要 30 秒响应；其他时候只需 3 秒。"没有链路追踪。日志显示了 LLM 调用，但没有工具分发、没有 MCP 服务器往返、没有子 Agent。你只能猜测。最终你发现：一个 MCP 服务器偶尔在冷启动时挂起。

没有端到端链路追踪，你无法找到这个问题。OTel GenAI 解决了它。

约定在 2025-2026 年间由 OpenTelemetry 语义约定组确定。它们定义了稳定的属性名称，使 Datadog、Langfuse、Phoenix、OpenLLMetry 和 AgentOps 都能解析相同的 spans。一次插桩；发送到任何后端。

## 概念

### Span 层级

```
agent.invoke_agent  （顶层，INTERNAL span）
 ├── llm.chat       （CLIENT span）
 ├── tool.execute   （INTERNAL）
 │    └── mcp.call  （CLIENT span）
 ├── llm.chat       （CLIENT span）
 └── subagent.invoke （INTERNAL）
```

整个结构嵌套在一个 trace id 下。Span id 链接父子关系。

### 必需属性

根据 2025-2026 语义约定：

- `gen_ai.operation.name` —— `"chat"`、`"text_completion"`、`"embeddings"`、`"execute_tool"`、`"invoke_agent"`。
- `gen_ai.provider.name` —— `"openai"`、`"anthropic"`、`"google"`、`"azure_openai"`。
- `gen_ai.request.model` —— 请求的模型字符串（例如 `"gpt-4o-2024-08-06"`）。
- `gen_ai.response.model` —— 实际提供服务的模型。
- `gen_ai.usage.input_tokens` / `gen_ai.usage.output_tokens`。
- `gen_ai.response.id` —— 用于关联的提供商响应 ID。

对于工具 spans：

- `gen_ai.tool.name` —— 工具标识符。
- `gen_ai.tool.call.id` —— 具体调用 ID。
- `gen_ai.tool.description` —— 工具描述（可选）。

对于 Agent spans：

- `gen_ai.agent.name` / `gen_ai.agent.id` / `gen_ai.agent.description`。

### Span 类型

- `SpanKind.CLIENT` 用于跨越进程边界的调用（LLM 提供商、MCP 服务器）。
- `SpanKind.INTERNAL` 用于 Agent 自身的循环步骤和工具执行。

### 选择加入的内容捕获

默认情况下，spans 携带指标和计时 —— 不携带提示词或补全。大型负载和 PII 默认关闭。设置 `OTEL_SEMCONV_STABILITY_OPT_IN=gen_ai_latest_experimental` 和特定的内容捕获环境变量以包含内容。在生产环境启用前仔细审查。

### Span 上的事件

令牌级事件可以作为 span 事件添加：

- `gen_ai.content.prompt` —— 输入消息。
- `gen_ai.content.completion` —— 输出消息。
- `gen_ai.content.tool_call` —— 记录的工具调用。

事件在 span 内按时间排序，以便进行详细回放。

### 导出器

OTel spans 导出到：

- **Jaeger / Tempo。** 开源，本地部署。
- **Langfuse。** 专用于 LLM 可观测性；可视化令牌使用。
- **Arize Phoenix。** 评估 + 链路追踪组合。
- **Datadog。** 商业；原生解析 `gen_ai.*` 属性。
- **Honeycomb。** 面向列；查询友好。

所有这些都使用 OTLP 传输格式。你的代码无需关心。

### 跨 MCP 传播

当 MCP 客户端调用服务器时，将 W3C traceparent 头注入请求。Streamable HTTP 支持标准头。Stdio 原生不携带 HTTP 头；规范的 2026 路线图讨论在 JSON-RPC 调用上添加 `_meta.traceparent` 字段。

在此功能发布之前：手动将 traceparent 包含在每次请求的 `_meta` 中。服务器记录 trace id。

### 指标

与 spans 并列，GenAI 语义约定定义了指标：

- `gen_ai.client.token.usage` —— 直方图。
- `gen_ai.client.operation.duration` —— 直方图。
- `gen_ai.tool.execution.duration` —— 直方图。

将这些用于不需要每次调用细节的仪表盘。

### AgentOps 层

AgentOps（成立于 2024 年）专注于 GenAI 可观测性。它包装了流行的框架（LangGraph、Pydantic AI、CrewAI）以自动发出 OTel spans。如果你的技术栈使用受支持的框架，这很有用；否则使用手动插桩。

## 使用

`code/main.py` 向 stdout 发出 OTel 格式的 spans（类似 OTLP-JSON 格式），用于一个调用 LLM、分发两个工具并进行一次 MCP 往返的 Agent。没有真正的导出器 —— 课程聚焦于 span 结构和属性集。将输出粘贴到与 OTLP 兼容的查看器中，或直接阅读。

需要关注的内容：

- Trace id 在所有 spans 之间共享。
- 父子链接通过 `parentSpanId` 编码。
- 必需的 `gen_ai.*` 属性已填充。
- 内容捕获默认关闭；一个场景通过环境变量开启。

## 交付物

本课产出 `outputs/skill-otel-genai-instrumentation.md`。给定一个 Agent 代码库，该技能生成插桩计划：在哪里添加 spans、填充哪些属性、定位哪些导出器。

## 练习

1. 运行 `code/main.py`。统计 spans 数量，识别哪些是 CLIENT 类型，哪些是 INTERNAL 类型。

2. 打开内容捕获（环境变量），确认 `gen_ai.content.prompt` 和 `gen_ai.content.completion` 事件出现。注意对 PII 的影响。

3. 添加工具执行指标 `gen_ai.tool.execution.duration`，并按每次调用作为直方图样本发出。

4. 将 traceparent 从父 Agent span 传播到 MCP 请求的 `_meta.traceparent` 字段。验证 MCP 服务器将看到相同的 trace id。

5. 阅读 OTel GenAI 语义约定规范。找出语义约定中列出但本课代码未发出的一个属性。添加它。

## 关键术语

| 术语 | 常见说法 | 实际含义 |
|------|----------|----------|
| OTel | "OpenTelemetry" | 链路追踪、指标、日志的开放标准 |
| GenAI semconv（GenAI 语义约定） | "GenAI semantic conventions" | LLM / 工具 / Agent spans 的稳定属性名称 |
| `gen_ai.*` | "属性命名空间" | 所有 GenAI 属性共享此前缀 |
| Span | "计时操作" | 具有开始、结束和属性的工作单元 |
| Trace（链路） | "跨 span 的血统" | 共享一个 trace id 的 span 树 |
| SpanKind | "CLIENT / SERVER / INTERNAL" | 关于 span 方向的提示 |
| OTLP | "OpenTelemetry Line Protocol" | 导出器的传输格式 |
| Opt-in content（选择加入的内容） | "提示词 / 补全捕获" | 默认关闭；通过环境变量启用 |
| traceparent | "W3C 头" | 跨服务传播链路上下文 |
| Exporter（导出器） | "后端特定的发送器" | 将 spans 发送到 Jaeger / Datadog 等的组件 |

## 扩展阅读

- [OpenTelemetry — GenAI semconv](https://opentelemetry.io/docs/specs/semconv/gen-ai/) — GenAI spans、指标和事件的权威约定
- [OpenTelemetry — GenAI spans](https://opentelemetry.io/docs/specs/semconv/gen-ai/gen-ai-spans/) — LLM 和工具执行 span 属性列表
- [OpenTelemetry — GenAI agent spans](https://opentelemetry.io/docs/specs/semconv/gen-ai/gen-ai-agent-spans/) — Agent 级别的 `invoke_agent` span
- [open-telemetry/semantic-conventions — GenAI spans](https://github.com/open-telemetry/semantic-conventions/blob/main/docs/gen-ai/gen-ai-spans.md) — GitHub 上的权威来源
- [Datadog — LLM OTel semantic convention](https://www.datadoghq.com/blog/llm-otel-semantic-convention/) — 生产集成的实操讲解