# MARL——MADDPG、QMIX、MAPPO

> 多 Agent 协调的强化学习遗产，在 2026 年仍在为 LLM 代理系统提供信息。**MADDPG**（Lowe 等人，NeurIPS 2017，arXiv:1706.02275）引入了集中训练、分散执行（Centralized Training, Decentralized Execution，CTDE）：每个评论家（Critic）在训练期间看到所有 Agent 的状态和行动；在测试时只有本地行动者（Actor）运行。适用于合作、竞争和混合设置。**QMIX**（Rashid 等人，ICML 2018，arXiv:1803.11485）是带单调混合网络的值分解；每个 Agent 的 Q 值组合成联合 Q 值，因此 `argmax` 可以干净地分布——在星际争霸多 Agent 挑战（StarCraft Multi-Agent Challenge，SMAC）上占主导地位。**MAPPO**（Yu 等人，NeurIPS 2022，arXiv:2103.01955）是带集中值函数的 PPO；在粒子世界、SMAC、Google Research Football、Hanabi 上以最少调优「令人惊讶地有效」。这些支撑着训练必须分散行动的 Agent 团队策略。MAPPO 是**默认的 2026 合作 MARL 基线**。本课从小型网格世界玩具构建每个算法，在接触 LLM Agent 训练之前让三个思想进入肌肉记忆。

**类型：** 学习
**语言：** Python（标准库，小型无 NumPy 实现）
**前置知识：** 第 09 阶段（强化学习）、第 16 阶段 · 09（并行集群网络）
**时间：** 约 90 分钟

## 问题

LLM Agent 系统越来越多地为代理间的协调训练策略：何时推迟、何时行动、调用哪个同伴。告诉你如何训练这种策略的文献是多 Agent 强化学习（Multi-Agent Reinforcement Learning，MARL），它早于 LLM 浪潮，有一套小的主导算法。

没有模式词汇阅读 MARL 论文是痛苦的。集中训练分散执行（CTDE）、值分解和集中评论家不是流行语——它们是对特定问题的特定答案：

- 独立 RL（每个 Agent 单独学习）从每个 Agent 的角度是非平稳（Non-Stationary）的。不好。
- 集中 RL（一个 Agent 控制所有）不能扩展并且违反执行约束。
- CTDE 获得两者的优点：用全局信息训练，用局部策略部署。

## 概念

### 论文使用的三种环境

- **粒子世界（Particle World，多 Agent 粒子环境）。** 带有合作/竞争任务的简单 2D 物理。MADDPG 的原始测试平台。
- **星际争霸多 Agent 挑战（SMAC）。** 合作微管理，部分观察。QMIX 的测试平台。离散行动，连续状态。
- **Google Research Football、Hanabi、MPE。** MAPPO 基线。

不同环境有不同行动/观察类型。算法相应选择。

### MADDPG（2017）——CTDE 模式

每个 Agent `i` 有一个行动者 `mu_i(o_i)`，将其自身观察映射到行动。每个 Agent 也有一个评论家 `Q_i(x, a_1, ..., a_n)`，在训练期间看到所有观察和所有行动。行动者通过策略梯度根据评论家的评估更新。

```
actor update:    grad_theta_i J = E[grad_theta mu_i(o_i) * grad_a_i Q_i(x, a_1..n) at a_i=mu_i(o_i)]
critic update:   TD on Q_i(x, a_1..n) given next-state joint estimate
```

为什么 CTDE：在训练时，我们知道每个人的行动；我们用它来减少每个评论家的方差。在部署时，每个 Agent 只看到 `o_i` 并调用 `mu_i(o_i)`。

失败模式：评论家随 N 个 Agent 增长（输入包括所有行动）。没有近似不能扩展到约 10 个 Agent 以上。

### QMIX（2018）——值分解

仅合作。全局奖励是每个 Agent Q 值的单调函数之和：

```
Q_tot(tau, a) = f(Q_1(tau_1, a_1), ..., Q_n(tau_n, a_n)),   df/dQ_i >= 0
```

单调性保证 `argmax_a Q_tot` 可以通过每个 Agent 独立选择 `argmax_{a_i} Q_i` 来计算。这正是你需要的**分散执行属性**。在训练时，混合网络从每个 Agent 的 Q 值产生 `Q_tot`。

