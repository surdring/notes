# 综合项目 05 — 自主研究 Agent（AI 科学家级）

> Sakana 的 AI-Scientist-v2 发表了完整论文。Agent Laboratory 运行了实验。Allen AI 分享了追踪记录。2026 年的形态是对实验进行计划-执行-验证树搜索（plan-execute-verify tree search），配合预算成本、沙箱化代码执行、视觉反馈 LaTeX 编写器，以及自动化 NeurIPS 风格评审器集合。本综合项目旨在构建一个这样的系统，以每篇论文不超过 30 美元的预算端到端运行，并通过 Sakana 记录的沙箱逃逸红队测试。

**类型：** 综合项目
**语言：** Python（agent + 沙箱）、LaTeX（输出）
**前置知识：** 阶段 2（机器学习）、阶段 3（深度学习）、阶段 7（Transformer）、阶段 10（从零构建 LLM）、阶段 14（Agent）、阶段 15（自主系统）、阶段 16（多 Agent）、阶段 18（安全）
**涵盖阶段：** P0 · P2 · P3 · P7 · P10 · P14 · P15 · P16 · P18
**时间：** 40 小时

## 问题

自主研究 Agent 在 2026 年跨过了一道门槛。Sakana AI 的 AI-Scientist-v2 在 Nature 上发表，其生成的论文通过了 workshop 同行评审。ShinkaEvolve（ICLR 2026）将该路线扩展到了演化假设。AMD 的 Agent Laboratory 发布了可复现的追踪记录。这些 Agent 并非魔法——它们是一个计划-执行-验证循环，在候选实验树、成本上限、种子限定的沙箱以及自动化评审上运行。其工艺在于循环、预算和安全故事。

你通过针对一个窄领域的种子想法（例如，在 1 亿参数 Transformer 上进行注意力稀疏性消融实验）来实现该循环，从而学习这门工艺。价值不在于第一次运行就发现新东西。价值在于基础设施：树搜索、实验沙箱、编写器-评审器循环、红队报告。Sakana 团队记录了沙箱逃逸失败案例；你的 Agent 必须通过同样的红队测试。

## 概念

该 Agent 是一种最佳优先树搜索（best-first tree search）。节点是实验规格：(假设, 配置, 代码, 预期结果)。展开（expand）步骤通过小幅编辑（更换优化器、调整批量大小、消融某个组件）提出子节点。每个子节点在具有硬资源限制的全新沙箱中运行。结果反馈给评分函数，该函数按 (新颖性 × 质量 × 剩余预算) 对节点进行排序。树持续增长直到预算耗尽，然后最佳分支被撰写成文。

编写器是多模态的。它生成 LaTeX 草稿，编译它，渲染图表，然后将渲染后的 PDF 反馈给 Claude Opus 4.7 的视觉模式，以对布局、图表可读性和声明-证据对齐进行评审。由五个 LLM 评审员组成的评审集合（reviewer ensemble）给出 NeurIPS 风格的评分（新颖性、严谨性、清晰度、可复现性、影响力）；如果平均分低于阈值，论文将带着评审意见返回给编写器。

安全是承重的。每个实验都在一个 E2B 或 Daytona 沙箱中运行，没有网络出口、有界墙钟时间和固定的资源限制。Agent 的代码生成步骤通过一个策略层，该层会阻止逃逸沙箱的系统调用。红队报告复现 Sakana 记录的攻击面（fork 炸弹、文件系统逃逸、LLM 编写的网络调用）。

## 架构

```
种子想法 + 领域
      |
      v
  文献搜索（Semantic Scholar + OpenAlex + FAISS 缓存）
      |
      v
  LangGraph 计划-执行-验证树
      |
      v
  +--- 展开节点 ----+      每个节点的沙箱
  |                 |      （E2B / Daytona）
  v                 v      资源上限
  子节点_1         子节点_k   无网络出口
  |                 |      确定性种子
  v                 v
  运行实验          运行实验
  |                 |
  v                 v
  按（新颖性, 质量, 预算）评分节点
      |
      v
  最佳分支 -> LaTeX 编写器
      |
      v
  编译 + 视觉评审（Opus 4.7 vision）
      |
      v
  评审集合（5 个 LLM 评审员，NeurIPS 评分标准）
      |
      v
  paper.pdf + review.md + trace.json
```

