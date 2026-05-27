# LLM 生产混沌工程

> 2026 年，面向 LLM 的混沌工程（Chaos Engineering）已成为独立学科。在生产中运行实验的前提条件：已定义的 SLI/SLO、追踪+指标+日志可观测性、自动回滚、运维手册、值班。架构有四个平面：控制（实验调度器）、目标（服务、基础设施、数据存储）、安全（守卫 + 中止 + 流量过滤）、可观测性（指标 + 追踪 + 日志）、反馈（进入 SLO 调整）。护栏是强制性的：消耗率告警（Burn-Rate Alert）在日常错误预算消耗 > 预期 2 倍时暂停实验；抑制窗口（Suppression Windows）+ 追踪-ID 关联去重告警噪音。节奏：每周小型金丝雀实验 + SLO 评审；每月游戏日（Game Day）+ 事后总结；每季度跨团队韧性审计 + 依赖映射。LLM 特定实验：内存过载、网络故障、供应商中断、畸形提示词、KV 缓存回收风暴（Eviction Storm）。工具：Harness Chaos Engineering（LLM 衍生的实验建议、爆炸半径缩小、MCP 工具集成）；LitmusChaos（CNCF）；Chaos Mesh（CNCF Kubernetes 原生）。

**类型：** 学习
**语言：** Python（标准库，玩具级混沌实验运行器）
**前置知识：** 第 17 阶段 · 23（AI SRE），第 17 阶段 · 13（可观测性）
**时间：** 约 60 分钟

## 学习目标

- 说出混沌工程的五个前提（SLI/SLO、可观测性、回滚、运维手册、值班），并解释为什么跳过任何一项都会破坏实践。
- 画出四个平面（控制、目标、安全、可观测性）以及进入 SLO 的反馈循环。
- 列举五个 LLM 特定实验（内存过载、网络故障、供应商中断、畸形提示词、KV 回收风暴）。
- 根据技术栈选择工具——Harness、LitmusChaos、Chaos Mesh。

## 问题

传统技术栈中的混沌测试已经很成熟。LLM 技术栈增加了新的失败模式。一个带毒字符（Poison Character）的 4K token 提示词让分词器停滞 12 秒。上游供应商 429；你的网关重试；你的服务因重试放大的并发而 OOM。突发负载下的 KV 缓存回收风暴导致重新预填充级联（Re-Prefill Cascade），使计算饱和。

这些都不会出现在单元测试中。混沌工程是你在用户之前发现它们的方式。

## 概念

### 前提条件

不要在缺少以下条件时在生产环境运行混沌实验：

1. **SLI/SLO** — 已定义的服务水平指标和目标。
2. **可观测性** — 追踪、指标、日志，连接到仪表板。
3. **自动回滚** — 第 17 阶段 · 20 的策略标志回滚。
4. **运维手册** — 结构化的，第 17 阶段 · 23。
5. **值班** — 有人响应。

缺少任何一项，混沌实验就会变成真实事故。

### 四个平面 + 反馈

**控制平面** — 实验调度器（Litmus 工作流、Chaos Mesh 调度、Harness UI）。

**目标平面** — 服务、Pod、节点、负载均衡器、数据存储。

**安全平面** — 终止开关（Kill Switch）、抑制窗口、爆炸半径限制、错误预算关卡。

**可观测平面** — 正常指标 + 追踪-ID 关联，以区分混沌引起的失败和自然失败。

**反馈循环** — 发现反馈到 SLO 调整、运维手册更新、代码修复。

### 护栏是强制性的

- **消耗率告警**：当日错误预算消耗 > 预期 2 倍时暂停实验。
- **抑制窗口**：实验期间在爆炸半径内静默非实验告警。
- **追踪-ID 关联**：所有实验引起的错误携带标签，以便值班团队去重。

### 五个 LLM 特定实验

1. **内存过载** — 通过高并发长上下文请求强制 KV 缓存抢占风暴。观察：服务是优雅降级还是崩溃？

2. **网络故障** — 切断推理网关和供应商之间的连接。观察：故障转移是否在 SLA 内启动？（第 17 阶段 · 19）

