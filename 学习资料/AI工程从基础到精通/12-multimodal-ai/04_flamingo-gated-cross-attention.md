# Flamingo 与用于少样本 VLM 的门控交叉注意力

> DeepMind 的 Flamingo（2022）先于所有人做了两件事。它证明单个模型可以处理任意交错的图像、视频和文本序列。并且它证明 VLM 可以进行上下文学习（in-context learning）——给出一个带有三个示例（图像，描述）对的少样本提示词（Few-shot Prompt），模型可以在没有任何梯度步骤的情况下为新图像生成描述。机制：门控交叉注意力层（gated cross-attention layers），插入在冻结 LLM 的现有层之间，带有可学习的 tanh 门控，初始为 0，使得 LLM 的文本能力在初始化时得到保留。本课讲解 Flamingo 的 Perceiver 重采样器（Perceiver Resampler）和门控交叉注意力架构——Gemini 交错输入和 Idefics2 视觉 token 的祖先。

**类型：** 学习
**语言：** Python（标准库，门控交叉注意力 + Perceiver 重采样器演示）
**前置条件：** Phase 12 · 03（BLIP-2 Q-Former）
**时间：** 约 120 分钟

## 学习目标

- 解释门控交叉注意力如何通过 `tanh(gate) = 0` 在初始化时保留冻结 LLM 的文本能力。
- 逐步讲解 Perceiver 重采样器：N 个图像块 → 通过交叉注意力产生 K 个固定「潜在」查询。
- 描述 Flamingo 如何处理交错图像-文本序列，使用尊重图像位置的因果掩码。
- 复现一个少样本多模态提示词结构（3 个图像-描述示例，然后一个查询图像）。

## 问题所在

BLIP-2 将 32 个视觉 token 送入冻结 LLM 的输入层。对于每个提示词一张图像有效。但如果你想送入许多与文本交错的图像，例如「这是图像 A，描述它；这是图像 B，描述它；现在这是图像 C，描述它」？LLM 的自注意力需要在单个流中处理图像 token 和文本 token，而哪些位置可以关注哪些图像的问题变得棘手。

Flamingo 的答案：根本不要改变 LLM 的输入流。在现有 LLM 块之间插入额外的交叉注意力层。文本 token 仍然像往常一样在 LLM 的因果自注意力中流动。每隔几个 LLM 块，文本 token 也通过新的门控层对图像特征做交叉注意力。门控（初始化为零）意味着在步骤零时，新层是无操作（no-op）——模型的行为完全像预训练的 LLM。随着训练进行，门控打开，视觉信息开始流动。

Flamingo 回答的第二个问题：如何处理每个提示词中可变数量的图像（0、1 或很多）？Perceiver 重采样器——一个小型交叉注意力模块，接收任意数量的块并产生固定数量的视觉潜在 token。无论提示词中有多少张图像，LLM 交叉注意力层看到的形状是相同的。

## 核心概念

### 冻结的 LLM

Flamingo 从一个冻结的 Chinchilla 70B LLM 开始。全部 700 亿权重不动。现有的文本自注意力和 FFN 正常操作。

### Perceiver 重采样器

对于提示词中的每张图像，ViT 产生 N 个 patch token。Perceiver 重采样器有 K 个固定的可学习潜在向量（Flamingo 使用 K=64）。每个重采样器块包含两个子步骤：

1. 交叉注意力：K 个潜在向量关注 N 个 patch token（Q 来自潜在向量，K/V 来自块）。
2. 潜在向量内部的自注意力 + FFN。

经过 6 个重采样器块后，输出是 K=64 个维度为 1024 的视觉 token，无论 ViT 产生了多少个块。224x224 的图像（196 个块）和 480x480 的图像（900 个块）都输出为 64 个重采样器 token。

对于视频，重采样器在时间上应用：每个帧的块产生 64 个潜在向量，时间位置编码让模型区分 t=0 和 t=N。整个视频变为 T * 64 个视觉 token。

### 门控交叉注意力

在冻结 LLM 的每 M 层之间（Flamingo 使用 M=4），插入一个新的门控交叉注意力块：

