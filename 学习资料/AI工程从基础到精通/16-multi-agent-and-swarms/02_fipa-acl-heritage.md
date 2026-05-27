# FIPA-ACL 与言语行为的历史遗产

> 在 MCP 之前，在 A2A 之前，有 FIPA-ACL。2000 年，IEEE 智能物理代理基金会（FIPA）批准了一个代理通信语言，包含二十个述行语（Performative）、两种内容语言和一套交互协议——合同网（Contract Net）、订阅/通知（Subscribe/Notify）、条件请求（Request-When）。它从产业中淡出，因为本体论（Ontology）开销对 Web 来说太重了，但 LLM 驱动的多代理系统复兴正在悄悄地重新实现同样的想法，只是没有形式语义：JSON 契约代替述行语，自然语言代替本体论。本课认真阅读 FIPA-ACL，让你看清 2026 年的哪些协议决策是重新发明，哪些是真正的创新，以及当前浪潮将在何处重新发现 2000 年代已经解决的问题。

**类型：** 学习
**语言：** Python（标准库）
**前置知识：** 第 16 阶段 · 01（为什么需要多 Agent）
**时间：** 约 60 分钟

## 问题

2026 年代理协议格局非常繁忙：MCP 用于工具，A2A 用于代理，ACP 用于企业审计，ANP 用于去中心化信任，NLIP 用于自然语言内容，加上 CA-MCP 和二十几个研究提案。每个规范都宣称自己是基础性的。

诚实的解读是，它们中的大多数都在重新发现一个非常具体的、已有二十年历史的决策树。Austin（1962 年）和 Searle（1969 年）的言语行为理论（Speech-Act Theory）告诉我们「话语即行动」。KQML（1993 年）将其转化为网络协议。FIPA-ACL（2000 年批准）产生了参考标准化：二十个述行语、内容语言 SL0/SL1、合同网和订阅/通知等交互协议。JADE 和 JACK 是 Java 参考平台。这一努力在 2010 年左右衰落，因为本体论开销太重，而且 Web 正在获胜。

当你看到 MCP 的 `tools/call`、A2A 的任务生命周期或 CA-MCP 的共享上下文存储时，你看到的是一个更柔和的、JSON 原生的 FIPA 决策的复刻。了解历史遗产告诉你两件事：哪些「创新」实际上是重新发明，以及哪些旧的失败模式新的规范将会重新发现。

## 概念

### 言语行为，用一段话概括

Austin 注意到有些句子不描述世界——它们改变世界。「我承诺。」「我请求。」「我宣布。」他称这些为述行话语（Performative Utterance）。Searle 将其形式化为五个类别：断言式（Assertive）、指令式（Directive）、承诺式（Commissive）、表达式（Expressive）、宣告式（Declarative）。KQML（Finin 等人，1993 年）使其对软件代理可操作：消息是述行语（动作）加上内容（动作针对什么）。FIPA-ACL 清理了 KQML 的缺陷，并围绕二十个述行语进行了标准化。

### 二十个 FIPA 述行语（部分列表）

| 述行语 | 意图 |
|---|---|
| `inform` | 「我告诉你 P 为真」 |
| `request` | 「我要求你做 X」 |
| `query-if` | 「P 为真吗？」 |
| `query-ref` | 「X 的值是什么？」 |
| `propose` | 「我提议我们做 X」 |
| `accept-proposal` | 「我接受提议」 |
| `reject-proposal` | 「我拒绝提议」 |
| `agree` | 「我同意做 X」 |
| `refuse` | 「我拒绝做 X」 |
| `confirm` | 「我确认 P 为真」 |
| `disconfirm` | 「我否认 P」 |
| `not-understood` | 「你的消息无法解析」 |
| `cfp` | 「征集关于 X 的提案」 |
| `subscribe` | 「当 X 变化时通知我」 |
| `cancel` | 「取消正在进行的 X」 |
| `failure` | 「我尝试了 X 但失败了」 |

完整列表在 `fipa00037.pdf`（FIPA ACL 消息结构）中。重点不是记住它——重点是每一个都对应 LLM 协议最终会重新添加的原语。

### 规范的 FIPA-ACL 消息

```
(inform
  :sender       agent1@platform
  :receiver     agent2@platform
  :content      "((price IBM 83))"
  :language     SL0
  :ontology     finance
  :protocol     fipa-request
  :conversation-id   conv-42
  :reply-with   msg-17
)
```

七个字段承载协议信封；一个字段（`content`）承载有效载荷。其余字段正是你每次把重试、线程和本体论拼接到 JSON 协议上时重新发明的东西。

### 两个历史平台

**JADE**（Java Agent DEvelopment Framework，Java 代理开发框架，1999-2020 年代）是最常用的 FIPA 兼容运行时。代理扩展一个基类，交换 ACL 消息，在容器内运行，并使用「行为（Behavior）」进行协调。交互协议库附带合同网、订阅/通知、条件请求和提议/接受。

