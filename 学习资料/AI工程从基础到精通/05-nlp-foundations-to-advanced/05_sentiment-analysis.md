# 情感分析

> 经典的NLP任务。大多数你需要了解的经典文本分类知识都在这里出现。

**类型:** 构建
**语言:** Python
**前置条件:** 第五阶段·02（BoW + TF-IDF），第二阶段·14（朴素贝叶斯）
**时间:** ~75分钟

## 问题

"The food was not great." 正面还是负面？

情感听起来简单。评论者说他们喜欢或不喜欢某样东西。给句子打标签。它之所以成为经典NLP任务，是因为每个看起来简单的案例都隐藏着一个困难的案例。否定翻转含义。反讽完全反转。"Not bad at all"是正面的，尽管有两个编码为负面的词。Emoji携带比周围文本更多的信号。领域词汇重要（音乐评论中的`tight` vs 时尚评论中的`tight`）。

情感是经典NLP的实作实验室。如果你理解为什么每个天真的基线都有特定的失败模式，你就理解了为什么每个更丰富的模型被发明出来。本课从零构建朴素贝叶斯基线，加入逻辑回归，并命名使生产情感成为合规级别问题的陷阱。

## 概念

经典情感是两步配方。

1. **表示。** 将文本转化为特征向量。BoW、TF-IDF或n-gram。
2. **分类。** 在标注样本上拟合线性模型（朴素贝叶斯、逻辑回归、SVM）。

朴素贝叶斯是最笨但有效的模型。假设给定标签后每个特征独立。从计数中估计`P(word | positive)`和`P(word | negative)`。推理时，将概率相乘。"天真"的独立性假设简直错得离谱，但结果却惊人地强。原因：在稀疏文本特征和中等数据量下，分类器更关心每个词倾向于哪一边，而不是有多少。

逻辑回归修复了独立性假设。它为每个特征学习一个权重，包括负权重。`not good`作为二元组特征得到一个负权重。朴素贝叶斯无法为其从未标注的二元组做到这一点。

## 构建部分

### 步骤1：一个真实的小数据集

```python
POSITIVE = [
    "absolutely loved this movie",
    "beautiful cinematography and a great story",
    "one of the best films of the year",
    "brilliant acting from the lead",
    "heartwarming and funny",
]

NEGATIVE = [
    "boring and far too long",
    "not worth your time",
    "the plot made no sense",
    "terrible acting, awful script",
    "i want my two hours back",
]
```

刻意小的数据集。真实工作使用数万个样本（IMDb、SST-2、Yelp情感）。数学是完全相同的。

### 步骤2：从头实现多项朴素贝叶斯

```python
import math
from collections import Counter


def train_nb(docs_by_class, vocab, alpha=1.0):
    class_priors = {}
    class_word_probs = {}
    total_docs = sum(len(d) for d in docs_by_class.values())

    for cls, docs in docs_by_class.items():
        class_priors[cls] = len(docs) / total_docs
        counts = Counter()
        for doc in docs:
            for token in doc:
                counts[token] += 1
        total = sum(counts.values()) + alpha * len(vocab)
        class_word_probs[cls] = {
            w: (counts[w] + alpha) / total for w in vocab
        }
    return class_priors, class_word_probs


def predict_nb(doc, class_priors, class_word_probs):
    scores = {}
    for cls in class_priors:
        s = math.log(class_priors[cls])
        for token in doc:
            if token in class_word_probs[cls]:
                s += math.log(class_word_probs[cls][token])
        scores[cls] = s
    return max(scores, key=scores.get)
```

加性平滑（alpha=1.0）是拉普拉斯平滑。没有它，某个类别中未见过的词概率为零，取log会爆炸。`alpha=0.01`在实践中常见。`alpha=1.0`是教学默认。

### 步骤3：从头实现逻辑回归

```python
import numpy as np


def sigmoid(x):
    return 1.0 / (1.0 + np.exp(-np.clip(x, -20, 20)))


def train_lr(X, y, epochs=500, lr=0.05, l2=0.01):
    n_features = X.shape[1]
    w = np.zeros(n_features)
    b = 0.0
    for _ in range(epochs):
        logits = X @ w + b
        preds = sigmoid(logits)
        err = preds - y
        grad_w = X.T @ err / len(y) + l2 * w
        grad_b = err.mean()
        w -= lr * grad_w
        b -= lr * grad_b
    return w, b


def predict_lr(X, w, b):
    return (sigmoid(X @ w + b) >= 0.5).astype(int)
```

这里L2正则化很重要。文本特征是稀疏的；没有L2模型会背诵训练样本。从`0.01`开始然后调参。

### 步骤4：处理否定（失败模式）

考虑"not good"和"not bad"。BoW分类器看到`{not, good}`和`{not, bad}`，并从训练中出现更多的那一个中学习。二元组分类器看到`not_good`和`not_bad`并将它们作为不同的特征学习。这通常就够了。

一个更笨拙但在没有二元组时有效的修复：**否定范围界定**。在否定词后给token加`NOT_`前缀，直到下一个标点。

