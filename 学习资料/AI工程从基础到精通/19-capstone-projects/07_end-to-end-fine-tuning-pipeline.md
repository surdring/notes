# 综合项目 07 — 端到端微调管道（从数据到 SFT 到 DPO 到服务）

> 一个 80 亿参数模型，用你自己的数据训练，用你自己的偏好进行 DPO 对齐，量化，推测解码，并以可衡量的每百万 Token 美元成本提供服务。2026 年的开源技术栈是 Axolotl v0.8、TRL 0.15、Unsloth 用于迭代、GPTQ/AWQ/GGUF 用于量化、vLLM 0.7 配合 EAGLE-3 用于服务。本综合项目旨在可复现地运行整个管道——YAML 输入，服务端点输出——并在 2026 年模型开放性框架（Model Openness Framework）下发布模型卡。

**类型：** 综合项目
**语言：** Python（管道）、YAML（配置）、Bash（脚本）
**前置知识：** 阶段 2（机器学习）、阶段 3（深度学习）、阶段 7（Transformer）、阶段 10（从零构建 LLM）、阶段 11（LLM 工程）、阶段 17（基础设施）、阶段 18（安全）
**涵盖阶段：** P2 · P3 · P7 · P10 · P11 · P17 · P18
**时间：** 35 小时

## 问题

2026 年，每个认真的 AI 团队都随时保留着微调管道。不是因为他们发布前沿基座模型，而是因为下游适配——领域 SFT、针对标注偏好的 DPO、用于推测解码的蒸馏草稿、配合 EAGLE-3 的服务——才是可衡量收益所在。Axolotl v0.8 处理多 GPU SFT 配置。TRL 0.15 处理 DPO 和 GRPO。Unsloth 让你快速进行单 GPU 迭代。vLLM 0.7 配合 EAGLE-3 将解码吞吐量提升 2-3 倍而不损失质量。工具能正常工作；工艺在于 YAML 文件、数据卫生和评估规范。

你将对一个 80 亿参数基座模型（Llama 3.3、Qwen3 或 Gemma 3）在任务特定数据上运行 SFT 然后再运行 DPO，进行量化以提供服务，并对照 lm-evaluation-harness、RewardBench-2、MT-Bench-v2 和 MMLU-Pro 衡量增益。你将生成一份 2026 年模型开放性框架下的模型卡。要点是可复现性——一条命令端到端重新运行整个管道。

## 概念

管道有五个阶段。**数据**：去重（MinHash / Datatrove）、质量过滤（Nemotron-CC 风格分类器）、PII 脱敏、针对公共基准测试污染的划分卫生检查。**SFT**：Axolotl YAML、ZeRO-3 在 8xH100 上、余弦调度、序列打包、2-3 个 epoch。**DPO 或 GRPO**：TRL 配置、1 个 epoch、偏好对（人工标注或模型判断）、beta 调优。**量化**：GPTQ + AWQ + GGUF 用于部署灵活性。**服务**：vLLM 0.7 配合 EAGLE-3 推测头（speculative heads）（或 SGLang 配合 SpecForge）、K8s 部署、基于队列等待的 HPA。

消融实验是交付物：在三个任务特定基准测试上的 SFT-only vs SFT+DPO vs SFT+GRPO。服务指标：batch 1/8/32 下的 tokens/s、EAGLE-3 接受率、每百万 Token 美元成本。安全评估：Llama Guard 4 通过率。模型卡：偏差评估、可复现性种子、数据许可。

## 架构

```
原始数据（HF 数据集 + 内部数据）
    |
    v
Datatrove 去重 + Nemotron-CC 质量过滤 + PII 脱敏
    |
    v
划分卫生（MMLU-Pro 污染检查）
    |
    v
Axolotl SFT 配置（YAML）  ---> 8xH100，ZeRO-3
    |
    v
TRL DPO / GRPO 配置       ---> 4xH100，1 epoch
    |
    v
GPTQ + AWQ + GGUF 量化
    |
    v
vLLM 0.7 + EAGLE-3 推测解码（speculative decoding）
    |
    v
K8s 部署，基于队列等待的 HPA
    |
    v
lm-eval-harness + RewardBench-2 + MT-Bench-v2 + MMLU-Pro
    |
    v
模型卡（2026 MOF）+ 安全评估（Llama Guard 4）
```

## 技术栈

- 数据：Datatrove 用于去重，Nemotron-CC 分类器用于质量，Presidio 用于 PII
- 基座模型：Llama 3.3 8B、Qwen3 14B 或 Gemma 3 12B
- SFT：Axolotl v0.8 配合 ZeRO-3、Flash Attention 3、序列打包
- 偏好调优：TRL 0.15 用于 DPO 或 GRPO；Unsloth 用于单 GPU 迭代
- 量化：GPTQ（Marlin）、AWQ、GGUF（通过 llama.cpp）
- 服务：vLLM 0.7 配合 EAGLE-3 推测解码（或 SGLang 0.4 + SpecForge）
- 评估：lm-evaluation-harness、RewardBench-2、MT-Bench-v2、MMLU-Pro
- 安全评估：Llama Guard 4、ShieldGemma-2
- 基础设施：Kubernetes + NVIDIA device plugin，基于队列等待指标的 HPA
- 可观测性：W&B 用于训练，Langfuse 用于推理

## 构建步骤

1. **数据管道。** 对原始语料库运行 Datatrove 去重。应用 Nemotron-CC 风格质量分类器。Presidio 脱敏 PII。用显式种子写入训练/验证划分。

2. **污染检查。** 对每个验证划分，对照 MMLU-Pro、MT-Bench-v2、RewardBench-2 测试集计算 MinHash。拒绝任何重叠。

