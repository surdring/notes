# 机器翻译

> 翻译是支撑了 NLP 研究三十年，并且至今仍在持续投入的任务。

**类型：** 构建
**语言：** Python
**前置要求：** 第 5 阶段 · 10（注意力机制），第 5 阶段 · 04（GloVe、FastText、子词）
**时间：** 约 75 分钟

## 问题

一个模型读取一种语言的句子，生成另一种语言的句子。长度不同。词序不同。一些源词映射到多个目标词，反之亦然。习语拒绝一一映射。法语中"I miss you"是"tu me manques"——字面意思是"你对我来说是缺失的"。没有词级对齐能幸存下来。

机器翻译是迫使 NLP 发明编码器-解码器、注意力、Transformer，乃至整个 LLM 范式的任务。每一次进步都源于翻译质量是可衡量的，而人类与机器之间的差距顽固地存在。

本课跳过历史课，教授 2026 年的工作流水线：预训练多语言编码器-解码器（NLLB-200 或 mBART）、子词分词、束搜索、BLEU 和 chrF 评估，以及那些仍然未被发现就上线的少量失败模式。

## 概念

![MT 流水线：分词 → 编码 → 带注意力的解码 → 去分词](../assets/mt-pipeline.svg)

现代 MT 是在平行文本上训练的 Transformer 编码器-解码器。编码器以其语言的标记化方式读取源文本。解码器使用编码器的输出通过交叉注意力（第 10 课）逐个子词生成目标文本。解码使用束搜索来避免贪心解码的陷阱。输出经过去分词、去大小写处理，并与参考答案进行评分。

三个操作选择驱动现实世界的 MT 质量。

- **分词器。** 在混合语言语料库上训练的 SentencePiece BPE。跨语言共享词汇表是 NLLB 实现零样本语言对的关键。
- **模型大小。** NLLB-200 distilled 600M 能在笔记本上运行。NLLB-200 3.3B 是发布的生产默认值。54.5B 是研究上限。
- **解码。** 通用内容使用束宽 4-5。长度惩罚避免输出过短。需要术语一致性时使用约束解码。

## 构建

### 步骤 1：调用预训练 MT

```python
from transformers import AutoTokenizer, AutoModelForSeq2SeqLM

model_id = "facebook/nllb-200-distilled-600M"
tok = AutoTokenizer.from_pretrained(model_id, src_lang="eng_Latn")
model = AutoModelForSeq2SeqLM.from_pretrained(model_id)

src = "The cats are running."
inputs = tok(src, return_tensors="pt")

out = model.generate(
    **inputs,
    forced_bos_token_id=tok.convert_tokens_to_ids("fra_Latn"),
    num_beams=5,
    length_penalty=1.0,
    max_new_tokens=64,
)
print(tok.batch_decode(out, skip_special_tokens=True)[0])
```

```text
Les chats courent.
```

这里有三件事很重要。`src_lang` 告诉分词器应用哪种文字和分段方式。`forced_bos_token_id` 告诉解码器生成哪种语言。两者都是 NLLB 特有的技巧；mBART 和 M2M-100 使用各自的约定，不能互换。

### 步骤 2：BLEU 和 chrF

BLEU 衡量输出与参考答案之间的 n-gram 重叠。四种参考 n-gram 大小（1-4），精确率的几何平均，对过短输出的长度惩罚。分数在 [0, 100] 之间。常用。难以解读：30 BLEU 表示"可用"；40 表示"好"；50 表示"卓越"；低于 1 BLEU 的差异是噪声。

chrF 衡量字符级 F 分数。对形态丰富的语言更敏感，因为 BLEU 会低估匹配数。通常与 BLEU 一起报告。

```python
import sacrebleu

hypotheses = ["Les chats courent."]
references = [["Les chats courent."]]

bleu = sacrebleu.corpus_bleu(hypotheses, references)
chrf = sacrebleu.corpus_chrf(hypotheses, references)
print(f"BLEU: {bleu.score:.1f}  chrF: {chrf.score:.1f}")
```

