# Kubernetes 上的 GPU 自动扩展 —— Karpenter、KAI Scheduler、Gang 调度

> 三层，而非一层。Karpenter 动态供应节点（一分钟内，比 Cluster Autoscaler 快 40%）。KAI Scheduler 处理 Gang 调度、拓扑感知和层级队列——它防止 8 个中 7 个部分分配陷阱（Partial-Allocation Trap），即七个节点等待一个缺失 GPU 并烧钱。应用级自动扩展器（NVIDIA Dynamo Planner、llm-d Workload Variant Autoscaler）基于推理特定信号——队列深度、KV 缓存利用率——而非 CPU/DCGM 占空比。经典的 HPA 陷阱是 `DCGM_FI_DEV_GPU_UTIL` 是一个占空比测量：100% 可能是 10 个请求也可能是 100 个。vLLM 预分配 KV 缓存内存，因此内存永远不会触发缩减。本课教你组合三层并避免默认的 Karpenter `WhenEmptyOrUnderutilized` 策略，该策略会在推理中途终止运行中的 GPU 作业。

**类型：** 学习
**语言：** Python（标准库，玩具级队列深度自动扩展模拟器）
**前置条件：** Phase 17 · 02（推理平台经济学）、Phase 17 · 04（vLLM 推理内部）
**时间：** ~75 分钟

## 学习目标

- 画出三层自动扩展（节点供应、Gang 调度、应用级）并命名每层使用的工具。
- 解释为什么 `DCGM_FI_DEV_GPU_UTIL` 对 vLLM 是错误的 HPA 信号，并命名两个替代信号（队列深度、KV 缓存利用率）。
- 描述 Gang 调度和 KAI Scheduler 防止的部分分配失败模式（8 个中有 7 个 GPU 空闲）。
- 命名终止运行中 GPU 作业的 Karpenter 整合策略（`WhenEmptyOrUnderutilized`）并陈述 2026 年的安全替代方案。

## 问题

你的团队在 Kubernetes 上发布了一个 LLM 推理服务。你设置了 HPA，以 `DCGM_FI_DEV_GPU_UTIL` 为信号。服务在工作时间固定在 100% 利用率。HPA 从不扩展——它已经认为你满了。你手动添加一个副本；TTFT 下降。HPA 仍然不扩展。信号在对你撒谎。

另外，你为节点使用 Cluster Autoscaler。一个 1M Token 的提示在凌晨 2 点到达；集群花了 3 分钟供应节点，请求超时。

另外，你部署一个需要 8 个 GPU 跨 2 个节点的 70B 模型。集群有 7 个 GPU 空闲，1 个分布在 3 个节点上。Cluster Autoscaler 为缺少的 1 个 GPU 供应一个节点。七个节点等待 4 分钟烧钱，而 Kubernetes 启动最后一个 GPU。

三层，三种不同的失败模式。2026 年的 GPU 感知自动扩展不是"打开 HPA"。它是组合节点供应、Gang 调度和应用信号自动扩展。

## 概念

### 第一层——节点供应（Karpenter）

Karpenter 监视挂起的 Pod 并在约 45-60 秒内供应节点（Cluster Autoscaler 对 GPU 节点通常需要 90-120 秒）。它根据 `NodePool` 约束动态选择实例类型——如果你的 Pod 需要 8 个 H100 而集群没有匹配的节点，Karpenter 直接供应一个，而不是扩展现有组。

**整合陷阱**：Karpenter 的默认 `consolidationPolicy: WhenEmptyOrUnderutilized` 对 GPU 池是危险的。它将终止一个运行中的 GPU 节点，将 Pod 迁移到更便宜的合适大小的实例。对于推理工作负载，这意味着驱逐运行中的请求，并在新节点上重新加载 70B 模型。损失是数分钟的容量加上请求失败。

GPU 池的安全设置：

```yaml
disruption:
  consolidationPolicy: WhenEmpty
  consolidateAfter: 1h
```

允许 Karpenter 在一小时后整合真正空闲的节点，但绝不驱逐运行中的作业。

### 第二层——Gang 调度（KAI Scheduler）

KAI Scheduler（项目"Karp"后更名）处理默认 kube-scheduler 不处理的事情：

**Gang 调度**——全有或全无调度。一个需要 8 个 GPU 的分布式推理 Pod，要么全部 8 个一起启动，要么一个也不启动。没有这个，你会遇到部分分配陷阱：8 个 Pod 中的 7 个启动，无限等待，烧钱。

**拓扑感知**——知道哪些 GPU 共享 NVLink，哪些位于同一机架，哪些之间有 InfiniBand。相应地放置 Pod。DeepSeek-V3 67B 张量并行工作负载必须停留在一个 NVLink 域内；KAI Scheduler 遵守这一点。

**层级队列**——多个团队以优先级和配额竞争同一 GPU 池。A 团队的生产任务只有在优先级规则允许时才被 B 团队的训练作业抢占。

KAI 作为辅助调度器部署在 kube-scheduler 旁边；你注释工作负载以使用它。Ray 和 vLLM 生产栈都集成。

### 第三层——应用级信号

**HPA 陷阱**：`DCGM_FI_DEV_GPU_UTIL` 是一个占空比指标——它测量 GPU 在每个采样间隔是否在工作。100% 利用率可能意味着 10 个并发请求或 100 个；GPU 无论如何都很忙。基于占空比扩展是盲扩展。

更糟的是，vLLM 和类似引擎预分配 KV 缓存内存（上限为 `--gpu-memory-utilization`）。即使只有一个请求，内存使用也保持在 90% 左右。基于内存的 HPA 永远不会缩减。

**2026 年替代信号**：

