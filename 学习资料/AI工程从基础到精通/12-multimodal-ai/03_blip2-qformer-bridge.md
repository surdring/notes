# 从 CLIP 到 BLIP-2 —— 作为模态桥的 Q-Former

> CLIP 对齐了图像和文本，但无法生成描述、回答问题或进行对话。BLIP-2（Salesforce，2023）用一个小的可训练桥解决了这个问题：32 个可学习的查询向量（query vector）通过交叉注意力（cross-attention）关注冻结 ViT 的特征，然后直接插入冻结 LLM 的输入流中。1.88 亿参数的桥将 110 亿参数的 LLM 连接到 ViT-g/14。直到 2026 年，每一个基于适配器的 VLM——MiniGPT-4、InstructBLIP、LLaVA 的同类变体——都是其衍生品。本课阅读 Q-Former 的架构，解释其两阶段训练，并构建一个玩具版本，将视觉 token 输入冻结的文本解码器。

**类型：** 构建
**语言：** Python（标准库，交叉注意力 + 可学习查询演示）
**前置条件：** Phase 12 · 02（CLIP）、Phase 7（Transformer）
**时间：** 约 180 分钟

## 学习目标

- 解释为什么在冻结的视觉编码器和冻结的 LLM 之间的可训练瓶颈在成本和稳定性上优于端到端微调。
- 实现一个交叉注意力块，其中一组固定的可学习查询关注外部图像特征。
- 逐步讲解 BLIP-2 的两阶段预训练：表示学习（ITC + ITM + ITG）然后是生成式（LM 损失，冻结解码器）。
- 将 Q-Former 与 LLaVA 中使用的更简单 MLP 投影器进行比较，并论证每种选择在何时胜出。

## 问题所在

你有一个冻结的 ViT，每张图像产生 256 个维度为 1408 的 patch token。你有一个冻结的 7B LLM，期望维度为 4096 的 token 嵌入。显而易见的桥——从 1408 到 4096 的线性层——确实有效，但将全部 256 个 patch token 送入 LLM 的上下文需要每张图像消耗 256 个额外 token。在 32 张图像的批次上，仅视觉模态就消耗了 8192 个 token。

BLIP-2 的问题是：你能将 256 个 token 的图像表示压缩成少得多的 token（比如 32 个），同时保留足够的信息供 LLM 进行描述生成、问答和关于图像的推理吗？你能在不触及冻结骨干的情况下训练这个桥，将训练成本限制在只有桥的参数吗？

答案是：Q-Former。32 个可学习的「查询」向量，通过交叉注意力关注 ViT 的 patch token，产生一个 32 个 token 的视觉摘要供 LLM 消费。总共 1.88 亿参数。在接触到 LLM 之前，用对比、匹配和生成目标进行训练。

## 核心概念

### 可学习的查询

Q-Former 的核心技巧：不让 LLM 的文本 token 关注图像块，而是引入一组新的 32 个可学习查询向量 `Q`，让它们去关注图像块。查询是模型的参数——它们在训练过程中被学习，同一组 32 个查询用于每张图像。

经过交叉注意力后，每个查询持有图像的一个压缩摘要——「描述主要物体」「描述背景」「数物体数量」等。查询不会按语义标签真正特化；它们学习的是能让下游损失下降的任何编码。

### 架构

Q-Former 是一个小型 Transformer（12 层，约 1 亿参数），有两条路径：

1. 查询路径：32 个查询向量经过自注意力（彼此之间），然后对冻结 ViT 的 patch token 做交叉注意力，然后 FFN。
2. 文本路径：类似 BERT 的文本编码器与查询路径共享自注意力和 FFN 权重。文本路径禁用交叉注意力。

训练时两条路径都运行。查询和文本通过共享自注意力进行交互，这意味着查询可以根据需要它的任务（ITM、ITG）以文本为条件。在 VLM 交接的推理时，只有查询流过，产生 32 个视觉 token。

### 两阶段训练

BLIP-2 分两个阶段预训练：

