# 深度 Q 网络（DQN）

> 2013：Mnih 在原始像素上训练了一个 Q-learning 网络，在七个 Atari 游戏上击败了每个经典 RL 代理。2015：扩展到 49 个游戏，发表在 Nature 上，引发了深度 RL 时代。DQN 是 Q-learning 加上三个使函数近似稳定的技巧。

**类型：** 构建
**语言：** Python
**前置要求：** 第 3 阶段 · 03（反向传播），第 9 阶段 · 04（Q-learning、SARSA）
**时间：** 约 75 分钟

## 问题

表格 Q-learning 需要为每个 (状态, 动作) 对单独一个 Q 值。国际象棋棋盘有约 10⁴³ 个状态。Atari 帧是 210×160×3 = 100,800 个特征。表格 RL 在数千个状态就死亡，更不用说数十亿。

修复在后见之明中显而易见：用神经网络替换 Q 表，`Q(s, a; θ)`。但后见之明的显而易见花了几十年。朴素的函数近似与 Q-learning 在"致命三元组"下发散——函数近似 + 自举 + 离策略学习。Mnih et al. (2013, 2015) 确定了三个稳定学习的工程技巧：

1. **经验重放** 去相关转移。
2. **目标网络** 冻结自举目标。
3. **奖励裁剪** 归一化梯度幅度。

Atari 上的 DQN 是第一次单一架构用单一超参数集从原始像素解决数十个控制问题。自此构建的一切"深度 RL"——DDQN、Rainbow、Dueling、Distributional、R2D2、Agent57——都堆叠在这个三技巧基础之上。

## 概念

![DQN 训练循环：env、重放缓冲、在线网络、目标网络、Bellman TD 损失](../assets/dqn.svg)

**目标。** DQN 最小化神经 Q 函数上的一步 TD 损失：

`L(θ) = E_{(s,a,r,s')~D} [ (r + γ max_{a'} Q(s', a'; θ^-) - Q(s, a; θ))² ]`

`θ` = 在线网络，每步通过梯度下降更新。`θ^-` = 目标网络，从 `θ` 定期复制（每约 10,000 步）。`D` = 过去转移的重放缓冲。

**三个技巧，按重要性排序：**

**经验重放。** `~10⁶` 个转移的环形缓冲。每个训练步骤均匀随机采样一个小批量。这打破了时间相关性（连续帧几乎相同），让网络多次从稀有奖励转移中学习，去相关连续梯度更新。没有它，同策略 TD 与神经网络在 Atari 上发散。

**目标网络。** 在 Bellman 方程两侧使用同一网络 `Q(·; θ)` 使目标每次更新都移动——"追逐自己的尾巴"。修复：保持第二个权重冻结的网络 `Q(·; θ^-)`。每 `C` 步，复制 `θ → θ^-`。这稳定了数千个梯度步骤的回归目标。软更新 `θ^- ← τ θ + (1-τ) θ^-`（DDPG、SAC 中使用）是更平滑的变体。

**奖励裁剪。** Atari 奖励幅度从 1 到 1000+ 不等。裁剪到 `{-1, 0, +1}` 阻止任何单一游戏主导梯度。当奖励幅度重要时是错误的；对 Atari 可以，因为只有符号重要。

**Double DQN。** Hasselt (2016) 修复最大化偏差：使用在线网络*选择*动作，目标网络*评估*它。

`target = r + γ Q(s', argmax_{a'} Q(s', a'; θ); θ^-)`

即插即用替换，一致更好。默认使用它。

**其他改进（Rainbow, 2017）：** 优先重放（更多采样高 TD 误差转移）、决斗架构（分离 `V(s)` 和优势头）、噪声网络（学习探索）、n 步回报、分布 Q（C51/QR-DQN）、多步自举。每个增加几个百分点；收益大致可加。

## 构建

这里的代码是仅标准库、无 numpy 的——我们使用手工编写的单隐藏层 MLP 在微型连续 GridWorld 上，因此每个训练步骤以微秒运行。算法与 Atari DQN 在大规模上相同。

