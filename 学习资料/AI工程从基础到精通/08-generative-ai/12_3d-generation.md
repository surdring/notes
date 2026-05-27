# 3D 生成

> 3D 是 2D 到 3D 杠杆作用最强的模态。2023 年的突破是 3D 高斯泼溅。2024-2026 年的生成推动在其之上叠加多视图扩散 + 3D 重建，从单个提示或照片生成物体和场景。

**类型：** 学习
**语言：** Python
**前置要求：** 第 4 阶段（视觉），第 8 阶段 · 07（潜在扩散）
**时间：** 约 45 分钟

## 问题

3D 内容很痛苦：

- **表示。** 网格、点云、体素网格、有符号距离场（SDF）、神经辐射场（NeRF）、3D 高斯。每种都有权衡。
- **数据稀缺。** ImageNet 有 1400 万张图片。最大的干净 3D 数据集（Objaverse-XL, 2023）有约 1000 万个物体，大多数质量低。
- **内存。** 512³ 体素网格是 1.28 亿个体素；一个有用的场景 NeRF 每条射线需要 100 万个采样点。生成比重建更难。
- **监督。** 对于 2D 图像你有像素。对于 3D 你通常只有少量 2D 视图，需要提升到 3D。

2026 年的技术栈将两个问题分开。首先，用扩散模型生成*2D 多视图图像*。其次，将*3D 表示*（通常是高斯泼溅）拟合到这些图像。

## 概念

![3D 生成：多视图扩散 + 3D 重建](../assets/3d-generation.svg)

### 表示：3D 高斯泼溅（Kerbl et al., 2023）

将场景表示为约 100 万个 3D 高斯的云。每个有 59 个参数：位置（3）、协方差（6，或四元数 4 + 尺度 3）、不透明度（1）、球谐颜色（3 阶 48，0 阶 3）。

渲染 = 投影 + alpha 合成。快（4090 上 1080p 约 100 fps）。可微分。通过梯度下降拟合真实照片。一个场景在消费级 GPU 上 5-30 分钟拟合完成。

之上的两个 2023-2024 创新：
- **生成式高斯泼溅。** LGM、LRM、InstantMesh 等模型从一张或几张图像直接预测高斯云。
- **4D 高斯泼溅。** 带每帧偏移的高斯用于动态场景。

### 多视图扩散

微调预训练图像扩散模型，从文本提示或单张图像生成同一物体的多个一致视图。Zero123（Liu et al., 2023）、MVDream（Shi et al., 2023）、SV3D（Stability, 2024）、CAT3D（Google, 2024）。通常输出物体周围的 4-16 个视图，通过高斯泼溅或 NeRF 提升到 3D。

### 文本到 3D 流水线

| 模型 | 输入 | 输出 | 时间 |
|-------|------|--------|------|
| DreamFusion (2022) | 文本 | 通过 SDS 的 NeRF | 每个资产约 1 小时 |
| Magic3D | 文本 | 网格 + 纹理 | 约 40 分钟 |
| Shap-E (OpenAI, 2023) | 文本 | 隐式 3D | 约 1 分钟 |
| SJC / ProlificDreamer | 文本 | NeRF / 网格 | 约 30 分钟 |
| LRM (Meta, 2023) | 图像 | 三平面 | 约 5 秒 |
| InstantMesh (2024) | 图像 | 网格 | 约 10 秒 |
| SV3D (Stability, 2024) | 图像 | 新视图 | 约 2 分钟 |
| CAT3D (Google, 2024) | 1-64 张图片 | 3D NeRF | 约 1 分钟 |
| TripoSR (2024) | 图像 | 网格 | 约 1 秒 |
| Meshy 4 (2025) | 文本 + 图像 | PBR 网格 | 约 30 秒 |
| Rodin Gen-1.5 (2025) | 文本 + 图像 | PBR 网格 | 约 60 秒 |
| 腾讯 Hunyuan3D 2.0 (2025) | 图像 | 网格 | 约 30 秒 |

2025-2026 方向：直接文本到网格模型，带适合游戏引擎的 PBR 材质。多视图扩散中间步骤仍然是通用物体的最佳方案。

### NeRF（背景知识）

神经辐射场（Mildenhall et al., 2020）。一个微型 MLP 接受 `(x, y, z, 视角方向)` 并输出 `(颜色, 密度)`。通过沿射线积分渲染。在新视图合成质量上超越基于网格的方法，但渲染慢 100-1000 倍。在大多数实时使用中被高斯泼溅取代，但在研究中仍占主导。

## 构建

`code/main.py` 实现一个玩具 2D "高斯泼溅"拟合：将合成目标图像（平滑渐变）表示为 2D 高斯斑点的和。通过梯度下降优化位置、颜色和协方差以匹配目标。你看到两个核心操作：前向渲染（泼溅 + alpha 合成）和通过梯度下降拟合。

### 步骤 1：2D 高斯泼溅

```python
def gaussian_at(x, y, gaussian):
    px, py = gaussian["pos"]
    sigma = gaussian["sigma"]
    d2 = (x - px) ** 2 + (y - py) ** 2
    return math.exp(-d2 / (2 * sigma * sigma))
```

### 步骤 2：通过求和泼溅渲染

```python
def render(image_size, gaussians):
    img = [[0.0] * image_size for _ in range(image_size)]
    for g in gaussians:
        for y in range(image_size):
            for x in range(image_size):
                img[y][x] += g["color"] * gaussian_at(x, y, g)
    return img
```

真正的 3D 高斯泼溅按深度排序高斯并按顺序 alpha 合成。我们的 2D 玩具只做求和。

### 步骤 3：通过梯度下降拟合

