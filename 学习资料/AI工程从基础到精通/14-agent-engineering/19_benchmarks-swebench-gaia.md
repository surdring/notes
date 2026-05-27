# 基准测试：SWE-bench、GAIA、AgentBench

> 三个基准测试锚定了 2026 年的代理评估。SWE-bench 测试代码补丁。GAIA 测试通用工具使用。AgentBench 测试多环境推理。了解它们的组成、污染情况以及它们不测量什么。

**类型：** 学习
**语言：** Python（标准库）
**前置条件：** Phase 14 · 06（工具使用，Tool Use）
**时间：** ~60 分钟

## 学习目标

- 列举 SWE-bench 的测试工具链（FAIL_TO_PASS）并解释为什么它通过单元测试进行把关。
- 解释为什么 SWE-bench Verified（OpenAI，500 个任务）存在以及它移除了什么。
- 描述 GAIA 的设计：对人类简单，对 AI 困难；三个难度等级。
- 列举 AgentBench 的八个环境及其对开源 LLM 的主要障碍。
- 总结 SWE-bench+ 的污染发现及其影响。

## 问题

排行榜告诉你哪个模型在一个基准测试上获胜。但不会告诉你：

- 基准测试是否被污染（训练数据中含有解决方案、测试泄漏）。
- 基准测试是否测量你关心的东西（代码 vs 浏览 vs 通用）。
- 评估器是否稳健（AST 匹配、状态检查、人工审核）。

在引用数字之前，了解这三个锚定基准测试及其失败模式。

## 概念

### SWE-bench（Jimenez 等人，ICLR 2024 oral）

- 来自 12 个流行 Python 仓库的 2,294 个真实 GitHub Issue。
- 代理获得：修复前提交版本的代码库 + 自然语言 Issue 描述。
- 代理产出：一个补丁。
- 评估器：应用补丁，运行仓库的测试套件。补丁必须使 FAIL_TO_PASS 测试翻转（之前失败，现在通过），且不破坏 PASS_TO_PASS 测试。

SWE-agent（Yang 等人，2024）在发布时达到了 12.5%，强调代理-计算机接口（文件编辑器命令、模型能理解的搜索语法）。

### SWE-bench Verified

OpenAI，2024 年 8 月。人工筛选的 500 个任务子集。移除了模糊的 Issue、不可靠的测试以及修复方案不明确的任务。这是"你的代理是否交付真实补丁？"的主要基准测试。

### 污染

- 超过 94% 的 SWE-bench Issue 在大多数模型截止日期之前就已经存在。
- **SWE-bench+** 发现 32.67% 的成功补丁在 Issue 文本中泄露了解决方案（模型在描述中看到了修复方案），31.08% 由于测试覆盖弱而存在可疑。
- Verified 更干净但不是无污染的。

实际意义：一个在 SWE-bench 上得分 50% 的模型可能在 SWE-bench+ 上只得分 35%。如果声称 SWE-bench 性能，请始终同时报告两者。

### GAIA（Mialon 等人，2023 年 11 月）

- 466 个问题；300 个保留用于私有排行榜（huggingface.co/gaia-benchmark）。
- 设计理念："对人类概念上简单（92%），但对 AI 困难（GPT-4 加插件：15%）。"
- 测试推理、多模态、Web、工具使用。
- 三个难度等级；Level 3 需要跨模态的长工具链。

GAIA 是你用来衡量"通用能力"的基准。不要与特定代码基准测试混淆。

### AgentBench（Liu 等人，ICLR 2024）

- 8 个环境，涵盖代码（Bash、DB、KG）、游戏（Alfworld、LTP）、Web（WebShop、Mind2Web）和开放式生成。
- 多轮次，每个划分约 4k-13k 轮。
- 主要发现：长期推理、决策制定和指令遵循是开源 LLM 追赶商业模型的主要障碍。

### 这些基准测试不测量什么

