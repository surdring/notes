# Kiro Spec 工作流文档规范（任务开始与执行）

## 1. 目的
本规范用于统一 Kiro Specs 工作流中**如何开始执行任务、如何推进/校验任务完成、如何处理任务与代码不一致**等执行规则，保证 tasks 执行：
- 可控（按任务推进）
- 可追踪（状态更新与 review）
- 可迭代（任务可更新、可标记已完成）

## 2. 适用范围
- 适用于 Kiro 生成的 `.kiro/specs/<spec-name>/tasks.md`。
- 适用于从 spec 进入实现阶段（Implementation / Execution）。

## 3. 官方能力对齐（你可以依赖的行为）
Kiro 官方文档明确提到以下工作方式：
- `tasks.md` 是离散、可追踪的实施计划，Kiro 会提供任务执行界面并显示状态。
- **开始任务**：在 `tasks.md` 中对单个任务点击 **Start Task**（或在任务项上点击执行入口）启动该任务。
- **进度跟踪**：任务会自动更新为 `In Progress` / `Done`。
- **逐任务执行**：Kiro 官方不推荐一次性执行所有任务，建议按任务逐步执行以获得更好结果。
- **已实现任务识别**：
  - 可在 `tasks.md` 使用 **Update tasks** 让 Kiro 自动标记已完成任务；
  - 或在 spec session 让 Kiro 扫描并判断“哪些任务已经完成”。

## 4. 执行流程规范（必须）

### 4.1 执行前（Pre-flight）
- 确认 `requirements.md` 与 `design.md` 已稳定（或至少当前迭代已对齐）。
- 在开始某条任务前，检查该任务：
  - 是否引用了 `R#`（需求可追踪）
  - 是否依赖其它任务（依赖已完成）
  - 是否明确 Done criteria（否则先补齐再做）

### 4.2 开始执行（Start Task）
- 以单任务为粒度推进：
  - 在 `tasks.md` 中点击该任务的 **Start Task**
  - 或在 chat 中引用 `#spec` 并指明要执行的任务编号（例如 “implement task T2.3”）
- 若执行过程中发现需求/设计不成立：
  - **必须回退**到 requirements/design 更新，再更新 tasks（避免任务与事实脱节）。

### 4.3 执行中（During Task）
每条任务执行必须同时满足：
- **代码变更**：实现任务所述行为
- **测试/验证**：至少一种验证方式（单测/集成/E2E/手工验证步骤）
- **自检**：对照 Done criteria 逐条确认

> 注意：Kiro 官方提醒即便任务显示 “Task completed”，你仍需要人工 review、运行测试并迭代。

### 4.4 完成与合并（Done / Merge）
- 完成后必须：
  - 通过测试（或记录明确的验证步骤与结果）
  - 确认未引入明显回归
  - 必要时更新文档/配置（与任务范围一致）

## 5. 变更处理（需求/设计/任务不同步时）

### 5.1 需求或设计变更
参考 Kiro best practices：
- 修改 `requirements.md` 后：可 refine design 让 design/tasks 同步。
- 修改 `design.md` 后：使用 refine 使 design 与 tasks 同步。
- 修改 `tasks.md`：使用 **Update tasks** 生成对齐新需求/设计的任务。

### 5.2 发现任务已在代码中实现
- 首选：在 `tasks.md` 点击 **Update tasks** 让 Kiro 自动标记完成。
- 或在 spec session 让 Kiro 扫描："Check which tasks are already complete"。

## 6. 质量门槛（Definition of Done）
对每个任务（T#）至少满足：
- 需求追踪：引用 `R#`
- 产出明确：有可定位的代码改动
- 可验证：存在测试或清晰可重复的验证步骤
- 可评审：变更范围与任务描述一致

## 7. 模板（建议写入 `.kiro/specs/<spec-name>/tasks.md` 的任务项格式）

```markdown
### T<id> - <任务标题>
- 关联需求：R<id>
- 依赖：T<id> / 无
- 变更点：
  - 文件/模块：...
  - 行为：...
- 验证方式：
  - 单测/集成/E2E：...
  - 手工步骤：...
- Done criteria：
  - ...
```

## 8. 参考
- https://kiro.dev/docs/getting-started/first-project/
- https://kiro.dev/docs/specs/best-practices/
- https://kiro.dev/docs/guides/learn-by-playing/05-using-specs-for-complex-work/
