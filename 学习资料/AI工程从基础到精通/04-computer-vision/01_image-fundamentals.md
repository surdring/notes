# 图像基础 — 像素、通道、色彩空间

> 图像是一个光采样张量。你将使用的每一个视觉模型都源于这一个事实。

**类型：** 构建
**语言：** Python
**前置课程：** 阶段 1 第 12 课（张量运算）、阶段 3 第 11 课（PyTorch 入门）
**时间：** 约 45 分钟

## 学习目标

- 解释连续场景如何被离散化为像素，以及为什么采样/量化决策决定了每个下游模型的上限
- 将图像作为 NumPy 数组读取、切片和检查，并在 HWC 和 CHW 布局之间流畅切换
- 在 RGB、灰度、HSV 和 YCbCr 之间转换，并论证每种色彩空间存在的原因
- 完全按照 torchvision 期望的方式应用像素级预处理（归一化、标准化、缩放、通道优先）

## 问题

你将要阅读的每一篇论文、下载的每一个预训练权重、调用的每一个视觉 API 都假设输入具有特定的编码方式。将 `uint8` 图像传给期望 `float32` 的模型，它照样会运行——但会悄无声息地产生垃圾。把 BGR 图像喂给在 RGB 上训练的网络，准确率会掉十分。将通道最后（channels-last）的输入传给期望通道优先（channels-first）的模型，第一个卷积层会把高度当作特征通道处理。这一切都不会抛出错误。它只会毁了你的指标，让你花一周时间去追查一个出在文件加载方式上的 bug。

卷积本身并不复杂——前提是你知道它在滑动什么。难点在于"一张图像"对于相机、JPEG 解码器、PIL、OpenCV、torchvision 和 CUDA 内核来说意味着不同的东西。每个技术栈都有自己的轴序、字节范围和通道约定。一个无法理清这些差异的视觉工程师输出的流水线必然是坏的。

本课打好基础，以便本阶段后续内容可以在此基础上构建。学完之后你将知道：像素是什么，为什么每个像素有三个数字而不是一个，用 ImageNet 统计量做"标准化"到底做了什么，以及如何在本阶段其他所有课程都将假定的两三种布局之间切换。

## 概念

### 预处理流水线总览

每个生产级视觉系统都是相同的可逆变换序列。错一步，模型看到的就是与训练时不同的输入。

```mermaid
flowchart LR
    A["图像文件<br/>(JPEG/PNG)"] --> B["解码<br/>uint8 HWC"]
    B --> C["转换<br/>色彩空间<br/>(RGB/BGR/YCbCr)"]
    C --> D["缩放<br/>较短边"]
    D --> E["中心裁剪<br/>模型尺寸"]
    E --> F["除以 255<br/>float32 [0,1]"]
    F --> G["减去均值<br/>除以标准差"]
    G --> H["转置<br/>HWC → CHW"]
    H --> I["批次化<br/>CHW → NCHW"]
    I --> J["模型"]

    style A fill:#fef3c7,stroke:#d97706
    style J fill:#ddd6fe,stroke:#7c3aed
    style G fill:#fecaca,stroke:#dc2626
    style H fill:#bfdbfe,stroke:#2563eb
```

红色和蓝色的两个框是 80% 的静默失败的根源：缺失的标准化和错误的布局。

### 像素是一个采样点，不是一个方块

相机传感器对落在网格状微小探测器上的光子进行计数。每个探测器在几分之一秒内积分光线，并发出与击中它的光子数成正比的电压。然后传感器将该电压离散化为一个整数。一个探测器变成一个像素。

```
连续场景                     传感器网格                     数字图像
（无限细节）                  （H x W 个探测器）              （H x W 个整数）

    ~~~~~                    +--+--+--+--+--+             210 198 180 155 120
   ~   ~   ~                 |  |  |  |  |  |             205 195 178 152 118
  ~ 光线  ~      ---->       +--+--+--+--+--+   ---->     200 190 175 150 115
   ~~~~~                     |  |  |  |  |  |             195 185 170 148 112
                             +--+--+--+--+--+             188 180 165 145 108
```

在这一步中有两个决策，它们决定了后续所有操作的上限：

- **空间采样**决定场景每度有多少个探测器。太少，边缘会变得锯齿状（混叠）。太多，存储和计算会爆炸。
- **强度量化**决定电压被分桶的精细程度。8 位给出 256 个级别，是显示的标准。10、12、16 位给出更平滑的梯度，对医学成像、HDR 和原始传感器流水线很重要。

