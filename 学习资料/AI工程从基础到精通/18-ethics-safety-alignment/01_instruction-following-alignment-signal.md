# 指令遵循作为对齐信号

> 之后对 RLHF 的每一次批评都是在反驳这个流程。在研究优化压力如何扭曲代理指标之前，你必须先看清这个代理是什么。InstructGPT（Ouyang et al., 2022）定义了参考架构：在指令-响应对上进行监督微调（SFT），在成对偏好排序上训练一个奖励模型（RM），以及针对该奖励模型的 PPO，同时带有一个相对于 SFT 策略的 KL 惩罚。一个 1.3B 的 InstructGPT 比 175B 的 GPT-3 更受偏好。这单一结果就是每一个前沿实验室在 2026 年仍在交付 RLHF 形态的后训练流程的原因。

**类型：** 学习
**语言：** Python（标准库，玩具级三阶段流水线）
**前置知识：** 第 10 阶段 · 06（SFT），第 10 阶段 · 07（RLHF），第 10 阶段 · 08（DPO）
**时间：** 约 45 分钟

## 学习目标

- 说出 InstructGPT 流程的三个阶段以及每个阶段使用的损失函数。
- 解释为什么一个 1.3B 的指令微调模型在人类偏好评估中击败了原始 175B 的 GPT-3。
- 说明第 3 阶段的 KL 惩罚在防范什么，以及为什么移除它会导致模式寻求行为（Mode-Seeking Behaviour）。
- 描述对齐税（Alignment Tax）以及 Ouyang et al. 用来对抗它的 PPO-ptx 缓解方案。

## 问题

预训练语言模型补全文本。它们不回答问题。询问 GPT-3"写一个反转列表的 Python 函数"，你通常得到的是另一个提示词，因为训练分布的大部分是继续写更多网页文本的网页文本。模型在做它的工作——只是这个工作是错的。

每个严肃的实验室用来修复这个问题的代理都是人类偏好。两个补全结果交给评分者；评分者选出更好的一个；奖励模型学习评分者。然后一个 RL 循环将策略推向奖励模型评分高的输出方向。这就是 InstructGPT 的完整论点，用三句话概括。论文的其余部分是工程。

## 概念

### 第 1 阶段：监督微调（SFT）

收集提示词-响应对，其中响应是一个善意人类会写的内容。Ouyang et al. 使用了标注者和 OpenAI API 的 13k 提示词。用标准交叉熵损失在此数据上微调基础模型。

SFT 给你的：模型现在回答问题而非补全它们。SFT 没给你的：当多个答案都可信时，哪个答案是评分者偏好的任何信号。

### 第 2 阶段：奖励模型（RM）

对每个提示词，从 SFT 模型中采样 K 个补全结果。一个标注者对它们排序。训练一个奖励模型对任何提示词-响应对打分，使得对于 `y_w` 优于 `y_l` 的对：

```
L_RM = -log sigmoid(r(x, y_w) - r(x, y_l))
```

这是 Bradley-Terry 成对偏好损失。RM 通常从 SFT 模型初始化，将 LM 头替换为标量头。

奖励模型较小：6B 对 175B 的 InstructGPT 足够了。它们也很脆弱——论文第 5 节主要是关于在小规模下出现的奖励攻击行为。

### 第 3 阶段：带 KL 惩罚的 PPO

定义目标：

```
J(pi) = E_{x~D, y~pi(.|x)} [ r(x, y) ] - beta * KL(pi(.|x) || pi_SFT(.|x))
```

用 PPO 最大化。KL 项防止 `pi` 远离 SFT 策略漂移。没有它，优化器会找到对抗性示例——在 RM 下得分高的字符串，因为 RM 从未见过它们，而非因为人类实际上偏好它们。

KL 系数 `beta` 是 RLHF 最重要的超参数。太低：奖励攻击。太高：相对 SFT 没有改进。

### 对齐税

RLHF 之后，模型在人类偏好上更优，但在标准基准（SQuAD、HellaSwag、DROP）上退化。Ouyang et al. 称之为对齐税，并用 PPO-ptx 修复：将预训练梯度混入 RL 目标，使模型不会遗忘从未被奖励的下游任务。

```
J_ptx(pi) = J(pi) + gamma * E_{x~D_pretrain} [ log pi(x) ]
```

PPO-ptx 成为标准。Anthropic、DeepMind 和 Meta 都使用某种变体。

### 结果

一个 1.3B 的 InstructGPT（SFT + RM + PPO-ptx）在标注者的偏好中约 70% 的情况下优于 175B 的基础 GPT-3。在来自生产流量的隐藏测试提示词上差距更大。从这一数字可以读出两点：

