# 自主编码代理格局（2026）

> SWE-bench Verified 在不到三年内从 4% 升至 80.9%。同样的 Claude Sonnet 4.5 在 SWE-agent v1 上得了 43.2%，在 Cline 自主模式下得了 59.8%——围绕模型的脚手架现在与模型本身同等重要。OpenHands（前身 OpenDevin）是最活跃的 MIT 许可平台，其 CodeAct 循环直接在沙箱中执行 Python 操作而非 JSON 工具调用。头条数字隐藏了一个方法论问题：500 个 SWE-bench Verified 任务中有 161 个只需要 1-2 行更改，而 SWE-bench Pro（10+ 行任务）对于相同的前沿模型只停留在 23-59%。

**类型：** 学习
**语言：** Python（标准库，CodeAct vs JSON 工具调用比较）
**前置条件：** Phase 14 · 07（工具使用），Phase 15 · 01（长周期代理）
**时间：** ~45 分钟

## 问题

"哪个编码代理最好"是错误的问题。正确的问题是：在匹配我工作内容的任务分布上，用我在生产中运行的脚手架，我能得到什么端到端可靠性？

在 2022 年至 2026 年间，该领域学到了脚手架——检索层、规划器、沙箱、编辑-验证循环、反馈格式——是承重的。Claude Sonnet 4.5 在 SWE-agent v1 上在 SWE-bench Verified 得 43.2%；同一模型在 Cline 自主脚手架内得 59.8%。16.6 个绝对点数的差异，相同的权重。基础模型是一个组件；循环是产品。

伴随的问题是基准测试饱和掩盖了回退。SWE-bench Verified 接近饱和，简单任务尾部（500 个任务中有 161 个需要 ≤2 行）拉高了顶部分数。真实世界的质量更适合在 SWE-bench Pro（10+ 行更改）等分布上测量，在那里相同的领先者在 23-59% 之间。

## 概念

### SWE-bench，一段话

SWE-bench（Jimenez 等人）取真实的带 ground-truth 补丁的 GitHub issue，要求代理生成一个使测试套件通过的补丁。SWE-bench Verified（OpenAI，2024）是一个人工整理的 500 任务子集，移除了模糊和破损的任务。SWE-bench Pro 是更难的继任者——需要 10+ 行更改的任务，当前前沿代理在此得分在 23-59% 之间。

### 2022 → 2026 曲线实际展示了什么

- **2022**：研究模型在原始 SWE-bench 上约 4%。
- **2024**：GPT-4 + Devin 风格脚手架约 14%；SWE-agent 约 12%。
- **2025**：Claude 3.5/3.7 Sonnet 在 Aider 和 SWE-agent 内推入 40-55% 范围。
- **2026**：Claude Sonnet 4.5 和前沿竞争者在 SWE-bench Verified 上达到 70-80%+。Epoch AI 的排行榜实时跟踪这一点。

斜率来自三个复合来源：更好的基础模型、更好的脚手架（CodeAct、反思、验证器循环）和更好的基准测试（Verified 移除噪声）。

### CodeAct vs JSON 工具调用

OpenHands（All-Hands-AI，arXiv:2407.16741，前 OpenDevin）采取了一个特定的架构赌注：不是模型发出 JSON 工具调用让主机解码和执行，而是模型发出 Python 代码，Jupyter 风格内核在沙箱中运行它。代理可以在一个操作中循环遍历文件、链式调用工具并捕获自己的异常。

权衡：

- **JSON 工具调用**：每个操作是一轮；容易审计；有限的可组合性；默认安全，因为每个调用通过显式验证器。
- **CodeAct**：一个操作可以是整个程序；可组合的；需要加固的沙箱（OpenHands 使用 Docker 隔离）；失败模式包括沙箱运行时允许的任何操作。

两种架构都在生产中。CodeAct 在开放平台（OpenHands、smolagents）中占主导。JSON 工具调用在托管服务（Anthropic Managed Agents、OpenAI Assistants）中仍然占主导，其中提供商控制执行器。

### 2026 年格局中的脚手架

| 脚手架 | 许可证 | 执行模型 | 显著属性 |
|-------|--------|---------|---------|
| OpenHands（OpenDevin） | MIT | Docker 中的 CodeAct | 最活跃的开放平台；事件流可重放 |
| SWE-agent | MIT | Agent-Computer Interface（ACI） | 首个端到端 SWE-bench 脚手架 |
| Aider | Apache-2 | 本地仓库的 diff 编辑 | 最小脚手架，强大的回退稳定性 |
| Cline | Apache-2 | 带工具策略的 VS Code 代理 | Sonnet 4.5 上得分最高的开放脚手架 |
| Devin（Cognition） | 专有 | 托管 VM + 规划器 | 首个"AI 软件工程师"产品类别 |
| Claude Code | 专有 | 权限模式 + 例行任务 | 第 10 课详细覆盖代理循环 |

