# StyleGAN

> 大多数生成器将 `z` 同时搅入每一层。StyleGAN 将其分开：首先将 `z` 映射到中间的 `w`，然后通过 AdaIN 在每个分辨率级别*注入* `w`。这个单一变化解开了潜在空间，使照片级人脸成为七年来已解决的问题。

**类型：** 构建
**语言：** Python
**前置要求：** 第 8 阶段 · 03（GAN），第 4 阶段 · 08（归一化），第 3 阶段 · 07（CNN）
**时间：** 约 45 分钟

## 问题

DCGAN 通过一层层转置卷积将 `z` 映射到图像。问题在于：`z` 控制一切——姿态、光照、身份、背景——纠缠在一起。沿 `z` 的一个轴移动，四个都变。你不能要求模型"同一人，不同姿势"，因为表示不会那样因式分解。

Karras 等人（2019，NVIDIA）提出：停止将 `z` 直接馈入卷积层。馈入一个常数 `4×4×512` 张量作为网络输入。学习一个 8 层 MLP，将 `z ∈ Z → w ∈ W` 映射。通过*自适应实例归一化*（AdaIN）在每个分辨率注入 `w`：归一化每个卷积特征图，然后通过 `w` 的仿射投影缩放和移位。添加每层噪声用于随机细节（皮肤毛孔、发丝）。

结果是：`W` 对"高级风格"（姿态、身份）和"精细风格"（光照、颜色）具有大致正交的轴。你可以通过使用图像 A 的 `w` 用于低分辨率级别和图像 B 的 `w` 用于高级别来交换两个图像之间的风格。这解锁了编辑、跨域风格化以及整个"StyleGAN 反演"研究方向。

## 概念

![StyleGAN：映射网络 + AdaIN + 每层噪声](../assets/stylegan.svg)

**映射网络。** `f: Z → W`，一个 8 层 MLP。`Z = N(0, I)^512`。`W` 不被迫为高斯——它学习一个适应数据的形状。

**合成网络。** 从学习常数 `4×4×512` 开始。每个分辨率块：`上采样 → 卷积 → AdaIN(w_i) → 噪声 → 卷积 → AdaIN(w_i) → 噪声`。分辨率加倍：4, 8, 16, 32, 64, 128, 256, 512, 1024。

**AdaIN。**

```
AdaIN(x, y) = y_scale · (x - mean(x)) / std(x) + y_bias
```

其中 `y_scale` 和 `y_bias` 来自 `w` 的仿射投影。按特征图归一化，然后重新风格化。这里的"风格"是特征图的一阶和二阶统计量。

**每层噪声。** 添加到每个特征图的单通道高斯噪声，按学习的每通道因子缩放。控制随机细节而不影响全局结构。

**截断技巧。** 在推理时，采样 `z`，计算 `w = mapping(z)`，然后 `w' = ŵ + ψ·(w - ŵ)`，其中 `ŵ` 是许多样本上的均值 `w`。`ψ < 1` 用多样性换取质量。几乎每个 StyleGAN 演示都使用 `ψ ≈ 0.7`。

## StyleGAN 1 → 2 → 3

| 版本 | 年份 | 创新 |
|---------|------|------------|
| StyleGAN | 2019 | 映射网络 + AdaIN + 噪声 + 渐进增长。 |
| StyleGAN2 | 2020 | 权重解调替换 AdaIN（修复水滴伪影）；跳跃/残差架构；路径长度正则化。 |
| StyleGAN3 | 2021 | 无混叠卷积 + 等变核；消除纹理粘在像素网格上。 |
| StyleGAN-XL | 2022 | 类条件，1024²，ImageNet。 |
| R3GAN | 2024 | 用更强的正则化重新品牌；在 FFHQ-1024 上以 20 倍更少的参数缩小与扩散的差距。 |

2026 年 StyleGAN3 仍然是以下场景的默认选择：(a) 高 FPS 下的窄域照片级真实感，(b) 少样本域适应（用 100 张图像在新数据集上训练，冻结映射网络），(c) 基于反演的编辑（找到重建真实照片的 `w`，然后编辑该 `w`）。对于开放域文本到图像，它不是正确的工具——扩散才是。

## 构建

`code/main.py` 在 1-D 中实现了一个玩具"StyleGAN 精简版"：一个映射 MLP，一个合成函数，接受学习常数向量并用 `w` 派生的缩放/偏置和每层噪声调制它。它表明通过仿射调制注入 `w` 匹配或优于将 `z` 拼接到生成器输入。

### 步骤 1：映射网络

```python
def mapping(z, M):
    h = z
    for i in range(num_layers):
        h = leaky_relu(add(matmul(M[f"W{i}"], h), M[f"b{i}"]))
    return h
```

### 步骤 2：自适应实例归一化

```python
def adain(x, w_scale, w_bias):
    mu = mean(x)
    sd = std(x)
    x_norm = [(xi - mu) / (sd + 1e-8) for xi in x]
    return [w_scale * xi + w_bias for xi in x_norm]
```

每特征图缩放和偏置来自 `w` 通过线性投影。

### 步骤 3：每层噪声

```python
def add_noise(x, sigma, rng):
    return [xi + sigma * rng.gauss(0, 1) for xi in x]
```

每通道 Sigma 是可学习的。

## 陷阱

