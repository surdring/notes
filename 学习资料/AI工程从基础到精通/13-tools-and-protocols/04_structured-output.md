# 结构化输出 —— JSON Schema、Pydantic、Zod、约束解码

> "客气地请模型返回 JSON"在前沿模型上仍有 5% 到 15% 的失败率。结构化输出（Structured Outputs）通过约束解码（Constrained Decoding）弥合了这一差距：模型被字面上阻止输出任何会违反 Schema 的 Token。OpenAI 的严格模式、Anthropic 的 Schema 类型化工具使用、Gemini 的 `responseSchema`、Pydantic AI 的 `output_type` 和 Zod 的 `.parse` 是同一理念的五种表面形态。本课构建 Schema 验证器和严格模式契约，学习者将把它用于每个生产级数据提取管道。

**类型：** 构建
**语言：** Python（标准库，JSON Schema 2020-12 子集）
**前置知识：** Phase 13 · 02（函数调用深入剖析）
**时间：** ~75 分钟

## 学习目标

- 为数据提取目标编写一个 JSON Schema 2020-12，使用正确的约束（enum、min/max、required、pattern）。
- 解释为什么严格模式和约束解码提供与"生成后验证"不同的保障。
- 区分三种失败模式：解析错误、Schema 违规、模型拒绝。
- 交付一个带类型化修复和类型化拒绝处理的数据提取管道。

## 问题

一个读取采购订单邮件的 Agent 需要将自由文本转换为 `{customer, line_items, total_usd}`。三种方法。

**方法一：提示模型输出 JSON。** "以 JSON 格式回复，字段为 customer、line_items、total_usd。"在前沿模型上有 85% 到 95% 的成功率。以六种方式失败：缺少大括号、多余逗号、类型错误、幻想的字段、在 Token 限制处截断、泄露如"这是你的 JSON："之类的散文。

**方法二：生成后验证。** 自由生成，解析，对照 Schema 验证，失败时重试。可靠但昂贵——你需要为每次重试付费，且截断 bug 每次出现要额外消耗一个回合。

**方法三：约束解码。** 提供商在解码时强制 Schema。无效 Token 从采样分布中被屏蔽。输出保证能够解析，且保证能够通过验证。失败模式塌缩为一种：拒绝（模型判定输入不适合该 Schema）。

每一个 2026 年前沿提供商都提供了方法三的某种形式。

- **OpenAI。** `response_format: {type: "json_schema", strict: true}` 加上响应中的 `refusal`（如果模型拒绝的话）。
- **Anthropic。** `tool_use` 输入上的 Schema 强制；`stop_reason: "refusal"` 不存在，但 `end_turn` 且没有工具调用就是信号。
- **Gemini。** 请求级的 `responseSchema`；2026 年 Gemini 对选定类型提供了 Token 级语法约束。
- **Pydantic AI。** `output_type=InvoiceModel` 生成一个类型化为 `InvoiceModel` 的结构化 `RunResult`。
- **Zod（TypeScript）。** 运行时解析器，对照 Zod Schema 验证提供商输出；配合 OpenAI 的 `beta.chat.completions.parse` 使用。

共同线索：声明一次 Schema，端到端强制执行。

## 核心概念

### JSON Schema 2020-12 —— 通用语言

每个提供商都接受 JSON Schema 2020-12。你最常使用的构造：

- `type`：`object`、`array`、`string`、`number`、`integer`、`boolean`、`null` 之一。
- `properties`：字段名到子 Schema 的映射。
- `required`：必须出现的字段名列表。
- `enum`：允许值的封闭集合。
- `minimum` / `maximum`（数字），`minLength` / `maxLength` / `pattern`（字符串）。
- `items`：应用于每个数组元素的子 Schema。
- `additionalProperties`：`false` 禁止额外字段（默认值因模式而异）。

OpenAI 严格模式增加了三个要求：每个属性都必须列在 `required` 中、所有地方 `additionalProperties: false`、以及不能有未解析的 `$ref`。如果你违反这些规则，API 在请求时会返回 400。

### Pydantic，Python 绑定

Pydantic v2 通过 `model_json_schema()` 从数据类形态的模型生成 JSON Schema。Pydantic AI 包装了这一点，使你可以这样写：

```python
class Invoice(BaseModel):
    customer: str
    line_items: list[LineItem]
    total_usd: Decimal
```

Agent 框架在边缘将 Schema 翻译为 OpenAI 严格模式、Anthropic 的 `input_schema` 或 Gemini 的 `responseSchema`。模型的输出以类型化的 `Invoice` 实例返回。验证错误会抛出带有类型化错误路径的 `ValidationError`。

### Zod，TypeScript 绑定

Zod（`z.object({customer: z.string(), ...})`）是 TypeScript 的等价物。OpenAI 的 Node SDK 暴露了 `zodResponseFormat(Invoice)`，它会翻译为 API 的 JSON Schema 负载。

### 拒绝（Refusals）

严格模式不能强迫模型回答。如果输入无法匹配 Schema（"这封邮件是一首诗，不是发票"），模型会发出一个包含原因的 `refusal` 字段。你的代码必须将其作为一等结果来处理，而非失败。拒绝也作为安全信号很有用：一个被要求从受保护内容邮件中提取信用卡号的模型会返回带有安全原因的拒绝。

### 开放环境下的约束解码

开放权重实现使用三种技术。

1. **基于语法的解码（Grammar-Based Decoding）**（`outlines`、`guidance`、`lm-format-enforcer`）：从 Schema 构建确定性有限自动机（DFA）；在每一步中，屏蔽会违反 FSM 的 Token 的 logits。
2. **使用 JSON 解析器的 Logit 屏蔽**：与模型同步运行一个流式 JSON 解析器；在每一步中计算合法的下一 Token 集合。
3. **带验证器的投机解码（Speculative Decoding with Verifier）**：廉价的草稿模型提议 Token，验证器强制 Schema。

