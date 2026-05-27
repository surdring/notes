# 多智能体强化学习

> 单智能体 RL 假设环境是静态的。将两个学习智能体放在同一个世界中，这个假设就破了：每个智能体是其他智能体环境的一部分，且两者都在变化。多智能体 RL 是当 Markov 假设不再成立时使学习收敛的一套技巧。

**类型：** 构建
**语言：** Python
**前置要求：** 第 9 阶段 · 04（Q-learning），第 9 阶段 · 06（REINFORCE），第 9 阶段 · 07（Actor-Critic）
**时间：** 约 45 分钟

## 问题

一个学习导航房间的机器人是单智能体 RL 问题。一支足球队不是。AlphaStar 对星际争霸对手不是。一个竞价代理市场不是。两辆车协商四向停车不是。多对多现实世界问题不是。

在每个多智能体设置中，从任何一个智能体的视角，其他智能体*就是*环境的一部分。随着它们学习和改变行为，环境变得非平稳。Markov 性质——"下一状态仅依赖当前状态和我的动作"——被违反，因为下一状态也取决于*其他*智能体选择了什么，而它们的策略是移动的目标。

这打破了表格收敛证明（Q-learning 的保证假设平稳环境）。它也打破了朴素的深度 RL：智能体在循环中互相追逐，永远不收敛到稳定策略。你需要多智能体特定的技术：集中训练 / 分散执行、反事实基线、联赛博弈、自博弈。

2026 年应用：机器人群、交通路由、自动驾驶车队、市场模拟器、多智能体 LLM 系统（第 16 阶段），以及任何有多个智能玩家的游戏。

## 概念

![四个 MARL 模式：独立、集中评论家、自博弈、联赛](../assets/marl.svg)

**形式化：Markov 博弈。** MDP 的推广：状态 `S`，联合动作 `a = (a_1, …, a_n)`，转移 `P(s' | s, a)`，以及每智能体奖励 `R_i(s, a, s')`。每个智能体 `i` 在其自身的策略 `π_i` 下最大化其自身的回报。如果奖励相同，是**完全合作**。如果零和，是**对抗**。如果混合，是**一般和**。

**核心挑战：**

- **非平稳性。** 从智能体 `i` 视角的 `P(s' | s, a_i)` 依赖 `π_{-i}`，而它正在变化。
- **信用分配。** 共享奖励时，哪个智能体造成了它？
- **探索协调。** 智能体必须探索互补策略，而非冗余探索相同状态。
- **可扩展性。** 联合动作空间随 `n` 指数增长。
- **部分可观测性。** 每个智能体只看到自己的观察；全局状态是隐藏的。

**四种主导模式：**

**1. 独立 Q-learning / 独立 PPO（IQL、IPPO）。** 每个智能体学习自己的 Q 或策略，将其他智能体视为环境的一部分。简单，有时有效（特别是经验重放作为平滑的智能体建模仿真技巧）。理论收敛：无。实践中：对松散耦合任务可以，对紧密耦合任务不行。

**2. 集中训练，分散执行（CTDE）。** 最常见的现代范式。每个智能体有自己的*策略* `π_i`，以局部观察 `o_i` 为条件——部署时标准分散执行。在*训练*期间，集中评论家 `Q(s, a_1, …, a_n)` 以完整全局状态和联合动作为条件。例子：
- **MADDPG**（Lowe et al. 2017）：每智能体带着集中评论家的 DDPG。
- **COMA**（Foerster et al. 2017）：反事实基线——问"如果我采取了动作 `a'` 而不是实际动作，我的奖励会怎样？"——隔离我的贡献。
- **MAPPO** / **IPPO** 带共享评论家（Yu et al. 2022）：带集中值函数的 PPO。2026 年合作 MARL 的主导选择。
- **QMIX**（Rashid et al. 2018）：值分解——`Q_tot(s, a) = f(Q_1(s, a_1), …, Q_n(s, a_n))` 带单调混合。

**3. 自博弈。** 同一智能体的两份副本对战。对手的策略*是*我过去快照的策略。AlphaGo / AlphaZero / MuZero。OpenAI Five。对零和博弈最有效；训练信号是对称的。

