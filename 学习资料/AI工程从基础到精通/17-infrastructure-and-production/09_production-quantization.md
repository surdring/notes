# 生产量化 — AWQ、GPTQ、GGUF K-quant、FP8、MXFP4/NVFP4

> 量化格式并非通用选择——它是硬件、推理引擎和工作负载的函数。GGUF Q4_K_M 或 Q5_K_M 主导 CPU 和边缘设备，通过 llama.cpp 和 Ollama 交付。GPTQ 在 vLLM 中需要同一基座上运行多个 LoRA 时胜出。AWQ 配合 Marlin-AWQ 内核在 7B 级模型上实现约 741 tok/s，且在 INT4 下 Pass@1 最佳——是 2026 年数据中心生产的默认选择。FP8 仍是 Hopper、Ada 和 Blackwell 上的中间地带——近乎无损且广泛支持。NVFP4 和 MXFP4（Blackwell 微缩放）较为激进，需要逐块验证。两个陷阱会坑到团队：标定数据集必须与部署领域匹配，且 KV 缓存与权重量化是独立的——"我的模型现在只有 4 GB"这个 AWQ 经验忘记了在生产批次规模下 10-30 GB 的 KV 缓存。

**类型：** 学习
**语言：** Python（标准库，跨格式的玩具级内存与吞吐量对比）
**前置知识：** 第 10 阶段 · 13（量化基础），第 17 阶段 · 04（vLLM 推理内部）
**时间：** 约 75 分钟

## 学习目标

- 说出六种生产量化格式及其 2026 年的最佳适用场景。
- 根据硬件（CPU vs GPU、Hopper vs Blackwell）、引擎（vLLM、TRT-LLM、llama.cpp）和工作负载（常规对话、推理、多 LoRA）选择格式。
- 计算所选格式节省的权重内存以及未被触动的 KV 缓存大小。
- 指出会在领域流量上降低量化模型质量的标定数据集陷阱。

## 问题

量化能减少内存和 HBM 带宽，这正是解码推理（Decode）所需。一个 FP16 70B 模型权重 140 GB。将权重量化为 INT4（AWQ 或 GPTQ）后模型为 35 GB——可装入一块 H100 并为 KV 缓存留出空间，这很重要，因为在 128 并发序列、2k 上下文的场景下，仅 KV 缓存就需要 20-30 GB。

但量化并非没有代价。激进量化会降低质量，尤其是在推理密集型任务上。不同格式适配不同引擎。不同硬件原生支持不同精度。2026 年的格式种类繁多，不能照搬别人的选择——必须根据自身技术栈做出选择。

## 概念

### 六种格式

| 格式 | 位数 | 最佳场景 | 引擎 |
|--------|------|-----------|---------|
| GGUF Q4_K_M / Q5_K_M | 4-5 | CPU、边缘设备、笔记本电脑 | llama.cpp、Ollama |
| GPTQ | 4-8 | vLLM 上多 LoRA | vLLM、TGI |
| AWQ | 4 | 数据中心 GPU 生产 | vLLM（Marlin-AWQ）、TGI |
| FP8 | 8 | Hopper/Ada/Blackwell 数据中心 | vLLM、TRT-LLM、SGLang |
| MXFP4 | 4 | Blackwell 多用户 | TRT-LLM |
| NVFP4 | 4 | Blackwell 多用户 | TRT-LLM |

### GGUF — CPU/边缘默认方案

GGUF 是一种文件格式，而非严格意义上的量化方案——它将 K-quant 变体（Q2_K、Q3_K_M、Q4_K_M、Q5_K_M、Q6_K、Q8_0）打包在一个容器中。Q4_K_M 和 Q5_K_M 是生产环境的默认选择——在 4-5 位下质量接近 BF16。是 CPU 或边缘推理的最佳选择，因为 llama.cpp 是迄今为止最快的 CPU 推理引擎。

在 vLLM 中的吞吐量惩罚：7B 模型约 93 tok/s——该格式未针对 GPU 内核优化。仅在部署目标是 CPU/边缘时使用 GGUF，否则不用。

### GPTQ — vLLM 中多 LoRA 方案

GPTQ 是一种带有标定通路的训练后量化（Post-Training Quantization）算法。Marlin 内核使其在 GPU 上高效运行（相比无 Marlin 的 GPTQ 有 2.6 倍加速）。7B 模型约 712 tok/s。

独特优势：GPTQ-Int4 在 vLLM 中支持 LoRA 适配器。如果你正在提供基础模型加 10-50 个微调变体（每个以 LoRA 形式存在），GPTQ 是你的路径。截至 2026 年初，NVFP4 尚不支持 LoRA。

### AWQ — 数据中心 GPU 默认方案

激活感知权重量化（Activation-aware Weight Quantization）。在量化过程中保护约 1% 的最显著权重。Marlin-AWQ 内核：相比朴素实现有 10.9 倍加速。7B 模型约 741 tok/s，INT4 格式中 Pass@1 最佳。

新的 GPU 推理服务选择 AWQ，除非需要多 LoRA（GPTQ）或激进的 Blackwell FP4（NVFP4）。

### FP8 — 可靠中间方案

8 位浮点。近乎无损。广泛支持。Hopper Tensor Core 原生加速 FP8。Blackwell 继承。当质量不可妥协时（推理、医疗、代码生成），FP8 是 2026 年的安全默认选择。内存节省是 INT4 的一半，但质量风险远低。

### MXFP4 / NVFP4 — Blackwell 激进方案

