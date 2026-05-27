# 人在回路中：提议-然后-提交

> 2026 年关于 HITL（Human-in-the-Loop）的共识是具体的。它不是"代理询问，用户点击批准"。它是提议-然后-提交（Propose-Then-Commit）：提议的操作持久化到带幂等键（Idempotency Key）的持久存储中；呈现给审查者，附带意图、数据谱系、触及的权限、影响范围和回滚计划；仅在正面确认后提交；执行后验证以确认副作用实际发生。LangGraph 的 `interrupt()` 加 PostgreSQL 检查点、Microsoft Agent Framework 的 `RequestInfoEvent` 和 Cloudflare 的 `waitForApproval()` 都实现相同形状。经典失败模式是橡皮图章批准：不审查就点击"批准"。有记录的缓解是带显式检查表的挑战-响应（Challenge-and-Response）。

**类型：** 学习
**语言：** Python（标准库，带幂等性的提议-然后-提交状态机）
**前置条件：** Phase 15 · 12（持久执行），Phase 15 · 14（绊网检测器）
**时间：** ~60 分钟

## 问题

代理采取一个操作。用户必须决定：批准与否。如果决定是即时的，可能不是审查。如果决定是结构化的，慢但值得信任。工程问题是如何使结构化审查成为阻力最小的路径。

2023 年时代的 HITL 模式是同步提示："代理想发送邮件给 X，内容为 Y——批准？"用户点击批准。每个人都觉得系统是安全的。在实践中，这种表面被严重橡皮图章化：用户快速批准，批准预测力很小，当代理出错时，审计追踪显示用户无法回忆的一长串批准历史。

2026 年模式——提议-然后-提交——将 HITL 移至持久基板，附加结构化元数据，并要求正面提交。每个托管代理 SDK 都交付一个版本：LangGraph `interrupt()`、Microsoft Agent Framework `RequestInfoEvent`、Cloudflare `waitForApproval()`。API 名称不同；形状相同。

## 概念

### 提议-然后-提交状态机

1. **提议（Propose）。** 代理产生提议的操作。持久化到持久存储（PostgreSQL、Redis、Durable Object）。包括：
   - 意图（代理为什么这样做）
   - 数据谱系（什么来源导致此提议）
   - 触及的权限（哪些范围 / 文件 / 端点）
   - 影响范围（最坏情况是什么）
   - 回滚计划（如果提交了，如何撤销）
   - 幂等键（每个提议唯一；重新提交返回相同记录）
2. **呈现（Surface）。** 审查者查看带有所有元数据的提议。审查者是人（不是代理自我审查）。
3. **提交（Commit）。** 正面确认。操作执行。
4. **验证（Verify）。** 执行后，副作用被回读并确认。如果验证步骤失败，系统处于已知不良状态，警报启动。

### 幂等键

没有幂等键，瞬时失败后的重试可能双重执行已批准的操作。具体例子：用户批准"从 A 转账 $100 到 B"。网络闪断。工作流重试。用户已批准一次但转账执行两次。幂等键将批准与一个唯一的副作用绑定；第二次执行是无操作。

这与 Stripe 和 AWS API 使用的幂等模式相同。将其复用于代理批准在 Microsoft Agent Framework 文档中明确出现。

### 持久性：为什么批准比进程更持久

批准等候室是代理不拥有的一块状态。工作流暂停（第 12 课）。当批准到达时，工作流从确切位置恢复。这就是为什么 LangGraph 将 `interrupt()` 与 PostgreSQL 检查点配对，而不仅是内存状态——两天后的批准仍能找到完整的工作流。

### 橡皮图章批准与挑战-响应缓解

HITL 的默认 UI（"批准"/"拒绝"按钮）产生快速批准而没有真正的审查。有记录的缓解：一个挑战-响应检查表，要求对特定问题的正面回答，才能启用批准按钮。具体形状：

- "你是否理解此操作触及什么资源？[ ]"
- "你是否已验证影响范围可接受？[ ]"
- "若此操作失败，你是否有回滚计划？[ ]"

不是为官僚主义而设——一种强制功能。无法勾选框的审查者要么请求澄清（升级），要么拒绝（安全默认）。Anthropic 的代理安全研究明确引用基于检查表的 HITL 作为橡皮图章批准模式的缓解。

