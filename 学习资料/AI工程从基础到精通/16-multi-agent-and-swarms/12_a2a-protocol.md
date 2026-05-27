# A2A——Agent-to-Agent 协议

> Google 于 2025 年 4 月宣布 A2A；到 2026 年 4 月，规范在 https://a2a-protocol.org/latest/specification/，150+ 个组织支持它。A2A 是 MCP（第 13 课）的水平补充：MCP 是垂直的（代理 ↔ 工具），A2A 是点对点的（代理 ↔ 代理）。它定义了代理卡片（Agent Card，用于发现）、带有工件的任务（文本、结构化数据、视频）、不透明的任务生命周期和认证。生产系统越来越多地将 MCP 与 A2A 配对。Google Cloud 在 2025-2026 年间将 A2A 支持推出到 Vertex AI Agent Builder。

**类型：** 学习 + 构建
**语言：** Python（标准库、`http.server`、`json`）
**前置知识：** 第 16 阶段 · 04（原语模型）
**时间：** 约 75 分钟

## 问题

你的代理需要调用另一个系统上的另一个代理。怎么做？你可以暴露一个 HTTP 端点，定义一个定制的 JSON Schema，并希望对端也用它。每对代理都成为一个自定义集成。

A2A 是用于该调用的通用传输协议。标准发现、标准任务模型、标准传输、标准工件。就像 HTTP+REST，但将代理作为一等公民。

## 概念

### 四个元素

**代理卡片（Agent Card）。** 位于 `/.well-known/agent.json` 的 JSON 文档，描述代理：名称、技能、端点、支持的模态、认证要求。发现通过读取卡片完成。

```
GET https://agent.example.com/.well-known/agent.json
→ {
    "name": "code-review-agent",
    "skills": ["review-python", "review-typescript"],
    "endpoints": {
      "tasks": "https://agent.example.com/tasks"
    },
    "auth": {"type": "bearer"},
    "modalities": ["text", "structured"]
  }
```

**任务（Task）。** 工作单元。一个异步、有状态的对象，具有生命周期：`submitted → working → completed / failed / canceled`。客户端发送任务，轮询或订阅更新。

**工件（Artifact）。** 任务产生的结果类型。文本、结构化 JSON、图像、视频、音频。工件是类型化的，因此不同模态是一等公民。

**不透明生命周期（Opaque Lifecycle）。** A2A 不规定远程代理*如何*解决任务。客户端看到状态转换和工件；实现可以自由使用任何框架。

### MCP/A2A 划分

- **MCP**（第 13 课）：代理 ↔ 工具。代理通过 JSON-RPC 对工具服务器进行读/写。默认无状态。
- **A2A**：代理 ↔ 代理。对等协议；双方都是具有自己推理的代理。

生产多代理系统两者都用。A2A 对等方在其一侧调用 MCP 工具。划分使两个关注点保持干净。

### 发现流程

```
客户端                     代理服务器
  ├──GET /.well-known/agent.json──>
  <──Agent Card JSON─────────────
  ├──POST /tasks {skill, input}──>
  <──201 task_id, state=submitted
  ├──GET /tasks/{id}──────────────>
  <──state=working, 42% done──────
  ├──GET /tasks/{id}──────────────>
  <──state=completed, artifacts──
```

或者使用流式：SSE 订阅 `/tasks/{id}/events` 用于推送更新。

### 认证

A2A 支持三种常见模式：

- **Bearer Token** — OAuth2 或不透明令牌。
- **mTLS** — 双向 TLS；组织相互证明身份。
- **签名请求** — 对有效载荷进行 HMAC。

认证在代理卡片中声明；客户端发现并遵守。

### 到 2026 年 4 月 150+ 个组织

企业采用推动了 A2A 的规模。头条：A2A 成为企业代理系统跨越信任边界的方式。Google Cloud 发布了 Vertex AI Agent Builder A2A 支持；Microsoft Agent Framework 支持它；大多数主要框架（LangGraph、CrewAI、AutoGen）都提供了 A2A 适配器。

### A2A 在哪些方面胜出

- **跨组织调用。** 公司 A 的代理调用公司 B 的代理。没有 A2A，每对都是一个定制契约。
- **异构框架。** LangGraph 代理调用 CrewAI 代理调用自定义 Python 代理。A2A 标准化。
- **类型化工件。** 视频结果、结构化 JSON、音频——全都是一等公民。
- **长时间运行的任务。** 不透明生命周期 + 轮询使数小时长的任务变得简单。

