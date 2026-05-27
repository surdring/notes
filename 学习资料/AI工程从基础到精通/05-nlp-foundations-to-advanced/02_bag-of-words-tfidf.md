# 词袋、TF-IDF与文本表示

> 先数，后想。2026年，TF-IDF在定义明确的任务上仍然击败嵌入。

**类型:** 构建
**语言:** Python
**前置条件:** 第五阶段·01（文本处理），第二阶段·02（线性回归从零开始）
**时间:** ~75分钟

## 问题

模型需要数字。你只有字符串。

每个NLP管道都必须回答同一个问题。我们如何将变长的token流转换为分类器可以消费的固定大小向量。领域给出的第一个答案是最笨但能用的一个。数词。做一个向量。

那个向量承载了比任何嵌入模型都多的生产NLP。垃圾邮件过滤、主题分类、日志异常检测、搜索排序（BM25之前）、第一波情感分析、AI十年学术NLP基准测试。2026年的实践者仍然在窄分类任务上首选它。它快、可解释，并且在词是否存在决定一切的任务上，通常与400M参数的嵌入模型难以区分。

本课从零构建词袋，然后是TF-IDF。然后展示scikit-learn用三行做同样的事。然后指出让你转向嵌入的失败模式。

## 概念

**词袋（BoW）** 丢弃顺序。对每个文档，计算每个词汇词出现的次数。向量长度是词汇表大小。位置`i`是词`i`的计数。

**TF-IDF** 重新加权BoW。一个出现在每个文档中的词没有信息量，所以降低它的权重。在整个语料库中罕见但在单个文档中频繁出现的词是信号，所以提高它的权重。

```
TF-IDF(w, d) = TF(w, d) * IDF(w)
             = 文档d中w的计数 / |d| * log(N / df(w))
```

其中`TF`是文档中的词频，`df`是文档频率（有多少文档包含该词），`N`是总文档数。`log`使权重对普遍出现的词有界。

关键属性：两者都产生具有可解释轴的稀疏向量。你可以查看训练好的分类器的权重，并读取哪些词将文档推向每个类别。你无法用768维的BERT嵌入做到这一点。

## 构建部分

### 步骤1：构建词汇表

```python
def build_vocab(docs):
    vocab = {}
    for doc in docs:
        for token in doc:
            if token not in vocab:
                vocab[token] = len(vocab)
    return vocab
```

输入：分词后的文档列表（任何词级分词器都可以；本课的`code/main.py`使用简化的全小写变体）。输出：`{word: index}`字典。稳定的插入顺序意味着词索引0是第一个文档中见到的第一个词。约定各异；scikit-learn按字母顺序排序。

### 步骤2：词袋

```python
def bag_of_words(docs, vocab):
    matrix = [[0] * len(vocab) for _ in docs]
    for i, doc in enumerate(docs):
        for token in doc:
            if token in vocab:
                matrix[i][vocab[token]] += 1
    return matrix
```

```python
>>> docs = [["cat", "sat", "on", "mat"], ["cat", "cat", "ran"]]
>>> vocab = build_vocab(docs)
>>> bag_of_words(docs, vocab)
[[1, 1, 1, 1, 0], [2, 0, 0, 0, 1]]
```

行是文档。列是词汇索引。条目`[i][j]`是"词`j`在文档`i`中出现多少次"。文档1有`cat`两次因为它确实有。文档0有`ran`零次因为它没有。

### 步骤3：词频与文档频率

```python
import math


def term_frequency(doc_bow, doc_length):
    return [c / doc_length if doc_length else 0 for c in doc_bow]


def document_frequency(bow_matrix):
    df = [0] * len(bow_matrix[0])
    for row in bow_matrix:
        for j, count in enumerate(row):
            if count > 0:
                df[j] += 1
    return df


def inverse_document_frequency(df, n_docs):
    return [math.log((n_docs + 1) / (d + 1)) + 1 for d in df]
```

两个值得命名的平滑技巧。`(n+1)/(d+1)`避免了`log(x/0)`。末尾的`+1`确保即使每个文档中都出现的词也有IDF值1（不是0），匹配scikit-learn的默认设置。其他实现使用原始`log(N/df)`。两者都有效；平滑版本更友好。

### 步骤4：TF-IDF

```python
def tfidf(bow_matrix):
    n_docs = len(bow_matrix)
    df = document_frequency(bow_matrix)
    idf = inverse_document_frequency(df, n_docs)
    out = []
    for row in bow_matrix:
        length = sum(row)
        tf = term_frequency(row, length)
        out.append([tf_j * idf_j for tf_j, idf_j in zip(tf, idf)])
    return out
```

### 步骤5：L2归一化行

```python
def l2_normalize(matrix):
    out = []
    for row in matrix:
        norm = math.sqrt(sum(x * x for x in row))
        out.append([x / norm if norm else 0 for x in row])
    return out
```

