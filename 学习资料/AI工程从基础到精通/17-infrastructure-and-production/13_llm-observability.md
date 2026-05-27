# LLM 可观测性技术栈选择

> 2026 年的可观测性市场分为两类。开发平台（LangSmith、Langfuse、Comet Opik）将监控与评估、提示词管理、会话回放捆绑在一起。网关/插桩工具（Helicone、SigNoz、OpenLLMetry、Phoenix）专注于遥测（Telemetry）。Langfuse 核心采用 MIT 许可证，具有强 OSS 平衡（云端免费 50K 事件/月）。Phoenix 是 OpenTelemetry 原生的，使用 Elastic License 2.0——在漂移/RAG 可视化方面表现出色，但并非持久化生产后端。Arize AX 使用零拷贝 Iceberg/Parquet 集成，声称比单体式可观测性便宜约 100 倍。LangSmith 在 LangChain/LangGraph 领域领先，$39/用户/月，仅企业版支持自托管。Helicone 基于代理，15-30 分钟即可设置，免费 100K 请求/月，但在代理追踪方面深度不足。常见生产模式：网关（Helicone/Portkey）+ 评估平台（Phoenix/TruLens），通过 OpenTelemetry 粘合。

**类型：** 学习
**语言：** Python（标准库，玩具级追踪采样模拟器）
**前置知识：** 第 17 阶段 · 08（推理指标），第 14 阶段（Agent 工程）
**时间：** 约 60 分钟

## 学习目标

- 区分开发平台（捆绑：评估 + 提示词 + 会话）和网关/遥测工具（仅追踪 + 指标）。
- 将六大主流工具（Langfuse、LangSmith、Phoenix、Arize AX、Helicone、Opik）映射到其许可证、定价和最佳使用场景。
- 解释允许你将网关工具与独立评估平台组合的 OpenTelemetry 粘合模式。
- 说出 2026 年成本差异化因素（Arize AX 的零拷贝方式 vs 单体式摄取）并陈述约 100 倍的倍率。

## 问题

你发布了一个 LLM 功能。它运行正常。你对提示词失败、工具循环、延迟回归、成本飙升或提示词缓存命中率毫无可见性。你搜索"LLM 可观测性"，得到八个工具，都声称以三种不同价位解决了同样的问题。

它们解决的问题并不相同。LangSmith 回答"这个 LangGraph 运行为什么失败？"Phoenix 回答"我的 RAG 管线是否在漂移？"Helicone 回答"哪个应用在烧 token？"Langfuse 回答"我能自托管整个系统吗？"不同的工具，不同的受众。

选择涉及四个维度：技术栈（LangChain？原始 SDK？多供应商？）、许可证容忍度（只接受 MIT？Elastic 可以？商业许可可以？）、预算（免费层？$100/月？$1000/月？）和自托管（必须？锦上添花？绝不需要？）。

## 概念

### 两大类

**开发平台**将可观测性与评估、提示词管理、数据集版本控制和会话回放捆绑。你可以运行实验，查看哪个提示词有效，将新提示词与旧获胜者进行数据集回归。LangSmith、Langfuse、Comet Opik。

**网关/遥测工具**插桩推理调用——提示词、响应、token、延迟、模型、成本。Helicone、SigNoz、OpenLLMetry、Phoenix。极简风格。可通过 OpenTelemetry 与独立的评估工具组合。

### Langfuse — OSS 平衡

- 核心 Apache / MIT 许可；通过 Docker 自托管。
- 云端免费层：50K 事件/月。付费：$29/月团队版。
- 评估、提示词管理、追踪、数据集。合理覆盖了开发平台的四个特性。
- 最佳场景：你想要 LangSmith 级别的功能但必须自托管或保持 OSS 许可。

### Phoenix（Arize）— 遥测优先，OpenTelemetry 原生

- Elastic License 2.0；自托管简单。
- 在 RAG 和漂移可视化方面表现出色。嵌入空间散点图作为一等公民提供。
- 不是为持久化生产后端设计的——主要面向开发期可观测性。
- 最佳场景：RAG 管线开发、漂移调试，与独立的网关配对用于生产环境。

### Arize AX — 规模化方案

- 商业许可。通过 Iceberg/Parquet 实现零拷贝数据湖集成。
- 声称在大规模下比单体式可观测性（Datadog 级别）便宜约 100 倍。其计算逻辑：你将追踪存储在自己的 S3 Parquet 中；Arize 直接读取。
- 最佳场景：每天 >10M 追踪，已有数据湖，想要 LLM 专属仪表板而不需要 Datadog 的价格。

### LangSmith — LangChain/LangGraph 优先

- 商业许可，$39/用户/月。仅企业版支持自托管。
- 在 LangChain 和 LangGraph 技术栈上表现一流。如果你不使用这两者，其吸引力会降低。
- 最佳场景：团队已投入 LangChain，愿意付费。

### Helicone — 基于代理的最小可行方案

