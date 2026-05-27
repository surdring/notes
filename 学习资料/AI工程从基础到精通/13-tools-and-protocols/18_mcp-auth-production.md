# 生产环境中的 MCP 认证 —— 在 iii 原语上的 DCR、JWKS 轮换与受众锁定令牌

> 第 16 课在内存中建立了 OAuth 2.1 状态机。到 2026 年，你交付给任何真实组织的每个 MCP 服务器都运行在生产级认证之后：动态客户端注册（DCR, RFC 7591）、授权服务器元数据发现（RFC 8414）、不会在凌晨 3 点破坏令牌验证的 JWKS 轮换、以及拒绝混淆代理重用的受众锁定令牌。本课通过 iii 原语将所有这一切串联起来 —— `iii.registerTrigger` 用于 HTTP 和 cron、`iii.registerFunction` 用于认证逻辑、`state::set/get` 用于缓存密钥 —— 使认证面可观测、可重启、可重放，就像引擎中的其他所有工作负载一样。

**类型：** 构建
**语言：** Python（标准库，iii 原语在课程环境中模拟）
**前置要求：** Phase 13 · 16（OAuth 2.1 状态机），Phase 13 · 17（网关）
**时间：** ~90 分钟

## 学习目标

- 通过 RFC 8414 元数据发现授权服务器并验证契约。
- 实现 RFC 7591 动态客户端注册，使 MCP 客户端无需管理员干预即可注册。
- 使用 cron 触发器缓存和轮换 JWKS 密钥，使签名验证能在密钥轮换后继续正常工作。
- 使用 RFC 8707 资源指示器将令牌锁定到单个 MCP 资源，并拒绝混淆代理重用。
- 将每个端点和后台作业连接为 iii 原语 —— HTTP 触发器、cron 触发器、命名函数和 `state::*` 读取 —— 使单次重启即可重建认证面。
- 阅读 IdP 能力矩阵，并在 IdP 无法满足 MCP 认证配置文件时拒绝部署。

## 问题

第 16 课的模拟器在内存中运行 OAuth 2.1。生产环境存在三个仅靠内存模拟器看不到的运营差距。

第一个差距是注册。一个真实的组织运行数百个 MCP 服务器和数千个 MCP 客户端。运维人员不会手动将每个 Cursor 用户注册为 OAuth 客户端。RFC 7591 动态客户端注册允许客户端向授权服务器 `POST /register` 并当场收到 `client_id`（以及可选的 `client_secret`）。服务器在其 RFC 8414 元数据中发布 `registration_endpoint`；客户端无需带外配置即可发现它。

第二个差距是密钥轮换。JWT 验证依赖授权服务器的签名密钥，以 JSON Web Key Set（JWKS）形式发布。授权服务器按计划轮换这些密钥（通常每小时一次，有时在应急响应下更快）。一个仅在启动时获取 JWKS 的 MCP 服务器在轮换窗口之前验证正常 —— 然后直到重启前每个请求都会失败。生产环境将 JWKS 连接为带刷新作业的缓存值，该作业在前一个密钥过期之前覆盖缓存，加上在缓存未命中时的回退获取，以处理令牌签名密钥比缓存更新的情况。

第三个差距是受众绑定。第 16 课介绍了 RFC 8707 资源指示器。在生产环境中，该指示器变成对每个请求的硬性声明检查。MCP 服务器将 `token.aud` 与自身的规范资源 URL 进行比较，不匹配时返回 HTTP 401。这是防止上游 MCP 服务器（或持有用于某个服务器的令牌的恶意客户端）在同一信任网格中对另一个服务器重放该令牌的唯一防御。

本课将每一个差距都视为一个 iii 原语。元数据文档是一个 HTTP 触发器，返回函数的输出。JWKS 轮换是一个 cron 触发器，调用 `auth::rotate-jwks`，后者写入 `state::set("auth/jwks/<issuer>", ...)`。JWT 验证是一个其他函数通过 `iii.trigger("auth::validate-jwt", token)` 调用的函数。MCP 服务器本身只是另一个 HTTP 触发器，在分发前调用验证。重启引擎：触发器注册表重建；状态存活；认证面无需手动调谐即可正常运行。

## 概念

### RFC 8414 —— OAuth 授权服务器元数据

位于 `/.well-known/oauth-authorization-server` 的文档描述了客户端所需的一切：

