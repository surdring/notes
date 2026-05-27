# MCP 传输层 —— stdio vs Streamable HTTP vs SSE 迁移

> stdio 在本地工作，其他地方不行。Streamable HTTP（2025-03-26）是远程标准。旧的 HTTP+SSE 传输已被弃用，并将在 2026 年年中被移除。选错传输层代价是一次迁移；选对传输层则获得一个可远程托管的 MCP 服务器，具有会话连续性和 DNS 重绑定防护。

**类型：** 学习
**语言：** Python（标准库，Streamable HTTP 端点骨架）
**前置知识：** Phase 13 · 07、08（MCP 服务器和客户端）
**时间：** ~45 分钟

## 学习目标

- 根据部署形态（本地 vs 远程、单进程 vs 集群）在 stdio 和 Streamable HTTP 之间做出选择。
- 实现 Streamable HTTP 单端点模式：POST 用于请求，GET 用于会话流。
- 强制执行 `Origin` 验证和会话 ID 语义以防御 DNS 重绑定。
- 在 2026 年年中的移除截止日期之前将旧的 HTTP+SSE 服务器迁移到 Streamable HTTP。

## 问题

第一个 MCP 远程传输（2024-11）是 HTTP+SSE：两个端点，一个用于客户端的 POST，一个服务器发送事件（Server-Sent Events）通道用于服务器到客户端的流。它工作过。它也很笨拙：每个会话两个端点、某些 CDN 前面的缓存被破坏，以及对长生命周期 SSE 连接的硬依赖——某些 WAF 会激进地终止这种连接。

2025-03-26 规范将其替换为 Streamable HTTP：一个端点，POST 用于客户端请求，GET 用于建立会话流，两者共享 `Mcp-Session-Id` 头部。此后构建或迁移的每个服务器都使用 Streamable HTTP。旧的 SSE 模式正在被弃用——Atlassian Rovo 于 2026 年 6 月 30 日将其移除；Keboola 于 2026 年 4 月 1 日；大多数剩余的企业服务器在 2026 年底之前移除。

而 stdio 对于本地服务器仍然重要。Claude Desktop、VS Code 和每个 IDE 形态的客户端都通过 stdio 启动服务器。正确的思维模型：stdio 用于"本机"，Streamable HTTP 用于"网络传输"。没有交叉。

## 核心概念

### stdio

- 子进程传输。客户端启动服务器，通过 stdin/stdout 通信。
- 每行一个 JSON 对象。换行分隔。
- 无会话 ID；进程身份就是会话。
- 无需认证（子进程继承父进程的信任边界）。
- 绝不用于远程服务器——你需要 SSH 或 socat 做隧道，此时直接用 Streamable HTTP。

### Streamable HTTP

单个端点 `/mcp`（或任意路径）。支持三种 HTTP 方法：

- **POST /mcp。** 客户端发送 JSON-RPC 消息。服务器回复单个 JSON 响应，或者一个包含一个或多个响应的 SSE 流（用于与该请求相关的批量响应和通知）。
- **GET /mcp。** 客户端打开一个长生命周期 SSE 通道。服务器用它进行服务器到客户端的请求（采样、通知、引导）。
- **DELETE /mcp。** 客户端显式终止会话。

会话由 `Mcp-Session-Id` 头部标识，服务器在第一个响应上设置，客户端在后续每个请求上回显。会话 ID 必须是密码学随机的（128+ 位）；客户端选择的 ID 因安全性被拒绝。

### 单端点 vs 双端点

来自旧规范的双端点模式在 2026 年仍可调用——规范声明其"兼容旧版"。但所有新服务器都应是单端点的。官方 SDK 生成单端点；仅在需要与未迁移的远程服务器通信时使用旧模式。

### `Origin` 验证与 DNS 重绑定

