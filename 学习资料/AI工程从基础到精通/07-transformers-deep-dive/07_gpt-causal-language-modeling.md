# GPT——因果语言建模

> BERT 看两边。GPT 只看过去。三角形掩码是现代 AI 中最重要的单行代码。

**类型：** 构建
**语言：** Python
**前置要求：** 第 7 阶段 · 02（自注意力），第 7 阶段 · 05（完整 Transformer），第 7 阶段 · 06（BERT）
**时间：** 约 75 分钟

## 问题

语言模型回答一个问题：给定前 `t-1` 个标记，标记 `t` 的概率分布是什么？在这个信号——下一个标记预测——上训练，你得到一个可以一次一个标记生成任意文本的模型。

要在整个序列上端到端并行训练它，你需要每个位置的预测仅依赖更早的位置。否则模型通过看答案轻易作弊。

因果掩码做到这一点。它是一个上三角 `-inf` 值矩阵，在 softmax 之前加到注意力分数上。softmax 后，那些位置变成 0。每个位置只能关注自己和更早的位置。因为你对整个序列应用一次，你获得一次前向传播中的 N 个并行下一个标记预测。

GPT-1（2018）、GPT-2（2019）、GPT-3（2020）、GPT-4（2023）、GPT-5（2024）、Claude、Llama、Qwen、Mistral、DeepSeek、Kimi——它们都是具有相同核心循环的仅解码器因果 transformer。只是更大、更好的数据和更好的 RLHF。

## 概念

![因果掩码创建三角形注意力矩阵](../assets/causal-attention.svg)

### 掩码

给定长度 `N` 的序列，构建 `N × N` 矩阵：

```
M[i, j] = 0       如果 j <= i
M[i, j] = -inf    如果 j > i
```

在 softmax 之前将 `M` 加到原始注意力分数上。`exp(-inf) = 0`，所以掩码位置贡献零权重。注意力矩阵的每一行是仅对之前位置的概率分布。

实现成本：一次 `torch.tril()` 调用。计算时间：纳秒。对领域的影响：一切。

### 并行训练，串行推理

训练：前向传播整个 `(N, d_model)` 序列一次，计算 N 个交叉熵损失（每位置一个），求和，反向传播。沿序列并行。这就是 GPT 训练可缩放的原因——你在一次 GPU 传播中处理批次中的 100 万标记。

推理：你逐标记生成。输入 `[t1, t2, t3]`，得到 `t4`。输入 `[t1, t2, t3, t4]`，得到 `t5`。输入 `[t1, t2, t3, t4, t5]`，得到 `t6`。KV 缓存（第 12 课）保存 `t1…tn` 的隐藏状态，因此你不必每步重新计算它们。但推理时的串行深度 = 输出长度。这是自回归税，也是为什么解码是每个 LLM 的延迟瓶颈。

### 损失——偏移 1

给定标记 `[t1, t2, t3, t4]`：

- 输入：`[t1, t2, t3]`
- 目标：`[t2, t3, t4]`

对于每个位置 `i`，计算 `-log P(target_i | inputs[:i+1])`。求和。这是整个序列的交叉熵。

你听说过的每个 transformer 语言模型都在这损失上训练。预训练、微调、SFT——相同损失，不同数据。

### 解码策略

训练后，采样选择比人们想的更重要。

| 方法 | 做什么 | 何时使用 |
|--------|--------------|-------------|
| 贪心 | 每步 argmax | 确定性任务、代码补全 |
| 温度 | logits 除以 T，采样 | 创造性任务，更高 T = 更多多样性 |
| Top-k | 仅从 top-k 标记采样 | 杀死低概率尾部 |
| Top-p（核采样） | 从累积概率 ≥ p 的最小集合采样 | 2020+ 默认；适应分布形状 |
| Min-p | 保持 `p > min_p * max_p` 的标记 | 2024+；比 top-p 更好地拒绝长尾 |
| 推测解码 | 草稿模型提出 N 个标记，大模型验证 | 相同质量 2-3× 延迟减少 |

2026 年，min-p + temperature 0.7 是开源模型合理的默认。推测解码是任何生产推理栈的基本要求。

### 是什么让"GPT 配方"有效

1. **仅解码器。** 无编码器开销。每层一次注意力 + FFN。
2. **缩放。** 124M → 1.5B → 175B → 万亿。Chinchilla 缩放法则（第 13 课）告诉你如何花费计算。
3. **上下文学习。** 约在 6B-13B 涌现。模型可以跟随少样本示例而无需微调。
4. **RLHF。** 人类偏好的后训练将原始预训练文本转为聊天助手。
5. **Pre-norm + RoPE + SwiGLU。** 规模下稳定训练。

自 GPT-2 以来核心架构没有太大变化。所有有趣的事情发生在数据、规模和后训练中。

## 构建