微缩放 FP4（Microscaling FP4）。每个权重块有独立的缩放因子。激进但由 Blackwell Tensor Core 硬件加速。每 token 字节数相比 FP8 减半——这就是第 17 阶段 · 07 中的经济效益所在。

注意事项：
- 目前不支持 LoRA（2026 年初）。
- 在推理密集型工作负载上可观察到质量下降。
- 需要按模型在自己的评估集上验证。

### 标定陷阱

AWQ 和 GPTQ 需要标定数据集——通常是 C4 或 WikiText。对于领域模型（代码、医疗、法律），在通用网页文本上进行标定会让算法在选择保护哪些权重时做出错误决策。HumanEval 上的 Pass@1 可能下降数个百分点。

修复方案：在领域内数据上标定。数百条领域样本通常足够。上线前在评估集上测试。

### KV 缓存陷阱

AWQ 将权重缩减为 4 位。KV 缓存是独立的，保持在 FP16/FP8。对于一个使用 AWQ 的 70B 模型：

- 权重：约 35 GB（从 140 GB 的 INT4）。
- KV 缓存（128 并发 × 2k 上下文）：约 20 GB。
- 激活值：约 5 GB。
- 总计：约 60 GB——可装入 H100 80GB。

天真地以为"我把模型量化到 4 GB 了"会忘记另外 30-50 GB。要整体规划 HBM 预算。

另外，KV 缓存量化（FP8 KV 或 INT8 KV）是一个独立选择，有其自身的权衡——它直接影响注意力精度，并非免费午餐。

### AWQ INT4 对推理任务有危害

思维链（Chain-of-Thought）、数学、长上下文代码生成——这些在激进量化下质量下降明显。AWQ INT4 在 MATH 上可能损失约 3-5 分。对于推理密集型工作负载，使用 FP8 或 BF16；接受相应的内存成本。

### 2026 年选择指南

- CPU/边缘推理：GGUF Q4_K_M。无需多虑。
- GPU 推理，常规对话，无 LoRA：AWQ。
- GPU 推理，多 LoRA：GPTQ 配合 Marlin。
- 推理工作负载：FP8。
- Blackwell 数据中心，已验证质量：NVFP4 + FP8 KV。
- 不确定：在每个候选格式上运行 1000 条样本评估。

## 使用它

`code/main.py` 计算跨六种格式在不同模型规模下的内存占用（权重 + KV + 激活值）和相对吞吐量。展示 KV 缓存在何处占据主导、权重压缩在何处带来回报，以及 FP8 在何处是最安全的选择。

## 交付它

本课生成 `outputs/skill-quantization-picker.md`。根据硬件、模型规模、工作负载类型和质量容忍度，选择格式并生成标定/验证计划。

## 练习

1. 运行 `code/main.py`。对于一个 70B 模型在 128 并发、2k 上下文下，计算每种格式的总 HBM 占用。哪种格式能让你装入一块 H100 80GB？
2. 你有一个 7B 代码模型。选择一种格式并说明理由。如果质量容忍度判断错误，恢复路径是什么？
3. 计算为一个医疗领域模型标定 AWQ 所需的标定数据集规模。为什么更多数据并不总是更好？
4. 阅读 Marlin-AWQ 内核论文或发布说明。用三句话解释为什么 AWQ 在 7B 上达到 741 tok/s 而原始 GPTQ 约为 712。
5. 什么时候将 AWQ 权重与 FP8 KV 缓存结合比将 KV 保持为 BF16 更有意义？

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|----------------|------------------------|
| GGUF | "llama.cpp 格式" | 捆绑 K-quant 变体的文件格式；CPU/边缘默认方案 |
| Q4_K_M | "Q4 K M" | 4 位 K-quant 中等；生产环境 GGUF 默认选择 |
| GPTQ | "gee pee tee q" | 带标定的训练后 INT4 量化；在 vLLM 中支持 LoRA |
| AWQ | "a w q" | 激活感知 INT4 量化；Marlin 内核；INT4 下 Pass@1 最佳 |
| Marlin kernels | "快速 INT4 内核" | 为 Hopper 定制的 CUDA INT4 内核；10 倍加速 |
| FP8 | "八位浮点" | Hopper/Ada/Blackwell 上的安全精度默认方案 |
| MXFP4 / NVFP4 | "微缩放四位" | Blackwell 4 位浮点，带逐块缩放因子 |
| Calibration dataset | "标定数据" | 用于选择量化参数的输入文本；必须与领域匹配 |
| KV cache quantization | "KV INT8" | 与权重量化独立的选择；影响注意力精度 |

## 延伸阅读

- [VRLA Tech — LLM Quantization 2026](https://vrlatech.com/llm-quantization-explained-int4-int8-fp8-awq-and-gptq-in-2026/) — 对比基准。
- [Jarvis Labs — vLLM Quantization Complete Guide](https://jarvislabs.ai/blog/vllm-quantization-complete-guide-benchmarks) — 按格式列出的吞吐量数据。
- [PremAI — GGUF vs AWQ vs GPTQ vs bitsandbytes 2026](https://blog.premai.io/llm-quantization-guide-gguf-vs-awq-vs-gptq-vs-bitsandbytes-compared-2026/) — 逐格式选择指南。
- [vLLM docs — Quantization](https://docs.vllm.ai/en/latest/features/quantization/index.html) — 支持的格式和参数。
- [AWQ paper (arXiv:2306.00978)](https://arxiv.org/abs/2306.00978) — AWQ 原始论文。
- [GPTQ paper (arXiv:2210.17323)](https://arxiv.org/abs/2210.17323) — GPTQ 原始论文。