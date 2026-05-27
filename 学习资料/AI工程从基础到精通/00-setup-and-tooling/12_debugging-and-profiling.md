# 调试与性能分析

> 最糟糕的 AI bug 不会崩溃。它们默默地在垃圾数据上训练，却报告出漂亮的损失曲线。

**类型：** 构建
**使用语言：** Python
**前置课程：** 第 01 课（开发环境），基本 PyTorch 知识
**预计时间：** ~60 分钟

## 学习目标

- 使用条件 `breakpoint()` 和 `debug_print` 在训练过程中检查张量形状、数据类型和 NaN 值
- 使用 `cProfile`、`line_profiler` 和 `tracemalloc` 对训练循环进行性能分析以找到瓶颈
- 检测常见的 AI bug：形状不匹配、NaN 损失、数据泄漏和设备错误的张量
- 设置 TensorBoard 来可视化损失曲线、权重直方图和梯度分布

## 问题

AI 代码的失败方式与其他代码不同。Web 应用崩溃会伴随堆栈跟踪报错。配置错误的训练循环运行 8 小时，烧掉 $200 的 GPU 时间，产出一个对每个输入都预测均值的模型。代码从未报错。Bug 是一个在错误设备上的张量、一个忘记的 `.detach()` 或特征中泄漏的标签。

你需要能捕获这些静默失败的调试工具，在它们浪费你的时间和计算资源之前。

## 概念

AI 调试在三个层次上运作：

```mermaid
graph TD
    L3["3. 训练动态\n损失曲线、梯度范数、激活值"] --> L2
    L2["2. 张量操作\n形状、数据类型、设备、NaN/Inf 值"] --> L1
    L1["1. 标准 Python\n断点、日志、性能分析、内存"]
```

大多数人直接跳到第 3 层（盯着 TensorBoard）。但 80% 的 AI bug 存在于第 1 和第 2 层。

## 构建它

### 第 1 部分：打印调试（是的，它有效）

打印调试通常被轻视，但不应该。对于张量代码，有针对性的 print 语句胜过在调试器中逐步执行，因为你需要同时看到形状、数据类型和值范围。

```python
def debug_print(name, tensor):
    print(f"{name}: shape={tensor.shape}, dtype={tensor.dtype}, "
          f"device={tensor.device}, "
          f"min={tensor.min().item():.4f}, max={tensor.max().item():.4f}, "
          f"mean={tensor.mean().item():.4f}, "
          f"has_nan={tensor.isnan().any().item()}")
```

在每次可疑操作后调用它。找到 bug 后，移除打印语句。简单。

### 第 2 部分：Python 调试器（pdb 和 breakpoint）

内置调试器在 AI 工作中被低估了。在训练循环中放置 `breakpoint()` 并交互式检查张量。

```python
def training_step(model, batch, criterion, optimizer):
    inputs, labels = batch
    outputs = model(inputs)
    loss = criterion(outputs, labels)

    if loss.item() > 100 or torch.isnan(loss):
        breakpoint()

    loss.backward()
    optimizer.step()
```

当调试器把你放下时，有用的命令：

- `p outputs.shape` 检查形状
- `p loss.item()` 查看损失值
- `p torch.isnan(outputs).sum()` 统计 NaN 数量
- `p model.fc1.weight.grad` 检查梯度
- `c` 继续，`q` 退出

这是条件调试。你只在有什么看起来不对时才停止。对于 10,000 步的训练运行，这一点很重要。

### 第 3 部分：Python 日志记录

当调试超出快速检查范围时，将 print 语句替换为日志记录。

```python
import logging

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler("training.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

logger.info("开始训练: lr=%.4f, batch_size=%d", lr, batch_size)
logger.warning("检测到损失峰值: %.4f，步数 %d", loss.item(), step)
logger.error("步数 %d 处损失为 NaN，停止", step)
```

日志记录给你时间戳、严重级别和文件输出。当训练在凌晨 3 点失败时，你需要的是日志文件，而不是已经被滚动掉的终端输出。

### 第 4 部分：代码段计时

知道时间花在哪里是优化的第一步。

