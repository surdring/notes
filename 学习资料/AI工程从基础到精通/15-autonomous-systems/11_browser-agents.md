# 浏览器代理与长周期 Web 任务

> ChatGPT agent（2025 年 7 月）将 Operator 和深度研究合并为一个浏览器/终端代理，在 BrowseComp 上取得 68.9% 的 SOTA。OpenAI 于 2025 年 8 月 31 日关闭了 Operator——产品层的整合。Anthropic 的 Vercept 收购将 Claude Sonnet 在 OSWorld 上从低于 15% 提升至 72.5%。WebArena-Verified（ServiceNow，ICLR 2026）修复了原始 WebArena 中 11.3 个百分点的假阴性率并交付了 258 任务的 Hard 子集。数字是真实的。攻击面也是真实的：OpenAI 的准备部门负责人公开表示对浏览器代理的间接提示注入"不是一个可以完全修补的 bug"。有记录的 2025-2026 攻击：Tainted Memories（Atlas CSRF）、HashJack（Cato Networks）以及 Perplexity Comet 中的一键劫持。

**类型：** 学习
**语言：** Python（标准库，间接提示注入攻击面模型）
**前置条件：** Phase 15 · 10（权限模式），Phase 15 · 01（长周期代理）
**时间：** ~45 分钟

## 问题

浏览器代理是一个读取不可信内容并采取后果性操作的长周期代理。代理访问的每个页面是用户未编写的输入。每个页面上的每个表单是潜在的命令通道。2025-2026 年攻击语料库显示这不是假设性的：Tainted Memories 让攻击者通过制作页面将恶意指令绑定到代理的记忆；HashJack 在代理访问的 URL 片段中隐藏命令；Perplexity Comet 劫持在一次点击中发生。

防御图景令人不安。OpenAI 的准备部门负责人公开说出了安静的部分：间接提示注入"不是一个可以完全修补的 bug"。这是因为攻击存在于代理的读取与行动边界中，这在架构上是模糊的——模型读取的每个 Token 在原则上都可能被读取为指令。

本课命名攻击面，命名基准测试格局（BrowseComp、OSWorld、WebArena-Verified），并建模最小间接提示注入场景，以便你可以在第 14 课和第 18 课中推理真实的防御。

## 概念

### 2026 年格局，每个系统一段话

**ChatGPT agent（OpenAI）。** 2025 年 7 月发布。统一了 Operator（浏览）和 Deep Research（数小时研究）。于 2025 年 8 月 31 日关闭了独立 Operator。BrowseComp 上 SOTA 68.9%；在 OSWorld 和 WebArena-Verified 上得分强劲。

**Claude Sonnet + Vercept（Anthropic）。** Anthropic 的 Vercept 收购专注于计算机使用能力。将 Claude Sonnet 在 OSWorld 上从 <15% 提升至 72.5%。Claude Computer Use 作为工具 API 交付。

**Gemini 3 Pro with Browser Use（DeepMind）。** Browser Use 集成交付计算机使用控制；FSF v3（2026 年 4 月，第 20 课）专门跟踪 ML 研发领域的自主性。

**WebArena-Verified（ServiceNow，ICLR 2026）。** 修复了一个有文档记录的问题：原始 WebArena 有约 11.3% 的假阴性率（任务被标记为失败但实际已解决）。Verified 版本用人工整理的成功标准重新评分，并添加了一个 258 任务的 Hard 子集（ICLR 2026 论文，openreview.net/forum?id=94tlGxmqkN）。

### BrowseComp vs OSWorld vs WebArena

| 基准测试 | 测量内容 | 时间周期 |
|---------|---------|---------|
| BrowseComp | 在开放 Web 上在时间压力下找到特定事实 | 分钟 |
| OSWorld | 代理操作完整桌面（鼠标、键盘、Shell） | 数十分钟 |
| WebArena-Verified | 模拟站点中的事务性 Web 任务 | 分钟 |
| Hard 子集 | 带多页面状态转换的 WebArena-Verified 任务 | 数十分钟 |

不同的轴。高 BrowseComp 分数表示代理能找到事实；不表示代理能预订航班。OSWorld 分数更接近"它能否在我的桌面上工作"。WebArena-Verified 更接近"它能否完成一个流程"。任何生产决策都需要匹配任务分布的基准测试。

### 攻击面，具体命名

1. **间接提示注入（Indirect Prompt Injection）。** 不可信页面内容包含指令。代理读取它们。代理执行它们。公开示例：2024 Kai Greshake 等人，2025 Tainted Memories 论文，2026 HashJack（Cato Networks）。
2. **URL 片段/查询注入。** 已爬取 URL 的 `#fragment` 或查询字符串包含命令。从不视觉渲染；仍在代理上下文中。
3. **记忆绑定攻击（Memory-Binding Attacks）。** 页面指示代理写入持久记忆（第 12 课涵盖持久状态）。下次会话，记忆在没有可见触发器的情况下触发负载。
4. **对认证会话的 CSRF 风格攻击。** Tainted Memories 类：代理在某处已登录；攻击者的页面发出代理用用户 Cookie 执行的状态更改请求。
5. **一键劫持（One-Click Hijack）。** 视觉无害的按钮携带代理跟随的负载。Comet 类。
6. **代理主机表面的内容安全策略漏洞。** 渲染和工具层本身可以是攻击向量；代理中浏览器栈范围广阔。

