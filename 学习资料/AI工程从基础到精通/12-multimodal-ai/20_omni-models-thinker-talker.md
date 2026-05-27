# 全模态模型：Qwen2.5-Omni 与 Thinker-Talker 分离架构

> GPT-4o 在 2024年5月的产品演示之所以具有颠覆性，不是因为底层模型，而是因为产品形态——一个语音界面，你可以说话，模型看到摄像头所看到的，并在 250ms 内回话。开源生态在 2024 年剩余时间和 2025 年都在竞相追赶这一产品体验。Qwen2.5-Omni（2025年3月）是参考开源设计：一个 Thinker（大型文本生成 Transformer）加上一个 Talker（并行语音生成 Transformer），通过流式语音 Token 连接。Mini-Omni 简化了它，Moshi 匹配了其延迟，GLM-4-Voice 将其扩展到中文。本课将解读 Thinker-Talker 架构以及使流式实时对话成为可能的延迟预算。

**类型：** 构建
**语言：** Python（标准库，流式流水线延迟模拟器 + VAD 循环）
**前置要求：** 第12阶段 · 19（音频-LLM），第12阶段 · 16（任意模态到任意模态）
**时间：** ~180分钟

## 学习目标

- 将推理流水线拆分为 Thinker（文本推理）和 Talker（语音合成），并解释为什么并行流式工作可行。
- 逐组件计算对话交互的首字节音频时间（TTFAB）预算。
- 描述 Thinker 内部跨视觉、音频和文本的 TMRoPE 时间对齐位置编码。
- 列举三种实时对话模式：半双工、轮流发言、全双工。

## 问题

一个实时语音助手必须做很多事情，而且要快：

1. 听用户说话。实时语音分词，语音活动检测（VAD）以判断用户何时说完。
2. 可选择地看。摄像头以 2-4 FPS 输入，与音频一起流式输入 Thinker。
3. 思考。以对话历史为条件组合响应。
4. 说话。合成音频 Token，解码为波形，流式传输到用户的扬声器。

每一步都增加延迟。对话体验要求总往返时间 < 500ms——低于此阈值，用户不再注意到延迟。GPT-4o 声称约 250ms。Moshi 约 160ms。Qwen2.5-Omni 约 350-500ms。

每个组件都需要流式处理。不能"全部批处理然后解码"。

## 核心概念

### Thinker 和 Talker

Qwen2.5-Omni 的分解：

- Thinker：一个 7B-80B 的文本生成 Transformer。消费交错的文本 + 图像 + 音频 Token。输出表示要说什么的文本 Token。
- Talker：一个较小的语音生成 Transformer（200M-1B）。消费 Thinker 的文本输出 Token 加上最近的语音上下文 Token。输出离散语音 Token（残差 VQ 索引）。
- 语音解码器：一个流式波形解码器（SNAC、MoVQGAN 系列），将语音 Token 实时转换为音频样本。

这种分离很重要。Thinker 必须足够大以获得良好的推理能力。Talker 可以较小，因为它的工作是局部的——将文本转换为语音 Token。更大的 Talker 并不会更有表现力；反而更慢。

两者并行运行：

1. Thinker 发出文本 Token t_i。
2. Talker 消费 t_i（通过流式）并发出语音 Token s_i, s_{i+1}, ..., s_{i+k}。
3. 语音解码器消费到达的语音 Token 并发出音频样本。
4. 当 Thinker 处理到文本 Token t_{i+3} 时，Talker 已经为 t_0..t_{i+2} 流式输出了音频。

### TMRoPE——时间对齐的多模态位置编码

Thinker 需要整合图像帧（以例如 4 FPS 到达）、音频帧（以 50 帧/秒到达）和对话历史中的文本。天真的序列顺序（所有图像，然后所有音频，然后文本）会丢失时间对齐。

TMRoPE 为每个 Token 分配绝对时间戳。视觉 Token 在 t=2.3s。音频 Token 在 t=2.32s。用户说"停"的文本 Token 在 t=2.35s。RoPE 按时间戳旋转注意力；模型将它们视为时间上并发的。

这是"他一边挥手一边说你好"得以工作的基础设施——模型在同一概念时刻看到视频帧和音频。

### 流式语音合成

语音 Token 必须流式输出。Mini-Omni（Xie & Wu，2024）引入了"语言模型可以听，同时在流式思考中说话"：Thinker 的输出 Token 和 Talker 的输出 Token 在同一序列中交错。一旦 Thinker 提交下一个文本 Token，Talker 就立即触发。没有批次边界。

