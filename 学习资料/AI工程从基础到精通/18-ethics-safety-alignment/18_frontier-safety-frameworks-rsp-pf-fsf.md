# 前沿安全框架 — RSP、PF、FSF

> 三大实验室框架定义了 2026 年前沿能力行业治理。Anthropic Responsible Scaling Policy v3.0（2026 年 2 月）引入了分层 AI 安全级别（ASL-1 至 ASL-5+），以生物安全级别为模型，ASL-3 于 2025 年 5 月针对 CBRN 相关模型激活。OpenAI Preparedness Framework v2（2025 年 4 月）定义了追踪能力的五个标准，并将能力报告（Capabilities Reports）与安全防护报告（Safeguards Reports）分离。DeepMind Frontier Safety Framework v3.0（2025 年 9 月）引入了关键能力级别（Critical Capability Levels, CCLs），包括一个新的有害操纵（Harmful Manipulation）CCL。三者现在都包含竞争者调整条款，在同行实验室在不具备可比安全防护的情况下发布时允许推迟要求。跨实验室对齐是结构性的，而非术语性的："能力阈值（Capability Thresholds）"、"高能力阈值（High Capability thresholds）"和"关键能力级别（Critical Capability Levels）"表示类似的构造。

**类型：** 学习
**语言：** 无
**前置知识：** 第 18 阶段 · 17（WMDP），第 18 阶段 · 07-09（欺骗失败）
**时间：** 约 75 分钟

## 学习目标

- 描述 Anthropic 的 ASL 层级结构以及什么激活了 ASL-3。
- 说出 OpenAI Preparedness Framework v2 追踪能力的五个标准。
- 描述 DeepMind 的关键能力级别结构和有害操纵 CCL。
- 解释竞争者调整条款以及为什么它们对竞赛动态很重要。
- 定义安全论证并描述三大支柱结构（监控、不可执行性、无能力）。

## 问题

第 7-17 课确立了欺骗是可能的，双重用途能力存在，评估有局限。一个拥有前沿能力模型的实验室需要一个内部治理结构，它应：
- 定义何时需要新安全防护的阈值。
- 定义扩展前所需的评估。
- 描述安全论证长什么样。
- 处理竞赛动态问题（如果竞争者在没有安全防护的情况下发布，你怎么办？）。

三个 2025-2026 框架是最先进的——不完美，不断演进，跨实验室足够对齐，以至于治理问题现在是框架是否足够，而不是它们是否存在。

## 概念

### Anthropic Responsible Scaling Policy v3.0（2026 年 2 月）

ASL 结构：
- ASL-1：非前沿模型（被低于前沿基线所覆盖）。
- ASL-2：当前前沿基线；以常规安全防护部署。
- ASL-3：灾难性滥用的实质性更高风险；CBRN 相关能力。2025 年 5 月激活。
- ASL-4：AI 研发-2 交叉阈值；可以自动化入门级 AI 研究的模型。
- ASL-5+：高级 AI 研发；大幅加速有效扩展的模型。

v3.0 新增：
- 前沿安全路线图（以编辑版形式公开）。
- 风险报告（每季度，部分经外部审查）。
- AI 研发被分解为 AI 研发-2 和 AI 研发-4。
- 一旦 AI 研发-4 被跨越，需要肯定性安全论证（Affirmative Safety Case），识别来自追求不一致目标的模型的不对齐风险。

### OpenAI Preparedness Framework v2（2025 年 4 月 15 日）

追踪能力的五个标准：
- **合理（Plausible）。** 存在合理的威胁模型。
- **可测量（Measurable）。** 经验评估是可能的。
- **严重（Severe）。** 危害很大。
- **净新增（Net-new）。** 不是一个放大版本的先前风险。
- **瞬时或不可补救（Instantaneous-or-irremediable）。** 伤害发生快或无法撤销。

满足全部五个标准的能力被追踪。其他不被追踪。

PF v2 其他结构：
- 将能力报告（模型能做什么）与安全防护报告（存在什么控制）分离。
- 安全咨询组审查。
- 领导层批准；董事会安全与安全委员会监督。
- "调整条款"：如果另一实验室在不具备可比安全防护的情况下发布，OpenAI 可以降低要求。

### DeepMind Frontier Safety Framework v3.0（2025 年 9 月）

按领域的关键能力级别（CCLs）：
- 生物武器提升
- 网络提升
- ML 研发加速
- 有害操纵（v3.0 新增）：可能在高风险情境下实质性改变信念/行为的模型。

