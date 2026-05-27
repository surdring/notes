# 词嵌入——从零实现Word2Vec

> 一个词是它同伴的聚集。在这个想法上训练一个浅层网络，几何就自然浮现。

**类型:** 构建
**语言:** Python
**前置条件:** 第五阶段·02（BoW + TF-IDF），第三阶段·03（反向传播从零开始）
**时间:** ~75分钟

## 问题

TF-IDF知道`dog`和`puppy`是不同的词。它不知道它们几乎意味着同一件事。在`dog`上训练的分类器不能泛化到关于`puppy`的评论。你可以通过列出同义词来弥补，但这在罕见术语、领域行话和每个你没预料到的语言上都会失效。

你想要一个表示，其中`dog`和`puppy`在空间中靠近。其中`king - man + woman`落在`queen`附近。其中在`dog`上训练的模型将一些信号免费传递给`puppy`。

Word2Vec给了我们这个空间。两层神经网络，万亿token训练，2013年发表。架构几乎简单到令人尴尬。结果重塑了NLP整整十年。

## 概念

**分布式假设**（Firth, 1957）："你可以通过一个词的同伴来了解它。"如果两个词出现在相似的上下文中，它们可能意味着相似的东西。

Word2Vec有两种风格，都利用这个想法。

- **Skip-gram。** 给定一个中心词，预测周围词。窗口大小为2时`cat -> (the, sat, on)`。
- **CBOW（连续词袋）。** 给定周围词，预测中心词。`(the, sat, on) -> cat`。

Skip-gram训练更慢但更好地处理罕见词。它成为默认选择。

网络有一层没有非线性的隐藏层。输入是词汇表上的独热向量。输出是词汇表上的softmax。训练后，你扔掉输出层。隐藏层权重就是嵌入。

```
独热(中心) ── W ──▶ 隐藏层 (d维) ── W' ──▶ softmax(词汇表)
                          ^
                          这就是嵌入
```

技巧：100k个词上的softmax过于昂贵。Word2Vec使用**负采样**将其转化为二分类任务。预测"这个上下文词是否出现在这个中心词附近，是或否"。对每个训练对采样少量负样本（不共现的）词，而不是对整个词汇表计算softmax。

## 构建部分

### 步骤1：从语料库生成训练对

```python
def skipgram_pairs(docs, window=2):
    pairs = []
    for doc in docs:
        for i, center in enumerate(doc):
            for j in range(max(0, i - window), min(len(doc), i + window + 1)):
                if i == j:
                    continue
                pairs.append((center, doc[j]))
    return pairs
```

窗口内的每个(中心, 上下文)对都是一个正训练样本。

### 步骤2：嵌入表

两个矩阵。`W`是中心词嵌入表（你保留的那个）。`W'`是上下文词表（通常丢弃，有时与`W`平均）。

```python
import numpy as np


def init_embeddings(vocab_size, dim, seed=0):
    rng = np.random.default_rng(seed)
    W = rng.normal(0, 0.1, size=(vocab_size, dim))
    W_prime = rng.normal(0, 0.1, size=(vocab_size, dim))
    return W, W_prime
```

小随机初始化。词汇大小10k和维度100是现实的；对教学，50词汇x16维足以看到几何结构。

### 步骤3：负采样目标

对每个正样本对`(center, context)`，从词汇表中采样`k`个随机词作为负样本。训练模型使正样本的点积`W[center] · W'[context]`高，负样本的低。

```python
def sigmoid(x):
    return 1.0 / (1.0 + np.exp(-np.clip(x, -20, 20)))


def train_pair(W, W_prime, center_idx, context_idx, negative_indices, lr):
    v_c = W[center_idx]
    u_pos = W_prime[context_idx]
    u_negs = W_prime[negative_indices]

    pos_score = sigmoid(v_c @ u_pos)
    neg_scores = sigmoid(u_negs @ v_c)

    grad_center = (pos_score - 1) * u_pos
    for i, u in enumerate(u_negs):
        grad_center += neg_scores[i] * u

    W[context_idx] = W[context_idx]
    W_prime[context_idx] -= lr * (pos_score - 1) * v_c
    for i, neg_idx in enumerate(negative_indices):
        W_prime[neg_idx] -= lr * neg_scores[i] * v_c
    W[center_idx] -= lr * grad_center
```

魔法公式：正样本对上的逻辑损失（希望sigmoid接近1）加负样本对上的逻辑损失（希望sigmoid接近0）。梯度流向两个表。完整推导在原论文中；用纸笔走一遍如果你想让它记住。

### 步骤4：在玩具语料库上训练

```python
def train(docs, dim=16, window=2, k_neg=5, epochs=100, lr=0.05, seed=0):
    vocab = build_vocab(docs)
    vocab_size = len(vocab)
    rng = np.random.default_rng(seed)
    W, W_prime = init_embeddings(vocab_size, dim, seed=seed)
    pairs = skipgram_pairs(docs, window=window)

    for epoch in range(epochs):
        rng.shuffle(pairs)
        for center, context in pairs:
            c_idx = vocab[center]
            ctx_idx = vocab[context]
            negs = rng.integers(0, vocab_size, size=k_neg)
            negs = [n for n in negs if n != ctx_idx and n != c_idx]
            train_pair(W, W_prime, c_idx, ctx_idx, negs, lr)
    return vocab, W
```

