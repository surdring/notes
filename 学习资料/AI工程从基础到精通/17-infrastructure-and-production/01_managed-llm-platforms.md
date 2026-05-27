# 托管 LLM 平台 —— Bedrock、Vertex AI、Azure OpenAI

> 三个超大规模云厂商，三种不同的策略。AWS Bedrock 是一个模型市场——Claude、Llama、Titan、Stability、Cohere 在同一个 API 后面。Azure OpenAI 是独家 OpenAI 合作伙伴关系加上用于专用容量的预置吞吐量单元（Provisioned Throughput Units，PTU）。Vertex AI 以 Gemini 优先，拥有最好的长上下文和多模态故事。2026 年 Artificial Analysis 测量 Azure OpenAI 在 Llama 3.1 405B 等效模型上的中位延迟约 50 ms，Bedrock 约 75 ms——PTU 解释了这种差距，因为专用容量优于共享按需。决策规则不是"哪个最快"，而是"哪个模型目录和 FinOps 界面匹配我的产品"。本课教你用写下来的权衡做选择，而非凭感觉。

**类型：** 学习
**语言：** Python（标准库，玩具级成本和延迟比较器）
**前置条件：** Phase 11（LLM 工程）、Phase 13（工具与协议）
**时间：** ~60 分钟

## 学习目标

- 说出三种平台策略（市场 vs 独家 vs Gemini 优先）并分别匹配到产品用例。
- 解释 Azure OpenAI 中的预置吞吐量单元（PTU）为你带来什么，以及为什么按需 Bedrock 在 405B 规模下通常读取慢约 25 ms。
- 绘制每个平台的 FinOps 归因表面（Bedrock Application Inference Profiles vs Vertex 每团队项目 vs Azure 范围 + PTU 预留）。
- 写下"双供应商最低要求"策略，并解释为什么单供应商锁定是 2026 年代价高昂的错误。

## 问题

你为产品选择了 Claude 3.7 Sonnet。现在你需要提供服务。你可以直接调用 Anthropic API，也可以通过 AWS Bedrock 调用，或者通过网关。直接 API 最简单；Bedrock 增加了 BAA、VPC 端点、IAM 和 CloudWatch 归因。网关增加了故障转移、统一计费和跨供应商的速率限制。

更深层的问题是目录。如果你需要 Claude、Llama 和 Gemini 在同一个产品中，你无法从一个地方购买全部，除非那个地方同时是 Bedrock 加 Vertex 加 Azure OpenAI。超大规模云厂商不可互换——它们各自对谁拥有模型层下了不同的赌注。

本课映射这三种赌注、延迟差距、FinOps 差距和锁定风险。

## 概念

### 三种策略

**AWS Bedrock**——市场。Claude（Anthropic）、Llama（Meta）、Titan（AWS 第一方）、Stability（图像）、Cohere（嵌入）、Mistral，加上图像和嵌入子目录。一个 API、一个 IAM 界面、一个 CloudWatch 导出。Bedrock 的赌注是客户更需要可选性而非单一模型。

**Azure OpenAI**——独家合作伙伴关系。你在 Azure 数据中心获得 GPT-4 / 4o / 5 / o-series、DALL·E、Whisper 和 OpenAI 模型的微调。"Azure OpenAI 服务"目录中无非 OpenAI 模型——那些归入 Azure AI Foundry（单独产品）。Azure 的赌注是 OpenAI 保持前沿地位，客户需要对该特定关系的企业级控制。

**Vertex AI**——Gemini 优先，其他其次。Gemini 1.5 / 2.0 / 2.5 Flash 和 Pro，加上 Model Garden（第三方）。Vertex 的赌注是多模态长上下文——1M Token 的 Gemini 上下文是差异化因素。

### 大规模下的延迟差距

Artificial Analysis 运行持续基准测试。在等效 Llama 3.1 405B 部署上（共享按需），Azure OpenAI 中位首 Token 延迟约为 50 ms；Bedrock 约为 75 ms。差距不是 AWS 的失败——而是容量模型的差异。Azure 销售 PTU（预置吞吐量单元），为你的租户预留 GPU 容量。Bedrock 的等价物（预置吞吐量，Provisioned Throughput）存在但起步约 $21/小时每单元，大多数客户保持在共享按需上。

按需共享容量与每个其他客户的流量竞争。专用容量则不会。如果你的产品 SLA 是 TTFT < 100 ms P99，你要么在 Azure 上购买 PTU，要么购买 Bedrock 预置吞吐量，要么接受默认方差。

### 预置吞吐量经济学

Azure PTU：一块预留的推理计算。相比按需可节省高达约 70%，适用于可预测工作负载。每小时固定成本，无论流量——即使空闲也要为预留付费。盈亏平衡点通常在约 40-60% 的持续利用率。

Bedrock 预置吞吐量：$21-$50/小时，取决于模型和区域。类似的计算——盈亏平衡点约在峰值利用率的一半。需要月度承诺。

Vertex 预置容量按 Gemini SKU 销售；定价因模型和区域而异，公开宣传较少。

### FinOps 界面——真正的差异化因素

**Bedrock Application Inference Profiles** 是市场上最干净的归因。用 `team`、`product`、`feature` 标记一个配置文件；将所有模型调用路由通过它；CloudWatch 无需后处理即可按配置文件拆分成本。2025 年新增，仍然是最细粒度的超大规模原生方案。

**Vertex** 归因是每团队项目加标签全覆盖。你将每个团队建模为一个 GCP 项目，在每个资源上打标签，并使用 BigQuery Billing Export + DataStudio 进行汇总。工作量更大，但 BigQuery 使你能对成本数据运行任意 SQL。

