# 综合项目 13 — 带注册表和治理的 MCP 服务器

> 模型上下文协议（Model Context Protocol，MCP）在 2026 年不再只是未来，而是成为默认的工具使用规范。Anthropic、OpenAI、Google 以及每个主流 IDE 都发布了 MCP 客户端。Pinterest 发布了其内部 MCP 服务器生态系统。AAIF Registry 在 `.well-known` 规范了能力元数据。AWS ECS 发布了参考无状态部署。Block 的 goose-agent 将同一协议放在托管助手中。2026 年的生产形态是：StreamableHTTP 传输、OAuth 2.1 权限范围、OPA 策略闸门，以及一个让平台团队可以发现、验证和启用服务器的注册表。端到端构建这些。

**类型：** 综合项目
**语言：** Python（服务器，通过 FastMCP）或 TypeScript（@modelcontextprotocol/sdk），Go（注册表服务）
**前置知识：** 阶段 11（LLM 工程）、阶段 13（工具和 MCP）、阶段 14（Agent）、阶段 17（基础设施）、阶段 18（安全）
**涵盖阶段：** P11 · P13 · P14 · P17 · P18
**时间：** 25 小时

## 问题

MCP 成为工具使用的通用语言。Claude Code、Cursor 3、Amp、OpenCode、Gemini CLI 以及每个托管 Agent 现在都消费 MCP 服务器。生产挑战不是编写服务器（FastMCP 使其很容易），而是以企业需求大规模部署：每租户 OAuth 权限范围、对破坏性工具的 OPA 策略、StreamableHTTP 无状态扩展、用于发现的注册表、每次工具调用的审计日志。Pinterest 的内部 MCP 生态系统和 AAIF Registry 规范设定了 2026 年的标准。

你将构建一个暴露 10 个内部工具的 MCP 服务器（Postgres 只读、S3 列表、Jira、Linear、Datadog 等）、一个用于平台发现的注册表 UI，以及一个用于破坏性工具的人工批准闸门。负载测试演示 StreamableHTTP 水平扩展。审计追踪满足企业安全审查要求。

## 概念

MCP 2026 修订版要求 StreamableHTTP 作为默认传输。与早期的 stdio 和 SSE 形态不同，StreamableHTTP 默认无状态：单个 HTTP 端点接受 JSON-RPC 请求，流式传输响应，并支持用于通知的长连接。无状态意味着可以在负载均衡器后面水平扩展。

授权使用 OAuth 2.1 配合每个工具的权限范围。令牌携带如 `jira:read`、`s3:list`、`postgres:query:readonly` 的范围。MCP 服务器在工具调用时检查范围，而不仅仅在会话开始时。对于高风险工具，服务器拒绝任何过去 N 分钟内范围未提升到 `approved:by:human` 的调用——该提升来自 Slack 审查卡片。

注册表是一个独立服务。每个 MCP 服务器暴露一个 `.well-known/mcp-capabilities` 文档，包含工具清单、传输 URL、认证要求。注册表轮询、验证和索引。平台团队使用注册表 UI 查看可用工具、需要什么范围以及哪个团队拥有它们。

## 架构

```
MCP 客户端（Claude Code、Cursor 3 等）
          |
          v
StreamableHTTP over HTTPS（JSON-RPC + 流式传输）
          |
          v
MCP 服务器（FastMCP）位于负载均衡器后
          |
   +------+------+---------+----------+------------+
   v             v         v          v            v
Postgres    S3 列表    Jira       Linear     Datadog
（只读）      （分页）    （读取）    （读取）    （查询）
          |
   +------+-------------+
   v                    v
 OPA 策略闸门      破坏性工具 MCP（独立服务器）
                        |
                        v
                   通过 Slack 的人工批准
                        |
                        v
                   审计日志（仅追加，每租户）

  注册表服务
     |
     v  GET /.well-known/mcp-capabilities 从每个服务器
     v
     UI：搜索 / 验证 / 启用-禁用 / 所有权
```

## 技术栈

- 服务器框架：FastMCP（Python）或 `@modelcontextprotocol/sdk`（TypeScript）
- 传输：StreamableHTTP over HTTPS（无状态）
- 认证：OAuth 2.1 配合通过 SPIFFE / SPIRE 的工作负载身份
- 策略：每个工具的 OPA / Rego 规则；每个请求的策略决策服务
- 注册表：自托管，消费 `.well-known/mcp-capabilities` 清单
- 人工批准：用于破坏性工具的 Slack 交互式消息
- 部署：AWS ECS Fargate 或 Fly.io，每个租户一个服务器或共享且带租户范围限定
- 审计：每个租户的结构化 JSONL 桶，包含每次调用的谱系

## 构建步骤

1. **工具表面。** 暴露 10 个内部工具：Postgres 只读查询、S3 列出对象、Jira 搜索/获取、Linear 搜索/获取、Datadog 指标查询、PagerDuty 值班查询、GitHub 只读、Notion 搜索、Slack 搜索、Salesforce 读取。每个工具都有类型化模式和范围标签。

2. **FastMCP 服务器。** 挂载工具。配置 StreamableHTTP 传输。添加用于 OAuth 令牌内省和范围强制的中间件。

