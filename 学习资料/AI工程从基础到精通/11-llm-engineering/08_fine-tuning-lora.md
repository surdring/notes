# 使用 LoRA 和 QLoRA 进行微调

> 全量微调一个 7B 模型需要 56GB 显存。你没有这么多。大多数公司也没有。LoRA 让你可以在 6GB 中微调同一个模型，只需训练不到 1% 的参数。这不是妥协——它在大多数任务上匹敌全量微调的质量。整个开源微调生态都建立在这一技巧之上。

**类型：** 构建
**语言：** Python
**先修要求：** Phase 10, Lesson 06（指令调优 / SFT）
**时间：** 约 75 分钟
**相关：** Phase 10 涵盖从零实现的 SFT/DPO 循环。本课将其接入 2026 年的 PEFT 工具链（PEFT、TRL、Unsloth、Axolotl、LLaMA-Factory）。

## 学习目标

- 通过向预训练模型的注意力层注入低秩适配器矩阵（A 和 B）实现 LoRA
- 计算 LoRA vs 全量微调的参数节省：秩 r 配合 d_model 维度训练 2*r*d 个参数而非 d²
- 使用 QLoRA（4 位量化基础模型 + LoRA 适配器）在消费级 GPU 内存中微调模型
- 将 LoRA 权重合并回基础模型用于部署，并比较有适配器和无适配器的推理速度

## 问题

你有一个基础模型。Llama 3 8B。你想让它以你公司的语气回答客户支持工单。SFT 是答案。但 SFT 有成本问题。

全量微调更新模型中的每个参数。Llama 3 8B 有 80 亿个参数。在 fp16 中，每个参数占 2 字节。仅加载权重就需要 16GB。在训练期间，你还需要梯度（16GB）、Adam 的优化器状态（momentum + variance 需要 32GB）和激活值。总计：单个 8B 模型大约需要 56GB 显存。

一张 A100 80GB 勉强能装下。两张 A100 在云提供商上每小时 $3-4。在 50,000 个样本上训练 3 个 epoch 需要 6-10 小时。每个实验 $30-40。运行 10 个实验来调优超参数，还没部署就花了 $400。

扩展到 Llama 3 70B，数字变得荒谬。仅权重就需要 140GB。你需要一个集群。每个实验 $100+。

还有一个更深层的问题。全量微调修改模型中的每个权重。如果你在客户支持数据上微调，可能会降低模型的一般能力。这叫做灾难性遗忘。模型在你的任务上变好了，但在其他所有方面都变差了。

你需要一种方法，训练更少的参数，使用更少的内存，且不破坏模型现有的知识。

## 概念

### LoRA：低秩适应（Low-Rank Adaptation）

微软的 Edward Hu 及其同事于 2021 年 6 月发表了 LoRA。论文的洞见：微调期间的权重更新具有低内在秩。你不需要更新一个 4096x4096 权重矩阵中的所有 1670 万个参数。更新中的有用信息可以被秩为 16 或 32 的矩阵捕获。

数学如下。一个标准线性层计算：

```
y = Wx
```

其中 W 是一个 d_out x d_in 矩阵。对于 4096x4096 的注意力投影，那是 16,777,216 个参数。

LoRA 冻结 W 并添加一个低秩分解：

```
y = Wx + BAx
```

其中 B 是 (d_out x r)，A 是 (r x d_in)。秩 r 远小于 d——通常是 8、16 或 32。

对于 4096x4096 层上的 r=16：
- 原始参数：4096 x 4096 = 16,777,216
- LoRA 参数：(4096 x 16) + (16 x 4096) = 65,536 + 65,536 = 131,072
- 减少：131,072 / 16,777,216 = 0.78%

你训练了 0.78% 的参数，获得了 95-100% 的质量。

