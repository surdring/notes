# 流匹配与整流流

> 扩散模型需要 20-50 个采样步骤，因为它们从噪声走到数据的路径是弯曲的。流匹配（Lipman et al., 2023）和整流流（Liu et al., 2022）训练直线路径。更直的路径意味着更少的步骤意味着更快的推理。Stable Diffusion 3、Flux.1 和 AudioCraft 2 都在 2024 年转向了流匹配。

**类型：** 构建
**语言：** Python
**前置要求：** 第 8 阶段 · 06（DDPM），第 1 阶段 · 微积分
**时间：** 约 45 分钟

## 问题

DDPM 的反向过程是从 `N(0, I)` 回到数据分布的 1000 步随机游走。DDIM 将其压缩为 20-50 个确定性步骤。你想要更少的步骤——理想情况下一步。阻碍是求解反向过程的 ODE 是刚性的；路径是弯曲的。

如果你能训练模型使得从噪声到数据的路径是*直线*，从 `t=1` 到 `t=0` 的单步 Euler 就可以工作。流匹配直接构建这一点：定义从 `x_1 ∼ N(0, I)` 到 `x_0 ∼ data` 的直线插值，训练向量场 `v_θ(x, t)` 匹配其时间导数，在推理时积分。

整流流（Liu 2022）更进一步：用重流过程迭代拉直路径，产生渐进更接近线性的 ODE。两次重流迭代后，2 步采样器匹配 50 步 DDPM 质量。

## 概念

![流匹配：噪声和数据之间的直线插值](../assets/flow-matching.svg)

### 直线流

定义：

```
x_t = t · x_1 + (1 - t) · x_0,   t ∈ [0, 1]
```

其中 `x_0 ~ data`，`x_1 ~ N(0, I)`。沿这条直线的时间导数是常数：

```
dx_t / dt = x_1 - x_0
```

定义神经向量场 `v_θ(x_t, t)` 并训练它匹配这个导数：

```
L = E_{x_0, x_1, t} || v_θ(x_t, t) - (x_1 - x_0) ||²
```

这是**条件流匹配**损失（Lipman 2023）。训练是无模拟的：你永远不展开 ODE。只需采样 `(x_0, x_1, t)` 并回归。

### 采样

在推理时，在时间上*反向*积分学到的向量场：

```
x_{t-Δt} = x_t - Δt · v_θ(x_t, t)
```

从 `x_1 ~ N(0, I)` 开始，Euler 步降到 `t=0`。

### 整流流（Liu 2022）

直线流可行但学到的路径*实际上不直*——它们弯曲因为多个 `x_0` 可以映射到同一个 `x_1`。整流流的重流步骤：

1. 用随机配对训练流模型 v_1。
2. 通过从 `x_1` 积分 v_1 到其落点 `x_0` 采样 N 对 `(x_1, x_0)`。
3. 在这些配对示例上训练 v_2。因为配对现在是"ODE 匹配的"，它们之间的直线插值确实更平坦。
4. 重复。

实践中 2 次重流迭代让你接近线性，实现 2-4 步推理。SDXL-Turbo、SD3-Turbo、LCM 都是蒸馏自流匹配模型。

### 为什么这在 2024 年对图像获胜

三个原因：

1. **无模拟训练**——训练期间无 ODE 展开，实现简单。
2. **更好的损失几何**——直线路径具有一致的信噪比，而 DDPM 的 ε 损失在调度边缘 SNR 差。
3. **更快推理**——SDXL-Turbo 质量下 4-8 步；一致性蒸馏下 1 步。

## 流匹配 vs DDPM——精确联系

带高斯条件路径的流匹配是*具有特定噪声调度的*扩散。选择 `x_t = α(t) x_0 + σ(t) x_1` 调度，流匹配恢复 Stratonovich 重表述的扩散，其中 `v = α'·x_0 - σ'·x_1`。两者对高斯路径代数等价。

流匹配增加的是：目标的*清晰性*（平凡速度）、更干净的损失，以及实验非高斯插值的自由度。

## 构建

`code/main.py` 在双峰高斯混合上实现 1-D 流匹配。向量场 `v_θ(x, t)` 是用直线目标训练的微型 MLP。在推理时，积分 1、2、4 和 20 个 Euler 步并比较样本质量。

### 步骤 1：训练损失

```python
def train_step(x0, net, rng, lr):
    x1 = rng.gauss(0, 1)
    t = rng.random()
    x_t = t * x1 + (1 - t) * x0
    target = x1 - x0
    pred = net_forward(x_t, t)
    loss = (pred - target) ** 2
    # 反向传播 + 更新
```

### 步骤 2：多步推理

```python
def sample(net, num_steps):
    x = rng.gauss(0, 1)
    for i in range(num_steps):
        t = 1.0 - i / num_steps
        dt = 1.0 / num_steps
        x -= dt * net_forward(x, t)
    return x
```

### 步骤 3：比较步数

期望 4 步采样器已经匹配 20 步质量——对延迟很重要。

## 陷阱