### 什么算作后果性操作

并非每个操作都需要提议-然后-提交。2026 年指导：

- **后果性操作**（始终 HITL）：不可逆写入、金融交易、对外通信、生产数据库更改、破坏性文件系统操作。
- **可逆操作**（有时 HITL）：本地文件编辑、staging 环境更改、带清晰回滚的可逆写入。
- **读取和检查**（永不 HITL）：读取文件、列出资源、调用只读 API。

### 操作后验证

"提交已运行"不同于"副作用已发生"。网络分区和竞态条件可能产生一个认为成功的工作流而实际后端没有持久化。验证步骤在提交后重新读取目标资源以确认。这与带 `RETURNING` 子句的数据库事务或 `PutObject` 后执行 AWS `GetObject` 是相同的模式。

### EU AI Act 第 14 条

第 14 条要求欧盟高风险 AI 系统的有效人类监督。"有效"不是装饰性的。监管语言明确排除橡皮图章模式。在微软 Agent Governance Toolkit 合规文档中，带挑战-响应的提议-然后-提交是通过第 14 条审查的形状。

## 使用场景

`code/main.py` 在标准库 Python 中实现提议-然后-提交状态机。持久存储是一个 JSON 文件。幂等键是（thread_id, action_signature）的哈希。驱动程序模拟三种情况：干净的批准流程、瞬时失败后的重试（必须不双重执行），以及橡皮图章默认 vs 挑战-响应流程。

## 部署

`outputs/skill-hitl-design.md` 审查提议的 HITL 工作流的提议-然后-提交形状，并标记缺失的元数据、幂等性、验证或挑战-响应层。

## 练习

1. 运行 `code/main.py`。确认已批准提议的重试使用持久记录且不重新执行。现在更改幂等键以包含时间戳，显示重试双重执行。

2. 用 `rollback` 字段扩展提议记录。模拟执行失败、验证步骤失败的场景。显示回滚自动触发。

3. 阅读 Microsoft Agent Framework 的 `RequestInfoEvent` 文档。识别玩具引擎缺失而该 API 包含的一个元数据字段。添加它并解释它防御什么。

4. 为特定操作设计挑战-响应检查表（例如"发布到公开 Twitter 账号"）。审查者必须回答哪三个问题？为什么这三个？

5. 选一个同步"批准？"提示足够的情况（无需持久存储）。解释原因，并命名你接受的此类风险。

## 关键术语

| 术语 | 人们常说的 | 实际含义 |
|------|-----------|---------|
| 提议-然后-提交（Propose-then-Commit） | "两阶段批准" | 持久化提议 + 正面提交 + 验证 |
| 幂等键（Idempotency Key） | "重试安全 Token" | 每个提议唯一；第二次执行无操作 |
| 数据谱系（Data Lineage） | "它来自哪里" | 导致提议的具体来源内容 |
| 影响范围（Blast Radius） | "最坏情况" | 如果操作出错的影响范围 |
| 橡皮图章（Rubber-Stamp） | "快速批准" | 点击"批准"而无真正审查 |
| 挑战-响应（Challenge-and-Response） | "强制检查表" | 审查者必须正面确认特定问题 |
| RequestInfoEvent | "MS Agent Framework 原语" | 带结构化元数据的持久 HITL 请求 |
| `interrupt()` / `waitForApproval()` | "框架原语" | 相同形状的 LangGraph / Cloudflare 等价物 |

## 进一步阅读

- [Microsoft Agent Framework — 人在回路中](https://learn.microsoft.com/en-us/agent-framework/workflows/human-in-the-loop) — `RequestInfoEvent`、持久批准。
- [Cloudflare Agents — 人在回路中](https://developers.cloudflare.com/agents/concepts/human-in-the-loop/) — `waitForApproval()` 和 Durable Objects。
- [Anthropic — 实践中测量代理自主性](https://www.anthropic.com/research/measuring-agent-autonomy) — HITL 作为长周期风险的缓解。
- [EU AI Act — 第 14 条：人类监督](https://artificialintelligenceact.eu/article/14/) — 高风险系统的监管基线。
- [Anthropic — Claude 的宪法（2026 年 1 月）](https://www.anthropic.com/news/claudes-constitution) — 围绕监督的宪法框架。