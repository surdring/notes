# 对齐研究生态系统 —— MATS、Redwood、Apollo、METR

> 五个组织定义了 2026 年非实验室对齐研究层。MATS（ML Alignment & Theory Scholars）：自 2021 年末以来 527+ 名学者，180+ 篇论文，10K+ 引用，h-index 47；2024 年夏季 cohort 注册为 501(c)(3)，约 90 名学者和 40 名导师；80% 的 2025 年前校友从事安全/安全工作，200+ 名在 Anthropic、DeepMind、OpenAI、UK AISI、RAND、Redwood、METR、Apollo。Redwood Research：由 Buck Shlegeris 创立的应用对齐实验室；引入了 AI 控制（AI Control，第 10 课）；与 UK AISI 在控制安全论证上合作。Apollo Research：为前沿实验室进行部署前谋划评估（Scheming Evaluations）；撰写了上下文内谋划（In-Context Scheming，第 8 课）和 Towards Safety Cases for AI Scheming。METR（Model Evaluation and Threat Research）：基于任务的能力评估，自主任务时间跨度研究；"Common Elements of Frontier AI Safety Policies" 比较实验室框架。Eleos AI Research：模型福祉部署前评估（第 19 课）；进行了 Claude Opus 4 福祉评估。

**类型：** 学习
**语言：** 无
**前置知识：** Phase 18 · 01-27（Phase 18 之前课程）
**时间：** 约 45 分钟

## 学习目标

- 识别非实验室对齐研究生态系统的五个组织及其核心产出。
- 描述 MATS 的规模（学者、论文、h-index）及其作为人才管道的角色。
- 描述 Redwood 的 AI 控制议程及其与 UK AISI 的合作。
- 描述 METR 基于任务的评估方法论。

## 问题

前沿实验室（第 18 课）在内部产生安全评估并发布选定结果。实验室之外的生态系统是评估得到验证、新型失效模式被首次发现以及人才被培养的地方。理解该生态系统有助于解读哪些研究发现在被谁所信任。

## 概念

### MATS（ML Alignment & Theory Scholars）

始于 2021 年末。研究导师计划；学者与资深研究者一起花费 10-12 周处理特定的对齐问题。

规模（2026）：
- 自成立以来 527+ 名研究者。
- 发表 180+ 篇论文。
- 10K+ 引用。
- h-index 47。
- 2024 年夏季：90 名学者 + 40 名导师；注册为 501(c)(3)。

职业成果：约 80% 的 2025 年前校友从事安全/安全工作。200+ 名在 Anthropic、DeepMind、OpenAI、UK AISI、RAND、Redwood、METR、Apollo。

### Redwood Research

应用对齐实验室。由 Buck Shlegeris 创立。引入了 AI 控制议程（第 10 课）。与 UK AISI 在控制安全论证上合作。为 DeepMind 和 Anthropic 提供评估设计建议。

经典论文：Greenblatt, Shlegeris et al., "AI Control"（arXiv:2312.06942, ICML 2024）；对齐伪装（Alignment Faking，Greenblatt, Denison, Wright et al., arXiv:2412.14093，与 Anthropic 联合）。

风格：具体的威胁模型、最坏情况的攻击者、可经受压力测试的协议。

### Apollo Research

为前沿实验室进行部署前谋划评估。撰写了上下文内谋划（第 8 课，arXiv:2412.04984）。2025 年 OpenAI 反谋划训练合作伙伴。产出 Towards Safety Cases for AI Scheming（2024）。

风格：agent 环境下的评估，欺骗可能自然出现；三大支柱分解（不一致性、目标导向性、情境意识）。

### METR（Model Evaluation and Threat Research）

基于任务的能力评估。自主任务完成时间跨度研究。"Common Elements of Frontier AI Safety Policies"（metr.org/common-elements，2025）比较实验室框架。

与 Apollo 联合撰写 AI 谋划安全论证草图。

