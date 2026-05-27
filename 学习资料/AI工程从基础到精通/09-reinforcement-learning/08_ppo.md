# 近端策略优化（PPO）

> A2C 每次更新后丢弃每个 rollout。PPO 将策略梯度包裹在截断的重要性比率中，因此你可以在相同数据上做 10+ epoch 而策略不会爆炸。Schulman et al. (2017)。2026 年仍然是默认的策略梯度算法。

**类型：** 构建
**语言：** Python
**前置要求：** 第 9 阶段 · 06（REINFORCE），第 9 阶段 · 07（Actor-Critic）
**时间：** 约 75 分钟

## 问题

A2C（第 07 课）是同策略的：梯度 `E_{π_θ}[A · ∇ log π_θ]` 需要从*当前* `π_θ` 采样的数据。做一次更新，`π_θ` 就变了；你使用的数据现在是离策略的。重用它，你的梯度就是有偏的。

Rollout 很昂贵。在 Atari 上，跨 8 个环境 × 128 步的一个 rollout = 1024 个转移和十几秒的环境时间。在一次梯度步骤后丢弃它是浪费的。

信任区域策略优化（TRPO，Schulman 2015）是第一个修复：约束每次更新使得新旧策略之间的 KL 散度保持在 `δ` 以下。理论上干净，但每次更新需要共轭梯度求解。2026 年没人运行 TRPO。

PPO（Schulman et al. 2017）用一个简单的截断目标替换了硬信任区域约束。一行额外的代码。每个 rollout 十个 epoch。无共轭梯度。足够好的理论保证。九年后它仍然是每个地方的默认策略梯度算法，从 MuJoCo 到 RLHF。

## 概念

![PPO 截断代理目标：比率截断在 1 ± ε](../assets/ppo.svg)

**重要性比率。**

`r_t(θ) = π_θ(a_t | s_t) / π_{θ_old}(a_t | s_t)`

这是新策略与收集数据的策略之间的似然比。`r_t = 1` 表示无变化。`r_t = 2` 表示新策略采取 `a_t` 的可能性是旧策略的两倍。

**截断代理目标。**

`L^{CLIP}(θ) = E_t [ min( r_t(θ) A_t, clip(r_t(θ), 1-ε, 1+ε) A_t ) ]`

两项：

- 如果优势 `A_t > 0` 且比率试图增长超过 `1 + ε`，截断抹平梯度——不要将好动作推到超过旧概率 `+ε` 以上。
- 如果优势 `A_t < 0` 且比率试图增长超过 `1 - ε`（意味着我们会让坏动作比其截断的减少更可能），截断限制梯度——不要将坏动作推到 `-ε` 以下。

`min` 处理另一个方向：如果比率在*有益*方向上移动，你仍然得到梯度（在会伤害你的那一侧不截断）。

典型 `ε = 0.2`。将目标作为 `r_t` 的函数绘制：一个分段线性函数，在"好侧"有一个平坦的顶部，在"坏侧"有一个平坦的底部。

**完整的 PPO 损失。**

`L(θ, φ) = L^{CLIP}(θ) - c_v · (V_φ(s_t) - V_t^{target})² + c_e · H(π_θ(·|s_t))`

与 A2C 相同的 actor-critic 结构。三个系数，通常 `c_v = 0.5`，`c_e = 0.01`，`ε = 0.2`。

**训练循环。**

1. 跨 `N` 个并行环境收集 `N × T` 个转移，每个环境 `T` 步。
2. 计算优势（GAE），将它们冻结为常量。
3. 将 `π_{θ_old}` 冻结为当前 `π_θ` 的快照。
4. 对于 `K` 个 epoch，对于每个 `(s, a, A, V_target, log π_old(a|s))` 的小批量：
   - 计算 `r_t(θ) = exp(log π_θ(a|s) - log π_old(a|s))`。
   - 应用 `L^{CLIP}` + 值损失 + 熵。
   - 梯度步骤。
5. 丢弃 rollout。返回步骤 1。

`K = 10` 和 64 的小批量是标准超参数集。PPO 很鲁棒：确切数字在 ±50% 内很少重要。

**KL 惩罚变体。** 原始论文提出了使用自适应 KL 惩罚的替代方案：`L = L^{PG} - β · KL(π_θ || π_old)`，其中 `β` 根据观察到的 KL 调整。截断版本成为主导；KL 变体在 RLHF 中幸存（其中到参考策略的 KL 是你无论如何都始终想要的单独约束）。

## 构建

### 步骤 1：在 rollout 时捕获 `log π_old(a | s)`

```python
for step in range(T):
    probs = softmax(logits(theta, state_features(s)))
    a = sample(probs, rng)
    s_next, r, done = env.step(s, a)
    buffer.append({
        "s": s, "a": a, "r": r, "done": done,
        "v_old": value(w, state_features(s)),
        "log_pi_old": log(probs[a] + 1e-12),
    })
    s = s_next
```

快照在 rollout 时获取一次。它在更新 epoch 期间不改变。

### 步骤 2：计算 GAE 优势（第 07 课）

与 A2C 相同。在批次内归一化。

### 步骤 3：截断代理更新