在充足轮次和大语料库上训练后，共享上下文的词具有相似的中心嵌入。在玩具语料库上，你会微弱地看到效果。在数十亿token上，你会戏剧性地看到它。

### 步骤5：类比技巧

```python
def nearest(vocab, W, target_vec, topk=5, exclude=None):
    exclude = exclude or set()
    inv_vocab = {i: w for w, i in vocab.items()}
    norms = np.linalg.norm(W, axis=1, keepdims=True) + 1e-9
    W_norm = W / norms
    target = target_vec / (np.linalg.norm(target_vec) + 1e-9)
    sims = W_norm @ target
    order = np.argsort(-sims)
    out = []
    for i in order:
        if i in exclude:
            continue
        out.append((inv_vocab[i], float(sims[i])))
        if len(out) == topk:
            break
    return out


def analogy(vocab, W, a, b, c, topk=5):
    v = W[vocab[b]] - W[vocab[a]] + W[vocab[c]]
    return nearest(vocab, W, v, topk=topk, exclude={vocab[a], vocab[b], vocab[c]})
```

在预训练的300d Google News向量上：`king - man + woman = queen`。不是因为模型知道什么是皇室。因为向量`(king - man)`捕获了类似"皇室的"的东西，将其加到`woman`上就落在了皇室-女性区域附近。

## 使用部分

从头写Word2Vec是教学。生产NLP使用`gensim`。

```python
from gensim.models import Word2Vec

sentences = [
    ["the", "cat", "sat", "on", "the", "mat"],
    ["the", "dog", "ran", "across", "the", "room"],
]

model = Word2Vec(
    sentences,
    vector_size=100,
    window=5,
    min_count=1,
    sg=1,
    negative=5,
    workers=4,
    epochs=30,
)

print(model.wv["cat"])
print(model.wv.most_similar("cat", topn=3))
```

实际工作中，你几乎从不自己训练Word2Vec。你下载预训练向量。

- **GloVe** — Stanford的共现矩阵分解方法。50d、100d、200d、300d检查点。良好的通用覆盖。第04课专门介绍GloVe。
- **fastText** — Facebook的Word2Vec扩展，嵌入字符n-gram。通过组合子词处理词典外词。第04课。
- **Google News预训练Word2Vec** — 300d，3M词词汇，2013年发布。至今每天仍在被下载。

### Word2Vec在2026年何时仍然胜出

- 轻量级领域特定检索。在医学摘要上用笔记本训练一小时，获得通用模型无法捕捉的专用向量。
- 类比风格的特征工程。`gender_vector = mean(man - woman pairs)`。从其他词减去它获得性别中性轴。仍在公平性研究中使用。
- 可解释性。100d足够小，可以通过PCA或t-SNE绘制并实际看到聚类形成。
- 任何推理必须在设备上运行且没有GPU的地方。Word2Vec查找是单次行获取。

### Word2Vec失败的地方

多义性困境。`bank`只有一个向量。`river bank`和`financial bank`共享它。`table`（电子表格 vs 家具）共享它。下游分类器无法从向量中区分含义。

上下文嵌入（ELMo、BERT、此后每个Transformer）通过根据周围上下文为词的每个出现产生不同向量解决了这个问题。这就是从Word2Vec到BERT的跳跃：从静态到上下文化。第七阶段讲解Transformer部分。

词典外问题是另一个失败。如果`Zoomer-approved`不在训练数据中，Word2Vec从未见过它。没有回退。fastText通过子词组合（第04课）修复了这一点。

## 交付物

保存为`outputs/skill-embedding-probe.md`：

## 练习

1. **（简单）** 在一个微型语料库（20句关于猫和狗的句子）上运行训练循环。200轮后验证`nearest(vocab, W, W[vocab["cat"]])`在其前三中返回`dog`。如果没有，增加轮次或词汇量。
2. **（中等）** 添加高频词子采样。频率高于`10^-5`的词以与其频率成正比的概率从训练对中丢弃。测量对罕见词相似度的影响。
3. **（困难）** 在20 Newsgroups语料库上训练模型。计算两个偏置轴：`he - she`和`doctor - nurse`。将职业词投影到两个轴上。报告哪些职业的偏置差距最大。这是公平性研究人员使用的那种探查。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| 分布式假设 | "词的同伴" | 出现在相似上下文中的词具有相似含义。 |
| Skip-gram | 预测上下文词 | 给定中心词，预测窗口内的词。 |
| CBOW | 预测中心词 | 给定上下文词，预测中间词。 |
| 负采样 | 二分类技巧 | 将softmax替换为对k个随机词的二分类（是邻居，不是邻居）。 |
| 类比任务 | `king - man + woman = queen` | W[king]-W[man]+W[woman]的最邻近词返回queen。 |
| 多义性 | 一个词，多个含义 | 静态嵌入将`bank`的所有含义坍缩成一个向量。 |

## 进一步阅读