# 文本 CNN 与 RNN

> 卷积学习 n-gram。循环记住上下文。两者都被注意力取代了。两者在受限硬件上仍然重要。

**类型：** 构建
**语言：** Python
**前置要求：** 第 3 阶段 · 11（PyTorch 入门），第 5 阶段 · 03（词嵌入），第 4 阶段 · 02（从零实现卷积）
**时间：** 约 75 分钟

## 问题

TF-IDF 和 Word2Vec 产生的是忽略词序的平坦向量。基于它们构建的分类器无法区分 `dog bites man` 和 `man bites dog`。词序有时承载着信号。

在 Transformer 出现之前，有两类架构填补了这个空白。

**文本卷积网络（TextCNN）。** 在词嵌入序列上应用一维卷积。宽度为 3 的滤波器是一个可学习的三元组检测器：它跨越三个词并输出一个分数。堆叠不同宽度（2、3、4、5）来检测多尺度模式。最大池化到固定大小的表示。扁平、并行、快速。

**循环网络（RNN、LSTM、GRU）。** 逐标记处理，维护一个携带信息向前传递的隐藏状态。顺序执行、具有记忆能力、支持灵活的输入长度。从 2014 年到 2017 年主导了序列建模，然后注意力出现了。

本课构建两者，然后指出促使注意力出现的失败点。

## 概念

**TextCNN**（Kim, 2014）。标记被嵌入。宽度为 `k` 的一维卷积在连续的 `k`-gram 嵌入上滑动滤波器，产生特征图。对该特征图进行全局最大池化，选出最强的激活值。拼接来自多个滤波器宽度的最大池化输出。送入分类头。

为什么有效。一个滤波器就是一个可学习的 n-gram。最大池化是位置不变的，所以 "not good" 无论出现在评论的开头还是中间，都会激活相同的特征。三个滤波器宽度，每个 100 个滤波器，共 300 个可学习的 n-gram 检测器。训练是并行的；没有顺序依赖。

**RNN。** 在每个时间步 `t`，隐藏状态 `h_t = f(W * x_t + U * h_{t-1} + b)`。`W`、`U`、`b` 跨时间共享。时间步 `T` 的隐藏状态是整个前缀的摘要。对于分类任务，在 `h_1 ... h_T` 上进行池化（最大池化、平均池化或取最后一个）。

普通 RNN 存在梯度消失问题。**LSTM** 添加了门来控制遗忘什么、存储什么和输出什么，从而稳定了长序列中的梯度。**GRU** 将 LSTM 简化为两个门；性能相近，参数更少。

**双向 RNN** 同时运行一个前向 RNN 和一个后向 RNN，拼接隐藏状态。每个标记的表示同时看到左右两侧的上下文。对标注任务至关重要。

## 构建

### 步骤 1：PyTorch 中的 TextCNN

```python
import torch
import torch.nn as nn
import torch.nn.functional as F


class TextCNN(nn.Module):
    def __init__(self, vocab_size, embed_dim, n_classes, filter_widths=(2, 3, 4), n_filters=64, dropout=0.3):
        super().__init__()
        self.embed = nn.Embedding(vocab_size, embed_dim, padding_idx=0)
        self.convs = nn.ModuleList([
            nn.Conv1d(embed_dim, n_filters, kernel_size=k)
            for k in filter_widths
        ])
        self.dropout = nn.Dropout(dropout)
        self.fc = nn.Linear(n_filters * len(filter_widths), n_classes)

    def forward(self, token_ids):
        x = self.embed(token_ids).transpose(1, 2)
        pooled = []
        for conv in self.convs:
            c = F.relu(conv(x))
            p = F.max_pool1d(c, c.size(2)).squeeze(2)
            pooled.append(p)
        h = torch.cat(pooled, dim=1)
        return self.fc(self.dropout(h))
```

