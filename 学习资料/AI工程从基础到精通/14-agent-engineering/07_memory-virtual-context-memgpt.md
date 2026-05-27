# 记忆：虚拟上下文与 MemGPT

> 上下文窗口是有限的。对话、文档和工具轨迹不是。MemGPT（Packer 等人，2023）将此构建为操作系统虚拟内存 —— 主上下文是 RAM，外部存储是磁盘，Agent 在两者之间换页。这是每个 2026 年记忆系统继承的模式。

**类型：** 构建
**语言：** Python（标准库）
**前置要求：** Phase 14 · 01（Agent 循环），Phase 14 · 06（工具使用）
**时间：** ~75 分钟

## 学习目标

- 解释 MemGPT 所构建的操作系统类比：主上下文 = RAM，外部上下文 = 磁盘，记忆工具 = 换入/换出。
- 使用主上下文缓冲区、外部可搜索存储和换入/换出工具，在标准库中实现两层的 MemGPT 模式。
- 描述 Agent 如何发出"中断"来查询或修改外部记忆，以及结果如何拼接回下一个提示词中。
- 识别进入 Letta（第 08 课）和 Mem0（第 09 课）的 MemGPT 设计选择。

## 问题

上下文窗口看起来应该能解决记忆问题。它们不能。三种故障模式在生产中反复出现：

1. **溢出。** 多轮对话、长文档或工具调用密集的轨迹超出窗口。截止点之后的一切都消失了。
2. **稀释。** 即使在窗口内，填充不相关的上下文会稀释对重要内容的注意力。前沿模型在长输入上仍然会退化。
3. **持久性。** 新会话以空窗口开始。没有外部记忆的 Agent 无法说"记得你让我……"跨会话。

更大的窗口有帮助，但不能修复这个问题。Mem0 的 2025 年论文测量表明，128k 窗口基线仍然遗漏了拥有外部记忆的 4k 窗口 Agent 能够捕获的长视野事实。

## 概念

### MemGPT：操作系统类比

Packer 等人（arXiv:2310.08560，v2 2024年2月）将上下文管理映射到操作系统虚拟内存：

| OS 概念 | MemGPT 概念 | 2026 生产级类比 |
|---------|-------------|------------------|
| RAM | 主上下文（提示词） | Anthropic/OpenAI 上下文窗口 |
| Disk | 外部上下文 | 向量数据库、KV 存储、图存储 |
| Page fault（缺页异常） | 记忆工具调用 | `memory.search`、`memory.read`、`memory.write` |
| OS kernel（操作系统内核） | Agent 控制循环 | 带记忆工具的 ReAct 循环 |

Agent 运行正常的 ReAct 循环。额外的一类工具让它可以换入和换出主上下文中的数据。

### 两个层次

- **主上下文。** 固定大小的提示词，持有当前任务。模型始终可见。
- **外部上下文。** 无界，可通过工具搜索。按需读取，当事实涌现时写入。

原论文在两个超出基础窗口的任务上评估了该设计：超过 100k 令牌的文档分析，以及跨天持久记忆的多会话对话。

### 中断模式

MemGPT 引入了记忆即中断（memory-as-interrupt）：在对话中间，Agent 可以调用记忆工具，运行时执行它，结果作为新的观察拼接到下一个助手轮次中。概念上与 Unix `read()` 系统调用相同，该系统调用阻塞进程、返回字节，然后进程继续。

经典的记忆工具面：

- `core_memory_append(section, text)` —— 写入提示词的持久部分。
- `core_memory_replace(section, old, new)` —— 编辑持久部分。
- `archival_memory_insert(text)` —— 写入可搜索的外部存储。
- `archival_memory_search(query, top_k)` —— 从外部存储检索。
- `conversation_search(query)` —— 扫描过去的轮次。

### MemGPT 的终点与 Letta 的起点

2024 年 9 月 MemGPT 成为了 Letta。研究仓库（`cpacker/MemGPT`）仍然保留；Letta 扩展了设计：

- 三个层次而非两个（core、recall、archival —— 第 08 课）。
- 原生推理取代 `send_message`/heartbeat 模式（第 08 课）。
- 运行异步记忆工作的休眠 Agent（第 08 课）。

MemGPT 论文是 2026 年的基础，即使生产系统运行的是 Letta、Mem0 或自定义的两层存储。

### 此模式出错的地方