3. **Axolotl SFT。** YAML 配置 ZeRO-3、FA3、序列打包。在 8xH100 上训练 2-3 个 epoch。日志记录到 W&B。

4. **TRL DPO / GRPO。** 取 SFT 检查点，在偏好对上运行一个 epoch 的 DPO（或对数学/代码使用 GRPO 配合可验证奖励）。扫描 beta。

5. **量化。** 生成三种量化：GPTQ-INT4-Marlin、AWQ-INT4、GGUF-Q4_K_M（用于 llama.cpp）。记录大小和标称吞吐量。

6. **使用推测解码服务。** vLLM 0.7 配置配合通过 Red Hat Speculators 训练的 EAGLE-3 草稿头。衡量 batch 1/8/32 下的接受率和尾延迟。在同一评估上报告每百万 Token 美元成本 vs Anthropic / OpenAI。

7. **评估矩阵。** 在基座、SFT-only、SFT+DPO、SFT+GRPO 上运行 lm-eval-harness、RewardBench-2、MT-Bench-v2、MMLU-Pro。生成表格。

8. **安全评估。** 在开发集上的 Llama Guard 4 通过率。ShieldGemma-2 输出过滤器。

9. **模型卡。** MOF 2026 模板：数据、训练、评估、安全、许可、带 YAML 和提交 SHA 的可复现性章节。

## 使用方式

```
$ ./pipeline.sh config/llama3.3-8b-domainX.yaml
[data]    30 万条去重，1.2 万条过滤，28 万条接受（种子=7）
[SFT]     3 epochs，8xH100，6h12m，验证损失 1.42 -> 1.03
[DPO]     1 epoch，beta=0.08，4xH100，1h40m
[quant]   GPTQ-INT4 4.6 GB，AWQ-INT4 4.8 GB，GGUF-Q4_K_M 5.1 GB
[serve]   vLLM 0.7，EAGLE-3 接受率 0.74，p99 126ms @ bs=8
[eval]    MMLU-Pro +3.2，MT-Bench-v2 +0.41，RewardBench-2 +0.08
[card]    model-card.md 已按 2026 MOF 生成
```

## 交付标准

`outputs/skill-finetuning-pipeline.md` 描述交付物。一条命令运行数据 -> SFT -> DPO -> 量化 -> 服务 -> 评估，并生成模型卡 + 服务端点。

| 权重 | 标准 | 衡量方式 |
|:-:|---|---|
| 25 | 相比基座的评估差异 | 目标任务的测量增益（MMLU-Pro、MT-Bench-v2、任务特定） |
| 20 | 管道可复现性 | 一条命令使用相同种子端到端重新运行 |
| 20 | 数据卫生 | 去重率、PII 脱敏覆盖、污染检查通过 |
| 20 | 服务效率 | bs=1/8/32 下的 tokens/s、EAGLE-3 接受率、每百万 Token 美元成本 |
| 15 | 模型卡 + 安全评估 | 2026 MOF 完整性 + Llama Guard 4 通过率 |
| **100** | | |

## 练习

1. 在同一任务特定基准测试上运行 SFT-only vs SFT+DPO vs SFT+GRPO。报告哪种偏好方法胜出以及优势有多大。

2. 将 Llama 3.3 8B 替换为 Qwen3 14B。在匹配质量下衡量每百万 Token 美元成本。

3. 衡量 EAGLE-3 在领域数据上 vs 通用 ShareGPT 上的接受率。报告差异及其对延迟预算的意义。

4. 注入 1% 的污染（将 MMLU-Pro 答案泄露到训练数据中）并重新运行评估。观察 MMLU-Pro 准确性不切实际地跳跃。构建一个能捕获此问题的污染检查 CI 闸门。

5. 添加 LoRA SFT 作为完整微调的替代方案。在以 10 倍更低内存运行的情况下衡量质量差距。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|------------------------|
| Axolotl | "SFT 训练器" | 统一的 YAML 驱动训练器，用于 SFT、DPO 和蒸馏 |
| TRL | "偏好调优器" | Hugging Face 库，用于 LLM 上的 DPO、GRPO、PPO |
| GRPO | "组相对策略优化（Group-relative policy optimization）" | DeepSeek R1 的 RL 配方，使用可验证奖励 |
| EAGLE-3 | "推测解码草稿" | 预测未来 N 个 token 的草稿头；vLLM 用目标模型验证 |
| MOF | "模型开放性框架（Model Openness Framework）" | 2026 年对模型发布按数据、代码、许可进行评级的标准化框架 |
| 污染检查（Contamination check） | "划分卫生" | 基于 MinHash 的测试集泄露到训练数据的检测 |
| 接受率（Acceptance rate） | "EAGLE / MTP 指标" | 目标模型接受的草稿 token 比例 |

## 延伸阅读

- [Axolotl 文档](https://axolotl-ai-cloud.github.io/axolotl/) — 参考 SFT / DPO 训练器
- [TRL 文档](https://huggingface.co/docs/trl) — DPO 和 GRPO 参考实现
- [Unsloth](https://github.com/unslothai/unsloth) — 单 GPU 迭代参考
- [DeepSeek R1 论文 (arXiv:2501.12948)](https://arxiv.org/abs/2501.12948) — GRPO 方法论
- [vLLM + EAGLE-3 文档](https://docs.vllm.ai) — 参考服务技术栈
- [SGLang SpecForge](https://github.com/sgl-project/SpecForge) — 替代推测解码训练器
- [Model Openness Framework 2026](https://isocpp.org/) — 开放发布评级标准
- [lm-evaluation-harness](https://github.com/EleutherAI/lm-evaluation-harness) — 规范评估运行器