- **水滴伪影。** StyleGAN 1 在特征图中产生了斑驳水滴，因为 AdaIN 归零了均值。StyleGAN 2 的权重解调通过缩放卷积权重来修复它。
- **纹理粘滞。** StyleGAN 1 和 2 的纹理跟随像素坐标，而不是物体坐标（插值时可见）。StyleGAN 3 的无混叠卷积用窗口 sinc 滤波器修复了这一点。
- **模式覆盖。** 截断 `ψ < 0.7` 看起来干净但从窄锥中采样；如果你需要多样性，使用 `ψ = 1.0`。
- **反演是有损的。** 将真实照片反演到 `W` 通常通过优化或编码器（e4e、ReStyle、HyperStyle）完成。结果在多次迭代中漂移。

## 使用

| 用例 | 方法 |
|----------|----------|
| 照片级人脸（动漫、产品、窄域） | StyleGAN3 FFHQ / 自定义微调 |
| 从照片进行面部编辑 | e4e 反演 + StyleSpace / InterFaceGAN 方向 |
| 面部交换 / 重现 | StyleGAN + 编码器 + 混合 |
| 头像流水线 | StyleGAN3 带 ADA 用于低数据微调 |
| 从少量图像进行域适应 | 冻结映射网络，微调合成 |
| 多模态或文本条件生成 | 不要——使用扩散 |

对于产品级演示，答案是"人脸的图片"，StyleGAN 在推理成本（单次前向传播，4090 上 <10ms）和相同质量条下的清晰度上击败扩散。

## 交付

保存 `outputs/skill-stylegan-inversion.md`。技能接受真实照片并输出：反演方法（e4e / ReStyle / HyperStyle）、预期潜在损失、编辑预算（在出现伪影之前你可以在 `W` 中移动多远的距离），以及已知好用的编辑方向列表（年龄、表情、姿态）。

## 练习

1. **简单。** 运行 `code/main.py` 设置 `adain_on=True` 和 `adain_on=False`。比较固定潜在 vs 扰动潜在的输出分布。
2. **中等。** 实现混合正则化：对于训练批次，计算 `w_a`、`w_b`，在前半合成中应用 `w_a`，在后半合成中应用 `w_b`。解码器是否学习分离的风格？
3. **困难。** 取一个预训练的 StyleGAN3 FFHQ 模型（ffhq-1024.pkl）。通过在标记样本上训练 SVM 找到控制"微笑"的 `w` 方向；报告在身份漂移之前你可以推多远。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|-----------------------|
| 映射网络 | "MLP" | `f: Z → W`，8 层，将潜在几何与数据统计解耦。 |
| W 空间 | "风格空间" | 映射网络的输出；大致解耦。 |
| AdaIN | "自适应实例归一化" | 归一化特征图，然后通过 `w` 投影缩放 + 移位。 |
| 截断技巧 | "Psi" | `w = mean + ψ·(w - mean)`，ψ<1 用多样性换取质量。 |
| 路径长度正则化 | "PL reg" | 惩罚图像每单位 `w` 变化的大变化；使 `W` 更平滑。 |
| 权重解调 | "StyleGAN2 修复" | 归一化卷积权重而不是激活；消除水滴伪影。 |
| 无混叠 | "StyleGAN3 的技巧" | 窗口 sinc 滤波器；消除纹理粘在像素网格上。 |
| 反演 | "为真实图像找到 w" | 优化或编码 `x → w` 使得 `G(w) ≈ x`。 |

## 生产说明：为什么 StyleGAN 在 2026 年仍然被交付

StyleGAN3 在 4090 上以不到 10 毫秒生成一个 1024² FFHQ 人脸——`num_steps = 1`，没有 VAE 解码，没有交叉注意力传播。在生产术语中，这是任何图像生成器的延迟底线。相同分辨率下的 50 步 SDXL + VAE 解码流水线大约 3 秒。那是 **300 倍**的差距，对于窄域产品（头像服务、ID 文档流水线、素材人脸生成）它在 TCO 上获胜。

两个操作后果：

- **无调度器，无批处理器。** 目标占用的静态批次是最优的。连续批处理（对 LLM 和扩散至关重要）提供零收益，因为每个请求花费相同的 FLOPs。
- **截断 `ψ` 是安全旋钮。** `ψ < 0.7` 从映射网络范围的窄锥中采样。这是服务层对样本方差的唯一杠杆。高峰负载时降低 `ψ`，高级用户时提高它。

## 扩展阅读

- [Karras et al. (2019). A Style-Based Generator Architecture for GANs](https://arxiv.org/abs/1812.04948)——StyleGAN。
- [Karras et al. (2020). Analyzing and Improving the Image Quality of StyleGAN](https://arxiv.org/abs/1912.04958)——StyleGAN2。
- [Karras et al. (2021). Alias-Free Generative Adversarial Networks](https://arxiv.org/abs/2106.12423)——StyleGAN3。
- [Tov et al. (2021). Designing an Encoder for StyleGAN Image Manipulation](https://arxiv.org/abs/2102.02766)——e4e 反演。
- [Sauer et al. (2022). StyleGAN-XL: Scaling StyleGAN to Large Diverse Datasets](https://arxiv.org/abs/2202.00273)——StyleGAN-XL。
- [Huang et al. (2024). R3GAN: The GAN is dead; long live the GAN!](https://arxiv.org/abs/2501.05441)——现代极简 GAN 配方。