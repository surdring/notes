# 推测解码与 EAGLE

> 一个前沿 LLM 每生成一个 token 都需要对数十亿参数进行一次完整的前向传播。这次前向传播是严重超配的：大多数时候，一个更小的模型可以正确猜测接下来的 3-5 个 token，而大模型只需要验证这个猜测。当猜测正确时，你以一次传播的代价获得了 5 个 token。推测解码（Leviathan 等人 2023）使其精确化，而 EAGLE-3（2025）将接受率推高到每次验证约 4.5 个 token——在匹配的输出分布下实现 4-5x 加速。

**类型：** 构建
**语言：** Python（含 numpy）
**前置知识：** 第十阶段 第 12 课（推理优化），第十阶段 第 04 课（预训练迷你 GPT）
**时间：** 约 75 分钟

## 问题

70B 级别模型在 H100 上的解码吞吐量通常是每秒 40-80 个 token。每个 token 需要一次完整的前向传播从 HBM 读取所有模型权重。你无法在不变更输出的情况下缩小模型。你无法在内存之外增加批量大小。你被困住了——除非你能让模型每次前向传播输出超过一个 token。

自回归生成看起来本质上是串行的：`x_{t+1} = sample(p(· | x_{1:t}))`。但存在并发机会。如果你有一个廉价预测器说"接下来 4 个 token 大概是 [a, b, c, d]"，你可以在大模型的单次前向传播中验证所有 5 个位置，并接受最长匹配前缀。

Leviathan、Kalai、Matias（2023，"Fast Inference from Transformers via Speculative Decoding"）通过一个巧妙的接受/拒绝规则使其精确化，该规则保持了目标模型的采样分布。相同的输出分布，快 2-4×。

## 核心概念

### 双模型设置

- **目标模型** `M_p`：你实际想从中采样的大型、慢速、高质量模型。分布：`p(x)`。
- **草稿模型** `M_q`：小型、快速、低质量模型。分布：`q(x)`。小 5-30×。

每步：

1. 草稿模型自回归地提出 `K` 个 token：`x_1, x_2, ..., x_K ~ q`。
2. 目标模型对所有 `K+1` 个位置运行一次前向传播，为每个提出的 token 产生 `p(x_k)`。
3. 通过下述修改后的拒绝采样规则从左到右接受/拒绝每个 token。接受最长匹配前缀。
4. 如果任何 token 被拒绝，从修正分布中采样替换并停止。否则从 `p(· | x_1...x_K)` 采样一个奖励 token。

如果草稿与目标完美匹配，你每次目标前向传播获得 K+1 个 token。如果草稿在位置 1 错误，你只获得 1 个 token。

### 精确性规则

推测解码在分布上可证明等价于从 p 采样。拒绝规则：

```
对于每个草稿 token x_t:
    r ~ Uniform(0, 1)
    如果 r < p(x_t) / q(x_t):
        接受 x_t
    否则:
        从残差中采样替换: (p - q)+ / ||(p - q)+||_1
        停止
```

其中 `(p - q)+` 表示逐点差的正部。当草稿和目标一致时（`p ≈ q`），接受概率接近 1。当它们不一致时，残差分布的构造使得整体样本仍然精确为 `p`。

**贪心情形。** 对于 temperature=0 采样，只需检查 `argmax(p) == x_t`。如果是则接受；如果否，输出 `argmax(p)` 并停止。

### 期望加速比

如果草稿模型的 token 级接受率为 `α`，每次目标前向传播的期望产生 token 数为：

```
E[tokens] = (1 - α^{K+1}) / (1 - α)        # K = 草稿长度, α ∈ [0, 1]
```

在 `α = 0.8, K = 4` 时：`(1 - 0.8^5)/(1 - 0.8) = 3.36` 个 token 每次前向传播。单次目标前向传播的成本大约是 `cost_q * K + cost_p`（K 次草稿步加一次目标验证）。如果 `cost_p >> cost_q * K`，吞吐量加速比为 `3.36× / 1 = 3.36×`。

唯一真正的参数是 `α`，它完全取决于草稿-目标对齐程度。好的草稿就是一切。

### 训练草稿：蒸馏

随机小模型是糟糕的草稿。标准配方是从目标模型蒸馏：

