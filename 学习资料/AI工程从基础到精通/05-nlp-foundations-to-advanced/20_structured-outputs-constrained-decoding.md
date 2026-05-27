# 结构化输出与约束解码

> 要求 LLM 输出 JSON。大多数时候得到 JSON。在生产环境中，"大多数"就是问题。约束解码通过在采样前编辑 logits，把"大多数"变成"总是"。

**类型：** 构建
**语言：** Python
**前置要求：** 第 5 阶段 · 17（聊天机器人），第 5 阶段 · 19（子词分词）
**时间：** 约 60 分钟

## 问题

一个分类器向 LLM 提示："Return one of {positive, negative, neutral}。"模型返回"The sentiment is positive — this review is overwhelmingly favorable because the customer explicitly states that they ..."。你的解析器崩溃。你的分类器 F1 为 0.0。

自由形式生成不是合约，只是一个建议。生产系统需要合约。

2026 年存在三个层次。

1. **提示。** 礼貌地请求。"Return only the JSON object。"在前沿模型上大约 80% 可行，在较小模型上更低。
2. **原生结构化输出 API。** OpenAI 的 `response_format`、Anthropic 工具使用、Gemini JSON 模式。在支持的 schema 上可靠。供应商锁定。
3. **约束解码。** 在每一步生成时修改 logits，使模型*不能*发出无效标记。构造上 100% 有效。在任何本地模型上工作。

本课为三者构建直觉，并指出何时使用哪个。

## 概念

![约束解码在每一步掩码无效标记](../assets/constrained-decoding.svg)

**约束解码的工作原理。** 在每一步生成中，LLM 在整个词汇（约 100k 标记）上产生一个 logit 向量。一个 *logit 处理器* 位于模型和采样器之间。它根据当前在目标语法中的位置计算哪些标记是有效的——JSON Schema、正则表达式、上下文无关文法——并将所有无效标记的 logits 设置为负无穷。在剩余 logits 上的 softmax 只在有效延续上分配概率质量。

2026 年的实现：

- **Outlines。** 将 JSON Schema 或正则表达式编译为有限状态机。每个标记获得 O(1) 的有效下一个标记查找。基于 FSM，所以递归 schema 需要展平。
- **XGrammar / llguidance。** 上下文无关文法引擎。处理递归 JSON Schema。近乎零解码开销。OpenAI 在 2025 年结构化输出实现中提到了 llguidance。
- **vLLM guided decoding。** 内置 `guided_json`、`guided_regex`、`guided_choice`、`guided_grammar`，通过 Outlines、XGrammar 或 lm-format-enforcer 后端。
- **Instructor。** 基于 Pydantic 的包装器，适合任何 LLM。在验证失败时重试。跨供应商，但不修改 logits——依赖重试 + 结构感知提示。

### 反直觉的结果

约束解码通常比非约束生成*更快*。两个原因。第一，它缩小了下一个标记的搜索空间。第二，巧妙的实现对强制标记完全跳过标记生成（脚手架如 `{"name": "`——每个字节都是确定的）。

### 让你付出代价的陷阱

字段顺序很重要。把 `answer` 放在 `reasoning` 之前，模型在思考之前就提交了答案。JSON 是有效的。答案是错的。没有验证能捕捉到。

```json
// BAD
{"answer": "yes", "reasoning": "because ..."}

// GOOD
{"reasoning": "... therefore ...", "answer": "yes"}
```

Schema 字段顺序是逻辑，不是格式。

## 构建

### 步骤 1：从零实现正则约束生成

见 `code/main.py` 的独立 FSM 实现。核心思想用 30 行代码：

```python
def mask_logits(logits, valid_token_ids):
    mask = [float("-inf")] * len(logits)
    for tid in valid_token_ids:
        mask[tid] = logits[tid]
    return mask


def generate_constrained(model, tokenizer, prompt, fsm):
    ids = tokenizer.encode(prompt)
    state = fsm.initial_state
    while not fsm.is_accept(state):
        logits = model.next_token_logits(ids)
        valid = fsm.valid_tokens(state, tokenizer)
        logits = mask_logits(logits, valid)
        tok = sample(logits)
        ids.append(tok)
        state = fsm.transition(state, tok)
    return tokenizer.decode(ids)
```

FSM 跟踪我们目前满足了文法的哪些部分。`valid_tokens(state, tokenizer)` 计算哪些词汇标记可以在不离开接受路径的情况下推进 FSM。

### 步骤 2：JSON Schema 的 Outlines

```python
from pydantic import BaseModel
from typing import Literal
import outlines


class Review(BaseModel):
    sentiment: Literal["positive", "negative", "neutral"]
    confidence: float
    evidence_span: str


model = outlines.models.transformers("meta-llama/Llama-3.2-3B-Instruct")
generator = outlines.generate.json(model, Review)

result = generator("Classify: 'The wait staff was attentive and the food arrived hot.'")
print(result)
# Review(sentiment='positive', confidence=0.93, evidence_span='attentive ... hot')
```

零验证错误。永远。FSM 使无效输出无法到达。

### 步骤 3：供应商无关 Pydantic 的 Instructor

```python
import instructor
from anthropic import Anthropic
from pydantic import BaseModel, Field


class Invoice(BaseModel):
    vendor: str
    total_usd: float = Field(ge=0)
    line_items: list[str]


client = instructor.from_anthropic(Anthropic())
invoice = client.messages.create(
    model="claude-opus-4-7",
    max_tokens=1024,
    response_model=Invoice,
    messages=[{"role": "user", "content": "Extract from: 'Acme Corp $420. Widget, Gizmo.'"}],
)
```

