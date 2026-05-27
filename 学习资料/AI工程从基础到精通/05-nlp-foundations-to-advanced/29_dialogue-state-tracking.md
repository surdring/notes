# 对话状态追踪

> "I want a cheap restaurant in the north... actually make it moderate... and add Italian."三轮对话，三次状态更新。DST 保持槽值字典同步，使预订正常工作。

**类型：** 构建
**语言：** Python
**前置要求：** 第 5 阶段 · 17（聊天机器人），第 5 阶段 · 20（结构化输出）
**时间：** 约 75 分钟

## 问题

在任务导向的对话系统中，用户的目标被编码为一组槽值对：`{cuisine: italian, area: north, price: moderate}`。每个用户轮次可以添加、更改或删除一个槽。系统必须读取整个对话并正确输出当前状态。

一个槽出错，系统就预订了错误的餐厅、安排了错误的航班或收取了错误的费用。DST 是用户所说的和后端执行之间的枢纽。

尽管有 LLM，为什么 2026 年它仍然重要：

- 合规敏感领域（银行、医疗、航空预订）需要确定性槽值，而非自由形式生成。
- 工具使用 agent 在调用 API 前仍需要槽解析。
- 多轮纠正比看起来更难："actually no, make it Thursday."

现代 pipeline：经典 DST 概念 + LLM 抽取器 + 结构化输出护栏。

## 概念

![DST：对话历史 → 槽值状态](../assets/dst.svg)

**任务结构。** 模式定义领域（餐厅、酒店、出租车）及其槽（菜系、区域、价格、人数）。每个槽可以是空的、填充来自封闭集合的值（价格：{cheap, moderate, expensive}）或自由形式的值（名称："The Copper Kettle"）。

**两种 DST 公式化。**

- **分类。** 对每对 (槽, 候选值) 预测是/否。适用于封闭词汇槽。2020 年前标准。
- **生成。** 给定对话，以自由文本生成槽值。适用于开放词汇槽。现代默认选择。

**指标。** 联合目标准确率（JGA）——*每个*槽都正确的轮次比例。全有或全无。MultiWOZ 2.4 排行榜在 2026 年顶部约 83%。

**架构。**

1. **基于规则（槽正则 + 关键词）。** 窄领域的强基线。可调试。
2. **TripPy / BERT-DST。** 带 BERT 编码的基于复制的生成。LLM 前标准。
3. **LDST（LLaMA + LoRA）。** 指令微调的 LLM 带领域-槽提示。在 MultiWOZ 2.4 上达到 ChatGPT 级别质量。
4. **无本体（2024-26）。** 跳过模式；直接生成槽名和值。处理开放领域。
5. **提示 + 结构化输出（2024-26）。** 带 Pydantic 模式 + 约束解码的 LLM。5 行代码，生产就绪。

### 经典失败模式

- **跨轮次共指。** "Let's stay with the first option."需要解析哪个选项。
- **覆盖 vs 追加。** 用户说"add Italian。"是替换菜系还是追加？
- **隐式确认。** "OK cool"——这是接受了提供的预订吗？
- **纠正。** "Actually make it 7 pm."必须更新时间而不清除其他槽。
- **对之前系统话语的共指。** "Yes, that one."哪个"that"？

## 构建

### 步骤 1：基于规则的槽抽取器

见 `code/main.py`。正则 + 同义词字典在窄领域中覆盖 70% 的规范话语：

```python
CUISINE_SYNONYMS = {
    "italian": ["italian", "pasta", "pizza", "italy"],
    "chinese": ["chinese", "chow mein", "noodles"],
}


def extract_cuisine(utterance):
    for canonical, synonyms in CUISINE_SYNONYMS.items():
        if any(syn in utterance.lower() for syn in synonyms):
            return canonical
    return None
```

在规范词汇之外脆弱。适用于确定性槽确认。

### 步骤 2：状态更新循环

```python
def update_state(state, utterance):
    new_state = dict(state)
    for slot, extractor in SLOT_EXTRACTORS.items():
        value = extractor(utterance)
        if value is not None:
            new_state[slot] = value
    for slot in NEGATION_CLEARS:
        if is_negated(utterance, slot):
            new_state[slot] = None
    return new_state
```

三个不变量：

- 永远不要重置用户未触及的槽。
- 显式否定（"never mind the cuisine"）必须清除。
- 用户纠正（"actually..."）必须覆盖，而非追加。

### 步骤 3：带结构化输出的 LLM 驱动 DST

```python
from pydantic import BaseModel
from typing import Literal, Optional
import instructor

class RestaurantState(BaseModel):
    cuisine: Optional[Literal["italian", "chinese", "indian", "thai", "any"]] = None
    area: Optional[Literal["north", "south", "east", "west", "center"]] = None
    price: Optional[Literal["cheap", "moderate", "expensive"]] = None
    people: Optional[int] = None
    day: Optional[str] = None


def llm_dst(history, llm):
    prompt = f"""You track the slot values of a restaurant booking across turns.
Dialogue so far:
{render(history)}

Update the state based on the latest user turn. Output only the JSON state."""
    return llm(prompt, response_model=RestaurantState)
```

Instructor + Pydantic 保证有效的状态对象。无正则、无模式不匹配、无虚构槽。

