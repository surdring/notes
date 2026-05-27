# KV 缓存、Flash Attention 与推理优化

> 训练是并行的且受限于 FLOP。推理是串行的且受限于内存。不同瓶颈，不同技巧。

**类型：** 构建
**语言：** Python
**前置要求：** 第 7 阶段 · 02（自注意力），第 7 阶段 · 05（完整 Transformer），第 7 阶段 · 07（GPT）
**时间：** 约 75 分钟

## 问题

朴素的自回归解码器生成 `N` 个标记做 `O(N²)` 工作：每一步都在整个前缀上重新计算注意力。对于 4K 标记的响应，那是 1600 万次注意力操作，其中大部分是冗余的。前缀标记的每个隐藏状态一旦计算就是确定性的——你只需要将新标记的查询与之前所有内容的缓存键值进行匹配。

除此之外，注意力本身移动大量数据。标准注意力物化一个 N×N 分数矩阵、N×d softmax 输出、N×d 最终输出——太多对 HBM 的读写。对于 N≥2K，注意力在受限于 FLOP 之前就受限于内存。经典注意力内核对现代 GPU 的利用率低 4-10 倍。

两项优化，都来自 Dao et al.，将前沿推理从"慢"推到"快"：

1. **KV 缓存。** 存储每个前缀标记的 K 和 V 向量。每个新标记的注意力是一个查询对缓存键值的匹配。推理从每生成步 `O(N²)` 减少到 `O(N)`。
2. **Flash Attention。** 将注意力计算分块，使完整的 N×N 矩阵永远不会到达 HBM。所有 softmax + matmul 发生在 SRAM 中。A100 上 2-4× 墙钟加速；H100 上 FP8 时 5-10×。

到 2026 年两者都是通用的。每个生产推理栈（vLLM、TensorRT-LLM、SGLang、llama.cpp）都假设它们。每个前沿模型都默认启用 Flash Attention。

## 概念

![KV 缓存增长和 Flash Attention 分块](../assets/kv-cache-flash-attn.svg)

### KV 缓存数学

每解码器层，每标记，每头：

```
bytes_per_token_per_layer = 2 * d_head * dtype_size
                          ^
                          K 和 V
```

对于 7B 模型，32 层，32 头，d_head=128，fp16：

```
每标记每层 = 2 * 128 * 2 = 512 字节
每标记（32 层）= 16 KB
每 32K 上下文 = 512 MB
```

对于 Llama 3 70B（80 层，d_head=128，GQA 8 个 KV 头）：

```
每标记每层 = 2 * 8 * 128 * 2 = 4096 字节（4 KB）
每 32K 上下文 = 10.4 GB
```

这 10 GB 就是为什么 Llama 3 70B 在 128K 上下文下，批大小 1 时几乎需要整个 40 GB A100 仅用于 KV 缓存。

**GQA 是 KV 缓存的胜利。** 64 头的 MHA 将是 32 GB。MLA 进一步压缩。

### Flash Attention——分块技巧

标准注意力：

```
S = Q @ K^T          （HBM 读取，N×N，HBM 写入）
P = softmax(S)       （HBM 读取，HBM 写入）
O = P @ V            （HBM 读取，HBM 写入）
```

三次 HBM 往返。在 H100 上，HBM 带宽是 3 TB/s；SRAM 是 30 TB/s。每次 HBM 往返相对于将所有内容保留在芯片上都是 10 倍的减速。

Flash Attention：

```
for each block of Q（块大小 ~128 × 128）：
    load Q_tile into SRAM
    for each block of K, V:
        load K_tile, V_tile into SRAM
        compute S_tile = Q_tile @ K_tile^T     （SRAM）
        running softmax aggregation             （SRAM）
        accumulate into O_tile                  （SRAM）
    write O_tile to HBM
```

每块一次 HBM 往返。总内存占用从 `O(N²)` 降到 `O(N)`。反向传播从前向传播重新计算一些值而不是存储它们——又一项内存胜利。

**数值技巧。** 运行 softmax 跨块维护 `(max, sum)`，因此最终归一化是精确的。不是近似——Flash Attention 计算与标准注意力比特相同的输出（模 fp16 非结合性）。

