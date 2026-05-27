# 序列到序列模型

> 两个 RNN 假装自己是翻译器。它们遇到的瓶颈正是注意力机制存在的原因。

**类型：** 构建
**语言：** Python
**前置要求：** 第 5 阶段 · 08（文本 CNN + RNN），第 3 阶段 · 11（PyTorch 入门）
**时间：** 约 75 分钟

## 问题

分类任务将变长序列映射到单个标签。翻译任务将变长序列映射到另一个变长序列。输入和输出属于不同的词汇表，可能是不同的语言，长度没有任何对等保证。

seq2seq 架构（Sutskever, Vinyals, Le, 2014）用一个刻意简单的配方破解了这个问题。两个 RNN。一个读取源句子并产生一个固定大小的上下文向量。另一个读取该向量并逐标记生成目标句子。就是你为第 08 课写的代码，以不同的方式粘合在一起。

这值得学习，有两个原因。首先，上下文向量瓶颈是 NLP 中最具教学价值的失败案例。它驱动了注意力和 Transformer 擅长的一切。其次，训练配方（教师强制、计划采样、推理时的束搜索）仍然适用于包括 LLM 在内的每一个现代生成系统。

## 概念

**编码器。** 一个读取源句子的 RNN。其最终隐藏状态是**上下文向量**——整个输入的固定大小摘要。据说不会丢失任何信息，只丢失源语言。

**解码器。** 另一个从上下文向量初始化的 RNN。每一步，它接收上一个生成的标记作为输入，并产生目标词汇表上的分布。采样或 argmax 选择下一个标记。将其反馈回去。重复，直到生成 `<EOS>` 标记或达到最大长度。

**训练：** 每个解码器步骤的交叉熵损失，在序列上求和。通过两个网络进行标准的时序反向传播。

**教师强制。** 在训练期间，解码器在步骤 `t` 的输入是位置 `t-1` 的*真实*标记，而不是解码器自己之前的预测。这稳定了训练；没有它，早期的错误会级联放大，模型永远无法学到正确的结果。在推理时，你必须使用模型自己的预测，因此总存在训练/推理分布差距。这个差距被称为**曝光偏差**。

**瓶颈。** 编码器学到的关于源语言的一切都必须压缩到那一个上下文向量中。长句子丢失细节。罕见词变得模糊。重排序（chat noir vs. black cat）必须被记忆，而不是被计算。

注意力（第 10 课）通过让解码器查看*每一个*编码器隐藏状态（而不仅仅是最后一个）来解决这个问题。这就是全部要义。

## 构建

### 步骤 1：编码器

```python
import torch
import torch.nn as nn


class Encoder(nn.Module):
    def __init__(self, src_vocab_size, embed_dim, hidden_dim):
        super().__init__()
        self.embed = nn.Embedding(src_vocab_size, embed_dim, padding_idx=0)
        self.gru = nn.GRU(embed_dim, hidden_dim, batch_first=True)

    def forward(self, src):
        e = self.embed(src)
        outputs, hidden = self.gru(e)
        return outputs, hidden
```

`outputs` 形状为 `[batch, seq_len, hidden_dim]`——每个输入位置一个隐藏状态。`hidden` 形状为 `[1, batch, hidden_dim]`——最后一步。第 08 课说"在 outputs 上池化用于分类。"这里我们保留最后一个隐藏状态作为上下文向量，忽略每个步骤的输出。

### 步骤 2：解码器

```python
class Decoder(nn.Module):
    def __init__(self, tgt_vocab_size, embed_dim, hidden_dim):
        super().__init__()
        self.embed = nn.Embedding(tgt_vocab_size, embed_dim, padding_idx=0)
        self.gru = nn.GRU(embed_dim, hidden_dim, batch_first=True)
        self.fc = nn.Linear(hidden_dim, tgt_vocab_size)

    def forward(self, token, hidden):
        e = self.embed(token)
        out, hidden = self.gru(e, hidden)
        logits = self.fc(out)
        return logits, hidden
```

