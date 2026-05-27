# 谈判与讨价还价

> 代理就资源、价格、任务分配和条款进行谈判。2026 年基准集清晰：NegotiationArena（arXiv:2402.05863）显示 LLM 可通过角色操纵（「绝望」）将收益提高约 20%；「Measuring Bargaining Abilities」（arXiv:2402.15813）显示买方比卖方更难，规模无帮助——其 **OG-Narrator**（确定性报价生成器 + LLM 叙述者）将成交率从 26.67% 推至 88.88%；大规模自主谈判竞赛（Large-Scale Autonomous Negotiation Competition，arXiv:2503.06416）运行了约 18 万次谈判，并发现**思维链隐藏（Chain-of-Thought-Concealing）**代理通过向对手隐藏推理获胜；Bhattacharya 等人 2025 年关于哈佛谈判项目（Harvard Negotiation Project）指标的论文将 Llama-3 排为最有效、Claude-3 最具攻击性、GPT-4 最公平。本课实现合同网协议（Contract Net Protocol，FIPA 祖先，第 02 课），连接 LLM 风格的买方/卖方，运行 OG-Narrator 风格的分解，并测量成交率如何随每种结构性选择变化。

**类型：** 学习 + 构建
**语言：** Python（标准库）
**前置知识：** 第 16 阶段 · 02（FIPA-ACL 遗产）、第 16 阶段 · 09（并行集群网络）
**时间：** 约 75 分钟

## 问题

两个代理需要就价格达成一致。留给它们纯语言提示，2024-2026 年 LLM 以惊人的低率成交（在 arXiv:2402.15813 的严格参数化讨价还价中约 27%）。规模不能解决：GPT-4 在结构上不比 GPT-3.5 更擅长讨价还价；它在讨价还价的*语言*上更强。

根本问题是 LLM 混淆了两个任务——决定报价和叙述报价。OG-Narrator 将它们分离：确定性报价生成器计算数值移动；LLM 仅作叙述。成交率跃升至约 89%。

这镜像了一个经典多 Agent 发现：将机制（Mechanism）与通信层解耦获胜。合同网协议（Contract Net Protocol，FIPA 1996；Smith 1980）是参考任务市场机制。将 LLM 插入叙述槽位，你就得到了现代的 LLM 驱动任务市场。

## 概念

### 合同网，一句话

Smith 1980 年合同网协议：一个**管理者（Manager）**广播**提案征集（Call for Proposals，CFP）**；**投标者（Bidder）**以包含其报价的 **propose** 消息回应；管理者选取获胜者，向获胜者发送 **accept-proposal**，向失败者发送 **reject-proposal**。获胜者执行工作。可选消息：**refuse**（投标者拒绝提案）。FIPA 将其编入 `fipa-contract-net` 交互协议。

### 为什么 OG-Narrator 获胜

「Measuring Bargaining Abilities of Language Models」（arXiv:2402.15813）观察到：

- LLM 经常违反讨价还价规则（以荒谬价格报价，忽略对方的 ZOPA）。
- 它们锚定差（接受坏的首次报价；以象征性而非战略性金额还价）。
- 规模本身不能解决。更大模型产生更合理的语言，战略错误相似。

OG-Narrator 分解：

```
           ┌──────────────────┐        ┌──────────────────┐
  state  → │   报价生成器     │ price → │   LLM 叙述者     │ → message
           │   (确定性)       │        │  (撰写拟人化     │
           │                  │        │   伴随文本)      │
           └──────────────────┘        └──────────────────┘
```

报价生成器是经典谈判策略：Rubinstein 讨价还价模型、Zeuthen 策略或对价格的简单以牙还牙（Tit-for-Tat）。LLM 叙述。消息包含确定性价格和自然语言框架。

成交率跃升因为：
- 价格停留在讨价还价区间内。
- 锚定是战略性的，非情绪的。
- LLM 做了它擅长的事：写作。

### NegotiationArena 发现

arXiv:2402.05863 提供了规范基准。头条发现：

