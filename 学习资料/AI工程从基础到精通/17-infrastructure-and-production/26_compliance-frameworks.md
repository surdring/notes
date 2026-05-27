# 合规 — SOC 2、HIPAA、GDPR、PCI-DSS、EU AI Act、ISO 42001

> 多框架覆盖是 2026 年企业交易的基本要求。**EU AI Act**（欧盟人工智能法案）：自 2024 年 8 月 1 日生效。大多数高风险要求于 2026 年 8 月 2 日强制执行。高风险系统义务违反罚款高达 €15M 或全球年营业额的 3%（Art. 99(4)）；禁止的 AI 实践罚款高达 €35M 或 7%（Art. 99(3)）。如果服务欧盟用户则全球适用。**Colorado AI Act**（科罗拉多州人工智能法案）：2026 年 6 月 30 日生效（由 SB25B-004 从 2026 年 2 月推迟）——高风险系统影响评估、上诉 AI 决策的权利。弗吉尼亚州类似，覆盖信用/就业/住房/教育。**SOC 2 Type II**：事实上的 B2B AI 要求（Type II 而非 Type I，用于金融科技）。**GDPR**：最大记录的 AI 特定罚款为 Clearview AI 的 €30.5M（荷兰 DPA，2024 年 9 月）；意大利 Garante 在 2024 年 12 月对 OpenAI 罚款 €15M（2026 年 3 月上诉推翻）。推理时实时 PII 编辑是可辩护的标准；后处理清理不够。**HIPAA**：医疗健康绑定——没有 BAA 不能将 PHI 发送到外部 AI 服务。**PCI-DSS**：AI 交互层覆盖需要配置 + 合同协议，非自动。**ISO 42001**：新兴的 AI 治理标准，与 ISO 27001 并列，日益成为采购要求。参考画像：OpenAI 维持 SOC 2 Type 2、ISO/IEC 27001:2022、ISO/IEC 27701:2019、GDPR/CCPA/HIPAA (BAA)/FERPA、ChatGPT 支付组件的 PCI-DSS。跨框架映射减少审计疲劳：访问控制映射到 ISO 27001 A.5.15-5.18、GDPR Art. 32、HIPAA §164.312(a)。

**类型：** 学习
**语言：** （Python 可选——合规是策略 + 流程，非代码）
**前置知识：** 第 17 阶段 · 25（安全），第 17 阶段 · 13（可观测性）
**时间：** 约 60 分钟

## 学习目标

- 列举与 LLM 产品相关的七个 2026 年框架，并将每个框架与客户细分匹配。
- 引用 EU AI Act 执法时间线（2024 年 8 月生效；高风险执法 2026 年 8 月）和两级罚款上限（高风险义务 €15M / 3%；禁止实践 €35M / 7%）。
- 解释为什么后处理 PII 清理对 GDPR 不够，并指出实时推理层编辑是可辩护的标准。
- 描述跨框架控制映射（例如，访问控制映射到 ISO 27001 A.5.15-5.18 + GDPR Art. 32 + HIPAA §164.312(a)）。

## 问题

一个企业客户的采购要求 SOC 2 Type II、GDPR、HIPAA BAA、ISO 27001 和"EU AI Act 合规声明"。你的团队有 SOC 2 Type I。你距离 Type II 还有六个月，还没有开始 GDPR Article 30 记录。

多框架覆盖不是 LLM 问题——它是企业 SaaS 问题，带有 LLM 特定的叠加层。2026 年的采购团队想要的是一个矩阵：每一行对应一个框架，每一列对应一个控制项，而不是一个 PDF。

## 概念

### 七大框架

| 框架 | 范围 | LLM 特定要求 |
|-----------|-------|--------------------------|
| SOC 2 Type II | B2B SaaS 基线 | 在 6-12 个月内审计的过程控制 |
| HIPAA | 美国医疗 | 需要 BAA；PHI 不能在无签署协议的情况下离开基础设施 |
| GDPR | 欧盟用户 | 实时 PII 编辑；数据主体权利；Article 30 记录 |
| PCI-DSS | 支付数据 | 涉及支付的 AI 的配置 + 合同 |
| EU AI Act | 服务欧盟用户 | 风险等级分类；高风险系统：合规评估、文档、日志记录 |
| Colorado AI Act | 服务科罗拉多州居民 | 影响评估；上诉权利 |
| ISO 42001 | AI 治理 | 新兴；与 ISO 27001 搭配 |

### EU AI Act 时间线

- 2024 年 8 月 1 日：生效。
- 2025 年 2 月 2 日：禁止的 AI 实践执法。
- 2026 年 8 月 2 日：高风险系统执法（合规评估、文档、日志记录）。
- 2027 年 8 月：协调立法下的产品中的高风险系统。

风险等级：不可接受（禁止）、高风险（合规检查 + 日志）、有限风险（透明度）、最小风险（无约束）。大多数 B2B LLM SaaS 是有限风险；高风险适用于就业、信用、教育、执法、移民、基本服务。

罚款（Article 99）：违反高风险系统义务最高 €15M 或全球年营业额的 3%（Art. 99(4)）；禁止的 AI 实践最高 €35M 或 7%（Art. 99(3)）；取较高者。

### GDPR — 实时编辑是标准

后处理清理（在 LLM 看到 PII 后再编辑）不是可辩护的姿态——模型已经看到了数据。推理层实时编辑是 2026 年的标准：

- LLM 调用前的实体识别。
- 一致性分词化（Mesh 方法）保留语义。
- 仅存储编辑后的提示词 + 同意选择性入的原始内容。

