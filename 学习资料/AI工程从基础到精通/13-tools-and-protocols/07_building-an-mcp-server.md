# 构建 MCP 服务器 —— Python + TypeScript SDK

> 大多数 MCP 教程只展示 stdio 的 Hello World。一个真正的服务器需要暴露工具、资源和提示词，处理能力协商，发出结构化错误，并且在不同的 SDK 之间行为一致。本课端到端构建一个笔记服务器：标准库 stdio 传输、JSON-RPC 分发、三个服务器端原语，以及一种纯函数风格，可以在你升级时无缝迁移到 Python SDK 的 FastMCP 或 TypeScript SDK。

**类型：** 构建
**语言：** Python（标准库，stdio MCP 服务器）
**前置知识：** Phase 13 · 06（MCP 基础）
**时间：** ~75 分钟

## 学习目标

- 实现 `initialize`、`tools/list`、`tools/call`、`resources/list`、`resources/read`、`prompts/list` 和 `prompts/get` 方法。
- 编写一个分发循环，从 stdin 读取 JSON-RPC 消息并将响应写入 stdout。
- 按照 JSON-RPC 2.0 规范和 MCP 的额外代码发出结构化错误响应。
- 将标准库实现升级到 FastMCP（Python SDK）或 TypeScript SDK，无需重写工具逻辑。

## 问题

在你可以使用远程传输（Phase 13 · 09）或认证层（Phase 13 · 16）之前，你需要一个干净的本地服务器。本地意味着 stdio：服务器由客户端作为子进程启动，消息通过 stdin/stdout 以换行分隔的方式进行传输。

2025-11-25 规范规定 stdio 消息被编码为 JSON 对象，带有显式的 `\n` 分隔符。这里没有 SSE；SSE 是旧的远程模式，正在 2026 年年中被移除（Atlassian 的 Rovo MCP 服务器于 2026 年 6 月 30 日弃用了它；Keboola 于 2026 年 4 月 1 日弃用）。对于 stdio，每行一个 JSON 对象就是全部的传输格式。

笔记服务器是一个很好的形态，因为它演练了所有三个服务器端原语。工具（Tools）执行变更（`notes_create`）。资源（Resources）暴露数据（`notes://{id}`）。提示词（Prompts）提供模板（`review_note`）。本课的形态可以推广到任何领域。

## 核心概念

### 分发循环

```
loop:
  line = stdin.readline()
  msg = json.loads(line)
  if has id:
    handle request -> write response
  else:
    handle notification -> no response
```

三条规则：

- 不要向 stdout 打印任何不是 JSON-RPC 信封的内容。调试日志输出到 stderr。
- 每个请求 MUST 匹配一个携带相同 `id` 的响应。
- 通知 MUST NOT 被响应。

### 实现 `initialize`

```python
def initialize(params):
    return {
        "protocolVersion": "2025-11-25",
        "capabilities": {
            "tools": {"listChanged": True},
            "resources": {"listChanged": True, "subscribe": False},
            "prompts": {"listChanged": False},
        },
        "serverInfo": {"name": "notes", "version": "1.0.0"},
    }
```

只声明你支持的内容。客户端依赖能力集来门控特性。

### 实现 `tools/list` 和 `tools/call`

`tools/list` 返回 `{tools: [...]}`，每个条目包含 `name`、`description`、`inputSchema`。`tools/call` 接收 `{name, arguments}` 并返回 `{content: [blocks], isError: bool}`。

内容块是类型化的。最常见的：

```json
{"type": "text", "text": "Found 2 notes"}
{"type": "resource", "resource": {"uri": "notes://14", "text": "..."}}
{"type": "image", "data": "<base64>", "mimeType": "image/png"}
```

工具错误有两种形态。协议级错误（未知方法、错误参数）是 JSON-RPC 错误。工具级错误（有效调用但工具失败）以 `{content: [...], isError: true}` 的形式返回。这让模型能在上下文中看到失败信息。

### 实现资源

资源被设计为只读的。`resources/list` 返回清单；`resources/read` 返回内容。URI 可以是 `file://...`、`http://...` 或自定义 scheme，如 `notes://`。

当你将数据作为资源而非工具暴露时：

- 模型不会"调用"它；客户端可以在用户请求时将其注入上下文。
- 当资源发生变化时，订阅（Subscription）允许服务器推送更新（Phase 13 · 10）。
- Phase 13 · 14 通过 `ui://` 将其扩展为交互式资源。

### 实现提示词

提示词是带有命名参数的模板。宿主将它们显示为斜杠命令。一个 `review_note` 提示词可能接收一个 `note_id` 参数，并生成一个多消息提示词模板，客户端将其提供给自己的模型。

### stdio 传输的微妙之处

