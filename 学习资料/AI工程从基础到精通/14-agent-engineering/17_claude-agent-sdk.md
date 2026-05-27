# Claude Agent SDK：子代理与会话存储

> Claude Agent SDK 是 Claude Code 工具链的库形式。内置工具、用于上下文隔离的子代理、钩子（Hooks）、W3C 追踪传播、会话存储对等。Claude 托管代理（Claude Managed Agents）是用于长时间运行异步工作的托管替代方案。

**类型：** 学习 + 构建
**语言：** Python（标准库）
**前置条件：** Phase 14 · 01（Agent 循环），Phase 14 · 10（技能库，Skill Libraries）
**时间：** ~75 分钟

## 学习目标

- 解释 Anthropic 客户端 SDK（原始 API）与 Claude Agent SDK（工具链形态）之间的区别。
- 描述子代理（Subagent）——并行化与上下文隔离——以及何时使用它们。
- 列举 Python SDK 的会话存储接口（`append`、`load`、`list_sessions`、`delete`、`list_subkeys`）以及 `--session-mirror` 的作用。
- 实现一个标准库工具链，包含内置工具、带隔离上下文的子代理生成、生命周期钩子以及会话存储。

## 问题

原始 LLM API 只能提供一次往返。生产级代理需要工具执行、MCP 服务器、生命周期钩子、子代理生成、会话持久化、追踪传播。Claude Agent SDK 以库的形式提供这些能力——与 Claude Code 使用相同的工具链，用于自定义代理。

## 概念

### 客户端 SDK vs Agent SDK

- **客户端 SDK（`anthropic`）。** 原始 Messages API。你自行管理循环、工具和状态。
- **Agent SDK（`claude-agent-sdk`）。** 内置工具执行、MCP 连接、钩子、子代理生成、会话存储。Claude Code 循环作为库。

### 内置工具

SDK 内置了 10+ 种工具：文件读写、Shell、grep、glob、网页抓取等。自定义工具通过标准工具 Schema 接口注册。

### 子代理

Anthropic 文档中描述了两种用途：

1. **并行化。** 并发运行独立工作。"为这 20 个模块分别找到测试文件"就是 20 个并行的子代理任务。
2. **上下文隔离。** 子代理使用自己的上下文窗口；只有结果返回给编排器（Orchestrator）。编排器的预算得以保留。

Python SDK 近期新增：`list_subagents()`、`get_subagent_messages()` 用于读取子代理的记录。

### 会话存储

与 TypeScript 版本的协议对等：

- `append(session_id, message)` — 添加一个轮次。
- `load(session_id)` — 恢复对话。
- `list_sessions()` — 枚举。
- `delete(session_id)` — 级联删除子代理会话。
- `list_subkeys(session_id)` — 列出子代理键。

`--session-mirror`（CLI 标志）在流式传输时将记录镜像到外部文件，用于调试。

### 钩子

可以注册的生命周期钩子：

- `PreToolUse`、`PostToolUse` — 门控或审计工具调用。
- `SessionStart`、`SessionEnd` — 设置和拆卸。
- `UserPromptSubmit` — 在模型看到之前处理用户输入。
- `PreCompact` — 在上下文压缩之前运行。
- `Stop` — 代理退出时清理。
- `Notification` — 旁路告警。

钩子是类似 pro-workflow（Phase 14 课程参考）等系统添加横切行为的方式。

### W3C 追踪上下文

调用方上活跃的 OTel Span 通过 W3C 追踪上下文头部传播到 CLI 子进程。整个多进程追踪在你的后端显示为一条追踪链。

### Claude 托管代理

托管替代方案（Beta 头部 `managed-agents-2026-04-01`）。长时间运行的异步工作，内置提示缓存（Prompt Caching），内置压缩。用控制换取托管基础设施。

### 这种模式的陷阱

- **子代理过度生成。** 为 100 个小任务生成 100 个子代理。开销占主导地位。改为批量处理。
- **钩子蔓延。** 每个团队都添加钩子；启动时间膨胀。每季度审查钩子。
- **会话膨胀。** 会话累积；大小增长。使用 `list_sessions` + 过期策略。

## 构建

`code/main.py` 用标准库实现了 SDK 的形态：

- `Tool`、`ToolRegistry`，内置 `read_file`、`write_file`、`list_dir`。
- `Subagent` — 私有上下文、隔离运行、返回结果。
- `SessionStore` — append、load、list、delete、list_subkeys。
- `Hooks` — `pre_tool_use`、`post_tool_use`、`session_start`、`session_end`。
- 演示：主代理并行生成 3 个子代理（每个相互隔离），聚合结果，持久化会话。

运行方式：

```
python3 code/main.py
```

追踪显示子代理上下文隔离（编排器上下文大小保持受限）、钩子执行和会话持久化。

## 使用场景

- **Claude Agent SDK** — 面向希望使用 Claude Code 工具链形态的 Claude 优先产品。
- **Claude 托管代理** — 面向托管的长时间运行异步工作。
- **OpenAI Agents SDK**（第 16 课）—OpenAI 优先的对应方案。
- **LangGraph + 自定义工具** — 如果你希望使用图形态的状态机。

## 部署

`outputs/skill-claude-agent-scaffold.md` 搭建了一个 Claude Agent SDK 应用脚手架，包含子代理、钩子、会话存储、MCP 服务器附加和 W3C 追踪传播。

## 练习

1. 添加一个子代理生成器，将 20 个任务分批为每组 5 个并行子代理。测量编排器上下文大小与每个任务一个子代理的对比。
2. 实现一个 `PreToolUse` 钩子，对 `write_file` 调用进行限速（每个会话每分钟 5 次）。追踪其行为。
3. 使用 `list_subkeys` 渲染子代理树。深层嵌套会是什么样子？
4. 将玩具示例移植到真实的 `claude-agent-sdk` Python 包。工具注册方面有什么变化？
5. 阅读 Claude 托管代理文档。何时从自托管切换到托管？

## 关键术语

| 术语 | 人们常说的 | 实际含义 |
|------|-----------|---------|
| Agent SDK | "Claude Code 作为库" | 工具链形态：工具、MCP、钩子、子代理、会话存储 |
| 子代理 | "子代理" | 独立上下文、独立预算；结果上浮 |
| 会话存储 | "对话数据库" | 持久化、加载、列出、删除轮次，子代理级联 |
| 钩子 | "生命周期回调" | 工具前后、会话、提示提交、压缩、停止 |
| W3C 追踪上下文 | "跨进程追踪" | 父 Span 传播到 CLI 子进程 |
| 托管代理 | "托管工具链" | Anthropic 托管的长时间运行异步工作 |
| `--session-mirror` | "记录镜像" | 在流式传输时将会话轮次写入外部文件 |
| MCP 服务器 | "工具接口" | 附加到代理的外部工具/资源源 |

## 进一步阅读

- [Claude Agent SDK 概述](https://platform.claude.com/docs/en/agent-sdk/overview) — Claude Code 的库形式
- [Anthropic，使用 Claude Agent SDK 构建代理](https://www.anthropic.com/engineering/building-agents-with-the-claude-agent-sdk) — 生产模式
- [Claude 托管代理概述](https://platform.claude.com/docs/en/managed-agents/overview) — 托管替代方案
- [OpenAI Agents SDK](https://openai.github.io/openai-agents-python/) — 对应方案