# Jamba——混合 SSM-Transformer

> 状态空间模型（SSM）和 transformer 想要不同的东西。Transformer 通过注意力以二次代价换取质量。SSM 通过递归以线性时间推理和恒定内存换取，但质量落后。AI21 的 Jamba（2024 年 3 月）和 Jamba 1.5（2024 年 8 月）将它们放在同一模型中：每 7 个 Mamba 层配 1 个 Transformer 层，每隔一个块使用 MoE，以及适配单块 80GB GPU 的 256k 上下文窗口。Mamba-3（ICLR 2026）通过复值状态空间和 MIMO 投影加强了 SSM 一侧。本课从头到尾阅读两种架构，并解释为什么混合配方在纯 SSM 和纯 Transformer 长上下文尝试都失败的情况下存活了三年扩展。

**类型：** 学习
**语言：** Python（标准库，层混合计算器）
**前置知识：** 第十阶段 · 14（开放模型架构），第十阶段 · 17（原生稀疏注意力）
**时间：** 约 60 分钟

## 学习目标

- 解释 Jamba 块中的三个原语——Transformer 层、Mamba 层、MoE——以及 1:7:偶数交错配方。
- 在高层次上陈述 SSM 的递归是什么样子，以及为什么它实现恒定内存推理。
- 在 256k 上下文下计算 Jamba 模型的 KV 缓存占用，并与纯 Transformer 模型需要的内存比较。
- 说出三个 Mamba-3 创新（指数梯形离散化、复值状态更新、MIMO）以及每个所针对的问题。

## 问题

注意力与序列长度是二次方关系。状态空间模型是线性关系。这种差异复合：在 256k token 时，Transformer 注意力图每个头是 65B 个条目；SSM 的递归状态无论序列长度如何都是固定大小。

纯 SSM 模型（Mamba、Mamba-2）在小规模上匹配 Transformer 困惑度，但在状态跟踪任务上落后，并在某些类别的上下文检索上失败。直觉：SSM 将历史压缩为固定状态，当历史很长时，信息泄露。注意力精确记住一切，但付出二次代价。

明显的修复：两者都用。在需要精确回忆的地方放 Transformer 层。在其他地方用 SSM 层。调整比率。Jamba 是第一个在大规模上发布此混合配方的生产级模型（52B 总计，12B 激活，256k 上下文，单块 80GB GPU）。Jamba 1.5 将家族扩展到 398B 总计 / 94B 激活。Mamba-3（ICLR 2026）是当前最佳的纯 SSM 基线，混合模型可围绕其重建。

本课阅读三篇论文，并产生"选择正确比率"的心智模型。

## 核心概念

### 一页纸了解 SSM

状态空间模型通过固定大小状态 `h` 处理序列 `x_1, ..., x_N`：

```
h_t = A h_{t-1} + B x_t
y_t = C h_t
```

在每一步，状态通过线性动力学 `A` 演化，接受输入 `B x_t`，并发出输出 `C h_t`。`A, B, C` 可以是可学习的。注意关键属性：计算 `y_t` 只需要 `h_{t-1}` 和 `x_t`，不需要任何更早的 `x`。内存恒定。推理是每个 token O(1)。

建模质量的关键是 `A` 的结构。S4（Gu 2021）使用了一个高度结构化的矩阵，可以在训练期间作为长卷积高效评估。Mamba（Gu、Dao 2023）将固定的 `A, B, C` 替换为数据相关的（"选择性"部分）。Mamba-2（2024）进一步简化了结构。Mamba-3（2026）在特定位置重新增加复杂性。

关键属性：对于解码器 LLM，SSM 层是注意力层的即插即用替换，具有每层固定大小状态而非增长的 KV 缓存。

### Jamba 块

Jamba 块根据两个数字交错排列层：

- `l`：注意力与 Mamba 的比率。Jamba 使用 `l = 8`，意味着每 7 个 Mamba 层配 1 个 Transformer 层（7 Mamba + 1 Attention = 每组 8 层）。
- `e`：MoE 频率。Jamba 使用 `e = 2`，意味着每隔一层应用 MoE。

块内的层序列：

```
M  M  M  M  M  M  M  A    （7 Mamba + 1 Attention）
|  M  |  M  |  M  |  M    （其中 | 标记 MoE 应用处）
```

每个 Jamba 块是 8 层。在 4 个块深度（总共 32 层）下，你得到 28 个 Mamba 和 4 个 Attention 层。其中 16 个使用 MoE。

### 为什么是 1:7 比率

AI21 进行了消融实验：注意力与 Mamba 的什么比率在它们的长上下文评估上给出最佳的每参数困惑度和上下文内召回？

- 太多注意力（1:1）：质量上升但内存和速度下降。
- 太少注意力（1:15）：内存很好但上下文检索失败。
- 甜蜜点：1:7 或 1:8。

直觉：Transformer 层处理精确回忆和状态跟踪。Mamba 层处理廉价的批量处理。

