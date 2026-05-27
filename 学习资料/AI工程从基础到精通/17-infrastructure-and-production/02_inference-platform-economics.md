# 推理平台经济学 —— Fireworks、Together、Baseten、Modal、Replicate、Anyscale

> 2026 年的推理市场不再是 GPU 时间租赁。它分化为定制芯片（Groq、Cerebras、SambaNova）、GPU 平台（Baseten、Together、Fireworks、Modal）和 API 优先市场（Replicate、DeepInfra）。Fireworks 于 2026 年 5 月 1 日将价格提高 $1/小时/GPU，$40 亿估值和每天 10T+ Token 的处理量说明了数量驱动模型是有效的。Baseten 于 2026 年 1 月以 $50 亿估值完成了 $3 亿的 E 轮融资。竞争定位规则很简单：Fireworks 优化延迟，Together 优化目录广度，Baseten 优化企业精致度，Modal 优化 Python 原生开发体验，Replicate 优化多模态覆盖范围，Anyscale 优化分布式 Python。本课给你一个可以直接交给创始人的矩阵。

**类型：** 学习
**语言：** Python（标准库，玩具级每次调用经济学比较器）
**前置条件：** Phase 17 · 01（托管 LLM 平台）、Phase 17 · 04（vLLM 推理内部）
**时间：** ~60 分钟

## 学习目标

- 说出三个市场细分（定制芯片、GPU 平台、API 优先）并将每个供应商映射到一个细分。
- 解释为什么"每 Token" API 定价模型向推理引擎的成本曲线压缩，而非向硬件成本曲线。
- 计算至少三个供应商的每次请求有效成本，并解释何时每分钟（Baseten、Modal）优于每 Token。
- 确定哪个平台是给定工作负载的正确默认选择（无服务器突发、稳定高吞吐量、微调变体、多模态）。

## 问题

你评估了托管超大规模平台。你决定需要一个更窄、更快的供应商——Fireworks 做延迟，Together 做广度，Baseten 做微调自定义模型。现在你有六个真实选择，但定价页面并不对齐。Fireworks 显示 $/M tokens；Baseten 显示 $/分钟；Modal 显示 $/秒；Replicate 显示 $/预测。不建模工作负载就无法头对头比较它们。

更糟的是，每个定价页面背后的商业模式不同。Fireworks 在共享 GPU 上运行自己的自定义引擎（FireAttention）；每 Token 费率反映其利用率曲线。Baseten 给你 Truss + 专用 GPU；每分钟反映独占性。Modal 是真正的 Python 无服务器——每秒计费，亚秒级冷启动。相同的输出（LLM 响应），三种不同的成本函数。

本课对六个进行建模，并告诉你每种情况下的最佳选择。

## 概念

### 三个细分

**定制芯片**——Groq（LPU）、Cerebras（WSE）、SambaNova（RDU）。通常比基于 GPU 的集群在相同模型上快 5-10 倍解码。每 Token 价格更高（Groq 在 2025 年末 Llama-70B 上约 $0.99/M），但对延迟敏感的场景无与伦比。Groq 是语音代理和实时翻译的生产选择。

**GPU 平台**——Baseten、Together、Fireworks、Modal、Anyscale。运行在 NVIDIA（2026 年为 H100、H200、B200）或有时 AMD 上。"原始 GPU 租赁"（RunPod、Lambda）和"超大规模托管服务"（Bedrock）之间的经济层。

**API 优先市场**——Replicate、DeepInfra、OpenRouter、Fal。广泛的目录，按预测或按秒付费，强调首次调用时间。

### Fireworks——延迟优化的 GPU 平台

- FireAttention 引擎（自定义）；宣传比等效配置下 vLLM 延迟低 4 倍。
- 批处理层级约为无服务器费率的 50%，适用于非交互工作负载。
- 微调模型以与基座模型相同的费率提供服务——相对于对 LoRA 收取溢价的供应商来说，这是一个真正的差异化因素。
- 2026 年中：2026 年 5 月 1 日生效，按需 GPU 租赁上调 $1/小时。大规模下可协商批量定价。
- 财务信号：$40 亿估值，每天处理 10T+ Token。

### Together——广度优化

- 200+ 模型，包括上游发布后数天内的开源版本。
- 比 Replicate 在等效 LLM 模型上便宜 50-70%——"AI 原生云"定位是数量和目录。
- 推理 + 微调 + 训练在一个 API 中。

### Baseten——企业精致度优化

- Truss 框架：模型打包，依赖项、密钥、推理配置在一个清单中。
- GPU 范围从 T4 到 B200。每分钟计费，具有合理的冷启动缓解。
- SOC 2 Type II，HIPAA 就绪。常见的金融科技和医疗选择。
- $50 亿估值，2026 年 1 月 E 轮（来自 CapitalG、IVP、NVIDIA 的 $3 亿）。

### Modal——Python 原生优化

- 纯 Python 的基础设施即代码。用 `@modal.function(gpu="A100")` 装饰一个函数，一条命令部署。
- 每秒计费。预热后冷启动 2-4 秒；小型模型 <1 秒。
- $8700 万 B 轮，$11 亿估值（2025 年）。独立调查中最强的开发者体验评分。

