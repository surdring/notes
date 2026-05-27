# 多区域 LLM 推理与 KV 缓存局部性

> 轮询负载均衡对带缓存的 LLM 推理是有害的。一个没有落到持有其前缀的节点上的请求，要付出完整的预填充（Prefill）代价——在长提示词上 P50 约 800 ms，而缓存命中约 80 ms。2026 年的生产模式是缓存感知路由器（Rust 编写的 vLLM Router，llm-d 路由器），消费 KV 缓存事件并按前缀哈希匹配进行路由。最新研究（GORGO）将跨区域网络延迟作为路由目标中的显式项。商业化的"跨区域推理"产品（Bedrock 跨区域推理、GKE 多集群网关）将推理视为不透明的——它们处理可用性，而非 TTFT。摩根大通（JPMorgan）和梅奥诊所（Mayo Clinic）在 2024 年 11 月运行 us-east-1 故障转移时耗时约 22 分钟。灾备（DR）的现实：32% 的 LLM 灾备失败是因为团队备份了权重但忘记了分词器文件或量化配置。

**类型：** 学习
**语言：** Python（标准库，玩具级前缀缓存感知路由器模拟器）
**前置知识：** 第 17 阶段 · 04（vLLM 推理），第 17 阶段 · 06（SGLang RadixAttention）
**时间：** 约 60 分钟

## 学习目标

- 解释为什么轮询负载均衡会破坏带缓存的推理，并量化 TTFT 惩罚。
- 画出缓存感知路由器的图示：输入（KV 缓存事件）、算法（前缀哈希匹配）、备选策略（GPU 利用率）。
- 说出 LLM 灾备失败中占比 32% 的驱动因素（缺少分词器文件/量化配置），并陈述三文件灾备清单。
- 区分商业跨区域产品（Bedrock CRI、GKE 多集群网关）与 KV 感知路由。

## 问题

你的服务运行在 us-east-1、us-west-2 和 eu-west-1。你在前面放了一个 ALB，使用轮询策略。生产环境中的前缀缓存命中率降至 8%。TTFT P50 变为三倍。你的 vLLM 日志显示每个请求都在付出完整的预填充代价。

轮询对无状态服务是最优的。而 LLM 推理本质上是状态化的——KV 缓存编码了模型所见的一切。盲路由就是路由到错误的缓存。

另外，你的团队有一份灾备计划。你将模型权重备份到 S3 跨区域。一个区域发生故障；你尝试故障转移；副本拒绝启动。你忘了 tokenizer.json、量化配置和 RoPE 缩放配置放在另一个你没有同步的 bucket 里。

多区域 LLM 推理是一个缓存问题、一个路由问题和一个灾备规范问题——而不是负载均衡器问题。

## 概念

### 缓存感知路由

请求到达，携带提示词。路由器对前缀（比如前 512 token）做哈希；它向每个副本询问"你有此前缀缓存吗？"。副本在分配和回收块时通过发布/订阅通道发布 KV 缓存事件。路由器选择有匹配的副本，如果都没有匹配则回退到基于 GPU 利用率的备选策略。

**vLLM Router**（Rust，2026 生产栈）：订阅 `kv.cache.block_added` 事件，维护前缀哈希到副本索引的映射，实现 O(1) 查找路由。无匹配时回退到最短队列深度策略。

**llm-d 路由器**：相同模式，Kubernetes 原生。通过 ControlPlane API 发布事件。

**SGLang RadixAttention**（第 17 阶段 · 06）是副本内部的等价方案。跨副本路由严格属于上游层。

### 数据

TTFT P50，2K token 提示词，Llama 3.3 70B FP8，H100：
- 缓存命中（同一副本，前缀驻留）：约 80 ms。
- 缓存未命中（冷预填充）：约 800 ms。

10 倍差距。如果你的路由器在副本间命中 60-80% 的前缀缓存，你在 N 副本容量下逼近单副本性能。如果只命中 10%，你逼近朴素扩展。

### 跨区域有一个新约束 — 网络延迟

跨区域往返时间（RTT）：
- us-east-1 ↔ us-west-2：约 65 ms。
- us-east-1 ↔ eu-west-1：约 75 ms。
- us-east-1 ↔ ap-southeast-1：约 220 ms。

如果将一个请求从 us-east-1 路由到 ap-southeast-1 的热前缀，省下的预填充时间（800 → 80 ms）被 440 ms 往返延迟完全压倒。GORGO（2026 研究）将此显式化——联合最小化 `prefill_time + network_latency`，而非单独最小化预填充时间。答案通常是在区域内路由，除非是超大多 MB 前缀且预填充占主导的情况。

### 商业"跨区域推理"在此无济于事

