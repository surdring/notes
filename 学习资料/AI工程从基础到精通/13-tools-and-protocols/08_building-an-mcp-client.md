# 构建 MCP 客户端 —— 发现、调用、会话管理

> 大多数 MCP 内容提供服务器教程，对客户端部分只是一笔带过。客户端代码才是困难编排之所在：进程启动、能力协商、跨多个服务器的工具列表合并、采样回调、重连和命名空间冲突解决。本课构建一个多服务器客户端，将三个不同的 MCP 服务器提升为一个扁平的工具命名空间供模型使用。

**类型：** 构建
**语言：** Python（标准库，多服务器 MCP 客户端）
**前置知识：** Phase 13 · 07（构建 MCP 服务器）
**时间：** ~75 分钟

## 学习目标

- 将 MCP 服务器作为子进程启动，完成 `initialize`，并发送 `notifications/initialized`。
- 维护每个服务器的会话状态（能力、工具列表、最后看到的通知 ID）。
- 将跨多个服务器的工具列表合并为一个命名空间，并处理冲突。
- 将工具调用路由到拥有该工具的服务器，并重组响应。

## 问题

一个真正的 Agent 宿主（Claude Desktop、Cursor、Goose、Gemini CLI）同时加载多个 MCP 服务器。一个用户可能同时运行着一个文件系统服务器、一个 Postgres 服务器和一个 GitHub 服务器。客户端的工作：

1. 启动每个服务器。
2. 独立与每个服务器握手。
3. 对每个服务器调用 `tools/list` 并将结果展平。
4. 当模型发出 `notes_search` 时，在合并的命名空间中查找并路由到正确的服务器。
5. 在不阻塞的情况下处理来自任何服务器的通知（`tools/list_changed`）。
6. 在传输失败时重连。

手工完成所有这些，正是"玩具"与"可用"之间的区别。官方 SDK 封装了这些，但思维模型必须是你自己的。

## 核心概念

### 子进程启动

`subprocess.Popen`，设置 `stdin=PIPE, stdout=PIPE, stderr=PIPE`。设置 `bufsize=1` 并使用文本模式进行逐行读取。每个服务器是一个进程；客户端为每个服务器持有一个 `Popen` 句柄。

### 每个服务器的会话状态

每个服务器一个 `Session` 对象，包含：

- `process` —— Popen 句柄。
- `capabilities` —— 服务器在 `initialize` 时声明的内容。
- `tools` —— 最后一次 `tools/list` 的结果。
- `pending` —— 请求 ID 到等待响应的 Promise/Future 的映射。

请求本质上是异步的；发送到服务器 A 的 `tools/call` 在服务器 B 正在执行调用时不应阻塞。可以使用线程加队列或 asyncio。

### 合并命名空间

当客户端看到聚合的工具列表时，名称可能会冲突。两个服务器可能都暴露了 `search`。客户端有三种选择：

1. **按服务器名称前缀。** `notes/search`、`files/search`。清晰但不够美观。
2. **静默先到先得。** 后到的服务器的 `search` 覆盖先前的。有风险；隐藏了冲突。
3. **冲突拒绝。** 拒绝加载第二个服务器；通知用户。对安全敏感的宿主来说最安全。

Claude Desktop 使用按服务器前缀。Cursor 使用冲突拒绝并给出明确的错误。VS Code MCP 也采用按服务器前缀。

### 路由

合并后，一个分发表将 `tool_name -> session` 映射起来。模型按名称发出调用；客户端找到 session 并向该服务器的 stdin 写入 `tools/call` 消息，然后等待响应。

### 采样回调

如果服务器在 `initialize` 时声明了 `sampling` 能力，它可能会发送 `sampling/createMessage`，请求客户端运行其 LLM。客户端必须：

1. 在采样解决之前阻止向该服务器发送进一步的请求，或者如果其实现支持并发则进行流水线处理。
2. 调用其 LLM 提供商。
3. 将响应发送回服务器。

第 11 课端到端介绍采样。本课为完整性提供存根。

### 通知处理

`notifications/tools/list_changed` 意味着重新调用 `tools/list`。`notifications/resources/updated` 意味着如果正在使用该资源则重新读取。通知不得产生响应——不要尝试对它们发送 ACK。

一个常见的客户端 bug：在 `tools/call` 上阻塞读取循环，而一个通知停留在流中。使用一个后台读取线程，将每条消息推送到队列中；主线程出队并分发。

### 重连

传输可能失败：服务器崩溃、操作系统终止进程、stdio 管道断裂。客户端在 stdout 上检测到 EOF，并将 session 视为已死。选项：

