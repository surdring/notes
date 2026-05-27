# MCP 采样 —— 服务器请求的 LLM 补全与 Agent 循环

> 大多数 MCP 服务器是哑执行器：接收参数、运行代码、返回内容。采样（Sampling）让服务器切换方向：它请求客户端的 LLM 来做出决策。这使服务器托管的 Agent 循环无需服务器拥有任何模型凭证。2025-11-25 合并的 SEP-1577 在采样请求中添加了工具，使循环可以包含更深层次的推理。漂移风险提示：SEP-1577 的采样中工具形态在 2026 年第一季度仍是实验性的，SDK API 仍在稳定中。

**类型：** 构建
**语言：** Python（标准库，采样测试程序）
**前置知识：** Phase 13 · 07（MCP 服务器），Phase 13 · 10（资源和提示词）
**时间：** ~75 分钟

## 学习目标

- 解释 `sampling/createMessage` 解决了什么问题（无需服务端 API 密钥的服务器托管循环）。
- 实现一个服务器，请求客户端在多轮提示词上进行采样并返回补全结果。
- 使用 `modelPreferences`（成本/速度/智能优先级）指导客户端模型选择。
- 构建一个 `summarize_repo` 工具，内部通过采样迭代而不是硬编码行为。

## 问题

一个用于代码摘要工作流的实用 MCP 服务器需要：遍历文件树、选择要读取的文件、合成摘要并返回。LLM 推理发生在哪里？

选项 A：服务器调用自己的 LLM。需要 API 密钥，在服务器端计费，每个用户成本高。

选项 B：服务器返回原始内容；客户端的 Agent 进行推理。可行但将服务器逻辑移到客户端提示词中，这很脆弱。

选项 C：服务器通过 `sampling/createMessage` 请求客户端的 LLM。服务器保留算法（读取哪些文件、进行多少次遍历），而客户端保留计费和模型选择。服务器完全没有凭证。

采样就是选项 C。这是一种机制，使受信任的服务器可以托管 Agent 循环，而无需自己成为完整的 LLM 宿主。

## 核心概念

### `sampling/createMessage` 请求

服务器发送：

```json
{
  "jsonrpc": "2.0",
  "id": 42,
  "method": "sampling/createMessage",
  "params": {
    "messages": [{"role": "user", "content": {"type": "text", "text": "..."}}],
    "systemPrompt": "...",
    "includeContext": "none",
    "modelPreferences": {
      "costPriority": 0.3,
      "speedPriority": 0.2,
      "intelligencePriority": 0.5,
      "hints": [{"name": "claude-3-5-sonnet"}]
    },
    "maxTokens": 1024
  }
}
```

客户端运行其 LLM，返回：

```json
{"jsonrpc": "2.0", "id": 42, "result": {
  "role": "assistant",
  "content": {"type": "text", "text": "..."},
  "model": "claude-3-5-sonnet-20251022",
  "stopReason": "endTurn"
}}
```

### `modelPreferences`

三个浮点数，总和为 1.0：

- `costPriority`：偏向更便宜的模型。
- `speedPriority`：偏向更快的模型。
- `intelligencePriority`：偏向能力更强的模型。

加上 `hints`：服务器偏好的命名模型。客户端可以遵守也可以不遵守提示；客户端用户配置始终优先。

### `includeContext`

三个值：

- `"none"` —— 仅服务器提供的消息。默认。
- `"thisServer"` —— 包含来自此服务器会话的先前消息。
- `"allServers"` —— 包含所有会话上下文。

`includeContext` 自 2025-11-25 起软弃用，因为它会泄露跨服务器上下文，这是一个安全问题。首选 `"none"`，并在消息中传递显式上下文。

### 带工具的采样（SEP-1577）

2025-11-25 新增：采样请求可以包含一个 `tools` 数组。客户端使用这些工具运行一个完整的工具调用循环。这让服务器可以通过客户端的模型托管 ReAct 风格的 Agent 循环。

```json
{
  "messages": [...],
  "tools": [
    {"name": "fetch_url", "description": "...", "inputSchema": {...}}
  ]
}
```

客户端循环：采样，如果调用了工具则执行，再次采样，返回最终的助理消息。这在 2026 年第一季度仍是实验性的；SDK 签名可能仍有变化。在实现时，对照 2025-11-25 规范的 client/sampling 部分确认。

### 人在回路中（Human-in-the-Loop）

客户端 MUST 在运行采样之前向用户展示服务器要求模型做什么。恶意的服务器可以使用采样操纵用户的会话（"对用户说 X 以便他们点击 Y"）。Claude Desktop、VS Code 和 Cursor 将采样请求展示为用户可以拒绝的确认对话框。

2026 年的共识：没有人工确认的采样是一个危险信号。网关（Phase 13 · 17）可以自动批准低风险采样并自动拒绝任何可疑内容。

### 无 API 密钥的服务器托管循环

