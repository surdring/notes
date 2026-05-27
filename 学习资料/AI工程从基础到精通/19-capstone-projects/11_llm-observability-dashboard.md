# 综合项目 11 — LLM 可观测性与评估仪表板

> Langfuse 走向开放核心。Arize Phoenix 发布了 2026 年 GenAI semconv 映射。Helicone 和 Braintrust 都加倍投入了每用户成本归因。Traceloop 的 OpenLLMetry 成为事实上的 SDK 仪器化标准。生产形态是 ClickHouse 用于追踪、Postgres 用于元数据、Next.js 用于 UI，以及一组在采样追踪上运行的小型评估任务（DeepEval、RAGAS、LLM-judge）。构建一个自托管的，从至少四个 SDK 家族摄入数据，并演示在五分钟内捕获注入的回归。

**类型：** 综合项目
**语言：** TypeScript（UI）、Python / TypeScript（摄入 + 评估）、SQL（ClickHouse）
**前置知识：** 阶段 11（LLM 工程）、阶段 13（工具）、阶段 17（基础设施）、阶段 18（安全）
**涵盖阶段：** P11 · P13 · P17 · P18
**时间：** 25 小时

## 问题

2026 年，每个运行生产流量的 AI 团队都在模型旁边维护一个可观测性平面。成本归因。幻觉检测。漂移监控。越狱信号。SLO 仪表板。PII 泄露告警。开源参考——Langfuse、Phoenix、OpenLLMetry——汇聚到 OpenTelemetry GenAI 语义约定（semantic conventions）作为摄入模式。你现在可以用一个 SDK 仪器化 OpenAI、Anthropic、Google、LangChain、LlamaIndex 和 vLLM，并发送兼容的 span。

你将构建一个自托管仪表板，从至少四个 SDK 家族摄入数据，在采样追踪上运行一小组评估任务，检测漂移，并发出告警。衡量标准：给定一个故意注入的回归（一个开始产生 PII 的提示），仪表板捕获它并在五分钟内触发告警。

## 概念

摄入使用 OTLP HTTP。SDK 生成 GenAI-semconv span：`gen_ai.system`、`gen_ai.request.model`、`gen_ai.usage.input_tokens`、`gen_ai.response.id`、`llm.prompts`、`llm.completions`。Span 存入 ClickHouse 用于列式分析；元数据（用户、会话、应用）存入 Postgres。

评估作为批处理任务在采样追踪上运行。DeepEval 对忠实度、毒性和答案相关性进行评分。当追踪携带检索上下文时，RAGAS 对检索指标进行评分。自定义 LLM-judge 运行领域特定检查（PII 泄露、偏离策略的响应）。评估运行将结果作为链接到父追踪的评估 span 写回同一个 ClickHouse。

漂移检测监控随时间变化的嵌入空间分布（对提示嵌入的 PSI 或 KL 散度）以及评估评分趋势。告警输入 Prometheus Alertmanager，然后到 Slack / PagerDuty。UI 是 Next.js 15 配合 Recharts。

## 架构

```
生产应用：
  OpenAI SDK  +  Anthropic SDK  +  Google GenAI SDK
  LangChain + LlamaIndex + vLLM
       |
       v
  OpenTelemetry SDK 配合 GenAI semconv
       |
       v  OTLP HTTP
  收集器（摄入、采样、扇出）
       |
       +-------------+-----------+
       v             v           v
   ClickHouse    Postgres    S3 归档
   （span）      （元数据）    （原始事件）
       |
       +---> 评估任务（DeepEval、RAGAS、LLM-judge）
       |     采样或全追踪
       |     将评估 span 写回
       |
       +---> 漂移检测器（对提示嵌入的 PSI / KL）
       |
       +---> Prometheus 指标 -> Alertmanager -> Slack / PagerDuty
       |
       v
   Next.js 15 仪表板（Recharts）
```

## 技术栈

- 摄入：OpenTelemetry SDK + GenAI 语义约定；OTLP HTTP 传输
- 收集器：OpenTelemetry Collector 配合尾采样处理器（用于成本控制）
- 存储：ClickHouse 用于 span，Postgres 用于元数据，S3 用于原始事件归档
- 评估：DeepEval、RAGAS 0.2、Arize Phoenix 评估器包、自定义 LLM-judge
- 漂移：每周对池化提示嵌入（sentence-transformers）进行 PSI / KL 计算
- 告警：Prometheus Alertmanager -> Slack / PagerDuty
- UI：Next.js 15 App Router + Recharts + server actions
- 开箱支持的 SDK：OpenAI、Anthropic、Google GenAI、LangChain、LlamaIndex、vLLM

## 构建步骤

1. **收集器配置。** OpenTelemetry Collector 配置 OTLP HTTP 接收器，尾采样器保留 100% 的错误追踪和 10% 的成功追踪，导出器到 ClickHouse 和 S3。

2. **ClickHouse 模式。** 表 `spans`，列镜像 GenAI semconv：`gen_ai_system`、`gen_ai_request_model`、`input_tokens`、`output_tokens`、`latency_ms`、`prompt_hash`、`trace_id`、`parent_span_id`，加上用于长载荷的 JSON 包。按 user_id 和 app_id 添加二级索引。

