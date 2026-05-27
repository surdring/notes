# 推理优化

> LLM 推理由两个阶段定义。Prefill 并行处理你的提示——受计算限制。Decode 一次生成一个 token——受内存限制。每个优化都针对其中一个或两个。

**类型：** 构建
**语言：** Python
**前置要求：** 第 10 阶段，第 01-08 课（Transformer 架构、注意力）
**时间：** 约 120 分钟

## 学习目标

- 实现 KV-cache 以在自回归 token 生成期间消除冗余计算
- 解释 LLM 推理的 prefill vs decode 阶段以及为什么每个有不同的瓶颈（计算受限 vs 内存受限）
- 实现连续批处理和 PagedAttention 概念以在并发请求下最大化 GPU 利用率
- 比较推理优化技术（KV-cache、推测解码、flash attention）及其吞吐量/延迟权衡

## 问题

你在 4xA100 GPU 上部署 Llama 3 70B。单个用户获得约 50 个 token 每秒。感觉很快。然后 100 个用户同时访问端点。吞吐量下降到每用户 3 token/秒。你每月 25,000 美元的 GPU 账单提供的响应速度比人类打字还慢。

模型本身在 1 个用户和 100 个用户之间没有改变。相同的权重，相同的架构，相同的数学。改变的是你如何调度工作。天真推理浪费了 90% 以上的可用 GPU 计算。一个等待 token 47 的用户占用整个批次槽，而 GPU 内存总线在 matmul 之间空闲。与此同时，一个新用户的 2,000 token 提示可以用有用的计算填充那段死时间。

这不是扩展问题。而是调度问题。本课中的技术——KV 缓存、连续批处理、PagedAttention、推测解码、前缀缓存——是将每月 25,000 美元的推理账单与为相同流量服务的 5,000 美元账单区分开的东西。

vLLM 在 4xA100-80GB 上服务 Llama 3 70B，在低并发时实现约 50 token/秒/用户，在 100 个并发请求下通过连续批处理和 PagedAttention 维持 15-25 TPS/用户。没有这些优化，相同的硬件在该并发下服务 5 TPS/用户。相同的 GPU，相同的模型，4 倍的吞吐量。

## 概念

### Prefill vs Decode

每个 LLM 推理请求有两个不同的阶段。

**Prefill** 处理整个输入提示。所有 token 已知，所以注意力可以跨完整序列并行计算。这是一个大型矩阵乘法——GPU 核心保持忙碌。瓶颈是计算：你的硬件每秒能提供多少 FLOPS。A100 做 312 TFLOPS（BF16）。70B 模型上 4,096 token 提示的 Prefill 在单个 A100 上需要约 400ms。

**Decode** 一次生成一个输出 token。每个新 token 关注所有之前的 token，但每次前向传播只产生一个 token。权重矩阵与 prefill 期间大小相同，但你是将它们乘以单个向量而不是矩阵。GPU 核心在微秒内完成，然后等待下一批权重从内存到达。瓶颈是内存带宽：你能多快地将模型权重从 HBM 流式传输到计算单元。A100 有 2 TB/s 带宽。FP16 中的 70B 模型是 140 GB。读取完整模型一次需要 70ms——这是你单个 decode 步骤的底限。

**ops:byte 比率**（也称算术强度）捕捉这种权衡。它衡量你每从内存加载一个字节执行多少操作。

```
ops:byte 比率 = 每 token FLOPs / 从内存读取的字节数
```

在批次为 4,096 token 的 prefill 期间，你每个加载的权重执行约 4,096 个乘加操作。比率很高——你是计算受限的。在批次大小为 1 的 decode 期间，你每个加载的权重执行约 1 个操作。比率很低——你是内存受限的。

基本洞察：*decode 是内存受限的，因为你读取整个模型只为产生一个 token*。下面的每个优化要么减少你读取的内容，要么增加每读取处理的 token 批次，要么完全避免读取。

### KV 缓存

在注意力期间，每个 token 的查询关注每个之前 token 的键和值向量。没有缓存，生成 token N 需要为所有 N-1 个前面的 token 重新计算键和值投影。Token 1 在生成 token 2 时被投影，然后再次为 token 3，然后再次为 token 4。到 token 1,000，你已经投影 token 1 总共 999 次。

KV 缓存存储所有之前 token 的键和值投影。生成 token N 时，你只计算 token N 的键和值，然后将它们与缓存中 token 1 到 N-1 的 K/V 拼接。

**KV 缓存的内存公式：**

```
KV 缓存大小 = 2 * num_layers * num_kv_heads * head_dim * seq_len * bytes_per_param
```

