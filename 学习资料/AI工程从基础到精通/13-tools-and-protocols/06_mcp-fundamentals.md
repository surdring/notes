# MCP 基础 —— 原语、生命周期、JSON-RPC 基础

> 在 MCP 出现之前，每个集成都是一次性的。模型上下文协议（Model Context Protocol）由 Anthropic 于 2024 年 11 月首次发布，现在由 Linux 基金会下属的 Agentic AI 基金会管理，它标准化了发现和调用，使得任何客户端都可以与任何服务器通信。2025-11-25 版规范定义了六个原语（三个服务器端，三个客户端）、一个三阶段生命周期和 JSON-RPC 2.0 传输格式。掌握这些，本 Phase 中 MCP 章节的其余部分就只是阅读了。

**类型：** 学习
**语言：** Python（标准库，JSON-RPC 解析器）
**前置知识：** Phase 13 · 01 至 05（工具接口和函数调用）
**时间：** ~45 分钟

## 学习目标

- 说出所有六个 MCP 原语（服务器端的 tools、resources、prompts；客户端的 roots、sampling、elicitation），并各给出一个用例。
- 遍历三阶段生命周期（initialize、operation、shutdown），陈述每个阶段谁发送什么消息。
- 解析并生成 JSON-RPC 2.0 的请求、响应和通知信封。
- 解释 `initialize` 时的能力协商（Capability Negotiation）是什么，以及没有它会发生什么。

## 问题

在 MCP 出现之前，每个使用工具的 Agent 都有自己的协议。Cursor 有一个类似 MCP 但不兼容的工具系统。Claude Desktop 发布时使用了一个不同的系统。VS Code 的 Copilot 扩展用了第三个。一个构建"Postgres 查询"工具的团队需要把同一个工具写三遍，每次适配不同的宿主 API。要复用它就不得不复制代码。

结果是一次性集成的寒武纪大爆发，同时也是生态系统增速的天花板。

MCP 通过标准化传输格式解决了这个问题。一个 MCP 服务器可以工作在所有 MCP 客户端中：Claude Desktop、ChatGPT、Cursor、VS Code、Gemini、Goose、Zed、Windsurf——截至 2026 年 4 月已有 300 多个客户端。每月 1.1 亿次 SDK 下载。10,000 多个公开服务器。Linux 基金会于 2025 年 12 月在新成立的 Agentic AI 基金会下接手了管理工作。

本 Phase 使用的规范版本是 **2025-11-25**。它新增了异步 Task（SEP-1686）、URL 模式引导（SEP-1036）、带工具的采样（SEP-1577）、增量权限同意（SEP-835）以及 OAuth 2.1 资源指示器语义。Phase 13 · 09 至 16 涵盖这些扩展。本课只讲基础。

## 核心概念

### 三个服务器端原语

1. **Tools。** 可调用的操作。与 Phase 13 · 01 中相同的四步循环。
2. **Resources。** 暴露的数据。可通过 URI 寻址的只读内容：`file:///path`、`db://query/...`、自定义 scheme。
3. **Prompts。** 可复用的模板。宿主 UI 中的斜杠命令；服务器提供模板，客户端填充参数。

### 三个客户端原语

4. **Roots。** 服务器被允许访问的 URI 集合。客户端声明它们；服务器遵守它们。
5. **Sampling。** 服务器请求客户端的模型执行一次补全。使服务器托管的 Agent 循环无需服务端 API 密钥。
6. **Elicitation。** 服务器在执行过程中请求客户端用户提供结构化输入。表单或 URL（SEP-1036）。

MCP 中的每一种能力都恰好属于这六个原语之一。Phase 13 · 10 至 14 逐一深入涵盖每个原语。

### 传输格式：JSON-RPC 2.0

每条消息都是一个包含以下字段的 JSON 对象：

- 请求：`{jsonrpc: "2.0", id, method, params}`。
- 响应：`{jsonrpc: "2.0", id, result | error}`。
- 通知：`{jsonrpc: "2.0", method, params}`——没有 `id`，不期望响应。

基础规范约有 15 个方法，按原语分组。其中重要的有：

- `initialize` / `initialized`（握手）
- `tools/list`、`tools/call`
- `resources/list`、`resources/read`、`resources/subscribe`
- `prompts/list`、`prompts/get`
- `sampling/createMessage`（服务器到客户端）
- `notifications/tools/list_changed`、`notifications/resources/updated`、`notifications/progress`

### 三阶段生命周期

**第一阶段：initialize。**

客户端发送 `initialize`，附带其 `capabilities` 和 `clientInfo`。服务器响应自己的 `capabilities`、`serverInfo` 以及其支持的规范版本。客户端在消化响应后发送 `notifications/initialized`。从此以后，任何一方都可以根据协商好的能力发送请求。

**第二阶段：operation。**

双向的。客户端调用 `tools/list` 来发现工具，然后调用 `tools/call` 来调用。服务器可以发送 `sampling/createMessage`，如果它声明了该能力。当工具集发生变更时，服务器可以发送 `notifications/tools/list_changed`。当用户更改 root 范围时，客户端可以发送 `notifications/roots/list_changed`。

**第三阶段：shutdown。**

任一方关闭传输通道。MCP 中没有结构化的关闭方法；传输层（stdio 或 Streamable HTTP，Phase 13 · 09）承载连接结束信号。

### 能力协商

`initialize` 握手过程中的 `capabilities` 是契约。一个服务器的示例：

```json
{
  "tools": {"listChanged": true},
  "resources": {"subscribe": true, "listChanged": true},
  "prompts": {"listChanged": true}
}
```

服务器声明它可以发送 `tools/list_changed` 通知，并支持 `resources/subscribe`。客户端通过声明自己的能力来表示同意：