```mermaid
graph LR
    X["输入 x"] --> W["冻结的 W (d x d)"]
    X --> A["A (r x d)"]
    A --> B["B (d x r)"]
    W --> Plus["+ (合并)"]
    B --> Plus
    Plus --> Y["输出 y"]

    style W fill:#1a1a2e,stroke:#e94560,color:#fff
    style A fill:#0f3460,stroke:#16213e,color:#fff
    style B fill:#0f3460,stroke:#16213e,color:#fff
```

A 用随机高斯分布初始化。B 初始化为零。这意味着 LoRA 贡献从零开始——模型从其原始行为开始训练，逐渐学习适应。

### 缩放因子：Alpha

LoRA 引入了一个缩放因子 alpha，控制低秩更新对输出的影响程度：

```
y = Wx + (alpha / r) * BAx
```

当 alpha = r 时，缩放为 1x。当 alpha = 2r（常见的默认值）时，缩放为 2x。这个超参数独立于基础学习率控制 LoRA 路径的学习率。

实用指导：
- alpha = 2 * rank 是常见的社区惯例（原始论文在大多数实验中使用 alpha = rank）
- alpha = rank 给出 1x 缩放，保守但稳定
- 更高的 alpha 意味着每步更大的更新，可以加速收敛或导致不稳定

### 在哪里应用 LoRA

Transformer 有很多线性层。你不需要对所有层都添加 LoRA。原始论文测试了不同的组合：

| 目标层 | 可训练参数 (7B) | 质量 |
|--------------|----------------------|---------|
| 仅 q_proj | 4.7M | 好 |
| q_proj + v_proj | 9.4M | 更好 |
| q_proj + k_proj + v_proj + o_proj | 18.9M | 注意力方面最佳 |
| 所有线性层（注意力 + MLP） | 37.7M | 边际增益，参数翻倍 |

大多数任务的最佳点：q_proj + v_proj。这针对自注意力中的查询和值投影，它们控制模型关注什么以及提取什么信息。添加 MLP 层对代码生成等复杂任务有帮助，但在简单任务上参数翻倍带来的回报递减。

### 秩选择

秩 r 控制适应的表达能力：

| 秩 | 可训练参数（每层） | 最适合 |
|------|---------------------------|----------|
| 4 | 32,768 | 简单分类，情感分析 |
| 8 | 65,536 | 单领域问答，摘要 |
| 16 | 131,072 | 多领域任务，指令遵循 |
| 32 | 262,144 | 复杂推理，代码生成 |
| 64 | 524,288 | 大多数任务回报递减 |
| 128 | 1,048,576 | 很少有必要 |

Hu 等人表明，对于简单任务，r=4 已经捕获了大部分适应。r=8 和 r=16 是实践中最常见的选择。超过 r=64 很少能提升质量，并开始失去 LoRA 的内存优势。

### QLoRA：4 位量化 + LoRA

华盛顿大学的 Tim Dettmers 及其同事于 2023 年 5 月发表了 QLoRA。思路：将冻结的基础模型量化为 4 位精度，然后在其上附加 fp16 的 LoRA 适配器。

这极大地改变了内存方程：

| 方法 | 权重要内存 (7B) | 训练内存 (7B) | 所需 GPU |
|--------|-------------------|---------------------|-------------|
| 全量微调 (fp16) | 14GB | ~56GB | 1x A100 80GB |
| LoRA (fp16 基础) | 14GB | ~18GB | 1x A100 40GB |
| QLoRA (4 位基础) | 3.5GB | ~6GB | 1x RTX 3090 24GB |

QLoRA 做出了三项技术贡献：

**NF4（Normal Float 4-bit）**：一种专门为神经网络权重设计的新数据类型。神经网络权重大致遵循正态分布。NF4 将其 16 个量化级别放置在标准正态分布的分位数上。这对于正态分布数据是在信息论上最优的。它比均匀 4 位量化（INT4）或标准 Float4 损失更少信息。

