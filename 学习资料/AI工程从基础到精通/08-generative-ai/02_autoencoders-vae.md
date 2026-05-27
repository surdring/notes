# 自编码器与变分自编码器（VAE）

> 普通的自编码器先压缩再重建。它记住。它不生成。加一个技巧——强制编码看起来像高斯分布——你就得到了一个采样器。那个单一技巧，`z = μ + σ·ε` 的重参数化，是为什么你在 2026 年使用的每个潜在扩散和流匹配图像模型在输入端都有一个 VAE。

**类型：** 构建
**语言：** Python
**前置要求：** 第 3 阶段 · 02（反向传播），第 3 阶段 · 07（CNN），第 8 阶段 · 01（分类学）
**时间：** 约 75 分钟

## 问题

将一个 784 像素的 MNIST 数字压缩为 16 个数字的编码，然后重建。普通的自编码器会在重建 MSE 上表现完美，但编码空间是一团乱麻。在编码空间中随机选一个点，解码它，你会得到噪声。它没有采样器。它是一个伪装成生成模型的压缩模型。

你实际想要的是：(a) 编码空间是一个你可以采样的干净、平滑分布——比如各向同性高斯 `N(0, I)`，(b) 解码任何样本产生一个可信的数字，(c) 编码器和解码器仍然压缩良好。三个目标，一个架构，一个损失。

Kingma 2013 年的 VAE 通过训练编码器输出一个*分布* `q(z|x) = N(μ(x), σ(x)²)`，通过 KL 惩罚将该分布拉向先验 `N(0, I)`，然后在解码前从 `q(z|x)` 采样 `z` 来解决这个问题。在推理时，丢弃编码器，采样 `z ~ N(0, I)`，解码。KL 惩罚是强制编码空间结构化的原因。

2026 年 VAE 很少单独使用——它们在原始图像质量上已被扩散超越——但它们是每个潜在扩散模型（SD 1/2/XL/3、Flux、AudioCraft）的首选编码器。学习 VAE 就是学习你使用的每个图像管道的不可见的第一层。

## 概念

![自编码器 vs VAE：重参数化技巧](../assets/vae.svg)

**自编码器。** `z = encoder(x)`，`x̂ = decoder(z)`，损失 = `||x - x̂||²`。编码空间非结构化。

**VAE 编码器。** 输出两个向量：`μ(x)` 和 `log σ²(x)`。这些定义 `q(z|x) = N(μ, diag(σ²))`。

**重参数化技巧。** 从 `q(z|x)` 采样不可微。将样本重写为 `z = μ + σ·ε`，其中 `ε ~ N(0, I)`。现在 `z` 是 `(μ, σ)` 的确定性函数加上一个非参数噪声——梯度流经 `μ` 和 `σ`。

**损失。** 证据下界（ELBO），两项：

```
loss = reconstruction + β · KL[q(z|x) || N(0, I)]
     = ||x - x̂||²  + β · Σ_i ( σ_i² + μ_i² - log σ_i² - 1 ) / 2
```

重建将 `x̂` 推向 `x`。KL 将 `q(z|x)` 推向先验。它们互相权衡。小的 β (<1) = 更清晰的样本，编码空间不那么高斯。大的 β (>1) = 更干净的编码空间，更模糊的样本。β-VAE（Higgins 2017）使这个旋钮出名并引发了分离表示研究。

**采样。** 在推理时：抽取 `z ~ N(0, I)`，通过解码器前向传播。一次前向传播——不像扩散那样迭代采样。

## 构建

`code/main.py` 在不使用 numpy 或 torch 的情况下实现了一个微型 VAE。输入是从 8-D 二分量高斯混合中抽取的 8 维合成数据。编码器和解码器是单隐藏层 MLP。我们实现 tanh 激活、前向传播、损失和手写反向传播。不是生产级——是教学。

### 步骤 1：编码器前向传播