阶段 1：表示学习（无 LLM）。三个损失：
- ITC（图像-文本对比，Image-Text Contrastive）：在池化后的查询 token 和文本 CLS token 之间做 CLIP 风格的对比。
- ITM（图像-文本匹配，Image-Text Matching）：二分类器——这个图像-文本对是否匹配？使用硬负样本挖掘。
- ITG（图像锚定的文本生成，Image-grounded Text Generation）：因果 LM 头作用于文本，以查询为条件。迫使查询编码可生成文本的内容。

只有 Q-Former 训练。ViT 冻结。不涉及 LLM。

阶段 2：生成式学习。附加一个冻结的 LLM（OPT-2.7B 或 Flan-T5-XL 等）。通过一个小型线性层将 32 个查询输出投影到 LLM 的嵌入维。将它们前置到文本提示词之前。在拼接后的提示词 + 图像 + 描述序列上，仅训练线性投影和 Q-Former，使用 LM 损失。

阶段 2 之后，Q-Former + 投影就是完整的视觉适配器。推理时：图像 → ViT → Q-Former → 线性投影 → 前置到文本 → 冻结 LLM 发出输出。

### 参数经济学

BLIP-2，ViT-g/14（11 亿，冻结）+ OPT-6.7B（67 亿，冻结）+ Q-Former（1.88 亿，训练）= 总计 80 亿，训练 1.88 亿。Q-Former 单独占全栈参数约 2.4%。训练成本反映了这一点：几个 A100 上几天 vs 端到端几周。

质量：BLIP-2 在零样本 VQA 上匹敌或超过 Flamingo-80B，同时只有其 1/50 大小。桥是有效的。

### InstructBLIP 与指令感知 Q-Former

InstructBLIP（2023）用额外输入扩展了 Q-Former：指令文本本身。在交叉注意力时，查询现在同时可以访问图像块和指令。查询可以按指令特化（「数一下汽车」「描述氛围」），而不是学习单一固定的摘要。在留出任务上获得基准提升。

### MiniGPT-4 与仅投影器方案

MiniGPT-4 保留了 Q-Former，但只训练输出线性投影，冻结其他所有内容。便宜，但代价是质量——查询是 BLIP-2 的，不是你的。适合快速迭代，不是最佳架构。

### 为什么 LLaVA 走向更简单

LLaVA（2023，第 12.05 课）用普通的两层 MLP 替换了 Q-Former，将每个 ViT patch token 投影到 LLM 空间——24x24 网格每张图像 576 个 token，全部送入 LLM。压缩效果更差，但让 LLM 直接关注原始块。当时这是有争议的；到 2023 年末，它成了主导方案，因为视觉指令数据（LLaVA-Instruct-150k）证明了 MLP 可以被训练来保留足够的信号。权衡：LLaVA 的上下文填充更快，但它能自然地扩展到多图像和视频。

到 2026 年，领域分裂为：Q-Former 在 token 预算重要时存活（长视频、多图像）；MLP 投影器在每 token 原始质量优先时占主导。

### 门控交叉注意力：Flamingo，祖先

Flamingo（第 12.04 课）早于 BLIP-2，使用相同的交叉注意力思路，但在每个冻结 LLM 层上都做，而不是作为单个桥。BLIP-2 表明你可以只压缩到输入层，仍然有效。Gemini 和 Idefics 结合两者：交错输入 token 加上用于上下文少样本的可选门控交叉注意力。

### 2026 年的衍生品

- Q-Former：BLIP-2、InstructBLIP、MiniGPT-4 以及大多数视频-语言模型（出于 token 预算原因）。
- Perceiver 重采样器（Perceiver resampler）：Flamingo 的变体（第 12.04 课）；Idefics 系列、Eagle、OmniMAE。
- MLP 投影器：LLaVA、LLaVA-NeXT、LLaVA-OneVision、Cambrian-1。
- 注意力池化：VILA、PaliGemma。

四种都有效。决定性问题是你在 token 预算上受限还是在每 token 质量上受限。

## 使用指南

`code/main.py` 构建一个标准库的 Q-Former 风格交叉注意力：

1. 模拟 256 个图像 patch token（维度 128）。
2. 实例化 32 个可学习查询（维度 128）。
3. 运行缩放点积交叉注意力（Q 来自查询，K/V 来自块）。
4. 通过线性层投影到 LLM 维度（512）。
5. 输出 32 个 LLM 就绪的视觉 token。

