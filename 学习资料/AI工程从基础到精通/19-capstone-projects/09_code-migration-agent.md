# 综合项目 09 — 代码迁移 Agent（仓库级语言/运行时升级）

> Amazon 的 MigrationBench（Java 8 到 17）和 Google 的 App Engine Py2 到 Py3 迁移器设定了 2026 年的标准。Moderne 的 OpenRewrite 大规模进行确定性 AST 重写。Grit 使用 codemod 风格的 DSL 解决同样的问题。生产模式将两者结合：一个确定性基板用于安全重写，加上一个 Agent 层处理歧义情况，一个用于每个分支构建的沙箱，以及一个在打开 PR 前变绿的测试工具。本综合项目旨在迁移 50 个真实仓库，并发布通过率和失败分类法。

**类型：** 综合项目
**语言：** Python（agent）、Java / Python（目标）、TypeScript（仪表板）
**前置知识：** 阶段 5（NLP）、阶段 7（Transformer）、阶段 11（LLM 工程）、阶段 13（工具）、阶段 14（Agent）、阶段 15（自主系统）、阶段 17（基础设施）
**涵盖阶段：** P5 · P7 · P11 · P13 · P14 · P15 · P17
**时间：** 30 小时

## 问题

大规模代码迁移是 2026 年编码 Agent 最干净的生产应用之一。基础真相很明确（迁移后测试套件是否通过？），收益是真实的（一个 Java 8 机群迁移是一个人头规模的工程），基准测试是公开的（MigrationBench 50 仓库子集）。Moderne 的 OpenRewrite 处理确定性的一面。Agent 层处理 OpenRewrite 配方无法处理的一切：歧义重写、构建系统漂移、长尾语法、传递依赖断裂。

你将构建一个 Agent，接受一个 Java 8 仓库（或 Python 2 仓库）并生成一个 CI 变绿的迁移分支。你将衡量通过率、测试覆盖保持率、每个仓库的成本，并构建失败分类法。与仅确定性基线的并排对比会告诉你 Agent 的价值真正在哪里。

## 概念

管道有两层。**确定性基板（deterministic substrate）**（OpenRewrite 用于 Java，libcst 用于 Python）安全地运行大部分机械重写：导入、方法签名、空安全编辑、try-with-resources、废弃 API 替换。它很快并且产生可审计的差异。**Agent 层**（OpenAI Agents SDK 或在 Claude Opus 4.7 和 GPT-5.4-Codex 上运行的 LangGraph）处理配方无法处理的情况：构建文件升级（Maven/Gradle/pyproject）、传递依赖冲突、测试不稳定、自定义注解。

每个仓库获得一个 Daytona 沙箱，预装目标运行时。Agent 迭代：运行构建，分类失败，应用修复，重新运行。硬限制：每个仓库 30 分钟，8 美元，20 个 Agent 轮次。如果所有测试通过且覆盖差异不为负，该分支打开一个 PR。如果没有，该仓库被归档到带有证据的失败类别下。

失败分类法是交付物。在 50 个仓库中，什么出错了？传递依赖？自定义注解？构建工具版本？与迁移无关的测试不稳定？每个类别都有一个计数和一个示例差异。未来的配方作者可以针对前三名。

## 架构

```
目标仓库
      |
      v
OpenRewrite / libcst 确定性配方
   （安全、快速、可审计，~70-80% 的修复）
      |
      v
每个分支的 Daytona 沙箱
      |
      v
Agent 循环（Claude Opus 4.7 / GPT-5.4-Codex）：
   - 运行构建 -> 捕获失败
   - 分类失败（构建、测试、lint）
   - 应用修复（补丁或重试配方）
   - 重新运行
   - 预算：30 分钟，$8，20 轮次
      |
      v
测试 + 覆盖差异闸门
      |
      v（通过）
打开 PR
      |
      v（失败）
归档到失败类别 + 附带复现
```

## 技术栈

- 确定性基板：OpenRewrite（Java）或 libcst（Python）
- Agent：OpenAI Agents SDK 或在 Claude Opus 4.7 + GPT-5.4-Codex 上运行的 LangGraph
- 沙箱：每个分支的 Daytona 开发容器，预装目标运行时（Java 17 / Python 3.12）
- 构建系统：Maven、Gradle、uv（Python）
- 基准测试：Amazon MigrationBench 50 仓库子集（Java 8 到 17）、Google App Engine Py2 到 Py3 仓库
- 测试工具：并行运行器，通过 Jacoco（Java）或 coverage.py（Python）进行覆盖
- 可观测性：Langfuse + 每个仓库的追踪包，包含每个差异块
- 仪表板：失败分类仪表板，包含每个类别的计数和示例差异

## 构建步骤

1. **配方阶段。** 首先运行 OpenRewrite（Java）或 libcst（Python）配方。捕获 70-80% 的机械性迁移。以 "recipe" 提交进行提交。

2. **构建试用。** Daytona 沙箱：安装目标运行时，运行构建。如果通过，跳到测试。如果失败，交给 Agent。