**JACK**（Agent Oriented Software，商业产品）强调在 FIPA 消息之上的 BDI（信念-愿望-意图，Belief-Desire-Intention）推理。更形式化，但采纳更少。

两者都在 Web 技术栈吞噬了多代理用例后衰落。MCP 和 A2A 是 2026 年的运行时「容器」。

### 为什么 FIPA 衰落了

- **本体论开销**。FIPA 要求共享本体论来解析 `content`。就本体论达成一致是一个需要多年的标准过程。Web 只用 HTTP + JSON。
- **无人使用的形式语义**。SL（语义语言，Semantic Language）提供了严格的真值条件，但大多数生产系统使用自由格式内容而忽略形式化。
- **工具锁定**。JADE 仅支持 Java；JACK 是商业产品。多语言团队绕过两者。
- **互联网赢得了技术栈**。REST，然后是 JSON-RPC，然后是 gRPC 取代了 ACL 的传输层。

### LLM 复兴是 FIPA 的轻量版

比较一个 FIPA `request` 和一个 MCP `tools/call`：

```
(request                                {
  :sender  agent1                         "jsonrpc": "2.0",
  :receiver tool-server                   "method":  "tools/call",
  :content "(lookup stock IBM)"           "params":  {"name":"lookup_stock",
  :ontology finance                                   "arguments":{"symbol":"IBM"}},
  :conversation-id c42                    "id": 42
)                                        }
```

相同的信封，不同的语法。两者都承载：谁、对谁、意图、有效载荷、关联 ID。没有一个是相对于另一个的革命——它们是对同一设计的不同权衡。

Liu 等人 2025 年的综述（「A Survey of Agent Interoperability Protocols: MCP, ACP, A2A, ANP」，arXiv:2505.02279）明确指出了这一谱系：MCP 对应工具使用言语行为，A2A 对应代理对等言语行为，ACP 对应审计轨迹言语行为，ANP 对应去中心化身份扩展。新规范是具有 JSON 语法和更松散语义的 ACL 后代。

### 权衡，明说

**FIPA 给你而现代规范丢弃的：**

- 形式语义——你可以证明 `inform` 蕴含发送者相信其内容。
- 规范的述行语目录——你不需要重新争论「我们应该有 `cancel` 吗？」。
- 数十年的交互协议模式——合同网、订阅/通知、提议/接受——具有已知的正确性属性。

**现代规范给你而 FIPA 没有的：**

- JSON 原生有效载荷，兼容每个现代工具。
- LLM 可以解释的自然语言内容，无需手工编码的本体论。
- Web 技术栈传输（HTTP、SSE、WebSocket）。
- 通过自描述文档的能力发现（MCP `listTools`、A2A Agent Card）。

更松散意图语义换来更容易的实现。这就是确切的权衡。

### 值得移植的交互协议

FIPA 发布了约 15 个交互协议。三个值得带入 LLM 多代理系统：

1. **合同网协议（Contract Net Protocol，CNP）**。管理者发出 `cfp`（征集提案）；竞标者以 `propose` 回应；管理者接受/拒绝。这是规范的任务市场模式（第 16 阶段 · 16 谈判）。
2. **订阅/通知（Subscribe/Notify）**。订阅者发送 `subscribe`；发布者在主题变化时发送 `inform`。这是 2026 年的每个事件总线。
3. **条件请求（Request-When）**。「当条件 Y 成立时做 X。」带前置条件的延迟动作。2026 年对应的是持久工作流引擎中的延迟任务（第 16 阶段 · 22 生产扩展）。

每个都可以干净地映射到现代消息队列、HTTP + 轮询或 SSE 流。

### 去掉本体论会出什么问题

没有共享本体论，代理从自然语言内容中推断含义。已记录的 2026 年失败模式是**语义漂移（Semantic Drift）**：两个代理对微妙不同的概念使用同一个词（`"customer"`），接收方代理按错误解释行动，没有模式验证器捕获到。FIPA 的本体论要求会在解析时拒绝消息。

不完全回到完整本体论的缓解措施：

- 对 `content` 使用 JSON Schema——在传输层就拒绝结构错误。
- A2A 的类型化工件——拒绝错误模态。
- 信封中的显式述行语——即使内容是自然语言也使意图明确。

### 2026 规范，映射到言语行为遗产

| 现代规范 | FIPA 类比 | 保留了什么 | 丢弃了什么 |
|---|---|---|---|
| MCP `tools/call` | `request` | 显式意图，关联 ID | 形式语义，本体论 |
| MCP `resources/read` | `query-ref` | 显式意图，关联 ID | 形式语义 |
| A2A Task 生命周期 | contract-net + request-when | 异步生命周期，状态转换 | 形式完备性保证 |
| A2A 流事件 | subscribe/notify | 异步推送 | 类型化谓词订阅 |
| CA-MCP 共享上下文 | 黑板（Hayes-Roth 1985） | 多写入者共享内存 | 逻辑一致性模型 |
| NLIP | 自然语言内容 | LLM 原生 | Schema |

