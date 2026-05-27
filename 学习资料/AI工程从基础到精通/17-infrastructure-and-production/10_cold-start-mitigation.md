# 无服务器 LLM 冷启动缓解

> 一个 20 GB 模型镜像从冷启动到提供服务需要 5-10 分钟（7B）到 20 分钟以上（70B）。在真正的无服务器（Serverless）世界中，这已经不是一个预热问题——而是一次宕机。缓解措施分为五个层面：预植入节点镜像（AWS Bottlerocket，双卷架构）、模型流式加载（NVIDIA Run:ai Model Streamer，vLLM 原生支持）、GPU 内存快照（Modal 检查点，重启速度最高提升 10 倍）、预热池（`min_workers=1`）、分层加载（ServerlessLLM 的 NVMe→DRAM→HBM 管线，延迟降低 10-200 倍），以及将输入 token（KB 级）而非 KV 缓存（GB 级）转移的实时迁移。Modal 公布的冷启动时间为 2-4 秒；Baseten 默认为 5-10 秒，预热后可达亚秒级。本课教你测量、预算并叠加这五个层面的缓解措施。

**类型：** 学习
**语言：** Python（标准库，玩具级冷启动路径模拟器）
**前置知识：** 第 17 阶段 · 02（推理平台经济学），第 17 阶段 · 03（GPU 自动扩展）
**时间：** 约 60 分钟

## 学习目标

- 列举冷启动缓解的五个层面，并说出每个层面的一种工具或模式。
- 将总冷启动时间计算为（节点供应）+（权重下载）+（权重加载到 HBM）+（引擎初始化）之和，以 70B 模型为例。
- 解释为什么实时迁移传输的是输入 token（KB 级）而非 KV 缓存（GB 级），以及其代价是什么（重新计算）。
- 说出预热池的权衡（为闲置 GPU 付费还是接受冷启动尾部延迟），以及 `min_workers > 0` 成为必需的 SLA 阈值。

## 问题

你的无服务器 LLM 端点夜间缩减至零。早上 8 点流量激增。第一个请求等待的过程中：

1. Karpenter 供应 GPU 节点：45-60 秒。
2. 容器拉取 30 GB 含权重的镜像：120-300 秒。
3. 引擎将权重加载到 HBM：45-120 秒，取决于模型大小和存储速度。
4. vLLM 或 TRT-LLM 初始化 CUDA 图、KV 缓存池、分词器：10-30 秒。

总计：220-510 秒（约 3-8 分钟）之后才能产出第一个 token。而你的 SLA 是 2 秒。你加了一个预热池（`min_workers=1`），问题似乎消失了——但你现在 24×7 为一个闲置 GPU 付费。如果你的服务有 5 个产品，每个有一个预热副本，那就是 5 × 24 × 30 = 3600 GPU 小时/月，无论有没有用户调用。

冷启动缓解就是在保持无服务器经济性的同时，逼近常驻服务的延迟。

## 概念

### 第一层 — 预植入节点镜像（Bottlerocket）

在 AWS 上，Bottlerocket 的双卷架构将操作系统与数据分离。对数据卷做快照，使容器镜像已预先拉取；在 `EC2NodeClass` 中引用快照 ID。新节点启动时权重已在本地 NVMe 上——步骤 2 和步骤 3 的一部分消除。与 Karpenter 原生配合使用。典型节省：大模型每次冷启动节省 2-4 分钟。

GCP 等效方案：使用预烘焙容器层的自定义 VM 镜像。Azure：使用托管磁盘快照的相同模式。

### 第二层 — 模型流式加载（Run:ai Model Streamer）

不再加载完整文件后才响应第一个请求，而是逐层将权重流式加载到 GPU 内存中，当第一个 Transformer 块驻留后即开始处理。NVIDIA Run:ai Model Streamer 在 vLLM 2026 中原生支持。支持 S3、GCS 和本地 NVMe。通过重叠 I/O 与计算设置，将大模型权重加载时间大约减半。

### 第三层 — GPU 内存快照（Modal）

Modal 在首次加载后对 GPU 状态（权重、CUDA 图、KV 缓存区域）进行检查点保存。后续重启时直接反序列化到 HBM——比重新初始化快 10 倍。这最接近"在 2 秒内启动一个热 GPU"。权衡：快照与 GPU 拓扑绑定，如果 Karpenter 将你迁移到不同 SKU，你需要重新检查点。

### 第四层 — 预热池（min_workers=1）

最简单的缓解：始终保持一个副本就绪。成本是一块 GPU 的 24×7 小时费率。小模型上这个算术很残酷（支付 $0.85-$1.50/小时来避免 30 秒冷启动），大模型上则较为友好（支付 $4/小时来避免 5 分钟冷启动）。预热池成为必需的 SLA 阈值：通常是 70B+ 模型上 TTFT P99 < 60 秒。

### 第五层 — 分层加载（ServerlessLLM）

ServerlessLLM 将存储视为一个层次结构：NVMe（快但大）、DRAM（中等但分层）、HBM（小但即时）。权重预加载到 DRAM；按需加载到 HBM。论文报告相比朴素的磁盘到 HBM 加载，延迟降低 10-200 倍。生产采用尚在早期，但已有 vLLM 集成。

