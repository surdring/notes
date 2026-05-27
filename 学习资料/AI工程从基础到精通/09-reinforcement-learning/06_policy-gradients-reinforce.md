# 策略梯度——从零实现 REINFORCE

> 停止估计值函数。直接参数化策略，计算期望回报的梯度，沿梯度上升。Williams (1992) 用一个定理写出来了。这是 PPO、GRPO 和每个 LLM RL 循环存在的原因。

**类型：** 构建
**语言：** Python
**前置要求：** 第 3 阶段 · 03（反向传播），第 9 阶段 · 03（蒙特卡洛），第 9 阶段 · 04（TD 学习）
**时间：** 约 75 分钟

## 问题

Q-learning 和 DQN 参数化*值*函数。你通过 `argmax Q` 选择动作。对于离散动作和离散状态没问题。当动作连续时（在 10 维扭矩上的 `argmax`？）或当你想用随机策略时（`argmax` 构造上就是确定性的），它就坏了。

策略梯度改为参数化*策略*。`π_θ(a | s)` 是一个神经网络，输出动作上的分布。从中采样来行动。计算期望回报关于 `θ` 的梯度。沿梯度上升。没有 `argmax`。没有 Bellman 递归。只是对 `J(θ) = E_{π_θ}[G]` 做梯度上升。

REINFORCE 定理（Williams 1992）告诉你这个梯度是可计算的：`∇J(θ) = E_π[ G · ∇_θ log π_θ(a | s) ]`。运行一个 episode。计算回报。在每一步乘以 `∇ log π_θ(a | s)`。平均。梯度上升。完成。

2026 年的每个 LLM-RL 算法——PPO、DPO、GRPO——都是 REINFORCE 的精炼。用双手理解它是本阶段其余部分及第 10 阶段 · 07（RLHF 实现）和第 10 阶段 · 08（DPO）的前置条件。

## 概念

![策略梯度：softmax 策略、log-π 梯度、回报加权更新](../assets/policy-gradient.svg)

**策略梯度定理。** 对于由 `θ` 参数化的任意策略 `π_θ`：

`∇J(θ) = E_{τ ~ π_θ}[ Σ_{t=0}^{T} G_t · ∇_θ log π_θ(a_t | s_t) ]`

其中 `G_t = Σ_{k=t}^{T} γ^{k-t} r_{k+1}` 是从步骤 `t` 开始的折扣回报。期望是在从 `π_θ` 采样的完整轨迹 `τ` 上。

**证明很短。** 在期望下对 `J(θ) = Σ_τ P(τ; θ) G(τ)` 求导。使用 `∇P(τ; θ) = P(τ; θ) ∇ log P(τ; θ)`（对数导数技巧）。分解 `log P(τ; θ) = Σ log π_θ(a_t | s_t) + 不依赖 θ 的环境项`。环境项消失。两行代数就得到定理。

**方差减少技巧。** 原始 REINFORCE 有极高的方差——回报是嘈杂的，`∇ log π` 是嘈杂的，它们的乘积非常嘈杂。两个标准修复：

1. **基线减法。** 用 `G_t - b(s_t)` 替换 `G_t`，对任意不依赖 `a_t` 的基线 `b(s_t)`。无偏，因为 `E[b(s_t) · ∇ log π(a_t | s_t)] = 0`。典型选择：`b(s_t) = V̂(s_t)` 由评论家学习 → actor-critic（第 07 课）。
2. **按步回报。** 用 `Σ_t G_t^{from t} · ∇ log π_θ(a_t | s_t)` 替换 `Σ_t G_t · ∇ log π_θ(a_t | s_t)`。只有未来回报对给定动作重要——过去奖励贡献零均值噪声。

结合后得到：

`∇J ≈ (1/N) Σ_{i=1}^{N} Σ_{t=0}^{T_i} [ G_t^{(i)} - V̂(s_t^{(i)}) ] · ∇_θ log π_θ(a_t^{(i)} | s_t^{(i)})`

这是带基线的 REINFORCE——A2C（第 07 课）和 PPO（第 08 课）的直接祖先。

**Softmax 策略参数化。** 对于离散动作，标准选择：

`π_θ(a | s) = exp(f_θ(s, a)) / Σ_{a'} exp(f_θ(s, a'))`

其中 `f_θ` 是任意输出每个动作分数的神经网络。梯度有清晰形式：

`∇_θ log π_θ(a | s) = ∇_θ f_θ(s, a) - Σ_{a'} π_θ(a' | s) ∇_θ f_θ(s, a')`

即采取动作的分数减去其在策略下的期望值。

**连续动作的高斯策略。** `π_θ(a | s) = N(μ_θ(s), σ_θ(s))`。`∇ log N(a; μ, σ)` 有闭式解。这就是第 9 阶段 · 07 的 SAC 所需的一切。

## 构建

### 步骤 1：softmax 策略网络

```python
def policy_logits(theta, state_features):
    return [dot(theta[a], state_features) for a in range(N_ACTIONS)]

def softmax(logits):
    m = max(logits)
    exps = [exp(l - m) for l in logits]
    Z = sum(exps)
    return [e / Z for e in exps]
```

对表格环境使用线性策略（每个动作一个权重向量）。对 Atari 换入 CNN 并保留 softmax 头。

### 步骤 2：采样和对数概率

```python
def sample_action(probs, rng):
    x = rng.random()
    cum = 0
    for a, p in enumerate(probs):
        cum += p
        if x <= cum:
            return a
    return len(probs) - 1

def log_prob(probs, a):
    return log(probs[a] + 1e-12)
```

