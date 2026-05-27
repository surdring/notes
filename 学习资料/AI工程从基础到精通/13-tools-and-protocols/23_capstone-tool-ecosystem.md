# 综合项目 —— 构建完整的工具体系

> Phase 13 教授了每一个部分。本综合项目将它们串联成一个生产形态的系统：一个带有工具 + 资源 + 提示词 + 任务 + UI 的 MCP 服务器，边界部署 OAuth 2.1，一个 RBAC 网关，一个多服务器客户端，一个 A2A 子 Agent 调用，OTel 链路追踪到一个收集器，CI 中的工具投毒检测，以及一个 AGENTS.md + SKILL.md 包。完成之后你可以为每一个架构选择进行辩护。

**类型：** 构建
**语言：** Python（标准库，端到端生态实验环境）
**前置要求：** Phase 13 · 01 到 21
**时间：** ~120 分钟

## 学习目标

- 组合一个暴露工具、资源、提示词和带有 `ui://` 应用的任务的 MCP 服务器。
- 用强制执行 RBAC 和锁定哈希的 OAuth 2.1 网关作为服务器前端。
- 编写一个使用 OTel GenAI 属性进行端到端链路追踪的多服务器客户端。
- 将部分工作负载委托给 A2A 子 Agent；验证不透明性得到保留。
- 使用 AGENTS.md + SKILL.md 打包整个技术栈，以便其他 Agent 可以驱动它。

## 问题

交付"研究与报告"系统：

- 用户问："总结 2026 年关于 Agent 协议的被引用最多的三篇 arXiv 论文。"
- 系统：通过 MCP 搜索 arXiv；通过 A2A 将论文摘要委托给专门的写作 Agent；聚合结果；将交互式报告渲染为 MCP Apps `ui://` 资源；将每个步骤记录到 OTel。

Phase 13 的所有原语都出现了。这不是玩具 —— 2026 年发布的由 Anthropic（Claude Research 产品）、OpenAI（使用 Apps SDK 的 GPTs）和第三方构建的生产级研究助手系统正是这种形态。

## 概念

### 架构

```
[user] -> [client] -> [gateway (OAuth 2.1 + RBAC)] -> [research MCP server]
                                                      |
                                                      +- MCP tool: arxiv_search (纯工具)
                                                      +- MCP resource: notes://recent
                                                      +- MCP prompt: /research_topic
                                                      +- MCP task: generate_report (长时任务)
                                                      +- MCP Apps UI: ui://report/current
                                                      +- A2A call: writer-agent (tasks/send)
                                                      |
                                                      +- OTel GenAI spans
```

### 链路层级

```
agent.invoke_agent
 ├── llm.chat (启动)
 ├── mcp.call -> tools/call arxiv_search
 ├── mcp.call -> resources/read notes://recent
 ├── mcp.call -> prompts/get research_topic
 ├── a2a.tasks/send -> writer-agent
 │    └── task transitions (不透明的内部)
 ├── mcp.call -> tools/call generate_report (任务增强)
 │    └── tasks/status polling
 │    └── tasks/result (completed, returns ui:// resource)
 └── llm.chat (最终综合)
```

一个 trace id。每个 span 都有正确的 `gen_ai.*` 属性。

### 安全姿态

- OAuth 2.1 + PKCE，使用资源指示器将受众锁定到网关。
- 网关持有上游凭据；用户永远看不到它们。
- RBAC：`alice` 拥有 `research:read`、`research:write`，可以调用所有工具。`bob` 拥有 `research:read`，不能调用 `generate_report`。
- 锁定描述清单：移除任何工具哈希已变更的服务器。
- 二选规则审计：没有工具同时组合不可信输入、敏感数据和有后果的操作。

### 渲染

最终的 `generate_report` 任务返回内容块以及一个 `ui://report/current` 资源。客户端的宿主机（Claude Desktop 等）在沙盒 iframe 中渲染交互式仪表盘。仪表盘包含排序的论文列表、引用次数，以及一个对于用户点击的任何论文调用 `host.callTool('summarize_paper', {arxiv_id})` 的按钮。

### 打包

整个系统以如下形式交付：

```
research-system/
  AGENTS.md                     # 项目约定
  skills/
    run-research/
      SKILL.md                  # 顶层工作流程
  servers/
    research-mcp/               # MCP 服务器
      pyproject.toml
      src/
  agents/
    writer/                     # A2A Agent
  gateway/
    config.yaml                 # RBAC + 锁定清单
```

用户使用 `docker compose up` 部署。Claude Code、Cursor、Codex 和 opencode 用户可以通过调用 `run-research` 技能来驱动系统。

