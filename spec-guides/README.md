# spec-guides

本目录用于沉淀 **Spec 驱动开发（Requirements → Design → Tasks）** 的写作规范、工具规则（Windsurf 等）与示例，作为团队的“规范/模板/指南库”。

- 这里的内容是 **guides（方法与规范）**，相对稳定。
- 你项目的 **真实 specs（随需求迭代的需求/设计/任务文档）**建议放在仓库统一位置（例如仓库根目录 `specs/` 或 `docs/specs/`），避免与指南混在一起。

## 目录结构

```text
spec-guides/
  README.md
  spec-writing/               # spec 文档写作规范与模板（以 Kiro 的三段式思路为蓝本）
    kiro_requirements_spec.md
    kiro_design_spec.md
    kiro_tasks_spec.md
    kiro_task_execution_spec.md
    kiro_steering_spec.md
    windsurf_rules_spec.md

  examples/                   # 示例（供参考/拷贝，不建议当作项目真实 specs 的长期存放地）
    study-copilot/
      study-copilot-driven-requirements.md
      study-copilot-template.md
    vertical-ai-framework/
      requirements.md
      design.md
      tasks.md
      tasks-prompts-optimized.md

  steering/                   # 可直接用于工具/团队协作的“规则片段”（按需引用/迁移）
    chinese-response.md
    coding-standards.md
    rule.md

  tools/                      # 工具相关的进一步拆分（可选，当前为空）
```

## 如何使用（推荐流程）

### 1) 写一个新的 Spec（面向本项目）
- 在你的项目 specs 目录（例如仓库根目录 `specs/<feature>/`）创建：
  - `requirements.md`
  - `design.md`
  - `tasks.md`

- 写作时参考本仓库的规范：
  - **需求写法**：`spec-writing/kiro_requirements_spec.md`
  - **设计写法**：`spec-writing/kiro_design_spec.md`
  - **任务拆分与追踪**：`spec-writing/kiro_tasks_spec.md`
  - **任务执行方式**：`spec-writing/kiro_task_execution_spec.md`

> 注：这些文件名前缀为 `kiro_`，表示其来源思路参考了 Kiro 的三段式 workflow；并不要求你实际使用 Kiro 工具。

### 2) 为编码工具配置规则（Windsurf）
- Windsurf 规则机制与写作规范参考：
  - `spec-writing/windsurf_rules_spec.md`

建议落地方式：
- 在项目仓库根目录或相关子目录放置 `AGENTS.md`（目录作用域）。
- 在项目中创建 `.windsurf/rules/` 并按需拆分规则文件。

### 3) 参考示例
- `examples/` 下提供示例 specs（用于学习、拷贝结构、对照质量标准）：
  - `examples/study-copilot/`
  - `examples/vertical-ai-framework/`

## 编写与维护约定

- **保持简洁**：优先用列表/清单表达规则与标准。
- **可验证**：需求验收标准尽量可测试（例如 EARS 风格）。
- **可追踪**：建议在 requirements/tasks 中使用稳定编号（如 `R1`、`T1`）。
- **不要混放真实 specs**：`spec-guides` 只放规范/模板/示例；真实项目 specs 放 `specs/` 或 `docs/specs/`。
- **像代码一样维护**：规范变更应走评审；示例同步更新需注明原因。

## 快速入口

- `spec-writing/kiro_requirements_spec.md`
- `spec-writing/kiro_design_spec.md`
- `spec-writing/kiro_tasks_spec.md`
- `spec-writing/kiro_task_execution_spec.md`
- `spec-writing/windsurf_rules_spec.md`
