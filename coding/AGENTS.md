---
trigger: always
---

# Project Rules (AGENTS)

## 1) 语言
- 始终使用中文回复（除非用户明确要求使用其他语言）。

## 2) 文档生成与落盘
- 当用户要求“生成文档/规范/模板/清单”等内容时：
  - 必须根据仓库目录结构，选择**合理的目标目录**。
  - 必须以 **Markdown（.md）** 格式在目标目录中**创建文件并写入内容**（而不是只在聊天中输出）。
  - 若用户未指定目标目录或命名：
    - 先提出 1-3 个建议路径与文件名供用户确认，再创建文件。

## 3) 任务状态标记
- 任务**只有在自动化验证通过后**方可标记完成（避免“文档已完成但代码不可运行”）：
  - 优先运行任务说明中指定的验证命令；若未指定，则运行仓库默认命令（如 `npm run test`，必要时叠加 `npm run typecheck` / `npm run lint`）。
  - 若变更范围仅影响单个 workspace，可用 scoped 命令缩小范围（如 `npm run test -w @niche/core`）。
  - 若因环境/依赖缺失导致无法运行验证，必须在任务条目中记录原因与补验收计划，**不得直接标记完成**。
- 标记动作：
  - `specs/study-copilot/tasks.md`：任务标题上打完成标记（例如 `✅`）。
  - `specs/study-copilot/tasks-prompts-v2-T10-T21.md`：同步更新对应任务的 `# Checklist` 状态标记（例如 `[x]`）。
- 完成每个任务后，必须在 `reports/` 目录中生成该任务的验收日志。
  - **验收日志命名**：`reports/YYYY-MM-DD_T{N}_short-slug.md`（例如 `reports/2025-12-22_T6_graphql-core.md`）
  - **代码审查报告命名**：`reports/YYYY-MM-DD_T{N}_short-slug-review.md`（例如 `reports/2025-12-24_T13_export-markdown-review.md`）
    - 审查报告必须以 `-review.md` 结尾，以区别于验收日志

## 4) Study Copilot Conventions（约定）

1. **文档权威来源**
   - 需求：`specs/study-copilot/requirements.md`
   - 任务：`specs/study-copilot/tasks.md`
   - 设计：
     - `specs/study-copilot/design-overview.md`
     - `specs/study-copilot/design/design-ui.md`
     - `specs/study-copilot/design/design-frontend.md`
     - `specs/study-copilot/design/design-backend.md`
     - `specs/study-copilot/design/design-agent.md`
     - `specs/study-copilot/design/design-contracts.md`

2. **工程结构（建议对齐仓库规范）**
   - 若当前仓库尚未建立 monorepo，则在 `T1` 中创建并对齐：
     - `packages/core`：核心编排、Agent、契约类型
     - `apps/api`：Fastify + GraphQL/REST/Streaming
     - `apps/web`：UI（模板选择、运行、step events、引用、导出）
     - `tests/{unit,property,integration,e2e}`：测试

3. **默认验证命令（若任务未单独指定）**
   - 优先运行仓库脚本集合：
     - `npm run test`
     - `npm run typecheck`
     - `npm run lint`
   - 若仅影响单个 workspace，优先 scoped：
     - `npm run test -w @niche/core`

4. **全局编码规范（强制）**
   - TypeScript Strict（**禁止 `any`**）
   - 所有输入/输出/配置/工具参数必须用 **Zod** 校验
   - 错误消息（message）必须用 **英文**（便于日志搜索）；注释可中文

5. **自动化验收原则（强制）**
   - 每个任务的 Verification 优先写成**可自动化断言**（单元/集成/契约测试），避免仅“手工目测”。
   - 契约相关（GraphQL/REST/Events/Streaming/Citation/Error）一律以 `specs/study-copilot/design/design-contracts.md` 为准，并使用 Zod schema 做断言。
