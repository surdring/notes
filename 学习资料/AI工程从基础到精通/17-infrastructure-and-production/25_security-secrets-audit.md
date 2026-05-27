# 安全 — 密钥、API Key 轮换、审计日志、护栏

> 通过集中化保险库消除密钥蔓延（HashiCorp Vault、AWS Secrets Manager、Azure Key Vault）。永远不要在配置文件、版本控制中的 env 文件、电子表格中存储凭据。使用 IAM 角色而非静态密钥；CI/CD 使用 OIDC。AI 网关模式是 2026 年的解决方案：应用 → 网关 → 模型供应商，网关在运行时从保险库拉取凭据。在保险库中轮换，所有应用在几分钟内获取新密钥——无需重新部署，无需 Slack 上问"谁有新的 key"。轮换策略 ≤ 90 天；每次提交用 TruffleHog / GitGuardian / Gitleaks 扫描。零信任（Zero-Trust）：MFA、SSO、RBAC/ABAC、短期令牌、设备姿态。PII 脱敏使用实体识别在转发前屏蔽 PHI/PII；一致性分词化（Consistent Tokenization）（Mesh 方法）将敏感值映射到稳定的占位符，使 LLM 保留代码/关系语义。网络出口：LLM 服务在专用 VPC/VNet 子网中，白名单仅允许 `api.openai.com`、`api.anthropic.com` 等；阻止所有其他出站流量。2026 年事件驱动：Vercel 供应链攻击通过被泄露的 CI/CD 凭据窃取了数千个客户部署中的环境变量。

**类型：** 学习
**语言：** Python（标准库，玩具级 PII 脱敏器 + 审计日志写入器）
**前置知识：** 第 17 阶段 · 19（AI 网关），第 17 阶段 · 13（可观测性）
**时间：** 约 60 分钟

## 学习目标

- 列举四种密钥管理的反模式（VCS 中的配置文件、硬编码环境变量、电子表格、静态密钥）并说出其替代方案。
- 解释 AI 网关从保险库拉取模式是 2026 年的生产标准。
- 实现一个带一致性分词化的 PII 脱敏器（相同值 → 相同占位符），使语义得以保留。
- 说出 2026 年 Vercel 供应链事件及其对 CI/CD 凭据卫生的教训。

## 问题

一个实习生提交了包含 API 密钥的 `.env`。他们很快删除了它。密钥已经在 git 历史中——GitGuardian 扫描捕获到它，你的轮换流程是"在 Slack 上通知团队，更新 40 个配置文件，重新部署所有服务"。8 小时后，一半服务在线，一半在等部署窗口。

另外，用户提示词包含"我的 SSN 是 123-45-6789"。提示词发送给 OpenAI。你有 BAA 但你的内部策略是在转发前屏蔽 PII。你没有做。

另外，你 EKS 集群的 LLM Pod 可以访问任何互联网主机。有人通过 DNS 查找将数据泄露到攻击者控制的域。没有任何东西阻止它。

LLM 服务的安全必须应对所有这三个向量。保险库支持的凭据。PII 脱敏。网络出口过滤。审计日志。

## 概念

### 集中化保险库 + IAM 角色拉取

**保险库**：HashiCorp Vault、AWS Secrets Manager、Azure Key Vault、GCP Secret Manager。唯一的真实来源。

**IAM 角色**：应用/网关通过其 IAM 身份认证，而非静态密钥。保险库返回令牌有效期内的密钥。

**AI 网关模式**：网关在请求时从保险库拉取 `OPENAI_API_KEY`。在保险库中轮换；下一个请求获取新密钥。无需重新部署。

### 轮换策略 ≤ 90 天

所有 API 密钥、保险库根令牌、CI/CD 凭据。尽可能自动化轮换。手动轮换需记录并追踪。

### 密钥扫描

- **TruffleHog** — 提交时正则 + 熵检测。
- **GitGuardian** — 商业，高准确率。
- **Gitleaks** — 开源，在 CI 中运行。

每次提交时运行。检测到新密钥则阻止 PR。

### 零信任姿态

- 所有账户要求 MFA。
- 通过 SAML/OIDC 的 SSO。
- RBAC（基于角色）或 ABAC（基于属性）的细粒度访问。
- 短期令牌（小时而非天）。
- 设备姿态——仅带磁盘加密的公司设备。

### PII / PHI 脱敏

提示词离开你的基础设施之前：