**双重量化（Double quantization）**：量化常数本身占用内存。每 64 个权重的块需要一个 fp32 缩放因子（4 字节）。对于 7B 模型，这是额外的 0.4GB。双重量化将这些常数量化为 fp8，将开销减少到 0.1GB。虽然小，但积少成多。

**分页优化器（Paged optimizers）**：训练期间，优化器状态（Adam 的 momentum 和 variance）在长序列上可能超出 GPU 内存。分页优化器使用 NVIDIA 的统一内存在 GPU 内存耗尽时自动将优化器状态分页到 CPU RAM，需要时再分页回来。这以防止 OOM 崩溃为代价，牺牲一些吞吐量。

### 质量问题

减少参数或量化基础模型会损害质量吗？多篇论文的结果：

| 方法 | MMLU (5-shot) | MT-Bench | HumanEval |
|--------|--------------|----------|-----------|
| 全量微调 (Llama 2 7B) | 48.3 | 6.72 | 14.6 |
| LoRA r=16 | 47.9 | 6.68 | 14.0 |
| QLoRA r=16 (NF4) | 47.5 | 6.61 | 13.4 |
| QLoRA r=64 (NF4) | 48.1 | 6.70 | 14.2 |

LoRA 在 r=16 时在大多数基准上在全量微调的 1% 以内。QLoRA 在 r=16 时再损失零点几个百分点。QLoRA 在 r=64 时基本匹配全量微调，同时使用少 90% 的内存。

### 真实成本

在 50,000 个样本（3 个 epoch）上微调 Llama 3 8B：

| 方法 | GPU | 时间 | 成本 |
|--------|-----|------|------|
| 全量微调 | 2x A100 80GB | 8 小时 | ~$32 |
| LoRA r=16 | 1x A100 40GB | 4 小时 | ~$8 |
| QLoRA r=16 | 1x RTX 4090 24GB | 6 小时 | ~$5 |
| QLoRA r=16 (Unsloth) | 1x RTX 4090 24GB | 2.5 小时 | ~$2 |
| QLoRA r=16 | 1x T4 16GB | 12 小时 | ~$4 |

在单张消费级 GPU 上使用 QLoRA 的成本不到一顿午餐。这就是为什么开源权重微调社区在 2023 年爆发，以及为什么 2026 年下面每个训练框架默认都提供 QLoRA。

### 2026 年 PEFT 工具栈

| 框架 | 是什么 | 何时选用 |
|-----------|-----------|-----------|
| **Hugging Face PEFT** | 标准的 LoRA/QLoRA/DoRA/IA3 库 | 你想要原始控制且训练循环已在 `transformers.Trainer` 上 |
| **TRL** | HF 的基于反馈的强化训练器（SFT、DPO、GRPO、PPO、ORPO） | 你在 SFT 之后需要 DPO/GRPO；构建在 PEFT 之上 |
| **Unsloth** | Triton 内核重写的前向/后向传播 | 你想要 2-5 倍加速 + 一半显存且无精度损失；Llama/Mistral/Qwen 系列 |
| **Axolotl** | 基于 YAML 配置的 PEFT + TRL + DeepSpeed + Unsloth 封装 | 你需要可复现、版本控制的训练运行 |
| **LLaMA-Factory** | 基于 PEFT + TRL 的 GUI/CLI/API | 你想要零代码微调；支持 100+ 模型系列 |
| **torchtune** | 原生 PyTorch recipes，不依赖 `transformers` | 你想要最少依赖，且你的组织已标准化 PyTorch |

经验法则：研究或一次性实验 → PEFT。可重复的生产管道 → 启用 Unsloth 内核的 Axolotl。快速原型 → LLaMA-Factory。

### 合并适配器

训练之后，你有两个东西：冻结的基础模型和一个小型 LoRA 适配器（通常 10-100MB）。你可以：

1. **保持分离**：加载基础模型，在上面加载适配器。为不同任务切换适配器。这就是你如何从一个基础模型服务多个微调变体。

