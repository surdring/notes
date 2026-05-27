# 综合项目 01 —— 终端原生编程 Agent

> 到 2026 年，编程 agent 的形态已经定型。一个 TUI 框架（Harness）、一个有状态的计划（Plan）、一个沙盒化的工具面（Tool Surface）、一个规划-执行-观察-恢复的循环。Claude Code、Cursor 3 和 OpenCode 在 50 英尺外看起来都一样。本综合项目要求你端到端构建一个 —— CLI 输入，pull request 输出 —— 并在 SWE-bench Pro 上对照 mini-swe-agent 和 Live-SWE-agent 进行度量。你将学到为何难点不在于模型调用，而在于工具循环、沙盒以及 50 轮运行的成本上限。

**类型：** 综合项目
**语言：** TypeScript / Bun（框架），Python（评估脚本）
**前置知识：** Phase 11（LLM 工程），Phase 13（工具与协议），Phase 14（Agent），Phase 15（自主系统），Phase 17（基础设施）
**涉及的 Phase：** P0 · P5 · P7 · P10 · P11 · P13 · P14 · P15 · P17 · P18
**时间：** 35 小时

## 问题

编程 agent 在 2026 年成为 AI 应用的主导类别。Claude Code（Anthropic）、Cursor 3（带有 Composer 2 和 Agent Tabs）、Amp（Sourcegraph）、OpenCode（112k stars）、Factory Droids 和 Google Jules 都发布了相同架构的变体：一个终端框架、一个权限工具面、一个沙盒，以及围绕前沿模型构建的规划-执行-观察循环。前沿很窄 —— Live-SWE-agent 在 SWE-bench Verified 上使用 Opus 4.5 达到 79.2% —— 但工程工艺宽广。大多数失效模式不是模型错误。它们是工具循环不稳定、上下文污染、失控的 token 成本，以及破坏性文件系统操作。

你无法从外部推理这些 agent。你必须构建一个，看着循环在第 47 轮因为 ripgrep 返回 8MB 匹配结果而崩溃，然后重建截断层。这就是本综合项目的意义。

## 概念

框架有四个面。**规划（Plan）** 维护一个 TodoWrite 风格的状态对象，模型每轮重写它。**执行（Act）** 分发工具调用（read、edit、run、search、git）。**观察（Observe）** 捕获 stdout / stderr / 退出码，截断，并将摘要反馈回去。**恢复（Recover）** 在不耗尽上下文窗口或无限循环的情况下处理工具错误。2026 年的形态增加了一个新元素：**钩子（Hooks）**。`PreToolUse`、`PostToolUse`、`SessionStart`、`SessionEnd`、`UserPromptSubmit`、`Notification`、`Stop` 和 `PreCompact` —— 可配置的扩展点，操作者在此注入策略、遥测和防护栏。

沙盒是 E2B 或 Daytona。每个任务在包含读写挂载 git worktree 的全新 devcontainer 中运行。框架永远不会接触宿主文件系统。worktree 在成功或失败后被拆除。成本控制在三层强制执行：每轮 token 上限、每会话美元预算和硬性轮数限制（通常 50）。可观测层是带有 GenAI 语义约定的 OpenTelemetry span，发送到自托管的 Langfuse。

## 架构

```
  user CLI  ->  harness (Bun + Ink TUI)
                  |
                  v
           plan / act / observe loop  <--->  Claude Sonnet 4.7 / GPT-5.4-Codex / Gemini 3 Pro
                  |                          (通过 OpenRouter，模型无关)
                  v
           tool dispatcher (MCP StreamableHTTP client)
                  |
     +------------+------------+----------+
     v            v            v          v
  read/edit    ripgrep     tree-sitter   git/run
     |            |            |          |
     +------------+------------+----------+
                  |
                  v
           E2B / Daytona sandbox  (worktree 隔离)
                  |
                  v
           hooks: Pre/Post, Session, Prompt, Compact
                  |
                  v
           OpenTelemetry -> Langfuse (spans, tokens, $)
                  |
                  v
           PR via GitHub app
```

