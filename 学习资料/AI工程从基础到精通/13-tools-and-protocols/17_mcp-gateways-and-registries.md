# MCP 网关与注册表 —— 企业控制平面

> 企业不能让每个开发者随意安装任意的 MCP 服务器。网关集中管理认证、RBAC、审计、限流、缓存和工具投毒检测，然后将合并后的工具面作为单个 MCP 端点暴露。MCP 官方注册表（Official MCP Registry，由 Anthropic + GitHub + PulseMCP + Microsoft 共同管理，命名空间验证）是权威的上游来源。本课指出网关的位置，演示一个最简实现，并调查 2026 年的供应商格局。

**类型：** 学习
**语言：** Python（标准库，最简网关）
**前置要求：** Phase 13 · 15（工具投毒），Phase 13 · 16（OAuth 2.1）
**时间：** ~45 分钟

## 学习目标

- 解释 MCP 网关放置在什么位置（在 MCP 客户端和多个后端 MCP 服务器之间）。
- 实现网关的五大职责：认证、RBAC、审计、限流、策略。
- 在网关层强制执行锁定工具哈希清单。
- 区分 MCP 官方注册表与元注册表（Glama、MCPMarket、MCP.so、Smithery、LobeHub）。

## 问题

一家财富 500 强企业有 30 个批准的 MCP 服务器、5000 名开发者、合规与审计要求，以及一个希望集中控制策略的安全团队。让每个开发者在他们的 IDE 中安装任意服务器是不可行的。

网关模式：

1. 网关作为单个 Streamable HTTP 端点运行，开发者连接到它。
2. 网关持有每个后端 MCP 服务器的凭据。
3. 每个开发者请求通过网关自身的 OAuth 进行认证和范围限定。
4. 网关将调用路由到后端服务器，同时应用策略。
5. 所有调用记录在审计日志中。

Cloudflare MCP Portals、Kong AI Gateway、IBM ContextForge、MintMCP、TrueFoundry、Envoy AI Gateway —— 都在 2025-2026 年间发布了网关或网关功能。

与此同时，MCP 官方注册表作为权威上游来源正式上线：精选的、命名空间验证的、反向 DNS 命名的服务器，网关可以从中拉取。元注册表（Glama、MCPMarket、MCP.so、Smithery、LobeHub）聚合来自多个来源的服务器。

## 概念

### 网关五大职责

1. **认证（Auth）。** OAuth 2.1 识别开发者；映射到用户角色。
2. **RBAC。** 每用户策略：允许哪些服务器、哪些工具、哪些权限范围。
3. **审计（Audit）。** 每次调用记录谁、做了什么、何时、结果如何。
4. **限流（Rate limit）。** 每用户 / 每工具 / 每服务器的上限以防止滥用。
5. **策略（Policy）。** 拒绝投毒描述、强制执行二选规则、脱敏 PII。

### 网关作为单一端点

对开发者而言，网关看起来就像一个 MCP 服务器。在内部，它路由到 N 个后端。会话 ID（Phase 13 · 09）在边界处被重写。

### 凭据保管

开发者永远看不到后端令牌。网关持有它们（或代理给持有它们的身份提供商）。在网关上具有 `notes:read` 权限的开发者，可以使用网关自身的后端凭据传递访问笔记 MCP 服务器 —— 但仅在绑定该传递访问的策略约束下。

### 网关层的工具哈希锁定

网关持有一份批准的工具描述清单（SHA256 哈希值）。在发现时，它获取每个后端的 `tools/list`，将哈希值与清单比对，并移除任何描述已变更的工具。这是 Phase 13 · 15 中 rug-pull 防御的集中化应用。

### 策略即代码

高级网关使用 OPA/Rego、Kyverno 或 Styra 来表达策略。诸如"用户 `alice` 只能对 `acme` 组织中的仓库调用 `github.open_pr`"之类的规则以声明式编码。简单网关使用手写 Python。两种形式都是有效的。

### 会话感知路由

当用户的会话包含多个服务器时，网关进行多路复用：开发者的单个 MCP 会话包含 N 个后端会话，每个服务器一个。来自任何后端的通知通过网关路由到开发者的会话。

### 命名空间合并

网关合并所有后端的工具命名空间，通常在冲突时加前缀。`github.open_pr`、`notes.search`。这使得路由无歧义。

### 注册表

- **MCP 官方注册表（`registry.modelcontextprotocol.io`）。** 在 Anthropic、GitHub、PulseMCP、Microsoft 的管理下上线。命名空间验证（反向 DNS：`io.github.user/server`）。经过基本质量预筛选。
- **Glama。** 以搜索为中心的元注册表，聚合多个来源。
- **MCPMarket。** 商业倾向的目录，包含供应商列表。
- **MCP.so。** 社区目录；开放提交。
- **Smithery。** 类似包管理器的安装流程。
- **LobeHub。** 在其 LobeChat 应用中集成了 UI 的注册表。

