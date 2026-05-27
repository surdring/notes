# Inpainting、Outpainting 与图像编辑

> 文本到图像创造新东西。Inpainting 修复旧东西。在生产中，70% 的可计费图像工作是编辑——替换背景、移除标志、扩展画布、重新生成一只手。Inpainting 是扩散赚钱的地方。

**类型：** 构建
**语言：** Python
**前置要求：** 第 8 阶段 · 07（潜在扩散），第 8 阶段 · 08（ControlNet & LoRA）
**时间：** 约 75 分钟

## 问题

客户发送了一张完美的产品照片，背景中有一个分散注意力的标志。你想擦除标志并保持其他一切像素级相同。你不能从头运行文本到图像——结果会有不同的颜色、不同的光照、不同的产品角度。你想*仅*重新生成被遮罩的区域，并且想让它尊重周围上下文。

这就是 inpainting。变体：

- **Inpainting。** 在遮罩内部重新生成，保持外部像素。
- **Outpainting。** 在遮罩外部（或画布之外）重新生成，保持内部。
- **图像编辑。** 重新生成整个图像但保持对原始图像的语义或结构保真度（SDEdit、InstructPix2Pix）。

2026 年的每个扩散流水线都交付 inpainting 模式。Flux.1-Fill、Stable Diffusion Inpaint、SDXL-Inpaint、DALL-E 3 Edit。它们基于相同的原理。

## 概念

![Inpainting：带上下文保留重注入的遮罩感知去噪](../assets/inpainting.svg)

### 朴素方法（以及为什么是错的）

使用遮罩运行标准文本到图像。在每个采样步骤，用前向扩散的干净图像替换非遮罩区域的噪声潜在。它有效...但效果差。边界伪影渗出，因为模型没有关于遮罩区域内是什么的信息。

### 正确的 inpainting 模型

训练一个修改后的 U-Net，接受 9 个输入通道而不是 4 个：

```
input = concat([ noisy_latent (4ch), encoded_image (4ch), mask (1ch) ], dim=channel)
```

额外通道是 VAE 编码源图像的副本加上单通道遮罩。在训练时，你随机遮罩图像区域并训练模型仅去噪遮罩区域，而非遮罩区域作为干净条件信号给出。在推理时，模型可以"看到"遮罩区域周围的内容并产生连贯的补全。

SD-Inpaint、SDXL-Inpaint、Flux-Fill 都使用这个 9 通道（或类似）输入。Diffusers 的 `StableDiffusionInpaintPipeline`、`FluxFillPipeline`。

### SDEdit（Meng et al., 2022）——自由编辑

向源图像添加噪声到某个中间 `t`，然后从 `t` 向下运行反向链到 0，使用新提示。无需重新训练。起始 `t` 的选择在保真度和创造自由之间权衡：

- `t/T = 0.3` → 几乎与源相同，小的风格变化
- `t/T = 0.6` → 中等编辑，保留粗略结构
- `t/T = 0.9` → 从接近噪声生成，最小源保留

### InstructPix2Pix（Brooks et al., 2023）

在 `(input_image, instruction, output_image)` 三元组上微调扩散模型。在推理时，条件在输入图像和文本指令（"让它日落"、"添加一条龙"）上。两个 CFG 尺度：图像尺度和文本尺度。

### RePaint（Lugmayr et al., 2022）

保持标准无条件扩散模型。在每个反向步骤，重新采样——偶尔跳回更嘈杂的状态并重新生成。避免边界伪影。在你没有训练的 inpainting 模型时使用。

## 构建

`code/main.py` 在 5 维数据上实现一个玩具 1-D inpainting 方案。我们在 5-D 混合数据上训练 DDPM，每个样本是来自两个簇之一的 5 个浮点数。在推理时，我们"遮罩" 5 维中的 2 维，在每个步骤注入非遮罩三维的前向噪声版本，仅重新生成遮罩维度。

### 步骤 1：5-D DDPM 数据

```python
def sample_data(rng):
    cluster = rng.choice([0, 1])
    center = [-1.0] * 5 if cluster == 0 else [1.0] * 5
    return [c + rng.gauss(0, 0.2) for c in center], cluster
```

### 步骤 2：在所有 5 维上训练去噪器

标准 DDPM。网络为 5-D 噪声输入输出 5-D 噪声预测。

### 步骤 3：在推理时，遮罩感知反向

```python
def inpaint_step(x_t, mask, clean_image, alpha_bars, t, rng):
    # 用干净源的新鲜噪声版本替换非遮罩维度
    a_bar = alpha_bars[t]
    for i in range(len(x_t)):
        if not mask[i]:
            x_t[i] = math.sqrt(a_bar) * clean_image[i] + math.sqrt(1 - a_bar) * rng.gauss(0, 1)
    # ...然后在 x_t 上运行正常的反向步骤
```

这是朴素方法，在玩具 1-D 数据上有效。真实图像 inpainting 使用 9 通道输入，因为纹理一致性更重要。

### 步骤 4：outpainting

Outpainting 是遮罩反转的 inpainting：遮罩新的（以前不存在的）画布，用原始填充其余部分。相同的训练目标。

## 陷阱

- **接缝。** 朴素方法留下可见边界，因为梯度信息不跨越遮罩流动。修复：将遮罩扩张 8-16 像素，或使用适当的 inpainting 模型。
- **遮罩泄漏。** 如果条件图像的非遮罩区域是低质量或嘈杂的，它污染遮罩内的生成。略微去噪或模糊。
- **CFG 与遮罩大小相互作用。** 小遮罩上的高 CFG = 饱和补丁。对小编辑降低 CFG。
- **SDEdit 保真度悬崖。** 从 `t/T = 0.5` 到 `t/T = 0.6` 可能丢失主体的身份。扫描并检查点。
- **提示不匹配。** 提示应描述*整个*图像，而不仅仅是新内容。"一只猫坐在椅子上"而不是"一只猫"。

