# 从零实现3D高斯溅射

> 一个场景是数百万个3D高斯函数的集合。每个高斯函数有一个位置、方向、尺度、不透明度，以及取决于观察方向的颜色。将它们光栅化，通过光栅化反向传播，完成。

**类型:** 构建
**语言:** Python
**前置条件:** 第四阶段第13课（3D视觉与NeRF），第一阶段第12课（张量运算），第四阶段第10课（扩散基础，可选）
**时间:** ~90分钟

## 学习目标

- 解释为什么3D高斯溅射在2026年取代NeRF成为逼真3D重建的生产默认方案
- 列出六个逐高斯参数（位置、旋转四元数、尺度、不透明度、球谐函数颜色、可选特征）以及每个参数贡献的浮点数
- 使用`alpha`合成从头实现一个2D高斯溅射光栅化器，然后展示3D情况如何投影到相同的循环中
- 使用`nerfstudio`、`gsplat`或`SuperSplat`从20-50张照片重建场景，并导出为`KHR_gaussian_splatting` glTF扩展或OpenUSD 26.03 `UsdVolParticleField3DGaussianSplat`模式

## 问题

NeRF将场景存储为MLP的权重。每个渲染的像素是沿射线进行数百次MLP查询。训练需要数小时，渲染需要数秒，且权重不可编辑——如果你想移动场景中的椅子，必须重新训练。

3D高斯溅射（Kerbl, Kopanas, Leimkühler, Drettakis, SIGGRAPH 2023）取代了这一切。场景是一组显式的3D高斯函数。渲染是100+ fps的GPU光栅化。训练只需数分钟。编辑是直接的：平移一部分高斯子集，椅子就被移动了。到2026年，Khronos集团已批准了高斯溅射的glTF扩展，OpenUSD 26.03内置了高斯溅射模式，Zillow和Apartments.com使用它们渲染房地产，大多数3D重建的新研究论文都是核心3DGS思路的变体。

思维模型很简单，但数学部分有足够的移动部件，大多数介绍都从光栅化开始而跳过了投影和球谐函数。本课从头构建整个过程——先构建2D版本，再扩展至3D。

## 概念

### 一个高斯函数携带什么

一个3D高斯函数是空间中的一个参数化斑点，具有以下属性：

```
位置             mu         (3,)    世界坐标中的中心
旋转             q          (4,)    编码方向的单位四元数
尺度             s          (3,)    每轴的对数尺度（渲染时取指数）
不透明度         alpha      (1,)    sigmoid后的不透明度 [0, 1]
SH系数           c_lm       (3 * (L+1)^2,)   依赖视角的颜色
```

旋转 + 尺度构建一个3x3协方差：`Sigma = R S S^T R^T`。这就是高斯函数在3D中的形状。球谐函数使颜色随观察方向变化——镜面高光、微妙光泽、依赖视角的辉光——无需存储每视角纹理。使用SH度数3时，每个颜色通道有16个系数，每个高斯函数仅颜色就需要48个浮点数。

典型场景有100万-500万个高斯函数。每个存储大约60个浮点数（3 + 4 + 3 + 1 + 48 + 杂项）。对于一个五百万高斯函数的场景，大约是240 MB——远小于具有逐点纹理的等效点云，也比NeRF在更高分辨率重新渲染时的MLP权重小一个数量级。

### 光栅化，而非光线步进

```mermaid
flowchart LR
    SCENE["数百万3D高斯<br/>（位置、旋转、尺度、<br/>不透明度、SH颜色）"] --> PROJ["投影到2D<br/>（相机外参+内参）"]
    PROJ --> TILES["分配到瓦片<br/>（16x16屏幕空间）"]
    TILES --> SORT["按深度排序<br/>每个瓦片"]
    SORT --> ALPHA["Alpha合成<br/>从前到后"]
    ALPHA --> PIX["像素颜色"]

    style SCENE fill:#dbeafe,stroke:#2563eb
    style ALPHA fill:#fef3c7,stroke:#d97706
    style PIX fill:#dcfce7,stroke:#16a34a
```

