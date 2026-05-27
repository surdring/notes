# 扩散模型——从头构建 DDPM

> Ho, Jain, Abbeel (2020) 给了这个领域一个无法放弃的配方。在一千个小步骤中用噪声摧毁数据。训练一个神经网络来预测噪声。在推理时反转该过程。今天每个主流图像、视频、3D 和音乐模型都运行在这个循环上，可能在上面叠加流匹配或一致性技巧。

**类型：** 构建
**语言：** Python
**前置要求：** 第 3 阶段 · 02（反向传播），第 8 阶段 · 02（VAE）
**时间：** 约 75 分钟

## 问题

你想要一个 `p_data(x)` 的采样器。GAN 玩一个经常发散的极小极大博弈。VAE 从高斯解码器产生模糊样本。你真正想要的训练目标是 (a) 一个单一稳定的损失（无鞍点，无极小极大），(b) `log p(x)` 的下界（所以你有似然），(c) 匹配 SOTA 质量的样本。

Sohl-Dickstein 等人（2015）有一个理论答案：定义一个逐渐添加高斯噪声的马尔可夫链 `q(x_t | x_{t-1})`，并训练反向链 `p_θ(x_{t-1} | x_t)` 去噪。Ho, Jain, Abbeel (2020) 展示了损失可以简化为一行——预测噪声——并清理了数学。2020 年这是一个奇闻。2021 年它产生了最先进的样本。2022 年它成为 Stable Diffusion。2026 年它是基板。

## 概念

![DDPM：前向噪声，反向去噪](../assets/ddpm.svg)

**前向过程 `q`。** 在 `T` 个小步骤中添加高斯噪声。闭式——数学可计算的原因——是累积步骤也是高斯的：

```
q(x_t | x_0) = N( sqrt(α̅_t) · x_0,  (1 - α̅_t) · I )
```

其中 `α̅_t = ∏_{s=1..t} (1 - β_s)`，对于 `β_t` 的调度。从 1e-4 到 0.02 线性选择 `β_t`，在 T=1000 步内，`x_T` 近似为 `N(0, I)`。

**反向过程 `p_θ`。** 学习一个神经网络 `ε_θ(x_t, t)`，预测被添加的噪声。给定 `x_t`，通过以下方式去噪：

```
x_{t-1} = (1 / sqrt(α_t)) · ( x_t - (β_t / sqrt(1 - α̅_t)) · ε_θ(x_t, t) )  +  σ_t · z
```

其中 `σ_t` 是 `sqrt(β_t)` 或学习的方差。表达式丑陋但它只是代数——给定后验 `q(x_{t-1} | x_t, x_0)` 解 `x_{t-1}` 并用其噪声预测估计替换 `x_0`。

**训练损失。**

```
L_simple = E_{x_0, t, ε} [ || ε - ε_θ( sqrt(α̅_t) · x_0 + sqrt(1 - α̅_t) · ε,  t ) ||² ]
```

从数据中采样 `x_0`，选择随机 `t`，采样 `ε ~ N(0, I)`，通过闭式一次性计算噪声 `x_t`，并对噪声进行回归。一个损失，无极小极大，无 KL，无重参数化技巧。

**采样。** 从 `x_T ~ N(0, I)` 开始。从 `t = T` 迭代反向步骤到 `1`。完成。

## 为什么有效

三个直觉：

1. **去噪容易；生成困难。** 在 `t=T`，数据是纯噪声——网络需要解决一个平凡问题。在 `t=0`，网络只需要清理几个像素。在中间 `t`，问题困难但网络有很多梯度通过相同的权重从每个噪声级别流过。

2. **伪装的分数匹配。** Vincent (2011) 证明预测噪声等价于估计 `∇_x log q(x_t | x_0)`，即*分数*。反向 SDE 使用这个分数沿密度梯度行走——向高概率区域的引导随机游走。

3. **ELBO 简化为简单 MSE。** 完整变分下界有一个每时间步的 KL 项。使用 DDPM 参数化，这些 KL 项简化为具有特定系数的噪声预测 MSE；Ho 丢弃了系数（称之为"简单"损失），质量*提高了*。

## 构建

`code/main.py` 实现一个 1-D DDPM。数据是双峰混合。"网络"是一个微型 MLP，接受 `(x_t, t)` 并输出预测噪声。训练是一行损失。采样迭代反向链。