### 为什么脚手架占主导

编码运行是一个长周期轨迹（第 1 课）。可靠性跨步骤复合。脚手架获取分数的三个地方：

1. **检索**：找到正确的文件是无声的瓶颈。SWE-agent 的 ACI、OpenHands 的文件索引和 Aider 的仓库映射都针对这一点。
2. **验证器循环**：运行测试、读取堆栈追踪和重试是 SWE-bench 上 10+ 点的增量。
3. **失败遏制**：错误时回滚的沙箱防止复合损害。有和没有验证器循环的相同模型看起来像两个不同的产品。

### 基准测试饱和与真实分布

OpenHands 作者和 Epoch AI 都标记了 SWE-bench Verified 有一个简单任务尾部：500 个任务中有 161 个只需要 1-2 行更改。高分部分被此尾部驱动。SWE-bench Pro 限制为 10+ 行更改，即使对于前沿系统，分数也在 23-59% 范围内。你的生产分布几乎肯定更接近 Pro 而非 Verified。

选择代理的含义：运行你自己 bug 积压的 Pro 式子集。重要的分数是代表你交付内容的任务上的分数。

## 使用场景

`code/main.py` 在固定迷你任务分布上比较两个玩具代理脚手架：

1. **JSON 工具调用**脚手架，每轮采取一个操作。
2. **CodeAct**脚手架，每个操作可以发出一个小 Python 片段。

两者使用存根"模型"（确定性规则），因此比较将脚手架与模型质量隔离。输出显示 CodeAct 脚手架在更少轮次中解决更多任务，代价是更大的每次操作影响范围。

## 部署

`outputs/skill-scaffold-audit.md` 帮助你在采用前审计提议的编码代理脚手架：检索质量、验证器存在、沙箱隔离和基准测试到分布的匹配。

## 练习

1. 运行 `code/main.py`。每个脚手架在相同任务集上需要多少轮次？每个的每次操作影响范围是多少？

2. 阅读 OpenHands 论文（arXiv:2407.16741）。论文论证 CodeAct 在复杂任务上击败 JSON 工具调用。识别论文承认的一个失败模式，并写一句话说明该模式在生产中何时会占主导。

3. 从你的 bug 积压中选一个需要跨两个文件 10+ 行更改的任务。估算前沿模型在 (a) JSON 工具调用和 (b) CodeAct 下的端到端成功概率。为差距提供理由。

4. SWE-bench Verified 有 161 个单文件、1-2 行任务。构建一个排除它们的分数。排行榜如何重新洗牌？

5. 阅读"Introducing SWE-bench Verified"（OpenAI）。解释用于移除模糊任务的具体方法论，并指出该整理会遗漏的一个类别。

## 关键术语

| 术语 | 人们常说的 | 实际含义 |
|------|-----------|---------|
| SWE-bench | "编码基准测试" | 真实的带 ground-truth 补丁和测试套件的 GitHub issue |
| SWE-bench Verified | "清理后的子集" | 500 个人工整理的任务，存在简单任务尾部 |
| SWE-bench Pro | "更难子集" | 10+ 行更改；前沿在 23-59% 之间 |
| CodeAct | "代码即操作" | 代理发出 Python；Jupyter 风格内核在沙箱中执行 |
| JSON 工具调用（JSON Tool Call） | "函数调用" | 每个操作是执行前验证的结构化 JSON 负载 |
| 脚手架（Scaffold） | "代理框架" | 围绕基础模型的检索 + 规划器 + 执行器 + 验证器循环 |
| ACI（Agent-Computer Interface） | "SWE-agent 的格式" | 为 LLM 人体工程学而非人类 Shell 设计的命令集 |
| 验证器循环（Verifier Loop） | "测试并重试" | 运行测试、读取输出、修订补丁；最大的非模型可靠性增益 |

## 进一步阅读

- [Jimenez 等人 — SWE-bench](https://www.swebench.com/) — 原始基准测试和方法论。
- [OpenAI — 介绍 SWE-bench Verified](https://openai.com/index/introducing-swe-bench-verified/) — 整理后子集如何构建。
- [Wang 等人 — OpenHands：AI 软件开发者的开放平台](https://arxiv.org/abs/2407.16741) — CodeAct 架构和事件流设计。
- [Epoch AI — SWE-bench 排行榜](https://epoch.ai/benchmarks) — 实时跟踪的分数。
- [Anthropic — 测量代理自主性](https://www.anthropic.com/research/measuring-agent-autonomy) — 长周期编码代理可靠性框架。