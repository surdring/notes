# 注意力机制——突破

> 解码器不再眯着眼睛看压缩后的摘要，开始查看整个源输入。在这之后一切都是注意力加上工程实践。

**类型：** 构建
**语言：** Python
**前置要求：** 第 5 阶段 · 09（序列到序列模型）
**时间：** 约 45 分钟

## 问题

第 09 课以一个可衡量的失败结束。在玩具复制任务上训练的 GRU 编码器-解码器，长度为 5 时准确率 89%，长度为 80 时准确率接近随机。原因是结构性的，不是训练 bug：编码器收集到的每条信息都必须装进一个固定大小的隐藏状态，而解码器永远看不到其他信息。

Bahdanau、Cho 和 Bengio 在 2014 年发表了一个三行代码的修复方案。不给解码器只提供最终编码器状态，保留每个编码器状态。在每个解码器步骤，计算编码器状态的加权平均，权重表示"解码器现在需要多看编码器位置 `i` 多少？"这个加权平均就是上下文，它在每个解码器步骤都会变化。

这就是整个想法。Transformer 对其进行了扩展。自注意力将其应用到单个序列上。多头注意力并行运行。但 2014 年的版本已经打破了瓶颈，一旦你掌握了它，转向 Transformer 只是工程问题，不是概念问题。

## 概念

![Bahdanau 注意力：解码器查询所有编码器状态](../assets/attention.svg)

在每个解码器步骤 `t`：

1. 使用前一个解码器隐藏状态 `s_{t-1}` 作为**查询**。
2. 用它对每个编码器隐藏状态 `h_1, ..., h_T` 打分。每个编码器位置得到一个标量。
3. 对分数进行 softmax 得到注意力权重 `α_{t,1}, ..., α_{t,T}`，总和为 1。
4. 上下文向量 `c_t = Σ α_{t,i} * h_i`。编码器状态的加权平均。
5. 解码器接受 `c_t` 加上前一个输出标记，产生下一个标记。

加权平均是关键。当解码器需要将"Je"翻译为"I"，它会给"Je"上方的编码器状态分配高权重，其他位置低权重。当需要翻译"not"时，它给"pas"分配高权重。上下文向量在每一步都会重塑。

## 维度（每个人都在这里犯错）

这是每个注意力实现第一次都会出错的地方。慢慢读。

| 事物 | 形状 | 注释 |
|-------|-------|-------|
| 编码器隐藏状态 `H` | `(T_enc, d_h)` | 如果是双向 LSTM，`d_h = 2 * d_hidden` |
| 解码器隐藏状态 `s_{t-1}` | `(d_s,)` | 一个向量 |
| 注意力分数 `e_{t,i}` | 标量 | 每个编码器位置一个 |
| 注意力权重 `α_{t,i}` | 标量 | 对所有 `i` 做 softmax 后 |
| 上下文向量 `c_t` | `(d_h,)` | 与编码器状态形状相同 |

**Bahdanau（加性）打分。** `e_{t,i} = v_α^T * tanh(W_a * s_{t-1} + U_a * h_i)`。

- `s_{t-1}` 形状 `(d_s,)`，`h_i` 形状 `(d_h,)`。
- `W_a` 形状 `(d_attn, d_s)`。`U_a` 形状 `(d_attn, d_h)`。
- tanh 内部它们的和形状 `(d_attn,)`。
- `v_α` 形状 `(d_attn,)`。与 `v_α` 的内积收缩为一个标量。**这就是 `v_α` 的作用。** 这不是魔法。它就是将注意力维度向量投影为标量分数的投影层。

**Luong（乘性）打分。** 三个变体：

- `dot`: `e_{t,i} = s_t^T * h_i`。要求 `d_s == d_h`。硬约束。如果编码器是双向的就跳过。
- `general`: `e_{t,i} = s_t^T * W * h_i`，`W` 形状 `(d_s, d_h)`。移除了维度相等约束。
- `concat`: 本质上就是 Bahdanau 形式。由于前两种更便宜，很少使用。

