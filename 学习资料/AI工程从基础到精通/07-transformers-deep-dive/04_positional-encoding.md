# 位置编码——Sinusoidal、RoPE、ALiBi

> 注意力是置换不变的。"The cat sat on the mat"和"mat the on sat cat the"在没有位置信号的情况下产生相同输出。三种算法修复它——每种对"位置"的含义有不同的押注。

**类型：** 构建
**语言：** Python
**前置要求：** 第 7 阶段 · 02（自注意力），第 7 阶段 · 03（多头注意力）
**时间：** 约 45 分钟

## 问题

缩放点积注意力是顺序盲的。注意力矩阵 `softmax(Q K^T / √d) V` 从成对相似度计算。打乱 `X` 的行，输出的行以相同方式打乱。注意力内部没有任何东西关心位置。

这在词袋模型中不是 bug。对于语言、代码、音频、视频——顺序携带意义的任何事情——这是致命的。

修复是以某种方式将位置注入嵌入。三个时代的答案：

1. **绝对正弦**（Vaswani 2017）。将位置的 `sin/cos` 加到嵌入上。简单，免费，无需学习，在训练好的长度之外外推差。
2. **RoPE——旋转位置嵌入**（Su 2021）。通过与位置成正比的角旋转 Q 和 K 向量。在点积中直接编码*相对*位置。2026 年主导。
3. **ALiBi——带线性偏置的注意力**（Press 2022）。完全跳过嵌入；根据距离对注意力分数添加每头线性惩罚。优秀的长距离外推。

截至 2026 年，基本上每个前沿开源模型都使用 RoPE：Llama 2/3/4、Qwen 2/3、Mistral、Mixtral、DeepSeek-V3、Kimi。少数长上下文模型使用 ALiBi 或其现代变体。绝对正弦是历史。

## 概念

![正弦绝对 vs RoPE 旋转 vs ALiBi 距离偏置](../assets/positional-encoding.svg)

### 绝对正弦

预计算形状 `(max_len, d_model)` 的固定矩阵 `PE`：

```
PE[pos, 2i]   = sin(pos / 10000^(2i / d_model))
PE[pos, 2i+1] = cos(pos / 10000^(2i / d_model))
```

然后注意力之前 `X' = X + PE[:N]`。每个维度是不同频率的正弦波。模型学习从相位模式读取位置。超过 `max_len` 失败：没有任何东西告诉模型位置 2048 发生什么，当它只看到位置 0-2047 时。

### RoPE

旋转 Q 和 K 向量（不是嵌入）。对于一对维度 `(2i, 2i+1)`：

```
[q'_2i    ]   [ cos(pos·θ_i)  -sin(pos·θ_i) ] [q_2i   ]
[q'_2i+1  ] = [ sin(pos·θ_i)   cos(pos·θ_i) ] [q_2i+1 ]

θ_i = base^(-2i / d_head),  base = 默认 10000
```

对具有位置 `pos_k` 的键应用相同旋转。点积 `q'_m · k'_n` 变成单独 `(m - n)` 的函数。即：**注意力分数仅依赖相对距离**，即使旋转是基于绝对位置的。美妙技巧。

扩展 RoPE：`base` 可以缩放（NTK-aware、YaRN、LongRoPE）以在不重新训练的情况下外推到更长上下文。Llama 3 以这种方式从 8K 扩展到 128K 上下文。

### ALiBi

跳过嵌入技巧。直接偏置注意力分数：

```
attn_score[i, j] = (q_i · k_j) / √d  -  m_h · |i - j|
```

其中 `m_h` 是头特定的斜率（如 `1 / 2^(8·h/H)`）。更近的标记获得提升；远的标记获得惩罚。无训练时间成本。论文显示长度外推在其原始训练长度上优于正弦并匹配 RoPE。

### 2026 年选什么

| 变体 | 外推能力 | 训练成本 | 使用者 |
|---------|---------------|---------------|---------|
| 绝对正弦 | 差 | 免费 | 原始 transformer、早期 BERT |
| 学习型绝对 | 无 | 微小 | GPT-2、GPT-3 |
| RoPE | 有缩放则好 | 免费 | Llama 2/3/4、Qwen 2/3、Mistral、DeepSeek-V3、Kimi |
| RoPE + YaRN | 优秀 | 微调阶段 | Qwen2-1M、Llama 3.1 128K |
| ALiBi | 优秀 | 免费 | BLOOM、MPT、Baichuan |

RoPE 赢了因为它在不改变架构的情况下嵌入注意力、编码相对位置，其 `base` 超参数为长上下文微调提供了清晰的旋钮。

## 构建

### 步骤 1：正弦编码

见 `code/main.py`。4 行计算：

```python
def sinusoidal(N, d):
    pe = [[0.0] * d for _ in range(N)]
    for pos in range(N):
        for i in range(d // 2):
            theta = pos / (10000 ** (2 * i / d))
            pe[pos][2 * i]     = math.sin(theta)
            pe[pos][2 * i + 1] = math.cos(theta)
    return pe
```

在第一个注意力层之前将其加到嵌入矩阵上。

### 步骤 2：应用于 Q、K 的 RoPE

RoPE 在原地对 Q 和 K 操作。对于每对维度：

```python
def apply_rope(x, pos, base=10000):
    d = len(x)
    out = list(x)
    for i in range(d // 2):
        theta = pos / (base ** (2 * i / d))
        c, s = math.cos(theta), math.sin(theta)
        a, b = x[2 * i], x[2 * i + 1]
        out[2 * i]     = a * c - b * s
        out[2 * i + 1] = a * s + b * c
    return out
```

