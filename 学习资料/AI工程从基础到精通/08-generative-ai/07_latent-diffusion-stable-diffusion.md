# 潜在扩散与 Stable Diffusion

> 在 512×512 图像上的像素空间扩散是计算战争罪。Rombach 等人（2022）注意到你不需要全部 786k 维度来生成图像——你需要足够捕获语义结构的维度，以及一个单独的解码器用于其余部分。在 VAE 的潜在空间内运行扩散。那一个想法就是 Stable Diffusion。

**类型：** 构建
**语言：** Python
**前置要求：** 第 8 阶段 · 02（VAE），第 8 阶段 · 06（DDPM），第 7 阶段 · 09（ViT）
**时间：** 约 75 分钟

## 问题

512² 上的像素空间扩散意味着 U-Net 在形状为 `[B, 3, 512, 512]` 的张量上运行。每个采样步骤对于一个 500M 参数的 U-Net 约 100 GFLOPS。五十步是每张图像 5 TFLOPS。在十亿张图像上训练，计算账单是荒谬的。

这些 FLOPs 中的大多数用于通过感知上不重要的细节推动网络——一个有损 VAE 可以压缩掉的高频纹理。Rombach 的想法：训练一次 VAE（*第一阶段*），冻结它，并完全在 4 通道 64×64 潜在空间（*第二阶段*）中运行扩散。相同的 U-Net。1/16 的像素。~64 倍更少的 FLOPs 获得可比的质量。

这就是 Stable Diffusion 配方。SD 1.x / 2.x 使用 860M U-Net 在 `64×64×4` 潜在上，SDXL 使用 2.6B U-Net 在 `128×128×4` 上，SD3 用带有流匹配的扩散 Transformer（DiT）替换 U-Net。Flux.1-dev（Black Forest Labs, 2024）交付一个 12B 参数的 DiT-MMDiT。所有这些都运行在相同的两阶段基板上。

## 概念

![潜在扩散：VAE 压缩 + 潜在空间中的扩散](../assets/latent-diffusion.svg)

**两阶段，分别训练。**

1. **阶段 1 — VAE。** 编码器 `E(x) → z`，解码器 `D(z) → x`。目标压缩：每个空间轴 8× 下采样 + 调整通道使总潜在大小约为像素数的 1/16。损失 = 重建（L1 + LPIPS 感知）+ KL（小权重所以 `z` 不被强迫太高斯，因为我们不需要从 `z` 精确采样）。通常用对抗损失训练，使解码图像清晰。

2. **阶段 2 — 在 `z` 上的扩散。** 将 `z = E(x_real)` 视为数据。训练一个 U-Net（或 DiT）去噪 `z_t`。在推理时：通过扩散采样 `z_0`，然后 `x = D(z_0)`。

**文本条件。** 两个额外组件。一个冻结的文本编码器（SD 1.x 的 CLIP-L，SD 2/XL 的 CLIP-L+OpenCLIP-G，SD3 和 Flux 的 T5-XXL）。交叉注意力注入：每个 U-Net 块取 `[Q = 图像特征, K = V = 文本标记]` 并混合它们。标记是文本影响图像的唯一方式。

**损失函数与第 06 课相同。** 在噪声上相同的 DDPM / 流匹配 MSE。你只是交换了数据域。

## 架构变体

| 模型 | 年份 | 骨干 | 潜在形状 | 文本编码器 | 参数 |
|-------|------|----------|--------------|--------------|--------|
| SD 1.5 | 2022 | U-Net | 64×64×4 | CLIP-L（77 标记） | 860M |
| SD 2.1 | 2022 | U-Net | 64×64×4 | OpenCLIP-H | 865M |
| SDXL | 2023 | U-Net + 精炼器 | 128×128×4 | CLIP-L + OpenCLIP-G | 2.6B + 6.6B |
| SDXL-Turbo | 2023 | 蒸馏 | 128×128×4 | 相同 | 1-4 步采样 |
| SD3 | 2024 | MMDiT（多模态 DiT） | 128×128×16 | T5-XXL + CLIP-L + CLIP-G | 2B / 8B |
| Flux.1-dev | 2024 | MMDiT | 128×128×16 | T5-XXL + CLIP-L | 12B |
| Flux.1-schnell | 2024 | MMDiT 蒸馏 | 128×128×16 | T5-XXL + CLIP-L | 12B，1-4 步 |

