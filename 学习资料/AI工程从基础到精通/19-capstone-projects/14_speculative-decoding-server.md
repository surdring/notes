# 综合项目 14 — 推测解码推理服务器

> vLLM 0.7 中的 EAGLE-3 在实际流量上提供 2.5-3 倍吞吐量。P-EAGLE（AWS 2026）进一步推动了并行推测。SGLang 的 SpecForge 大规模训练草稿头。Red Hat 的 Speculators hub 为常见的开源模型发布了对齐草稿。TensorRT-LLM 使推测解码在 NVIDIA 上成为一等公民。2026 年的生产服务栈是 vLLM 或 SGLang 配合 EAGLE 家族草稿、FP8 或 INT4 量化，以及基于队列等待的 HPA。本综合项目旨在以 2.5 倍以上基线吞吐量服务两个开源模型，并附上完整的尾延迟报告。

**类型：** 综合项目
**语言：** Python（服务）、C++ / CUDA（内核检查）、YAML（配置）
**前置知识：** 阶段 3（深度学习）、阶段 7（Transformer）、阶段 10（从零构建 LLM）、阶段 17（基础设施）
**涵盖阶段：** P3 · P7 · P10 · P17
**时间：** 30 小时

## 问题

推测解码（speculative decoding）在 2026 年成为商品。EAGLE-3 草稿头在目标模型的隐藏状态上训练，并预测未来 N 个 Token；目标模型在单次传递中验证。60-80% 的接受率转化为 2-3 倍的端到端吞吐量。vLLM 0.7 原生集成了这一点。SGLang + SpecForge 为你提供训练管道。Red Hat 的 Speculators 为 Llama 3.3 70B、Qwen3-Coder-30B MoE、GPT-OSS-120B 发布了对齐草稿。

工艺在于服务运维，而非模型。接受率随流量分布（ShareGPT vs 代码 vs 领域数据）漂移。拒绝后的尾延迟比无推测时更差——你必须报告多个批量大小下的 p99，而不仅仅是稳态 tokens/秒。每百万 Token 成本 vs Anthropic / OpenAI API 是可信度杠杆。

## 概念

推测解码有两层。一个**草稿**模型（EAGLE-3 头、ngram 或较小的目标对齐模型）每步提出 k 个候选 Token。**目标**模型在一次传递中验证所有 k 个；接受的任何前缀替换贪婪路径。接受率取决于草稿-目标对齐和输入分布。

EAGLE-3 在大多数流量上优于 ngram 草稿。P-EAGLE 运行并行推测以实现更深的草稿树。权衡：拒绝时的 P99 延迟更高，因为验证传递更大。服务配置必须报告批量大小分桶延迟以暴露这一点。

部署使用 Kubernetes。vLLM 0.7 在每个 GPU 或张量并行分片上运行一个副本。HPA 根据队列等待而非 CPU 自动扩展。FP8（Marlin）和 INT4（AWQ）量化将 GPU 内存保持在 H100 / H200 范围内。端到端报告包含吞吐量、接受率、批量 1/8/32 下的 p50/p99，以及每百万 Token 美元成本。

## 架构

```
请求入口
    |
    v
vLLM 服务器（0.7）或 SGLang（0.4）
    |
    +-- 草稿：EAGLE-3 头 | P-EAGLE 并行 | ngram 备选
    +-- 目标：Llama 3.3 70B | Qwen3-Coder-30B | GPT-OSS-120B
    |     量化为 FP8-Marlin 或 INT4-AWQ
    |
    v
验证传递：将 k 个草稿 Token 批量通过目标模型
    |
    v（接受前缀；为被拒绝的后缀重采样）
    v
Token 流返回给客户端
    |
    v
Prometheus 指标：吞吐量、接受率、队列等待、延迟 p50/p99
    |
    v
基于队列等待指标的 HPA
```

## 技术栈

- 服务：vLLM 0.7 或 SGLang 0.4
- 推测方法：EAGLE-3 草稿头、P-EAGLE 并行推测、ngram 备选
- 草稿训练：SpecForge（SGLang）或 Red Hat Speculators
- 目标模型：Llama 3.3 70B、Qwen3-Coder-30B MoE、GPT-OSS-120B
- 量化：FP8（Marlin）、INT4 AWQ
- 部署：Kubernetes + NVIDIA device plugin；基于队列等待指标的 HPA
- 评估：ShareGPT、MT-Bench-v2、GSM8K、HumanEval 用于领域分布接受率测量
- 参考：TensorRT-LLM 推测解码作为供应商基线

## 构建步骤

1. **目标模型准备。** 选择 Llama 3.3 70B。通过 Marlin 量化为 FP8。在 vLLM 0.7 上部署到 1xH100（或 2x 张量并行）。

2. **草稿源。** 从 Red Hat Speculators 拉取对齐的 EAGLE-3 草稿头（或通过 SpecForge 训练一个）。加载到 vLLM 的推测解码配置中。