```json
{
  "roots": {"listChanged": true},
  "sampling": {},
  "elicitation": {}
}
```

如果客户端没有声明 `sampling`，服务器就不能调用 `sampling/createMessage`。对称地：如果服务器没有声明 `resources.subscribe`，客户端就不能尝试订阅。

这就是防止生态系统漂移的机制。一个不支持采样的客户端仍然是有效的 MCP 客户端；一个不调用 `sampling` 的服务器仍然是有效的 MCP 服务器。它们只是不使用该特性而已。

### 结构化内容和错误形态

`tools/call` 返回一个类型化块的 `content` 数组：`text`、`image`、`resource`。Phase 13 · 14 在此列表中添加了 MCP App（`ui://` 交互式 UI）。

错误使用 JSON-RPC 错误代码。规范定义的额外代码：`-32002`"Resource not found"、`-32603`"Internal error"，以及作为 `error.data` 的 MCP 特定错误数据。

### 客户端能力 vs 工具调用细节

一个常见的混淆：`capabilities.tools` 表示客户端是否支持工具列表变更通知。客户端是否 WILL 调用特定工具是一个运行时选择，由其模型驱动，而不是能力标志。能力标志是规范级别的契约。模型的选择是与之正交的。

### 为什么是 JSON-RPC 而不是 REST？

JSON-RPC 2.0（2010 年）是一个轻量级双向协议。REST 是客户端发起的。MCP 需要服务器发起的消息（采样、通知），因此 JSON-RPC 及其对称的请求/响应形态是自然的匹配。JSON-RPC 也能干净地组合在 stdio 和 WebSocket/Streamable HTTP 之上，而无需重新发明 HTTP 的请求形态。

## 使用它

`code/main.py` 提供一个最小的 JSON-RPC 2.0 解析器和生成器，然后手动遍历 `initialize` → `tools/list` → `tools/call` → `shutdown` 序列，打印每条消息。没有真实的传输层；只有消息形态。与"延伸阅读"中链接的规范对比，验证每个信封。

需要关注的点：

- `initialize` 双向声明能力；响应包含 `serverInfo` 和 `protocolVersion: "2025-11-25"`。
- `tools/list` 返回一个 `tools` 数组；每个条目包含 `name`、`description`、`inputSchema`。
- `tools/call` 使用 `params.name` 和 `params.arguments`。
- 响应 `content` 是一个 `{type, text}` 块的数组。

## 交付成果

本课产出 `outputs/skill-mcp-handshake-tracer.md`。给定一份 pcap 风格的 MCP 客户端-服务器交互记录，该技能为每条消息标注它属于哪个原语、哪个生命周期阶段以及依赖哪个能力。

## 练习

1. 运行 `code/main.py`。找出能力协商发生的那行，并描述如果服务器没有声明 `tools.listChanged` 会有什么变化。

2. 扩展解析器以处理 `notifications/progress`。消息形态：`{method: "notifications/progress", params: {progressToken, progress, total}}`。在一个长时间运行的 `tools/call` 进行中发送它，并确认客户端处理程序会显示进度条。

3. 从头到尾阅读 MCP 2025-11-25 规范——整个文档大约 80 页。找出大多数服务器不需要的一个能力标志。提示：它与资源订阅有关。

4. 在纸上画出假设的"cron 作业"特性所属的原语。（提示：服务器希望客户端在预定时间调用它。今天六个原语都不适合。）MCP 的 2026 路线图有一个针对此特性的 SEP 草案。

5. 从 GitHub 上一个开放的 MCP 服务器的会话日志中解析一次会话。统计请求 vs 响应 vs 通知消息的数量。计算流量中有多大比例是生命周期 vs 操作。

## 关键术语

| 术语 | 人们的说法 | 实际含义 |
|------|----------------|------------------------|
| MCP | "Model Context Protocol" | 用于模型到工具发现和调用的开放协议 |
| 服务器端原语（Server Primitive） | "服务器暴露的东西" | tools（操作）、resources（数据）、prompts（模板） |
| 客户端原语（Client Primitive） | "客户端让服务器使用的东西" | roots（范围）、sampling（LLM 回调）、elicitation（用户输入） |
| JSON-RPC 2.0 | "传输格式" | 对称的请求/响应/通知信封 |
| `initialize` 握手 | "能力协商" | 第一对消息；服务器和客户端声明各自支持的特性 |
| `tools/list` | "发现" | 客户端向服务器请求其当前工具集 |
| `tools/call` | "调用" | 客户端请求服务器执行带参数的工具 |
| `notifications/*_changed` | "变更事件" | 服务器告知客户端其原语列表已更改 |
| Content Block | "类型化结果" | 工具结果中的 `{type: "text" | "image" | "resource" | "ui_resource"}` |
| SEP | "Spec Evolution Proposal" | 命名的草案提案（例如，针对异步 Task 的 SEP-1686） |

## 延伸阅读

- [Model Context Protocol — Specification 2025-11-25](https://modelcontextprotocol.io/specification/2025-11-25) —— 规范原文
- [Model Context Protocol — Architecture concepts](https://modelcontextprotocol.io/docs/concepts/architecture) —— 六原语思维模型
- [Anthropic — Introducing the Model Context Protocol](https://www.anthropic.com/news/model-context-protocol) —— 2024 年 11 月发布博文
- [MCP blog — First MCP anniversary](https://blog.modelcontextprotocol.io/posts/2025-11-25-first-mcp-anniversary/) —— 一周年回顾和 2025-11-25 规范变更
- [WorkOS — MCP 2025-11-25 spec update](https://workos.com/blog/mcp-2025-11-25-spec-update) —— SEP-1686、1036、1577、835 和 1724 的总结