- 真实世界的运营成本（Token、墙钟时间）。
- 对抗条件下的安全行为。
- 在你领域上的性能（使用你自己的评估，第 30 课）。
- 尾部故障（基准测试取平均值；生产运营商关心最差的 1%）。

### 基准测试的误区

- **单一数字执着。** SWE-bench 50% 告诉你的信息少于 P50/P75/P95 成本 + 步骤分布。
- **污染声明。** 报告 SWE-bench 而不提 Verified 或 SWE-bench+ 是有误导性的。
- **将基准测试作为开发目标。** 优化基准测试会偏离生产实用性。

## 构建

`code/main.py` 实现了一个玩具级 SWE-bench 风格的工具链：

- 合成的 Bug 修复任务（3 个任务）。
- 一个脚本化的"代理"来提出补丁。
- 一个测试运行器，检查 FAIL_TO_PASS（Bug 现已修复）和 PASS_TO_PASS（没有破坏任何东西）。
- 一个基于问题分解深度的 GAIA 风格难度分类器。

运行方式：

```
python3 code/main.py
```

输出显示每个任务 + 每个难度的解决率，并具体化评估器规则。

## 使用场景

- **SWE-bench Verified** — 用于代码代理。始终报告 Verified 分数。
- **GAIA** — 用于通用代理。使用私有排行榜划分。
- **AgentBench** — 用于多环境比较。
- **自定义评估**（第 30 课）— 用于产品的实际形态。

## 部署

`outputs/skill-benchmark-harness.md` 为任何代码库-任务对构建一个 SWE-bench 风格的工具链，包含 FAIL_TO_PASS / PASS_TO_PASS 门控。

## 练习

1. 将玩具工具链移植到真实仓库（选择你自己的一个）。为已知 Bug 编写 3 个 FAIL_TO_PASS 测试。
2. 添加步骤计数指标。在你的 3 个任务上，每次解决需要多少代理步骤？
3. 阅读 SWE-bench+ 论文。实现一个解决方案泄漏检查（将 Issue 文本与 diff 进行模式匹配）。
4. 从公开划分下载一个 GAIA 问题。追踪 GPT-4 级别代理会怎么做。它需要哪些工具？
5. 阅读 AgentBench 的每个环境细分。哪个环境最贴近你的产品表面？那里的"SOTA"是什么样子的？

## 关键术语

| 术语 | 人们常说的 | 实际含义 |
|------|-----------|---------| 
| SWE-bench | "代码代理基准测试" | 2,294 个 GitHub Issue；补丁必须翻转 FAIL_TO_PASS 测试 |
| SWE-bench Verified | "清理版 SWE-bench" | 500 个人工筛选的任务，OpenAI |
| FAIL_TO_PASS | "修复门控" | 之前失败的测试在补丁后必须通过 |
| PASS_TO_PASS | "无回归门控" | 之前通过的测试必须仍然通过 |
| GAIA | "通用基准测试" | 466 个人类容易/AI 困难的多工具问题 |
| AgentBench | "多环境基准测试" | 8 个环境；长周期多轮次 |
| 污染（Contamination） | "训练集泄漏" | 基准测试任务出现在模型训练中 |
| SWE-bench+ | "污染审计" | 在成功的 SWE-bench 补丁中发现 32.67% 的解决方案泄漏 |

## 进一步阅读

- [Jimenez 等人，SWE-bench（arXiv:2310.06770）](https://arxiv.org/abs/2310.06770) — 原始基准测试
- [OpenAI，SWE-bench Verified](https://openai.com/index/introducing-swe-bench-verified/) — 筛选的子集
- [Mialon 等人，GAIA（arXiv:2311.12983）](https://arxiv.org/abs/2311.12983) — 通用基准测试
- [Liu 等人，AgentBench（arXiv:2308.03688）](https://arxiv.org/abs/2308.03688) — 多环境套件