## 技术栈

- 框架运行时：Bun 1.2 + Ink 5（终端中的 React）
- 模型访问：OpenRouter 统一 API，支持 Claude Sonnet 4.7、GPT-5.4-Codex、Gemini 3 Pro、Opus 4.5（用于最难的任务）
- 工具传输：模型上下文协议（MCP）StreamableHTTP（2026 修订版）
- 沙盒：E2B 沙盒（JS SDK）或 Daytona devcontainers
- 代码搜索：ripgrep 子进程，tree-sitter 解析器支持 17 种语言（预编译）
- 隔离：每个任务 `git worktree add`，成功/失败后清理
- 评估框架：SWE-bench Pro（verified 子集）+ Terminal-Bench 2.0 + 你自己的 30 任务留出集
- 可观测性：带有 `gen_ai.*` 语义约定的 OpenTelemetry SDK → 自托管 Langfuse
- PR 提交：GitHub App 带细粒度 token，范围限定目标仓库

## 构建步骤

1. **TUI 和命令循环。** 使用 Ink 搭建 Bun 项目。接受 `agent run <repo> "<task>"`。打印分割视图：计划窗格（顶部）、工具调用流（中部）、token 预算（底部）。在取消时添加 Ctrl-C，在退出前触发 `SessionEnd` 钩子。

2. **计划状态。** 定义一个类型化的 TodoWrite 模式（pending / in_progress / done 项目，带备注）。模型每轮作为工具调用重写完整状态 —— 不要让它增量式变更。将计划持久化到 `.agent/state.json`，以便崩溃后可以恢复。

3. **工具面。** 定义六个工具：`read_file`、`edit_file`（带 diff 预览）、`ripgrep`、`tree_sitter_symbols`、`run_shell`（带超时）、`git`（status / diff / commit / push）。通过 MCP StreamableHTTP 暴露，使框架传输无关。每个工具返回截断输出（每次调用上限 4k token）。

4. **沙盒包装。** 每个任务启动一个 E2B 沙盒。`git worktree add -b agent/$TASK_ID` 一个全新分支。所有工具调用在沙盒内执行。宿主文件系统不可达。

5. **钩子。** 实现全部八种 2026 年钩子类型。编写至少四个用户编写的钩子：(a) `PreToolUse` 破坏性命令守卫，阻止 worktree 外的 `rm -rf`，(b) `PostToolUse` token 计数，(c) `SessionStart` 预算初始化，(d) `Stop` 写入最终 trace 包。

6. **评估循环。** 克隆 SWE-bench Pro Python 的 30 问题子集。对你的框架运行。与 mini-swe-agent（最小基线）比较 pass@1、每任务轮数和每任务美元成本。将结果写入 `eval/results.jsonl`。

7. **成本控制。** 硬性上限：50 轮、200k 上下文、每任务 $5。`PreCompact` 钩子在 150k 标记处将较旧的轮次总结为先前状态块，为新的观察释放空间而不丢失计划。

8. **PR 提交。** 成功时，最后一步是 `git push` + 一个 GitHub API 调用，打开一个 PR，正文中包含计划和 diff 摘要。

## 使用方式

```
$ agent run ./my-repo "Fix the race condition in worker.rs"
[plan]  1 定位 worker.rs 并枚举 mutex 使用
        2 识别处于竞争状态的共享状态
        3 提出修复方案，验证测试
[tool]  ripgrep mutex.*lock -t rust           (44 matches, truncated)
[tool]  read_file src/worker.rs 120..180
[tool]  edit_file src/worker.rs (+8 -3)
[tool]  run_shell cargo test worker::          (passed)
[plan]  1 done · 2 done · 3 done
[done]  PR opened: #482   turns=9   tokens=38k   cost=$0.41
```

## 产出