2. **永久合并**：计算 W' = W + (alpha/r) * BA 并保存结果为一个新的完整模型。合并后的模型与原始模型大小相同。没有推理开销。没有适配器需要管理。

为了服务多个任务（客户支持适配器、代码适配器、翻译适配器），保持分离。为了部署单个专用模型，合并。

合并多个适配器的高级技术：

- **TIES-Merging**（Yadav 等，2023）：裁剪小幅度参数，解决符号冲突，然后合并。减少适配器之间的干扰。
- **DARE**（Yu 等，2023）：在合并前随机丢弃适配器参数并重新缩放剩余部分。在组合能力方面出奇地有效。
- **任务算术**：简单地添加或减去适配器权重。添加「代码」适配器和「数学」适配器通常产生在这两方面都好的模型。

### 何时不应该微调

微调是第三种选择，不是第一种。

**第一：提示词工程。** 写更好的系统提示词。添加少样本示例。使用思维链。这无需成本，只需几分钟。如果提示词能让你达到 80%，你可能不需要微调。

**第二：RAG。** 如果模型需要了解你的特定数据（文档、知识库、产品目录），检索比固化到权重中更便宜且更易维护。见 Lesson 06。

**第三：微调。** 当你需要模型采用特定的风格、格式或推理模式，仅通过提示词无法实现时使用。当你需要一致的 structured output 时。当你需要将更大的模型蒸馏为更小的模型时。当延迟很重要，你无法承受少样本提示词带来的额外 token 开销时。

```mermaid
graph TD
    Start["需要更好的模型行为?"] --> PE["尝试提示词工程"]
    PE -->|"有效"| Done["交付"]
    PE -->|"不够"| RAG["需要外部知识?"]
    RAG -->|"是"| RAGBuild["构建 RAG 管道"]
    RAG -->|"否, 需要风格/格式变更"| FT["用 LoRA/QLoRA 微调"]
    RAGBuild -->|"有效"| Done
    RAGBuild -->|"也需要风格变更"| FT
    FT --> Done

    style Start fill:#1a1a2e,stroke:#e94560,color:#fff
    style Done fill:#0f3460,stroke:#16213e,color:#fff
```

## 构建

我们使用纯 PyTorch 从零实现 LoRA。没有库。没有魔法。你将构建 LoRA 层，将其注入模型，训练它，并合并权重。

### 步骤 1：LoRA 层

```python
import torch
import torch.nn as nn
import math

class LoRALayer(nn.Module):
    def __init__(self, in_features, out_features, rank=8, alpha=16):
        super().__init__()
        self.rank = rank
        self.alpha = alpha
        self.scaling = alpha / rank

        self.A = nn.Parameter(torch.randn(in_features, rank) * (1 / math.sqrt(rank)))
        self.B = nn.Parameter(torch.zeros(rank, out_features))

    def forward(self, x):
        return (x @ self.A @ self.B) * self.scaling
```

A 用缩放的随机值初始化。B 初始化为零。乘积 BA 从零开始，所以模型从其原始行为开始。

### 步骤 2：LoRA 包装的线性层

```python
class LinearWithLoRA(nn.Module):
    def __init__(self, linear, rank=8, alpha=16):
        super().__init__()
        self.linear = linear
        self.lora = LoRALayer(
            linear.in_features, linear.out_features, rank, alpha
        )

        for param in self.linear.parameters():
            param.requires_grad = False

    def forward(self, x):
        return self.linear(x) + self.lora(x)
```

原始线性层被冻结。只有 LoRA 参数（A 和 B）是可训练的。

### 步骤 3：将 LoRA 注入模型

