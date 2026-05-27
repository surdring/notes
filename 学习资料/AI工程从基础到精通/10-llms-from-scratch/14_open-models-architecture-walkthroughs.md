# 开放模型：架构走读

> 你在第 04 课中从零构建了一个 GPT-2 Small。2026 年的前沿开放模型是同一家族，有五六个具体变化。RMSNorm 代替 LayerNorm。SwiGLU 代替 GELU。RoPE 代替学习位置。GQA 或 MLA 代替完整 MHA。规模化的专家混合。你已经知道的数学覆盖了其中的 95%。本课并排阅读 Llama 3、DeepSeek-V3、Mixtral、Qwen 和 Gemma，指出每个架构偏离的确切行。

**类型：** 学习
**语言：** Python（标准库）
**前置要求：** 第 10 阶段，第 04、05、12 课（预训练、扩展、推理）
**时间：** 约 45 分钟

## 学习目标

- 阅读 Llama 3、Mistral、Mixtral、Gemma 2、Qwen 2.5 和 DeepSeek-V3 的 config.json 并解释每个字段
- 命名每个模型相对于 GPT-2 Small 所做的具体架构变化，并从第一性原理证明其合理性
- 仅从 config 计算任何开放模型的参数量、KV 缓存大小和激活内存
- 在给定延迟、内存和能力约束下为部署目标选择正确的开放模型

## 问题

在第 04 课中，你写了 350 行 numpy 代码，得到了一个 GPT-2 形状的模型。Llama 3 405B 有一份 200 页的技术报告。你的直觉是这些是不同的野兽。但它们不是。这 200 页描述了同一个对象，加上五六个动机良好的修改，外加一千个关于扩展的实现细节。骨架——嵌入、transformer 块、注意力、MLP、归一化、头——没有改变。

这一课是一个差异。对于每个主要的开放模型家族，我们列出从 GPT-2 具体改变了什么、为什么以及代价是什么。当你完成后，你可以读一份新模型卡并心算将其翻译回 GPT-2 基线。

实际的回报是，当 Meta 发布 Llama 5 或 DeepSeek 发布 V4 时，你将不需要一个新的心智模型。你将查看 config，看到哪些众所周知的旋钮移动了，并知道下游影响是什么。2026 年的架构是一个有限的工具箱。每个新模型选择不同的子集。

## 概念

### 不变的核心

所有自回归开放模型共享：

- Token 嵌入矩阵（vocab_size x hidden_dim）。
- N 个解码器块的堆叠：归一化、自注意力、残差、归一化、MLP、残差。
- 最终归一化和投影到 vocab_size 的线性头（通常与嵌入权重绑定）。
- 因果掩码、下一 token 交叉熵损失。

这就是形状。其余的是旋钮。

### 实际移动的六个旋钮

在所有 2024-2026 年前沿开放模型中，相同的六个设计选择被反复做出：

1. **归一化。** LayerNorm -> RMSNorm。
2. **位置编码。** 学习绝对值 -> RoPE（加变体：YaRN、NTK）。
3. **激活函数。** GELU -> SwiGLU（或 GeGLU）。
4. **注意力头共享。** MHA -> GQA -> MQA -> MLA。
5. **密集 vs 稀疏 MLP。** 密集 -> 专家混合。
6. **Pre-norm 位置。** Pre-norm 保留。Post-norm 消失了。

其他所有东西（学习率调度、数据混合、批次大小、上下文长度）存在于训练配置中，而非架构中。六个旋钮。

### 旋钮 1：RMSNorm

LayerNorm 减去均值，除以标准差，缩放，和偏移。RMSNorm 只保留缩放：

```
RMSNorm(x) = x / sqrt(mean(x^2) + eps) * gamma
```

没有均值减法。没有偏置。每个 token 少一次 matmul。Zhang 和 Sennrich（2019）认为它在机器翻译上匹配 LayerNorm，同时快 10%。每个现代开放模型都运行它。

### 旋钮 2：RoPE

学习位置嵌入在 GPT-2 中是一个 1024 槽的查找表。上下文 1025 就超出了表的末端。模型无法外推到其训练长度之外。

旋转位置嵌入（RoPE，Su et al. 2021）通过在注意力点积之前对每对 Q 和 K 向量进行旋转来注入位置。旋转角度是位置的确定性函数，因此没有任何需要学习的内容，也没有会用完的东西。使用缩放技巧（NTK 感知插值、YaRN），在 8k 上下文上训练的模型可以在推理时扩展到 128k，准确度损失适中。

```
q_rotated = rotate(q, angle(pos))
k_rotated = rotate(k, angle(pos))
score = q_rotated . k_rotated
```

每个 Llama、Mistral、Qwen、DeepSeek 和 Gemma 都使用 RoPE。Gemma 2 使用混合方案（大多数层用 RoPE，其他层用局部滑动窗口注意力）。

### 旋钮 3：SwiGLU

GPT-2 的 MLP 是 `x -> gelu(xW1 + b1) -> (...)W2 + b2`。SwiGLU（Shazeer 2020）将激活替换为门控乘积：

```
SwiGLU(x) = (xW1) * sigmoid(xW1) * xV
```

两个并行投影而不是一个，由 Swish 激活门控。经验上每参数困惑度更强。Llama 2 采用了它，所有人都跟随了。MLP 的隐藏大小通常设置使总参数量匹配原始密集 MLP：如果 GPT-2 使用 `ff_dim = 4 * hidden`，SwiGLU 使用 `ff_dim = (2/3) * 4 * hidden = 8/3 * hidden`。

### 旋钮 4：注意力头共享

GPT-2 使用**多头注意力（MHA）**：每个头有自己的 Q、K、V 投影。

