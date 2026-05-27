# AI 网关 — LiteLLM、Portkey、Kong AI Gateway、Bifrost

> 网关位于你的应用和模型供应商之间。核心功能是供应商路由、故障转移（Fallback）、重试、速率限制（Rate Limiting）、密钥引用、可观测性（Observability）、护栏（Guardrails）。2026 年的市场分布：**LiteLLM** 是 MIT OSS，支持 100+ 供应商，OpenAI 兼容，但在约 2000 RPS（8 GB 内存，已发布基准中的级联故障）附近会崩溃；最适合 Python、<500 RPS、开发/原型。**Portkey** 定位于控制平面（护栏、PII 脱敏、越狱检测、审计追踪），2026 年 3 月开源为 Apache 2.0，20-40 ms 延迟开销，$49/月生产层。**Kong AI Gateway** 构建在 Kong Gateway 之上——Kong 自己的基准测试相同 12 CPU 下：比 Portkey 快 228%，比 LiteLLM 快 859%；定价 $100/模型/月（Plus 层最多 5 个）；如果你已在 Kong 上，适合企业场景。**Bifrost**（Maxim AI）——可配置退避的自动重试、OpenAI 429 时故障转移到 Anthropic。**Cloudflare / Vercel AI Gateways**——托管、零运维、基础重试。数据驻留决定了自托管决策；Portkey 和 Kong 以开源 + 可选托管居中。

**类型：** 学习
**语言：** Python（标准库，玩具级网关路由模拟器）
**前置知识：** 第 17 阶段 · 01（托管 LLM 平台），第 17 阶段 · 16（模型路由）
**时间：** 约 60 分钟

## 学习目标

- 列举七个核心网关功能（路由、故障转移、重试、速率限制、密钥、可观测性、护栏）。
- 将四个 2026 年网关（LiteLLM、Portkey、Kong AI、Bifrost）映射到其规模上限和使用场景。
- 引用 Kong 基准测试（比 Portkey 快 228%，比 LiteLLM 快 859%）并解释在 >500 RPS 时为何重要。
- 在数据驻留和运维预算的约束下选择自托管 vs 托管方案。

## 问题

你的产品调用 OpenAI、Anthropic 和一个自托管 Llama。每个供应商有不同的 SDK、错误模型、速率限制和认证方案。你希望故障转移（如果 OpenAI 429，尝试 Anthropic）、统一密钥存储、统合可观测性以及按租户的速率限制。

在应用层重新实现这些会将每个服务耦合到每个供应商。网关层将其整合到一个进程，提供单一 API（通常是 OpenAI 兼容），分发到各供应商。

## 概念

### 七个核心功能

1. **供应商路由** — OpenAI、Anthropic、Gemini、自托管等，在单一 API 背后。
2. **故障转移（Fallback）** — 在 429、5xx 或质量失败时，在其他地方重试。
3. **重试** — 指数退避（Exponential Backoff），有界尝试。
4. **速率限制（Rate Limit）** — 按租户、按密钥、按模型。
5. **密钥引用** — 运行时从密钥库（Vault）拉取凭据（绝不在应用中）。
6. **可观测性** — OTel + GenAI 属性（第 17 阶段 · 13）+ 成本归因。
7. **护栏（Guardrails）** — PII 脱敏（PII Redaction）、越狱检测（Jailbreak Detection）、允许主题过滤。

### LiteLLM — MIT OSS，Python

- 100+ 供应商，OpenAI 兼容，路由器配置，故障转移，基础可观测性。
- 在 Kong 的基准测试中约 2000 RPS 崩溃；8 GB 内存占用，持续负载下级联故障。
- 最佳场景：Python 应用，<500 RPS，开发/预发布网关，实验性路由。
- 成本：OSS 免费；云端有免费层。

### Portkey — 控制平面定位

- 2026 年 3 月起 Apache 2.0 开源。护栏、PII 脱敏、越狱检测、审计追踪。
- 每次请求 20-40 ms 延迟开销。
- $49/月生产层，含保留期 + SLA。
- 最佳场景：需要护栏 + 可观测性捆绑的受监管行业。

### Kong AI Gateway — 规模化方案

- 构建在 Kong Gateway 之上（成熟的 API 网关产品，lua+OpenResty）。
- Kong 自己的基准测试 12 CPU 等价环境：比 Portkey 快 228%，比 LiteLLM 快 859%。
- 定价：$100/模型/月，Plus 层最多 5 个模型。
- 最佳场景：已在 Kong 上；>1000 RPS；愿意付费许可。

### Bifrost（Maxim AI）

- 可配置退避的自动重试。
- OpenAI 429 时故障转移到 Anthropic 是经典配方。
- 较新的参与者；商业产品。

### Cloudflare AI Gateway / Vercel AI Gateway

