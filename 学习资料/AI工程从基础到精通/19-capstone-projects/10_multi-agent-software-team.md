# 综合项目 10 — 多 Agent 软件工程团队

> SWE-AF 的工厂架构、MetaGPT 的基于角色的提示、AutoGen 0.4 的类型化 Actor 图、Cognition 的 Devin、以及 Factory 的 Droids 都在 2026 年汇聚成同一形态：一个架构师做规划，N 个编码员在并行工作树中工作，一个评审员把关，一个测试员验证。并行工作树将墙钟时间转化为吞吐量。共享状态和交接协议成为故障表面。本综合项目旨在构建这样一个团队，在 SWE-bench Pro 上评估，并报告哪些交接出错以及频率如何。

**类型：** 综合项目
**语言：** Python / TypeScript（Agent）、Shell（工作树脚本）
**前置知识：** 阶段 11（LLM 工程）、阶段 13（工具）、阶段 14（Agent）、阶段 15（自主系统）、阶段 16（多 Agent）、阶段 17（基础设施）
**涵盖阶段：** P11 · P13 · P14 · P15 · P16 · P17
**时间：** 40 小时

## 问题

单 Agent 编码工具在大型任务上遇到瓶颈。不是因为任何单个 Agent 能力弱，而是因为 20 万 Token 的上下文无法同时容纳架构计划、四个并行代码库切片、评审员评论和测试输出。多 Agent 工厂将问题拆分：架构师负责规划，编码员在并行工作树中负责实现，评审员把关，测试员验证。SWE-AF 的"工厂"架构、MetaGPT 的角色、AutoGen 的类型化 Actor 图——这三种框架描述了同一个形态。

故障表面在于交接（handoff）。架构师规划了编码员无法实现的内容。编码员产生冲突的差异。评审员批准了幻觉修复。测试员与仍在编写的编码员竞争。你将构建一个这样的团队，在 50 个 SWE-bench Pro 问题上运行它，跟踪每一次交接，并发布事后分析。

## 概念

角色是类型化 Agent。**架构师**（Claude Opus 4.7）读取问题，编写计划，并将其分解为具有显式接口的子任务。**编码员**（Claude Sonnet 4.7，N 个并行实例，每个在一个 `git worktree` + Daytona 沙箱中）独立实现子任务。**评审员**（GPT-5.4）读取合并后的差异并批准或请求具体更改。**测试员**（Gemini 2.5 Pro）在隔离环境中运行测试套件并报告通过/失败及产物。

通信通过共享任务板（文件支持或 Redis）进行。每个角色消费它被允许处理的任务。交接是 A2A 协议类型化的消息。协调关注点：合并冲突解决（协调者角色或自动三路合并）、共享状态同步（一旦编码员开始，计划就冻结；重新规划是单独事件）、以及评审员把关（评审员不能批准自己的更改或它提议的更改）。

Token 放大（token amplification）是隐藏成本。每个角色边界都会增加摘要提示和交接上下文。一次 40 轮次的单 Agent 运行在四个角色之间变成总共 160 轮次。评分标准特别权衡 Token 效率与单 Agent 基线，因为问题不是"多 Agent 是否有效"而是"它在每美元上是否胜出"。

## 架构

```
GitHub issue URL
      |
      v
架构师（Opus 4.7）
   读取问题，生成带子任务和接口的计划
      |
      v
任务板（文件 / Redis）
      |
   +-- 子任务 1 ---+-- 子任务 2 ---+-- 子任务 3 ---+-- 子任务 4 ---+
   v               v               v               v               v
编码员 A         编码员 B         编码员 C         编码员 D         （4 并行）
 （Sonnet）        （Sonnet）        （Sonnet）        （Sonnet）
 工作树 A         工作树 B         工作树 C         工作树 D
 Daytona          Daytona          Daytona          Daytona
      |                |                |                |
      +--------+-------+-------+--------+
               v
           合并协调者  （三路合并 + 冲突解决）
               |
               v
           评审员（GPT-5.4）
               |
               v
           测试员（Gemini 2.5 Pro） -> 通过？-> 打开 PR
                                    -> 失败？-> 路由回编码员
```

## 技术栈

- 编排：LangGraph 配合共享状态 + 每个 Agent 的子图
- 消息传递：A2A 协议（Google 2025）用于类型化 Agent 间消息
- 模型：Opus 4.7（架构师）、Sonnet 4.7（编码员）、GPT-5.4（评审员）、Gemini 2.5 Pro（测试员）
- 工作树隔离：每个编码员 `git worktree add` + Daytona 沙箱
- 合并协调者：自定义三路合并 + LLM 介导的冲突解决
- 评估：SWE-bench Pro（50 个问题）、SWE-AF 场景、HumanEval++ 用于单元测试
- 可观测性：Langfuse 配合角色标记的 span，每个 Agent 的 Token 统计
- 部署：K8s，每个角色作为一个独立的 Deployment + 基于积压的 HPA

## 构建步骤

1. **任务板。** 文件支持的 JSONL，包含类型化消息：`plan_request`、`subtask`、`diff_ready`、`review_needed`、`test_needed`、`approved`、`rejected`、`replan_needed`。Agent 订阅标签。

2. **架构师。** 读取 GitHub issue，使用 Opus 4.7 运行计划模板，要求显式子任务接口（涉及的文件、公共函数、测试影响）。发出一个带有子任务 DAG 的 `plan_request`。