**多查询注意力（MQA，Shazeer 2019）** 在所有头之间共享一个 K 和一个 V。将 KV 缓存削减 num_heads 倍，在典型模型上是 12x 到 32x 的减少。在难基准上精度略有下降。

**分组查询注意力（GQA，Ainslie et al. 2023）** 是折中方案：G 组 Q 头共享一个 K 和一个 V。Llama 3 8B 使用 GQA，32 个 Q 头和 8 个 KV 头（G=8），因此 KV 缓存缩小 4 倍。

**多头潜在注意力（MLA，DeepSeek 2024）** 将 K 和 V 压缩到共享的低秩潜在空间中，按头投影回来。进一步减少 KV 缓存同时保留每头表达能力。DeepSeek-V2 和 V3 依赖此技术实现其长上下文性能。

| 方案 | KV 头数 | KV 缓存 | 准确度 |
|------|---------|---------|--------|
| MHA | num_heads | 完整 | 最佳 |
| GQA | num_groups (G < num_heads) | num_heads / G 减少 | 接近 MHA |
| MQA | 1 | 最大减少 | 下降 1-3% |
| MLA | 潜在维度 | 比 MQA 更少 | 接近 MHA |

### 旋钮 5：专家混合（MoE）

密集模型为每个 token 激活*所有*参数。对于 70B 模型，每个前向传播乘以完整的 70B 权重矩阵。

专家混合将 MLP 层替换为一组专家——通常是 8 或 16 个较小的 MLP。一个路由器（一个小型学习网络）为每个 token 选择 top-k 专家（通常 k=2）。只有这些专家被激活。

Mixtral 8x7B 有 8 个专家，每个 token 使用 2 个。总参数量：46.7B。每 token 活跃参数：12.9B。推理成本与 13B 密集模型相同，但质量接近 70B 密集模型。

DeepSeek-V3 有 256 个专家，每个 token 使用 8 个（1 个共享 + 7 个路由）。总计：671B 参数。每 token 活跃：37B。质量匹配 405B 密集模型，推理速度更快。

### 旋钮 6：Pre-norm

GPT-2 使用 pre-norm：层归一化在注意力和 MLP*之前*。Post-norm（原始 transformer）在之后放置归一化。Pre-norm 更稳定——训练曲线更平滑，对学习率不那么敏感。每篇 2020 年后的论文都默认使用它。

### 模型对照表

| 模型 | 参数 | RoPE | 注意力 | MLP | 归一化 | 独特之处 |
|------|------|------|--------|-----|--------|----------|
| GPT-2 Small | 124M | 学习位置 | MHA (12头) | GELU 密集 | LayerNorm | 基线 |
| Llama 3 8B | 8B | RoPE (8K) | GQA (32Q/8KV) | SwiGLU 密集 | RMSNorm | GQA |
| Llama 3 70B | 70B | RoPE (8K) | GQA (64Q/8KV) | SwiGLU 密集 | RMSNorm | 更大规模 |
| Mistral 7B | 7.3B | RoPE (32K) | GQA (32Q/8KV) | SwiGLU 密集 | RMSNorm | 滑动窗口注意力 |
| Mixtral 8x7B | 46.7B | RoPE (32K) | GQA (32Q/8KV) | SwiGLU MoE (8专家) | RMSNorm | MoE |
| DeepSeek-V3 | 671B | RoPE (MLA) | MLA | SwiGLU MoE (256专家) | RMSNorm | MLA + 大规模 MoE |
| Qwen 2.5 72B | 72B | RoPE (128K) | GQA (64Q/8KV) | SwiGLU 密集 | RMSNorm | YaRN 扩展上下文 |
| Gemma 2 27B | 27B | RoPE (8K) | GQA (32Q/8KV) | GeGLU 密集 | RMSNorm | 交替局部/全局注意力 |

## 构建

本课是学习性质的。不涉及代码。目标是阅读和计算。

## 交付

保存为 `outputs/skill-open-model-picker.md`。

## 练习

1. **简单。** 从 Llama 3 8B config.json 计算总参数量。验证与报告值匹配。
2. **中等。** 为所有七个模型计算 128K 上下文下的 KV 缓存大小。哪个需要最多的内存？为什么？
3. **困难。** 解释为什么 DeepSeek-V3 可以在匹配 405B 密集模型的同时使用更少的推理计算。具体命名节省来自哪些旋钮。

## 关键术语

| 术语 | 含义 |
|------|------|
| RMSNorm | 无均值减法的层归一化；更快，相同的经验性能。 |
| RoPE | 旋转位置嵌入；位置通过旋转注入。 |
| SwiGLU | 门控激活：Swish 乘以投影。 |
| GQA | 分组查询注意力：G 组 Q 头，每组一个 K/V 对。 |
| MLA | 多头潜在注意力：低秩压缩的 KV 缓存。 |
| MoE | 专家混合：每个 token 激活参数的子集。 |
| YaRN | RoPE 插值方法，用于扩展训练后的上下文长度。 |

## 扩展阅读

- [Touvron et al. (2023). Llama 2: Open Foundation and Fine-Tuned Chat Models](https://arxiv.org/abs/2307.09288)
- [Dubey et al. (2024). The Llama 3 Herd of Models](https://arxiv.org/abs/2407.21783)
- [Jiang et al. (2023). Mistral 7B](https://arxiv.org/abs/2310.06825)
- [Jiang et al. (2024). Mixtral of Experts](https://arxiv.org/abs/2401.04088)
- [DeepSeek-AI. (2024). DeepSeek-V2: A Strong, Economical, and Efficient Mixture-of-Experts Language Model](https://arxiv.org/abs/2405.04434)
- [Team et al. (2024). Gemma 2: Improving Open Language Models at a Practical Size](https://arxiv.org/abs/2408.00118)