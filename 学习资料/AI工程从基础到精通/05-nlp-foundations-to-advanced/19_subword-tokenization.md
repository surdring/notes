# 子词分词——BPE、WordPiece、Unigram、SentencePiece

> 词分词器在未见过的词上窒息。字符分词器让序列长度爆炸。子词分词器取两者折中。每个现代 LLM 都建立在某一个之上。

**类型：** 学习
**语言：** Python
**前置要求：** 第 5 阶段 · 01（文本处理），第 5 阶段 · 04（GloVe / FastText / 子词）
**时间：** 约 60 分钟

## 问题

你的词汇表有 50,000 个词。用户输入 "untokenizable"。你的分词器返回 `[UNK]`。模型现在对这个词没有任何信号。更糟糕：你语料库中第 90 百分位的文档有 40 个罕见词，意味着每篇文档丢失 40 位信息。

子词分词解决了这个问题。常见词保留为单个标记。罕见词分解为有意义的片段：`untokenizable` → `un`、`token`、`izable`。训练数据覆盖一切，因为任何字符串最终都是字节序列。

2026 年每个前沿 LLM 都建立在三种算法之一（BPE、Unigram、WordPiece）和三种库之一（tiktoken、SentencePiece、HF Tokenizers）之上。你无法在不选择其中之一的情况下发布语言模型。

## 概念

![BPE vs Unigram vs WordPiece，逐字符对比](../assets/subword-tokenization.svg)

**BPE（Byte-Pair Encoding）。** 从字符级词汇开始。计数每个相邻对。将最频繁的对合并为新标记。重复直到达到目标词汇大小。主导算法：GPT-2/3/4、Llama、Gemma、Qwen2、Mistral。

**字节级 BPE。** 同样的算法，但在原始字节（256 个基础标记）上而不是 Unicode 字符上运行。保证零 `[UNK]` 标记——任何字节序列都能编码。GPT-2 使用 50,257 个标记（256 字节 + 50,000 合并 + 1 特殊）。

**Unigram。** 从一个巨大的词汇开始。为每个标记分配一元概率。迭代剪枝那些移除后对语料对数似然增加最少的标记。推理时是概率性的：可以采样分词结果（通过子词正则化对数据增强有用）。被 T5、mBART、ALBERT、XLNet、Gemma 使用。

**WordPiece。** 合并那些最大化训练语料库似然的词对，而不是原始频率。被 BERT、DistilBERT、ELECTRA 使用。

**SentencePiece vs tiktoken。** SentencePiece 是*训练*词汇的库（BPE 或 Unigram），直接在原始 Unicode 文本上训练，将空白编码为 `▁`。tiktoken 是 OpenAI 针对预构建词汇的快速*编码器*；它不进行训练。

经验法则：

- **训练新词汇：** SentencePiece（多语言，无需预分词）或 HF Tokenizers。
- **针对 GPT 词汇的快速推理：** tiktoken（cl100k_base、o200k_base）。
- **两者兼顾：** HF Tokenizers——一个库，训练 + 服务。

## 构建

### 步骤 1：从零实现 BPE

见 `code/main.py`。循环：

```python
def train_bpe(corpus, num_merges):
    vocab = {tuple(word) + ("</w>",): count for word, count in corpus.items()}
    merges = []
    for _ in range(num_merges):
        pairs = Counter()
        for symbols, freq in vocab.items():
            for a, b in zip(symbols, symbols[1:]):
                pairs[(a, b)] += freq
        if not pairs:
            break
        best = pairs.most_common(1)[0][0]
        merges.append(best)
        vocab = apply_merge(vocab, best)
    return merges
```

算法编码的三个事实。`</w>` 标记词尾，使 "low"（后缀）和 "lower"（前缀）保持区分。频率加权使高频对早期胜出。合并列表是有序的——推理时按训练顺序应用合并。

### 步骤 2：用学习到的合并进行编码

```python
def encode_bpe(word, merges):
    symbols = list(word) + ["</w>"]
    for a, b in merges:
        i = 0
        while i < len(symbols) - 1:
            if symbols[i] == a and symbols[i + 1] == b:
                symbols = symbols[:i] + [a + b] + symbols[i + 2:]
            else:
                i += 1
    return symbols
```

朴素的 O(n·|merges|)。生产实现（tiktoken、HF Tokenizers）使用带优先队列的合并排名查找，运行在近线性时间。

### 步骤 3：SentencePiece 实践

```python
import sentencepiece as spm

spm.SentencePieceTrainer.train(
    input="corpus.txt",
    model_prefix="my_tokenizer",
    vocab_size=8000,
    model_type="bpe",          # 或 "unigram"
    character_coverage=0.9995, # CJK 用更低的值（如 English 0.9995，Japanese 0.995）
    normalization_rule_name="nmt_nfkc",
)

sp = spm.SentencePieceProcessor(model_file="my_tokenizer.model")
print(sp.encode("untokenizable", out_type=str))
# ['▁un', 'token', 'izable']
```

注意：无需预分词，空格编码为 `▁`，`character_coverage` 控制罕见字符被保留 vs 映射到 `<unk>` 的激进程度。

### 步骤 4：OpenAI 兼容词汇的 tiktoken

