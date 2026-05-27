# GloVe、FastText与子词嵌入

> Word2Vec每个词训练一个嵌入。GloVe分解共现矩阵。FastText嵌入片段。BPE通向Transformer。

**类型:** 构建
**语言:** Python
**前置条件:** 第五阶段·03（Word2Vec从零开始）
**时间:** ~45分钟

## 问题

Word2Vec留下两个未解决的问题。

首先，有一线并行的研究直接分解共现矩阵（LSA、HAL）而不是进行在线skip-gram更新。Word2Vec的迭代方法从根本上更好，还是差异是两种方法处理计数方式的产物？**GloVe**回答了：带精心设计损失函数的矩阵分解匹配或击败Word2Vec，而且训练成本更低。

第二，两种方法都没有处理从未见过的词的办法。`Zoomer-approved`、`dogecoin`、任何上周才造出的专有名词、每个稀缺词根的屈折形式。**FastText**通过嵌入字符n-gram修复了这一点：一个词是其组成部分的总和，包括词素，所以即使词典外词也能得到合理的向量。

第三，一旦Transformer到来，问题再次转移。词级词汇表上限大约为一百万个条目；真实语言比这更开放。**字节对编码（BPE）**及其同类通过学习覆盖一切的高频子词单元词汇表解决了这个问题。每个现代LLM的每个现代分词器都是子词分词器。

本课逐一讲解这三者，然后解释何时选用哪个。

## 概念

**GloVe（全局向量）。** 构建词-词共现矩阵`X`，其中`X[i][j]`是词`j`在词`i`的上下文中出现的频率。训练向量使得`v_i · v_j + b_i + b_j ≈ log(X[i][j])`。加权损失使高频对不主导一切。完成。

**FastText。** 一个词是其字符n-gram的总和加上词本身。`where`变为`<wh, whe, her, ere, re>, <where>`。词向量是那些组成向量的总和。作为Word2Vec训练。好处：未见过的词（`whereupon`）从已知n-gram组合出来。

**BPE（字节对编码）。** 从单个字节（或字符）的词汇表开始。统计语料库中每个相邻对的数量。将最频繁的对合并成新token。重复`k`次迭代。结果：一个包含`k + 256`个token的词汇表，其中高频序列（`ing`、`tion`、`the`）是单个token，稀有词被分解为熟悉的片段。每个句子都可分词。

## 构建部分

### GloVe：分解共现矩阵

```python
import numpy as np
from collections import Counter


def build_cooccurrence(docs, window=5):
    pair_counts = Counter()
    vocab = {}
    for doc in docs:
        for token in doc:
            if token not in vocab:
                vocab[token] = len(vocab)
    for doc in docs:
        indexed = [vocab[t] for t in doc]
        for i, center in enumerate(indexed):
            for j in range(max(0, i - window), min(len(indexed), i + window + 1)):
                if i != j:
                    distance = abs(i - j)
                    pair_counts[(center, indexed[j])] += 1.0 / distance
    return vocab, pair_counts


def glove_train(vocab, pair_counts, dim=16, epochs=100, lr=0.05, x_max=100, alpha=0.75, seed=0):
    n = len(vocab)
    rng = np.random.default_rng(seed)
    W = rng.normal(0, 0.1, size=(n, dim))
    W_tilde = rng.normal(0, 0.1, size=(n, dim))
    b = np.zeros(n)
    b_tilde = np.zeros(n)

    for epoch in range(epochs):
        for (i, j), x_ij in pair_counts.items():
            weight = (x_ij / x_max) ** alpha if x_ij < x_max else 1.0
            diff = W[i] @ W_tilde[j] + b[i] + b_tilde[j] - np.log(x_ij)
            coef = weight * diff

            grad_W_i = coef * W_tilde[j]
            grad_W_tilde_j = coef * W[i]
            W[i] -= lr * grad_W_i
            W_tilde[j] -= lr * grad_W_tilde_j
            b[i] -= lr * coef
            b_tilde[j] -= lr * coef

    return W + W_tilde
```

值得命名的两个可动部分。加权函数`f(x) = (x/x_max)^alpha`降低极高频对（如`(the, and)`）的权重，使其不主导损失。最终嵌入是`W`（中心）和`W_tilde`（上下文）表的和。求和是已知的技巧，往往优于仅使用一个。

### FastText：子词感知嵌入

```python
def char_ngrams(word, n_min=3, n_max=6):
    wrapped = f"<{word}>"
    grams = {wrapped}
    for n in range(n_min, n_max + 1):
        for i in range(len(wrapped) - n + 1):
            grams.add(wrapped[i:i + n])
    return grams
```

每个词由其n-gram集合（通常是3到6个字符）表示。词嵌入是其n-gram嵌入的总和。对于skip-gram训练，将其插入Word2Vec使用单个向量的地方。

