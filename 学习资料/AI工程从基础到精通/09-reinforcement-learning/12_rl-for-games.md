# 游戏强化学习——AlphaZero、MuZero 与 LLM 推理时代

> 1992：TD-Gammon 用纯 TD 在西洋双陆棋上击败人类冠军。2016：AlphaGo 击败李世石。2017：AlphaZero 从零开始统治国际象棋、将棋和围棋。2024：DeepSeek-R1 证明了相同配方，用 GRPO 替换 PPO，在推理上有效。游戏是驱动本阶段每次突破的基准。

**类型：** 构建
**语言：** Python
**前置要求：** 第 9 阶段 · 05（DQN），第 9 阶段 · 08（PPO），第 9 阶段 · 09（RLHF），第 9 阶段 · 10（MARD）
**时间：** 约 120 分钟

## 问题

游戏拥有 RL 想要的一切。干净的奖励（赢/输）。无限 episode（自博弈重置）。完美仿真（游戏*就是*仿真器）。离散或小连续动作空间。强制对抗鲁棒性的多智能体结构。

而游戏是每个主要 RL 突破的测试方式。TD-Gammon（西洋双陆棋，1992）。Atari-DQN（2013）。AlphaGo（2016）。AlphaZero（2017）。OpenAI Five（Dota 2，2019）。AlphaStar（星际争霸 II，2019）。MuZero（学习模型，2019）。AlphaTensor（矩阵乘法，2022）。AlphaDev（排序算法，2023）。DeepSeek-R1（数学推理，2025）——游戏 RL 技术在文本上有效的最新示范。

这一收尾课调研三个里程碑架构——AlphaZero、MuZero 和 GRPO——通过一个统一的视角：**自博弈 + 搜索 + 策略改进**。每个都推广了前一个；特别地，GRPO 是 AlphaZero 的配方应用于 LLM 推理，以 token 为动作，以数学验证为胜利信号。

## 概念

![AlphaZero ↔ MuZero ↔ GRPO：相同循环，不同环境](../assets/rl-games.svg)

**统一循环。**

```
while True:
    trajectory = self_play(current_policy, search)     # 与自己下棋
    policy_target = search.improved_policy(trajectory) # 搜索改进原始策略
    policy_net.update(policy_target, value_target)     # 在搜索输出上的监督
```

**AlphaZero（2017）。** Silver et al. 给定一个具有已知规则的游戏（国际象棋、将棋、围棋）：

- 策略-值网络：一个塔 `f_θ(s) → (p, v)`。`p` 是合法动作上的先验。`v` 是期望的游戏结果。
- 蒙特卡洛树搜索（MCTS）：在每个动作处，展开一棵可能延续的树。使用 `(p, v)` 作为先验 + 自举。通过 UCB（PUCT）选择节点：`a* = argmax Q(s, a) + c · p(a|s) · √N(s) / (1 + N(s, a))`。
- 自博弈：进行智能体对智能体的游戏。在第 `t` 步，MCTS 访问分布 `π_t` 成为策略训练目标。
- 损失：`L = (v - z)² - π · log p + c · ||θ||²`。`z` 是游戏结果（+1 / 0 / -1）。

零人类知识。零手工启发式。一个单一配方，每个游戏各自经过几千万自博弈对局后精通了国际象棋、将棋和围棋。

**MuZero（2019）。** Schrittwieser et al. 移除了规则已知的要求。

- 不是固定环境，而是学习一个*潜在动力学模型* `(h, g, f)`：
  - `h(s)`：将观测编码到潜在状态。
  - `g(s_latent, a)`：预测下一个潜在状态 + 奖励。
  - `f(s_latent)`：预测策略先验 + 值。
- MCTS 在*学习的潜在空间*中运行。相同搜索，相同训练循环。
- 在围棋、国际象棋、将棋*和* Atari 上有效——一种算法，无规则知识。

**Stochastic MuZero（2022）。** 添加随机动力学和机会节点；扩展到西洋双陆棋类游戏。