### 步骤 1：前向调度（闭式）

```python
betas = [1e-4 + (0.02 - 1e-4) * t / (T - 1) for t in range(T)]
alphas = [1 - b for b in betas]
alpha_bars = []
cum = 1.0
for a in alphas:
    cum *= a
    alpha_bars.append(cum)
```

### 步骤 2：一次性采样 `x_t`

```python
def forward_sample(x0, t, alpha_bars, rng):
    a_bar = alpha_bars[t]
    eps = rng.gauss(0, 1)
    x_t = math.sqrt(a_bar) * x0 + math.sqrt(1 - a_bar) * eps
    return x_t, eps
```

### 步骤 3：一个训练步

```python
def train_step(x0, model, alpha_bars, rng):
    t = rng.randrange(T)
    x_t, eps = forward_sample(x0, t, alpha_bars, rng)
    eps_hat = model_forward(model, x_t, t)
    loss = (eps - eps_hat) ** 2
    return loss, gradient_step(model, ...)
```

### 步骤 4：反向采样

```python
def sample(model, alpha_bars, T, rng):
    x = rng.gauss(0, 1)
    for t in range(T - 1, -1, -1):
        eps_hat = model_forward(model, x, t)
        beta_t = 1 - alphas[t]
        x = (x - beta_t / math.sqrt(1 - alpha_bars[t]) * eps_hat) / math.sqrt(alphas[t])
        if t > 0:
            x += math.sqrt(beta_t) * rng.gauss(0, 1)
    return x
```

对于一个 1-D 问题，40 个时间步，24 单元 MLP，这在大约 200 个 epoch 内学习双峰混合。

## 时间条件

网络需要知道它正在去噪哪个时间步。两个标准选项：

- **正弦嵌入。** 类似 Transformer 位置编码。`embed(t) = [sin(t/ω_0), cos(t/ω_0), sin(t/ω_1), ...]`。通过 MLP 传递，广播到网络中。
- **FiLM / 组归一化条件。** 在每个块将嵌入投影为每通道缩放/偏置（FiLM）。

我们的玩具代码使用正弦 → 拼接。生产级 U-Net 使用 FiLM。

## 陷阱

- **调度非常重要。** 线性 `β` 是 DDPM 默认但余弦调度（Nichol & Dhariwal, 2021）在相同计算下给出更好的 FID。如果质量停滞则切换调度。
- **时间步嵌入是脆弱的。** 将原始 `t` 作为浮点数传递对玩具 1-D 有效但对图像失败；始终使用适当的嵌入。
- **V 预测 vs ε 预测。** 对于窄区间（非常小或非常大的 t），`ε` 有差的信噪比。V 预测（`v = α·ε - σ·x`）更稳定；SDXL、SD3 和 Flux 使用它。
- **无分类器引导。** 在推理时，计算条件和无条件 `ε`，然后 `ε_cfg = (1 + w) · ε_cond - w · ε_uncond`，其中 `w ≈ 3-7`。在第 08 课中涵盖。
- **1000 步太多。** 生产使用 DDIM（20-50 步）、DPM-Solver（10-20 步）或蒸馏（1-4 步）。见第 12 课。

## 使用

| 角色 | 2026 年典型技术栈 |
|------|-----------------------|
| 图像像素空间扩散（小型、玩具） | DDPM + U-Net |
| 图像潜在扩散 | VAE 编码器 + U-Net 或 DiT（第 07 课） |
| 视频潜在扩散 | 时空 DiT（Sora、Veo、WAN） |
| 音频潜在扩散 | Encodec + 扩散 Transformer |
| 科学（分子、蛋白质、物理） | 等变扩散（EDM、RFdiffusion、AlphaFold3） |

扩散是通用生成骨干。流匹配（第 13 课）是 2024-2026 年的竞争对手，通常在相同质量下的推理速度上获胜。

## 交付

保存 `outputs/skill-diffusion-trainer.md`。技能接受数据集 + 计算预算并输出：调度（线性/余弦/sigmoid）、预测目标（ε/v/x）、步数、引导尺度、采样器家族和评估协议。

## 练习

