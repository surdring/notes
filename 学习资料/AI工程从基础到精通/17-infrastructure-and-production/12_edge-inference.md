# 边缘推理 — Apple Neural Engine、Qualcomm Hexagon、WebGPU/WebLLM、Jetson

> 边缘推理的核心约束是内存带宽，而非计算。移动 DRAM 位于 50-90 GB/s；数据中心 HBM3 超过 2-3 TB/s——30-50 倍的差距。解码推理受限于内存带宽，因此这个差距是决定性的。2026 年格局分为四条路线。Apple M4/A18 Neural Engine 峰值 38 TOPS，使用统一内存（无 CPU↔NPU 拷贝）。Qualcomm Snapdragon X Elite / 8 Gen 4 Hexagon 达到 45 TOPS。WebGPU + WebLLM 在 M3 Max 上以约 41 tok/s 运行 Llama 3.1 8B（Q4）（大约为原生的 70-80%）；17.6k GitHub 星标，OpenAI 兼容 API，约 70-75% 移动设备覆盖率。NVIDIA Jetson Orin Nano Super（8GB）适配 Llama 3.2 3B / Phi-3；AGX Orin 通过 vLLM 以约 40 tok/s 运行 gpt-oss-20b；Jetson T4000（JetPack 7.1）性能为 AGX Orin 的 2 倍。TensorRT Edge-LLM 支持 EAGLE-3、NVFP4、分块预填充——由 Bosch、ThunderSoft、MediaTek 在 CES 2026 上展示。

**类型：** 学习
**语言：** Python（标准库，玩具级带宽受限解码模拟器）
**前置知识：** 第 17 阶段 · 04（vLLM 推理内部），第 17 阶段 · 09（生产量化）
**时间：** 约 60 分钟

## 学习目标

- 解释为什么移动端 LLM 推理受限于内存带宽，而计算是次要的。
- 列举四种边缘目标（Apple ANE、Qualcomm Hexagon、WebGPU/WebLLM、NVIDIA Jetson），并为每种目标匹配合适的使用场景。
- 说出 2026 年 WebGPU 覆盖率缺口（Firefox Android 仍在追赶）以及 Safari iOS 26 的上线。
- 按目标选择量化格式（ANE 使用 Core ML INT4 + FP16，Hexagon 使用 QNN INT8/INT4，浏览器使用 WebGPU Q4，Jetson Thor 使用 NVFP4）。

## 问题

一个客户想要一个设备端聊天机器人：语音优先、默认隐私、离线可用。在 MacBook Pro M3 Max 上，Llama 3.1 8B Q4 以约 55 tok/s 运行——没问题。在 iPhone 16 Pro 上，同一模型以 3 tok/s 运行——不行。在配备 Snapdragon 8 Gen 3 的中端 Android 上，7 tok/s。在 Chrome Android v121+ 上的 WebGPU 浏览器中，视设备而定 4-8 tok/s。

吞吐量的差异不是一个移植问题。这是带宽差距乘以量化格式乘以 NPU 是否从用户空间可访问的结果。2026 年的边缘推理是四个不同的问题，有四种不同的解决方案。

## 概念

### 带宽才是真正的天花板

解码推理为每个 token 读取全部权重。一个 Q4 的 7B 模型是 3.5 GB。以 50 GB/s 读取 3.5 GB 需要 70 ms——理论天花板约 14 tok/s。在 90 GB/s（高端移动 DRAM）下天花板移动到约 25 tok/s。在这个数字之下，再多的计算也无济于事。

数据中心 HBM3 以 3 TB/s 读取同样的 3.5 GB 仅需 1.2 ms——天花板为 830 tok/s。同样的模型，同样的权重。不同的是内存子系统。

### Apple Neural Engine（M4 / A18）

- 最高 38 TOPS。统一内存（CPU 和 ANE 共享同一内存池）——无拷贝开销。
- 通过 Core ML + `.mlmodel` 编译模型访问，或通过 PyTorch 的 Metal Performance Shaders（MPS）访问。
- llama.cpp Metal 后端使用 MPS，而非直接使用 ANE；原生 ANE 需要 Core ML 转换。
- 2026 年 iOS 应用的最佳实践路径：Core ML，INT4 权重 + FP16 激活值。

### Qualcomm Hexagon（Snapdragon X Elite / 8 Gen 4）

- 最高 45 TOPS。在 SoC 中与 CPU 和 GPU 集成，但处于独立内存域。
- QNN（Qualcomm Neural Network）SDK 和 AI Hub 提供从 PyTorch/ONNX 的转换。
- 对话模板、Llama 3.2、Phi-3 均在 AI Hub 上作为一级产物提供。

### Intel / AMD NPU（Lunar Lake、Ryzen AI 300）

- 40-50 TOPS。软件落后于 Apple/Qualcomm；OpenVINO 在改进但仍属小众。
- 最适用于 Windows ARM Copilot 应用；在 AMD/Intel 桌面端原生支持本地优先场景。

### WebGPU + WebLLM

- 通过 WebGPU 计算着色器（Compute Shader）在浏览器中运行模型；无需安装。
- Llama 3.1 8B Q4 在 M3 Max 上约 41 tok/s——大约为同一后端的原生性能的 70-80%。
- WebLLM 17.6k GitHub 星标；OpenAI 兼容 JS API；Apache 2.0。
- 2026 年覆盖率：Chrome Android v121+、Safari iOS 26 正式版、Firefox Android 仍在追赶。总体约 70-75% 移动设备覆盖率。

### NVIDIA Jetson 家族

