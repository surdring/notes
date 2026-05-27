# 时序差分——Q-Learning 与 SARSA

> 蒙特卡洛等到 episode 结束。TD 每一步之后通过自举下一值估计来更新。Q-learning 是离策略且乐观的；SARSA 是同策略且谨慎的。两者都是一行代码。两者都是本阶段每个深度 RL 方法的基础。

**类型：** 构建
**语言：** Python
**前置要求：** 第 9 阶段 · 01（MDP），第 9 阶段 · 02（动态规划），第 9 阶段 · 03（蒙特卡洛）
**时间：** 约 75 分钟

## 问题

蒙特卡洛有效但它有两个昂贵的需求。它需要终止的 episode，且只在最终回报到达后更新。如果你的 episode 是 1,000 步，MC 等 1,000 步才更新任何东西。它是高方差、低偏差，实践中慢。

动态规划有相反的轮廓——零方差自举备份——但需要已知模型。

时序差分（TD）学习折中。从单次转移 `(s, a, r, s')`，形成一步目标 `r + γ V(s')` 并向其微调 `V(s)`。无模型。无需完整 episode。使用近似 `V` 在右侧带来的偏差，但比 MC 方差大幅降低，且从第 1 步开始在线更新。

这是现代所有 RL——DQN、A2C、PPO、SAC——围绕的枢纽。第 9 阶段其余部分是在一步 TD 更新之上构建的函数近似层和技巧，你将在本课中编写这个更新。

## 概念

![Q-learning vs SARSA：离策略 max vs 同策略 Q(s', a')](../assets/td.svg)

**V 的 TD(0) 更新：**

`V(s) ← V(s) + α [r + γ V(s') - V(s)]`

括号中的量是 TD 误差 `δ = r + γ V(s') - V(s)`。它是 MC 中 `G_t - V(s_t)` 的在线类比。收敛要求 `α` 满足 Robbins-Monro（`Σ α = ∞`，`Σ α² < ∞`）且所有状态被无限次访问。

**Q-learning。** 控制的离策略 TD 方法：

`Q(s, a) ← Q(s, a) + α [r + γ max_{a'} Q(s', a') - Q(s, a)]`

`max` 假设从 `s'` 开始将遵循*贪心*策略，无论代理实际采取什么动作。这种解耦使 Q-learning 在代理通过 ε-贪心探索时学习 `Q*`。Mnih et al. (2015) 将其转化为 Atari 上的深度 Q-learning（第 05 课）。

**SARSA。** 同策略 TD 方法：

`Q(s, a) ← Q(s, a) + α [r + γ Q(s', a') - Q(s, a)]`

名称是元组 `(s, a, r, s', a')`。SARSA 使用代理*实际*采取的下一动作 `a'`，而非贪心 `argmax`。收敛到 `Q^π`，对于正在运行的任何 ε-贪心 `π`，在极限 `ε → 0` 时成为 `Q*`。

**悬崖行走差异。** 在经典的悬崖行走任务（掉落悬崖 = 奖励 -100）上，Q-learning 沿着悬崖边缘学习最优路径，但在探索期间偶尔承受惩罚。SARSA 学习离悬崖一步的更安全路径，因为它将探索噪声纳入 Q 值。随着训练，两者在 `ε → 0` 时都达到最优。实践中很重要：当探索在部署时实际发生时，SARSA 的行为更保守。

**期望 SARSA。** 将 `Q(s', a')` 替换为其在 `π` 下的期望值：

`Q(s, a) ← Q(s, a) + α [r + γ Σ_{a'} π(a'|s') Q(s', a') - Q(s, a)]`

比 SARSA 方差更低（无 `a'` 的采样），相同的同策略目标。通常是现代教材中的默认选择。

**n 步 TD 和 TD(λ)。** 通过在自举之前等待 `n` 步在 TD(0) 和 MC 之间插值。`n=1` 是 TD，`n=∞` 是 MC。TD(λ) 以几何权重 `(1-λ)λ^{n-1}` 对所有 `n` 平均。大多数深度 RL 使用 3 到 20 之间的 `n`。

## 构建

### 步骤 1：ε-贪心策略上的 SARSA

```python
def sarsa(env, episodes, alpha=0.1, gamma=0.99, epsilon=0.1):
    Q = defaultdict(lambda: {a: 0.0 for a in ACTIONS})

    def choose(s):
        if random() < epsilon:
            return choice(ACTIONS)
        return max(Q[s], key=Q[s].get)

    for _ in range(episodes):
        s = env.reset()
        a = choose(s)
        while True:
            s_next, r, done = env.step(s, a)
            a_next = choose(s_next) if not done else None
            target = r + (gamma * Q[s_next][a_next] if not done else 0.0)
            Q[s][a] += alpha * (target - Q[s][a])
            if done:
                break
            s, a = s_next, a_next
    return Q
```

八行。与 Q-learning 的*唯一*区别是目标行。

### 步骤 2：Q-learning

```python
def q_learning(env, episodes, alpha=0.1, gamma=0.99, epsilon=0.1):
    Q = defaultdict(lambda: {a: 0.0 for a in ACTIONS})
    for _ in range(episodes):
        s = env.reset()
        while True:
            a = choose(s, Q, epsilon)
            s_next, r, done = env.step(s, a)
            target = r + (gamma * max(Q[s_next].values()) if not done else 0.0)
            Q[s][a] += alpha * (target - Q[s][a])
            if done:
                break
            s = s_next
    return Q
```

