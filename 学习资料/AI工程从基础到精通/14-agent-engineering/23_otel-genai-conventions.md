# OpenTelemetry GenAI 语义约定

> OpenTelemetry 的 GenAI SIG（2024 年 4 月启动）定义了代理遥测（Agent Telemetry）的标准模式。Span 名称、属性和内容捕获规则在各供应商之间收敛，使得代理追踪在 Datadog、Grafana、Jaeger 和 Honeycomb 中含义一致。

**类型：** 学习 + 构建
**语言：** Python（标准库）
**前置条件：** Phase 14 · 13（LangGraph），Phase 14 · 24（可观测性平台，Observability Platforms）
**时间：** ~60 分钟

## 学习目标

- 列举 GenAI Span 类别：模型/客户端（model/client）、代理（agent）、工具（tool）。
- 区分 `invoke_agent` CLIENT 与 INTERNAL Span 以及各自适用场景。
- 列出顶层 GenAI 属性：provider name、request model、data-source ID。
- 解释内容捕获契约：选择加入（Opt-in）、`OTEL_SEMCONV_STABILITY_OPT_IN`、外部引用推荐。

## 问题

每个供应商都发明自己的 Span 名称。运维团队最终需要为每个框架构建单独的仪表板。OpenTelemetry 的 GenAI SIG 通过定义整个生态共同瞄准的一个标准来解决这个问题。

## 概念

### Span 类别

1. **模型 / 客户端 Span。** 覆盖原始 LLM 调用。由提供商 SDK（Anthropic、OpenAI、Bedrock）和框架模型适配器发出。
2. **代理 Span。** `create_agent`（代理构建时）和 `invoke_agent`（运行时）。
3. **工具 Span。** 每次工具调用一个；通过父子关系连接到代理 Span。

### 代理 Span 命名

- Span 名称：如果有命名则为 `invoke_agent {gen_ai.agent.name}`；否则回退为 `invoke_agent`。
- Span 种类（Span Kind）：
  - **CLIENT** — 用于远程代理服务（OpenAI Assistants API、Bedrock Agents）。
  - **INTERNAL** — 用于进程内代理框架（LangChain、CrewAI、本地 ReAct）。

### 关键属性

- `gen_ai.provider.name` — `anthropic`、`openai`、`aws.bedrock`、`google.vertex`。
- `gen_ai.request.model` — 模型 ID。
- `gen_ai.response.model` — 解析后的模型（因路由可能与请求不同）。
- `gen_ai.agent.name` — 代理标识符。
- `gen_ai.operation.name` — `chat`、`completion`、`invoke_agent`、`tool_call`。
- `gen_ai.data_source.id` — 用于 RAG：查询了哪个语料库或存储。

针对 Anthropic、Azure AI Inference、AWS Bedrock、OpenAI 存在特定技术的约定。

### 内容捕获

默认规则：插桩默认情况下不应（SHOULD NOT）捕获输入/输出。捕获通过以下方式选择加入（Opt-in）：

- `gen_ai.system_instructions`
- `gen_ai.input.messages`
- `gen_ai.output.messages`

推荐的生产模式：将内容存储在外部（S3、你的日志存储），在 Span 上记录引用（指针 ID，而非文本）。这是将第 27 课的内容中毒防御接入可观测性。

### 稳定性

截至 2026 年 3 月，大多数约定处于实验阶段。通过以下方式选择加入稳定预览：

```
OTEL_SEMCONV_STABILITY_OPT_IN=gen_ai_latest_experimental
```

Datadog v1.37+ 将 GenAI 属性原生映射到其 LLM 可观测性模式中。其他后端（Grafana、Honeycomb、Jaeger）支持原始属性。

### 这种模式的陷阱

- **在 Span 中捕获完整提示。** PII、密钥、客户数据出现在运维可读的追踪中。存储在外部。
- **缺少 `gen_ai.provider.name`。** 多提供商的仪表板在缺少归属时崩溃。
- **没有父链接的 Span。** 孤立的工具 Span。始终传播上下文。
- **未设置稳定性选择加入。** 你的属性可能在后端升级时被重命名。

## 构建

`code/main.py` 实现了一个标准库 Span 发射器，符合 GenAI 约定：

- `Span` 带有 GenAI 属性 Schema。
- `Tracer` 带有 `start_span`，嵌套上下文。
- 一个脚本化代理运行，发出：`create_agent`、`invoke_agent`（INTERNAL）、每个工具的 Span、LLM 调用的 `chat` Span。
- 内容捕获模式，将提示存储在外部并在 Span 上记录 ID。

运行方式：

```
python3 code/main.py
```

输出：具有所有必需 GenAI 属性的 Span 树，以及显示选择加入内容引用的"外部存储"。

## 使用场景

- **Datadog LLM 可观测性**（v1.37+）原生映射属性。
- **Langfuse / Phoenix / Opik**（第 24 课）— 自动插桩整个生态。
- **Jaeger / Honeycomb / Grafana Tempo** — 原始 OTel 追踪；从 GenAI 属性构建仪表板。
- **自托管** — 使用 GenAI 处理器运行 OTel 收集器。

## 部署

`outputs/skill-otel-genai.md` 将 OTel GenAI Span 接入现有代理，包含内容捕获默认值和外部引用存储。

## 练习

1. 用 `invoke_agent`（INTERNAL）+ 每个工具的 Span 插桩你的第 01 课 ReAct 循环。发送到 Jaeger 实例。
2. 以"仅引用"模式添加内容捕获：提示存入 SQLite，Span 属性只携带行 ID。
3. 阅读 `gen_ai.data_source.id` 的规范。将其接入你的第 09 课 Mem0 搜索。
4. 设置 `OTEL_SEMCONV_STABILITY_OPT_IN=gen_ai_latest_experimental` 并验证你的属性不会被收集器重命名。
5. 构建一个仪表板："哪些工具错误与哪些模型相关"，仅从 GenAI 属性构建。

## 关键术语

| 术语 | 人们常说的 | 实际含义 |
|------|-----------|---------|
| GenAI SIG | "OpenTelemetry GenAI 组" | 定义 Schema 的 OTel 工作组 |
| invoke_agent | "代理 Span" | 表示代理运行的 Span 名称 |
| CLIENT Span | "远程调用" | 调用远程代理服务的 Span |
| INTERNAL Span | "进程内" | 进程内代理运行的 Span |
| gen_ai.provider.name | "提供商" | anthropic / openai / aws.bedrock / google.vertex |
| gen_ai.data_source.id | "RAG 源" | 检索命中了哪个语料库/存储 |
| 内容捕获（Content Capture） | "提示日志" | 选择加入的消息捕获；在生产中存储在外部 |
| 稳定性选择加入（Stability Opt-in） | "预览模式" | 固定实验约定的环境变量 |

## 进一步阅读

- [OpenTelemetry GenAI 语义约定](https://opentelemetry.io/docs/specs/semconv/gen-ai/) — 规范
- [OpenAI Agents SDK](https://openai.github.io/openai-agents-python/) — 默认内置 GenAI Span
- [AutoGen v0.4（Microsoft Research）](https://www.microsoft.com/en-us/research/articles/autogen-v0-4-reimagining-the-foundation-of-agentic-ai-for-scale-extensibility-and-robustness/) — 内置 OTel Span
- [Claude Agent SDK](https://platform.claude.com/docs/en/agent-sdk/overview) — W3C 追踪上下文传播