# Chameleon 与早期融合纯 Token 多模态模型

> 我们目前见过的每个 VLM 都将图像和文本分开。视觉 token 来自视觉编码器，流入投影器，然后在 LLM 内部与文本相遇。视觉和文本词汇从不重叠。Chameleon（Meta，2024 年 5 月）问：如果它们重叠呢？训练一个 VQ-VAE，将图像转化为共享词汇中的离散 token 序列。每个多模态文档现在是一个序列——文本 token 和图像 token 交错，一个单一的自回归损失。副作用：模型可以生成混合模态输出——单次推理调用中交替文本和图像 token。本课阅读早期融合（Early Fusion）论点并端到端构建一个玩具版本。

**类型：** 构建
**语言：** Python（标准库，VQ-VAE 分词器 + 交错解码器）
**前置条件：** Phase 12 · 05、Phase 8（生成式 AI）
**时间：** 约 180 分钟

## 学习目标

- 解释为什么共享词汇 + 单一损失改变了模型所能做的事情。
- 描述 VQ-VAE 如何将图像分词为与 Transformer 的下一 token 目标兼容的离散序列。
- 指出 Chameleon 的训练稳定性技巧：QK-Norm、dropout 放置、LayerNorm 顺序。
- 比较 Chameleon vs BLIP-2 的 Q-Former 方法，描述每种选择何时正确。

## 问题所在

基于适配器的 VLM（LLaVA、BLIP-2、Qwen-VL）将文本和图像视为两种不同的东西。文本 token 通过 `embed(text_token)`；图像通过 `visual_encoder(image) → projector → ... pseudo_tokens`。模型有两条输入路径，在中途合并。

三个后果：

1. LLM 只能消费图像，不能发出图像。输出仅限于文本。
2. 混合模态文档（交替的段落和图像，如文章）很别扭——你要么在模型外解析多模态输入，要么链式生成。
3. 分布不匹配。视觉 token 和文本 token 位于隐藏空间的不同区域，产生微妙的对齐问题。

Chameleon 拒绝了前提：图像只是来自共享词汇的离散 token 序列。在交错文档上训练模型，一个损失，一个自回归解码器，你就能免费解锁混合模态生成。

## 核心概念

### VQ-VAE 作为图像分词器

分词器是一个向量量化变分自编码器（Vector-Quantized Variational Autoencoder）。架构：

- 编码器：CNN + ViT，将图像映射为空间特征图，比如 32x32 个维度为 256 的特征。
- 码本（Codebook）：K 个向量的学习词汇（Chameleon 使用 8192），维度也为 256。
- 量化：对每个空间特征，按 L2 距离查找最近的码本条。用整数索引替换连续特征。
- 解码器：CNN，将量化特征转回像素。

训练：VAE 重建损失 + 承诺损失 + 码本损失。码本索引形成了图像的离散字母表。

对于 Chameleon：一张图像变成 32*32 = 1024 个 token，从 8192 的词汇中抽取。与文本 token（来自 LLM 的 BPE 词汇，比如 32000）拼接。最终词汇：40192。Transformer 看到一个序列，一个损失。

### 共享词汇

Chameleon 的词汇结合了文本 token、图像 token 和模态分隔符。每个 token 有单一 ID。输入嵌入层将每个 ID 映射为 D 维隐藏向量。输出投影将隐藏映射回词汇 logit。Softmax 选择下一个 token，无论什么模态。

分隔符很重要：`<image>` 和 `</image>` 标签包围图像 token 序列。在生成时，如果模型发出 `<image>`，下游软件知道接下来的 1024 个 token 是 VQ 索引，要发送到解码器进行像素渲染。

### 混合模态生成

推理是在共享词汇中的下一 token 预测。示例提示词：「画一只猫并描述它。」Chameleon 发出：

```
<image> 4821 1029 2891 ... (1024 个图像 token) </image>
猫是橙色的，坐在窗台上...
```

模型自主选择顺序——它可能先生成图像再生成文本，先生成文本再生成图像，或交错。相同的解码器，相同的损失。

对比适配器 VLM，生成仅限于文本。Chameleon 重新开启了模型输出模态的问题。

### 训练稳定性——QK-Norm、dropout、LayerNorm 顺序

早期融合训练在大规模下不稳定。Chameleon 论文记录了三个技巧：

- QK-Norm。在注意力内部对查询和键投影应用 LayerNorm，在点积之前。防止深层 logit 幅度爆炸。多个 2024 年后的大模型使用。
- Dropout 放置。每个残差加法之后做 dropout，不仅注意力和 MLP 之后。当来自图像 token 的梯度可能占主导时需要更多正则化。
- LayerNorm 顺序。残差分支上的 Pre-LN（标准），加上最后一个块的跳跃连接上的额外 LN。稳定最后一层的梯度流。

没有这些技巧，34B 参数的 Chameleon 训练在多个检查点发散。有了它们，它收敛了。训练方案与架构一样是贡献。

### 分词器的重建上限