### 步骤 1：重放缓冲

```python
class ReplayBuffer:
    def __init__(self, capacity):
        self.buf = []
        self.capacity = capacity
    def push(self, s, a, r, s_next, done):
        if len(self.buf) == self.capacity:
            self.buf.pop(0)
        self.buf.append((s, a, r, s_next, done))
    def sample(self, batch, rng):
        return rng.sample(self.buf, batch)
```

Atari 约 50,000 容量；我们的玩具环境 5,000 足够。

### 步骤 2：微型 Q 网络（手工 MLP）

```python
class QNet:
    def __init__(self, n_in, n_hidden, n_actions, rng):
        self.W1 = [[rng.gauss(0, 0.3) for _ in range(n_in)] for _ in range(n_hidden)]
        self.b1 = [0.0] * n_hidden
        self.W2 = [[rng.gauss(0, 0.3) for _ in range(n_hidden)] for _ in range(n_actions)]
        self.b2 = [0.0] * n_actions
    def forward(self, x):
        h = [max(0.0, sum(w * xi for w, xi in zip(row, x)) + b) for row, b in zip(self.W1, self.b1)]
        q = [sum(w * hi for w, hi in zip(row, h)) + b for row, b in zip(self.W2, self.b2)]
        return q, h
```

前向传播：线性 → ReLU → 线性。这就是整个网络。

### 步骤 3：DQN 更新

```python
def train_step(online, target, batch, gamma, lr):
    grads = zeros_like(online)
    for s, a, r, s_next, done in batch:
        q, h = online.forward(s)
        if done:
            y = r
        else:
            q_next, _ = target.forward(s_next)
            y = r + gamma * max(q_next)
        td_error = q[a] - y
        accumulate_grads(grads, online, s, h, a, td_error)
    apply_sgd(online, grads, lr / len(batch))
```

形状是第 04 课的 Q-learning，有两个区别：(a) 我们反向传播通过可微分的 `Q(·; θ)` 而非索引表格，(b) 目标使用 `Q(·; θ^-)`。

### 步骤 4：外循环

对于每个 episode，在 `Q(·; θ)` 上 ε-贪心行动，将转移推入缓冲，采样小批量，梯度步骤，定期同步 `θ^- ← θ`。模式：

```python
for episode in range(N):
    s = env.reset()
    while not done:
        a = epsilon_greedy(online, s, epsilon)
        s_next, r, done = env.step(s, a)
        buffer.push(s, a, r, s_next, done)
        if len(buffer) >= batch:
            train_step(online, target, buffer.sample(batch), gamma, lr)
        if steps % sync_every == 0:
            target = copy(online)
        s = s_next
```

在我们的微型 GridWorld 上用 16 维独热状态，代理约 500 episode 后学习到接近最优策略。在 Atari 上，扩展到 200M 帧并添加 CNN 特征提取器。

## 陷阱

- **致命三元组。** 函数近似 + 离策略 + 自举可能发散。DQN 用目标网络 + 重放缓解；不要移除任何一个。
- **探索。** ε 必须衰减，通常在前约 10% 的训练中从 1.0 到 0.01。没有足够的早期探索 Q 网收敛到局部盆地。
- **高估。** 嘈杂 Q 上的 `max` 有正偏差。在生产中始终使用 Double DQN。
- **奖励尺度。** 裁剪或归一化奖励；梯度幅度与奖励幅度成正比。
- **重放缓冲冷启动。** 不要在缓冲有几千个转移之前训练。约 20 个样本上的早期梯度过拟合。
- **目标同步频率。** 太频繁 ≈ 无目标网络；太不频繁 ≈ 陈旧目标。Atari DQN 使用 10,000 环境步骤。经验法则：每约训练视野的 1/100 同步一次。
- **观察预处理。** Atari DQN 堆叠 4 帧使状态 Markov。任何有速度信息的环境需要帧堆叠或循环状态。

