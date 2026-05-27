# 从零实现自注意力

> 注意力是一个查找表，其中每个词问"谁对我重要？"——并学习答案。

**类型：** 构建
**语言：** Python
**前置要求：** 第 3 阶段（深度学习核心），第 5 阶段第 10 课（序列到序列）
**时间：** 约 90 分钟

## 学习目标

- 仅使用 NumPy 从头实现缩放点积自注意力，包括查询/键/值投影和 softmax 加权和
- 构建一个分割头、计算并行注意力并拼接结果的多头注意力层
- 追踪注意力矩阵如何捕获标记关系，并解释为什么要除以 sqrt(d_k) 防止 softmax 饱和
- 应用因果掩码将双向注意力转换为自回归（解码器风格）注意力

## 问题

RNN 一次处理一个标记的序列。当你到达标记 50 时，标记 1 的信息已经通过 50 次压缩步骤被挤压。长程依赖被压进固定大小的隐藏状态——没有任何 LSTM 门控能完全解决的瓶颈。

2014 年 Bahdanau 注意力论文展示了修复：让解码器回头看每个编码器位置，决定哪些对当前步骤重要。但它仍然附加在 RNN 上。2017 年"Attention Is All You Need"论文提出了一个更尖锐的问题：如果注意力是*唯一*的机制呢？没有循环。没有卷积。只有注意力。

自注意力让序列中的每个位置在一次并行步骤中关注每个其他位置。这就是 transformer 快速、可缩放和主导的原因。

## 概念

### 数据库查找类比

把注意力想象成软数据库查找：

```
传统数据库：
  查询："法国的首都"  -->  精确匹配  -->  "巴黎"

注意力：
  查询："法国的首都"  -->  与所有键的相似度  -->  所有值的加权混合
```

每个标记生成三个向量：
- **查询（Q）**："我在找什么？"
- **键（K）**："我包含什么？"
- **值（V）**："如果被选中，我提供什么信息？"

查询与所有键的点积产生注意力分数。高分意味着"这个键匹配我的查询"。这些分数加权值。输出是值的加权和。

### Q、K、V 计算

每个标记嵌入通过三个学习到的权重矩阵投影：

```
输入嵌入（n 个标记的序列，每标记 d 维）：

  X = [x1, x2, x3, ..., xn]       形状：(n, d)

三个权重矩阵：

  Wq  形状：(d, dk)
  Wk  形状：(d, dk)
  Wv  形状：(d, dv)

投影：

  Q = X @ Wq    形状：(n, dk)      每个标记的查询
  K = X @ Wk    形状：(n, dk)      每个标记的键
  V = X @ Wv    形状：(n, dv)      每个标记的值
```

可视化，对于一个标记：

```
             Wq
  x_i ------[*]------> q_i    "我在找什么？"
       |
       |     Wk
       +----[*]------> k_i    "我包含什么？"
       |
       |     Wv
       +----[*]------> v_i    "我提供什么？"
```

### 注意力矩阵

一旦你有了所有标记的 Q、K、V，注意力分数形成一个矩阵：

```
分数 = Q @ K^T    形状：(n, n)

              k1    k2    k3    k4    k5
        +-----+-----+-----+-----+-----+
   q1   | 2.1 | 0.3 | 0.1 | 0.8 | 0.2 |   <- q1 关注每个键的程度
        +-----+-----+-----+-----+-----+
   q2   | 0.4 | 1.9 | 0.7 | 0.1 | 0.3 |
        +-----+-----+-----+-----+-----+
   q3   | 0.2 | 0.6 | 2.3 | 0.5 | 0.1 |
        +-----+-----+-----+-----+-----+
   q4   | 0.9 | 0.1 | 0.4 | 1.7 | 0.6 |
        +-----+-----+-----+-----+-----+
   q5   | 0.1 | 0.3 | 0.2 | 0.5 | 2.0 |
        +-----+-----+-----+-----+-----+

每行：一个标记对整个序列的注意力
```

### 为什么需要缩放？

点积随维度 dk 增长。如果 dk = 64，点积可能在数十范围内，将 softmax 推入梯度消失的区域。修复：除以 sqrt(dk)。

```
缩放分数 = (Q @ K^T) / sqrt(dk)
```

这使值保持在 softmax 产生有用梯度的范围内。

### Softmax 将分数转化为权重

Softmax 将原始分数转换为每行的概率分布：

```
q1 的原始分数：   [2.1, 0.3, 0.1, 0.8, 0.2]
                            |
                         softmax
                            |
注意力权重：        [0.52, 0.09, 0.07, 0.14, 0.08]   （和约 1.0）
```

现在每个标记有一组权重表示关注每个其他标记的程度。

### 值的加权和

每个标记的最终输出是所有值向量的加权和：

```
output_i = sum( attention_weight[i][j] * v_j  for all j )

对于标记 1：
  output_1 = 0.52 * v1 + 0.09 * v2 + 0.07 * v3 + 0.14 * v4 + 0.08 * v5
```

### 完整流水线

```
                    +-------+
  X (输入)  ------->|  @ Wq  |-----> Q
                    +-------+
                    +-------+
  X (输入)  ------->|  @ Wk  |-----> K
                    +-------+                     +----------+
                    +-------+                     |          |
  X (输入)  ------->|  @ Wv  |-----> V ---------->| 加权     |----> 输出
                    +-------+          ^          |  求和     |
                                       |          +----------+
                              +--------+--------+
                              |    softmax      |
                              +---------+-------+
                                        ^
                              +---------+-------+
                              | Q @ K^T / sqrt  |
                              +-----------------+
```

一行公式：

```
Attention(Q, K, V) = softmax( Q @ K^T / sqrt(dk) ) @ V
```