```json
{
  "issuer": "https://auth.example.com",
  "authorization_endpoint": "https://auth.example.com/authorize",
  "token_endpoint": "https://auth.example.com/token",
  "jwks_uri": "https://auth.example.com/.well-known/jwks.json",
  "registration_endpoint": "https://auth.example.com/register",
  "response_types_supported": ["code"],
  "grant_types_supported": ["authorization_code", "refresh_token"],
  "code_challenge_methods_supported": ["S256"],
  "scopes_supported": ["mcp:tools.read", "mcp:tools.invoke"],
  "token_endpoint_auth_methods_supported": ["none", "private_key_jwt"]
}
```

给定 MCP 资源 URL 的客户端链式发现：来自 RFC 9728 的 `oauth-protected-resource`（资源服务器的文档）指明 issuer，然后 `oauth-authorization-server`（本 RFC）指明每个端点。客户端永远不硬编码授权 URL。

在信任 IdP 用于 MCP 之前你需要验证的契约：

- `code_challenge_methods_supported` 包含 `S256`（RFC 7636 PKCE）。
- `grant_types_supported` 包含 `authorization_code` 且拒绝 `password` 和 `implicit`。
- `registration_endpoint` 存在（RFC 7591 支持）。
- 对于 OAuth 2.1，`response_types_supported` 恰好为 `["code"]`。

如果上述任何一项缺失，MCP 服务器拒绝针对此 IdP 部署。部署清单有问题，不是代码的问题。

### RFC 9728（回顾）—— 受保护资源元数据

第 16 课涵盖了 RFC 9728。生产环境中的差异：此文档是客户端查找**此** MCP 服务器信任的授权服务器的唯一位置。单个 MCP 服务器可能接受来自多个 IdP 的令牌（一个用于员工，一个用于合作伙伴）。RFC 9728 声明该集合；RFC 8414 记录每个 IdP 支持什么。

```json
{
  "resource": "https://notes.example.com",
  "authorization_servers": ["https://auth.example.com", "https://partners.example.com"],
  "scopes_supported": ["mcp:tools.invoke"],
  "bearer_methods_supported": ["header"],
  "resource_documentation": "https://notes.example.com/docs"
}
```

### RFC 7591 —— 动态客户端注册

没有 DCR 时，每个 MCP 客户端（Cursor、Claude Desktop、自定义 Agent）都需要与 IdP 管理员进行带外交互。使用 DCR 时，客户端直接提交：

```json
POST /register
Content-Type: application/json

{
  "redirect_uris": ["http://127.0.0.1:7333/callback"],
  "grant_types": ["authorization_code", "refresh_token"],
  "response_types": ["code"],
  "token_endpoint_auth_method": "none",
  "scope": "mcp:tools.invoke",
  "client_name": "Cursor",
  "software_id": "com.cursor.cursor",
  "software_version": "0.42.0"
}
```

服务器响应 `client_id` 和用于后续更新的 `registration_access_token`：

```json
{
  "client_id": "c_3e7f1a",
  "client_id_issued_at": 1769472000,
  "redirect_uris": ["http://127.0.0.1:7333/callback"],
  "grant_types": ["authorization_code", "refresh_token"],
  "registration_access_token": "regt_b2...",
  "registration_client_uri": "https://auth.example.com/register/c_3e7f1a"
}
```

`token_endpoint_auth_method: none` 是在用户设备上运行的 MCP 客户端的正确默认值。它们只获得 `client_id` —— 没有 `client_secret` 可被窃取。PKCE 提供了公共客户端所需的持有证明。

三个生产陷阱：

- 注册端点必须对源 IP 进行限流。没有限流，恶意攻击者可以脚本化数百万个伪造注册并耗尽 `client_id` 命名空间。iii 使这变得简单：注册 HTTP 触发器在分发给注册器之前调用 `auth::rate-limit` 函数。
- `software_statement`（一个为客户端担保的签名 JWT）被某些企业 IdP 要求。本课的模拟跳过了它；生产环境添加一个验证步骤，拒绝来自非 localhost 重定向 URI 的未签名注册。
- `registration_access_token` 必须存储为哈希值，而非明文。此令牌被盗意味着攻击者可以重写客户端的重定向 URI。

### RFC 8707（回顾）—— 资源指示器

第 16 课建立了基本形式。生产规则：每次令牌请求包含 `resource=<canonical-mcp-url>`，MCP 服务器在每次调用时验证 `token.aud` 是否匹配自身的资源 URL。如果 MCP 服务器在 `https://notes.example.com/mcp` 上可达，规范 URL 是 `https://notes.example.com` —— 排除路径组件，以便单个服务器在一个受众下承载多个路径。

