# MCP Apps —— 通过 `ui://` 的交互式 UI 资源

> 纯文本的工具输出限制了 Agent 能展示的内容。MCP Apps（SEP-1724，2026 年 1 月 26 日正式发布）允许工具返回在 Claude Desktop、ChatGPT、Cursor、Goose 和 VS Code 中内联渲染的沙盒化交互式 HTML。仪表盘、表单、地图、3D 场景，全部通过一个扩展实现。本课讲解 `ui://` 资源方案、`text/html;profile=mcp-app` MIME 类型、iframe 沙盒 postMessage 协议，以及允许服务器渲染 HTML 所带来的安全攻击面。

**类型：** 构建
**语言：** Python（标准库，UI 资源发射器），HTML（示例应用）
**前置要求：** Phase 13 · 07（MCP 服务器），Phase 13 · 10（资源）
**时间：** ~75 分钟

## 学习目标

- 从工具调用中返回 `ui://` 资源并设置正确的 MIME 类型和元数据。
- 使用 `_meta.ui.resourceUri`、`_meta.ui.csp` 和 `_meta.ui.permissions` 声明工具关联的 UI。
- 实现用于 UI 到宿主机通信的 iframe 沙盒 postMessage JSON-RPC 协议。
- 应用能防御源自 UI 的攻击的 CSP 和权限策略默认值。

## 问题

2025 年代的一个 `visualize_timeline` 工具可以返回 "以下是按时间顺序排列的 14 条笔记：……"。这只是一段文字。用户真正想要的是交互式时间线。在 MCP Apps 出现之前，选项只有：客户端特有的小部件 API（Claude artifacts、OpenAI Custom GPT HTML），或者完全没有 UI。

MCP Apps（SEP-1724，2026 年 1 月 26 日发布）标准化了这一契约。工具结果包含一个 `resource`，其 URI 为 `ui://...`，MIME 类型为 `text/html;profile=mcp-app`。宿主机会在一个沙盒化的 iframe 中渲染它，附带有限的 CSP，并且除非显式授予否则无网络访问权限。iframe 内的 UI 通过一个微小的 postMessage JSON-RPC 方言向宿主机发送消息。

每个兼容的客户端（Claude Desktop、ChatGPT、Goose、VS Code）以相同的方式渲染相同的 `ui://` 资源。一个服务器，一个 HTML 包，通用的 UI。

## 概念

### `ui://` 资源方案

工具返回：

```json
{
  "content": [
    {"type": "text", "text": "Here is your notes timeline:"},
    {"type": "ui_resource", "uri": "ui://notes/timeline"}
  ],
  "_meta": {
    "ui": {
      "resourceUri": "ui://notes/timeline",
      "csp": {
        "defaultSrc": "'self'",
        "scriptSrc": "'self' 'unsafe-inline'",
        "connectSrc": "'self'"
      },
      "permissions": []
    }
  }
}
```

宿主机随后对 `ui://notes/timeline` URI 调用 `resources/read`，得到：

```json
{
  "contents": [{
    "uri": "ui://notes/timeline",
    "mimeType": "text/html;profile=mcp-app",
    "text": "<!doctype html>..."
  }]
}
```

### Iframe 沙盒

宿主机在沙盒化的 `<iframe>` 中渲染 HTML，配置如下：

- `sandbox="allow-scripts allow-same-origin"`（或根据服务器声明更严格）
- 通过响应头应用服务器声明的 CSP。
- 无 cookie，无从宿主机源的 localStorage。
- 网络访问限于 CSP 中的 `connectSrc`。

### postMessage 协议

iframe 通过 `window.postMessage` 与宿主机通信。这是一个微型的 JSON-RPC 2.0 方言：

始终将 `targetOrigin` 锁定为对端的确切源，接收端在处理任何负载之前验证 `event.origin` 是否在白名单中。切勿在此通道的任一侧使用 `"*"` —— 消息体中携带工具调用和资源读取。

```js
// iframe 到宿主机（锁定宿主机源）
window.parent.postMessage({
  jsonrpc: "2.0",
  id: 1,
  method: "host.callTool",
  params: { name: "notes_update", arguments: { id: "note-14", title: "..." } }
}, "https://host.example.com");

// 宿主机到 iframe（锁定 iframe 源）
iframe.contentWindow.postMessage({
  jsonrpc: "2.0",
  id: 1,
  result: { content: [...] }
}, "https://iframe.example.com");

// 两侧的接收方
window.addEventListener("message", (event) => {
  if (event.origin !== "https://expected-peer.example.com") return;
  // 安全地处理 event.data
});
```

UI 可调用的宿主机端方法：

- `host.callTool(name, arguments)` —— 调用服务器工具。
- `host.readResource(uri)` —— 读取 MCP 资源。
- `host.getPrompt(name, arguments)` —— 获取提示词模板。
- `host.close()` —— 关闭 UI。

每次调用仍通过 MCP 协议进行，并继承服务器的权限。

### 权限

`_meta.ui.permissions` 列表请求额外能力：

- `camera` —— 访问用户摄像头（用于扫描文档 UI）。
- `microphone` —— 语音输入。
- `geolocation` —— 位置信息。
- `network:*` —— 比单独使用 `connectSrc` 更广泛的网络访问。

每个权限都是在 UI 渲染前用户看到的提示。

### 安全风险

iframe 中的 HTML 仍然是 HTML。新的攻击面：

- **通过 UI 的提示注入。** 恶意服务器 UI 可以显示看起来像系统消息的文本并欺骗用户。宿主机渲染应在视觉上区分服务器 UI 和宿主机 UI。
- **通过 `connectSrc` 的数据外泄。** 如果 CSP 允许 `connect-src: *`，UI 可以将数据发送到任何地方。默认应严格。
- **点击劫持。** UI 覆盖宿主机界面。宿主机必须阻止 z-index 操纵并强制透明度规则。
- **焦点窃取。** UI 获取键盘焦点并捕获下一条消息。宿主机必须拦截。

