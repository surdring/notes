# 分离式预填充/解码 — NVIDIA Dynamo 与 llm-d

> 预填充受限于计算（Compute-Bound）；解码受限于内存（Memory-Bound）。在同一 GPU 上运行两者会浪费一种资源。分离式架构（Disaggregation）将它们拆分到独立的资源池，并通过 NIXL（RDMA/InfiniBand 或 TCP 回退）在两者之间传输 KV 缓存。NVIDIA Dynamo（GTC 2025 宣布，1.0 GA）位于 vLLM/SGLang/TRT-LLM 之上——其 Planner Profiler + SLA Planner 自动匹配预填充:解码比率以满足 SLO。NVIDIA 公布的吞吐量增益大致在此区间——developer.nvidia.com（2025-06）显示 DeepSeek-R1 MoE 在 GB200 NVL72 + Dynamo 上在中延迟区间约 6 倍提升，Dynamo 产品页面（developer.nvidia.com，无日期）宣传 GB300 NVL72 + Dynamo 相比 Hopper 最高 50 倍 MoE 吞吐量。"30 倍"这个数字是全栈 Blackwell + Dynamo + DeepSeek-R1 报告的社区汇总；我们未找到单一来源精确陈述 30 倍，因此将其视为方向性声明。llm-d（Red Hat + AWS）是 Kubernetes 原生的：预填充 / 解码 / 路由器作为独立 Service，按角色配置 HPA。llm-d 0.5 新增了层次化 KV 卸载（Hierarchical KV Offloading）、缓存感知 LoRA 路由、UCCL 网络、缩减至零。经济学：多个客户披露的内部汇总显示，在恒定 SLA 下从共址推理切换到分离式配合 Dynamo 可节省 30-40% 的 $2M 级推理支出（即 $600-800K/年）；具体的 $2M→$600-800K 数字是内部复合数据，非单一发表的案例研究——用作数量级锚点，而非引用来源。短提示词（<512 token，短输出）不值得付出传输代价。

**类型：** 学习
**语言：** Python（标准库，玩具级分离式 vs 共址模拟器）
**前置知识：** 第 17 阶段 · 04（vLLM 推理内部），第 17 阶段 · 08（推理指标）
**时间：** 约 75 分钟

## 学习目标

- 解释为什么预填充和解码有不同的最优 GPU 分配，并量化共址下的浪费。
- 画出分离式架构图：预填充池、解码池、通过 NIXL 的 KV 传输、路由器。
- 说出分离式架构不划算的条件（短提示词、短输出）。
- 区分 NVIDIA Dynamo（上层编排器）和 llm-d（Kubernetes 原生），并分别匹配到对应的运维上下文。

## 问题

你在 8 块 H100 上运行 Llama 3.3 70B。在混合工作负载下（长提示词 + 短输出），GPU 在解码期间空闲，因为大部分计算花在了预填充上。在不同工作负载下（短提示词 + 长输出），则相反。共址的预填充 + 解码意味着你对两者都过度供应。

预算影响：20-40% 的 GPU 时间浪费在错误的资源上。你购买 H100 算力来运行内存受限的解码，或者购买 H100 HBM 带宽来运行计算受限的预填充。两者都是昂贵的浪费。

分离式架构将预填充和解码拆分到各自按瓶颈维度规划的独立资源池。KV 缓存通过高带宽互联从预填充池传输到解码池。

## 概念

### 瓶颈为什么不同

**预填充** — 在完整输入提示词上一次性运行 transformer。矩阵乘法占主导；计算受限。H100 FP8 提供约 2000 TFLOPS 有效吞吐量。批量效率好——一次前向计算处理大量 token。

**解码** — 逐 token 生成，每次迭代读取全部权重。内存带宽受限。HBM3 提供约 3 TB/s。批量效率仅在高并发下表现良好——权重读取在批量上均摊。

共址：你购买同时针对两者优化的 GPU。H100 在两者上都表现良好，但无论如何成本相同。在大规模下，你希望预填充池用 H100 / 计算密集型；解码池用 H200 / 内存密集型，或配合激进量化。