像素不是一个有面积的彩色方块。它是一个单一的测量值。当你缩放或旋转时，你是在对该测量网格进行重采样。

### 为什么有三个通道

一个探测器对整个可见光谱的光子进行计数——这就是灰度。为了获得颜色，传感器用红、绿、蓝滤光片的马赛克覆盖网格。经过解马赛克（demosaicing）后，每个空间位置就有三个整数：附近红滤光探测器、绿滤光探测器和蓝滤光探测器的响应。这三个整数就是一个像素的 RGB 三元组。

```
内存中的一个像素：

    (R, G, B) = (210, 140, 30)   <- 红橙色

一个 H x W 的 RGB 图像：

    shape (H, W, 3)     存储为     H 行，每行 W 个像素，每个像素 3 个值
                                 对于 uint8，每个值在 [0, 255] 范围内
```

三并不是什么神奇的数字。深度相机增加一个 Z 通道。卫星增加红外和紫外波段。医学扫描通常有一个通道（X 光、CT）或很多通道（高光谱）。通道数是最后一个轴；卷积层学习在通道维度上进行混合。

### 两种布局约定：HWC 和 CHW

同一个张量，两种排序。每个库选择一种。

```
HWC（高度，宽度，通道）                  CHW（通道，高度，宽度）

   W ->                                    H ->
  +-----+-----+-----+                     +-----+-----+
H |R G B|R G B|R G B|                   C |R R R R R R|
| +-----+-----+-----+                   | +-----+-----+
v |R G B|R G B|R G B|                   v |G G G G G G|
  +-----+-----+-----+                     +-----+-----+
                                          |B B B B B B|
                                          +-----+-----+

   PIL、OpenCV、matplotlib、              PyTorch、大多数深度学习
   磁盘上几乎所有的图像文件                框架、cuDNN 内核
```

CHW 存在的原因是卷积核在 H 和 W 上滑动。将通道轴放在第一位意味着每个核看到每个通道的连续 2D 平面，这可以干净地向量化。磁盘格式保持 HWC，因为这匹配扫描线从传感器出来的方式。

你将要输入上千次的单行转换：

```
img_chw = img_hwc.transpose(2, 0, 1)      # NumPy
img_chw = img_hwc.permute(2, 0, 1)        # PyTorch 张量
```

内存布局可视化：

```mermaid
flowchart TB
    subgraph HWC["HWC — 像素交错存储（PIL、OpenCV、JPEG）"]
        H1["第 0 行：R G B | R G B | R G B ..."]
        H2["第 1 行：R G B | R G B | R G B ..."]
        H3["第 2 行：R G B | R G B | R G B ..."]
    end
    subgraph CHW["CHW — 通道以堆叠平面方式存储（PyTorch、cuDNN）"]
        C1["R 平面：整个 H x W 的红色值"]
        C2["G 平面：整个 H x W 的绿色值"]
        C3["B 平面：整个 H x W 的蓝色值"]
    end
    HWC -->|"transpose(2, 0, 1)"| CHW
    CHW -->|"transpose(1, 2, 0)"| HWC
```

### 字节范围和数据类型

三种约定占据主导：

| 约定 | dtype | 范围 | 出现场景 |
|------|-------|------|----------|
| 原始 | `uint8` | [0, 255] | 磁盘上的文件，PIL、OpenCV 输出 |
| 归一化 | `float32` | [0.0, 1.0] | 经过 `img.astype('float32') / 255` |
| 标准化 | `float32` | 约 [-2, +2] | 减去均值并除以标准差之后 |

卷积网络是在标准化输入上训练的。ImageNet 统计量 `mean=[0.485, 0.456, 0.406]`、`std=[0.229, 0.224, 0.225]` 是三个通道在整个 ImageNet 训练集上的算术均值和标准差，在 [0, 1] 归一化像素上计算得出。将原始 `uint8` 喂给期望标准化浮点数的模型，是应用视觉中最常见的静默失败。

### 色彩空间及其存在的原因

RGB 是捕获格式，但并不总是对模型最有用的表示。

```
 RGB               HSV                       YCbCr / YUV

 R 红色            H 色调（角度 0-360）       Y 亮度（明度）
 G 绿色            S 饱和度（0-1）           Cb 蓝色-黄色色度
 B 蓝色            V 明度/亮度（0-1）        Cr 红色-绿色色度

 线性对应           将颜色与亮度分离。         将亮度与颜色分离。
 传感器输出         用于颜色阈值、UI 滑块、    JPEG 和大多数视频编解码器
                   简单滤镜                   对色度通道进行更高程度的压缩，
                                             因为人眼对色度细节的敏感度低于对 Y。

```

