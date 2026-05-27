# 视觉 Transformer 与 Patch-Token 原语

> 在任何多模态之前，图像必须变成 Transformer 可以处理的一串 token 序列。2020 年的 ViT（Vision Transformer）论文用 16x16 像素块（patch）、一个线性投影和一个位置嵌入回答了这个问题。五年之后，2026 年的每一个前沿模型（Claude Opus 4.7 原生 2576px、Gemini 3.1 Pro、Qwen3.5-Omni）仍然以此为起点——编码器从 ViT 换成了 DINOv2 再到 SigLIP 2，增加了注册 token（register token），位置方案变成了 2D-RoPE，但这个原语保持不变。本课从头到尾阅读 patch-token 管道，并用标准库 Python 构建它，以便 Phase 12 的其余部分对「视觉 token」有一个具体的思维模型。

**类型：** 学习
**语言：** Python（标准库，patch tokenizer + 几何计算器）
**前置条件：** Phase 7（Transformer）、Phase 4（计算机视觉）
**时间：** 约 120 分钟

## 学习目标

- 将 HxWx3 的图像转换为带有正确位置编码的 patch token 序列。
- 计算给定（patch 大小、分辨率、隐藏维度、深度）的 ViT 的序列长度、参数数量和 FLOPs。
- 指出将 ViT 从 2020 年研究推向 2026 年生产的三个升级：自监督预训练（DINO / MAE）、注册 token 和原生分辨率打包（native-resolution packing）。
- 在下游任务中选择 CLS 池化、均值池化或注册 token。

## 问题所在

Transformer 在向量序列上操作。文本已经是一个序列（字节或 token）。图像是一个具有三个颜色通道的 2D 像素网格——不是一个序列。如果你将每个像素展平，一张 224x224 的 RGB 图像变成 150,528 个 token，而在这个长度上的自注意根本无法使用（序列长度的二次方复杂度）。

2020 年之前的方法在前端挂接一个 CNN 特征提取器：ResNet 产生一个 7x7 的 2048 维向量特征图，将这 49 个 token 输入 Transformer。这确实有效，但继承了 CNN 的偏置（平移等变性、局部感受野），并失去了 Transformer 对规模的需求。

Dosovitskiy 等人（2020）提出了一个直截了当的问题：如果我们跳过 CNN 呢？将图像分割成固定大小的块（比如 16x16 像素），将每个块线性投影为一个向量，添加位置嵌入，然后将序列馈入一个普通的 Transformer。当时这被视为异端——没有卷积的视觉。在足够的数据（JFT-300M，之后是 LAION）下，它在 ImageNet 上击败了 ResNet 并持续改进。

到 2026 年，ViT 原语已是毋庸置疑的基础。每个开源 VLM 的视觉塔（vision tower）都是某种后代（DINOv2、SigLIP 2、CLIP、EVA、InternViT）。问题不再是「我们应该用块吗？」而是「用什么块大小、什么分辨率调度、什么预训练目标、什么位置编码」。

## 核心概念

### 将块作为 token

给定形状为 `(H, W, 3)` 的图像 `x` 和一个块大小 `P`，你将图像切割成 `(H/P) x (W/P)` 个不重叠的块。每个块是一个 `P x P x 3` 的像素立方体。将每个立方体展平成一个 `3 P^2` 向量。应用一个形状为 `(3 P^2, D)` 的共享线性投影 `W_E`，将每个块映射到模型的隐藏维度 `D`。

以 ViT-B/16 规范配置为例：
- 分辨率 224，块大小 16 → 网格 14x14 → 196 个 patch token。
- 每个块是 `16 x 16 x 3 = 768` 个像素值，投影到 `D = 768`。
- 添加一个可学习的 `[CLS]` token → 序列长度 197。

块投影在数学上等同于一个卷积核大小为 `P`、步长为 `P`、具有 `D` 个输出通道的 2D 卷积。这就是生产代码实际实现的方式——`nn.Conv2d(3, D, kernel_size=P, stride=P)`。「线性投影」的表述是概念性的；卷积核的表述是高效的。

### 位置嵌入

块本身没有固有顺序——Transformer 将它们视为一个袋子。早期 ViT 添加了一个可学习的 1D 位置嵌入（每个位置一个 768 维向量，共 197 个）。这是可行的，但将模型与训练分辨率绑定：在推理时，如果你改变网格，你必须插值位置表。

