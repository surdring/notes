# 奖励建模与 RLHF

> 人类无法为"好的助手回复"编写奖励函数，但他们可以比较两个回复并选出更好的。将奖励模型拟合到这些比较，然后让语言模型针对该奖励做 RL。Christiano 2017。InstructGPT 2022。将 GPT-3 变成 ChatGPT 的配方。2026 年它大多被 DPO 取代——但心智模型仍在。

**类型：** 构建
**语言：** Python
**前置要求：** 第 5 阶段 · 05（情感分析），第 9 阶段 · 08（PPO）
**时间：** 约 45 分钟

## 问题

你在下一个 token 预测目标上训练了一个语言模型。它写出符合语法的英语。它也撒谎、冗长、拒绝拒绝。你不能用更多预训练来修复——网页文本是问题，不是解药。

你想要一个*标量奖励*，说"对于指令 X，回复 A 比回复 B 更好"。手写该奖励函数是不可能的。"有帮助性"不是 token 上的闭式表达式。但人类可以比较两个输出并标记偏好。这在规模上收集起来很便宜。

RLHF（Christiano et al. 2017; Ouyang et al. 2022）将偏好转换为奖励模型，然后通过 PPO 针对该奖励优化 LM。三步：SFT → RM → PPO。这是交付 ChatGPT、Claude、Gemini 和 2023-2025 年每个对齐 LLM 的配方。

2026 年 PPO 步骤大多被 DPO（第 10 阶段 · 08）取代，因为它更便宜且对对齐微调几乎一样好。但*奖励模型*部分仍然支撑着每个 Best-of-N 采样器、每个从可验证奖励 RL 的管道，以及每个使用过程奖励模型的推理模型。理解 RLHF 就是理解整个对齐栈。

## 概念

![三阶段 RLHF：SFT，在成对偏好上训练 RM，带 KL 惩罚的 PPO](../assets/rlhf.svg)

**阶段 1：监督微调（SFT）。** 从预训练的基础模型开始。在目标行为的人工编写示范（遵循指令的回复、有帮助的答复等）上微调。结果：模型 `π_SFT` *偏向良好行为*但仍有无界的动作空间。

**阶段 2：奖励模型训练。**

- 收集对提示 `x` 的成对回复 `(y_+, y_-)`，由人类标记为"y_+ 比 y_- 更被偏好"。
- 训练奖励模型 `R_φ(x, y)` 对 `y_+` 分配更高分数。
- 损失：**Bradley-Terry 成对逻辑**：

  `L(φ) = -E[ log σ(R_φ(x, y_+) - R_φ(x, y_-)) ]`

  σ 是 sigmoid。奖励的差异意味着偏好的对数几率。BT 自 1952 年（Bradley-Terry）以来一直是标准，是现代 RLHF 中的主导选择。

- `R_φ` 通常从 SFT 模型初始化，顶部加一个标量头。相同的 transformer 主干；一个线性层输出奖励。

**阶段 3：带 KL 惩罚的针对 RM 的 PPO。**

- 从 `π_SFT` 初始化可训练策略 `π_θ`。保持冻结的*参考* `π_ref = π_SFT`。
- 回复 `y` 末尾的奖励：

  `r_total(x, y) = R_φ(x, y) - β · KL(π_θ(·|x) || π_ref(·|x))`

  KL 惩罚防止 `π_θ` 从 `π_SFT` 任意漂移——它是一个*正则化器*，不是硬信任区域。`β` 通常 `0.01`-`0.05`。
- 用此奖励运行 PPO（第 08 课）。优势在 token 级轨迹上计算，但 RM 只对完整回复评分。

**为什么需要 KL？** 没有它，PPO 会愉快地找到奖励黑客策略——RM 仅在分布内补全上训练。一个分布外的回复可能比任何人写的得分更高。KL 保持 `π_θ` 靠近 RM 训练的流形。它是 RLHF 中最重要的调节旋钮。

**2026 年状态：**

- **DPO**（Rafailov 2023）：闭式代数将阶段 2+3 坍缩为在偏好数据上的单一监督损失。无 RM，无 PPO。在对齐基准上相同质量，成本仅为几分之一。第 10 阶段 · 08 涵盖。
- **GRPO**（DeepSeek 2024–2025）：带组相对基线而非评论家的 PPO，奖励来自*验证器*（代码运行 / 数学答案匹配）而非人工训练的 RM。推理模型的主导选择。第 9 阶段 · 12 涵盖。
- **过程奖励模型（PRM）：** 对部分解（每个推理步骤）评分，用于 RLHF 和 GRPO 变体的推理。
- **宪法 AI / RLAIF：** 使用对齐的 LLM 生成偏好而非人类。扩展偏好预算。

