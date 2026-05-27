# Janus-Pro：统一多模态模型的解耦编码器

> 统一多模态模型存在一个无法回避的矛盾。理解需要语义特征——SigLIP 或 DINOv2 输出富含概念级信息的向量。生成需要适合重建的编码——能够组合回清晰像素的 VQ Token。这两个目标在单一编码器中无法兼容。Janus（DeepSeek，2024年10月）和 Janus-Pro（DeepSeek，2025年1月）认为解决方案就是停止尝试统一：将两个编码器解耦。在任务之间共享 Transformer 主体，但将理解路径路由到 SigLIP，将生成路径路由到 VQ 分词器。在 7B 参数规模下，Janus-Pro 在 GenEval 上超越了 DALL-E 3，同时在 MMMU 上与 LLaVA 持平。本课将解读为什么两个编码器在一个编码器失败的地方取得了成功。

**类型：** 构建
**语言：** Python（标准库，双编码器路由 + 共享主体信号）
**前置要求：** 第12阶段 · 13（Transfusion），第12阶段 · 14（Show-o）
**时间：** ~120分钟

## 学习目标

- 解释为什么单一共享编码器会损害理解或生成质量。
- 描述 Janus-Pro 的路由机制：理解路径输入侧使用 SigLIP 特征，生成路径输入和输出侧使用 VQ Token。
- 追踪使 Janus-Pro 成功而 Janus 未能成功的数据混合扩展策略。
- 对比解耦（Janus-Pro）、耦合-连续（Transfusion）和耦合-离散（Show-o）架构。

## 问题

统一模型在理解和生成任务之间共享 Transformer 主体。以往的尝试（Chameleon、Show-o、Transfusion）在两个方向上都使用同一个视觉分词器。该分词器是一种折中：

- 为重建（生成）优化：VQ-VAE 捕获细粒度像素细节，但产生的 Token 语义连贯性较弱。
- 为语义（理解）优化：SigLIP 嵌入将"猫"图像与"猫"文本 Token 聚合在一起，但无法实现良好的重建。

Show-o 和 Transfusion 为此在某一方向上付出了明显的质量代价。Janus-Pro 提出的问题是：当任务有不同需求时，为什么要强制使用一个分词器？

## 核心概念

### 解耦的视觉编码

Janus-Pro 的架构将两个编码器分离：

- 理解路径。输入图像 → SigLIP-SO400m → 2层 MLP → Transformer 主体。
- 生成路径。输入图像（如果以现有图像为条件）→ VQ 分词器 → Token ID → Transformer 主体。
- 输出生成。Transformer 预测的图像 Token → VQ 解码器 → 像素。

Transformer 主体是共享的。主体上下游的所有内容都是任务特定的。

输入通过提示格式进行区分：`<understand>` 标签路由到 SigLIP；`<generate>` 路由到 VQ。或者路由由任务隐式决定。

### 为什么这能行

理解损失获得 SigLIP 特征，而 CLIP 风格的预训练已经针对语义相似性进行了调优。由于输入特征更适合任务，模型的感知基准测试结果优于 Show-o / Transfusion。

生成损失获得 VQ Token，分词器已针对重建进行了优化。由于 VQ 编码可以干净地组合回像素，图像质量优于 Show-o。

共享的 Transformer 主体看到两种输入分布（SigLIP 和 VQ），并学会处理两者。其核心主张是：足够的数据 + 足够的参数，主体能够适应这种切换。

### 数据扩展——Janus vs Janus-Pro

Janus（原始版本，arXiv 2410.13848）引入了编码器解耦，但规模较小（1.3B 参数，数据有限）。Janus-Pro（arXiv 2501.17811）进行了扩展：

- 7B 参数（vs 1.3B）。
- 第一阶段（对齐）9000万图文对，高于之前的7200万。
- 第二阶段（统一）7200万，高于之前的2600万。
- 第三阶段新增20万图像生成指令样本。

结果：Janus-Pro-7B 在 MMMU 上持平 LLaVA（60.3 vs ~58），在 GenEval 上超越 DALL-E 3（0.80 vs 0.67）。一个开源模型，在统一谱系的两端都具有竞争力。

### JanusFlow——整流流变体

JanusFlow（arXiv 2411.07975）将 VQ 生成路径替换为整流流（Rectified Flow）生成路径（连续）。分割变为 SigLIP 用于理解 + 整流流用于生成。质量上限进一步提升。架构仍然是解耦编码器 + 共享主体。

### 共享主体的职责