```python
import tiktoken
enc = tiktoken.get_encoding("o200k_base")
print(enc.encode("untokenizable"))        # [127340, 101028]
print(len(enc.encode("Hello, world!")))   # 4
```

仅编码。快速（Rust 后端）。与 GPT-4/5 的分词精确匹配，用于字节计数、成本估算、上下文窗口预算。

## 2026 年仍然在线上运行的陷阱

- **分词器漂移。** 在词汇 A 上训练，对词汇 B 部署。标记 ID 不同；模型输出垃圾。在 CI 中检查 `tokenizer.json` 哈希。
- **空白歧义。** BPE 中 "hello" vs " hello" 产生不同的标记。始终显式指定 `add_special_tokens` 和 `add_prefix_space`。
- **多语言训练不足。** 英语为主的语料库产生将非拉丁文字分割成 5-10 倍标记的词汇。在 GPT-3.5 上相同的提示在日语/阿拉伯语中成本 5-10 倍。o200k_base 部分修复了这一点。
- **Emoji 分割。** 单个 emoji 可能需要 5 个标记。在预算上下文时检查 emoji 处理。

## 使用

2026 年技术栈：

| 场景 | 选择 |
|-----------|------|
| 从头训练单语言模型 | HF Tokenizers (BPE) |
| 训练多语言模型 | SentencePiece (Unigram, `character_coverage=0.9995`) |
| 服务 OpenAI 兼容 API | tiktoken (`o200k_base` 用于 GPT-4+) |
| 领域特定词汇（代码、数学、蛋白质）| 在领域语料上训练自定义 BPE，与基础词汇合并 |
| 边缘推理，小型模型 | Unigram（较小词汇效果更好） |

词汇大小是一个缩放决策，不是常数。粗略启发式：<1B 参数用 32k，1-10B 用 50-100k，多语言/前沿用 200k+。

## 交付

保存为 `outputs/skill-bpe-vs-wordpiece.md`：

```markdown
---
name: tokenizer-picker
description: 为给定语料库和部署目标选择分词算法、词汇大小和库。
version: 1.0.0
phase: 5
lesson: 19
tags: [nlp, tokenization]
---

给定语料库（大小、语言、领域）和部署目标（从头训练 / 微调 / API 兼容推理），输出：

1. 算法。BPE、Unigram 或 WordPiece。一句话原因。
2. 库。SentencePiece、HF Tokenizers 或 tiktoken。原因。
3. 词汇大小。四舍五入到最接近的 1k。原因与模型大小和语言覆盖相关。
4. 覆盖设置。`character_coverage`、`byte_fallback`、特殊标记列表。
5. 验证计划。留出集合上的每词平均标记数、OOV 率、压缩比、编码解码往返一致性。

拒绝在包含罕见文字内容的语料库上训练 character_coverage < 0.995 的分词器。拒绝在 CI 中没有 `tokenizer.json` 哈希检查就发布词汇。将任何低于 16k 词汇的单语言分词器标记为可能规格不足。
```

## 练习

1. **简单。** 在 `code/main.py` 的小型语料库上训练一个 500 合并的 BPE。编码三个留出词。有多少产生了恰好 1 个标记 vs >1 个标记？
2. **中等。** 在 100 个英语 Wikipedia 句子上比较 `cl100k_base`、`o200k_base` 和一个你以 vocab=32k 训练的 SentencePiece BPE 之间的标记数。报告每种方法的压缩比。
3. **困难。** 用 BPE、Unigram 和 WordPiece 训练相同语料库。在小型情感分类器上使用每种分词器衡量下游准确率。选择差异是否超过 1 个 F1 点？

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| BPE | Byte-Pair Encoding | 贪婪合并最频繁的字符对直到达到目标词汇大小。 |
| 字节级 BPE | 绝无未知标记 | 在原始 256 字节上的 BPE；GPT-2 / Llama 使用此方法。 |
| Unigram | 概率分词器 | 使用对数似然从大型候选集中剪枝；被 T5、Gemma 使用。 |
| SentencePiece | 处理空白的那个 | 在原始文本上训练 BPE/Unigram 的库；空格编码为 `▁`。 |
| tiktoken | 快速的那个 | OpenAI 的 Rust 驱动 BPE 编码器，用于预构建词汇。不进行训练。 |
| 合并列表 | 魔法数字 | `(a, b) → ab` 合并的有序列表；推理时按顺序应用。 |
| 字符覆盖率 | 多罕见算太罕见？ | 分词器必须覆盖训练语料库中字符的比例；典型值 ~0.9995。 |

## 扩展阅读

- [Sennrich, Haddow, Birch (2015). Neural Machine Translation of Rare Words with Subword Units](https://arxiv.org/abs/1508.07909)——BPE 论文。
- [Kudo (2018). Subword Regularization with Unigram Language Model](https://arxiv.org/abs/1804.10959)——Unigram 论文。
- [Kudo, Richardson (2018). SentencePiece: A simple and language independent subword tokenizer](https://arxiv.org/abs/1808.06226)——库。
- [Hugging Face — Summary of the tokenizers](https://huggingface.co/docs/transformers/tokenizer_summary)——简洁参考。
- [OpenAI tiktoken 仓库](https://github.com/openai/tiktoken)——cookbook + 编码列表。