```python
for step in range(steps):
    pred = render(size, gaussians)
    loss = mse(pred, target)
    gradients = compute_grads(pred, target, gaussians)
    update(gaussians, gradients, lr)
```

## 陷阱

- **视图不一致。** 如果你独立生成 4 个视图且它们对物体结构不一致，3D 拟合会模糊。修复：带共享注意力的多视图扩散。
- **背面幻觉。** 单图像 → 3D 必须发明看不见的一面。质量变化很大。
- **高斯泼溅爆炸。** 无约束训练增长到 1000 万个泼溅并过拟合。增密 + 修剪启发式（来自 3D-GS 原始论文）是必不可少的。
- **拓扑问题。** 来自隐式场（SDF）的网格经常有孔洞或自相交。在发布前运行重网格化器（例如 blender 的体素重网格）。
- **训练数据许可。** Objaverse 具有混合许可证；商业使用因模型而异。

## 使用

| 任务 | 2026 年选择 |
|------|-----------|
| 从照片场景重建 | 高斯泼溅（3DGS、Gsplat、Scaniverse） |
| 文本到 3D 游戏物体 | Meshy 4 或 Rodin Gen-1.5（PBR 输出） |
| 图像到 3D | Hunyuan3D 2.0、TripoSR、InstantMesh |
| 从少量图像新视图合成 | CAT3D、SV3D |
| 动态场景重建 | 4D 高斯泼溅 |
| 虚拟人 / 穿衣人体 | Gaussian Avatar、HUGS |
| 研究 / SOTA | 上周刚发布的任何东西 |

对于在游戏或电商流水线中交付生产 3D：Meshy 4 或 Rodin Gen-1.5 输出直接进入 Unity / Unreal 的 PBR 网格。

## 交付

保存 `outputs/skill-3d-pipeline.md`。技能接受 3D 简报（输入：文本 / 一张图像 / 少量图像；输出：网格 / 泼溅 / NeRF；用途：渲染 / 游戏 / VR）并输出：流水线（多视图扩散 + 拟合，或直接网格模型）、基础模型、迭代预算、拓扑后处理、所需材质通道。

## 练习

1. **简单。** 用 4、16、64 个高斯运行 `code/main.py`。报告与目标的最终 MSE。
2. **中等。** 扩展为有颜色的高斯（RGB）。确认重建匹配目标颜色模式。
3. **困难。** 使用 gsplat 或 Nerfstudio，从 50 张照片捕获重建真实物体。报告拟合时间和保留视图上的最终 SSIM。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|-----------------------|
| 3D 高斯泼溅 | "3DGS" | 场景作为 3D 高斯云；可微分 alpha 合成渲染。 |
| NeRF | "神经辐射场" | MLP 输出 3D 点的颜色 + 密度；通过射线积分渲染。 |
| 三平面 | "三个 2-D 平面" | 将 3D 分解为三个 2-D 轴对齐特征网格；比体积更便宜。 |
| SDS | "分数蒸馏采样" | 使用 2D 扩散分数作为伪梯度训练 3D 模型。 |
| 多视图扩散 | "同时多个视图" | 扩散模型输出一批一致的摄像机视图。 |
| PBR | "基于物理的渲染" | 带反照率、粗糙度、金属度、法线通道的材质。 |
| 增密 | "增长泼溅" | 3DGS 训练启发式：在高梯度区域拆分/克隆泼溅。 |

## 生产说明：3D 尚无共享底层

与图像（潜在扩散 + DiT）和视频（时空 DiT）不同，3D 在 2026 年没有单一主导运行时。生产决策树在表示上分叉：

- **NeRF / 三平面。** 推理是射线行进 + 每个采样点一个 MLP 前向传播。512² 渲染需要数百万次 MLP 前向传播。积极批处理射线采样；SDPA/xformers 适用。
- **多视图扩散 + LRM 重建。** 两阶段流水线。阶段 1（多视图 DiT）是扩散服务器，就像第 07 课。阶段 2（LRM transformer）是在视图上的一次性前向传播。整体延迟轮廓是"扩散 + 一次性"——相应地选择每个阶段的服务原语。
- **SDS / DreamFusion。** 每个资产优化，而非推理。构建作业，而非请求处理器。

对于大多数 2026 年产品，正确答案是"按需运行多视图扩散模型，异步重建为 3DGS，提供 3DGS 用于实时查看"。这将工作负载清晰地分为 GPU 推理服务器（快）和离线优化器（慢）。

## 扩展阅读

- [Mildenhall et al. (2020). NeRF: Representing Scenes as Neural Radiance Fields](https://arxiv.org/abs/2003.08934)——NeRF。
- [Kerbl et al. (2023). 3D Gaussian Splatting for Real-Time Radiance Field Rendering](https://arxiv.org/abs/2308.04079)——3DGS。
- [Poole et al. (2022). DreamFusion: Text-to-3D using 2D Diffusion](https://arxiv.org/abs/2209.14988)——SDS。
- [Liu et al. (2023). Zero-1-to-3: Zero-shot One Image to 3D Object](https://arxiv.org/abs/2303.11328)——Zero123。
- [Shi et al. (2023). MVDream](https://arxiv.org/abs/2308.16512)——多视图扩散。
- [Hong et al. (2023). LRM: Large Reconstruction Model for Single Image to 3D](https://arxiv.org/abs/2311.04400)——LRM。
- [Gao et al. (2024). CAT3D: Create Anything in 3D with Multi-View Diffusion Models](https://arxiv.org/abs/2405.10314)——CAT3D。
- [Stability AI (2024). Stable Video 3D (SV3D)](https://stability.ai/research/sv3d)——SV3D。