### Phase 13 各课程贡献了什么

| 课程 | 综合项目使用的内容 |
|--------|------------------------|
| 01-05 | 工具接口、提供商可移植性、并行调用、schema、检查 |
| 06-10 | MCP 原语、服务器、客户端、传输层、资源 + 提示词 |
| 11-14 | 采样、Roots + Elicitation、异步任务、`ui://` 应用 |
| 15-17 | 工具投毒、OAuth 2.1、网关 + 注册表 |
| 18 | A2A 子 Agent 委托 |
| 19 | OTel GenAI 链路追踪 |
| 20 | LLM 层的路由网关 |
| 21 | SKILL.md + AGENTS.md 打包 |

## 使用

`code/main.py` 将前面课程的模式拼接成一个可运行的演示。全部使用标准库，全部在进程内，以便你可以端到端阅读。它运行研究与报告场景的完整流程：与网关握手，模拟 OAuth 2.1，合并工具列表，将 generate_report 作为任务，A2A 调用 writer，返回 ui:// 资源，发出 OTel spans。

需要关注的内容：

- 每个跳之间共享一个 trace id。
- 网关策略阻止第二个用户的写入操作。
- 任务生命周期走 working → completed，并返回文本和 ui:// 内容。
- A2A 调用的内部状态对编排器是不透明的。
- AGENTS.md 和 SKILL.md 是其他 Agent 重现此工作流程所需的唯一文件。

## 交付物

本课产出 `outputs/skill-ecosystem-blueprint.md`。给定一个产品需求（研究、摘要、自动化），该技能生成完整架构：使用哪些 MCP 原语、哪些网关控制、哪些 A2A 调用、哪些遥测、哪些打包。

## 练习

1. 运行 `code/main.py`。注意单个 trace id 以及 spans 如何嵌套。统计演示触及了 Phase 13 的多少原语。

2. 扩展演示：添加第二个后端 MCP 服务器（例如 `bibliography`），确认网关将其工具合并到同一命名空间中。

3. 将伪造的 A2A 写作 Agent 替换为在子进程中运行的真实 Agent。使用第 19 课的实验环境。

4. 在编排器和 LLM 之间的路由网关中添加 PII 脱敏步骤。确认用户查询中的邮件地址被清洗。

5. 为将维护此系统的队友编写一个 AGENTS.md。它应该在五分钟内读完，并给他们提供在 Cursor 或 Codex 中驱动此综合项目所需的一切。

## 关键术语

| 术语 | 常见说法 | 实际含义 |
|------|----------|----------|
| Capstone（综合项目） | "Phase 13 集成演示" | 使用每个原语的端到端系统 |
| Research and report（研究与报告） | "场景" | 搜索、摘要、渲染模式 |
| Ecosystem（生态） | "所有部分组合在一起" | 服务器 + 客户端 + 网关 + 子 Agent + 遥测 + 打包 |
| Trace hierarchy（链路层级） | "单个 trace id" | 每个跳的 span 共享 trace；父子关系通过 span id 链接 |
| Gateway-issued token（网关签发令牌） | "传递认证" | 客户端只看到网关的令牌；网关持有上游凭据 |
| Merged namespace（合并命名空间） | "所有工具在一个扁平列表中" | 网关处的多服务器合并，冲突时加前缀 |
| Opacity boundary（不透明边界） | "A2A 调用隐藏内部" | 子 Agent 的推理对编排器不可见 |
| Three-layer stack（三层技术栈） | "AGENTS.md + SKILL.md + MCP" | 项目上下文 + 工作流程 + 工具 |
| Defense-in-depth（纵深防御） | "多层安全" | 锁定哈希、OAuth、RBAC、二选规则、审计日志 |
| Spec compliance matrix（规范合规矩阵） | "我们交付的内容符合规范要求" | 将交付物映射到 2025-11-25 要求的清单 |

## 扩展阅读

- [MCP — Specification 2025-11-25](https://modelcontextprotocol.io/specification/2025-11-25) — 统一参考
- [MCP blog — 2026 roadmap](https://blog.modelcontextprotocol.io/posts/2026-mcp-roadmap/) — 协议发展方向
- [a2a-protocol.org](https://a2a-protocol.org/latest/) — A2A v1.0 参考
- [OpenTelemetry — GenAI semconv](https://opentelemetry.io/docs/specs/semconv/gen-ai/) — 权威链路追踪约定
- [Anthropic — Claude Agent SDK overview](https://code.claude.com/docs/en/agent-sdk/overview) — 生产级 Agent 运行时模式