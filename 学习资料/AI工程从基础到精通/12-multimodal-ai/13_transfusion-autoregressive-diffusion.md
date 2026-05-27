# Transfusion：自回归文本 + 扩散图像合一 Transformer

> Chameleon 和 Emu3 将一切都押在离散 token 上。它们有效，但量化瓶颈是可见的——图像质量平台期低于连续空间扩散模型。Transfusion（Meta，Zhou 等人，2024 年 8 月）押了相反的赌注：保持图像连续，完全丢弃 VQ-VAE，用两个损失训练一个 Transformer。文本 token 做下一 token 预测。图像块做流匹配（Flow Matching）/ 扩散损失。两个目标优化相同的权重。Stable Diffusion 3（MMDiT）的底层架构是近亲。本课阅读 Transfusion 论点，构建一个玩具双损失训练器，并追踪让一个 Transformer 同时做两件事的注意力掩码。

**类型：** 构建
**语言：** Python（标准库，MNIST 规模玩具上的双损失训练器）
**前置条件：** Phase 12 · 11（Chameleon）、Phase 8（生成式 AI）
**时间：** 约 180 分钟

## 学习目标

- 编写一个在单一骨干上运行两个损失（文本 token 的 NTP，图像块上的扩散 MSE）的 Transformer。
- 解释为什么跨图像块的双向注意力加上文本 token 上的因果注意力是正确的掩码选择。
- 在算力、质量和代码复杂度上比较 Transfusion 风格（连续图像，扩散损失）与 Chameleon 风格（离散图像，NTP）。
- 指出 MMDiT 的贡献：每个块的模态特定权重，残差流上的联合注意力。

## 问题所在

离散 vs 连续图像 token 的辩论比 LLM 还古老。连续表示（原始像素、VAE 潜在）保留细节。离散 token（VQ 索引）适合 Transformer 的原生词汇但在量化步骤中丢失细节。

Chameleon / Emu3 走了离散路线：一个损失，一个架构，但图像保真度受分词器质量限制。

扩散模型走了连续路线：卓越的图像质量，但是与 LLM 分离的模型，复杂的噪声调度工程，且与文本生成没有干净集成。

Transfusion 问：我们能两者兼得吗？保持图像连续，仍然训练一个模型，用两个损失缝合成一个梯度步骤。

## 核心概念

### 双损失架构

单个仅解码器 Transformer 处理一个包含以下内容的序列：

- 文本 token（离散，来自 BPE 词汇）。
- 图像块（连续，16x16 像素块通过线性嵌入投影到隐藏维度——与 ViT 编码器的输入相同）。
- `<image>` 和 `</image>` 标签标记连续块所在的位置。

前向传播只运行一次。损失按 token 从两个头中选择一个：

- 对于文本 token：词汇-logit 头上的标准交叉熵。
- 对于图像块：连续块上的扩散损失——预测添加到每个块的噪声。

梯度流经共享的 Transformer 体。两个损失同时改进共享权重。

### 注意力掩码：因果文本 + 双向图像

文本 token 必须是因果的——你不能让文本 token 关注未来的文本，否则教师强制会崩溃。然而图像块代表一个快照；它们应该在同一图像块内双向关注彼此。

掩码：

```
M[i, j] = 1 如果：
  (i 是文本 且 j 是文本 且 j <= i)   # 文本的因果
  或 (i 是图像 且 j 是图像 且 same_image_block(i, j))   # 图像内的双向
  或 (i 是文本 且 j 是图像 且 j < i_image_end)   # 文本关注先前的图像
  或 (i 是图像 且 j 是文本 且 j < i_image_start)   # 图像关注前面的文本
```

在训练和推理时实现为块三角掩码。

### Transformer 内部的扩散损失

扩散损失是标准的：向图像块添加噪声，要求模型预测噪声（或等价的干净块）。Transfusion 的版本使用流匹配（Flow Matching）——预测从噪声到干净的速度场。

训练期间：
1. 对于每个图像块 x0，采样随机时间步 t。
2. 采样噪声 ε，计算 xt = (1-t) * x0 + t * ε（流匹配的线性插值）。
3. Transformer 预测 v_theta(xt, t)；损失 = MSE(v_theta(xt, t), ε - x0)。
4. 与同一序列的文本 NTP 损失一起反向传播。

推理时，生成为：
- 文本 token：标准自回归采样。
- 图像块：扩散采样循环（典型 10-30 步），以先前的文本 token 为条件。

### MMDiT：Stable Diffusion 3 的变体

Stable Diffusion 3（Esser 等人，2024 年 3 月）与 Transfusion 大约同时发布了 MMDiT（多模态扩散 Transformer）。架构是兄弟关系。

MMDiT 的关键差异：