1. 选择一个小架构（70B 目标约 1B，7B 目标约 500M）。
2. 在大型文本语料上运行目标模型；存储其下一个 token 分布。
3. 用 KL 散度针对目标分布训练草稿（而非针对真实 token）。

结果：代码生成上 `α` 通常 0.6-0.8，自然语言对话上 0.7-0.85。生产环境中加速 2-3×。

### EAGLE：树草稿 + 特征复用

Li、Wei、Zhang、Zhang（2024，"EAGLE: Speculative Sampling Requires Rethinking Feature Uncertainty"）观察到标准推测解码中的两个低效：

1. 草稿做 K 步串行，每步全栈执行。但草稿可以复用来自最近验证的目标特征（隐藏状态）——目标已经计算了草稿从头重新推导的丰富表示。
2. 草稿输出线性链。如果草稿能输出候选树（每个节点多个猜测），目标的单次前向传播可以通过树注意力掩码并行验证多条候选路径，并选择最长被接受分支。

EAGLE-1 的改变：
- 草稿输入 = 目标在位置 t 的最终隐藏状态，而非原始 token。
- 草稿架构 = 1 个 transformer 解码器层（而非单独的小模型）。
- 输出 = 每个深度 K = 4-8 个候选，深度 4-6 的树。

EAGLE-2（2024）添加动态树拓扑：在草稿不确定的地方树变宽，在有信心的地方保持窄。在不增加验证成本的情况下提高 `α_effective`。

EAGLE-3（Li 等人 2025，"EAGLE-3: Scaling up Inference Acceleration of Large Language Models via Training-Time Test"）移除固定的顶层特征依赖，并用新的"测试时模拟"损失训练草稿——草稿在匹配目标测试时分布的输出上训练，而非教师强制训练分布。接受率从 0.75（EAGLE-2）提升到 0.82（EAGLE-3），平均每次验证 token 数从 3.0 提升到 4.5。

### 树注意力验证

当草稿输出一棵树时，目标模型使用树注意力掩码在单次前向传播中验证它——一个编码树拓扑而非纯线的因果掩码。每个 token 仅关注树中其祖先。验证传播仍是一次前向、一次矩阵乘法；拓扑掩码仅花费少量额外 KV 条目。

```
        root
       /    \
      a      b
     / \    / \
    c  d   e   f
```

如果 `a, b` 是竞争的候选首 token，`c, d, e, f` 是候选次 token，所有六个位置在一次前向传播中被验证。输出是沿任何被接受路径的最长前缀。

### 何时成功，何时失败

**成功：**
- 可预测文本的聊天/补全（代码、常见英语、结构化输出）。`α` 高。
- 解码期间 GPU 计算未充分利用的设置（内存受限阶段）。树草稿使用可用的 FLOPs。

**失败/无收益：**
- 高度随机的输出（高温创意写作）。`α` 下降到接近 `1/|vocab|`。
- 极高并发的批量服务——批处理已填满 FLOPs，几乎没有树验证的空间。
- 非常小的目标模型，草稿并不小太多。

生产团队通常报告对话上 2-3× 墙钟加速，代码生成上 3-5×，创意写作上接近零。

## 构建实现

`code/main.py`：

- 一个参考实现 `speculative_decode(target, draft, prompt, K, temperature)`，实现精确拒绝规则并验证其保持目标分布（经验 KL < 0.01 vs 纯目标采样）。
- 一个 EAGLE 风格的树草稿器，构建带 top-p 分支的深度 K 树。
- 一个为验证器产生正确因果模式的树注意力掩码构建器。
- 一个在小 LM 上运行两者的接受率测试框架（从 GPT-2-medium 目标蒸馏一个 GPT-2-small）。

