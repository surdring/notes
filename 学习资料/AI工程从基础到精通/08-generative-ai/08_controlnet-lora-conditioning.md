# ControlNet、LoRA 与条件化

> 仅靠文本是笨拙的控制信号。ControlNet 让你克隆预训练的扩散模型并用深度图、姿态骨架、涂鸦或边缘图像来驾驭它。LoRA 让你通过训练 1 千万参数来微调 2B 参数的模型。它们一起把 Stable Diffusion 从玩具变成了每个代理商在 2026 年交付的图像流水线。

**类型：** 构建
**语言：** Python
**前置要求：** 第 8 阶段 · 07（潜在扩散），第 10 阶段（从头构建 LLM——LoRA 基础）
**时间：** 约 75 分钟

## 问题

像"一个穿红裙子的女人在繁忙的街道遛狗"这样的提示，没有告诉模型狗在*哪里*，女人是什么*姿态*，或者街道的*视角*。文本固定了指定图像所需的约 10%。其余的是视觉的，无法用语言高效描述。

为每个信号（姿态、深度、canny、分割）从头训练新的条件模型是昂贵的。你想保持 2.6B 参数的 SDXL 骨干冻结，附加一个读取条件的小型侧网络，并让它推动骨干的中间特征。这就是 ControlNet。

你还想教模型新概念（你的脸、你的产品、你的风格）而不重新训练完整模型。你想要一个小 100 倍的增量。这就是 LoRA——插入现有注意力权重的低秩适配器。

ControlNet + LoRA + 文本 = 2026 年实践者的工具包。大多数生产图像流水线在 SDXL / SD3 / Flux 基础之上层叠 2-5 个 LoRA、1-3 个 ControlNet 和一个 IP-Adapter。

## 概念

![ControlNet 克隆编码器；LoRA 添加低秩增量](../assets/controlnet-lora.svg)

### ControlNet（Zhang et al., 2023）

取一个预训练的 SD。*克隆* U-Net 的编码器半部分。冻结原版。训练克隆以接受额外的条件输入（边缘、深度、姿态）。用*零卷积*跳跃连接（初始化为零的 1×1 卷积——从无操作开始，学习增量）将克隆连接回原版的解码器半部分。

```
SD U-Net 解码器：  ... ← orig_enc_features + zero_conv(controlnet_enc(condition))
```

零卷积初始化意味着 ControlNet 从恒等开始——即使在训练前也没有损害。在 1M（提示、条件、图像）三元组上用标准扩散损失训练。

每种模态的 ControlNet 作为小型侧模型交付（SDXL 约 360M，SD 1.5 约 70M）。你可以在推理时组合它们：

```
features += weight_a * control_a(depth) + weight_b * control_b(pose)
```

### LoRA（Hu et al., 2021）

对于模型中任何线性层 `W ∈ R^{d×d}`，冻结 `W` 并添加低秩增量：

```
W' = W + ΔW,  ΔW = B @ A,  A ∈ R^{r×d},  B ∈ R^{d×r}
```

其中 `r << d`。注意力通常用秩 4-16，重型微调用秩 64-128。新参数数量：`2 · d · r` 而不是 `d²`。对于 `d=640` 的 SDXL 注意力，`r=16`：每个适配器 20k 参数而不是 410k——20 倍的减少。整个模型中：一个 LoRA 通常 20-200MB，而基础模型 5GB。

在推理时你可以放缩 LoRA：`W' = W + α · B @ A`。`α = 0.5-1.5` 是正常的。多个 LoRA 可加性堆叠（通常注意它们以非线性方式相互作用）。

### IP-Adapter（Ye et al., 2023）

一个微小的适配器，接受*图像*作为条件（与文本一起）。使用 CLIP 图像编码器产生图像标记，将它们注入到交叉注意力中与文本标记一起。每个基础模型约 20MB。让你"以这个参考的风格生成图像"而不需要 LoRA。

## 可组合性矩阵

