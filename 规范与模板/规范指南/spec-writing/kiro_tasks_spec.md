# Kiro Spec 工作流文档规范（tasks）

## 1. 目的
本规范用于统一 Kiro Specs 工作流中 `tasks.md`（任务清单/实施计划）文档的**结构、拆分标准、追踪方式与完成定义**，确保任务：
- 可执行（每条任务都有清晰产出）
- 可追踪（回溯到 `R#` 与设计章节）
- 可迭代（需求/设计变更后可更新任务）

## 2. 适用范围
- Kiro workflow 的 Implementation Planning 阶段输出：`tasks.md`。
- 适用于将设计落地为工程执行计划，并在执行阶段跟踪进度。

## 3. 推荐目录与命名
- **建议位置**：`.kiro/specs/<spec-name>/tasks.md`
- 任务编号建议：`T1, T2, ...`；子任务：`T1.1, T1.2`。

## 4. 任务清单的核心原则
- **离散可交付**：每条任务应能在一次 PR/一次提交中完成并自测。
- **明确产出**：代码改动点、测试、文档/配置、迁移脚本等要写清楚。
- **依赖清晰**：先后顺序、阻塞项、前置条件。
- **可验证**：每条任务要有完成判据（Done criteria）。

## 5. 文档结构（必须）

### 5.1 概览
- 总目标
- 范围与里程碑

### 5.2 追踪矩阵（Traceability）
- `R#` → `T#` 的映射（至少能从任务回溯到需求）

### 5.3 任务列表
按阶段组织（推荐）：
- 准备/基建
- 核心功能
- 测试与质量
- 发布与运维

每条任务必须包含：
- 任务标题
- 关联需求：`R#`
- 依赖：`T#`/外部依赖
- 产出/变更点
- Done criteria

### 5.4 风险与回滚（可选但推荐）
- 高风险任务标注
- 回滚/降级方案

## 6. 任务拆分标准（强约束）
- **过大任务拆分**：
  - 单条任务包含多个模块/多个用户路径/多个数据迁移点 → 必拆
- **可测试优先**：
  - 将“新增测试/性质测试/回归点”作为显式任务（而不是埋在实现任务里）
- **顺序正确**：
  - 先定义契约/数据结构，再实现业务逻辑，再补齐 UI/边缘处理，再补回归与发布

## 7. 与 Kiro 执行方式对齐
Kiro 官方提到：
- `tasks.md` 在 Kiro 中会以任务执行界面展示状态（in-progress / completed）。
- 虽然任务可能显示“完成”，仍需要人工 review / test / iterate。
- 可在 chat 中使用 `#spec` 引用 spec 上下文进行实现或校验。
- 不建议“一次性执行所有任务”，更推荐逐任务执行以提升质量。

## 8. 迭代与更新
参考 Kiro best practices：
- 修改 requirements / design 后，应通过 update tasks（或手动）使任务与最新设计对齐。
- 当发现部分任务已在现有代码中实现：
  - 可通过 update tasks 自动标记完成，或在 spec session 中让 Kiro 扫描识别。

## 9. 评审清单（Definition of Done）
- **可追踪性**：每条 `T#` 至少引用一个 `R#`。
- **可执行性**：任务描述包含具体改动点与预期结果。
- **可验证性**：任务包含明确 Done criteria。
- **依赖明确**：不存在隐性阻塞。
- **粒度合理**：能按任务逐个合并/回滚。

## 10. 模板（可直接复制到 `.kiro/specs/<spec-name>/tasks.md`）

```markdown
# <Spec 名称> - Tasks

## Overview
- 目标：
- 里程碑：

## Traceability (R# -> T#)
- R1: T1, T2
- R2: T3

## Tasks
### T1 - <任务标题>
- 关联需求：R1
- 依赖：无
- 产出：
  - ...
- Done criteria：
  - ...

### T2 - <任务标题>
- 关联需求：R1
- 依赖：T1
- 产出：
- Done criteria：

## Risks / Rollback（可选）
- ...
```

## 11. 参考
- https://kiro.dev/docs/specs/concepts/
- https://kiro.dev/docs/specs/best-practices/
- https://kiro.dev/docs/guides/learn-by-playing/05-using-specs-for-complex-work/
