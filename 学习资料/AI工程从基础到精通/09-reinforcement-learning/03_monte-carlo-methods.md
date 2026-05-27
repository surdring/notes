# 蒙特卡洛方法——从完整 Episode 中学习

> 动态规划需要模型。蒙特卡洛只需要 episode。运行策略，观察回报，平均它们。RL 中最简单的思想——也是解锁一切下游内容的思想。

**类型：** 构建
**语言：** Python
**前置要求：** 第 9 阶段 · 01（MDP），第 9 阶段 · 02（动态规划）
**时间：** 约 75 分钟

## 问题

动态规划优雅，但它假设你可以为每个状态和动作查询 `P(s' | s, a)`。现实世界中几乎没有东西是这样工作的。机器人无法解析计算关节力矩后摄像机像素的分布。定价算法无法对每个可能的客户反应积分。LLM 无法枚举一个标记后的所有可能续写。

你需要一种只需要从环境*采样*能力的方法。运行策略。得到轨迹 `s_0, a_0, r_1, s_1, a_1, r_2, …, s_T`。用它估计值。这就是蒙特卡洛。

从 DP 到 MC 的转变在哲学上很重要：我们从*已知模型 + 精确备份*转向*采样展开 + 平均回报*。方差跃升，但适用性爆炸。本课之后的每个 RL 算法——TD、Q-learning、REINFORCE、PPO、GRPO——本质上都是蒙特卡洛估计器，有时在上面叠加强化学习。

## 概念

![蒙特卡洛：展开、计算回报、平均；首次访问 vs 每次访问](../assets/monte-carlo.svg)

**核心思想，一行：** `V^π(s) = E_π[G_t | s_t = s] ≈ (1/N) Σ_i G^{(i)}(s)` 其中 `G^{(i)}(s)` 是在策略 `π` 下访问 `s` 后观察到的回报。

**首次访问 vs 每次访问 MC。** 给定一个多次访问状态 `s` 的 episode，首次访问 MC 只计算首次访问的回报；每次访问 MC 计算所有访问。两者在极限下均无偏。首次访问更易分析（独立同分布样本）。每次访问每个 episode 使用更多数据，实践中通常收敛更快。

**增量均值。** 不存储所有回报，更新运行均值：

`V_n(s) = V_{n-1}(s) + (1/n) [G_n - V_{n-1}(s)]`

重组：`V_new = V_old + α · (target - V_old)` 其中 `α = 1/n`。将 `1/n` 换为常数步长 `α ∈ (0, 1)`，你得到一个跟踪 `π` 变化的非稳态 MC 估计器。这一举措是从 MC 到 TD 到每个现代 RL 算法的全部跳跃。

**探索现在是个问题。** DP 通过枚举触及每个状态。MC 只看到策略访问的状态。如果 `π` 是确定性的，整个状态空间区域永远不会被采样，它们的值估计永远保持为零。三种修复，按历史顺序：

1. **探索性起始。** 从随机 (s, a) 对开始每个 episode。保证覆盖；实践中不现实（你无法将机器人"重置"到任意状态）。
2. **ε-贪心。** 相对于当前 Q 贪心行动，但以概率 `ε` 选择随机动作。所有状态-动作对渐近被采样。
3. **离策略 MC。** 在行为策略 `μ` 下收集数据，通过重要性采样学习目标策略 `π`。高方差，但它是通往重放缓冲方法如 DQN 的桥梁。

**蒙特卡洛控制。** 评估 → 改进 → 评估，就像策略迭代，但评估是基于采样的：

1. 运行 `π`，得到一个 episode。
2. 从观察到的回报更新 `Q(s, a)`。
3. 使 `π` 相对于 `Q` 为 ε-贪心。
4. 重复。

在温和条件下（每对被访问无限次，`α` 满足 Robbins-Monro）以概率 1 收敛到 `Q*` 和 `π*`。

## 构建

### 步骤 1：展开 → (s, a, r) 列表

```python
def rollout(env, policy, max_steps=200):
    trajectory = []
    s = env.reset()
    for _ in range(max_steps):
        a = policy(s)
        s_next, r, done = env.step(s, a)
        trajectory.append((s, a, r))
        s = s_next
        if done:
            break
    return trajectory
```

无模型，只有 `env.reset()` 和 `env.step(s, a)`。与 gym 环境相同接口但简化。

### 步骤 2：计算回报（反向扫描）

```python
def returns_from(trajectory, gamma):
    returns = []
    G = 0.0
    for _, _, r in reversed(trajectory):
        G = r + gamma * G
        returns.append(G)
    return list(reversed(returns))
```

一次遍历，`O(T)`。反向递推 `G_t = r_{t+1} + γ G_{t+1}` 避免重复求和。

### 步骤 3：首次访问 MC 评估

```python
def mc_policy_evaluation(env, policy, episodes, gamma=0.99):
    V = defaultdict(float)
    counts = defaultdict(int)
    for _ in range(episodes):
        trajectory = rollout(env, policy)
        returns = returns_from(trajectory, gamma)
        seen = set()
        for t, ((s, _, _), G) in enumerate(zip(trajectory, returns)):
            if s in seen:
                continue
            seen.add(s)
            counts[s] += 1
            V[s] += (G - V[s]) / counts[s]
    return V
```