始终使用 `sacrebleu`。它规范化了分词，使得分数在论文间可比较。自己编写 BLEU 计算是产生误导性基准的原因。

### 三层评估体系（2026）

现代 MT 评估使用三种互补的指标族。至少使用两种上线。

- **启发式**（BLEU、chrF）。快速、基于参考、可解释、对改写不敏感。用于遗留对比和回归检测。
- **学习式**（COMET、BLEURT、BERTScore）。在人类判断上训练的神经元模型；比较翻译与源文和参考的语义相似性。COMET 自 2023 年以来与 MT 研究的关联度最高，是 2026 年在质量至关重要时的生产默认选择。
- **LLM 作为评委**（无参考）。提示大型模型对翻译的流畅性、充分性、语调、文化适当性评分。GPT-4 作为评委在评分标准设计良好的情况下，与人类一致性匹配约 80%。用于没有参考译文存在的开放式内容。

实用的 2026 技术栈：`sacrebleu` 用于 BLEU 和 chrF，`unbabel-comet` 用于 COMET，以及一个提示 LLM 用于最终的人类可见信号。在信任每个指标用于生产数据之前，先用 50-100 个人工标注样本校准。

无参考指标（COMET-QE、BLEURT-QE、LLM 作为评委）让你可以在没有参考译文的情况下评估翻译，这对长尾语言对非常重要，因为那些语言对没有参考译文。

### 步骤 3：生产中的失败

上述工作流水线 80% 的时间会流畅翻译，剩下 20% 会静默失败。命名的失败模式：

- **幻觉。** 模型编造了源文中不存在的内容。在不熟悉的领域词汇中常见。症状：输出流畅但声称了源文未陈述的事实。缓解：领域术语的约束解码、受监管内容的人工审核、监控输出是否远长于输入。
- **偏离目标生成。** 模型翻译成了错误的语言。NLLB 在罕见语言对上出人意料地容易出现这个问题。缓解：验证 `forced_bos_token_id`，并始终用语言 ID 模型检查输出。
- **术语漂移。** "Sign up"在文档 1 中翻译为"s'inscrire"，在文档 2 中翻译为"créer un compte"。对于 UI 文本和面向用户的字符串，一致性比原始质量更重要。缓解：词汇表约束解码或后编辑词典。
- **正式程度不匹配。** 法语的"tu"与"vous"，日语敬语等级。模型选择训练中更常见的形式。对于面向客户的内容，这通常是错误的。缓解：如果模型支持，用正式度标记作为提示前缀，或仅在正式语料上微调一个小模型。
- **短输入的长度爆炸。** 非常短的输入句子经常产生过长的翻译，因为长度惩罚在约 5 个源标记以下时会急剧失效。缓解：与源文长度成比例的硬性最大长度上限。

### 步骤 4：领域微调

预训练模型是通才。法律、医疗或游戏对话翻译从领域平行数据上的微调中获益显著。配方并不特殊：

```python
from transformers import Trainer, TrainingArguments
from datasets import Dataset

pairs = [
    {"src": "The defendant pleaded guilty.", "tgt": "L'accusé a plaidé coupable."},
]

ds = Dataset.from_list(pairs)


def preprocess(ex):
    return tok(
        ex["src"],
        text_target=ex["tgt"],
        truncation=True,
        max_length=128,
        padding="max_length",
    )


ds = ds.map(preprocess, remove_columns=["src", "tgt"])

args = TrainingArguments(output_dir="out", per_device_train_batch_size=4, num_train_epochs=3, learning_rate=3e-5)
Trainer(model=model, args=args, train_dataset=ds).train()
```

几千对高质量的平行示例胜过几十万嘈杂的网络抓取数据。训练数据质量是最大的生产杠杆。

## 使用

2026 年 MT 生产技术栈：

