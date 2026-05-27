# Emu3：用于图像和视频生成的下一 Token 预测

> BAAI 的 Emu3（Wang 等人，2024 年 9 月）是 2024 年本应终结扩散-vs-自回归辩论的结果。一个单一的 Llama 风格仅解码器 Transformer，仅在下一 token 预测目标上训练，跨文本 + VQ 图像 token + 3D VQ 视频 token 的统一词汇，在图像生成上击败 SDXL，在感知上击败 LLaVA-1.6。没有 CLIP 损失。没有扩散调度。推理时使用无分类器引导（Classifier-Free Guidance）提高质量，但核心训练目标是带有教师强制（Teacher Forcing）的下一 token 预测。发表在《自然》上。本课阅读 Emu3 论点——为什么更好的分词器加规模就是全部所需——并与扩散方法对比。

**类型：** 学习
**语言：** Python（标准库，3D 视频分词器数学 + 自回归采样器骨架）
**前置条件：** Phase 12 · 11（Chameleon）
**时间：** 约 120 分钟

## 学习目标

- 解释为什么 Emu3 的单一损失下一 token 目标有效，尽管长期假设扩散是图像质量的必要条件。
- 描述 3D 视频分词器：时空 VQ 码本长什么样，为什么块跨越时间。
- 比较 Emu3 vs Stable Diffusion XL 在（训练算力、推理成本、质量上限）方面的差异。
- 指出同一 Emu3 模型扮演的三种角色：Emu3-Gen（图像生成）、Emu3-Chat（感知）、Emu3-Stage2（视频生成）。

## 问题所在

贯穿 2024 年的传统智慧：图像生成需要扩散。论点：离散图像 token 丢失太多信息，无法重建细节，自回归采样在数千个 token 上累积误差。Stable Diffusion、DALL-E 3、Imagen、Midjourney 都使用某种形式的扩散。Chameleon（第 12.11 课）在小规模上部分反驳了这一点，但在质量上没有匹敌 SDXL。

Emu3 正面攻击了这一论点。声称：更好的视觉分词器 + 足够的规模 + 下一 token 损失 = 在同时也能做感知的同一模型中实现击败扩散的图像生成。

这个赌注在发表时是有争议的。两年后，开源统一生成家族（Emu3、Show-o、Janus-Pro、Transfusion）是研究的默认路径；生产前沿模型似乎使用某种变体。

## 核心概念

### Emu3 分词器

关键成分是视觉分词器。Emu3 训练了一个定制的 IBQ 类分词器（逆瓶颈量化器，Inverse Bottleneck Quantizer，SBER-MoVQGAN 家族），每个 token 的分辨率降低 8x8。512x512 的图像变成 64x64 = 4096 个 token，码本大小 32768。

这比 Chameleon 在 K=8192 下每 512x512 的 1024 个 token 更大，但每个 token 更便宜（更小的码本查找，更简单的编解码器）。关键指标：重建 PSNR 在 30.5 dB，与 Stable Diffusion 在 32 dB 的连续潜在空间有竞争力。

对于视频：3D VQ 分词器将时空块（4x4x4 像素）编码为一个整数。一段 8 FPS 的 4 秒片段有 32 帧；在 256x256 分辨率下，以 4x 空间和 4x 时间缩减，token 数是 (256/4) * (256/4) * (32/4) = 64 * 64 * 8 = 32,768 个 token。

分词器质量是上限。Emu3 的贡献部分是「我们训练了一个非常好的分词器」。

### 单一损失训练

Emu3 使用一个目标：在文本 token、2D 图像 token 和 3D 视频 token 的共享词汇上做下一 token 预测。训练期间权重乘以模态特定因子以平衡贡献，但损失函数相同。

在以下混合上训练：
- 图像生成：`<文本描述> <image> 图像_token </image>`
- 图像感知：`<image> 图像_token </image> <问题> 文本_token`
- 视频生成：`<文本描述> <video> 视频_token </video>`
- 视频感知：类似。
- 纯文本：标准 NTP。

模型从数据分布中学习何时发出图像 token vs 文本 token。生成从模型在 `<image>` 标签之后预测图像 token 中涌现。

### 无分类器引导与温度

自回归图像生成在推理时使用无分类器引导（CFG）会好得多。Emu3 使用它：生成两次，一次带有完整描述，一次带有空描述，用引导权重（典型 3.0-7.0）混合 logit。这与扩散使用的 CFG 技巧相同，被借用到自回归设置中。

温度很重要：太高会产生伪影；太低会模式坍塌。Emu3 推荐温度为感知 1.0，图像生成 0.8。

### 三种角色，一个模型

Emu3 作为三个功能上不同的 API 发布，但底层是一组权重：

- Emu3-Gen。图像生成。输入文本，输出图像 token。
- Emu3-Chat。VQA 和描述生成。输入图像（token），输出文本。
- Emu3-Stage2。视频生成和视频 VQA。输入文本或视频，输出文本或视频。

没有特定任务的头。只是不同的提示词模板。相同的检查点。