### 位置编码

Mamba 层自身就是位置感知的（通过递归）。原始基于 Mamba 的混合模型中的注意力层不使用 RoPE——SSM 层提供位置信息。Jamba 1.5 向注意力层添加了 RoPE 以实现更长上下文的泛化，这是基于经验长上下文评估的事后优化。

### 内存预算

对于 Jamba-1 形状（32 层：28 Mamba + 4 Attention，hidden 4096，32 个注意力头）：

- KV 缓存（仅注意力层）：`2 * 4 * 32 * 128 * 256k * 2 = 8.4 GB` 在 256k BF16 下。只有 4 个注意力层有贡献。
- SSM 状态：每个 token 前缀 `28 * hidden * state_size`，但这是每层的固定大小，不随序列长度缩放。典型 Mamba 状态是每个特征 16，hidden 4096：`28 * 4096 * 16 * 2 = 3.7 MB` 总计。

与 32 层、相同 hidden、32 头全 MHA 的纯 Transformer 比较：`2 * 32 * 32 * 128 * 256k * 2 = 128 GB` 在 256k BF16 下。KV 缓存减少 8x。即使与大多数 2024 模型使用的 GQA(8) 基线比较（`2 * 32 * 8 * 128 * 256k * 2 = 32 GB`），Jamba 的 1:7 混合在 16 GB 时仍然小 2x。

这就是 AI21 所说的"在单块 80GB GPU 上实现 256k 上下文"。纯全 MHA Transformer 的 KV 缓存根本装不下；即使是 GQA 基线也没有为权重和激活留下空间；Jamba 的可以。

### Mamba-3：2026 年纯 SSM 基线

Mamba-3（ICLR 2026，arXiv:2603.15569）在纯 SSM 一侧引入了三个创新：

1. **指数梯形离散化。** 用更具表达力的递归替换 Mamba-2 中的欧拉法离散化。在核心递归中对状态输入应用类卷积操作，而非作为 `x_t` 上的外卷积。

2. **复值状态更新。** 之前的 Mamba 将状态矩阵从复数（S4）简化为实数对角（Mamba）再简化为缩放恒等（Mamba-2）。Mamba-3 重新添加复数值——等价于状态上的数据相关旋转嵌入。这恢复了之前实数值简化所牺牲的状态跟踪能力。

3. **多输入多输出（MIMO）投影。** 使用矩阵值投影替代每个特征的标量投影。在不增加解码延迟的情况下提高建模能力和推理时硬件利用率。

在 1.5B 参数下，Mamba-3 比 Gated DeltaNet 平均下游准确率提高 0.6 分；MIMO 变体再加 1.2 分，总计 1.8 分增益。在相同状态大小下，Mamba-3 以一半状态匹配 Mamba-2。

Mamba-3 尚未在大规模生产混合模型中发布——但它是下一个 Jamba 级别模型 SSM 一侧的明显候选。

### 何时使用混合模型

混合模型在以下情况胜出：

- 上下文足够长以至于纯 Transformer KV 缓存变得痛苦（64k+）。
- 任务混合短程结构（适合 SSM）和长程回忆（需要 Transformer）。
- 你想在 Transformer KV 缓存本身无法容纳的单 GPU 内存预算上部署。

混合模型在以下情况失败：

- 上下文很短（低于 16k）。SSM 开销被浪费；纯 Transformer 完全没问题。
- 任务需要处处到处的注意力（深度推理、多文档交叉引用）。混合模型中注意力层的稀疏性有害。
- 你正在扩展到万亿参数前沿模型。纯 Transformer + MLA + MoE（DeepSeek-V3 风格）目前胜出能力竞赛。

### 竞争格局

| 模型 | 家族 | 规模 | 独特声明 |
|-------|--------|------|-------------|
| Mamba-2 | 纯 SSM | 3B | 线性时间，恒定内存 |
| Jamba | 混合 | 52B/12B | 80GB 上 256k |
| Jamba 1.5 Large | 混合 | 398B/94B | 企业级长上下文 |
| Mamba-3 | 纯 SSM | 1.5B（论文） | 状态跟踪恢复 |
| DeepSeek-V3 | 纯 Transformer + MoE | 671B/37B | 前沿能力 |

2026 年格局：纯 Transformer MoE 主导前沿，但混合模型在 256k+ 上下文细分市场占有优势。Mamba-3 的状态跟踪优势可能在下一代中推动更低的混合比率（更多 SSM，更少注意力）。

## 使用方式

`code/main.py` 是混合架构的内存计算器。给定 SSM-Transformer 比率和隐藏大小/层数配置，它计算：

- 目标上下文下的 KV 缓存。
- SSM 状态内存。
- 在上下文 N 下对一系列模型形状的总内存。

计算器支持：

- 纯 Transformer 基线（KV 缓存随 N 增长）。
- Jamba 风格 1:7 混合。
- 纯 SSM（完全没有 KV 缓存）。