- 托管、零运维。基础重试和可观测性。
- 最佳场景：Cloudflare/Vercel 上的边缘推理 JavaScript 应用。
- 相比 Kong/Portkey，在护栏和速率限制方面有局限。

### 自托管 vs 托管

数据驻留是关键决策因素。医疗和金融默认自托管（LiteLLM 或 Portkey OSS 或 Kong）。消费级产品默认托管（Cloudflare AI Gateway）或中间方案（Portkey 托管）。混合方案：受监管租户自托管，其他托管。

### 延迟预算

- LiteLLM：典型 5-15 ms 开销。
- Portkey：20-40 ms 开销。
- Kong：3-8 ms 开销。
- Cloudflare/Vercel：1-3 ms 开销（边缘优势）。

网关延迟直接加到 TTFT 上。对于 TTFT P99 < 100 ms SLA，使用 Kong 或 Cloudflare。对于 P99 < 500 ms，任何方案都可以。

### 速率限制语义很重要

简单的令牌桶（Token-Bucket）可满足中等规模。多租户需要滑动窗口（Sliding-Window）+ 突发配额 + 按租户分层。LiteLLM 提供令牌桶；Kong 提供滑动窗口；Portkey 提供分层。

### 网关 + 可观测性 + 路由组合

第 17 阶段 · 13（可观测性）+ 16（模型路由）+ 19（网关）在生产中是同一个层面。选择一个覆盖三者全部的工具，或仔细配合：2026 年大多数部署组合 Helicone（可观测性）或 Portkey（护栏）与 Kong（规模）用于分工角色。

### 应记住的数字

- LiteLLM：在约 2000 RPS 崩溃，8 GB 内存。
- Portkey：20-40 ms 开销；2026 年 3 月起 Apache 2.0。
- Kong：比 Portkey 快 228%，比 LiteLLM 快 859%。
- Kong 定价：$100/模型/月，Plus 层最多 5 个模型。
- Cloudflare/Vercel：边缘 1-3 ms 开销。

## 使用它

`code/main.py` 模拟在 429/5xx 注入下跨 3 个供应商的网关路由与故障转移。报告延迟、重试率和故障转移命中率。

## 交付它

本课生成 `outputs/skill-gateway-picker.md`。根据规模、运维姿态、合规要求和延迟预算，选择网关。

## 练习

1. 运行 `code/main.py`。配置 OpenAI→Anthropic→自托管的故障转移。在 5% 供应商错误率下，预期命中率是多少？
2. 你的 SLA 是 TTFT P99 < 200 ms，基线 300 ms。哪些网关在预算内？
3. 一个医疗客户要求自托管 + PII 脱敏 + 审计。选择 Portkey OSS 或 Kong。
4. 对比 LiteLLM vs Kong：团队应在什么 RPS 上限下迁移？
5. 设计一个多租户 SaaS 的速率限制策略：免费层、试用层、付费层。令牌桶还是滑动窗口？

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|----------------|------------------------|
| Gateway | "API 代理" | 位于应用和供应商之间的进程 |
| LiteLLM | "MIT 那个" | Python OSS，100+ 供应商，2K RPS 崩溃 |
| Portkey | "护栏网关" | 控制平面 + 可观测性，Apache 2.0 |
| Kong AI Gateway | "规模化那款" | 构建在 Kong Gateway 上，基准测试领先 |
| Bifrost | "Maxim 的网关" | 重试 + Anthropic 故障转移配方 |
| Cloudflare AI Gateway | "边缘托管" | 边缘部署的托管网关，零运维 |
| PII redaction | "数据脱敏" | 正则 + NER 掩码，发送给模型前 |
| Jailbreak detection | "提示注入守卫" | 对用户输入的分类器 |
| Audit trail | "受监管日志" | 每次 LLM 调用的不可变记录 |
| Token-bucket | "简单速率限制" | 基于补充的速率限制器 |
| Sliding-window | "精确速率限制" | 时间窗口速率限制器；公平性更好 |

## 延伸阅读

- [Kong AI Gateway Benchmark](https://konghq.com/blog/engineering/ai-gateway-benchmark-kong-ai-gateway-portkey-litellm)
- [TrueFoundry — AI Gateways 2026 Comparison](https://www.truefoundry.com/blog/a-definitive-guide-to-ai-gateways-in-2026-competitive-landscape-comparison)
- [Techsy — Top LLM Gateway Tools 2026](https://techsy.io/en/blog/best-llm-gateway-tools)
- [LiteLLM GitHub](https://github.com/BerriAI/litellm)
- [Portkey GitHub](https://github.com/Portkey-AI/gateway)
- [Kong AI Gateway docs](https://docs.konghq.com/gateway/latest/ai-gateway/)