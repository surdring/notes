# CLIP 与对比式视觉-语言预训练

> OpenAI 的 CLIP（2021）证明了一个足够大的想法足以驱动接下来五年的发展：仅使用嘈杂的网络图像-描述对和对比损失（Contrastive Loss），将图像编码器和文本编码器对齐到同一个向量空间中。零监督标签。4 亿对。生成的嵌入空间可以做零样本分类、图像-文本检索，并作为视觉塔（vision tower）接入 2026 年的每一个 VLM 中。SigLIP 2（2025）用 sigmoid 替代 softmax，以更低的成本超越了 CLIP。本课从 InfoNCE 到 sigmoid 成对损失（Sigmoid Pairwise Loss）逐步讲解数学原理，并在标准库 Python 中构建训练步骤。

**类型：** 构建
**语言：** Python（标准库，InfoNCE + sigmoid 损失实现）
**前置条件：** Phase 12 · 01（ViT 块）、Phase 7（Transformer）
**时间：** 约 180 分钟

## 学习目标

- 从互信息推导 InfoNCE 损失，并实现数值稳定的向量化版本。
- 解释为什么 sigmoid 成对损失（SigLIP）可以扩展到 batch 32768+ 而没有 softmax 所要求的全收集（all-gather）开销。
- 通过构建文本模板（`a photo of a {class}`）并在余弦相似度上取 argmax，运行零样本 ImageNet 分类。
- 指出 CLIP / SigLIP 预训练给你的四个杠杆：批次大小、温度、提示词模板、数据质量。

## 问题所在

CLIP 之前的视觉是监督的。收集标注数据集（ImageNet：120 万张图像，1000 个类别），训练 CNN，发布。标签昂贵，标签偏向标注者能达成一致的内容，并且如果不微调就难以迁移到新任务上。

图像-描述网络上有超过十亿个免费且松散标注的对。一张金毛犬的照片配上 alt 文字「我的狗 Max 在公园里」携带了一个监督信号——文本描述了图像。问题是：你能把它转化为有用的训练吗？

CLIP 的答案：将图像-描述对视为匹配任务。给定一批 N 张图像和 N 条描述，学习将每张图像与其自己的描述匹配，对抗 N-1 个干扰项。监督信号是「这两个东西属于一起；这 N-1 个不属于一起」。没有类别标签。没有人工标注。只有一个对比损失。

生成的嵌入空间做得比 CLIP 被训练来做的事情更多。ImageNet 零样本之所以有效，是因为「一张猫的照片」嵌入在从未被明确标注为猫的猫照片附近。这个赌注催生了 2026 年的每一个 VLM。

## 核心概念

### 双编码器

CLIP 有两个塔：

- 图像编码器 `f`：ViT 或 ResNet，每张图像输出一个 D 维向量。
- 文本编码器 `g`：小型 Transformer，每条描述输出一个 D 维向量。

两个塔都将其输出归一化为单位长度。相似度是 `cos(f(x), g(y)) = f(x)^T g(y)`，因为两者都是单位范数。

对于一批 N 个（图像，描述）对，构建形状为 `(N, N)` 的相似度矩阵 `S`：

```
S[i, j] = cos(f(x_i), g(y_j)) / tau
```

其中 `tau` 是一个可学习的温度参数（CLIP 初始化为 0.07；在对数空间中学习）。

### InfoNCE 损失

CLIP 在行和列上使用对称的交叉熵：

```
loss_i2t = CE(S, labels=identity)     # 每张图像的正样本是其自己的描述
loss_t2i = CE(S^T, labels=identity)   # 每条描述的正样本是其自己的图像
loss = (loss_i2t + loss_t2i) / 2
```

这就是 InfoNCE。CE 中的 softmax 迫使每张图像与自己的描述匹配度高于批次中的其他每一条描述。负样本是所有其他批次项。更大的批次 = 更多的负样本 = 更强的信号。CLIP 在 batch 32k 训练；规模很重要。

### 温度参数