```python
def encode(x, enc):
    h = tanh(add(matmul(enc["W1"], x), enc["b1"]))
    mu = add(matmul(enc["W_mu"], h), enc["b_mu"])
    log_sigma2 = add(matmul(enc["W_sig"], h), enc["b_sig"])
    return mu, log_sigma2
```

用 `log σ²` 而不是 `σ`，这样网络输出没有约束（σ 的 softplus 是个陷阱——在 σ ≈ 0 时梯度消失）。

### 步骤 2：重参数化并解码

```python
def reparameterize(mu, log_sigma2, rng):
    eps = [rng.gauss(0, 1) for _ in mu]
    sigma = [math.exp(0.5 * lv) for lv in log_sigma2]
    return [m + s * e for m, s, e in zip(mu, sigma, eps)]

def decode(z, dec):
    h = tanh(add(matmul(dec["W1"], z), dec["b1"]))
    return add(matmul(dec["W_out"], h), dec["b_out"])
```

### 步骤 3：ELBO

```python
def elbo(x, x_hat, mu, log_sigma2, beta=1.0):
    recon = sum((a - b) ** 2 for a, b in zip(x, x_hat))
    kl = 0.5 * sum(math.exp(lv) + m * m - lv - 1 for m, lv in zip(mu, log_sigma2))
    return recon + beta * kl, recon, kl
```

精确闭式 KL 因为两个分布都是高斯分布。不要数值积分。到 2026 年人们仍然发布带有蒙特卡洛 KL 估计的代码——它慢 3 倍毫无理由。

### 步骤 4：生成

```python
def sample(dec, z_dim, rng):
    z = [rng.gauss(0, 1) for _ in range(z_dim)]
    return decode(z, dec)
```

这就是生成模型。五行代码。

## 陷阱

- **后验坍塌。** KL 项如此激进地将 `q(z|x) → N(0, I)` 驱动以至于 `z` 不携带关于 `x` 的信息。修复：β 退火（从 β=0 开始，逐渐增加到 1）、free bits，或在非活跃维度上跳过 KL。
- **模糊样本。** 高斯解码器似然意味着 MSE 重建，这是 L2 的贝叶斯最优（均值）——一组合理数字的均值是一个模糊数字。修复：离散解码器（VQ-VAE、NVAE），或仅将 VAE 用作编码器并在潜在上叠加扩散（这就是 Stable Diffusion 所做的）。
- **β 太大、太早。** 见后验坍塌。从 β≈0.01 开始并逐渐增加。
- **潜在维度太小。** 16-D 适用于 MNIST，256-D 适用于 ImageNet 256²，2048-D 适用于 ImageNet 1024²。Stable Diffusion 的 VAE 将 512×512×3 → 64×64×4 压缩（空间面积 32 倍下采样，通道数 32 倍）。

## 使用

2026 年 VAE 技术栈：

| 场景 | 选择 |
|-----------|------|
| 扩散模型的图像潜在编码器 | Stable Diffusion VAE (`sd-vae-ft-ema`) 或 Flux VAE |
| 音频潜在编码器 | Encodec (Meta)、SoundStream 或 DAC (Descript) |
| 视频潜在 | Sora 的时空补丁、Latte VAE、WAN VAE |
| 分离表示学习 | β-VAE、FactorVAE、TCVAE |
| 离散潜在（用于 transformer 建模） | VQ-VAE、RVQ (ResidualVQ) |
| 用于生成的连续潜在 | 普通 VAE，然后在潜在空间中条件流/扩散模型 |

潜在扩散模型是一个 VAE，在编码器和解码器之间居住着一个扩散模型。VAE 进行粗压缩，扩散模型承担繁重工作。视频（VAE + 视频扩散 DiT）和音频（Encodec + MusicGen transformer）的模式相同。

## 交付

保存 `outputs/skill-vae-trainer.md`。