商业提供商在背后选择其中一种技术。2026 年的最先进水平是：对于短结构化输出比纯生成更快，对于长结构化输出速度大致相同。

### 三种失败模式

1. **解析错误（Parse Error）。** 输出不是有效的 JSON。在严格模式下不可能发生。在非严格提供商上仍可能发生。
2. **Schema 违规（Schema Violation）。** 输出能够解析但违反 Schema。在严格模式下不可能发生。在其他情况下常见。
3. **拒绝（Refusal）。** 模型拒绝。必须作为类型化结果处理。

### 重试策略

当你在严格模式之外时（Anthropic 工具使用、非严格 OpenAI、旧版 Gemini），恢复模式为：

```
generate -> parse -> validate -> if fail, inject error and retry, max 3x
```

一次重试通常足够。三次重试可以捕捉弱模型的偶然故障。超过三次表明 Schema 有问题：模型无法为某些输入满足它，需要修复提示词或 Schema。

### 小模型支持

约束解码适用于小模型。一个启用了语法强制的 3B 参数开放模型在结构化任务上的表现优于 70B 参数模型的原始提示。这是结构化输出对生产至关重要的主要原因：它将可靠性与模型大小解耦。

## 使用它

`code/main.py` 用标准库提供了一个最小的 JSON Schema 2020-12 验证器（types、required、enum、min/max、pattern、items、additionalProperties）。它包装了一个 `Invoice` Schema，并将一个假的 LLM 输出通过验证器运行，演示了解析错误、Schema 违规和拒绝路径。在生产中可将假输出替换为任何提供商的真实响应。

需要关注的点：

- 验证器返回一个带路径和消息的类型化 `[ValidationError]` 列表。这是你想要呈现给重试提示词的形态。
- 拒绝分支不会重试。它记录日志并返回一个类型化的拒绝。Phase 14 · 09 将拒绝作为安全信号使用。
- 对抗性测试输入上触发了 `additionalProperties: false` 检查，展示了为什么严格模式关闭了幻想字段的大门。

## 交付成果

本课产出 `outputs/skill-structured-output-designer.md`。给定一个自由文本提取目标（发票、支持工单、简历等），该技能生成一个兼容严格模式的 JSON Schema 2020-12 和一个镜像化的 Pydantic 模型，并带有类型化拒绝和重试处理的存根。

## 练习

1. 运行 `code/main.py`。添加第四个测试用例，其 `total_usd` 是负数。确认验证器通过 `minimum` 约束路径拒绝它。

2. 扩展验证器以支持带鉴别器（Discriminator）的 `oneOf`。常见情况：`line_item` 是产品或服务，通过 `kind` 标记。严格模式对此有细微的规则；查阅 OpenAI 的结构化输出指南。

3. 将相同的 Invoice Schema 写为 Pydantic BaseModel，比较 `model_json_schema()` 输出与你手写的 Schema。找出 Pydantic 默认设置而手写版本省略的一个字段。

4. 测量拒绝率。构造十个不应该能够提取的输入（一句歌词、一个数学证明、一封空白邮件），通过真实提供商以严格模式运行。统计拒绝 vs 幻想的输出。这是你用于拒绝感知重试的真实基准。

5. 从头到尾阅读 OpenAI 的结构化输出指南。找出它明确禁止在严格模式中使用、而纯 JSON Schema 允许的一个构造。然后设计一个非必要使用该禁止构造的 Schema，并将其重构为兼容严格模式。

## 关键术语

| 术语 | 人们的说法 | 实际含义 |
|------|----------------|------------------------|
| JSON Schema 2020-12 | "Schema 规范" | 每个现代提供商都使用的 IETF 草案 Schema 方言 |
| 严格模式（Strict Mode） | "保证 Schema 合规" | OpenAI 标志，通过约束解码强制 Schema |
| 约束解码（Constrained Decoding） | "Logit 屏蔽" | 解码时强制，屏蔽无效的下一个 Token |
| 拒绝（Refusal） | "模型拒绝" | 当输入无法匹配 Schema 时的类型化结果 |
| 解析错误（Parse Error） | "无效的 JSON" | 输出未被解析为 JSON；在严格模式下不可能 |
| Schema 违规（Schema Violation） | "错误的形状" | 已解析但违反 types / required / enum / range |
| `additionalProperties: false` | "不允许额外字段" | 禁止未知字段；OpenAI 严格模式下必需 |
| Pydantic BaseModel | "类型化输出" | 发出并验证 JSON Schema 的 Python 类 |
| Zod Schema | "TypeScript 输出类型" | 用于提供商输出验证的 TypeScript 运行时 Schema |
| 语法强制（Grammar Enforcement） | "开放权重约束解码" | 基于 FSM 的 Logit 屏蔽，见于 outlines / guidance 等工具 |

## 延伸阅读

- [OpenAI — Structured outputs](https://platform.openai.com/docs/guides/structured-outputs) —— 严格模式、拒绝和 Schema 要求
- [OpenAI — Introducing structured outputs](https://openai.com/index/introducing-structured-outputs-in-the-api/) —— 2024 年 8 月发布博文，解释解码保障
- [Pydantic AI — Output](https://ai.pydantic.dev/output/) —— 序列化到每个提供商的类型化 output_type 绑定
- [JSON Schema — 2020-12 release notes](https://json-schema.org/draft/2020-12/release-notes) —— 规范原文
- [Microsoft — Structured outputs in Azure OpenAI](https://learn.microsoft.com/en-us/azure/foundry/openai/how-to/structured-outputs) —— 企业部署说明和严格模式注意事项