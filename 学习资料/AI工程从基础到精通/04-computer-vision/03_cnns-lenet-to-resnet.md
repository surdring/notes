# CNN — 从 LeNet 到 ResNet

> 过去三十年的每一个主要 CNN 都是同一个"卷积-非线性-下采样"配方加上一个新想法。按顺序学习这些想法。

**类型：** 学习 + 构建
**语言：** Python
**前置课程：** 阶段 3 第 11 课（PyTorch）、阶段 4 第 01 课（图像基础）、阶段 4 第 02 课（从零实现卷积）
**时间：** 约 75 分钟

## 学习目标

- 梳理架构谱系 LeNet-5 -> AlexNet -> VGG -> Inception -> ResNet，并说出每个家族贡献的单一新想法
- 在 PyTorch 中实现 LeNet-5、VGG 风格的块和 ResNet BasicBlock，每个不超过 40 行代码
- 解释为什么残差连接将一个 1,000 层的网络从不训练的变成了最先进的
- 阅读现代骨干网络（ResNet-18、ResNet-50）并在查看源码之前预测其输出形状、感受野和参数数量

## 问题

2011 年，最好的 ImageNet 分类器 top-5 准确率约为 74%。2012 年 AlexNet 达到 85%。2015 年 ResNet 达到 96%。没有新数据，没有新一代 GPU。增益来自架构思想。一个合格工作的视觉工程师必须知道哪个想法来自哪篇论文，因为你在 2026 年交付的每个生产级骨干网络都是这些相同组件的重新组合——而且因为这些思想在不断迁移：分组卷积从 CNN 走向了 Transformer，残差连接从 ResNet 走向了每一个存在的 LLM，批归一化则存在于扩散模型中。

按顺序研究这些网络还能让你对一种常见错误免疫：在 LeNet 规模就能解决问题时伸手去拿最大的模型。MNIST 不需要 ResNet。了解每个家族的缩放曲线告诉你应该坐在曲线的哪个位置。

## 概念

### 改变视觉的四个想法

```mermaid
timeline
    title 四个想法，四个家族
    1998 : LeNet-5 : 用于数字识别的 Conv + pool + FC，在 CPU 上训练，6 万参数
    2012 : AlexNet : 更深 + ReLU + dropout + 双 GPU，ImageNet 领先 10 个点
    2014 : VGG / Inception : 3x3 堆叠（VGG），并行滤波器尺寸（Inception）
    2015 : ResNet : 恒等跳跃连接解锁 100+ 层训练
```

在经典视觉中，没有其他东西像这四个跳跃一样重要。

### LeNet-5 (1998)

Yann LeCun 的数字识别器。60,000 个参数。两个 conv-pool 块，两个全连接层，tanh 激活。它定义了每个 CNN 继承的模板：

```
输入 (1, 32, 32)
  conv 5x5 -> (6, 28, 28)
  avg pool 2x2 -> (6, 14, 14)
  conv 5x5 -> (16, 10, 10)
  avg pool 2x2 -> (16, 5, 5)
  展平 -> 400
  密集层 -> 120
  密集层 -> 84
  密集层 -> 10
```

现代世界称之为 CNN 的一切——交替的卷积和下采样，喂给一个小分类头——都是 LeNet，只是有更多层、更大的通道数和更好的激活函数。

### AlexNet (2012)

三个共同打破 ImageNet 的改变：

1. **ReLU** 替代 tanh。梯度不再消失。训练速度提升六倍。
2. **Dropout** 在全连接头中。正则化变成一个层，而不是一个技巧。
3. **深度和宽度**。五个卷积层，三个密集层，6,000 万参数，在两个 GPU 上训练，模型分拆到两个 GPU 上。

论文的 Figure 2 仍然将 GPU 分拆表示为两条并行流。那个并行性是硬件绕行方案，不是架构洞见——但上面的三个想法仍然存在于你使用的每个模型中。

### VGG (2014)

VGG 问：如果只使用 3x3 卷积并且往深了走，会发生什么？

