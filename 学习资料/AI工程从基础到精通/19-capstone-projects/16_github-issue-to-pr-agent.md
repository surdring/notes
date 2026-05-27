# 综合项目 16 — GitHub Issue-to-PR 自主 Agent

> AWS Remote SWE Agents、Cursor Background Agents、OpenAI Codex cloud 和 Google Jules 都交付了相同的 2026 年产品形态：标记一个 issue，获得一个 PR。在云沙箱中运行 Agent，验证测试通过，并发布一个带有推理说明的待审查 PR。难点在于自动复现仓库的构建环境、防止凭据泄露、强制执行每个仓库的预算，以及确保 Agent 不能强制推送。本综合项目构建自托管版本，并在成本和通过率上与托管替代方案进行比较。

**类型：** 综合项目
**语言：** Python（agent）、TypeScript（GitHub App）、YAML（Actions）
**前置知识：** 阶段 11（LLM 工程）、阶段 13（工具）、阶段 14（Agent）、阶段 15（自主系统）、阶段 17（基础设施）
**涵盖阶段：** P11 · P13 · P14 · P15 · P17
**时间：** 30 小时

## 问题

异步云编码 Agent 是与交互式编码 Agent（综合项目 01）不同的独立产品类别。用户体验是一个 GitHub 标签。你给一个 issue 打上 `@agent fix this` 标签，一个工作进程在云沙箱中启动，克隆仓库，运行测试，编辑文件，验证，并打开一个 PR，其中 Agent 的推理说明在正文中。没有交互循环，没有终端。AWS Remote SWE Agents、Cursor Background Agents、OpenAI Codex cloud、Google Jules 和 Factory Droids 都汇聚于此。

工程挑战是具体的：环境复现（Agent 必须从零构建仓库，没有缓存的开发镜像）、不稳定测试（必须重新运行或隔离）、凭据范围限定（具有最小细粒度权限的 GitHub App）、每个仓库每日预算强制、以及无强制推送策略。本综合项目衡量通过率、成本和安全性与托管替代方案的对比。

## 概念

触发器是 GitHub webhook（issue 标签或 PR 评论）。调度器将工作入队到 ECS Fargate 或 Lambda。工作进程将仓库拉取到 Daytona 或 E2B 沙箱中，使用从仓库推断的通用 Dockerfile（语言、框架）。Agent 针对 Claude Opus 4.7 或 GPT-5.4-Codex 运行 mini-swe-agent 或 SWE-agent v2 循环。它迭代：读取代码，提出修复，应用补丁，运行测试。

验证是闸门步骤。完整的 CI 必须在沙箱中通过，然后才打开 PR。计算覆盖差异；如果超出阈值为负，PR 打开但被标记为 `needs-review`。Agent 将推理说明作为 PR 描述发布，加上一个 `@agent` 线程，审查者可以通过它进行后续操作。

安全性通过两个不同的 GitHub 表面来限定范围：App 提供一个具有 `workflows: read` 和窄仓库 contents/PR 范围的短期安装令牌；分支保护（而非应用权限）强制执行 "无直接写入 `main`" 和 "无强制推送"——应用永远不会被添加到绕过列表中。对 `.github/workflows` 的路径范围只读访问不是真正的 GitHub App 原语，因此 Agent 对文件编辑的允许列表必须在工作进程中强制执行。每个仓库每日预算上限在调度器处强制执行（例如，每个仓库每天最多 5 个 PR，每个 PR 20 美元）。

## 架构

```
GitHub issue 标记为 `@agent fix` 或 PR 评论
            |
            v
    GitHub App webhook -> AWS Lambda 调度器
            |
            v
    ECS Fargate 任务（或 GitHub Actions 自托管运行器）
       - 拉取仓库
       - 推断 Dockerfile（语言、包管理器）
       - Daytona / E2B 沙箱配合目标运行时
       - 克隆 -> git worktree -> agent 分支
            |
            v
    mini-swe-agent / SWE-agent v2 循环
       Claude Opus 4.7 或 GPT-5.4-Codex
       工具：ripgrep、tree-sitter、读/编辑、运行测试、git
            |
            v
    验证沙箱内 CI 通过 + 覆盖差异检查
            |
            v（已验证）
    git push + 通过 GitHub App 打开 PR
       PR 正文 = 推理说明 + 差异摘要 + 追踪 URL
       标签：needs-review
            |
            v
    运维人员审查；可以 @ 提及 Agent 进行后续操作
```

## 技术栈

- 触发器：带细粒度令牌的 GitHub App；通过 Lambda 或 Fly.io 接收 webhook
- 工作进程：ECS Fargate 任务（或 GitHub Actions 自托管运行器）
- 沙箱：每个任务的 Daytona 开发容器或 E2B 沙箱
- Agent 循环：mini-swe-agent 基线或在 Claude Opus 4.7 / GPT-5.4-Codex 上运行的 SWE-agent v2
- 检索：tree-sitter 仓库地图 + ripgrep
- 验证：沙箱内完整 CI + 覆盖差异闸门
- 可观测性：Langfuse 配合每个 PR 的追踪归档，从 PR 正文链接
- 预算：每个仓库每日美元上限；每个仓库每天最大 PR 数

## 构建步骤