### 步骤 1：因果掩码

见 `code/main.py`。一行代码：

```python
def causal_mask(n):
    return [[0.0 if j <= i else float("-inf") for j in range(n)] for i in range(n)]
```

在 softmax 之前加到注意力分数上。这就是整个机制。

### 步骤 2：2 层类 GPT 模型

堆叠两个解码器块（掩码自注意力 + FFN，无交叉注意力）。添加标记嵌入、位置编码和反嵌入（与标记嵌入矩阵绑定——自 GPT-2 以来的标准技巧）。

### 步骤 3：端到端下一个标记预测

在 20 标记玩具词汇上，在每个位置产生 logits。以偏移-1 目标计算交叉熵损失。无梯度——这是前向传播合理性检查。

### 步骤 4：采样

实现贪心、温度、top-k、top-p、min-p。在固定提示上运行每个并比较输出。采样函数就是 10 行代码。

## 使用

PyTorch，2026 惯用语：

```python
from transformers import AutoModelForCausalLM, AutoTokenizer
model = AutoModelForCausalLM.from_pretrained("meta-llama/Llama-3.2-3B-Instruct")
tok = AutoTokenizer.from_pretrained("meta-llama/Llama-3.2-3B-Instruct")

prompt = "Attention is all you need because"
inputs = tok(prompt, return_tensors="pt")
out = model.generate(
    **inputs,
    max_new_tokens=64,
    temperature=0.7,
    top_p=0.9,
    do_sample=True,
)
print(tok.decode(out[0]))
```

底层，`generate()` 运行前向传播，拉取最后位置 logits，采样下一个标记，追加它，重复。每个生产 LLM 推理栈（vLLM、TensorRT-LLM、llama.cpp、Ollama、MLX）实现相同的循环，带重优化——批量预填充、连续批处理、KV 缓存分页、推测解码。

**GPT vs BERT，各一行：** GPT 预测 `P(x_t | x_{<t})`。BERT 预测 `P(x_masked | x_unmasked)`。损失决定模型是否可以生成。

## 交付

见 `outputs/skill-sampling-tuner.md`。该技能为新的生成任务选择采样参数，并在需要确定性解码时标记。

## 练习

1. **简单。** 运行 `code/main.py` 并验证因果注意力矩阵在 softmax 后是下三角。抽查：第 3 行应只在列 0-3 有权重。
2. **中等。** 为宽度 4 实现束搜索。比较 10 个短提示上束搜索-4 vs 贪心的困惑度。束搜索总是赢吗？（提示：通常用于翻译，不用于开放式聊天。）
3. **困难。** 实现推测解码：使用微型 2 层模型作为草稿，6 层模型作为验证器。在 100 个长度 64 的补全上测量墙钟速度。确认输出匹配验证器的贪心。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| 因果掩码 | "三角形" | 上三角 `-inf` 矩阵加到注意力分数上，使位置 `i` 只能看到位置 `≤ i`。 |
| 下一个标记预测 | "损失" | 模型分布与每个位置真实下一个标记的交叉熵。 |
| 自回归 | "一次生成一个" | 将输出作为输入反馈；仅在训练时并行，生成时不并行。 |
| Logits | "softmax 前分数" | softmax 前 LM 头的原始输出；采样发生在这些上。 |
| 温度 | "创造性旋钮" | logits 除以 T；T→0 = 贪心，T→∞ = 均匀。 |
| Top-p | "核采样" | 截断分布到总和 ≥ p 的最小集合；从剩余的采样。 |
| Min-p | "比 top-p 更好" | 保持 `p ≥ min_p × max_p` 的标记；根据分布锐度自适应截止。 |
| 推测解码 | "草稿 + 验证" | 廉价模型提出 N 个标记；大模型并行验证。 |
| 教师强制 | "训练技巧" | 训练时，输入真实的前一个标记，而非模型预测。每个 seq2seq LM 的标准。 |

## 扩展阅读

- [Radford et al. (2018). Improving Language Understanding by Generative Pre-Training](https://cdn.openai.com/research-covers/language-unsupervised/language_understanding_paper.pdf)——GPT-1。
- [Radford et al. (2019). Language Models are Unsupervised Multitask Learners](https://cdn.openai.com/better-language-models/language_models_are_unsupervised_multitask_learners.pdf)——GPT-2。
- [Brown et al. (2020). Language Models are Few-Shot Learners](https://arxiv.org/abs/2005.14165)——GPT-3 和上下文学习。
- [Leviathan, Kalman, Matias (2023). Fast Inference from Transformers via Speculative Decoding](https://arxiv.org/abs/2211.17192)——推测解码论文。
- [HuggingFace `modeling_llama.py`](https://github.com/huggingface/transformers/blob/main/src/transformers/models/llama/modeling_llama.py)——规范因果 LM 参考代码。