```
堆叠：   conv 3x3 -> conv 3x3 -> pool 2x2
重复：   16 或 19 个卷积层
```

两个 3x3 卷积看到的 5x5 输入区域与一个 5x5 卷积相同，但参数更少（2*9*C^2 = 18C^2 vs 25*C^2），且中间多了一个 ReLU。VGG 将这个观察变成了整个架构。其简洁性——一种块类型，重复使用——使其成为之后一切事物的参考点。

代价：1.38 亿参数，训练慢，推理昂贵。

### Inception (2014，同年)

Google 对"应该用什么卷积核尺寸？"的回答是：全都要，并行使用。

```mermaid
flowchart LR
    IN["输入特征图"] --> A["1x1 conv"]
    IN --> B["3x3 conv"]
    IN --> C["5x5 conv"]
    IN --> D["3x3 max pool"]
    A --> CAT["沿通道轴<br/>拼接"]
    B --> CAT
    C --> CAT
    D --> CAT
    CAT --> OUT["下一个块"]

    style IN fill:#dbeafe,stroke:#2563eb
    style CAT fill:#fef3c7,stroke:#d97706
    style OUT fill:#dcfce7,stroke:#16a34a
```

每个分支专业化——1x1 用于通道混合，3x3 用于局部纹理，5x5 用于更大模式，池化用于平移不变特征——拼接让下一层可以选择哪个分支有用。Inception v1 在每个分支内使用 1x1 卷积作为瓶颈，以保持参数数量合理。

### 退化问题

到 2015 年，VGG-19 有效，而 VGG-32 无效。深度本应有帮助，但超过约 20 层后，训练损失和测试损失都变差了。这不是过拟合。这是优化器无法找到有用的权重，因为梯度在每一层乘法级地缩小。

```
普通深度网络：
  y = f_L( f_{L-1}( ... f_1(x) ... ) )

相对于早期层的梯度：
  dL/dW_1 = dL/dy * df_L/df_{L-1} * ... * df_2/df_1 * df_1/dW_1

每个乘法项的幅度大致是（权重幅度）*（激活增益）。
堆叠 100 个增益小于 1 的项，梯度实际上为零。
```

VGG 在 19 层有效是因为批归一化（同时发表）保持了激活的良好缩放。但即便是批归一化也无法拯救超过约 30 层的深度。

### ResNet (2015)

He, Zhang, Ren, Sun 提出了一个修复一切的改变：

```
标准块：   y = F(x)
残差块：   y = F(x) + x
```

`+ x` 意味着层始终可以通过将 `F(x)` 驱动到零来选择什么也不做。一个 1,000 层的 ResNet 现在最多只和一个 1 层网络一样差，因为每个额外的块都有一个平凡的逃生舱口。有了这种保证，优化器愿意让每个块**稍微**有用——而稍微有用，堆叠 100 次，就是最先进的。

```mermaid
flowchart LR
    X["输入 x"] --> F["F(x)<br/>conv + BN + ReLU<br/>conv + BN"]
    X -.->|恒等跳跃| PLUS(["+"])
    F --> PLUS
    PLUS --> RELU["ReLU"]
    RELU --> OUT["y"]

    style X fill:#dbeafe,stroke:#2563eb
    style PLUS fill:#fef3c7,stroke:#d97706
    style OUT fill:#dcfce7,stroke:#16a34a
```

块的两种变体随处可见：

- **BasicBlock**（ResNet-18、ResNet-34）：两个 3x3 卷积，跳跃连接绕过两者。
- **Bottleneck**（ResNet-50、-101、-152）：1x1 降维，3x3 中间，1x1 升维，跳跃连接绕过三者。在通道数高时更便宜。

当跳跃连接需要跨过下采样（步长=2）时，恒等路径被替换为 1x1 步长=2 的卷积以匹配形状。

### 为什么残差在视觉之外也重要

这个想法并非真的关于图像分类。它是关于将深度网络从"双手合十祈祷梯度能存活"变成可靠、可扩展的工程工具。你在下个阶段将要阅读的每个 Transformer 在每个块中都有一模一样的跳跃连接。没有 ResNet，就没有 GPT。