### 为什么"不完全可修补"

攻击与代理的能力同构。代理必须读取不可信内容来完成工作。代理读取的任何内容都可能包含指令。代理遵循的任何指令都可能与用户的实际请求失对齐。防御（信任边界、分类器、工具允许列表、后果性操作的 HITL）提高了攻击成本并减少了其影响范围。它们不闭合这一类别。

这与 Lob 定理（第 8 课）是相同的推理模式：代理不能证明下一个 Token 是安全的；它只能设置一个系统，让不安全的 Token 更可检测。

### 实际交付的防御姿态

- **读/写边界。** 读取永不是后果性的。写入（提交表单、发布内容、调用有副作用的工具）如果发起内容来自信任边界之外，则需要新的用户批准。
- **每个任务的工具允许列表。** 代理可以浏览；它不能发起电汇，除非该工具被显式启用于该任务。第 13 课涵盖预算。
- **会话隔离。** 浏览器代理会话仅以受限凭证运行。无生产认证，无个人邮箱。每次 HTTP 请求的日志保留用于审计。
- **内容净化器。** 获取的 HTML 在拼接进模型上下文前被剥离已知不良模式。（减少简单攻击；不阻止复杂负载。）
- **后果性操作上的 HITL。** 提议-然后-提交模式（第 15 课）。
- **记忆上的金丝雀 Token。** 如果记忆条目触发，用户看到它（第 14 课）。

## 使用场景

`code/main.py` 对三个合成页面建模微型浏览器代理运行。一个页面是良性的，一个在可见文本中有直接提示注入 blob，一个有 URL 片段注入（不可见但在代理上下文中）。脚本显示 (a) 朴素代理会做什么，(b) 读/写边界捕获什么，(c) 净化器捕获什么，(d) 两者都未捕获什么。

## 部署

`outputs/skill-browser-agent-trust-boundary.md` 界定提议的浏览器代理部署范围：它触及哪些信任区域，它被授权写什么，以及在首次运行前哪些防御必须就位。

## 练习

1. 运行 `code/main.py`。识别净化器捕获但读/写边界未捕获的攻击，以及只有读/写边界捕获的攻击。

2. 扩展净化器以检测一类 HashJack 风格的 URL 片段注入。测量在带有合法片段的良性 URL 上的误报率。

3. 选一个你知道的真实浏览器代理工作流（例如"预订航班"）。列出每一次读取和每一次写入。标记哪些写入需要 HITL 以及原因。

4. 阅读 WebArena-Verified ICLR 2026 论文。识别原始 WebArena 评分不可靠的一个任务类别，并解释 Verified 子集如何解决它。

5. 为浏览器代理设置设计记忆金丝雀。你会存储什么，在哪里，什么触发警报？

## 关键术语

| 术语 | 人们常说的 | 实际含义 |
|------|-----------|---------|
| 间接提示注入（Indirect Prompt Injection） | "不良页面文本" | 代理读取的页面中不可信内容包含代理执行的指令 |
| Tainted Memories | "记忆攻击" | 代理将攻击者提供的指令写入持久记忆；下次会话触发 |
| HashJack | "URL 片段攻击" | 负载隐藏在 URL 片段/查询字符串中，在代理上下文中但不可见渲染 |
| 一键劫持（One-Click Hijack） | "不良按钮" | 可见视觉元素携带代理执行的后续负载 |
| BrowseComp | "Web 搜索基准测试" | 在开放 Web 上找到特定事实；分钟级时间周期 |
| OSWorld | "桌面基准测试" | 完整 OS 控制；多步 GUI 任务 |
| WebArena-Verified | "修复的 Web 任务基准测试" | ServiceNow 重新评分的 WebArena，带 Hard 子集 |
| 读/写边界（Read/Write Boundary） | "副作用门控" | 读取永无后果；写入如果内容超出信任范围则需要新批准 |

## 进一步阅读

- [OpenAI — 介绍 ChatGPT agent](https://openai.com/index/introducing-chatgpt-agent/) — Operator 和深度研究的合并；BrowseComp SOTA。
- [OpenAI — 计算机使用代理](https://openai.com/index/computer-using-agent/) — Operator 谱系和成为 ChatGPT agent 的架构。
- [Zhou 等人 — WebArena](https://webarena.dev/) — 原始基准测试。
- [WebArena-Verified（OpenReview）](https://openreview.net/forum?id=94tlGxmqkN) — ICLR 2026 修复子集论文。
- [Anthropic — 实践中测量代理自主性](https://www.anthropic.com/research/measuring-agent-autonomy) — 包含计算机使用代理的攻击面讨论。