# GAN——生成器 vs 分辨器

> Goodfellow 在 2014 年的技巧是完全跳过密度。两个网络。一个造假。一个抓假。它们战斗直到假货与真货无法区分。这不应该有效。它通常不有效。当它有效时，样本仍然是文献中对于窄域最清晰的。

**类型：** 构建
**语言：** Python
**前置要求：** 第 3 阶段 · 02（反向传播），第 3 阶段 · 08（优化器），第 8 阶段 · 02（VAE）
**时间：** 约 75 分钟

## 问题

VAE 产生模糊样本，因为它们的 MSE 解码器损失是*均值*图像的贝叶斯最优——而许多合理数字的均值是一个模糊的数字。你想要一个奖励*可信度*而不是与任何一个目标的像素级接近度的损失。可信度没有闭式形式。你必须学习它。

Goodfellow 的想法：训练一个分类器 `D(x)` 来区分真实图像和假图像。训练一个生成器 `G(z)` 来欺骗 `D`。`G` 的损失信号是 `D` 当前认为使某物看起来真实的东西。这个信号随着 `G` 改进而更新，追逐一个移动目标。如果两个网络都收敛，`G` 就学会了数据分布，而无需写下 `log p(x)`。

这就是对抗训练。数学是一个极小极大博弈：

```
min_G max_D  E_real[log D(x)] + E_fake[log(1 - D(G(z)))]
```

2026 年 GAN 已不再是最先进的生成器（扩散和流匹配夺取了那个王冠）。但 StyleGAN 2/3 仍然是有史以来发布的最清晰的人脸模型，GAN 分辨器被用作扩散训练中的*感知损失*，对抗训练驱动了快速的一步蒸馏（SDXL-Turbo、SD3-Turbo、LCM），让你可以交付实时扩散。

## 概念

![GAN 训练：极小极大博弈中的生成器和分辨器](../assets/gan.svg)

**生成器 `G(z)`。** 将噪声向量 `z ~ N(0, I)` 映射到样本 `x̂`。一个解码器形状的网络（密集或转置卷积）。

**分辨器 `D(x)`。** 将样本映射到标量概率（或分数）。真实 → 1，假 → 0。

**损失。** 两个交替更新：

- **训练 `D`：** `loss_D = -[ log D(x) + log(1 - D(G(z))) ]`。对 real=1, fake=0 的二分类交叉熵。
- **训练 `G`：** `loss_G = -log D(G(z))`。这是 Goodfellow 使用的*非饱和*形式（原始的 `log(1 - D(G(z)))` 在 `D` 自信时会饱和并杀死梯度）。

**训练循环。** 一步 `D`，一步 `G`。重复。

**为什么有效。** 如果 `G` 完美匹配 `p_data`，那么 `D` 不能比随机更好，在任何地方输出 0.5；`G` 不再获得梯度。均衡。

**为什么失败。** 模式坍塌（`G` 找到 `D` 无法分类的一个模式并永远铸造它）、梯度消失（`D` 学习太快，`log D` 饱和）、训练不稳定（学习率、批大小，什么都可能）。

## 使 GAN 工作的变体

| 年份 | 创新 | 修复 |
|------|------------|-----|
| 2015 | DCGAN | 卷积/反卷积、批归一化、LeakyReLU——第一个稳定的架构。 |
| 2017 | WGAN, WGAN-GP | 用 Wasserstein 距离 + 梯度惩罚替换 BCE。修复梯度消失。 |
| 2017 | 谱归一化 | Lipschitz 约束分辨器。2026 年仍在分辨器中使用。 |
| 2018 | Progressive GAN | 先训练低分辨率，添加层。第一个百万像素结果。 |
| 2019 | StyleGAN / StyleGAN2 | 映射网络 + 自适应实例归一化。固定领域照片级真实感的最先进。 |
| 2021 | StyleGAN3 | 无混叠、平移等变——2026 年仍是人脸黄金标准。 |
| 2022 | StyleGAN-XL | 条件化、类别感知、更大规模。 |
| 2024 | R3GAN | 用更强的正则化重新品牌；在 1024² 上无需技巧工作。 |

## 构建

`code/main.py` 在 1-D 数据上训练一个微型 GAN：两个高斯的混合。生成器和分辨器是单隐藏层 MLP。我们手写实现前向、反向和极小极大循环。目标是看到两个关键失败模式（模式坍塌 + 梯度消失）如何发生。

### 步骤 1：非饱和损失

原版 Goodfellow 损失 `log(1 - D(G(z)))` 在 D 以高置信度将 G 的假货分类为假货时趋近于 0。在那一点，G 的梯度基本为零——G 无法改进。非饱和形式 `-log D(G(z))` 有相反的渐近行为：当 D 自信时它爆炸，给 G 一个强信号。

```python
def g_loss(d_fake):
    # maximize log D(G(z))  <=>  minimize -log D(G(z))
    return -sum(math.log(max(p, 1e-8)) for p in d_fake) / len(d_fake)
```

### 步骤 2：每个生成器步一个分辨器步

```python
for step in range(steps):
    # 训练 D
    real_batch = sample_real(batch_size)
    fake_batch = [G(z) for z in sample_noise(batch_size)]
    update_D(real_batch, fake_batch)

    # 训练 G
    fake_batch = [G(z) for z in sample_noise(batch_size)]  # 新鲜的假货
    update_G(fake_batch)
```

给 G 新鲜的假货，否则梯度是陈旧的。

### 步骤 3：观察模式坍塌

```python
if step % 200 == 0:
    samples = [G(z) for z in sample_noise(500)]
    mode_a = sum(1 for s in samples if s < 0)
    mode_b = 500 - mode_a
    if min(mode_a, mode_b) < 50:
        print("  [!] 模式坍塌：一个模式饥饿")
```

