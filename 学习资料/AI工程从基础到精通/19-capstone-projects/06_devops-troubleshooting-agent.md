# 综合项目 06 — Kubernetes DevOps 故障排除 Agent

> AWS 的 DevOps Agent 已正式发布（GA），Resolve AI 发布了其 K8s 操作手册，NeuBird 演示了语义监控，Metoro 将 AI SRE 与每服务 SLO 绑定。生产形态已经定型：告警 webhook 触发，Agent 读取遥测数据，遍历 K8s 对象图谱，对根因假设进行排序，并发布带有批准按钮的 Slack 简报。默认只读。每个修复操作都由人工把关。本综合项目就是构建这样一个 Agent，在 20 个合成事件上评估，并在三个共享案例上与 AWS 的 Agent 进行对比。

**类型：** 综合项目
**语言：** Python（agent）、TypeScript（Slack 集成）
**前置知识：** 阶段 11（LLM 工程）、阶段 13（工具和 MCP）、阶段 14（Agent）、阶段 15（自主系统）、阶段 17（基础设施）、阶段 18（安全）
**涵盖阶段：** P11 · P13 · P14 · P15 · P17 · P18
**时间：** 30 小时

## 问题

2025-2026 年 SRE 叙事变成了："AI Agent 分流事件，人工批准修复。"AWS DevOps Agent、Resolve AI、NeuBird、Metoro、PagerDuty AIOps 都在生产环境中交付了这种形态。Agent 读取 Prometheus 指标、Loki 日志、Tempo 追踪、kube-state-metrics 以及 K8s 对象的知识图谱（knowledge graph）。它在五分钟内生成带有遥测引用的排序根因假设。没有明确的 Slack 人工批准，它绝不执行破坏性命令。

大部分困难工作在于范围界定和安全，而非推理。Agent 需要一个默认只读的 RBAC 表面、一个加固的 MCP 工具服务器，以及每个命令的考虑 vs 执行的审计日志。它需要知道何时超出自身能力范围并进行升级。而且它必须足够便宜地运行，使得 OOM-kill 级联不会产生 5000 美元的 Agent 账单。

## 概念

Agent 在知识图谱上运行。节点是 K8s 对象（Pod、Deployment、Service、Node、HPA、PVC）加上遥测源（Prometheus 序列、Loki 流、Tempo 追踪）。边编码所有权（Pod -> ReplicaSet -> Deployment）、调度（Pod -> Node）和观测（Pod -> Prometheus 序列）。图谱通过 kube-state-metrics 同步保持最新，并在每次告警时重新采样。

当告警触发时，Agent 从受影响的对象开始根因分析。它遍历边，拉取相关遥测切片（最近 15 分钟），并草拟假设。假设按证据排序：有多少遥测引用支持它、多近期、多具体。前 3 个假设连同图谱路径可视化和修复操作的批准按钮一起发送到 Slack。

修复是有闸门的。允许的默认操作是只读的。破坏性操作（缩容、回滚、删除 Pod）需要 Slack 批准；ArgoCD 回滚钩子需要 Agent 永远不持有的授权令牌。审计日志记录 Agent **考虑过**的每个命令——不仅仅是已执行的——以便审查过程捕获险兆事件（near-misses）。

## 架构

```
PagerDuty / Alertmanager webhook
           |
           v
     FastAPI 接收器
           |
           v
   LangGraph 根因分析 Agent
           |
           +---- 只读 MCP 工具 ----+
           |                       |
           v                       v
   K8s 知识图谱               遥测切片
     （Neo4j / kuzu）        Prometheus、Loki、Tempo
   所有权 + 调度              最近 15 分钟，限定范围
           |
           v
   假设排序（证据权重）
           |
           v
   Slack 简报 + 批准按钮
           |
           v（已批准）
   ArgoCD 回滚钩子 / PagerDuty 升级
           |
           v
   审计日志：考虑 vs 执行，每个命令
```

## 技术栈

- 可观测性源：Prometheus、Loki、Tempo、kube-state-metrics
- 知识图谱：Neo4j（托管）或 kuzu（嵌入式），包含 K8s 对象 + 遥测边
- Agent：LangGraph，带每个工具的允许列表，默认只读
- 工具传输：FastMCP over StreamableHTTP；破坏性工具使用独立服务器，位于批准闸门之后
- 模型：Claude Sonnet 4.7 用于根因推理，Gemini 2.5 Flash 用于日志摘要
- 修复：ArgoCD 回滚 webhook、PagerDuty 升级、Slack 批准卡片
- 审计：仅追加结构日志（已考虑、已执行、已批准、结果）
- 部署：K8s 部署，具有自己的窄 RBAC 角色；独立命名空间

## 构建步骤

1. **图谱摄入。** 每 30 秒将 kube-state-metrics 同步到 Neo4j/kuzu。节点：Pod、Deployment、Node、Service、PVC、HPA。边：OWNED_BY、SCHEDULED_ON、EXPOSES、MOUNTS、SCALES。遥测叠加边：OBSERVED_BY（一个 Pod 被一个 Prometheus 序列观测）。

2. **告警接收器。** FastAPI 端点，接受 PagerDuty 或 Alertmanager webhook。提取受影响的对象和 SLO 违反。

3. **只读工具表面。** 通过 FastMCP 包装 kubectl、Prometheus 查询、Loki logql、Tempo traceql。每个工具具有窄 RBAC 动词（"get"、"list"、"describe"）。默认服务器中无 "delete"、"exec"、"scale"。

