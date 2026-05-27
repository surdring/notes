# 视觉 Transformer (ViT)

> 把图像切成 patch，把每个 patch 当作一个词，跑一个标准 transformer。别回头看。

**类型：** 构建
**语言：** Python
**前置知识：** Phase 7 Lesson 02（自注意力）、Phase 4 Lesson 04（图像分类）
**时间：** ~45 分钟

## 学习目标

- 从零实现 patch embedding、可学习位置嵌入、class token 和 transformer encoder block，构建一个最小 ViT
- 解释为什么 ViT 被认为需要海量预训练数据，直到 DeiT 和 MAE 证明并非如此
- 从架构先验的角度比较 ViT、Swin 和 ConvNeXt（无先验、局部窗口注意力、卷积主干）
- 使用 `timm` 和标准的 linear-probe / fine-tune 方法在小数据集上微调预训练 ViT

## 问题

十年间，卷积就是计算机视觉的代名词。CNN 具有强大的归纳偏置——局部性、平移等变性——没人认为能被替代。然后 Dosovitskiy 等人（2020）展示了：一个普通的 transformer 应用于展平的图像 patch，完全没有卷积机制，也能在大规模数据上匹敌甚至超越最好的 CNN。

关键在于"大规模"。ViT 在 ImageNet-1k 上输给了 ResNet。在 ImageNet-21k 或 JFT-300M 上预训练、然后在 ImageNet-1k 上微调的 ViT 则赢了。结论是：transformer 缺乏有用的先验，但可以从足够多的数据中学习这些先验。后续工作（DeiT、MAE、DINO）表明，使用正确的训练方法——强数据增强、自监督预训练、蒸馏——ViT 在小数据上也能很好地训练。

到 2026 年，纯 CNN 在边缘设备上仍有竞争力（ConvNeXt 是最强的），但 transformer 主导了其他一切：分割（Mask2Former、SegFormer）、检测（DETR、RT-DETR）、多模态（CLIP、SigLIP）、视频（VideoMAE、VJEPA）。ViT block 结构是必须掌握的。

## 核心概念

### 处理流程

```mermaid
flowchart LR
    IMG["图像<br/>(3, 224, 224)"] --> PATCH["Patch embedding<br/>conv 16x16 s=16<br/>-> (768, 14, 14)"]
    PATCH --> FLAT["展平为<br/>(196, 768) tokens"]
    FLAT --> CAT["前置<br/>[CLS] token"]
    CAT --> POS["加上可学习<br/>位置嵌入"]
    POS --> ENC["N 个 transformer<br/>encoder block"]
    ENC --> CLS["取 [CLS]<br/>token 输出"]
    CLS --> HEAD["MLP 分类器"]

    style PATCH fill:#dbeafe,stroke:#2563eb
    style ENC fill:#fef3c7,stroke:#d97706
    style HEAD fill:#dcfce7,stroke:#16a34a
```

七步。Patch -> token -> 注意力 -> 分类器。每个变体（DeiT、Swin、ConvNeXt、MAE 预训练）只改七步中的一两步，其余不变。

### Patch Embedding

第一个卷积是秘密所在。卷积核大小 16，步长 16，所以 224x224 的图像变成 14x14 的 16x16 patch 网格，每个被投影到 768 维嵌入向量。这一个卷积同时完成了 patchification 和线性投影。

```
输入:  (3, 224, 224)
Conv (3 -> 768, k=16, s=16, 无 padding):
输出: (768, 14, 14)
展平空间维度: (196, 768)
```

196 个 patch = 196 个 token。每个 token 的特征维度是 768（ViT-B）、1024（ViT-L）或 1280（ViT-H）。

### Class Token

一个单一的可学习向量，前置到序列中：

```
tokens = [CLS; patch_1; patch_2; ...; patch_196]   形状 (197, 768)
```

经过 N 个 transformer block 后，`[CLS]` 的输出就是全局图像表示。分类头只读这一个向量。

### 位置嵌入

Transformer 没有内置的空间位置概念。给每个 token 加一个可学习向量：

```
tokens = tokens + learned_pos_embedding   （形状也是 (197, 768)）
```

这个嵌入是模型的参数；基于梯度的训练使其适应 2D 图像结构。正弦 2D 替代方案存在但实践中很少使用。

### Transformer Encoder Block

标准的。多头自注意力、MLP、残差连接、pre-LayerNorm。

```
x = x + MSA(LN(x))
x = x + MLP(LN(x))

MLP 是两层带 GELU 的：Linear(d -> 4d) -> GELU -> Linear(4d -> d)
```

ViT-B/16 堆叠 12 个这样的 block，每个有 12 个注意力头，总计 8600 万参数。

### 为什么用 Pre-LN

早期 transformer 使用 post-LN（`x = LN(x + sublayer(x))`），在没有 warmup 的情况下难以训练超过 6-8 层。Pre-LN（`x = x + sublayer(LN(x))`）可以稳定地训练更深的网络，不需要 warmup。每个 ViT 和每个现代 LLM 都使用 pre-LN。