五个步骤，全部GPU友好。每个像素不需要MLP查询。单张RTX 3080 Ti以147 fps渲染600万个溅射点。

### 投影步骤

世界位置`mu`处的3D高斯函数，具有3D协方差`Sigma`，投影为屏幕位置`mu'`处的2D高斯函数，具有2D协方差`Sigma'`：

```
mu' = project(mu)
Sigma' = J W Sigma W^T J^T          (2 x 2)

W = 视角变换（相机的旋转+平移）
J = 在mu'处透视投影的雅可比矩阵
```

2D高斯函数的足迹是一个椭圆，其轴是`Sigma'`的特征向量。椭圆内的每个像素接收高斯函数的贡献，由`exp(-0.5 * (p - mu')^T Sigma'^-1 (p - mu'))`加权。

### Alpha合成规则

对于一个像素，覆盖它的高斯函数按从后到前排序（或等效地从前到后使用反转公式）。颜色使用自上世纪80年代以来每个半透明光栅化器都使用的相同方程进行合成：

```
C_pixel = sum_i alpha_i * T_i * c_i

T_i = prod_{j < i} (1 - alpha_j)       第i个之前的透射率
alpha_i = opacity_i * exp(-0.5 * d^T Sigma'^-1 d)   局部贡献
c_i = eval_SH(SH_i, view_direction)    依赖视角的颜色
```

这与NeRF的体积渲染方程是**相同的方程**，只是基于显式的稀疏高斯函数集而非沿射线的密集采样。这种同一性解释了为什么渲染质量匹配NeRF——两者都在积分相同的辐射场方程。

### 为什么这是可微的

每一步——投影、瓦片分配、alpha合成、SH评估——关于高斯参数都是可微的。给定一个真实图像，计算渲染像素损失，通过光栅化器反向传播，通过梯度下降更新所有`(mu, q, s, alpha, c_lm)`。经过大约30,000次迭代，高斯函数找到它们正确的位置、尺度和颜色。

### 密集化和剪枝

固定的高斯函数集无法覆盖复杂场景。训练包括两种自适应机制：

- **克隆**：当高斯函数的梯度幅度高但其尺度小时，在其当前位置克隆它——重建需要更多细节。
- **分裂**：当梯度大时，将大尺度的高斯函数分裂为两个较小的——一个大高斯函数太平滑，无法适应该区域。
- **剪枝**：移出不透明度低于阈值的高斯函数——它们没有贡献。

密集化每隔N次迭代运行一次。场景通常从约10万个初始高斯函数（从SfM点种子）增长到训练结束时的100万-500万个。

### 球谐函数一句话概括

依赖视角的颜色是单位球面上的一个函数`c(direction)`。球谐函数是球面的傅里叶基。在度数`L`处截断，每个通道得到`(L+1)^2`个基函数。为新视角评估颜色是学习到的SH系数与在观察方向上评估的基函数之间的点积。度数0 = 一个系数 = 恒定颜色。度数3 = 16个系数 = 足以捕捉朗伯阴影、镜面和柔和反射。SD高斯溅射论文默认使用度数3。

### 2026年生产栈

```
1. 采集         智能手机 / DJI无人机 / 手持扫描仪
2. SfM / MVS    COLMAP或GLOMAP推导相机位姿 + 稀疏点
3. 训练3DGS     nerfstudio / gsplat / inria官方 / PostShot（RTX 4090大约10-30分钟）
4. 编辑         SuperSplat / SplatForge（清理浮点、分割）
5. 导出         .ply -> glTF KHR_gaussian_splatting 或 .usd（OpenUSD 26.03）
6. 查看         Cesium / Unreal / Babylon.js / Three.js / Vision Pro
```

### 4D和生成式变体

- **4D高斯溅射** — 高斯函数是时间的函数；用于体积视频（Superman 2026, A$AP Rocky的"Helicopter"）。
- **生成式溅射** — 文本到溅射模型（World Labs的Marble）可以想象整个场景。
- **3D高斯无迹变换** — NVIDIA NuRec用于自动驾驶仿真的变体。