典型症状：两个真实模式中的一个停止被生成。分辨器停止纠正它，因为它从未被当作假货看到。

## 陷阱

- **分辨器太强。** 将 D 的学习率降低 2-5 倍，或添加实例/层噪声。如果 D 达到 >95% 准确率，G 就死了。
- **生成器记忆了一个模式。** 向 D 输入添加噪声，使用小批次分辨器层，或切换到 WGAN-GP。
- **批归一化泄漏统计。** 真实批 + 假批流过同一个 BN 层混合了它们的统计。改用实例归一化或谱归一化。
- **Inception Score 博弈。** FID 和 IS 在小样本数时有噪声。在评估时使用 ≥10k 样本。
- **一步采样对条件任务是个谎言。** 你仍然需要 CFG 尺度、截断技巧和重采样来获得可用输出。

## 使用

2026 年 GAN 技术栈：

| 场景 | 选择 |
|-----------|------|
| 照片级人脸，固定姿态 | StyleGAN3（最清晰，最小） |
| 动漫 / 风格化人脸 | StyleGAN-XL 或 Stable Diffusion LoRA |
| 图像到图像翻译 | Pix2Pix / CycleGAN（第 8 阶段 · 04）或 ControlNet（第 8 阶段 · 08） |
| 快速一步文本到图像 | 扩散的对抗蒸馏（SDXL-Turbo, SD3-Turbo） |
| 扩散训练器内部的感知损失 | 图像裁剪上的小型 GAN 分辨器 |
| 任何多模态、开放领域 | 不要——使用扩散或流匹配 |

GAN 清晰但窄。一旦你的领域开放——照片、任意文本提示、视频——切换到扩散。对抗技巧作为组件（感知损失、蒸馏）继续存在，而不是作为独立生成器。

## 交付

保存 `outputs/skill-gan-debugger.md`。技能接受一个失败 GAN 的运行（损失曲线、样本网格、数据集大小）并输出可能原因的排名列表、一行修复和重新运行协议。

## 练习

1. **简单。** 用默认设置运行 `code/main.py`。然后设置 `D_LR = 5 * G_LR` 并重新运行。G 的损失多快坍塌为常数？
2. **中等。** 用 WGAN 损失替换 Goodfellow BCE 损失：`loss_D = E[D(fake)] - E[D(real)]`，`loss_G = -E[D(fake)]`，并将 D 的权重裁剪到 `[-0.01, 0.01]`。训练是否更稳定？比较挂钟收敛。
3. **困难。** 将 1-D 示例扩展到 2-D 数据（环上的 8 个高斯混合）。跟踪生成器在 1k、5k、10k 步时捕获了多少个模式。实现小批次分辨并重新测量。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|-----------------------|
| 生成器 | "G" | 噪声到样本网络，`G: z → x̂`。 |
| 分辨器 | "D" | 分类器 `D: x → [0, 1]`，真实 vs 假。 |
| 极小极大 | "博弈" | 联合目标的 `min_G max_D`。 |
| 非饱和损失 | "修复" | 对 G 使用 `-log D(G(z))` 而不是 `log(1 - D(G(z)))`。 |
| 模式坍塌 | "G 记住了一件事" | 尽管数据多样，生成器产生很少的不同输出。 |
| WGAN | "Wasserstein" | 用推土机距离 + 梯度惩罚替换 BCE；更平滑的梯度。 |
| 谱归一化 | "Lipschitz 技巧" | 约束 D 的权重范数以限制其斜率；稳定训练。 |
| StyleGAN | "那个有效的" | 映射网络 + AdaIN；人脸的最佳，2026 年仍然。 |

## 生产说明：一步推理是 GAN 的持久优势

GAN 在开放域生成的样本质量上不再获胜，但它们在推理成本上仍然获胜。在生产推理文献的说法中，一个 GAN 有：

- **无预填充，无解码阶段。** 单个 `G(z)` 前向传播。TTFT ≈ 总延迟。
- **无 KV 缓存压力。** 唯一的状态是权重。批大小受激活内存限制，而不是缓存。
- **平凡连续批处理。** 由于每个请求花费相同的固定 FLOPs，服务器目标占用下的静态批通常是最优的。不需要飞行调度器。

这就是为什么 GAN 蒸馏（SDXL-Turbo、SD3-Turbo、ADD、LCM）是 2026 年快速文本到图像的主导技术：它将 20-50 步的扩散流水线折叠为 1-4 次 GAN 式前向传播，同时保持扩散基的分布。对抗损失作为将慢速生成器变成快速生成器的训练时旋钮继续存在。

## 扩展阅读

- [Goodfellow et al. (2014). Generative Adversarial Nets](https://arxiv.org/abs/1406.2661)——原始 GAN 论文。
- [Radford et al. (2015). Unsupervised Representation Learning with DCGAN](https://arxiv.org/abs/1511.06434)——第一个稳定架构。
- [Arjovsky, Chintala, Bottou (2017). Wasserstein GAN](https://arxiv.org/abs/1701.07875)——WGAN。
- [Miyato et al. (2018). Spectral Normalization for GANs](https://arxiv.org/abs/1802.05957)——SN。
- [Karras et al. (2020). Analyzing and Improving the Image Quality of StyleGAN](https://arxiv.org/abs/1912.04958)——StyleGAN2。
- [Karras et al. (2021). Alias-Free Generative Adversarial Networks](https://arxiv.org/abs/2106.12423)——StyleGAN3。
- [Sauer et al. (2023). Adversarial Diffusion Distillation](https://arxiv.org/abs/2311.17042)——SDXL-Turbo。