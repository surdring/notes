# 主题建模——LDA 与 BERTopic

> LDA：文档是主题的混合，主题是词上的分布。BERTopic：文档在嵌入空间中聚类，聚类就是主题。相同的目标，不同的原语。

**类型：** 学习
**语言：** Python
**前置要求：** 第 5 阶段 · 02（词袋模型 + TF-IDF），第 5 阶段 · 03（Word2Vec）
**时间：** 约 45 分钟

## 问题

你有 10,000 张客户支持工单、50,000 篇新闻文章或 200,000 条推文。你需要在不阅读全部内容的情况下了解这个集合是关于什么的。你没有标注的类别。你甚至不知道存在多少类别。

主题建模无需监督就能回答这个问题。给它一个语料库，它返回一小组连贯的主题，以及每个文档在这些主题上的分布。

两个算法族占据主导地位。LDA（2003）将每个文档视为潜在主题的混合，每个主题视为词上的分布。推断是贝叶斯式的。在需要混合成员主题分配和可解释的词级概率分布的生产场景中它仍然在线运行。

BERTopic（2020）用 BERT 编码文档，用 UMAP 降维，用 HDBSCAN 聚类，并通过基于类的 TF-IDF 提取主题词。它在短文本、社交媒体以及语义相似性比词重叠更重要的任何场景中胜出。一个文档得到一个主题，这对长篇幅内容是局限。

本课为两者构建直觉，并指出针对给定语料库选择哪一种。

## 概念

![LDA 混合模型 vs BERTopic 聚类](../assets/topic-modeling.svg)

**LDA 生成过程。** 每个主题是词上的分布。每个文档是主题的混合。要生成文档中的一个词，从文档的主题混合中采样一个主题，然后从该主题的词分布中采样一个词。推断逆转这一过程：给定观察到的词，推断每个文档的主题分布和每个主题的词分布。折叠吉布斯采样或变分贝叶斯做数学计算。

LDA 的关键输出：

- `doc_topic`：矩阵 `(n_docs, n_topics)`，每行求和为 1（文档的主题混合）。
- `topic_word`：矩阵 `(n_topics, vocab_size)`，每行求和为 1（主题的词分布）。

**BERTopic 流水线。**

1. 用句子 Transformer（如 `all-MiniLM-L6-v2`）编码每个文档。384 维向量。
2. 用 UMAP 降维到约 5 维。BERT 嵌入对聚类来说维度太高。
3. 用 HDBSCAN 聚类。基于密度，产生可变大小的聚类和一个"离群"标签。
4. 对每个聚类，计算该聚类文档上的基于类的 TF-IDF 来提取 top 词。

输出是每个文档一个主题（加上 -1 离群标签）。可选地，通过 HDBSCAN 的概率向量获得软成员分配。

## 构建

### 步骤 1：通过 scikit-learn 使用 LDA

```python
from sklearn.feature_extraction.text import CountVectorizer
from sklearn.decomposition import LatentDirichletAllocation
import numpy as np


def fit_lda(documents, n_topics=5, max_features=1000):
    cv = CountVectorizer(
        max_features=max_features,
        stop_words="english",
        min_df=2,
        max_df=0.9,
    )
    X = cv.fit_transform(documents)
    lda = LatentDirichletAllocation(
        n_components=n_topics,
        random_state=42,
        max_iter=50,
        learning_method="online",
    )
    doc_topic = lda.fit_transform(X)
    feature_names = cv.get_feature_names_out()
    return lda, cv, doc_topic, feature_names


def print_top_words(lda, feature_names, n_top=10):
    for idx, topic in enumerate(lda.components_):
        top_idx = np.argsort(-topic)[:n_top]
        words = [feature_names[i] for i in top_idx]
        print(f"topic {idx}: {' '.join(words)}")
```

注意：移除停用词，min_df 和 max_df 过滤罕见和普遍词项，使用 CountVectorizer（不是 TfidfVectorizer），因为 LDA 期望原始计数。

### 步骤 2：BERTopic（生产）

```python
from bertopic import BERTopic

topic_model = BERTopic(
    embedding_model="sentence-transformers/all-MiniLM-L6-v2",
    min_topic_size=15,
    verbose=True,
)

topics, probs = topic_model.fit_transform(documents)
info = topic_model.get_topic_info()
print(info.head(20))
valid_topics = info[info["Topic"] != -1]["Topic"].tolist()
for topic_id in valid_topics[:5]:
    print(f"topic {topic_id}: {topic_model.get_topic(topic_id)[:10]}")
```

过滤 `Topic != -1` 丢弃 BERTopic 的离群桶（HDBSCAN 无法聚类的文档）。`min_topic_size` 控制 HDBSCAN 的最小聚类大小；BERTopic 库的默认值是 10。此示例为本课的规模将其显式设置为 15。对于超过 10,000 文档的语料库，增加到 50 或 100。

### 步骤 3：评估

两种方法都输出主题词。问题是这些词是否连贯。