- 通过将 `OPENAI_API_BASE` 换成 Helicone 代理，15-30 分钟即可设置。
- MIT 许可；免费 100K 请求/月，付费 $20/月起。
- 包含故障转移、缓存、速率限制——同时也充当网关。
- 在 agent / 多步追踪方面深度不足。
- 最佳场景：快速启动、单一技术栈应用、需要网关 + 可观测性合一。

### Opik（Comet）— OSS 开发平台

- Apache 2.0，完全开源。
- 功能集与 Langfuse 相似，有 Comet 的传统优势。
- 最佳场景：已在 Comet 上的 ML 团队，希望在同一面板上获得 LLM 可观测性。

### SigNoz — OpenTelemetry 优先的全栈 APM

- Apache 2.0。通过 OpenTelemetry 处理通用 APM 加 LLM。
- 最佳场景：跨服务和 LLM 调用的统一可观测性。

### 粘合剂：OpenTelemetry + GenAI 语义约定

OpenTelemetry 在 2025 年末发布了 GenAI 语义约定（`gen_ai.system`、`gen_ai.request.model`、`gen_ai.usage.input_tokens`）。消费 OTel 的工具可以互操作。正在形成的生产模式：

1. 每次 LLM 调用都按 GenAI 约定发出 OTel。
2. 路由到网关（Helicone / Portkey）用于日常监控。
3. 双重发送到评估平台（Phoenix / Langfuse）用于回归检测。
4. 归档到数据湖（Iceberg）用于通过 Arize AX 或 DuckDB 进行长期分析。

### 陷阱：在错误的层面插桩

在你的 agent 框架内部插桩（例如，添加 LangSmith 追踪）会将你耦合到该框架。在 HTTP/OpenAI-SDK 层面插桩（通过 OpenLLMetry 或你的网关）是可移植的。

### 采样 — 你无法保留所有数据

在每天 >1M 请求时，全量追踪保留的成本超过 LLM 调用本身。按规则采样：100% 错误，100% 高成本，5% 成功。始终保留聚合数据；为长尾保留原始数据。

### 应记住的数字

- Langfuse 免费云端：50K 事件/月。
- LangSmith：$39/用户/月。
- Helicone 免费：100K 请求/月。
- Arize AX 声称：在大规模下比单体式便宜约 100 倍。
- OpenTelemetry GenAI 约定：2025 年发布，2026 年广泛采用。

## 使用它

`code/main.py` 在保留策略（100% 摄取、采样、采样 + 错误）下模拟一天 1M 追踪。报告每种策略下的存储成本和丢失的内容。

## 交付它

本课生成 `outputs/skill-observability-stack.md`。根据技术栈、规模、预算和许可证立场，选择工具。

## 练习

1. 你的 LangChain 团队想要开源自托管可观测性。选择 Langfuse 或 Opik 并说明理由。
2. 每天 5M 追踪，Datadog 报价 $150K/月，计算 Arize AX 的盈亏平衡点。
3. 设计一套你的组织应在每次 LLM 调用中强制要求的 OpenTelemetry GenAI 属性集。
4. 论证 Phoenix 单独是否能满足生产需求。何时不够？
5. Helicone 有 20ms 代理开销。在 TTFT P99 为 300 ms 的情况下，这是否可接受？如果 SLA 是 100 ms 呢？

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|----------------|------------------------|
| OpenLLMetry | "LLM 的 OTel" | 面向 LLM 的开源 OpenTelemetry 插桩 |
| GenAI conventions | "OTel 属性" | LLM 调用的标准 OTel 属性名称 |
| LangSmith | "LangChain 可观测性" | 与 LangChain 生态系统捆绑的商业平台 |
| Langfuse | "OSS LangSmith" | MIT OSS，功能集相似 |
| Phoenix | "Arize 开发工具" | OpenTelemetry 原生的开发/评估平台 |
| Arize AX | "规模化可观测性" | 商业零拷贝 Iceberg/Parquet 可观测性 |
| Helicone | "代理可观测性" | 收集 LLM 遥测的 HTTP 代理 + 网关特性 |
| Opik | "Comet LLM" | Apache 2.0 OSS 开发平台，来自 Comet |
| Session replay | "追踪重放" | 重放一个完整的 agent 会话及工具调用 |
| Eval | "离线测试" | 在标注数据集上运行候选模型/提示词 |

## 延伸阅读

- [SigNoz — Top LLM Observability Tools 2026](https://signoz.io/comparisons/llm-observability-tools/)
- [Langfuse — Arize AX Alternative analysis](https://langfuse.com/faq/all/best-phoenix-arize-alternatives)
- [PremAI — Setting Up Langfuse, LangSmith, Helicone, Phoenix](https://blog.premai.io/llm-observability-setting-up-langfuse-langsmith-helicone-phoenix/)
- [OpenTelemetry GenAI Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/gen-ai/)
- [Arize Phoenix docs](https://docs.arize.com/phoenix)
- [Helicone docs](https://docs.helicone.ai/)