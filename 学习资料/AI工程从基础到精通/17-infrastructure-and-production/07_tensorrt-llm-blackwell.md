# Blackwell 上的 TensorRT-LLM：FP8 与 NVFP4

> TensorRT-LLM 仅限 NVIDIA，但在 Blackwell 上它胜出。在带有 Dynamo 编排的 GB200 NVL72 上，SemiAnalysis InferenceX 在 2026 年 Q1-Q2 测量 120B 模型每百万 Token $0.012，对比 H100 + vLLM 的 $0.09/M——7 倍经济差距。这个栈是三个浮点体制的复合：FP8 对 KV 缓存和注意力内核仍然关键，因为它们需要动态范围；NVFP4（4 位微缩放）处理权重和激活；多 Token 预测（MTP）和分离式预填充/解码在之上再增加 2-3 倍。第 0 天模型支持直接加载 FP4 权重，无需训练后转换。2026 年工程团队的陷阱：TRT-LLM 是封闭的 NVIDIA 栈，因此采用它是以可移植性换取吞吐量。在承诺之前，对你的模型和硬件组合运行计算。

**类型：** 学习
**语言：** Python（标准库，玩具级 FP8/NVFP4 内存和成本计算器）
**前置条件：** Phase 17 · 04（vLLM 推理内部）、Phase 10 · 13（量化）
**时间：** ~75 分钟

## 学习目标

- 解释为什么即使权重在 NVFP4 中，FP8 对 KV 缓存和注意力仍然关键。
- 计算前沿模型在 BF16、FP8 和 NVFP4 下的 HBM 占用，并推理节省来自哪里。
- 说出 TRT-LLM 利用的 Blackwell 特定特性（第 0 天 FP4、MTP、分离式推理、全对全原语）。
- 决定 TRT-LLM 的 NVIDIA 锁定何时值得相对 vLLM on Hopper 的 7 倍成本差距。

## 问题

2026 年推理经济学的前沿是"每美元多少 Token"。答案取决于四个叠加的选择：硬件代际（Hopper H100/H200 vs Blackwell B200/GB200）、精度（BF16 → FP8 → NVFP4）、推理引擎（vLLM vs SGLang vs TRT-LLM）和编排（纯 vs 分离式 vs Dynamo）。

在带 vLLM 的 Hopper 上，120B MoE 运行在约 $0.09 每百万 Token。在带 TRT-LLM + Dynamo 的 Blackwell 上，相同模型运行在约 $0.012——便宜 7 倍。部分差距来自硬件（Blackwell 的每 GPU LLM 吞吐量是 Hopper 的 11-15 倍）。部分来自栈：FP4 权重、MTP 草稿、分离式预填充/解码和用于 MoE 专家通信的 NVLink 5 全对全。

你无法在 NVIDIA 栈之外复制这一点。这就是权衡——可移植性换取经济学。理解哪些栈选择贡献了差距的哪一部分是本课的重点。

## 概念

### 为什么 FP8 仍然是 KV 缓存的最低要求

2026 年常见错误：假设 NVFP4 适用于所有地方。并非如此。KV 缓存需要 FP8（8 位浮点），因为它存储跨越大动态范围的注意力键和值。将 KV 量化到 FP4 会导致灾难性的精度损失——分布的尾部丢失，注意力分数崩溃。FP8 的指数位为 KV 缓存提供所需的范围。

NVFP4（2025-2026）适用于权重和激活。微缩放：每个权重块有自己的缩放因子，因此小块可以跨越不同的动态范围而不损失每张量缩放。对于激活，FP4 可以维持，因为激活在一层内是小范围的。

典型的 Blackwell 配置：

- 权重：NVFP4（4 位微缩放）。
- 激活：NVFP4。
- KV 缓存：FP8。
- 注意力累加器：FP32（softmax 稳定性）。

### TRT-LLM 使用的 Blackwell 特定原语

- **第 0 天 FP4 权重**：模型提供商直接发布 FP4 权重；TRT-LLM 无需训练后转换加载。FP4 无需 AWQ / GPTQ 步骤。
- **多 Token 预测（MTP）**：与 EAGLE（Phase 17 · 05）相同的思想，但集成到 TRT-LLM 构建中。
- **分离式推理**：预填充和解码在独立 GPU 池上，KV 缓存通过 NVLink 或 InfiniBand 传输。与 Dynamo（Phase 17 · 20）相同的思想。
- **全对全通信原语**：NVLink 5 将 MoE 专家通信延迟相比 Hopper 减少了 3 倍。TRT-LLM 的 MoE 内核为此调优。
- **NVFP4 + MXFP8 微缩放**：Blackwell Tensor Core 上的硬件加速缩放因子处理。

### 你应该记住的数字

- HGX B200 通过 TRT-LLM 在 GPT-OSS-120B 上 $0.02/M tokens。
- GB200 NVL72 通过 Dynamo（编排 TRT-LLM）$0.012/M tokens。
- H100 + vLLM 在可比工作负载上约 $0.09/M tokens。
- TRT-LLM 更新三个月内吞吐量提升 2.8 倍（2026）。
- Blackwell vs Hopper 每 GPU LLM 吞吐量：11-15 倍。
- MLPerf Inference v6.0（2026 年 4 月）：Blackwell 在每个提交任务中占主导。

