# 工具使用与函数调用

> Toolformer（Schick 等人，2023）开启了自监督工具标注。Berkeley 函数调用排行榜 V4（BFCL V4, Patil 等人，2025）设定了 2026 年的标准：40% agent 化（agentic）、30% 多轮（multi-turn）、10% 实时（live）、10% 非实时（non-live）、10% 幻觉（hallucination）。单轮已解决。记忆、动态决策和长链条工具调用尚未解决。

**类型：** 构建
**语言：** Python（标准库）
**前置要求：** Phase 14 · 01（Agent 循环），Phase 13 · 01（函数调用深入解析）
**时间：** ~60 分钟

## 学习目标

- 解释 Toolformer 的自监督训练信号：仅当执行工具的结果能降低下一个令牌的损失时才保留工具标注。
- 说出 BFCL V4 的五个评估类别以及每类衡量什么。
- 实现一个带有 schema 验证、参数转换和执行沙箱化的标准库工具注册表。
- 诊断三个 2026 年未解决问题：长视野工具链、动态决策和记忆。

## 问题

早期工具使用问的是：模型能否预测正确的函数调用？现代工具使用问的是：模型能否在 40 步中链接工具，带记忆，带部分可观测性，能从工具失败中恢复，不幻觉调用不存在的工具？

Toolformer 建立了基线：模型可以通过自监督学习何时调用工具。BFCL V4 定义了 2026 年评估目标。两者之间的差距就是生产级 Agent 活动的空间。

## 概念

### Toolformer（Schick 等人，NeurIPS 2023）

思想：让模型在自己的预训练语料上标注候选 API 调用。对每个候选，执行它。仅当包含工具结果降低了下一个令牌的损失时才保留标注。在过滤后的语料上微调。

覆盖的工具：计算器、QA 系统、搜索引擎、翻译器、日历。自监督信号纯粹是关于工具是否有助于预测文本 —— 没有人工标签。

规模结果：工具使用在大规模上涌现。较小的模型在工具标注上受损；较大的模型受益。这就是为什么 2026 年前沿模型内置了强大的工具使用能力，而大多数 7B 模型需要显式的工具使用微调才能可靠。

### Berkeley 函数调用排行榜 V4（BFCL V4, Patil 等人，ICML 2025）

BFCL 是 2026 年的事实评估标准。V4 组成：

- **Agent 化（40%）** —— 完整的 Agent 轨迹：记忆、多轮、动态决策。
- **多轮（30%）** —— 带工具链的交互对话。
- **实时（10%）** —— 用户提交的真实提示词（更难的分发）。
- **非实时（10%）** —— 合成测试用例。
- **幻觉（10%）** —— 检测何时不应调用工具。

V3 引入了基于状态的评估：在工具序列之后，检查 API 的实际状态（如"文件是否已创建？"），而非匹配工具调用的 AST。V4 添加了网络搜索、记忆和格式敏感类别。

关键 2026 年发现：单轮函数调用已接近解决。失败集中在记忆（跨轮次携带上下文）、动态决策（根据先前结果选择工具）、长视野链条（20+ 步后漂移）和幻觉检测（在没有适用工具时拒绝调用）。

### 工具 schema

每个提供商都有一个 schema。它们在细节上有所不同，但共享相同的形态：

```
name: string
description: string（做什么，何时使用它）
input_schema: JSON Schema（properties, required, types, enums）
```

Anthropic 直接使用 `input_schema`。OpenAI 使用 `function.parameters`。两者都接受 JSON Schema。描述承载着关键作用 —— 模型通过阅读描述来选择正确的工具。糟糕的工具描述是选错工具失败的头号根本原因。

### 参数验证

不要信任任何工具调用。验证：

1. **类型转换。** 模型可能返回字符串 "5"，而 schema 说是 int。如果不模糊则转换；如果模糊则拒绝。
2. **枚举验证。** 如果 schema 规定 `status in {"open", "closed"}` 而模型发出 `"in_progress"`，用描述性错误拒绝。
3. **必填字段。** 缺少必填字段 -> 立即将错误观察反馈给模型，而非崩溃。
4. **格式验证。** 日期、电子邮件、URL —— 用具体的解析器而非正则表达式验证。