- LLM 可通过采用角色（「我迫切需要在周五前卖掉这个」）将收益提高约 20%——角色操纵是一种真实策略。
- 公平/合作的代理被对抗性代理利用；防御需要显式反击。
- 对称配对在约 40% 的基准场景上收敛到不平等结果。

这不是「LLM 是糟糕的谈判者」。而是「LLM 谈判太像人类了，包括可被利用的部分」。

### 思维链隐藏

大规模自主谈判竞赛（arXiv:2503.06416）在许多 LLM 策略上运行了约 18 万次谈判。获胜者对对手隐藏推理：

- 如果一个代理在公开可见的草稿纸上打印「我只会到 75 美元；我的保留价是 70 美元」，对手会读到它。
- 获胜者私下计算策略；输出通道只包含报价和必要的最少叙述。

这是 2026 年经典博弈论（Aumann 1976 关于理性与信息）的回响：披露你的私人估值会损失收益。LLM 不直觉这一点，愉快地在对手可见的推理追踪中键入它们的保留价。

工程要点：将私有草稿纸上下文与公开消息上下文分开。不是可选的。

### Bhattacharya 等人 2025——模型排名

在哈佛谈判项目指标（原则性谈判、BATNA 尊重、利益互惠）上：

- **Llama-3** 在达成交易上最有效（成交率 + 收益）。
- **Claude-3** 是最具攻击性的谈判者（高锚定、迟到让步）。
- **GPT-4** 是最公平的（配对间收益方差最小）。

这是 2025 年的快照。重点不是 2026 年 4 月哪个模型获胜——而是不同基础模型有持久的谈判风格。异构集成（第 15 课）将其作为多样性来源。

### 通过合同网 + LLM 进行任务分配

合同网对 LLM 多 Agent 的现代复用：

1. 管理者代理将任务分解为单元。
2. 向工作者代理广播带有任务描述的 `cfp`。
3. 每个工作者返回报价：`(价格, 预计时间, 置信度)`，其中价格可以是 token、计算单元或美元。
4. 管理者选取获胜者（单个或多个，取决于任务）并授予。
5. 被拒绝的工作者可以自由投标其他任务。

这可以很好地扩展到 100+ 个工作者，因为协调是广播-响应，而非同步聊天。用于生产：Microsoft Agent Framework 的编排模式、一些 LangGraph 实现。

### LLM-Stakeholders 交互式谈判

NeurIPS 2024（https://proceedings.neurips.cc/paper_files/paper/2024/file/984dd3db213db2d1454a163b65b84d08-Paper-Datasets_and_Benchmarks_Track.pdf）引入了多方可评分博弈，带有**秘密分数**和**最低接受阈值**。每个利益相关者有私有效用；LLM 必须从消息中推断它们。这是双人讨价还价到 N 方联盟形成（Coalition Formation）的泛化。对于具有异构工作者能力的生产任务市场相关。

### 叙述 vs 机制规则

在 2024-2026 年所有谈判基准中，一致的工程规则是：

> 让 LLM 叙述。不要让 LLM 计算报价。

如果报价需要是一个数字（价格、预计时间、数量），从谈判状态确定性生成，让 LLM 产生框架。如果报价需要是提案结构（任务分解、角色分配），让 LLM 起草，但在发送前根据 Schema 进行验证和约束检查。

## 构建

`code/main.py` 实现：

- `ContractNetManager`、`ContractNetTask`、`Bid`——管理者 + 投标者，广播 cfp、收集提案、授予。
- `og_narrator_bargain(state, rng)`——OG-Narrator 买方：确定性 Zeuthen 风格让步至中点。
- `seller_response(state, rng)`——确定性卖方还价策略（两种风格的结构性基准真相）。
- `naive_llm_bargain(state, rng)`——模拟全 LLM 讨价还价者：选价格有高方差，通常在 ZOPA 之外。
- 测量：1000 次试验的成交率，每次试验采样新的保留价。

运行：

```
python3 code/main.py
```