浏览器不是 MCP 客户端（目前），但攻击者可以制作一个网页，诱导浏览器 POST 到 `localhost:1234/mcp`——即用户的本地 MCP 服务器监听的地方。如果服务器不检查 `Origin`，浏览器的同源策略将无法保护它，因为 `Origin: http://evil.com` 是一个有效的跨域请求。

2025-11-25 规范要求服务器拒绝 `Origin` 不在白名单中的请求。白名单通常包含 MCP 客户端宿主（`https://claude.ai`、`vscode-webview://*`）和用于本地 UI 的 localhost 变体。

### 会话 ID 生命周期

1. 客户端发送第一个请求，不带 `Mcp-Session-Id`。
2. 服务器分配一个随机 ID，在响应头中设置 `Mcp-Session-Id`。
3. 客户端在所有后续请求和用于流的 `GET /mcp` 上回显该头部。
4. 服务器可以撤销会话；客户端在后续请求中看到 404，必须重新初始化。
5. 客户端可以显式 DELETE 会话以实现干净关闭。

### 保活与重连

SSE 连接会中断。客户端通过使用相同的 `Mcp-Session-Id` 重新 GET 来重建。服务器 MUST 将中断期间错过的事件排队（在合理的时间窗口内），并通过客户端回显的 `last-event-id` 头部重放。

Phase 13 · 13 介绍 Task，它允许长时间运行的工作在完整的会话重连后仍然存活。

### 向后兼容探测

一个希望同时支持新旧服务器的客户端：

1. POST 到 `/mcp`。
2. 如果响应是 `200 OK`，包含 JSON 或 SSE，这是 Streamable HTTP。
3. 如果响应是 `200 OK`，`Content-Type: text/event-stream` 且有一个 `Location` 头指向二级端点，这是旧的 HTTP+SSE；跟随 `Location`。

### Cloudflare、ngrok 与托管

2026 年的生产级远程 MCP 服务器运行在 Cloudflare Workers（使用其 MCP Agents SDK）、Vercel Functions 或容器化的 Node/Python 上。关键：你的托管必须支持用于 SSE GET 的长生命周期 HTTP 连接。Vercel 免费层限制为 10 秒，不适合。Cloudflare Workers 支持无限流。

### 网关组合

当你用一个网关（Phase 13 · 17）作为多个 MCP 服务器的前端时，网关是一个单一的 Streamable HTTP 端点，它重写会话 ID 并向上游多路复用。工具在网关层合并；客户端看到的是一个单一的、逻辑上的服务器。

### 传输失败模式

- **stdio SIGPIPE。** 子进程在写入中死亡抛出 SIGPIPE；服务器应干净退出。客户端应检测 EOF 并将会话标记为已死。
- **HTTP 502 / 504。** Cloudflare、nginx 等代理在上游失败时发出这些错误。Streamable HTTP 客户端应在短暂退避后重试一次。
- **SSE 连接中断。** TCP RST、代理超时或客户端网络变更关闭流。客户端使用 `Mcp-Session-Id` 和可选的 `last-event-id` 重连以恢复。
- **会话撤销。** 服务器使会话 ID 失效；客户端在下一次请求中看到 404。客户端必须重新握手。
- **时钟偏差。** 客户端上的资源 TTL 计算与服务器不一致。客户端应将服务器时间戳视为权威。

### 何时绕过 Streamable HTTP

一些企业在内部网络中部署带有 gRPC 或消息队列传输的 MCP 服务器。这是非标准的——MCP 的规范没有正式定义这些。网关可以向 MCP 客户端暴露一个 Streamable HTTP 接口，而内部使用 gRPC。保持外部接口符合规范；网关负责转换。

## 使用它

`code/main.py` 使用 `http.server`（标准库）实现一个最小的 Streamable HTTP 端点。它处理 `/mcp` 上的 POST、GET 和 DELETE，在第一个响应上设置 `Mcp-Session-Id`，验证 `Origin`，并拒绝来自非白名单源的请求。处理程序复用了第 07 课笔记服务器的分发逻辑。

