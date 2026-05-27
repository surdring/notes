# Anthropic 的工作流模式：简单优于复杂

> Schluntz 和 Zhang（Anthropic，2024 年 12 月）区分工作流（预定义路径）和 Agent（动态工具使用）。五种工作流模式覆盖大多数情况。从直接 API 调用开始。仅在步骤无法预测时才添加 Agent。

**类型：** 学习 + 构建
**语言：** Python（标准库）
**前置要求：** Phase 14 · 01（Agent 循环）
**时间：** ~60 分钟

## 学习目标

- 说出 Anthropic 的五种工作流模式：提示词链（prompt chaining）、路由（routing）、并行化（parallelization）、编排器-工作器（orchestrator-workers）、评估器-优化器（evaluator-optimizer）。
- 解释 Agent 与工作流的区别以及各自的工程成本。
- 识别何时选择工作流而非 Agent（反之亦然）。
- 在标准库中针对脚本化 LLM 实现所有五种模式。

## 问题

团队为只需要一次函数调用的问题就引入多 Agent 框架。成本是真实存在的：框架增加了层，模糊了提示词，隐藏了控制流，并招致过早的复杂性。Schluntz 和 Zhang 2024 年 12 月的文章是被引用最多的行业反驳：从简单开始，仅当复杂性物有所值时才添加。

## 概念

### 工作流 vs Agent

- **工作流。** LLM 和工具通过预定义的代码路径编排。工程师拥有图。
- **Agent。** LLM 动态指导自己的工具并自行决策步骤。模型拥有图。

两者各有其位。工作流更便宜、更快、更容易调试。Agent 解锁开放式问题，但使故障模式更难推理。

### 增强 LLM

所有五种模式的基础：一个 LLM 连接三种能力 —— 搜索（检索）、工具（动作）、记忆（持久化）。任何 API 调用都可以使用这些。

### 五种模式

1. **提示词链。** 调用 1 的输出是调用 2 的输入。当任务有清晰的线性分解时使用。步骤之间可选程序化门控。

2. **路由。** 一个分类器 LLM 选择调用哪个下游 LLM 或工具。当类别不同的输入需要不同处理时使用（一级支持 vs 退款 vs bug vs 销售）。

3. **并行化。** 并行运行 N 个 LLM 调用，聚合结果。两种形态：分段（不同块）和投票（相同提示词，N 次运行，多数/综合）。

4. **编排器-工作器。** 一个编排器 LLM 动态决定运行哪些工作器（也是 LLM）并综合其输出。类似于 Agent 循环，但编排器不会无限循环。

5. **评估器-优化器。** 一个 LLM 提出答案，另一个 LLM 评估它。迭代直到评估器通过。这是泛化的 Self-Refine（第 05 课）。

### 工作流胜过 Agent 的场景

- **可预测的任务。** 如果你可以枚举步骤，你就应该枚举。
- **成本受限的任务。** 工作流有有界的步骤计数；Agent 可能会螺旋上升。
- **合规受限的任务。** 审计员想要读图，而非从轨迹推断。

### Agent 胜过工作流的场景

- **开放式研究。** 当下一步取决于上一步返回了什么。
- **可变长度任务。** 几分钟到几小时的工作，步骤数未知。
- **新领域。** 当你还不清楚正确的工作流时 —— 先探索，后固化。

### 上下文工程伴侣

"Effective context engineering for AI agents"（Anthropic 2025）形式化了相邻学科：200k 窗口是一个预算，而非一个容器。包含什么、何时压缩、何时让上下文增长。在 Phase 14 关于上下文压缩的课程中详细覆盖（本课程重新编号前为 Phase 14 第 6 课）。

## 构建

`code/main.py` 针对 `ScriptedLLM` 实现所有五种工作流模式：

- `prompt_chain(input, steps)` —— 顺序执行。
- `route(input, classifier, handlers)` —— 分类 + 分发。
- `parallel_vote(prompt, n, aggregator)` —— N 次运行，聚合。
- `orchestrator_workers(task, workers)` —— 编排器选择工作器。
- `evaluator_optimizer(task, proposer, evaluator, max_iter)` —— 循环直到通过。

运行：

```
python3 code/main.py
```

每种模式打印其轨迹。每种模式的总代码行数约为 10-15 行；框架的成本以千行为单位衡量。

## 使用

- 对大多数任务使用直接 API 调用。
- 仅当模式真正需要持久状态（LangGraph）、Actor 模型并发（AutoGen v0.4）或角色模板（CrewAI）时才使用框架。
- 当需要 Claude Code 实验环境形态而不想自己重建时，选择 Claude Agent SDK。

## 交付物

`outputs/skill-workflow-picker.md` 为给定任务描述选择正确的模式，包括决策理由和当工作流不足时重构为 Agent 的路径。

## 练习

1. 使用置信度阈值实现路由。低于阈值 -> 升级到人工。对于一级支持用例，阈值应设在何处？
2. 向 `parallel_vote` 添加超时。当一个调用挂起时会发生什么？如何聚合缺失的投票？
3. 将 `evaluator_optimizer` 变成一个 bandit：在迭代之间保留 top-2 输出，使一个后期的好结果不会后期差结果覆盖。
4. 将提示词链与路由结合：路由器选择三个链之一。测量令牌成本 vs 单一大提示词的替代方案。
5. 选择一个你的生产功能。绘制工作流图。计算步骤数。在这里 Agent 真的会更好吗？

## 关键术语

| 术语 | 常见说法 | 实际含义 |
|------|----------|----------|
| Workflow（工作流） | "预定义流程" | 工程师拥有的 LLM 和工具调用图 |
| Agent | "自动 AI" | 模型拥有的图；动态工具指导 |
| Augmented LLM（增强 LLM） | "带工具的 LLM" | LLM + 搜索 + 工具 + 记忆；原子单元 |
| Prompt chaining（提示词链） | "顺序调用" | 调用 N 的输出是调用 N+1 的输入 |
| Routing（路由） | "分类器分发" | 选择哪个链/模型处理输入 |
| Parallelization（并行化） | "扇出" | N 个并发调用；通过分段或投票聚合 |
| Orchestrator-workers（编排器-工作器） | "分发 Agent" | 编排器 LLM 动态选择专家 LLM |
| Evaluator-optimizer（评估器-优化器） | "提出者 + 评判者" | 迭代直到评估器通过；泛化的 Self-Refine |

## 扩展阅读

- [Anthropic, Building Effective Agents (Dec 2024)](https://www.anthropic.com/research/building-effective-agents) — 五种工作流模式
- [Anthropic, Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) — 伴侣学科
- [LangGraph overview](https://docs.langchain.com/oss/python/langgraph/overview) — 当有状态图物有所值时
- [OpenAI Agents SDK](https://openai.github.io/openai-agents-python/) — 编排器-工作器模式的产品化