为什么 QMIX 在 SMAC 上获胜：合作星际争霸微管理具有同质代理、局部观察、全局奖励——非常适合值分解。

失败模式：单调性约束是限制性的；某些任务具有非单调可分解的奖励结构（一个 Agent 为团队牺牲）。扩展（QTRAN、QPLEX）放宽了这一点。

### MAPPO（2022）——被忽视的默认

多 Agent PPO：带集中值函数的 PPO。每个 Agent 有自己的策略；所有 Agent 共享（或有每个 Agent 的）看到完整状态的值函数。Yu 等人 2022 年在五个基准上对 MAPPO 与 MADDPG、QMIX 及其扩展进行了基准测试，发现：

- MAPPO 在粒子世界、SMAC、Google Research Football、Hanabi、MPE 上匹敌或击败离策略（Off-Policy）MARL 方法。
- 需要最少的超参数调优。
- 训练稳定；跨种子可复现。

社区在此论文之前低估了在策略（On-Policy）MARL。在 2026 年，MAPPO 是合作 MARL 的默认基线；任何新方法必须击败它。

### 为什么 LLM Agent 工程师应该关心

三个直接用途：

1. **路由训练。** 元 Agent 选择哪个子 Agent 处理任务。这是一个有 N 个分散子 Agent 和一个集中路由器（Router）的 MARL 问题。MAPPO 适合。
2. **角色涌现。** 在生成式 Agent 模拟中，训练 Agent 随时间采用互补角色，这实质上是 MARL 问题。QMIX 风格的值分解按构造强制互补性。
3. **多 Agent 工具使用。** 当 Agent 共享工具并竞争预算时，通过 CTDE 训练它们产生遵守资源约束的可部署本地策略。

实际注意事项：在 2026 年，大多数生产 LLM Agent 系统提示其策略而非训练它们。MARL 在你有（a）大量交互数据，（b）清晰的奖励信号，和（c）投资训练基础设施的意愿时才介入。

### CTDE 作为 RL 之外的设计模式

即使没有训练，CTDE 也是一种有用的架构模式：

- 在*设计*期间，假设完整的团队可见性。
- 在*运行时*，强制分散执行：每个 Agent 只看到 `o_i`。

该模式强制你保持每个 Agent 状态显式化，并预先思考部分可观察性。许多生产多 Agent 系统默默假设处处共享状态——CTDE 纪律防止了这一点。

### 非平稳性问题

当多个 Agent 同时学习时，每个 Agent 的环境（包含其他 Agent 的策略）是非平稳的。经典单 Agent RL 证明破裂。本课中的 MARL 算法都解决了这一点：

- MADDPG：全局评论家看到所有行动，因此其值估计是平稳的。
- QMIX：值分解将学习移动到联合 Q 空间，其中最优性是明确定义的。
- MAPPO：集中值函数抑制来自他人策略变化的方差。

在 LLM Agent 系统中，非平稳性表现为「我的 Agent 上个月工作，现在上游的那个 Agent 变了，我的行为失常了。」用 CTDE 训练 MARL 是原则性修复；提示级修复更快但更不耐久。

### 本课不涵盖什么

训练实际网络是第 09 阶段的话题。本课构建脚本化策略版本，演示 CTDE、值分解和集中值模式，无需梯度更新。目标是在你使用完整的 MARL 库（PyMARL、MARLlib、RLlib multi-agent）之前内化这些模式。

## 构建

`code/main.py` 实现三个模式演示，全部在一个微型 2 Agent 合作网格世界上：

- 环境：4x4 网格上的 2 个 Agent，一个奖励颗粒。如果有任何 Agent 到达颗粒，奖励 = 1；任务结束。
- `IndependentAgents`——每个 Agent 将其他视为环境。基线。
- `MADDPGStyle`——集中评论家计算联合值；行动者策略从中更新。脚本化策略改进。
- `QMIXStyle`——带单调混合器的值分解。
- `MAPPOStyle`——集中值函数；策略根据共享基线更新。

