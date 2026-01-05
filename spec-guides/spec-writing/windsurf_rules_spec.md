# Windsurf 编码工具规则规范（Rules / AGENTS.md）

## 1. 目的
本规范用于统一在 **Windsurf（Cascade）** 中编写与维护项目级“规则/指令”的方式，确保：
- 规则可被 Cascade 稳定遵守
- 团队编码风格与工程约束可版本化与可评审
- 规则粒度合适、可扩展、可迁移

## 2. Kiro Steering 规范能否用于 Windsurf？
结论：**“内容可以复用，机制需要改写。”**

- 可复用的部分：
  - 规则的组织思想（分领域、可追踪、强调安全红线、保持简洁、提供示例/反例）
  - 文件命名建议（语义明确、按领域拆分）
  - “像代码一样 review、定期维护”的治理策略

- 不可直接照搬的部分（需要改写为 Windsurf 的机制）：
  - **目录结构**：Kiro 使用 `.kiro/steering/`，Windsurf 的规则主要使用 `.windsurf/rules` 与 `AGENTS.md`
  - **生效方式**：Kiro 的 YAML `inclusion` front matter 不适用于 Windsurf；Windsurf 以 Rule 的 activation mode（Always on / Glob / Manual / Model decision）与 `AGENTS.md` 的目录作用域来控制
  - **限制**：Windsurf rules 文件有**长度限制（每个 rules 文件最多 12000 characters）**

## 3. Windsurf 的规则载体（官方机制）

### 3.1 AGENTS.md（目录作用域的“强指令”）
Windsurf 官方说明：创建 `AGENTS.md`（或 `agents.md`）后，Windsurf 会自动发现并将其作为对 Cascade 的指令。
- **根目录 `AGENTS.md`**：对整个仓库/工作区全局生效
- **子目录 `AGENTS.md`**：仅对该目录及其子目录下文件生效
- **无需 front matter**：纯 Markdown

适用场景（推荐）：
- 强制性规则（安全、代码风格、测试、提交要求）
- 目录特定规范（如 `frontend/`、`backend/`、`infra/`）

### 3.2 Rules（可配置激活方式的规则文件）
Windsurf 官方说明：Rules 支持全局与工作区级；工作区规则存放于 `.windsurf/rules`，可在多层目录出现并被自动发现。

#### Rules 存储位置（Rules Storage Locations）
- `.windsurf/rules` 位于当前工作区目录
- `.windsurf/rules` 位于工作区任意子目录
- 若是 git 仓库，向上搜索到 git root 的父目录路径中也会发现 `.windsurf/rules`

#### Rules 激活模式（Activation Modes）
Windsurf 官方列出了 4 种模式：
1. **Manual**：通过在对话框 `@mention` 手动启用
2. **Always On**：始终生效
3. **Model Decision**：根据你给的自然语言描述，由模型决定是否应用
4. **Glob**：对匹配 glob 的文件生效（例如 `*.js`、`src/**/*.ts`）

#### Rules 写作最佳实践（官方建议）
- 保持简单、简洁、具体
- 不要写泛化空话（如“写好代码”）
- 使用 Markdown 的列表、编号（比长段落更易遵循）
- 可用 XML 标签分组规则（便于模型理解与聚类）
- 单文件长度上限：**12000 characters**

## 4. Windsurf 规则分层策略（推荐实践）

### 4.1 “硬规则”放 AGENTS.md
- 例如：禁止引入未经批准的依赖、必须添加测试、必须遵循目录结构等。
- 通过目录放置实现作用域控制（全局 vs 子目录）。

### 4.2 “软规则/可选规则”放 .windsurf/rules
- Always on：通用编码习惯
- Glob：特定语言/框架/目录的规则
- Manual：排障指南、迁移 SOP、发布流程（不需要每次都加载）
- Model decision：适合描述性规则（比如“当你修改 API 层时，优先检查鉴权与错误模型”）

## 5. 命名与组织规范（建议）
- `.windsurf/rules/<domain>-<topic>.md`
  - 示例：
    - `typescript-style.md`
    - `api-error-contract.md`
    - `testing-standards.md`
    - `security-baseline.md`

## 6. 模板

### 6.1 全局 AGENTS.md 模板（放仓库根目录）
```markdown
# Project Rules (AGENTS)

## Non-negotiables
- Do not commit secrets.
- Prefer minimal diffs.
- Keep changes scoped to the request.

## Coding standards
- ...

## Testing
- ...
```

### 6.2 子目录 AGENTS.md 模板（例：frontend/AGENTS.md）
```markdown
# Frontend Rules

- Use <your framework> patterns.
- Keep components small.
- Tests: ...
```

### 6.3 Rules 文件模板（建议用于 Always on / Glob / Manual / Model decision）
> 具体的激活方式需要在 Windsurf 的 Rules 面板中选择（与文件内容配合）。

```markdown
# <Rule Title>

<coding_guidelines>
- ...
- ...
</coding_guidelines>

## Examples
- ...
```

## 7. 从 Kiro Steering 迁移到 Windsurf 的操作建议
- 将 Kiro 的“基础 steering 文件”思想迁移为：
  - 根目录 `AGENTS.md`（放最核心的约束/偏好）
  - 以及 `.windsurf/rules`（按 Glob/Manual/Always on 拆分）
- 若你已有 `.kiro/steering/product.md / tech.md / structure.md`：
  - 建议提炼成更短、更指令化的版本（不要整段人类文档原样搬运）
  - 为不同目录建立局部 `AGENTS.md`，减少全局噪声

## 8. 参考（官方文档）
- AGENTS.md：https://docs.windsurf.com/windsurf/cascade/agents-md
- Memories & Rules（Rules Discovery / Activation Modes / Best Practices）：https://docs.windsurf.com/windsurf/cascade/memories
- 示例规则目录（Windsurf 官方 curated templates）：https://windsurf.com/editor/directory