需要关注的点：

- POST 处理程序读取 JSON-RPC 正文，分发，并写入 JSON 响应（单响应变体；SSE 变体结构类似）。
- `Origin` 检查拒绝默认的 `http://evil.example` 探测，但接受 `http://localhost`。
- 会话 ID 是随机的 128 位十六进制字符串；服务器在内存中保存每个会话的状态。

## 交付成果

本课产出 `outputs/skill-mcp-transport-migrator.md`。给定一个 HTTP+SSE（旧版）MCP 服务器，该技能生成一个迁移计划，迁移到 Streamable HTTP，包含会话 ID 连续性、Origin 检查和向后兼容探测支持。

## 练习

1. 运行 `code/main.py`。用 `curl` 发送一个 `initialize` POST，观察 `Mcp-Session-Id` 响应头。发送第二个请求，回显该头部，验证会话连续性。

2. 添加一个 GET 处理程序，打开一个 SSE 流。每五秒发送一个 `notifications/progress` 事件。使用相同的会话 ID 重新 GET 来重连，确认服务器接受。

3. 实现 `last-event-id` 重放逻辑。重连时，重放自该 ID 以来生成的任何事件。

4. 扩展 `Origin` 验证以支持通配符模式（`https://*.example.com`），确认它接受 `https://app.example.com` 但拒绝 `https://evil.example.com.attacker.net`。

5. 从官方注册中心选一个旧版 HTTP+SSE 服务器（有好几个），勾勒迁移方案：端点处理、会话 ID 生成和头部语义方面需要哪些变更。

## 关键术语

| 术语 | 人们的说法 | 实际含义 |
|------|----------------|------------------------|
| stdio 传输 | "本地子进程" | JSON-RPC 通过 stdin/stdout，换行分隔 |
| Streamable HTTP | "远程传输" | 单端点 POST + GET + 可选 SSE，2025-03-26 规范 |
| HTTP+SSE | "旧版" | 双端点模式，将在 2026 年年中被移除 |
| `Mcp-Session-Id` | "会话头部" | 服务器分配的随机 ID，在后续每个请求中回显 |
| `Origin` 白名单 | "DNS 重绑定防御" | 拒绝 Origin 不在批准列表中的请求 |
| 单端点（Single Endpoint） | "一个 URL" | `/mcp` 处理所有会话操作的 POST / GET / DELETE |
| `last-event-id` | "SSE 重放" | 用于在不停机丢失事件的情况下恢复中断流的头部 |
| 向后兼容探测（Backwards-Compat Probe） | "新旧检测" | 客户端响应形态检查，自动选择传输方式 |
| 长生命周期 HTTP | "SSE 流" | 服务器在一个 TCP 连接上推送事件数分钟或数小时 |
| 会话撤销（Session Revocation） | "强制重新初始化" | 服务器使会话 ID 失效；客户端必须重新握手 |

## 延伸阅读

- [MCP — Basic transports spec 2025-11-25](https://modelcontextprotocol.io/specification/2025-11-25/basic/transports) —— stdio 和 Streamable HTTP 的权威参考
- [MCP — Basic transports spec 2025-03-26](https://modelcontextprotocol.io/specification/2025-03-26/basic/transports) —— 引入 Streamable HTTP 的版本
- [Cloudflare — MCP transport](https://developers.cloudflare.com/agents/model-context-protocol/transport/) —— Workers 托管的 Streamable HTTP 模式
- [AWS — MCP transport mechanisms](https://builder.aws.com/content/35A0IphCeLvYzly9Sw40G1dVNzc/mcp-transport-mechanisms-stdio-vs-streamable-http) —— 不同部署形态的比较
- [Atlassian — HTTP+SSE deprecation notice](https://community.atlassian.com/forums/Atlassian-Remote-MCP-Server/HTTP-SSE-Deprecation-Notice/ba-p/3205484) —— 具体的迁移截止日期示例