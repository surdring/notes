# 图像检索与度量学习

> 检索系统按嵌入空间中的距离对候选项排序。度量学习是塑造那个空间使距离符合你意图的学科。

**类型：** 构建
**语言：** Python
**前置知识：** Phase 4 Lesson 14（ViT）、Phase 4 Lesson 18（CLIP）
**时间：** ~45 分钟

## 学习目标

- 解释 triplet、contrastive 和 proxy-based 度量学习损失，并为给定数据集选择正确的一个
- 正确实现 L2 归一化和余弦相似度，审计"同一物品"和"同一类别"检索之间的区别
- 构建 FAISS 索引，通过文本和图像查询，报告留出查询集的 recall@K
- 使用 DINOv2、CLIP 和 SigLIP 作为现成的嵌入骨干，知道每个何时胜出

## 问题

检索在生产视觉中无处不在：重复检测、反向图像搜索、视觉搜索（"查找相似产品"）、人脸再识别、监控中的人员再识别、电商的实例级匹配。产品问题始终相同："给定这张查询图像，对我的目录排序。"

两个设计决策决定整个系统。嵌入——什么模型产生向量。索引——如何在大规模上找到最近邻。两者在 2026 年都是商品（DINOv2 做嵌入，FAISS 做索引），这提高了门槛：困难的部分是定义*什么算作相似*对你的应用，然后塑造嵌入空间使距离匹配。

这种塑造就是度量学习。它是一门小而高杠杆的学科。

## 核心概念

### 检索一览

```mermaid
flowchart LR
    Q["查询图像<br/>或文本"] --> ENC["编码器"]
    ENC --> EMB["查询嵌入"]
    EMB --> IDX["FAISS 索引"]
    CAT["目录图像"] --> ENC2["编码器（相同）"] --> IDX_BUILD["构建索引"]
    IDX_BUILD --> IDX
    IDX --> RANK["按余弦/L2<br/>Top-k 最近邻"]
    RANK --> OUT["排序结果"]

    style ENC fill:#dbeafe,stroke:#2563eb
    style IDX fill:#fef3c7,stroke:#d97706
    style OUT fill:#dcfce7,stroke:#16a34a
```

### 四种损失家族

| 损失 | 需要 | 优点 | 缺点 |
|------|-----|------|------|
| **Contrastive** | (anchor, positive) + negatives | 简单，适用于任何对标签 | 没有很多负样本时收敛慢 |
| **Triplet** | (anchor, positive, negative) | 直观；直接控制 margin | 困难三元组挖掘代价高 |
| **NT-Xent / InfoNCE** | 对 + 批次内挖掘负样本 | 可扩展到大 batch | 需要大 batch 或动量队列 |
| **Proxy-based (ProxyNCA)** | 仅类别标签 | 快速、稳定、无需挖掘 | 在小数据集上可能对 proxy 过拟合 |

对于大多数生产用例，从预训练骨干开始，只有在现成嵌入在测试集上表现不佳时才添加度量学习微调。

### Triplet 损失的形式化

```
L = max(0, ||f(a) - f(p)||^2 - ||f(a) - f(n)||^2 + margin)
```

将 anchor `a` 拉近 positive `p`，将 `a` 推离 negative `n`，并有一个 `margin` 确保间隔。三图结构泛化到任何相似度排序。

挖掘很重要：简单三元组（`n` 已经离 `a` 很远）贡献零损失；只有困难三元组教会网络。半困难挖掘（`n` 比 `p` 远但在 margin 内）是 2016 年 FaceNet 的方法，至今仍占主导。

### 余弦相似度 vs L2

两种度量，两种约定：

- **余弦**：向量间的角度。需要 L2 归一化嵌入。
- **L2**：欧几里得距离。在原始或归一化嵌入上均可，但通常与 L2 归一化 + 平方 L2 配对。

对于大多数现代网络两者是等价的：当 `||a|| = ||b|| = 1` 时，`||a - b||^2 = 2 - 2 cos(a, b)`。选择与嵌入训练匹配的约定；混用会悄然改变"最近"的含义。