**Bahdanau / Luong 一个值得注意的坑。** Bahdanau 使用 `s_{t-1}`（生成当前词之前的解码器状态）。Luong 使用 `s_t`（生成当前词之后的状态）。混淆它们会产生微妙的错误梯度，这极难调试。选择一篇论文，坚持它的约定。

## 构建

### 步骤 1：加性（Bahdanau）注意力

```python
import numpy as np


def additive_attention(decoder_state, encoder_states, W_a, U_a, v_a):
    projected_dec = W_a @ decoder_state
    projected_enc = encoder_states @ U_a.T
    combined = np.tanh(projected_enc + projected_dec)
    scores = combined @ v_a
    weights = softmax(scores)
    context = weights @ encoder_states
    return context, weights


def softmax(x):
    x = x - np.max(x)
    e = np.exp(x)
    return e / e.sum()
```

对照上表检查你的维度。`encoder_states` 形状 `(T_enc, d_h)`。`projected_enc` 形状 `(T_enc, d_attn)`。`projected_dec` 形状 `(d_attn,)` 并进行广播。`combined` 形状 `(T_enc, d_attn)`。`scores` 形状 `(T_enc,)`。`weights` 形状 `(T_enc,)`。`context` 形状 `(d_h,)`。完成。

### 步骤 2：Luong dot 和 general

```python
def dot_attention(decoder_state, encoder_states):
    scores = encoder_states @ decoder_state
    weights = softmax(scores)
    return weights @ encoder_states, weights


def general_attention(decoder_state, encoder_states, W):
    projected = W.T @ decoder_state
    scores = encoder_states @ projected
    weights = softmax(scores)
    return weights @ encoder_states, weights
```

每个只要三行。这就是 Luong 的论文成功的原因。在大多数任务上准确率相同，代码少很多。

### 步骤 3：数值计算示例

给定三个编码器状态（大致对应 "cat"、"sat"、"mat"）和一个与第一个最对齐的解码器状态，注意力分布集中在位置 0。如果解码器状态移动到与最后一个对齐，注意力会移动到位置 2。上下文向量随之变化。

```python
H = np.array([
    [1.0, 0.0, 0.2],
    [0.5, 0.5, 0.1],
    [0.1, 0.9, 0.3],
])

s_close_to_cat = np.array([0.9, 0.1, 0.2])
ctx, w = dot_attention(s_close_to_cat, H)
print("weights:", w.round(3))
```

```
weights: [0.464 0.305 0.231]
```

第一行获胜。然后将解码器状态移动到更靠近第三个编码器状态，观察权重如何变化。就是这样。注意力就是显式对齐。

### 步骤 4：为什么这是通往 Transformer 的桥梁

将上述语言翻译成 Q/K/V：

- **查询** = 解码器状态 `s_{t-1}`
- **键** = 编码器状态（我们用来打分的对象）
- **值** = 编码器状态（我们加权求和的对象）

在经典注意力中，键和值是同一个东西。自注意力将它们分离：你可以用它对一个序列自己查询自己，对 K 和 V 使用不同的学习投影。多头注意力用不同的学习投影并行运行。Transformer 将整个阶段堆叠多次，抛弃了 RNN。

数学是相同的。形状是相同的。从 Bahdanau 注意力到缩放点积注意力，教学上的跳跃主要就是符号问题。

## 使用

PyTorch 和 TensorFlow 直接提供注意力。

```python
import torch
import torch.nn as nn

mha = nn.MultiheadAttention(embed_dim=128, num_heads=8, batch_first=True)
query = torch.randn(2, 5, 128)
key = torch.randn(2, 10, 128)
value = torch.randn(2, 10, 128)

output, weights = mha(query, key, value)
print(output.shape, weights.shape)
```

```
torch.Size([2, 5, 128]) torch.Size([2, 5, 10])
```

这就是一个 Transformer 注意力层。查询批量有 5 个位置，键/值批量有 10 个位置，每个都是 128 维，8 个头。`output` 是新的上下文增强的查询。`weights` 是你可以可视化的 5×10 对齐矩阵。

