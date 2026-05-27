# 动态规划——策略迭代与值迭代

> 动态规划是作弊的 RL。你已经知道转移和奖励函数；只需迭代 Bellman 方程直到 `V` 或 `π` 停止移动。它是每个基于采样的方法试图接近的基准。

**类型：** 构建
**语言：** Python
**前置要求：** 第 9 阶段 · 01（MDP）
**时间：** 约 75 分钟

## 问题

你有一个已知模型的 MDP：你可以为任何状态-动作对查询 `P(s' | s, a)` 和 `R(s, a, s')`。库存经理知道需求分布。棋盘游戏有确定性转移。GridWorld 是四行 Python。你有一个*模型*。

无模型 RL（Q-learning、PPO、REINFORCE）是为你没有模型的情况发明的——你只能从环境采样。但当你有模型时，有更快、更好的方法：动态规划。Bellman 在 1957 年设计了它们。它们仍然定义正确性：当人们说"这个 MDP 的最优策略"时，他们指的是 DP 会返回的策略。

2026 年你需要它们有三个原因。首先，RL 研究中的每个表格环境（GridWorld、FrozenLake、CliffWalking）都用 DP 求解以产生黄金标准策略。其次，精确值让你*调试*采样方法：如果 Q-learning 对 `V*(s_0)` 的估计与 DP 答案差 30%，你的 Q-learning 有 bug。第三，现代离线 RL 和规划方法（MCTS、AlphaZero 的搜索、第 9 阶段 · 10 的基于模型的 RL）都在学习到的或给定的模型上迭代 Bellman 备份。

## 概念

![策略迭代和值迭代，并排](../assets/dp.svg)

**两种算法，都是 Bellman 上的定点迭代。**

**策略迭代。** 交替两个步骤直到策略停止变化。

1. *评估：* 给定策略 `π`，通过反复应用 `V(s) ← Σ_a π(a|s) Σ_{s',r} P(s',r|s,a) [r + γ V(s')]` 直到收敛来计算 `V^π`。
2. *改进：* 给定 `V^π`，使 `π` 相对于 `V^π` 贪心：`π(s) ← argmax_a Σ_{s',r} P(s',r|s,a) [r + γ V(s')]`。

收敛是有保证的，因为 (a) 每个改进步骤要么保持 `π` 不变，要么严格增加某些状态的 `V^π`，(b) 确定性策略的空间是有限的。即使对于大状态空间，通常在大约 5-20 次外迭代中收敛。

**值迭代。** 将评估和改进合并为一次扫描。应用 Bellman *最优性*方程：

`V(s) ← max_a Σ_{s',r} P(s',r|s,a) [r + γ V(s')]`

重复直到 `max_s |V_{new}(s) - V(s)| < ε`。在最后通过取贪心动作提取策略。每次迭代严格更快——无内评估循环——但通常需要更多迭代才能收敛。

**广义策略迭代（GPI）。** 统一框架。值函数和策略锁定在双向改进循环中；任何将两者推向相互一致的方法（异步值迭代、修正策略迭代、Q-learning、actor-critic、PPO）都是 GPI 的实例。

**为什么 `γ < 1` 重要。** Bellman 算子是上确界范数中的 `γ` 压缩：`||T V - T V'||_∞ ≤ γ ||V - V'||_∞`。压缩意味着唯一不动点和几何收敛。放弃 `γ < 1` 则失去保证——你需要有限视野或吸收终止状态。

## 构建

### 步骤 1：构建 GridWorld MDP 模型

使用第 01 课的相同 4×4 GridWorld。我们添加随机变体：以概率 `0.1` 代理滑到随机正交方向。

```python
SLIP = 0.1

def transitions(state, action):
    if state == TERMINAL:
        return [(state, 0.0, 1.0)]
    outcomes = []
    for direction, prob in action_probs(action):
        outcomes.append((apply_move(state, direction), -1.0, prob))
    return outcomes
```

`transitions(s, a)` 返回 `(s', r, p)` 列表。这就是整个模型。

### 步骤 2：策略评估

给定策略 `π(s) = {动作: 概率}`，迭代 Bellman 方程直到 `V` 停止移动：

```python
def policy_evaluation(policy, gamma=0.99, tol=1e-6):
    V = {s: 0.0 for s in states()}
    while True:
        delta = 0.0
        for s in states():
            v = sum(pi_a * sum(p * (r + gamma * V[s_prime])
                              for s_prime, r, p in transitions(s, a))
                   for a, pi_a in policy(s).items())
            delta = max(delta, abs(v - V[s]))
            V[s] = v
        if delta < tol:
            return V
```

### 步骤 3：策略改进

用相对于 `V` 的贪心策略替换 `π`。如果 `π` 没变，返回——我们在最优解。

```python
def policy_improvement(V, gamma=0.99):
    new_policy = {}
    for s in states():
        best_a = max(
            ACTIONS,
            key=lambda a: sum(p * (r + gamma * V[s_prime])
                              for s_prime, r, p in transitions(s, a)),
        )
        new_policy[s] = best_a
    return new_policy
```

### 步骤 4：缝合它们

