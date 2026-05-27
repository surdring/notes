# 视频-语言模型：时序 Token 与时间定位

> 视频不是一叠照片。一段 5 秒的片段具有因果顺序、动作动词和事件时间，这些是图像模型无法表示的。Video-LLaMA（Zhang et al.，2023年6月）发布了首个带有音视频定位功能的开源视频-LLM。VideoChat 和 Video-LLaVA 扩展了这一模式。到 2025 年，Qwen2.5-VL 的 TMRoPE 缩小了与前沿闭源模型的差距。每个系统以不同方式处理时序 Token——每个片段的 Q-former、每帧的拼接池化、每个 Token 的 TMRoPE。本课将解读这些模式，构建统一与动态帧采样器，并在时序定位任务上进行评估。

**类型：** 构建
**语言：** Python（标准库，帧采样器 + 时序定位评估器）
**前置要求：** 第12阶段 · 08（LLaVA-OneVision）
**时间：** ~180分钟

## 学习目标

- 解释为什么时序位置编码独立于视觉编码器影响视频 VLM 的性能。
- 比较均匀、动态 FPS 和事件驱动的帧采样策略在每秒 Token 数与定位准确率上的差异。
- 描述 Q-former-每片段（Video-LLaMA）vs 池化-每帧（Video-LLaVA）vs M-RoPE-每 Token（Qwen2.5-VL）的设计。
- 列举四种视频基准测试：VideoMME、TempCompass、EgoSchema、Video-MMMU。

## 问题

一段 1 分钟、30 FPS 的视频有 1800 帧。每帧 196 个视觉 Token（ViT-B，224分辨率），总计 352k Token——超过了 2024 年任何 LLM 的上下文窗口。

存在三种缩减策略：

1. 下采样帧（根据内容 1-8 FPS）。
2. 对每帧的图像块 Token 进行激进池化（3x3 或 4x4 双线性池化）。
3. 通过 Q-former 压缩，输入 16 帧片段，输出 64 个 Token。

每种策略的权衡不同。下采样丢失时序细节。池化丢失空间细节。Q-former 两者都丢失一点，但节省 Token。

时序位置编码是另一个维度：模型如何知道第5帧在第6帧之前？选项包括简单的 1D 时序 RoPE（Video-LLaMA）、学习的时序嵌入（Video-LLaVA）和 TMRoPE（Qwen2.5-VL，完整 3D）。

## 核心概念

### Video-LLaMA：每个片段的 Q-former + 音频分支

Video-LLaMA（2023）是首个开源视频-LLM。架构：

- 16 帧片段，2 FPS（即 8 秒）。
- 每帧 ViT 特征 -> Video Q-former 对所有 16 帧进行交叉注意力 -> 32 个可学习查询 -> LLM。
- 并行音频分支：波形 -> ImageBind 音频编码器 -> Audio Q-former -> 32 个查询 -> LLM。

优势：音视频联合推理。劣势：固定片段长度，无法进行任意时间定位。

### VideoChat 和 Video-LLaVA

VideoChat 保留了 Video-LLaMA 的思路，但去掉了音频并进行了简化。Video-LLaVA（Lin et al.，2023）在图像和视频帧上训练了单一视觉编码器（"投影前对齐"），提供了统一的表示。两者都是冻结的 CLIP 编码器 + MLP + LLM。

两者都无法处理长视频。两者都是 8-16 帧的系统。

### Qwen2.5-VL 和 TMRoPE

Qwen2.5-VL 引入了 TMRoPE——时序-模态旋转位置嵌入（Temporal-Modality Rotary Position Embedding）。每个图像块 Token 携带一个 (t, h, w) 位置，其中 t 是实际时间戳（而非帧索引）。

与简单时序嵌入的关键区别：

- 绝对时间，而非索引。模型看到的是"在 4.2 秒处"，而不是"在第15帧处"。
- 每个 Token 独立旋转，而非每个片段。每个视觉 Token 根据其时间戳独立旋转。
- 兼容动态 FPS。如果你在这里以 2 FPS 采样，在那里以 4 FPS 采样，TMRoPE 原生处理不均匀的间距。

TMRoPE 使得"猫在第几秒跳起来？"这样的查询成为可能。模型可以输出"在 4.2 秒处"。Video-LLaMA 只能回答"在片段早期"。

### 帧采样策略

均匀采样：在时长内均匀采样 N 帧。简单，但丢失运动峰值。

动态 FPS：根据运动强度自适应采样。光流或帧差分选择高运动片段进行更密集的采样。Qwen2.5-VL 在此策略上训练。

事件驱动：运行轻量级检测器，在动作发生的地方采样更多。VideoAgent 使用此策略。