## 构建部分

### 步骤1：2D高斯函数

我们首先构建一个2D光栅化器。3D情况在投影后归结为它。

```python
import torch
import torch.nn as nn
import torch.nn.functional as F


def eval_2d_gaussian(means, covs, points):
    """
    means:  (G, 2)      中心
    covs:   (G, 2, 2)   协方差矩阵
    points: (H, W, 2)   像素坐标
    返回: (G, H, W)  每个高斯函数在每个像素的密度
    """
    G = means.size(0)
    H, W, _ = points.shape
    flat = points.view(-1, 2)
    inv = torch.linalg.inv(covs)
    diff = flat[None, :, :] - means[:, None, :]
    d = torch.einsum("gpi,gij,gpj->gp", diff, inv, diff)
    density = torch.exp(-0.5 * d)
    return density.view(G, H, W)
```

`einsum`为每个（高斯函数，像素）对计算二次型`diff^T Sigma^-1 diff`。

### 步骤2：2D溅射光栅化器

从前到后的Alpha合成。2D中的深度无意义，所以我们使用学习的逐高斯标量进行排序。

```python
def rasterise_2d(means, covs, colours, opacities, depths, image_size):
    """
    means:     (G, 2)
    covs:      (G, 2, 2)
    colours:   (G, 3)
    opacities: (G,)     范围 [0, 1]
    depths:    (G,)     用于排序的逐高斯标量
    image_size: (H, W)
    返回:   (H, W, 3) 渲染图像
    """
    H, W = image_size
    yy, xx = torch.meshgrid(
        torch.arange(H, dtype=torch.float32, device=means.device),
        torch.arange(W, dtype=torch.float32, device=means.device),
        indexing="ij",
    )
    points = torch.stack([xx, yy], dim=-1)

    densities = eval_2d_gaussian(means, covs, points)
    alphas = opacities[:, None, None] * densities
    alphas = alphas.clamp(0.0, 0.99)

    order = torch.argsort(depths)
    alphas = alphas[order]
    colours_sorted = colours[order]

    T = torch.ones(H, W, device=means.device)
    out = torch.zeros(H, W, 3, device=means.device)
    for i in range(means.size(0)):
        a = alphas[i]
        out += (T * a)[..., None] * colours_sorted[i][None, None, :]
        T = T * (1.0 - a)
    return out
```

速度不快——真正的实现使用基于瓦片的CUDA内核——但数学完全正确且完全可微。

### 步骤3：可训练的2D溅射场景

```python
class Splats2D(nn.Module):
    def __init__(self, num_splats=128, image_size=64, seed=0):
        super().__init__()
        g = torch.Generator().manual_seed(seed)
        H, W = image_size, image_size
        self.means = nn.Parameter(torch.rand(num_splats, 2, generator=g) * torch.tensor([W, H]))
        self.log_scale = nn.Parameter(torch.ones(num_splats, 2) * math.log(2.0))
        self.rot = nn.Parameter(torch.zeros(num_splats))  # 2D中的单个角度
        self.colour_logits = nn.Parameter(torch.randn(num_splats, 3, generator=g) * 0.5)
        self.opacity_logit = nn.Parameter(torch.zeros(num_splats))
        self.depth = nn.Parameter(torch.rand(num_splats, generator=g))

    def covs(self):
        s = torch.exp(self.log_scale)
        c, si = torch.cos(self.rot), torch.sin(self.rot)
        R = torch.stack([
            torch.stack([c, -si], dim=-1),
            torch.stack([si, c], dim=-1),
        ], dim=-2)
        S = torch.diag_embed(s ** 2)
        return R @ S @ R.transpose(-1, -2)

    def forward(self, image_size):
        covs = self.covs()
        colours = torch.sigmoid(self.colour_logits)
        opacities = torch.sigmoid(self.opacity_logit)
        return rasterise_2d(self.means, covs, colours, opacities, self.depth, image_size)
```

