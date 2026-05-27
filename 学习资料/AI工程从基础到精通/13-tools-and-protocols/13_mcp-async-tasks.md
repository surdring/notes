# 异步任务（Async Tasks, SEP-1686）—— 先调用、后取结果的长时运行工作模式

> 真正的 Agent 工作需要几分钟到几小时：CI 运行、深度研究综合、批量导出。同步工具调用会断开连接、超时或阻塞 UI。SEP-1686 于 2025 年 11 月 25 日合并，新增了任务（Tasks）原语：任何请求都可以增强为任务，结果可以稍后获取或通过状态通知流式传输。漂移风险提示：任务在 2026 年上半年处于实验阶段；SDK 接口仍在围绕规范进行设计。

**类型：** 构建
**语言：** Python（标准库，异步任务状态机）
**前置要求：** Phase 13 · 07（MCP 服务器），Phase 13 · 09（传输层）
**时间：** ~75 分钟

## 学习目标

- 判断何时将工具从同步模式升级为任务增强模式（服务器端工作时间超过 30 秒）。
- 遍历任务生命周期：`working` → `input_required` → `completed` / `failed` / `cancelled`。
- 持久化任务状态，使崩溃不会丢失正在进行的工作。
- 正确轮询 `tasks/status` 并获取 `tasks/result`。

## 问题

一个 `generate_report` 工具运行一个数分钟的提取流水线。在同步模型下的选项：

1. 保持连接开启三分钟。远程传输层会断开；客户端会超时；UI 会冻结。
2. 立即返回一个占位符；要求客户端轮询自定义端点。破坏 MCP 的统一性。
3. 发射后不管；没有结果。

这些都不好。SEP-1686 增加了第四种：任务增强。任何请求（通常是 `tools/call`）都可以标记为任务。服务器立即返回一个任务 ID。客户端轮询 `tasks/status`，并在完成后获取 `tasks/result`。服务器端状态在重启后仍然存活。

## 概念

### 任务增强

请求通过设置 `params._meta.task.required: true`（或 `optional: true`，由服务器决定）变成任务。服务器立即响应：

```json
{
  "jsonrpc": "2.0", "id": 1,
  "result": {
    "_meta": {
      "task": {
        "id": "tsk_9f7b...",
        "state": "working",
        "ttl": 900000
      }
    }
  }
}
```

`ttl` 是服务器承诺保留状态的时间；过期后任务结果将被丢弃。

### 按工具的显式声明

工具注解可以声明任务支持：

- `taskSupport: "forbidden"` —— 此工具始终同步运行。适用于快速工具。
- `taskSupport: "optional"` —— 客户端可以请求任务增强。
- `taskSupport: "required"` —— 客户端必须使用任务增强。

`generate_report` 工具应为 `required`。`notes_search` 工具应为 `forbidden`。

### 状态

```
working  -> input_required -> working  （通过诱导循环）
working  -> completed
working  -> failed
working  -> cancelled
```

状态机是追加式的：一旦达到 `completed`、`failed` 或 `cancelled`，任务即进入终态。

### 方法

- `tasks/status {taskId}` —— 返回当前状态和进度提示。
- `tasks/result {taskId}` —— 阻塞，或如果尚未完成则返回 404。
- `tasks/cancel {taskId}` —— 幂等；终态任务忽略此请求。
- `tasks/list` —— 可选；枚举活跃和最近完成的任务。

### 流式状态变更

当服务器支持时，客户端可以订阅状态通知：

```
server -> notifications/tasks/updated {taskId, state, progress?}
```

客户端使用流式而非轮询可获得更好的用户体验。轮询始终作为最小功能集支持。

### 持久化状态

规范要求声明支持任务的服务器必须持久化状态。在 ttl 内，崩溃不应丢失已完成的结果。存储方案从 SQLite 到 Redis 再到文件系统不等。第 13 课的实验环境使用文件系统。

### 取消语义

`tasks/cancel` 是幂等的。如果任务正在执行中，服务器会尝试停止（检查执行器协作取消）。如果已进入终态，请求为无操作。

### 崩溃恢复

当服务器进程重启时：

1. 加载所有持久化的任务状态。
2. 将任何进程已终止的 `working` 任务标记为 `failed`，错误信息为 `CRASH_RECOVERY`。
3. 在 ttl 内保留 `completed` / `failed` / `cancelled` 状态。