可交付技能在 `outputs/skill-terminal-coding-agent.md` 中。给定一个仓库路径和任务描述，它在沙盒中运行完整的规划-执行-观察循环，并返回 PR URL 及 trace 包。本综合项目的评分标准：

| 权重 | 标准 | 度量方式 |
|:-:|---|---|
| 25 | SWE-bench Pro pass@1 vs 基线 | 你的框架 vs mini-swe-agent，在 30 个匹配的 Python 任务上 |
| 20 | 架构清晰度 | 规划/执行/观察分离、钩子面、工具模式 —— 对照 Live-SWE-agent 布局评审 |
| 20 | 安全性 | 沙盒逃逸测试、权限提示、破坏性命令守卫通过红队测试 |
| 20 | 可观测性 | Trace 完整性（100% 工具调用有 span），每轮 token 核算 |
| 15 | 开发者体验 | 冷启动 < 2s，崩溃恢复可重新开始计划，Ctrl-C 干净地取消中间工具调用 |
| **100** | | |

## 练习

1. 将底层模型从 Claude Sonnet 4.7 替换为在 vLLM 上服务的 Qwen3-Coder-30B。比较 pass@1 和每任务美元成本。报告开源模型在何处表现不佳。

2. 添加一个 `reviewer` 子 agent，在 PR 提交前读取 diff，并可请求修订循环。度量误报审查是否将 SWE-bench 通过率降至单 agent 基线以下（提示：通常会）。

3. 对沙盒进行压力测试：编写一个尝试 `curl` 外部 URL 的任务和一个在 worktree 外写入的任务。确认两者都被 PreToolUse 钩子阻止。记录尝试。

4. 使用较小模型（Haiku 4.5）实现 `PreCompact` 摘要。度量在 3 倍压缩下丢失的计划保真度。

5. 将 MCP StreamableHTTP 传输替换为 stdio。基准测试冷启动和每次调用延迟。为仅本地使用选择获胜者。

## 关键术语

| 术语 | 人们常说的 | 实际含义 |
|------|-----------|---------|
| 框架（Harness） | "Agent 循环" | 围绕模型的代码，分发工具调用、维护计划状态并执行预算 |
| 钩子（Hook） | "Agent 事件监听器" | 由框架在八种生命周期事件之一上运行的用户编写脚本 |
| Worktree | "Git 沙盒" | 在独立路径上的链接 git 检出版本；可丢弃而不影响主克隆 |
| TodoWrite | "计划状态" | 模型每轮重写的 pending/in-progress/done 项目类型化列表 |
| StreamableHTTP | "MCP 传输" | 2026 MCP 修订版：长连接 HTTP 连接，支持双向流；替代 SSE |
| Token 上限（Token Ceiling） | "上下文预算" | 每轮或每会话的 input+output token 上限；触发压缩或终止 |
| pass@1 | "单次尝试通过率" | 在首次运行且不重试或窥探测试集的情况下解决的 SWE-bench 任务比例 |

## 扩展阅读

- [Claude Code documentation](https://docs.anthropic.com/en/docs/claude-code) —— Anthropic 的参考框架
- [Cursor 3 changelog](https://cursor.com/changelog) —— Agent Tabs 和 Composer 2 产品说明
- [mini-swe-agent](https://github.com/SWE-agent/mini-swe-agent) —— SWE-bench 框架比较的最小基线
- [Live-SWE-agent](https://github.com/OpenAutoCoder/live-swe-agent) —— 使用 Opus 4.5 达到 79.2% SWE-bench Verified
- [OpenCode](https://opencode.ai) —— 开源框架，112k stars
- [SWE-bench Pro leaderboard](https://www.swebench.com) —— 本综合项目针对的评估基准
- [Model Context Protocol 2026 roadmap](https://blog.modelcontextprotocol.io/posts/2026-mcp-roadmap/) —— StreamableHTTP、能力元数据
- [OpenTelemetry GenAI semantic conventions](https://opentelemetry.io/docs/specs/semconv/gen-ai/) —— 工具调用和 token 使用的 span 模式