对于大多数现代 CNN，你喂给它们的是 RGB。你会在以下场景遇到其他空间：

- **HSV** — 经典 CV 代码、基于颜色的分割、白平衡。
- **YCbCr** — 读取 JPEG 内部结构、视频流水线、仅对 Y 进行操作的超分辨率模型。
- **灰度** — OCR、文档模型、任何颜色是干扰变量而非信号的情况。

从 RGB 到灰度的转换是加权和，而不是平均值，因为人眼对绿色的敏感度高于对红色或蓝色：

```
Y = 0.299 R + 0.587 G + 0.114 B       （ITU-R BT.601，经典权重）
```

### 宽高比、缩放和插值

每个模型都有一个固定的输入尺寸（大多数 ImageNet 分类器为 224x224，现代检测器为 384x384 或 512x512）。你的图像很少匹配。三个重要的缩放选择：

- **缩放较短边，然后中心裁剪** — 标准的 ImageNet 配方。保持宽高比，丢弃边缘像素的条带。
- **缩放并填充** — 保持宽高比和每个像素，添加黑边。检测和 OCR 的标准做法。
- **直接缩放到目标尺寸** — 拉伸图像。便宜，扭曲几何形状，对许多分类任务来说没问题。

插值方法决定当新网格与旧网格不对齐时如何计算中间像素：

```
最近邻     最快，块状效果，是掩码/标签的唯一选择
双线性     快速，平滑，大多数图像缩放的默认选择
双三次     较慢，上采样更锐利
Lanczos    最慢，质量最好，用于最终显示
```

经验法则：训练用双线性，你要查看的资源用双三次或 lanczos，任何包含整数类别 ID 的内容用最近邻。

## 构建它

### 步骤 1：加载图像并检查其形状

使用 Pillow 加载任意 JPEG 或 PNG，转换为 NumPy，并打印你得到的内容。为了获得一个可离线运行的确定性示例，可以合成一张。

```python
import numpy as np
from PIL import Image

def synthetic_rgb(h=128, w=192, seed=0):
    rng = np.random.default_rng(seed)
    yy, xx = np.meshgrid(np.linspace(0, 1, h), np.linspace(0, 1, w), indexing="ij")
    r = (np.sin(xx * 6) * 0.5 + 0.5) * 255
    g = yy * 255
    b = (1 - yy) * xx * 255
    rgb = np.stack([r, g, b], axis=-1) + rng.normal(0, 6, (h, w, 3))
    return np.clip(rgb, 0, 255).astype(np.uint8)

arr = synthetic_rgb()
# 或者从磁盘加载：
# arr = np.asarray(Image.open("your_image.jpg").convert("RGB"))

print(f"type:   {type(arr).__name__}")
print(f"dtype:  {arr.dtype}")
print(f"shape:  {arr.shape}     # (H, W, C)")
print(f"min:    {arr.min()}")
print(f"max:    {arr.max()}")
print(f"pixel at (0, 0): {arr[0, 0]}")
```

预期输出：`shape: (H, W, 3)`、`dtype: uint8`、范围 `[0, 255]`。这就是规范的磁盘表示形式，无论字节是来自相机、JPEG 解码器还是合成生成器。

### 步骤 2：分离通道并重新排序布局

分别提取 R、G、B，然后从 HWC 转换为 CHW 以用于 PyTorch。

```python
R = arr[:, :, 0]
G = arr[:, :, 1]
B = arr[:, :, 2]
print(f"R shape: {R.shape}, mean: {R.mean():.1f}")
print(f"G shape: {G.shape}, mean: {G.mean():.1f}")
print(f"B shape: {B.shape}, mean: {B.mean():.1f}")

arr_chw = arr.transpose(2, 0, 1)
print(f"\nHWC shape: {arr.shape}")
print(f"CHW shape: {arr_chw.shape}")
```

三个灰度平面，每个通道一个。CHW 只是将轴重新排序；在内存布局允许的情况下，不严格要求数据拷贝。

### 步骤 3：灰度和 HSV 转换

加权和灰度化，然后是手动的 RGB 到 HSV 转换。