- 静默重启服务器并重新握手。对纯只读服务器可以。
- 将失败呈现给用户。对有状态的服务器和用户可见的会话可以。

Phase 13 · 09 介绍 Streamable HTTP 重连语义；stdio 更简单。

### 保活和会话 ID

Streamable HTTP 使用 `Mcp-Session-Id` 头部。Stdio 没有会话 ID——进程的身份就是会话。保活 ping 是可选的；stdio 管道不会因不活动而断裂。

## 使用它

`code/main.py` 将三个模拟 MCP 服务器作为子进程启动，与每个服务器握手，合并它们的工具列表，并将工具调用路由到正确的一个。"服务器"实际上是运行玩具响应器的其他 Python 进程（没有真实的 LLM）。运行它以查看：

- 三次初始化，每个都有各自的能力集。
- 三个 `tools/list` 结果合并为一个包含 7 个工具的命名空间。
- 基于工具名称的路由决策。
- 通过命名空间前缀防止冲突。

需要关注的点：

- `Session` 数据类干净地保存每个服务器的状态。
- 后台读取线程逐行出队 stdout，不阻塞主线程。
- 分发表是一个简单的 `dict[str, Session]`。
- 冲突处理是显式的：当两个服务器声明相同的名称时，后者被加上前缀重命名。

## 交付成果

本课产出 `outputs/skill-mcp-client-harness.md`。给定一个声明式 MCP 服务器列表（名称、命令、参数），该技能生成一个测试程序，启动它们、合并工具列表，并提供一个带冲突解决的路由函数。

## 练习

1. 运行 `code/main.py`，观察服务器启动日志。用 SIGTERM 终止一个模拟服务器进程，观察客户端如何检测 EOF 并将该会话标记为已死。

2. 实现命名空间前缀。当两个服务器暴露 `search` 时，将第二个重命名为 `<server>/search`。更新分发表并验证工具调用正确路由。

3. 为服务器重启添加连接池风格的退避：连续失败时指数退避，上限 30 秒，在三次失败后向用户发出通知。

4. 勾勒一个支持 100 个并发 MCP 服务器的客户端。什么数据结构取代简单的分发字典？（提示：使用前缀命名空间的 trie，加上每个服务器工具数量的指标。）

5. 将客户端移植到官方 MCP Python SDK。SDK 封装了 `stdio_client` 和 `ClientSession`。代码应从约 200 行缩减到约 40 行，同时保留多服务器路由。

## 关键术语

| 术语 | 人们的说法 | 实际含义 |
|------|----------------|------------------------|
| MCP 客户端 | "Agent 宿主" | 启动服务器并编排工具调用的进程 |
| Session | "每个服务器的状态" | 能力、工具列表和待处理请求的簿记 |
| 合并命名空间（Merged Namespace） | "一个工具列表" | 所有活跃服务器中工具名称的扁平集合 |
| 命名空间冲突（Namespace Collision） | "两个服务器相同工具" | 客户端必须对重复项加前缀、拒绝或先到先得 |
| 路由（Routing） | "谁来处理这个调用？" | 从工具名称分发到拥有该工具的服务器 |
| 后台读取器（Background Reader） | "非阻塞 stdout" | 将服务器 stdout 流入队列的线程或任务 |
| 采样回调（Sampling Callback） | "LLM 即服务" | 客户端对来自服务器的 `sampling/createMessage` 的处理程序 |
| `notifications/*_changed` | "原语已变更" | 客户端必须重新发现或重新读取的信号 |
| 重连策略（Reconnection Policy） | "服务器挂了怎么办" | 传输失败时的重启语义 |
| Stdio Session | "进程 = 会话" | 无会话 ID；子进程生命周期即是会话 |

## 延伸阅读

- [Model Context Protocol — Client spec](https://modelcontextprotocol.io/specification/2025-11-25/client) —— 规范客户端行为
- [MCP — Quickstart client guide](https://modelcontextprotocol.io/quickstart/client) —— 使用 Python SDK 的 Hello World 客户端教程
- [MCP Python SDK — client module](https://github.com/modelcontextprotocol/python-sdk) —— 参考 `ClientSession` 和 `stdio_client`
- [MCP TypeScript SDK — Client](https://github.com/modelcontextprotocol/typescript-sdk) —— TypeScript 并行实现
- [VS Code — MCP in extensions](https://code.visualstudio.com/api/extension-guides/ai/mcp) —— VS Code 如何在单个编辑器宿主中复用多个 MCP 服务器