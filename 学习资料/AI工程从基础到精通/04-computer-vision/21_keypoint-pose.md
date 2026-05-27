# 关键点检测与姿态估计

> 姿态是一组有序的关键点。关键点检测器是一个热力图回归器。其余都是记账工作。

**类型：** 构建
**语言：** Python
**前置知识：** Phase 4 Lesson 06（检测）、Phase 4 Lesson 07（U-Net）
**时间：** ~45 分钟

## 学习目标

- 区分自顶向下和自底向上的姿态估计，并说明各自的适用场景
- 用每个关键点的高斯目标回归 K 个关键点的热力图，并在推理时提取关键点坐标
- 解释部件亲和场（PAFs）以及自底向上管线如何将关键点关联到实例
- 使用 MediaPipe Pose 或 MMPose 进行生产级关键点估计并理解其输出格式

## 问题

关键点任务隐藏在许多名称之下：人体姿态（17 个身体关节）、面部关键点（68 或 478 个点）、手部（21 个点）、动物姿态、机器人物体姿态、医学解剖标志。它们都共享相同的结构：检测物体上的 K 个离散点并输出其 (x, y) 坐标。

姿态估计是动作捕捉、健身应用、体育分析、手势控制、动画、AR 试穿和机器人抓取的基础。2D 情况已成熟；3D 姿态（从单个相机估计世界坐标中的关节位置）是当前研究前沿。

工程问题是规模。单图像、单人的姿态是一个 20ms 的问题。30 fps 下人群中的多人姿态是一个不同的问题，有不同的架构。

## 核心概念

### 自顶向下 vs 自底向上

```mermaid
flowchart LR
    subgraph TD["自顶向下管线"]
        A1["检测人体框"] --> A2["裁剪每个框"]
        A2 --> A3["每框关键点模型<br/>(HRNet, ViTPose)"]
    end
    subgraph BU["自底向上管线"]
        B1["一次遍历图像"] --> B2["所有关键点热力图<br/>+ 关联场"]
        B2 --> B3["将关键点分组为<br/>实例（贪心匹配）"]
    end

    style TD fill:#dbeafe,stroke:#2563eb
    style BU fill:#fef3c7,stroke:#d97706
```

- **自顶向下**——先检测人，然后在每个裁剪上运行每人的关键点模型。准确率最高；延迟随人数线性增长。
- **自底向上**——一次前向传播预测所有关键点加关联场；然后分组。无论人群大小耗时恒定。

自顶向下（HRNet、ViTPose）是准确率领先者；自底向上（OpenPose、HigherHRNet）在拥挤场景中是吞吐量领先者。

### 热力图回归

不直接回归 `(x, y)`，而是预测每个关键点的 `H x W` 热力图，在真实位置中心放置高斯斑。

```
target[k, y, x] = exp(-((x - cx_k)^2 + (y - cy_k)^2) / (2 sigma^2))
```

推理时，每个热力图的 argmax 就是预测的关键点位置。

为什么热力图比直接回归效果更好：网络的空间结构（卷积特征图）与空间输出天然对齐。高斯目标也提供正则化——小的定位误差产生小的损失，而非零。

### 亚像素定位

Argmax 给出整数坐标。对于亚像素精度，通过在 argmax 及其邻居上拟合抛物线来细化，或使用众所周知的偏移方向 `(dx, dy) = 0.25 * (heatmap[y, x+1] - heatmap[y, x-1], ...)`。

### 部件亲和场（PAFs）

OpenPose 用于自底向上关联的技巧。对于每对连接的关键点（如左肩到左肘），预测一个 2 通道场，编码从一个指向另一个的单位向量。要将肩与肘关联，沿连接候选对的线积分 PAF；积分最高的对被匹配。

```
对于每个连接（肢体）：
  PAF 通道：2（单位向量 x, y）
  线积分：沿采样点的 (PAF . 线方向) 求和
  更高的积分 = 更强的匹配
```

优雅且可扩展到任意人群规模，无需每人的裁剪。

### COCO 关键点

标准人体姿态数据集：每人 17 个关键点，PCK（Percentage of Correct Keypoints）和 OKS（Object Keypoint Similarity）作为指标。OKS 是关键点领域的 IoU 类比，也是 COCO mAP@OKS 报告的指标。

### 2D vs 3D

- **2D 姿态**——图像坐标；已达到生产级质量（MediaPipe、HRNet、ViTPose）。
- **3D 姿态**——世界 / 相机坐标；仍是活跃研究领域。常见方法：
  - 用小 MLP 将 2D 预测提升到 3D（VideoPose3D）。
  - 从图像直接回归 3D（PyMAF、MHFormer）。
  - 多视图设置（CMU Panoptic）获取真值。

## 构建

### 步骤 1：高斯热力图目标

```python
import numpy as np
import torch

def gaussian_heatmap(size, cx, cy, sigma=2.0):
    yy, xx = np.meshgrid(np.arange(size), np.arange(size), indexing="ij")
    return np.exp(-((xx - cx) ** 2 + (yy - cy) ** 2) / (2 * sigma ** 2)).astype(np.float32)

hm = gaussian_heatmap(64, 32, 32, sigma=2.0)
print(f"peak: {hm.max():.3f} at ({hm.argmax() % 64}, {hm.argmax() // 64})")
```

每个关键点的热力图沿通道轴堆叠构成完整的目标张量。

### 步骤 2：微型关键点头

输出 K 个热力图通道的 U-Net 风格模型。