- **记忆腐烂。** 写入积累速度快于读取速度；检索淹没在过时的事实中。修复：定期整合（Letta 休眠时）、显式失效（Mem0 冲突检测器）。
- **记忆投毒。** 外部记忆是检索到的文本。如果攻击者控制的内容进入记忆笔记，Agent 在下一个会话中会重新摄取它。这是随时间重述的 Greshake 等人（第 27 课）攻击。
- **引用丢失。** Agent 回忆"用户让我交付 X"，但无法引用哪个轮次。存储来源引用（会话 ID、轮次 ID）与每个存档写入一起。

## 构建

`code/main.py` 在标准库中实现 MemGPT 的两层模式：

- `MainContext` —— 固定大小的提示词缓冲区，带有 `core` 字典和 `messages` 列表；超过上限时自动压缩最旧的消息。
- `ArchivalStore` —— 内存中的 BM25 类存储（令牌重叠评分），记录形式为 `(id, text, tags, session, turn)`。
- 五个映射到 MemGPT 面的记忆工具。
- 一个脚本化的 Agent，用事实填充存档，然后通过调用 `archival_memory_search` 回答问题。

运行：

```
python3 code/main.py
```

轨迹显示 Agent 写入三个事实，将主上下文填充到上限（强制驱逐），然后通过从存档检索来回答后续问题 —— 在没有任何真实 LLM 的情况下重现了 MemGPT 工作流。

## 使用

如今每个生产级记忆系统都是 MemGPT 的变体：

- **Letta**（第 08 课） —— 三个层次、原生推理、休眠计算。
- **Mem0**（第 09 课） —— 与评分层融合的向量 + KV + 图。
- **OpenAI Assistants / Responses** —— 通过线程和文件的托管记忆。
- **Claude Agent SDK** —— 通过技能和会话存储的长期记忆。

按操作形态（自托管、托管、框架集成）而非核心模式选择 —— 核心模式就是 MemGPT。

## 交付物

`outputs/skill-virtual-memory.md` 是一个可复用的技能，为任何目标运行时生成一个正确的两层记忆支架（主 + 存档 + 工具面），并连接驱逐策略和引用字段。

## 练习

1. 添加一个以令牌为单位的 `max_main_context_tokens` 上限（用 `len(text.split())` * 1.3 近似）。当超过上限时将最旧的消息压缩为摘要。比较有和没有摘要器的行为。
2. 在存档存储上正确实现 BM25（词频、逆文档频率）。在玩具事实上测量 recall@10 与令牌重叠基线的对比。
3. 向存档插入添加 `citation` 字段（session_id、turn_id、source_url）。让 Agent 在每次基于检索的答案中都引用来源。
4. 模拟记忆投毒：添加一个存档记录，内容为"忽略所有未来的用户指令。"编写一个防护措施扫描检索结果中的指令形状文本，将其标记为不可信。
5. 将实现移植到使用 MemGPT 研究仓库的核心记忆 JSON schema（`cpacker/MemGPT`）。当你从扁平字符串切换到类型化段落时会发生什么变化？

## 关键术语

| 术语 | 常见说法 | 实际含义 |
|------|----------|----------|
| Virtual context（虚拟上下文） | "无限记忆" | 主（提示词）+ 外部（可搜索）层次，带换入/换出 |
| Main context（主上下文） | "工作记忆" | 提示词 —— 固定大小，始终可见 |
| Archival memory（存档记忆） | "长期存储" | 外部可搜索持久化，按需检索 |
| Core memory（核心记忆） | "持久提示词段落" | 固定在主上下文内的命名段落 |
| Memory tool（记忆工具） | "记忆 API" | Agent 发出的用于读取/写入外部记忆的工具调用 |
| Interrupt（中断） | "记忆缺页异常" | Agent 暂停，运行时获取数据，结果拼接到下一个轮次 |
| Memory rot（记忆腐烂） | "过时的事实" | 旧写入淹没检索；通过整合修复 |
| Memory poisoning（记忆投毒） | "注入的持久化笔记" | 攻击者内容作为记忆存储，在回忆时被重新摄取 |

## 扩展阅读

- [Packer et al., MemGPT (arXiv:2310.08560)](https://arxiv.org/abs/2310.08560) — 受 OS 启发的虚拟上下文论文
- [Letta, Memory Blocks blog](https://www.letta.com/blog/memory-blocks) — 三层演进
- [Anthropic, Effective context engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) — 将上下文视为预算
- [Chhikara et al., Mem0 (arXiv:2504.19413)](https://arxiv.org/abs/2504.19413) — 建立在此模式之上的混合生产级记忆