趋势：用 DiT（在潜在补丁上的 transformer）替换 U-Net，扩展文本编码器（T5 在提示遵循上击败 CLIP），增加潜在通道（4 → 16 给出更多细节余量）。

## 构建

`code/main.py` 在第 06 课的 DDPM 之上堆叠一个玩具 1-D "VAE"（恒等编码器 + 解码器，用于演示；真正的 VAE 将是卷积网络），并添加带无分类器引导的类条件。它表明无论你在原始 1-D 值还是编码值上运行，相同的扩散损失都有效——这是关键见解。

### 步骤 1：编码器/解码器

```python
def encode(x):    return x * 0.5          # 玩具"压缩"到更小的尺度
def decode(z):    return z * 2.0
```

真正的 VAE 有训练的权重。为了教学，这个线性映射足以表明扩散在 `z` 上运行而不关心原始数据空间。

### 步骤 2：`z` 空间中的扩散

与第 06 课相同的 DDPM。网络看到的数据是 `z = E(x)`。采样 `z_0` 后，用 `D(z_0)` 解码。

### 步骤 3：无分类器引导

在训练时，10% 时间丢弃类标签（用空标记替换）。在推理时，计算 `ε_cond` 和 `ε_uncond`，然后：

```python
eps_cfg = (1 + w) * eps_cond - w * eps_uncond
```

`w = 0` = 无引导（完全多样性），`w = 3` = 默认，`w = 7+` = 饱和 / 过清晰。

### 步骤 4：文本条件（概念，非代码）

用冻结文本编码器输出替换类标签。通过交叉注意力将文本嵌入馈送到 U-Net：

```python
h = h + CrossAttention(Q=h, K=text_embed, V=text_embed)
```

这是类条件扩散模型和 Stable Diffusion 之间唯一的实质性区别。

## 陷阱

- **VAE 尺度不匹配。** SD 1.x VAE 有一个缩放常数（`scaling_factor ≈ 0.18215`）在编码后应用。忘记这会使 U-Net 在方差严重错误的潜在上训练。每个检查点都附带一个。
- **文本编码器静默错误。** SD3 需要 T5-XXL 且 ≥128 标记，回退到仅 CLIP 是有损的。始终检查 `use_t5=True` 或提示保真度会崩溃。
- **混合潜在空间。** SDXL、SD3、Flux 都使用不同的 VAE。在 SDXL 潜在上训练的 LoRA 不会在 SD3 上工作。Hugging Face diffusers 0.30+ 拒绝加载不匹配的检查点。
- **CFG 太高。** `w > 10` 产生饱和、油腻的图像，以多样性为代价过度拟合提示。最佳点是 `w = 3-7`。
- **负提示泄漏。** 空负提示成为空标记；填充的负提示成为 `ε_uncond`。这些不一样；某些管道静默默认使用空标记。

## 使用

2026 年生产技术栈：

| 目标 | 推荐骨干 |
|--------|----------------------|
| 窄域，配对数据，从头训练模型 | SDXL 微调（LoRA / 完整）——最快交付 |
| 开放域文本到图像，开放权重 | Flux.1-dev（12B，Apache / 非商业）或 SD3.5-Large |
| 最快推理，开放权重 | Flux.1-schnell（1-4 步，Apache）或 SDXL-Lightning |
| 最佳提示遵循，托管 | GPT-Image / DALL-E 3（仍然），Midjourney v7，Imagen 4 |
| 编辑工作流 | Flux.1-Kontext（2024 年 12 月）——原生接受图像 + 文本 |
| 研究，基线 | SD 1.5——古老但研究充分 |

## 交付

保存 `outputs/skill-sd-prompter.md`。技能接受文本提示 + 目标风格并输出：模型 + 检查点、CFG 尺度、采样器、负提示、分辨率、可选的 ControlNet/IP-Adapter 组合，以及每步质量检查清单。

## 练习