**Azure** 依赖订阅/资源组范围加标签，PTU 预留作为一等成本对象。标签从资源组继承，而非请求级，因此每请求归因需要 Application Insights 自定义指标或一个能加盖头部的网关。

模式：Bedrock 是最干净的原生方案，Vertex 通过 BigQuery 最灵活，Azure 最不透明除非你进行仪表化。

### 锁定是 2026 年的风险

当一个模型占主导地位时，单超大规模承诺是可以的。2026 年前沿每月移动——一个季度是 Claude 3.7，下一个季度是 Gemini 2.5，再下一个是 GPT-5。锁定到一个平台会将你排除在三分之二的前沿之外。

有效团队采用的模式：对任何产品关键的 LLM 调用采用双供应商最低要求。Bedrock 加 Azure OpenAI 是常见的组合——一个提供 Claude，另一个提供 GPT，之间故障转移，同一个网关。成本增量可忽略，因为网关路由选择最优方案；可用性增量在宕机期间（如 Azure OpenAI 2025 年 1 月事件、AWS us-east-1 宕机）是决定性的。

### 数据驻留、BAA 和受监管行业

Bedrock：大多数区域提供 BAA；VPC 端点；护栏。常见的金融科技默认选择。
Azure OpenAI：HIPAA、SOC 2、ISO 27001；欧盟数据驻留；企业受监管的默认选择。
Vertex：HIPAA、GDPR、按区域数据驻留；Google Cloud 的合规栈。

三者都满足基本检查项。差异在于数据保留策略、日志处理方式以及滥用监控是否读取你的流量（大多数默认选择加入；企业可退出）。

### 你应该记住的数字

- Azure OpenAI 在 Llama 3.1 405B 等效模型上的中位 TTFT：~50 ms（使用 PTU）。
- Bedrock 按需中位 TTFT：~75 ms。
- Bedrock 预置吞吐量：$21-$50/hr 每单元。
- Azure PTU 盈亏平衡点：~40-60% 持续利用率。
- PTU 在高利用率下相比按需的节省：高达 70%。

## 使用它

`code/main.py` 在合成工作负载上比较三个平台——它建模按需 vs PTU 经济学、TTFT 方差和成本归因保真度。运行它以查看 PTU 在何处产生回报，以及市场的模型广度在何处抵消了 TTFT 差距。

## 交付它

本课产出 `outputs/skill-managed-platform-picker.md`。给定工作负载配置文件（所需模型、TTFT SLA、日交易量、合规要求），它推荐一个主平台、一个备用平台和一个 FinOps 仪表化计划。

## 练习

1. 运行 `code/main.py`。在什么持续利用率下 Azure PTU 对 70B 级别模型优于按需？计算盈亏平衡点并与宣传的 40-60% 区间比较。
2. 你的产品需要 Claude 3.7 Sonnet 和 GPT-4o。设计一个双供应商部署——哪个去哪个超大规模云厂商，前面放什么网关，故障转移策略是什么？
3. 一个受监管的医疗客户需要 BAA、美国东部数据驻留和低于 100ms P99 TTFT。选择一个平台并用三个具体功能进行论证。
4. 你发现你的 Bedrock 账单本月上涨了 4 倍，但流量未变。没有 Application Inference Profiles，你如何找到罪魁祸首？使用 Profiles 需要多长时间？
5. 阅读 Azure OpenAI 和 Bedrock 定价页面。对于每月 1 亿 Token 的 Claude 工作负载，哪种更便宜——直接 Anthropic API、Bedrock 按需还是 Bedrock 预置吞吐量？

## 关键术语

| 术语 | 人们的说法 | 实际含义 |
|------|----------------|------------------------|
| Bedrock | "AWS LLM 服务" | 跨 Claude、Llama、Titan、Mistral、Cohere 的模型市场 |
| Azure OpenAI | "Azure 的 ChatGPT" | Azure 数据中心中独家的 OpenAI 模型，带企业控制 |
| Vertex AI | "Google 的 LLM" | Gemini 优先平台，附 Model Garden 提供第三方模型 |
| PTU | "专用容量" | 预置吞吐量单元——预留的推理 GPU，按小时定价 |
| Application Inference Profile | "Bedrock 标签" | 带标签的每产品成本/使用配置文件，CloudWatch 原生 |
| Model Garden | "Vertex 目录" | Vertex AI 的第三方模型部分，与 Gemini 分离 |
| 双供应商最低要求 | "LLM 冗余" | 将每个关键 LLM 路径运行在 ≥2 个超大规模云厂商上的策略 |
| BAA | "HIPAA 文书" | 业务伙伴协议；处理 PHI 所需；三者都提供 |
| 滥用监控 | "日志观察者" | 供应商对提示/输出的安全扫描；企业可退出 |

## 扩展阅读

- [AWS Bedrock 定价](https://aws.amazon.com/bedrock/pricing/) —— 权威费率卡和预置吞吐量定价。
- [Azure OpenAI 服务定价](https://azure.microsoft.com/en-us/pricing/details/cognitive-services/openai-service/) —— PTU 经济学和费率卡。
- [Vertex AI 生成式 AI 定价](https://cloud.google.com/vertex-ai/generative-ai/pricing) —— Gemini 层级和 Model Garden 附加费。
- [Artificial Analysis LLM 排行榜](https://artificialanalysis.ai/) —— 跨供应商的持续延迟和吞吐量基准。
- [The AI Journal — AWS Bedrock vs Azure OpenAI CTO Guide 2026](https://theaijournal.co/2026/03/aws-bedrock-vs-azure-openai/) —— 企业决策框架。
- [Finout — Bedrock vs Vertex vs Azure FinOps](https://www.finout.io/blog/bedrock-vs.-vertex-vs.-azure-cognitive-a-finops-comparison-for-ai-spend) —— 并排归因机制。