VQ-VAE 是有损的。在 8192 个码本条和每张 512x512 图像 1024 个 token 时，重建 PSNR 上限约为 26-28 dB。这对于可识别的图像生成足够，但明显比连续空间扩散更差（Stable Diffusion 3 达到 32+ dB）。

分词器是瓶颈。更好的分词器（MAGVIT-v2、IBQ、SBER-MoVQGAN）提高了上限。Emu3（第 12.12 课）仅通过更好的分词器就达到了 SDXL 质量的生成。

### Chameleon vs BLIP-2 / LLaVA

Chameleon（早期融合，共享词汇）：
- 一个损失，一个解码器。
- 生成混合模态输出。
- 分词器是质量上限。
- 昂贵：推理路径上每张生成图像需要 VQ-VAE 解码器。

BLIP-2 / LLaVA（晚期融合，独立塔）：
- 视觉进，仅文本出。
- 重用预训练 LLM。
- 理解方面没有分词器瓶颈。
- 便宜：单次前向传播。

按任务选择。如果需要图像生成，Chameleon 家族。如果只需要理解，适配器 VLM 更简单且重用更多预训练算力。

### Fuyu 与 AnyGPT

Fuyu（Adept，2023）是一种相关方法：完全跳过独立的视觉编码器，直接将原始图像块通过 LLM 的输入投影输入，仿佛它们是 token，没有分词器。比 Chameleon 简单，但失去了共享词汇的输出生成。

AnyGPT（Zhan 等人，2024）将 Chameleon 扩展到四种模态：文本、图像、语音、音乐。每种模态使用相同的 VQ-VAE 技巧，共享 Transformer。任意-到-任意生成。第 12.16 课更多覆盖。

## 使用指南

`code/main.py` 构建一个玩具端到端早期融合模型：

- 一个微型 VQ-VAE 风格量化器，将 8x8 块映射到码本索引（K=16）。
- 一个共享词汇：（文本 id 0..31）+（图像 id 32..47）+（分隔符 48, 49）。
- 一个玩具自回归解码器（二元组表），在合成描述 + 图像 token 序列上训练。
- 采样循环，给定提示词后发出交替的文本 + 图像 token。

代码特意将 Transformer 保持得极小（二元组），让你可以端到端追踪信号流。

## 交付物

本课产出 `outputs/skill-tokenizer-vs-adapter-picker.md`。给定产品规格（仅理解 vs 理解 + 生成，所需图像质量，成本预算），它在 Chameleon 家族（早期融合）和 LLaVA 家族（晚期融合）之间选择，并用定量经验法则提供理由。

## 练习

1. Chameleon 使用 K=8192 个码本条和每张 512x512 图像 1024 个 token。估计与 24 位 RGB 图像相比的压缩比。它是有损的吗？有多大损耗？

2. 一张 4K 图像（3840x2160）在相同 VQ-VAE 密度下产生多少个图像 token？Chameleon 风格模型能否在一次推理调用中生成 4K 图像？什么最先崩溃——上下文、分词器质量还是 KV 缓存？

3. 在纯 Python 中实现 QK-Norm。给定 64 维查询和键，展示 LayerNorm 前后的点积。为什么幅度控制在深层很重要？

4. 阅读 Chameleon 第 2.3 节关于训练稳定性的内容。描述论文在 34B 下没有 QK-Norm 时观察到的确切失败模式。「范数爆炸」的特征是什么？

5. 扩展玩具解码器，在给定仅文本提示词时发出混合模态响应。测量在训练数据分布为 60% 文本优先 / 40% 图像优先的情况下，模型选择图像优先 vs 文本优先的频率。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|------------------------|
| 早期融合（Early fusion） | 「统一 token」 | 图像被转换为离散 token，从第一步起共享 Transformer 的词汇 |
| VQ-VAE | 「图像分词器」 | CNN + ViT + 码本，将图像映射为 Transformer 可以预测的整数索引 |
| 共享词汇 | 「一个词典」 | 涵盖文本 + 图像 + 模态分隔符的单一 token ID 空间 |
| QK-Norm | 「注意力稳定器」 | 在查询和键的点积之前对它们应用 LayerNorm，防止范数爆炸 |
| 混合模态生成 | 「文本 + 图像输出」 | 单次推理中自主产生交错文本和图像 token 的推理 |
| 码本大小 | 「K 个条目」 | VQ-VAE 可以量化到的离散向量数量；在压缩和保真度之间权衡 |
| 分词器上限 | 「重建极限」 | 解码 VQ token 可达到的最佳 PSNR；限制模型的图像质量 |

## 进一步阅读

- [Chameleon Team — Chameleon: Mixed-Modal Early-Fusion Foundation Models (arXiv:2405.09818)](https://arxiv.org/abs/2405.09818)
- [Aghajanyan et al. — CM3 (arXiv:2201.07520)](https://arxiv.org/abs/2201.07520)
- [Yu et al. — CM3Leon (arXiv:2309.02591)](https://arxiv.org/abs/2309.02591)
- [Zhan et al. — AnyGPT (arXiv:2402.12226)](https://arxiv.org/abs/2402.12226)
- [Adept — Fuyu-8B blog (adept.ai)](https://www.adept.ai/blog/fuyu-8b)