1. **简单。** 运行 `code/main.py`，引导 `w ∈ {0, 1, 3, 7, 15}`。记录每类均值样本。在什么 `w` 时类均值发散超过真实数据均值？
2. **中等。** 将玩具线性编码器交换为带重建损失的 tanh-MLP 编码器/解码器对。在新潜在上重新训练扩散。样本质量是否改变？
3. **困难。** 使用 diffusers 设置真正的 Stable Diffusion 推理：加载 `sdxl-base`，以 CFG=7 运行 30 个 Euler 步骤，计时。现在以 4 步和 CFG=0 切换到 `sdxl-turbo`。相同的主题，不同的质量——描述什么改变了以及为什么。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|-----------------------|
| 第一阶段 | "VAE" | 训练的编码器/解码器对；将 512² 压缩到 64²。 |
| 第二阶段 | "U-Net" | 潜在空间上的扩散模型。 |
| CFG | "引导尺度" | `(1+w)·ε_cond - w·ε_uncond`；调优条件强度。 |
| 空标记 | "空提示嵌入" | 用于 `ε_uncond` 的无条件嵌入。 |
| 交叉注意力 | "文本如何进入" | 每个 U-Net 块将文本标记作为 K 和 V 进行注意力。 |
| DiT | "扩散 Transformer" | 用潜在补丁上的 transformer 替换 U-Net；更好地缩放。 |
| MMDiT | "多模态 DiT" | SD3 的架构：文本和图像流带联合注意力。 |
| VAE 缩放因子 | "幻数" | 将潜在除以约 5.4，使扩散在单位方差空间中运行。 |

## 生产说明：在 8GB 消费级 GPU 上运行 Flux-12B

参考 Flux 集成是经典的"我有消费级 GPU，能交付这个吗？"配方。诀窍是生产推理文献中列出的相同三旋钮配方应用于扩散 DiT：

1. **交错加载。** Flux 有三个从不需要同时在 VRAM 中共存的网络：T5-XXL 文本编码器（fp32 约 10 GB）、CLIP-L（小）、12B MMDiT 和 VAE。先编码提示，*删除*编码器，加载 DiT，去噪，*删除* DiT，加载 VAE，解码。消费级 8GB GPU 一次只能容纳一个阶段。
2. **通过 bitsandbytes 进行 4 位量化。** `BitsAndBytesConfig(load_in_4bit=True, bnb_4bit_compute_dtype=torch.bfloat16)` 在 T5 编码器和 DiT 上。减少内存 8 倍，文本到图像的质量下降不可察觉，根据 Aritra 的基准（链接在 notebook 中）。
3. **CPU 卸载。** `pipe.enable_model_cpu_offload()` 在每次前向传播推进时自动在 CPU 和 GPU 之间交换模块。增加 10-20% 延迟但使管道能够运行。

内存核算：`10 GB T5 / 8 = 1.25 GB` 量化，`12 B 参数 × 0.5 字节 = ~6 GB` 量化 DiT，加上激活。用 stas00 的术语来说这是 TP=1 推理的极端端——无模型并行，最大量化。对于生产，你会在 H100 上运行 TP=2 或 TP=4；对于单个开发笔记本，这是配方。

## 扩展阅读

- [Rombach et al. (2022). High-Resolution Image Synthesis with Latent Diffusion Models](https://arxiv.org/abs/2112.10752)——Stable Diffusion。
- [Podell et al. (2023). SDXL: Improving Latent Diffusion Models for High-Resolution Image Synthesis](https://arxiv.org/abs/2307.01952)——SDXL。
- [Peebles & Xie (2023). Scalable Diffusion Models with Transformers (DiT)](https://arxiv.org/abs/2212.09748)——DiT。
- [Esser et al. (2024). Scaling Rectified Flow Transformers for High-Resolution Image Synthesis](https://arxiv.org/abs/2403.03206)——SD3，MMDiT。
- [Ho & Salimans (2022). Classifier-Free Diffusion Guidance](https://arxiv.org/abs/2207.12598)——CFG。
- [Labs (2024). Flux.1 — Black Forest Labs announcement](https://blackforestlabs.ai/announcing-black-forest-labs/)——Flux.1 家族。
- [Hugging Face Diffusers 文档](https://huggingface.co/docs/diffusers/index)——以上每个检查点的参考实现。