# 从零构建 Transformer——最终项目

> 十三课。一个模型。没有捷径。

**类型：** 构建
**语言：** Python
**前置要求：** 第 7 阶段 · 01 到 13。不要跳过。
**时间：** 约 120 分钟

## 问题

你已经读了每一篇论文。你已经实现了注意力、多头分割、位置编码、编码器和解码器块、BERT 和 GPT 损失、MoE、KV 缓存。现在让它们在一个真实任务上一起工作。

最终项目：在字符级语言建模任务上端到端训练一个小型仅解码器 transformer。它读莎士比亚。它生成新的莎士比亚。它小到可以在笔记本上 10 分钟内训练。它足够正确，换入更大的数据集和更长的训练就能得到一个真实的 LM。

这是课程中的"nanoGPT"。它不是原创——Karpathy 的 2023 nanoGPT 教程是每个学生至少写一次的参考实现。我们沿袭其形态并根据我们所涵盖的内容重新装备它。

## 概念

![从零构建 Transformer 框图](../assets/capstone.svg)

架构注释：

```
输入标记（B, N）
   │
   ▼
标记嵌入 + 位置嵌入                         ◀── 第 4 课（RoPE 选项）
   │
   ▼
┌──── 块 × L ─────────────────────────┐
│  RMSNorm                             │  ◀── 第 5 课
│  多头注意力（因果）                    │  ◀── 第 3 课 + 第 7 课（因果掩码）
│  残差                                │
│  RMSNorm                             │
│  SwiGLU FFN                          │  ◀── 第 5 课
│  残差                                │
└─────────────────────────────────────┘
   │
   ▼
最终 RMSNorm
   │
   ▼
lm_head（与标记嵌入绑定）
   │
   ▼
logits（B, N, V）
   │
   ▼
偏移-1 交叉熵                            ◀── 第 7 课
```

### 我们完成的内容

- `GPTConfig`——一个配置所有超参数的地方。
- `MultiHeadAttention`——因果、批处理、带可选 Flash 风格路径（PyTorch 的 `scaled_dot_product_attention`）。
- `SwiGLUFFN`——现代 FFN。
- `Block`——预归一化、残差包裹的注意力 + FFN。
- `GPT`——嵌入、堆叠块、LM 头、generate()。
- 训练循环，带 AdamW、余弦 LR、梯度裁剪。
- 莎士比亚文本上的字符级分词器。

### 我们不完成的内容

- RoPE——第 4 课中概念性实现。这里我们为简单使用可学习位置嵌入。练习要求你换入 RoPE。
- 生成时的 KV 缓存——每个生成步在整个前缀上重新计算注意力。更慢但更简单。练习要求你添加 KV 缓存。
- Flash Attention——PyTorch 2.0+ 在输入匹配时自动分发；我们使用 `F.scaled_dot_product_attention`。
- MoE——每块单个 FFN。你在第 11 课看到了 MoE。

### 目标指标

在 Mac M2 笔记本上，在 `tinyshakespeare.txt` 上训练 4 层、4 头、d_model=128 的 GPT 2,000 步：

- 训练损失从约 4.2（随机）收敛到约 1.5，约 6 分钟。
- 采样输出看起来莎士比亚化：古词、换行、像"ROMEO:"的专有名词涌现。
- 验证损失（保留最后 10% 文本）紧密跟踪训练损失；在此大小/预算下无过拟合。

## 构建

本课使用 PyTorch。安装 `torch`（CPU 版本即可）。见 `code/main.py`。脚本处理：

- 下载 `tinyshakespeare.txt`（如果缺失）或读取本地副本。
- 字节级字符分词器。
- 90/10 训练/验证分割。
- 在支持的硬件上使用 bf16 autocast 的训练循环。
- 训练完成后采样。

### 步骤 1：数据

```python
text = open("tinyshakespeare.txt").read()
chars = sorted(set(text))
stoi = {c: i for i, c in enumerate(chars)}
itos = {i: c for c, i in stoi.items()}
encode = lambda s: [stoi[c] for c in s]
decode = lambda xs: "".join(itos[x] for x in xs)
```

65 个唯一字符。微型词汇。适合 4 字节 vocab_size。无 BPE，无分词器闹剧。