`log_scale`、`opacity_logit`和`colour_logits`都是无约束参数，在渲染时通过正确的激活函数映射。这是每个3DGS实现的标准模式。

### 步骤4：将2D高斯拟合到目标图像

```python
import math
import numpy as np

def make_target(size=64):
    yy, xx = np.meshgrid(np.arange(size), np.arange(size), indexing="ij")
    img = np.zeros((size, size, 3), dtype=np.float32)
    # 红色圆
    mask = (xx - 20) ** 2 + (yy - 20) ** 2 < 10 ** 2
    img[mask] = [1.0, 0.2, 0.2]
    # 蓝色正方形
    mask = (np.abs(xx - 45) < 8) & (np.abs(yy - 40) < 8)
    img[mask] = [0.2, 0.3, 1.0]
    return torch.from_numpy(img)


target = make_target(64)
model = Splats2D(num_splats=64, image_size=64)
opt = torch.optim.Adam(model.parameters(), lr=0.05)

for step in range(200):
    pred = model((64, 64))
    loss = F.mse_loss(pred, target)
    opt.zero_grad(); loss.backward(); opt.step()
    if step % 40 == 0:
        print(f"step {step:3d}  mse {loss.item():.4f}")
```

经过200步，64个高斯函数聚拢成两个形状。这就是整个思想——对显式几何基元进行梯度下降。

### 步骤5：从2D到3D

3D扩展保持相同的循环。增加的内容：

1. 逐高斯旋转是四元数而非单个角度。
2. 协方差是`R S S^T R^T`，其中`R`由四元数构建，`S = diag(exp(log_scale))`。
3. 投影`(mu, Sigma) -> (mu', Sigma')`使用相机外参和在`mu`处透视投影的雅可比矩阵。
4. 颜色变为球谐函数展开；在观察方向上评估它。
5. 深度排序使用实际的相机空间z而非学习的标量。

每个生产实现（`gsplat`、`inria/gaussian-splatting`、`nerfstudio`）都在GPU上使用基于瓦片的CUDA内核做完全相同的事。

### 步骤6：球谐函数评估

度数最高为3的SH基每个通道有16个项。评估：

```python
def eval_sh_degree_3(sh_coeffs, dirs):
    """
    sh_coeffs: (..., 16, 3)   最后一维是RGB通道
    dirs:      (..., 3)       单位向量
    返回:   (..., 3)
    """
    C0 = 0.282094791773878
    C1 = 0.488602511902920
    C2 = [1.092548430592079, 1.092548430592079,
          0.315391565252520, 1.092548430592079,
          0.546274215296039]
    x, y, z = dirs[..., 0], dirs[..., 1], dirs[..., 2]
    x2, y2, z2 = x * x, y * y, z * z
    xy, yz, xz = x * y, y * z, x * z

    result = C0 * sh_coeffs[..., 0, :]
    result = result - C1 * y[..., None] * sh_coeffs[..., 1, :]
    result = result + C1 * z[..., None] * sh_coeffs[..., 2, :]
    result = result - C1 * x[..., None] * sh_coeffs[..., 3, :]

    result = result + C2[0] * xy[..., None] * sh_coeffs[..., 4, :]
    result = result + C2[1] * yz[..., None] * sh_coeffs[..., 5, :]
    result = result + C2[2] * (2.0 * z2 - x2 - y2)[..., None] * sh_coeffs[..., 6, :]
    result = result + C2[3] * xz[..., None] * sh_coeffs[..., 7, :]
    result = result + C2[4] * (x2 - y2)[..., None] * sh_coeffs[..., 8, :]

    # 此处省略了度数3的项以节省篇幅；完整16系数版本在代码文件中
    return result
```

学习到的`sh_coeffs`存储该高斯的"每个方向上的颜色"。在渲染时，你根据当前视角方向进行评估，得到一个3维RGB向量。

## 使用部分

对于真正的3DGS工作，使用`gsplat`（Meta）或`nerfstudio`：