技能接受：数据集概要 + 潜在维度目标 + 下游用途（重建、采样或潜在扩散输入）并输出：架构选择（普通/β/VQ/RVQ）、β 调度、潜在维度、解码器似然（高斯 vs 分类），以及评估计划（重建 MSE、每维 KL、`q(z|x)` 和 `N(0, I)` 之间的 Fréchet 距离）。

## 练习

1. **简单。** 在 `code/main.py` 中将 `β` 改为 `0.01`、`0.1`、`1.0`、`5.0`。记录最终重建 MSE 和 KL。对于你的合成数据，哪个 β 是帕累托最优的？
2. **中等。** 用伯努利似然（交叉熵损失）替换高斯解码器似然。在相同合成数据的二值化版本上比较样本质量。
3. **困难。** 将 `code/main.py` 扩展为迷你 VQ-VAE：用 K=32 个条目的码本中的最近邻查找替换连续 `z`。比较重建 MSE 并报告有多少码本条项被使用（码本坍塌是真实的）。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|-----------------------|
| 自编码器 | 编码-解码网络 | `x → z → x̂`，学习 MSE。不可生成。 |
| VAE | 带采样器的 AE | 编码器输出一个分布，KL 惩罚塑造编码空间。 |
| ELBO | 证据下界 | `log p(x) ≥ recon - KL[q(z|x) || p(z)]`；当 `q = p(z|x)` 时紧密。 |
| 重参数化 | `z = μ + σ·ε` | 将随机节点重写为确定性 + 纯噪声。通过采样启用反向传播。 |
| 先验 | `p(z)` | 潜在的目标分布，通常是 `N(0, I)`。 |
| 后验坍塌 | "KL 项赢了" | 编码器忽略 `x`，输出先验；解码器必须幻觉。 |
| β-VAE | 可调 KL 权重 | `loss = recon + β·KL`。更高的 β = 更分离但更模糊。 |
| VQ-VAE | 离散潜在 | 用最近码本向量替换连续 `z`；启用 transformer 建模。 |

## 生产说明：VAE 是扩散服务器中最热的路径

在 Stable Diffusion / Flux / SD3 流水线中，VAE 每个请求调用两次——一次编码（如果做 img2img / inpainting），一次解码。在 1024² 分辨率下，解码器前向传播通常是整个流水线中最大的单次激活内存峰值，因为它将 `128×128×16` 的潜在上采样回 `1024×1024×3`。两个实际后果：

- **切片或平铺解码。** `diffusers` 暴露 `pipe.vae.enable_slicing()` 和 `pipe.vae.enable_tiling()`。平铺用 `O(tile²)` 的内存换来小的接缝伪影，而不是 `O(H·W)`。对于消费级 GPU 上的 1024²+ 至关重要。
- **bf16 解码器，最终缩放的 fp32 数值。** SD 1.x VAE 以 fp32 发布，在 1024²+ 转换为 fp16 时会*静默产生 NaN*。SDXL 发布 `madebyollin/sdxl-vae-fp16-fix`——始终优先使用 fp16-fix 变体或使用 bf16。

## 扩展阅读

- [Kingma & Welling (2013). Auto-Encoding Variational Bayes](https://arxiv.org/abs/1312.6114)——VAE 论文。
- [Higgins et al. (2017). β-VAE: Learning Basic Visual Concepts with a Constrained Variational Framework](https://openreview.net/forum?id=Sy2fzU9gl)——解耦 β-VAE。
- [van den Oord et al. (2017). Neural Discrete Representation Learning](https://arxiv.org/abs/1711.00937)——VQ-VAE。
- [Vahdat & Kautz (2021). NVAE: A Deep Hierarchical Variational Autoencoder](https://arxiv.org/abs/2007.03898)——最先进图像 VAE。
- [Rombach et al. (2022). High-Resolution Image Synthesis with Latent Diffusion Models](https://arxiv.org/abs/2112.10752)——Stable Diffusion；VAE 作为编码器。
- [Défossez et al. (2022). High Fidelity Neural Audio Compression](https://arxiv.org/abs/2210.13438)——Encodec，音频 VAE 标准。