Moshi（Défossez et al.，2024年10月）是最快的开源实现。在单张 A100 上实现 160ms TTFAB。架构：单个 7B Transformer，在交替位置上发出文本和语音 Token，并通过"内心独白"（Inner Monologue）将思考流与说话流分离。这实际上是将 Thinker + Talker 融合为一个模型，并通过精心训练实现。

### VAD 和轮流发言

语音活动检测（VAD）运行在输入端。两种模式：

- 半双工：用户说话，模型听。模型说话，用户听。通过 VAD 静音检测（约 200ms）进行清晰切换。
- 全双工：双方可以同时说话。模型可以反馈（"嗯哼"）或打断。难度大得多。Moshi 支持此模式。

Qwen2.5-Omni 默认支持半双工，通过静音阈值进行轮流切换。全双工需要应用层处理。

### Qwen3-Omni（2025年11月）

后续版本。Qwen3-80B Thinker，更大的 Talker，改进的 TMRoPE-v2。延迟接近 GPT-4o 的 250ms。开源权重。OmniBench 上的基准测试与 Gemini 2.0 Live 竞争。

### 生产延迟预算

对于典型的流式交互：

- 麦克风 -> 音频 Token：40-80ms。
- 预填充（提示 + 历史）：7B 模型 100-200ms，70B 模型更长。
- 首个 Thinker 文本 Token：40ms。
- Talker 处理首个文本 Token：20ms。
- 首组语音 Token 提交：40ms。
- 残差 VQ 解码：30ms。
- 语音波形解码：50-80ms。

总 TTFAB：7B 模型 320-510ms，70B 模型 600-900ms。前沿质量通常意味着 70B+；这就是前沿模型的延迟差距。

### Token 速率计算

在 16kHz 语音、50 Hz 基础语音 Token 下，每秒输出需要 50 个语音 Token。Talker 必须以 ≥50 tok/s 的速度发出来跟上。在 H100 上典型 LLM 吞吐量为 30-80 tok/s 的情况下，小型（200-300M）Talker 足够快；7B Talker 会跟不上。

这就是为什么存在专用的小型 Talker 模型，而不是"直接使用主模型"。

## 实践

`code/main.py`：

- 模拟 Thinker-Talker 流水线，使用模拟 Token 发出速率。
- 计算可配置模型大小和麦克风采样率下的 TTFAB。
- 演示带 VAD 静音阈值的半双工轮流发言。

## 成果输出

本课产出 `outputs/skill-omni-streaming-budget.md`。给定一个实时语音产品的目标 TTFAB 和功能集（视觉输入、双语、全双工），选择 Qwen2.5-Omni、Qwen3-Omni、Moshi 或 Mini-Omni，并确定 Thinker/Talker 的大小。

## 练习

1. 你的目标 TTFAB 是 300ms。在 7B Thinker 和 300M Talker 上，写出每个组件的延迟。

2. Qwen2.5-Omni 使用 TMRoPE。描述对于用户在 t=1s 开始说话且摄像头在 t=1.2s 捕捉到一个手势这样的提示，模型看到的是什么。

3. 全双工支持要求模型在说话的同时听。提出一种训练数据格式来教授这一点。

4. 阅读 Moshi 论文第4节。描述"内心独白"分离，以及为什么它避免了 Thinker-Talker 拆分。

5. 计算吞吐量预算：Talker 必须以多快的速度发出 Token 才能跟上 16kHz 语音每秒 50 个基础层 Token 的速度？

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| Thinker | "推理大脑" | 大型文本生成 Transformer，产生要说什么的内容 |
| Talker | "语音生成的嘴" | 小型 Transformer，从 Thinker 的文本产生离散语音 Token |
| TTFAB | "延迟预算" | 首字节音频时间：从用户语音结束到首个音频样本输出 |
| TMRoPE | "时间对齐 RoPE" | 跨视觉、音频、文本使用绝对时间戳的位置编码 |
| 半双工 | "轮流发言" | 用户和模型交替；VAD 静音检测用户完成 |
| 全双工 | "同时进行" | 模型可以同时说和听；支持反馈 |
| 内心独白 | "Moshi 分离" | 单模型设计，思考流和说话流交错 |

## 延伸阅读

- [Xu et al. — Qwen2.5-Omni (arXiv:2503.20215)](https://arxiv.org/abs/2503.20215)
- [Qwen Team — Qwen3-Omni (arXiv:2509.17765)](https://arxiv.org/html/2509.17765v1)
- [Xie & Wu — Mini-Omni (arXiv:2408.16725)](https://arxiv.org/abs/2408.16725)
- [Défossez et al. — Moshi (arXiv:2410.00037)](https://arxiv.org/abs/2410.00037)
- [Zeng et al. — GLM-4-Voice (arXiv:2412.02612)](https://arxiv.org/abs/2412.02612)