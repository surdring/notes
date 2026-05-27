# 技能与 Agent SDK —— Anthropic Skills、AGENTS.md、OpenAI Apps SDK

> MCP 说"存在哪些工具"。技能说"如何完成一项任务"。2026 年的技术栈将两者叠加。Anthropic 的 Agent Skills（开放标准，2025 年 12 月）以 SKILL.md 形式发布，支持渐进式信息披露。OpenAI 的 Apps SDK 是 MCP 加上小部件元数据。AGENTS.md（现已在 60,000+ 仓库中采用）位于仓库根目录，作为项目级的 Agent 上下文。本课指出每种方案覆盖的内容，并构建一个跨 Agent 的迷你 SKILL.md + AGENTS.md 包。

**类型：** 学习
**语言：** Python（标准库，SKILL.md 解析器和加载器）
**前置要求：** Phase 13 · 07（MCP 服务器）
**时间：** ~45 分钟

## 学习目标

- 区分三个层次：AGENTS.md（项目上下文）、SKILL.md（可复用知识）、MCP（工具）。
- 编写带有 YAML 前置元数据和渐进式信息披露的 SKILL.md。
- 以文件系统方式将技能加载到 Agent 运行时中。
- 将技能与 MCP 服务器和 AGENTS.md 组合，使一个包可以在 Claude Code、Cursor 和 Codex 中使用。

## 问题

一位工程师将一个发布说明编写工作流程提炼为一个多步骤提示词："读取最新合并的 PR。按领域分组。逐个总结。按照团队风格编写 changelog 条目。发布到 Slack 草稿。"他们将其放在团队的 Notion 文档中。

现在他们想从 Claude Code、Cursor 和 Codex CLI 中使用此工作流程。每个 Agent 加载指令的方式不同：Claude Code 斜杠命令、Cursor 规则、Codex `.codex.md`。工程师将工作流程复制三次，维护三个副本。

AGENTS.md 和 SKILL.md 共同解决了这个问题：

- **AGENTS.md** 位于仓库根目录。每个兼容的 Agent 在会话启动时读取它。"这个项目如何工作？有哪些约定？哪些命令运行测试？"
- **SKILL.md** 是一个可移植的包：YAML 前置元数据（名称、描述）+ markdown 正文 + 可选的资源。支持技能的 Agent 按需按名称加载它们。
- **MCP**（Phase 13 · 06-14）处理技能需要调用的工具。

三个层次，一个可移植的制品。

## 概念

### AGENTS.md (agents.md)

2025 年底推出，截至 2026 年 4 月已被 60,000+ 仓库采用。仓库根目录下的一个文件。格式：

```markdown
# Project: my-service

## Conventions
- TypeScript with strict mode.
- Use Pydantic for models on the Python side.
- Tests run with `pnpm test`.

## Build and run
- `pnpm dev` for local dev server.
- `pnpm build` for production bundle.
```

Agent 在会话启动时读取此文件，并使用它来校准其对该项目的行为。2026 年的每个编程 Agent 都支持 AGENTS.md：Claude Code、Cursor、Codex、Copilot Workspace、opencode、Windsurf、Zed。

### SKILL.md 格式

Anthropic 的 Agent Skills（2025 年 12 月作为开放标准发布）：