从上往下读这个表，模式是：保留结构原语，丢弃形式化，让 LLM 填补歧义。

## 构建

`code/main.py` 实现了一个纯标准库的 FIPA-ACL 翻译器。它编码和解码规范的 ACL 信封，并展示每个 MCP / A2A 消息形状如何归约为相同的七个字段。演示：

- 将五个 MCP 风格和 A2A 风格的消息编码为 FIPA-ACL。
- 将 FIPA-ACL 解码回现代等价物。
- 在两个管理者与三个竞标者之间运行一个玩具合同网谈判，使用 `cfp`、`propose`、`accept-proposal`、`reject-proposal`。

运行：

```
python3 code/main.py
```

输出是一个并排追踪，展示每条现代消息同时以其 2026 年 JSON 形式和 FIPA-ACL 形式出现，然后是对合同网竞标的一个往返。相同的协议原语在往返中幸存；只有语法不同。

## 实践

`outputs/skill-fipa-mapper.md` 是一个技能，读取任何代理协议规范并生成 FIPA-ACL 映射。在采用新协议之前用它来回答：「这真的是新的，还是带 JSON 语法的 `inform`？」

## 交付

不要复活 FIPA-ACL。复活它的检查清单：

- 每条消息的意图原语（述行语）是什么？
- 是否有用于请求-响应和取消的关联 ID？
- 是否有显式的内容语言（JSON-RPC、纯文本、结构化类型工件）？
- 交互协议是一等公民吗，还是你在从零开始重新实现合同网？
- 当两个代理对内容含义有分歧（语义漂移）时会发生什么？

在将任何新协议交付生产之前，记录这五个问题。

## 练习

1. 运行 `code/main.py`。观察往返编码。识别哪个 FIPA 述行语对应 `tools/call`、`resources/read` 和 A2A 任务创建。
2. 用 `cancel` 述行语扩展合同网演示，让管理者可以在竞标中途撤回任务。`cancel` 解决了仅靠重试无法解决的什么失败案例？
3. 阅读 FIPA ACL 消息结构（http://www.fipa.org/specs/fipa00037/）第 4.1-4.3 节。选择一个本课未涵盖的述行语，描述其现代 JSON-RPC 类比。
4. 阅读 Liu 等人，arXiv:2505.02279。对 MCP、A2A、ACP、ANP 中的每一个，列出它们保留和丢弃的 FIPA 述行语家族。
5. 为你自己系统中的 `request` 述行语的 `content` 字段设计一个最小 JSON-Schema。该模式给了你纯自然语言所没有的什么，代价是什么？

## 关键术语

| 术语 | 人们说的 | 实际含义 |
|------|---------|---------|
| 言语行为（Speech Act） | 「一个做了某事的话语」 | Austin/Searle：话语即行动。ACL 的理论源头。 |
| FIPA | 「那个旧 XML 东西」 | IEEE 智能物理代理基金会。2000 年标准化了 ACL。 |
| ACL | 「代理通信语言」 | FIPA 的信封格式：述行语 + 内容 + 元数据。 |
| 述行语（Performative） | 「动词」 | 消息的意图类别：`inform`、`request`、`propose`、`cfp` 等。 |
| KQML | 「FIPA 的前身」 | 知识查询与操作语言（1993 年）。更简单，更窄。 |
| 本体论（Ontology） | 「共享词汇」 | 内容语言所谈论概念的形式定义。 |
| SL0 / SL1 | 「FIPA 内容语言」 | 语义语言级别 0 和 1——形式内容语言家族。 |
| 合同网（Contract Net） | 「任务市场」 | 管理者发出 cfp；竞标者提议；管理者接受。规范的交互协议。 |
| 交互协议（Interaction Protocol） | 「消息模式」 | 具有已知正确性的述行语序列：request-when、subscribe-notify 等。 |

## 扩展阅读

- [Liu 等人 — 代理互操作性协议综述：MCP、ACP、A2A、ANP](https://arxiv.org/html/2505.02279v1) — 连接现代规范与 FIPA 遗产的规范 2025 年综述
- [FIPA ACL 消息结构规范（fipa00037）](http://www.fipa.org/specs/fipa00037/) — 批准于 2000 年的信封格式
- [FIPA 交际行为库规范（fipa00037）](http://www.fipa.org/specs/fipa00037/) — 完整的述行语目录
- [MCP 规范 2025-11-25](https://modelcontextprotocol.io/specification/2025-11-25) — `request`/`query-ref` 的现代工具使用等价物
- [A2A 规范](https://a2a-protocol.org/latest/specification/) — contract-net 和 subscribe-notify 的现代代理对等等价物