```python
import time

class Timer:
    def __init__(self, name=""):
        self.name = name

    def __enter__(self):
        self.start = time.perf_counter()
        return self

    def __exit__(self, *args):
        elapsed = time.perf_counter() - self.start
        print(f"[{self.name}] {elapsed:.4f}s")

with Timer("数据加载"):
    batch = next(dataloader_iter)

with Timer("前向传播"):
    outputs = model(batch)

with Timer("反向传播"):
    loss.backward()
```

常见发现：数据加载占用 60% 的训练时间。修复方法是在 DataLoader 中设置 `num_workers > 0`，而不是用更快的 GPU。

### 第 5 部分：cProfile 和 line_profiler

当需要比手动计时更多时：

```bash
python -m cProfile -s cumtime train.py
```

这显示按累积时间排序的每个函数调用。对于逐行分析：

```bash
pip install line_profiler
```

```python
@profile
def train_step(model, data, target):
    output = model(data)
    loss = F.cross_entropy(output, target)
    loss.backward()
    return loss

# 使用 kernprof -l -v train.py 运行
```

### 第 6 部分：内存分析

#### 使用 tracemalloc 分析 CPU 内存

```python
import tracemalloc

tracemalloc.start()

# 你的代码
model = build_model()
data = load_dataset()

snapshot = tracemalloc.take_snapshot()
top_stats = snapshot.statistics("lineno")
for stat in top_stats[:10]:
    print(stat)
```

#### 使用 memory_profiler 分析 CPU 内存

```bash
pip install memory_profiler
```

```python
from memory_profiler import profile

@profile
def load_data():
    raw = read_csv("data.csv")       # 观察内存跳跃
    processed = preprocess(raw)       # 以及这里
    return processed
```

使用 `python -m memory_profiler your_script.py` 运行以查看逐行内存使用情况。

#### 使用 PyTorch 分析 GPU 内存

```python
import torch

if torch.cuda.is_available():
    print(torch.cuda.memory_summary())

    print(f"已分配: {torch.cuda.memory_allocated() / 1e9:.2f} GB")
    print(f"已缓存: {torch.cuda.memory_reserved() / 1e9:.2f} GB")
```

当遇到 OOM（内存不足）时：

1. 减小批量大小（总是先尝试这个）
2. 使用 `torch.cuda.empty_cache()` 释放缓存内存
3. 对大型中间结果使用 `del tensor` 后跟 `torch.cuda.empty_cache()`
4. 使用混合精度（`torch.cuda.amp`）将内存使用减半
5. 对非常深的模型使用梯度检查点

### 第 7 部分：常见 AI Bug 及其捕获方法

#### 形状不匹配

最常见的 bug。当模型期望 `[batch, channels, height, width]` 时，张量形状是 `[batch, features]`。

```python
def check_shapes(model, sample_input):
    print(f"输入: {sample_input.shape}")
    hooks = []

    def make_hook(name):
        def hook(module, inp, out):
            in_shape = inp[0].shape if isinstance(inp, tuple) else inp.shape
            out_shape = out.shape if hasattr(out, "shape") else type(out)
            print(f"  {name}: {in_shape} -> {out_shape}")
        return hook

    for name, module in model.named_modules():
        hooks.append(module.register_forward_hook(make_hook(name)))

    with torch.no_grad():
        model(sample_input)

    for h in hooks:
        h.remove()
```

用样本批次运行一次。它会映射模型中的每次形状变换。

#### NaN 损失

NaN 损失意味着某些东西爆炸了。常见原因：

- 学习率过高
- 自定义损失中的除以零
- 对零或负数取对数
- RNN 中的梯度爆炸

```python
def detect_nan(model, loss, step):
    if torch.isnan(loss):
        print(f"步数 {step} 处损失为 NaN")
        for name, param in model.named_parameters():
            if param.grad is not None:
                if torch.isnan(param.grad).any():
                    print(f"  {name} 中梯度为 NaN")
                if torch.isinf(param.grad).any():
                    print(f"  {name} 中梯度为 Inf")
        return True
    return False
```

#### 数据泄漏