```python
def inject_lora(model, target_modules, rank=8, alpha=16):
    for param in model.parameters():
        param.requires_grad = False

    lora_layers = {}
    for name, module in model.named_modules():
        if isinstance(module, nn.Linear):
            if any(t in name for t in target_modules):
                parent_name = ".".join(name.split(".")[:-1])
                child_name = name.split(".")[-1]
                parent = dict(model.named_modules())[parent_name]
                lora_linear = LinearWithLoRA(module, rank, alpha)
                setattr(parent, child_name, lora_linear)
                lora_layers[name] = lora_linear
    return lora_layers
```

首先，冻结模型中的每个参数。然后遍历模型树，找到匹配目标名称的线性层，并用 LoRA 包装版本替换它们。LoRA 的 A 和 B 矩阵是整个模型中唯一可训练的参数。

### 步骤 4：统计参数

```python
def count_parameters(model):
    total = sum(p.numel() for p in model.parameters())
    trainable = sum(p.numel() for p in model.parameters() if p.requires_grad)
    frozen = total - trainable
    return {
        "total": total,
        "trainable": trainable,
        "frozen": frozen,
        "trainable_pct": 100 * trainable / total if total > 0 else 0
    }
```

### 步骤 5：合并权重

```python
def merge_lora_weights(model):
    for name, module in model.named_modules():
        if isinstance(module, LinearWithLoRA):
            with torch.no_grad():
                merged = (
                    module.lora.A @ module.lora.B
                ) * module.lora.scaling
                module.linear.weight.data += merged.T
            parent_name = ".".join(name.split(".")[:-1])
            child_name = name.split(".")[-1]
            if parent_name:
                parent = dict(model.named_modules())[parent_name]
            else:
                parent = model
            setattr(parent, child_name, module.linear)
```

合并后，LoRA 层消失了。模型与原始模型大小相同，适应性已固化到权重中。没有推理开销。

### 步骤 6：模拟 QLoRA 量化

```python
def quantize_to_nf4(tensor, block_size=64):
    blocks = tensor.reshape(-1, block_size)
    scales = blocks.abs().max(dim=1, keepdim=True).values / 7.0
    scales = torch.clamp(scales, min=1e-8)
    quantized = torch.round(blocks / scales).clamp(-8, 7).to(torch.int8)
    return quantized, scales

def dequantize_from_nf4(quantized, scales, original_shape):
    dequantized = quantized.float() * scales
    return dequantized.reshape(original_shape)
```

这通过将权重映射到 64 个块内的 16 个离散级别来模拟 4 位量化。生产级 QLoRA 使用 bitsandbytes 库在 GPU 上实现真正的 NF4。

### 步骤 7：训练循环

```python
def train_lora(model, data, epochs=5, lr=1e-3, batch_size=4):
    optimizer = torch.optim.AdamW(
        [p for p in model.parameters() if p.requires_grad], lr=lr
    )
    criterion = nn.MSELoss()

    losses = []
    for epoch in range(epochs):
        epoch_loss = 0.0
        n_batches = 0
        indices = torch.randperm(len(data["inputs"]))

        for i in range(0, len(indices), batch_size):
            batch_idx = indices[i:i + batch_size]
            x = data["inputs"][batch_idx]
            y = data["targets"][batch_idx]

            output = model(x)
            loss = criterion(output, y)

            optimizer.zero_grad()
            loss.backward()
            optimizer.step()

            epoch_loss += loss.item()
            n_batches += 1

        avg_loss = epoch_loss / n_batches
        losses.append(avg_loss)

    return losses
```

### 步骤 8：完整演示

```python
def demo():
    torch.manual_seed(42)
    d_model = 256
    n_classes = 10

    model = nn.Sequential(
        nn.Linear(d_model, 512),
        nn.ReLU(),
        nn.Linear(512, 512),
        nn.ReLU(),
        nn.Linear(512, n_classes),
    )

    n_samples = 500
    x = torch.randn(n_samples, d_model)
    y = torch.randint(0, n_classes, (n_samples,))
    y_onehot = torch.zeros(n_samples, n_classes).scatter_(1, y.unsqueeze(1), 1.0)

    data = {"inputs": x, "targets": y_onehot}

    params_before = count_parameters(model)

    lora_layers = inject_lora(
        model, target_modules=["0", "2"], rank=8, alpha=16
    )

    params_after = count_parameters(model)

    losses = train_lora(model, data, epochs=20, lr=1e-3)

    merge_lora_weights(model)
    params_merged = count_parameters(model)

    return {
        "params_before": params_before,
        "params_after": params_after,
        "params_merged": params_merged,
        "losses": losses,
    }
```