```python
for _ in range(K_EPOCHS):
    for mb in minibatches(buffer, size=64):
        for rec in mb:
            x = state_features(rec["s"])
            probs = softmax(logits(theta, x))
            logp = log(probs[rec["a"]] + 1e-12)
            ratio = exp(logp - rec["log_pi_old"])
            adv = rec["advantage"]
            surrogate = min(
                ratio * adv,
                clamp(ratio, 1 - EPS, 1 + EPS) * adv,
            )
            grad_logpi = onehot(rec["a"]) - probs
            if (adv > 0 and ratio >= 1 + EPS) or (adv < 0 and ratio <= 1 - EPS):
                pg_grad = 0.0  # 截断
            else:
                pg_grad = ratio * adv
            for i in range(N_ACTIONS):
                for j in range(N_FEAT):
                    theta[i][j] += LR * pg_grad * grad_logpi[i] * x[j]
```

"截断 → 零梯度"模式是 PPO 的核心。如果新策略已经在有益方向上漂移太远，更新就停止。

### 步骤 4：值和熵

添加标准 MSE 到评论家目标和演员上的熵奖励，与 A2C 相同。

### 步骤 5：诊断

每次更新要关注三件事：

- **平均 KL** `E[log π_old - log π_θ]`。应保持在 `[0, 0.02]`。如果超过 `0.1`，减少 `K_EPOCHS` 或 `LR`。
- **截断比例**——比率在 `[1-ε, 1+ε]` 之外的样本比例。应在 `~0.1-0.3`。如果 `~0`，截断从未触发 → 提高 `LR` 或 `K_EPOCHS`。如果 `~0.5+`，你在对 rollout 过拟合 → 降低它们。
- **可解释方差** `1 - Var(V_target - V_pred) / Var(V_target)`。评论家质量指标。应随着评论家学习向 1 攀升。

## 陷阱

- **截断系数调错。** `ε = 0.2` 是事实标准。降到 `0.1` 使更新过于怯懦；`0.3+` 会引发不稳定。
- **太多 epoch。** `K > 20` 经常导致不稳定，因为策略漂移远离 `π_old`。限制 epoch，特别是对大型网络。
- **没有奖励归一化。** 大的奖励尺度会吃掉截断范围。在计算优势之前归一化奖励（运行标准差）。
- **忘记优势归一化。** 每批次零均值/单位标准差归一化是标准。跳过它会在大多数基准上毁掉 PPO。
- **学习率不衰减。** PPO 受益于线性 LR 衰减到零。常数 LR 通常更差。
- **重要性比率数学错误。** 始终用 `exp(log_new - log_old)` 保持数值稳定，而非 `new / old`。
- **错误的梯度符号。** 最大化代理 = *最小化* `-L^{CLIP}`。翻转符号是最常见的 PPO 错误。

## 使用

PPO 是 2026 年跨惊人数量领域的默认 RL 算法：

| 用例 | PPO 变体 |
|------|---------|
| MuJoCo / 机器人控制 | 带高斯策略的 PPO，GAE(0.95) |
| Atari / 离散游戏 | 带类别策略的 PPO，滚动 128 步 rollout |
| LLM 的 RLHF | 带到参考模型 KL 惩罚的 PPO，奖励来自响应末尾的 RM |
| 大规模游戏代理 | IMPALA + PPO（AlphaStar、OpenAI Five） |
| 推理 LLM | GRPO（第 12 课）——无评论家的 PPO 变体 |
| 仅偏好数据 | DPO——PPO+KL 的闭式坍缩，无在线采样 |

PPO *损失形状*——截断代理 + 值 + 熵——是 DPO、GRPO 和几乎每个 RLHF 管道的脚手架。

## 交付

保存为 `outputs/skill-ppo-trainer.md`：

```markdown
---
name: ppo-trainer
description: 配置和调整 PPO，选择截断范围、epoch 数、GAE λ、值系数和熵奖励。
version: 1.0.0
phase: 9
lesson: 8
tags: [rl, ppo, policy-gradient, gae, rlhf]
---
```

## 练习

1. **简单。** 在 `code/main.py` 中运行 PPO 并变化截断范围 `ε ∈ {0.05, 0.1, 0.2, 0.3, 0.5}`。绘制每个的最终策略回报。最佳 ε 是多少？
2. **中等。** 固定 ε = 0.2，变化 PPO epoch 数 `K ∈ {1, 3, 5, 10, 20}`。测量达到 -7 平均回报所需的 wall-clock 步骤。是否存在回报递减？
3. **困难。** 计算更新前后策略之间的逐样本 KL。绘制 KL 随 epoch 的变化。推导 KL 增长预测截断比例开始上升的规律。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|-----------------------|
| PPO | "截断代理" | 近端策略优化——带截断重要性比率的 A2C。 |
| 重要性比率 | "r_t(θ)" | `π_new / π_old`——策略变化了多少。 |
| 截断 | "不要走太远" | 如果比率超过 1 ± ε，将梯度设为 0。 |
| KL 惩罚 | "保持在参考点附近" | 向损失添加 KL 散度项，而非硬截断。 |
| θ_old | "冻结的快照" | rollout 时策略参数的副本。 |
| GAE | "平滑 n 步" | 带 λ 平均的广义优势估计。 |
| 截断比例 | "诊断" | 被截断的样本比例。 |

## 扩展阅读

- [Schulman et al. (2017). Proximal Policy Optimization Algorithms](https://arxiv.org/abs/1707.06347)——PPO 论文。
- [Schulman et al. (2015). Trust Region Policy Optimization](https://arxiv.org/abs/1502.05477)——TRPO，PPO 的数学前驱。
- [Ilyas et al. (2020). A Closer Look at Deep Policy Gradients](https://arxiv.org/abs/1811.02553)——详细剖析 PPO 中实际起作用的部分。
- [Engstrom et al. (2020). Implementation Matters in Deep Policy Gradients: A Case Study on PPO and TRPO](https://arxiv.org/abs/2005.12729)——PPO 的实现级别关键因素。