- Orin Nano Super（8GB）：可运行 Llama 3.2 3B、Phi-3，得到不错的 tok/s。
- AGX Orin：通过 vLLM 以约 40 tok/s 运行 gpt-oss-20b。
- Thor / T4000（JetPack 7.1）：2 倍 AGX Orin 性能，支持 EAGLE-3 和 NVFP4。
- TensorRT Edge-LLM（2026）支持 EAGLE-3 推测解码（Speculative Decoding）、NVFP4 权重、分块预填充——数据中心优化移植到边缘。

### 各目标的量化选择

| 目标 | 格式 | 说明 |
|--------|--------|-------|
| Apple ANE | INT4 权重 + FP16 激活值 | Core ML 转换路径 |
| Qualcomm Hexagon | QNN INT8 / INT4 | AI Hub 转换器 |
| WebGPU / WebLLM | Q4 MLC（q4f16_1） | 使用 `mlc_llm convert_weight` + 编译后的 `.wasm`；不支持 GGUF |
| Jetson Orin Nano | Q4 GGUF 或 TRT-LLM INT4 | 内存受限 |
| Jetson AGX / Thor | NVFP4 + FP8 KV | Edge-LLM 路径 |

### 边缘上的长上下文陷阱

Llama 3.1 的 128K 上下文是数据中心特性。在 8 GB RAM 的手机上，4 GB 模型 + 32K token 的 2 GB KV 缓存 + OS 开销 = OOM。边缘部署将上下文保持在 4K-8K，除非接受激进的 KV 量化（Q4 KV）。

### 语音是杀手级应用

语音代理对延迟敏感（首个 token < 500 ms）。本地推理完全消除了网络延迟。结合语音转文字（Whisper Turbo 变体可在边缘运行），边缘推理成为生产级语音循环。

### 应记住的数字

- Apple M4 / A18 ANE：38 TOPS。
- Qualcomm Hexagon SD X Elite：45 TOPS。
- WebLLM M3 Max：Llama 3.1 8B Q4 约 41 tok/s。
- AGX Orin：通过 vLLM 运行 gpt-oss-20b 约 40 tok/s。
- 数据中心-边缘带宽差距：30-50 倍。
- WebGPU 移动端覆盖率：约 70-75%（Firefox Android 滞后）。

## 使用它

`code/main.py` 根据带宽受限的数学计算跨边缘目标的理论解码吞吐量天花板。对比观测基准并高亮带宽（而非计算）在何处成为瓶颈。

## 交付它

本课生成 `outputs/skill-edge-target-picker.md`。根据平台（iOS/Android/浏览器/Jetson）、模型以及延迟/内存预算，选择量化格式和转换管线。

## 练习

1. 运行 `code/main.py`。对 Snapdragon 8 Gen 3（约 77 GB/s 带宽）上的 7B Q4 模型，计算解码天花板。对比观测的 6-8 tok/s——运行时效率如何？
2. WebGPU 在 Android 上需要 Chrome v121+。为旧版浏览器设计回退方案——通过相同的 OpenAI 兼容 API 在服务端完成。
3. 你的 iOS 应用需要 4K 上下文的流式输出。哪种模型/格式组合能让你在 iPhone 16 上保持在 4 GB 活动内存以内？
4. Jetson AGX Orin 以 40 tok/s 运行 gpt-oss-20b。Jetson Nano 只能适配 3B。如果你的产品同时面向两者，如何统一推理栈？
5. 论证"WebLLM 在 2026 年是否已生产就绪"。引用覆盖率、性能以及 Firefox Android 缺口。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|----------------|------------------------|
| ANE | "Apple 神经引擎" | M 系列和 A 系列中的设备端 NPU；统一内存 |
| Hexagon | "Qualcomm NPU" | Snapdragon NPU；通过 QNN SDK 访问 |
| WebGPU | "浏览器 GPU" | W3C 标准化的浏览器 GPU API；Chrome/Safari 2026 |
| WebLLM | "浏览器 LLM 运行时" | MLC-LLM 项目；Apache 2.0；OpenAI 兼容 JS |
| Jetson | "NVIDIA 边缘" | Orin Nano / AGX / Thor / T4000 家族 |
| TRT Edge-LLM | "边缘 TensorRT" | 2026 年 TensorRT-LLM 的边缘移植版；EAGLE-3 + NVFP4 |
| Unified memory | "共享内存池" | CPU 和 NPU 看到相同的 RAM；无拷贝开销 |
| Bandwidth-bound | "内存受限" | 解码推理受限于读取权重的字节/秒速率 |
| Core ML | "Apple 转换" | Apple 用于 ANE 原生模型的框架 |
| QNN | "Qualcomm 技术栈" | Qualcomm Neural Network SDK |

## 延伸阅读

- [On-Device LLMs State of the Union 2026](https://v-chandra.github.io/on-device-llms/) — 格局和基准。
- [NVIDIA Jetson Edge AI](https://developer.nvidia.com/blog/getting-started-with-edge-ai-on-nvidia-jetson-llms-vlms-and-foundation-models-for-robotics/) — Orin / AGX / Thor。
- [NVIDIA TensorRT Edge-LLM](https://developer.nvidia.com/blog/accelerating-llm-and-vlm-inference-for-automotive-and-robotics-with-nvidia-tensorrt-edge-llm/) — 2026 边缘移植公告。
- [WebLLM (arXiv:2412.15803)](https://arxiv.org/html/2412.15803v2) — 设计和基准。
- [Apple Core ML](https://developer.apple.com/documentation/coreml) — ANE 原生转换。
- [Qualcomm AI Hub](https://aihub.qualcomm.com/) — Hexagon 的预转换模型。