- **主题连贯性（c_v）。** 在滑动窗口上下文中组合 top 词对的 NPMI（归一化点对点互信息），将分数聚合为主题向量，并通过余弦相似度比较这些向量。越高越好。使用 `gensim.models.CoherenceModel`，`coherence="c_v"`。
- **主题多样性。** 所有主题的 top 词中唯一词的比例。越高越好（主题不重叠）。
- **定性检查。** 阅读每个主题的 top 词。它们命名了一个真实的东西吗？人类判断仍然是最后一道防线。

## 何时选择哪种

| 情况 | 选择 |
|-----------|------|
| 短文本（推文、评论、标题） | BERTopic |
| 有主题混合的长文档 | LDA |
| 无 GPU / 有限计算 | LDA 或 NMF |
| 需要文档级多主题分布 | LDA |
| LLM 集成进行主题标记 | BERTopic（直接支持） |
| 资源受限的边缘部署 | LDA |
| 最大语义连贯性 | BERTopic |

最大的实际考虑是文档长度。BERT 嵌入会截断；LDA 计数在任何长度上都有效。对于比嵌入模型上下文更长的文档，要么分块 + 聚合，要么使用 LDA。

## 使用

2026 年技术栈：

- **BERTopic。** 短文本和语义重要场景的默认选择。
- **`gensim.models.LdaModel`。** 经典生产级 LDA，成熟，久经考验。
- **`sklearn.decomposition.LatentDirichletAllocation`。** 简单易用的实验性 LDA。
- **NMF。** 非负矩阵分解。LDA 的快速替代方案，在短文本上质量相当。
- **Top2Vec。** 与 BERTopic 类似的设计。社区较小，但在某些基准上表现良好。
- **FASTopic。** 更新的方法，在非常大的语料库上比 BERTopic 更快。
- **基于 LLM 的标注。** 运行任何聚类，然后提示模型为每个聚类命名。

## 交付

保存为 `outputs/skill-topic-picker.md`：

```markdown
---
name: topic-picker
description: 为语料库选择 LDA 或 BERTopic。指定库、旋钮和评估方法。
version: 1.0.0
phase: 5
lesson: 15
tags: [nlp, topic-modeling]
---

给定语料库描述（文档数量、平均长度、领域、语言、计算预算），输出：

1. 算法。LDA / NMF / BERTopic / Top2Vec / FASTopic。一句话原因。
2. 配置。主题数：`recommended = max(5, round(sqrt(n_docs)))`，对于 40,000 文档以下的语料库上限为 200；仅在语料库确实很大（>40k）时允许 >200 并注明增加的计算成本。`min_df` / `max_df` 过滤器以及神经元方法的嵌入模型也应在此。
3. 评估。通过 `gensim.models.CoherenceModel` 的主题连贯性（c_v），主题多样性，以及 20 个样本的人工阅读。
4. 需要探索的失败模式。对于 LDA，"垃圾主题"吸收停用词和频繁词。对于 BERTopic，-1 离群聚类吞掉模糊的文档。

拒绝在文档长度超过嵌入模型上下文窗口且没有分块策略的情况下使用 BERTopic。拒绝在非常短的文本（推文、10 个标记以下的评论）上使用 LDA，因为连贯性会崩溃。将任何低于 5 的 n_topics 选择标记为可能错误；将 40k 文档以下语料库的 >200 标记为可能过度分割。
```

## 练习

1. **简单。** 在 20 Newsgroups 数据集上用 5 个主题拟合 LDA。打印每个主题的 top 10 词。手工标注每个主题。算法找到了真实的类别吗？
2. **中等。** 在相同的 20 Newsgroups 子集上拟合 BERTopic。比较找到的主题数量、top 词以及定性连贯性，与 LDA 对比。哪种方法更干净地展现出真实类别？
3. **困难。** 在你的语料库上为 LDA 和 BERTopic 计算 c_v 连贯性。分别以 5、10、20、50 个主题运行。绘制连贯性 vs 主题数的关系图。报告哪种方法在不同主题数上更稳定。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| 主题 | 语料库关于的东西 | LDA 中是词上的概率分布，BERTopic 中是相似文档的聚类。 |
| 混合成员 | 文档是多主题的 | LDA 将每个文档分配为所有主题上的分布。 |
| UMAP | 降维 | 保持局部结构的流形学习；用于 BERTopic。 |
| HDBSCAN | 密度聚类 | 找到可变大小的聚类；为离群点产生"噪声"标签（-1）。 |
| c_v 连贯性 | 主题质量指标 | 在滑动窗口内 top 主题词的平均点对点互信息。 |

## 扩展阅读

- [Blei, Ng, Jordan (2003). Latent Dirichlet Allocation](https://www.jmlr.org/papers/volume3/blei03a/blei03a.pdf)——LDA 论文。
- [Grootendorst (2022). BERTopic: Neural topic modeling with a class-based TF-IDF procedure](https://arxiv.org/abs/2203.05794)——BERTopic 论文。
- [Röder, Both, Hinneburg (2015). Exploring the Space of Topic Coherence Measures](https://svn.aksw.org/papers/2015/WSDM_Topic_Evaluation/public.pdf)——引入 c_v 及其同类指标的论文。
- [BERTopic 文档](https://maartengr.github.io/BERTopic/)——生产参考。优秀的示例。