## 构建

本课使用表示为字符串的微小合成"提示"和"回复"。RM 是词袋表示上的线性评分器。没有真正的 LLM——管道的*形状*重要，不是规模。见 `code/main.py`。

### 步骤 1：合成偏好数据

```python
PROMPTS = ["help me", "answer me", "explain this"]
GOOD_WORDS = {"clear", "specific", "kind", "thorough"}
BAD_WORDS = {"vague", "rude", "wrong", "short"}

def make_pair(rng):
    x = rng.choice(PROMPTS)
    y_good = rng.choice(list(GOOD_WORDS)) + " " + rng.choice(list(GOOD_WORDS))
    y_bad = rng.choice(list(BAD_WORDS)) + " " + rng.choice(list(BAD_WORDS))
    return (x, y_good, y_bad)
```

在真实 RLHF 中这被人类标注者替换。形状——`(prompt, preferred_response, rejected_response)`——完全相同。

### 步骤 2：Bradley-Terry 奖励模型

线性分数：`R(x, y) = w · bag(y)`。训练以最小化 BT 成对 log 损失：

```python
def rm_train_step(w, x, y_pos, y_neg, lr):
    r_pos = dot(w, bag(y_pos))
    r_neg = dot(w, bag(y_neg))
    p = sigmoid(r_pos - r_neg)
    for tok, cnt in bag(y_pos).items():
        w[tok] += lr * (1 - p) * cnt
    for tok, cnt in bag(y_neg).items():
        w[tok] -= lr * (1 - p) * cnt
```

几百次更新后，`w` 对好词 token 赋正权重，对坏词赋负权重。

### 步骤 3：RM 上的类 PPO 策略

我们的玩具策略从词汇表中产生单个 token。我们在 RM 下对该 token 评分，计算 `log π_θ(token | prompt)`，添加 KL-到-参考惩罚，并应用截断的 PPO 代理。

```python
def rlhf_step(theta, ref, w, prompt, rng, eps=0.2, beta=0.1, lr=0.05):
    logits_theta = policy_logits(theta, prompt)
    probs = softmax(logits_theta)
    token = sample(probs, rng)
    logits_ref = policy_logits(ref, prompt)
    probs_ref = softmax(logits_ref)
    reward = dot(w, bag([token])) - beta * kl(probs, probs_ref)
    # theta 上的 ppo 风格更新，将 reward 视为回报
    ...
```

### 步骤 4：监控 KL

每次更新跟踪平均 `KL(π_θ || π_ref)`。如果它爬到超过 `~5-10`，策略已从 `π_SFT` 漂移很远——降低 `β` 正在上升或奖励黑客正在开始。这是真实 RLHF 中的首要诊断。

### 步骤 5：使用 TRL 的生产配方