预期输出：朴素 LLM 成交率 ~65-75%；OG-Narrator 成交率 ~85-95%；15-25 分的差距是将报价生成从叙述分解的结构性优势。外加一个具有三个投标者和一个任务的合同网任务市场分配示例。

## 实践

`outputs/skill-bargainer-designer.md` 设计讨价还价协议：谁生成报价（确定性或 LLM）、谁叙述、私有草稿纸如何与公开消息分离，以及如何监控成交率。

## 交付

生产讨价还价检查清单：

- **分离草稿纸。** 私有状态永远不会到达对手的上下文。这是不可协商的。
- **确定性报价生成。** 价格、数量、预计时间：计算，不要提示。
- **验证所有传入报价**是否符合 Schema。在协议边界拒绝超出 ZOPA 的报价。
- **限制轮次。** 最多 3-5 轮；僵局时升级给调解人。
- **持续测量成交率和收益方差。** 下降的成交率是症状——通常是提示漂移或对手侧攻击。
- **记录所有被拒绝的提案**及其确定性理由。对于合同网管理者，失败的投标者需要理解原因。

## 练习

1. 运行 `code/main.py`。确认 OG-Narrator 在成交率上超过朴素 LLM。超过多少？
2. 实现**基于角色的收益提升**（arXiv:2402.05863）——买方仅在叙述中采用「本周迫切想买」角色，报价生成器不变。成交率或收益会改变吗？
3. 实现思维链**隐藏**：维护一个不传递给对手的私有草稿纸字符串。如果你意外泄漏会发生什么（通过交换通道模拟）？
4. 将合同网扩展到带保留价的 N 投标者拍卖。当投标全部超过保留价时，管理者如何在最低价和最高质量之间决定？你选择什么授予规则，为什么？
5. 阅读 Bhattacharya 等人 2025 关于哈佛谈判项目指标的论文。实现两个不同风格的讨价还价者（攻击性 vs 公平）。测量对称和非对称配对下的收益方差。

## 关键术语

| 术语 | 人们说的 | 实际含义 |
|------|---------|---------|
| Contract Net | 「任务市场」 | Smith 1980，FIPA 1996。cfp + propose + accept/reject。规范任务市场。 |
| ZOPA | 「可能协议区间」 | 买方最高价与卖方最低价之间的重叠。区间外的报价无法成交。 |
| BATNA | 「谈判协议的最佳替代方案」 | 如果此交易失败你的退路。设定你的保留价。 |
| OG-Narrator | 「报价生成器 + 叙述者」 | 分解：确定性报价，LLM 叙述。 |
| Zeuthen strategy | 「风险最小化让步」 | 经典报价生成器，根据风险限制让步。 |
| Rubinstein bargaining | 「交替报价均衡」 | 带有折现的无限期讨价还价的博弈论模型。 |
| CoT concealment | 「隐藏你的推理」 | arXiv:2503.06416 中获胜者保持私有草稿纸；公开通道仅显示报价。 |
| Persona manipulation | 「情绪化姿态」 | arXiv:2402.05863：约 20% 收益来自绝望/急迫等角色。 |

## 扩展阅读

- [NegotiationArena](https://arxiv.org/abs/2402.05863) — 基准；角色操纵和利用发现
- [Measuring Bargaining Abilities of Language Models](https://arxiv.org/abs/2402.15813) — OG-Narrator 和买方比卖方更难的结论
- [Large-Scale Autonomous Negotiation Competition](https://arxiv.org/abs/2503.06416) — 约 18 万次谈判；思维链隐藏获胜
- [LLM-Stakeholders 交互式谈判（NeurIPS 2024）](https://proceedings.neurips.cc/paper_files/paper/2024/file/984dd3db213db2d1454a163b65b84d08-Paper-Datasets_and_Benchmarks_Track.pdf) — 带有秘密效用的多方可评分博弈
- [Smith 1980 — 合同网协议](https://ieeexplore.ieee.org/document/1675516) — 经典机制，IEEE Transactions on Computers