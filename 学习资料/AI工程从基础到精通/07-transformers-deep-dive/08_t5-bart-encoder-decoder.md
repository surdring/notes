# T5、BART——编码器-解码器模型

> 编码器理解。解码器生成。将它们放回一起，你得到为输入 → 输出任务构建的模型：翻译、摘要、重写、转录。

**类型：** 学习
**语言：** Python
**前置要求：** 第 7 阶段 · 05（完整 Transformer），第 7 阶段 · 06（BERT），第 7 阶段 · 07（GPT）
**时间：** 约 45 分钟

## 问题

仅解码器 GPT 和仅编码器 BERT 各自为不同目标精简化了 2017 架构。但许多任务天然是输入-输出：

- 翻译：英语 → 法语。
- 摘要：5,000 词的短文 → 200 词摘要。
- 语音识别：音频标记 → 文本标记。
- 结构化提取：散文 → JSON。

对于这些，编码器-解码器是最清晰的适配。编码器产生源的密集表示。解码器生成输出，在每一步交叉关注该表示。训练在输出侧偏移-1。与 GPT 相同的损失，只是以编码器输出为条件。

两篇论文定义了现代剧本：

1. **T5**（Raffel et al. 2019）。"Text-to-Text Transfer Transformer"。每个 NLP 任务重定义为文本输入、文本输出。单一架构，单一词汇，单一损失。在掩码跨度预测上预训练（破坏输入中的跨度，在输出中解码它们）。
2. **BART**（Lewis et al. 2019）。"Bidirectional and Auto-Regressive Transformer"。去噪自编码器：以多种方式破坏输入（打乱、掩码、删除、旋转），要求解码器重建原始。

2026 年编码器-解码器格式在输入结构重要的地方继续存在：

- Whisper（语音 → 文本）。
- Google 的翻译技术栈。
- 一些具有不同上下文和编辑结构的代码补全/修复模型。
- Flan-T5 和变体用于结构化推理任务。

仅解码器赢了聚光灯，但编码器-解码器从未消失。

## 概念

![带交叉注意力的编码器-解码器](../assets/encoder-decoder.svg)

### 前向循环

```
源标记 ─▶ 编码器 ─▶ (N_src, d_model)  ──┐
                                          │
目标标记 ─▶ 解码器块                       │
            ├─▶ 掩码自注意力               │
            ├─▶ 交叉注意力 ◀───────────────┘
            └─▶ FFN
           ↓
         下一个标记 logits
```

关键是编码器每个输入运行一次。解码器自回归运行但每步交叉关注*相同*的编码器输出。缓存编码器输出是长输入的免费加速。

### T5 预训练——跨度破坏

选择输入的随机跨度（平均长度 3 个标记，总计 15%）。将每个跨度替换为唯一哨兵：`<extra_id_0>`、`<extra_id_1>` 等。解码器仅输出被破坏的跨度及其哨兵前缀：

```
源：The quick <extra_id_0> fox jumps <extra_id_1> dog
目标：<extra_id_0> brown <extra_id_1> over the lazy
```

比预测整个序列更便宜的信号。在 T5 论文的消融中与 MLM（BERT）和前缀 LM（UniLM）竞争。

### BART 预训练——多噪声去噪

BART 尝试五种噪声函数：

1. 标记掩码。
2. 标记删除。
3. 文本填充（掩码一个跨度，解码器插入正确长度）。
4. 句子排列。
5. 文档旋转。

组合文本填充 + 句子排列产生最佳下游数字。解码器总是重建原始。BART 输出完整序列，不仅仅是破坏的跨度——因此预训练计算比 T5 高。

### 推理

与 GPT 相同的自回归生成。贪心/束搜索/top-p 采样适用。束搜索（宽度 4-5）是翻译和摘要的标准，因为输出分布比聊天窄。

### 2026 年何时选择每个变体

| 任务 | 编码器-解码器？ | 为什么 |
|------|------------------|-----|
| 翻译 | 是的，通常 | 清晰的源序列；固定输出分布；束搜索有效 |
| 语音到文本 | 是的（Whisper） | 输入模态与输出不同；编码器塑形音频特征 |
| 聊天/推理 | 否，仅解码器 | 无持久"输入"——对话就是序列 |
| 代码补全 | 通常否 | 带长上下文的仅解码器胜出；Qwen 2.5 Coder 等代码模型是仅解码器 |
| 摘要 | 两者都可 | BART、PEGASUS 击败更早的仅解码器基线；现代仅解码器 LLM 匹配它们 |
| 结构化提取 | 两者 | T5 干净因为"文本 → 文本"吸收任何输出格式 |

自约 2022 年以来的趋势：仅解码器接管了编码器-解码器曾经拥有的任务，因为 (a) 指令微调仅解码器 LLM 通过提示泛化到任何内容，(b) 一种架构比两种更容易缩放，(c) RLHF 假设解码器。编码器-解码器在输入模态不同（语音、图像）或束搜索质量重要的地方坚持。