3. **OPA 策略。** 每个工具的 Rego 策略：哪些范围允许调用、适用什么 PII 脱敏、适用什么载荷大小上限。每次工具调用时调用决策服务。

4. **注册表服务。** 独立的 Go 或 TS 服务，从注册的服务器轮询 `.well-known/mcp-capabilities`，使用 JSON Schema 验证，并暴露列表 / 搜索 / 验证 / 启用-禁用 UI。

5. **能力清单。** 每个服务器暴露 `.well-known/mcp-capabilities`，包含：工具列表、认证要求、传输 URL、所属团队、SLO。

6. **破坏性工具分离。** 修改状态的工具（Jira 创建、Linear 创建、Postgres 写入）位于第二个 MCP 服务器上，具有更严格的认证流程：令牌必须在 15 分钟内通过 Slack 卡片获得 `approved:by:human` 范围的提升。

7. **审计日志。** 每个租户的仅追加 JSONL：`{timestamp, user, tool, args_redacted, response_redacted, outcome}`。写入前通过 Presidio 进行 PII 脱敏。

8. **负载测试。** StreamableHTTP 上的 100 个并发客户端。通过添加第二个副本演示水平扩展；显示负载均衡器在无会话粘性的情况下重新分配。

9. **一致性测试。** 对两个服务器运行官方 MCP 一致性套件。通过所有必选章节。

## 使用方式

```
$ curl -H "Authorization: Bearer eyJhbGc..." \
       -X POST https://mcp.internal.example.com/ \
       -d '{"jsonrpc":"2.0","method":"tools/call",
            "params":{"name":"postgres.readonly","arguments":{"sql":"SELECT 1"}}}'
[registry]   能力已验证：postgres.readonly v1.2
[policy]    范围 postgres:query:readonly 存在；已允许
[audit]     已记录：user=u42 tool=postgres.readonly outcome=ok
响应：       { "result": { "rows": [[1]] } }
```

## 交付标准

`outputs/skill-mcp-server.md` 描述交付物。一个用于内部工具的生产级 MCP 服务器 + 注册表 + 审计层，配合 OAuth 2.1 范围和 OPA 闸门。

| 权重 | 标准 | 衡量方式 |
|:-:|---|---|
| 25 | 规范一致性 | StreamableHTTP + 能力清单通过 MCP 一致性测试 |
| 20 | 安全性 | 范围强制，每个工具的 OPA 覆盖，密钥卫生 |
| 20 | 可观测性 | 每次工具调用的审计日志，带 PII 脱敏 |
| 20 | 规模 | 100 客户端负载测试水平扩展演示 |
| 15 | 注册表体验 | 发现 / 验证 / 启用-禁用工作流 |
| **100** | | |

## 练习

1. 添加一个新工具（Confluence 搜索）。通过注册表验证流程交付它，而不触及核心服务器。

2. 编写一个 OPA 策略，脱敏包含 `email`、`ssn` 或 `phone` 列的 Postgres 查询结果。使用探测查询演练。

3. 基准测试 StreamableHTTP vs stdio 在本地延迟上的表现。报告每次调用的 p50/p95。

4. 实现每租户配额：每个工具每个租户每分钟最大 N 次调用。通过第二个 OPA 规则强制执行。

5. 从 [mcp-conformance-tests](https://github.com/modelcontextprotocol/conformance) 运行 MCP 一致性套件并修复每个失败。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|------------------------|
| StreamableHTTP | "2026 MCP 传输" | 无状态 HTTP + 流式传输；取代 SSE + stdio 用于网络化服务器 |
| 能力清单（Capability manifest） | "Well-known 文档" | `.well-known/mcp-capabilities` 包含工具列表、认证、传输 URL |
| OPA / Rego | "策略引擎" | 开放策略代理（Open Policy Agent）用于根据外部规则授权工具调用 |
| 范围提升（Scope elevation） | "人工批准" | 通过 Slack 批准授予的短期范围，破坏性工具需要此范围 |
| 注册表（Registry） | "工具发现" | 从其能力清单索引 MCP 服务器的服务 |
| 工作负载身份（Workload identity） | "SPIFFE / SPIRE" | 用于 OAuth 令牌签发的加密服务身份 |
| 一致性套件（Conformance suite） | "规范测试" | 用于 StreamableHTTP + 工具清单正确性的官方 MCP 测试集 |

## 延伸阅读

- [Model Context Protocol 2026 路线图](https://blog.modelcontextprotocol.io/posts/2026-mcp-roadmap/) — StreamableHTTP、能力元数据、注册表
- [AAIF MCP Registry 规范](https://github.com/modelcontextprotocol/registry) — 2026 注册表规范
- [AWS ECS 参考部署](https://aws.amazon.com/blogs/containers/deploying-model-context-protocol-mcp-servers-on-amazon-ecs/) — 参考生产部署
- [Pinterest 内部 MCP 生态系统](https://www.infoq.com/news/2026/04/pinterest-mcp-ecosystem/) — 参考内部部署
- [Block `goose` MCP 使用](https://block.github.io/goose/) — 参考 Agent 消费模式
- [FastMCP](https://github.com/jlowin/fastmcp) — Python 服务器框架
- [Open Policy Agent](https://www.openpolicyagent.org/) — 策略引擎参考
- [SPIFFE / SPIRE](https://spiffe.io) — 工作负载身份参考