## 构建它

### 步骤 1：LeNet-5

一个最小、忠实的 LeNet。Tanh 激活，平均池化。唯一对现代的妥协是我们在下游使用 `nn.CrossEntropyLoss` 而非原始的 Gaussian 连接。

```python
import torch
import torch.nn as nn
import torch.nn.functional as F

class LeNet5(nn.Module):
    def __init__(self, num_classes=10):
        super().__init__()
        self.conv1 = nn.Conv2d(1, 6, kernel_size=5)
        self.conv2 = nn.Conv2d(6, 16, kernel_size=5)
        self.pool = nn.AvgPool2d(2)
        self.fc1 = nn.Linear(16 * 5 * 5, 120)
        self.fc2 = nn.Linear(120, 84)
        self.fc3 = nn.Linear(84, num_classes)

    def forward(self, x):
        x = self.pool(torch.tanh(self.conv1(x)))
        x = self.pool(torch.tanh(self.conv2(x)))
        x = torch.flatten(x, 1)
        x = torch.tanh(self.fc1(x))
        x = torch.tanh(self.fc2(x))
        return self.fc3(x)

net = LeNet5()
x = torch.randn(1, 1, 32, 32)
print(f"output: {net(x).shape}")
print(f"params: {sum(p.numel() for p in net.parameters()):,}")
```

预期输出：`output: torch.Size([1, 10])`，`params: 61,706`。这就是开启了现代视觉的整个数字分类器。

### 步骤 2：一个 VGG 块

一个可复用的块：两个 3x3 卷积，ReLU，批归一化，最大池化。

```python
class VGGBlock(nn.Module):
    def __init__(self, in_c, out_c):
        super().__init__()
        self.conv1 = nn.Conv2d(in_c, out_c, kernel_size=3, padding=1)
        self.bn1 = nn.BatchNorm2d(out_c)
        self.conv2 = nn.Conv2d(out_c, out_c, kernel_size=3, padding=1)
        self.bn2 = nn.BatchNorm2d(out_c)
        self.pool = nn.MaxPool2d(2)

    def forward(self, x):
        x = F.relu(self.bn1(self.conv1(x)))
        x = F.relu(self.bn2(self.conv2(x)))
        return self.pool(x)

class MiniVGG(nn.Module):
    def __init__(self, num_classes=10):
        super().__init__()
        self.stack = nn.Sequential(
            VGGBlock(3, 32),
            VGGBlock(32, 64),
            VGGBlock(64, 128),
        )
        self.head = nn.Sequential(
            nn.AdaptiveAvgPool2d(1),
            nn.Flatten(),
            nn.Linear(128, num_classes),
        )

    def forward(self, x):
        return self.head(self.stack(x))

net = MiniVGG()
x = torch.randn(1, 3, 32, 32)
print(f"output: {net(x).shape}")
print(f"params: {sum(p.numel() for p in net.parameters()):,}")
```

三个 VGG 块在 CIFAR 大小的输入上，一个自适应池化，一个线性层。约 29 万参数。对 CIFAR-10 来说足够。

### 步骤 3：一个 ResNet BasicBlock

ResNet-18 和 ResNet-34 的核心构建块。

```python
class BasicBlock(nn.Module):
    def __init__(self, in_c, out_c, stride=1):
        super().__init__()
        self.conv1 = nn.Conv2d(in_c, out_c, kernel_size=3, stride=stride, padding=1, bias=False)
        self.bn1 = nn.BatchNorm2d(out_c)
        self.conv2 = nn.Conv2d(out_c, out_c, kernel_size=3, stride=1, padding=1, bias=False)
        self.bn2 = nn.BatchNorm2d(out_c)
        if stride != 1 or in_c != out_c:
            self.shortcut = nn.Sequential(
                nn.Conv2d(in_c, out_c, kernel_size=1, stride=stride, bias=False),
                nn.BatchNorm2d(out_c),
            )
        else:
            self.shortcut = nn.Identity()

    def forward(self, x):
        out = F.relu(self.bn1(self.conv1(x)))
        out = self.bn2(self.conv2(out))
        out = out + self.shortcut(x)
        return F.relu(out)
```

