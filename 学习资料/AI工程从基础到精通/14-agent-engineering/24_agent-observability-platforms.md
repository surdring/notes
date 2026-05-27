# 代理可观测性：Langfuse、Phoenix、Opik

> 三个开源的代理可观测性平台主导了 2026 年。Langfuse（MIT）— 每月 6M+ 安装量，追踪 + 提示管理 + 评估 + 会话回放。Arize Phoenix（Elastic 2.0）— 深度代理特定评估、RAG 相关性、OpenInference 自动插桩。Comet Opik（Apache 2.0）— 自动提示优化、护栏、LLM-as-Judge 幻觉检测。

**类型：** 学习
**语言：** Python（标准库）
**前置条件：** Phase 14 · 23（OTel GenAI）
**时间：** ~45 分钟

## 学习目标

- 列举三个顶级开源代理可观测性平台及其许可证。
- 区分每个平台的最强项：Langfuse（提示管理 + 会话），Phoenix（RAG + 自动插桩），Opik（优化 + 护栏）。
- 解释为什么到 2026 年 89% 的组织报告已有代理可观测性。
- 实现一个带有 LLM-as-Judge 评估的标准库追踪到仪表板流水线。

## 问题

OTel GenAI（第 23 课）提供了 Schema。你仍然需要摄取 Span、运行评估、存储提示版本并揭示回归的平台。三个竞争者各自强调生命周期的不同部分。

## 概念

### Langfuse（MIT）

- 每月 6M+ SDK 安装，19k+ GitHub Stars。
- 功能：追踪、带版本管理和 Playground 的提示管理、评估（LLM-as-Judge、用户反馈、自定义）、会话回放（Session Replay）。
- 2025 年 6 月：原商业模块（LLM-as-a-Judge、标注队列、提示实验、Playground）在 MIT 许可下开源。
- 最强项：端到端可观测性 + 紧密的提示管理循环。

### Arize Phoenix（Elastic License 2.0）

- 更深的代理特定评估：追踪聚类（Trace Clustering）、异常检测、RAG 检索相关性。
- 原生 OpenInference 自动插桩。
- 与管理版本 Arize AX 配对用于生产。
- 无提示版本管理——定位为漂移/行为回归工具，配合更广泛平台使用。
- 最强项：RAG 相关性、行为漂移、异常检测。

### Comet Opik（Apache 2.0）

- 通过 A/B 实验自动提示优化。
- 护栏（PII 脱敏、主题约束）。
- LLM-as-Judge 幻觉检测。
- Comet 自家基准测试：Opik 日志 + 评估 23.44 秒 vs Langfuse 327.15 秒（约 14 倍差距）——将供应商基准测试视为方向性参考。
- 最强项：优化循环、自动实验、护栏执行。

### 行业数据

据 Maxim（2026 年实地分析）：89% 的组织已有代理可观测性；质量问题是最大生产障碍（32% 的受访者提到）。

### 选择一个

| 需求 | 选择 |
|------|------|
| 含提示管理的一体化方案 | Langfuse |
| 深度 RAG 评估 + 漂移 | Phoenix |
| 自动优化 + 护栏 | Opik |
| 开放许可，非 ELv2 | Langfuse（MIT）或 Opik（Apache 2.0） |
| Datadog / New Relic 集成 | 任意——它们都导出 OTel |

### 这种模式的陷阱

- **没有评估策略。** 没有评估的追踪只是昂贵的日志。
- **自研 LLM-as-Judge 无事实依据。** CRITIC 模式适用（第 05 课）——评判者需要外部工具进行事实验证。
- **提示版本未与追踪关联。** 当生产出现回归时，你无法二分查找导致回归的提示。

## 构建

`code/main.py` 实现了一个标准库追踪收集器 + LLM-as-Judge 评估器：

- 摄取 GenAI 形态的 Span。
- 按会话分组，标记失败运行（护栏触发、低置信度评估）。
- 一个脚本化 LLM-as-Judge 根据评分标准对代理响应评分。
- 仪表板风格摘要：失败率、失败原因排行、评估分数分布。

运行方式：

```
python3 code/main.py
```

输出：每个会话的评估分数和失败分类，与 Langfuse/Phoenix/Opik 显示的内容一致。

## 使用场景

- **Langfuse** — 自托管或云；通过 OTel 或 SDK 接入。
- **Arize Phoenix** — 自托管；自动插桩 OpenInference。
- **Comet Opik** — 自托管或云；自动优化循环。
- **Datadog LLM 可观测性** — 适用于已经运行 Datadog 的混合运维+ML 团队。

## 部署

`outputs/skill-obs-platform-wiring.md` 选择一个平台并将追踪 + 评估 + 提示版本接入现有代理。

## 练习

1. 将一周的 OTel 追踪导出到 Langfuse Cloud（免费层）。哪些会话失败了？为什么？
2. 为你领域编写 LLM-as-Judge 评分标准（事实正确性、语气、范围遵守）。在 50 条追踪上测试。
3. 比较 Langfuse 提示版本管理 vs Phoenix 追踪聚类。哪个能更快告诉你什么出错了？
4. 阅读 Opik 的护栏文档。将 PII 脱敏护栏接入你的一次代理运行。
5. 在你的语料库上对三者进行基准测试。忽略供应商发布的数字；测量你自己的。

## 关键术语

| 术语 | 人们常说的 | 实际含义 |
|------|-----------|---------|
| 追踪（Tracing） | "Span 收集器" | 摄取 OTel/SDK Span；按会话索引 |
| 提示管理（Prompt Management） | "提示 CMS" | 版本化提示与追踪关联 |
| LLM-as-Judge | "自动评估" | 独立 LLM 根据评分标准对代理输出评分 |
| 会话回放（Session Replay） | "追踪回放" | 逐步遍历历史运行以调试 |
| RAG 相关性（RAG Relevancy） | "检索质量" | 检索到的上下文是否与查询匹配 |
| 追踪聚类（Trace Clustering） | "行为分组" | 聚类相似运行以进行漂移检测 |
| 护栏执行（Guardrail Enforcement） | "日志时策略" | 对记录内容的 PII/毒性/范围检查 |

## 进一步阅读

- [Langfuse 文档](https://langfuse.com/) — 追踪、评估、提示管理
- [Arize Phoenix 文档](https://docs.arize.com/phoenix) — 自动插桩、漂移
- [Comet Opik](https://www.comet.com/site/products/opik/) — 优化 + 护栏
- [OpenTelemetry GenAI 语义约定](https://opentelemetry.io/docs/specs/semconv/gen-ai/) — 三者都消费的 Schema