| 工具 | 控制什么 | 大小 | 何时使用 |
|------|------------------|------|-------------|
| ControlNet | 空间结构（姿态、深度、边缘） | 70-360MB | 精确布局、构图 |
| LoRA | 风格、主题、概念 | 20-200MB | 个性化、风格 |
| IP-Adapter | 来自参考图像的风格或主题 | 20MB | 没有文本能描述外观 |
| Textual Inversion | 单个概念作为新标记 | 10KB | 遗留，大多被 LoRA 替代 |
| DreamBooth | 主题完整微调 | 2-5GB | 强身份，高计算 |
| T2I-Adapter | 更轻的 ControlNet 替代 | 70MB | 边缘设备，推理预算 |

ControlNet ≈ 空间的。LoRA ≈ 语义的。两者都用。

## 构建

`code/main.py` 在 1-D 上模拟这两种机制：

1. **LoRA。** 一个预训练的线性层 `W`。冻结它。训练一个低秩的 `B @ A` 使 `W + BA` 匹配目标线性层。展示 `r = 1` 足以完美学习一个秩 1 修正。

2. **ControlNet-lite。** 一个"冻结基"预测器和一个读取额外信号的"侧网络"。侧网络的输出由一个初始化为零的可学习标量门控（我们的零卷积版本）。训练并观察门控上升。

### 步骤 1：LoRA 数学

```python
def lora(W, A, B, x, alpha=1.0):
    # W 被冻结；A, B 是可训练的低秩因子。
    return [W[i][j] * x[j] for i, j in ...] + alpha * (B @ (A @ x))
```

### 步骤 2：零初始化侧网络

```python
side_out = control_net(x, condition)
gated = gate * side_out  # gate 初始化为 0
h = base(x) + gated
```

在步骤 0，输出与基础相同。早期训练缓慢更新 `gate`——没有灾难性漂移。

## 陷阱

- **过度放缩 LoRA。** `α = 2` 或 `α = 3` 是常见的"让它更强"的技巧，产生过风格化 / 破损的输出。保持 `α ≤ 1.5`。
- **ControlNet 权重冲突。** 使用权 1.0 的 Pose ControlNet 和权重 1.0 的 Depth ControlNet 通常过冲。权重之和 ≈ 1.0 是安全默认。
- **在错误基础上使用 LoRA。** SDXL LoRA 在 SD 1.5 上静默无操作，因为注意力维度不匹配。Diffusers 将在 0.30+ 中警告。
- **Textual Inversion 漂移。** 在一个检查点上训练的标记在另一个上严重漂移。LoRA 更具可移植性。
- **LoRA 权重合并和存储。** 你可以将 LoRA 烘焙到基础模型权重中以加快推理（无运行时加法），但你失去了在运行时缩放 `α` 的能力。保留两个版本。

## 使用

| 目标 | 2026 年流水线 |
|------|---------------|
| 重现品牌的风格 | 在约 30 张精选图像上以秩 32 训练的 LoRA |
| 将我的脸放入生成的图像 | DreamBooth 或 LoRA + IP-Adapter-FaceID |
| 特定姿态 + 提示 | ControlNet-Openpose + SDXL + 文本 |
| 深度感知构图 | ControlNet-Depth + SD3 |
| 参考 + 提示 | IP-Adapter + 文本 |
| 精确布局 | ControlNet-Scribble 或 ControlNet-Canny |
| 背景替换 | ControlNet-Seg + Inpainting（第 09 课） |
| 快速 1 步风格 | SDXL-Turbo 上的 LCM-LoRA |

## 交付

保存 `outputs/skill-sd-toolkit-composer.md`。技能接受任务（输入资产：提示，可选参考图像，可选姿态，可选深度，可选涂鸦）并输出工具栈、权重和可重现的随机种子协议。

## 练习

