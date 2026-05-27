# LLM 评估——RAGAS、DeepEval、G-Eval

> 精确匹配和 F1 无法捕捉语义等价。人工审核无法规模化。LLM-as-judge 是生产环境的答案——需要足够的校准来信任那个数字。

**类型：** 构建
**语言：** Python
**前置要求：** 第 5 阶段 · 13（问答），第 5 阶段 · 14（信息检索）
**时间：** 约 75 分钟

## 问题

你的 RAG 系统回答："June 29th, 2007."
黄金参考是："June 29, 2007."
精确匹配得 0。F1 约 75%。人类会给 100%。

现在乘以 10,000 个测试用例。再乘以检索器、分块、提示或模型的每次变更。你需要一个理解含义、大规模低成本运行、不会在回归上说谎、并能指出正确失败模式的评估器。

2026 年有三个框架解决了这个问题。

- **RAGAS。** 检索增强生成评估。四个 RAG 指标（忠实度、答案相关性、上下文精确度、上下文召回率），使用 NLI + LLM-judge 后端。经过研究验证，轻量级。
- **DeepEval。** LLM 的 Pytest。G-Eval、任务完成度、幻觉、偏见指标。原生 CI/CD。
- **G-Eval。** 一种方法（也是一个 DeepEval 指标）：带链式思维的 LLM-as-judge，自定义标准，0-1 分。

三者都依赖 LLM-as-judge。本课为该方法及其周围的信任层建立直觉。

## 概念

![四个评估维度，LLM-as-judge 架构](../assets/llm-evaluation.svg)

**LLM-as-judge。** 用 LLM 替换静态指标，给定评分标准对输出评分。给定 `(查询, 上下文, 答案)`，提示评判 LLM："评分 0-1 关于忠实度。"返回分数。

为什么有效：LLM 以极低的成本近似人类判断。GPT-4o-mini 每评分案例约 $0.003，使 1000 样本的回归评估运行成本低于 $5。

为什么静默失败：

1. **评判偏见。** 评判者偏好更长的答案、来自自己模型家族的答案、匹配提示风格的答案。
2. **JSON 解析失败。** 坏的 JSON → NaN 分数 → 静默排除出汇总。RAGAS 用户知道这种痛苦。用 try/except + 显式失败模式防护。
3. **模型版本间漂移。** 升级评判者会改变每个指标。冻结评判模型 + 版本。

**RAG 四项。**

| 指标 | 问题 | 后端 |
|--------|----------|---------|
| 忠实度 | 答案中的每个声明都来自检索到的上下文吗？ | 基于 NLI 的蕴含 |
| 答案相关性 | 答案是否针对问题？ | 从答案生成假设性问题；与真实问题比较 |
| 上下文精确度 | 检索到的分块中有多少是相关的？ | LLM-judge |
| 上下文召回率 | 检索是否返回了所需的一切？ | LLM-judge 对照黄金答案 |

**G-Eval。** 定义自定义标准："答案是否引用了正确的来源？"框架自动扩展为链式思维评估步骤，然后评分 0-1。适用于 RAGAS 未覆盖的领域特定质量维度。

**校准。** 在有与人类标签的关联之前，永远不要信任原始评判分数。运行 100 个手工标注的示例。绘制评判 vs 人类。计算 Spearman rho。如果 rho < 0.7，你的评判标准需要改进。

## 构建

### 步骤 1：用 NLI 进行忠实度（RAGAS 风格）

```python
from typing import Callable
from transformers import pipeline

nli = pipeline("text-classification",
               model="MoritzLaurer/DeBERTa-v3-large-mnli-fever-anli-ling-wanli",
               top_k=None)

# `llm` 是任何可调用对象：提示字符串 → 生成字符串。
# 例如：llm = lambda p: client.messages.create(model="claude-haiku-4-5", ...).content[0].text
LLM = Callable[[str], str]


def atomic_claims(answer: str, llm: LLM) -> list[str]:
    prompt = f"""Break this answer into simple factual claims (one per line):
{answer}
"""
    return llm(prompt).splitlines()


def faithfulness(answer: str, context: str, llm: LLM) -> float:
    claims = atomic_claims(answer, llm)
    if not claims:
        return 0.0
    supported = 0
    for claim in claims:
        result = nli({"text": context, "text_pair": claim})[0]
        entail = next((s for s in result if s["label"] == "entailment"), None)
        if entail and entail["score"] > 0.5:
            supported += 1
    return supported / len(claims)
```

