# 群聊与发言人选择

> AutoGen GroupChat 和 AG2 GroupChat 在 N 个代理之间共享一个对话；一个选择器函数（LLM、轮询或自定义）决定谁下一个发言。这是涌现式多 Agent 对话的原型——代理不知道自己在静态图中的角色，它们只是对共享池做出反应。AutoGen v0.2 的 GroupChat 语义被保留在 AG2 分支中；AutoGen v0.4 将其重写为事件驱动的 Actor 模型。微软于 2026 年 2 月将 AutoGen 转入维护模式，并将其与 Semantic Kernel 合并到 Microsoft Agent Framework（RC 2026 年 2 月）。GroupChat 原语在 AG2 和 Microsoft Agent Framework 中都存续了——学一次，到处使用。

**类型：** 学习 + 构建
**语言：** Python（标准库）
**前置知识：** 第 16 阶段 · 04（原语模型）
**时间：** 约 60 分钟

## 问题

当工作流已知时，静态图（LangGraph）很棒。真实对话不是静态的：有时程序员问审查者，有时问研究员，有时问写作者。硬编码每个可能的交接会产生边的爆炸。你想要*代理对共享池做出反应*，由某个函数决定谁下一个发言。

这正是 AutoGen GroupChat 所做的。

## 概念

### 形状

```
              ┌─── 共享池 ────┐
              │ m1 m2 m3 ... │
              └─────────┬──────────┘
                        │ (每个人都读到全部)
      ┌───────┬─────────┼─────────┬───────┐
      ▼       ▼         ▼         ▼       ▼
    Agent A Agent B  Agent C  Agent D  选择器
                                           │
                                           ▼
                                  "下一个发言者 = C"
```

每个代理看到每条消息。每轮调用一个选择器函数来决定谁下一个发言。

### 三种选择器风格

**轮询（Round-Robin）。** 固定循环。确定性。以 N 线性扩展但忽略上下文——即使主题是法务审查，程序员也获得发言权。

**LLM 选择（LLM-Selected）。** 一次 LLM 调用，读取最近的池并返回最佳的下一个发言者。上下文感知但慢：每轮增加一次 LLM 调用。AutoGen 的默认设置。

**自定义（Custom）。** 一个包含任何逻辑的 Python 函数。典型：带有回退规则的 LLM 选择（例如，「程序员之后总是给验证者发言权」）。

### ConversableAgent API

```
agent = ConversableAgent(
    name="coder",
    system_message="你写 Python。",
    llm_config={...},
)
chat = GroupChat(agents=[coder, reviewer, tester], messages=[])
manager = GroupChatManager(groupchat=chat, llm_config={...})
```

`GroupChatManager` 持有选择器。当一个代理完成一轮时，管理者调用选择器，选择器返回下一个代理。循环继续直到终止条件。

### 终止

三种常见模式：

- **最大轮数。** 总轮数的硬上限。
- **「TERMINATE」令牌。** 代理可以发送一个哨兵消息；管理者在看到它时停止。
- **目标达成检查。** 每轮运行一个轻量级验证器，在完成时停止聊天。

### AutoGen → AG2 分裂与 Microsoft Agent Framework 合并

2025 年初，微软开始围绕事件驱动的 Actor 模型对 AutoGen（v0.4）进行重大重写。社区将 AutoGen v0.2 的 GroupChat 语义分支为 AG2，保留了早期采用者已集成的 API。

2026 年 2 月，微软宣布 AutoGen 将进入维护模式，事件驱动的 Actor 模型合并到 **Microsoft Agent Framework**（RC 2026 年 2 月，现与 Semantic Kernel 合并）。GroupChat 概念在两个方向中都存续；实现细节不同。AG2 是 v0.2 兼容代码的首选上游。

### 什么时候 GroupChat 合适

- **涌现对话。** 你不想预连线每个可能的下一个发言者。
- **角色混合任务。** 程序员问研究员，研究员问档案管理员，档案管理员回问程序员。流程不是 DAG。
- **探索性问题解决。** 想象「头脑风暴会议」，而非「流水线」。

### 什么时候失败

