# OpenAI Agents SDK：交接、护栏、链路追踪

> OpenAI Agents SDK 是构建在 Responses API 之上的轻量级多 Agent 框架。五个原语：Agent、Handoff、Guardrail、Session、Tracing。交接（Handoffs）是名为 `transfer_to_<agent>` 的工具。护栏（Guardrails）在输入或输出上触发。链路追踪（Tracing）默认开启。

**类型：** 学习 + 构建
**语言：** Python（标准库）
**前置要求：** Phase 14 · 01（Agent 循环），Phase 14 · 06（工具使用）
**时间：** ~75 分钟

## 学习目标

- 说出 OpenAI Agents SDK 的五个原语。
- 解释交接：为什么它们被建模为工具，模型看到什么名称形状，以及上下文如何传输。
- 区分输入护栏、输出护栏和工具护栏；解释 `run_in_parallel` vs 阻塞模式。
- 实现一个带有交接 + 护栏 + span 风格链路追踪的标准库运行时。

## 问题

无法干净委派的 Agent 最终将所有内容塞入一个提示词中。没有护栏的 Agent 会发送 PII、违规输出或永远循环。OpenAI 的 SDK 将这三个使多 Agent 工作可处理的原语固化下来。

## 概念

### 五个原语

1. **Agent。** LLM + 指令 + 工具 + 交接。
2. **Handoff（交接）。** 委派给另一个 Agent。对模型表示为名为 `transfer_to_<agent_name>` 的工具。
3. **Guardrail（护栏）。** 对输入（仅第一个 Agent）、输出（仅最后一个 Agent）或工具调用（每个函数工具）的验证。
4. **Session（会话）。** 跨轮次的自动对话历史。
5. **Tracing（链路追踪）。** 用于 LLM 生成、工具调用、交接、护栏的内置 span。

### 交接作为工具

模型在其工具列表中看到 `transfer_to_billing_agent`。调用它向运行时发出信号：

1. 复制对话上下文（或通过 `nest_handoff_history` beta 折叠它）。
2. 使用其指令初始化目标 Agent。
3. 继续使用目标 Agent 运行。

这是被产品化的监督者模式（第 13 课 / 第 28 课）。

### 护栏

三种风格：

- **输入护栏。** 对第一个 Agent 的输入运行。在任何 LLM 调用之前拒绝不安全或超出范围的请求。
- **输出护栏。** 对最后一个 Agent 的输出运行。捕获 PII 泄漏、策略违规、格式错误的响应。
- **工具护栏。** 对每个函数工具运行。验证参数、检查权限、审计执行。

模式：

- **并行（Parallel）**（默认）。护栏 LLM 与主 LLM 并行运行。尾部延迟较低。如果触发，主 LLM 的工作被丢弃（令牌浪费）。
- **阻塞（Blocking）**（`run_in_parallel=False`）。护栏 LLM 先运行。如果触发，不浪费令牌在主调用上。

触发器引发 `InputGuardrailTripwireTriggered` / `OutputGuardrailTripwireTriggered`。

### 链路追踪

默认开启。每次 LLM 生成、工具调用、交接和护栏都发出一个 span。`OPENAI_AGENTS_DISABLE_TRACING=1` 退出。`add_trace_processor(processor)` 将 span 扇出到你自己后端，与 OpenAI 的并行。

### 会话

`Session` 在后端（SQLite、Redis、自定义）存储对话历史。`Runner.run(agent, input, session=session)` 自动加载和追加。

### 此模式出错的地方

- **交接漂移。** Agent A 交接给 Agent B，后者交接回 Agent A。添加跳数计数器。
- **护栏绕过。** 工具护栏仅对函数工具触发；内置工具（文件读取器、网络获取）需要单独策略。
- **过度链路追踪。** Span 中的敏感内容。配合 OTel GenAI 内容捕获规则（第 23 课）—— 外部存储，通过 ID 引用。

## 构建

`code/main.py` 在标准库中实现 SDK 形态：

- `Agent`、`FunctionTool`、`Handoff`（作为带传输语义的函数工具）。
- `Runner` 带输入/输出/工具护栏、交接分发和跳数计数器。
- 一个简单的 span 发射器展示轨迹形态。
- 一个分诊 Agent，根据用户查询交接给账单或支持部门；护栏在一个输入上触发。

运行：

```
python3 code/main.py
```

轨迹显示两次成功的交接、一次输入护栏触发和一个镜像真实 SDK 发出的 span 树。

## 使用

- **OpenAI Agents SDK** 用于 OpenAI 优先产品。
- **Claude Agent SDK**（第 17 课）用于 Claude 优先产品。
- **LangGraph**（第 13 课）当你想要显式状态和持久恢复时。
- **自定义** 当需要精确控制时（语音、多提供商、联邦部署）。

## 交付物

`outputs/skill-agents-sdk-scaffold.md` 搭建一个 Agents SDK 应用，带有分诊 Agent、交接、输入/输出/工具护栏、会话存储和轨迹处理器。

## 练习

1. 添加交接跳数计数器：在 N 次传输后拒绝。追踪此行为。
2. 将 `nest_handoff_history` 作为选项实现 —— 在传输前将之前的消息压缩为一个摘要。
3. 编写一个阻塞输出护栏。比较会触发的提示词与通过的提示词的延迟。
4. 将 `add_trace_processor` 连接到一个 JSON 日志器。每个 span 发出什么形状？
5. 阅读 SDK 文档。将你的标准库玩具移植到 `openai-agents-python`。你建模错了什么？

## 关键术语

| 术语 | 常见说法 | 实际含义 |
|------|----------|----------|
| Agent | "LLM + 指令" | SDK 中的 Agent 类型；拥有工具和交接 |
| Handoff（交接） | "转移" | 模型调用以委派给另一个 Agent 的工具 |
| Guardrail（护栏） | "策略检查" | 对输入/输出/工具调用的验证 |
| Tripwire（触发） | "护栏触发" | 护栏拒绝时引发的异常 |
| Session（会话） | "历史存储" | 在运行之间持久化的对话记忆 |
| Tracing（链路追踪） | "Span" | 对 LLM + 工具 + 交接 + 护栏的内置可观测性 |
| Blocking guardrail（阻塞护栏） | "顺序检查" | 护栏先运行；触发时不浪费令牌 |
| Parallel guardrail（并行护栏） | "并发检查" | 护栏并行运行；延迟较低，触发时浪费令牌 |

## 扩展阅读

- [OpenAI Agents SDK docs](https://openai.github.io/openai-agents-python/) — 原语、交接、护栏、链路追踪
- [Claude Agent SDK overview](https://platform.claude.com/docs/en/agent-sdk/overview) — Claude 风格对应物
- [Anthropic, Building Effective Agents](https://www.anthropic.com/research/building-effective-agents) — 何时需要交接
- [OpenTelemetry GenAI semantic conventions](https://opentelemetry.io/docs/specs/semconv/gen-ai/) — Agents SDK span 映射到的标准