每个验证失败都应返回一个结构化的观察，以便模型可以用正确的形态重试。

### 并行工具调用

现代提供商支持在一个助手轮次中进行并行工具调用。循环：

1. 模型发出 3 个带有不同 `tool_use_id` 的工具调用。
2. 运行时执行它们（如果独立则并行执行）。
3. 每个结果作为 `tool_result` 块返回，通过 `tool_use_id` 关联。

工程规则：将关联 ID 视为承载核心作用的关键因素。交换它们会导致错误的工具到错误结果的路由。

### 沙箱化

工具执行是沙箱边界。详见第 09 课。简短版本：每个工具应指定读/写面、网络访问、超时、内存上限。通用的 `run_shell(cmd)` 是红色标志；具体的 `git_status()` 更安全。

## 构建

`code/main.py` 实现了一个生产形态的工具注册表：

- JSON Schema 子集验证器（仅标准库）。
- 带描述、输入 schema、超时和执行器的工具注册。
- 参数转换和枚举验证。
- 带关联 ID 的并行工具分发。
- 结构化字符串格式的错误观察。

运行：

```
python3 code/main.py
```

轨迹显示一个微型 Agent 在一个轮次中调用三个工具，其中一个故意格式错误，被带有描述性错误的拒绝，模型可以据此行动。

## 使用

每个提供商都有自己的工具 schema —— Anthropic、OpenAI、Gemini、Bedrock。如果需要多提供商，使用转换层（OpenAI Agents SDK、Vercel AI SDK、LangChain tool adapter）。BFCL 是参考基准 —— 如果工具使用对产品至关重要，在发布前对 Agent 运行它。

## 交付物

`outputs/skill-tool-registry.md` 为给定的任务领域生成工具目录、schema 和注册表。包括描述质量检查（每个工具的描述是否告诉模型何时使用它？）。

## 练习

1. 添加一个"无操作"工具，让模型显式拒绝使用任何其他工具。在 BFCL 类幻觉测试上测量效果。
2. 为 int-as-string 和 float-as-string 实现参数转换。转换在哪一点开始隐藏真正的 bug？
3. 添加每个工具的超时和熔断器（连续 3 次失败后拒绝该工具 60 秒）。这如何改变模型的恢复方式？
4. 阅读 BFCL V4 描述。选择一个类别（如"多轮"），并通过你的 Agent 运行 10 个示例提示词。报告通过率。
5. 将标准库验证器移植到 Pydantic 或 Zod。Pydantic/Zod 捕获了什么玩具遗漏的东西？

## 关键术语

| 术语 | 常见说法 | 实际含义 |
|------|----------|----------|
| Function calling（函数调用） | "工具使用" | 带验证 schema 的结构化输出工具调用 |
| Toolformer | "自监督工具标注" | Schick 2023 —— 保留其执行结果能降低下一令牌损失的工具调用 |
| BFCL | "Berkeley 函数调用排行榜" | 2026 基准：40% agentic, 30% multi-turn, 10% live, 10% non-live, 10% hallucination |
| Tool schema（工具 schema） | "给模型的函数签名" | 名称、描述、参数的 JSON Schema |
| tool_use_id | "关联 ID" | 将工具调用与其结果绑定；对并行分发至关重要 |
| Hallucination detection（幻觉检测） | "知道何时不调用" | V4 类别：当没有适用工具时拒绝 |
| Argument coercion（参数转换） | "字符串到整数的修复" | 对可预测的 schema 不匹配进行窄修复；模糊时拒绝 |
| Sandboxing（沙箱化） | "工具执行边界" | 每个工具的读/写面、网络、超时、内存上限 |

## 扩展阅读

- [Schick et al., Toolformer (arXiv:2302.04761)](https://arxiv.org/abs/2302.04761) — 自监督工具标注
- [Berkeley Function Calling Leaderboard (V4)](https://gorilla.cs.berkeley.edu/leaderboard.html) — 2026 评估基准
- [Anthropic, Tool use documentation](https://platform.claude.com/docs/en/agent-sdk/overview) — Claude Agent SDK 中的生产工具 schema
- [OpenAI Agents SDK docs](https://openai.github.io/openai-agents-python/) — 函数工具类型和 Guardrails