`max` 将目标与行为解耦。那一个符号是同策略与离策略之间的区别。

### 步骤 3：学习曲线

跟踪每 100 个 episode 的平均回报。Q-learning 在简单确定性 GridWorld 上收敛更快；SARSA 在悬崖行走上更保守。在 `code/main.py` 中的 4×4 GridWorld 上，两者在 `α=0.1, ε=0.1` 下约 2,000 个 episode 后都接近最优。

### 步骤 4：与 DP 真实值比较

运行值迭代（第 02 课）得到 `Q*`。检查 `max_{s,a} |Q_learned(s,a) - Q*(s,a)|`。一个健康的表格 TD 代理在 4×4 GridWorld 上 10,000 个 episode 后落在 `~0.5` 以内。

## 陷阱

- **初始 Q 值很重要。** 乐观初始化（负奖励任务 `Q = 0`）鼓励探索。悲观初始化可能永远困住贪心策略。
- **α 调度。** 常数 `α` 对非稳态问题很好。递减 `α_n = 1/n` 理论上给出收敛但在实践中太慢——固定 `α` 在 `[0.05, 0.3]` 并监控学习曲线。
- **ε 调度。** 从高开始（`ε=1.0`），衰减到 `ε=0.05`。"GLIE"（极限贪心与无限探索）是收敛条件。
- **Q-learning 中的 max 偏差。** 当 `Q` 有噪声时 `max` 算子有正偏差。导致高估——Hasselt 的 Double Q-learning（第 05 课中 DDQN 使用）用两个 Q 表修复。
- **非终止 episode。** TD 可以在无终止条件时学习，但你需要在限制处限制步骤或正确处理自举。标准：将限制视为非终止，继续自举。
- **状态哈希。** 如果状态是元组/张量，使用可哈希键（元组，不是列表；舍入浮点元组，不是原始值）。

## 使用

2026 年的 TD 格局：

| 任务 | 方法 | 原因 |
|------|--------|--------|
| 小型表格环境 | Q-learning | 直接学习最优策略。 |
| 同策略安全关键 | SARSA / 期望 SARSA | 探索期间保守。 |
| 高维状态 | DQN（第 9 阶段 · 05） | 带重放和目标网络的神经网络 Q 函数。 |
| 连续动作 | SAC / TD3（第 9 阶段 · 07） | Q 网络上的 TD 更新；策略网络发出动作。 |
| LLM RL（基于奖励模型） | PPO / GRPO（第 9 阶段 · 08, 12） | 通过 GAE 的 TD 风格优势的 Actor-critic。 |
| 离线 RL | CQL / IQL（第 9 阶段 · 08） | 带保守正则化的 Q-learning。 |

你在 2026 年论文中读到的"RL"的百分之九十是 Q-learning 或 SARSA 的某种阐述。在更深入阅读之前，理解指间的表格更新。

## 交付

保存为 `outputs/skill-td-agent.md`：

```markdown
---
name: td-agent
description: 为表格或小特征 RL 任务在 Q-learning、SARSA、期望 SARSA 之间选择。
version: 1.0.0
phase: 9
lesson: 4
tags: [rl, td-learning, q-learning, sarsa]
---
```

## 练习

1. **简单。** 在 `code/main.py` 中，在确定性 GridWorld 上比较 Q-learning 和 SARSA。绘制每 100 episode 的平均回报两侧。在 2,000 episode 后哪个有更低方差？
2. **中等。** 在悬崖行走环境上实现两者的 Double Q-learning 变体。Double 是否减少 Q-learning 对悬崖的脆弱性？测量 10 次运行的跌落率。
3. **困难。** 实现 n 步 SARSA 用于 `n ∈ {1, 3, 5, 10, ∞ (MC)}`。对每个 n 在 500 episode 后测量均方 Q 误差 vs `Q*`。最佳 n 是多少？为什么它匹配在 MC 和 TD 方差/偏差之间的权衡？

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|-----------------------|
| TD 误差 | "δ" | `δ = r + γ V(s') - V(s)`；TD 更新的驱动项。 |
| Bootstrapping | "使用估计来更新估计" | TD 目标使用 `V(s')`，本身就是估计。 |
| Q-learning | "离策略 TD" | 学习 `Q*` 的同时通过 ε-贪心探索。 |
| SARSA | "同策略 TD" | 学习当前探索性策略的 Q 值。 |
| Double Q-learning | "去偏差 max" | 用第二 Q 表评估以修复高估。 |
| n 步 TD | "MC 和 TD 之间" | 等待 n 步再自举；在偏差和方差之间插值。 |
| GLIE | "收敛条件" | 极限贪心与无限探索。 |
| 经验重放 | "打破相关性" | 随机采样存储的转移；第 05 课的基础。 |

## 扩展阅读

- [Sutton & Barto (2018). 第 6 章 Temporal-Difference Learning](http://incompleteideas.net/book/RLbook2020.pdf)
- [Watkins & Dayan (1992). Q-Learning](https://link.springer.com/article/10.1007/BF00992698)——Q-learning 论文。
- [Rummery & Niranjan (1994). On-Line Q-Learning using Connectionist Systems](http://citeseerx.ist.psu.edu/viewdoc/summary?doi=10.1.1.17.2539)——SARSA 论文。
- [Hasselt (2010). Double Q-learning](https://papers.nips.cc/paper/3964-double-q-learning)——Double Q-learning 论文。