`transpose(1, 2)` 将 `[batch, seq_len, embed_dim]` 转换为 `[batch, embed_dim, seq_len]`，因为 `nn.Conv1d` 将中间轴视为通道。池化后的输出是固定大小的，不受输入长度影响。

### 步骤 2：LSTM 分类器

```python
class LSTMClassifier(nn.Module):
    def __init__(self, vocab_size, embed_dim, hidden_dim, n_classes, bidirectional=True, dropout=0.3):
        super().__init__()
        self.embed = nn.Embedding(vocab_size, embed_dim, padding_idx=0)
        self.lstm = nn.LSTM(embed_dim, hidden_dim, batch_first=True, bidirectional=bidirectional)
        factor = 2 if bidirectional else 1
        self.dropout = nn.Dropout(dropout)
        self.fc = nn.Linear(hidden_dim * factor, n_classes)

    def forward(self, token_ids):
        x = self.embed(token_ids)
        out, _ = self.lstm(x)
        pooled = out.max(dim=1).values
        return self.fc(self.dropout(pooled))
```

在序列上进行最大池化，而不是取最后一个状态的池化。对于分类任务，最大池化通常优于取最后一个隐藏状态，因为长序列末尾的信息往往主导最后一状态。

### 步骤 3：梯度消失演示（直观理解）

没有门控的普通 RNN 无法学习长距离依赖。考虑一个玩具任务：预测标记 `A` 是否出现在序列中的任何位置。如果 `A` 在位置 1，序列长度为 100，那么损失的梯度必须通过 99 次循环权重的乘法反向传播。如果权重小于 1，梯度消失。如果大于 1，梯度爆炸。

```python
def vanishing_gradient_sim(seq_len, recurrent_weight=0.9):
    import math
    return math.pow(recurrent_weight, seq_len)


# 权重 0.9，100 步：
#   0.9 ^ 100 ≈ 2.7e-5
# 从第 100 步到第 1 步的梯度几乎为零。
```

LSTM 通过一个**细胞状态**来解决这个问题，该状态在仅有加法交互的网络中传递（遗忘门对其做乘法缩放，但梯度仍然沿着这条"高速公路"流动）。GRU 用更少的参数做了类似的事情。两者都能让你在 100+ 步的序列中稳定训练。

### 步骤 4：为什么这仍然不够

即使有了 LSTM，仍然存在三个问题。

1. **顺序瓶颈。** 在长度为 1000 的序列上训练 RNN 需要 1000 次串行的前向/反向步骤。无法跨时间并行。
2. **编码器-解码器设置中的固定大小上下文向量。** 解码器只能看到编码器的最终隐藏状态，压缩了整个输入。长输入丢失细节。第 09 课直接讨论这个问题。
3. **远距离依赖的准确率上限。** LSTM 优于普通 RNN，但仍然难以在 200+ 步中传播特定信息。

注意力解决了所有三个问题。Transformer 完全放弃了循环。第 10 课是关键转折点。

## 使用

PyTorch 的 `nn.LSTM`、`nn.GRU` 和 `nn.Conv1d` 都是生产可用的。训练代码是标准的。

Hugging Face 提供预训练嵌入，你可以将其作为输入层插入：

```python
from transformers import AutoModel

encoder = AutoModel.from_pretrained("bert-base-uncased")
for param in encoder.parameters():
    param.requires_grad = False


class BertCNN(nn.Module):
    def __init__(self, n_classes, filter_widths=(2, 3, 4), n_filters=64):
        super().__init__()
        self.encoder = encoder
        self.convs = nn.ModuleList([nn.Conv1d(768, n_filters, kernel_size=k) for k in filter_widths])
        self.fc = nn.Linear(n_filters * len(filter_widths), n_classes)

    def forward(self, input_ids, attention_mask):
        with torch.no_grad():
            out = self.encoder(input_ids=input_ids, attention_mask=attention_mask).last_hidden_state
        x = out.transpose(1, 2)
        pooled = [F.max_pool1d(F.relu(conv(x)), kernel_size=conv(x).size(2)).squeeze(2) for conv in self.convs]
        return self.fc(torch.cat(pooled, dim=1))
```