1. 实体识别（spaCy NER、Presidio、商业）。
2. 屏蔽匹配的实体：`"我的 SSN 是 123-45-6789"` → `"我的 SSN 是 [SSN_TOKEN_A3F]"`。
3. 一致性分词化（Mesh 方法）：相同值映射到相同占位符，使 LLM 保留关系。
4. 可选的 LLM 响应反向映射。

静态正则过滤器捕获基本模式；NER 捕获更多。两者都用。

### 输入 + 输出护栏

输入：阻止已知的越狱（Jailbreak）、禁止的主题；按用户速率限制。

输出：正则脱敏泄露的密钥（API key 模式、拒绝场景中的邮箱模式）、策略违规的分类器。

### 网络出口白名单

LLM 服务在专用子网中：
- 白名单：`api.openai.com`、`api.anthropic.com`、向量 DB 端点、保险库端点。
- 其他一切：丢弃。
- 通过仅允许列表的 DNS 解析器（避免 DNS 隧道外泄）。

### 审计日志

每个 LLM 调用的不可变日志：
- 时间戳。
- 用户 / 租户。
- 提示词哈希（为隐私不过原始提示词）。
- 模型 + 版本。
- Token 数量。
- 成本。
- 响应哈希。
- 任何护栏触发。

按监管要求保留（SOC 2 1 年，HIPAA 6 年）。

### 2026 年 Vercel 事件

供应链攻击：被泄露的 CI/CD 凭据窃取了数千个客户部署中的环境变量。教训：CI/CD 凭据等同于生产凭据。存储在保险库中。窄范围授权。积极轮换。

### 应记住的数字

- 轮换策略：≤ 90 天。
- 每次提交扫描：TruffleHog / GitGuardian / Gitleaks。
- Vercel 2026：CI/CD 凭据泄露 → 数千客户环境变量泄露。
- 审计日志保留：SOC 2 = 1 年，HIPAA = 6 年。

## 使用它

`code/main.py` 实现了一个带一致性分词化和仅可追加审计日志的玩具级 PII 脱敏器。

## 交付它

本课生成 `outputs/skill-llm-security-plan.md`。根据监管范围和当前状态，规划保险库迁移、脱敏器、出口策略和审计日志。

## 练习

1. 运行 `code/main.py`。发送两个引用相同 SSN 的提示词。确认两者得到相同的占位符。
2. 为调用 OpenAI + Anthropic + Weaviate 的 vLLM-on-EKS 部署设计网络出口策略。
3. 你在 git 历史中发现一个 2 年前的密钥。正确的响应是什么——轮换密钥、清除历史，还是两者？说明理由。
4. 你的审计日志每天增长 10 GB。设计保留层级（热 30 天、温 12 个月、冷 6 年）。
5. 论证反向分词化（将真实值替换回 LLM 响应）的复杂性是否值得，而不是保持占位符可见。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|----------------|------------------------|
| Vault | "密钥存储" | 集中化凭据管理服务 |
| IAM role | "基于身份的认证" | 应用承担的角色；返回短期凭据 |
| OIDC for CI/CD | "云签发令牌" | CI 中无静态密钥——通过 OIDC 的身份 |
| TruffleHog / GitGuardian / Gitleaks | "密钥扫描器" | 提交时密钥检测 |
| RBAC / ABAC | "访问控制" | 基于角色 vs 基于属性 |
| PII scrubbing | "数据脱敏" | 移除或分词化敏感实体 |
| Consistent tokenization | "稳定占位符" | 相同值 → 每次相同 token |
| Mesh approach | "Mesh 分词化" | 保留语义的分词化模式 |
| Egress whitelist | "出站白名单" | 仅允许指定域可达 |
| Audit log | "不可变历史" | 为合规目的的仅可追加记录 |

## 延伸阅读

- [Doppler — Advanced LLM Security](https://www.doppler.com/blog/advanced-llm-security)
- [Portkey — Manage LLM API keys with secret references](https://portkey.ai/blog/secret-references-ai-api-key-management/)
- [Datadog — LLM Guardrails Best Practices](https://www.datadoghq.com/blog/llm-guardrails-best-practices/)
- [JumpServer — Secrets Management Best Practices 2026](https://www.jumpserver.com/blog/secret-management-best-practices-2026)
- [Microsoft Presidio](https://github.com/microsoft/presidio) — PII 检测与匿名化。
- [HashiCorp Vault docs](https://developer.hashicorp.com/vault/docs)