**4. 联赛博弈。** 自博弈向一般和/对抗环境的扩展：维护一个过去和当前策略的种群，从联赛中采样对手，针对它们训练。添加利用者（专门击败当前最佳）和主要利用者（专门击败利用者）。AlphaStar（星际争霸 II）。当博弈允许"石头剪刀布"策略循环时需要。

**通信。** 允许智能体彼此发送学习到的消息 `m_i`。在合作设置中有效。Foerster et al. (2016) 展示了可微的智能体间通信可以端到端训练。今天的基于 LLM 的多智能体系统（第 16 阶段）本质上用自然语言通信。

## 构建

本课使用有两个合作智能体的 6×6 GridWorld。它们从对角的角落出发，必须到达共享目标。共享奖励：当任一智能体仍在移动时 `-1` 每步，当两者都到达时 `+10`。见 `code/main.py`。

### 步骤 1：多智能体环境

```python
class CoopGridWorld:
    def __init__(self):
        self.size = 6
        self.goal = (5, 5)

    def reset(self):
        return ((0, 0), (5, 0))  # 两个智能体

    def step(self, state, actions):
        a1, a2 = state
        new1 = move(a1, actions[0])
        new2 = move(a2, actions[1])
        done = (new1 == self.goal) and (new2 == self.goal)
        reward = 10.0 if done else -1.0
        return (new1, new2), reward, done
```

*联合*动作空间是 `|A|² = 16`。全局状态是两个位置。

### 步骤 2：独立 Q-learning

每个智能体运行自己的 Q 表，以联合状态为键。每步：两者选择 ε-贪心动作，收集联合转移，每个用共享奖励更新自己的 Q。

```python
def independent_q(env, episodes, alpha, gamma, epsilon):
    Q1, Q2 = defaultdict(default_q), defaultdict(default_q)
    for _ in range(episodes):
        s = env.reset()
        while not done:
            a1 = epsilon_greedy(Q1, s, epsilon)
            a2 = epsilon_greedy(Q2, s, epsilon)
            s_next, r, done = env.step(s, (a1, a2))
            target1 = r + gamma * max(Q1[s_next].values())
            target2 = r + gamma * max(Q2[s_next].values())
            Q1[s][a1] += alpha * (target1 - Q1[s][a1])
            Q2[s][a2] += alpha * (target2 - Q2[s][a2])
            s = s_next
```

在此任务上有效，因为奖励是密集且对齐的。在紧密耦合任务上失败（例如一个智能体必须*等待*另一个的地方）。

### 步骤 3：带分解值更新的集中 Q

对联合动作使用一个 Q `Q(s, a_1, a_2)`。从共享奖励更新。执行时通过边际化分散：`π_i(s) = argmax_{a_i} max_{a_{-i}} Q(s, a_1, a_2)`。用指数级联合动作空间换取*正确*的全局视图。

### 步骤 4：简单自博弈（对抗 2 智能体）

同一智能体，两个角色。训练智能体 A 对抗智能体 B；`K` episode 后，将 A 的权重复制到 B。对称训练，持续进展。微型 AlphaZero 配方。

## 陷阱

- **非平稳重放。** 独立智能体的经验重放比单智能体更差，因为旧转移是由现已过时的对手生成的。修复：按新近度重新标记或加权。
- **信用分配模糊。** 长 episode 后的共享奖励；没有明确方式说哪个智能体贡献了。修复：反事实基线（COMA），或每智能体奖励塑造。
- **策略漂移 / 追逐。** 每个智能体的最佳响应随其他每个智能体的更新而改变。修复：集中评论家，慢学习率，或一次冻结一个。
- **通过协调的奖励黑客。** 智能体找到设计者未预见的协调利用。拍卖智能体收敛到竞标零。修复：仔细的奖励设计，行为约束。
- **探索冗余。** 两个智能体探索相同的状态-动作对。修复：每智能体熵奖励，或角色条件化。
- **联赛循环。** 纯自博弈可能卡在支配性循环中。修复：带多样化对手的联赛博弈。
- **样本爆炸。** `n` 智能体 × 状态空间 × 联合动作。用函数近似近似；因子化动作空间（每智能体一个策略输出头）。

