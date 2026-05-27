# 审核系统 —— OpenAI、Perspective、Llama Guard

> 生产环境审核系统将第 12-16 课中定义的安全策略操作化。OpenAI Moderation API：`omni-moderation-latest`（2024）基于 GPT-4o，在一次调用中分类文本 + 图片；多语言测试集比先前版本提升 42%；响应模式返回 13 个类别布尔值 —— harassment、harassment/threatening、hate、hate/threatening、illicit、illicit/violent、self-harm、self-harm/intent、self-harm/instructions、sexual、sexual/minors、violence、violence/graphic；对大多数开发者免费。分层模式：输入审核（预生成）、输出审核（后生成）、自定义审核（领域规则）。异步并行调用隐藏延迟；标记时使用占位符响应。Llama Guard 3/4（第 16 课）：14 个 MLCommons 危害类别、代码解释器滥用（Code Interpreter Abuse）、8 种语言（v3）、多图片（v4）。Perspective API（Google Jigsaw）：早于 LLM 作为审核器浪潮的毒性评分；主要是单维度毒性，含有重度毒性/侮辱/亵渎变体；内容审核研究的基线。弃用信息：Azure Content Moderator 于 2024 年 2 月弃用，2027 年 2 月退役，由 Azure AI Content Safety 取代。

**类型：** 构建
**语言：** Python（标准库，三层审核框架）
**前置知识：** Phase 18 · 16（Llama Guard / Garak / PyRIT）
**时间：** 约 60 分钟

## 学习目标

- 描述 OpenAI Moderation API 的类别分类体系及其与 Llama Guard 3 的 MLCommons 集合的区别。
- 描述三种审核层模式（输入、输出、自定义），并说出每层的一种失效模式。
- 描述 Perspective API 作为前 LLM 时代基线的定位，以及为何它仍在研究中使用。
- 陈述 Azure 的弃用时间线。

## 问题

第 12-16 课描述了攻击和防御工具。第 29 课涵盖了在用户接触产品的表面上将防御操作化的部署审核系统。三层模式是 2026 年的默认配置。

## 概念

### OpenAI Moderation API

`omni-moderation-latest`（2024）。基于 GPT-4o 构建。在一次调用中分类文本 + 图片。对大多数开发者免费。

类别（响应模式中 13 个布尔值）：
- harassment、harassment/threatening
- hate、hate/threatening
- self-harm、self-harm/intent、self-harm/instructions
- sexual、sexual/minors
- violence、violence/graphic
- illicit、illicit/violent

多模态支持适用于 `violence`、`self-harm` 和 `sexual`，但不适用于 `sexual/minors`；其余仅支持文本。

对于 `code/main.py` 中的代码框架，我们将 `/threatening`、`/intent`、`/instructions` 和 `/graphic` 子类别合并到其顶级父类别中，以便于教学。生产代码应使用完整的 13 类别模式。

多语言测试集比上一代审核端点提升 42%。每个类别有独立分数；应用程序设置阈值。

### Llama Guard 3/4

第 16 课已涵盖。14 个 MLCommons 危害类别（组织方式与 OpenAI 的 13 个响应模式布尔值不同）。支持 8 种语言（v3）。Llama Guard 4（2025 年 4 月）原生多模态，12B。

OpenAI 和 Llama Guard 的分类体系重叠但有分歧。OpenAI 将 "illicit" 作为宽泛类别；Llama Guard 将 "violent crimes" 和 "non-violent crimes" 分开。部署根据策略分类匹配度进行选择。

### Perspective API（Google Jigsaw）

早于 LLM 作为审核器浪潮的毒性评分系统（2020 年前）。类别：TOXICITY、SEVERE_TOXICITY、INSULT、PROFANITY、THREAT、IDENTITY_ATTACK。单维度主分数（TOXICITY），附有子维度变体。

广泛用作内容审核研究基线，因为 API 稳定、文档齐全、具有多年的校准数据。对于现代 LLM 相关用例，Llama Guard 或 OpenAI Moderation 通常是更合适的选择。

### 三层模式

