# 推理指标 —— TTFT、TPOT、ITL、有效吞吐量、P99

> 四个指标决定推理部署是否工作。TTFT 是预填充加队列加网络。TPOT（等同于 ITL）是每 Token 的内存受限解码成本。端到端延迟是 TTFT 加 TPOT 乘以输出长度。吞吐量是整个集群每秒的总 Token 数。但对产品重要的是有效吞吐量（Goodput）——同时满足每个 SLO 的请求比例。高吞吐量低有效吞吐量意味着你正在处理从未及时到达用户的 Token。2026 年 TRT-LLM 上 Llama-3.1-8B-Instruct 的参考数字：平均 TTFT 162 ms，平均 TPOT 7.33 ms，平均 E2E 1,093 ms。始终报告 P50、P90、P99——永远不仅是均值。并注意测量陷阱：GenAI-Perf 从 ITL 计算中排除 TTFT，LLMPerf 包括它；同一运行两个工具在 TPOT 上不一致。

**类型：** 学习
**语言：** Python（标准库，玩具级百分位计算器和有效吞吐量报告器）
**前置条件：** Phase 17 · 04（vLLM 推理内部）
**时间：** ~60 分钟

## 学习目标

- 精确定义 TTFT、TPOT、ITL、E2E、吞吐量和有效吞吐量，并命名每个测量的组件。
- 解释为什么均值对 LLM 推理是错误的统计量，以及如何阅读 P50/P90/P99。
- 构造一个 SLO 多约束（例如 TTFT<500 ms AND TPOT<15 ms AND E2E<2 s）并针对它计算有效吞吐量。
- 说出两个在同一运行上对 TPOT 不一致的基准工具，并解释原因。

## 问题

"我们的吞吐量是每秒 15,000 Token。"那又怎样？如果 40% 的请求端到端超过 2 秒，用户放弃了会话。吞吐量单独不能告诉你产品是否工作。

推理有多个延迟轴，每个以不同方式失败。预填充是计算密集型的，随提示长度扩展。解码是内存密集型的，随批次大小扩展。排队延迟是运维问题。网络是物理距离问题。你需要每个的独立指标，你需要百分位数，你需要一个单一的复合指标来说明"用户是否得到了他们期望的"——那就是有效吞吐量。

## 概念

### TTFT——首 Token 时间

`TTFT = queue_time + network_request + prefill_time`

当提示长时预填充主导。在 Llama-3.3-70B FP8 on H100 上，32k 提示需要约 800 ms 的纯预填充。队列时间是负载下的调度器行为。网络请求是包括 TLS 的线路时间。TTFT 是用户在有任何内容流回之前看到的延迟。

### TPOT / ITL——Token 间延迟

一个量有很多名称。`TPOT`（每输出 Token 时间）、`ITL`（Token 间延迟）、`每 Token 解码延迟`——都一样。它是第一个 Token 之后连续流式 Token 之间的时间。

`TPOT = (decode_forward_time + scheduler_overhead) / tokens_produced`

在相同 Llama-3.3-70B H100 栈上，带分块预填充，TPOT 均值约 7 ms。不带分块预填充，在邻近序列的长预填充期间，TPOT 可以飙升到 50 ms。观察 P99，而非均值。

### E2E 延迟

`E2E = TTFT + TPOT * output_tokens + network_response`

对于长输出（>500 Token），E2E 是 TPOT 主导的。对于短输出加长提示，E2E 是 TTFT 主导的。报告以输出长度条件化的 E2E。

### 吞吐量

`throughput = total_output_tokens / elapsed_time`

聚合指标。告诉你集群效率。不告诉你个别请求健康状况。

### 有效吞吐量——你真正关心的指标

`goodput = fraction of requests meeting (TTFT <= a) AND (TPOT <= b) AND (E2E <= c)`

SLO 是一个多约束。一个请求仅在每个约束都满足时才是"好"的。有效吞吐量是这一份额。在 60% 有效吞吐量下的高吞吐量是失败。在 99% 有效吞吐量下的较低吞吐量是目标。

在 2026 年，有效吞吐量是 MLPerf Inference v6.0 提交和 AI 平台提供商内部 SLA 追踪中使用的指标。

### 为什么均值是错误的统计量

LLM 延迟分布是右偏的。带一个长预填充邻居的解码批次可以以 TPOT ~7 ms 发送 500 Token，以 TPOT ~60 ms 发送 20 Token。均值 TPOT 是 9 ms。P99 TPOT 是 65 ms。用户经常遇到 P99——这就是他们离开的原因。

始终报告三元组（P50, P90, P99）。对于用户体验，P99 是你优化的目标。

### 参考数字——Llama-3.1-8B-Instruct on TRT-LLM，2026

- 均值 TTFT：162 ms
- 均值 TPOT：7.33 ms
- 均值 E2E：1,093 ms
- P99 TPOT：10-25 ms 不等，取决于分块预填充配置。