**Muesli、Gumbel MuZero（2022-2024）。** 样本效率和确定性搜索的改进。

**GRPO（2024-2025）。** DeepSeek-R1 配方。相同 AlphaZero 形状的循环，应用于语言模型推理：

- "游戏"：回答数学 / 编程 / 推理问题。"赢" = 验证器（测试用例通过、数值答案匹配）返回 1。
- 策略：LLM。动作：token。状态：提示 + 到目前为止的回复。
- 无评论家（PPO 风格 V_φ）。相反，对每个提示，从策略采样 `G` 个补全。为每个计算奖励。使用**组相对优势** `A_i = (r_i - mean_r) / std_r` 作为 REINFORCE 风格更新的信号。
- 带到参考策略的 KL 惩罚以防止漂移（类似 RLHF）。
- 完整损失：

  `L_GRPO(θ) = -E_{q, {o_i}} [ (1/G) Σ_i A_i · log π_θ(o_i | q) ] + β · KL(π_θ || π_ref)`

无奖励模型、无评论家、无 MCTS。组相对基线替换了所有三个。在推理基准上以极低成本匹配或超过 PPO-RLHF 质量。

**完整的 R1 配方。** DeepSeek-R1（DeepSeek 2025）是同一篇论文中的两个模型：

- **R1-Zero。** 从 DeepSeek-V3 基础模型开始。无 SFT。直接用两个奖励组件应用 GRPO：*准确性奖励*（基于规则——最终答案是否解析为正确的数字 / 代码是否通过单元测试）和*格式奖励*（补全是否将其思维链包裹在 ` 思考… 回复` 标签中）。经过数千步，平均响应长度从 ~100 增长到 ~10,000 token，数学基准分数攀升到接近 o1-preview 水平。模型从头学习推理。缺点：其思维链往往不可读、混合语言且缺乏风格润色。
- **R1。** 用四阶段管道修复 R1-Zero 的可读性问题：
  1. **冷启动 SFT。** 收集几千个格式干净的长 CoT 示范。在它们上对基础模型进行监督微调。这给出了一个可读的起点。
  2. **推理导向的 GRPO。** 应用带有准确性和格式奖励加上*语言一致性*奖励的 GRPO 以防止代码切换。
  3. **拒绝采样 + SFT 第二轮。** 从 RL 检查点采样约 600K 推理轨迹，仅保留那些有正确最终答案和可读 CoT 的，并与约 200K 非推理 SFT 示例（写作、QA、自我认知）组合。再次微调基础模型。
  4. **全谱 GRPO。** 再一轮 RL 覆盖推理（基于规则的奖励）和通用对齐（有帮助性/无害性基于偏好的奖励）。

结果在 AIME 和 MATH-500 上以开放权重匹配 o1，且足够小可蒸馏。同一篇论文还通过 SFT 在 R1 的推理轨迹上发布了六个蒸馏的密集模型（Qwen-1.5B 到 Llama-70B）——学生端无 RL。强 RL 教师的蒸馏始终在学生的规模上优于从头 RL。

**为什么 GRPO 而非 PPO 用于推理。** DeepSeekMath 论文（2024 年 2 月）中的三个原因：(1) 无值网络需训练，内存减半；(2) 组基线自然处理推理任务产生的稀疏轨迹末尾奖励；(3) 每提示归一化使优势在难度差异极大的问题之间可比，这是 PPO 的单一评论家无法做到的。

**无搜索 vs 基于搜索。** 游戏已分支：

- *长视界的完全信息游戏*（围棋、国际象棋）：仍然基于搜索。AlphaZero / MuZero 主导。
- *LLM 推理*：生产中尚没有 MCTS；完整 rollout 上的 GRPO，推理计算用 best-of-N。过程奖励模型（PRM）暗示步骤级搜索正在被加回来。

## 构建

`code/main.py` 中的代码实现了**微型 GRPO**——一个多组样本的赌博机。算法与 LLM 上的相同；只有策略和环境更简单。它教授*损失*和*组相对优势*，这是 2025 年的创新。