**版本演进：**

| 版本 | 年份 | 关键变化 | 参考硬件上的加速 |
|---------|------|-----------|-------------------------------|
| Flash 1 | 2022 | 分块 SRAM 内核 | A100 上 2× |
| Flash 2 | 2023 | 更好的并行性，因果优先排序 | A100 上 3× |
| Flash 3 | 2024 | Hopper 异步，FP8 | H100 上 1.5–2×（~740 TFLOPs FP16） |
| Flash 4 | 2026 | Blackwell 5 阶段流水线，软件 exp2 | 推理优先（最初仅前向） |

Flash 4 发布时仅前向传播。训练仍用 Flash 3。Flash 4 的 GQA 和变长支持待定（2026 年中）。

### 推测解码——另一项延迟胜利

廉价模型提议 N 个标记。大模型并行验证所有 N 个。如果验证接受 k 个标记，你为 k 次生成支付了 1 次大模型前向传播。代码和散文上典型 k=3-5。

2026 默认：
- **EAGLE 2 / Medusa。** 集成草稿头，共享验证器的隐藏状态。2–3× 加速，无质量损失。
- **草稿模型推测解码。** 消费级硬件上 2–4× 加速。
- **前瞻解码。** Jacobi 迭代；不需要草稿模型。小众但免费。

### 连续批处理

经典批处理推理：等待最慢的序列完成，然后启动新批次。当短响应提前完成时浪费 GPU。

连续批处理（首次在 Orca 中发布，现在在 vLLM、TensorRT-LLM、SGLang 中）：一旦旧请求完成就将新请求交换进批次。典型聊天工作负载的 5-10× 吞吐量增益。

### PagedAttention——KV 缓存作为虚拟内存

vLLM 的头条特性。KV 缓存以 16 标记块分配；页表将逻辑位置映射到物理块。允许跨并行采样共享 KV（束搜索、并行采样）、提示缓存的热交换前缀、以及内存碎片整理。相对于朴素连续分配的 4× 吞吐量提升。

## 构建

见 `code/main.py`。我们实现：

1. 朴素 `O(N²)` 增量解码器。
2. `O(N)` KV 缓存解码器。
3. 模拟 Flash Attention 运行最大值算法的分块 softmax。

### 步骤 1：KV 缓存

```python
class KVCache:
    def __init__(self, n_layers, n_heads, d_head):
        self.K = [[[] for _ in range(n_heads)] for _ in range(n_layers)]
        self.V = [[[] for _ in range(n_heads)] for _ in range(n_layers)]

    def append(self, layer, head, k, v):
        self.K[layer][head].append(k)
        self.V[layer][head].append(v)

    def read(self, layer, head):
        return self.K[layer][head], self.V[layer][head]
```

简单：在每层每头列表中持续增长每标记 K、V 向量。

### 步骤 2：分块 softmax

```python
def tiled_softmax_dot(q, K, V, tile=4):
    """Flash-attention 风格的 softmax(qK^T)V，带运行 max/sum。"""
    m = float("-inf")
    s = 0.0
    out = [0.0] * len(V[0])
    for start in range(0, len(K), tile):
        k_block = K[start:start + tile]
        v_block = V[start:start + tile]
        scores = [sum(qi * ki for qi, ki in zip(q, k)) for k in k_block]
        new_m = max(m, *scores)
        exp_old = math.exp(m - new_m) if m != float("-inf") else 0.0
        exp_new = [math.exp(sc - new_m) for sc in scores]
        s = s * exp_old + sum(exp_new)
        for j in range(len(out)):
            out[j] = out[j] * exp_old + sum(e * v[j] for e, v in zip(exp_new, v_block))
        m = new_m
    return [o / s for o in out]
```

一次性输出与 `softmax(qK) V` 比特相同，但任何时候工作集是一个 `tile × d_head` 块，而非完整的 `N × d_head`。

### 步骤 3：在 100 标记生成上比较朴素 vs 缓存解码

计算注意力操作。朴素：`O(N²)` = 5050。缓存：`O(N)` = 100。代码打印两者。

## 使用