### RFC 7636（回顾）—— PKCE

PKCE 在 OAuth 2.1 中是强制性的。本课的授权码流程始终携带 `code_challenge` 和 `code_verifier`。服务器拒绝任何没有 verifier 或 verifier 的哈希与存储的 challenge 不匹配的令牌请求。

### MCP 规范 2025-11-25 认证配置文件

MCP 规范（2025-11-25）精确规定了 MCP 服务器授权层必须做什么：

- 发布 `/.well-known/oauth-protected-resource`（RFC 9728）。
- 仅通过 `Authorization: Bearer ...` 接受令牌。
- 按请求验证 `aud`、`iss`、`exp` 和所需的权限范围。
- 对每个 401 和 403 响应携带 `WWW-Authenticate` 和 `Bearer error=...`，在适用时包含 `scope=` 和 `resource=` 参数。
- 拒绝 `aud` 不匹配规范资源的令牌。
- 拒绝 `iss` 不在受保护资源元数据的 `authorization_servers` 列表中的令牌。

OAuth 2.1 草案是基础层；RFC 8414/7591/8707/9728 + RFC 7636 是接口层；MCP 规范是配置文件。

### IdP 能力矩阵

并非每个 IdP 都支持完整的 MCP 配置文件。下表记录了截至 2025 年 11 月 25 日规范的实际能力声明。它是**部署门槛**，而非推荐。

| IdP 类别 | RFC 8414 元数据 | RFC 7591 DCR | RFC 8707 资源 | RFC 7636 S256 PKCE | 备注 |
|---|---|---|---|---|---|
| 自托管（Keycloak） | 是 | 是 | 是（自 24.x 起） | 是 | 本课 MCP 配置文件的参考 IdP；端到端支持每个 RFC。 |
| 企业 SSO（Microsoft Entra ID） | 是 | 是（高级层） | 是 | 是 | DCR 可用性因租户层而异；在目标租户中部署前验证。 |
| 企业 SSO（Okta） | 是 | 是（Okta CIC / Auth0） | 是 | 是 | DCR 在 Auth0（现为 Okta CIC）上可用；经典 Okta 组织需要管理员预注册。 |
| 社交登录 IdP（通用） | 不一 | 很少 | 很少 | 是 | 大多数社交 IdP 将客户端视为静态合作伙伴；勿依赖 DCR。仅用作身份来源，在其之上层叠你自己的 MCP 感知授权服务器。 |
| 自定义 / 自建 | 取决于 | 取决于 | 取决于 | 取决于 | 如果你自建，请提供完整配置文件。跳过上述四个 RFC 之一将破坏 MCP 认证契约。 |

部署清单的拒绝规则：如果所选 IdP 未返回 `registration_endpoint` 且未在 `code_challenge_methods_supported` 中列出 `S256`，MCP 服务器拒绝启动。没有降级模式。

### 基于 iii 的 JWKS 轮换模式

生产故障模式是过期的 JWKS 缓存。使用 cron 触发器和 `state::*` 缓存解决：

```python
iii.registerTrigger(
    "cron",
    {"schedule": "0 */6 * * *", "name": "auth::jwks-refresh"},
    "auth::rotate-jwks",
)
```

每六小时，cron 触发器调用 `auth::rotate-jwks`，后者获取 `<issuer>/.well-known/jwks.json` 并写入 `state::set("auth/jwks/<issuer>", {keys, fetched_at})`。验证器从 `state::get` 读取。对于其 `kid` 在缓存中缺失的令牌，触发同步的 `auth::rotate-jwks` 调用作为回退。这样可同时处理两种情况：计划轮换（cron）和密钥重叠窗口（同步回退）。

状态结构：

```json
{
  "auth/jwks/https://auth.example.com": {
    "keys": [
      {"kid": "k_2026_03", "kty": "RSA", "n": "...", "e": "AQAB", "alg": "RS256", "use": "sig"},
      {"kid": "k_2026_04", "kty": "RSA", "n": "...", "e": "AQAB", "alg": "RS256", "use": "sig"}
    ],
    "fetched_at": 1772668800
  }
}
```

同时存在两个密钥是稳态。授权服务器通过在退役前一个密钥（`k_2026_03`）之前引入下一个密钥（`k_2026_04`）来轮换，因此使用旧密钥签发的令牌在过期前仍然有效。缓存保留并集；验证器按 `kid` 选择。