将答案分解为原子声明。对每个声明进行 NLI 检查，对照检索到的上下文。忠实度 = 支持的比例。

### 步骤 2：答案相关性

```python
import numpy as np
from sentence_transformers import SentenceTransformer

# encoder：任何实现 .encode(texts, normalize_embeddings=True) -> ndarray 的模型
# 例如，encoder = SentenceTransformer("BAAI/bge-small-en-v1.5")

def answer_relevance(question: str, answer: str, encoder, llm: LLM, n: int = 3) -> float:
    prompt = f"Write {n} questions this answer could be the answer to:\n{answer}"
    generated = [line for line in llm(prompt).splitlines() if line.strip()][:n]
    if not generated:
        return 0.0
    q_emb = np.asarray(encoder.encode([question], normalize_embeddings=True)[0])
    g_embs = np.asarray(encoder.encode(generated, normalize_embeddings=True))
    sims = [float(q_emb @ g_emb) for g_emb in g_embs]
    return sum(sims) / len(sims)
```

如果答案暗示的问题与所问的问题不同，相关性就会下降。

### 步骤 3：G-Eval 自定义指标

```python
from deepeval.metrics import GEval
from deepeval.test_case import LLMTestCaseParams, LLMTestCase

metric = GEval(
    name="Correctness",
    criteria="The answer should be factually accurate and match the expected output.",
    evaluation_steps=[
        "Read the expected output.",
        "Read the actual output.",
        "List factual claims in the actual output.",
        "For each claim, mark supported or unsupported by the expected output.",
        "Return score = fraction supported.",
    ],
    evaluation_params=[LLMTestCaseParams.INPUT, LLMTestCaseParams.ACTUAL_OUTPUT, LLMTestCaseParams.EXPECTED_OUTPUT],
)

test = LLMTestCase(input="When was the first iPhone released?",
                   actual_output="June 29th, 2007.",
                   expected_output="June 29, 2007.")
metric.measure(test)
print(metric.score, metric.reason)
```

评估步骤就是标准。显式步骤比隐式"评分 0-1"提示更稳定。

### 步骤 4：CI 门控

```python
import deepeval
from deepeval.metrics import FaithfulnessMetric, ContextualRelevancyMetric


def test_rag_system():
    cases = load_regression_cases()
    faith = FaithfulnessMetric(threshold=0.85)
    rel = ContextualRelevancyMetric(threshold=0.7)
    for case in cases:
        faith.measure(case)
        assert faith.score >= 0.85, f"faithfulness regression on {case.id}"
        rel.measure(case)
        assert rel.score >= 0.7, f"relevancy regression on {case.id}"
```

作为 pytest 文件部署。在每个 PR 上运行。在回归时阻止合并。

### 步骤 5：从零构建玩具评估

见 `code/main.py`。仅标准库近似的忠实度（答案声明与上下文的重叠）和相关性（答案标记与问题标记的重叠）。非生产用。展示了形式。

## 陷阱

- **没有校准。** 与人类标签相关性为 0.3 的评判者是噪声。在部署前要求校准运行。
- **自我评估。** 使用相同的 LLM 生成和评判会将分数抬高 10-20%。使用不同的模型家族作为评判者。
- **成对评判中的位置偏见。** 评判者偏好第一个选项。始终随机化顺序并双向运行。
- **原始汇总隐藏失败。** 平均分 0.85 通常隐藏了 5% 的灾难性失败。始终检查底部分位数。
- **黄金数据集腐化。** 随时间漂移的未版本化评估集会破坏纵向比较。用每次变更标记数据集。
- **LLM 成本。** 大规模下，评判调用主导成本。使用满足校准阈值的最便宜模型。GPT-4o-mini、Claude Haiku、Mistral-small。