没有归一化，更长的文档得到更大的向量并主导相似度分数。L2归一化将每个文档放到单位超球面上。行之间的余弦相似度现在就是点积。

## 使用部分

scikit-learn提供了生产版本。

```python
from sklearn.feature_extraction.text import CountVectorizer, TfidfVectorizer

docs = ["the cat sat on the mat", "the dog sat on the mat", "the cat ran"]

bow_vectorizer = CountVectorizer()
bow = bow_vectorizer.fit_transform(docs)
print(bow_vectorizer.get_feature_names_out())
print(bow.toarray())

tfidf_vectorizer = TfidfVectorizer()
tfidf = tfidf_vectorizer.fit_transform(docs)
print(tfidf.toarray().round(3))
```

`CountVectorizer`一次调用完成分词、词汇表构建和BoW。`TfidfVectorizer`添加IDF加权和L2归一化。两者都返回稀疏矩阵。对于100k文档，稠密版本无法装入内存；在分类器要求稠密矩阵之前保持稀疏。

改变一切的旋钮：

| 参数 | 效果 |
|------|------|
| `ngram_range=(1, 2)` | 包含二元组。通常会提升分类效果。 |
| `min_df=2` | 丢弃在少于2个文档中出现的词。在噪声数据上修剪词汇表。 |
| `max_df=0.95` | 丢弃在超过95%文档中出现的词。近似停用词移除，无需硬编码列表。 |
| `stop_words="english"` | scikit-learn的内置停用词列表。与任务相关——情感分析*不应*删除否定词。 |
| `sublinear_tf=True` | 使用`1 + log(tf)`代替原始`tf`。有助于当一个词在单个文档中重复多次时。 |

### TF-IDF何时仍然胜出（截至2026年）

- 垃圾邮件检测、主题标注、日志异常标记。词是否存在是关键；语义细微差别不重要。
- 低数据场景（数百个标注样本）。TF-IDF加逻辑回归没有预训练成本。
- 任何延迟重要的地方。TF-IDF加线性模型在微秒内回答。通过Transformer嵌入一个文档需要10-100ms。
- 必须解释预测的系统。检查分类器的系数。最高的正向词就是原因。

### TF-IDF何时失败

语义盲区失败。考虑这两个文档：

- "The movie was not good at all."
- "The movie was excellent."

一个是负面评论。一个是正面。它们的TF-IDF重叠正好是`{the, movie, was}`。词袋分类器必须记住`not`靠近`good`时会翻转标签。它可以在足够的数据上学会，但永远不会像理解语法的模型那样优雅。

另一个失败：推理时的词典外词。一个在IMDb评论上训练的BoW模型不知道如何处理`Zoomer-approved`如果这个token从未在训练中出现。子词嵌入（第04课）可以处理。TF-IDF不能。

### 混合：TF-IDF加权嵌入

2026年中等数据分类的实用默认方案：使用TF-IDF权重作为词嵌入上的注意力。

```python
def tfidf_weighted_embedding(doc, tfidf_scores, embedding_table, dim):
    vec = [0.0] * dim
    total_weight = 0.0
    for token in doc:
        if token not in embedding_table or token not in tfidf_scores:
            continue
        weight = tfidf_scores[token]
        emb = embedding_table[token]
        for i in range(dim):
            vec[i] += weight * emb[i]
        total_weight += weight
    if total_weight == 0:
        return vec
    return [v / total_weight for v in vec]
```

你从嵌入获得语义能力，从TF-IDF获得罕见词强调。分类器在池化向量上训练。这在情感、主题和意图分类中，大约50k标注样本以下，优于单独使用任何一种。

## 交付物

保存为`outputs/prompt-vectorization-picker.md`：

## 练习

1. **（简单）** 在L2归一化后的TF-IDF输出上实现`cosine_similarity(doc_vec_a, doc_vec_b)`。验证相同文档得分为1.0，词汇完全不重合的文档得分为0.0。
2. **（中等）** 为`bag_of_words`添加`n-gram`支持。参数`n`产生`n`元组计数。测试`n=2`在`["the", "cat", "sat"]`上产生`["the cat", "cat sat"]`的二元组计数。
3. **（困难）** 使用GloVe 100d向量构建上述TF-IDF加权嵌入混合方案。在20 Newsgroups数据集上比较分类准确率与纯TF-IDF和纯平均池化嵌入。报告哪种在哪些类别上胜出。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| BoW | 词频向量 | 一个文档中词汇词的计数。丢弃顺序。 |
| TF | 词频 | 一个词在文档中的计数，可选择用文档长度归一化。 |
| IDF | 逆文档频率 | log(总文档数/包含该词的文档数)。惩罚在所有文档中出现的词。 |
| 稀疏向量 | 大部分为零 | 大多数BoW/TF-IDF条目为零；有用信息在少数非零值中。 |
| 余弦相似度 | L2归一化后的点积 | L2归一化后两向量之间的欧几里得角。分类的标准文本相似度。 |

## 进一步阅读