```bash
pip install nerfstudio gsplat
ns-download-data example
ns-train splatfacto --data path/to/data
```

`splatfacto`是nerfstudio的3DGS训练器。对于典型场景，在RTX 4090上运行需要10-30分钟。

2026年相关的导出选项：

- `.ply` — 原始高斯云（便携，文件最大）。
- `.splat` — PlayCanvas / SuperSplat量化格式。
- glTF `KHR_gaussian_splatting` — Khronos标准，跨查看器可移植（2026年2月RC）。
- OpenUSD `UsdVolParticleField3DGaussianSplat` — USD原生，用于NVIDIA Omniverse和Vision Pro管线。

对于4D/动态场景，`4DGS`和`Deformable-3DGS`使用时变均值和透明度扩展相同的机制。

## 交付物

本课产生：

- `outputs/prompt-3dgs-capture-planner.md` — 为给定场景类型规划采集方案（照片数量、相机路径、光线）的提示词。
- `outputs/skill-3dgs-export-router.md` — 根据下游查看器或引擎选择正确导出格式（`.ply` / `.splat` / glTF / USD）的技能。

## 练习

1. **（简单）** 在不同的合成图像上运行上述2D溅射训练器。在`[16, 64, 256]`范围内变化`num_splats`，绘制每个的MSE与步骤的关系。识别收益递减的点。
2. **（中等）** 扩展2D光栅化器以支持每高斯RGB颜色，该颜色通过2阶谐波依赖标量"视角"。在一对目标图像上训练并验证模型重建了两者。
3. **（困难）** 克隆`nerfstudio`并对你手头的任何场景（桌子、植物、人脸、房间）的20张照片采集训练`splatfacto`。导出为glTF `KHR_gaussian_splatting`并在查看器中打开（Three.js `GaussianSplats3D`、SuperSplat、Babylon.js V9）。报告训练时间、高斯函数数量和渲染fps。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| 3DGS | "高斯溅射" | 将场景显式表示为数百万个3D高斯函数，带有逐高斯位置、旋转、尺度、不透明度、SH颜色 |
| 协方差 | "高斯函数的形状" | `Sigma = R S S^T R^T`；一个高斯函数的朝向和各向异性尺度 |
| Alpha合成 | "从后到前混合" | 与NeRF体积渲染相同的方程，现在基于显式稀疏集合 |
| 密集化 | "克隆和分裂" | 在重建欠拟合的地方自适应添加新高斯函数 |
| 剪枝 | "删除低不透明度" | 移除在训练期间坍塌到接近零不透明度的高斯函数 |
| 球谐函数 | "依赖视角的颜色" | 球面上的傅里叶基；将颜色存储为观察方向的函数 |
| Splatfacto | "nerfstudio的3DGS" | 2026年训练3DGS的最简单途径 |
| `KHR_gaussian_splatting` | "glTF标准" | Khronos 2026扩展，使3DGS在查看器和引擎之间可移植 |

## 进一步阅读

- [3D Gaussian Splatting for Real-Time Radiance Field Rendering (Kerbl et al., SIGGRAPH 2023)](https://repo-sam.inria.fr/fungraph/3d-gaussian-splatting/) — 原始论文
- [gsplat (Meta/nerfstudio)](https://github.com/nerfstudio-project/gsplat) — 生产级CUDA光栅化器
- [nerfstudio Splatfacto](https://docs.nerf.studio/nerfology/methods/splat.html) — 参考训练配方
- [Khronos KHR_gaussian_splatting 扩展](https://github.com/KhronosGroup/glTF/blob/main/extensions/2.0/Khronos/KHR_gaussian_splatting/README.md) — 2026便携格式
- [OpenUSD 26.03 发行说明](https://openusd.org/release/) — `UsdVolParticleField3DGaussianSplat`模式
- [THE FUTURE 3D State of Gaussian Splatting 2026](https://www.thefuture3d.com/blog-0/2026/4/4/state-of-gaussian-splatting-2026) — 行业概览