你的模型在测试集上达到 99% 准确率。听起来很棒。但这是一个 bug。

```python
def check_data_leakage(train_set, test_set, id_column="id"):
    train_ids = set(train_set[id_column].tolist())
    test_ids = set(test_set[id_column].tolist())
    overlap = train_ids & test_ids
    if overlap:
        print(f"数据泄漏: {len(overlap)} 个样本同时在训练集和测试集中")
        return True
    return False
```

还要检查时间泄漏：使用未来数据预测过去。在划分前按时间戳排序。

#### 错误的设备

不同设备上的张量（CPU vs GPU）会导致运行时错误。但有时一个张量悄无声息地留在 CPU 上，而其他所有张量都在 GPU 上，训练只是运行得慢。

```python
def check_devices(model, *tensors):
    model_device = next(model.parameters()).device
    print(f"模型设备: {model_device}")
    for i, t in enumerate(tensors):
        if t.device != model_device:
            print(f"  警告: 张量 {i} 在 {t.device} 上，模型在 {model_device} 上")
```

### 第 8 部分：TensorBoard 基础

TensorBoard 随时间展示训练内部发生的情况。

```bash
pip install tensorboard
```

```python
from torch.utils.tensorboard import SummaryWriter

writer = SummaryWriter("runs/experiment_1")

for step in range(num_steps):
    loss = train_step(model, batch)

    writer.add_scalar("loss/train", loss.item(), step)
    writer.add_scalar("lr", optimizer.param_groups[0]["lr"], step)

    if step % 100 == 0:
        for name, param in model.named_parameters():
            writer.add_histogram(f"weights/{name}", param, step)
            if param.grad is not None:
                writer.add_histogram(f"grads/{name}", param.grad, step)

writer.close()
```

启动它：

```bash
tensorboard --logdir=runs
```

需要注意的：

- **损失不下降**：学习率太低，或模型架构问题
- **损失剧烈波动**：学习率太高
- **损失变为 NaN**：数值不稳定（参见上面的 NaN 部分）
- **训练损失下降，验证损失上升**：过拟合
- **权重直方图塌缩到零**：梯度消失
- **梯度直方图爆炸**：需要梯度裁剪

### 第 9 部分：VS Code 调试器

要进行交互式调试，使用 `launch.json` 配置 VS Code：

```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "调试训练",
            "type": "debugpy",
            "request": "launch",
            "program": "${file}",
            "console": "integratedTerminal",
            "justMyCode": false
        }
    ]
}
```

点击行号左侧设置断点。使用变量窗格检查张量属性。调试控制台让你在代码执行中途运行任意 Python 表达式。

对于单步执行数据预处理流水线很有用，能查看每次转换。

## 使用它

以下是捕获大多数 AI bug 的调试工作流：

1. **训练前**：用样本批次运行 `check_shapes`。验证输入和输出维度是否符合预期。
2. **前 10 步**：对损失、输出和梯度使用 `debug_print`。确认没有任何 NaN，值在合理范围内。
3. **训练期间**：记录损失、学习率和梯度范数。使用 TensorBoard 进行可视化。
4. **当某些东西出问题时**：在故障点放置 `breakpoint()`。交互式检查张量。
5. **性能方面**：计时数据加载 vs 前向传播 vs 反向传播。如果接近 OOM，分析内存。

## 交付

运行调试工具包脚本：

```bash
python phases/00-setup-and-tooling/12-debugging-and-profiling/code/debug_tools.py
```

参见 `outputs/prompt-debug-ai-code.md` 获取帮助诊断 AI 特有 bug 的提示词。

## 练习

1. 运行 `debug_tools.py` 并阅读每个部分的输出。修改虚拟模型引入 NaN（提示：在前向传播中除以零）并观察检测器捕获它。
2. 使用 `cProfile` 分析一个训练循环，找出最慢的函数。
3. 使用 `tracemalloc` 找出数据加载流水线中哪一行分配了最多的内存。
4. 为一个简单的训练运行设置 TensorBoard，判断模型是否过拟合。
5. 在训练循环中使用 `breakpoint()`。练习从调试器提示中检查张量形状、设备和梯度值。`