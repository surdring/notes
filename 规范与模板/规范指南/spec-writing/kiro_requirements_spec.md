# Kiro Spec 工作流文档规范（requirements）

## 1. 目的
本规范用于统一 Kiro 三段式 spec 工作流中 `requirements.md`（需求规格）文档的**结构、写法与质量门槛**，确保需求：
- 可理解（对齐业务意图）
- 可测试（可转化为测试用例/性质测试）
- 可追踪（可映射到设计与任务）

## 2. 适用范围
- 适用于使用 Kiro 的 Specs 功能（Workflow：Requirements → Design → Tasks）。
- 适用于新增功能、较复杂重构、跨模块改动。

## 3. 推荐目录与命名
- **建议位置**：`.kiro/specs/<spec-name>/requirements.md`
- **Spec 名称**：`kebab-case`，语义明确（如 `user-authentication`）。
- **需求编号**：使用 `R1, R2, ...`，并在 tasks 中引用。

> 说明：Kiro 官方描述 specs 的三文件基础结构为 `requirements.md / design.md / tasks.md`。

## 4. 文档结构（必须）
- **4.1 背景与目标**
- **4.2 术语与范围**
- **4.3 用户故事列表**（每条需求一个用户故事）
- **4.4 验收标准**（每条需求对应一组可测试标准）
- **4.5 非目标（Out of scope）**
- **4.6 风险与假设（可选但推荐）**

## 5. 写作规范

### 5.1 用户故事（User Story）
每条需求以用户故事形式描述：
- 建议格式：`作为… 我希望… 以便…`
- 每条故事应能明确：角色、动机、价值、触发场景。

### 5.2 验收标准（Acceptance Criteria）：优先使用 EARS
Kiro 官方推荐在 `requirements.md` 中用结构化 **EARS（Easy Approach to Requirements Syntax）** 编写验收标准：

- **标准句式**：

```text
WHEN [condition/event] THE SYSTEM SHALL [expected behavior]
```

- **示例**：

```text
WHEN a user submits a form with invalid data THE SYSTEM SHALL display validation errors next to the relevant fields
```

#### EARS 写作要点
- **可测试**：避免主观词（如“尽量”“友好”“快速”），必要时给出量化指标。
- **单一行为**：一条 EARS 只描述一个可验证行为，复杂逻辑拆分多条。
- **边界条件**：覆盖异常输入、权限不足、外部依赖失败等。

### 5.3 需求粒度
- 一条需求（R#）应能映射到：
  - 设计中的某个关键决策/交互流程
  - tasks 中 1 个或多个可交付任务
- 如果一个需求无法落到可实现的任务，通常意味着需求过大或不清晰。

### 5.4 非功能性需求（NFR）建议表达
非功能性需求也应尽量写成可验证条款：
- 性能：响应时间、吞吐、并发、资源消耗
- 安全：鉴权、审计、数据脱敏
- 可靠性：重试、降级、幂等、SLO
- 可用性：可访问性、可观测性（日志/指标/追踪）

可用 EARS 或 GIVEN/WHEN/THEN 表达，但保持**可测试**。

## 6. 追踪与可验证性
- **需求 → 任务**：tasks 文档中的任务项应引用 `R#`。
- **需求 → 测试**：建议每条 `R#` 至少有一种验证方式：
  - 单元/集成/E2E 测试
  - 或性质测试（PBT）。Kiro 提到可从 EARS 需求提取可逻辑测试的“性质”，并生成大量随机用例作为反馈回路。

## 7. 迭代与变更
Kiro 官方建议 Specs 作为可迭代工件：
- 需求更新后，可通过 refine design / update tasks 让设计与任务同步演进。
- 需求变更必须：
  - 更新 `R#`（新增用新编号，避免大规模重排）
  - 在 design/tasks 中同步引用变更。

## 8. 评审清单（Definition of Done）
- **清晰性**：读者无需口头补充即可理解目标与范围。
- **可测试性**：每条 `R#` 至少有一条可验证的验收标准。
- **完整性**：覆盖关键异常与边界条件。
- **可追踪性**：存在稳定编号 `R#`，后续 tasks 可引用。
- **非目标明确**：防止范围蔓延。

## 9. 模板（可直接复制到 `.kiro/specs/<spec-name>/requirements.md`）

```markdown
# <Spec 名称> - Requirements

## 背景与目标
- 背景：
- 目标：
- 成功指标（可选）：

## 术语与范围
- 术语：
- In scope：
- Out of scope：

## 需求列表
### R1 - <需求标题>
**用户故事**：作为…我希望…以便…

**验收标准（EARS）**：
- WHEN ... THE SYSTEM SHALL ...
- WHEN ... THE SYSTEM SHALL ...

**备注/约束（可选）**：

### R2 - <需求标题>
...

## 非目标（Out of scope）
- ...

## 风险与假设（可选）
- 风险：
- 假设：
```

## 10. 参考
- https://kiro.dev/docs/specs/concepts/
- https://kiro.dev/docs/specs/best-practices/
- https://kiro.dev/docs/specs/correctness/
