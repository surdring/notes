# 实时视觉——边缘部署

> 边缘推理是这样一门学科：让一个 90% 准确率的模型在有 2 GB 内存的设备上跑到 30 fps。每一个百分点的准确率都要用毫秒级的延迟来交换。

**类型：** 学习 + 构建
**语言：** Python
**前置知识：** Phase 4 Lesson 04（图像分类）、Phase 10 Lesson 11（量化）
**时间：** ~75 分钟

## 学习目标

- 测量任意 PyTorch 模型的推理延迟、峰值内存和吞吐量，并理解 FLOPs / 参数 / 延迟之间的权衡
- 使用 PyTorch 的训练后量化将视觉模型量化为 INT8，并验证准确率损失 < 1%
- 导出到 ONNX 并用 ONNX Runtime 或 TensorRT 编译；列举三种最常见的导出失败及其修复方法
- 解释在边缘约束下何时选择 MobileNetV3、EfficientNet-Lite、ConvNeXt-Tiny 或 MobileViT

## 问题

训练时的视觉模型是一个浮点怪物。1 亿参数、每次前向传播 10 GFLOPs、2 GB 显存。这些都不适合手机、汽车信息娱乐单元、工业相机或无人机。交付视觉系统意味着将相同的预测塞进一个缩小 100 倍的预算中。

三个旋钮完成大部分工作：模型选择（相同方法下的更小架构）、量化（INT8 替代 FP32）和推理运行时（ONNX Runtime、TensorRT、Core ML、TFLite）。正确设置它们，是 workstation 上的 demo 和 $30 摄像头上出货的产品之间的区别。

本课首先建立测量纪律（你无法优化你无法测量的东西），然后逐一讲解三个旋钮。目标不是学习每种边缘运行时，而是知道存在哪些杠杆，以及如何验证每个杠杆是否如你所想地工作。

## 核心概念

### 三个预算

```mermaid
flowchart LR
    M["模型"] --> LAT["延迟<br/>每张图像 ms"]
    M --> MEM["内存<br/>峰值 MB"]
    M --> PWR["功耗<br/>每次推理 mJ"]

    LAT --> SHIP["出货 / 不出货<br/>决策"]
    MEM --> SHIP
    PWR --> SHIP

    style LAT fill:#fecaca,stroke:#dc2626
    style MEM fill:#fef3c7,stroke:#d97706
    style PWR fill:#dbeafe,stroke:#2563eb
```

- **延迟**：p50、p95、p99。仅做平均会隐藏对实时系统至关重要的尾部行为。
- **峰值内存**：设备曾达到的最大值，而非稳态平均值。因为在嵌入式目标上 OOM 是致命的。
- **功耗 / 能量**：电池供电设备上每次推理的毫焦耳。通常用 CPU/GPU 利用率 × 时间来代理。

（模型、延迟、内存、准确率）的表格是边缘决策的基础。每个格子都要在目标设备上测量，而非在 workstation 上。

### 测量纪律

每个边缘性能分析应遵循的三条规则：

1. **预热**模型：用 5-10 次虚拟前向传播再开始测量。冷缓存和 JIT 编译会产生不具代表性的前几次数据。
2. **同步** GPU 工作负载：在计时块前后使用 `torch.cuda.synchronize()`。没有它会测量 kernel 调度时间而非 kernel 执行时间。
3. **固定输入尺寸**为生产分辨率。224x224 上的延迟不是 512x512 上的延迟。

### FLOPs 作为代理指标

FLOPs（每次推理的浮点运算次数）是一个廉价、设备无关的延迟代理指标。对架构比较有用，但作为绝对挂钟时间是有误导性的。FLOPs 多 10% 的模型在实际中可能快 2 倍，因为它使用了硬件友好的操作（深度卷积编译得好，大 7x7 卷积则不行）。

规则：用 FLOPs 做架构搜索，用设备上延迟做部署决策。

### 量化一图通

用 INT8 替换 FP32 权重和激活值。模型大小缩小 4 倍，内存带宽缩小 4 倍，在具备 INT8 kernel 的硬件上计算缩小 2-4 倍（每个现代移动 SoC、每个带 Tensor Core 的 NVIDIA GPU 都具备）。视觉任务的准确率损失通常在 0.1-1 个百分点，使用训练后静态量化。

类型：

- **动态量化**——权重量化为 INT8，激活值以 FP 计算。简单，小加速。
- **静态（训练后）量化**——量化权重 + 在小校准集上校准激活值范围。比动态快得多。
- **量化感知训练（QAT）**——训练时模拟量化，让模型学会绕开量化误差。精度最高，但需要标注数据。

对视觉任务而言，训练后静态量化用 5% 的投入获得 95% 的收益。仅在 PTQ 的精度损失不可接受时才使用 QAT。

### 剪枝和蒸馏

