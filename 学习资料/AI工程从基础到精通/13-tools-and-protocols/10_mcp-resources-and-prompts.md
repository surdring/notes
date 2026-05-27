# MCP 资源与提示词 —— 超越工具的上下文暴露

> 工具获得了 MCP 90% 的关注。另外两个服务器端原语解决的是不同的问题。资源（Resources）暴露数据以供读取；提示词（Prompts）将可复用的模板作为斜杠命令暴露。许多服务器应该使用资源来代替将读取包装为工具，使用提示词来代替在客户端提示词中硬编码工作流。本课阐明决策规则，并演练 `resources/*` 和 `prompts/*` 消息。

**类型：** 构建
**语言：** Python（标准库，资源 + 提示词处理程序）
**前置知识：** Phase 13 · 07（MCP 服务器）
**时间：** ~45 分钟

## 学习目标

- 对于给定领域，决定将一项能力作为工具、资源还是提示词暴露。
- 实现 `resources/list`、`resources/read`、`resources/subscribe` 并处理 `notifications/resources/updated`。
- 实现带参数模板的 `prompts/list` 和 `prompts/get`。
- 识别宿主何时将提示词作为斜杠命令暴露 vs 自动注入上下文。

## 问题

一个天真的笔记应用 MCP 服务器将一切都暴露为工具：`notes_read`、`notes_list`、`notes_search`。这将每个数据访问都包装在模型驱动的工具调用中。后果：

- 模型必须决定是否为每个可能受益于上下文的查询调用 `notes_read`。
- 只读内容不能被订阅或流式传输到宿主的侧面板。
- 客户端 UI（Claude Desktop 的资源附加面板、Cursor 的"包含文件"选择器）无法展示这些数据。

正确的划分：将数据作为资源暴露，将变更或计算操作作为工具暴露，将可复用的多步骤工作流作为提示词暴露。每个原语都有其 UX 形式和访问模式。

## 核心概念

### 工具 vs 资源 vs 提示词 —— 决策规则

| 能力 | 原语 |
|------------|-----------|
| 用户想要搜索、过滤或转换数据 | 工具 |
| 用户希望宿主将此数据作为上下文包含 | 资源 |
| 用户想要一个可以重复运行的可模板化工作流 | 提示词 |

指导方针：如果模型在每个相关查询中都受益于调用它，它就是工具。如果用户受益于将其附加到对话中，它就是资源。如果整个多步骤工作流是用户想要复用的单元，它就是提示词。

### 资源

`resources/list` 返回 `{resources: [{uri, name, mimeType, description?}]}`。`resources/read` 接收 `{uri}` 并返回 `{contents: [{uri, mimeType, text | blob}]}`。

URI 可以是任何可寻址的内容：

- `file:///Users/alice/notes/mcp.md`
- `postgres://my-db/query/SELECT ...`
- `notes://note-14`（自定义 scheme）
- `memory://session-2026-04-22/recent`（服务器特定）

`contents[]` 同时支持文本和二进制。二进制使用 `blob` 作为 base64 编码字符串加上 `mimeType`。

### 资源订阅

在能力中声明 `{resources: {subscribe: true}}`。客户端调用 `resources/subscribe {uri}`。当资源发生变化时，服务器发送 `notifications/resources/updated {uri}`。客户端重新读取。

用例：一个笔记服务器，其资源是磁盘上的文件；文件监视器在文件在宿主机外被编辑时触发更新通知；Claude Desktop 重新拉取文件到上下文中。

### 资源模板（2025-11-25 新增）

`resourceTemplates` 允许你暴露一个参数化的 URI 模式：`notes://{id}`，其中 `id` 作为补全目标。客户端可以在资源选择器中自动补全 ID。

### 提示词

`prompts/list` 返回 `{prompts: [{name, description, arguments?}]}`。`prompts/get` 接收 `{name, arguments}` 并返回 `{description, messages: [{role, content}]}`。

提示词是一个模板，填充为宿主提供给其模型的消息列表。例如，一个 `code_review` 提示词接收一个 `file_path` 参数，返回一个三消息序列：一条系统消息、一条包含文件正文的用户消息，以及一条带有推理模板的助理启动消息。

### 宿主与提示词

Claude Desktop、VS Code 和 Cursor 在聊天 UI 中将提示词暴露为斜杠命令。用户输入 `/code_review` 并从表单中选择参数。服务器的提示词是"用户快捷方式"与"发送给模型的完整提示词"之间的契约。

尚非每个客户端都支持提示词——检查能力协商。声明了提示词能力但客户端不支持提示词的服务器，简单地不会显示斜杠命令。

### "列表已变更"通知

当集合发生变化时，资源和提示词都会发出 `notifications/list_changed`。一个刚导入了 20 条新笔记的笔记服务器发出 `notifications/resources/list_changed`；客户端重新调用 `resources/list` 以获取新增内容。