## 使用

2026 年 MARL 应用地图：

| 领域 | 方法 | 备注 |
|------|------|------|
| 合作导航 / 操控 | MAPPO / QMIX | CTDE；共享评论家 + 分散演员。 |
| 双人游戏（象棋、围棋、扑克） | 自博弈带 MCTS（AlphaZero） | 零和；对称训练。 |
| 复杂多人（Dota、星际争霸） | 联赛博弈 + 模仿预训练 | OpenAI Five、AlphaStar。 |
| 自动驾驶车队 | CTDE MAPPO / PPO 带注意力 | 部分观测；可变队伍规模。 |
| 拍卖市场 | 博弈论均衡 + RL | 均值场 RL 当 `n` → ∞。 |
| LLM 多智能体系统（第 16 阶段） | 自然语言通信 + 角色条件化 | RL 循环在智能体规划层。 |

2026 年，MARL 最大的增长领域是基于 LLM 的：语言模型代理群谈判、辩论、构建软件。RL 表现为*轨迹级*输出上的偏好优化，而非 token 级（第 16 阶段 · 03）。

## 交付

保存为 `outputs/skill-marl-architect.md`：

```markdown
---
name: marl-architect
description: 为给定任务选择合适的 MARL 模式（IPPO、CTDE、自博弈、联赛）。
version: 1.0.0
phase: 9
lesson: 10
tags: [rl, multi-agent, marl, self-play]
---

给定一个具有 `n` 个智能体的任务，输出：

1. 模式分类。合作 / 对抗 / 一般和。证明。
2. 算法。IPPO / MAPPO / QMIX / 自博弈 / 联赛。理由与耦合紧密性和奖励结构相关。
3. 信息访问。集中训练（什么全局信息进入评论家）？分散执行？
4. 信用分配。反事实基线、值分解或奖励塑造。
```

## 练习

1. **简单。** 运行 `code/main.py` 比较独立 Q-learning 与集中 Q。独立 Q 在多紧密耦合的 GridWorld（agent2 必须等 agent1）上收敛？
2. **中等。** 添加反事实基线：对每对 `(s, a_i)`，计算 `A_i = Q(s, a_i, a_{-i}) - Σ_{a'} π_i(a' | s) Q(s, a', a_{-i})`。将它与独立 Q 的共享优势比较。
3. **困难。** 在 4×4 GridWorld 上为三智能体实现 QMIX 值分解。绘制 `Q_tot`（集中学习的）与独立 `Q_1 + Q_2 + Q_3` 的比较。QMIX 提高收敛速度吗？

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|-----------------------|
| CTDE | "集中训练，分散执行" | 训练：评论家看到全局状态。执行：每智能体用局部观察。 |
| 非平稳性 | "移动目标" | 其他智能体的策略变化，所以转移概率变化。 |
| MADDPG | "多智能体 DDPG" | 每智能体带集中评论家的 DDPG。 |
| COMA | "反事实基线" | "如果我做了不同的选择会怎样？" 基线。 |
| QMIX | "单调值分解" | 联合 Q 是每智能体 Q 的单调函数。 |
| 自博弈 | "我对我的过去版本" | 对手是过去快照；对称训练。 |
| 联赛博弈 | "种群训练" | 维护许多策略；针对混合对手训练。 |

## 扩展阅读

- [Lowe et al. (2017). Multi-Agent Actor-Critic for Mixed Cooperative-Competitive Environments](https://arxiv.org/abs/1706.02275)——MADDPG。
- [Foerster et al. (2017). Counterfactual Multi-Agent Policy Gradients](https://arxiv.org/abs/1705.08926)——COMA。
- [Rashid et al. (2018). QMIX: Monotonic Value Function Factorisation for Deep Multi-Agent Reinforcement Learning](https://arxiv.org/abs/1803.11485)——QMIX。
- [Vinyals et al. (2019). Grandmaster level in StarCraft II using multi-agent reinforcement learning](https://www.nature.com/articles/s41586-019-1724-z)——AlphaStar。