### 架构

```
            ┌──────────────┐
  Request → │    路由器     │ ───────────────────────┐
            └──────┬───────┘                        │
                   │                                │
                   ▼ （仅提示词）                     │
            ┌──────────────┐    KV 缓存     ┌───────▼──────┐
            │  预填充池    │ ─── NIXL ────► │   解码池     │
            │  （计算）     │                │  （内存）     │
            └──────────────┘                └──────┬───────┘
                                                   │ token
                                                   ▼
                                                 客户端
```

NIXL 是 NVIDIA 的节点间传输层。可用时使用 RDMA/InfiniBand，否则 TCP 回退。传输延迟是真实存在的——70B FP8 的 4K token 提示词 KV 缓存典型为 20-80 ms。这就是短提示词不值得分离式架构的原因：传输税超过节省。

### Dynamo vs llm-d

**NVIDIA Dynamo**（GTC 2025 宣布，1.0 GA）：
- 位于 vLLM、SGLang、TRT-LLM 之上的编排器。
- Planner Profiler 测量工作负载，SLA Planner 自动配置预填充:解码比率。
- Rust 核心，Python 可扩展。
- 吞吐量增益：NVIDIA 报告 DeepSeek-R1 MoE 在 GB200 NVL72 + Dynamo 上在中延迟区间约 6 倍提升（developer.nvidia.com，2025-06）；社区关于全栈 Blackwell + Dynamo + DeepSeek-R1 "最高 30 倍"的说法缺乏单一主要来源，应视为方向性声明。
- GB300 NVL72 + Dynamo：相比 Hopper 最高 50 倍 MoE 吞吐量，据 Dynamo 产品页面（developer.nvidia.com，无日期）。

**llm-d**（Red Hat + AWS，Kubernetes 原生）：
- 预填充 / 解码 / 路由器作为独立的 Kubernetes Service。
- 按角色配置 HPA，使用队列深度（预填充）/ KV 利用率（解码）信号。
- `topologyConstraint packDomain: rack` 将预填充+解码团（Clique）打包在同一机架上以实现高带宽 KV 传输。
- llm-d 0.5（2026）：层次化 KV 卸载、缓存感知 LoRA 路由、UCCL 网络、缩减至零。

如果想要托管的上层编排器，使用 Dynamo。如果想要 Kubernetes 原生原语且投入 CNCF 生态系统，使用 llm-d。

### 经济学

内部复合数据（非单一发表的案例研究——数量级锚点）：

- $2M/年推理支出，共址推理服务。
- 切换到分离式 + Dynamo。
- 相同请求量，相同 P99 延迟 SLA。
- 报告节省：$600K–$800K/年（降低 30-40%）。
- 无需新硬件。

我们从多个客户披露中综合出这个数字，而非单一的引用案例研究；最接近的已发表数据点是 Baseten 使用 Dynamo KV 路由实现 2 倍更快的 TTFT / 61% 更高的吞吐量（baseten.co，2025-10），以及 VAST + CoreWeave 预测在 40-60% KV 命中率下每个 token 成本节省 60-130%（vastdata.com，2025-12）。节省来自为各池合理规划资源；预填充密集型工作负载（8K+ 前缀的 RAG）比均衡型受益更多。

### 何时不应使用分离式架构

- 提示词 < 512 token 且输出 < 200 token：传输税超过收益。
- 小集群（< 4 GPU）：池多样性不足。
- 团队无法运维两个带按角色缩放的 GPU 池：Dynamo 有帮助但并非易事。
- 无 RDMA 网络：TCP 传输税更重。

### 路由器与第 17 阶段 · 11 集成

分离式路由器是 KV 缓存感知的（第 17 阶段 · 11）。请求落在持有其前缀的解码池上——如果没有匹配，则流经预填充 → 解码。命中率和分离式架构相互叠加——缓存感知路由器决定是否甚至需要新的预填充。

### MoE on Blackwell 才是真正数字所在