## 使用

2026 年，DQN 很少是最先进的，但仍是参考离策略算法：

| 任务 | 选择方法 | 为什么不是 DQN？ |
|------|------------------|--------------|
| 离散动作类 Atari | Rainbow DQN 或 Muesli | 相同框架，更多技巧。 |
| 连续控制 | SAC / TD3（第 9 阶段 · 07） | DQN 无策略网络。 |
| 同策略 / 高吞吐量 | PPO（第 9 阶段 · 08） | 无重放缓冲；更易扩展。 |
| 离线 RL | CQL / IQL / Decision Transformer | 保守 Q 目标，无自举爆炸。 |
| 大离散动作空间（推荐系统） | 带动作嵌入的 DQN，或 IMPALA | 可以；装饰重要。 |
| LLM RL | PPO / GRPO | 序列级，非步级；不同损失。 |

经验仍在传播。重放和目标网络出现在 SAC、TD3、DDPG、SAC-X、AlphaZero 的自对弈缓冲和每个离线 RL 方法中。奖励裁剪作为 PPO 中的优势归一化延续。架构是蓝图。

## 交付

保存为 `outputs/skill-dqn-trainer.md`：

```markdown
---
name: dqn-trainer
description: 训练深度 Q 网络；设置经验重放、目标网络、探索调度；调试致命三元组。
version: 1.0.0
phase: 9
lesson: 5
tags: [rl, dqn, deep-rl, replay-buffer, target-network]
---
```

## 练习

1. **简单。** 运行 `code/main.py` 并改变同步频率 `C ∈ {10, 100, 1000}`。绘制每 100 episode 的平均回报。哪个 C 最快收敛？哪个发散？
2. **中等。** 实现 Double DQN（在目标网上的 `max` 处切换为在线网的 `argmax`）。对标准 DQN 和 Double DQN 在 5 次运行中测量 max Q 值。Double DQN 的 Q 值是否更低？
3. **困难。** 添加优先经验重放（通过 TD 误差的绝对值采样转移）。与统一采样 DQN 比较在 4×4 GridWorld 上用 100 步最大 episode 长度达到 `-6.5` 平均回报所需的 episode 数。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|-----------------------|
| 重放缓冲 | "经验重放" | 转移 (s, a, r, s', done) 的环形缓冲；随机采样以打破相关性。 |
| 目标网络 | "θ^-" | Q 网络的冻结副本；定期从在线网络同步以稳定 TD 目标。 |
| 奖励裁剪 | "幅度控制" | 将奖励限制在 `{-1, 0, +1}` 以归一化梯度。 |
| 致命三元组 | "为什么朴素 DQN 死亡" | 函数近似 + 自举 + 离策略 = 发散无缓解。 |
| Double DQN | "去偏差 max" | 在线选择动作；目标评估动作。 |
| Dueling DQN | "分离 V 和 A" | Q = V(s) + A(s, a) - mean(A)。 |
| 优先重放 | "学习这些更多" | 更高概率采样高 TD 误差转移。 |
| Rainbow | "厨房水槽" | 2017 年论文组合 7 个 DQN 扩展；在基准上击败所有。 |

## 扩展阅读

- [Mnih et al. (2015). Human-level control through deep reinforcement learning (Nature DQN)](https://www.nature.com/articles/nature14236)——原始 DQN 论文。
- [Hasselt, Guez, Silver (2016). Deep Reinforcement Learning with Double Q-learning](https://arxiv.org/abs/1509.06461)——DDQN。
- [Schaul et al. (2016). Prioritized Experience Replay](https://arxiv.org/abs/1511.05952)——优先重放。
- [Wang et al. (2016). Dueling Network Architectures for Deep Reinforcement Learning](https://arxiv.org/abs/1511.06581)——Dueling 架构。
- [Hessel et al. (2018). Rainbow: Combining Improvements in Deep Reinforcement Learning](https://arxiv.org/abs/1710.02298)——将所有东西放在一起。