```python
def rgb_to_grayscale(rgb):
    weights = np.array([0.299, 0.587, 0.114], dtype=np.float32)
    return (rgb.astype(np.float32) @ weights).astype(np.uint8)

def rgb_to_hsv(rgb):
    rgb_f = rgb.astype(np.float32) / 255.0
    r, g, b = rgb_f[..., 0], rgb_f[..., 1], rgb_f[..., 2]
    cmax = np.max(rgb_f, axis=-1)
    cmin = np.min(rgb_f, axis=-1)
    delta = cmax - cmin

    h = np.zeros_like(cmax)
    mask = delta > 0
    rmax = mask & (cmax == r)
    gmax = mask & (cmax == g)
    bmax = mask & (cmax == b)
    h[rmax] = ((g[rmax] - b[rmax]) / delta[rmax]) % 6
    h[gmax] = ((b[gmax] - r[gmax]) / delta[gmax]) + 2
    h[bmax] = ((r[bmax] - g[bmax]) / delta[bmax]) + 4
    h = h * 60.0

    s = np.where(cmax > 0, delta / cmax, 0)
    v = cmax
    return np.stack([h, s, v], axis=-1)

gray = rgb_to_grayscale(arr)
hsv = rgb_to_hsv(arr)
print(f"gray shape: {gray.shape}, range: [{gray.min()}, {gray.max()}]")
print(f"hsv   shape: {hsv.shape}")
print(f"hue range: [{hsv[..., 0].min():.1f}, {hsv[..., 0].max():.1f}] degrees")
print(f"sat range: [{hsv[..., 1].min():.2f}, {hsv[..., 1].max():.2f}]")
print(f"val range: [{hsv[..., 2].min():.2f}, {hsv[..., 2].max():.2f}]")
```

色调以度数输出，饱和度和明度在 [0, 1] 范围内。这与 OpenCV 的 `hsv_full` 约定一致。

### 步骤 4：归一化、标准化及其逆操作

从原始字节得到预训练 ImageNet 模型所期望的精确张量，然后再转换回来。

```python
mean = np.array([0.485, 0.456, 0.406], dtype=np.float32)
std = np.array([0.229, 0.224, 0.225], dtype=np.float32)

def preprocess_imagenet(rgb_uint8):
    x = rgb_uint8.astype(np.float32) / 255.0
    x = (x - mean) / std
    x = x.transpose(2, 0, 1)
    return x

def deprocess_imagenet(chw_float32):
    x = chw_float32.transpose(1, 2, 0)
    x = x * std + mean
    x = np.clip(x * 255.0, 0, 255).astype(np.uint8)
    return x

x = preprocess_imagenet(arr)
print(f"preprocessed shape: {x.shape}     # (C, H, W)")
print(f"preprocessed dtype: {x.dtype}")
print(f"preprocessed mean per channel:  {x.mean(axis=(1, 2)).round(3)}")
print(f"preprocessed std  per channel:  {x.std(axis=(1, 2)).round(3)}")

roundtrip = deprocess_imagenet(x)
max_diff = np.abs(roundtrip.astype(int) - arr.astype(int)).max()
print(f"roundtrip max pixel diff: {max_diff}    # 应该是 0 或 1")
```

每通道均值应接近零，标准差接近一。preprocess/deprocess 这对函数正是每个 torchvision `transforms.Normalize` 调用在底层所做的工作。

### 步骤 5：使用三种插值方法进行缩放

在上采样时比较最近邻、双线性和双三次，让差异可见。

```python
target = (arr.shape[0] * 3, arr.shape[1] * 3)

nearest = np.asarray(Image.fromarray(arr).resize(target[::-1], Image.NEAREST))
bilinear = np.asarray(Image.fromarray(arr).resize(target[::-1], Image.BILINEAR))
bicubic = np.asarray(Image.fromarray(arr).resize(target[::-1], Image.BICUBIC))

def local_roughness(x):
    gy = np.diff(x.astype(float), axis=0)
    gx = np.diff(x.astype(float), axis=1)
    return float(np.abs(gy).mean() + np.abs(gx).mean())

for name, out in [("nearest", nearest), ("bilinear", bilinear), ("bicubic", bicubic)]:
    print(f"{name:>8}  shape={out.shape}  roughness={local_roughness(out):6.2f}")
```

最近邻在粗糙度上得分最高，因为它保留了硬边缘。双线性最平滑。双三次居中，在保持视觉锐度的同时不产生阶梯效应。

## 使用它

`torchvision.transforms` 将上述所有内容打包成一个可组合的流水线。以下代码精确复现了 `preprocess_imagenet` 的功能，外加缩放和裁剪。