```markdown
---
name: release-notes-writer
description: 按照本项目风格为最新合并的 PR 编写 changelog 条目。
---

# Release notes writer

When invoked, run these steps:

1. List PRs merged since the last tag. Use `gh pr list --base main --state merged`.
2. Group by label: feature, fix, chore, docs.
3. For each PR in each group, write one line: `- <title> (#<num>)`.
4. Draft the release notes and stage them in CHANGELOG.md.

If the user says "ship", run `git tag vX.Y.Z` and `gh release create`.

## Notes

- Never include commits without a PR.
- Skip "chore" entries from the public changelog.
```

前置元数据声明技能的身份。正文是技能加载时显示给模型的提示词。

### 渐进式信息披露

技能可以引用子资源，Agent 仅在需要时获取。示例：

```
skills/
  release-notes-writer/
    SKILL.md
    style-guide.md
    template.md
    scripts/
      generate.sh
```

SKILL.md 说"风格规则参见 style-guide.md。"Agent 仅在技能活跃运行时拉取 style-guide.md。这避免了用模型可能不需要的细节填充提示词。

### 文件系统发现

Agent 运行时扫描已知目录中的 SKILL.md 文件：

- `~/.anthropic/skills/*/SKILL.md`
- 项目 `./skills/*/SKILL.md`
- `~/.claude/skills/*/SKILL.md`

加载按文件夹名称和前置元数据中的 `name` 进行。Claude Code、Anthropic Claude Agent SDK 和 SkillKit（跨 Agent）都遵循此模式。

### Anthropic Claude Agent SDK

`@anthropic-ai/claude-agent-sdk`（TypeScript）和 `claude-agent-sdk`（Python）在会话启动时加载技能，将其作为运行时内的可调用"Agent"暴露。当用户调用时，Agent 循环将任务分发给技能。

### OpenAI Apps SDK

2025 年 10 月发布；直接构建在 MCP 之上。将 OpenAI 之前的 Connectors 和 Custom GPT Actions 统一在单一的开发者界面下。一个 Apps SDK 应用是：

- 一个 MCP 服务器（工具、资源、提示词）。
- 加上用于 ChatGPT UI 的小部件元数据。
- 加上用于交互界面的可选 MCP Apps `ui://` 资源。

相同的协议，更丰富的用户体验。

### 通过 SkillKit 实现的跨 Agent 可移植性

SkillKit 和类似的跨 Agent 分发层工具将单个 SKILL.md 翻译成 32+ AI Agent 的原生格式（Claude Code、Cursor、Codex、Gemini CLI、OpenCode 等）。一个真实来源；多个消费者。

### 三层技术栈

| 层次 | 文件 | 加载时机 | 目的 |
|-------|------|-------------|---------|
| AGENTS.md | 仓库根目录 | 会话启动时 | 项目级约定 |
| SKILL.md | skills 目录 | 技能被调用时 | 可复用的工作流程 |
| MCP 服务器 | 外部进程 | 需要工具时 | 可调用的操作 |

三者组合：Agent 在会话启动时读取 AGENTS.md，用户调用一个技能，技能的指令包含 MCP 工具调用，Agent 通过 MCP 客户端进行分发。

## 使用

`code/main.py` 提供了一个标准库的 SKILL.md 解析器和加载器。它发现 `./skills/` 下的技能，解析 YAML 前置元数据和 markdown 正文，并生成按技能名称索引的字典。然后它模拟一个按名称调用 `release-notes-writer` 的 Agent 循环。

需要关注的内容：

- YAML 前置元数据使用最简标准库解析器解析（不依赖 `pyyaml`）。
- 技能正文逐字存储；Agent 在调用时将其作为前缀附加到系统提示词。
- 渐进式信息披露通过一个 `read_subresource` 函数演示，该函数按需拉取引用的文件。

## 交付物

本课产出 `outputs/skill-agent-bundle.md`。给定一个工作流程，该技能生成组合的 SKILL.md + AGENTS.md + MCP 服务器蓝图包，可跨 Agent 移植。

## 练习

1. 运行 `code/main.py`。在 `skills/` 下添加第二个技能，确认加载器能发现它。

2. 为本课程仓库编写一个 AGENTS.md。包括测试命令、风格约定和 Phase 13 的心智模型。

3. 将团队内部文档中的多步骤工作流程移植到一个 SKILL.md 中。在 Claude Code 中验证其加载。

4. 手动将技能翻译成 Cursor 和 Codex 的原生规则格式。统计格式之间的差异 —— 这就是 SkillKit 自动化的翻译面。

5. 阅读 Anthropic Agent Skills 博客文章。找出 Claude Agent SDK 中本课加载器未涵盖的一个功能。（提示：Agent 子调用。）

## 关键术语

| 术语 | 常见说法 | 实际含义 |
|------|----------|----------|
| SKILL.md | "技能文件" | YAML 前置元数据加 markdown 正文，由 Agent 运行时加载 |
| AGENTS.md | "仓库根目录的 Agent 上下文" | 会话启动时读取的项目级约定文件 |
| Progressive disclosure（渐进式信息披露） | "懒加载子资源" | 技能正文引用仅在需要时才拉取的文件 |
| Frontmatter（前置元数据） | "顶部的 YAML 块" | `---` 定界符中的元数据（名称、描述） |
| Claude Agent SDK | "Anthropic 的技能运行时" | `@anthropic-ai/claude-agent-sdk`，加载技能并路由 |
| OpenAI Apps SDK | "MCP + 小部件元数据" | 基于 MCP 构建的 OpenAI 开发者界面，加 ChatGPT UI 钩子 |
| Skill discovery（技能发现） | "文件系统扫描" | 遍历已知目录寻找 SKILL.md，按名称索引 |
| Cross-agent portability（跨 Agent 可移植性） | "一个技能，多个 Agent" | 通过 SkillKit 风格的工具将一个 SKILL.md 翻译到 32+ Agent |
| Agent Skill | "可移植知识" | MCP 工具概念之外的可复用任务模板 |
| Apps SDK | "MCP 加 ChatGPT UI" | 在 MCP 上统一的 Connectors 和 Custom GPTs |

## 扩展阅读

- [Anthropic — Agent Skills announcement](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills) — 2025 年 12 月发布
- [Anthropic — Agent Skills docs](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview) — SKILL.md 格式参考
- [OpenAI — Apps SDK](https://developers.openai.com/apps-sdk) — 基于 MCP 的 ChatGPT 开发者平台
- [agents.md](https://agents.md/) — AGENTS.md 格式和采用列表
- [Anthropic — anthropics/skills GitHub](https://github.com/anthropics/skills) — 官方技能示例