### 步骤 3：捕获对数概率的 rollout

```python
def rollout(theta, env, rng, gamma):
    trajectory = []
    s = env.reset()
    while not done:
        logits = policy_logits(theta, s)
        probs = softmax(logits)
        a = sample_action(probs, rng)
        s_next, r, done = env.step(s, a)
        trajectory.append((s, a, r, probs))
        s = s_next
    return trajectory
```

### 步骤 4：REINFORCE 更新

```python
def reinforce_step(theta, trajectory, gamma, lr, baseline=0.0):
    returns = compute_returns(trajectory, gamma)
    for (s, a, _, probs), G in zip(trajectory, returns):
        advantage = G - baseline
        grad_log_pi_a = [-p for p in probs]
        grad_log_pi_a[a] += 1.0
        for i in range(N_ACTIONS):
            for j in range(len(s)):
                theta[i][j] += lr * advantage * grad_log_pi_a[i] * s[j]
```

梯度 `∇ log π(a|s) = e_a - π(·|s)`（`a` 的 onehot 减去概率）是 softmax 策略梯度的核心。烧入肌肉记忆。

### 步骤 5：基线

最近 episode 上 `G` 的运行均值足以减少方差让 4×4 GridWorld 运行；约 500 episode 收敛。将基线升级为学习到的 `V̂(s)`，就得到 actor-critic。

## 陷阱

- **爆炸梯度。** 回报可能巨大。始终在乘以 `∇ log π` 之前在批次内将 `G` 归一化到 `~N(0, 1)`。
- **熵坍缩。** 策略过早收敛到近确定性动作，停止探索，卡住。修复：向目标添加熵奖励 `β · H(π(·|s))`。
- **高方差。** 原始 REINFORCE 需要数千 episode。评论家基线（第 07 课）或 TRPO/PPO 的信任区域（第 08 课）是标准修复。
- **样本低效。** 同策略意味着每次更新后丢弃每个转移。通过重要性采样的离策略修正能带回数据，代价是方差（PPO 的 ratio 是截断的 IS 权重）。
- **非稳态梯度。** 100 episode 前的相同梯度使用的是旧的 `π`。因此同策略方法每几次 rollout 更新一次。
- **信用分配。** 没有按步回报时，过去奖励贡献噪声。始终使用按步回报。

## 使用

2026 年，REINFORCE 很少直接运行，但其梯度公式无处不在：

| 用例 | 派生方法 |
|------|---------|
| 连续控制 | 带高斯策略的 PPO / SAC |
| LLM RLHF | 带 KL 惩罚的 PPO，运行在 token 级策略上 |
| LLM 推理（DeepSeek） | GRPO——带组相对基线的 REINFORCE，无评论家 |
| 多智能体 | 中心化评论家 REINFORCE（MADDPG、COMA） |
| 离散动作机器人 | A2C、A3C、PPO |
| 仅偏好设置 | DPO——REINFORCE 改写为偏好似然损失，无采样 |

当你在 2026 年训练脚本中读到 `loss = -advantage * log_prob` 时，那就是带基线的 REINFORCE。整篇论文（DPO、GRPO、RLOO）都是在这行之上做的方差减少技巧。

## 交付

保存为 `outputs/skill-policy-gradient-trainer.md`：

```markdown
---
name: policy-gradient-trainer
description: 为小型环境训练 REINFORCE 策略，适当选择基线和方差减少。
version: 1.0.0
phase: 9
lesson: 6
tags: [rl, policy-gradient, reinforce]
---
```

## 练习

1. **简单。** 在 `code/main.py` 中，在确定性 GridWorld 上比较 REINFORCE 和 Q-learning。绘制每 100 episode 的平均回报。在 2,000 episode 后每个达到什么平均回报？
2. **中等。** 向 REINFORCE 添加一个学习到的线性基线 `V̂(s) = w · s`（即 actor-critic）。它需要多少 episode 才能达到与原始 REINFORCE 相同的 500 episode 性能？测量方差减少。
3. **困难。** 为具有 2 维连续动作空间的连续 CartPole 实现高斯策略 REINFORCE。绘制策略均值 `μ(s)` 随训练 episode 的演变。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|-----------------------|
| 策略梯度 | "∇J" | `E[G · ∇ log π]`——回报加权 log 概率梯度。 |
| REINFORCE | "Williams 1992" | 蒙特卡洛策略梯度；每个 episode 的完整回报。 |
| 对数导数技巧 | "∇ log P" | `∇P = P · ∇ log P`——将梯度移入期望的代数。 |
| 基线 | "b(s)" | 从回报中减去以减少方差，保持无偏。 |
| 按步回报 | "未来回报" | 仅使用 t 之后的回报；过去奖励是噪声。 |
| 熵奖励 | "保持探索" | 向目标添加 `β · H(π)` 以鼓励随机性。 |
| 信用分配 | "哪个动作" | 将回报归因到单个动作，而非整个轨迹。 |

## 扩展阅读

- [Williams (1992). Simple Statistical Gradient-Following Algorithms for Connectionist Reinforcement Learning](https://link.springer.com/article/10.1007/BF00992696)——REINFORCE 论文。
- [Sutton & Barto (2018). 第 13 章 Policy Gradient Methods](http://incompleteideas.net/book/RLbook2020.pdf)
- [Schulman et al. (2015). Trust Region Policy Optimization](https://arxiv.org/abs/1502.05477)——TRPO，PPO 的前驱。
- [Schulman et al. (2017). Proximal Policy Optimization Algorithms](https://arxiv.org/abs/1707.06347)——PPO 论文。