# Actor-Critic——A2C 和 A3C

> REINFORCE 很嘈杂。添加一个学习 `V̂(s)` 的评论家，从回报中减去它，你就得到一个具有相同期望但方差低得多的优势。这就是 actor-critic。A2C 同步运行；A3C 跨线程运行。两者都是每个现代深度 RL 方法的心智模型。

**类型：** 构建
**语言：** Python
**前置要求：** 第 9 阶段 · 04（TD 学习），第 9 阶段 · 06（REINFORCE）
**时间：** 约 75 分钟

## 问题

原始 REINFORCE 有效，但其方差很糟糕。蒙特卡洛回报 `G_t` 可以在 episode 之间波动超过 10 倍。将该噪声乘以 `∇ log π` 并平均会产生一个梯度估计器，需要数千 episode 才能将策略移动与少得多 DQN 更新相同的距离。

方差来自使用原始回报。如果你减去一个基线 `b(s_t)`——任何状态函数，包括学习到的值——期望不变，方差下降。最佳可处理的基线是 `V̂(s_t)`。现在乘以 `∇ log π` 的量是*优势*：

`A(s, a) = G - V̂(s)`

如果一个动作产生了高于平均的回报，就是好的；低于就是坏的。带学习评论家的 REINFORCE 是 *actor-critic*。评论家给演员一个低方差的老师。这是 2015 年后每个深度策略方法（A2C、A3C、PPO、SAC、IMPALA）。

## 概念

![Actor-critic：策略网络加值网络，TD 残差作为优势](../assets/actor-critic.svg)

**两个网络，一个共享损失：**

- **演员** `π_θ(a | s)`：策略。采样来行动。用策略梯度训练。
- **评论家** `V_φ(s)`：估计从状态开始的期望回报。训练以最小化 `(V_φ(s) - target)²`。

**优势。** 两种标准形式：

- *MC 优势：* `A_t = G_t - V_φ(s_t)`。无偏，较高方差。
- *TD 优势：* `A_t = r_{t+1} + γ V_φ(s_{t+1}) - V_φ(s_t)`。有偏（使用 `V_φ`），方差低得多。也称为 *TD 残差* `δ_t`。

**n 步优势。** 在两者之间插值：

`A_t^{(n)} = r_{t+1} + γ r_{t+2} + … + γ^{n-1} r_{t+n} + γ^n V_φ(s_{t+n}) - V_φ(s_t)`

`n = 1` 是纯 TD。`n = ∞` 是 MC。大多数实现对 Atari 使用 `n = 5`，对 MuJoCo 上的 PPO 使用 `n = 2048`。

**广义优势估计（GAE）。** Schulman et al. (2016) 提出了所有 n 步优势上的指数加权平均：

`A_t^{GAE} = Σ_{l=0}^{∞} (γλ)^l δ_{t+l}`

其中 `λ ∈ [0, 1]`。`λ = 0` 是 TD（低方差，高偏差）。`λ = 1` 是 MC（高方差，无偏）。`λ = 0.95` 是 2026 年的默认值——调整直到偏差/方差旋钮在你想要的位置。

**A2C：同步优势 actor-critic。** 在 `N` 个并行环境中收集 `T` 步。为每步计算优势。在组合批次上更新演员和评论家。重复。A3C 的更简单、更可扩展的兄弟。

**A3C：异步优势 actor-critic。** Mnih et al. (2016)。生成 `N` 个工作线程，每个运行一个环境。每个工作线程在其自己的 rollout 上本地计算梯度，然后异步地应用到共享参数服务器。不需要重放缓冲——工作线程通过运行不同轨迹去相关。A3C 证明了可以在 CPU 上大规模训练。在 2026 年，基于 GPU 的 A2C（批处理并行环境）占主导，因为 GPU 想要大批量。

**组合损失。**

`L(θ, φ) = -E[ A_t · log π_θ(a_t | s_t) ]  +  c_v · E[(V_φ(s_t) - G_t)²]  -  c_e · E[H(π_θ(·|s_t))]`

三项：策略梯度损失、值回归、熵奖励。`c_v ~ 0.5`，`c_e ~ 0.01` 是规范的起点。

## 构建

### 步骤 1：一个评论家

线性评论家 `V_φ(s) = w · features(s)` 用 MSE 更新：

```python
def critic_update(w, x, target, lr):
    v_hat = dot(w, x)
    err = target - v_hat
    for j in range(len(w)):
        w[j] += lr * err * x[j]
    return v_hat
```

在表格环境上评论家在几百 episode 内收敛。在 Atari 上，用共享 CNN 主干 + 值头替换线性评论家。

### 步骤 2：n 步优势

给定长度为 `T` 的 rollout 和自举的最终 `V(s_T)`：

```python
def compute_advantages(rewards, values, gamma=0.99, lam=0.95, last_value=0.0):
    advantages = [0.0] * len(rewards)
    gae = 0.0
    for t in reversed(range(len(rewards))):
        next_v = values[t + 1] if t + 1 < len(values) else last_value
        delta = rewards[t] + gamma * next_v - values[t]
        gae = delta + gamma * lam * gae
        advantages[t] = gae
    returns = [a + v for a, v in zip(advantages, values)]
    return advantages, returns
```