所有数学运算均为纯 Python（向量上的嵌套循环）。玩具级别但形状正确。注意力权重矩阵被打印出来，让你看到每个查询从哪些块拉取。

## 交付物

本课产出 `outputs/skill-modality-bridge-picker.md`。给定一个目标 VLM 配置（视觉编码器 token 数、LLM 上下文预算、部署约束、质量目标），它推荐 Q-Former vs MLP vs Perceiver 重采样器，并提供简短的论证和每个桥的参数数量估算。

## 练习

1. 在 PyTorch 中实现交叉注意力块。验证使用 32 个查询和 256 个键/值时，注意力权重矩阵是 32 x 256，且 softmax 后每行求和为 1。

2. 在 BLIP-2 阶段 1 中，Q-Former 同时运行三个损失：ITC、ITM、ITG。用伪代码为每个编写前向签名。哪个需要文本编码器路径处于活动状态？

3. 比较参数数量：Q-Former（12 层，768 隐藏维度）vs 两层 MLP 投影器（1408 → 4096，两层）。在多大的 LLM 规模下，1.88 亿的 Q-Former 成本能在训练效率上收回？

4. 阅读 BLIP-2 论文（arXiv:2301.12597）第 3.2 节关于 Q-Former 初始化的内容。解释为什么从 BERT-base（而非随机）初始化能加速收敛。

5. 对于一段 10 分钟的视频，以 1 FPS 采样到 60 帧，计算每帧的 token 成本：Q-Former → 32 token/帧 vs MLP 投影器 → 576 token/帧。哪个能装入 128k token 的 LLM 上下文窗口？

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|----------------|------------------------|
| Q-Former | 「查询 Transformer」 | 具有 32 个可学习查询向量的小型 Transformer，通过交叉注意力关注冻结 ViT 特征 |
| 可学习查询（Learnable queries） | 「视觉的软提示词」 | 一组固定参数，作为交叉注意力的查询侧；每个模型学习，所有输入共享 |
| 交叉注意力（Cross-attention） | 「Q 从这里，K/V 从那里」 | 注意力中查询、键和值来自不同来源；查询如何从 ViT 块中拉取 |
| ITC | 「图像-文本对比」 | CLIP 风格损失，作用于 Q-Former 池化查询 vs 文本 CLS |
| ITM | 「图像-文本匹配」 | 在硬负样本挖掘对上做二分类器；迫使查询区分细粒度不匹配 |
| ITG | 「图像锚定的文本生成」 | 因果 LM 损失，文本以查询为条件生成；迫使查询编码文本可解码的内容 |
| 两阶段预训练 | 「表示再生成」 | 阶段 1 单独训练 Q-Former（ITC/ITM/ITG）；阶段 2 附加冻结 LLM 并仅训练投影 + Q-Former |
| 冻结骨干（Frozen backbone） | 「不微调」 | 视觉编码器和 LLM 权重是固定的；只有桥训练 |
| 投影头（Projection head） | 「线性层到 LLM 维度」 | 将 Q-Former 输出映射到 LLM 嵌入维度的最终线性层 |
| Perceiver 重采样器 | 「Flamingo 的版本」 | 类似的可学习查询交叉注意力，由 Flamingo 在每层使用，而非作为单个桥 |

## 进一步阅读

- [Li et al. — BLIP-2 (arXiv:2301.12597)](https://arxiv.org/abs/2301.12597)——核心论文。
- [Li et al. — BLIP (arXiv:2201.12086)](https://arxiv.org/abs/2201.12086)——具有 ITC/ITM/ITG 三者的前身。
- [Li et al. — ALBEF (arXiv:2107.07651)](https://arxiv.org/abs/2107.07651)——「先对齐再融合」——阶段 1 训练的概念祖先。
- [Dai et al. — InstructBLIP (arXiv:2305.06500)](https://arxiv.org/abs/2305.06500)——指令感知 Q-Former。
- [Zhu et al. — MiniGPT-4 (arXiv:2304.10592)](https://arxiv.org/abs/2304.10592)——仅投影器方案。
- [Jaegle et al. — Perceiver IO (arXiv:2107.14795)](https://arxiv.org/abs/2107.14795)——可学习查询交叉注意力的通用架构。