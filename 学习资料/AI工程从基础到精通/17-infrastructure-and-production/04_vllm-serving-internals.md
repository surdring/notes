# vLLM 推理内部：PagedAttention、连续批处理、分块预填充

> vLLM 在 2026 年的主导地位建立在三个复合默认值上，而非单一技巧。PagedAttention 始终开启。连续批处理（Continuous Batching）在解码迭代之间将新请求注入活跃批次。分块预填充（Chunked Prefill）将长提示切片，使得解码 Token 永远不会饥饿。全部三个打开，Llama 3.3 70B FP8 在一个 H100 SXM5 上以 128 并发推送 2,200-2,400 tok/s——比 vLLM 自身默认值高出约 25%，是 naive PyTorch 循环的 3-4 倍。本课以你可以画出的层次解读调度器和注意力内核，并以一个实现 vLLM 方式调度预填充和解码的玩具连续批处理器结尾。

**类型：** 学习
**语言：** Python（标准库，玩具级连续批处理调度器）
**前置条件：** Phase 17 · 01（模型推理）、Phase 11（LLM 工程）
**时间：** ~75 分钟

## 学习目标

- 将 PagedAttention 解释为 KV 缓存分配器：块、块表，以及为什么碎片在生产负载下保持在 4% 以下。
- 在迭代级别画出连续批处理：已完成的序列如何离开批次，新的序列如何在不排空的情况下加入。
- 用一句话描述分块预填充，并命名它保护的延迟指标（提示：是 TTFT 尾部，而非平均吞吐量）。
- 命名 2026 年 vLLM v0.18.0 中同时启用所有优化时会遇到问题的陷阱。

## 问题

naive PyTorch 推理循环一次运行一个请求：分词、预填充、解码直到 EOS、返回。一个用户时可行。一百个用户时，它是一排耐心排队的人。显而易见的修复——静态批处理（Static Batching）——将每个请求填充到窗口中最大的提示，将每次解码填充到最长的预期输出，并使整个批次在慢的序列上停滞。你为从未使用的填充付费，快速的请求等待慢速的。

vLLM 同时解决三个问题。PagedAttention 阻止 KV 缓存碎片像经典连续分配那样吃掉 60-80% 的 GPU 内存。连续批处理允许请求在每次解码迭代之间加入和离开批次，因此批次总是充满真实的工作。分块预填充将 32k Token 的提示分解为约 512 Token 的切片，与解码交错进行，使得长提示不会冻结 GPU 上的每个解码 Token。

2026 年的生产默认是全部三个开启。你需要理解每个做什么，因为失败模式都在调度器上，而非模型。

## 概念

### PagedAttention 作为虚拟内存系统

每个序列的 KV 缓存是 `num_layers × 2 × num_heads × head_dim × seq_len × bytes_per_element`。对于 Llama 3.3 70B 在 8192 Token 下，在 BF16 中每个序列约 1.25 GB。如果你为每个请求预保留 8192 个槽位但平均请求只使用 1500 Token，你浪费了大约 82% 的预留 HBM。经典批处理付出这种浪费。

PagedAttention 借鉴了 OS 虚拟内存的思想。KV 缓存不是每个序列连续的。它以固定大小的块（默认 16 Token）分配。每个序列有一个块表，将其逻辑 Token 位置映射到物理块 ID。当序列增长超过其已分配块时，增加一个块。当它完成时，其块返回池中。

碎片从 60-80%（经典）降至 4% 以下（PagedAttention）。你不通过标志启用 PagedAttention——它是 vLLM 唯一的分配器。可调的旋钮是 `--gpu-memory-utilization`（默认 0.9），它告诉 vLLM 在加载权重和激活后为 KV 块保留多少 HBM。

### 迭代级别的连续批处理

旧的"动态批处理"等待一个窗口（比如 10 ms）填满批次，然后运行预填充 + 解码 + 解码 + 解码直到每个序列完成。快速序列提前离开并在 GPU 完成慢速序列时处于空闲。

连续批处理在每次解码步骤之间操作。将运行中序列的集合称为 `RUNNING` 列表。每次迭代：

1. `RUNNING` 中任何刚达到 EOS 或 max_tokens 的序列被移除。
2. 调度器查看等待队列。如果有空闲 KV 块，它接纳新序列（预填充或恢复）。
3. 前向传播在 `RUNNING` 中当前内容上运行，每个序列发出一个新 Token。

批次大小从不填充到固定数字。处于不同输出位置的序列共享一个融合前向传播。在 2026 年的 vLLM 中，这称为 `V1 scheduler`。关键不变量：调度器每次解码迭代运行一次，而非每次请求。

### 分块预填充保护 TTFT 尾部

预填充是计算密集型的。Llama 3.3 70B 上 32k Token 的提示在一个 H100 上纯预填充约需 800 ms。当预填充运行时，批次中每个其他序列的解码 Token 等待。在推理循环中，一个长提示的首 Token 延迟（TTFT）变成数十个其他用户的 Token 间延迟（ITL）波动。

分块预填充将预填充分割为固定大小的块（默认 512 Token），并将每个块作为一个单元调度。块之间调度器可以将解码序列推进一个 Token。你用少量绝对预填充延迟代价（每个块几 ms）换取低得多的解码时抖动。在已发布的基准测试中，混合负载下的 P99 ITL 从约 50 ms 降至约 15 ms。

### 三个默认值的交互

所有三个特性相互假设。PagedAttention 给调度器一个细粒度的 KV 资源来进行权衡。连续批处理需要那个细粒度的资源，使得接纳新序列不会强制全局重排。分块预填充是调度器在同一个 `RUNNING` 列表上做出的决定——它是另一个调度器策略，而非单独的系统。