## 技术栈

- 编排：LangGraph，带检查点（checkpointing）和人工批准闸门
- 树搜索：自定义最佳优先搜索，覆盖实验节点（AB-MCTS 风格，源自 Sakana v2）
- 沙箱：每个实验使用 E2B，Docker-in-Docker 作为备选；通过 cgroups 进行资源限制
- 文献：Semantic Scholar Graph API + OpenAlex + 本地 FAISS 摘要缓存
- 编写器：LaTeX 模板 + Claude Opus 4.7（视觉模式）用于图表评审和布局
- 评审器：5 个评审员组成的集合（Opus 4.7、GPT-5.4、Gemini 3 Pro、DeepSeek R1、Qwen3-Max），加权聚合
- 实验框架：PyTorch 2.5 用于物理实验，W&B 用于日志记录
- 可观测性：Langfuse 用于 Agent 追踪，每篇论文硬预算 30 美元

## 构建步骤

1. **种子和领域范围界定。** 取一个种子想法（如"研究 10 亿参数以下 Transformer 注意力图中的稀疏模式"）。定义搜索空间：模型、数据集、计算预算。

2. **文献检索。** 查询 Semantic Scholar + OpenAlex 获取 50 篇最高引用相关论文；本地缓存摘要；生成 1 页领域摘要。

3. **树脚手架。** 用种子假设初始化根节点。实现 `expand(node) -> children`，生成小幅编辑提案（每个子节点一个配置变更）。实现 `score(node)` 作为加权的 新颖性 × 质量 × 预算项。

4. **沙箱包装。** 每个实验运行 `docker run --network=none --memory=8g --cpus=2 --pids-limit=256 --read-only`（或等效的 E2B 策略）。种子写入沙箱；输出以只读方式挂载回来。

5. **计划-执行-验证循环。** `plan` 提出子节点。`execute` 运行沙箱，捕获日志和指标。`verify` 对指标运行单元检查（损失是否降低？消融是否隔离了效果？）。失败的节点在树上记录失败原因。

6. **编写器。** 预算用完后，选择最佳分支。用 matplotlib 渲染图表。通过 Claude Opus 4.7 以上下文中的分支追踪记录生成 LaTeX 草稿。编译。将编译后的 PDF 反馈给 Opus 4.7 视觉模式进行评审。迭代。

7. **评审集合。** 五个评审员按 NeurIPS 风格评分标准在（新颖性、严谨性、清晰度、可复现性、影响力）上对草稿评分。如果均值 < 4.0/5，将草稿连同评审意见返回给编写器。3 次重写后硬停止。

8. **红队。** 构建或集成一组针对沙箱的对抗性任务：fork 炸弹、网络外泄尝试、文件系统逃逸、LLM 编写的 shell 元字符。确认全部被阻止。撰写发现报告。

9. **可复现性。** 每篇论文附带其树搜索追踪 JSON、种子、W&B 运行链接、沙箱配置，以及一个端到端复现的 README。

## 使用方式

```
$ ai-scientist run --seed "10亿参数以下Transformer中的注意力稀疏性" --budget 30
[lit]    50 篇论文，摘要生成耗时 12s
[tree]   展开 8 个节点，预算 12/30
[exec]   节点 #3 稀疏性=top-8，loss=2.83（目前最佳）
[exec]   节点 #6 稀疏性=top-4，loss=3.12（更差）
[exec]   ...
[tree]   选择以节点 #3 为根的分支（新颖性 0.62，质量 0.81）
[write]  LaTeX 草稿 v1 完成
[vision] 评审：图 2 图例太小，声明-证据对齐可接受
[write]  3 次编辑后草稿 v2
[review] 均值 4.2/5（新颖性 3.9，严谨性 4.3，清晰度 4.1，可复现性 4.5，影响力 4.2）
[done]   paper.pdf + review.md + trace.json     花费 $28.40
```