```python
import torch.nn as nn
import torch.nn.functional as F

class TinyKeypointNet(nn.Module):
    def __init__(self, num_keypoints=4, base=16):
        super().__init__()
        self.down1 = nn.Sequential(nn.Conv2d(3, base, 3, 2, 1), nn.ReLU(inplace=True))
        self.down2 = nn.Sequential(nn.Conv2d(base, base * 2, 3, 2, 1), nn.ReLU(inplace=True))
        self.mid = nn.Sequential(nn.Conv2d(base * 2, base * 2, 3, 1, 1), nn.ReLU(inplace=True))
        self.up1 = nn.ConvTranspose2d(base * 2, base, 2, 2)
        self.up2 = nn.ConvTranspose2d(base, num_keypoints, 2, 2)

    def forward(self, x):
        h1 = self.down1(x)
        h2 = self.down2(h1)
        h3 = self.mid(h2)
        u1 = self.up1(h3)
        return self.up2(u1)
```

输入 `(N, 3, H, W)`，输出 `(N, K, H, W)`。损失是对高斯目标的逐像素 MSE。

### 步骤 3：推理——提取关键点坐标

```python
def heatmap_to_coords(heatmaps):
    """
    heatmaps: (N, K, H, W)
    返回:     (N, K, 2) 图像像素中的浮点坐标
    """
    N, K, H, W = heatmaps.shape
    hm = heatmaps.reshape(N, K, -1)
    idx = hm.argmax(dim=-1)
    ys = (idx // W).float()
    xs = (idx % W).float()
    return torch.stack([xs, ys], dim=-1)

coords = heatmap_to_coords(torch.randn(2, 4, 32, 32))
print(f"coords: {coords.shape}")  # (2, 4, 2)
```

推理时一行。对于亚像素细化，在 argmax 附近插值。

### 步骤 4：合成关键点数据集

简单：在白色画布上画四个点，学习预测它们。

```python
def make_synthetic_sample(size=64):
    img = np.ones((3, size, size), dtype=np.float32)
    rng = np.random.default_rng()
    kps = rng.integers(8, size - 8, size=(4, 2))
    for cx, cy in kps:
        img[:, cy - 2:cy + 2, cx - 2:cx + 2] = 0.0
    hms = np.stack([gaussian_heatmap(size, cx, cy) for cx, cy in kps])
    return img, hms, kps
```

简单到微型模型可以在一分钟内学会。

### 步骤 5：训练

```python
model = TinyKeypointNet(num_keypoints=4)
opt = torch.optim.Adam(model.parameters(), lr=3e-3)

for step in range(200):
    batch = [make_synthetic_sample() for _ in range(16)]
    imgs = torch.from_numpy(np.stack([b[0] for b in batch]))
    hms = torch.from_numpy(np.stack([b[1] for b in batch]))
    pred = model(imgs)
    pred = F.interpolate(pred, size=hms.shape[-2:], mode="bilinear", align_corners=False)
    loss = F.mse_loss(pred, hms)
    opt.zero_grad(); loss.backward(); opt.step()
```

## 使用

- **MediaPipe Pose**——Google 的生产级姿态估计器；提供 WebGL + 移动端运行时，延迟低于 10ms。
- **MMPose**（OpenMMLab）——全面的研究代码库；每种 SOTA 架构都带预训练权重。
- **YOLOv8-pose**——最快的一次前向传播实时多人姿态估计。
- **transformers HumanDPT / PoseAnything**——较新的视觉语言方法，用于开放词汇姿态（任意物体、任意关键点集）。

## 交付物

本课产出：

- `outputs/prompt-pose-stack-picker.md`——一个 prompt，根据延迟、人群大小和 2D/3D 需求选择 MediaPipe / YOLOv8-pose / HRNet / ViTPose。
- `outputs/skill-heatmap-to-coords.md`——一个 skill，编写每个生产级姿态模型使用的亚像素热力图转坐标例程。

## 练习

1. **（简单）** 在合成 4 点数据集上训练微型关键点模型。200 步后报告预测与真实关键点之间的平均 L2 误差。
2. **（中等）** 添加亚像素细化：给定 argmax 位置，从相邻像素沿 x 和 y 拟合 1D 抛物线。报告相比整数 argmax 的准确率提升。
3. **（困难）** 构建一个 2 人合成数据集，每张图像显示两个 4 关键点模式的实例。使用 PAF 训练自底向上管线预测哪个关键点属于哪个实例，并评估 OKS。

## 关键术语

| 术语 | 别人说的 | 实际含义 |
|------|---------|---------|
| 关键点 | "一个标志点" | 物体上特定的有序点（关节、角、特征） |
| 姿态 | "骨架" | 属于一个实例的一组有序关键点 |
| 自顶向下 | "先检测再姿态" | 两阶段管线：人体检测器 + 每裁剪关键点模型；准确率最高 |
| 自底向上 | "先姿态后分组" | 单次所有关键点预测 + 分组；人群规模下耗时恒定 |
| 热力图 | "高斯目标" | 每个关键点的 H x W 张量，真实位置是峰值；首选的回归目标 |
| PAF | "部件亲和场" | 编码肢体方向的 2 通道单位向量场；用于将关键点分组为实例 |
| OKS | "关键点 IoU" | Object Keypoint Similarity；COCO 的姿态指标 |
| HRNet | "高分辨率网络" | 主导的自顶向下关键点架构；全程保持高分辨率特征 |

## 进一步阅读

- [OpenPose (Cao et al., 2017)](https://arxiv.org/abs/1812.08008) — 带 PAF 的自底向上方法；仍然是该方法的权威论文
- [HRNet (Sun et al., 2019)](https://arxiv.org/abs/1902.09212) — 自顶向下参考架构
- [ViTPose (Xu et al., 2022)](https://arxiv.org/abs/2204.12484) — 纯 ViT 作为姿态骨干；多个基准上的当前 SOTA
- [MediaPipe Pose](https://developers.google.com/mediapipe/solutions/vision/pose_landmarker) — 生产级实时姿态；2026 年最快的部署栈