v2.0（2025 年 2 月）添加了欺骗性对齐部分并为 ML 研发 CCL 提高了安全级别。

### 跨实验室对齐

- Anthropic "能力阈值"。
- DeepMind "关键能力级别"。
- OpenAI "高能力阈值"。

没有行业标准术语。结构上对齐：三个层次的前沿能力，带有已发布评估标准。三者都包含竞争者调整条款（2025 年起）。

### 安全论证

安全论证是一份书面论证，表明部署在最坏情况假设下是可接受安全的。标准结构针对三大支柱：

- **监控。** 如果坏行为发生，我们能检测到吗？
- **不可执行性。** 模型是否缺乏执行连贯计划来造成伤害的能力？
- **无能力。** 模型是否缺乏造成所述伤害的能力？

不同安全论证针对不同支柱。对于 ASL-3 CBRN 论证，无能力（通过遗忘）是主要目标。对于欺骗性对齐，监控和不可执行性是目标。对于网络提升，三者都相关。

### 竞赛动态问题

竞争者调整条款是有争议的。批评者认为它们创造了一场逐底竞赛：如果所有三个实验室在竞争者叛变时都降低要求，均衡会向叛变转移。辩护者认为替代方案（单方面安全防护）在叛变实验室安全意识较低时产生更坏的结果。

UK AISI、US CAISI 和 EU AI Office（第 24 课）是外部治理对应方。实验室框架是自愿的；监管框架正在涌现。

### 这在第 18 阶段中的位置

第 17-18 课是欺骗和红队分析之上的度量与治理层。第 19-24 课涵盖福祉、偏见、隐私、水印和监管结构。第 28 课映射操作化评估的研究生态系统（MATS、Redwood、Apollo、METR）。

## 使用它

本课无代码。阅读三个主要来源：RSP v3.0、PF v2、FSF v3.0。将每个实验室的层级结构映射到其他实验室，并识别每个实验室定义了而其他实验室没有的一个阈值。

## 交付它

本课生成 `outputs/skill-framework-diff.md`。给定安全框架或发布说明，它将框架的阈值定义、所需评估和安全论证结构与 RSP v3.0、PF v2、FSF v3.0 进行比较，并标记跨实验室差距。

## 练习

1. 阅读 RSP v3.0、PF v2 和 FSF v3.0。编制每个实验室的 CBRN 阈值、AI 研发阈值和所需的部署前评估表格。

2. 竞争者调整条款在所有三个框架中（2025+）。写一段支持它的论述；写一段反对它的论述。识别每个立场依赖的假设。

3. 为跨越 Anthropic 的 AI 研发-4 阈值的模型设计安全论证。命名三大支柱（监控、不可执行性、无能力）各自所需的证据。

4. DeepMind 的 FSF v3.0 引入了有害操纵 CCL。提出三个经验度量，表明模型已经跨越此阈值。

5. 阅读 METR 的"Common Elements of Frontier AI Safety Policies"（2025）。指出三个最强的跨实验室趋同点和两个最大的分歧点。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|------------------------|
| RSP | "Anthropic 的框架" | 负责任扩展政策；ASL 层级；v3.0 2026 年 2 月 |
| PF | "OpenAI 的框架" | 准备框架；五个标准；v2 2025 年 4 月 |
| FSF | "DeepMind 的框架" | 前沿安全框架；CCLs；v3.0 2025 年 9 月 |
| ASL-3 | "生物安全级别 3 类比" | Anthropic 针对 CBRN 相关能力的层级；2025 年 5 月激活 |
| CCL | "关键能力级别" | DeepMind 的阈值构造；按领域 |
| Safety case | "正式论证" | 书面论证部署在最坏情况 U 下是可接受安全的 |
| Adjustment clause | "竞争者叛变容允" | 在竞争者无可比安全防护发布时降低要求的框架条款 |

## 延伸阅读

- [Anthropic — Responsible Scaling Policy v3.0 (February 2026)](https://www.anthropic.com/responsible-scaling-policy) — ASL 层级、路线图、AI 研发分解
- [OpenAI — Updating the Preparedness Framework (April 15, 2025)](https://openai.com/index/updating-our-preparedness-framework/) — 五个标准、调整条款
- [DeepMind — Strengthening our Frontier Safety Framework (September 2025)](https://deepmind.google/blog/strengthening-our-frontier-safety-framework/) — CCL v3.0、有害操纵
- [METR — Common Elements of Frontier AI Safety Policies (2025)](https://metr.org/blog/2025-03-26-common-elements-of-frontier-ai-safety-policies/) — 跨实验室比较