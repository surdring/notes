# 完整 Transformer——编码器 + 解码器

> 注意力是明星。其他一切——残差、归一化、前馈、交叉注意力——是让你能堆深层的脚手架。

**类型：** 构建
**语言：** Python
**前置要求：** 第 7 阶段 · 02（自注意力），第 7 阶段 · 03（多头注意力），第 7 阶段 · 04（位置编码）
**时间：** 约 75 分钟

## 问题

单层注意力是特征提取器，不是模型。每层一次矩阵乘法对语言来说不够容量。你需要深度——而深度在没有正确管道的情况下会断裂。

2017 年 Vaswani 论文打包了六项设计决策，将一层注意力变成可堆叠的块。自那以后的每个 transformer——仅编码器（BERT）、仅解码器（GPT）、编码器-解码器（T5）——继承相同的骨架。2026 年块已被精炼（RMSNorm、SwiGLU、pre-norm、RoPE），但骨架是相同的。

本课是骨架。后续课程专门化它——06 用于编码器，07 用于解码器，08 用于编码器-解码器。

## 概念

![编码器和解码器块内部，连接](../assets/full-transformer.svg)

### 六个部分

1. **嵌入 + 位置信号。** 标记 → 向量。位置通过 RoPE（现代）或正弦（经典）注入。
2. **自注意力。** 每个位置关注每个其他位置。解码器中掩码。
3. **前馈网络（FFN）。** 逐位置两层 MLP：`W_2 · activation(W_1 · x)`。默认扩展比 4×。
4. **残差连接。** `x + sublayer(x)`。没有这个，梯度在大约 6 层后消失。
5. **层归一化。** `LayerNorm` 或 `RMSNorm`（现代）。稳定残差流。
6. **交叉注意力（仅解码器）。** 查询来自解码器，键和值来自编码器输出。

### 编码器块（BERT、T5 编码器使用）

```
x → LN → MHA(self) → + → LN → FFN → + → out
                     ^              ^
                     |              |
                     └── 残差 ──────┘
```

编码器是双向的。无掩码。所有位置看到所有位置。

### 解码器块（GPT、T5 解码器使用）

```
x → LN → MHA(masked self) → + → LN → MHA(cross to encoder) → + → LN → FFN → + → out
```

解码器每块有三个子层。中间那个——交叉注意力——是信息从编码器流向解码器的唯一地方。在纯仅解码器架构（GPT）中，交叉注意力被省略，你只有掩码自注意力 + FFN。

### Pre-norm vs post-norm

原始论文：`x + sublayer(LN(x))` vs `LN(x + sublayer(x))`。Post-norm 在 2019 年左右失宠——没有仔细的预热难以深度训练。Pre-norm（子层*之前*的 `LN`）是 2026 年默认：Llama、Qwen、GPT-3+、Mistral 都使用。

### 2026 现代化块

Vaswani 2017 发布 LayerNorm + ReLU。现代栈替换了两者。生产块实际的样子：

| 组件 | 2017 | 2026 |
|-----------|------|------|
| 归一化 | LayerNorm | RMSNorm |
| FFN 激活 | ReLU | SwiGLU |
| FFN 扩展 | 4× | 2.6×（SwiGLU 使用三个矩阵，总参数匹配） |
| 位置 | 正弦绝对 | RoPE |
| 注意力 | 完整 MHA | GQA（或 MLA） |
| 偏置项 | 是 | 否 |

RMSNorm 丢弃 LayerNorm 的均值中心化（少一次减法），节省计算且在经验上至少一样稳定。SwiGLU（`Swish(W1 x) ⊙ W3 x`）在 Llama、PaLM 和 Qwen 论文中持续比 ReLU/GELU FFN 好约 0.5 ppl。

### 参数量

对于一个 `d_model = d` 且 FFN 扩展 `r` 的块：

- MHA：`4 · d²`（Q、K、V、O 投影）
- FFN（SwiGLU）：`3 · d · (r · d)` ≈ `3rd²`
- 归一化：可忽略

在 `d = 4096, r = 2.6, layers = 32`（大约 Llama 3 8B），总计：`32 · (4·4096² + 3·2.6·4096²) ≈ 32 · (16 + 32) M = ~1.5B 参数每层 × 32 ≈ 7B`（加上嵌入和头）。匹配已发布计数。

## 构建

### 步骤 1：构建块

使用第 03 课的微型 `Matrix` 类（复制到此文件以保持独立）：

- `layer_norm(x, eps=1e-5)`——减去均值，除以标准差。
- `rms_norm(x, eps=1e-6)`——除以 RMS。无均值减法。
- `gelu(x)` 和 `silu(x) * W3 x`（SwiGLU）。
- `ffn_swiglu(x, W1, W2, W3)`。
- `encoder_block(x, params)` 和 `decoder_block(x, enc_out, params)`。

见 `code/main.py` 获取完整连接。

### 步骤 2：连接 2 层编码器和 2 层解码器