### Replicate——多模态广度

- 按预测付费。图像、视频和音频模型的默认平台。
- 集成生态系统（Zapier、Vercel、CMS 插件）。
- LLM 每 Token 费率竞争力较低，但在多模态多样性上胜出。

### Anyscale——Ray 原生

- 基于 Ray 构建；RayTurbo 是 Anyscale 的专有推理引擎（与 vLLM 竞争）。
- 最适合分布式 Python 工作负载，其中推理步骤是更大图中的一个节点。
- 托管 Ray 集群；与 Ray AIR 和 Ray Serve 紧密集成。

### 每 Token vs 每分钟——何时各自胜出

每 Token 在工作负载延迟不敏感且突发时合理——只为你使用的付费。每分钟在利用率高且可预测时合理——一旦你充分利用 GPU，就能击败每 Token。

粗略规则：对于持续利用率约 30% 以上的工作负载，每分钟（Baseten、Modal）开始击败每 Token（Fireworks、Together）。低于此值，每 Token 胜出，因为你避免了为空闲付费。

### 自定义引擎是真正的护城河

每个 vLLM 和 SGLang 之上的平台都声称有自定义引擎。FireAttention、RayTurbo、Baseten 的推理栈。自定义引擎的声明带有营销色彩——诚实的框架是 vLLM + SGLang 代表了约 80% 的生产级开源推理，平台层的差异化因素是 DX、归因和 SLA。

### 你应该记住的数字

- Fireworks GPU 租赁：2026 年 5 月 1 日生效上调 $1/hr。
- Fireworks 声明：比等效配置下 vLLM 延迟低 4 倍。
- Together：比 Replicate 在 LLM 上便宜 50-70%。
- Baseten 估值：$50 亿（E 轮，2026 年 1 月，$3 亿轮）。
- Modal 估值：$11 亿（B 轮，2025 年）。
- 每分钟在约 30% 持续利用率以上击败每 Token。

## 使用它

`code/main.py` 在合成工作负载上跨定价模型比较六个供应商。报告 $/天和有效 $/M tokens。运行它以找到每 Token 和每分钟之间的盈亏平衡点。

## 交付它

本课产出 `outputs/skill-inference-platform-picker.md`。给定工作负载配置文件、SLA 和预算，选择主推理平台并指定次选。

## 练习

1. 运行 `code/main.py`。在什么持续利用率下 Baseten（每分钟）在一个 H100 上的 70B 模型击败 Fireworks（每 Token）？自行推导交叉点并与经验法则比较。
2. 你的产品提供图像生成加聊天加语音转文本。为每种模态选择平台，并命名统一它们的网关模式。
3. Fireworks 将你的主模型价格上调 $1/hr。如果 40% 的流量转移到批处理层级（50% 折扣），建模混合成本影响。
4. 一个受监管客户需要 SOC 2 Type II + HIPAA + 专用 GPU。哪三个平台是可行的，哪个在 FinOps 上胜出？
5. 比较 Llama 3.1 70B 在 Fireworks 无服务器、Together 按需、Baseten 专用和 Replicate API 上的每 1000 次预测成本。每天 10 次预测哪种最便宜？10000 次呢？

## 关键术语

| 术语 | 人们的说法 | 实际含义 |
|------|----------------|------------------------|
| 定制芯片 | "非 GPU 芯片" | Groq LPU、Cerebras WSE、SambaNova RDU——为解码优化 |
| FireAttention | "Fireworks 引擎" | 自定义注意力内核；宣传比 vLLM 延迟低 4 倍 |
| Truss | "Baseten 的格式" | 模型打包清单；依赖项 + 密钥 + 推理配置 |
| 每 Token | "API 定价" | 按消耗的 Token 收费；不为空闲付费 |
| 每分钟 | "专用定价" | 按墙钟 GPU 时间收费；高利用率时获胜 |
| 每预测 | "Replicate 定价" | 按模型调用收费；图像/视频常用 |
| RayTurbo | "Anyscale 引擎" | Ray 上的专有推理；在 Ray 集群上与 vLLM 竞争 |
| 批处理层级 | "50% 折扣" | 降低费率的非交互队列；Fireworks、OpenAI 上常见 |
| 微调以基座费率 | "Fireworks LoRA" | 以基座模型费率对 LoRA 推理请求收费（差异化因素） |

## 扩展阅读

- [Fireworks 定价](https://fireworks.ai/pricing) —— 每 Token 费率、批处理层级、GPU 租赁。
- [Baseten 定价](https://www.baseten.co/pricing/) —— 每分钟费率、承诺容量、企业层级。
- [Modal 定价](https://modal.com/pricing) —— 每秒 GPU 费率和免费层级。
- [Together AI 定价](https://www.together.ai/pricing) —— 模型目录和每 Token 费率。
- [Anyscale 定价](https://www.anyscale.com/pricing) —— RayTurbo 和托管 Ray 定价。
- [Northflank — Fireworks AI 替代方案](https://northflank.com/blog/7-best-fireworks-ai-alternatives-for-inference) —— 比较评估。
- [Infrabase — 2026 年 AI 推理 API 供应商](https://infrabase.ai/blog/ai-inference-api-providers-compared) —— 供应商格局。