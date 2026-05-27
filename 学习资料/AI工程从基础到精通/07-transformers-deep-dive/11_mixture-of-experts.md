# 专家混合（MoE）

> 一个密集的 70B transformer 为每个标记激活每个参数。671B MoE 每个标记只激活 37B，却在每个基准上击败它。稀疏性是这十年最重要的缩放思想。

**类型：** 构建
**语言：** Python
**前置要求：** 第 7 阶段 · 05（完整 Transformer），第 7 阶段 · 07（GPT）
**时间：** 约 45 分钟

## 问题

密集 transformer 的推理 FLOPs 等于其参数数量（前向传播乘以 2）。放大密集模型，每个标记都要支付全部账单。到 2024 年前沿正在撞计算墙：要想变得更有意义地聪明，你需要每个标记指数级更多的 FLOPs。

专家混合打破了这种关联。将每个 FFN 替换为 `E` 个独立专家 + 为每个标记选择 `k` 个专家的路由器。总参数 = `E × FFN_size`。每标记活跃参数 = `k × FFN_size`。典型 2026 配置：`E=256`，`k=8`。存储随 `E` 缩放，计算随 `k` 缩放。

2026 前沿几乎完全是 MoE：DeepSeek-V3（671B 总计 / 37B 活跃）、Mixtral 8×22B、Qwen2.5-MoE、Llama 4、Kimi K2、gpt-oss。在 Artificial Analysis 的独立排行榜上，前 10 开源模型全是 MoE。

## 概念

![MoE 层：路由器为每个标记从 E 个专家中选择 k 个](../assets/moe.svg)

### FFN 替换

密集 transformer 块：

```
h = x + attn(norm(x))
h = h + FFN(norm(h))
```

MoE 块：

```
h = x + attn(norm(x))
scores = router(norm(h))              # (N_tokens, E)
top_k = argmax_k(scores)              # 每标记选 k 个 E 中的专家
h = h + sum_{e in top_k}(
        gate(scores[e]) * Expert_e(norm(h))
    )
```

每个专家是独立的 FFN（通常 SwiGLU）。路由器是单个线性层。每个标记选择自己的 `k` 个专家并获取它们输出的门控混合。

### 负载均衡问题

如果路由器将 90% 的标记通过专家 3，其他专家饥饿。尝试过三种修复：

1. **辅助负载均衡损失**（Switch Transformer、Mixtral）。添加与专家使用方差成比例的惩罚。有效，但增加超参数和第二个梯度信号。
2. **专家容量 + 标记丢弃**（早期 Switch）。每个专家最多处理 `C × N/E` 个标记；溢出标记跳过该层。损害质量。
3. **无辅助损失均衡**（DeepSeek-V3）。添加学习的每专家偏置，改变路由器的 top-k 选择。偏置在训练损失之外更新。无对主目标的惩罚。2024 年的大解锁。

DeepSeek-V3 的方法：每个训练步后，对每个专家，检查其使用是否高于或低于目标。用 `±γ` 微调偏置。选择使用 `scores + bias`。用于门控的专家概率是原始 `scores` 不变。解耦路由和表达。

### 共享专家

DeepSeek-V2/V3 还将专家分为*共享*和*路由*。每个标记都通过所有共享专家。路由专家通过 top-k 选择。共享专家捕获通用知识；路由专家专门化。V3 运行 1 个共享专家加 256 个路由专家中的 top-8。

### 细粒度专家

经典 MoE（GShard、Switch）：每个专家与完整 FFN 一样宽。`E` 小（8-64），`k` 小（1-2）。

现代细粒度 MoE（DeepSeek-V3、Qwen-MoE）：每个专家更窄（1/8 FFN 大小）。`E` 大（256+），`k` 更大（8+）。相同总参数，但组合缩放快得多。`C(256, 8) = 400 万亿` 每标记可能的"专家"。质量上升，延迟不变。

### 成本概况

每标记，每层：

| 配置 | 活跃参数/标记 | 总参数 |
|--------|-----------------------|--------------|
| Mixtral 8×22B | ~39B | 141B |
| Llama 3 70B（密集） | 70B | 70B |
| DeepSeek-V3 | 37B | 671B |
| Kimi K2（MoE） | ~32B | 1T |

DeepSeek-V3 在几乎每个基准上击败 Llama 3 70B（密集），同时做**更少的每标记活跃 FLOPs**。更多参数 = 更多知识。更多活跃 FLOPs = 每标记更多计算。MoE 解耦它们。

### 代价：内存

无论哪些专家激活，所有专家都在 GPU 上。671B 模型需要约 1.3 TB VRAM 用于 fp16 权重。前沿 MoE 部署需要专家并行——跨 GPU 切分专家，跨网络路由标记。延迟由全对全通信主导，而非矩阵乘法。

## 构建

见 `code/main.py`。纯标准库的紧凑 MoE 层，包含：

- `n_experts=8` 个类 SwiGLU 专家（各一个线性层，用于演示）
- top-k=2 路由
- softmax 归一化门控权重
- 通过每专家偏置的无辅助损失均衡

### 步骤 1：路由器