### 步骤 4：JGA 评估

```python
def joint_goal_accuracy(predicted_states, gold_states):
    correct = sum(1 for p, g in zip(predicted_states, gold_states) if p == g)
    return correct / len(predicted_states)
```

校准：系统在所有槽上正确的轮次比例是多少？对于 MultiWOZ 2.4，2026 年顶部系统：80-83%。你领域内的系统应在你的窄词汇上超过此值，否则 LLM 基线会击败你。

### 步骤 5：处理纠正

```python
CORRECTION_CUES = {"actually", "no wait", "on second thought", "change that to"}


def is_correction(utterance):
    return any(cue in utterance.lower() for cue in CORRECTION_CUES)
```

检测到纠正时，覆盖最后更新的槽而非追加。没有 LLM 帮助很难正确处理。现代模式：始终让 LLM 从历史重新生成整个状态，而不是增量更新——这自然处理了纠正。

## 陷阱

- **完整历史再生成本。** 让 LLM 每轮重新生成状态消耗 O(n²) 总 token。限制历史或总结较早轮次。
- **模式漂移。** 事后添加新槽会破坏旧的训练数据。为模式设置版本。
- **大小写敏感。** "Italian" vs "italian" vs "ITALIAN"——处处归一化。
- **隐式继承。** 如果用户之前指定了"for 4 people"，更改时间的新请求不应清除人数。始终传递完整历史。
- **自由形式 vs 封闭集合。** 名称、时间、地址需要自由形式槽；菜系和区域是封闭的。在模式中混合两者。

## 使用

2026 年技术栈：

| 场景 | 方法 |
|-----------|----------|
| 窄领域（一到两个意图） | 基于规则 + 正则 |
| 宽领域，有标注数据 | LDST（LLaMA + LoRA 在 MultiWOZ 风格数据上） |
| 宽领域，无标签，生产就绪 | LLM + Instructor + Pydantic 模式 |
| 语音 / 声音 | ASR + 归一化器 + LLM-DST |
| 多领域预订流程 | 模式引导的 LLM 带每个领域的 Pydantic 模型 |
| 合规敏感 | 基于规则为主，LLM 后备带确认流程 |

## 交付

保存为 `outputs/skill-dst-designer.md`：

```markdown
---
name: dst-designer
description: 设计对话状态追踪器——模式、抽取器、更新策略、评估。
version: 1.0.0
phase: 5
lesson: 29
tags: [nlp, dialogue, task-oriented]
---

给定用例（领域、语言、词汇开放度、合规需求），输出：

1. 模式。领域列表、每个领域的槽、每个槽的开放 vs 封闭词汇。
2. 抽取器。基于规则 / seq2seq / LLM-with-Pydantic。原因。
3. 更新策略。重新生成完整状态 / 增量；纠正处理；否定处理。
4. 评估。留出对话集上的联合目标准确率、槽级精确率/召回率、最难槽的混淆情况。
5. 确认流程。何时显式要求用户确认（破坏性操作、低置信度抽取）。

拒绝对合规敏感槽使用纯 LLM DST 而无基于规则的二次检查。拒绝任何在用户纠正时不能回滚槽的 DST。标记无版本标签的模式。
```

## 练习

1. **简单。** 为 3 个槽（菜系、区域、价格）构建 `code/main.py` 中基于规则的状态追踪器。在 10 个手工构建的对话上测试。衡量 JGA。
2. **中等。** 相同数据集用 Instructor + Pydantic + 小 LLM。比较 JGA。检查最难的轮次。
3. **困难。** 实现两者并路由：基于规则为主，当规则输出 <2 个置信度槽时 LLM 后备。衡量组合 JGA 和每轮推理成本。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| DST | 对话状态追踪 | 跨对话轮次维护槽值字典。 |
| 槽 | 用户意图单元 | 后端需要的命名参数（菜系、日期）。 |
| 领域 | 任务区域 | 餐厅、酒店、出租车——槽的集合。 |
| JGA | 联合目标准确率 | 每个槽都正确的轮次比例。全有或全无。 |
| MultiWOZ | 基准 | 多领域 WOZ 数据集；标准 DST 评估。 |
| 无本体 DST | 无模式 | 直接生成槽名和值，无固定列表。 |
| 纠正 | "Actually..." | 覆盖先前填充槽的轮次。 |

## 扩展阅读

- [Budzianowski et al. (2018). MultiWOZ — A Large-Scale Multi-Domain Wizard-of-Oz](https://arxiv.org/abs/1810.00278)——规范基准。
- [Feng et al. (2023). Towards LLM-driven Dialogue State Tracking (LDST)](https://arxiv.org/abs/2310.14970)——LLaMA + LoRA 指令微调用于 DST。
- [Heck et al. (2020). TripPy — A Triple Copy Strategy for Value Independent Neural Dialog State Tracking](https://arxiv.org/abs/2005.02877)——基于复制的 DST 主力。
- [King, Flanigan (2024). Unsupervised End-to-End Task-Oriented Dialogue with LLMs](https://arxiv.org/abs/2404.10753)——基于 EM 的无监督 TOD。
- [MultiWOZ leaderboard](https://github.com/budzianowski/multiwoz)——规范 DST 结果。