### Patch 大小的权衡

- 16x16 patch -> 196 tokens，标准配置。
- 32x32 patch -> 49 tokens，更快但分辨率更低。
- 8x8 patch -> 784 tokens，更精细但 O(n²) 的注意力代价急剧增长。

更大的 patch = 更少的 token = 更快但空间细节更少。SwinV2 在层次化窗口中使用 4x4 patch。

### DeiT 在 ImageNet-1k 上训练 ViT 的方法

原始 ViT 需要 JFT-300M 才能击败 CNN。DeiT（Touvron 等人，2020）仅在 ImageNet-1k 上就将 ViT-B 训练到 81.8% top-1 准确率，用了四个改变：

1. 强数据增强：RandAugment、Mixup、CutMix、Random Erasing。
2. 随机深度（训练时随机丢弃整个 block）。
3. 重复增强（每批中同一图像采样 3 次）。
4. 从 CNN 教师模型蒸馏（可选，进一步提升准确率）。

每个现代 ViT 训练方案都源于 DeiT。

### Swin vs ConvNeXt

- **Swin**（Liu 等人，2021）——基于窗口的注意力。每个 block 在局部窗口内做注意力；交替的 block 偏移窗口以在不同窗口间混合信息。在保留注意力算子的同时引入了类似 CNN 的局部性先验。
- **ConvNeXt**（Liu 等人，2022）——重新设计的 CNN，匹配 Swin 的架构选择（深度卷积、LayerNorm、GELU、倒置瓶颈）。证明了差距不在于"注意力 vs 卷积"，而在于"现代训练方案 + 架构"。

到 2026 年，ConvNeXt-V2 和 Swin-V2 都是生产级的；正确选择取决于你的推理栈（ConvNeXt 对边缘设备编译更好）和预训练语料。

### MAE 预训练

掩码自编码器（He 等人，2022）：随机掩码 75% 的 patch，训练 encoder 只处理可见的 25%，训练一个小 decoder 从 encoder 输出重建被掩码的 patch。预训练后，丢弃 decoder 并微调 encoder。

MAE 使 ViT 可以在仅 ImageNet-1k 上训练，达到 SOTA，是当前默认的自监督方法。

## 构建

### 步骤 1：Patch Embedding

```python
import torch
import torch.nn as nn

class PatchEmbedding(nn.Module):
    def __init__(self, in_channels=3, patch_size=16, dim=192, image_size=64):
        super().__init__()
        assert image_size % patch_size == 0
        self.proj = nn.Conv2d(in_channels, dim, kernel_size=patch_size, stride=patch_size)
        num_patches = (image_size // patch_size) ** 2
        self.num_patches = num_patches

    def forward(self, x):
        x = self.proj(x)
        return x.flatten(2).transpose(1, 2)
```

一个卷积、一次展平、一次转置。这就是整个图像到 token 的步骤。

### 步骤 2：Transformer Block

Pre-LN、多头自注意力、带 GELU 的 MLP、残差连接。

```python
class Block(nn.Module):
    def __init__(self, dim, num_heads, mlp_ratio=4, dropout=0.0):
        super().__init__()
        self.ln1 = nn.LayerNorm(dim)
        self.attn = nn.MultiheadAttention(dim, num_heads, dropout=dropout, batch_first=True)
        self.ln2 = nn.LayerNorm(dim)
        self.mlp = nn.Sequential(
            nn.Linear(dim, dim * mlp_ratio),
            nn.GELU(),
            nn.Dropout(dropout),
            nn.Linear(dim * mlp_ratio, dim),
            nn.Dropout(dropout),
        )

    def forward(self, x):
        a, _ = self.attn(self.ln1(x), self.ln1(x), self.ln1(x), need_weights=False)
        x = x + a
        x = x + self.mlp(self.ln2(x))
        return x
```

`nn.MultiheadAttention` 处理了拆分为多头、缩放点积和输出投影。`batch_first=True` 使形状为 `(N, seq, dim)`。

### 步骤 3：ViT

```python
class ViT(nn.Module):
    def __init__(self, image_size=64, patch_size=16, in_channels=3,
                 num_classes=10, dim=192, depth=6, num_heads=3, mlp_ratio=4):
        super().__init__()
        self.patch = PatchEmbedding(in_channels, patch_size, dim, image_size)
        num_patches = self.patch.num_patches
        self.cls_token = nn.Parameter(torch.zeros(1, 1, dim))
        self.pos_embed = nn.Parameter(torch.zeros(1, num_patches + 1, dim))
        self.blocks = nn.ModuleList([
            Block(dim, num_heads, mlp_ratio) for _ in range(depth)
        ])
        self.ln = nn.LayerNorm(dim)
        self.head = nn.Linear(dim, num_classes)
        nn.init.trunc_normal_(self.pos_embed, std=0.02)
        nn.init.trunc_normal_(self.cls_token, std=0.02)

    def forward(self, x):
        x = self.patch(x)
        cls = self.cls_token.expand(x.size(0), -1, -1)
        x = torch.cat([cls, x], dim=1)
        x = x + self.pos_embed
        for blk in self.blocks:
            x = blk(x)
        x = self.ln(x[:, 0])
        return self.head(x)

vit = ViT(image_size=64, patch_size=16, num_classes=10, dim=192, depth=6, num_heads=3)
x = torch.randn(2, 3, 64, 64)
print(f"输出: {vit(x).shape}")
print(f"参数: {sum(p.numel() for p in vit.parameters()):,}")
```