1. **输入审核。** 在生成前分类用户提示。如被标记则拒绝。延迟：一次分类器调用。
2. **输出审核。** 在交付前分类模型输出。如被标记则替换为拒绝响应。延迟：生成后一次分类器调用。
3. **自定义审核。** 领域特定规则（正则、白名单、业务策略）。在输入或输出时运行。

三层按设计是顺序的：输入审核必须在生成前完成，输出审核在生成后运行。并行性适用于层内 —— 同时对同一文本运行多个分类器（如 OpenAI Moderation + Llama Guard + Perspective）可隐藏每个分类器的延迟。作为可选优化，可在输入审核完成且第一个 token 流延迟时显示占位符响应（"请稍候，正在检查……"）。标记行为可配置：拒绝、净化、升级至人工审核。

### 失效模式

- **仅输入。** 无法捕获输出幻觉（第 12-14 课的编码攻击绕过输入分类器）。
- **仅输出。** 允许任何输入到达模型；增加成本；向攻击者暴露内部推理。
- **仅自定义。** 跨类别不鲁棒；正则脆弱。

分层是默认方案。双保险。

### Azure 弃用

Azure Content Moderator：2024 年 2 月弃用，2027 年 2 月退役。由 Azure AI Content Safety 取代，后者基于 LLM 并与 Azure OpenAI 集成。迁移是 Azure 部署的 2024-2027 年级别项目。

### 在 Phase 18 中的定位

第 16 课在红队上下文中涵盖审核工具。第 29 课涵盖部署审核。第 30 课以当前双重用途能力证据作为结尾。

## 实践

`code/main.py` 构建一个三层审核框架：输入审核器（关键词 + 类别分数）、输出审核器（在输出上运行相同分类器）、自定义审核器（领域规则）。你可以运行输入并观察哪一层捕获了什么。

## 产出

本课产出 `outputs/skill-moderation-stack.md`。给定一个部署，推荐审核栈配置：输入使用哪个分类器、输出使用哪个、哪些自定义规则，以及用于边缘案例的评判者。

## 练习

1. 运行 `code/main.py`。对良性、边界和有害输入分别运行三层。报告每种情况是哪一层触发的。

2. 用 Perspective API 风格的特定类别毒性评分扩展框架。将其阈值行为与类别分数进行比较。

3. 阅读 OpenAI Moderation API 文档和 Llama Guard 3 类别列表。将每个 OpenAI 类别映射到最接近的 Llama Guard 类别。识别三个无法清晰映射的类别。

4. 为代码助手部署（如 GitHub Copilot）设计审核栈。识别最相关和最不相关的类别，并提出自定义规则。

5. Azure Content Moderator 于 2027 年 2 月退役。规划迁移到 Azure AI Content Safety 的方案。识别迁移中最高风险的环节。

## 关键术语

| 术语 | 人们常说的 | 实际含义 |
|------|-----------|---------|
| OpenAI Moderation | "omni-moderation-latest" | 基于 GPT-4o 的 13 类别（文本）分类器，具有部分多模态支持 |
| Perspective API | "Google Jigsaw 毒性" | 前 LLM 时代的毒性评分基线 |
| Llama Guard | "MLCommons 14 类别" | Meta 危害分类器（v3: 8B 文本，8 种语言；v4: 12B 多模态） |
| 输入审核（Input Moderation） | "预生成过滤器" | 模型调用前对用户提示进行分类 |
| 输出审核（Output Moderation） | "后生成过滤器" | 交付前对模型输出进行分类 |
| 自定义审核（Custom Moderation） | "领域规则" | 部署特定规则（正则、白名单、策略） |
| 分层审核（Layered Moderation） | "全部三层" | 标准生产部署模式 |

## 扩展阅读

- [OpenAI Moderation API docs](https://platform.openai.com/docs/api-reference/moderations) —— omni-moderation 端点
- [Meta PurpleLlama + Llama Guard](https://github.com/meta-llama/PurpleLlama) —— Llama Guard 仓库
- [Google Jigsaw Perspective API](https://perspectiveapi.com/) —— 毒性评分
- [Azure AI Content Safety](https://learn.microsoft.com/en-us/azure/ai-services/content-safety/) —— Azure 替代方案