- **剪枝**——移除不重要的权重（基于幅值）或通道（结构化）。对过参数化模型效果好；对已经紧凑的架构用处较小。
- **蒸馏**——训练一个小 student 模型模仿大 teacher 模型的 logits。通常可以恢复模型缩小丢失的大部分精度。是生产级边缘模型的标准做法。

### 推理运行时

- **PyTorch eager**——慢，不用于部署。仅用于开发。
- **TorchScript**——已过时。被 `torch.compile` 和 ONNX 导出取代。
- **ONNX Runtime**——中立的运行时。CPU、CUDA、CoreML、TensorRT、OpenVINO 都有 ONNX provider。从这里开始。
- **TensorRT**——NVIDIA 的编译器。在 NVIDIA GPU（workstation 和 Jetson）上延迟最低。与 ONNX Runtime 集成或独立使用。
- **Core ML**——Apple 的 iOS/macOS 运行时。需要 `.mlmodel` 或 `.mlpackage`。
- **TFLite**——Google 的 Android/ARM 运行时。需要 `.tflite`。
- **OpenVINO**——Intel 的 CPU/VPU 运行时。需要 `.xml` + `.bin`。

实践中：导出 PyTorch -> ONNX -> 为目标平台选择运行时。ONNX 是通用语言。

### 边缘架构选择

| 预算 | 模型 | 原因 |
|------|-----|------|
| < 3M 参数 | MobileNetV3-Small | 到处都能编译，良好的基线 |
| 3-10M | EfficientNet-Lite-B0 | TFLite 上每参数最佳准确率 |
| 10-20M | ConvNeXt-Tiny | 每参数最佳准确率，CPU 友好 |
| 20-30M | MobileViT-S 或 EfficientViT | 带 transformer 的 ImageNet 准确率 |
| 30-80M | Swin-V2-Tiny | 如果栈支持窗口注意力 |

除非有特殊原因，否则全部量化为 INT8。

## 构建

### 步骤 1：正确测量延迟

```python
import time
import torch

def measure_latency(model, input_shape, device="cpu", warmup=10, iters=50):
    model = model.to(device).eval()
    x = torch.randn(input_shape, device=device)
    with torch.no_grad():
        for _ in range(warmup):
            model(x)
        if device == "cuda":
            torch.cuda.synchronize()
        times = []
        for _ in range(iters):
            if device == "cuda":
                torch.cuda.synchronize()
            t0 = time.perf_counter()
            model(x)
            if device == "cuda":
                torch.cuda.synchronize()
            times.append((time.perf_counter() - t0) * 1000)
    times.sort()
    return {
        "p50_ms": times[len(times) // 2],
        "p95_ms": times[int(len(times) * 0.95)],
        "p99_ms": times[int(len(times) * 0.99)],
        "mean_ms": sum(times) / len(times),
    }
```

预热、同步、使用 `time.perf_counter()`。报告百分位数，不仅是均值。

### 步骤 2：参数和 FLOP 计数

```python
def parameter_count(model):
    return sum(p.numel() for p in model.parameters())

def flops_estimate(model, input_shape):
    """
    卷积/线性模型的粗略 FLOP 计数。生产环境使用 `fvcore` 或 `ptflops`。
    """
    total = 0
    def conv_hook(m, inp, out):
        nonlocal total
        c_out, c_in, kh, kw = m.weight.shape
        h, w = out.shape[-2:]
        total += 2 * c_in * c_out * kh * kw * h * w
    def linear_hook(m, inp, out):
        nonlocal total
        total += 2 * m.in_features * m.out_features
    hooks = []
    for m in model.modules():
        if isinstance(m, torch.nn.Conv2d):
            hooks.append(m.register_forward_hook(conv_hook))
        elif isinstance(m, torch.nn.Linear):
            hooks.append(m.register_forward_hook(linear_hook))
    model.eval()
    with torch.no_grad():
        model(torch.randn(input_shape))
    for h in hooks:
        h.remove()
    return total
```

实际项目使用 `fvcore.nn.FlopCountAnalysis` 或 `ptflops`；它们能正确处理每种模块类型。

### 步骤 3：训练后静态量化

```python
def quantise_ptq(model, calibration_loader, backend="x86"):
    import torch.ao.quantization as tq
    model = model.eval().cpu()
    model.qconfig = tq.get_default_qconfig(backend)
    tq.prepare(model, inplace=True)
    with torch.no_grad():
        for x, _ in calibration_loader:
            model(x)
    tq.convert(model, inplace=True)
    return model
```

三步：配置、准备（插入观察器）、用真实数据校准、转换（融合 + 量化）。要求模型已融合（`Conv -> BN -> ReLU` -> `ConvBnReLU`），这由 `torch.ao.quantization.fuse_modules` 处理。

### 步骤 4：导出到 ONNX

