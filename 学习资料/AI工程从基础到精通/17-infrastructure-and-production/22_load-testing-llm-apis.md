# LLM API 负载测试 — 为什么 k6 和 Locust 会撒谎

> 传统负载测试工具不是为流式响应、可变输出长度、token 级指标或 GPU 饱和而设计的。两个陷阱坑了大多数团队。GIL 陷阱：Locust 的 token 级测量在 Python GIL 下运行分词器，在高并发下与请求生成竞争；分词器积压膨胀了报告的 token 间延迟——你的客户端才是瓶颈，而非服务器。提示词一致性陷阱（Prompt-Uniformity Trap）：在循环中使用相同的提示词测试的是 token 分布上的一个点；真实流量具有可变长度和多样化的前缀匹配。LLMPerf 通过 `--mean-input-tokens` + `--stddev-input-tokens` 解决了这个问题。2026 年工具映射：LLM 专用工具（GenAI-Perf、LLMPerf、LLM-Locust、guidellm）用于 token 级准确性；**k6 v2026.1.0** + **k6 Operator 1.0 GA（2025 年 9 月）**——流式感知，Kubernetes 原生分布式，通过 TestRun/PrivateLoadZone CRD，最适合 CI/CD 关卡；Vegeta 用于 Go 恒定速率饱和测试；Locust 2.43.3 仅配合 LLM-Locust 扩展支持流式。负载模式：稳态（Steady-State）、渐进式（Ramp）、突发（Spike）、浸泡（Soak，用于内存泄漏检测）。

**类型：** 构建
**语言：** Python（标准库，玩具级现实提示词生成器 + 延迟收集器）
**前置知识：** 第 17 阶段 · 08（推理指标），第 17 阶段 · 03（GPU 自动扩展）
**时间：** 约 75 分钟

## 学习目标

- 解释两个反模式（GIL 陷阱、提示词一致性陷阱）为何让通用负载测试工具在 LLM API 上产生误导性结果。
- 按用途选择工具：LLMPerf（基准运行）、k6 + 流式扩展（CI 关卡）、guidellm（大规模合成）、GenAI-Perf（NVIDIA 参考）。
- 设计四种负载模式（稳态、渐进、突发、浸泡）并指出每种模式捕捉的失败类型。
- 使用输入 token 的均值 + 标准差而非固定长度来构建真实提示词分布。

## 问题

你用 k6 在 500 并发用户下测试了 LLM 端点。它撑住了。你发布了。在生产环境中，200 个实际用户时服务崩溃——P99 TTFT 爆炸，GPU 被钉住。

发生了两件事。第一，k6 发送了 500 个相同的提示词——你的请求合并和前缀缓存使其看起来像在处理 500 个并发解码，而实际上你只处理了一个。第二，k6 不像人眼那样追踪流式响应上的 token 间延迟；它看到的是一个 HTTP 连接，而非 500 个以不同间隔到达的 token。

LLM 的负载测试是一门独立的学科。

## 概念

### GIL 陷阱（Locust）

Locust 使用 Python，并在 GIL 下在客户端运行分词器。在高并发下，分词器在请求生成后面排队。报告的 token 间延迟包含了客户端分词积压。你以为是服务器慢；其实是测试工具的问题。

修复：LLM-Locust 扩展将分词器移到独立进程，或使用编译语言的测试工具（k6、LLMPerf 使用 tokenizers.rs）。

### 提示词一致性陷阱

所有已知的负载测试器都允许配置一个提示词。在 10,000 次循环测试中，每次都发送完全相同的提示词。服务器每次看到相同的前缀——前缀缓存命中率接近 100%，吞吐量看起来很好。

修复：从提示词分布中采样。LLMPerf 使用 `--mean-input-tokens 500 --stddev-input-tokens 150`——多样化长度，多样化内容。

### 四种负载模式

1. **稳态（Steady-State）** — 恒定 RPS 运行 30-60 分钟。捕捉：基线性能回归。
2. **渐进式（Ramp）** — 15 分钟内线性增加 RPS 从 0 到目标。捕捉：容量断点、预热异常。
3. **突发（Spike）** — 2 分钟内突然 3-10 倍 RPS，然后恢复。捕捉：自动扩展延迟、队列饱和、冷启动影响。
4. **浸泡（Soak）** — 稳态运行 4-8 小时。捕捉：内存泄漏、连接池漂移、可观测性溢出。

### 2026 年工具映射

**LLMPerf**（Anyscale）— Python 但 Rust 支持的分词器。均值/标准差提示词。流式感知。性能运行的默认选择。