3. **基线数值。** 推测前：批量 1/8/32 下的 tokens/s、p50/p99 延迟、GPU 利用率。发布。

4. **启用 EAGLE-3。** 翻转配置；重新运行相同基准测试。报告加速比、接受率、p99 尾延迟差异。

5. **P-EAGLE。** 启用并行推测；衡量更深草稿树 vs 串行 EAGLE-3。报告 P-EAGLE 有利 vs 不利的拐点。

6. **领域流量。** 通过同一服务器运行 ShareGPT vs HumanEval vs 领域特定流量。衡量每个分布的接受率。识别草稿何时漂移。

7. **第二个目标模型。** 对 Qwen3-Coder-30B MoE 运行相同管道。草稿更棘手（MoE 路由噪声）。报告。

8. **K8s HPA。** 在 K8s 下部署，HPA 追踪 `queue_wait_ms`。演示负载增加三倍时的自动扩展。

9. **成本比较。** 计算每百万 Token 美元成本 vs Anthropic Claude Sonnet 4.7 和 OpenAI GPT-5.4 在同一评估上的表现。发布。

## 使用方式

```
$ curl https://infer.example.com/v1/chat/completions -d '{"messages":[...]}'
[serve]     vLLM 0.7，Llama 3.3 70B FP8，EAGLE-3 已激活
[decode]    bs=8，每步接受 Token=3.2，接受率=0.76
[latency]   首 Token 42ms，完整响应 980ms（620 tokens）
[cost]      在持续吞吐量下每百万输出 Token $0.34
```

## 交付标准

`outputs/skill-inference-server.md` 描述交付物。一个经过测量的服务栈，包含推测解码、完整的基准测试报告和 K8s 部署。

| 权重 | 标准 | 衡量方式 |
|:-:|---|---|
| 25 | 相比基线的测量加速比 | 在两个模型上匹配质量下 2.5 倍以上吞吐量 |
| 20 | 实际流量上的接受率 | 每个分布的接受率报告 |
| 20 | P99 尾延迟规范 | 有推测和无推测下 batch 1/8/32 的 p99 |
| 20 | 运维 | K8s 部署，基于队列等待的 HPA，平滑发布 |
| 15 | 报告和方法论 | 清楚解释什么发生了变化以及为什么 |
| **100** | | |

## 练习

1. 衡量当草稿比目标落后一个版本时（如 Llama 3.3 -> 3.4 漂移）的接受率退化。构建监控告警。

2. 实现 ngram 备选：如果 EAGLE-3 接受率降到阈值以下，切换到 ngram 草稿。报告可靠性改进。

3. 运行受控 MoE 实验：同一 Qwen3-Coder-30B 注入路由噪声 vs 不注入。衡量草稿接受率敏感性。

4. 扩展到 H200（141 GB）。报告每个副本获得的模型大小余量以及是否能服务未量化的 Llama 3.3 70B。

5. 在相同 H100 硬件上基准测试 TensorRT-LLM 推测解码。报告它 vs vLLM 的优势。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|------------------------|
| 草稿模型（Draft model） | "推测器（Speculator）" | 提出 N 个 Token 供目标验证的小模型 |
| EAGLE-3 | "2026 草稿架构" | 在目标隐藏状态上训练的草稿头；~75% 接受率 |
| P-EAGLE | "并行推测" | 在一次目标传递中验证的草稿分支树 |
| 接受率（Acceptance rate） | "命中率" | 被接受而无需重采样的草稿 Token 比例 |
| 量化（Quantization） | "FP8 / INT4" | 低精度权重以在 GPU 内存中容纳更多模型 |
| 队列等待（Queue wait） | "HPA 指标" | 请求在推理开始前在待处理队列中等待的时间 |
| Speculators hub | "对齐草稿" | Red Hat Neural Magic 的 EAGLE 草稿中心，用于常见开源模型 |

## 延伸阅读

- [vLLM EAGLE 和 P-EAGLE 文档](https://docs.vllm.ai) — 参考服务栈
- [P-EAGLE (AWS 2026)](https://aws.amazon.com/blogs/machine-learning/p-eagle-faster-llm-inference-with-parallel-speculative-decoding-in-vllm/) — 并行推测解码论文 + 集成
- [SGLang SpecForge](https://github.com/sgl-project/SpecForge) — 草稿头训练管道
- [Red Hat Speculators](https://github.com/neuralmagic/speculators) — 对齐草稿中心
- [TensorRT-LLM 推测解码](https://nvidia.github.io/TensorRT-LLM/) — 供应商替代方案
- [Fireworks.ai 服务架构](https://fireworks.ai/blog) — 商业参考
- [EAGLE-3 论文 (arXiv:2503.01840)](https://arxiv.org/abs/2503.01840) — 方法论文
- [vLLM 仓库](https://github.com/vllm-project/vllm) — 代码和基准测试