## 交付标准

`outputs/skill-ai-scientist.md` 是交付物。给定一个种子想法 + 一个领域 + 30 美元预算，它运行完整管道并产出一篇可评审的论文以及一个可复现套装。

| 权重 | 标准 | 衡量方式 |
|:-:|---|---|
| 25 | 论文质量 | 对照已发表 workshop 论文进行盲审评分 |
| 20 | 实验严谨性 | 基线、种子、消融实验；每个声明都有结果表中的单元格支撑 |
| 20 | 成本和计算纪律 | 每篇论文 30 美元上限强制执行，Langfuse 追踪 |
| 20 | 安全性 | 沙箱红队通过；网络策略和紧急停止开关已验证 |
| 15 | 可复现性 | 一条命令使用相同种子重新运行即可复现论文 |
| **100** | | |

## 练习

1. 在同一领域对三个不同的种子想法运行管道。比较树搜索的哪些部分重叠。识别重复浪费的计算。

2. 在估计成本超过 5 美元的节点实验执行前添加人机协作（human-in-the-loop）闸门。衡量总成本下降多少。

3. 将评审集合替换为单个评审员。在一组已知为差论文的保留集上衡量假通过率。

4. 引入网络外泄红队测试：Agent 编写尝试 `curl` 外部地址的代码。确认 `--network=none` 策略阻止了它。记录该尝试。

5. 将你的树搜索与扁平随机基线（相同预算，无展开策略）进行比较。报告新颖性 × 质量的增益。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|------------------------|
| 树搜索（Tree search） | "AB-MCTS 风格展开" | 对实验节点进行最佳优先探索，使用新颖性×质量×预算评分 |
| 沙箱（Sandbox） | "实验隔离" | 无网络、有界 CPU/内存、固定种子、只读输入的容器 |
| 视觉评审（Vision critique） | "渲染后阅读" | 将论文编译为 PDF，将 PDF 反馈给 VLM 进行布局和声明-证据评审 |
| 评审集合（Reviewer ensemble） | "自动化同行评审" | 多个 LLM 评审员按 NeurIPS 评分标准对论文评分；加权聚合决定管道闸门 |
| 新颖性评分（Novelty score） | "这是新的吗？" | 惩罚与 50 篇文献缓存接近程度的启发式方法 |
| 成本上限（Cost ceiling） | "预算" | 每篇论文总花费的硬上限；Langfuse 计数器 + 运行前估算 |
| 红队（Red team） | "沙箱逃逸审计" | 如果策略错误就会逃逸沙箱的对抗性任务 |

## 延伸阅读

- [Sakana AI-Scientist-v2 仓库](https://github.com/SakanaAI/AI-Scientist-v2) — 参考级生产研究 Agent
- [Sakana AI-Scientist-v1 论文 (arXiv:2408.06292)](https://arxiv.org/abs/2408.06292) — 原始方法论
- [ShinkaEvolve (Sakana ICLR 2026)](https://sakana.ai) — 演化扩展
- [Agent Laboratory (AMD)](https://github.com/SamuelSchmidgall/AgentLaboratory) — 多角色研究实验室框架
- [LangGraph 文档](https://langchain-ai.github.io/langgraph/) — 参考编排层
- [Semantic Scholar Graph API](https://api.semanticscholar.org/) — 文献搜索
- [E2B 沙箱](https://e2b.dev) — 参考实验隔离
- [NeurIPS 评审员指南](https://neurips.cc/Conferences/2026/Reviewer-Guidelines) — 评审集合编码的评分标准