Transformer 主体处理统一的序列，但面对两种输入分布。其职责是：

- 理解：消费 SigLIP 特征 + 文本 Token → 自回归输出文本。
- 生成：消费文本 Token +（可选的图像 VQ Token）→ 自回归输出图像 VQ Token。

主体在每个块中没有模态特定的权重。它就是你在 Qwen 或 Llama 中看到的文本风格 Transformer，再加上两个输入适配器。

有趣的是，这意味着 Janus-Pro 的主体可以从预训练的 LLM 初始化。Janus-Pro 确实是从 DeepSeek-MoE-7B 初始化的。这个选择很重要：LLM 贡献了推理能力，这是从零开始训练的统一模型难以达到的。

### 与 InternVL-U 的对比

InternVL-U（第12.10课）是2026年的后续工作。它结合了：

- 原生多模态预训练（InternVL3 骨干）。
- 解耦编码器路由（SigLIP 输入，VQ + 扩散头输出）。
- 统一理解 + 生成 + 编辑。

InternVL-U 将 Janus-Pro 的架构选择纳入了一个更大的框架中。解耦编码器的思想现在已成为大规模统一模型的默认方案。

### 局限性

解耦编码器增加了架构复杂性。需要训练两个分词器，维护两条输入路径，处理两套故障模式。对于不需要生成能力的产品，Janus-Pro 是过度设计的——选择 LLaVA 系列的理解模型即可。

对于不需要理解能力的产品，Janus-Pro 是大材小用的——选择 Stable Diffusion 3 / Flux 模型即可。

对于同时需要两者的产品，Janus-Pro 现在是最佳的开源参考架构。

## 实践

`code/main.py` 模拟了 Janus-Pro 的路由：

- 两个模拟编码器：类 SigLIP（产生256维语义向量）和类 VQ（产生整数编码）。
- 一个提示路由器，根据任务标签选择编码器。
- 一个共享主体（占位符），处理 Token 序列，无论序列由哪个编码器产生。
- 从第一阶段（对齐）切换到第三阶段（指令微调）的加权样本调度。

打印3个示例的路由路径：图像问答、T2I、图像编辑。

## 成果输出

本课产出 `outputs/skill-decoupled-encoder-picker.md`。给定一个需要在接近前沿质量水平上统一生成和理解的产品，在 Janus-Pro、JanusFlow 或 InternVL-U 之间做出选择，并给出具体的数据规模建议。

## 练习

1. Janus-Pro-7B 在 GenEval 上超越了 DALL-E 3。请解释为什么一个 7B 的开源模型在生成上能匹敌前沿闭源模型，但在理解上却不能。

2. 实现一个路由器函数：给定提示文本，分类为 `understand` 或 `generate`。如何处理像"描述然后绘制"这样的模糊提示？

3. JanusFlow 将 VQ 路径替换为整流流。Transformer 主体现在输出什么？损失函数有什么变化？

4. 提出 Janus-Pro 架构可以通过增加一个解耦编码器来处理的第四种任务。示例：图像分割（DINO 风格）、深度估计（MiDaS 风格）。

5. 阅读 Janus-Pro 第4.2节关于数据扩展的内容。哪个数据阶段对 T2I 质量提升的贡献最大（相比 Janus）？

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| 解耦编码 | "两个视觉编码器" | 每个方向使用独立的分词器或编码器：语义用于理解，重建用于生成 |
| 共享主体 | "一个 Transformer" | 单个 Transformer 处理任一编码器的输出；没有模态特定的权重 |
| SigLIP 用于理解 | "语义特征" | CLIP 系列视觉塔，提供丰富的概念特征但重建效果差 |
| VQ 用于生成 | "重建编码" | 向量量化 Token，可以干净地解码回像素 |
| JanusFlow | "整流流变体" | Janus-Pro 使用连续流匹配生成头替代 VQ |
| 路由标签 | "任务标签" | 提示标记（`<understand>` / `<generate>`），用于选择输入编码器 |

## 延伸阅读

- [Wu et al. — Janus (arXiv:2410.13848)](https://arxiv.org/abs/2410.13848)
- [Chen et al. — Janus-Pro (arXiv:2501.17811)](https://arxiv.org/abs/2501.17811)
- [Ma et al. — JanusFlow (arXiv:2411.07975)](https://arxiv.org/abs/2411.07975)
- [InternVL-U (arXiv:2603.09877)](https://arxiv.org/abs/2603.09877)
- [Dong et al. — DreamLLM (arXiv:2309.11499)](https://arxiv.org/abs/2309.11499)