现代视觉骨干使用 2D-RoPE（Qwen2-VL 的 M-RoPE、SigLIP 2 的默认方案）或因子化 2D 位置。2D-RoPE 根据块的（行、列）索引旋转查询和键向量，因此模型从旋转角度推断相对 2D 位置。没有位置表。模型在推理时处理任意网格大小。

### CLS token、池化输出与注册 token

什么是图像级表示？三种选择并存：

1. `[CLS]` token。在块序列前添加一个可学习向量。经过所有 Transformer 块后，CLS token 的隐藏状态就是图像表示。继承自 BERT。被原始 ViT、CLIP 使用。
2. 均值池化（Mean pool）。对 patch token 的输出隐藏状态取平均值。被 SigLIP、DINOv2 和大多数现代 VLM 使用。
3. 注册 token（Register tokens）。Darcet 等人（2023）观察到，没有显式汇聚 token（sink token）训练的 ViT 会产生高范数的「伪影」块，劫持自注意力。添加 4-16 个可学习的注册 token 可以吸收这一负载，并改善密集预测质量（分割、深度）。DINOv2 和 SigLIP 2 都标配了注册 token。

选择对下游任务很重要。CLS 适合分类。对于将 patch token 输入 LLM 的 VLM，你完全跳过池化——每个块成为 LLM 的一个输入 token。注册 token 在移交给 LLM 之前被丢弃（它们是脚手架，不是内容）。

### 预训练：监督、对比、掩码、自蒸馏

2020 年的 ViT 在 JFT-300M 上通过监督分类预训练。很快被以下方法取代：

- CLIP（2021）：在 4 亿图像-文本对上做对比学习。第 12.02 课。
- MAE（2021，He 等人）：掩码 75% 的块，重建像素。自监督，在纯图像上工作。
- DINO（2021）/ DINOv2（2023）：师生自蒸馏，无标签，无描述。2023 年的 DINOv2 ViT-g/14 是最强的纯视觉骨干，是「密集特征」用例的默认选择。
- SigLIP / SigLIP 2（2023、2025）：使用 sigmoid 损失和 NaFlex 实现原生宽高比的 CLIP。2026 年开源 VLM 的主流视觉塔（Qwen、Idefics2、LLaVA-OneVision）。

你对预训练的选择决定了骨干适合什么：CLIP/SigLIP 适合与文本的语义匹配，DINOv2 适合密集视觉特征，MAE 作为下游微调的起点。

### 缩放定律

ViT 缩放（Zhai 等人，2022）确立了 ViT 的质量遵循模型大小、数据大小和算力方面的可预测规律。在固定算力下：
- 更大的模型 + 更多的数据 → 更好的质量。
- 块大小是序列长度 vs 保真度的一个杠杆。Patch 14（DINOv2/SigLIP SO400m 的典型值）每张图像产生比 patch 16 更多的 token；对 OCR 和密集任务更好，对速度更差。
- 分辨率是另一个重要杠杆。从 224 到 384 到 512 几乎总是有帮助的，但 FLOPs 会以平方级增加。

ViT-g/14（1B 参数，块大小 14，分辨率 224 → 256 个 token）和 SigLIP SO400m/14（400M 参数，块大小 14）是 2026 年开源 VLM 的两个主力编码器。

### ViT 的参数数量

完整计算见 `code/main.py`。对于 ViT-B/16 @ 224：

```
patch_embed = 3 * 16 * 16 * 768 + 768  =  591k
cls + pos    = 768 + 197 * 768          =  152k
block        = 4 * 768^2 (QKVO) + 2 * 4 * 768^2 (MLP) + 2 * 2*768 (LN)
             = 12 * 768^2 + 3k          =  7.1M
12 blocks    = 85M
final LN    = 1.5k
total       ≈ 86M
```

在加载检查点之前，用这种方法估算每个 ViT。骨干大小决定了任何下游 VLM 中的 VRAM 下限。

### 2026 年生产配置

2026 年大多数开源 VLM 配备的编码器是原生分辨率（NaFlex）的 SigLIP 2 SO400m/14。它具有：
- 400M 参数。
- 块大小 14，默认分辨率 384 → 每张图像 729 个 patch token。
- 图像级任务使用均值池化；所有 729 个块流入 LLM 用于 VQA。
- 4 个注册 token，在移交给 LLM 之前丢弃。
- 2D-RoPE 配合图像级缩放以支持原生宽高比。

该配置中的每一项决策都可以追溯到你可以阅读的一篇论文。

## 使用指南

`code/main.py` 是一个 patch tokenizer 和几何计算器。它接受（图像 H、W、块大小 P、隐藏维度 D、深度 L）并报告：