### 步骤 1：一个小小的验证器环境

```python
QUESTIONS = [
    {"prompt": "q1", "correct": 3},
    {"prompt": "q2", "correct": 1},
]

def verify(prompt_idx, answer_token):
    return 1.0 if answer_token == QUESTIONS[prompt_idx]["correct"] else 0.0
```

在真实 GRPO 中验证器运行单元测试或检查数学等式。

### 步骤 2：策略：每个提示 K 个答案 token 上的 softmax

```python
def policy_probs(theta, p_idx):
    return softmax(theta[p_idx])
```

等价于 LLM 以提示为条件的最终层输出。

### 步骤 3：组采样和组相对优势

```python
def grpo_step(theta, p_idx, G=8, beta=0.01, lr=0.1, rng=None):
    probs = policy_probs(theta, p_idx)
    samples = [sample(probs, rng) for _ in range(G)]
    rewards = [verify(p_idx, s) for s in samples]
    mean_r = sum(rewards) / G
    std_r = stddev(rewards) + 1e-8
    advs = [(r - mean_r) / std_r for r in rewards]

    for a, A in zip(samples, advs):
        grad = onehot(a) - probs
        for i in range(len(probs)):
            theta[p_idx][i] += lr * A * grad[i]
    # KL 惩罚：将 theta 拉向 reference
    for i in range(len(probs)):
        theta[p_idx][i] -= beta * (theta[p_idx][i] - reference[p_idx][i])
```

组相对优势是 2024 年 DeepSeek 的技巧。不需要评论家。"基线"是组均值，归一化使用组标准差。

### 步骤 4：与 REINFORCE 基线比较（无值）

相同设置，相同计算，纯 REINFORCE。GRPO 收敛更快且更稳定。

### 步骤 5：观察熵和 KL

与 RLHF 相同的诊断：到参考的平均 KL，策略熵，随时间变化的奖励。一旦这些稳定，训练完成。

## 陷阱

- **通过验证器博弈的奖励黑客。** GRPO 继承了 RLHF 的风险：如果验证器错误或可利用，LLM 会找到利用方式。鲁棒的验证器（多个测试用例、形式化证明）很重要。
- **组大小太小。** 组基线的方差按 `1/√G` 变化。低于 `G = 4`，优势信号嘈杂；标准选择是 `G = 8` 到 `64`。
- **长度偏差。** 不同长度的 LLM 补全有不同的对数概率。除以 token 数归一化，或使用序列级对数概率，或截断到最大长度。
- **纯自博弈循环。** AlphaZero 风格训练可能在一股和博弈上卡在支配性循环中。通过多样化对手池缓解（联赛博弈，第 10 课）。
- **搜索策略不匹配。** AlphaZero 训练策略模仿搜索输出。如果策略网络太小无法表示搜索的分布，训练会停滞。
- **计算下限。** MuZero / AlphaZero 需要大量计算。一个消融实验通常是数百 GPU 小时。微型演示存在（例如 Connect Four 上的 AlphaZero）用于学习。
- **验证器覆盖。** 单元测试对错误解通过会强化错误。设计能捕获边缘情况的验证器。

## 使用

2026 年游戏 RL 景观：

| 领域 | 方法 | 原因 |
|------|------|------|
| 国际象棋/围棋/将棋 | AlphaZero / MuZero（搜索） | 长视界完全信息；搜索是 SOTA。 |
| 扑克（不完美信息） | ReBeL / DeepStack（反事实遗憾最小化） | 博弈论方法。 |
| Atari | MuZero / Muesli | 无模型 + 基于模型。 |
| LLM 数学推理 | GRPO（DeepSeek-R1） | 无搜索，规则验证。 |
| LLM 代码 | GRPO + 单元测试奖励 | 与 R1 相同，以测试作为验证器。 |
| 一般游戏（学规则） | MuZero | 从像素和分数学习潜在动力学。 |
| LLM 规划 / 工具使用 | GRPO + 轨迹奖励（过程 RM） | 带过程监督的长轨迹 RL。 |

