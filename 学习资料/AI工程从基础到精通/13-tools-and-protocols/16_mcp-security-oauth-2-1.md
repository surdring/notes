# MCP 安全 II —— OAuth 2.1、资源指示器、增量权限

> 远程 MCP 服务器需要授权，而不仅仅是认证。2025 年 11 月 25 日规范与 OAuth 2.1 + PKCE + 资源指示器（RFC 8707）+ 受保护资源元数据（RFC 9728）对齐。SEP-835 新增增量权限同意，通过 403 WWW-Authenticate 实现逐步授权。本课将逐步授权流程实现为一个状态机，让你可以观察每一步。

**类型：** 构建
**语言：** Python（标准库，OAuth 状态机模拟器）
**前置要求：** Phase 13 · 09（传输层），Phase 13 · 15（安全 I）
**时间：** ~75 分钟

## 学习目标

- 区分资源服务器和授权服务器的职责。
- 遍历受 PKCE 保护的 OAuth 2.1 授权码流程。
- 使用 `resource`（RFC 8707）和受保护资源元数据（RFC 9728）防止混淆代理攻击。
- 实现逐步授权：服务器响应 403 并附带 WWW-Authenticate，要求更高的权限范围；客户端重新提示用户同意并重试。

## 问题

早期的 MCP（2025 年之前）为远程服务器提供了临时 API 密钥甚至完全没有认证。2025 年 11 月 25 日规范通过完整的 OAuth 2.1 配置文件弥补了这一差距。

三种实际需求：

- **普通远程服务器。** 用户安装一个远程 MCP 服务器来访问他们的 Notion / GitHub / Gmail。OAuth 2.1 + PKCE 是正确的方案。
- **权限范围升级。** 一个被授予 `notes:read` 的笔记服务器稍后可能需要 `notes:write` 来执行特定操作。逐步授权（SEP-835）会请求额外权限范围，而不是重新走完整流程。
- **混淆代理预防。** 客户端持有一个受众范围为服务器 A 的令牌。服务器 A 是恶意的，试图将该令牌提交给服务器 B。资源指示器（RFC 8707）将令牌锁定到其目标受众。

OAuth 2.1 并不新鲜。新鲜的是 MCP 的配置文件：特定的必需流程（仅授权码 + PKCE；不允许隐式流程，默认不允许客户端凭据），每次令牌请求都必须携带资源指示器，以及发布受保护资源元数据以便客户端知道该去哪里。

## 概念

### 角色

- **客户端。** MCP 客户端（Claude Desktop、Cursor 等）。
- **资源服务器。** MCP 服务器（笔记、GitHub、Postgres 等等）。
- **授权服务器。** 颁发令牌。可能与资源服务器是同一服务，也可能是独立的 IdP（Auth0、Keycloak、Cognito）。

在 MCP 的配置文件中，资源服务器和授权服务器可以是同一主机，但应当通过 URL 区分。

### 授权码 + PKCE

流程：

1. 客户端生成 `code_verifier`（随机值）和 `code_challenge`（SHA256）。
2. 客户端将用户重定向到 `/authorize?response_type=code&client_id=...&redirect_uri=...&scope=notes:read&code_challenge=...&resource=https://notes.example.com`。
3. 用户同意。授权服务器重定向到 `redirect_uri?code=...`。
4. 客户端 POST 到 `/token?grant_type=authorization_code&code=...&code_verifier=...&resource=...`。
5. 授权服务器用存储的 challenge 验证 verifier 的哈希，并颁发访问令牌（Access Token）。
6. 客户端使用该令牌：每次请求资源服务器时携带 `Authorization: Bearer ...`。

PKCE 防止授权码拦截攻击。资源指示器防止令牌在其他地方有效。

### 受保护资源元数据（RFC 9728）

资源服务器发布 `.well-known/oauth-protected-resource` 文档：

```json
{
  "resource": "https://notes.example.com",
  "authorization_servers": ["https://auth.example.com"],
  "scopes_supported": ["notes:read", "notes:write", "notes:delete"]
}
```

客户端从资源服务器发现授权服务器。减少了配置 —— 客户端只需要资源 URL。

### 资源指示器（RFC 8707）

令牌请求中的 `resource` 参数锁定令牌的目标受众。颁发的令牌包含 `aud: "https://notes.example.com"`。接收到此令牌的另一个 MCP 服务器检查 `aud` 并拒绝它。

### 权限范围模型

权限范围（Scopes）是空格分隔的字符串。常见的 MCP 约定：

- `notes:read`、`notes:write`、`notes:delete`
- `admin:*` 用于管理员能力（谨慎使用）
- `profile:read` 用于身份信息

权限范围选择应遵循最小权限原则：请求当前所需，需要更多时逐步升级。

### 逐步授权（Step-Up Authorization, SEP-835）

用户授予 `notes:read`。后来他们要求 Agent 删除一条笔记。服务器响应：

```
HTTP/1.1 403 Forbidden
WWW-Authenticate: Bearer error="insufficient_scope",
    scope="notes:delete", resource="https://notes.example.com"
```