- 分块后的网格形状和序列长度。
- 合成 8x8 像素玩具图像的 token 序列（遍历展平 + 投影路径）。
- 按块嵌入、位置嵌入、Transformer 块和头部拆分的参数数量。
- 目标分辨率下每次前向传播的 FLOPs。
- 跨 ViT-B/16 @ 224、ViT-L/14 @ 336、DINOv2 ViT-g/14 @ 224、SigLIP SO400m/14 @ 384 的比较表。

运行它。将参数数量与已发布的数字匹配。调整块大小和分辨率来感受 token 数量的代价。

## 交付物

本课产出 `outputs/skill-patch-geometry-reader.md`。给定一个 ViT 配置（块大小、分辨率、隐藏维度、深度），它输出 token 数量、参数数量和 VRAM 估算及理由。每当你为 VLM 选择视觉骨干时使用这个技能——它能防止「token 爆炸，LLM 上下文填满」的意外。

## 练习

1. 计算 Qwen2.5-VL 在原生 1280x720 输入、块大小 14 时的 patch token 序列长度。与仅 CLS 的表示相比如何？

2. 一个 1080p 帧（1920x1080）在 patch 14 下产生多少个 token？在 30 FPS 下，5 分钟视频总共产生多少视觉 token？哪种成本节省最多：池化、帧采样还是 token 合并？

3. 用纯 Python 在 patch token 上实现均值池化。验证对 DINOv2 输出的 196 个 token 做均值池化是否与模型 `forward` 在请求池化嵌入时返回的结果匹配。

4. 阅读「Vision Transformers Need Registers」（arXiv:2309.16588）第 3 节。用两句话描述注册 token 吸收了何种伪影，以及为什么这对下游密集预测很重要。

5. 修改 `code/main.py` 以支持 patch-n'-pack：给定不同分辨率的图像列表，生成单个打包序列和块对角注意力掩码。当你学到第 12.06 课时对照验证。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|----------------|------------------------|
| 块（Patch） | 「16x16 像素方块」 | 输入图像的一个固定大小、不重叠的区域；成为一个 token |
| 块嵌入（Patch embedding） | 「线性投影」 | 一个共享的学习矩阵（或步长=P 的 Conv2d），将展平的块像素映射为 D 维向量 |
| CLS token | 「分类 token」 | 追加的可学习向量，其最终隐藏状态代表整个图像；2026 年可选 |
| 注册 token（Register token） | 「汇聚 token」 | 额外的可学习 token，吸收 ViT 在预训练期间产生的高范数注意力伪影 |
| 位置嵌入（Position embedding） | 「位置信息」 | 每个位置的向量或旋转，使序列具有顺序感知；2D-RoPE 是现代默认方案 |
| 网格（Grid） | 「块网格」 | 给定分辨率和块大小的 (H/P) x (W/P) 2D 块数组 |
| NaFlex | 「原生灵活分辨率」 | SigLIP 2 功能：单一模型服务多种宽高比和分辨率，无需重新训练 |
| 骨干（Backbone） | 「视觉塔」 | 预训练的图像编码器，其 patch token 输出馈入 VLM 中的 LLM |
| 池化（Pooling） | 「图像级摘要」 | 将 patch token 转换为一个向量的策略：CLS、均值、注意力池化或基于注册 token 的方式 |
| Patch 14 vs 16 | 「更细 vs 更粗的网格」 | Patch 14 每张图像产生更多 token，OCR 保真度更高，速度更慢；patch 16 是经典默认值 |

## 进一步阅读

- [Dosovitskiy et al. — An Image is Worth 16x16 Words (arXiv:2010.11929)](https://arxiv.org/abs/2010.11929)——原始 ViT 论文。
- [He et al. — Masked Autoencoders Are Scalable Vision Learners (arXiv:2111.06377)](https://arxiv.org/abs/2111.06377)——MAE，自监督预训练。
- [Oquab et al. — DINOv2 (arXiv:2304.07193)](https://arxiv.org/abs/2304.07193)——规模化自蒸馏，无标签。
- [Darcet et al. — Vision Transformers Need Registers (arXiv:2309.16588)](https://arxiv.org/abs/2309.16588)——注册 token 和伪影分析。
- [Tschannen et al. — SigLIP 2 (arXiv:2502.14786)](https://arxiv.org/abs/2502.14786)——2026 年的默认视觉塔。
- [Zhai et al. — Scaling Vision Transformers (arXiv:2106.04560)](https://arxiv.org/abs/2106.04560)——经验缩放定律。