- **时间参数化。** 流匹配使用 `t ∈ [0, 1]`，`t=0` 在数据，`t=1` 在噪声。DDPM 使用 `t ∈ [0, T]`，`t=0` 在数据，`t=T` 在噪声。方向相同，尺度不同。论文经常搞错这点。
- **调度选择。** 整流流的直线是"那个"流匹配调度，但你可以使用余弦或 logit-正态 t 采样（SD3 这样做）以获得更好的尺度覆盖。
- **重流成本。** 为重流生成配对数据集是每个样本一次完整的推理传递。只有当你真的需要 1-2 步推理时才做重流。
- **无分类器引导仍然适用。** 只需在线性组合中将 ε 换为 v：`v_cfg = (1+w) v_cond - w v_uncond`。

## 使用

| 用例 | 2026 年技术栈 |
|----------|-----------|
| 文本到图像，最佳质量 | 流匹配：SD3、Flux.1-dev |
| 文本到图像，1-4 步 | 蒸馏流匹配：Flux.1-schnell、SD3-Turbo、SDXL-Turbo |
| 实时推理 | 从流匹配基模型的一致性蒸馏（LCM、PCM） |
| 音频生成 | 流匹配：Stable Audio 2.5、AudioCraft 2 |
| 视频生成 | 流匹配与扩散混合（Sora、Veo、Stable Video） |
| 科学 / 物理（粒子轨迹、分子） | 流匹配 + 等变向量场 |

每当 2025-2026 年一篇论文说"比扩散更快"，几乎总是流匹配 + 蒸馏。

## 交付

保存 `outputs/skill-fm-tuner.md`。技能接受扩散风格模型规格并将其转换为流匹配训练配置：调度选择、时间采样分布（均匀 / logit-正态）、优化器、重流计划、目标步数、评估协议。

## 练习

1. **简单。** 运行 `code/main.py` 并比较 1 步 vs 20 步 MSE 与真实数据分布。
2. **中等。** 从均匀 `t` 采样切换到 logit-正态（将采样集中在中间 t）。模型质量是否提高？
3. **困难。** 实现一次重流迭代：通过积分第一个模型生成配对的 (x_0, x_1)，在配对数据上训练第二个模型，比较 1 步样本质量。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|-----------------------|
| 流匹配 | "直线扩散" | 训练 `v_θ(x, t)` 沿插值匹配 `x_1 - x_0`。 |
| 整流流 | "重流" | 拉直学习流的迭代过程。 |
| 速度场 | "v_θ" | 模型输出——移动 `x_t` 的方向。 |
| 直线插值 | "路径" | `x_t = (1-t)·x_0 + t·x_1`；平凡目标导数。 |
| Euler 采样器 | "一阶 ODE 求解器" | 最简单的积分器；当路径直时工作良好。 |
| Logit-正态 t | "SD3 采样" | 将 `t` 采样集中到梯度最强的中间值。 |
| 一致性蒸馏 | "1 步采样器" | 训练学生将任意 `x_t` 直接映射到 `x_0`。 |
| 带速度的 CFG | "v-CFG" | `v_cfg = (1+w) v_cond - w v_uncond`；同样技巧，新变量。 |

## 生产说明：Flux.1-schnell 是最快的流匹配

流匹配的生产胜利是 Flux.1-schnell——一个流匹配的 DiT 蒸馏到 1-4 个推理步骤同时保持 Flux-dev 级别的质量。Niels 的"在 8GB 机器上运行 Flux"笔记本是参考部署配方：T5 + CLIP 编码，量化 MMDiT 去噪（schnell 4 步 vs dev 50 步），VAE 解码。成本核算：

| 变体 | 步数 | L4 上 1024² 延迟 | 总 FLOPs（相对） |
|---------|-------|------------------------|------------------------|
| Flux.1-dev（原始） | 50 | 约 15 秒 | 1.0× |
| Flux.1-schnell | 4 | 约 1.2 秒 | 0.08×（快 12 倍） |
| SDXL-base | 30 | 约 4 秒 | 0.25× |
| SDXL-Lightning 2 步 | 2 | 约 0.3 秒 | 0.03× |

生产规则：**流匹配基模型 + 蒸馏 = 2026 年快速文本到图像的默认选择。** 每个主要供应商都交付这个组合：SD3-Turbo（SD3 + 流 + 蒸馏）、Flux-schnell（Flux-dev + 整流流拉直）、CogView-4-Flash。纯扩散基模型仅存在于旧版检查点。

## 扩展阅读

- [Liu, Gong, Liu (2022). Flow Straight and Fast: Learning to Generate and Transfer Data with Rectified Flow](https://arxiv.org/abs/2209.03003)——整流流。
- [Lipman et al. (2023). Flow Matching for Generative Modeling](https://arxiv.org/abs/2210.02747)——流匹配。
- [Esser et al. (2024). Scaling Rectified Flow Transformers for High-Resolution Image Synthesis](https://arxiv.org/abs/2403.03206)——SD3，大规模整流流。
- [Albergo, Vanden-Eijnden (2023). Stochastic Interpolants](https://arxiv.org/abs/2303.08797)——覆盖 FM + 扩散的通用框架。
- [Song et al. (2023). Consistency Models](https://arxiv.org/abs/2303.01469)——扩散/流的 1 步蒸馏。
- [Sauer et al. (2023). Adversarial Diffusion Distillation (SDXL-Turbo)](https://arxiv.org/abs/2311.17042)——turbo 变体。
- [Black Forest Labs (2024). Flux.1 models](https://blackforestlabs.ai/announcing-black-forest-labs/)——生产中的流匹配。