3. **Agent 循环。** LangGraph 带工具：`run_build`、`read_file`、`edit_file`、`run_test`、`git_diff`。Agent 对失败进行分类（依赖、语法、测试、构建工具）并应用针对性修复。重新运行。

4. **预算上限。** 每个仓库 30 分钟墙钟时间，8 美元成本，20 个 Agent 轮次。任何超限都会停止，并以 "budget_exhausted" 归档当前差异。

5. **测试 + 覆盖闸门。** 构建通过后，运行测试套件。将覆盖率与基座仓库进行比较。如果覆盖率下降超过 2%，按 "coverage_regression" 归档。

6. **打开 PR。** 成功后，推送分支，打开带有差异摘要以及应用了哪些配方和 Agent 编写了哪些提交的 PR。

7. **失败分类法。** 对每个失败的仓库，标记类别：`dep_upgrade_required`、`build_tool_drift`、`custom_annotation`、`test_flake`、`syntax_edge_case`、`budget_exhausted`。构建仪表板。

8. **50 仓库运行。** 在 MigrationBench 子集上执行。报告每个类别的通过率、每个仓库的成本、覆盖保持率，以及与仅确定性基线的对比。

## 使用方式

```
$ migrate legacy-java-service --target java17
[recipe]   应用了 27 条重写（JUnit 4->5，HashMap initializer，try-with-resources）
[build]    失败：找不到符号 sun.misc.BASE64Encoder
[agent]    轮次 1 分类：removed_jdk_api
[agent]    轮次 2 应用：sun.misc.BASE64Encoder -> java.util.Base64
[build]    通过
[tests]    412/412 通过；覆盖率 84.1% -> 84.3%
[pr]       打开 #1841  成本=$3.20  轮次=4
```

## 交付标准

`outputs/skill-migration-agent.md` 是交付物。给定一个仓库，它执行确定性配方然后运行 Agent 循环以生成通过 CI 的迁移分支，或将仓库归档到分类法类别下。

| 权重 | 标准 | 衡量方式 |
|:-:|---|---|
| 25 | MigrationBench 通过率 | 50 仓库子集的 pass@1 |
| 20 | 测试覆盖保持 | 相比基座的平均覆盖差异 |
| 20 | 每个迁移仓库的成本 | 通过运行的每个仓库美元成本 |
| 20 | Agent / 确定性工具集成 | OpenRewrite 处理的修复比例 vs Agent 编写的修复比例 |
| 15 | 失败分析报告 | 带示例的分类法完整性 |
| **100** | | |

## 练习

1. 仅用 OpenRewrite（不使用 Agent）运行迁移管道。将通过率与完整管道进行比较。识别 Agent 单独发挥作用的情况。

2. 实现 "lint-clean" 检查：迁移后，运行风格检查器（Java 用 spotless，Python 用 ruff）。如果出现新的 lint 错误，PR 失败。衡量覆盖保持但风格退化的比率。

3. 添加 "最小差异" 优化器：Agent 的分支通过测试后，用第二遍修剪不必要的更改。报告差异大小缩减。

4. 扩展到第三种迁移：Node 18 到 Node 22。复用沙箱包装；将配方层替换为自定义 codemod。

5. 将首次绿色构建时间（TTFGB）作为 UX 指标进行衡量。目标：p50 低于 10 分钟。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|------------------------|
| 确定性基板（Deterministic substrate） | "配方引擎" | OpenRewrite / libcst：具有安全保证的声明式 AST 重写 |
| Codemod | "代码修改程序" | 机械地更改源代码的重写规则 |
| 构建漂移（Build drift） | "工具版本偏差" | 主要版本之间微妙的 Maven / Gradle / uv 行为变化 |
| 失败类别（Failure class） | "分类法桶" | 仓库未迁移的标记原因：依赖、语法、测试、构建工具、预算 |
| 覆盖差异（Coverage delta） | "覆盖保持" | 从基座到迁移分支的测试覆盖率百分比变化 |
| Agent 轮次（Agent turn） | "工具调用回合" | Agent 循环中的一个 计划 -> 行动 -> 观察 周期 |
| 预算耗尽（Budget exhaustion） | "触及上限" | 仓库在 30 分钟 / $8 / 20 轮次限制内用尽而未通过 |

## 延伸阅读

- [Amazon MigrationBench](https://aws.amazon.com/blogs/devops/amazon-introduces-two-benchmark-datasets-for-evaluating-ai-agents-ability-on-code-migration/) — 2026 年规范基准测试
- [Moderne.io OpenRewrite 平台](https://www.moderne.io) — 确定性基板参考
- [OpenRewrite 文档](https://docs.openrewrite.org) — 配方编写
- [Grit.io](https://www.grit.io) — 替代 codemod DSL
- [OpenAI 沙箱化迁移 cookbook](https://developers.openai.com/cookbook/examples/agents_sdk/sandboxed-code-migration/sandboxed_code_migration_agent) — Agents SDK 参考
- [Google App Engine Py2 到 Py3 迁移器](https://cloud.google.com/appengine) — 替代迁移基准
- [libcst](https://github.com/Instagram/LibCST) — Python 确定性基板
- [Daytona 沙箱](https://daytona.io) — 参考每个分支沙箱