演示创建一个小模型，将 LoRA 注入两层，训练它，然后合并权重。参数数量从全量可训练下降到 LoRA 训练期间约 1% 可训练，然后合并后恢复到原始架构。

## 实际使用

使用 Hugging Face 生态，在真实模型上使用 LoRA 只需大约 20 行代码：

```python
from transformers import AutoModelForCausalLM, AutoTokenizer
from peft import LoraConfig, get_peft_model, TaskType

model = AutoModelForCausalLM.from_pretrained("meta-llama/Llama-3.1-8B")
tokenizer = AutoTokenizer.from_pretrained("meta-llama/Llama-3.1-8B")

lora_config = LoraConfig(
    task_type=TaskType.CAUSAL_LM,
    r=16,
    lora_alpha=32,
    lora_dropout=0.05,
    target_modules=["q_proj", "v_proj"],
)

model = get_peft_model(model, lora_config)
model.print_trainable_parameters()
```

对于 QLoRA，添加 bitsandbytes 量化：

```python
from transformers import BitsAndBytesConfig

bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_compute_dtype=torch.bfloat16,
    bnb_4bit_use_double_quant=True,
)

model = AutoModelForCausalLM.from_pretrained(
    "meta-llama/Llama-3.1-8B",
    quantization_config=bnb_config,
    device_map="auto",
)

model = get_peft_model(model, lora_config)
```

就这样。相同的训练循环。相同的数据管道。基础模型现在以 4 位存在，LoRA 适配器以 fp16 训练，整个东西装入 6GB。

使用 Hugging Face Trainer 训练：

```python
from transformers import TrainingArguments, Trainer
from datasets import load_dataset

dataset = load_dataset("tatsu-lab/alpaca", split="train[:5000]")

training_args = TrainingArguments(
    output_dir="./lora-llama",
    num_train_epochs=3,
    per_device_train_batch_size=4,
    gradient_accumulation_steps=4,
    learning_rate=2e-4,
    fp16=True,
    logging_steps=10,
    save_strategy="epoch",
    optim="paged_adamw_8bit",
)

trainer = Trainer(
    model=model,
    args=training_args,
    train_dataset=dataset,
)

trainer.train()

model.save_pretrained("./lora-adapter")
```

保存的适配器是 10-100MB。基础模型保持不变。你可以在 Hugging Face Hub 上共享适配器而无需重新分发完整模型。

## 交付

本课产出：
- `outputs/prompt-lora-advisor.md`——帮助你就特定任务决定 LoRA 秩、目标模块和超参数的提示词
- `outputs/skill-fine-tuning-guide.md`——教 agent 何时以及如何微调的决策树的技能

## 练习

1. **秩消融研究。** 使用秩 2、4、8、16、32 和 64 运行演示。绘制最终损失 vs 秩。找到回报递减点，即加倍秩不再能减半损失。对于 256 维特征的简单分类任务，这应该在 r=8-16 左右。

2. **目标模块比较。** 修改 inject_lora 只针对层「0」、只针对层「2」、只针对层「4」以及全部三个。每个变体训练 20 个 epoch。比较收敛速度和最终损失。这反映了真实的决策：针对 q_proj vs v_proj vs 所有线性层。

3. **量化误差分析。** 在 quantize_to_nf4 / dequantize_from_nf4 前后取训练模型权重矩阵。计算均方误差、最大绝对误差以及原始和重构权重之间的相关性。用 block_size 值 32、64、128 和 256 进行实验。