关键帧 + 上下文：在镜头边界 + 相邻几帧处采样。用于电影内容。

### 每帧池化

在 1 FPS 和每帧 576 Token 的情况下，一段 5 分钟的片段有 172,800 Token。使用 Qwen2.5-VL-72B 的 128k 上下文可以处理，但成本很高。

3x3 双线性池化将每帧减少到 64 Token -> 5 分钟 19,200 Token。对于大多数任务是最佳平衡点。

对于空间细节不那么重要的智能体工作流，更激进地池化（6x6 -> 每帧 16 Token）。

### 四种视频基准测试

- VideoMME：全面的视频理解，短 + 中 + 长。
- TempCompass：细粒度时序推理，"之前"/"之后"类问题。
- EgoSchema：长时程第一人称视频。
- Video-MMMU：多模态多学科视频问答。

完整的视频-VLM 评估需要覆盖全部四种。它们强调不同的维度——TempCompass 关注时间顺序，EgoSchema 关注 3 分钟以上的推理，VideoMME 涵盖多种时长。

### 定位输出格式

时序定位的输出格式：

- 自由文本："猫在大约4秒处跳起来。"易于解析但不精确。
- 结构化 JSON：`{"event": "jump", "start": 4.1, "end": 4.3}`。Qwen2.5-VL 训练此格式。
- 基于 Token：特殊的 `<time>4.1</time>` Token 与答案交错。Qwen2.5-VL 的内部格式。

基于 Token 的格式在下游使用中最为准确。Qwen2.5-VL 的 JSON 输出格式可以直接解析。

### 2026 最佳实践

2026 年视频 VLM 的最佳实践：

- 编码器：带 M-RoPE 或 TMRoPE 的 SigLIP 2（Qwen2.5-VL）。
- 帧采样：动态 FPS（根据运动 1-4），带最大帧数上限。
- 每帧池化：3x3 双线性。
- 输出：带时间和事件字段的结构化 JSON。
- 基准测试：VideoMME + TempCompass 用于通用能力；EgoSchema 用于长时程。

## 实践

`code/main.py` 包含：

- 均匀和动态 FPS 帧采样器。
- 一个玩具时序定位评估器：给定时间 T 的"真值"事件和模型输出，以容差评分准确率。
- 对比 Video-LLaMA（16帧，Q-former）、Video-LLaVA（8帧，MLP）、Qwen2.5-VL（动态 FPS + TMRoPE）。

## 成果输出

本课产出 `outputs/skill-video-vlm-frame-planner.md`。给定一个视频任务（监控、动作识别、时序定位、摘要），选择帧采样器、池化因子、输出格式和预期准确率层级。

## 练习

1. 对于一段 3 分钟的烹饪演示，选择均匀 vs 动态 FPS。用 Token 数量来论证。

2. TMRoPE 具体添加了什么简单的时序嵌入表所不能做的事情？

3. 编写一个 VLM 可以学习生成的时序定位 JSON schema。包含错误情况。

4. 阅读 Video-LLaVA 第3节关于"投影前对齐"的内容。为什么这比训练独立的图像和视频编码器更好？

5. 根据 VideoMME 排行榜，截至 2026 年，顶级开源模型与顶级闭源模型之间的差距有多大？其中多少差距可归因于时序编码 vs 基座 LLM 规模？

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| 时序定位 | "时间本地化答案" | VLM 输出事件发生的具体时间戳范围 |
| TMRoPE | "时间-多模态 RoPE" | 带有绝对时间戳的 3D 旋转位置编码，Qwen2.5-VL 使用 |
| 动态 FPS | "运动感知采样" | 在高运动片段采样更多帧，在静态片段采样更少 |
| 帧池化 | "每帧空间压缩" | 在进入 LLM 之前用双线性插值减少每帧的图像块数量 |
| Video Q-former | "片段压缩器" | 将 N 帧映射到 K 个可学习查询的交叉注意力瓶颈 |
| VideoMME | "视频基准测试" | 全面的短/中/长视频基准测试，2500+ 样本 |

## 延伸阅读

- [Zhang et al. — Video-LLaMA (arXiv:2306.02858)](https://arxiv.org/abs/2306.02858)
- [Li et al. — VideoChat (arXiv:2305.06355)](https://arxiv.org/abs/2305.06355)
- [Lin et al. — Video-LLaVA (arXiv:2311.10122)](https://arxiv.org/abs/2311.10122)
- [Qwen Team — Qwen2.5-VL (arXiv:2502.13923)](https://arxiv.org/abs/2502.13923)
- [Lin et al. — VILA-1.5 (arXiv:2312.07533)](https://arxiv.org/abs/2312.07533)