不同的机制。Instructor 不触及 logits。它将 schema 格式化为提示，解析输出，在验证失败时重试（默认 3 次）。适用于任何供应商。重试增加延迟和成本。跨供应商可移植性是卖点。

### 步骤 4：原生供应商 API

```python
from openai import OpenAI

client = OpenAI()
response = client.responses.create(
    model="gpt-5",
    input=[{"role": "user", "content": "Classify: 'The food was cold.'"}],
    text={"format": {"type": "json_schema", "name": "sentiment",
          "schema": {"type": "object", "required": ["sentiment"],
                     "properties": {"sentiment": {"type": "string",
                                                  "enum": ["positive", "negative", "neutral"]}}}}},
)
print(response.output_parsed)
```

服务端约束解码。在支持的 schema 上与 Outlines 可靠性相当。不需要本地模型管理。锁定到供应商。

## 陷阱

- **递归 schema。** Outlines 将递归展平到固定深度。树形输出（嵌套评论、AST）需要 XGrammar 或 llguidance（基于 CFG）。
- **巨大枚举。** 10,000 选项的枚举编译缓慢或超时。切换到检索器：先预测 top-k 候选，然后约束到这些候选。
- **文法太严格。** 强制 `date: "YYYY-MM-DD"` 正则，模型无法为缺失日期输出 `"unknown"`。模型通过发明日期来补偿。允许 `null` 或哨兵值。
- **过早提交。** 见上面的字段顺序陷阱。始终把 reasoning 放在前面。
- **供应商 JSON 模式无 schema。** 纯 JSON 模式只保证有效 JSON，不保证对你的用例有效。始终提供完整的 schema。

## 使用

2026 年技术栈：

| 场景 | 选择 |
|-----------|------|
| OpenAI/Anthropic/Google 模型，简单 schema | 原生供应商结构化输出 |
| 任何供应商，Pydantic 工作流程，可容忍重试 | Instructor |
| 本地模型，需要 100% 有效性，扁平 schema | Outlines (FSM) |
| 本地模型，递归 schema | XGrammar 或 llguidance |
| 自托管推理服务器 | vLLM guided decoding |
| 批量处理，可接受重试 | Instructor + 最便宜的模型 |

## 交付

保存为 `outputs/skill-structured-output-picker.md`：

```markdown
---
name: structured-output-picker
description: 选择结构化输出方法、schema 设计和验证计划。
version: 1.0.0
phase: 5
lesson: 20
tags: [nlp, llm, structured-output]
---

给定用例（供应商、延迟预算、schema 复杂度、失败容忍度），输出：

1. 机制。原生供应商结构化输出、Instructor 重试、Outlines FSM 或 XGrammar CFG。一句话原因。
2. Schema 设计。字段顺序（reasoning 在先，answer 在最后）、可为 null 字段用于 "unknown"、枚举 vs 正则、必填字段。
3. 失败策略。最大重试次数、后备模型、优雅的 `null` 处理、分布外拒绝。
4. 验证计划。Schema 合规率（目标 100%）、语义有效性（LLM 判断）、字段覆盖率、延迟 p50/p99。

拒绝任何将 `answer` 或 `decision` 放在 reasoning 字段之前的设计。拒绝使用不带 schema 的裸 JSON 模式。标记 FSM-only 库后面的递归 schema。
```

## 练习

1. **简单。** 在没有约束解码的情况下向小型开放权重模型（如 Llama-3.2-3B）提示 `Review(sentiment, confidence, evidence_span)`。在 100 篇评论上衡量解析为有效 JSON 的比例。
2. **中等。** 相同语料库使用 Outlines JSON 模式。比较合规率、延迟和语义准确率。
3. **困难。** 从零为电话号码实现正则约束解码器（`\d{3}-\d{3}-\d{4}`）。在 1000 个样本上验证 0 无效输出。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| 约束解码 | 强制有效输出 | 在每一步生成时掩码无效标记的 logits。 |
| Logit 处理器 | 做约束的东西 | 函数：`(logits, state) -> masked_logits`。 |
| FSM | 有限状态机 | 编译的文法表示；O(1) 有效下一个标记查找。 |
| CFG | 上下文无关文法 | 处理递归的文法；比 FSM 慢但表现力更强。 |
| Schema 字段顺序 | 重要吗？ | 是的——第一个字段提交；始终把 reasoning 放在 answer 之前。 |
| Guided decoding | vLLM 的叫法 | 相同概念，集成到推理服务器中。 |
| JSON 模式 | OpenAI 的早期版本 | 保证 JSON 语法；不保证 schema 匹配。 |

## 扩展阅读

- [Willard, Louf (2023). Efficient Guided Generation for LLMs](https://arxiv.org/abs/2307.09702)——Outlines 论文。
- [XGrammar 论文 (2024)](https://arxiv.org/abs/2411.15100)——快速基于 CFG 的约束解码。
- [vLLM — Structured Outputs](https://docs.vllm.ai/en/latest/features/structured_outputs.html)——推理服务器集成。
- [OpenAI — Structured Outputs 指南](https://platform.openai.com/docs/guides/structured-outputs)——API 参考 + 坑点。
- [Instructor 库](https://python.useinstructor.com/)——跨供应商的 Pydantic + 重试。
- [JSONSchemaBench (2025)](https://arxiv.org/abs/2501.10868)——对 6 个约束解码框架的基准测试。