4. **多适配器服务。** 在数据的不同子集上训练两个 LoRA 适配器（偶数索引 vs 奇数索引）。保存两个适配器。加载一次基础模型，然后交换适配器并验证每个适配器在相同输入上产生不同输出。这是生产系统如何从一个基础模型服务多个微调模型的方式。

5. **合并 vs 非合并推理。** 在 merge_lora_weights 前后比较 LoRA 模型在相同 100 个输入上的输出。验证输出完全相同（在浮点容差 1e-5 以内）。然后对两者的推理速度进行基准测试——合并后应该稍快一些，因为它是单次矩阵乘法而非两次。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|----------------|----------------------|
| LoRA | 「高效微调」 | 低秩适应（Low-Rank Adaptation）：冻结基础权重，训练两个小矩阵 A 和 B，其乘积近似完整的权重更新 |
| QLoRA | 「在笔记本上微调」 | 量化 LoRA：以 4 位 NF4 加载基础模型，在其上以 fp16 训练 LoRA 适配器，使 7B 微调在 6GB 显存中成为可能 |
| 秩 (r) | 「模型能学多少」 | A 和 B 矩阵的内维度；控制表达能力与参数数量 |
| Alpha | 「LoRA 学习率」 | 应用于 LoRA 输出的缩放因子；alpha/r 缩放适应对最终输出的贡献 |
| NF4 | 「4 位量化」 | Normal Float 4：一种 4 位数据类型，量化级别位于正态分布分位数上，对神经网络权重最优 |
| 适配器 | 「小的训练部分」 | 保存为单独文件（10-100MB）的 LoRA A 和 B 矩阵，可在任何基础模型副本上加载 |
| 目标模块 | 「对哪些层做 LoRA」 | 注入 LoRA 适配器的特定线性层（q_proj、v_proj 等） |
| 合并 | 「固化进去」 | 计算 W + (alpha/r) * BA 并替换原始权重，消除推理时的适配器开销 |
| 分页优化器 | 「训练时不要 OOM」 | 当 GPU 内存耗尽时将优化器状态（Adam momentum、variance）卸载到 CPU |
| 灾难性遗忘 | 「微调毁了其他一切」 | 当更新所有权重导致模型丢失先前学到的能力时 |

## 扩展阅读

- Hu 等, "LoRA: Low-Rank Adaptation of Large Language Models" (2021) -- 提出低秩分解方法的原始论文，在 GPT-3 175B 上测试，秩低至 4
- Dettmers 等, "QLoRA: Efficient Finetuning of Quantized Language Models" (2023) -- 引入 NF4、双重量化和分页优化器，使 65B 微调在单张 48GB GPU 上成为可能
- PEFT 库文档 (huggingface.co/docs/peft) -- Hugging Face 生态中 LoRA、QLoRA 和其他参数高效方法的标准库
- Yadav 等, "TIES-Merging: Resolving Interference When Merging Models" (2023) -- 组合多个 LoRA 适配器而不损失质量的技术
- [Rafailov 等, "Direct Preference Optimization: Your Language Model is Secretly a Reward Model" (NeurIPS 2023)](https://arxiv.org/abs/2305.18290) -- DPO 推导；SFT 之后的偏好调优阶段，不需要奖励模型。
- [TRL 文档](https://huggingface.co/docs/trl/) -- `SFTTrainer`、`DPOTrainer`、`KTOTrainer` 以及与 PEFT/bitsandbytes/Unsloth 集成接口的官方参考。
- [Unsloth 文档](https://docs.unsloth.ai/) -- 将微调吞吐量翻倍并将内存减半的融合内核；TRL 下的性能层。
- [Axolotl 文档](https://axolotl-ai-cloud.github.io/axolotl/) -- YAML 配置的多 GPU SFT/DPO/QLoRA 训练器；手写脚本的配置即代码替代方案。