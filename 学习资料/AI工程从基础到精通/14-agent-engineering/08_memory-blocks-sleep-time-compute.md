# 记忆块与休眠计算（Letta）

> MemGPT 在 2024 年变成了 Letta。2026 年的演进添加了两个思想：模型可以直接编辑的离散功能记忆块，以及一个在主 Agent 空闲时异步整合记忆的休眠 Agent。这就是你将记忆扩展到超越一次对话的方式。

**类型：** 构建
**语言：** Python（标准库）
**前置要求：** Phase 14 · 07（MemGPT）
**时间：** ~75 分钟

## 学习目标

- 说出 Letta 使用的三个记忆层次（core、recall、archival）以及每个层次的作用。
- 解释记忆块模式：Human 块、Persona 块和用户自定义块作为一等类型化对象。
- 描述什么是休眠计算，为什么它位于关键路径之外，以及为什么它可以运行比主 Agent 更强的模型。
- 实现一个脚本化的双 Agent 循环，主 Agent 提供响应，休眠 Agent 在轮次之间整合块。

## 问题

MemGPT（第 07 课）解决了虚拟内存的控制流。出现了三个生产级问题：

1. **延迟。** 每个记忆操作都在关键路径上。如果 Agent 必须在用户等待时进行修剪、摘要化或调和，尾部延迟会爆炸。
2. **记忆腐烂。** 写入不断累积。矛盾的事实保留。检索淹没在过时的内容中。
3. **结构丢失。** 扁平的存档存储无法表达"Human 块始终在提示词中；Persona 块始终在提示词中；Task 块按会话交换。"

Letta（letta.com）是 2026 年的重写。记忆块使结构显式化；休眠计算将整合移出关键路径。

## 概念

### 三个层次

| 层次 | 范围 | 所在位置 | 写入方 |
|------|------|----------|--------|
| Core（核心） | 始终可见 | 主提示词内部 | Agent 工具调用 + 休眠重写 |
| Recall（回忆） | 对话历史 | 可检索 | 自动轮次记录 |
| Archival（存档） | 任意事实 | 向量 + KV + 图 | Agent 工具调用 + 休眠摄取 |

Core 是 MemGPT 的核心。Recall 是对话缓冲区及其被逐出的尾部。Archival 是外部存储。这种划分清理了 MemGPT 的两层过载。

### 记忆块

一个块（block）是核心层的一个类型化、持久、可编辑的段落。原始 MemGPT 论文定义了两个：

- **Human 块** —— 关于用户的事实（名称、角色、偏好、目标）。
- **Persona 块** —— Agent 的自我概念（身份、语调、约束）。

Letta 泛化到任意用户自定义的块：一个 `Task` 块用于当前目标，一个 `Project` 块用于代码库事实，一个 `Safety` 块用于硬约束。每个块有一个 `id`、`label`、`value`、`limit`（字符上限）、`description`（这样模型知道何时编辑它）。

块可通过工具面编辑：

- `block_append(label, text)`
- `block_replace(label, old, new)`
- `block_read(label)`
- `block_summarize(label)` —— 压缩接近上限的块。

### 休眠计算

2025 年 Letta 的添加：在后台运行第二个 Agent，位于关键路径之外。休眠 Agent 处理对话转录和代码库上下文，将 `learned_context` 写入共享块，并整合或使存档记录失效。

随之而来的属性：

- **无延迟成本。** 主响应不等待记忆操作。
- **允许更强的模型。** 休眠 Agent 可以是更昂贵、更慢的模型，因为它不受延迟约束。
- **自然整合窗口。** 在用户不等待时进行去重、摘要化、使矛盾事实失效。

形态与人类的工作方式相匹配：你做任务，你睡一觉，长期记忆在夜间沉淀。

### Letta V1 与原生推理

Letta V1（`letta_v1_agent`，2026）废弃了 `send_message`/heartbeat 和内联 `Thought:` 令牌，改用原生推理。Responses API（OpenAI）和 Messages API with extended thinking（Anthropic）在独立通道上发出推理，跨轮次透传（在生产中跨提供商加密）。控制循环仍然是 ReAct。思考轨迹是结构化的，而非提示词形状的。