1. **GitHub App。** 细粒度安装令牌：issues 读写、pull_requests 写入、contents 读写、workflows 读取。分支保护（唯一能做到这一点的表面）强制执行 "无直接推送 `main`" 和 "无强制推送"；应用不在绕过列表中。由于 GitHub App 权限不是路径范围的，工作进程在提议的差异上强制执行 "无写入 `.github/workflows`" 作为允许列表检查。

2. **Webhook 接收器。** Lambda 函数接受 issue 标签 / PR 评论 webhook。通过标签 `@agent fix this` 过滤。入队到 SQS。

3. **调度器。** 从 SQS 弹出任务。强制执行每个仓库每日预算。启动 ECS Fargate 任务，包含仓库 URL、issue 正文和一个全新的 Daytona 沙箱。

4. **环境推断。** 检测语言（Python、Node、Go、Rust）和包管理器（uv、pnpm、go mod、cargo）。如果不存在则即时生成 Dockerfile。

5. **Agent 循环。** mini-swe-agent 或 SWE-agent v2 配合 Claude Opus 4.7。工具：ripgrep、tree-sitter 仓库地图、read_file、edit_file、run_tests、git。硬限制：20 美元成本、30 分钟墙钟时间、30 个 Agent 轮次。

6. **验证。** 循环结束后，在沙箱中运行完整测试套件。通过 jacoco / coverage.py 计算覆盖差异。如果 CI 失败：停止，不打开 PR。如果覆盖率下降超过 2%：打开带有 `needs-review` 标签的 PR。

7. **PR 发布。** 推送 Agent 分支。通过 GitHub API 打开 PR，包含：标题、推理说明、差异摘要、追踪 URL、成本、轮次。

8. **凭据卫生。** 工作进程使用短期 GitHub App 安装令牌运行。日志在归档前清除密钥。

9. **评估。** 30 个不同难度的种子内部 issue。衡量通过率、PR 质量（差异大小、风格、覆盖）、成本、延迟。与 Cursor Background Agents 和 AWS Remote SWE Agents 在相同 issue 上进行比较。

## 使用方式

```
# 在 github.com 上
  - 用户将 issue #842 标记为 `@agent fix this`
  - 14 分钟后 PR #1903 出现
  - 正文：
    > 修复了由空比较器条目引起的 widget.dedupe() 中的 NPE。
    > 添加了回归测试 widget_test.go::TestDedupeNullComparator。
    > 覆盖差异：+0.12%
    > 轮次：7  成本：$1.80  追踪：langfuse:...
    > 标签：needs-review
```

## 交付标准

`outputs/skill-issue-to-pr.md` 是交付物。一个 GitHub App + 异步云工作进程，将标记的 issue 转换为待审查 PR，具有有界成本和限定范围凭据。

| 权重 | 标准 | 衡量方式 |
|:-:|---|---|
| 25 | 30 个 issue 上的通过率 | 端到端成功（CI 绿色 + 覆盖 OK） |
| 20 | PR 质量 | 差异大小、覆盖差异、风格一致性 |
| 20 | 每个已解决问题的成本和延迟 | 每个 PR 的美元和墙钟时间 |
| 20 | 安全性 | 限定范围令牌、每个仓库预算、无强制推送、凭据卫生 |
| 15 | 运维人员体验 | 推理说明评论、重试能力、@ 提及后续操作 |
| **100** | | |

## 练习

1. 添加 "修复不稳定测试" 模式：标签 `@agent stabilize-flake TestX` 在沙箱中运行测试 50 次，并提议一个使其稳定化的最小更改。

2. 在三个共享 issue 上比较成本 vs Cursor Background Agents。报告哪些工具在哪些方面胜出。

3. 实现预算仪表板：每个仓库每日成本、每个用户成本。对异常告警。

4. 构建 "试运行" 模式，打开一个草稿 PR 而不运行 CI，以便审查者可以廉价地检查计划。

5. 添加保留策略：未合并超过 7 天的 PR 分支自动删除。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|------------------------|
| GitHub App | "限定范围机器人身份" | 具有细粒度权限 + 短期安装令牌的应用 |
| 异步云 Agent（Async cloud agent） | "后台 Agent" | 在云沙箱而非终端中运行的非交互式工作进程 |
| 环境推断（Environment inference） | "Dockerfile 合成" | 检测语言 + 包管理器，如果缺少则生成 Dockerfile |
| 验证（Verification） | "沙箱内 CI" | 在打开 PR 之前在工作进程内运行完整测试套件 |
| 覆盖差异（Coverage delta） | "覆盖保持" | 从基座到 Agent 分支的测试覆盖率百分比变化 |
| 每个仓库预算（Per-repo budget） | "每日上限" | 在调度器处强制执行的美元和 PR 数量上限 |
| 推理说明（Rationale） | "PR 正文解释" | Agent 对什么发生了变化以及为什么的摘要；在 PR 正文中是必需的 |

## 延伸阅读

- [AWS Remote SWE Agents](https://github.com/aws-samples/remote-swe-agents) — 规范异步云 Agent 参考
- [SWE-agent](https://github.com/SWE-agent/SWE-agent) — CLI 参考
- [Cursor Background Agents](https://docs.cursor.com/background-agent) — 商业替代方案
- [OpenAI Codex (cloud)](https://openai.com/codex) — 托管竞品
- [Google Jules](https://jules.google) — Google 托管版本
- [Factory Droids](https://www.factory.ai) — 替代商业参考
- [GitHub App 文档](https://docs.github.com/en/apps) — 限定范围机器人身份
- [Daytona 云沙箱](https://daytona.io) — 参考沙箱