- **严格确定性。** LLM 选择器可能不一致。相同提示，不同运行，不同下一个发言者。
- **谄媚级联。** 代理屈从于说得最自信的那个。显式地反向提示。
- **上下文膨胀。** 每个代理读取每条消息；10 轮后上下文巨大。使用投影（第 15 课）来限定视图。
- **热点发言者（Hot Speaker）。** 一个代理主导对话，因为选择器偏爱其专业领域。将发言者平衡引入选择器特性。

### 群聊 vs 监督者

相同原语，不同默认值：

- 监督者：一个代理规划，其他代理执行。选择器是「询问规划者该做什么」。
- 群聊：所有代理都是对等方；选择器是共享池上的函数。

两者都使用第 04 课的四个原语。群聊默认为 LLM 选择的编排和全池共享状态。

## 构建

`code/main.py` 用标准库从零实现一个 GroupChat。三个代理（程序员、审查者、管理者），轮询和 LLM 选择变体，并在 `TERMINATE` 令牌上终止。

演示打印对话记录以及两种变体的选择器决策追踪。

运行：

```
python3 code/main.py
```

## 实践

`outputs/skill-groupchat-selector.md` 为给定任务配置 GroupChat 选择器——轮询 vs LLM 选择 vs 自定义，以及使用什么选择器输入（最近消息、代理专业领域、轮数）。

## 交付

检查清单：

- **最大轮数上限。** 总是。典型任务 10-20 轮。
- **发言者平衡指标。** 追踪每个代理的轮数；当不平衡超过阈值时发出警报。
- **终止令牌。** `TERMINATE` 或专用的验证者代理。
- **投影或限定记忆。** 约 10 条消息后，考虑只给每个代理限定视图以防止上下文膨胀。
- **选择器日志。** 对 LLM 选择的变体，记录选择器的输入和选择。否则调试是不可能的。

## 练习

1. 运行 `code/main.py`。比较轮询和 LLM 选择下的对话。每种情况下哪个代理占主导？
2. 在选择器中添加「每个代理最大发言次数」规则。它如何影响记录？
3. 实现目标达成终止：当审查者返回「已批准」时停止。它在轮次上限之前触发的频率如何？
4. 阅读 AutoGen 稳定文档中关于 GroupChat 的部分（https://microsoft.github.io/autogen/stable/user-guide/core-user-guide/design-patterns/group-chat.html）。识别 `GroupChatManager` 使用的默认选择器。
5. 阅读 AG2 仓库（https://github.com/ag2ai/ag2）并比较其 v0.2 GroupChat 与 v0.4 事件驱动版本。v0.4 添加了什么具体属性（吞吐量、容错、可组合性）？

## 关键术语

| 术语 | 人们说的 | 实际含义 |
|------|---------|---------|
| GroupChat | 「代理在一个聊天室」 | 共享消息池 + 选择器函数。AutoGen / AG2 原语。 |
| Speaker selection | 「谁下一个发言」 | 选择下一个代理的函数。轮询、LLM 选择或自定义。 |
| GroupChatManager | 「会议主持人」 | 拥有选择器并在轮次上循环的 AutoGen 组件。 |
| ConversableAgent | 「基础代理」 | AutoGen 基类；一个能发送和接收消息的代理。 |
| Termination token | 「停止词」 | 结束聊天的哨兵字符串（通常是 `TERMINATE`）。 |
| Hot speaker | 「一个代理占主导」 | 失败模式，选择器持续选择同一代理。 |
| Context bloat | 「池无限增长」 | 每个代理读取每条先前消息；上下文随轮次增长。 |
| Projection | 「限定视图」 | 共享池的角色特定视图，以防止上下文膨胀。 |

## 扩展阅读

- [AutoGen 群聊文档](https://microsoft.github.io/autogen/stable/user-guide/core-user-guide/design-patterns/group-chat.html) — 参考实现
- [AG2 仓库](https://github.com/ag2ai/ag2) — 社区 AutoGen v0.2 延续
- [Microsoft Agent Framework 文档](https://microsoft.github.io/agent-framework/) — 合并后的继任者，RC 2026 年 2 月
- [AutoGen v0.4 发布说明](https://microsoft.github.io/autogen/stable/) — 事件驱动 Actor 模型重写细节