解码器每次被调用一步。输入：一批单个标记和当前隐藏状态。输出：下一个标记的词汇表 logits 和更新后的隐藏状态。

### 步骤 3：带教师强制的训练循环

```python
def train_batch(encoder, decoder, src, tgt, bos_id, optimizer, teacher_forcing_ratio=0.9):
    optimizer.zero_grad()
    _, hidden = encoder(src)
    batch_size, tgt_len = tgt.shape
    input_token = torch.full((batch_size, 1), bos_id, dtype=torch.long)
    loss = 0.0
    loss_fn = nn.CrossEntropyLoss(ignore_index=0)

    for t in range(tgt_len):
        logits, hidden = decoder(input_token, hidden)
        step_loss = loss_fn(logits.squeeze(1), tgt[:, t])
        loss += step_loss
        use_teacher = torch.rand(1).item() < teacher_forcing_ratio
        if use_teacher:
            input_token = tgt[:, t].unsqueeze(1)
        else:
            input_token = logits.argmax(dim=-1)

    loss.backward()
    optimizer.step()
    return loss.item() / tgt_len
```

两个值得命名的旋钮。`ignore_index=0` 跳过填充标记上的损失。`teacher_forcing_ratio` 是每一步使用真实标记而非模型预测的概率。从 1.0（完全教师强制）开始，在训练过程中退火到约 0.5 来缩小曝光偏差差距。

### 步骤 4：推理循环（贪心）

```python
@torch.no_grad()
def greedy_decode(encoder, decoder, src, bos_id, eos_id, max_len=50):
    _, hidden = encoder(src)
    batch_size = src.shape[0]
    input_token = torch.full((batch_size, 1), bos_id, dtype=torch.long)
    output_ids = []
    for _ in range(max_len):
        logits, hidden = decoder(input_token, hidden)
        next_token = logits.argmax(dim=-1)
        output_ids.append(next_token)
        input_token = next_token
        if (next_token == eos_id).all():
            break
    return torch.cat(output_ids, dim=1)
```

贪心解码每一步选择最高概率的标记。它可能走偏：一旦你选择了一个标记，就无法撤回。**束搜索**在每一步保留 top-`k` 个部分序列，最后选择得分最高的完整序列。束宽 3-5 是标准配置。

### 步骤 5：瓶颈演示

在玩具复制任务上训练模型：源 `[a, b, c, d, e]`，目标 `[a, b, c, d, e]`。增加序列长度。观察准确率。

```
seq_len=5   复制准确率：98%
seq_len=10  复制准确率：91%
seq_len=20  复制准确率：62%
seq_len=40  复制准确率：23%
```

单个 GRU 隐藏状态无法无损地记住一个 40 个标记的输入。信息在编码器的每一步都存在，但解码器只能看到最后的状态。注意力直接修复了这个问题。

## 使用

PyTorch 有 `nn.Transformer` 和基于 `nn.LSTM` 的 seq2seq 模板。Hugging Face 的 `transformers` 库提供完整的编码器-解码器模型（BART、T5、mBART、NLLB），这些模型在数十亿标记上训练。

```python
from transformers import AutoTokenizer, AutoModelForSeq2SeqLM

tok = AutoTokenizer.from_pretrained("facebook/bart-base")
model = AutoModelForSeq2SeqLM.from_pretrained("facebook/bart-base")

src = tok("Translate this to French: Hello, how are you?", return_tensors="pt")
out = model.generate(**src, max_new_tokens=50, num_beams=4)
print(tok.decode(out[0], skip_special_tokens=True))
```

现代编码器-解码器已用 Transformer 替代了 RNN。高层形态（编码器、解码器、逐标记生成）与 2014 年的 seq2seq 论文完全相同。每个块内部的机制不同。

### 何时仍然需要基于 RNN 的 seq2seq

对于新项目，几乎从不。特定例外：

