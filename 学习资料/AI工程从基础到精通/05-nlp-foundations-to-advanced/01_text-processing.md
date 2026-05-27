# 文本处理——分词、词干提取、词形还原

> 语言是连续的。模型是离散的。预处理是桥梁。

**类型:** 构建
**语言:** Python
**前置条件:** 第二阶段·14（朴素贝叶斯）
**时间:** ~45分钟

## 问题

模型不能读"The cats were running."。它读整数。

每个NLP系统都以同样三个问题开始。一个词从哪里开始。这个词的根是什么。我们如何在有帮助时把"run"、"running"、"ran"当作同一个东西，在没有帮助时当作不同的东西。

把分词搞错，模型就从垃圾中学习。如果你的分词器把`don't`当作一个token但把`do n't`当作两个，训练分布就会分裂。如果你的词干提取器把`organization`和`organ`坍缩到同一个词干，主题建模就完蛋了。如果你的词形还原器需要词性上下文但你没有传入，动词就会被当成名词处理。

本课从零构建三个预处理原语，然后展示NLTK和spaCy如何做同样的工作，这样你就能看到权衡。

## 概念

三个操作。每个都有一个工作和一个失败模式。

**分词** 将字符串分割成token。"Token"是刻意模糊的，因为合适的粒度取决于任务。经典NLP用词级。Transformer用子词级。没有空格的语言用字符级。

**词干提取** 用规则砍掉后缀。快、激进、傻。`running -> run`。`organization -> organ`。第二个就是失败模式。

**词形还原** 使用语法知识将词还原成字典形式。更慢、准确、需要查找表或形态分析器。`ran -> run`（需要知道"ran"是"run"的过去式）。`better -> good`（需要知道比较级形式）。

经验法则。当速度重要且你能容忍噪声时用词干提取（搜索索引、粗略分类）。当含义重要时用词形还原（问答、语义搜索、用户会看到的任何内容）。

## 构建部分

### 步骤1：正则表达式分词器

最简单的可用分词器按非字母数字字符分割，同时保留标点作为独立token。不完美，不是最终方案，但一行就能运行。

```python
import re

def tokenize(text):
    return re.findall(r"[A-Za-z]+(?:'[A-Za-z]+)?|[0-9]+|[^\sA-Za-z0-9]", text)
```

按优先级排列的三个模式。带可选内部撇号的单词（`don't`、`it's`）。纯数字。任何单个非空白非字母数字字符作为独立token（标点）。

```python
>>> tokenize("The cats weren't running at 3pm.")
['The', 'cats', "weren't", 'running', 'at', '3', 'pm', '.']
```

要注意的失败模式。`3pm`分割为`['3', 'pm']`因为我们在字母序列和数字序列之间交替。对大多数任务够用了。URL、邮件、话题标签都会破裂。用于生产时，在通用模式之前添加专门的模式。

### 步骤2：Porter词干提取器（仅步骤1a）

完整的Porter算法有五阶段规则。仅步骤1a就覆盖了最常见的英语后缀，并教了模式。

```python
def stem_step_1a(word):
    if word.endswith("sses"):
        return word[:-2]
    if word.endswith("ies"):
        return word[:-2]
    if word.endswith("ss"):
        return word
    if word.endswith("s") and len(word) > 1:
        return word[:-1]
    return word
```

```python
>>> [stem_step_1a(w) for w in ["caresses", "ponies", "caress", "cats"]]
['caress', 'poni', 'caress', 'cat']
```

自上而下读规则。`ies -> i`规则就是为什么`ponies -> poni`而不是`pony`。真实Porter有步骤1b可以修复它。规则竞争。前面的规则胜出。顺序比任何单个规则都重要。

### 步骤3：基于查找的词形还原器

正确的词形还原需要形态学。一个可教学的版本使用一个小词形还原表和一个回退。

```python
LEMMA_TABLE = {
    ("running", "VERB"): "run",
    ("ran", "VERB"): "run",
    ("runs", "VERB"): "run",
    ("better", "ADJ"): "good",
    ("best", "ADJ"): "good",
    ("cats", "NOUN"): "cat",
    ("cat", "NOUN"): "cat",
    ("were", "VERB"): "be",
    ("was", "VERB"): "be",
    ("is", "VERB"): "be",
}

def lemmatize(word, pos):
    key = (word.lower(), pos)
    if key in LEMMA_TABLE:
        return LEMMA_TABLE[key]
    if pos == "VERB" and word.endswith("ing"):
        return word[:-3]
    if pos == "NOUN" and word.endswith("s"):
        return word[:-1]
    return word.lower()
```

```python
>>> lemmatize("running", "VERB")
'run'
>>> lemmatize("cats", "NOUN")
'cat'
>>> lemmatize("better", "ADJ")
'good'
>>> lemmatize("watched", "VERB")
'watched'
```