### 内容类型约定

文本：`mimeType: "text/plain"`、`text/markdown`、`application/json`。
二进制：`image/png`、`application/pdf`，加上 `blob` 字段。
MCP App（第 14 课）：`ui://` URI 中的 `text/html;profile=mcp-app`。

### 动态资源

资源 URI 不必对应于静态文件。`notes://recent` 可以在每次读取时返回最新的五条笔记。`db://query/users/active` 可以执行参数化查询。服务器可以自由地动态计算内容。

规则：如果客户端可以按 URI 缓存，URI 必须是稳定的。如果计算是一次性的，URI 应包含时间戳或 nonce，使客户端缓存不会过期。

### 订阅 vs 轮询

支持订阅的客户端通过 `notifications/resources/updated` 获得服务器推送。不支持订阅的客户端或宿主通过重新读取来轮询。两者都符合规范。服务器的能力声明告诉客户端它支持哪种方式。

订阅的成本：服务器上每个会话的状态（谁订阅了什么）。保持订阅集合有界；断开连接的客户端应超时。

### 提示词 vs 系统提示词

MCP 中的提示词不是系统提示词。宿主的系统提示词（其自身的操作指令）和 MCP 提示词（由用户调用的服务器提供模板）并存。一个行为良好的客户端永远不会让服务器提示词覆盖自己的系统提示词；它分层处理。

## 使用它

`code/main.py` 扩展了第 07 课的笔记服务器，新增：

- 每个笔记的资源（`notes://note-1` 等），支持 `resources/subscribe`。
- 一个 `review_note` 提示词，渲染为三消息模板。
- 一个文件监视器模拟，当笔记被修改时发出 `notifications/resources/updated`。
- 一个 `notes://recent` 动态资源，始终返回最新五条笔记。

运行演示以查看完整流程。

## 交付成果

本课产出 `outputs/skill-primitive-splitter.md`。给定一个拟建的 MCP 服务器，该技能将每个能力归类为工具/资源/提示词，并附有理由。

## 练习

1. 运行 `code/main.py`。观察初始资源列表，然后触发一次笔记编辑，验证 `notifications/resources/updated` 事件触发。

2. 添加一个 `resources/list_changed` 发射器：当创建新笔记时，发送通知以便客户端重新发现。

3. 为 GitHub MCP 服务器设计三个提示词：`summarize_pr`、`triage_issue`、`release_notes`。每个都带有参数 Schema。提示词正文应无需进一步编辑即可运行。

4. 选第 07 课服务器中的一个现有工具，分类它是应该保持为工具，还是拆分为资源加工具对。用一句话说明理由。

5. 阅读规范的 `server/resources` 和 `server/prompts` 部分。找出 `resources/read` 中很少填充但规范支持的一个字段。提示：查看资源内容上的 `_meta`。

## 关键术语

| 术语 | 人们的说法 | 实际含义 |
|------|----------------|------------------------|
| 资源（Resource） | "暴露的数据" | 宿主可以读取的 URI 可寻址内容 |
| 资源 URI（Resource URI） | "数据指针" | Scheme 前缀标识符（`file://`、`notes://` 等）|
| `resources/subscribe` | "监听变更" | 客户端主动选择特定 URI 的服务器推送更新 |
| `notifications/resources/updated` | "资源已变更" | 向客户端发出信号，订阅的资源有新内容 |
| 资源模板（Resource Template） | "参数化 URI" | 带有补全提示的 URI 模式，供宿主选择器使用 |
| 提示词（Prompt） | "斜杠命令模板" | 带有参数槽的命名多消息模板 |
| 提示词参数（Prompt Arguments） | "模板输入" | 宿主在渲染前收集的类型化参数 |
| `prompts/get` | "渲染模板" | 服务器返回填充后的消息列表 |
| Content Block | "类型化块" | `{type: text | image | resource | ui_resource}` |
| 斜杠命令 UX（Slash-Command UX） | "用户快捷方式" | 宿主将提示词展示为以 `/` 开头的命令 |

## 延伸阅读

- [MCP — Concepts: Resources](https://modelcontextprotocol.io/docs/concepts/resources) —— 资源 URI、订阅和模板
- [MCP — Concepts: Prompts](https://modelcontextprotocol.io/docs/concepts/prompts) —— 提示词模板和斜杠命令集成
- [MCP — Server resources spec 2025-11-25](https://modelcontextprotocol.io/specification/2025-11-25/server/resources) —— 完整的 `resources/*` 消息参考
- [MCP — Server prompts spec 2025-11-25](https://modelcontextprotocol.io/specification/2025-11-25/server/prompts) —— 完整的 `prompts/*` 消息参考
- [MCP — Protocol info site: resources](https://modelcontextprotocol.info/docs/concepts/resources/) —— 社区指南，扩展了官方文档