约 280 万参数——一个可以在 CPU 上运行的微型 ViT。真正的 ViT-B 是 8600 万；同样的类定义，设置 `dim=768, depth=12, num_heads=12`。

### 步骤 4：完整性检查——单张图像推理

```python
logits = vit(torch.randn(1, 3, 64, 64))
print(f"logits: {logits}")
print(f"概率:  {logits.softmax(-1)}")
```

应该运行无误。概率之和为 1。

## 使用

`timm` 提供所有 ViT 变体及 ImageNet 预训练权重。一行代码：

```python
import timm

model = timm.create_model("vit_base_patch16_224", pretrained=True, num_classes=10)
```

`timm` 是 2026 年视觉 transformer 的生产级默认选择。在同一套 API 下支持 ViT、DeiT、Swin、Swin-V2、ConvNeXt、ConvNeXt-V2、MaxViT、MViT、EfficientFormer 等几十种模型。

对于多模态工作（图像 + 文本），`transformers` 提供 CLIP、SigLIP、BLIP-2、LLaVA。所有这些模型中的图像编码器都是 ViT 变体。

## 交付物

本课产出：

- `outputs/prompt-vit-vs-cnn-picker.md`——一个 prompt，根据数据集大小、算力和推理栈在 ViT、ConvNeXt 或 Swin 之间做选择。
- `outputs/skill-vit-patch-and-pos-embed-inspector.md`——一个 skill，验证 ViT 的 patch embedding 和位置嵌入的形状是否与模型预期的序列长度匹配，捕获最常见的移植错误。

## 练习

1. **（简单）** 打印上述微型 ViT 前向传播中每个中间张量的形状。确认：输入 `(N, 3, 64, 64)` -> patches `(N, 16, 192)` -> 带 CLS `(N, 17, 192)` -> 分类器输入 `(N, 192)` -> 输出 `(N, num_classes)`。
2. **（中等）** 在 Lesson 4 的 synthetic-CIFAR 数据集上微调预训练的 `timm` ViT-S/16。与在同一数据上微调的 ResNet-18 进行比较。报告训练时间和最终准确率。
3. **（困难）** 为微型 ViT 实现 MAE 预训练：掩码 75% 的 patch，训练 encoder + 一个小 decoder 重建被掩码的 patch。评估预训练前后在合成数据上的 linear-probe 准确率。

## 关键术语

| 术语 | 别人说的 | 实际含义 |
|------|---------|---------|
| Patch embedding | "第一个卷积" | 卷积核大小 = 步长 = patch 大小的卷积；将图像转换为 token embedding 网格 |
| Class token | "[CLS]" | 前置到 token 序列的可学习向量；其最终输出是全局图像表示 |
| 位置嵌入 | "可学习 pos" | 加到每个 token 上的可学习向量，让 transformer 知道每个 patch 来自哪里 |
| Pre-LN | "LayerNorm 在子层之前" | 稳定的 transformer 变体：`x + sublayer(LN(x))` 而非 `LN(x + sublayer(x))` |
| 多头注意力 | "并行注意力" | 标准 transformer 注意力拆分为 num_heads 个独立子空间，然后拼接 |
| ViT-B/16 | "Base, patch 16" | 标准尺寸：dim=768, depth=12, heads=12, patch_size=16, image=224；约 86M 参数 |
| DeiT | "数据高效 ViT" | 仅使用 ImageNet-1k 加增强训练的 ViT；证明大规模预训练数据集并非严格必需 |
| MAE | "掩码自编码器" | 自监督预训练：掩码 75% 的 patch 然后重建；主流的 ViT 预训练方法 |

## 进一步阅读

- [An Image is Worth 16x16 Words (Dosovitskiy et al., 2020)](https://arxiv.org/abs/2010.11929) — ViT 论文
- [DeiT: Data-efficient Image Transformers (Touvron et al., 2020)](https://arxiv.org/abs/2012.12877) — 如何仅用 ImageNet-1k 训练 ViT
- [Masked Autoencoders are Scalable Vision Learners (He et al., 2022)](https://arxiv.org/abs/2111.06377) — MAE 预训练
- [timm 文档](https://huggingface.co/docs/timm) — 你在生产中使用每个视觉 transformer 的参考文档