卷积层上的 `bias=False` 是批归一化约定——BN 的 beta 参数已经处理了偏置，所以再带一个卷积偏置是浪费。`shortcut` 只在步长或通道数改变时需要真正的卷积；否则它是一个无操作的恒等映射。

### 步骤 4：一个微型 ResNet

堆叠四组 BasicBlock 来得到一个用于 CIFAR 大小输入的工作 ResNet。

```python
class TinyResNet(nn.Module):
    def __init__(self, num_classes=10):
        super().__init__()
        self.stem = nn.Sequential(
            nn.Conv2d(3, 32, kernel_size=3, stride=1, padding=1, bias=False),
            nn.BatchNorm2d(32),
            nn.ReLU(inplace=True),
        )
        self.layer1 = self._make_group(32, 32, num_blocks=2, stride=1)
        self.layer2 = self._make_group(32, 64, num_blocks=2, stride=2)
        self.layer3 = self._make_group(64, 128, num_blocks=2, stride=2)
        self.layer4 = self._make_group(128, 256, num_blocks=2, stride=2)
        self.head = nn.Sequential(
            nn.AdaptiveAvgPool2d(1),
            nn.Flatten(),
            nn.Linear(256, num_classes),
        )

    def _make_group(self, in_c, out_c, num_blocks, stride):
        blocks = [BasicBlock(in_c, out_c, stride=stride)]
        for _ in range(num_blocks - 1):
            blocks.append(BasicBlock(out_c, out_c, stride=1))
        return nn.Sequential(*blocks)

    def forward(self, x):
        x = self.stem(x)
        x = self.layer1(x)
        x = self.layer2(x)
        x = self.layer3(x)
        x = self.layer4(x)
        return self.head(x)

net = TinyResNet()
x = torch.randn(1, 3, 32, 32)
print(f"output: {net(x).shape}")
print(f"params: {sum(p.numel() for p in net.parameters()):,}")
```

四组，每组两个块。步长 2 在组 2、3、4 的开始处。通道数在每次下采样时翻倍。约 280 万参数。这是干净地扩展到 ResNet-152 的标准配方。

### 步骤 5：比较参数到特征的效率

通过所有三个网络运行相同输入并比较参数数量。

```python
def summary(name, net, x):
    y = net(x)
    params = sum(p.numel() for p in net.parameters())
    print(f"{name:12s}  input {tuple(x.shape)} -> output {tuple(y.shape)}  params {params:>10,}")

x = torch.randn(1, 3, 32, 32)
summary("LeNet5",     LeNet5(),       torch.randn(1, 1, 32, 32))
summary("MiniVGG",    MiniVGG(),      x)
summary("TinyResNet", TinyResNet(),   x)
```

三个模型，三个时代，三个数量级的参数数量。对于 CIFAR-10 准确率，经过几轮训练你大约需要：LeNet 60%，MiniVGG 89%，TinyResNet 93%。

## 使用它

`torchvision.models` 给你上述所有模型的预训练版本。调用签名在不同家族之间相同，这正是骨干网络抽象的意义所在。

```python
from torchvision.models import resnet18, ResNet18_Weights, vgg16, VGG16_Weights

r18 = resnet18(weights=ResNet18_Weights.IMAGENET1K_V1)
r18.eval()

print(f"ResNet-18 params: {sum(p.numel() for p in r18.parameters()):,}")
print(r18.layer1[0])
print()

v16 = vgg16(weights=VGG16_Weights.IMAGENET1K_V1)
v16.eval()
print(f"VGG-16   params: {sum(p.numel() for p in v16.parameters()):,}")
```

