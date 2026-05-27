# LLM 功能 A/B 测试 — GrowthBook、Statsig 与感性判断问题

> 传统的 A/B 测试并非为非确定性 LLM 而构建。关键区别：评估回答"模型能做这项工作吗？"A/B 测试回答"用户在意吗？"两者都需要；靠感性判断发布已过时。2026 年需要测试的内容：提示工程（措辞）、模型选择（GPT-4 vs GPT-3.5 vs OSS；准确率 vs 成本 vs 延迟）、生成参数（温度（Temperature）、top-p）。真实案例：一个对话式奖励模型变体带来了 +70% 的对话长度和 +30% 的留存率；Nextdoor 的主题行实验在奖励函数优化后获得了 +1% CTR；Khan Academy Khanmigo 在延迟-vs-数学准确率轴上迭代。平台划分：**Statsig**（2025 年 9 月被 OpenAI 以 $1.1B 收购）——序列测试（Sequential Testing）、CUPED、一站式。**GrowthBook**——开源、数据仓库原生、贝叶斯（Bayesian）+ 频率论（Frequentist）+ 序列测试引擎、CUPED、SRM 检查、Benjamini-Hochberg + Bonferroni 校正。选择取决于对数据仓库-SQL 的偏好以及"被 OpenAI 收购"对你的组织是否重要。

**类型：** 学习
**语言：** Python（标准库，玩具级序列测试模拟器）
**前置知识：** 第 17 阶段 · 13（可观测性），第 17 阶段 · 20（渐进式部署）
**时间：** 约 60 分钟

## 学习目标

- 区分评估（"模型能做这项工作吗"）和 A/B 测试（"用户在意吗"）。
- 列举三个可测试的维度（提示词、模型、参数），并为每个维度选择指标。
- 解释 CUPED、序列测试（Sequential Testing）和 Benjamini-Hochberg 多重比较校正。
- 根据数据仓库-SQL 姿态和公司收购立场选择 Statsig 或 GrowthBook。

## 问题

你手动调整了一个系统提示词。感觉更好。你发布它。转化率在噪声范围内变化。你怪指标。或者你发布了一个新模型，转化率没有变化——是模型退化了还是变化太小无法检测？你不知道，因为你是未经 A/B 直接发布的。

评估回答的是模型能否在标注集上完成一项任务。它们回答不了用户是否更喜欢输出。只有受控的在线实验能回答这个问题，且前提是实验有足够的统计功效（Power）、控制非确定性并校正多重比较。

## 概念

### 评估 vs A/B 测试

**评估** — 离线，标注集，评判者（评分标准或 LLM 作为评委或人工）。回答："在这个固定分布上，输出是否正确 / 有帮助 / 安全？"

**A/B 测试** — 在线，真实用户，随机化。回答："新变体是否推动了真正重要的用户级指标？"

两者都需要。评估在暴露前捕捉回归；A/B 事后确认产品影响。

### 测试什么

1. **提示工程** — 措辞、系统提示词结构、示例。指标：任务成功率、用户留存率、成本/请求。
2. **模型选择** — GPT-4 vs GPT-3.5-Turbo vs Llama-OSS。指标：准确率（任务）+ 成本/请求 + 延迟 P99。多目标。
3. **生成参数** — 温度（Temperature）、top-p、max_tokens。指标：任务特定的（输出多样性 vs 确定性）。

### CUPED — 方差缩减

使用实验前数据的控制实验（Controlled-experiments Using Pre-Experiment Data）。在比较实验后周期之前回归掉实验前周期的方差。典型方差缩减：30-70%。有效样本量免费提高。

实现：Statsig 和 GrowthBook 都已实现。

### 序列测试

经典 A/B 假设固定样本量。序列测试（"随时查看并决定"）在反复查看下控制假阳性率。始终有效的序列过程（mSPRT、Howard 的置信序列）让你在明显优胜者出现时提前停止。

### 多重比较校正

在 95% 置信度下运行 20 个 A/B 测试，偶然产生一个假阳性。Bonferroni 校正收紧每次测试的 α；Benjamini-Hochberg 控制假发现率。GrowthBook 实现了两者。

### SRM — 样本比例不匹配

分配哈希将用户随机化到不同变体。如果 50/50 拆分变成 47/53，说明出了问题——SRM 检查标记它。两个平台都实现了。

