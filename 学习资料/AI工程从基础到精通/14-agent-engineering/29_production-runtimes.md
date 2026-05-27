# 生产运行时：队列、事件、定时

> 生产代理运行在六种运行时形态上：请求-响应（Request-Response）、流式（Streaming）、持久执行（Durable Execution）、基于队列的后台（Queue-based Background）、事件驱动（Event-Driven）和定时（Scheduled）。在选择框架之前先选择形态。可观测性在每种形态中都是承重的。

**类型：** 学习
**语言：** Python（标准库）
**前置条件：** Phase 14 · 13（LangGraph），Phase 14 · 22（语音）
**时间：** ~60 分钟

## 学习目标

- 列举六种生产运行时形态，并将其与对应的框架/产品模式匹配。
- 解释为什么持久执行（LangGraph）对长周期任务很重要。
- 描述事件驱动运行时以及 Claude 托管代理（Claude Managed Agents）的适用场景。
- 解释多步骤代理"可观测性即承重（Observability-as-Load-Bearing）"的主张。

## 问题

生产代理的失败方式是一个 Jupyter Notebook 无法揭示的：第 37 步网络超时、用户在语音通话中途挂断、定时任务在机器重启时死掉、后台工作器内存耗尽。运行时形态决定了哪些失败是可以存活下来的。

## 概念

### 请求-响应

- 同步 HTTP。用户等待完成。
- 仅适用于短任务（<30s）。
- 方案：Agno（Python + FastAPI），Mastra（TypeScript + Express/Hono/Fastify/Koa）。
- 可观测性：标准 HTTP 访问日志 + OTel Span。

### 流式

- SSE 或 WebSocket 用于渐进式输出。
- LiveKit 将此扩展到用于语音/视频的 WebRTC（第 22 课）。
- 方案：任何支持流式传输的框架 + 一个处理 SSE/WS 的前端。
- 可观测性：每块的时间、首 Token 延迟、尾部延迟。

### 持久执行

- 每个步骤后进行状态检查点（Checkpoint）；在失败时自动恢复。
- AutoGen v0.4 Actor 模型将故障隔离到单个代理（第 14 课）。
- LangGraph 的核心差异化优势（第 13 课）。
- 当步骤数未知且恢复成本高时至关重要。

### 基于队列 / 后台

- 作业进入队列，工作器拾取，结果通过 Webhook 或 Pub/Sub 回流。
- 对于长周期代理至关重要（每个任务数十到数百步，参见 Anthropic 的 Computer Use 公告）。
- 方案：Celery（Python），BullMQ（Node），SQS + Lambda（AWS），自定义。
- 可观测性：队列深度、每个作业的延迟分布、死信队列（DLQ）大小。

### 事件驱动

- 代理订阅触发器：新邮件、PR 开启、定时触发。
- Claude 托管代理开箱即用覆盖此功能（第 17 课）。
- CrewAI Flows（第 15 课）构建事件驱动的确定性工作流。
- 可观测性：触发源、事件到启动的延迟、代理延迟。

### 定时

- 定期运行的 Cron 形态代理。
- 结合持久执行，使失败的夜间运行在下一次继续。
- 方案：Kubernetes CronJob + 持久框架；托管方案（Render cron、Vercel cron）。

### 2026 年部署模式

- **CrewAI Flows** — 用于事件驱动生产。
- **Agno** — 无状态 FastAPI 用于 Python 微服务。
- **Mastra** — 服务器适配器（Express、Hono、Fastify、Koa）用于嵌入式部署。
- **Pipecat Cloud / LiveKit Cloud** — 用于托管语音（第 22 课）。
- **Claude 托管代理** — 用于托管长时间运行异步。

### 可观测性是承重的

没有 OpenTelemetry GenAI Span（第 23 课）加上 Langfuse/Phoenix/Opik 后端（第 24 课），你无法调试一个在第 40 步失败的多步骤代理。这对生产不是可选项。它是"我们快速调试"和"我们从零开始重新运行并添加更多日志"之间的区别。

### 生产运行时的失败之处

- **错误的形态选择。** 为 5 分钟的任务选择请求-响应。用户挂断；工作器堆积；重试加重问题。
- **没有死信队列。** 队列工作器没有死信。失败的作业消失。
- **不透明的后台工作。** 后台代理运行没有追踪导出。失败在用户上报之前不可见。
- **跳过持久状态。** 任何超过 30 秒且无法承受重启的运行都需要持久执行。

## 构建

`code/main.py` 是一个标准库多形态演示：

- 请求-响应端点（纯函数）。
- 流式处理器（生成器）。
- 带 DLQ 的基于队列的工作器。
- 事件触发器注册表。
- Cron 形态调度器。

运行方式：

```
python3 code/main.py
```

输出：显示每种形态在同一任务上行为的五条追踪。相同的代理逻辑，不同的外壳。持久执行（第六种形态）在第 13 课通过 LangGraph 检查点有意覆盖。

## 使用场景

- **请求-响应** — 聊天风格 UX。
- **流式** — 渐进式响应。
- **持久** — 长周期任务。
- **队列** — 批处理 / 异步 / 长时间运行。
- **事件** — 代理响应性。
- **定时** — 日常维护（记忆整合、评估、成本报告）。

## 部署

`outputs/skill-runtime-shape.md` 为任务选择运行时形态并接入可观测性需求。

## 练习

1. 将第 01 课的 ReAct 循环移植到你的技术栈中的所有六种形态。哪种形态适合哪个产品表面？
2. 为基于队列的演示添加死信队列。模拟 10% 的作业失败；显示 DLQ 大小。
3. 编写一个定时触发的评估代理，每个晚上对当天所有追踪的前 20 条的运行评估。
4. 实现带背压的流式传输：如果客户端慢，暂停代理。这如何与轮次预算交互？
5. 阅读 Claude 托管代理文档。何时将自托管的长周期代理迁移到托管方案？

## 关键术语

| 术语 | 人们常说的 | 实际含义 |
|------|-----------|---------|
| 请求-响应（Request-Response） | "同步" | 用户等待；仅短任务 |
| 流式（Streaming） | "SSE / WS" | 渐进式输出；更好的 UX；每块延迟可观测 |
| 持久执行（Durable Execution） | "从失败恢复" | 检查点状态；从上一步重启 |
| 基于队列（Queue-based） | "后台作业" | 生产者/工作器池/DLQ |
| 事件驱动（Event-Driven） | "基于触发" | 代理响应外部事件 |
| DLQ | "死信队列" | 失败作业的停放场 |
| Claude 托管代理（Claude Managed Agents） | "托管工具链" | Anthropic 托管的长时间运行异步，带缓存 + 压缩 |

## 进一步阅读

- [LangGraph 概述](https://docs.langchain.com/oss/python/langgraph/overview) — 持久执行细节
- [Claude 托管代理概述](https://platform.claude.com/docs/en/managed-agents/overview) — 托管长时间运行异步
- [Anthropic，Introducing computer use](https://www.anthropic.com/news/3-5-models-and-computer-use) — "每个任务数十到数百步"
- [AutoGen v0.4（Microsoft Research）](https://www.microsoft.com/en-us/research/articles/autogen-v0-4-reimagining-the-foundation-of-agentic-ai-for-scale-extensibility-and-robustness/) — Actor 模型故障隔离