AWS Bedrock 跨区域推理在容量紧张时自动将请求路由到其他区域。它优化的是可用性，而非 TTFT，并将推理视为不透明。GKE 多集群网关同理——服务级故障转移，无 KV 缓存感知。

即使使用这些产品，你仍然需要应用层的缓存感知路由器。它们处理"us-east-1 着火了"的情况。缓存感知路由处理 TTFT 的情况。

### 灾备规范 — 32% 的缺失文件问题

2026 年被广泛引用的统计：32% 的 LLM 灾备失败是因为团队备份了权重但忘记了：

- `tokenizer.json` 或 `tokenizer.model`
- 量化配置（`quantize_config.json`、AWQ 缩放因子、GPTQ 零点）
- 模型特定配置（RoPE 缩放、注意力掩码、对话模板）
- 引擎配置（`vllm_config.yaml`、采样默认值、LoRA 适配器清单）

修复方案是最小化的三文件灾备清单：

1. HF 模型仓库下的所有文件（权重 + 配置 + 分词器）。
2. 引擎特定的推理配置。
3. 部署清单（K8s YAML、Dockerfile、依赖锁定文件）。

另外：每季度进行一次灾备演练。摩根大通在 2024 年 11 月的 us-east-1 演练达到了 22 分钟恢复时间，仅仅是因为操作手册经过排练。

### 数据驻留是正交约束

欧盟用户的 PHI 不能离开欧盟。如果你的缓存感知路由器将一个源自巴黎的请求发送到 us-east-1 以匹配前缀，则无论 TTFT 增益如何，都违反了 GDPR。在优化缓存之前，先按驻留边界对路由器进行分区。

### 应记住的数字

- 缓存命中 vs 未命中 TTFT 差距：约 10 倍（2K 提示词，80 ms vs 800 ms）。
- 跨区域 RTT 美国-欧盟：约 75 ms。
- 灾备失败：32% 缺少分词器/量化配置。
- 摩根大通 us-east-1 故障转移 2024 年 11 月：22 分钟（30 分钟 SLA）。

## 使用它

`code/main.py` 在多区域工作负载上模拟三种路由策略（轮询、缓存感知区域内、缓存感知全局）。报告缓存命中率、TTFT P50/P99 和跨区域账单。

## 交付它

本课生成 `outputs/skill-multi-region-router.md`。根据区域、驻留约束和 SLA，设计路由方案。

## 练习

1. 运行 `code/main.py`。在多大提示词长度下，跨区域路由（给定 75 ms RTT）优于仅本地路由？
2. 你的缓存命中率从 70% 降至 12%。诊断三种可能的原因及其各自确认所需的可观测信号。
3. 为在 vLLM 中提供、使用 AWQ 量化并附带 5 个 LoRA 适配器的 70B 模型设计一份灾备清单。列出每一个文件和配置。
4. 论证 Bedrock 跨区域推理对一家有严格 TTFT SLO 的金融科技公司是否"足够"。引用具体行为。
5. 一个源自巴黎的请求在 us-east-1 中有前缀匹配。你是否路由它？写出策略。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|----------------|------------------------|
| Cache-aware routing | "智能 LB" | 按前缀哈希匹配路由到持有 KV 缓存的副本 |
| KV-cache events | "缓存发布-订阅" | 副本发布块的添加/回收事件；路由器建立索引 |
| Prefix hash | "缓存键" | 对前 N 个 token 做哈希，用作路由器查找键 |
| GORGO | "跨区域路由研究" | arXiv 2602.11688；网络延迟作为显式项 |
| Cross-region inference | "Bedrock CRI" | AWS 产品；可用性故障转移，非 TTFT 感知 |
| DR manifest | "备份清单" | 恢复所需的每一个文件——不只是权重 |
| Data residency | "GDPR 边界" | 哪些区域可以查看用户数据的法律约束 |
| RTT | "往返时间" | 网络延迟；美国-欧盟 75 ms，美国-亚太 220 ms |
| LLM-aware LB | "缓存命中 LB" | 作为产品类别的缓存感知路由器 |

## 延伸阅读

- [BentoML — Multi-cloud and cross-region inference](https://bentoml.com/llm/infrastructure-and-operations/multi-cloud-and-cross-region-inference)
- [arXiv — GORGO (2602.11688)](https://arxiv.org/html/2602.11688v1) — 带网络延迟项的跨区域 KV 缓存复用。
- [TianPan — Multi-Region LLM Serving Cache Locality](https://tianpan.co/blog/2026-04-17-multi-region-llm-serving-data-residency-routing)
- [AWS Bedrock Cross-Region Inference](https://docs.aws.amazon.com/bedrock/latest/userguide/cross-region-inference.html) — 可用性故障转移文档。
- [vLLM Production Stack Router](https://github.com/vllm-project/production-stack) — 缓存感知路由器源码。