根据约束选择架构的清单。

- **边缘/设备端推理。** 带 GloVe 嵌入的 TextCNN 比 Transformer 小 10-100 倍。如果你的部署目标是手机，这就是你的技术栈。
- **流式/在线分类。** RNN 逐标记处理；Transformer 需要完整序列。对于实时传入的文本，LSTM 仍然胜出。
- **用于基线的微型模型。** 在新任务上快速迭代。在 CPU 上 5 分钟训练一个 TextCNN。
- **有限数据的序列标注。** BiLSTM-CRF（第 06 课）仍然是 1k-10k 标注句子的生产级 NER 架构。

其他所有情况都用 Transformer。

## 交付

保存为 `outputs/prompt-text-encoder-picker.md`：

```markdown
---
name: text-encoder-picker
description: 为给定的约束集选择文本编码器架构。
phase: 5
lesson: 08
---

给定约束条件（任务、数据量、延迟预算、部署目标、计算预算），输出：

1. 编码器架构：TextCNN、BiLSTM、BiLSTM-CRF、Transformer 微调，或"使用预训练 Transformer 作为冻结编码器 + 小型分类头"。
2. 嵌入输入：随机初始化、GloVe/fastText 冻结，或上下文 Transformer 嵌入。
3. 5 行训练配方：优化器、学习率、批次大小、轮数、正则化。
4. 一个监控信号。对于 RNN/CNN 模型：注意力机制的缺失意味着它们会遗漏长距离依赖；检查按长度划分的准确率。对于 Transformer：学习率过高会导致微调坍塌；检查训练损失。

拒绝在数据少于约 500 个标注样本且未展示 TextCNN/BiLSTM 基线已经停滞的情况下推荐微调 Transformer。将边缘部署标记为需要"架构优先于一切"。
```

## 练习

1. **简单。** 在一个 3 分类的玩具数据集（你自己造数据）上训练 TextCNN。验证滤波器宽度 (2, 3, 4) 在平均 F1 上优于单一宽度 (3)。
2. **中等。** 对 LSTM 分类器实现最大池化、平均池化和取最后状态池化。在小型数据集上比较；记录哪种池化胜出并假设原因。
3. **困难。** 构建一个 BiLSTM-CRF NER 标注器（结合第 06 课和本课）。在 CoNLL-2003 上训练。与第 06 课的 CRF 单独基线和 BERT 微调对比。报告训练时间、内存和 F1。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| TextCNN | 文本 CNN | 在词嵌入上堆叠一维卷积并全局最大池化。Kim (2014)。 |
| RNN | 循环网络 | 每个时间步更新隐藏状态：`h_t = f(W x_t + U h_{t-1})`。 |
| LSTM | 门控 RNN | 添加输入/遗忘/输出门 + 细胞状态。在长序列中稳定训练。 |
| GRU | 更简单的 LSTM | 两个门而非三个。准确率相近，参数更少。 |
| 双向 | 双向 | 前向 + 后向 RNN 拼接。每个标记看到其上下文的两侧。 |
| 梯度消失 | 训练信号消失 | 普通 RNN 中反复乘以 <1 的权重使早期步的梯度几乎为零。 |

## 扩展阅读

- [Kim, Y. (2014). Convolutional Neural Networks for Sentence Classification](https://arxiv.org/abs/1408.5882)——TextCNN 论文。八页。可读性强。
- [Hochreiter, S. and Schmidhuber, J. (1997). Long Short-Term Memory](https://www.bioinf.jku.at/publications/older/2604.pdf)——LSTM 论文。出人意料地清晰。
- [Olah, C. (2015). Understanding LSTM Networks](https://colah.github.io/posts/2015-08-Understanding-LSTMs/)——让 LSTM 对所有人都可理解的图解。