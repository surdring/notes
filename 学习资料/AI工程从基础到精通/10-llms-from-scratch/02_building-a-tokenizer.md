# 从零构建分词器

> 第 01 课给了你一个玩具。这一课给你一个武器。

**类型：** 构建
**语言：** Python
**前置要求：** 第 10 阶段，第 01 课（分词器：BPE、WordPiece、SentencePiece）
**时间：** 约 90 分钟

## 学习目标

- 构建一个能处理 Unicode、空白归一化和特殊 token 的生产级 BPE 分词器
- 实现字节级回退，使分词器可以编码任何输入（包括 emoji、CJK 和代码）而不产生未知 token
- 添加在应用 BPE 合并之前按词边界分割文本的预分词正则表达式模式
- 在语料库上训练自定义分词器，并在多语言文本上评估其压缩比与 tiktoken 的比较

## 问题

你在第 01 课的 BPE 分词器在英语文本上工作。现在向它抛日语。或 emoji。或混合了 tab 和空格的 Python 代码。

它崩溃了。

不是因为 BPE 错了——而是因为实现不完整。一个生产分词器要处理任何编码中的原始字节，在分割前归一化 Unicode，管理从不被合并的特殊 token，将预分词与子词分割串联，并以足够不阻塞处理 15 万亿 token 的训练管道的速度完成所有这些。

GPT-2 的分词器有 50,257 个 token。Llama 3 有 128,256。GPT-4 大约 100,000。这些不是玩具数字。这些词汇量背后的合并表是在数百 GB 文本上训练的，其周围的机制——归一化、预分词、特殊 token 注入、对话模板格式化——是将处理 "hello world" 的分词器与处理整个互联网的分词器区分开来的东西。

你将构建那个机制。

## 概念

### 完整管道

一个生产分词器不是一个算法。它是一个五阶段管道，每个阶段解决不同的问题。

```mermaid
graph LR
    A[原始文本] --> B[归一化]
    B --> C[预分词]
    C --> D[BPE 合并]
    D --> E[特殊 Token]
    E --> F[Token ID]

    style A fill:#1a1a2e,stroke:#e94560,color:#fff
    style B fill:#1a1a2e,stroke:#e94560,color:#fff
    style C fill:#1a1a2e,stroke:#e94560,color:#fff
    style D fill:#1a1a2e,stroke:#e94560,color:#fff
    style E fill:#1a1a2e,stroke:#e94560,color:#fff
    style F fill:#1a1a2e,stroke:#e94560,color:#fff
```

每个阶段承担特定的工作：

| 阶段 | 做什么 | 为什么重要 |
|------|--------|------------|
| 归一化 | NFKC Unicode，可选小写，可选去除重音 | "fi" 合字（U+FB01）变成 "fi"（两个字符）。没有这个，相同单词得到不同 token。 |
| 预分词 | 在 BPE 之前将文本分割成块 | 防止 BPE 跨词边界合并。"the cat" 不应产生 "e c" 这样的 token。 |
| BPE 合并 | 对字节序列应用学习到的合并规则 | 核心压缩。将原始字节转换为子词 token。 |
| 特殊 Token | 注入 [BOS]、[EOS]、[PAD]、对话模板标记 | 这些 token 有固定 ID。它们永远不参与 BPE 合并。模型需要它们用于结构。 |
| ID 映射 | 将 token 字符串转换为整数 ID | 模型看到整数，不是字符串。 |

### 字节级 BPE

第 01 课的分词器操作 UTF-8 字节。这是正确的选择。但我们跳过了重要的东西：当这些字节不是有效的 UTF-8 时会发生什么？

字节级 BPE 通过将每个可能的字节值（0-255）视为有效 token 来解决这个问题。你的基础词汇量恰好是 256 个条目。任何文件——文本、二进制、损坏的——都可以被分词而不会产生未知 token。

GPT-2 添加了一个技巧：将每个字节映射到一个可打印的 Unicode 字符，使词汇表保持人类可读。字节 0x20（空格）变成字符 "G"（在其映射中）。这只是装饰性的。算法不在乎。

真正的力量：字节级 BPE 处理地球上的每种语言。中文字符每个是 3 个 UTF-8 字节。日语可以是 3-4 个字节。阿拉伯语、天城文、emoji——都是字节序列。BPE 算法以完全相同的方式在这些字节序列中找到模式，就像在英语 ASCII 字节中一样。

### 预分词

在 BPE 接触你的文本之前，你需要将其分割成块。这防止合并算法创建跨越词边界的 token。

GPT-2 使用正则表达式模式分割文本：

```
'(?:[sdmt]|ll|ve|re)| ?\p{L}+| ?\p{N}+| ?[^\s\p{L}\p{N}]+|\s+(?!\S)|\s+
```

这个模式在缩写（"don't" 变成 "don" + "'t"）、带可选前导空格的单词、数字、标点和空白上分割。前导空格被保留附加到单词上——所以 "the cat" 变成 [" the", " cat"]，而不是 ["the", " ", "cat"]。