你不需要知道每个标志。你需要知道调度器优化什么：在 KV 块预算下的有效吞吐量，受分块预填充切片约束。

### 2026 年 v0.18.0 陷阱

在 vLLM v0.18.0 中你不能将 `--enable-chunked-prefill` 与草稿模型推测解码（`--speculative-model`）组合使用。文档记录的例外是 V1 调度器中的 N-gram GPU 推测解码。不读发布说明就打开所有标志的团队会在启动时遇到运行时错误，而非软性退化。如果你的推测收益值得启用分块预填充，重新审视选择——2026 年的正确答案通常是 EAGLE-3 不带分块预填充，而非无法编译的草稿模型加分块预填充。

### 你应该记住的数字

- Llama 3.3 70B FP8，H100 SXM5，128 并发，全部三个开启：2,200-2,400 tok/s。
- 相同模型，默认 vLLM（无分块预填充）：~1,800 tok/s。
- 相同模型，naive PyTorch 前向循环：~600 tok/s。
- PagedAttention 在生产负载下的 KV 碎片浪费：<4%。
- 混合负载下 P99 ITL：有分块预填充约 15 ms，无约 50 ms。

### 调度器的样子

```
while True:
    finished = [s for s in RUNNING if s.is_done()]
    for s in finished: release_blocks(s); RUNNING.remove(s)

    while WAITING and have_free_blocks_for(WAITING[0]):
        s = WAITING.pop(0)
        allocate_initial_blocks(s)
        RUNNING.append(s)

    # 在一个批次中调度预填充块 + 解码
    batch = []
    for s in RUNNING:
        if s.in_prefill:
            batch.append(next_prefill_chunk(s))   # 例如 512 tokens
        else:
            batch.append(decode_one_token(s))     # 1 token

    run_forward(batch)                            # 一次融合 GPU 调用
```

`code/main.py` 正是这个循环，用标准库 Python，假 Token 计数和假前向延迟。运行它展示分块预填充如何在长预填充期间保持解码序列活跃。

## 使用它

`code/main.py` 模拟一个 vLLM 风格调度器，具有可切换的特性。运行它查看：

- `NAIVE` 模式：一次一个请求，无批处理。
- `STATIC` 模式：填充和等待，经典批处理。
- `CONTINUOUS` 模式：迭代级接纳和释放。
- `CONTINUOUS + CHUNKED` 模式：预填充切片与解码交错。

输出显示总吞吐量（每虚拟秒 Token 数）、TTFT 均值和 P99 ITL。`CONTINUOUS + CHUNKED` 行应在混合流量上占主导。

## 交付它

本课产出 `outputs/skill-vllm-scheduler-reader.md`。给定推理配置（批次大小、KV 内存利用率、分块预填充大小、推测配置），它产生一个调度器诊断，命名三个默认值中的哪一个成为瓶颈以及如何调优。

## 练习

1. 运行 `code/main.py`。在混合短和长请求的工作负载上比较 `STATIC` 和 `CONTINUOUS`。吞吐量差距来自哪里——预填充效率、解码效率还是尾部延迟？
2. 修改玩具调度器以添加 `--max-num-batched-tokens`。对于运行 Llama 3.3 70B FP8 的 H100，合适的值是多少？（提示：它是 KV 块大小和空闲块数量的函数，而非原始 HBM。）
3. 重新阅读 vLLM v0.18.0 发布说明。哪些标志组合是互斥的？列出它们。
4. 计算 1,000 个请求的追踪的 KV 缓存碎片浪费，平均 1,500 输出 Token，标准差 600 Token，在（a）8192 max 的连续每请求分配，（b）16 Token 块的 PagedAttention 下。
5. 用一段话解释为什么分块预填充帮助 P99 ITL 但单独帮助不了吞吐量。实践中吞吐量收益来自哪里？

## 关键术语

| 术语 | 人们的说法 | 实际含义 |
|------|----------------|------------------------|
| PagedAttention | "KV 技巧" | KV 缓存的固定大小块分配器；碎片 <4% |
| 块表 | "页表" | 从逻辑 Token 位置到物理 KV 块的每序列映射 |
| 连续批处理 | "动态批处理，但正确的" | 每次解码迭代做出的接纳/释放决策 |
| 分块预填充 | "预填充分割" | 将长预填充分解为与解码交错的 512 Token 切片 |
| TTFT | "首 Token 时间" | 预填充 + 队列 + 网络；长提示时预填充主导 |
| ITL | "Token 间延迟" | 连续解码 Token 之间的时间；批次大小主导 |
| 有效吞吐量 | "满足 SLO 的吞吐量" | 每个请求仍达到 TTFT 和 ITL 目标的每秒 Token 数 |
| V1 调度器 | "新调度器" | vLLM 2026 年调度器；N-gram 推测解码是与分块预填充兼容的路径 |
| `--gpu-memory-utilization` | "内存旋钮" | 在权重和激活之后为 KV 块保留的 HBM 比例 |

## 扩展阅读

- [vLLM 文档 — 推测解码](https://docs.vllm.ai/en/latest/features/spec_decode/) —— 分块预填充和推测解码兼容性的官方来源。
- [vLLM 发布说明（NVIDIA）](https://docs.nvidia.com/deeplearning/frameworks/vllm-release-notes/index.html) —— 2026 年发布节奏和版本特定行为。
- [vLLM 博客 — PagedAttention](https://blog.vllm.ai/2023/06/20/vllm.html) —— 仍然定义如何思考分配器的原始文章。
- [PagedAttention 论文（arXiv:2309.06180）](https://arxiv.org/abs/2309.06180) —— 碎片分析和调度器设计。
- [Aleksa Gordic — vLLM 内部](https://www.aleksagordic.com/blog/vllm) —— 带火焰图的详细 V1 调度器走查。