```
x_after_llm_block = llm_block(x_before)
cross = cross_attn(x_after, resampler_output)
gated = tanh(alpha) * cross + x_after
x_before_next_block = gated
```

- `alpha` 是一个可学习的标量，初始化为零。
- `tanh(0) = 0`，因此在初始化时门控分支贡献为零。
- 当 `alpha` 偏离零时，交叉注意力的贡献平稳增长。
- 残差连接意味着即使完全打开的门控也不会覆盖 LLM 的文本表示；它只是在上面添加视觉信息。

这是 Flamingo 中最重要的设计选择：视觉条件化是可加的、门控的，且在初始化时为零。步骤 0 的 Flamingo 在纯文本输入上是一个完美的 Chinchilla 70B。

### 用于交错输入的掩码交叉注意力

在类似「<图像 A> 描述 A <图像 B> 描述 B <图像 C> ?」的提示词中，每个文本 token 只能看到在序列中出现在它之前的图像。交叉注意力掩码强制：位置 `t` 的文本 token 只关注图像重采样器 token，其图像索引 `i < i_t`，其中 `i_t` 是位置 `t` 之前最近的图像。「只看到最后一张前面的图像」或「看到所有前面的图像」都是有效的选择；Flamingo 选择了前者。

### 上下文少样本学习

Flamingo 提示词看起来像：

```
<图像1> 一张猫的照片。<图像2> 一张狗的照片。<图像3> 一张
```

模型看到补全模式并输出「鸟」（或任何图像 3 展示的内容）。没有梯度步骤。冻结 LLM 的上下文学习能力通过门控交叉注意力传递——这是论文的关键论点及其重要性所在。

### 训练数据

Flamingo 在三个数据集上训练：

1. MultiModal MassiveWeb（M3W）：4300 万个带有交错图像和文本的网页，重建阅读顺序。
2. 图像-文本对（ALIGN + LTIP）：44 亿对。
3. 视频-文本对（VTP）：2700 万个短视频片段。

OBELICS（2023）是交错网页语料的开源复现，Idefics、Idefics2 和大多数开源「Flamingo 风格」模型都在此上训练。

### OpenFlamingo 与 Otter

OpenFlamingo（2023）是开源复现。架构相同（Perceiver 重采样器 + 门控交叉注意力，作用于冻结 LLaMA 或 MPT）。检查点有 3B、4B、9B。由于基础 LLM 更小和数据更少，质量落后于 Flamingo。

Otter（2023）在 OpenFlamingo 的基础上，在 MIMIC-IT（多模态指令数据集）上做指令微调，证明门控交叉注意力同样适用于指令跟随。

### 衍生品

- Idefics / Idefics2 / Idefics3：Hugging Face 的门控交叉注意力派系，逐步简化（Idefics2 用自适应池化的直接 patch token 替代了重采样器）。
- Flamingo 到 Chameleon 的转型：到 2024 年，许多团队转向了早期融合（Early Fusion，第 12.11 课）；Flamingo 风格的门控交叉注意力在需要骨干冻结的生产环境中仍然存在。
- Gemini 的交错输入：概念上继承了 Flamingo 的交错格式灵活性，尽管确切机制是专有的。

### 与 BLIP-2 的对比

| | BLIP-2 | Flamingo |
|---|---|---|
| 视觉桥 | Q-Former，仅在输入处一次 | 每 M 层都有门控交叉注意力 |
| 视觉 token | 每张图像 32 个 | 每个交叉注意力层每张图像 64 个 |
| 冻结 LLM | 是 | 是 |
| 上下文少样本 | 较弱 | 强——论文的核心卖点 |
| 交错输入 | 无原生支持 | 是，设计目标 |
| 训练数据 | 1.3 亿对 | 13 亿对 + 4300 万交错页面 |
| 参数数量 | 训练 1.88 亿 | 训练约 100 亿（交叉注意力层） |
| 算力 | 8 个 A100 几天 | 数千 TPUv4 几周 |

在预算内选 BLIP-2 做单图像 VQA。选 Flamingo/Idefics2 做交错、少样本或多图像推理。

## 使用指南

`code/main.py` 演示：