### 第六层 — 实时迁移（奖励模式）

当节点不可用时（竞价实例回收、节点排空），传统模式是冷启动另一个副本并排空请求队列。实时迁移将输入 token（KB 级）移动到已加载模型的目标节点，并在目标节点上重新计算 KV 缓存。重新计算比通过网络传输 GB 级 KV 缓存更便宜。适用于分离式部署（Disaggregated Deployment）。

### 预热池的数学

对于 TTFT P99 SLA 为 2 秒的服务，问题不是"预热池要还是不要"，而是"多少个预热副本，以及哪些路径需要它们"。

- 高价值交互路径（实时聊天、语音代理）：`min_workers=1-2`。
- 后台批处理路径（夜间分类）：接受缩减至零，容忍 5-10 分钟冷启动。
- 高级用户层：按租户设置 `min_workers` 并分配专用容量。

### 先测量再优化

70B 模型在新节点上的冷启动解剖（示例）：

| 阶段 | 时间 | 缓解措施 |
|-------|------|-----------|
| 节点供应 | 50 秒 | Bottlerocket + 预植入镜像、预热池 |
| 镜像拉取 | 180 秒 | 预植入数据卷（消除） |
| 权重到 HBM | 75 秒 | 模型流式加载器（减半）；GPU 快照（消除） |
| 引擎初始化 | 20 秒 | 持久化 CUDA 图缓存 |
| 首次前向计算 | 3 秒 | 最小固有延迟 |
| **总冷启动** | **328 秒** | |
| **缓解后总计** | **~15 秒** | 22 倍缩减 |

### 应记住的数字

- Modal 冷启动：2-4 秒（使用 GPU 快照）。
- Baseten 默认冷启动：5-10 秒；预热后亚秒级。
- 原始 70B 冷启动：3-8 分钟。
- Run:ai Model Streamer：约 2 倍权重加载加速。
- ServerlessLLM 分层加载：10-200 倍延迟降低（论文数据）。

## 使用它

`code/main.py` 建模有和没有每种缓解措施的冷启动路径。报告总冷启动时间、预热池成本，以及预热池值回成本的盈亏平衡请求率。

## 交付它

本课生成 `outputs/skill-cold-start-planner.md`。根据 SLA、模型规模、流量形态，选择叠加哪些缓解措施。

## 练习

1. 运行 `code/main.py`。计算盈亏平衡请求率：超过该速率时，预热副本比因 SLO 处额外请求丢弃而支付冷启动税更便宜。
2. 你部署一个 13B 模型，TTFT P99 SLA 为 3 秒。选择实现该目标所需的最少缓解措施栈（最少层数）。
3. Bottlerocket 预植入消除了镜像拉取，但权重仍从快照加载到 HBM。如果快照支持的 NVMe 读取速度为 7 GB/s，计算 70B 模型的实际耗时。
4. 你的无服务器提供商提供 GPU 快照（Modal），但你的团队以"快照会泄露 PII"为由拒绝。论证双方——现实风险是什么，缓解措施是什么（临时快照、加密、命名空间隔离）？
5. 设计一个分层预热池策略：付费用户、试用用户和批处理工作负载各需要多少个预热副本？展示计算过程。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|----------------|------------------------|
| Cold start | "那段大停顿" | 一个新副本上从请求到首个 token 的时间 |
| Warm pool | "常驻最小值" | `min_workers >= 1`，始终保持至少一个副本就绪 |
| Pre-seeded image | "预烘焙 AMI" | 容器权重已预装的节点镜像 |
| Bottlerocket | "AWS 节点操作系统" | AWS 容器优化操作系统，支持双卷快照 |
| Model streamer | "流式加载" | 重叠权重的 I/O 与计算设置 |
| GPU snapshot | "检查点到 HBM" | 序列化加载后的 GPU 状态；重启时反序列化 |
| Tiered loading | "NVMe + DRAM + HBM" | 存储层次结构；按需加载 |
| Live migration | "移动 token" | 传输输入（KB 级），在目标节点重新计算 KV |
| `min_workers` | "预热副本" | Serverless 最小保活数量 |
| Scale-to-zero | "完全 Serverless" | 空闲时零成本；接受完整冷启动税 |

## 延伸阅读

- [Modal — Cold start performance](https://modal.com/docs/guide/cold-start) — Modal 公布的基准和检查点架构。
- [AWS Bottlerocket](https://github.com/bottlerocket-os/bottlerocket) — 预植入数据卷快照模式。
- [NVIDIA Run:ai Model Streamer](https://github.com/run-ai/runai-model-streamer) — 重叠权重加载与计算设置。
- [Baseten — Cold-start mitigation](https://www.baseten.co/blog/cold-start-mitigation/) — 预热操作手册。
- [ServerlessLLM paper (USENIX OSDI'24)](https://www.usenix.org/conference/osdi24/presentation/fu) — 分层加载设计。
- [NVIDIA — Disaggregated LLM Inference on Kubernetes](https://developer.nvidia.com/blog/deploying-disaggregated-llm-inference-workloads-on-kubernetes/) — 分离式部署的实时迁移。