1. 对齐（Alignment）与能力（Capability）是不同的维度。175B 模型有更多的能力；1.3B 模型有更多的对齐；标注者偏好已对齐的那个。
2. 能力下限由基础模型设定。你无法通过 RLHF 让一个基础模型知道它从未见过的事实。

### 为什么这是第 18 阶段的参考点

后续课程中的每一个批评——奖励攻击（第 2 课）、DPO（第 3 课）、奉承（第 4 课）、CAI（第 5 课）、休眠代理（第 7 课）、对齐伪装（第 9 课）——都是反对这个流程的某个部分。奖励攻击攻击第 2 阶段。DPO 将第 2 和第 3 阶段合并。CAI 替代了人类标注者。奉承表明标注者是一个有偏见的信号。对齐伪装表明策略可以完全绕过第 3 阶段。如果你脑海中没有这个流程，你就无法跟上任何这些批评。

## 使用它

`code/main.py` 在玩具偏好数据上模拟三个阶段。基础"策略"是动作 {A, B, C} 上的一个有偏硬币。第 1 阶段 SFT 在 200 个提示词上模拟标注者动作。第 2 阶段从 500 个成对排序中拟合一个 Bradley-Terry 奖励模型。第 3 阶段运行一个简化的 PPO 更新，带有一个相对于 SFT 策略的 KL 惩罚。你可以观察奖励爬升、KL 散度增长以及策略漂移——你可以关闭 KL 项来看奖励攻击在 50 个更新步骤内出现。

应关注的内容：

- `beta = 0.1` vs `beta = 0.0` 下的奖励轨迹。
- 训练步骤中 KL(pi || pi_SFT) 的变化。
- 与标注者偏好相比的最终动作分布。

## 交付它

本课生成 `outputs/skill-instructgpt-explainer.md`。给定一个 RLHF 流程描述或论文摘要，它会识别三个阶段中哪一个被修改，每个阶段使用的损失是什么，以及是否存在 KL 惩罚或等效正则项。

## 练习

1. 运行 `code/main.py`。设置 `beta = 0.0` 并报告 200 个 PPO 步骤后的动作分布。用一段话解释模式寻求行为。

2. 修改奖励模型，给动作 B 设置 +0.5 偏置（模拟奖励 bug）。用 `beta = 0.1` 运行 PPO。KL 惩罚是否阻止了策略利用此偏置？在哪个 `beta` 下利用变得可见？

3. 阅读 Ouyang et al.（arXiv:2203.02155）图 1。通过运行 PPO 1、5、20、100 步并测量相对于 SFT 模型的偏好，复现标注者偏好曲线。

4. 论文第 4.3 节报告 1.3B InstructGPT 约 70% 的情况下击败 175B GPT-3。为什么在隐藏的生产提示词上这个比例会比标注者自己的提示词上更高？

5. 在相同偏好数据上将 PPO 损失替换为 DPO（第 10 阶段 · 08）。比较最终策略漂移（相对于 SFT 的 KL）和最终奖励。在匹配奖励的情况下，哪种方法漂移更大？

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|------------------------|
| SFT | "指令微调" | 第 1 阶段：在提示词-响应对上进行交叉熵微调 |
| Reward model | "RM" | 基于（提示词，响应）的标量回归器，用 Bradley-Terry 在成对标签上训练 |
| Bradley-Terry | "成对偏好损失" | -log sigmoid(r_w - r_l)；将成对排序归约为二分类 |
| KL penalty | "正则项" | `beta * KL(pi || pi_SFT)`——将 RL 策略保持在 SFT 锚点附近 |
| PPO-ptx | "带预训练混合的 PPO" | 在 PPO 目标中加入一部分预训练对数似然，以抵消对齐税 |
| Alignment tax | "RLHF 退化" | RLHF 后 RLHF 未针对的标准基准上的性能下降 |
| Labeler preference | "真实" | 人类排序的样本；RM 是此的统计代理，而非"人类价值观" |

## 延伸阅读

- [Ouyang et al. — Training language models to follow instructions with human feedback (arXiv:2203.02155)](https://arxiv.org/abs/2203.02155) — InstructGPT 论文，所有后续 RLHF 流程的基础
- [Stiennon et al. — Learning to summarize from human feedback (arXiv:2009.01325)](https://arxiv.org/abs/2009.01325) — RLHF-用于摘要的前身
- [Christiano et al. — Deep reinforcement learning from human preferences (arXiv:1706.03741)](https://arxiv.org/abs/1706.03741) — 原始的基于偏好的 RL 公式
- [Bai et al. — Training a Helpful and Harmless Assistant with RLHF (arXiv:2204.05862)](https://arxiv.org/abs/2204.05862) — Anthropic 对 InstructGPT 流程的 HH 扩展