# LLM 路由层 —— LiteLLM、OpenRouter、Portkey

> 锁定一个提供商代价高昂。不同的工具调用工作负载适合不同的模型。路由网关提供统一的 API 接口、重试、故障转移、成本追踪和护栏。2026 年有三种主导原型：LiteLLM（开源自托管）、OpenRouter（托管 SaaS）、Portkey（生产级，2026 年 3 月开源）。本课列出决策标准并演示一个标准库路由网关。

**类型：** 学习
**语言：** Python（标准库，路由 + 故障转移 + 成本追踪器）
**前置要求：** Phase 13 · 02（函数调用），Phase 13 · 17（网关）
**时间：** ~45 分钟

## 学习目标

- 区分自托管、托管和生产级路由选项。
- 实现一个在提供商失败时按定义的优先级顺序重试的回退链。
- 跨提供商追踪每个请求的成本和令牌使用。
- 在给定生产约束的情况下，在 LiteLLM、OpenRouter 和 Portkey 之间做出选择。

## 问题

提供商路由至关重要的场景：

1. **成本。** Claude Sonnet 的成本是 Haiku 的 3 倍。对于分类任务，Haiku 足够；对于综合任务，Sonnet 值得。按请求路由。

2. **故障转移。** OpenAI 有一个糟糕的小时。每个请求都失败。你希望自动回退到 Anthropic，无需重新部署。

3. **延迟。** 实时聊天 UI 需要快速的首令牌时间。批量摘要器不需要。按延迟 SLA 路由。

4. **合规。** 欧盟用户必须留在欧盟区域。按区域路由。

5. **实验。** 在同一工作负载上对两个模型进行 A/B 测试。按测试桶路由。

为每个集成手动编码所有这些是重复劳动。路由网关提供一个 OpenAI 兼容的 API，并处理其余部分。

## 概念

### OpenAI 兼容的代理形式

所有人都使用 OpenAI 形态。路由网关暴露 `/v1/chat/completions`，接受 OpenAI 模式，并在内部代理到 Anthropic / Gemini / Cohere / Ollama / 任何其他服务。客户端无需关心。

### 模型别名

不用 `claude-3-5-sonnet-20251022`，你的代码说 `our_smart_model`。网关将别名映射到真实模型。当 Anthropic 发布 Claude 4 时，你在服务器端更改别名；你的代码不做任何修改。

### 回退链

```
主选: openai/gpt-4o
遇5xx: anthropic/claude-3-5-sonnet
遇5xx: google/gemini-1.5-pro
遇5xx: 拒绝
```

网关在配置中定义这些。重试计入预算，因此回退级联不会导致成本爆炸。

### 语义缓存

相同或几乎相同的提示词命中缓存而非提供商。在重复的 Agent 循环中可节省 30% 到 60%。键基于嵌入向量；几乎相同的提示词共享一个缓存槽。

### 护栏

网关级别：

- **PII 脱敏。** 在发送提示词之前进行基于正则表达式或机器学习的脱敏。
- **策略违规。** 拒绝包含被禁止内容的提示词。
- **输出过滤。** 清理补全中的泄露信息。

Portkey 和 Kong 都提供了有主见的护栏。LiteLLM 将它们保留为可选。

### 按密钥限流

一个 API 密钥 = 一个团队。按密钥的预算防止一个团队消耗共享配额。大多数网关支持此功能。

### 自托管 vs 托管的权衡

| 因素 | LiteLLM（自托管） | OpenRouter（托管） | Portkey（生产级） |
|--------|----------------------|----------------------|----------------------|
| 代码 | 开源，Python | 托管 SaaS | 开源（2026 年 3 月）+ 托管 |
| 部署 | 部署代理 | 注册即可 | 两者均可 |
| 提供商 | 100+ | 300+ | 100+ |
| 计费 | 你自己的密钥 | OpenRouter 额度 | 你自己的密钥 |
| 可观测性 | OpenTelemetry | 仪表盘 | 完整 OTel + PII 脱敏 |
| 最适合 | 希望完全控制的团队 | 快速原型开发 | 有合规要求的生产环境 |

当你有 SRE 团队并希望数据主权时，LiteLLM 胜出。当你想要单个订阅且无需基础设施时，OpenRouter 胜出。当你需要开箱即用的护栏和合规时，Portkey 胜出。