```python
# HuggingFace transformers 在仅解码器 generate() 上自动启用 KV 缓存。
from transformers import AutoModelForCausalLM
model = AutoModelForCausalLM.from_pretrained(
    "meta-llama/Llama-3.2-3B",
    attn_implementation="flash_attention_2",  # 如果是 Hopper 则使用 FA3
    torch_dtype="bfloat16",
)
# generate() 自动使用 KV 缓存
```

vLLM 生产环境：

```bash
pip install vllm
vllm serve meta-llama/Llama-3.1-70B-Instruct \
    --tensor-parallel-size 4 \
    --max-model-len 32768 \
    --enable-prefix-caching \
    --kv-cache-dtype fp8
```

跨请求的前缀缓存是 2026 年的大胜利——相同的系统提示、少样本示例或长上下文文档在调用间重用 KV。对于带重复工具提示的代理工作负载，前缀缓存通常是 5× 吞吐量增益。

## 交付

见 `outputs/skill-inference-optimizer.md`。该技能为新的推理部署选择注意力实现、KV 缓存策略、量化和推测解码。

## 练习

1. **简单。** 运行 `code/main.py`。确认朴素和缓存解码器产生相同输出；注意操作计数差异。
2. **中等。** 实现前缀缓存：给定提示 P 和几个补全，运行一次 P 上的前向传播填充 KV 缓存，然后按补全分支。测量 vs 为每个重新编码 P 的加速。
3. **困难。** 实现玩具 PagedAttention：以固定 16 标记块分配 KV 缓存，带空闲列表。当序列完成时，将其块归还给池。模拟 1,000 次不同长度的聊天补全。比较内存碎片 vs 连续分配。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|-----------------------|
| KV 缓存 | "让解码变快的技巧" | 存储每个前缀标记的 K 和 V；新查询匹配它们而非重新计算。 |
| HBM | "GPU 主存" | 高带宽内存；H100 上 80 GB，B200 上 192 GB。约 3 TB/s 带宽。 |
| SRAM | "片上内存" | 每 SM 快速内存，H100 上约 256 KB 每 SM。约 30 TB/s 带宽。 |
| Flash Attention | "分块注意力内核" | 在不将 N×N 物化到 HBM 的情况下计算注意力。 |
| 连续批处理 | "无等待批处理" | 将完成的序列换出，新的换入，无需排空批次。 |
| PagedAttention | "vLLM 的头条" | KV 缓存以固定块分配，带页表；消除碎片。 |
| 前缀缓存 | "重用长提示" | 跨请求缓存共享前缀的 KV；代理的重大成本削减。 |
| 推测解码 | "草稿 + 验证" | 廉价草稿模型提议标记；大模型一次验证 k 个。 |

## 扩展阅读

- [Dao et al. (2022). FlashAttention: Fast and Memory-Efficient Exact Attention with IO-Awareness](https://arxiv.org/abs/2205.14135)——Flash 1。
- [Dao (2023). FlashAttention-2: Faster Attention with Better Parallelism and Work Partitioning](https://arxiv.org/abs/2307.08691)——Flash 2。
- [Shah et al. (2024). FlashAttention-3: Fast and Accurate Attention with Asynchrony and Low-precision](https://arxiv.org/abs/2407.08608)——Flash 3。
- [FlashAttention-4 发布说明（Dao-AILab，2026）](https://github.com/Dao-AILab/flash-attention)——Blackwell 5 阶段流水线和软件 exp2 技巧。
- [Kwon et al. (2023). Efficient Memory Management for Large Language Model Serving with PagedAttention](https://arxiv.org/abs/2309.06180)——vLLM 论文。
- [Leviathan et al. (2023). Fast Inference from Transformers via Speculative Decoding](https://arxiv.org/abs/2211.17192)——推测解码。
- [Li et al. (2024). EAGLE: Speculative Sampling Requires Rethinking Feature Uncertainty](https://arxiv.org/abs/2401.15077)——EAGLE-1/2 论文。
- [Cai et al. (2024). Medusa: Simple LLM Inference Acceleration Framework with Multiple Decoding Heads](https://arxiv.org/abs/2401.10774)——Medusa 方法。