### iii 原语连接（本课的实际核心内容）

五个原语组成认证面：

```python
# 1. RFC 8414 元数据文档
iii.registerTrigger(
    "http",
    {"path": "/.well-known/oauth-authorization-server", "method": "GET"},
    "auth::serve-asm",
)

# 2. RFC 7591 动态客户端注册
iii.registerTrigger(
    "http",
    {"path": "/register", "method": "POST"},
    "auth::register-client",
)

# 3. JWT 验证作为可调用函数（资源服务器触发它）
iii.registerFunction("auth::validate-jwt", validate_jwt_handler)

# 4. 增量权限范围的逐步授权签发（来自第 16 课的 SEP-835）
iii.registerFunction("auth::issue-step-up", issue_step_up_handler)

# 5. Cron 驱动的 JWKS 轮换
iii.registerTrigger(
    "cron",
    {"schedule": "0 */6 * * *"},
    "auth::rotate-jwks",
)
iii.registerFunction("auth::rotate-jwks", rotate_jwks_handler)
```

MCP 服务器本身从不直接调用验证。它这样做：

```python
result = iii.trigger("auth::validate-jwt", {"token": bearer_token, "resource": self.resource})
if not result["valid"]:
    return {"status": 401, "WWW-Authenticate": result["www_authenticate"]}
```

这种间接性是 iii 的核心价值。明天你将验证器替换为并行查询两个 IdP 的扇出，或者添加 span 发射器，或者缓存验证成功的令牌。MCP 服务器无需变更。

### 带受众绑定的混淆代理演练

服务器 A（`notes.example.com`）和服务器 B（`tasks.example.com`）都针对同一授权服务器注册。服务器 A 被入侵。攻击者取走用户的笔记令牌并向服务器 B 重放。

服务器 B 的验证器：

1. 解码 JWT，按 `kid` 获取 JWKS，验证签名。
2. 对照受保护资源元数据的 `authorization_servers` 检查 `iss`。（通过 —— 同一 IdP。）
3. 检查 `aud == "https://tasks.example.com"`。（失败 —— 令牌的 `aud` 是 `https://notes.example.com`。）
4. 返回 401 附带 `WWW-Authenticate: Bearer error="invalid_token", error_description="audience mismatch"`。

受众声明是在协议层面对抗此攻击的唯一防御。为性能跳过它是最常见的生产错误；验证器必须在每个请求上运行，而不仅仅是在会话开始时。

### 故障模式

- **过期 JWKS。** 验证器在密钥轮换后拒绝有效令牌。修复方法是上述 cron + 回退模式。永远不要在没有刷新作业的情况下缓存 JWKS。
- **缺失 `aud` 声明。** 某些 IdP 默认省略 `aud`，除非令牌请求中存在 `resource`。验证器必须拒绝缺少 `aud` 的令牌，而不是将缺失视为通配符。
- **权限范围升级竞态。** 同一用户的两个并发逐步授权流程可能同时成功并产生两个具有不同权限范围的访问令牌。验证器必须使用请求上提交的令牌，而不是查找"用户的当前权限范围" —— 那会制造 TOCTOU 窗口。
- **注册令牌被盗。** 泄露的 `registration_access_token` 使攻击者可以重写重定向 URI。在静止状态下哈希存储这些令牌；要求客户端在每次更新时提交明文；怀疑时轮换。
- **`iss` 未锁定。** 接受任意 `iss` 的验证器允许攻击者建立自己的授权服务器，为目标受众注册客户端并签发令牌。受保护资源元数据的 `authorization_servers` 列表是允许列表；强制执行它。

## 使用

`code/main.py` 使用标准库 Python 和一个模拟 `iii.registerFunction`、`iii.registerTrigger`、`iii.trigger` 和 `state::set/get` 的小型 `iii_mock` 注册表，演练完整的生产流程。流程：

1. 授权服务器在 `/.well-known/oauth-authorization-server` 发布 RFC 8414 元数据。
2. MCP 客户端调用元数据端点，发现注册端点。
3. MCP 客户端 POST 到 `/register`（RFC 7591）并收到 `client_id`。
4. MCP 客户端使用 PKCE 保护的授权码流程（RFC 7636）并携带 `resource` 指示器（RFC 8707）。
5. MCP 客户端使用 `Authorization: Bearer ...` 调用 MCP 服务器上的工具。
6. MCP 服务器触发 `auth::validate-jwt`，后者从 `state::get` 读取 JWKS。
7. Cron 触发器触发 `auth::rotate-jwks`，替换状态中的 JWKS。
8. 下一次调用使用新密钥验证，无需重启。
9. 针对不同 MCP 资源的混淆代理尝试收到 401 附带受众不匹配信息。