三行完成工作：首次访问时标记状态为已见，增加计数，更新运行均值。

### 步骤 4：ε-贪心 MC 控制（同策略）

```python
def mc_control(env, episodes, gamma=0.99, epsilon=0.1):
    Q = defaultdict(lambda: {a: 0.0 for a in ACTIONS})
    counts = defaultdict(lambda: {a: 0 for a in ACTIONS})

    def policy(s):
        if random() < epsilon:
            return choice(ACTIONS)
        return max(Q[s], key=Q[s].get)

    for _ in range(episodes):
        trajectory = rollout(env, policy)
        returns = returns_from(trajectory, gamma)
        seen = set()
        for (s, a, _), G in zip(trajectory, returns):
            if (s, a) in seen:
                continue
            seen.add((s, a))
            counts[s][a] += 1
            Q[s][a] += (G - Q[s][a]) / counts[s][a]
    return Q, policy
```

### 步骤 5：与 DP 黄金标准比较

随着 episode → ∞，你对 `V^π` 的 MC 估计应与第 02 课的 DP 结果一致。实践中：在 4×4 GridWorld 上 50,000 个 episode 让你在 DP 答案的 `~0.1` 以内。

## 陷阱

- **无限 episode。** MC 要求 episode 必须*终止*。如果你的策略可以永远循环，限制 `max_steps` 并将限制视为隐式失败。GridWorld 用随机策略经常超时——这很正常，只需确保正确计数。
- **方差。** MC 使用完整回报。在长 episode 上，方差巨大——末尾的一个不幸奖励会以相同量改变 `V(s_0)`。TD 方法（第 04 课）通过自举来削减。
- **状态覆盖。** 新鲜 Q 上的贪心 MC 用平局只会尝试一个动作。你*必须*探索（ε-贪心、探索性起始、UCB）。
- **非稳态策略。** 如果 `π` 变化（如在 MC 控制中），旧回报来自不同策略。常数 α MC 处理此问题；样本平均 MC 不处理。
- **离策略重要性采样。** 权重 `π(a|s)/μ(a|s)` 沿轨迹相乘。方差随视野爆炸。用每决策加权 IS 限制或切换到 TD。

## 使用

2026 年蒙特卡洛方法的角色：

| 用例 | 为什么 MC |
|----------|--------|
| 短视野游戏（21 点、扑克） | Episode 自然终止；回报干净。 |
| 离线评估记录策略 | 在存储轨迹上平均折扣回报。 |
| 蒙特卡洛树搜索（AlphaZero） | 来自树叶节点的 MC 展开引导选择。 |
| LLM RL 评估 | 计算给定策略采样补全的平均奖励。 |
| PPO 中的基线估计 | 优势目标 `A_t = G_t - V(s_t)` 使用 MC 的 `G_t`。 |
| RL 教学 | 实际可工作的最简单算法——剥离自举以看到核心。 |

## 交付

保存为 `outputs/skill-mc-evaluator.md`：

```markdown
---
name: mc-evaluator
description: 用完整-episode 采样评估指定策略的值函数；给出收敛估计。
version: 1.0.0
phase: 9
lesson: 3
tags: [rl, monte-carlo, policy-evaluation, control]
---
```

## 练习

1. **简单。** 运行 `code/main.py` 并对同一随机策略比较 100、1000、10000 个 episode 的 MC 策略评估。绘制 `|V_MC(s_0) - V_DP(s_0)|` vs episode。
2. **中等。** 实现离策略 MC 控制：用 ε=0.5 的策略收集数据，通过带截断重要性采样的加权重要性采样学习最优策略。
3. **困难。** 在 Open AI Gym 的 Blackjack 上实现 MC 控制。将策略绘制为玩家和庄家点数的函数。在 500,000 个 episode 后你的胜率是多少？

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|-----------------------|
| 蒙特卡洛 | "采样平均" | 通过平均观察到的回报估计 V 或 Q。 |
| 首次访问 MC | "更简单的 MC" | 仅平均每个 episode 中首次访问状态 s 的回报。 |
| 每次访问 MC | "更高数据效率" | 平均 episode 中对 s 的每次访问。 |
| 增量均值 | "运行平均" | `V += α(target - V)`；MC 和 TD 共享的更新规则。 |
| 同策略 | "跟随自身" | 用于收集数据的同一策略被改进。 |
| 离策略 | "向他人学习" | 数据来自行为策略；评估目标策略。 |
| 探索性起始 | "教学技巧" | 从任意 (s, a) 开始 episode 以确保覆盖。 |
| ε-贪心 | "标准探索" | 以概率 (1-ε) 贪心；以概率 ε 随机。 |

## 扩展阅读

- [Sutton & Barto (2018). Reinforcement Learning: An Introduction——第 5 章](http://incompleteideas.net/book/RLbook2020.pdf)
- [Singh & Sutton (1996). Reinforcement Learning with Replacing Eligibility Traces](http://www-anw.cs.umass.edu/pubs/1995_96/singh_s_MLJ96.pdf)