Phase 13 · 15 作为 MCP 安全的一部分深入讨论这些内容；本课仅作介绍。

### `ui/initialize` 握手

iframe 加载后，它通过 postMessage 发送 `ui/initialize`：

```json
{"jsonrpc": "2.0", "id": 0, "method": "ui/initialize",
 "params": {"theme": "dark", "locale": "en-US", "sessionId": "..."}}
```

宿主机响应能力和会话令牌。UI 在后续每次宿主机调用中使用该会话令牌。

### AppRenderer / AppFrame SDK 原语

ext-apps SDK 暴露了两个便利原语：

- `AppRenderer`（服务器端） —— 包装 React / Vue / Solid 组件，发出带有正确 MIME 和元数据的 `ui://` 资源。
- `AppFrame`（客户端） —— 接收资源，挂载 iframe，并中介 postMessage 通信。

你可以使用这些原语，也可以手写 HTML 和 JSON-RPC。

### 生态系统状态

MCP Apps 于 2026 年 1 月 26 日发布。截至 2026 年 4 月的客户端支持情况：

- **Claude Desktop。** 自 2026 年 1 月起完全支持。
- **ChatGPT。** 通过 Apps SDK 完全支持（底层使用相同的 MCP Apps 协议）。
- **Cursor。** Beta 阶段；通过设置启用。
- **VS Code。** 仅 Insider 构建版本支持。
- **Goose。** 完全支持。
- **Zed、Windsurf。** 路线图中。

已上线的生产服务器包括：仪表盘、地图可视化、数据表格、图表构建器、沙盒 IDE 预览。

## 使用

`code/main.py` 扩展了笔记服务器，添加了一个 `visualize_timeline` 工具，该工具返回一个 `ui://notes/timeline` 资源，以及一个处理该 URI 上 `resources/read` 的处理器，该处理器返回一个完整的小型 HTML 包，包含 SVG 时间线。HTML 使用标准库模板生成 —— 无需构建系统。由于标准库无法驱动浏览器，postMessage 以 JS 注释形式勾勒。

需要关注的内容：

- 工具响应上的 `_meta.ui` 携带 resourceUri、CSP、权限。
- HTML 在无网络访问权限下渲染；所有数据都是内联的。
- JS 通过 `window.parent.postMessage` 调用 `host.callTool`（已文档化，但在此标准库演示中是惰性的）。

## 交付物

本课产出 `outputs/skill-mcp-apps-spec.md`。给定一个受益于交互式 UI 的工具，该技能生成完整的 MCP Apps 契约：`ui://` URI、CSP、权限、postMessage 入口点以及安全清单。

## 练习

1. 运行 `code/main.py` 并检查发出的 HTML。在浏览器中直接打开 HTML；验证 SVG 是否渲染。然后草拟 UI 用来调用 `host.callTool("notes_update", ...)` 的 postMessage 契约。

2. 收紧 CSP：移除 `'unsafe-inline'`，使用基于 nonce 的脚本策略。HTML 生成代码需要做哪些更改？

3. 添加第二个 UI 资源 `ui://notes/editor`，包含一个用于就地编辑笔记的表单。当用户提交时，iframe 调用 `host.callTool("notes_update", ...)`。

4. 审计 UI 的攻击面。恶意服务器可以在哪里注入内容？iframe 沙盒能防御什么，不能防御什么？

5. 阅读 SEP-1724 规范，找出此简易实现中未使用的 MCP Apps SDK 功能之一。（提示：组件级状态同步。）

## 关键术语

| 术语 | 常见说法 | 实际含义 |
|------|----------|----------|
| MCP Apps | "交互式 UI 资源" | 2026 年 1 月 26 日发布的 SEP-1724 扩展 |
| `ui://` | "App URI 方案" | UI 包的资源方案 |
| `text/html;profile=mcp-app` | "MIME 类型" | MCP App HTML 的内容类型 |
| Iframe sandbox（iframe 沙盒） | "渲染容器" | 使用 CSP 和权限对 UI 进行浏览器沙盒化 |
| postMessage JSON-RPC | "UI 到宿主机的通信通道" | 用于宿主机调用的微型 JSON-RPC-over-postMessage 方言 |
| `_meta.ui` | "工具-UI 绑定" | 将工具结果链接到 UI 资源的元数据 |
| CSP（内容安全策略） | "Content-Security-Policy" | 声明脚本、网络、样式的允许来源 |
| AppRenderer | "服务器 SDK 原语" | 将框架组件转换为 `ui://` 资源 |
| AppFrame | "客户端 SDK 原语" | 中介 postMessage 通信的 iframe 挂载辅助工具 |
| `ui/initialize` | "握手" | 从 UI 到宿主机的第一条 postMessage |

## 扩展阅读

- [MCP ext-apps — GitHub](https://github.com/modelcontextprotocol/ext-apps) — 参考实现与 SDK
- [MCP Apps specification 2026-01-26](https://github.com/modelcontextprotocol/ext-apps/blob/main/specification/2026-01-26/apps.mdx) — 正式规范文档
- [MCP — Apps extension overview](https://modelcontextprotocol.io/extensions/apps/overview) — 高层文档
- [MCP blog — MCP Apps launch](https://blog.modelcontextprotocol.io/posts/2026-01-26-mcp-apps/) — 2026 年 1 月发布文章
- [MCP Apps API reference](https://apps.extensions.modelcontextprotocol.io/api/) — JSDoc 风格的 SDK 参考