游戏 RL 是一种心智模型。自博弈、搜索和蒸馏的循环过去已被证明在围棋和星际争霸上有效，现在在数学和代码上有效。当 2026 年有人推出一个新领域时，他们会用这个循环。

## 交付

保存为 `outputs/skill-game-rl-designer.md`：

```markdown
---
name: game-rl-designer
description: 设计用于离散或语言动作空间上游戏/推理的自博弈 + 搜索 + 改进循环，从 AlphaZero 到 GRPO。
version: 1.0.0
phase: 9
lesson: 12
tags: [rl, alphazero, muzero, grpo, reasoning, games]
---

给定一个任务（游戏规则或推理问题格式），输出完整的训练配方：

1. 架构。AlphaZero（已知规则）、MuZero（学习规则）、或 GRPO（语言空间，基于规则的奖励）。
2. 搜索（如果适用）。MCTS / 无搜索 / best-of-N 选择。节点评分和自举。
3. 策略改进。损失组件：策略、值、KL 惩罚、熵奖励。超参数值。
4. 训练循环。自博弈频率、目标网络更新、重放缓冲（如有）。
5. 蒸馏管道。如果有：教师规模、数据量、学生架构。
```

## 练习

1. **简单。** 运行 `code/main.py` 中的微型 GRPO 并变化组大小 `G ∈ {2, 4, 8, 16}`。绘制平均奖励 vs 步骤。哪一个最快收敛？
2. **中等。** 实现带有标量值头评论家的 PPO（第 08 课）与具有组基线的 GRPO。在相同计算预算下比较两者。GRPO 是否匹配或超过 PPO？
3. **困难。** 为一个简单游戏棋盘（例如 3×3 Tic-Tac-Toe 带合法动作掩码）实现微型 AlphaZero。使用 MCTS + 策略值网络 + 自博弈。多少对局后网络击败随机玩家？

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|-----------------------|
| AlphaZero | "自博弈 + MCTS" | 策略-值网络用搜索产生的改进策略训练。 |
| MuZero | "AlphaZero 无规则" | 学习潜在动力学模型；在潜在空间中搜索。 |
| MCTS | "蒙特卡洛树搜索" | 树搜索算法，使用先验和值估计引导节点选择。 |
| PUCT | "带先验的 UCB" | UCB 公式变体：`Q + c · p · √N / (1+n)`。 |
| GRPO | "组相对策略优化" | 无评论家 PPO；优势 = (r_i - mean_r) / std_r。 |
| 验证器 | "基于规则的奖励" | 返回 1/0 的正确性函数，例如单元测试 / 答案匹配。 |
| 自博弈 | "我对我的过去自我" | 智能体与自身副本对战；对称改进。 |
| 蒸馏 | "教师 → 学生" | 在教师输出上训练学生，而非从头 RL。 |

## 扩展阅读

- [Silver et al. (2017). Mastering Chess and Shogi by Self-Play with a General Reinforcement Learning Algorithm](https://arxiv.org/abs/1712.01815)——AlphaZero。
- [Schrittwieser et al. (2020). Mastering Atari, Go, Chess and Shogi by Planning with a Learned Model](https://www.nature.com/articles/s41586-020-03051-4)——MuZero。
- [DeepSeek-AI (2025). DeepSeek-R1: Incentivizing Reasoning Capability in LLMs via Reinforcement Learning](https://arxiv.org/abs/2501.12948)——DeepSeek-R1 和 GRPO。
- [DeepSeek-AI (2024). DeepSeekMath: Pushing the Limits of Mathematical Reasoning in Open Language Models](https://arxiv.org/abs/2402.03300)——介绍 GRPO 的 DeepSeekMath 论文。
- [Guo et al. (2025). DeepSeek-R1 and Beyond: A Survey](https://arxiv.org/abs/2503.06497)——R1 论文及其影响的全面调研。