GB300 NVL72 + Dynamo 显示相比 Hopper 基准 50 倍 MoE 吞吐量。MoE 专家路由在预填充时是计算密集型，但在解码时是内存密集型（专家缓存），因此分离式架构是双重胜利。2026 年前沿模型推理以 MoE 为主导（DeepSeek-V3、未来的 GPT-5 变体）。

### 应记住的数字

基准数字会漂移——NVIDIA 和推理栈每季度发布更新结果。引用前重新核对。

- DeepSeek-R1 on GB200 NVL72 + Dynamo：中延迟区间约 6 倍吞吐量相比基准（developer.nvidia.com，2025-06）；社区全栈 Blackwell + Dynamo 的"最高 30 倍"说法是方向性汇总，无单一主要来源。
- GB300 NVL72 + Dynamo：相比 Hopper 最高 50 倍 MoE 吞吐量（developer.nvidia.com，无日期）。
- 节省锚点（内部复合数据，非单一案例研究）：恒定 SLA 下 $2M 年度支出节省 $600-800K/年。
- 分离式架构阈值：提示词 >512 token + 输出 >200 token。
- 通过 NIXL 的 KV 传输：70B FP8 的 4K 提示词 KV 需 20-80 ms。

## 使用它

`code/main.py` 模拟共址 vs 分离式推理。报告吞吐量、每请求成本和提示词长度交叉点。

## 交付它

本课生成 `outputs/skill-disaggregation-decider.md`。根据工作负载和集群，决定是否采用分离式架构。

## 练习

1. 运行 `code/main.py`。在多大提示词长度下分离式架构优于共址？
2. 为一个 P99 前缀长度 8K、输出 300 的 RAG 服务设计预填充池和解码池。
3. Dynamo vs llm-d：为一个纯 Kubernetes 团队（无 Python 运行时偏好）选择其一。
4. 计算 KV 传输成本：70B FP8 的 4K 预填充 = 约 500 MB KV。在 RDMA 100 GB/s 下，传输 = 5 ms。在 TCP 10 GB/s = 50 ms。哪个对你的 SLA 最重要？
5. MoE 专家路由改变了 KV 访问模式。对每个 token 激活不同专家的 MoE，分离式架构表现如何？

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|----------------|------------------------|
| Disaggregated serving | "拆分预填充/解码" | 各阶段独立的 GPU 池 |
| NIXL | "NVIDIA 传输" | Dynamo 的节点间 KV 传输（RDMA/TCP） |
| NVIDIA Dynamo | "编排器" | vLLM/SGLang/TRT-LLM 的上层协调器 |
| llm-d | "Kubernetes 原生" | Red Hat + AWS 的 K8s 分离式架构栈 |
| Planner Profiler | "Dynamo 自动配置" | 测量工作负载，配置池比率 |
| SLA Planner | "Dynamo 策略" | 自动速率匹配预填充:解码以满足 SLO |
| `packDomain: rack` | "llm-d 拓扑" | 在同一机架打包预填充+解码以实现快速 KV 传输 |
| UCCL | "统一集合通信" | llm-d 0.5 网络层，用于缩减至零 |
| MoE expert routing | "每个 token 的专家" | DeepSeek-V3 模式；分离式架构有帮助 |

## 延伸阅读

- [NVIDIA — Introducing Dynamo](https://developer.nvidia.com/blog/introducing-nvidia-dynamo-a-low-latency-distributed-inference-framework-for-scaling-reasoning-ai-models/)
- [NVIDIA — Disaggregated LLM Inference on Kubernetes](https://developer.nvidia.com/blog/deploying-disaggregated-llm-inference-workloads-on-kubernetes/)
- [TensorRT-LLM Disaggregated Serving blog](https://nvidia.github.io/TensorRT-LLM/blogs/tech_blog/blog5_Disaggregated_Serving_in_TensorRT-LLM.html)
- [llm-d GitHub](https://github.com/llm-d/llm-d)
- [llm-d 0.5 release notes](https://github.com/llm-d/llm-d/releases)