```python
NEGATION_WORDS = {"not", "no", "never", "nor", "none", "nothing", "neither"}
NEGATION_TERMINATORS = {".", "!", "?", ",", ";"}


def apply_negation(tokens):
    out = []
    negate = False
    for token in tokens:
        if token in NEGATION_TERMINATORS:
            negate = False
            out.append(token)
            continue
        if token in NEGATION_WORDS:
            negate = True
            out.append(token)
            continue
        out.append(f"NOT_{token}" if negate else token)
    return out
```

```python
>>> apply_negation(["not", "good", "at", "all", ".", "but", "funny"])
['not', 'NOT_good', 'NOT_at', 'NOT_all', '.', 'but', 'funny']
```

现在`good`和`NOT_good`是不同的特征。分类器可以对它们赋予相反的权重。三行预处理，在情感基准上的可测量准确率提升。

### 步骤5：重要的评估指标

如果类别不均衡，单看准确率是有误导性的。真实情感语料库通常是70-80%正面或70-80%负面；一个常数多数类分类器得到80%准确率但毫无价值。报告以下每一项：

- **每类精确率和召回率。** 每类一对。宏观平均得到尊重类别均衡的单一数字。
- **宏观F1（不均衡数据的主要指标）。** 每类F1分数的均值，等权。当类别不均衡时用它代替准确率。
- **加权F1（替代选择）。** 与宏观相同但按类别频率加权。当不均衡本身有业务含义时与宏观F1一起报告。
- **混淆矩阵。** 原始计数。在信任任何标量指标之前始终检查；它揭示模型混淆了哪对类别。
- **每类错误样本。** 每类抽取5个错误预测。阅读它们。没有什么能替代阅读实际错误。

对于严重不均衡数据（> 95-5比例），报告**AUROC**和**AUPRC**代替准确率。AUPRC对少数类更敏感，而那通常是你关心的（垃圾邮件、欺诈、罕见情感）。

```python
def evaluate(y_true, y_pred):
    tp = sum(1 for t, p in zip(y_true, y_pred) if t == 1 and p == 1)
    fp = sum(1 for t, p in zip(y_true, y_pred) if t == 0 and p == 1)
    fn = sum(1 for t, p in zip(y_true, y_pred) if t == 1 and p == 0)
    tn = sum(1 for t, p in zip(y_true, y_pred) if t == 0 and p == 0)
    precision = tp / (tp + fp) if tp + fp else 0
    recall = tp / (tp + fn) if tp + fn else 0
    f1 = 2 * precision * recall / (precision + recall) if precision + recall else 0
    return {"tp": tp, "fp": fp, "tn": tn, "fn": fn, "precision": precision, "recall": recall, "f1": f1}
```

## 使用部分

scikit-learn用六行正确完成。

```python
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import Pipeline

pipe = Pipeline([
    ("tfidf", TfidfVectorizer(ngram_range=(1, 2), min_df=2, sublinear_tf=True, stop_words=None)),
    ("clf", LogisticRegression(C=1.0, max_iter=1000)),
])
pipe.fit(X_train, y_train)
print(pipe.score(X_test, y_test))
```

三件事需要注意。`stop_words=None`保留否定词。`ngram_range=(1, 2)`添加二元组使`not_good`成为特征。`sublinear_tf=True`抑制重复词。这三个标志是SST-2上75%准确率基线和85%准确率基线之间的区别。

### 何时转向Transformer

- 反讽检测。经典模型在这里失败。没商量。
- 情感在文档中途变化的长评论。
- 基于方面的情感。"Camera was great but battery was terrible."你需要将情感归因到方面。仅限Transformer或结构化输出模型。
- 非英语、低资源语言。多语言BERT免费给你零样本基线。

如果你需要上述任何一项，跳到第七阶段（Transformer深入）。否则，朴素贝叶斯或TF-IDF上的逻辑回归加上二元组加否定处理就是你的2026年生产基线。

### 可复现性陷阱（再次）

重新训练情感模型是常规操作。重新评估它们不是。论文中报告的准确率数字使用特定的分割、特定的预处理、特定的分词器。如果你将新模型与基线比较而不使用相同的管道，你会得到误导性的差值。始终在你的管道上重新生成基线，而不是用论文的数字。

## 交付物

保存为`outputs/prompt-sentiment-baseline.md`：

## 练习

1. **（简单）** 添加`apply_negation`作为scikit-learn管道中的预处理步骤，并测量小型情感数据集上的F1差值。
2. **（中等）** 实现类别加权逻辑回归（传入`class_weight="balanced"`到scikit-learn，或者自己推导梯度）。在合成90-10类别不均衡上测量效果。
3. **（困难）** 通过在情感模型的残差上训练第二个分类器来构建反讽检测器。记录你的实验设置。当你的准确率低于随机水平时警告读者（二分类反讽的随机水平约为50%，大多数初次尝试都落在这里）。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| 情感极性 | 正面或负面 | 二元标签；有时扩展到中性或细粒度（5星）。 |
| 基于方面的情感 | 每个方面的极性 | 将情感归因到文本中提到的特定实体或属性。 |
| 否定范围界定 | 反转附近的token | 在"not"之后的token加`NOT_`前缀直到标点。 |
| 拉普拉斯平滑 | 给计数加1 | 防止朴素贝叶斯中的零概率特征。 |
| L2正则化 | 收缩权重 | 给损失加`lambda * sum(w^2)`。对稀疏文本特征至关重要。 |

## 进一步阅读