一旦你理解了玩具管道，以下是真实库用户写的相同循环。Hugging Face 的 [TRL](https://huggingface.co/docs/trl) 是参考实现——`RewardTrainer` 用于阶段 2，`PPOTrainer`（内置 KL-到-参考）用于阶段 3。

```python
# 阶段 2：从成对偏好训练奖励模型
from trl import RewardTrainer, RewardConfig
from transformers import AutoModelForSequenceClassification, AutoTokenizer

tok = AutoTokenizer.from_pretrained("meta-llama/Llama-3.1-8B-Instruct")
rm = AutoModelForSequenceClassification.from_pretrained(
    "meta-llama/Llama-3.1-8B-Instruct", num_labels=1
)

# 数据集行：{"prompt", "chosen", "rejected"}——Bradley-Terry 格式
trainer = RewardTrainer(
    model=rm,
    tokenizer=tok,
    train_dataset=preference_data,
    args=RewardConfig(output_dir="./rm", num_train_epochs=1, learning_rate=1e-5),
)
trainer.train()
```

```python
# 阶段 3：针对 RM 做 PPO，带对 SFT 参考的 KL 惩罚
from trl import PPOTrainer, PPOConfig, AutoModelForCausalLMWithValueHead

policy = AutoModelForCausalLMWithValueHead.from_pretrained("./sft-checkpoint")
ref    = AutoModelForCausalLMWithValueHead.from_pretrained("./sft-checkpoint")  # 冻结

ppo = PPOTrainer(
    config=PPOConfig(learning_rate=1.41e-5, batch_size=64, init_kl_coef=0.05,
                     target_kl=6.0, adap_kl_ctrl=True),
    model=policy, ref_model=ref, tokenizer=tok,
)
```

## 陷阱

- **RM 覆盖率。** RM 仅在分布的偏好上训练。如果 PPO 找到 RM 过于乐观的分布外回复，奖励黑客就开始了。KL 惩罚是首要防线。
- **奖励尺度。** RM 输出无界。在 RL 之前归一化到具有已知标准差的零均值。未归一化的奖励会破坏 PPO 的优势。
- **提示分布。** 在 RL 期间提示必须与 RM 训练的提示分布匹配。提示 ∞ 上的 RM 噪声会增加奖励方差——用实际查询训练。
- **KL 系数漂移。** 自适应 KL（PPO 调整 β 以保持接近目标 KL）是常见实践，但对 β 的跳跃可能不稳定。许多团队冻结 β。
- **SFT 重要性。** 在 RM 训练之前，你的 `π_SFT` 必须合理地好。垃圾 in → 垃圾偏好 → 垃圾 RM → 垃圾策略。RLHF 的成功始于好的 SFT。
- **长度偏差。** RM 可以学习更长的 = 更好的，无论内容。添加长度惩罚或对偏好标注进行长度控制。

## 使用

RLHF 在 2026 年正在过渡：

| 任务 | 选择方法 | 原因 |
|------|--------------|--------|
| 对齐微调（有帮助性/无害性） | DPO 或 Online-DPO | 更简单，相同质量，无 RM。 |
| 带人类偏好的推理 | PRM + GRPO | 过程监督优于仅结果。 |
| 代码/数学推理 | GRPO + 可验证奖励 | 不需要 RM——奖励是二进制正确的。 |
| 创意写作 / 开放式任务 | RLHF（RM + PPO + KL） | 模糊"好"需要人类训练的 RM。 |
| 多轮/代理 RL | 带逐轮 RM 的 RLHF | 部分完成评分。 |
| 成本敏感 | DPO / KTO / ORPO | 无 RL 的对齐。 |

RLHF 的心智模型——偏好 → 奖励 → 策略——理解相位 10 中的每个 LLM 对齐方法。即使 DPO 也是用闭式推导的 RLHF。三阶段管道是参考模型。

## 交付

保存为 `outputs/skill-rlhf-pipeline.md`：

```markdown
---
name: rlhf-pipeline
description: 设计用于对齐的 RLHF 三阶段管道，适当处理奖励建模、KL 惩罚和偏好数据。
version: 1.0.0
phase: 9
lesson: 9
tags: [rl, rlhf, reward-model, alignment, ppo]
---
```

## 练习

1. **简单。** 运行 `code/main.py` 并变化 KL 系数 `β ∈ {0, 0.01, 0.05, 0.1}`。绘制奖励和 KL 随训练步骤的变化。哪个 β 给出最高奖励同时保持 KL < 5？
2. **中等。** 在 RM 训练集中添加对抗样本（高奖励词但语义不好）。测量 PPO 策略是否开始生成它们（奖励黑客）。它需要多少步骤才发生？
3. **困难。** 从预训练的 HuggingFace 模型训练一个小型奖励模型（~1M 参数），使用 Anthropic 的 helpfulness-base 偏好数据的一个小子集。将其连接到 TRL 的 PPOTrainer 进行 1 epoch 的 RL。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|-----------------------|
| RLHF | "人类反馈 RL" | 三步：SFT → 奖励模型 → PPO。 |
| Bradley-Terry | "BT 模型" | 偏好概率 = sigmoid（奖励差）。 |
| 奖励黑客 | "RM 被欺骗" | PPO 利用 RM 的盲点；输出高分但无效的文本。 |
| KL 惩罚 | "保持在 SFT 附近" | 向奖励添加 -β · KL(π || π_ref)。 |
| DPO | "直接偏好优化" | RLHF 的闭式等价物；无 RM，无 PPO。 |
| PRM | "过程奖励模型" | 对推理步骤评分，而非最终答案。 |
| RLAIF | "AI 反馈 RL" | 使用 LLM 而非人类来生成偏好。 |

## 扩展阅读

- [Christiano et al. (2017). Deep Reinforcement Learning from Human Preferences](https://arxiv.org/abs/1706.03741)——原始 RLHF 论文。
- [Ouyang et al. (2022). Training language models to follow instructions with human feedback](https://arxiv.org/abs/2203.02155)——InstructGPT，将 RLHF 带到规模。
- [Rafailov et al. (2023). Direct Preference Optimization](https://arxiv.org/abs/2305.18290)——DPO 论文。
- [Lambert et al. (2024). Tulu 3: Pushing Frontiers in Open Language Model Post-Training](https://arxiv.org/abs/2411.15124)——将 RLHF 与 DPO 比较，在偏好优化方面有价值。