风格：长时间跨度的任务评估、实证能力度量、框架综合。

### Eleos AI Research

模型福祉部署前评估。进行了 Claude Opus 4 系统卡第 5.3 节记录的福祉评估。为第 19 课的福祉相关声明提供外部方法论检验。

### 人才流向

MATS 培养研究者。毕业生前往 Anthropic、DeepMind、OpenAI（实验室安全团队）或 Redwood、Apollo、METR、Eleos（外部评估）。外部评估者与实验室及 UK AISI / CAISI 合作。出版物反馈回 MATS 生态系统，供下一期 cohort 使用。

### 为何这一层很重要

单一来源的评估不可靠：实验室评估自身模型存在结构性利益冲突。外部评估者可以提出并验证实验室可能低报的失效模式。2024 年休眠代理论文（第 7 课）是 Anthropic + Redwood；对齐伪装是 Anthropic + Redwood；上下文内谋划是 Apollo；反谋划是 Apollo + OpenAI。多组织架构就是质量控制。

### 在 Phase 18 中的定位

第 7-11 课引用了 Redwood 和 Apollo 的工作；第 18 课引用了 METR 的框架比较；第 19 课引用了 Eleos。第 28 课是 Phase 其余部分所依赖的生态系统的显式组织地图。

## 实践

无代码。阅读 METR 的"Common Elements of Frontier AI Safety Policies"，作为外部综合如何为实验室内部策略工作增加价值的一个例子。

## 产出

本课产出 `outputs/skill-ecosystem-map.md`。给定一个对齐声明或评估，识别组织、发表场所和方法论风格，并与已知对应组织进行交叉检查。

## 练习

1. 从第 7-15 课选一篇论文，识别涉及的组织。将作者与 MATS 校友和当前生态系统归属进行交叉检查。

2. 阅读 METR 的"Common Elements of Frontier AI Safety Policies"。识别他们强调的三个跨实验室趋同点和两个最大分歧。

3. MATS 职业成果约 80% 是安全/安全。论证这种选择压力是适应性的（培养领域人才）还是偏见的（过滤掉非正统立场）。

4. Redwood 和 Apollo 都做控制/谋划工作，但风格不同。选择一个失效模式，描述每个组织将如何研究它。

5. Eleos AI 是唯一纯模型福祉组织。设计一个假设的第二个组织，聚焦于不同的福祉相关问题（认知自由、机器人具身等），并阐述其方法论。

## 关键术语

| 术语 | 人们常说的 | 实际含义 |
|------|-----------|---------|
| MATS | "导师计划" | ML Alignment & Theory Scholars；自 2021 年以来 527+ 名研究者 |
| Redwood Research | "控制实验室" | 应用对齐；AI Control 作者；UK AISI 合作伙伴 |
| Apollo Research | "谋划评估" | 为前沿实验室进行部署前谋划评估 |
| METR | "任务跨度评估" | 基于任务的能力评估；框架综合 |
| Eleos AI | "福祉实验室" | 模型福祉部署前评估 |
| 人才管道（Talent Pipeline） | "MATS -> 实验室" | MATS 毕业生流向 Anthropic、DM、OpenAI、Redwood、Apollo、METR |
| 外部评估（External Evaluation） | "非实验室检验" | 非模型生产者进行的评估；增加可信度 |

## 扩展阅读

- [MATS (ML Alignment & Theory Scholars)](https://www.matsprogram.org/) —— 导师计划
- [Redwood Research](https://www.redwoodresearch.org/) —— AI Control 论文
- [Apollo Research](https://www.apolloresearch.ai/) —— 谋划评估
- [METR — Common Elements of Frontier AI Safety Policies](https://metr.org/blog/2025-03-26-common-elements-of-frontier-ai-safety-policies/) —— 框架比较
- [Eleos AI Research](https://www.eleosai.org/research) —— 模型福祉方法论