### A2A 在哪些方面挣扎

- **延迟敏感的微调用。** A2A 的生命周期是异步的。亚毫秒代理到代理不适合；使用直接 RPC。
- **紧耦合进程内代理。** 如果两个代理在同一 Python 进程中运行，A2A 的 HTTP 往返是杀鸡用牛刀。
- **小团队。** 规范开销是真实的；仅内部代理可能不需要这种形式化。

### A2A vs ACP、ANP、NLIP

几个相关规范在 2024-2026 年间出现：

- **ACP**（IBM/Linux Foundation）— A2A 的前身，范围更窄。
- **ANP**（Agent Network Protocol）— 重对等发现，去中心化优先。
- **NLIP**（Ecma 自然语言交互协议，2025 年 12 月标准化）— 自然语言内容类型。

截至 2026 年 4 月，A2A 是采用最广泛的对等协议。参见 arXiv:2505.02279（Liu 等人，「A Survey of Agent Interoperability Protocols」）进行比较。

## 构建

`code/main.py` 使用 `http.server` 和 JSON 实现了一个 A2A 最小服务器和客户端。服务器：

- 暴露 `/.well-known/agent.json`，
- 接受 `POST /tasks`，
- 管理任务状态，
- 在 `GET /tasks/{id}` 上返回工件。

客户端：

- 获取代理卡片，
- 提交任务，
- 轮询直到完成，
- 读取工件。

运行：

```
python3 code/main.py
```

脚本在后台线程中启动服务器，然后对服务器运行客户端。你看到完整流程：发现、提交、轮询、工件。

## 实践

`outputs/skill-a2a-integrator.md` 设计一个 A2A 集成：代理卡片内容、任务 Schema、认证选择、流式 vs 轮询。

## 交付

检查清单：

- **固定规范版本。** A2A 仍在演进；代理卡片应声明协议版本。
- **幂等任务创建。** 重复提交（网络重试）应产生一个任务。
- **工件 Schema。** 声明代理返回什么形状；消费者应验证。
- **速率限制 + 认证。** A2A 面向公共；应用标准 Web 安全。
- **失败任务的死信。** 随时间检查模式以查找重复出现的失败类型。

## 练习

1. 运行 `code/main.py`。确认客户端发现服务器并接收正确的工件。
2. 向服务器添加第二个技能（例如，「summarize」）。更新代理卡片。编写一个根据任务类型挑选技能的客户端。
3. 实现 SSE 流端点：`/tasks/{id}/events` 发出状态变化。客户端需要做什么不同？
4. 阅读 A2A 规范（https://a2a-protocol.org/latest/specification/）。识别规范强制但此演示未实现的三件事。
5. 比较 A2A（Agent Card 发现）与 MCP（通过 `listTools` 进行服务器端能力列表）。自描述代理与能力探测之间的权衡是什么？

## 关键术语

| 术语 | 人们说的 | 实际含义 |
|------|---------|---------|
| A2A | 「代理到代理」 | 代理跨系统调用其他代理的对等协议。Google 2025。 |
| Agent Card | 「代理的名片」 | 位于 `/.well-known/agent.json` 的 JSON，描述技能、端点、认证。 |
| Task | 「工作单元」 | 具有生命周期的异步有状态对象；完成时产生工件。 |
| Artifact | 「结果」 | 类型化输出：文本、结构化 JSON、图像、视频、音频。一等媒体。 |
| Opaque lifecycle | 「如何解决是代理的事」 | 客户端看到状态转换；服务器自由选择框架/工具。 |
| Discovery | 「找到代理」 | `GET /.well-known/agent.json` 返回卡片。 |
| MCP vs A2A | 「工具 vs 对等方」 | MCP：垂直代理 ↔ 工具。A2A：水平代理 ↔ 代理。 |
| ACP / ANP / NLIP | 「兄弟协议」 | 相邻规范；A2A 是 2026 年采用最广泛的。 |

## 扩展阅读

- [A2A 规范](https://a2a-protocol.org/latest/specification/) — 规范规范
- [Google 开发者博客 — A2A 公告](https://developers.googleblog.com/en/a2a-a-new-era-of-agent-interoperability/) — 2025 年 4 月发布文章
- [A2A GitHub 仓库](https://github.com/a2aproject/A2A) — 参考实现和 SDK
- [Liu 等人 — 代理互操作性协议综述](https://arxiv.org/html/2505.02279v1) — MCP、ACP、A2A、ANP 比较