Llama 使用 SentencePiece，完全跳过正则表达式。它将原始字节流视为一个长序列，让 BPE 算法自己找出边界。这更简单但给 BPE 更多自由来创建跨词 token。

这个选择很重要。GPT-2 的正则表达式防止分词器学习到一个词末尾的 "the" 和下一个词开头的 "the" 应该合并。SentencePiece 允许它，这有时产生更高效的压缩但不太可解释的 token。

### 特殊 Token

每个生产分词器为结构标记预留 token ID：

| Token | 用途 | 使用者 |
|-------|------|---------|
| `[BOS]` / `<s>` | 序列开始 | Llama 3、GPT |
| `[EOS]` / `</s>` | 序列结束 | 所有模型 |
| `[PAD]` | 批次对齐的填充 | BERT、T5 |
| `[UNK]` | 未知 token（字节级 BPE 消除了这个） | BERT、WordPiece |
| `<\|im_start\|>` | 对话消息边界开始 | ChatGPT、Qwen |
| `<\|im_end\|>` | 对话消息边界结束 | ChatGPT、Qwen |
| `<\|user\|>` | 用户回合标记 | Llama 3 |
| `<\|assistant\|>` | 助手回合标记 | Llama 3 |

特殊 token 从不被 BPE 分割。在合并算法运行之前精确匹配它们，用其固定 ID 替换，周围文本正常分词。

### 对话模板

这是大多数人感到困惑、大多数实现崩溃的地方。

当你向对话模型发送消息时，API 接受消息列表：

```
[
  {"role": "system", "content": "You are helpful."},
  {"role": "user", "content": "Hello"},
  {"role": "assistant", "content": "Hi there!"}
]
```

模型不看到 JSON。它看到扁平的 token 序列。对话模板使用特殊 token 将消息转换为该扁平序列。每个模型做法不同：

```
Llama 3:
<|begin_of_text|><|start_header_id|>system<|end_header_id|>

You are helpful.<|eot_id|><|start_header_id|>user<|end_header_id|>

Hello<|eot_id|><|start_header_id|>assistant<|end_header_id|>

Hi there!<|eot_id|>

ChatGPT:
<|im_start|>system
You are helpful.<|im_end|>
<|im_start|>user
Hello<|im_end|>
<|im_start|>assistant
Hi there!<|im_end|>
```

搞错模板，模型产生垃圾。它是在一个确切格式上训练的。任何偏差——缺失换行、交换的 token、多余空格——都将输入置于训练分布之外。

### 速度

Python 对生产分词太慢了。

tiktoken（OpenAI）是用 Rust 写的，带 Python 绑定。HuggingFace tokenizers 也是 Rust。SentencePiece 是 C++。这些实现了比纯 Python 快 10-100 倍的速度。

直观感受：以每秒 100 万 token 的速度（快速 Python）对 Llama 3 预训练的 15 万亿 token 分词需要 174 天。以每秒 1 亿 token 的速度（Rust），需要 1.7 天。

你在 Python 中构建以理解算法。在生产中，你会使用编译实现，只接触 Python 包装器。

## 构建

在 `code/main.py` 中实现所有五个管道阶段。目标是训练一个自定义 BPE 分词器，对英语文本、代码和多语言文本的混合展现 <5% 的压缩差距 vs tiktoken 的 cl100k_base。

## 交付

保存为 `outputs/prompt-tokenizer-builder.md`。

## 练习

1. **简单。** 向你的分词器添加 Unicode NFKC 归一化。分词 "e\u0301tude"（e + 组合重音）和 "étude"（预组合）。证明它们现在产生相同的 token。
2. **中等。** 实现 GPT-2 的预分词正则表达式。在包含英语、代码和数学表达的文本上比较有和没有预分词的压缩比。预分词改进了吗？
3. **困难。** 在 100MB 的 Common Crawl 样本上训练 BPE 分词器（vocab_size=32768）。与 tiktoken 的 cl100k_base 比较压缩比和罕见词的 token 跨度。

## 关键术语

| 术语 | 含义 |
|------|------|
| NFKC | Unicode 归一化形式；将兼容字符分解/重组。 |
| 预分词 | 在 BPE 合并之前按正则表达式边界分割文本。 |
| 特殊 Token | 具有固定 ID 的保留 token；从未被 BPE 触及。 |
| 对话模板 | 将用户/助手消息转换为带特殊 token 的扁平文本的规则。 |
| tok/s | 每秒 token 数——训练吞吐量的关键指标。 |
| 字节回退 | 未知字符回退到其 UTF-8 字节的单个 token。 |

## 扩展阅读

- [OpenAI. tiktoken](https://github.com/openai/tiktoken)——快速字节级 BPE 分词器（Rust）。
- [HuggingFace. tokenizers](https://github.com/huggingface/tokenizers)——Rust 中的快速分词器，与 HF 生态集成。
- [Kudo & Richardson (2018). SentencePiece](https://arxiv.org/abs/1808.06226)——原始 SentencePiece 论文，涵盖归一化和训练。