```python
import torch
from torchvision import transforms
from PIL import Image

img = Image.fromarray(synthetic_rgb(256, 256))

pipeline = transforms.Compose([
    transforms.Resize(256),
    transforms.CenterCrop(224),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
])

x = pipeline(img)
print(f"tensor type:  {type(x).__name__}")
print(f"tensor dtype: {x.dtype}")
print(f"tensor shape: {tuple(x.shape)}      # (C, H, W)")
print(f"per-channel mean: {x.mean(dim=(1, 2)).tolist()}")
print(f"per-channel std:  {x.std(dim=(1, 2)).tolist()}")

batch = x.unsqueeze(0)
print(f"\nbatched shape: {tuple(batch.shape)}   # (N, C, H, W) — 可以送入模型了")
```

四个步骤，严格按此顺序：`Resize(256)` 将较短边缩放到 256；`CenterCrop(224)` 从中间取出 224x224 的块；`ToTensor()` 除以 255 并将 HWC 交换为 CHW；`Normalize` 减去 ImageNet 均值再除以标准差。颠倒此顺序会静默地改变到达模型的内容。

## 交付它

本课产出：

- `outputs/prompt-vision-preprocessing-audit.md` — 一个提示词，将任意模型卡或数据集卡转换为团队必须遵守的精确预处理不变量的检查清单。
- `outputs/skill-image-tensor-inspector.md` — 一个技能，给定任意图像形状的张量或数组，报告 dtype、布局、范围，以及它看起来是原始的、归一化的还是标准化的。

## 练习

1. **（简单）** 分别用 OpenCV（`cv2.imread`）和 Pillow 加载一张 JPEG。打印两个数组的形状和像素 `(0, 0)`。解释通道顺序的差异，然后写一行转换代码使 OpenCV 数组与 Pillow 数组完全相同。
2. **（中等）** 编写 `standardize(img, mean, std)` 及其逆函数，二者需共同通过 `roundtrip_max_diff <= 1` 的测试（对任意 uint8 图像）。你的函数必须用同一个调用同时支持 HWC 单张图像和 NCHW 批次。
3. **（困难）** 取一个 3 通道 ImageNet 标准化的张量，通过一个 1x1 卷积运行，该卷积学习将 RGB 加权混合为单个灰度通道。将权重初始化为 `[0.299, 0.587, 0.114]`，冻结它们，并验证输出与你手写的 `rgb_to_grayscale` 在浮点误差范围内匹配。还有哪些其他经典色彩空间变换可以写成 1x1 卷积？

## 关键术语

| 术语 | 人们怎么说 | 它实际意味着什么 |
|------|-----------|----------------|
| 像素 | "一个彩色方块" | 一个网格位置上的光强度采样 — 彩色是三个数，灰度是一个数 |
| 通道 | "颜色" | 堆叠在图像张量中的多个平行空间网格之一；HWC 中为最后一个轴，CHW 中为第一个轴 |
| HWC / CHW | "形状" | 图像张量的轴序；磁盘和 PIL 使用 HWC，PyTorch 和 cuDNN 使用 CHW |
| 归一化 | "缩放图像" | 除以 255 使像素值落在 [0, 1] 范围内 — 必要但不充分 |
| 标准化 | "零中心化" | 每通道减去均值并除以标准差，使输入分布与模型训练时的分布匹配 |
| 灰度转换 | "对通道取平均" | 系数为 0.299/0.587/0.114 的加权和，匹配人眼亮度感知 |
| 插值 | "缩放如何选择像素" | 当新网格与旧网格不对齐时决定输出值的规则 — 标签用最近邻，训练用双线性，显示用双三次 |
| 宽高比 | "宽度除以高度" | 区分"缩放并填充"与"缩放并拉伸"的比例 |

## 进一步阅读

- [Charles Poynton — A Guided Tour of Color Space](https://poynton.ca/PDFs/Guided_tour.pdf) — 关于为什么有这么多色彩空间以及每种空间何时重要的最清晰技术论述
- [PyTorch Vision Transforms 文档](https://pytorch.org/vision/stable/transforms.html) — 你在生产中实际组合的完整变换流水线
- [How JPEG Works (Colt McAnlis)](https://www.youtube.com/watch?v=F1kYBnY6mwg) — 关于色度子采样、DCT 以及为什么 JPEG 编码 YCbCr 而非 RGB 的精彩视觉讲解
- [ImageNet 预处理约定（torchvision 模型）](https://pytorch.org/vision/stable/models.html) — `mean=[0.485, 0.456, 0.406]` 的权威来源，以及为什么模型库中的每个模型都期望它