最后一个case是关键教学时刻。`watched`不在我们的表中，而且我们的回退只处理`ing`。真实的词形还原覆盖`ed`、不规则动词、比较级形容词、带音变的复数（`children -> child`）。这就是为什么生产系统使用WordNet、spaCy的morphologizer或完整的形态分析器。

### 步骤4：管道组合

```python
def preprocess(text, pos_tagger=None):
    tokens = tokenize(text)
    stems = [stem_step_1a(t.lower()) for t in tokens]
    tags = pos_tagger(tokens) if pos_tagger else [(t, "NOUN") for t in tokens]
    lemmas = [lemmatize(word, pos) for word, pos in tags]
    return {"tokens": tokens, "stems": stems, "lemmas": lemmas}
```

缺失的部分是词性标注器。第五阶段·07（词性标注）构建它。目前，默认所有为`NOUN`并承认局限性。

## 使用部分

NLTK和spaCy提供了生产版本。每种只需几行。

### NLTK

```python
import nltk
nltk.download("punkt_tab")
nltk.download("wordnet")
nltk.download("averaged_perceptron_tagger_eng")

from nltk.tokenize import word_tokenize
from nltk.stem import PorterStemmer, WordNetLemmatizer
from nltk import pos_tag

text = "The cats were running."
tokens = word_tokenize(text)
stems = [PorterStemmer().stem(t) for t in tokens]
lemmatizer = WordNetLemmatizer()
tagged = pos_tag(tokens)


def nltk_pos_to_wordnet(tag):
    if tag.startswith("V"):
        return "v"
    if tag.startswith("J"):
        return "a"
    if tag.startswith("R"):
        return "r"
    return "n"


lemmas = [lemmatizer.lemmatize(t, nltk_pos_to_wordnet(tag)) for t, tag in tagged]
```

`word_tokenize`处理缩写、Unicode、你的正则遗漏的边界情况。`PorterStemmer`运行全部五个阶段。`WordNetLemmatizer`需要将POS标签从NLTK的Penn Treebank方案转换为WordNet的缩写集合。上面的翻译接线正是大多数教程跳过的部分。

### spaCy

```python
import spacy

nlp = spacy.load("en_core_web_sm")
doc = nlp("The cats were running.")

for token in doc:
    print(token.text, token.lemma_, token.pos_)
```

```
The      the     DET
cats     cat     NOUN
were     be      AUX
running  run     VERB
.        .       PUNCT
```

spaCy将整个管道隐藏在`nlp(text)`后面。分词、词性标注和词形还原全部运行。比NLTK大规模更快。开箱即用更准确。权衡是你不能轻易交换单个组件。

### 什么时候选哪个

| 情况 | 选择 |
|------|------|
| 教学、研究、交换组件 | NLTK |
| 生产、多语言、速度重要 | spaCy |
| Transformer管道（你无论如何都会用模型的tokenizer分词） | 用`tokenizers`/`transformers`，跳过经典预处理 |

### 没人警告你的两个失败模式

大多数教程教完算法就停了。有两件事会咬到真实的预处理管道，而它们几乎从不被提及。

**可复现性偏移。** NLTK和spaCy在不同版本之间会改变分词和词形还原器的行为。在spaCy 2.x中产生`['do', "n't"]`的输入在3.x中可能产生`["don't"]`。你的模型在一个分布上训练。推理现在在另一个分布上运行。准确率悄悄下降却没人知道为什么。在`requirements.txt`中锁定库版本。写一个预处理回归测试，冻结对20个示例句子的期望分词结果。每次升级时运行它。

**训练/推理不匹配。** 用激进预处理（小写化、停用词移除、词干提取）训练，在原始用户输入上部署，看性能跌入谷底。这是最常见的生产NLP失败。如果你在训练时预处理，你必须在推理时运行完全相同的函数。把预处理作为模型包内的一个函数发布，而不是作为服务团队重写的notebook cell。

## 交付物

保存为`outputs/prompt-preprocessing-advisor.md`：

## 练习

1. **（简单）** 扩展`tokenize`将URL保留为单个token。测试：`tokenize("Visit https://example.com today.")`应产生一个URL token。
2. **（中等）** 实现Porter步骤1b。如果单词包含元音且以`ed`或`ing`结尾，移除它。处理双辅音规则（`hopping -> hop`，不是`hopp`）。
3. **（困难）** 构建一个词形还原器，使用WordNet作为查找表，但当WordNet没有词条时回退到你的Porter词干提取器。在一个标注语料库上测量准确率，与纯WordNet和纯Porter对比。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| Token | 一个词 | 模型消费的任何单位。可以是词、子词、字符或字节。 |
| 词干 | 词的根 | 基于规则的后缀剥离结果。不总是一个真实的词。 |
| 词形 | 字典形式 | 你会查的形式。需要语法上下文才能正确计算。 |
| 词性标注 | 词性 | 如NOUN、VERB、ADJ的类别。准确词形还原所需。 |
| 形态学 | 词形规则 | 一个词如何根据时态、数、格改变形式。词形还原依赖它。 |

## 进一步阅读