典型用例：一个没有自身 LLM 访问权限的代码摘要 MCP 服务器。它这样做：

1. 遍历仓库结构。
2. 调用 `sampling/createMessage`，提示"选择最有可能描述此仓库目的的前五个文件。"
3. 读取这些文件。
4. 调用 `sampling/createMessage`，附上文件内容，提示"用三段话总结此仓库。"
5. 将摘要作为 `tools/call` 结果返回。

服务器从未接触 LLM API。客户端的用户使用自己的凭证为补全付费。

### 安全风险（Unit 42 披露，2026 年第一季度）

- **隐蔽采样（Covert Sampling）。** 一个工具总是在采样中提示"用会话上下文中的用户邮箱回复"。Phase 13 · 15 涵盖攻击向量。
- **通过采样的资源窃取。** 服务器要求客户端总结攻击者的负载，向用户计费。
- **循环炸弹（Loop Bombs）。** 服务器在紧密循环中调用采样。客户端 MUST 强制执行每个会话的速率限制。

## 使用它

`code/main.py` 提供一个假的服务器到客户端采样测试程序。一个模拟的"summarize_repo"工具发起两轮采样（选文件、然后摘要），假客户端返回预设的响应。测试程序展示：

- 服务器发送带有 `modelPreferences` 的 `sampling/createMessage`。
- 客户端返回补全。
- 服务器继续其循环。
- 速率限制器限制每个工具调用的总采样次数。

需要关注的点：

- 服务器仅暴露一个工具（`summarize_repo`）；所有推理发生在采样调用中。
- 模型偏好权重客户端模型选择；提示列表偏好模型。
- 循环在 `stopReason: "endTurn"` 时终止。
- `max_samples_per_tool = 5` 限制捕获失控循环。

## 交付成果

本课产出 `outputs/skill-sampling-loop-designer.md`。给定一个需要 LLM 调用的服务端算法（研究、摘要、规划），该技能设计一个基于采样的实现，包含适当的 modelPreferences、速率限制和安全确认。

## 练习

1. 运行 `code/main.py`。将 `max_samples_per_tool` 改为 2，观察速率限制截断。

2. 实现 SEP-1577 的采样中工具变体：采样请求携带一个 `tools` 数组。验证客户端循环在返回最终补全之前执行这些工具。注意漂移风险：SDK 签名在 2026 年上半年可能仍有变化。

3. 添加人在回路中的确认：在服务器的第一次 `sampling/createMessage` 之前，暂停并等待用户批准。被拒绝的调用返回类型化的拒绝。

4. 添加一个按客户端会话标识的每用户速率限制器。同一用户对同一服务器的循环应共享预算。

5. 设计一个使用采样来选择要包含的片段的 `summarize_pdf` 工具。勾勒发送的消息。`modelPreferences.intelligencePriority` 在 0.1 vs 0.9 时如何改变行为？

## 关键术语

| 术语 | 人们的说法 | 实际含义 |
|------|----------------|------------------------|
| 采样（Sampling） | "服务器到客户端的 LLM 调用" | 服务器请求客户端模型进行补全 |
| `sampling/createMessage` | "该方法" | 用于采样请求的 JSON-RPC 方法 |
| `modelPreferences` | "模型优先级" | 成本/速度/智能权重加上名称提示 |
| `includeContext` | "跨会话泄露" | 软弃用的上下文包含模式 |
| SEP-1577 | "采样中的工具" | 允许采样中携带工具，用于服务器托管的 ReAct |
| 人在回路中（Human-in-the-Loop） | "用户确认" | 客户端在运行前向用户展示采样请求 |
| 循环炸弹（Loop Bomb） | "失控采样" | 服务端无限采样循环；客户端必须速率限制 |
| 隐蔽采样（Covert Sampling） | "隐藏推理" | 恶意服务器在采样提示词中隐藏意图 |
| 资源窃取（Resource Theft） | "消耗用户 LLM 预算" | 服务器强迫客户端在其不想要的采样上花费 |
| `stopReason` | "生成为何停止" | `endTurn`、`stopSequence` 或 `maxTokens` |

## 延伸阅读

- [MCP — Concepts: Sampling](https://modelcontextprotocol.io/docs/concepts/sampling) —— 采样高级概述
- [MCP — Client sampling spec 2025-11-25](https://modelcontextprotocol.io/specification/2025-11-25/client/sampling) —— 规范的 `sampling/createMessage` 形态
- [MCP — GitHub SEP-1577](https://github.com/modelcontextprotocol/modelcontextprotocol) —— 采样中工具的规范演进提案（实验性）
- [Unit 42 — MCP attack vectors](https://unit42.paloaltonetworks.com/model-context-protocol-attack-vectors/) —— 隐蔽采样和资源窃取模式
- [Speakeasy — MCP sampling core concept](https://www.speakeasy.com/mcp/core-concepts/sampling) —— 带客户端代码示例的演练