3. **供应商中断模拟** — OpenAI 100% 429。观察：路由是否故障转移到 Anthropic？（第 17 阶段 · 16、19）

4. **畸形提示词** — 注入使分词器停滞的有效载荷（例如，深层嵌套的 unicode、巨大的 UTF-8 码点）。观察：单个请求是否锁死一个工作进程？

5. **KV 回收风暴** — 通过饱和 vLLM 块预算强制回收。观察：LMCache 能否恢复，还是服务降级？

### 节奏

- **每周** — 预发布环境中的小型金丝雀实验，可能 5% 生产环境。
- **每月** — 针对特定场景的计划游戏日；跨团队参与；事后总结。
- **每季度** — 跨团队韧性审计；依赖关系图更新。

### 工具

- **Harness Chaos Engineering** — 商业；AI 衍生的实验建议；爆炸半径缩小；MCP 工具集成。
- **LitmusChaos** — CNCF 毕业项目；Kubernetes 工作流基于。
- **Chaos Mesh** — CNCF 沙箱项目；Kubernetes 原生 CRD 风格。
- **Gremlin** — 商业；广泛支持。
- **AWS FIS** / **Azure Chaos Studio** — 托管云产品。

### 从小处着手

第一次实验：在稳定流量下对整个解码副本进行 Pod-kill（杀 Pod）。观察重路由和恢复。如果这运行良好且看起来安全，毕业到网络混沌。

第一个 LLM 特定实验：注入一个供应商 429 持续 5 分钟。观察故障转移。大多数团队发现他们的故障转移从未被完整测试过。

### 应记住的数字

- 四个平面：控制、目标、安全、可观测性。
- 消耗率暂停：预期每日预算消耗的 2 倍。
- 节奏：每周金丝雀、每月游戏日、每季度审计。
- 五个 LLM 实验：内存、网络、供应商、畸形提示词、KV 风暴。

## 使用它

`code/main.py` 模拟三个带安全平面关卡的混沌实验。报告哪些实验会触发消耗率中止。

## 交付它

本课生成 `outputs/skill-chaos-plan.md`。根据技术栈和成熟度，挑选前三个实验和工具。

## 练习

1. 运行 `code/main.py`。哪个实验触发消耗率关卡，为什么？
2. 为一个基于 vLLM 的 RAG 服务设计前五个混沌实验。包括成功标准。
3. 你的消耗率告警暂停了一个实验。如何判断根因是混沌还是自然故障？
4. 论证混沌实验应在生产还是仅在预发布环境运行。何时生产是正确的答案？
5. 说出三个通用网络混沌无法复现的 LLM 特定失败模式。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|----------------|------------------------|
| SLI / SLO | "服务目标" | 指标 + 目标；必需前提 |
| Blast radius | "爆炸范围" | 实验影响的服务/用户集合 |
| Burn-rate alert | "预算关卡" | 当错误预算消耗率 > 预期 2 倍时触发 |
| Game day | "月度演练" | 计划的跨团队混沌练习 |
| LitmusChaos | "CNCF 工作流" | 已毕业的 CNCF Kubernetes 混沌工具 |
| Chaos Mesh | "CNCF CRD" | CNCF 沙箱 Kubernetes 原生混沌 |
| Harness CE | "商业 AI 辅助" | 带 AI 建议的 Harness 混沌 |
| Malformed prompt | "分词器炸弹" | 使分词停滞的输入 |
| KV eviction storm | "抢占级联" | 大规模回收触发重新预填充 |

## 延伸阅读

- [DevSecOps School — Chaos Engineering 2026 Guide](https://devsecopsschool.com/blog/chaos-engineering/)
- [Ankush Sharma — Observability for LLMs (book)](https://www.amazon.com/Observability-Large-Language-Models-Engineering-ebook/dp/B0DJSR65TR)
- [LitmusChaos (CNCF)](https://litmuschaos.io/)
- [Chaos Mesh (CNCF)](https://chaos-mesh.org/)
- [Harness Chaos Engineering](https://www.harness.io/products/chaos-engineering)
- [AWS FIS](https://aws.amazon.com/fis/)