1. 在 36 个假 patch token 上用 8 个可学习潜在向量做 Perceiver 重采样器（纯 Python 交叉注意力）。
2. 门控交叉注意力步骤，`alpha = 0` → 输出等于输入（LLM 不变），然后 `alpha = 2.0` → 视觉贡献混合进来。
3. 交错掩码构建器，为「(图像 1) (文本 1) (图像 2) (文本 2)」序列生成 2D 注意力掩码。

## 交付物

本课产出 `outputs/skill-gated-bridge-diagnostic.md`。给定一个开源 VLM 的配置（重采样器 Y/N、交叉注意力频率、门控方案），它识别 Flamingo 谱系元素并解释冻结策略。对于调试为什么微调降低了文本性能很有用（答案：门控打开得太快了）。

## 练习

1. 计算 Flamingo-9B 的视觉参数数量：9B LLM + 14 亿门控交叉注意力层 + 6400 万重采样器。训练的参数占总参数的比例是多少？

2. 在 PyTorch 中实现门控残差 `y = tanh(alpha) * cross + x`。实验证明 `alpha=0` 时初始化时 `y==x` 精确成立。

3. 阅读 OpenFlamingo 第 3.2 节（arXiv:2308.01390）关于他们如何处理批次中每个提示词有不同图像数量的多张图像。描述填充策略。

4. 为什么 Flamingo 的交叉注意力掩码让文本 token 只关注最近的前面图像，而不是所有前面的图像？阅读 Flamingo 论文第 2.4 节并解释权衡。

5. 上下文少样本：为一个新 Flamingo 变体构建一个带有 4 个「图像 → 主要物体的颜色」示例的提示词。描述当你将示例数量从 0 变化到 8 时预期的准确率模式。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|----------------|------------------------|
| Perceiver 重采样器 | 「固定潜在交叉注意力」 | 从可变数量的输入块产生 K 个固定 token 的模块 |
| 门控交叉注意力（Gated cross-attention） | 「tanh 门控桥」 | 残差层 `y = tanh(alpha)*cross + x`，可学习 alpha，初始 0 |
| 交错输入（Interleaved input） | 「混合序列」 | 图像和文本按阅读顺序自由混合的提示词格式 |
| 冻结 LLM | 「无 LLM 梯度」 | 文本 LLM 的权重不更新；仅重采样器 + 交叉注意力层训练 |
| 少样本（Few-shot） | 「上下文示例」 | 在提示词中给出几个（图像，答案）对；模型在无微调的情况下泛化 |
| OBELICS | 「交错网页语料」 | 1.41 亿带有按阅读顺序排列的图像和文本的网页的开放数据集 |
| Chinchilla | 「70B 冻结基础」 | Flamingo 的冻结文本 LLM，来自 DeepMind 的 Chinchilla 论文 |
| 门控调度（Gate schedule） | 「alpha 如何移动」 | 训练期间交叉注意力门控打开的速度 |
| 交叉注意力频率 | 「每 M 层」 | 门控交叉注意力块的插入频率；Flamingo 使用 M=4 |
| OpenFlamingo | 「开源复现」 | MosaicML/LAION 开源检查点，3-9B；架构与 Flamingo 完全一致 |

## 进一步阅读

- [Alayrac et al. — Flamingo (arXiv:2204.14198)](https://arxiv.org/abs/2204.14198)——原始论文。
- [Awadalla et al. — OpenFlamingo (arXiv:2308.01390)](https://arxiv.org/abs/2308.01390)——开源复现。
- [Laurençon et al. — OBELICS (arXiv:2306.16527)](https://arxiv.org/abs/2306.16527)——交错网页语料。
- [Jaegle et al. — Perceiver IO (arXiv:2107.14795)](https://arxiv.org/abs/2107.14795)——通用 Perceiver 架构。
- [Li et al. — Otter (arXiv:2305.03726)](https://arxiv.org/abs/2305.03726)——指令微调的 Flamingo 衍生品。
- [Laurençon et al. — Idefics2 (arXiv:2405.02246)](https://arxiv.org/abs/2405.02246)——Flamingo 方案的现代简化。