对于 Llama 3 70B（80 层，带 GQA 的 8 个 KV 头，head_dim=128，BF16）：

```
每 token：2 * 80 * 8 * 128 * 2 字节 = 327,680 字节 = 320 KB
在 4,096 token：320 KB * 4,096 = 1.28 GB
在 128K token：320 KB * 131,072 = 40 GB
```

Llama 3 70B 的一个 128K 上下文对话消耗 40 GB KV 缓存——半个 A100 的内存。100 个并发用户每人 4K token，仅 KV 缓存就需要 128 GB。这就是为什么 KV 缓存管理是推理优化的核心挑战。

### 连续批处理

传统批处理等同请求长度。你可以批处理正好 100 序列长度为 128 的请求。但是一个用户的响应在第 27 步结束，另一个在第 314 步结束。在传统批处理中，GPU 一直等最慢请求完成。所有其他用户的 slot 浪费了。

连续批处理在迭代级别工作。每次前向传播后，完成的请求退出，新请求加入。批次大小动态变化。当用户 1 生成 EOS token 时，他们的槽立即由新用户 2 的 prefill 填充。GPU 从不等待。

结果：在相同并发下，平均 2-3 倍吞吐量改进。连续批处理是 vLLM、TGI 和 TRT-LLM 的默认设置。

### PagedAttention

KV 缓存内存分配是碎片化的。用户 A 到达，请求 4,096 个 KV 缓存槽。分配（4,096 x 320 KB = 1.28 GB）。用户 A 在 100 步后完成。那 1.28 GB 被释放。但现在你不一定会得到连续的 4,096 个空槽。五个完成请求留下间隙。有总空闲内存但无连续块——外部碎片。

PagedAttention（来自 vLLM）将 KV 缓存视为虚拟内存。块大小固定（通常 16 个 token）。缓存在逻辑上是连续的但在物理上可以跨非连续块。一个 4,096 token 的序列使用 256 个块。新序列分配池中的任何空闲块。完成释放块回池。内部碎片（每个序列的最后一个块可能未满）是唯一开销。

优势：在现实流量下，内存利用率从约 60% 提高到约 95%。相同的 GPU 内存服务 50% 更多并发用户。

### 前缀缓存

许多提示共享公共前缀。系统提示（"你是一个有帮助的助手。"）对于每个对话是相同的。少样本示例被复制。这些前缀的 KV 计算是冗余的。

前缀缓存存储常用前缀的 KV 缓存。当新请求到达时，引擎检查提示是否匹配任何缓存前缀。如果是，跳过这些 token 的 prefill 并直接从缓存恢复 KV。对于 2,000 token 的系统提示，前缀缓存将 TTFT（首次 token 时间）从约 400ms 降低到约 0ms。

### 推测解码

之前在单独的课程中涵盖。关键概念是：使用草稿模型（小、快）生成多个候选 token。使用目标模型（大）并行验证所有 token。接受正确的 token，丢弃不正确的，继续。在内存受限的设置中，吞吐量提高 2-3 倍，其中目标模型在 decode 期间空闲。

## 构建

`code/main.py` 实现了 KV 缓存、连续批处理和页面注意力模拟。

## 交付

保存为 `outputs/skill-inference-optimization.md`。

## 练习

1. **简单。** 比较带和不带 KV 缓存的 decode 延迟。测量生成 500 个 token 的加速比。
2. **中等。** 对于 100 个并发用户，计算带和不带 PagedAttention 的内存浪费。4,096 token 上下文每用户的平均浪费是多少？
3. **困难。** 比较连续批处理 vs 静态批处理的吞吐量。测量平均 token/秒/用户的差异。

## 关键术语

| 术语 | 含义 |
|------|------|
| Prefill | 并行处理提示 token；计算受限。 |
| Decode | 自回归 token 生成；内存受限。 |
| KV 缓存 | 存储 K/V 投影以避免冗余计算。 |
| 连续批处理 | 在迭代级别添加/移除请求以填补 GPU 空闲时间。 |
| PagedAttention | 虚拟内存式 KV 缓存分配以避免碎片。 |
| TTFT | 首次 token 时间：从请求响应到第一个输出 token 的延迟。 |

## 扩展阅读

- [Kwon et al. (2023). Efficient Memory Management for Large Language Model Serving with PagedAttention](https://arxiv.org/abs/2309.06180)——vLLM 和 PagedAttention 论文。
- [Dao et al. (2022). FlashAttention: Fast and Memory-Efficient Exact Attention with IO-Awareness](https://arxiv.org/abs/2205.14135)——FlashAttention 论文。
- [Leviathan et al. (2023). Fast Inference from Transformers via Speculative Decoding](https://arxiv.org/abs/2211.17192)