1. **简单。** 在 `code/main.py` 中将 T 从 40 改为 10。样本质量（输出的视觉直方图）如何下降？在什么 T 时双峰结构坍塌？
2. **中等。** 从 ε 预测切换到 v 预测。重新推导反向步骤。比较最终样本质量。
3. **困难。** 添加无分类器引导。条件在类标签 `c ∈ {0, 1}` 上，训练时 10% 时间丢弃它，在采样时使用 `ε = (1+w)·ε_cond - w·ε_uncond`。在 `w = 0, 1, 3, 7` 时测量条件模式命中率。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|-----------------------|
| 前向过程 | "添加噪声" | 固定的马尔可夫链 `q(x_t | x_{t-1})`，摧毁数据。 |
| 反向过程 | "去噪" | 学习链 `p_θ(x_{t-1} | x_t)`，重建数据。 |
| β 调度 | "噪声阶梯" | 每步方差；线性、余弦或 sigmoid。 |
| α̅ | "Alpha bar" | 累积乘积 `∏(1 - β)`；给出从 `x_0` 的闭式 `x_t`。 |
| 简单损失 | "噪声上的 MSE" | `||ε - ε_θ(x_t, t)||²`；所有变分推导坍缩为此。 |
| ε 预测 | "预测噪声" | 输出是添加的噪声；标准 DDPM。 |
| V 预测 | "预测速度" | 输出是 `α·ε - σ·x`；跨 t 更好的条件。 |
| DDPM | "论文" | Ho 等人 2020；线性 β，1000 步，U-Net。 |
| DDIM | "确定性采样器" | 非马尔可夫采样器，20-50 步，相同训练目标。 |
| 无分类器引导 | "CFG" | 混合条件和无条件噪声预测以放大条件化。 |

## 生产说明：扩散推理是一个步数问题

DDPM 论文运行 T=1000 反向步骤。没有人在生产中交付这个。每个真正的推理技术栈选择三种策略之一——每个策略都清晰地映射到生产框架中的"延迟来自哪里"：

1. **更快的采样器，相同模型。** DDIM（20-50 步）、DPM-Solver++（10-20）、UniPC（8-16）。反向循环的即插即用替换；训练的 `ε_θ` 权重不被触及。减少延迟 20-50 倍。
2. **蒸馏。** 训练学生模型以更少的步数匹配教师：渐进蒸馏（2 → 1）、一致性模型（任意 → 1-4）、LCM、SDXL-Turbo、SD3-Turbo。再减少延迟 5-10 倍，需要重新训练。
3. **缓存和编译。** `torch.compile(unet, mode="reduce-overhead")`、TensorRT-LLM 的扩散后端、`xformers`/SDPA 注意力、bf16 权重。每步延迟减少约 2 倍。与 (1) 和 (2) 叠加。

对于生产扩散服务器，预算对话与生产文献描述的 LLM 相同：延迟是 `num_steps × step_cost + VAE_decode`，吞吐量是 `batch_size × (num_steps × step_cost)^-1`。TTFT 小（一步）；TPOT 等效值是完整响应时间，因为从用户的角度来看图像生成是"一次性"的。

## 扩展阅读

- [Sohl-Dickstein et al. (2015). Deep Unsupervised Learning using Nonequilibrium Thermodynamics](https://arxiv.org/abs/1503.03585)——扩散论文，领先于时代。
- [Ho, Jain, Abbeel (2020). Denoising Diffusion Probabilistic Models](https://arxiv.org/abs/2006.11239)——DDPM。
- [Song, Meng, Ermon (2021). Denoising Diffusion Implicit Models](https://arxiv.org/abs/2010.02502)——DDIM，更少的步数。
- [Nichol & Dhariwal (2021). Improved DDPM](https://arxiv.org/abs/2102.09672)——余弦调度，学习方差。
- [Dhariwal & Nichol (2021). Diffusion Models Beat GANs on Image Synthesis](https://arxiv.org/abs/2105.05233)——分类器引导。
- [Ho & Salimans (2022). Classifier-Free Diffusion Guidance](https://arxiv.org/abs/2207.12598)——CFG。
- [Karras et al. (2022). Elucidating the Design Space of Diffusion-Based Generative Models (EDM)](https://arxiv.org/abs/2206.00364)——统一符号，最干净的配方。