`tau` 控制 softmax 的锐度。低 tau → 尖锐的分布，硬负样本挖掘效果。高 tau → 柔软，所有样本都参与贡献。CLIP 学习 `log(1/tau)`，并截断以防止坍塌。SigLIP 2 固定初始 tau 并改用可学习的偏置。

### 为什么 sigmoid 扩展性更好（SigLIP）

Softmax 需要整个相似度矩阵同步。在分布式训练中，你必须将每个嵌入全收集到每个副本，然后执行 softmax。这在通信上与世界大小呈平方关系。

SigLIP 用逐元素 sigmoid 替代 softmax：对于每个对 `(i, j)`，损失是一个二分类「这两个是匹配对吗？」正类标签是对角线，其他所有都是负类。损失是：

```
L = -1/N sum over (i, j) [ y_ij log sigmoid(S[i,j]) + (1-y_ij) log sigmoid(-S[i,j]) ]
```

`y_ij = 1` 如果 `i == j`，否则为 0。每个对的损失是独立的。不需要全收集。每块 GPU 计算其本地块并求和。SigLIP 2 以低成本扩展到 batch 32k-512k，而 CLIP 则需要成比例的更多通信。

### 零样本分类

给定 N 个类别名称，为每个类别构建一个文本模板：

```
"a photo of a {class}"
```

用文本编码器嵌入每个模板。用图像编码器嵌入你的图像。余弦相似度的 argmax = 预测类别。不需要在目标类别上训练。

提示词模板很重要。CLIP 的原始论文每个类别使用了 80 个模板（普通、艺术、照片、绘画等）并对嵌入取平均。+3 个 ImageNet 点。现代用法通常选择一个或两个模板。

### 线性探测器与微调

零样本是一个基线。线性探测器（Linear Probe）（在冻结的 CLIP 特征之上训练一个线性层用于你的目标类别）在领域内任务上优于零样本。全量微调在领域内优于线性探测器，但可能损害零样本迁移。三种模式，三种权衡。

### SigLIP 2：NaFlex 与密集特征

SigLIP 2（2025）增加了：
- NaFlex：单个模型处理可变宽高比和分辨率。
- 更好的密集特征用于分割和深度估计，目标是作为 VLM 中的冻结骨干使用。
- 多语言：在 100+ 种语言上训练，而 CLIP 仅为英语。
- 1B 参数规模，而 CLIP 最多到 400M。

在 2026 年的开源 VLM 中，SigLIP 2 SO400m/14 是默认的视觉塔。CLIP 仍然是纯图像-文本检索的默认选择，其中特定的 LAION-2B 训练分布与你的查询模式匹配。

### ALIGN、BASIC、OpenCLIP、EVA-CLIP

ALIGN（Google，2021）：与 CLIP 相同的想法，18 亿对规模，90% 噪声。证明噪声数据可以规模化。OpenCLIP（LAION）：在 LAION-400M / 2B 上的 CLIP 开源复现，多个规模，是首选的开源检查点。EVA-CLIP：从掩码图像建模初始化；VLM 的强骨干。BASIC：Google 的 CLIP+ALIGN 混合。全部属于同一家族，不同的数据和调优。

### 零样本上限

CLIP 类模型在 ImageNet 零样本的上限约为 76%（CLIP-G、OpenCLIP-G）。超过这个上限需要更大的数据（SigLIP 2 达到 80%+）或架构变化（监督头、更多参数）。基准正在饱和；真正的价值是下游 VLM 消费的嵌入空间。

## 使用指南

`code/main.py` 实现了：

1. 一个玩具双编码器（基于哈希的图像特征、文本字符特征），让你可以在不用 numpy 的情况下看到 InfoNCE 的形状。
2. 纯 Python 的 InfoNCE 损失（通过 log-sum-exp 实现数值稳定性）。
3. 用于比较的 sigmoid 成对损失。
4. 一个零样本分类例程：计算与一组文本提示词的余弦相似度，argmax 用于预测。

运行它并观察损失曲线。绝对数值是玩具级别的；形状匹配真实 CLIP 训练器输出的形状。

## 交付物