### 步骤 2：模型

见 `code/main.py`。块是第 5 课的教科书——预归一化、RMSNorm、SwiGLU、因果 MHA。4/4/128 的参数计数：约 800K。

### 步骤 3：训练循环

获取一批长度 256 的随机标记窗口。前向传播。偏移-1 交叉熵。反向传播。AdamW 步。记录。重复。

```python
for step in range(max_steps):
    x, y = get_batch("train")
    logits = model(x)
    loss = F.cross_entropy(logits.view(-1, vocab_size), y.view(-1))
    loss.backward()
    torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
    opt.step()
    opt.zero_grad()
```

### 步骤 4：采样

给定提示，重复前向传播，从 top-p logits 采样，追加，继续。500 标记后停止。

### 步骤 5：读取输出

2,000 步后：

```
ROMEO:
Away and mild will not thy friend, that thou shalt wit:
The chief that well shame and hath been his friends,
...
```

不是莎士比亚。但是莎士比亚化的。对于约 800K 参数和笔记本上 6 分钟来说是一次明确的胜利。

## 使用

这个最终项目是一个参考架构。三项扩展使其成为真实的东西：

1. **交换分词器。** 使用 BPE（例如 `tiktoken.get_encoding("cl100k_base")`）。词汇大小从 65 跳到约 50,000。模型容量需要相应放大。
2. **在更大语料上训练。** 使用 `OpenWebText` 或 `fineweb-edu`（HuggingFace）。在单个 A100 上为 125M 参数 GPT 训练 10B 标记需要约 24 小时。
3. **添加 RoPE + KV 缓存 + Flash Attention。** 下面的练习逐步引导你完成。

最终得到一个生成流畅英语的 125M 参数 GPT。不是前沿模型。但相同的代码路径——只是更大——正是 Karpathy、EleutherAI 和 Allen Institute 在 2026 年用来训练研究检查点的。

## 交付

见 `outputs/skill-transformer-review.md`。该技能审查从零构建的 transformer 实现在整个 13 课中的正确性。

## 练习

1. **简单。** 运行 `code/main.py`。验证你训练模型的最终步验证损失低于 2.0。将 `max_steps` 从 2,000 改为 5,000——验证损失继续改进吗？
2. **中等。** 用 RoPE 替换可学习位置嵌入。在 `MultiHeadAttention` 内对 Q 和 K 应用旋转。训练并验证损失至少一样低。
3. **中等。** 在采样循环中实现 KV 缓存。分别在有缓存和无缓存的情况下生成 500 个标记。笔记本上的墙钟应提高 5-20×。
4. **困难。** 为模型添加第二个头，预测下一个加一个标记（MTP——DeepSeek-V3 的多标记预测）。联合训练。有帮助吗？
5. **困难。** 将每块单个 FFN 替换为 4 专家 MoE。路由器 + top-2 路由。看在匹配活跃参数下验证损失如何变化。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|-----------------------|
| nanoGPT | "Karpathy 的教程仓库" | 最小仅解码器 transformer 训练代码，约 300 行；规范参考。 |
| tinyshakespeare | "标准玩具语料" | 约 1.1 MB 文本；自 2015 年以来每个字符 LM 教程都使用它。 |
| 绑定嵌入 | "共享输入/输出矩阵" | LM 头权重 = 标记嵌入矩阵的转置；节省参数，提高质量。 |
| bf16 autocast | "训练精度技巧" | 在 bf16 中运行前向/反向，在 fp32 中保持优化器状态；自 2021 年以来的标准。 |
| 梯度裁剪 | "阻止尖峰" | 将全局梯度范数上限设为 1.0；防止训练爆炸。 |
| 余弦 LR 调度 | "2020+ 默认" | LR 线性上升（预热）然后余弦形衰减到峰值的 10%。 |
| MFU | "模型 FLOP 利用率" | 实现的 FLOPs / 理论峰值；2026 年密集 40%、MoE 30% 是强劲的。 |
| 验证损失 | "留出损失" | 模型从未见过的数据上的交叉熵；过拟合检测器。 |

## 扩展阅读

- [The Annotated Transformer（Harvard NLP）](https://nlp.seas.harvard.edu/annotated-transformer/)——经典注释实现。