### Statsig vs GrowthBook

**Statsig**：
- 2025 年 9 月被 OpenAI 以 $1.1B 收购。托管，SaaS。
- 序列测试、CUPED、保留人群。
- 一站式：特性开关 + 实验 + 可观测性。
- 最佳场景：团队已经想要一个捆绑产品，不在乎 OpenAI 的所有权。

**GrowthBook**：
- 开源（MIT）；数据仓库原生（直接从 Snowflake/BigQuery/Redshift 读取）。
- 多引擎：贝叶斯、频率论、序列测试。
- CUPED、SRM、Bonferroni、BH 校正。
- 自托管或托管云端。
- 最佳场景：数据仓库-SQL 团队，数据团队控制指标层，想要开源。

### 非确定性使统计功效复杂化

相同的提示词产生不同的输出。传统的功效计算假设 IID 观测。在 LLM 非确定性下，有效样本量低于名义值。将所需样本量乘以约 1.3-1.5 倍作为安全余量。

### 真实案例结果

- 对话式奖励模型变体：+70% 对话长度，+30% 留存率。
- Nextdoor 主题行：奖励函数优化后 +1% CTR。
- Khan Academy Khanmigo：迭代延迟-vs-数学准确率的权衡。

### 反模式：靠感性判断发布

每位资深工程师都能说出一个因为"感觉更好"而发布但没有 A/B 的功能。其中大多数在数月间悄然降低了团队未曾注意的产品指标。A/B 就是强制力。

### 应记住的数字

- Statsig 被 OpenAI 收购：$1.1B，2025 年 9 月。
- GrowthBook：开源 MIT；贝叶斯 + 频率论 + 序列测试。
- CUPED 方差缩减：30-70%。
- LLM 非确定性 → +30-50% 样本量缓冲。

## 使用它

`code/main.py` 模拟一个带固定和序列边界的序列 A/B 测试。展示序列方法如何让你提前停止。

## 交付它

本课生成 `outputs/skill-ab-plan.md`。根据功能变更、工作负载、基线，挑选平台、关卡和样本量。

## 练习

1. 运行 `code/main.py`。对于预期 5% 提升、基线 3% 转化率，80% 功效需要多大样本量？
2. 为一个医疗受监管的本地客户选择 Statsig 或 GrowthBook。
3. 设计一个在每解决工单成本上测试 GPT-4 vs GPT-3.5 的 A/B 测试。主要指标是什么？防护指标？次要指标？
4. 你的金丝雀通过了但 A/B 显示 -1.2% 转化率。是否发布？写出升级标准。
5. 对实验前周期方差占实验后周期方差 60% 的数据应用 CUPED。计算有效样本量增益。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|----------------|------------------------|
| Eval | "离线测试" | 在标注集上评估模型能力 |
| A/B test | "实验" | 在用户上的在线随机对比 |
| CUPED | "方差缩减" | 通过实验前周期回归来降低方差 |
| Sequential test | "可随时查看的测试" | 允许提前停止的始终有效过程 |
| Multiple comparison | "家族误差" | 运行多个测试会膨胀假阳性 |
| Bonferroni | "严格校正" | α 除以测试数量 |
| Benjamini-Hochberg | "BH FDR" | 假发现率控制，不那么保守 |
| SRM | "错误拆分" | 样本比例不匹配；分配错误 |
| Statsig | "OpenAI 所有" | 商业一站式，2025 年被收购 |
| GrowthBook | "开源那款" | MIT 数据仓库原生平台 |
| mSPRT | "序列概率比测试" | 经典序列过程 |

## 延伸阅读

- [GrowthBook — How to A/B Test AI](https://blog.growthbook.io/how-to-a-b-test-ai-a-practical-guide/)
- [Statsig — Beyond Prompts: Data-Driven LLM Optimization](https://www.statsig.com/blog/llm-optimization-online-experimentation)
- [Statsig vs GrowthBook comparison](https://www.statsig.com/perspectives/ab-testing-feature-flags-comparison-tools)
- [Deng et al. — CUPED](https://www.exp-platform.com/Documents/2013-02-CUPED-ImprovingSensitivityOfControlledExperiments.pdf)
- [Howard — Confidence Sequences](https://arxiv.org/abs/1810.08240)