`returns` 是评论家目标。`advantages` 是乘以 `∇ log π` 的量。

### 步骤 3：组合更新

```python
for step_i, (x, a, _r, probs) in enumerate(traj):
    adv = advantages[step_i]
    target_v = returns[step_i]

    # 评论家
    critic_update(w, x, target_v, lr_v)

    # 演员
    for i in range(N_ACTIONS):
        grad_logpi = (1.0 if i == a else 0.0) - probs[i]
        for j in range(N_FEAT):
            theta[i][j] += lr_a * adv * grad_logpi * x[j]
```

同策略，每次更新一个 rollout，演员和评论家使用不同的学习率。

### 步骤 4：并行化（A3C vs A2C）

- **A3C：** 启动 `N` 个线程。每个运行自己的环境和前向传播。定期将梯度更新推送到共享主网络。主网络上无锁——竞争是可以的，它们只是添加噪声。
- **A2C：** 在单进程中运行 `N` 个环境实例，将观察堆叠成 `[N, obs_dim]` 批次，批量前向传播，批量反向传播。更高的 GPU 利用率，确定性，更容易推理。2026 年的默认选择。

我们的玩具代码是单线程的以保持清晰；重写为批量 A2C 是三行 numpy。

## 陷阱

- **演员梯度前的评论家偏差。** 如果评论家是随机的，其基线是无信息的，你在纯噪声上训练。在开启策略梯度之前预热评论家几百步，或使用慢的演员学习率。
- **优势归一化。** 每个批次将优势归一化到零均值/单位标准差。以接近零的成本大幅稳定训练。
- **共享主干。** 在图像输入上对演员和评论家使用共享特征提取器。分离头。共享特征在两种损失上免费获得好处。
- **同策略契约。** A2C 为恰好一次更新重用数据。更多的话你的梯度是有偏的（重要性采样修正是 PPO 添加的东西）。
- **熵坍缩。** 没有 `c_e > 0`，策略在几百次更新内变成近确定性并停止探索。
- **奖励尺度。** 优势幅度依赖奖励尺度。在不同任务间归一化奖励（例如运行标准差除法）以获得一致的梯度幅度。

## 使用

A2C/A3C 在 2026 年很少是最终选择，但它们是之后一切精炼的架构：

| 方法 | 与 A2C 的关系 |
|------|-------------|
| PPO | A2C + 截断重要性比率用于多 epoch 更新 |
| IMPALA | A3C + V-trace 离策略修正 |
| SAC（第 9 阶段 · 07） | 带软值评论家的离策略 A2C（下一课） |
| GRPO（第 9 阶段 · 12） | 无评论家的 A2C——组相对优势 |
| DPO | A2C 坍缩为偏好排序损失，无采样 |
| AlphaStar / OpenAI Five | 带联赛训练 + 模仿预训练的 A2C |

如果你在 2026 年论文中看到"优势"，就想到 actor-critic。

## 交付

保存为 `outputs/skill-actor-critic-trainer.md`：

```markdown
---
name: actor-critic-trainer
description: 为给定环境生成 A2C / A3C / GAE 配置，指定优势估计和损失权重。
version: 1.0.0
phase: 9
lesson: 7
tags: [rl, actor-critic, a2c, a3c, gae]
---
```

## 练习

1. **简单。** 运行 `code/main.py` 比较带基线和不带基线的 REINFORCE。测量在 1,000 episode 时方差减少的百分比。
2. **中等。** 在 4×4 GridWorld 上对 `λ ∈ {0, 0.5, 0.95, 1.0}` 比较 GAE。绘制每个 λ 每 100 episode 的平均回报。找到最佳 λ。
3. **困难。** 实现 n 个并行环境的 A2C。测量使用 `n ∈ {1, 2, 4, 8}` 个并行环境时达到 -7（接近最优）约 100 episode 平均回报所需的墙钟时间。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|-----------------------|
| 优势 | "A(s, a)" | `G - V(s)` 或 `r + γ V(s') - V(s)`——好的量。 |
| GAE | "广义优势估计" | 所有 n 步优势的指数加权混合。 |
| A2C | "同步 actor-critic" | 在并行环境批次上的 Actor-critic。 |
| A3C | "异步 actor-critic" | 多线程 actor-critic，异步梯度推送。 |
| TD(λ) | "带资格迹的 TD" | 与 GAE 等效但不同的公式。 |
| 共享主干 | "共享特征" | 演员和评论家使用相同的 CNN 层。 |
| 批评家预处理 | "先训练 V" | 在开启演员之前预热评论家。 |

## 扩展阅读

- [Mnih et al. (2016). Asynchronous Methods for Deep Reinforcement Learning](https://arxiv.org/abs/1602.01783)——A3C 论文。
- [Schulman et al. (2016). High-Dimensional Continuous Control Using Generalized Advantage Estimation](https://arxiv.org/abs/1506.02438)——GAE 论文。
- [Sutton & Barto (2018). 第 13.4 节 Actor-Critic Methods](http://incompleteideas.net/book/RLbook2020.pdf)
- [Wu et al. (2017). Scalable trust-region method for deep reinforcement learning using Kronecker-factored approximation](https://arxiv.org/abs/1708.05144)——ACKTR，使用自然梯度的 actor-critic。