### 异步任务加采样

任务本身可以调用 `sampling/createMessage`。这就是长时运行的研究型任务的工作方式：服务器的任务线程根据需要采样客户端的模型，客户端的 UI 则将任务显示为 `working` 并附带周期性进度更新。

### 为什么这是实验性的

SEP-1686 于 2025 年 11 月 25 日发布，但更广泛的路线图指出了三个未解决的问题：持久化订阅原语、子任务（父子任务关系）以及结果 TTL 标准化。预计规范将在 2026 年持续演进。生产代码应仅将任务视为常见场景下的稳定功能，并为未来子任务相关的 SDK 变更做好防护。

## 使用

`code/main.py` 实现了一个持久化任务存储（基于文件系统）和一个在后台线程中运行的 `generate_report` 工具。客户端调用该工具，立即获得一个任务 ID，在工作线程更新进度时轮询 `tasks/status`，完成后获取 `tasks/result`。取消操作有效；崩溃恢复通过杀死工作线程并重新加载状态来模拟。

需要关注的内容：

- 任务状态 JSON 持久化到 `/tmp/lesson-13-tasks/<id>.json`。
- 工作线程更新 `progress` 字段；轮询可看到它逐步推进。
- 客户端取消操作设置一个事件；工作线程检查该事件并提前退出。
- "崩溃"后的状态重新加载将在途任务标记为 `failed` 并附带 `CRASH_RECOVERY`。

## 交付物

本课产出 `outputs/skill-task-store-designer.md`。给定一个长时运行的工具（研究、构建、导出），该技能设计任务存储（状态结构、ttl、持久化），选择正确的 taskSupport 标志，并草拟进度通知。

## 练习

1. 运行 `code/main.py`。启动一个 `generate_report` 任务，轮询状态，然后获取结果。

2. 在运行中途添加一个 `tasks/cancel` 调用。验证工作线程遵守取消请求并且状态变为 `cancelled`。

3. 模拟崩溃恢复：杀死工作线程，重启加载器，观察 `CRASH_RECOVERY` 失败模式。

4. 将存储扩展为 SQLite。持久化收益不变；查询选项更丰富（列出会话 X 的所有任务）。

5. 阅读 MCP 2026 路线图文章。找出最可能影响下一年 SDK API 设计的任务相关未解决问题。

## 关键术语

| 术语 | 常见说法 | 实际含义 |
|------|----------|----------|
| Task（任务） | "长时运行的工具调用" | 通过 `_meta.task` 增强以实现异步执行的请求 |
| SEP-1686 | "任务规范" | 于 2025 年 11 月 25 日新增任务的规范演进提案 |
| `_meta.task` | "任务信封" | 包含 id、state、ttl 的每请求元数据 |
| taskSupport | "工具标志" | 每个工具的 `forbidden` / `optional` / `required` |
| `tasks/status` | "轮询方法" | 获取当前状态和可选的进度提示 |
| `tasks/result` | "获取结果" | 返回完成后的负载，或未完成时返回 404 |
| `tasks/cancel` | "停止它" | 幂等的取消请求 |
| ttl | "保留预算" | 服务器承诺保留任务状态的毫秒数 |
| `notifications/tasks/updated` | "状态推送" | 服务器发起的状态变更事件 |
| Durable store（持久化存储） | "崩溃安全状态" | 文件系统 / SQLite / Redis 持久化层 |

## 扩展阅读

- [MCP — GitHub SEP-1686 issue](https://github.com/modelcontextprotocol/modelcontextprotocol/issues/1686) — 原始提案及完整讨论
- [WorkOS — MCP async tasks for AI agent workflows](https://workos.com/blog/mcp-async-tasks-ai-agent-workflows) — 附带设计理念的流程讲解
- [DeepWiki — MCP task system and async operations](https://deepwiki.com/modelcontextprotocol/modelcontextprotocol/2.7-task-system-and-async-operations) — 机制与状态机
- [FastMCP — Tasks](https://gofastmcp.com/servers/tasks) — SDK 级别的任务实现模式
- [MCP blog — 2026 roadmap](https://blog.modelcontextprotocol.io/posts/2026-mcp-roadmap/) — 未解决问题及 2026 年优先级（含子任务）