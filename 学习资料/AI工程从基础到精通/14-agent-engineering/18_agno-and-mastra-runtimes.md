# Agno 与 Mastra：生产运行时

> Agno（Python）和 Mastra（TypeScript）是 2026 年生产运行时配对。Agno 追求微秒级代理实例化和无状态 FastAPI 后端。Mastra 在 Vercel AI SDK 基座上提供代理、工具、工作流、统一模型路由和组合存储。

**类型：** 学习
**语言：** Python、TypeScript
**前置条件：** Phase 14 · 01（Agent 循环），Phase 14 · 13（LangGraph）
**时间：** ~45 分钟

## 学习目标

- 识别 Agno 的性能目标以及何时它们才重要。
- 列举 Mastra 的三种原语——代理（Agents）、工具（Tools）、工作流（Workflows）——以及支持的服务器适配器。
- 解释为什么无状态会话范围的 FastAPI 后端是推荐的 Agno 生产路径。
- 根据技术栈选择 Agno 还是 Mastra（Python 优先 vs TypeScript 优先）。

## 问题

LangGraph、AutoGen、CrewAI 都是框架级的重型方案。那些只需要"快速运行代理循环"的团队会选择 Agno（Python）或 Mastra（TypeScript）。两者都用原始速度和与周围技术栈更紧密的集成来换取框架拥有的一些原语。

## 概念

### Agno

- Python 运行时，前身为 Phi-data。
- "没有图、链或复杂的模式——只有纯 Python。"
- 来自其文档的性能目标：~2 μs 代理实例化，~3.75 KiB 每代理内存，~23 个模型提供商。
- 生产路径：无状态会话范围的 FastAPI 后端。每个请求启动一个新代理；会话状态存储在数据库中。
- 原生多模态（文本、图像、音频、视频、文件）和代理 RAG。

当每秒有数千个短生命周期代理时（聊天汇聚、评估流水线），这些速度目标至关重要。当一个代理运行 10 分钟时，它们就不那么重要了。

### Mastra

- TypeScript，基于 Vercel AI SDK 构建。
- 三种原语：**代理**、**工具**（Zod 类型化）、**工作流**。
- 统一模型路由（Unified Model Router）——94 个提供商上的 3,300+ 个模型（2026 年 3 月）。
- 组合存储（Composite Storage）：内存、工作流、可观测性分别对应不同的后端；在大规模场景下推荐使用 ClickHouse 进行可观测性。
- Apache 2.0 许可，`ee/` 目录使用源可用企业许可证。
- 服务器适配器支持 Express、Hono、Fastify、Koa；一流的 Next.js 和 Astro 集成。
- 提供 Mastra Studio（localhost:4111）用于调试。
- 22k+ GitHub Stars，1.0 版本（2026 年 1 月）每周 npm 下载量突破 300k。

### 定位

两者都不想成为 LangGraph。它们在以下方面竞争：

- **语言契合。** Agno 适合 Python 优先团队；Mastra 适合 TypeScript 优先团队。
- **运行时人体工程学。** Agno = 几乎零开销；Mastra = 与 Vercel 生态集成。
- **可观测性。** 两者都集成了 Langfuse/Phoenix/Opik（第 24 课），但 Mastra Studio 是第一方工具。

### 何时选择哪个

- **Agno** — Python 后端，大量短生命周期代理，强性能需求，FastAPI 技术栈。
- **Mastra** — TypeScript 后端，Next.js / Vercel 部署，统一的多提供商模型路由，Zod 类型化工具。
- **LangGraph**（第 13 课）— 当持久化状态和显式图推理比原始速度更重要时。
- **OpenAI / Claude Agent SDK** — 当你想要提供商的成品形态时（第 16-17 课）。

### 这种模式的陷阱

- **为了性能而性能。** 选择 Agno 因为"2 μs"听起来很好，但实际负载是每个请求一次缓慢的代理调用。开销并不是瓶颈。
- **生态锁定。** Mastra 的 Vercel 风格集成在 Vercel 上是优势，在其他地方是劣势。
- **企业许可证混淆。** Mastra 的 `ee/` 目录是源可用（Source-available），不是 Apache 2.0。如果计划 fork，请阅读许可证。

## 构建

本课主要是比较性学习——没有单一的代码产物能同时公平地展示两个框架。参见 `code/main.py` 中的并排玩具示例：一个最小的"运行代理、流式输出、持久化会话"流程实现了两次（一次 Agno 风格，一次 Mastra 风格）。

运行方式：

```
python3 code/main.py
```

两条结构不同但功能等价的追踪。

## 使用场景

- **Agno** — 需要速度和 FastAPI 形态的 Python 后端。
- **Mastra** — 有众多提供商和工作流原语的 TypeScript 后端。
- 两者都提供第一方可观测性钩子。两者都集成 Langfuse。

## 部署

`outputs/skill-runtime-picker.md` 根据技术栈、延迟预算和运维形态选择 Agno、Mastra、LangGraph 或提供商 SDK。

## 练习

1. 阅读 Agno 的文档。将标准库 ReAct 循环（第 01 课）移植到 Agno。什么消失了？什么保留了？
2. 阅读 Mastra 的文档。将相同的循环移植到 Mastra。工具类型化方面有什么变化（Zod vs 无类型）？
3. 基准测试：在你的技术栈上测量代理实例化延迟。Agno 的 2 μs 对你的负载有意义吗？
4. 设计一次迁移：如果你一直在 Python 中使用 CrewAI，迁移到 Agno 会有什么破坏性变化？
5. 阅读 Mastra 的 `ee/` 许可条款。哪些限制会影响开源分支？

## 关键术语

| 术语 | 人们常说的 | 实际含义 |
|------|-----------|---------|
| Agno | "快速的 Python 代理" | 无状态会话范围代理运行时 |
| Mastra | "Vercel AI SDK 上的 TypeScript 代理" | 代理 + 工具 + 工作流 + 模型路由 |
| 统一模型路由 | "多提供商访问" | 94 个提供商 3,300+ 个模型的单一客户端 |
| 组合存储 | "多后端" | 内存/工作流/可观测性分别对应不同存储 |
| Mastra Studio | "本地调试器" | localhost:4111 用于检查代理的 UI |
| 源可用 | "非开源" | 许可证允许阅读源码但限制商业使用 |

## 进一步阅读

- [Agno Agent Framework 文档](https://www.agno.com/agent-framework) — 性能目标、FastAPI 集成
- [Mastra 文档](https://mastra.ai/docs) — 原语、服务器适配器、模型路由
- [LangGraph 概述](https://docs.langchain.com/oss/python/langgraph/overview) — 有状态图替代方案
- [Comet Opik](https://www.comet.com/site/products/opik/) — Mastra 集成引用的可观测性对比