## 构建

见 `code/main.py`。我们为玩具语料实现 T5 风格跨度破坏——本课最有用的单个部分，因为它出现在自此以来的每个编码器-解码器预训练配方中。

### 步骤 1：跨度破坏

```python
def corrupt_spans(tokens, mask_rate=0.15, mean_span=3.0, rng=None):
    """选择求和约 mask_rate 的标记的跨度。返回 (corrupted_input, target)。"""
    n = len(tokens)
    n_mask = max(1, int(n * mask_rate))
    n_spans = max(1, int(round(n_mask / mean_span)))
    ...
```

目标格式是 T5 约定：`<sent0> span0 <sent1> span1 ...`。被破坏的输入在跨度位置交错未改变标记和哨兵标记。

### 步骤 2：验证往返

给定被破坏的输入和目标，重建原始句子。如果你的破坏是可逆的，前向传播就是定义良好的。这是合理性检查——真实训练从不这样做，但测试便宜且捕获跨度簿记中的 off-by-one 错误。

### 步骤 3：BART 噪声

五个函数：`token_mask`、`token_delete`、`text_infill`、`sentence_permute`、`document_rotate`。组合其中两个并展示结果。

## 使用

HuggingFace 参考：

```python
from transformers import T5ForConditionalGeneration, T5Tokenizer
tok = T5Tokenizer.from_pretrained("google/flan-t5-base")
model = T5ForConditionalGeneration.from_pretrained("google/flan-t5-base")

inputs = tok("translate English to French: Attention is all you need.", return_tensors="pt")
out = model.generate(**inputs, max_new_tokens=32)
print(tok.decode(out[0], skip_special_tokens=True))
```

T5 技巧：任务名称进入输入文本。同一模型处理数十个任务，因为每个任务是文本输入、文本输出。2026 年此模式已被指令微调仅解码器模型泛化，但 T5 首先编纂了它。

## 交付

见 `outputs/skill-seq2seq-picker.md`。该技能给定输入-输出结构、延迟和质量目标，在新任务上在编码器-解码器和仅解码器之间选择。

## 练习

1. **简单。** 运行 `code/main.py`，对 30 标记句子应用跨度破坏，验证连接非哨兵源标记和解码的目标跨度能重现原始句子。
2. **中等。** 实现 BART 的 `text_infill` 噪声：用单个 `<mask>` 标记替换随机跨度，解码器必须推断正确的跨度长度和内容。展示一个示例。
3. **困难。** 在微型英语 → 猪拉丁语料（200 对）上微调 `flan-t5-small`。在留出的 50 对集合上测量 BLEU。与在相同数据和相同计算上微调 `Llama-3.2-1B` 比较。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| 编码器-解码器 | "Seq2seq transformer" | 两个栈：输入的双向编码器，带交叉注意力的因果解码器用于输出。 |
| 交叉注意力 | "源与目标对话的地方" | 解码器 Q × 编码器 K/V。编码器信息进入解码器的唯一地方。 |
| 跨度破坏 | "T5 的预训练技巧" | 用哨兵标记替换随机跨度；解码器输出跨度。 |
| 去噪目标 | "BART 的游戏" | 对输入应用噪声函数，训练解码器重建干净序列。 |
| 哨兵标记 | "`<extra_id_N>` 占位符" | 标记源中破坏跨度并在目标中重新标记的特殊标记。 |
| Flan | "指令微调 T5" | 在 1,800+ 任务上微调的 T5；使编码器-解码器在指令跟随上有竞争力。 |
| 束搜索 | "解码策略" | 每步保持 top-k 部分序列；翻译/摘要的标准。 |
| 教师强制 | "训练时输入" | 训练时，将真实上一个输出标记输入解码器，而非采样的那个。 |

## 扩展阅读

- [Raffel et al. (2019). Exploring the Limits of Transfer Learning with a Unified Text-to-Text Transformer](https://arxiv.org/abs/1910.10683)——T5。
- [Lewis et al. (2019). BART: Denoising Sequence-to-Sequence Pre-training for Natural Language Generation, Translation, and Comprehension](https://arxiv.org/abs/1910.13461)——BART。
- [Chung et al. (2022). Scaling Instruction-Finetuned Language Models](https://arxiv.org/abs/2210.11416)——Flan-T5。
- [Radford et al. (2022). Robust Speech Recognition via Large-Scale Weak Supervision](https://arxiv.org/abs/2212.04356)——Whisper，规范 2026 编码器-解码器。
- [HuggingFace `modeling_t5.py`](https://github.com/huggingface/transformers/blob/main/src/transformers/models/t5/modeling_t5.py)——参考实现。