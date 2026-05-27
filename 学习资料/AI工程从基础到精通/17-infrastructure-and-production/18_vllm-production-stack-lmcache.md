# vLLM 生产栈与 LMCache KV 卸载

> vLLM 的 production-stack 是参考 Kubernetes 部署——路由器、引擎和可观测性串联在一起。LMCache 是 KV 卸载层，从 GPU 内存中提取 KV 缓存，并在查询和引擎之间复用它（CPU DRAM，然后磁盘/Ceph）。vLLM 0.11.0 KV 卸载连接器（KV Offloading Connector，2026 年 1 月）通过连接器 API（Connector API，v0.9.0+）使其异步且可插拔。卸载延迟对用户不可见。LMCache 即使没有共享前缀也有价值——当 GPU 耗尽 KV 槽位时，被抢占的请求可以从 CPU 恢复而非重新计算预填充。已发布的基准测试：16x H100（80 GB HBM）分布在 4 个 a3-highgpu-4g 上：当 KV 缓存超过 HBM 时，原生 CPU 卸载和 LMCache 都大幅提升吞吐量；在低 KV 占用下，所有配置与基准持平，仅有小幅开销。

**类型：** 学习
**语言：** Python（标准库，玩具级 KV 溢出模拟器）
**前置知识：** 第 17 阶段 · 04（vLLM 推理内部），第 17 阶段 · 06（SGLang/RadixAttention）
**时间：** 约 60 分钟

## 学习目标

- 画出 vLLM 生产栈的层次：路由器、引擎、KV 卸载、可观测性。
- 解释 KV 卸载连接器 API（v0.9.0+）以及 0.11.0 的异步路径如何隐藏卸载延迟。
- 量化 LMCache CPU-DRAM 在何时有帮助（KV > HBM）vs 增加开销（KV 足够小以装入 HBM）的场景。
- 在原生 vLLM CPU 卸载和 LMCache 连接器之间根据部署约束做出选择。

## 问题

你的 vLLM 推理显示 GPU 在 HBM 达到 100% 时出现抢占（Preemption）事件。请求被驱逐、重新入队，相同的 2K token 提示词一分钟内重新预填充四次。GPU 算力花费在冗余的预填充上；有效吞吐量远低于原始吞吐量。

增加 GPU 成本线性增长。增加 HBM 不可行。但 CPU DRAM 很便宜——一个 Socket 有 512 GB+，延迟比 HBM 差几个数量级，但对"临时温热"的 KV 缓存来说足够。

LMCache 将 KV 缓存提取到 CPU DRAM，使被抢占的请求快速恢复，并且引擎间重复的前缀共享缓存而无需各自重新预填充。

## 概念

### vLLM 生产栈

`github.com/vllm-project/production-stack` 是参考 Kubernetes 部署：

- **路由器** — 缓存感知（第 17 阶段 · 11）。消费 KV 事件。
- **引擎** — vLLM 工作进程。每个 GPU 或每个 TP/PP 组一个。
- **KV 缓存卸载** — LMCache 部署或原生连接器。
- **可观测性** — Prometheus 采集、Grafana 仪表板、OTel 追踪。
- **控制平面** — 服务发现、配置、滚动更新。

以 Helm chart + operator 形式发布。

### KV 卸载连接器 API（v0.9.0+）

vLLM 0.9.0 引入了可插拔 KV 缓存后端的连接器 API（Connector API）。你的引擎将块卸载到连接器；连接器存储它们（RAM、磁盘、对象存储、LMCache）。请求需要一个块时，连接器加载回来。

vLLM 0.11.0（2026 年 1 月）添加了异步卸载路径——卸载可在后台进行，因此引擎在通常情况下不会阻塞。端到端延迟和吞吐量仍取决于工作负载形态、KV 缓存命中率和系统压力；vLLM 自己的备注指出自定义内核卸载在低命中率下可能降低吞吐量，异步调度与推测解码（Speculative Decoding）有已知的交互问题。

### 原生 CPU 卸载 vs LMCache

**原生 vLLM CPU 卸载**：引擎本地。将 KV 块存储在主机 RAM 中。实现快速，零网络跳数。不能跨引擎共享。

**LMCache 连接器**：集群规模。将块存储在共享的 LMCache 服务器中（CPU DRAM + Ceph/S3 层次）。任何引擎都可以访问这些块。已发布 16x H100 基准测试。

