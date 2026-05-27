# 技能库与终身学习（Voyager）

> Voyager（Wang 等人，TMLR 2024）将可执行代码视为技能。技能是可命名的、可查询的、可组合的，并通过环境反馈进行精炼。这是 Claude Agent SDK 技能、skillkit 以及 2026 年技能库模式的参考架构。

**类型：** 构建
**语言：** Python（标准库）
**前置要求：** Phase 14 · 07（MemGPT），Phase 14 · 08（Letta 块）
**时间：** ~75 分钟

## 学习目标

- 说出 Voyager 的三个组件 —— 自动课程（automatic curriculum）、技能库（skill library）、迭代提示机制（iterative prompting）—— 以及每个组件的作用。
- 解释为什么 Voyager 将动作空间设为代码，而非原始指令。
- 实现一个带有注册、检索、组合和失败驱动精炼的标准库技能库。
- 将 Voyager 的模式映射到 2026 年 Claude Agent SDK 技能和 skillkit 生态系统。

## 问题

在每个会话中从零开始重建所有能力的 Agent 犯了三个错误：

1. **浪费令牌。** 每次任务都重新引出相同的推理。
2. **失去进展。** 在会话 A 中学到的修正不会转移到会话 B。
3. **在长视野组合任务上失败。** 复杂任务需要能力层次结构；一次性提示词无法表达。

Voyager 的答案：将每个可复用能力视为存储在库中的一个命名代码块，可通过相似度检索，可与其他技能组合，并通过执行反馈进行精炼。

## 概念

### 三个组件

Voyager（arXiv:2305.16291）围绕以下结构构建一个 Agent：

1. **自动课程。** 一个好奇心驱动的提出器，根据 Agent 当前的技能集和环境状态选择下一个任务。探索是自底向上的。
2. **技能库。** 每个技能是可执行代码。当任务成功时添加新技能。技能通过查询到描述的相似度来检索。
3. **迭代提示机制。** 在失败时，Agent 收到执行错误、环境反馈和自我验证输出，然后精炼技能。

Minecraft 评估（Wang 等人，2024）：相比基线多 3.3 倍独特物品、8.5 倍快速制作石质工具、6.4 倍快速制作铁质工具、2.3 倍更长的地图穿越距离。数字是 Minecraft 特定的，但模式是可迁移的。

### 动作空间 = 代码

大多数 Agent 发出原始指令。Voyager 发出 JavaScript 函数。一个技能是：

```
async function craftIronPickaxe(bot) {
  await mineIron(bot, 3);
  await mineStick(bot, 2);
  await placeCraftingTable(bot);
  await craft(bot, 'iron_pickaxe');
}
```

由子技能组成。按描述和嵌入键存储。作为程序检索，而非提示词。

这就是 2026 年 Claude Agent SDK 技能：一个命名的、可查询的代码块加指令，Agent 按需加载。

### 技能检索

新任务"制作钻石镐"。Agent：

1. 嵌入任务描述。
2. 查询技能库获取 top-k 相似技能。
3. 检索 `craftIronPickaxe`、`mineDiamond`、`placeCraftingTable` 等。
4. 从检索到的原语 + 新逻辑组合新技能。

这就是 MCP 资源（Phase 13）和 Agent SDK 技能实现的模式：在知识/代码面上的检索，范围限定到当前任务。

### 迭代精炼

Voyager 的反馈循环：

1. Agent 编写一个技能。
2. 技能针对环境运行。
3. 三种信号之一返回：`success`、`error`（带堆栈跟踪）、`self-verification failure`。
4. Agent 使用信号作为上下文重写技能。
5. 循环直到成功或达到最大轮次。

这是应用于代码生成的 Self-Refine（第 05 课），使用环境锚定验证。CRITIC（第 05 课）是使用外部工具作为验证器的相同模式。

### 课程与探索

Voyager 的课程模块根据 Agent 已有的和尚未完成的，提出"在湖边建造庇护所"等任务。提出器使用环境状态 + 技能库存选择略高于当前能力的任务 —— 探索的最佳点。

对于生产级 Agent，这转化为"缺少什么"操作符：给定当前技能库和一个领域，我们还缺少哪些技能？团队通常手动实现这个作为课程审查。

