# 自托管推理服务选择 — llama.cpp、Ollama、TGI、vLLM、SGLang

> 2026 年有四个推理引擎主导自托管推理。基于硬件、规模和生态系统选择。**llama.cpp** 在 CPU 上最快——最广泛的模型支持，完全控制量化与线程。**Ollama** 是开发笔记本电脑的一键安装方案，比 llama.cpp 约慢 15-30%（Go + CGo + HTTP 序列化），在生产负载下吞吐量差距达 3 倍。**TGI 于 2025 年 12 月 11 日进入维护模式**——仅修复 Bug，原始吞吐量比 vLLM 约慢 10%，但历史上拥有顶级的可观测性和 HF 生态系统集成。该维护状态使其成为有风险的长期选择——对于新项目，SGLang 或 vLLM 是更安全的默认选项。**vLLM** 是通用生产默认选型——v0.15.1（2026 年 2 月）添加 PyTorch 2.10、RTX Blackwell SM120、H200 优化。**SGLang** 是 Agent 多轮 / 前缀密集型场景的专家——生产中超过 400,000+ GPU（xAI、LinkedIn、Cursor、Oracle、GCP、Azure、AWS）。硬件约束：仅 CPU → 仅 llama.cpp。AMD / 非 NVIDIA → 仅 vLLM（TRT-LLM 锁定 NVIDIA）。2026 年流水线模式：开发 = Ollama，预发布 = llama.cpp，生产 = vLLM 或 SGLang。整个过程使用相同的 GGUF/HF 权重。

**类型：** 学习
**语言：** Python（标准库，引擎决策树遍历器）
**前置知识：** 覆盖推理引擎的所有第 17 阶段课程（04、06、07、09、18）
**时间：** 约 45 分钟

## 学习目标

- 根据硬件（CPU / AMD / NVIDIA Hopper / Blackwell）、规模（1 用户 / 100 / 10,000）和工作负载（通用对话 / Agent / 长上下文）选择引擎。
- 说出 2026 年 TGI 维护模式状态（2025 年 12 月 11 日）以及为什么它使新项目倾向 vLLM 或 SGLang。
- 描述使用相同 GGUF 或 HF 权重的开发/预发布/生产流水线。
- 解释为什么"仅 CPU"强制使用 llama.cpp，以及"AMD"排除 TRT-LLM。

## 问题

你的团队开始一个新的自托管 LLM 项目。一位工程师说 Ollama，另一位说 vLLM，第三位说"TGI 难道不就能开箱即用吗？"三者在不同场景下都对。没有一个适用于所有场景。

在 2026 年，选择树很重要：硬件第一，规模第二，工作负载第三。而一个特定的 2025 年事件——TGI 于 12 月 11 日进入维护模式——改变了新项目的默认选项。

## 概念

### 五大引擎

| 引擎 | 最适合 | 备注 |
|--------|----------|-------|
| **llama.cpp** | CPU / 边缘 / 最少依赖 / 最广模型支持 | CPU 上最快，完全控制 |
| **Ollama** | 开发笔记本电脑，单用户，一键安装 | 比 llama.cpp 慢 15-30%；生产吞吐量差距 3 倍 |
| **TGI** | HF 生态系统，受监管行业 | **2025 年 12 月 11 日进入维护模式** |
| **vLLM** | 通用生产，100+ 用户 | 广泛的生产默认选型；v0.15.1 2026 年 2 月 |
| **SGLang** | Agent 多轮，前缀密集型工作负载 | 生产中 400,000+ GPU |

### 硬件优先决策

**仅 CPU** → llama.cpp。Ollama 也可以但更慢。没有其他引擎在 CPU 上有竞争力。

**AMD GPU** → vLLM（AMD ROCm 支持）。SGLang 也可以。TRT-LLM 锁定 NVIDIA，所以排除。

**NVIDIA Hopper（H100 / H200）** → vLLM 或 SGLang 或 TRT-LLM。三者皆为顶级。

**NVIDIA Blackwell（B200 / GB200）** → TRT-LLM 是吞吐量领先者（第 17 阶段 · 07）。vLLM 和 SGLang 紧随其后。

**Apple Silicon（M 系列）** → llama.cpp（Metal）。Ollama 封装了此功能。

### 规模第二决策

**1 用户 / 本地开发** → Ollama。一个命令，首个 Token 在数秒内返回。

**10-100 用户 / 小团队** → vLLM 单 GPU。

**100-10k 用户 / 生产** → vLLM 生产栈（第 17 阶段 · 18）或 SGLang。

**10k+ 用户 / 企业** → vLLM 生产栈 + 分离式（第 17 阶段 · 17）+ LMCache（第 17 阶段 · 18）。

### 工作负载第三决策