这里的模拟 JWT 使用 HS256 和共享密钥（以便课程仅在标准库上运行）。生产环境使用 RS256 或 EdDSA 配合上述 JWKS 模式；验证逻辑在其他方面完全相同。

## 交付物

本课产出 `outputs/skill-mcp-auth-iii.md`。给定 MCP 服务器配置和 IdP 能力集，该技能发出 iii 原语以注册、JWKS 轮换计划、权限范围映射，以及在 IdP 不支持完整 RFC 配置文件时应用的拒绝规则。

## 练习

1. 运行 `code/main.py`。追踪 9 步流程。注意在 `auth::rotate-jwks` 覆盖之前 `state::get` 返回过期数据的位置，以及下一个请求如何接着使用新密钥验证。

2. 在受保护资源元数据的 `authorization_servers` 列表中添加一个新的 IdP。签发一个由新 IdP 签名的令牌，确认验证器接受它。签发一个由未列出的 IdP 签名的令牌，确认验证器以 `WWW-Authenticate: Bearer error="invalid_token", error_description="iss not allowed"` 拒绝。

3. 将 `auth::rate-limit` 实现为 iii 函数，并在注册 HTTP 触发器中注册器运行之前调用它。对保存在 `state::set("auth/ratelimit/<ip>", ...)` 中的每个源 IP 使用令牌桶。

4. 阅读 RFC 7591，找出本课 `/register` 处理程序未验证的两个字段。添加验证。（提示：`software_statement` 和 `redirect_uris` URI 方案。）

5. 阅读 MCP 规范 2025-11-25 授权部分。找出本课验证器当前未发出的 `WWW-Authenticate` 头的一个规范性要求。添加它。

## 关键术语

| 术语 | 常见说法 | 实际含义 |
|------|----------|----------|
| ASM | "OAuth 元数据文档" | RFC 8414 `/.well-known/oauth-authorization-server` JSON |
| DCR | "自助客户端注册" | RFC 7591 `POST /register` 流程 |
| JWKS | "用于 JWT 验证的公钥" | JSON Web Key Set，从 `jwks_uri` 获取，按 `kid` 索引 |
| Resource indicator（资源指示器） | "受众参数" | RFC 8707 的 `resource` 参数，将令牌锁定到一个服务器 |
| `aud` claim（受众声明） | "Audience" | 验证器与规范资源 URL 比较的 JWT 声明 |
| Confused deputy（混淆代理） | "令牌重放" | 为服务器 A 签发的令牌被提交给服务器 B 的攻击 |
| `iss` allow-list（iss 允许列表） | "受信任的授权服务器" | 受保护资源元数据的 `authorization_servers` 中命名的集合 |
| Key rotation（密钥轮换） | "滚动 JWKS" | 带重叠窗口的签名密钥定期更换 |
| Public client（公共客户端） | "本地或浏览器客户端" | 没有 `client_secret` 的 OAuth 客户端；PKCE 弥补 |
| `WWW-Authenticate` | "401/403 响应头" | 携带驱动客户端恢复的 `Bearer error=...` 指令 |

## 扩展阅读

- [MCP — Authorization spec (2025-11-25)](https://modelcontextprotocol.io/specification/draft/basic/authorization) — 本课实现的 MCP 认证配置文件
- [RFC 8414 — OAuth 2.0 Authorization Server Metadata](https://datatracker.ietf.org/doc/html/rfc8414) — 发现契约
- [RFC 7591 — OAuth 2.0 Dynamic Client Registration Protocol](https://datatracker.ietf.org/doc/html/rfc7591) — DCR
- [RFC 7636 — Proof Key for Code Exchange (PKCE)](https://datatracker.ietf.org/doc/html/rfc7636) — 公共客户端持有证明
- [RFC 8707 — Resource Indicators for OAuth 2.0](https://datatracker.ietf.org/doc/html/rfc8707) — 受众锁定
- [RFC 9728 — OAuth 2.0 Protected Resource Metadata](https://datatracker.ietf.org/doc/html/rfc9728) — 资源服务器发现
- [OAuth 2.1 draft](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-v2-1) — 统一的 OAuth 基础层