堆叠它们。将编码器输出传入每个解码器交叉注意力。在输出投影之前添加最终 LN。

```python
def encode(tokens, params):
    x = embed(tokens, params.emb) + sinusoidal(len(tokens), params.d)
    for block in params.encoder_blocks:
        x = encoder_block(x, block)
    return x

def decode(target_tokens, encoder_out, params):
    x = embed(target_tokens, params.emb) + sinusoidal(len(target_tokens), params.d)
    for block in params.decoder_blocks:
        x = decoder_block(x, encoder_out, block)
    return x
```

### 步骤 3：在玩具示例上运行前向

输入 6 标记源和 5 标记目标。验证输出形状为 `(5, vocab)`。无训练——本课关于架构，不是损失。

### 步骤 4：换成 RMSNorm + SwiGLU

用 RMSNorm 和 SwiGLU 替换 LayerNorm 和 ReLU-FFN。确认形状仍匹配。这是通过一次函数替换实现的 2026 现代化。

## 使用

PyTorch/TF 参考实现：`nn.TransformerEncoderLayer`、`nn.TransformerDecoderLayer`。但大多数 2026 生产代码自己写块，因为：

- Flash Attention 在注意力内部调用，而非通过 `nn.MultiheadAttention`。
- GQA / MLA 不在标准库参考中。
- RoPE、RMSNorm、SwiGLU 不是 PyTorch 默认。

HF `transformers` 有你应读的干净参考块：`modeling_llama.py` 是规范的 2026 仅解码器块。约 500 行，值得走读一次。

**编码器 vs 解码器 vs 编码器-解码器——何时选择：**

| 需求 | 选择 | 示例 |
|------|------|---------|
| 分类、嵌入、文本 QA | 仅编码器 | BERT、DeBERTa、ModernBERT |
| 文本生成、聊天、代码、推理 | 仅解码器 | GPT、Llama、Claude、Qwen |
| 结构化输入 → 结构化输出（翻译、摘要） | 编码器-解码器 | T5、BART、Whisper |

仅解码器赢了语言，因为它缩放最干净且处理理解和生成。编码器-解码器在输入有明确"源序列"身份时仍然最佳（翻译、语音识别、结构化任务）。

## 交付

见 `outputs/skill-transformer-block-reviewer.md`。该技能对照 2026 默认项审查新的 transformer 块实现，标记缺失部分（pre-norm、RoPE、RMSNorm、GQA、FFN 扩展比）。

## 练习

1. **简单。** 在 `d_model=512, n_heads=8, ffn_expansion=4, swiglu=True` 时计算 encoder_block 的参数。通过实现块并使用 `sum(p.numel() for p in block.parameters())` 验证。
2. **中等。** 从 post-norm 切换到 pre-norm。初始化两者并测量随机输入上 12 层堆叠后的激活范数。Post-norm 的激活应爆炸；pre-norm 应保持有界。
3. **困难。** 在玩具复制任务上实现 4 层编码器-解码器（复制 `x` 的反转）。训练 100 步。报告损失。换成 RMSNorm + SwiGLU + RoPE——损失下降吗？

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| 块 | "一个 transformer 层" | 归一化 + 注意力 + 归一化 + FFN 的堆叠，包裹在残差连接中。 |
| 残差 | "跳跃连接" | `x + f(x)` 输出；使梯度通过深层堆叠流动。 |
| Pre-norm | "之前而非之后归一化" | 现代：`x + sublayer(LN(x))`。无需预热体操即可深度训练。 |
| RMSNorm | "无均值的 LayerNorm" | 除以 RMS；少一次操作，相同经验稳定性。 |
| SwiGLU | "每个人切换到的 FFN" | `Swish(W1 x) ⊙ W3 x → W2`。在 LM ppl 上击败 ReLU/GELU。 |
| 交叉注意力 | "解码器如何看到编码器" | MHA，Q 来自解码器，K/V 来自编码器输出。 |
| FFN 扩展 | "中间 MLP 有多宽" | 隐藏大小与 d_model 的比率，通常 4（LayerNorm）或 2.6（SwiGLU）。 |
| 无偏置 | "丢弃 +b 项" | 现代栈在线性层中省略偏置；轻微 ppl 改进，更小模型。 |

## 扩展阅读

- [Vaswani et al. (2017). Attention Is All You Need](https://arxiv.org/abs/1706.03762)——原始块规格。
- [Xiong et al. (2020). On Layer Normalization in the Transformer Architecture](https://arxiv.org/abs/2002.04745)——为什么 pre-norm 在深层击败 post-norm。
- [Zhang, Sennrich (2019). Root Mean Square Layer Normalization](https://arxiv.org/abs/1910.07467)——RMSNorm。
- [Shazeer (2020). GLU Variants Improve Transformer](https://arxiv.org/abs/2002.05202)——SwiGLU 论文。
- [HuggingFace `modeling_llama.py`](https://github.com/huggingface/transformers/blob/main/src/transformers/models/llama/modeling_llama.py)——规范 2026 仅解码器块。