1. **简单。** 在 `code/main.py` 中，将 LoRA 秩 `r` 从 1 变到 4。在什么秩时 LoRA 精确匹配秩 2 的目标增量？
2. **中等。** 在两个目标变换上训练两个单独的 LoRA。一起加载它们并显示它们的加法交互。交互何时打破线性？
3. **困难。** 使用 diffusers 堆叠：SDXL-base + Canny-ControlNet（权重 0.8）+ 一个风格 LoRA（α 0.8）+ IP-Adapter（权重 0.6）。随着堆叠权重的变化，测量 FID 与提示遵循之间的权衡。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|-----------------------|
| ControlNet | "空间控制" | 克隆编码器 + 零卷积跳跃连接；读取条件图像。 |
| 零卷积 | "从恒等开始" | 初始化为零的 1×1 卷积；ControlNet 从无操作开始。 |
| LoRA | "低秩适配器" | `W + B @ A`，`r << d`；比完整微调少 100 倍参数。 |
| rank r | "旋钮" | LoRA 压缩；4-16 典型，64+ 用于重型个性化。 |
| α | "LoRA 强度" | LoRA 增量的运行时缩放。 |
| IP-Adapter | "参考图像" | 通过 CLIP-图像标记的小型图像条件适配器。 |
| DreamBooth | "完整主题微调" | 在主题约 30 张图像上训练完整模型。 |
| Textual Inversion | "新标记" | 仅学习新的词嵌入；遗留，大多被替代。 |

## 生产说明：LoRA 交换、ControlNet 通道、多租户服务

真正的文本到图像 SaaS 在相同基础检查点上服务数百个 LoRA 和十几个 ControlNets。服务问题看起来很像 LLM 多租户（生产文献在连续批处理和 LoRAX / S-LoRA 下涵盖 LLM 案例）：

- **热交换 LoRA，不要合并。** 将 `W' = W + α·B·A` 合并到基础中给每步推理约 3-5% 加速但冻结 `α` 和基础。将 LoRA 作为秩 r 增量热保存在 VRAM 中；diffusers 暴露 `pipe.load_lora_weights()` + `pipe.set_adapters([...], adapter_weights=[...])` 用于每请求激活。交换成本是 `2 · d · r · num_layers` 权重——MB 级，亚秒级。
- **ControlNet 作为第二注意力通道。** 克隆编码器与基础并行运行。两个 ControlNet 各权重 1.0 = 每步两个额外前向传播，不是一个合并传播。批大小余量二次下降。预算每个活跃 ControlNet 约 1.5 倍步成本。
- **量化的 LoRA 也可以。** 如果你量化了基础（见第 07 课，Flux 在 8GB 上），LoRA 增量也可以干净地量化为 8 位或 4 位。QLoRA 式加载让你在 4 位 Flux 基础上堆叠 5-10 个 LoRA 而不爆内存。

Flux 特定：Niels 的 Flux-on-8GB notebook 将基础量化为 4 位；在该量化基础上堆叠一个风格 LoRA（`pipe.load_lora_weights("user/style-lora")`）在 `weight_name="pytorch_lora_weights.safetensors"` 仍然可以工作。这是大多数 SaaS 代理商在 2026 年交付的配方。

## 扩展阅读

- [Zhang, Rao, Agrawala (2023). Adding Conditional Control to Text-to-Image Diffusion Models](https://arxiv.org/abs/2302.05543)——ControlNet。
- [Hu et al. (2021). LoRA: Low-Rank Adaptation of Large Language Models](https://arxiv.org/abs/2106.09685)——LoRA（最初用于 LLM；移植到扩散）。
- [Ye et al. (2023). IP-Adapter: Text Compatible Image Prompt Adapter](https://arxiv.org/abs/2308.06721)——IP-Adapter。
- [Mou et al. (2023). T2I-Adapter: Learning Adapters to Dig Out More Controllable Ability](https://arxiv.org/abs/2302.08453)——对 ControlNet 更轻量的替代。
- [Ruiz et al. (2023). DreamBooth: Fine Tuning Text-to-Image Diffusion Models for Subject-Driven Generation](https://arxiv.org/abs/2208.12242)——DreamBooth。
- [HuggingFace Diffusers — ControlNet / LoRA / IP-Adapter 文档](https://huggingface.co/docs/diffusers/training/controlnet)——参考流水线。