| 用例 | 推荐起点 |
|---------|---------------------------|
| 任意到任意，200 种语言 | `facebook/nllb-200-distilled-600M`（笔记本）或 `nllb-200-3.3B`（生产） |
| 以英语为中心，高质量，50 种语言 | `facebook/mbart-large-50-many-to-many-mmt` |
| 短文本，便宜推理，英语-法语/德语/西班牙语 | Helsinki-NLP / Marian 模型 |
| 延迟关键的浏览器端 | ONNX 量化的 Marian（约 50 MB） |
| 最高质量，愿意付费 | GPT-4 / Claude / Gemini 带翻译提示 |

截至 2026 年，LLM 在多个语言对上已超越专用 MT 模型，尤其是在惯用内容和长上下文方面。权衡在于每个标记的成本和延迟。当上下文长度、风格一致性或通过提示进行领域适应比吞吐量更重要时，选择 LLM。

## 交付

保存为 `outputs/skill-mt-evaluator.md`：

```markdown
---
name: mt-evaluator
description: 评估机器翻译输出以决定是否上线。
version: 1.0.0
phase: 5
lesson: 11
tags: [nlp, translation, evaluation]
---

给定源文本和候选翻译，输出：

1. 自动评分估计。你预期的 BLEU 和 chrF 范围。说明是否有参考答案可用。
2. 五点人工可验证检查清单：(a) 内容保留（无幻觉），(b) 正确的语言，(c) 语域/正式度匹配，(d) 如果有词汇表，术语一致性，(e) 无截断或长度爆炸。
3. 一个需要探索的领域特定问题。例如，法律：命名实体和法规引用。医疗：药品名称和剂量。UI：占位符变量 `{name}`。
4. 置信度标记。"上线"/"审核后上线"/"不要上线"。与步骤 2 中发现的问题严重性关联。

拒绝上线未经语言 ID 检查输出的翻译。拒绝在没有参考答案的情况下评估，除非用户明确选择无参考评分（COMET-QE、BLEURT-QE）。将任何超过 1000 个标记的内容标记为可能需要分块翻译。
```

## 练习

1. **简单。** 使用 `nllb-200-distilled-600M` 将一个 5 句英文段落翻译成法语再翻译回英语。衡量往返翻译与原文的接近程度。你应该看到语义保留，但有措辞漂移。
2. **中等。** 使用 `fasttext lid.176` 或 `langdetect` 对翻译输出实现语言 ID 检查。集成到 MT 调用中，使偏离目标的生成在返回之前被捕获。
3. **困难。** 在你选择的 5000 对领域语料库上微调 `nllb-200-distilled-600M`。测量微调前后留存集上的 BLEU。报告哪种类型的句子改进了，哪些退步了。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| BLEU | 翻译分数 | N-gram 精确率加简短惩罚。[0, 100]。 |
| chrF | 字符 F 分数 | 字符级 F 分数。对形态丰富的语言更敏感。 |
| NMT | 神经元 MT | 在平行文本上训练的 Transformer 编码器-解码器。2017+ 默认方案。 |
| NLLB | 不让任何语言掉队 | Meta 的 200 语言 MT 模型族。 |
| 约束解码 | 受控输出 | 强制特定标记或 n-gram 出现在/不出现于输出中。 |
| 幻觉 | 编造内容 | 源文不支持的模型输出。 |

## 扩展阅读

- [Costa-jussà et al. (2022). No Language Left Behind: Scaling Human-Centered Machine Translation](https://arxiv.org/abs/2207.04672)——NLLB 论文。
- [Post (2018). A Call for Clarity in Reporting BLEU Scores](https://aclanthology.org/W18-6319/)——为什么 `sacrebleu` 是报告 BLEU 的唯一正确方式。
- [Popović (2015). chrF: character n-gram F-score for automatic MT evaluation](https://aclanthology.org/W15-3049/)——chrF 论文。
- [Hugging Face MT 指南](https://huggingface.co/docs/transformers/tasks/translation)——实用微调讲解。