ResNet-18 有 1170 万参数。VGG-16 有 1.38 亿。相似的 ImageNet top-1 准确率（69.8% vs 71.6%）。残差连接给你带来了 12 倍的参数效率优势。这就是为什么 ResNet 变体从 2016 年到 2021 年 ViT 出现之前一直占主导——并且在计算受限的实际部署中仍然占主导。

对于迁移学习，配方始终相同：加载预训练，冻结骨干网络，替换分类头。

```python
for p in r18.parameters():
    p.requires_grad = False
r18.fc = nn.Linear(r18.fc.in_features, 10)
```

三行代码。你现在有了一个 10 类 CIFAR 分类器，它继承了 ImageNet 付费获得的表示。

## 交付它

本课产出：

- `outputs/prompt-backbone-selector.md` — 一个提示词，给定任务、数据集大小和计算预算，选择正确的 CNN 家族（LeNet/VGG/ResNet/MobileNet/ConvNeXt）。
- `outputs/skill-residual-block-reviewer.md` — 一个技能，读取 PyTorch 模块并标记跳跃连接错误（步长改变时缺少 shortcut、shortcut 激活顺序、相对于加法的 BN 放置）。

## 练习

1. **（简单）** 逐层手算 `TinyResNet` 的参数数量。与 `sum(p.numel() for p in net.parameters())` 比较。大部分参数预算去了哪里——卷积、BN 还是分类头？
2. **（中等）** 实现 Bottleneck 块（带跳跃连接的 1x1 -> 3x3 -> 1x1），并用它为 CIFAR 构建一个 ResNet-50 风格的网络。与 `TinyResNet` 比较参数数量。
3. **（困难）** 从 `BasicBlock` 中移除跳跃连接，在 CIFAR-10 上各训练 10 轮的 34 块"普通"网络和 34 块 ResNet。绘制两者的训练损失 vs 轮数图。复现 He et al. 的 Figure 1 结果，即普通深度网络收敛到比其较浅孪生网络更高的损失。

## 关键术语

| 术语 | 人们怎么说 | 它实际意味着什么 |
|------|-----------|----------------|
| 骨干网络 | "模型" | 生成喂给任务头的特征图的卷积块堆叠 |
| 残差连接 | "跳跃连接" | `y = F(x) + x`；让优化器可以通过将 F 设为零来学习恒等映射，使任意深度变得可训练 |
| BasicBlock | "两个 3x3 卷积加一个跳跃" | ResNet-18/34 的构建块：conv-BN-ReLU-conv-BN-add-ReLU |
| Bottleneck | "1x1 降，3x3，1x1 升" | ResNet-50/101/152 的块；在高通道数时便宜，因为 3x3 在缩小的宽度上运行 |
| 退化问题 | "更深更差" | 超过约 20 个普通卷积层后，训练和测试误差都增加；由残差连接解决，而非更多数据 |
| Stem | "第一层" | 将 3 通道输入转换为基础特征宽度的初始卷积；ImageNet 通常为 7x7 步长 2，CIFAR 为 3x3 步长 1 |
| 头 | "分类器" | 最终骨干块之后的层：自适应池化、展平、线性层 |
| 迁移学习 | "预训练权重" | 加载在 ImageNet 上训练的骨干网络，仅在你的任务上微调头部 |

## 进一步阅读

- [Deep Residual Learning for Image Recognition (He et al., 2015)](https://arxiv.org/abs/1512.03385) — ResNet 论文；每个图都值得研究
- [Very Deep Convolutional Networks (Simonyan & Zisserman, 2014)](https://arxiv.org/abs/1409.1556) — VGG 论文；仍然是"为什么用 3x3"的最佳参考资料
- [ImageNet Classification with Deep CNNs (Krizhevsky et al., 2012)](https://papers.nips.cc/paper_files/paper/2012/hash/c399862d3b9d6b76c8436e924a68c45b-Abstract.html) — AlexNet；结束了手工特征时代的论文
- [Going Deeper with Convolutions (Szegedy et al., 2014)](https://arxiv.org/abs/1409.4842) — Inception v1；在视觉 Transformer 中仍然出现的并行滤波器思想