- 流式翻译，其中你以有界内存逐个标记消费输入。
- 设备端文本生成，Transformer 的内存成本过高。
- 教学。理解编码器-解码器瓶颈是理解 Transformer 为何胜出的最快路径。

### 曝光偏差及其缓解措施

- **计划采样。** 在训练过程中退火教师强制的比例，使模型学会从自己的错误中恢复。
- **最小风险训练。** 在句子级 BLEU 分数上训练，而不是标记级交叉熵。更接近你实际想要的。
- **强化学习微调。** 用指标奖励序列生成器。用于现代 LLM RLHF。

这三种方法仍然适用于基于 Transformer 的生成。

## 交付

保存为 `outputs/prompt-seq2seq-design.md`：

```markdown
---
name: seq2seq-design
description: 为给定任务设计序列到序列流水线。
phase: 5
lesson: 09
---

给定一个任务（翻译、摘要、改写、问题重写），输出：

1. 架构。预训练 Transformer 编码器-解码器（BART、T5、mBART、NLLB）是默认选择。仅对特定约束使用基于 RNN 的 seq2seq。
2. 起始检查点。给出名称（`facebook/bart-base`、`google/flan-t5-base`、`facebook/nllb-200-distilled-600M`）。将检查点与任务和语言覆盖匹配。
3. 解码策略。贪心用于确定性输出，束搜索（宽度 4-5）用于质量，带温度的采样用于多样性。一句话说明理由。
4. 部署前需要验证的一个失败模式。曝光偏差表现为在更长输出上的生成漂移；采样 90 分位数长度的 20 个输出并肉眼检查。

拒绝为少于一百万对平行语料的情况推荐从头训练 seq2seq。将任何对用户可见内容使用贪心解码的流水线标记为脆弱（贪心会重复和循环）。
```

## 练习

1. **简单。** 实现玩具复制任务。在输入-输出对（目标等于源）上训练一个 GRU seq2seq。测量长度 5、10、20 的准确率。复现瓶颈。
2. **中等。** 添加束宽为 3 的束搜索解码。在小型平行语料库上测量 BLEU 并与贪心对比。记录束搜索在哪里胜出（通常是最后几个标记）以及在哪里没有差异。
3. **困难。** 在 10k 对的改写数据集上微调 `facebook/bart-base`。将微调模型的 beam-4 输出与基础模型在留存输入上的输出对比。报告 BLEU 并挑选 10 个定性示例。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| 编码器 | 输入 RNN | 读取源序列。产生每个步骤的隐藏状态和一个最终上下文向量。 |
| 解码器 | 输出 RNN | 从上下文向量初始化。逐标记生成目标标记。 |
| 上下文向量 | 摘要 | 编码器最终隐藏状态。固定大小。正是注意力解决的瓶颈。 |
| 教师强制 | 使用真实标记 | 在训练时输入真实的前一个标记。稳定学习过程。 |
| 曝光偏差 | 训练/测试差距 | 在真实标记上训练的模型从未练习过从自己的错误中恢复。 |
| 束搜索 | 更好的解码 | 每一步保持 top-k 个部分序列存活，而不是贪心选择。 |

## 扩展阅读

- [Sutskever, Vinyals, Le (2014). Sequence to Sequence Learning with Neural Networks](https://arxiv.org/abs/1409.3215)——seq2seq 原始论文。四页。
- [Cho et al. (2014). Learning Phrase Representations using RNN Encoder-Decoder for Statistical Machine Translation](https://arxiv.org/abs/1406.1078)——引入了 GRU 和编码器-解码器框架。
- [Bahdanau, Cho, Bengio (2014). Neural Machine Translation by Jointly Learning to Align and Translate](https://arxiv.org/abs/1409.0473)——注意力论文。在学完本课后立即阅读。
- [PyTorch NLP from Scratch 教程](https://pytorch.org/tutorials/intermediate/seq2seq_translation_tutorial.html)——可构建的 seq2seq + 注意力代码。