```python
def fasttext_vector(word, ngram_table):
    grams = char_ngrams(word)
    vecs = [ngram_table[g] for g in grams if g in ngram_table]
    if not vecs:
        return None
    return np.sum(vecs, axis=0)
```

对于未见的词，只要其部分n-gram已知，你仍然能得到向量。`whereupon`共享`<wh`、`her`、`ere`和`<where`与`where`，所以两者落在彼此附近。

### BPE：学习的子词词汇表

```python
def learn_bpe(corpus, k_merges):
    vocab = Counter()
    for word, freq in corpus.items():
        tokens = tuple(word) + ("</w>",)
        vocab[tokens] = freq

    merges = []
    for _ in range(k_merges):
        pair_freq = Counter()
        for tokens, freq in vocab.items():
            for a, b in zip(tokens, tokens[1:]):
                pair_freq[(a, b)] += freq
        if not pair_freq:
            break
        best = pair_freq.most_common(1)[0][0]
        merges.append(best)

        new_vocab = Counter()
        for tokens, freq in vocab.items():
            new_tokens = []
            i = 0
            while i < len(tokens):
                if i + 1 < len(tokens) and (tokens[i], tokens[i + 1]) == best:
                    new_tokens.append(tokens[i] + tokens[i + 1])
                    i += 2
                else:
                    new_tokens.append(tokens[i])
                    i += 1
            new_vocab[tuple(new_tokens)] = freq
        vocab = new_vocab
    return merges


def apply_bpe(word, merges):
    tokens = list(word) + ["</w>"]
    for a, b in merges:
        new_tokens = []
        i = 0
        while i < len(tokens):
            if i + 1 < len(tokens) and tokens[i] == a and tokens[i + 1] == b:
                new_tokens.append(a + b)
                i += 2
            else:
                new_tokens.append(tokens[i])
                i += 1
        tokens = new_tokens
    return tokens
```

真实GPT/BERT/T5分词器学习30k-100k次合并。结果：任何文本都分词成有界长度的已知ID序列，永远没有OOV。

## 使用部分

实践中，你很少自己训练这些。你加载预训练检查点。

```python
import fasttext.util
fasttext.util.download_model("en", if_exists="ignore")
ft = fasttext.load_model("cc.en.300.bin")
print(ft.get_word_vector("whereupon").shape)
print(ft.get_word_vector("zoomerapproved").shape)
```

对于Transformer时代的BPE式子词分词：

```python
from transformers import AutoTokenizer

tok = AutoTokenizer.from_pretrained("gpt2")
print(tok.tokenize("unbelievably tokenized"))
```

```
['un', 'bel', 'iev', 'ably', 'Ġtoken', 'ized']
```

`Ġ`前缀标记词边界（GPT-2约定）。每个现代分词器都是BPE变体、WordPiece（BERT）或SentencePiece（T5、LLaMA）。

### 何时选哪个

| 情况 | 选择 |
|------|------|
| 预训练通用词向量，不需要OOV容忍 | GloVe 300d |
| 预训练通用词向量，必须处理拼写错误/新词/形态丰富的语言 | FastText |
| 任何进入Transformer的内容（训练或推理） | 模型自带的任何分词器。永远不要换。 |
| 从头训练自己的语言模型 | 先在语料库上训练BPE或SentencePiece分词器 |
| 用线性模型进行生产文本分类 | 仍然是TF-IDF。第02课。 |

## 交付物

保存为`outputs/skill-tokenizer-picker.md`：

## 练习

1. **（简单）** 运行`char_ngrams("playing")`和`char_ngrams("played")`。计算两个n-gram集合的Jaccard重叠。你应该看到大量共享片段（`pla`、`lay`、`play`），这就是FastText在形态变体之间传递良好的原因。
2. **（中等）** 扩展`learn_bpe`以追踪词汇增长。绘制每个语料字符的token数量作为合并次数的函数。你应该看到初始时快速压缩，渐近接近约2-3字符/token。
3. **（困难）** 在莎士比亚全集中训练1k次合并的BPE。比较常见词和罕见专有名词的分词结果。测量分词前后的平均每词token数。写下让你惊讶的地方。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| 共现矩阵 | 词-词频率表 | `X[i][j]` = 词`j`在词`i`周围窗口中出现的频率。 |
| 子词 | 词的片段 | 字符n-gram（FastText）或学习到的token（BPE/WordPiece/SentencePiece）。 |
| BPE | 字节对编码 | 迭代合并最频繁相邻对，直到词汇表达目标大小。 |
| OOV | 词典外 | 模型从未见过的词。Word2Vec/GloVe失败。FastText和BPE能处理。 |
| 字节级BPE | 在原始字节上的BPE | GPT-2的方案。词汇表从256个字节开始，所以没有东西永远是OOV。 |

## 进一步阅读