**通用对话 / 问答** → vLLM 在广泛默认上胜出。

**Agent 多轮（工具、规划、记忆）** → SGLang 的 RadixAttention（第 17 阶段 · 06）占主导。

**高前缀重用的 RAG** → SGLang。

**代码生成** → vLLM 足够好；SGLang 在缓存上略优。

**长上下文（128K+）** → vLLM + 分块预填充；SGLang + 分层 KV。

### TGI 维护陷阱

Hugging Face TGI 于 2025 年 12 月 11 日进入维护模式——今后仅修复 Bug。历史上：顶级可观测性、最佳 HF 生态系统集成（模型卡、安全工具）、原始吞吐量略落后 vLLM。

对于 2026 年的新项目：默认远离 TGI。现有 TGI 部署可以继续但最终应迁移。SGLang 和 vLLM 是更安全的默认选项。

### 流水线模式

开发（Ollama）→ 预发布（llama.cpp）→ 生产（vLLM）。整个过程使用相同的 GGUF 或 HF 权重。工程师在笔记本电脑上快速迭代；预发布镜像生产量化；生产是推理服务目标。

### Ollama 注意事项

Ollama 对开发非常棒。对共享生产则不然：Go HTTP 序列化增加开销，并发管理比 vLLM 简单，OpenTelemetry 支持滞后。在 Ollama 擅长的地方使用它——一个用户，一个命令——并切换到 vLLM 用于共享。

### 自托管 vs 托管是独立决策

第 17 阶段 · 01（托管超大规模平台）、· 02（推理平台经济学）覆盖托管。本课程假设你已决定自托管。自托管的理由：数据驻留、自定义微调、大规模的总拥有成本、领域模型在托管平台上不可用。

### 应记住的数字

- TGI 维护模式：2025 年 12 月 11 日。
- vLLM v0.15.1：2026 年 2 月；PyTorch 2.10；Blackwell SM120 支持。
- SGLang 生产足迹：400,000+ GPU。
- Ollama 吞吐量差距 vs llama.cpp：15-30% 更慢；生产负载下 3 倍。

## 使用它

`code/main.py` 是一个决策树遍历器：给定硬件 + 规模 + 工作负载，选择一个引擎并解释原因。

## 交付它

本课生成 `outputs/skill-engine-picker.md`。给定约束条件，选择一个引擎并编写迁移计划。

## 练习

1. 用你的硬件/规模/工作负载运行 `code/main.py`。输出是否符合你的直觉？
2. 你的基础设施是 12 H100 和 8 MI300X AMD。选什么引擎？为什么 TRT-LLM 不在考虑范围内？
3. 一个团队想在 2026 年使用 TGI，因为"这是我们熟悉的"。论证迁移方案。
4. 从 Ollama 开发到 vLLM 生产：量化、配置和可观测性方面有什么变化？
5. 一个 RAG 产品，P99 前缀长度 8K，租户间高度重用。选择一个引擎并叠加第 17 阶段 · 11 + 18。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|----------------|------------------------|
| llama.cpp | "CPU 那个" | 最广模型支持，CPU 上最快 |
| Ollama | "笔记本那个" | 一键安装，开发级吞吐量 |
| TGI | "HF 的推理服务" | 自 2025 年 12 月进入维护模式 |
| vLLM | "默认选项" | 2026 年广泛的生产基线 |
| SGLang | "Agent 那个" | 前缀密集型，RadixAttention |
| TRT-LLM | "NVIDIA 锁定" | Blackwell 吞吐量领先者，仅 NVIDIA |
| GGUF | "llama.cpp 格式" | 捆绑的 K-quant 变体 |
| Production-stack | "vLLM K8s" | 第 17 阶段 · 18 参考部署 |
| Pipeline pattern | "开发→预发布→生产" | Ollama → llama.cpp → vLLM 使用相同权重 |

## 延伸阅读

- [AI Made Tools — vLLM vs Ollama vs llama.cpp vs TGI 2026](https://www.aimadetools.com/blog/vllm-vs-ollama-vs-llamacpp-vs-tgi/)
- [Morph — llama.cpp vs Ollama 2026](https://www.morphllm.com/comparisons/llama-cpp-vs-ollama)
- [n1n.ai — Comprehensive LLM Inference Engine Comparison](https://explore.n1n.ai/blog/llm-inference-engine-comparison-vllm-tgi-tensorrt-sglang-2026-03-13)
- [PremAI — 10 Best vLLM Alternatives 2026](https://blog.premai.io/10-best-vllm-alternatives-for-llm-inference-in-production-2026/)
- [TGI maintenance announcement](https://github.com/huggingface/text-generation-inference) — 发布说明。
- [vLLM v0.15.1 release notes](https://github.com/vllm-project/vllm/releases)