## 使用

2026 年技术栈：

| 用例 | 框架 |
|---------|-----------|
| RAG 质量监控 | RAGAS（4 个指标） |
| CI/CD 回归门控 | DeepEval + pytest |
| 自定义领域标准 | DeepEval 内的 G-Eval |
| 在线实时流量监控 | RAGAS 无参考模式 |
| 人工抽查 | LangSmith 或带标注 UI 的 Phoenix |
| 红队 / 安全评估 | Promptfoo + DeepEval |

典型栈：RAGAS 用于监控，DeepEval 用于 CI，G-Eval 用于新维度。三者都运行；它们的分歧是有用的。

## 交付

保存为 `outputs/skill-eval-architect.md`：

```markdown
---
name: eval-architect
description: 设计带校准评判器和 CI 门控的 LLM 评估计划。
version: 1.0.0
phase: 5
lesson: 27
tags: [nlp, evaluation, rag]
---

给定用例（RAG / agent / 生成任务），输出：

1. 指标。忠实度 / 相关性 / 上下文精确度 / 上下文召回率 + 任何带标准的自定义 G-Eval 指标。
2. 评判模型。命名模型 + 版本，成本 vs 准确率的原因。
3. 校准。手工标注集大小，目标 Spearman rho vs 人类 > 0.7。
4. 数据集版本化。标记策略、变更日志、分层。
5. CI 门控。每个指标的阈值、回归窗口逻辑、底部分位数告警。

拒绝依赖未经 ≥50 个人工标注示例测试的评判者。拒绝自我评估（同一模型生成 + 评判）。拒绝仅汇总报告而不展示底部 10%。标记评判者升级未伴随并行基线评估的任何 pipeline。
```

## 练习

1. **简单。** 在 10 个已知幻觉的 RAG 示例上使用 RAGAS。验证忠实度指标捕捉到每一个。
2. **中等。** 手工标注 50 个 QA 答案为 0-1 的正确性。用 G-Eval 评分。衡量评判者与人类之间的 Spearman rho。
3. **困难。** 用 DeepEval 构建 pytest CI 门控。故意使检索器退化。验证门控失败。通过对最低 10% 的阈值检查添加底部分位数告警。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| LLM-as-judge | 用 LLM 评分 | 提示评判模型按标准对输出进行 0-1 评分。 |
| RAGAS | RAG 指标库 | 带 4 个无参考 RAG 指标的开源评估框架。 |
| 忠实度 | 答案是否有根据？ | 检索到的上下文蕴含的答案声明比例。 |
| 上下文精确度 | 检索的分块是否相关？ | top-K 分块中实际重要的比例。 |
| 上下文召回率 | 检索是否找到了全部？ | 检索到的分块支持的黄金答案声明比例。 |
| G-Eval | 自定义 LLM 评判 | 评分标准 + 链式思维评估步骤 + 0-1 分。 |
| 校准 | 信任但验证 | 评判分数与人类分数之间的 Spearman 相关性。 |

## 扩展阅读

- [Es et al. (2023). RAGAS: Automated Evaluation of Retrieval Augmented Generation](https://arxiv.org/abs/2309.15217)——RAGAS 论文。
- [Liu et al. (2023). G-Eval: NLG Evaluation using GPT-4 with Better Human Alignment](https://arxiv.org/abs/2303.16634)——G-Eval 论文。
- [DeepEval docs](https://deepeval.com/docs/metrics-introduction)——开源生产栈。
- [Zheng et al. (2023). Judging LLM-as-a-Judge with MT-Bench and Chatbot Arena](https://arxiv.org/abs/2306.05685)——偏见、校准、限制。
- [MLflow GenAI Scorer](https://mlflow.org/blog/third-party-scorers)——集成 RAGAS、DeepEval、Phoenix 的统一框架。