### 此模式出错的地方

- **块膨胀。** 无限的 `block_append` 迅速达到上限。在写入会超出限制时，在写入之前连接一个块摘要器。
- **静默漂移。** 休眠 Agent 重写了一个块，而主 Agent 从未注意。对块进行版本管理，并在轨迹中呈现差异。
- **被投毒的整合。** 休眠 Agent 将攻击者可接触的内容处理到核心中。第 27 课同样适用于休眠面。

## 构建

`code/main.py` 实现了：

- `Block` —— id、label、value、limit、description。
- `BlockStore` —— CRUD + `near_limit(label)` helper。
- 两个脚本化 Agent —— `PrimaryAgent` 服务一个轮次，`SleepTimeAgent` 在轮次之间整合。
- 轨迹显示一个带块写入的三轮对话，加上一个休眠操作，摘要化一个块并使一个过时事态失效。

运行：

```
python3 code/main.py
```

转录显示了分离：主轮次快速并产生原始写入；休眠操作压缩并清理。

## 使用

- **Letta**（letta.com）用于参考实现。自托管或托管云。
- **Claude Agent SDK 技能** 作为块形状的知识 —— 一个技能是一个命名的、版本化的、可检索的指令块，Agent 按需加载。
- **自定义构建** 适用于想要控制存储后端的团队。使用 Letta API 契约以便后续迁移。

## 交付物

`outputs/skill-memory-blocks.md` 为任何运行时生成一个 Letta 形态的块系统，带有休眠钩子，包括安全规则和引用连接。

## 练习

1. 添加一个 `block_summarize` 工具，当 `near_limit` 返回 true 时用模型生成的摘要替换块值。哪种触发阈值同时最小化摘要调用和块溢出？
2. 实现存档上的休眠时去重：文本有 >90% 令牌重叠的两条记录合并为一条。仅在休眠操作中进行，永远不在关键路径上。
3. 版本化块。在每次写入时记录旧值和差异。暴露 `block_history(label)`，使运维人员可以调试"Agent 为什么忘记了 X"。
4. 将休眠 Agent 视为不可信的写入者。当它们接触 Persona 或 Safety 块时，提交前需要第二个 Agent 审查。
5. 将示例移植到使用 Letta API（`letta_v1_agent`）。块 schema 中有什么变化，原生推理如何改变轨迹形态？

## 关键术语

| 术语 | 常见说法 | 实际含义 |
|------|----------|----------|
| Memory block（记忆块） | "可编辑的提示词段落" | 核心记忆中类型化、持久、LLM 可编辑的段落 |
| Human block（Human 块） | "用户记忆" | 关于用户的事实，固定在核心中 |
| Persona block（Persona 块） | "Agent 身份" | 自我概念、语调、约束，固定在核心中 |
| Sleep-time compute（休眠计算） | "异步记忆工作" | 第二个 Agent 在关键路径之外进行整合 |
| Core / Recall / Archival（核心/回忆/存档） | "层次" | 三层记忆划分：始终可见 / 对话 / 外部 |
| Block limit（块上限） | "容量限制" | 每个块的字符限制；强制进行摘要化 |
| Native reasoning（原生推理） | "思考通道" | 提供商级别的推理输出，而非提示词级别的 `Thought:` |
| Learned context（学习到的上下文） | "休眠输出" | 休眠 Agent 写入共享块的事实 |

## 扩展阅读

- [Letta, Memory Blocks blog](https://www.letta.com/blog/memory-blocks) — 块模式
- [Letta, Sleep-time Compute blog](https://www.letta.com/blog/sleep-time-compute) — 异步整合
- [Letta, Rearchitecting the Agent Loop](https://www.letta.com/blog/letta-v1-agent) — 原生推理重写
- [Packer et al., MemGPT (arXiv:2310.08560)](https://arxiv.org/abs/2310.08560) — 起源