当单个引擎面临 HBM 压力时选择原生。当多个引擎共享前缀时（带有通用系统提示词的 RAG、共享模板的多租户）选择 LMCache。

### 基准测试行为

16x H100（80 GB HBM）分布在 4 个 a3-highgpu-4g 上的测试：

- 低 KV 占用（短提示词、低并发）：所有配置与基准持平，LMCache 增加约 3-5% 开销。
- 中等占用：LMCache 在引擎间前缀复用时开始帮助。
- KV 超过 HBM：原生 CPU 卸载和 LMCache 都大幅提升吞吐量；LMCache 增益更大，因为有跨引擎共享。

### LMCache 决定性作用的场景

- 跨租户共享系统提示词的多租户推理。
- 文档块跨查询重复出现的 RAG。
- 同一基座的微调变体（LoRA），基座模型 KV 复用减少了冗余工作。
- 抢占密集型工作负载：从 CPU 恢复比重新预填充便宜。

### 何时不启用

- HBM 压力小——付出开销但无收益。
- 短上下文（<1K token）——传输时间 > 重新预填充。
- 单租户单提示词工作负载——无可捕获的复用。

### 与分离式推理的集成

第 17 阶段 · 17 的分离式推理 + LMCache 叠加：KV 传输从预填充池到解码池时，如果不使用则存入 LMCache；后续查询从 LMCache 拉取。第 17 阶段 · 11 的缓存感知路由器可以路由到其本地 OR LMCache 共享缓存匹配的引擎。

### 应记住的数字

- vLLM 0.9.0：连接器 API 发布。
- vLLM 0.11.0（2026 年 1 月）：异步卸载路径；端到端延迟影响取决于工作负载、KV 命中率和系统压力（非绝对保证）。
- 16x H100 基准测试：KV 占用超过 HBM 时 LMCache 有帮助。
- HBM 压力小：3-5% 开销且无收益。

## 使用它

`code/main.py` 模拟抢占密集型工作负载有无 LMCache 的情况。报告避免的重新预填充次数、吞吐量增益和盈亏平衡的 HBM 利用率。

## 交付它

本课生成 `outputs/skill-vllm-stack-decider.md`。根据工作负载形态和 vLLM 部署，决定原生方案 vs LMCache vs 两者都不用。

## 练习

1. 运行 `code/main.py`。在多大 HBM 利用率下 LMCache 开始划算？
2. 一个租户在 200 查询/小时中共享 6K token 系统提示词。计算每个租户的预期 LMCache 节省。
3. LMCache 服务器是单点故障。设计高可用策略（副本、回退到原生）。
4. LMCache 存储到旋转磁盘上的 Ceph。对于一个 70B FP8 的 4K token KV（500 MB），读取时间 vs 重新预填充如何？
5. 论证 vLLM 0.11.0 异步路径是否"免费"——开销隐藏在哪里？

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|----------------|------------------------|
| Production-stack | "参考部署" | vLLM 的 Kubernetes Helm chart + operator |
| Connector API | "KV 后端接口" | vLLM 0.9.0+ 可插拔 KV 存储接口 |
| Native CPU offload | "引擎本地溢出" | 将 KV 存储在同一引擎的主机 RAM 中 |
| LMCache | "集群 KV 缓存" | CPU DRAM + 磁盘上的跨引擎 KV 缓存服务器 |
| 0.11.0 async | "非阻塞卸载" | 在引擎流背后隐藏卸载 |
| Preemption | "驱逐以腾出空间" | HBM 满时的 KV 缓存清洗 |
| Prefix reuse | "相同系统提示词" | 多个查询共享开头；缓存命中 |
| Ceph tier | "磁盘层" | KV 缓存层次中 DRAM 下方的持久存储 |

## 延伸阅读

- [vLLM Blog — KV Offloading Connector (Jan 2026)](https://blog.vllm.ai/2026/01/08/kv-offloading-connector.html)
- [vLLM Production Stack GitHub](https://github.com/vllm-project/production-stack) — Helm chart + operator。
- [LMCache for Enterprise-Scale LLM Inference (arXiv:2510.09665)](https://arxiv.org/html/2510.09665v2)
- [LMCache GitHub](https://github.com/LMCache/LMCache) — 连接器实现。
- [vLLM 0.11.0 release notes](https://github.com/vllm-project/vllm/releases) — 异步路径详情。