### 成本追踪

每个请求携带 `provider`、`model`、`input_tokens`、`output_tokens`。乘以每个模型每个令牌的价格（从网关维护的价格表中拉取）。按用户 / 按团队 / 按项目聚合。

### MCP 加路由

网关可以同时路由 LLM 调用和 MCP 采样请求。当采样请求的 modelPreferences 偏好特定模型时，网关转换到正确的后端。这就是 Phase 13 · 17（MCP 网关）和本课的路由网关有时合并为一个服务的地方。

### 路由策略

- **静态优先级。** 列表中的第一个；出错时回退。
- **负载均衡。** 轮询或加权。
- **成本感知。** 选择满足延迟 / 质量的最便宜模型。
- **延迟感知。** 选择过去 N 分钟内最快的模型。
- **任务感知。** 提示词分类器将编码路由到一个模型，将摘要路由到另一个模型。

## 使用

`code/main.py` 在约 150 行中实现了一个路由网关：接受 OpenAI 形态的请求，转换到每个提供商的桩，运行优先级回退链，追踪每个请求的成本，并对输入应用 PII 脱敏。用三种场景运行它：正常请求、主提供商中断触发回退、PII 泄露被脱敏捕获。

需要关注的内容：

- `ROUTES` 字典：别名 -> 优先级排序的具体提供商列表。
- 回退循环在 5xx 时重试。
- 成本追踪器将令牌使用乘以每个模型的费率。
- PII 脱敏器在转发之前清洗 SSN 格式的模式。

## 交付物

本课产出 `outputs/skill-routing-config-designer.md`。给定工作负载配置文件（延迟、成本、合规），该技能选择 LiteLLM / OpenRouter / Portkey 并生成路由配置。

## 练习

1. 运行 `code/main.py`。触发中断场景；确认回退落在第二个提供商上且成本正确归因。

2. 添加语义缓存：提示词的 SHA256 是查找键；缓存命中立即返回。衡量重复调用上的成本节省。

3. 添加一个提示词分类器，将 "code ..." 提示词路由到偏好智能的别名，将 "summarize ..." 提示词路由到偏好速度的别名。

4. 设计按团队预算：每个团队有月度消费上限；网关在达到上限后拒绝请求。选择强制粒度（按请求或窗口化）。

5. 并排阅读 LiteLLM、OpenRouter 和 Portkey 的文档。说出每个产品提供而其他两个没有的一项功能。

## 关键术语

| 术语 | 常见说法 | 实际含义 |
|------|----------|----------|
| Routing gateway（路由网关） | "LLM 代理" | 位于许多提供商之前的单一 API 接口层 |
| OpenAI-compatible（OpenAI 兼容） | "使用 OpenAI 模式" | 接受 `/v1/chat/completions` 形态，转换到任何后端 |
| Model alias（模型别名） | "our_smart_model" | 代码中使用的名称，网关映射到具体模型 |
| Fallback chain（回退链） | "重试列表" | 失败时尝试的有序提供商列表 |
| Semantic caching（语义缓存） | "提示词嵌入缓存" | 键是提示词的嵌入向量；近重复项共享缓存命中 |
| Guardrails（护栏） | "输入/输出过滤器" | 脱敏 PII，拒绝策略违规 |
| Per-key rate limit（按密钥限流） | "团队预算" | 限定到 API 密钥的配额 |
| Cost tracking（成本追踪） | "按请求花费" | 聚合令牌使用量 × 每个模型的价格 |
| LiteLLM | "开放代理" | 可自托管的开源路由网关 |
| OpenRouter | "托管 SaaS" | 带信用额度计费的托管网关 |
| Portkey | "生产级选项" | 开源 + 托管，内置护栏 |

## 扩展阅读

- [LiteLLM — docs](https://docs.litellm.ai/) — 自托管路由网关
- [OpenRouter — quickstart](https://openrouter.ai/docs/quickstart) — 托管路由 SaaS
- [Portkey — docs](https://portkey.ai/docs) — 带护栏的生产级路由
- [TrueFoundry — LiteLLM vs OpenRouter](https://www.truefoundry.com/blog/litellm-vs-openrouter) — 决策指南
- [Relayplane — LLM gateway comparison 2026](https://relayplane.com/blog/llm-gateway-comparison-2026) — 供应商调查