4. **根因分析 Agent。** LangGraph 包含三个节点：`sample` 拉取最近 15 分钟的遥测切片，`walk` 查询图谱中相邻对象，`hypothesize` 草拟带遥测引用的排序根因候选。

5. **证据评分。** 每个假设的分数 = 近期性 * 具体性 * 图谱路径长度倒数 * 引用数量。返回前 3 个。

6. **Slack 简报。** 发布带有假设、图谱路径可视化（服务端渲染的子图图像）以及至多一个修复操作批准按钮的附件。

7. **修复闸门。** 破坏性工具（缩容、回滚、删除）位于第二个 MCP 服务器上，在批准令牌之后。Agent 只有在 Slack 卡片被人工批准后才能调用它们。

8. **审计日志。** 仅追加 JSONL：对每个候选命令，记录是否被考虑、是否被执行、由谁批准。每日发送到 S3。

9. **合成事件套件。** 构建 20 个场景：OOMKill 级联、DNS 抖动、HPA 震荡、PVC 填满、嘈杂邻居、故障 sidecar、错误 ConfigMap 部署、证书轮换、镜像拉取退避等。根据根因准确性和提出假设时间对 Agent 进行评分。

## 使用方式

```
webhook: alert.pagerduty.com -> checkout-api SLO 违反，错误率 14%
[graph]   受影响：Deployment checkout-api（3 个 Pod，节点 ip-10-2-3-4）
[walk]    邻居：ReplicaSet checkout-api-abc，Service checkout-api，
           最近部署 14 分钟前
[sample]  prometheus 错误率 14%，上升趋势；loki 在 /api/v2/pay 上出现 500 错误
[hypo]    #1 错误部署：最新镜像 checkout-api:v2.41 在 /healthz 上失败
          引用：deploy.yaml（版本 42），prometheus 错误率，loki 500 堆栈
[slack]   [回滚到 v2.40]  [升级]  [忽略]
          （需要批准；Agent 不会单方面回滚）
```

## 交付标准

`outputs/skill-devops-agent.md` 是交付物。给定一个 K8s 集群和告警源，Agent 生成排序根因假设和 Slack 闸门修复流程。

| 权重 | 标准 | 衡量方式 |
|:-:|---|---|
| 25 | 场景套件上的根因分析（RCA）准确性 | 20 个合成事件中 ≥80% 正确根因 |
| 20 | 安全性 | 审计日志中破坏性操作守卫从未在无 Slack 批准的情况下触发 |
| 20 | 提出假设时间 | 从告警到 Slack 简报的 p50 低于 5 分钟 |
| 20 | 可解释性 | 每个假设都有图谱路径和遥测引用 |
| 15 | 集成完整性 | PagerDuty、Slack、ArgoCD、Prometheus 端到端正常运行 |
| **100** | | |

## 练习

1. 在 AWS DevOps Agent 演示的三个相同事件上运行你的 Agent。发布并排对比。报告 Agent 在何处出现分歧。

2. 添加一个"险兆"审计，标记 Agent **考虑过**的、在没有批准的情况下本会是破坏性的任何命令。衡量一周内的险兆率。

3. 将假设模型从 Claude Sonnet 4.7 替换为自托管 Llama 3.3 70B。衡量根因分析准确性差异和每个事件的美元成本。

4. 构建因果过滤器：区分相关的遥测峰值与真正的根因。在 20 个场景标签上训练一个小型分类器。

5. 添加回滚试运行：在具有相同配置清单的 staging 集群上执行 ArgoCD 回滚。在 Slack 批准按钮之前在实际集群中验证回滚计划。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|------------------------|
| K8s 知识图谱（K8s knowledge graph） | "集群图谱" | 节点 = K8s 对象 + 遥测序列；边 = 所有权、调度、观测 |
| 默认只读（Read-only-by-default） | "限定范围 RBAC" | Agent 的服务账户只有 get/list/describe 动词；破坏性动词在独立服务器上，需批准后方可使用 |
| 审计日志（Audit log） | "考虑 vs 执行" | 仅追加记录，包含每个候选命令、是否运行、由谁批准 |
| 假设排序（Hypothesis ranking） | "证据评分" | 近期性 × 具体性 × 图谱路径长度倒数 × 引用数量 |
| Slack 批准卡片（Slack approval card） | "人机协作（HITL）闸门" | 带修复按钮的交互式 Slack 消息；Agent 在人工点击前不能继续 |
| 遥测引用（Telemetry citation） | "证据指针" | 支撑某个声明的 Prometheus 查询、Loki 选择器或 Tempo 追踪 URL |
| MTTR | "修复时间" | 从告警触发到 SLO 恢复的墙钟时间 |

## 延伸阅读

- [AWS DevOps Agent GA](https://aws.amazon.com/blogs/aws/aws-devops-agent-helps-you-accelerate-incident-response-and-improve-system-reliability-preview/) — 2026 年规范参考
- [Resolve AI K8s 故障排除](https://resolve.ai/blog/kubernetes-troubleshooting-in-resolve-ai) — 竞品参考
- [NeuBird 语义监控](https://www.neubird.ai) — 语义图谱方法
- [Metoro AI SRE](https://metoro.io) — SLO 优先的生产框架
- [kube-state-metrics](https://github.com/kubernetes/kube-state-metrics) — 集群状态源
- [LangGraph](https://langchain-ai.github.io/langgraph/) — 参考 Agent 编排器
- [FastMCP](https://github.com/jlowin/fastmcp) — Python MCP 服务器框架
- [ArgoCD 回滚](https://argo-cd.readthedocs.io/en/stable/user-guide/commands/argocd_app_rollback/) — 闸门修复目标