```python
def route(hidden, W_router, top_k, bias):
    scores = [sum(h * w for h, w in zip(hidden, W_router[e])) for e in range(len(W_router))]
    biased = [s + b for s, b in zip(scores, bias)]
    top_idx = sorted(range(len(biased)), key=lambda i: -biased[i])[:top_k]
    # 对选中专家的原始分数做 softmax
    chosen = [scores[i] for i in top_idx]
    m = max(chosen)
    exps = [math.exp(c - m) for c in chosen]
    s = sum(exps)
    gates = [e / s for e in exps]
    return top_idx, gates
```

偏置影响选择，不影响门控权重。这就是 DeepSeek-V3 技巧——偏置修正负载不均衡而无需引导模型预测。

### 步骤 2：通过路由器运行 100 个标记

跟踪哪些专家激活的频率。无偏置时，使用偏斜。通过偏置更新循环（对过度使用的专家 `-γ`，对使用不足的专家 `+γ`），使用在几次迭代内收敛到均匀分布。

### 步骤 3：参数计数比较

打印 MoE 配置的"密集等效"。DeepSeek-V3 形状：256 路由 + 1 共享，8 活跃，d_model=7168。总参数量令人瞠目。活跃计数是密集 Llama 3 70B 的七分之一。

## 使用

HuggingFace 加载：

```python
from transformers import AutoModelForCausalLM, AutoTokenizer
model = AutoModelForCausalLM.from_pretrained("mistralai/Mixtral-8x22B-v0.1")
```

2026 生产推理：vLLM 原生支持 MoE 路由。SGLang 有最快的专家并行路径。两者都自动处理 top-k 选择和专家并行。

**何时选择 MoE：**
- 想要前沿质量但每标记推理成本更低。
- 有 VRAM / 专家并行基础设施。
- 工作负载是标记密集型（聊天、代码）而非上下文密集型（长文档）。

**何时不选 MoE：**
- 边缘部署——你为任何活跃 FLOP 支付全部存储。
- 延迟关键的单用户服务——专家路由增加开销。
- 小模型（<7B）——MoE 的质量优势仅在计算阈值以上出现（~6B 活跃参数）。

## 交付

见 `outputs/skill-moe-configurator.md`。该技能给定参数预算、训练标记和部署目标，为新的 MoE 选择 E、k 和共享专家布局。

## 练习

1. **简单。** 运行 `code/main.py`。观察无辅助损失偏置更新如何在 50 次迭代内均匀化专家使用。
2. **中等。** 用基于哈希的路由器替换学习的路由器（确定性，无学习）。比较质量和均衡。为什么学习型路由器更好？
3. **困难。** 实现 GRPO 风格的"轨迹匹配路由"（DeepSeek-V3.2 技巧）：记录推理中哪些专家激活，在梯度计算中强制相同路由。在玩具策略梯度设置上测量效果。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|-----------------------|
| 专家 | "众多 FFN 中的一个" | 独立的前馈网络；专用于 FFN 计算稀疏切片的参数。 |
| 路由器 | "门控" | 对每个标记和每个专家评分的微型线性层；top-k 选择。 |
| Top-k 路由 | "每标记 k 个活跃专家" | 每个标记的 FFN 计算恰好通过 k 个专家，由门控加权。 |
| 辅助损失 | "负载均衡惩罚" | 惩罚偏斜专家使用的额外损失项。 |
| 无辅助损失 | "DeepSeek-V3 的技巧" | 仅通过路由器选择的每专家偏置均衡；无额外梯度。 |
| 共享专家 | "始终在线" | 每个标记都通过的额外专家；捕获通用知识。 |
| 专家并行 | "按专家切分" | 将不同专家分布到不同 GPU；跨网络路由标记。 |
| 稀疏性 | "活跃参数 < 总参数" | 比率 `k × expert_size / (E × expert_size)`；DeepSeek-V3 的 37/671 ≈ 5.5%。 |

## 扩展阅读

- [Shazeer et al. (2017). Outrageously Large Neural Networks: The Sparsely-Gated Mixture-of-Experts Layer](https://arxiv.org/abs/1701.06538)——思想来源。
- [Fedus, Zoph, Shazeer (2022). Switch Transformer: Scaling to Trillion Parameter Models with Simple and Efficient Sparsity](https://arxiv.org/abs/2101.03961)——Switch，经典 MoE。
- [Jiang et al. (2024). Mixtral of Experts](https://arxiv.org/abs/2401.04088)——Mixtral 8×7B。
- [DeepSeek-AI (2024). DeepSeek-V3 Technical Report](https://arxiv.org/abs/2412.19437)——MLA + 无辅助损失 MoE + MTP。
- [Wang et al. (2024). Auxiliary-Loss-Free Load Balancing Strategy for Mixture-of-Experts](https://arxiv.org/abs/2408.15664)——基于偏置的均衡论文。
- [Dai et al. (2024). DeepSeekMoE: Towards Ultimate Expert Specialization in Mixture-of-Experts Language Models](https://arxiv.org/abs/2401.06066)——本课路由器使用的细粒度+共享专家拆分。