### 经典注意力仍然重要的场景

- 教学。单头、单层、基于 RNN 的版本让每个概念都清晰可见。
- 设备端序列任务，Transformer 放不下。
- 任何 2014-2017 年的论文。不知道 Bahdanau 的约定你会读不懂。
- MT 中的细粒度对齐分析。即使在 Transformer 模型上，原始注意力权重也是一个可解释性工具，要读懂它们你需要知道它们是什么。

### 注意力权重即解释的陷阱

注意力权重看起来可解释。它们是权重，在位置上总和为一；你可以绘制它们；高权重意味着"看了这里"。审稿人喜欢它们。

它们并不像看起来那样可解释。Jain 和 Wallace（2019）表明，在某些任务上，注意力分布可以被置换并替换为任意替代方案，而不改变模型预测。如果没有消融或反事实检查，永远不要报告注意力权重作为推理证据。

## 交付

保存为 `outputs/prompt-attention-shapes.md`：

```markdown
---
name: attention-shapes
description: Debug attention implementations 中的形状 bug。
phase: 5
lesson: 10
---

给定一个坏掉的注意力实现，你识别出形状不匹配。输出：

1. 哪个矩阵形状错了。说出张量名称。
2. 它的形状应该是什么，从 (d_s, d_h, d_attn, T_enc, T_dec, batch_size) 推导而来。
3. 一行修复。转置、reshape 或投影。
4. 捕捉回归的测试。通常：断言 `output.shape == (batch, T_dec, d_h)` 且 `weights.shape == (batch, T_dec, T_enc)` 且 `weights.sum(dim=-1) close to 1`。

拒绝推荐静默广播的修复。隐藏广播的 bug 之后会作为静默准确率退化出现，这是最糟糕的注意力 bug。

对于 Bahdanau 混淆，坚持解码器输入是 `s_{t-1}`（步骤前状态）。对于 Luong，输入是 `s_t`（步骤后状态）。对于点积，标记查询和键之间的维度不匹配是最常见的首次错误。
```

## 练习

1. **简单。** 实现 softmax 掩码，使编码器中的填充标记获得零注意力权重。在一个带变长序列的批次上测试。
2. **中等。** 给 Luong `general` 形式添加多头注意力。将 `d_h` 分割成 `n_heads` 组，每个头运行注意力，然后拼接。验证单头情况与你之前的实现匹配。
3. **困难。** 在第 09 课的玩具复制任务上训练带 Bahdanau 注意力的 GRU 编码器-解码器。绘制准确率与序列长度的关系图。与无注意力基线对比。你应该看到差距随着长度增长而扩大，证实注意力解除了瓶颈。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| 注意力 | 关注事物 | 值序列的加权平均，权重由查询-键相似性计算得到。 |
| 查询、键、值 | QKV | 三个投影：Q 提问，K 是匹配对象，V 是返回内容。 |
| 加性注意力 | Bahdanau | 前馈打分：`v^T tanh(W q + U k)`。 |
| 乘性注意力 | Luong dot / general | 分数是 `q^T k` 或 `q^T W k`。更便宜，大多数任务准确率相同。 |
| 对齐矩阵 | 漂亮图片 | 作为 `(T_dec, T_enc)` 网格的注意力权重。读取它可以看到模型关注了什么。 |

## 扩展阅读

- [Bahdanau, Cho, Bengio (2014). Neural Machine Translation by Jointly Learning to Align and Translate](https://arxiv.org/abs/1409.0473)——原始论文。
- [Luong, Pham, Manning (2015). Effective Approaches to Attention-based Neural Machine Translation](https://arxiv.org/abs/1508.04025)——三种打分变体及其比较。
- [Jain and Wallace (2019). Attention is not Explanation](https://arxiv.org/abs/1902.10186)——可解释性警告。
- [Dive into Deep Learning——Bahdanau Attention](https://d2l.ai/chapter_attention-mechanisms-and-transformers/bahdanau-attention.html)——带 PyTorch 的可运行讲解。