3. **SDK 覆盖测试。** 编写使用每个 SDK（OpenAI、Anthropic、Google、LangChain、LlamaIndex、vLLM）的小型客户端应用，配合 OpenLLMetry 自动仪器化。验证每个都生成存入 ClickHouse 的规范 GenAI span。

4. **评估任务。** 一个定时任务读取最近 15 分钟的采样追踪，并运行 DeepEval 忠实度、毒性和答案相关性评分。输出是链接到父追踪的评估 span。

5. **自定义 LLM-judge。** 一个 PII 泄露判定器：给定一个响应，调用一个守卫 LLM 对 PII 泄露可能性进行评分。高评分响应进入分类队列。

6. **漂移检测。** 每周任务计算本周池化提示嵌入与过去 4 周基线的 PSI。如果 PSI 高于阈值，告警。

7. **仪表板。** Next.js 15，包含页面：概览（每秒 span、每用户成本、p95 延迟）、追踪（搜索 + 瀑布图）、评估（忠实度趋势、毒性）、漂移（随时间 PSI）、告警。

8. **告警链。** Prometheus 导出器读取评估评分聚合和延迟百分位数；Alertmanager 路由到 Slack 用于警告，路由到 PagerDuty 用于严重违反。

9. **回归探针。** 注入一个缺陷：被评估的聊天机器人开始 1% 的时间泄露虚假 SSN。衡量 MTTR：从缺陷部署到 Slack 告警。

## 使用方式

```
$ curl -X POST https://my-otel-collector/v1/traces -d @trace.json
[collector]  接受 1 个追踪，3 个 span
[clickhouse] 插入 3 个 span（app=chat，user=u_42）
[eval]       DeepEval 忠实度 0.82，毒性 0.03
[drift]      每周 PSI 0.08（低于 0.2 阈值）
[ui]         实时于 https://obs.example.com
```

## 交付标准

`outputs/skill-llm-observability.md` 是交付物。给定一个 LLM 应用，仪表板摄入其追踪，运行评估，告警漂移，并在 Next.js 中展示每用户成本分解。

| 权重 | 标准 | 衡量方式 |
|:-:|---|---|
| 25 | 追踪模式覆盖 | 产生规范 GenAI span 的 SDK 家族数量（目标：6+） |
| 20 | 评估正确性 | DeepEval / RAGAS 评分 vs 人工标注集 |
| 20 | 仪表板 UX | 注入回归的 MTTR（目标低于 5 分钟） |
| 20 | 成本 / 规模 | 在 1000 span/秒 下持续摄入而不积压 |
| 15 | 告警 + 漂移检测 | Prometheus/Alertmanager 链端到端演练 |
| **100** | | |

## 练习

1. 为 Haystack 框架添加自定义仪器化。验证规范 span 以忠实的 `gen_ai.*` 属性存入 ClickHouse。

2. 在同一追踪上将 DeepEval 替换为 Phoenix 评估器。衡量两个评估引擎之间的评分漂移。

3. 优化漂移检测器：按 app-id 而非全局计算 PSI。显示每应用漂移轨迹。

4. 添加 "用户影响" 页面：每个用户成本 和 每个用户故障率，带迷你趋势图。

5. 构建一个尾采样策略，保留 100% 的毒性 > 0.5 的追踪，加上其余 10% 的分层样本。衡量引入的采样偏差。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|------------------------|
| GenAI semconv | "OTel LLM 属性" | 2025 OpenTelemetry 规范用于 LLM span 属性（system、model、tokens） |
| 尾采样（Tail sampling） | "追踪后采样" | 收集器在追踪完成后决定保留或丢弃（可以查看错误） |
| PSI | "群体稳定性指数（Population stability index）" | 比较两个分布的漂移指标；> 0.2 通常表示有意义的漂移 |
| LLM-judge | "评估即模型" | 一个 LLM 按评分标准对另一个 LLM 的输出进行评分（忠实度、毒性、PII） |
| 尾采样策略（Tail-sampling policy） | "保留规则" | 决定哪些追踪要持久化 vs 丢弃的规则；错误 + 采样率 |
| 评估 span（Eval span） | "链接的评估追踪" | 携带链接到原始 LLM 调用 span 的评估评分的子 span |
| 每用户成本（Cost per user） | "单位经济" | 归因到一个时间段内 user_id 的美元成本；关键产品指标 |

## 延伸阅读

- [Langfuse](https://github.com/langfuse/langfuse) — 参考开放核心可观测性平台
- [Arize Phoenix](https://github.com/Arize-ai/phoenix) — 替代参考，具有强大的漂移支持
- [OpenLLMetry (Traceloop)](https://github.com/traceloop/openllmetry) — 自动仪器化 SDK 家族
- [OpenTelemetry GenAI 语义约定](https://opentelemetry.io/docs/specs/semconv/gen-ai/) — 摄入模式
- [Helicone](https://www.helicone.ai) — 替代托管可观测性
- [Braintrust](https://www.braintrust.dev) — 替代评估优先平台
- [ClickHouse 文档](https://clickhouse.com/docs) — 列式 span 存储
- [DeepEval](https://github.com/confident-ai/deepeval) — 评估器库