最近的执法：Clearview AI 的 €30.5M（荷兰 DPA，2024 年 9 月）是迄今最大记录的 AI 特定 GDPR 罚款；OpenAI 的 €15M（意大利 Garante，2024 年 12 月）是最大 LLM 特定罚款，但于 2026 年 3 月上诉推翻，该裁决仍在进一步审查中。后处理声明在审计中已失败。

### HIPAA — BAA 不是可选的

你不能在没有签署业务伙伴协议（BAA）的情况下将 PHI 发送到外部 AI 服务。所有三个超大规模 LLM 平台（Bedrock、Azure OpenAI、Vertex）提供 BAA。OpenAI 直接 API 提供 BAA。Anthropic 直接 API 提供 BAA。发送 PHI 前确认。

### SOC 2 Type II

Type I：控制项已设计和记录。
Type II：控制项在 6-12 个月内有效运作。

2026 年 B2B 采购默认要求 Type II。Type I 是入门；Type II 是门槛。

常见审计驱动因素：访问日志（谁看了什么）、变更管理（如何部署）、风险评估（每季度）、事件响应（测试过吗？）。来自第 17 阶段 · 25 的审计日志可直接复用。

### 跨框架映射

一个访问控制策略满足多个框架控制项：

| 控制项 | 框架 |
|---------|-----------|
| 访问日志 | ISO 27001 A.5.15-5.18、GDPR Art. 32、HIPAA §164.312(a) |
| 变更管理 | ISO 27001 A.8.32、PCI DSS Req. 6、HIPAA 违规通知范围 |
| 传输加密 | ISO 27001 A.8.24、GDPR Art. 32、HIPAA §164.312(e) |
| 密钥管理 | ISO 27001 A.8.19、PCI DSS Req. 8、SOC 2 CC6.1 |

合规工具（Drata、Vanta、Secureframe）自动化此映射。达到规模时物有所值。

### ISO 42001 — 新兴

2023 年底发布。与 ISO 27001 并列，日益成为采购要求。AI 治理框架，包括风险管理、数据质量、透明度、人类监督。

### OpenAI 的参考画像

OpenAI 维持 SOC 2 Type 2、ISO/IEC 27001:2022、ISO/IEC 27701:2019、GDPR/CCPA/HIPAA (BAA)/FERPA、ChatGPT 支付组件的 PCI-DSS。这大致是 2026 年的企业基本要求。

### 应记住的数字

- EU AI Act 罚款：最高 €15M / 3%（高风险义务，Art. 99(4)）；最高 €35M / 7%（禁止实践，Art. 99(3)）。
- EU AI Act 高风险执法：2026 年 8 月 2 日。
- 最大记录的 AI 特定 GDPR 罚款：€30.5M，Clearview AI（荷兰 DPA，2024 年 9 月）。
- 最大 LLM 特定 GDPR 罚款：€15M，OpenAI（意大利 Garante，2024 年 12 月；2026 年 3 月上诉推翻）。
- SOC 2 Type II 窗口：6-12 个月的受控操作。
- Colorado AI Act 生效日期：2026 年 6 月 30 日（由 SB25B-004 从 2026 年 2 月推迟）。

## 使用它

`code/main.py` 是 Python 中的合规映射电子表格——给定一个控制项，列出它满足的框架。

## 交付它

本课生成 `outputs/skill-compliance-matrix.md`。根据客户细分和地理位置，指定所需的框架和控制项。

## 练习

1. 你的第一个企业客户要求 SOC 2 Type II、HIPAA BAA、EU AI Act 声明。赢得交易的最小可行合规姿态是什么？
2. 根据 EU AI Act 风险等级对三个假设的 LLM 产品进行分类。高风险时有什么变化？
3. 你意外将 PHI 发送到没有 BAA 的供应商。走一遍事件响应流程。
4. 论证 ISO 42001 在 2026 年对中型 AI 供应商是否"必要"。
5. 将你的 LLM 审计日志字段（第 17 阶段 · 25）映射到至少三个框架控制项。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|----------------|------------------------|
| SOC 2 Type II | "审计控制" | 6-12 个月运行的控制项，独立认证 |
| HIPAA BAA | "医疗合同" | 业务伙伴协议；PHI 必需 |
| GDPR | "欧盟隐私" | 实时 PII 编辑是 2026 年可辩护的标准 |
| EU AI Act | "欧盟 AI 规则" | 高风险执法 2026 年 8 月；€15M / 3%（高风险义务）— €35M / 7%（禁止实践） |
| Colorado AI Act | "美国 AI 州法" | 2026 年 6 月 30 日生效（SB25B-004 推迟）；影响评估 |
| ISO 42001 | "AI 治理" | 新兴的 AI 风险 + 透明度框架 |
| ISO 27001 | "安全 ISMS" | 信息安全管理体系基线 |
| Conformity assessment | "EU AI 文档包" | 高风险要求：文档、测试、日志 |
| Cross-framework mapping | "一个控制项，多个框架" | 单一策略满足多个框架控制项 |

## 延伸阅读

- [OpenAI Security and Privacy](https://openai.com/security-and-privacy/) — 参考合规画像。
- [GuardionAI — LLM Compliance 2026: ISO 42001, EU AI Act, SOC 2, GDPR](https://guardion.ai/blog/llm-compliance-guide-iso-42001-eu-ai-act-soc2-gdpr-2026)
- [Dsalta — SOC 2 Type 2 Audit Guide 2026: 10 AI Controls](https://www.dsalta.com/resources/ai-compliance/soc-2-type-2-audit-guide-2026-10-ai-powered-controls-every-saas-team-needs)
- [EU AI Act official text](https://eur-lex.europa.eu/eli/reg/2024/1689/oj) — 主要来源。
- [Colorado AI Act](https://leg.colorado.gov/bills/sb24-205) — 主要来源。
- [ISO/IEC 42001:2023](https://www.iso.org/standard/81230.html) — AI 管理体系标准。