3. **编码员。** N 个并行工作者，每个从任务板认领一个子任务。每个生成一个新的 `git worktree add` 分支加上一个 Daytona 沙箱。实现子任务。发出带有补丁 + 测试差异的 `diff_ready`。

4. **合并协调者。** 在所有编码员完成后，将 N 个分支三路合并到一个 staging 分支。LLM 介导的冲突解决仅在文件级重叠存在时才进行。

5. **评审员。** GPT-5.4 读取合并后的差异。不能批准它编写的差异。发出 `approved`（无需操作）或 `review_feedback`，带有路由回相关编码员的具体更改请求。

6. **测试员。** Gemini 2.5 Pro 在干净沙箱中运行测试套件。捕获产物。发出 `test_passed` 或带有堆栈追踪的 `test_failed`。失败的测试循环回拥有失败子任务的编码员。

7. **交接统计。** 每个跨角色边界的消息在 Langfuse 中获得一个 span，包含载荷大小和使用的模型。计算每个子任务的 Token 放大（编码员 Token + 评审员 Token + 测试员 Token + 架构师份额 / 编码员 Token）。

8. **评估。** 在 50 个 SWE-bench Pro 问题上运行。比较 pass@1 和 每个已解决问题美元成本 与单 Agent 基线（一个 Sonnet 4.7 在单个工作树中）。

9. **事后分析。** 对每个失败的问题，识别出错的交接（计划太模糊、合并冲突、评审员假批准、测试员不稳定）。生成交接失败直方图。

## 使用方式

```
$ team run --issue https://github.com/acme/widget/issues/842
[architect] 计划：4 个子任务（parser、cache、api、migration）
[board]     分派给并行工作树中的 4 个编码员
[coder-A]   子任务 parser  -> 42 行，测试本地通过
[coder-B]   子任务 cache   -> 88 行，测试本地通过
[coder-C]   子任务 api     -> 31 行，测试本地通过
[coder-D]   子任务 migration -> 19 行，测试本地通过
[merge]     三路合并：0 冲突
[reviewer]  对 cache 的评论（线程池大小）；路由到编码员 B
[coder-B]   修订：92 行；提交
[reviewer]  已批准
[tester]    全部 412 个测试通过
[pr]        打开 #3382   4 个编码员，1 次修订，$4.90，18m
```

## 交付标准

`outputs/skill-multi-agent-team.md` 是交付物。给定一个问题 URL 和并行级别，团队生成一个可合并的 PR，附带每个角色的 Token 统计。

| 权重 | 标准 | 衡量方式 |
|:-:|---|---|
| 25 | SWE-bench Pro pass@1 | 匹配 50 问题子集，pass@1 |
| 20 | 并行加速 | 墙钟时间 vs 单 Agent 基线 |
| 20 | 评审质量 | 注入缺陷探针上的假批准率 |
| 20 | Token 效率 | 每个已解决问题总 Token vs 单 Agent |
| 15 | 协调工程 | 合并冲突解决，交接失败直方图 |
| **100** | | |

## 练习

1. 在运行中向差异注入一个明显的缺陷（在主体前添加额外的 `return None`）。衡量评审员的假批准率。调整评审员提示直到假批准低于 5%。

2. 减少到两个编码员（架构师 + 编码员 + 评审员 + 测试员，编码员按顺序运行两个子任务）。比较墙钟时间和通过率。

3. 将合并协调者替换为单一写入者约束（子任务触及不相交的文件集）。衡量对架构师的规划负担。

4. 将评审员从 GPT-5.4 替换为 Claude Opus 4.7。衡量假批准率和 Token 成本差异。

5. 添加第五个角色：文档员（Haiku 4.5）。评审后，它生成一个变更日志条目。衡量文档质量是否证明了额外的 Token 花费。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|------------------------|
| 并行工作树（Parallel worktree） | "隔离分支" | `git worktree add` 为每个编码员生成全新的工作树 |
| 任务板（Task board） | "共享消息总线" | Agent 订阅的类型化消息的文件或 Redis 存储 |
| 交接（Handoff） | "角色边界" | 从一个角色上下文跨越到另一个角色的任何消息 |
| Token 放大（Token amplification） | "多 Agent 开销" | 跨角色的总 Token / 同一任务的单 Agent Token |
| A2A 协议 | "Agent 到 Agent" | Google 2025 规范用于类型化 Agent 间消息 |
| 合并协调者（Merge coordinator） | "集成器" | 运行三路合并并调解冲突的组件 |
| 假批准（False approval） | "评审员幻觉" | 评审员批准带有已知缺陷的差异 |

## 延伸阅读

- [SWE-AF 工厂架构](https://github.com/Agent-Field/SWE-AF) — 2026 年参考多 Agent 工厂
- [MetaGPT](https://github.com/FoundationAgents/MetaGPT) — 基于角色的多 Agent 框架
- [AutoGen v0.4](https://github.com/microsoft/autogen) — 微软的类型化 Actor 框架
- [Cognition AI (Devin)](https://cognition.ai) — 参考产品
- [Factory Droids](https://www.factory.ai) — 替代参考产品
- [Google A2A 协议](https://developers.google.com/agent-to-agent) — Agent 间消息传递规范
- [git worktree 文档](https://git-scm.com/docs/git-worktree) — 隔离基板
- [SWE-bench Pro](https://www.swebench.com) — 评估目标