# Show-o 与离散扩散统一模型

> Transfusion 混合了连续和离散表示。Show-o（Xie et al.，2024年8月）走了另一条路：文本 Token 使用因果下一 Token 预测（Causal Next-Token Prediction），图像 Token 使用受 MaskGIT 启发的掩码离散扩散（Masked Discrete Diffusion）。两者共存于一个带有混合注意力掩码（Hybrid Attention Mask）的 Transformer 中。结果是在一个骨干网络、每种模态一个分词器、一种损失函数（将下一 Token 预测推广到掩码预测）上统一了 VQA、文本到图像（T2I）、图像修复（Inpainting）和混合模态生成。本课将详解 Show-o 的设计——为什么掩码离散扩散是一种并行的、少步数的图像生成器——并将其与 Transfusion 和 Emu3 进行对比。

**类型：** 学习
**语言：** Python（标准库，掩码离散扩散采样器）
**前置要求：** 第12阶段 · 13（Transfusion）
**时间：** ~120分钟

## 学习目标

- 解释掩码离散扩散：首先均匀掩码 Token，然后要求 Transformer 恢复它们的调度机制。
- 从速度和质量角度比较并行图像解码（Show-o、MaskGIT）与自回归图像解码（Chameleon、Emu3）。
- 列举 Show-o 在单个检查点中处理的三种任务：T2I、VQA、图像修复。
- 选择一种掩码调度（余弦、线性、截断）并分析其对样本质量的影响。

## 问题

Transfusion 的双损失训练虽然有效，但动态特性更复杂——连续扩散损失与离散 NTP 损失处于不同的数值尺度。平衡损失权重需要进行超参数搜索。该架构有效但复杂。

Show-o 的答案：保持两种模态离散（类似 Chameleon），但通过掩码离散扩散并行生成图像，而非顺序生成。训练目标变为单一的掩码 Token 预测，自然地推广了下一 Token 预测。

## 核心概念

### 掩码离散扩散（MaskGIT）

Chang et al.（2022）提出的原始 MaskGIT 技巧非常优雅。从一个完全掩码的图像开始（每个 Token 都是特殊的 `<MASK>` ID）。在每一步中，并行预测所有掩码 Token，然后保留置信度最高的 top-K 个预测并重新掩码其余部分。经过大约 8-16 次迭代后，所有 Token 都被填充完成。每步取消掩码的 Token 数量调度是经过调优的——余弦调度表现良好。

训练很简单：从 [0, 1] 均匀采样一个掩码比例，将其应用于图像的 VQ Token，训练 Transformer 恢复被掩码的 Token。这正是 BERT 对文本所做的，只是扩展到了图像生成。

### Show-o：一个 Transformer，混合掩码

Show-o 将 MaskGIT 嵌入到一个因果语言模型（Causal Language Model）Transformer 中。注意力掩码如下：

- 文本 Token：因果注意力（标准 LLM）。
- 图像 Token：图像块内完全双向注意力（因此掩码 Token 在预测时可以访问所有其他图像 Token）。
- 文本到图像：文本关注先前的图像，图像关注先前的文本。

训练交替进行：
1. 对文本序列进行标准 NTP 训练。
2. T2I 样本：文本 → 图像，图像 Token 被掩码，使用掩码 Token 预测损失。
3. VQA 样本：图像 → 文本，文本 Token 被掩码（实际上就是 NTP）。

统一损失是对 `<MASK>` Token 的交叉熵，它同时覆盖了文本 NTP（仅最后一个 Token 被"掩码"）和图像掩码扩散（随机子集被掩码）。

### 并行采样

Show-o 在大约 16 步内生成一张图像，而不是约 1000 步（逐 Token 自回归）或约 20 步（扩散）。在每一步中，并行预测所有掩码 Token；提交置信度最高的 top-K 个；重复。

对比：
- Chameleon / Emu3（逐 Token 自回归）：需要 N_tokens 次前向传播，通常每张图像 1024-4096 次。
- Transfusion（连续扩散）：约 20 步，每步一次完整的 Transformer 前向传播。
- Show-o（掩码离散扩散）：约 16 步，每步一次完整的 Transformer 前向传播。

在相似规模的模型上，Show-o 比 Chameleon 更快，步数与 Transfusion 大致相当，但每步计算成本更低（离散词汇 logits vs 连续 MSE 损失）。

### 单个检查点中的任务

Show-o 在推理时支持四种任务，通过提示格式选择：

- 文本生成：标准自回归文本输出。
- VQA：图像输入，文本输出。
- T2I：文本输入，通过掩码离散扩散输出图像。
- 图像修复：部分 Token 被掩码的图像，填充缺失部分。