客户端看到 insufficient_scope 错误，通过同意对话框提示用户授予额外权限范围，为其执行一个迷你 OAuth 流程，然后用新令牌重试请求。

### 令牌受众验证

每次请求：服务器检查 `token.aud == self.resource_url`。不匹配 = 401。这阻止了跨服务器令牌重用。

### 短时效令牌与轮换

访问令牌应当是短时效的（默认 1 小时）。刷新令牌（Refresh Token）在每次刷新时轮换。客户端在后台处理静默刷新。

### 不允许令牌透传

采样服务器（Phase 13 · 11）不得将客户端令牌透传给其他服务。采样请求就是边界。

### 混淆代理预防

令牌绑定到 `aud`。客户端绑定到 `client_id`。每次请求都要验证两者。规范明确禁止了在 MCP 之前的远程工具生态系统中常见的旧"透传令牌"模式。

### 客户端 ID 发现

每个 MCP 客户端在固定 URL 发布其元数据。授权服务器可以获取客户端的元数据文档来发现重定向 URI 和联系信息。这消除了手动注册客户端的过程。

### 网关与 OAuth

Phase 13 · 17 展示企业网关如何处理 OAuth：网关持有上游服务器的凭据，给客户端的令牌是网关颁发的，上游令牌永远不离开网关。这翻转了信任模型 —— 用户只需与网关认证一次；网关处理 N 个服务器的授权。

## 使用

`code/main.py` 将完整的 OAuth 2.1 逐步授权流程模拟为一个状态机。它实现了：

- PKCE code-verifier / challenge 生成。
- 带资源指示器的授权码流程。
- 受保护资源元数据端点。
- 带受众检查的令牌验证。
- insufficient_scope 时的逐步授权。

本课不涉及 HTTP 服务器；状态机在内存中运行，以便你可以追踪每一步。Phase 13 · 17 的网关课将其连接到实际的传输层。

## 交付物

本课产出 `outputs/skill-oauth-scope-planner.md`。给定一个带工具的远程 MCP 服务器，该技能设计权限范围集、锁定规则和逐步授权策略。

## 练习

1. 运行 `code/main.py`。追踪两个权限范围的逐步授权流程。注意在逐步升级时哪些步骤重复了。

2. 添加刷新令牌轮换：每次刷新颁发新的刷新令牌并作废旧令牌。模拟一个被盗刷新令牌在轮换后被使用，确认它失败。

3. 使用标准库 http.server 将受保护资源元数据端点实现为真正的 HTTP 响应。借鉴第 09 课的 /mcp 端点。

4. 为 GitHub MCP 服务器设计一个权限范围层级：read repo、write PR、approve PR、merge PR、admin。在各级之间使用逐步授权。

5. 阅读 RFC 8707 和 RFC 9728。找出 RFC 9728 中 MCP 使用方式与 RFC 示例不同的一个字段。（提示：涉及 `scopes_supported`。）

## 关键术语

| 术语 | 常见说法 | 实际含义 |
|------|----------|----------|
| OAuth 2.1 | "现代 OAuth" | 强制要求 PKCE 并禁止隐式流程的综合 RFC |
| PKCE | "持有证明" | 代码验证器 + 挑战，防止授权码拦截 |
| Resource indicator（资源指示器） | "令牌受众" | RFC 8707 的 `resource` 参数，将令牌锁定到一个服务器 |
| Protected-resource metadata（受保护资源元数据） | "发现文档" | RFC 9728 的 `.well-known/oauth-protected-resource` |
| Step-up authorization（逐步授权） | "增量同意" | SEP-835 的按需添加权限范围流程 |
| `insufficient_scope` | "403 附带 WWW-Authenticate" | 服务器信号，要求重新同意更大的权限范围 |
| Confused deputy（混淆代理） | "跨服务令牌重用" | 受信任持有者不恰当地转发令牌的攻击 |
| Short-lived token（短时效令牌） | "访问令牌 TTL" | 快速过期的 Bearer 令牌；刷新令牌续期 |
| Scope hierarchy（权限范围层级） | "最小权限栈" | 分级权限范围，各级之间通过逐步授权升级 |
| Client ID metadata（客户端 ID 元数据） | "客户端发现文档" | 客户端发布其自身 OAuth 元数据的 URL |

## 扩展阅读

- [MCP — Authorization spec](https://modelcontextprotocol.io/specification/draft/basic/authorization) — 权威的 MCP OAuth 配置文件
- [den.dev — MCP November authorization spec](https://den.dev/blog/mcp-november-authorization-spec/) — 2025 年 11 月 25 日变更的详细讲解
- [RFC 8707 — Resource indicators for OAuth 2.0](https://datatracker.ietf.org/doc/html/rfc8707) — 受众锁定 RFC
- [RFC 9728 — OAuth 2.0 protected resource metadata](https://datatracker.ietf.org/doc/html/rfc9728) — 发现文档 RFC
- [Aembit — MCP OAuth 2.1, PKCE and the future of AI authorization](https://aembit.io/blog/mcp-oauth-2-1-pkce-and-the-future-of-ai-authorization/) — 逐步授权流程的实操讲解