## 构建

### 步骤 1：从零实现 Softmax

Softmax 将原始 logits 转换为概率。减去最大值以保证数值稳定性。

```python
import numpy as np

def softmax(x):
    shifted = x - np.max(x, axis=-1, keepdims=True)
    exp_x = np.exp(shifted)
    return exp_x / np.sum(exp_x, axis=-1, keepdims=True)

logits = np.array([2.0, 1.0, 0.1])
print(f"logits:  {logits}")
print(f"softmax: {softmax(logits)}")
print(f"sum:     {softmax(logits).sum():.4f}")
```

### 步骤 2：缩放点积注意力

核心函数。接受 Q、K、V 矩阵，返回注意力输出和权重矩阵。

```python
def scaled_dot_product_attention(Q, K, V):
    dk = Q.shape[-1]
    scores = Q @ K.T / np.sqrt(dk)
    weights = softmax(scores)
    output = weights @ V
    return output, weights
```

### 步骤 3：带学习投影的自注意力类

一个完整的自注意力模块，带有用类 Xavier 缩放初始化的 Wq、Wk、Wv 权重矩阵。

```python
class SelfAttention:
    def __init__(self, d_model, dk, dv, seed=42):
        rng = np.random.default_rng(seed)
        scale = np.sqrt(2.0 / (d_model + dk))
        self.Wq = rng.normal(0, scale, (d_model, dk))
        self.Wk = rng.normal(0, scale, (d_model, dk))
        scale_v = np.sqrt(2.0 / (d_model + dv))
        self.Wv = rng.normal(0, scale_v, (d_model, dv))
        self.dk = dk

    def forward(self, X):
        Q = X @ self.Wq
        K = X @ self.Wk
        V = X @ self.Wv
        output, weights = scaled_dot_product_attention(Q, K, V)
        return output, weights
```

### 步骤 4：在句子上运行

为一个句子创建假嵌入并观察注意力权重。

```python
sentence = ["The", "cat", "sat", "on", "the", "mat"]
n_tokens = len(sentence)
d_model = 8
dk = 4
dv = 4

rng = np.random.default_rng(42)
X = rng.normal(0, 1, (n_tokens, d_model))

attn = SelfAttention(d_model, dk, dv, seed=42)
output, weights = attn.forward(X)

print("注意力权重（每行：该标记关注哪里）：\n")
print(f"{'':>6}", end="")
for token in sentence:
    print(f"{token:>6}", end="")
print()

for i, token in enumerate(sentence):
    print(f"{token:>6}", end="")
    for j in range(n_tokens):
        w = weights[i][j]
        print(f"{w:6.3f}", end="")
```

### 步骤 5：因果（自回归）掩码

对于生成，标记 `i` 只能关注 `j ≤ i`（不看未来）。对分数矩阵应用三角形掩码：

```python
def causal_mask(scores):
    n = scores.shape[0]
    mask = np.tril(np.ones((n, n)))  # 下三角为 1
    return np.where(mask, scores, float('-inf'))
```

没有这个掩码，解码器会在第 6 课要求的生成期间作弊。

## 使用

在 PyTorch 中，一行代码版本：

```python
from torch.nn.functional import scaled_dot_product_attention
out = scaled_dot_product_attention(q, k, v, is_causal=True)
```

参数 `is_causal=True` 自动应用三角形掩码并分派 Flash Attention。

从 HuggingFace 模型可视化注意力权重：

```python
from transformers import AutoModel
import torch

model = AutoModel.from_pretrained("bert-base-uncased", output_attentions=True)
inputs = tokenizer("The cat sat on the mat.", return_tensors="pt")
with torch.no_grad():
    outputs = model(**inputs)
# outputs.attentions: 每层 [B, heads, N, N] 的元组
```

## 交付

见 `outputs/prompt-attention-explainer.md`。提示要求你将注意力权重转化为特定标记关系的英文非技术解释。

## 练习

1. **简单。** 在没有缩放因子的情况下运行 `scaled_dot_product_attention`（使用 `Q @ K.T` 而非 `Q @ K.T / sqrt(dk)`）。将 softmax 输出与缩放版本并排打印。看到饱和吗？
2. **中等。** 将因果掩码应用于你的自注意力，并验证 `output[i]` 只依赖于 `V[0..i]`。运行验证测试。
3. **困难。** 在单批次中对 10 个不同的 128 标记句子运行 `self.attention`。收集 `(n, n)` 权重矩阵，在层和头上平均。什么模式一致出现？

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| 自注意力 | "标记互相看" | 同一序列内的注意力。Q、K、V 来自相同的 X。 |
| 交叉注意力 | "解码器看编码器" | Q 来自解码器，K/V 来自编码器输出。连接两个序列。 |
| 缩放因子 | "那个 sqrt 东西" | `√dk` 防止大 dk 时 softmax 饱和。 |
| 因果掩码 | "不看未来" | 注意力分数上的三角形掩码；对自回归生成必需。 |
| 归纳头 | "上下文学习电路" | 两个头的组合：一个头看前一个标记，另一个头复制跟随的内容。 |
| 权重矩阵 | "谁关注谁" | 每行是每个标记对其他令牌的分布。 |

## 扩展阅读

- [Vaswani et al. (2017). Attention Is All You Need §3.2.1](https://arxiv.org/abs/1706.03762)——缩放点积注意力的两页。
- [Bahdanau, Cho, Bengio (2014). Neural MT by Jointly Learning to Align and Translate](https://arxiv.org/abs/1409.0473)——为 seq2seq RNN 发明注意力的论文。
- [NLP-Progress——注意力可视化](http://nlpprogress.com/english/machine_translation.html)——追踪自 2014 年以来的 SOTA 注意力使用情况。