### FP4 在质量上实际损失什么

NVFP4 是激进的。在推理密集型工作负载（思维链、数学、长上下文代码生成）上，FP4 权重明显退化。每块校准缓解但不能消除。发布推理模型的团队通常使用 FP8 权重 + FP4 激活作为折中，或坚持使用 H200 全程 FP8。

规则：在承诺 NVFP4 权重之前，始终在你的评估集上验证任务质量。

### 为什么这是 NVIDIA 锁定决策

TRT-LLM 是 C++ + CUDA + 闭源内核。模型需要为特定 GPU SKU 编译。无 AMD、无 Intel、无 ARM。如果你的基础设施策略是多供应商，TRT-LLM 对 TRT-LLM 推理层是不可行的——你仍然可以在混合硬件上通过 vLLM 推理。如果你是纯 NVIDIA，7 倍差距为锁定买单。

### 2026 年实用配方

对于每年 $1 亿以上的推理账单，在 Hopper + vLLM 上运行会留下 7-10 倍的提升空间。将成本主导的工作负载迁移到 Blackwell + TRT-LLM + Dynamo。在 H100 + vLLM 上保持实验层以加快模型迭代速度。在生产前对每个 NVFP4 转换模型验证质量。

### 分离式奖励

TRT-LLM 的分离式推理（独立预填充和解码池）在 Phase 17 · 20 中深入涵盖。在 Blackwell 上，乘数叠加：FP4 权重 × MTP 加速比 × 分离式放置 × 缓存感知路由。7 倍数字假设这个完整栈。

## 使用它

`code/main.py` 跨三个栈计算模型的 HBM 占用、解码吞吐量（内存受限体制）和 $/M-tokens：H100 + BF16 + vLLM、H100 + FP8 + vLLM、B200 + NVFP4/FP8 + TRT-LLM。运行它以查看复合效应以及每个变化贡献的差距份额。

## 交付它

本课产出 `outputs/skill-trtllm-blackwell-advisor.md`。给定工作负载、模型大小和年 Token 量，它决定 Blackwell + TRT-LLM 栈是否值得 NVIDIA 锁定。

## 练习

1. 运行 `code/main.py`。在 30% 活跃参数的 120B MoE 上，计算 H100 BF16、H100 FP8 和 B200 NVFP4/FP8 下的内存带宽受限解码吞吐量。最大跳跃来自哪里？
2. 一个客户在 H100 + vLLM 上每年花费 $200 万。给定 7 倍经济差距，他们需要购买多少 Blackwell GPU 才能在 12 个月内摊销迁移到 TRT-LLM？
3. 你看到 NVFP4 权重转换后 MATH 准确率下降 3 分。说出两条恢复路径：一条质量优先（保持 FP8 权重），一条成本优先（用领域内数据校准）。
4. 阅读 MLPerf v6.0 推理结果。哪个任务有最小的 Blackwell-over-Hopper 差距，为什么？
5. 计算 405B 模型在 NVFP4 权重 + FP8 KV 缓存 128k 上下文下所需的 HBM。它能放入单个 GB200 NVL72 节点吗？

## 关键术语

| 术语 | 人们的说法 | 实际含义 |
|------|----------------|------------------------|
| FP8 | "八位浮点" | 8 位浮点；因动态范围用于 KV 缓存和注意力 |
| NVFP4 | "四位微型" | NVIDIA 的 4 位微缩放 FP 格式；Blackwell 上的权重和激活 |
| MXFP8 | "MX 八位" | 微缩放 FP8 变体；Blackwell Tensor Core 上硬件加速 |
| 第 0 天 FP4 | "直接发布 FP4 权重" | 模型提供商发布已是 FP4 的权重；无训练后转换步骤 |
| MTP | "多 Token 预测" | TRT-LLM 集成的推测解码草稿（Phase 17 · 05） |
| 分离式推理 | "拆分预填充/解码" | 预填充和解码在独立 GPU 池上；KV 通过 NVLink/IB 传输 |
| 全对全 | "MoE 专家通信" | 将 Token 路由到专家 GPU 的通信模式；NVLink 5 减少 3 倍 |
| InferenceX | "SemiAnalysis 推理基准" | 2026 年行业接受的每 Token 成本基准 |

## 扩展阅读

- [NVIDIA — Blackwell Ultra MLPerf Inference v6.0](https://developer.nvidia.com/blog/nvidia-blackwell-ultra-sets-new-inference-records-in-mlperf-debut/) —— 2026 年 4 月 MLPerf 结果。
- [NVIDIA — Blackwell 上的 MoE 推理](https://developer.nvidia.com/blog/delivering-massive-performance-leaps-for-mixture-of-experts-inference-on-nvidia-blackwell/) —— NVLink 5 全对全和 MoE 内核。
- [TensorRT-LLM 概述](https://nvidia.github.io/TensorRT-LLM/overview.html) —— 官方引擎文档。
- [NVIDIA — Introducing Dynamo](https://developer.nvidia.com/blog/introducing-nvidia-dynamo-a-low-latency-distributed-inference-framework-for-scaling-reasoning-ai-models/) —— TRT-LLM 之上的分离式编排。
- [MLPerf Inference](https://mlcommons.org/benchmarks/inference-datacenter/) —— 发布 Blackwell 数字的基准套件。