```python
def export_onnx(model, sample_input, path="model.onnx"):
    model = model.eval()
    torch.onnx.export(
        model,
        sample_input,
        path,
        input_names=["input"],
        output_names=["output"],
        dynamic_axes={"input": {0: "batch"}, "output": {0: "batch"}},
        opset_version=17,
    )
    return path
```

`opset_version=17` 是 2026 年的安全默认值。`dynamic_axes` 让你可以以任意 batch size 运行 ONNX 模型。

### 步骤 5：基准测试和比较不同方案

```python
import torch.nn as nn
from torchvision.models import mobilenet_v3_small

def compare_regimes():
    model = mobilenet_v3_small(weights=None, num_classes=10)
    params = parameter_count(model)
    flops = flops_estimate(model, (1, 3, 224, 224))
    lat_fp32 = measure_latency(model, (1, 3, 224, 224), device="cpu")
    print(f"FP32 MobileNetV3-Small: {params:,} 参数  {flops/1e9:.2f} GFLOPs  "
          f"p50={lat_fp32['p50_ms']:.2f}ms  p95={lat_fp32['p95_ms']:.2f}ms")
```

对 `resnet50`、`efficientnet_v2_s` 和 `convnext_tiny` 运行相同函数，就能得到部署决策所需的比较表。

## 使用

生产栈汇聚到以下三种路径之一：

- **Web / Serverless**：PyTorch -> ONNX -> ONNX Runtime（CPU 或 CUDA provider）。最简单，对大多数情况足够好。
- **NVIDIA 边缘（Jetson、GPU 服务器）**：PyTorch -> ONNX -> TensorRT。延迟最低，工程投入最大。
- **移动端**：PyTorch -> ONNX -> Core ML（iOS）或 TFLite（Android）。导出前量化。

对于测量，`torch-tb-profiler`、`nvprof` / `nsys` 和 macOS 上的 Instruments 提供逐层分解。`benchmark_app`（OpenVINO）和 `trtexec`（TensorRT）提供独立的 CLI 数值。

## 交付物

本课产出：

- `outputs/prompt-edge-deployment-planner.md`——一个 prompt，根据目标设备和延迟 SLA 选择骨干网络、量化策略和运行时。
- `outputs/skill-latency-profiler.md`——一个 skill，编写完整的延迟基准测试脚本，包含预热、同步、百分位数和内存跟踪。

## 练习

1. **（简单）** 在 CPU 上以 224x224 测量 `resnet18`、`mobilenet_v3_small`、`efficientnet_v2_s` 和 `convnext_tiny` 的 p50 延迟。报告表格并确定哪个架构有最佳的准确率/毫秒比。
2. **（中等）** 对 `mobilenet_v3_small` 应用训练后静态量化。报告 FP32 vs INT8 的延迟和在 CIFAR-10 或类似数据集留出子集上的准确率损失。
3. **（困难）** 将 `convnext_tiny` 导出为 ONNX，通过 `onnxruntime` 的 `CPUExecutionProvider` 运行，并将延迟与 PyTorch eager 基线比较。找出 ONNX Runtime 更快的第一个层并解释原因。

## 关键术语

| 术语 | 别人说的 | 实际含义 |
|------|---------|---------|
| 延迟 | "有多快" | 从输入到输出的时间；p50/p95/p99 百分位数，而非均值 |
| FLOPs | "模型大小" | 每次前向传播的浮点运算次数；计算成本的粗略代理指标 |
| INT8 量化 | "8 位" | 用 8 位整数替换 FP32 权重/激活值；约 4 倍更小，2-4 倍更快 |
| PTQ | "训练后量化" | 不需要重新训练来量化模型；简单，通常足够 |
| QAT | "量化感知训练" | 训练时模拟量化；精度最高，需要标注数据 |
| ONNX | "中性格式" | 所有主流推理运行时支持的模型交换格式 |
| TensorRT | "NVIDIA 编译器" | 将 ONNX 编译为 NVIDIA GPU 的优化引擎 |
| 蒸馏 | "教师 -> 学生" | 训练小模型模仿大模型的 logits；恢复大部分丢失的准确率 |

## 进一步阅读

- [EfficientNet (Tan & Le, 2019)](https://arxiv.org/abs/1905.11946) — 高效架构的复合缩放
- [MobileNetV3 (Howard et al., 2019)](https://arxiv.org/abs/1905.02244) — 移动端优先架构，带 h-swish 和 squeeze-excite
- [A Practical Guide to TensorRT Optimization (NVIDIA)](https://developer.nvidia.com/blog/accelerating-model-inference-with-tensorrt-tips-and-best-practices-for-pytorch-users/) — 如何真正获得论文中的吞吐量数据
- [ONNX Runtime 文档](https://onnxruntime.ai/docs/) — 量化、图优化、provider 选择