图像修复能力直接来源于掩码预测训练。掩码 VQ Token 网格的一个区域，输入其余部分和文本提示，预测被掩码的 Token。

### 掩码调度

每步取消掩码的 Token 数量调度决定了生成质量。Show-o 推荐余弦调度：

```
mask_ratio(t) = cos(pi * t / (2 * T))   # t = 0..T
```

在第 0 步，所有 Token 被掩码（比例 1.0）。在第 T 步，没有 Token 被掩码。余弦调度将质量集中在预测信息最丰富的中等比例范围。线性调度也有效，但更快达到平台期。

### Show-o2

Show-o2（2025年后续工作，arXiv 2506.15564）对 Show-o 进行了扩展：更大的 LLM 基座、更好的分词器、改进的掩码调度。架构模式相同。

### Show-o 的定位

在 2026 年的分类体系中：

- 离散 Token + NTP：Chameleon、Emu3。简单但推理慢。
- 离散 Token + 掩码扩散：Show-o、MaskGIT、LlamaGen、Muse。并行采样，但仍受分词器有损压缩影响。
- 连续 + 扩散：Transfusion、MMDiT、DiT。质量最高，训练更复杂。
- 连续 + VLM 中的流匹配：JanusFlow、InternVL-U。最新方案。

按任务选择：当需要一个开源模型中同时实现 T2I + 图像修复 + VQA 且速度合理时，选择 Show-o；当质量至关重要且能承受双损失复杂性时，选择 Transfusion。

## 实践

`code/main.py` 模拟了 Show-o 采样：

- 一个包含 16 个 VQ Token 的玩具网格。
- 一个模拟"Transformer"，根据提示和当前未掩码 Token 预测 logits。
- 8 步并行掩码采样，使用余弦调度。
- 打印中间状态（掩码模式演化）和最终 Token。

运行它，观察掩码逐步溶解的过程。

## 成果输出

本课产出 `outputs/skill-unified-gen-model-picker.md`。给定一个需要同时具备理解（VQA、描述生成）和生成（T2I、图像修复）能力且受限于开源权重的产品，在 Show-o 系列、Transfusion/MMDiT 系列和 Emu3 / Chameleon 系列之间做出选择，并给出具体的权衡分析。

## 练习

1. 掩码离散扩散需要约 16 步采样。为什么不是 1 步？如果在第 0 步就取消所有掩码会发生什么？

2. 图像修复能力在掩码扩散中是免费的。提出一个（真实的或假设的）产品用例，说明 Show-o 的图像修复能力为何优于专用模型。

3. 余弦调度 vs 线性调度：对 T=8 追踪每步取消掩码的 Token 数量。哪种更均衡？

4. 一张 512x512 的 Show-o 图像有 1024 个 Token。在词汇量 K=16384 时，模型输出 1024 * log2(16384) = 14,336 比特（约 1.75 KiB）的数据。Stable Diffusion 输出 512*512*24 比特 = 6,291,456 比特（约 768 KiB）的原始像素。压缩比是多少？这带来了什么样的质量？

5. 阅读 LlamaGen（arXiv:2406.06525）。LlamaGen 的类别条件自回归图像模型与 Show-o 的掩码方法有何不同？

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| 掩码离散扩散 | "MaskGIT 风格" | 训练预测被掩码的 Token；推理时迭代地取消掩码置信度最高的预测 |
| 余弦调度 | "取消掩码调度" | 推理步骤中掩码比例的衰减方式；将置信度增长集中在中间范围 |
| 并行解码 | "所有 Token 同时处理" | 每一步在一次前向传播中预测完整的掩码 Token 序列，然后提交 top-K |
| 混合注意力 | "因果 + 双向" | 对文本 Token 使用因果掩码，对图像块内 Token 使用双向掩码 |
| 图像修复 | "填充式生成" | 以部分 Token 被掩码的图像为条件，预测缺失的 Token；直接从训练目标中获得此能力 |
| 提交率 | "每步 top-K" | 每次迭代被声明为"完成"的 Token 数量；控制推理速度与质量的权衡 |

## 延伸阅读

- [Xie et al. — Show-o (arXiv:2408.12528)](https://arxiv.org/abs/2408.12528)
- [Show-o2 (arXiv:2506.15564)](https://arxiv.org/abs/2506.15564)
- [Chang et al. — MaskGIT (arXiv:2202.04200)](https://arxiv.org/abs/2202.04200)
- [Sun et al. — LlamaGen (arXiv:2406.06525)](https://arxiv.org/abs/2406.06525)
- [Chang et al. — Muse (arXiv:2301.00704)](https://arxiv.org/abs/2301.00704)