- 队列深度（等待预填充的请求数）。
- KV 缓存利用率（分配给活跃序列的块比例）。
- 每副本 P99 TTFT（你的 SLA 信号）。
- 有效吞吐量（Goodput，每秒满足所有 SLO 的请求数）。

NVIDIA Dynamo Planner 和 llm-d Workload Variant Autoscaler 消费这些信号并扩展副本。它们完全替代了 LLM 推理的 HPA。

### 何时使用什么

| 扩展决策 | 工具 |
|----------------|------|
| 添加/移除节点 | Karpenter |
| 调度多 GPU 作业 | KAI Scheduler |
| 添加/移除副本 | Dynamo Planner / llm-d WVA（或基于队列深度的自定义 HPA） |
| 选择 GPU 类型 | Karpenter NodePool |
| 抢占低优先级 | KAI Scheduler 队列 |

### 分离式预填充/解码使一切复杂化

如果你运行分离式预填充/解码（Phase 17 · 17），你有两种 Pod 类别，具有不同的扩展触发器：预填充 Pod 基于队列深度扩展，解码 Pod 基于 KV 缓存压力扩展。llm-d 将这些作为独立的 `Services` 暴露，具有每角色 HPA。不要试图在两者前面放一个单一的 HPA。

### 冷启动在这里也很重要

冷启动缓解（Phase 17 · 10）是节点供应时间变得用户可见的地方。Karpenter 的 45-60 秒预热加 20GB 模型加载加引擎初始化意味着一个从零开始的请求需要 2-5 分钟。为 SLO 关键路径保持一个预热池（`min_workers=1`），或在应用层使用 Modal 风格的检查点。

### 你应该记住的数字

- Karpenter 节点供应：~45-60s vs Cluster Autoscaler ~90-120s（GPU 节点）。
- KAI Scheduler 防止部分分配浪费——8 中 7 陷阱。
- `DCGM_FI_DEV_GPU_UTIL` 作为 HPA 信号：已损坏；使用队列深度或 KV 利用率。
- Karpenter `WhenEmptyOrUnderutilized`：终止运行中的 GPU 作业。推理使用 `WhenEmpty + consolidateAfter: 1h`。

## 使用它

`code/main.py` 在突发 GPU 工作负载上模拟三层自动扩展器。比较 naive HPA（占空比）、队列深度 HPA 和 KAI-gang 调度扩展。报告未满足的请求、空闲 GPU 分钟数和综合评分。

## 交付它

本课产出 `outputs/skill-gpu-autoscaler-plan.md`。给定集群拓扑、工作负载形态和 SLO，设计一个三层自动扩展计划。

## 练习

1. 运行 `code/main.py`。在突发工作负载下，naive 占空比 HPA 丢弃了多少请求，而队列深度 HPA 捕获了这些请求？差异来自哪里？
2. 为在 H100 SXM5 上推理 Llama 3.3 70B FP8 的集群设计一个 Karpenter NodePool。指定 `capacity-type`、`disruption.consolidationPolicy`、`consolidateAfter`，以及一个使非 GPU 工作负载远离这些节点的污点。
3. 你的团队报告部署卡在 Pending 状态，因为"GPU 可用但 Pod 无法调度"。诊断——这是 Karpenter、kube-scheduler 还是 KAI Scheduler？哪些指标可以确认？
4. 为分离式预填充 Pod 选择一个自动扩展信号，为解码 Pod 选择另一个信号。论证两者。
5. 计算 `WhenEmptyOrUnderutilized` 整合陷阱在 24x7 生产服务上的成本，该服务平均每天有 60 次请求丢弃事件，P99 TTFT > 10s。

## 关键术语

| 术语 | 人们的说法 | 实际含义 |
|------|----------------|------------------------|
| Karpenter | "节点供应器" | Kubernetes 节点自动扩展器；亚分钟供应 |
| Cluster Autoscaler | "旧的扩展器" | Kubernetes 节点自动扩展器前身；更慢，基于组 |
| KAI Scheduler | "GPU 调度器" | 辅助调度器，用于 Gang + 拓扑 + 队列 |
| Gang 调度 | "全有或全无" | 原子调度 N 个 Pod 或全部推迟 |
| 拓扑感知 | "机架感知" | 基于 NVLink/IB/机架位置放置 Pod |
| `DCGM_FI_DEV_GPU_UTIL` | "GPU 利用率" | 占空比指标；不是 LLM 的扩展信号 |
| 队列深度 | "等待请求" | 预填充绑定扩展的正确 HPA 信号 |
| KV 缓存利用率 | "内存压力" | 解码绑定扩展的正确 HPA 信号 |
| 整合 | "Karpenter 整合" | 节点终止以切换到更便宜的实例类型 |
| `WhenEmpty + 1h` | "安全整合" | 不驱逐运行中 GPU 作业的策略 |

## 扩展阅读

- [KAI Scheduler GitHub](https://github.com/kai-scheduler/KAI-Scheduler) —— 设计文档和配置示例。
- [Karpenter 中断控制](https://karpenter.sh/docs/concepts/disruption/) —— 整合策略语义和 GPU 安全默认值。
- [NVIDIA — Kubernetes 上的分离式 LLM 推理](https://developer.nvidia.com/blog/deploying-disaggregated-llm-inference-workloads-on-kubernetes/) —— Dynamo Planner 扩展信号。
- [Ray 文档 — RayClusters 的 KAI Scheduler](https://docs.ray.io/en/latest/cluster/kubernetes/k8s-ecosystem/kai-scheduler.html) —— Ray 集成模式。
- [AWS EKS 计算和自动扩展最佳实践](https://docs.aws.amazon.com/eks/latest/best-practices/aiml-compute.html) —— 托管 Kubernetes 特定指南。
- [llm-d GitHub](https://github.com/llm-d/llm-d) —— Workload Variant Autoscaler 设计。