### Recall@K

标准检索指标：

```
recall@K = 查询中至少有一个正确匹配在前 K 个结果中的比例
```

并列报告 recall@1、@5、@10。recall@10 高于 0.95 而 recall@1 低于 0.5 说明嵌入空间结构正确但排序嘈杂——尝试更长的微调或重排序步骤。

对于重复检测，precision@K 更重要，因为每个假阳性都是用户可见的错误。对于视觉搜索，recall@K 是产品信号。

### FAISS 一图通

Facebook AI 相似度搜索。最近邻搜索的事实标准库。三种索引选择：

- `IndexFlatIP` / `IndexFlatL2`——暴力、精确、无需训练。最多用于约 100 万向量。
- `IndexIVFFlat`——划分为 K 个单元，仅搜索最近的几个单元。近似、快速、需要训练数据。
- `IndexHNSW`——基于图，查询最多时最快，索引大小大。

对于 10 万向量你可能想用 `IndexFlatIP` 做余弦相似度。对于 1000 万用 `IndexIVFFlat`。对于 1 亿以上结合乘积量化（`IndexIVFPQ`）。

### 实例级 vs 类别级检索

两个非常不同的问题，同名：

- **类别级**——"在我的目录中找猫"。类条件相似度；现成的 CLIP / DINOv2 嵌入效果好。
- **实例级**——"在我的目录中找*这个确切产品*"。需要对视觉相似的同类物体做细粒度区分；现成嵌入表现不佳；度量学习微调很重要。

在选择模型前始终问清楚你解决的是哪一种。

## 构建

### 步骤 1：Triplet 损失

```python
import torch
import torch.nn.functional as F

def triplet_loss(anchor, positive, negative, margin=0.2):
    d_ap = F.pairwise_distance(anchor, positive, p=2)
    d_an = F.pairwise_distance(anchor, negative, p=2)
    return F.relu(d_ap - d_an + margin).mean()
```

一行。在 L2 归一化或原始嵌入上均可工作。

### 步骤 2：半困难挖掘

给定一批嵌入和标签，为每个 anchor 找到最困难的半困难负样本。

```python
def semi_hard_negatives(emb, labels, margin=0.2):
    dist = torch.cdist(emb, emb)
    same_class = labels[:, None] == labels[None, :]
    diff_class = ~same_class
    N = emb.size(0)

    positives = dist.clone()
    positives[~same_class] = float("-inf")
    positives.fill_diagonal_(float("-inf"))
    pos_idx = positives.argmax(dim=1)

    semi_hard = dist.clone()
    semi_hard[same_class] = float("inf")
    d_ap = dist[torch.arange(N), pos_idx].unsqueeze(1)
    semi_hard[dist <= d_ap] = float("inf")
    neg_idx = semi_hard.argmin(dim=1)

    fallback_mask = semi_hard[torch.arange(N), neg_idx] == float("inf")
    if fallback_mask.any():
        hardest = dist.clone()
        hardest[same_class] = float("inf")
        neg_idx = torch.where(fallback_mask, hardest.argmin(dim=1), neg_idx)
    return pos_idx, neg_idx
```

每个 anchor 获得类内最困难的 positive 和一个比 positive 远但仍在 margin 内的半困难 negative。

### 步骤 3：Recall@K

```python
def recall_at_k(query_emb, gallery_emb, query_labels, gallery_labels, k=1):
    sim = query_emb @ gallery_emb.T
    _, top_k = sim.topk(k, dim=-1)
    matches = (gallery_labels[top_k] == query_labels[:, None]).any(dim=-1)
    return matches.float().mean().item()
```

L2 归一化嵌入上的 top-k 按内积等于 top-k 按余弦。报告至少有一个正确近邻的查询的平均比例。

### 步骤 4：组装