```python
def policy_iteration(gamma=0.99):
    policy = {s: "up" for s in states()}   # 任意起点
    for _ in range(100):
        V = policy_evaluation(lambda s: {policy[s]: 1.0}, gamma)
        new_policy = policy_improvement(V, gamma)
        if new_policy == policy:
            return V, policy
        policy = new_policy
```

4×4 上典型收敛：4-6 次外迭代。输出 `V*(0,0) ≈ -6` 和一个严格减少步数的策略。

### 步骤 5：值迭代（单循环版本）

```python
def value_iteration(gamma=0.99, tol=1e-6):
    V = {s: 0.0 for s in states()}
    while True:
        delta = 0.0
        for s in states():
            v = max(sum(p * (r + gamma * V[s_prime])
                       for s_prime, r, p in transitions(s, a))
                   for a in ACTIONS)
            delta = max(delta, abs(v - V[s]))
            V[s] = v
        if delta < tol:
            break
    policy = policy_improvement(V, gamma)
    return V, policy
```

相同的不动点，更少代码。

## 陷阱

- **忘记处理终止状态。** 如果你对吸收状态应用 Bellman，它仍然会选择一个"最佳动作"但不改变任何东西。用 `if s == terminal: V[s] = 0` 保护。
- **上确界范数 vs L2 收敛。** 使用 `max |V_new - V|`，而非平均。理论保证是关于上确界范数的。
- **原地 vs 同步更新。** 原地更新 `V[s]`（Gauss-Seidel）比单独的 `V_new` 字典（Jacobi）收敛更快。生产代码使用原地更新。
- **策略平局。** 如果两个动作 Q 值相等，`argmax` 可能每次迭代不同地打破平局，导致"策略稳定"检查振荡。使用稳定打破平局（固定顺序中的第一个动作）。
- **状态空间爆炸。** DP 是每次扫描 `O(|S| · |A|)`。最多约 10⁷ 个状态。超过则需要函数近似（第 9 阶段 · 05 起）。

## 使用

2026 年，DP 是正确性基线和规划器的内循环：

| 用例 | 方法 |
|----------|--------|
| 精确求解小型表格 MDP | 值迭代（更简单）或策略迭代（更少外步骤） |
| 验证 Q-learning / PPO 实现 | 在玩具环境上与 DP 最优 V* 比较 |
| 基于模型的 RL（第 9 阶段 · 10） | Bellman 备份在学习到的转移模型上 |
| AlphaZero / MuZero 中的规划 | 蒙特卡洛树搜索 = 异步 Bellman 备份 |
| 离线 RL（CQL、IQL） | 保守 Q 迭代——对 OOD 动作加惩罚的 DP |

每次有人说"最优值函数"，他们的意思是"DP 不动点"。当你在论文中看到 `V*` 或 `Q*`，想象这个循环。

## 交付

保存为 `outputs/skill-dp-solver.md`：

```markdown
---
name: dp-solver
description: 通过策略迭代或值迭代精确求解小型表格 MDP。报告收敛行为。
version: 1.0.0
phase: 9
lesson: 2
tags: [rl, dynamic-programming, bellman]
---
```

## 练习

1. **简单。** 在 4×4 GridWorld 上用 `γ ∈ {0.9, 0.99}` 运行值迭代。达到 `max |ΔV| < 1e-6` 需要多少次扫描？将 `V*` 打印为 4×4 网格。
2. **中等。** 在*随机* GridWorld（滑动概率 `0.1`）上比较策略迭代 vs 值迭代。计数：扫描次数、挂钟时间、最终 `V*(0,0)`。哪种在迭代数上收敛更快？在挂钟时间上？
3. **困难。** 构建修正策略迭代：在评估步骤中，只运行 `k` 次扫描而非到收敛。对 `k ∈ {1, 2, 5, 10, 50}` 绘制 `V*(0,0)` 误差 vs `k`。曲线告诉你评估/改进权衡的什么信息？

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|-----------------------|
| 策略迭代 | "DP 算法" | 交替评估（`V^π`）和改进（相对于 `V^π` 的贪心 `π`）直到策略停止变化。 |
| 值迭代 | "更快的 DP" | Bellman 最优性备份在一次扫描中应用；几何收敛到 `V*`。 |
| Bellman 算子 | "递归" | `(T V)(s) = max_a Σ P (r + γ V(s'))`；上确界范数 `γ` 压缩。 |
| 压缩 | "为什么 DP 收敛" | 任何满足 `||T x - T y|| ≤ γ ||x - y||` 的算子 `T` 有唯一不动点。 |
| GPI | "一切都是 DP" | 广义策略迭代：任何将 `V` 和 `π` 推向相互一致的方法。 |
| 同步更新 | "Jacobi 风格" | 在一次扫描中处处使用旧 `V`；可干净分析但较慢。 |
| 原地更新 | "Gauss-Seidel 风格" | 使用正在更新的 `V`；实践中收敛更快。 |

## 扩展阅读

- [Sutton & Barto (2018). 第 4 章 Dynamic Programming](http://incompleteideas.net/book/RLbook2020.pdf)
- [Bellman (1957). Dynamic Programming](https://press.princeton.edu/books/paperback/9780691146683/dynamic-programming)