这些是已发布的 NVIDIA 参考点。它们随模型大小（70B 会显示 3-5 倍）、硬件（H100 vs B200 ~3 倍）和负载而变化。

### 测量陷阱

2026 年最常用的两个基准工具在同一运行上对 TPOT 不一致：

- **NVIDIA GenAI-Perf**：从 ITL 计算中排除 TTFT。ITL 从 Token 2 开始。
- **LLMPerf**：包括 TTFT。ITL 从 Token 1 开始。

对于 TTFT 500 ms 和 100 个输出 Token 总共 700 ms 解码的请求，GenAI-Perf 报告 `ITL = 700/99 = 7.07 ms`，LLMPerf 报告 `ITL = 1200/100 = 12.00 ms`。工具选择改变数字。

始终说明哪个工具。始终发布定义。

### 构建 SLO

2026 年 70B 聊天模型的合理面向消费者 SLO：

- TTFT P99 <= 800 ms。
- TPOT P99 <= 25 ms。
- E2E P99 <= 3 s（<300 Token 输出）。
- 有效吞吐量目标 >= 99%。

企业 SLO 收紧 TTFT（200-400 ms）并放宽 E2E。关键是写下来，测量全部三个，并作为单一复合追踪有效吞吐量。

### 如何测量

- 运行真实流量或实际合成流量（LLMPerf with `--mean-input-tokens 800 --stddev-input-tokens 300 --mean-output-tokens 150`）。
- 基准运行目标 2 倍峰值并发。
- 运行 30-50 次迭代，取合并样本的百分位数。
- 发布时带上工具名称、工具版本、模型、硬件、并发、提示分布。

## 使用它

`code/main.py` 是一个玩具有效吞吐量计算器。生成合成延迟分布，应用 SLO，计算有效吞吐量。还显示同一追踪上 GenAI-Perf vs LLMPerf 的 TPOT 差异。

## 交付它

本课产出 `outputs/skill-slo-goodput-gate.md`。给定工作负载和 SLO，它产生一个 CI/CD 就绪的基准配方，以有效吞吐量而非吞吐量作为部署门控。

## 练习

1. 运行 `code/main.py`。生成一个 1% 尾部尖峰的分布。当你将 P99 TPOT 从 30 ms 收紧到 15 ms 时，有效吞吐量如何变化？
2. 一个供应商报价 "Llama 3.3 70B H100 上 15,000 tok/s"。在信任之前说出三个要问的问题。
3. 为什么分块预填充保护 P99 TPOT 但不保护均值 TPOT？
4. 为语音助手构建一个消费者 SLO（首 Token 是听到的，而非读到的）。哪个指标对用户最可见？
5. 阅读 LLMPerf README 和 GenAI-Perf 文档。识别工具不一致的另外三个指标。

## 关键术语

| 术语 | 人们的说法 | 实际含义 |
|------|----------------|------------------------|
| TTFT | "首 Token 时间" | 队列 + 网络 + 预填充；长提示时预填充主导 |
| TPOT | "每输出 Token 时间" | 第一个之后每 Token 的内存受限解码成本 |
| ITL | "Token 间延迟" | 大多数工具中与 TPOT 相同（并非全部——见 GenAI-Perf） |
| E2E | "端到端" | TTFT + TPOT * output_len；之上还有响应端网络 |
| 吞吐量 | "tok/s" | 集群效率；没有延迟百分位数则无用 |
| 有效吞吐量 | "SLO 满足率" | 同时满足每个 SLO 约束的请求比例 |
| P99 | "尾部" | 1/100 最坏情况延迟；用户体验指标 |
| SLO 多约束 | "联合" | 全部三个延迟界限的 AND；任何一项违反则请求失败 |
| GenAI-Perf vs LLMPerf | "工具陷阱" | 工具在 ITL 是否包括 TTFT 上不一致 |

## 扩展阅读

- [NVIDIA NIM — LLM 基准测试指标](https://docs.nvidia.com/nim/benchmarking/llm/latest/metrics.html) —— TTFT、ITL、TPOT 的规范定义。
- [Anyscale — LLM 推理基准测试指标](https://docs.anyscale.com/llm/serving/benchmarking/metrics) —— 替代定义和测量配方。
- [BentoML — LLM 推理指标](https://bentoml.com/llm/inference-optimization/llm-inference-metrics) —— 真实部署的应用测量。
- [LLMPerf](https://github.com/ray-project/llmperf) —— 基于 Ray 的开源基准。
- [GenAI-Perf](https://docs.nvidia.com/deeplearning/triton-inference-server/user-guide/docs/client/src/c++/perf_analyzer/genai-perf/README.html) —— NVIDIA 的基准工具。
- [MLPerf Inference](https://mlcommons.org/benchmarks/inference-datacenter/) —— 行业接受的基于有效吞吐量的基准。