```python
import torch
import torch.nn as nn
from torch.optim import Adam

class Encoder(nn.Module):
    def __init__(self, in_dim=128, emb_dim=64):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(in_dim, 128), nn.ReLU(),
            nn.Linear(128, emb_dim),
        )

    def forward(self, x):
        return F.normalize(self.net(x), dim=-1)

torch.manual_seed(0)
num_classes = 6
protos = F.normalize(torch.randn(num_classes, 128), dim=-1)

def sample_batch(bs=32):
    labels = torch.randint(0, num_classes, (bs,))
    x = protos[labels] + 0.15 * torch.randn(bs, 128)
    return x, labels

enc = Encoder()
opt = Adam(enc.parameters(), lr=3e-3)

for step in range(200):
    x, y = sample_batch(32)
    emb = enc(x)
    pos_idx, neg_idx = semi_hard_negatives(emb, y)
    loss = triplet_loss(emb, emb[pos_idx], emb[neg_idx])
    opt.zero_grad(); loss.backward(); opt.step()
```

几百步后嵌入簇形成每个类别一个簇。

## 使用

2026 年的生产栈：

- **DINOv2 + FAISS**——通用视觉检索。开箱即用。
- **CLIP + FAISS**——当查询是文本时。
- **微调的 DINOv2 + FAISS**——实例级检索、人脸再识别、时尚、电商。
- **Milvus / Weaviate / Qdrant**——FAISS 或 HNSW 之上的托管向量数据库包装。

对于 SOTA 实例检索，方法是：DINOv2 骨干，添加嵌入头，在实例标注对上用 triplet 或 InfoNCE 损失微调，FAISS 索引。

## 交付物

本课产出：

- `outputs/prompt-retrieval-loss-picker.md`——一个 prompt，为给定的检索问题选择 triplet / InfoNCE / ProxyNCA。
- `outputs/skill-recall-at-k-runner.md`——一个 skill，为 recall@K 编写干净的评估框架，含训练/验证/库拆分和正确的数据契约。

## 练习

1. **（简单）** 运行上面的玩具示例。训练前后用 PCA 绘制嵌入图，观察六个簇的形成。
2. **（中等）** 添加 ProxyNCA 损失实现：每个类别一个可学习"proxy"，余弦相似度上的标准交叉熵。在玩具数据上比较与 triplet 损失的收敛速度。
3. **（困难）** 取 1000 张 ImageNet 验证图像，通过 HuggingFace 用 DINOv2 嵌入，构建 FAISS flat 索引，对同一批图像作为查询报告 recall@{1, 5, 10}（应该为 1.0），对留出拆分以 ImageNet 标签为真值报告。

## 关键术语

| 术语 | 别人说的 | 实际含义 |
|------|---------|---------|
| 度量学习 | "塑造空间" | 训练编码器使其输出空间中的距离反映目标相似度 |
| Triplet 损失 | "拉和推" | L = max(0, d(a, p) - d(a, n) + margin)；典型的度量学习损失 |
| 半困难挖掘 | "有用的负样本" | 比 anchor 到正样本远但在 margin 内的负样本；经验上信息量最大 |
| Proxy-based 损失 | "类别原型" | 每个类别一个可学习 proxy；与 proxy 相似度的交叉熵；无需对挖掘 |
| Recall@K | "Top-K 命中率" | 至少有一个正确结果在前 K 中的查询比例 |
| 实例检索 | "找这个确切的东西" | 细粒度匹配；现成特征通常表现不佳 |
| FAISS | "NN 库" | Facebook 的最近邻库；支持精确和近似索引 |
| HNSW | "图索引" | 层次可导航小世界图；快速近似 NN，内存开销小 |

## 进一步阅读

- [FaceNet: A Unified Embedding for Face Recognition (Schroff et al., 2015)](https://arxiv.org/abs/1503.03832) — triplet 损失 / 半困难挖掘论文
- [In Defense of the Triplet Loss for Person Re-Identification (Hermans et al., 2017)](https://arxiv.org/abs/1703.07737) — triplet 微调实用指南
- [FAISS 文档](https://github.com/facebookresearch/faiss/wiki) — 每种索引、每种权衡
- [SMoT: Metric Learning Taxonomy (Kim et al., 2021)](https://arxiv.org/abs/2010.06927) — 现代损失及其联系的综述