- 换行分隔的 JSON。不是长度前缀分帧。
- 不要缓冲。每次写入后调用 `sys.stdout.flush()`。
- 客户端控制生命周期。当 stdin 关闭（EOF）时，干净地退出。
- 不要静默处理 SIGPIPE；记录日志并退出。

### 注解（Annotations）

每个工具可以携带描述安全属性的 `annotations`：

- `readOnlyHint: true` —— 纯读取，可以安全重试。
- `destructiveHint: true` —— 不可逆的副作用；客户端应确认。
- `idempotentHint: true` —— 相同的输入产生相同的输出。
- `openWorldHint: true` —— 与外部系统交互。

客户端利用这些来决策 UX（确认对话框、状态指示器）和路由（Phase 13 · 17）。

### 升级路径

`code/main.py` 中的标准库服务器大约 180 行。FastMCP（Python）将同样的逻辑压缩为装饰器风格：

```python
from fastmcp import FastMCP
app = FastMCP("notes")

@app.tool()
def notes_search(query: str, limit: int = 10) -> list[dict]:
    ...
```

TypeScript SDK 有等价的形态。升级路径是即插即用的，概念（能力、分发、内容块）是相同的。

## 使用它

`code/main.py` 是一个完整的笔记 MCP 服务器，通过 stdio 通信，仅使用标准库。它处理 `initialize`、三个工具（`notes_list`、`notes_search`、`notes_create`）的 `tools/list` 和 `tools/call`、每个笔记的 `resources/list` 和 `resources/read`，以及一个 `review_note` 提示词。你可以通过管道发送 JSON-RPC 消息来驱动它：

```
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' | python main.py
```

需要关注的点：

- 分发器是一个以方法名为键的 `dict[str, Callable]`。
- 每个工具执行器返回一个内容块列表，而不是裸字符串。
- 当执行器抛出异常时设置 `isError: true`。

## 交付成果

本课产出 `outputs/skill-mcp-server-scaffolder.md`。给定一个领域（笔记、工单、文件、数据库），该技能为 MCP 服务器搭建框架，包含正确的工具/资源/提示词划分和 SDK 升级路径。

## 练习

1. 运行 `code/main.py`，用手工构建的 JSON-RPC 消息驱动它。演练 `notes_create`，然后 `resources/read` 来检索新笔记。

2. 添加一个带 `annotations: {destructiveHint: true}` 的 `notes_delete` 工具。验证客户端会弹出确认对话框（这需要一个真实的宿主；Claude Desktop 可以）。

3. 实现 `resources/subscribe`，使服务器在笔记被修改时推送 `notifications/resources/updated`。添加一个保活任务。

4. 将服务器移植到 FastMCP。Python 文件应缩小到 80 行以内。线上行为必须相同；用相同的 JSON-RPC 测试程序验证。

5. 阅读规范的 `server/tools` 部分，找出本课服务器未实现的一个工具定义字段。（提示：有好几个；选一个并添加它。）

## 关键术语

| 术语 | 人们的说法 | 实际含义 |
|------|----------------|------------------------|
| MCP 服务器 | "暴露工具的东西" | 通过 stdio 或 HTTP 使用 MCP JSON-RPC 的进程 |
| stdio 传输（Stdio Transport） | "子进程模式" | 服务器由客户端启动；通过 stdin/stdout 通信 |
| 分发器（Dispatcher） | "方法路由器" | JSON-RPC 方法名到处理函数的映射 |
| Content Block | "工具结果块" | 工具响应中 `content` 数组的类型化元素 |
| `isError` | "工具级失败" | 表示工具失败；与 JSON-RPC 错误区分 |
| Annotations | "安全提示" | readOnly / destructive / idempotent / openWorld 标志 |
| FastMCP | "Python SDK" | MCP 协议之上的装饰器风格高级框架 |
| Resource URI | "可寻址数据" | 标识资源的 `file://`、`db://` 或自定义 scheme |
| Prompt Template | "斜杠命令简述" | 服务器提供的模板，带有供宿主 UI 使用的参数槽 |
| Capability Declaration | "特性开关" | 在 `initialize` 中声明的每个原语的标志 |

## 延伸阅读

- [Model Context Protocol — Python SDK](https://github.com/modelcontextprotocol/python-sdk) —— 参考 Python 实现
- [Model Context Protocol — TypeScript SDK](https://github.com/modelcontextprotocol/typescript-sdk) —— 并行的 TypeScript 实现
- [FastMCP — server framework](https://gofastmcp.com/) —— MCP 服务器的装饰器风格 Python API
- [MCP — Quickstart server guide](https://modelcontextprotocol.io/quickstart/server) —— 使用任一 SDK 的端到端教程
- [MCP — Server tools spec](https://modelcontextprotocol.io/specification/2025-11-25/server/tools) —— tools/* 消息的完整参考