## 使用

| 任务 | 流水线 |
|------|----------|
| 移除物体，小遮罩 | SD-Inpaint 或 Flux-Fill，标准提示 |
| 替换天空 | SD-Inpaint + "日落时的蓝天" |
| 扩展画布 | SDXL outpaint 模式（8px 羽化）或带 outpaint 遮罩的 Flux-Fill |
| 重新生成手 / 脸 | SD-Inpaint 带重新描述主体的提示 + ControlNet-Openpose |
| 改变一个区域的风格 | 在遮罩区域上以 `t/T=0.5` 的 SDEdit |
| "让它日落" | InstructPix2Pix 或 Flux-Kontext |
| 背景替换 | SAM 遮罩 → SD-Inpaint |
| 超高保真度 | Flux-Fill 或 GPT-Image（托管）用于最难的情况 |

SAM（Meta 的 Segment Anything，2023）+ 扩散 inpainting 是 2026 年背景移除流水线。SAM 2（2024）在视频上工作。

## 交付

保存 `outputs/skill-editing-pipeline.md`。技能接受原始图像 + 编辑描述 + 可选遮罩（或 SAM 提示）并输出：遮罩生成方法、基础模型、CFG 尺度（图像 + 文本）、SDEdit-t 或 inpainting 模式，以及质量检查清单。

## 练习

1. **简单。** 在 `code/main.py` 中，将遮罩维度的比例从 0.2 变到 0.8。在什么比例时 inpainting 质量（遮罩维度的残差）等于无条件生成？
2. **中等。** 实现 RePaint：在每 10 个反向步骤，跳回 5 步（添加噪声）并重新去噪。测量它是否减少遮罩边缘的边界残差。
3. **困难。** 使用 Hugging Face diffusers 比较：SD 1.5 Inpaint + ControlNet-Openpose vs Flux.1-Fill 在 20 个面部重新生成任务上。分别对姿态遵循和身份保留打分。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|-----------------------|
| Inpainting | "填补空洞" | 在遮罩内重新生成；保持外部像素。 |
| Outpainting | "扩展画布" | 在画布外重新生成；保持内部。 |
| 9 通道 U-Net | "适当的 inpainting 模型" | U-Net 以 `noisy | encoded-source | mask` 作为输入。 |
| SDEdit | "带噪声级别的 Img2img" | 加噪到时间 `t`，用新提示去噪。 |
| InstructPix2Pix | "仅文本编辑" | 在（图像、指令、输出）三元组上微调扩散。 |
| RePaint | "无重训练" | 反向期间定期重新加噪以减少接缝。 |
| SAM | "分割一切" | 通过点击或框的遮罩生成器；与 inpainting 配对。 |
| Flux-Kontext | "带上下文编辑" | Flux 变体，接受参考图像 + 编辑指令。 |

## 生产说明：编辑流水线对延迟敏感

编辑图像的用户期望低于 5 秒的往返。在 L4 上 1024² 的 30 步 SDXL-Inpaint 是 3-4 秒，加上 SAM 遮罩生成（约 200 毫秒）和 VAE 编码/解码（一起约 500 毫秒）。在生产框架中，这是 TTFT 受限而非吞吐量受限——批次 1，低并发，最小化每个阶段：

- **SAM-H 是慢的那个。** 1024² 的 SAM-H 约 200 毫秒；SAM-ViT-B 约 40 毫秒，有小的质量损失。SAM 2（视频）增加时间开销；不要用它进行单图像编辑。
- **尽可能跳过编码。** `pipe.image_processor.preprocess(img)` 编码为潜在。如果你有上次生成的潜在（迭代编辑 UI 中典型），通过 `latents=...` 直接传递以跳过一次 VAE 编码。
- **遮罩扩张对吞吐量也很重要。** 小遮罩意味着 U-Net 前向传播的大部分被浪费（非遮罩像素无论如何被夹紧）。`diffusers` 的 `StableDiffusionInpaintPipeline` 无论如何运行完整 U-Net；只有 9 通道 proper-inpaint 变体利用遮罩计算。
- **Flux-Kontext 是 2025 年的答案。** 在 `(source_image, instruction)` 上的单次前向传播——无单独遮罩，无 SDEdit 噪声扫描。在 H100 上约 1.5 秒交付编辑。架构教训：折叠阶段。

## 扩展阅读

- [Lugmayr et al. (2022). RePaint: Inpainting using Denoising Diffusion Probabilistic Models](https://arxiv.org/abs/2201.09865)——无训练 inpainting。
- [Meng et al. (2022). SDEdit: Guided Image Synthesis and Editing with Stochastic Differential Equations](https://arxiv.org/abs/2108.01073)——SDEdit。
- [Brooks, Holynski, Efros (2023). InstructPix2Pix](https://arxiv.org/abs/2211.09800)——文本指令编辑。
- [Kirillov et al. (2023). Segment Anything](https://arxiv.org/abs/2304.02643)——SAM，遮罩源。
- [Ravi et al. (2024). SAM 2: Segment Anything in Images and Videos](https://arxiv.org/abs/2408.00714)——视频 SAM。
- [Hertz et al. (2022). Prompt-to-Prompt Image Editing with Cross-Attention Control](https://arxiv.org/abs/2208.01626)——注意力级编辑。
- [Black Forest Labs (2024). Flux.1-Fill and Flux.1-Kontext](https://blackforestlabs.ai/flux-1-tools/)——2024 工具。