### 此模式出错的地方

- **技能库腐烂。** 同一个技能被添加了 10 次，描述略有不同。在写入时添加去重；检索只返回一个。
- **组合技能漂移。** 父技能依赖一个被精炼过的子技能。对技能进行版本管理；固定在 v1 的父技能不会神奇地获取 v3。
- **检索质量。** 当库增长超过几百项时，按技能描述的向量检索会退化。用标签过滤和硬约束（"仅 `category=tooling` 的技能"）补充。

## 构建

`code/main.py` 实现一个标准库技能库：

- `Skill` —— 名称、描述、代码（字符串）、版本、标签、依赖项。
- `SkillLibrary` —— 注册、搜索（令牌重叠）、组合（依赖的拓扑排序）和精炼（更新时版本递增）。
- 一个脚本化的 Agent，注册三个原语技能，组合第四个，遇到一次失败，然后精炼。

运行：

```
python3 code/main.py
```

轨迹显示库写入、检索、组合、一次失败执行和 v2 精炼 —— Voyager 循环的端到端。

## 使用

- **Claude Agent SDK 技能**（Anthropic） —— 2026 年参考：每个技能有描述、代码和指令；在 Agent 会话期间按需加载。
- **skillkit**（npm: skillkit） —— 32+ 个 AI 编码 Agent 的跨 Agent 技能管理。
- **自定义技能库** —— 领域特定（数据 Agent 的 SQL 技能，基础设施 Agent 的 Terraform 技能）。Voyager 模式可缩小使用。
- **OpenAI Agents SDK `tools`** —— 在低端；每个工具是一个轻量技能。

## 交付物

`outputs/skill-skill-library.md` 为任何目标运行时生成一个 Voyager 形态的技能库，连接注册、检索、版本管理和精炼。

## 练习

1. 向 `compose()` 添加依赖循环检测器。当技能 A 依赖 B，而 B 依赖 A 时，会发生什么？错误 vs 警告？
2. 实现对每个技能的版本固定。当父技能组合子技能 `crafting@1` 时，精炼到 `crafting@2` 不能静默升级父技能。
3. 将令牌重叠检索替换为 sentence-transformers 嵌入（或 BM25 标准库实现）。在 50 技能的玩具库上测量 retrieval@5。
4. 添加一个"课程"Agent：给定当前库和一个领域描述，提出 5 个缺失的技能。每周调用它。
5. 阅读 Anthropic 的 Claude Agent SDK 技能文档。将玩具库移植到 SDK 的技能 schema。关于可发现性有什么变化？

## 关键术语

| 术语 | 常见说法 | 实际含义 |
|------|----------|----------|
| Skill（技能） | "可复用能力" | 命名的代码块 + 描述，可通过相似度检索 |
| Skill library（技能库） | "Agent 的记忆-如何做" | 技能的持久存储，可搜索和可组合 |
| Curriculum（课程） | "任务提出器" | 由当前能力差距驱动的自底向上目标生成器 |
| Composition（组合） | "技能 DAG" | 调用其他技能的技能；执行时拓扑排序 |
| Iterative refinement（迭代精炼） | "自我修正循环" | 环境反馈 + 错误 + 自我验证反馈到下一个版本 |
| Action-space-as-code（动作空间即代码） | "程序化动作" | 发出函数而非原始指令，实现时间上扩展的行为 |
| Dedup on write（写入去重） | "技能折叠" | 近似重复的描述折叠为一个规范技能 |

## 扩展阅读

- [Wang et al., Voyager (arXiv:2305.16291)](https://arxiv.org/abs/2305.16291) — 原始技能库论文
- [Claude Agent SDK overview](https://platform.claude.com/docs/en/agent-sdk/overview) — 技能作为 2026 年产品化
- [Anthropic, Building agents with the Claude Agent SDK](https://www.anthropic.com/engineering/building-agents-with-the-claude-agent-sdk) — 实践中的技能和子 Agent
- [Madaan et al., Self-Refine (arXiv:2303.17651)](https://arxiv.org/abs/2303.17651) — Voyager 底层的精炼循环