数字对于已发布形状直接来自 Jamba-1 和 Jamba-1.5 论文，对于假设变体进行外推。

真实部署的集成考量：

- 大多数生产推理服务器（vLLM、SGLang）支持 Jamba 和 Mamba。检查具体版本。
- 在 256k 上下文下，Jamba 的内存优势体现在并发请求吞吐量上。在相同 VRAM 上你能容纳比 Transformer 序列更多的 Jamba 序列。
- Mamba-3 作为独立模型尚未在生产中发布——1.5B 研究预览。

## 交付产出

本课产生 `outputs/skill-hybrid-picker.md`。给定工作负载规范（上下文长度分布、任务混合、内存预算），它在纯 Transformer、Jamba 风格混合和纯 SSM 之间推荐，附带关于内存和质量权衡的明确推理。

## 练习

1. 运行 `code/main.py` 计算在 256k 上下文下 32 层纯 Transformer（hidden 4096, 32 头）和相同形状的 Jamba-1 混合的 KV 缓存。验证 AI21 论文声称的约 8x 内存减少。

2. 修改计算器以建模 1:3 混合（4 Mamba : 1 Attention）和 1:15 混合（14 Mamba : 1 Attention）。绘制 KV 缓存 vs 比率。在什么比率下 KV 缓存等于 SSM 状态内存？

3. 阅读 Jamba 论文（arXiv:2403.19887）第 3 节。解释为什么 AI21 使用 Mamba-1 而非 Mamba-2，尽管 Mamba-2 更快。提示：混合消融实验部分记录了这一点。

4. 计算 Jamba 1.5 Large（398B 总计，94B 激活）中每隔一层 MoE 的参数开销。将激活比率与 DeepSeek-V3（37B/671B）比较，解释为什么 Jamba 的架构推动激活比率更高。

5. 阅读 Mamba-3 论文（arXiv:2603.15569）第 3 节。用三句话解释为什么复值状态更新等价于数据相关旋转嵌入。将答案与第七阶段 · 第 04 课的 RoPE 推导联系起来。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|----------------|------------------------|
| 状态空间模型（SSM） | "固定状态的递归" | 具有可学习递归 `h_t = A h_{t-1} + B x_t` 的层；每个 token 恒定内存 |
| 选择性 SSM | "Mamba 的技巧" | 数据相关的 A、B、C 参数，以线性时间赋予模型类门控的选择性 |
| 注意力与 Mamba 比率 | "有多少注意力层" | 在 Jamba 中，`l = 8` 意味着每 7 个 Mamba 层配 1 个注意力层 |
| Jamba 块 | "8 层组" | 一个注意力 + 七个 Mamba + 交替位置上的 MoE |
| SSM 状态 | "隐藏缓冲区" | 为 Mamba 层替换 KV 缓存的每层固定大小状态 |
| 256k 上下文 | "Jamba 的旗舰数字" | Jamba-1 能适配单块 80GB GPU 的序列长度；纯 Transformer 在该规模下做不到 |
| Mamba-3 | "2026 纯 SSM" | 当前最佳的纯 SSM 架构，具有复值状态 + MIMO；混合模型重建的基线 |
| MIMO | "多输入多输出" | Mamba-3 创新，使用矩阵值投影替代每个特征的标量 |
| 指数梯形离散化 | "Mamba-3 的递归" | 更具表达力的递归，包含 Mamba-2 的欧拉法离散化 |
| 混合架构 | "混合注意力和 SSM" | 任何交错 Transformer 和 SSM 层的模型；Jamba 是生产原型 |

## 扩展阅读

- [Lieber et al. — Jamba: A Hybrid Transformer-Mamba Language Model (arXiv:2403.19887)](https://arxiv.org/abs/2403.19887) — 原始 Jamba 论文，比率消融实验，256k 上下文声明
- [AI21 — Jamba 1.5: Hybrid Transformer-Mamba at Scale (arXiv:2408.12570)](https://arxiv.org/abs/2408.12570) — 扩展后的家族，398B/94B 和 12B/52B 公开发布
- [Gu, Dao — Mamba: Linear-Time Sequence Modeling with Selective State Spaces (arXiv:2312.00752)](https://arxiv.org/abs/2312.00752) — Jamba 所构建的选择性 SSM 论文
- [Dao, Gu — Mamba-2 (arXiv:2405.21060)](https://arxiv.org/abs/2405.21060) — 简化的结构化状态空间后继
- [Lahoti et al. — Mamba-3 (arXiv:2603.15569, ICLR 2026)](https://arxiv.org/abs/2603.15569) — 复值状态、MIMO，2026 年纯 SSM 前沿
- [Gu et al. — Efficiently Modeling Long Sequences with Structured State Spaces (arXiv:2111.00396)](https://arxiv.org/abs/2111.00396) — S4 论文，LLM SSM 谱系的起点