本课产出 `outputs/skill-clip-zero-shot.md`。给定一组图像（通过路径）和一个目标类别列表，它使用 CLIP 模板构建文本提示词，用指定的检查点（例如 `openai/clip-vit-large-patch14`）嵌入两侧，并返回 top-1 / top-5 预测及相似度分数。该技能拒绝为不在提示词列表中的类别做出断言。

## 练习

1. 手动实现批次 4 对的 InfoNCE。构建 4x4 相似度矩阵，运行 softmax，选择对角线，计算交叉熵。对照这个手动计算验证你的 Python 实现。

2. SigLIP 除温度外还使用一个偏置参数 `b`：`S'[i,j] = S[i,j]/tau + b`。当批次有大量类别不平衡（每行负样本远多于正样本）时，`b` 扮演什么角色？阅读 SigLIP 第 3 节（arXiv:2303.15343）。

3. 为猫 vs 狗构建一个零样本分类器。尝试两个提示词模板：`a photo of a {class}` 和 `a picture of a {class}`。在 100 张测试图像上测量准确率。模板的集成是否优于单个？

4. 计算 softmax InfoNCE vs sigmoid 成对在 512 GPU、batch 32k 运行时的通信成本。哪个按 O(N) 扩展，哪个按 O(N^2) 扩展？引用 SigLIP 第 4 节。

5. 阅读 OpenCLIP 缩放定律论文（arXiv:2212.07143，Cherti 等人）。从图表中重现他们关于数据缩放的结论：在固定模型大小时，ImageNet 零样本准确率与训练数据大小之间的对数-线性关系是什么？

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|----------------|------------------------|
| InfoNCE | 「对比损失」 | 对批次的相似度矩阵做交叉熵；每个项的正样本是其配对项，负样本是其他所有项 |
| Sigmoid 损失 | 「SigLIP 损失」 | 逐对二分类交叉熵；没有 softmax，没有全收集，在分布式训练中以低成本扩展 |
| 温度（Temperature） | 「tau」 | 在 softmax/sigmoid 之前缩放 logit 的标量；控制分布的锐度 |
| 零样本（Zero-shot） | 「不微调的分类」 | 使用文本提示词构建类别嵌入，通过余弦相似度分类；不在目标类别上训练 |
| 提示词模板 | 「a photo of a ...」 | 类别名称周围的文本脚手架；影响零样本准确率 1-5 个点 |
| 双编码器（Dual encoder） | 「双塔」 | 一个图像编码器 + 一个文本编码器，在共享 D 维空间中输出 |
| 硬负样本（Hard negative） | 「难处理的干扰项」 | 相似度足够接近正样本的负样本，模型需要努力才能将它们分开 |
| 线性探测器（Linear probe） | 「冻结 + 一层」 | 仅在冻结特征之上训练线性分类器；衡量特征质量 |
| NaFlex | 「原生灵活分辨率」 | SigLIP 2 的能力，可以在不改变大小的情况下以任何宽高比和分辨率输入图像 |
| 温度缩放 | 「对数参数化 tau」 | CLIP 将 `log(1/tau)` 参数化以使梯度行为良好；截断以防止坍塌到接近零的 tau |

## 进一步阅读

- [Radford et al. — Learning Transferable Visual Models From Natural Language Supervision (arXiv:2103.00020)](https://arxiv.org/abs/2103.00020)——CLIP 论文。
- [Zhai et al. — Sigmoid Loss for Language Image Pre-Training (arXiv:2303.15343)](https://arxiv.org/abs/2303.15343)——SigLIP。
- [Tschannen et al. — SigLIP 2 (arXiv:2502.14786)](https://arxiv.org/abs/2502.14786)——多语言 + NaFlex。
- [Jia et al. — ALIGN (arXiv:2102.05918)](https://arxiv.org/abs/2102.05918)——用嘈杂网络数据规模化。
- [Cherti et al. — Reproducible scaling laws for contrastive language-image learning (arXiv:2212.07143)](https://arxiv.org/abs/2212.07143)——OpenCLIP 缩放定律。