- 每个块的模态特定权重。每个 Transformer 块对文本 token vs 图像块有单独的 Q、K、V 和 MLP 权重。注意力是联合的（跨模态）；其他一切都是模态特定的。
- 整流流（Rectified Flow）训练。一种特定的流匹配变体，具有已知的采样和比 DDPM 更简单的数学。
- 规模。MMDiT 是 SD3（2B 和 8B 参数变体）的骨干。Transfusion 论文扩展到 7B。

两者聚合于相同的核心思想：一个 Transformer 在文本上运行 NTP，在连续图像表示上运行扩散。

### 为什么这优于 Chameleon 风格

连续扩散和离散 NTP 在图像生成上的质量差距是可测量的。Transfusion 论文报告：

- 在 7B 参数下，FID 比同尺寸 Chameleon 风格模型高 3-5 个点。
- 不需要训练分词器——图像编码器更简单（到隐藏的线性投影，与 ViT 的输入层相同）。
- 推理可以并行化图像块去噪，不像自回归图像 token。

缺点：Transfusion 是双损失模型，使训练动态更棘手。损失权重需要调优。NTP 和扩散之间的调度不匹配可能导致一个头占主导。

### 后续发展

Janus-Pro（第 12.15 课）通过解耦理解和生成的视觉编码器来优化 Transfusion 的思想——SigLIP 用于理解，VQ 用于生成——同时共享 Transformer 体。Show-o（第 12.14 课）将扩散替换为离散扩散（掩码预测）。统一生成家族在 Transfusion 之后迅速分支。

2026 年能发出图像的生产 VLM——Gemini 3 Pro、GPT-5、Claude Opus 4.7 的图像生成路径——几乎肯定使用了这个家族的某种衍生品。细节是专有的。

## 使用指南

`code/main.py` 在一个微小的 MNIST 风格问题上构建玩具 Transfusion：

- 文本描述是描述数字（0-9）的短整数序列。
- 图像是 4x4 字节网格。
- 一对共享权重线性投影充当 Transformer 的替代；文本上的 NTP 损失，噪声块上的 MSE 损失。
- 训练循环交替两个损失，注意力掩码是显式的。
- 生成在单次前向传播中产生文本描述和 4x4 图像。

Transformer 是玩具。双损失管线、注意力掩码构建和推理循环是真正的产物。

## 交付物

本课产出 `outputs/skill-two-loss-trainer-designer.md`。给定新的多模态训练任务（文本 + 图像、文本 + 音频、文本 + 视频），它设计双损失调度（损失权重、掩码形状、共享 vs 模态特定块）并标记实现风险。

## 练习

1. Transfusion 风格模型训练 70% 文本 token 和 30% 图像块。图像扩散损失在幅度上约是文本 NTP 损失的 10 倍。什么损失权重能平衡它们？

2. 为以下序列实现块三角掩码：`[T, T, <image>, P, P, P, P, </image>, T]`。将每个条目标记为 0 或 1。

3. MMDiT 有模态特定的 QKV 权重。与 Transfusion 完全共享的 Transformer 相比，这增加了多少参数计数开销？在 7B 参数下值得吗？

4. 生成：给定文本提示词，模型运行 NTP 产生 50 个 token，然后遇到 `<image>`，然后在 256 个块上以 20 个去噪步运行扩散。总共有多少次前向传播？

5. 阅读 SD3 论文第 3 节。描述整流流以及为什么它比 DDPM 在更少的推理步骤中收敛。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|------------------------|
| 双损失训练 | 「NTP + 扩散」 | 单个 Transformer 在同一梯度步骤中同时优化文本 token 的交叉熵和连续图像块的 MSE |
| 流匹配（Flow matching） | 「整流流」 | 扩散变体，预测从噪声到干净数据的速度场；数学比 DDPM 更简单 |
| MMDiT | 「多模态 DiT」 | Stable Diffusion 3 的架构：联合注意力，模态特定的 MLP 和归一化 |
| 块三角掩码 | 「因果文本 + 双向图像」 | 注意力掩码，跨文本是因果的，但在图像区域内是双向的 |
| 连续图像表示 | 「无 VQ」 | 图像块作为实值向量，而非整数码本索引 |
| 速度预测 | 「v-参数化」 | 网络输出是噪声和数据之间的速度场，而非噪声本身 |

## 进一步阅读

- [Zhou et al. — Transfusion (arXiv:2408.11039)](https://arxiv.org/abs/2408.11039)
- [Esser et al. — Stable Diffusion 3 / MMDiT (arXiv:2403.03206)](https://arxiv.org/abs/2403.03206)
- [Peebles & Xie — DiT (arXiv:2212.09748)](https://arxiv.org/abs/2212.09748)
- [Zhao et al. — MonoFormer (arXiv:2409.16280)](https://arxiv.org/abs/2409.16280)
- [Xie et al. — Show-o (arXiv:2408.12528)](https://arxiv.org/abs/2408.12528)