**NVIDIA GenAI-Perf** — NVIDIA 的参考工具。使用 Triton 客户端；全面的指标覆盖。注意其 ITL 排除 TTFT；LLMPerf 包含它。两个工具对同一服务器产生不同的 TPOT。

**LLM-Locust**（TrueFoundry）— 修复了 GIL 陷阱的 Locust 扩展。熟悉的 Locust DSL + 流式指标。

**guidellm** — 大规模合成基准。

**k6 v2026.1.0** + **k6 Operator 1.0 GA（2025 年 9 月）**：
- k6 本身（Go，编译，无 GIL）添加了流式感知指标。
- k6 Operator 使用 TestRun / PrivateLoadZone CRD 实现 Kubernetes 原生分布式测试。
- 最适合 CI/CD 关卡和 SLA 测试。

**Vegeta** — Go，比 k6 简单。恒定速率 HTTP 饱和。不 LLM 感知但适合网关/速率限制测试。

**Locust 2.43.3 原版** — 对 LLM 存在 GIL 陷阱。仅配合 LLM-Locust 扩展使用。

### CI 中的 SLA 关卡

在 PR 上运行 k6：

- 每次 30-50 次迭代，基线 RPS。
- 关卡：P50/P95 TTFT、5xx < 5%、TPOT 低于阈值。
- 违反则阻断构建。

### 真实的提示词分布

从真实流量样本构建（如果有的话），或从已发布的分布（如对话的 ShareGPT 提示词、代码的 HumanEval）。将均值 + 标准差输入 LLMPerf。不惜一切代价避免循环中单一提示词。

### 应记住的数字

- k6 Operator 1.0 GA：2025 年 9 月。
- k6 v2026.1.0：流式感知指标。
- 典型 LLMPerf 运行：100-1000 请求，并发数 X。
- 典型 CI 关卡：每次 PR 30-50 次迭代。
- 四种模式：稳态、渐进、突发、浸泡。

## 使用它

`code/main.py` 使用真实提示词分布模拟负载测试，测量有效 TPOT，并演示一致性提示词陷阱。

## 交付它

本课生成 `outputs/skill-load-test-plan.md`。根据工作负载和 SLA，选择工具并设计四种负载模式。

## 练习

1. 运行 `code/main.py`。对比一致分布 vs 真实分布——差距在哪里？
2. 为 CI 关卡编写 k6 脚本：TTFT P95 < 800 ms at 100 并发，运行时间 5 分钟。
3. 你的浸泡测试显示内存每小时增长 50 MB。说出三种原因以及用来区分它们的插桩手段。
4. 从 10 RPS 突发到 100 RPS。如果 Karpenter + vLLM 生产栈已就位（第 17 阶段 · 03 + 18），预期恢复时间是多少？
5. GenAI-Perf 报告 TPOT=6ms；LLMPerf 在同一服务器上报告 TPOT=11ms。解释原因。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|----------------|------------------------|
| LLMPerf | "LLM 测试工具" | Anyscale 基准工具，流式感知 |
| GenAI-Perf | "NVIDIA 工具" | NVIDIA 参考测试工具 |
| LLM-Locust | "面向 LLM 的 Locust" | 修复 GIL 陷阱的 Locust 扩展 |
| guidellm | "合成基准" | 大规模合成工具 |
| k6 Operator | "K8s k6" | 基于 CRD 的分布式 k6 |
| GIL trap | "Python 客户端开销" | 分词积压膨胀了报告延迟 |
| Prompt-uniformity trap | "单一提示词的谎言" | 循环相同提示词命中缓存，膨胀吞吐量 |
| Steady-state | "恒定负载" | 固定 RPS 运行 N 分钟 |
| Ramp | "线性增加" | 从 0 到目标，覆盖一段时间 |
| Spike | "突发测试" | 突然倍率增加然后恢复 |
| Soak | "长时测试" | 数小时以检测泄漏 |

## 延伸阅读

- [TianPan — Load Testing LLM Applications](https://tianpan.co/blog/2026-03-19-load-testing-llm-applications)
- [PremAI — Load Testing LLMs 2026](https://blog.premai.io/load-testing-llms-tools-metrics-realistic-traffic-simulation-2026/)
- [NVIDIA NIM — Introduction to LLM Inference Benchmarking](https://docs.nvidia.com/nim/large-language-models/1.0.0/benchmarking.html)
- [TrueFoundry — LLM-Locust](https://www.truefoundry.com/blog/llm-locust-a-tool-for-benchmarking-llm-performance)
- [LLMPerf](https://github.com/ray-project/llmperf)
- [k6 Operator](https://github.com/grafana/k6-operator)