四个都运行相同的回合并报告平均到达目标的步数。CTDE 变体收敛到比独立基线更短的路径。

运行：

```
python3 code/main.py
```

预期输出：独立 Agent 平均花费约 6 步；CTDE 变体收敛到约 3.5 步（4x4 网格的最优为 3）。尽管有脚本化策略，模式差异仍然显示出来。

## 实践

`outputs/skill-marl-picker.md` 是一个为给定多 Agent 任务选择 MARL 算法的技能：合作 vs 竞争、同质 vs 异构、行动空间类型、规模、奖励信号。

## 交付

MARL 在生产中很少见。当你确实使用时：

- **从 MAPPO 开始。** 2022 年论文建立了这个基线；首先复现它节省了追逐更花哨方法的时间。
- **记录每个 Agent 的观察和行动流。** 没有每个 Agent 追踪调试 MARL 是绝望的。
- **将训练代码与执行代码分离。** CTDE 是纪律；让执行路径真的只看到 `o_i`。
- **奖励塑形警告。** MARL 对奖励设计极其敏感。塑形中的一个协调 Bug 就会被 Agent 学会利用。运行对抗性测试。
- **对于 LLM Agent**，首先考虑提示级策略。仅当交互数据 + 奖励信号 + 基础设施都具备时才投资 MARL 训练。

## 练习

1. 运行 `code/main.py`。测量独立和 MAPPO 风格 Agent 之间到达目标的步数差距。在 6x6 网格上差距是扩大还是缩小？
2. 实现竞争变体：两个 Agent，一个颗粒，只有第一个到达的获得奖励。哪种模式干净地处理竞争？历史上是 MADDPG。
3. 阅读 MADDPG（arXiv:1706.02275）第 3 节。用你自己的话以伪代码符号化实现精确的评论家更新规则。
4. 阅读 MAPPO（arXiv:2103.01955）。为什么作者认为集中值 + PPO 在其基准上击败离策略 MARL？列出三个最强的声明。
5. 将 CTDE 作为设计模式应用于一个假设的 LLM Agent 系统（例如，研究 Agent + 摘要者 + 程序员）。什么是在设计时可用但在运行时不可用的联合信息？

## 关键术语

| 术语 | 人们说的 | 实际含义 |
|------|---------|---------|
| MARL | 「多 Agent RL」 | 多 Agent 系统的强化学习。 |
| CTDE | 「集中训练、分散执行」 | 用全局信息训练；用局部策略部署。 |
| MADDPG | 「多 Agent DDPG」 | 带每个 Agent 评论家看到所有观察 + 行动的 CTDE。 |
| QMIX | 「值分解」 | 每个 Agent Q 值的单调混合。合作。 |
| MAPPO | 「多 Agent PPO」 | 带集中值函数的 PPO。2026 默认基线。 |
| Value decomposition | 「个体 Q 值之和」 | 联合 Q 表示为每个 Agent Q 值的单调函数。 |
| Non-stationarity | 「移动目标」 | 每个 Agent 的环境随其他 Agent 学习而改变。核心 MARL 问题。 |
| On-policy / off-policy | 「从当前 / 重放学习」 | PPO 是 on-policy（MAPPO）；DDPG 和 Q-learning 是 off-policy。 |
| SMAC | 「星际争霸多 Agent 挑战」 | 合作微管理基准；QMIX 的主场。 |

## 扩展阅读

- [Lowe 等人 — 面向混合合作-竞争环境的多 Agent Actor-Critic](https://arxiv.org/abs/1706.02275) — MADDPG；NeurIPS 2017
- [Rashid 等人 — QMIX：面向深度多 Agent 强化学习的单调值函数因子化](https://arxiv.org/abs/1803.11485) — QMIX；ICML 2018
- [Yu 等人 — PPO 在合作多 Agent 游戏中的惊人有效性](https://arxiv.org/abs/2103.01955) — MAPPO；NeurIPS 2022
- [BAIR 博客关于 MAPPO](https://bair.berkeley.edu/blog/2021/07/14/mappo/) — MAPPO 结果的可读框架
- [SMAC 仓库](https://github.com/oxwhirl/smac) — 星际争霸多 Agent 挑战