关键：在位置 `m` 对 Q 和位置 `n` 对 K 应用相同函数。它们的点积在每对坐标上获取 `cos((m-n)·θ_i)` 因子。注意力免费学习相对位置。

### 步骤 3：ALiBi 斜率和偏置

```python
def alibi_bias(n_heads, seq_len):
    # slope_h = 2 ** (-8 * h / n_heads) for h = 1..n_heads
    slopes = [2 ** (-8 * (h + 1) / n_heads) for h in range(n_heads)]
    bias = []
    for m in slopes:
        row = [[-m * abs(i - j) for j in range(seq_len)] for i in range(seq_len)]
        bias.append(row)
    return bias  # 加到注意力分数上，在 softmax 之前
```

在 softmax 之前将 `bias[h]` 加到头 `h` 的 `(seq_len, seq_len)` 注意力分数矩阵上。

### 步骤 4：验证 RoPE 的相对距离性质

选择两个随机向量 `a, b`。按 `(pos_a, pos_b)` 旋转。然后按 `(pos_a + k, pos_b + k)` 旋转。两个点积必须在浮点误差内匹配。这个性质是 RoPE 的全部意义——它对绝对偏移不变，只有相对差距重要。

## 使用

PyTorch 2.5+ 在 `torch.nn.functional` 中自带 RoPE 工具。大多数生产代码使用 `flash_attn` 或 `xformers`，其中 RoPE 在注意力内核内应用。

```python
from transformers import AutoModel
model = AutoModel.from_pretrained("meta-llama/Llama-3.2-3B")
# model.config.rope_scaling → {"type": "yarn", "factor": 32.0, "original_max_position_embeddings": 8192}
```

**2026 年长上下文技巧：**

- **NTK-aware 插值。** 从 4K 扩展到 16K+ 时，将 `base` 重新缩放到 `base * (scale_factor)^(d/(d-2))`。
- **YaRN。** 更智能的插值，在长上下文上保留注意力熵。Llama 3.1 128K 使用。
- **LongRoPE。** 微软 2024 方法，使用进化搜索选择每维度缩放因子。Phi-3-Long 使用。
- **位置插值 + 微调。** 按扩展因子缩小位置并微调 1-5B 标记。出奇有效。

## 交付

见 `outputs/skill-positional-encoding-picker.md`。该技能给定目标上下文长度、外推需求和训练预算，为新模型选择编码策略。

## 练习

1. **简单。** 将正弦 `PE` 矩阵绘制为 `max_len=512, d=128` 的热力图。确认"条纹随维度索引增长变宽"的模式。
2. **中等。** 实现 NTK-aware RoPE 缩放。在长度 256 的序列上训练一个微型语言模型，然后在长度 1024 上测试有缩放和无缩放。测量困惑度。
3. **困难。** 在同一注意力模块中实现 ALiBi 和 RoPE。在长度 512 的复制任务上训练 4 层 transformer。在测试时外推到 2048。比较退化。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| 位置编码 | "告诉注意力顺序" | 添加到嵌入或注意力中编码位置的任何信号。 |
| 正弦 | "原始那个" | 几何频率的 `sin/cos` 添加到嵌入；不外推。 |
| RoPE | "旋转嵌入" | 用位置相关角度旋转 Q、K；点积编码相对距离。 |
| ALiBi | "线性偏置技巧" | 对注意力分数添加 `-m·|i-j|`；不需要嵌入，优秀外推。 |
| base | "RoPE 的旋钮" | RoPE 中的频率缩放器；增加以在推理时扩展上下文。 |
| NTK-aware | "RoPE 缩放技巧" | 重新缩放 `base` 使高频维度在上下文扩展时不被挤压。 |
| YaRN | "花哨的那个" | 保留注意力熵的每维度插值+外推。 |
| 外推 | "在训练长度之外有效" | 位置方案能否在训练中看到的 `max_len` 之外提供正确输出？ |

## 扩展阅读

- [Vaswani et al. (2017). Attention Is All You Need §3.5](https://arxiv.org/abs/1706.03762)——原始正弦。
- [Su et al. (2021). RoFormer: Enhanced Transformer with Rotary Position Embedding](https://arxiv.org/abs/2104.09864)——RoPE 论文。
- [Press, Smith, Lewis (2021). Train Short, Test Long: Attention with Linear Biases Enables Input Length Extrapolation](https://arxiv.org/abs/2108.12409)——ALiBi。
- [Peng et al. (2023). YaRN: Efficient Context Window Extension of Large Language Models](https://arxiv.org/abs/2309.00071)——最先进 RoPE 缩放。
- [Chen et al. (2023). Extending Context Window of Large Language Models via Positional Interpolation](https://arxiv.org/abs/2306.15595)——Meta 的 Llama 2 长上下文论文。
- [Ding et al. (2024). LongRoPE: Extending LLM Context Window Beyond 2 Million Tokens](https://arxiv.org/abs/2402.13753)——微软方法，被 Phi-3-Long 使用。
- [HuggingFace Transformers — `modeling_rope_utils.py`](https://github.com/huggingface/transformers/blob/main/src/transformers/modeling_rope_utils.py)——每种 RoPE 缩放方案的生产级实现（default、linear、dynamic、YaRN、LongRoPE、Llama-3）。