企业网关默认从官方注册表拉取，允许管理员从元注册表精选添加，拒绝任何未锁定的内容。

### 反向 DNS 命名

官方注册表强制公共服务器使用反向 DNS 名称：`io.github.alice/notes`。命名空间防止抢注，并使信任委托更清晰。

### 供应商调查，2026 年 4 月

| 供应商 | 优势 |
|--------|------|
| Cloudflare MCP Portals | 边缘托管；集成 OAuth；免费层 |
| Kong AI Gateway | K8s 原生；细粒度策略；日志输出到 OpenTelemetry |
| IBM ContextForge | 企业 IAM；合规；审计导出 |
| TrueFoundry | 偏向 DevOps；以指标为先 |
| MintMCP | 面向开发者平台 |
| Envoy AI Gateway | 开源；可定制过滤器 |

Phase 17（生产基础设施）将深入探讨网关运营。

## 使用

`code/main.py` 提供了一个约 150 行的最简网关：通过伪造的 Bearer 令牌认证用户，持有每用户 RBAC 策略，将请求路由到两个后端 MCP 服务器，将每次调用写入审计日志，强制执行限流，并拒绝任何其描述哈希与锁定清单不匹配的后端工具。

需要关注的内容：

- `RBAC` 字典按 `user_id` 索引，包含允许的 `server_tool` 条目。
- `AUDIT_LOG` 是仅追加的事件列表。
- 限流对每个用户使用令牌桶。
- 锁定清单是 `server::tool -> hash` 的字典。

## 交付物

本课产出 `outputs/skill-gateway-bootstrap.md`。给定一个企业 MCP 计划（用户、后端、合规要求），该技能生成网关配置规范。

## 练习

1. 运行 `code/main.py`。依次以允许用户、不允许用户、超过限流阈值的突发请求进行调用。验证三种流程。

2. 添加一个在返回给客户端之前对结果进行 PII 脱敏的策略。对 SSN 格式的字符串使用简单的正则表达式扫描；注意其不足（邮件、电话号码）。

3. 将审计日志扩展为发出 OpenTelemetry GenAI spans。Phase 13 · 20 涵盖确切的属性。

4. 为一个拥有 50 名开发者和五个后端（笔记、GitHub、Postgres、Jira、Slack）的团队设计 RBAC 策略。谁对每个后端拥有只读权限？谁拥有写入权限？

5. 从头到尾阅读 Cloudflare 企业 MCP 文章。找出 Cloudflare 提供但此标准库网关不具备的一项功能。

## 关键术语

| 术语 | 常见说法 | 实际含义 |
|------|----------|----------|
| Gateway（网关） | "MCP 代理" | 位于客户端和后端之间的集中化服务器 |
| Credential vaulting（凭据保管） | "后端令牌保留在服务器端" | 开发者永远看不到上游令牌 |
| Session-aware routing（会话感知路由） | "多后端会话" | 网关为每个开发者会话多路复用 N 个后端会话 |
| Tool-hash pinning（工具哈希锁定） | "批准的清单" | 每个批准工具描述的 SHA256；在中心层面阻止 rug-pull |
| RBAC | "每用户策略" | 基于角色的工具和服务器访问控制 |
| Policy-as-code（策略即代码） | "声明式规则" | 在网关处强制执行的 OPA/Rego、Kyverno、Styra 策略 |
| Audit log（审计日志） | "谁、做了什么、何时" | 用于合规的仅追加事件日志 |
| Rate limit（限流） | "每用户令牌桶" | 每分钟上限以防止滥用 |
| Official MCP Registry（MCP 官方注册表） | "权威上游" | `registry.modelcontextprotocol.io`，命名空间验证 |
| Reverse-DNS naming（反向 DNS 命名） | "注册表命名空间" | `io.github.user/server` 命名约定 |

## 扩展阅读

- [Official MCP Registry](https://registry.modelcontextprotocol.io/) — 权威上游，命名空间验证
- [Cloudflare — Enterprise MCP](https://blog.cloudflare.com/enterprise-mcp/) — 带 OAuth 和策略的网关模式
- [agentic-community — MCP gateway registry](https://github.com/agentic-community/mcp-gateway-registry) — 开源参考网关
- [TrueFoundry — What is an MCP gateway?](https://www.truefoundry.com/blog/what-is-mcp-gateway) — 功能对比文章
- [IBM — MCP context forge](https://github.com/IBM/mcp-context-forge) — IBM 的企业网关