```python
def speculative_step(p_target, q_draft, K, temperature=1.0):
    """一轮推测解码。返回被接受 token 列表。"""
    # 1. 草拟 K 个 token
    draft_tokens = []
    q_probs = []
    state = draft_state_init()
    for _ in range(K):
        probs = softmax(q_draft(state) / temperature)
        t = np.random.choice(len(probs), p=probs)
        draft_tokens.append(t)
        q_probs.append(probs[t])
        state = draft_step(state, t)

    # 2. 目标在每个草拟位置 + 1 个额外位置计算 p
    p_probs_all = target_forward_batched(p_target, draft_tokens, temperature)

    # 3. 从左到右接受/拒绝
    accepted = []
    for k, tok in enumerate(draft_tokens):
        r = np.random.uniform()
        if r < p_probs_all[k][tok] / q_probs[k]:
            accepted.append(tok)
        else:
            residual = np.maximum(p_probs_all[k] - q_probs[k], 0)
            residual /= residual.sum()
            accepted.append(np.random.choice(len(residual), p=residual))
            return accepted
    # 4. 所有 K 个被接受 → 从目标采样奖励 token
    accepted.append(np.random.choice(len(p_probs_all[-1]), p=p_probs_all[-1]))
    return accepted
```

## 使用方式

- **vLLM** 和 **SGLang** 内置一流的推测解码。标志：`--speculative_model`、`--num_speculative_tokens`。通过 `--spec_decoding_algorithm eagle` 标志支持 EAGLE-2/3。
- **NVIDIA TensorRT-LLM** 原生支持 Medusa 和 EAGLE 树。
- **参考草稿模型**：`Qwen/Qwen3-0.6B-spec`（为 Qwen3-32B 草拟）、`meta-llama/Llama-3.2-1B-Instruct-spec`（为 70B 草拟）。
- **Medusa 头**（Cai 等人 2024，"Medusa: Simple LLM Inference Acceleration Framework with Multiple Decoding Heads"）：不前使用草稿模型，而是向目标本身添加 K 个并行预测头。部署更简单，接受率略低于 EAGLE。

## 交付产出

本课产生 `outputs/skill-speculative-tuning.md`——一个分析目标模型工作负载并选择草稿模型、K（草稿长度）、树宽度、温度以及何时回退到普通解码的技能。

## 练习

1. 实现精确拒绝规则并经验验证。通过 `speculative_decode` 和纯目标采样运行 10K 样本；计算两个输出分布之间的 TV 距离。应小于 0.01。

2. 计算加速比公式。给定固定 `α` 和 `K`，绘制每次目标前向传播的期望 token 数。为 α ∈ {0.5, 0.7, 0.9} 找到最优 K。

3. 训练一个小型草稿。取 124M GPT-2 目标模型，在 100M token 上用 KL 损失蒸馏一个 30M GPT-2 草稿。在保留文本上测量 `α`。预期：0.6-0.7。

4. 实现 EAGLE 风格树草稿。让草稿在每个深度输出 top-3 分支而非链。构建树注意力掩码。验证目标接受最长正确分支。

5. 测量失败模式。在 temperature=1.5（高随机性）下运行推测解码。展示 α 崩溃，算法因草稿开销比普通解码更慢。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|------------------------|
| 目标模型 | "大模型" | 你希望从中采样的慢速、高质量模型（p 分布） |
| 草稿模型 | "推测器" | 小型、快速预测器（q 分布）；小 5-30x |
| K / 草稿长度 | "前瞻" | 每次验证传播的推测 token 数量 |
| α / 接受率 | "命中率" | 草稿提议被接受的每 token 概率 |
| 精确拒绝规则 | "接受测试" | 保持目标分布的 r < p/q 比较 |
| 残差分布 | "修正的 p-q" | (p - q)+ / \|\|(p - q)+\|\|_1，拒绝时从中采样的分布 |
| 树草稿 | "分支推测" | 草稿输出候选树，通过树结构注意力掩码在一次传播中验证 |
| 树注意力掩码 | "拓扑掩码" | 编码树拓扑的因果掩码，使得每个节点仅关注其祖先 |
| Medusa 头 | "并行头" | 目标本身上的 K 个额外预测头；无需单独草稿模型 |
| EAGLE 特征复用 | "隐藏状态草稿" | 草稿输入是目标的最后隐藏状态而非原始 token，缩小草稿 |
| 测试时模拟损失 | "EAGLE-3 训练" | 在匹配目标测试时分布而非教师强制的输出上训练草稿 |

## 扩展阅读

- [Leviathan, Kalai, Matias, 2023 — "Fast Inference from Transformers via Speculative Decoding"](https://arxiv.org/abs/2211.17192) — 精确拒绝规则和理论加速分析