### 基准

来自 Emu3 论文（2024 年 9 月）：

- 图像生成：在 MJHQ-30K FID 上击败 SDXL（5.4 vs 5.6），GenEval 总体（0.54 vs 0.55——统计平局），Deep-Eval 综合相当。
- 图像感知：在 VQAv2 上击败 LLaVA-1.6（75.1 vs 72.4），在 MMMU 上大致匹配。
- 视频生成：4 秒片段质量的 FVD 与 Sora 时代的公开基准模型有竞争力。

数字并非总是胜出——Emu3 在这里换一个点，在那里换一个点——但「下一 token 预测就是你全部所需」的声称在跨模态下是可辩护的。

### 算力成本

Emu3 在约 3000 亿多模态 token 上用 7B 参数模型训练。GPU-小时大致与 Llama-2-7B 预训练相当（A100 级硅片上 2k-4k GPU 年）。Stable Diffusion 3 等扩散模型在类似预算下训练，但需要单独的文本编码器和更复杂的管线。

在推理时，Emu3 每张图像比 SDXL 慢：4096 个图像 token 以 30 tok/s 是约 2 分钟/张 512x512 图像，而 SDXL 是 2-5 秒。推测解码（Speculative Decoding）和 KV 缓存优化缩小了差距但未消除。自回归图像生成是算力密集的；这是持续的权衡。

### 为什么重要

Emu3 的深层贡献是概念性的。如果下一 token 预测能够扩展到在图像生成上匹敌扩散，统一模型路径（一个损失、一个骨干、任意模态）就是可行的。未来的模型不需要单独的文本编码器、单独的扩散调度器、单独的 VAE。一个 Transformer，每种模态一个分词器，规模。

Show-o、Janus-Pro 和 InternVL-U 都建立在或挑战这一论点之上。中国实验室（BAAI、DeepSeek）在 2025 年中比美国实验室更积极地朝这个方向发表。

## 使用指南

`code/main.py` 构建两个玩具部分：

- 一个 2D vs 3D VQ 分词器 token 数计算器：给定（分辨率、块、片段长度、FPS），计算图像 vs 视频的 token 数。
- 一个带无分类器引导的自回归图像 token 采样器，在指定温度下。

CFG 实现匹配 Emu3 的方案——用引导权重混合条件和非条件 logit。

## 交付物

本课产出 `outputs/skill-token-gen-cost-analyzer.md`。给定生成产品规格（图像或视频、目标分辨率、质量层级、延迟预算），它计算 token 数量、推理成本，并选择 Emu3 家族 vs 扩散。

## 练习

1. Emu3 在 8x8 缩减下每 512x512 图像产生 4096 个 token。计算 1024x1024 和 2048x2048 的等价量。推理延迟会怎样变化？

2. 阅读 Emu3 第 3.3 节关于视频分词器的内容。描述 3D VQ 块形状及其为什么是 4x4x4 而非 8x8x1。

3. 无分类器引导权重 5.0 vs 3.0：什么视觉效果？在 `code/main.py` 中追踪数学。

4. 计算 Emu3-7B 在 300B token 上的训练 FLOPs，与 Stable Diffusion 3 比较。哪个训练更昂贵？

5. Emu3 在 FID 上击败 SDXL，但在 VQAv2 上不敌专门的 VLM。解释为什么统一损失方法在不同基准上显示不同的相对于专家的优势。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|------------------------|
| 下一 token 预测 | 「NTP」 | 标准自回归损失：给定 token[0..i] 预测 token[i+1]；当分词化后对每种模态都有效 |
| IBQ 分词器 | 「逆瓶颈量化器」 | 一类 VQ-VAE，具有更大的码本（32768+）和比 Chameleon 更好的重建 |
| 3D VQ | 「时空量化器」 | 按（时间、行、列）索引的码本；一个 token 覆盖 4x4x4 像素立方体 |
| 无分类器引导（CFG） | 「CFG」 | 用权重 gamma 混合条件和非条件 logit；在推理时提升图像质量 |
| 统一词汇 | 「共享 token」 | 文本 + 图像 + 视频都从同一整数空间抽取；模型预测接下来是哪种模态 |
| MJHQ-30K | 「图像生成基准」 | Midjourney 质量基准，含有 3 万条提示词；Emu3 在此报告 FID |

## 进一步阅读

- [Wang et al. — Emu3: Next-Token Prediction is All You Need (arXiv:2409.18869)](https://arxiv.org/abs/2409.18869)
- [Sun et al. — Emu: Generative Pretraining in Multimodality (arXiv:2307.05222)](https://arxiv.org/abs/2307.05222)
- [Liu et al. — LWM (arXiv:2402.08268)](https://arxiv.org/abs/2402.08268)
- [Yu et al. — MAGVIT-v2 (arXiv:2310.05737)](https://arxiv.org/abs/2310.05737)
- [Tian et al. — VAR (arXiv:2404.02905)](https://arxiv.org/abs/2404.02905)