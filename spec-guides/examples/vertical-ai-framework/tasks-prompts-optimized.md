
所有“普通任务”已合并为**Umbrella Tasks（综合任务）**，并包含具体的执行计划（Execution Plan）。**Complex Tasks（复杂任务）** 的特殊要求已被整合进相应的执行步骤中。**Checkpoint（检查点）** 任务保持独立，作为阶段性审查。

---

# tasks-prompts-optimized.md

> 本文件由脚本根据 `tasks.md` + `design.md` 自动优化生成。所有的任务指令已合并为综合性 Prompt，以提供完整的上下文依赖。

## 范围与关键决策（当前迭代）

- **RAG（检索）**: 集成 RAGFlow 作为外部知识库服务，仅负责“文档摄入/检索/引用溯源”；回答生成仍由本框架通过 Vercel AI SDK 调用模型完成。
- **多租户/配额**: 当前迭代不实现多租户与配额管理能力（Task 16、/api/admin 等延后）。

## Conventions

1. **Repository Layout (Canonical)**
   - `packages/core/src/...`: 核心引擎与通用库
   - `packages/cli/src/...`: CLI 工具
   - `apps/api/src/...`: Fastify API 服务
   - `apps/web/src/...`: Web 前端
   - `tests/{property,integration,e2e}/...`: 测试
   - `prisma/schema.prisma`: 数据模型
2. **Design Doc Path Mapping**
   - `design.md` 中示例路径 `src/...` 视为 `packages/core/src/...` 的等价映射。
3. **Test Naming**
   - Property-Based Tests: `tests/property/task-<task>.test.ts` 或 `tests/property/task-<task>-<subtask>.test.ts`
   - Integration Tests: `tests/integration/task-<task>.test.ts`
   - E2E Tests: `tests/e2e/task-<task>.test.ts`
4. **Default Verification Commands** (若任务内未单独指定)
   - `pnpm -r test`
   - `pnpm -r lint`

## Phase 1: 项目骨架搭建

### Task 1: 初始化项目结构和基础配置

```markdown
# Context
You are the Lead Engineer for the Vertical AI Framework.
We are currently executing **Phase 1: 项目骨架搭建**.
Your goal is to execute the umbrella **Task 1: 初始化项目结构和基础配置**, which consists of sequential sub-tasks (1.1 to 1.5).

# Global Constraints & Standards
1.  **Language**: TypeScript (Strict Mode). **NO `any` types allowed.**
2.  **Validation**: Use **Zod** for all schema definitions and runtime validation.
3.  **Testing**: All implementations MUST be accompanied by **Property-Based Tests** using `fast-check` and `vitest`.
4.  **Error Handling**: Strictly follow `design.md` (Error Handling section).

# References (Aggregate)
- **Design Specs**: `design.md` (Sections: 架构, 目录结构, Fastify Header, Observability).
- **Correctness Properties**:
    - **Property 5**: Provider interface consistency (Config/AI SDK).
    - **Property 13**: Token usage tracking integrity.
    - **Protocol/Headers**: Follow `design.md` (Fastify 流式响应 Header 规范 / Vercel AI Data Stream Protocol). If no explicit property exists, propose one and implement it as a property-based test.

# Execution Plan

## Task 1.1 & 1.3: Monorepo Structure & Core Configuration
*Scope: Project scaffolding, ConfigManager, and AI SDK Integration.*
- **Files**:
  - Monorepo: `pnpm-workspace.yaml`, `turbo.json`, root `package.json`, root `tsconfig.json` (or `tsconfig.base.json`), ESLint/Prettier configs.
  - Packages/Apps: directory structure for `packages/{core,cli}`, `apps/{api,web}`.
  - Core Config: `packages/core/src/config/{index.ts, schema.ts, defaults.ts}`.
- **Requirements**: Initialize pnpm workspace + Turborepo; implement `ConfigManager` (Zod validated); integrate Vercel AI SDK Core providers.
- **Verification**:
  - Property: `tests/property/task-1-5.test.ts` (Verify **Property 5** end-to-end via config-driven provider selection).
  - Build/Lint: `pnpm -r lint`, `pnpm -r test`.

## Task 1.2: Fastify Server Skeleton
*Scope: API Server Setup.*
- **Files**:
  - Server: `apps/api/src/server.ts` (Fastify init, plugins, error handler).
  - Routes: `apps/api/src/routes/{chat.ts, rag.ts, documents.ts, agents.ts}`.
  - Schemas: `apps/api/src/schemas/{common.ts, chat.ts, rag.ts, documents.ts, agents.ts}`.
- **Requirements**: Configure Fastify + `fastify-type-provider-zod`; implement streaming response headers per `design.md` (must include `X-Vercel-AI-Data-Stream: v1`).
- **Verification**:
  - Property (proposed if missing in `design.md`): `tests/property/task-1-2.test.ts` (Given a streaming handler, response headers must include `X-Vercel-AI-Data-Stream: v1` and must not set conflicting caching headers).
  - Integration: `tests/integration/task-1-2.test.ts` (Start server and assert headers via HTTP request).

## Task 1.4: Observability Infrastructure
*Scope: OTel, Tracing, Metrics.*
- **Files**: `packages/core/src/observability/{tracer.ts, metrics.ts, logger.ts}`.
- **Requirements**: Implement `IObservability`; configure OpenTelemetry providers; wire `onFinish` token usage into metrics/traces.
- **Verification**: `tests/property/task-1-4.test.ts` (Verify **Property 13**).

## Task 1.5: Global Initialization Verification
*Scope: Integration Testing.*
- **Files**:
  - Property: `tests/property/task-1-5.test.ts`.
  - Integration: `tests/integration/task-1-5.test.ts`.
- **Requirements**: Verify Config + API + OTel wire together correctly (server boots; `onFinish` is called; no stack traces leak to clients).
- **Verification**: Run `pnpm -r test` and ensure both property and integration suites pass.

# Checklist
- [ ] Monorepo structure created.
- [ ] ConfigManager & AI SDK implemented.
- [ ] Fastify server skeleton running.
- [ ] OpenTelemetry wired up.
- [ ] Property 5 and 13 verified.
- [ ] Code compiles with zero linting errors.

Please generate the implementation code and the property test code now.
```

### Task 2: 实现中间件层

```markdown
# Context
You are the Lead Engineer for the Vertical AI Framework.
We are currently executing **Phase 1: 项目骨架搭建**.
Your goal is to execute **Task 2: 实现中间件层**, covering sub-tasks 2.1 to 2.4.

# Global Constraints & Standards
- Language: TypeScript (Strict), Zod Validation, Property-Based Testing (`fast-check`).

# References
- **Design Specs**: Middleware Architecture in `design.md`.
- **Correctness Properties**:
    - **Property 19**: Middleware execution order (onion model).
    - **Property 20**: Mock model injection (for testing).

# Execution Plan

## Task 2.1 & 2.2: Middleware Pattern & Verification
*Scope: `wrapLanguageModel` implementation.*
- **Files**:
  - Middleware: `packages/core/src/middleware/wrap-language-model.ts`, `packages/core/src/middleware/index.ts`.
  - Shared types (if needed): `packages/core/src/types/core.ts`.
- **Requirements**: Implement middleware pipeline compatible with Vercel AI SDK; preserve request context; support system prompt injection.
- **Verification**: `tests/property/task-2-2.test.ts` (Verify **Property 19**: A_in -> B_in -> Core -> B_out -> A_out).

## Task 2.3 & 2.4: Mock Language Model Support
*Scope: Testing Infrastructure.*
- **Files**: `packages/core/src/testing/mock-model.ts`.
- **Requirements**: Create a `MockLanguageModel` that simulates AI responses for deterministic testing.
- **Verification**: `tests/property/task-2-4.test.ts` (Verify **Property 20**: mock injection fully substitutes real model and consumes zero tokens).

# Checklist
- [ ] `wrapLanguageModel` pattern implemented.
- [ ] Middleware execution order verified (Prop 19).
- [ ] `MockLanguageModel` created and verified (Prop 20).

Please generate the implementation code and the property test code now.
```

### Task 3: 实现流式处理器

```markdown
# Context
You are the Lead Engineer. **Phase 1: 项目骨架搭建**.
Your goal is to execute **Task 3: 实现流式处理器**, covering sub-tasks 3.1 to 3.5.

# Global Constraints & Standards
- Language: TypeScript (Strict), Zod Validation, Property-Based Testing.

# References
- **Design Specs**: Stream Handler / Fastify Header Norms / Error Handling.
- **Correctness Properties**:
    - **Property 14**: Stream Protocol Compliance (Vercel AI Data Stream Protocol).
    - **Property 15**: Error Block Format.
    - **Property 13**: Token Usage Tracking.

# Execution Plan

## Task 3.1 & 3.2: StreamHandler Core & Protocol
*Scope: Core streaming logic.*
- **Files**: `packages/core/src/core/stream-handler.ts`.
- **Requirements**: Implement `IStreamHandler`. Ensure strict adherence to Vercel AI Data Stream Protocol v1 (Text, Data, Error parts).
- **Verification**: `tests/property/task-3-2.test.ts` (Verify **Property 14**: Protocol format compliance).

## Task 3.3: Error Block Handling
*Scope: Robustness.*
- **Files**: `packages/core/src/core/stream-handler.ts`.
- **Requirements**: Ensure exceptions during streaming are converted to valid Protocol Error parts (`e:{...}`), not closed sockets.
- **Verification**: `tests/property/task-3-3.test.ts`. Verify **Property 15**.

## Task 3.4 & 3.5: Token Estimation & Tracking
*Scope: Observability Integration.*
- **Files**: `packages/core/src/core/stream-handler.ts`, `packages/core/src/observability/usage-estimator.ts`.
- **Requirements**: Implement fallback token estimation if provider doesn't return usage.
- **Verification**: `tests/property/task-3-5.test.ts`. Verify **Property 13**.

# Checklist
- [ ] StreamHandler implements Vercel AI Protocol v1.
- [ ] Error blocks handled gracefully mid-stream.
- [ ] Token usage estimation fallback implemented.
- [ ] Properties 13, 14, 15 verified.

Please generate the implementation code and the property test code now.
```

### Task 4: Checkpoint - Phase 1 Review

```markdown
# Context
Act as a **QA Engineer and Security Specialist**. Review `packages/core` and `apps/api` (Phase 1 Output).

# Review Objectives
1.  **Design Compliance**: Do interfaces match `design.md`? Are Zod schemas pervasive?
2.  **Property Audit**: Are Properties 5, 13, 14, 15, 19, 20 covered by tests?
3.  **Security**: Check for error leakage (stack traces in API responses).
4.  **Performance**: Check for async blocking in the StreamHandler.

# Verification
- Run `pnpm -r lint` and ensure zero lint errors.
- Run `pnpm -r test` and ensure all `tests/property` and `tests/integration` suites pass.
- Manually hit `/api/chat` (or the configured chat route) and confirm response headers include `X-Vercel-AI-Data-Stream: v1`.

# Output
Provide a bulleted list of issues or a confirmation of readiness for Phase 2.
```

## Phase 2: 核心引擎实现

### Task 5: 对接外部检索服务（RAGFlow）

```markdown
# Context
You are the Lead Engineer. **Phase 2: 核心引擎实现**.
Your goal is **Task 5: 对接外部检索服务（RAGFlow）** (Sub-tasks 5.1 - 5.3).

# Global Constraints
- TypeScript (Strict), Zod, Fast-Check.

# References
- **Design Specs**: RAGFlow（外部检索服务）集成 / `IRAGPipeline.ingest` & `IRAGPipeline.retrieve` 数据结构.
- **Correctness Property**: **Property 3** (Citation Traceability / Retrieval Source Integrity).

# Execution Plan

## Task 5.1: 定义检索适配器与数据映射
- **Files**:
  - `packages/core/src/adapters/retrieval/interface.ts`
  - `packages/core/src/types/core.ts`（`ICitation` / `IRetrieveResult` / `IIngestResult` 等）
- **Requirements**: 对齐 `design.md` 中 `IRAGPipeline.ingest/retrieve` 的输入输出结构；支持 `knowledgeBaseId/collectionId`。

## Task 5.2: 实现 RAGFlow HTTP API Client/Adapter
- **Files**:
  - `packages/core/src/adapters/retrieval/ragflow.ts`
  - `packages/core/src/config/schema.ts`（RAGFlow 配置：`RAGFLOW_BASE_URL` / `RAGFLOW_API_KEY`）
- **Requirements**:
  - ingest：文档摄入调用、错误处理、超时/重试策略（按 `design.md` 约定）
  - retrieve：检索调用、结果映射（chunks + citations）

## Task 5.3: 编写检索适配器溯源属性测试
- **Files**: `tests/property/task-5-3.test.ts`
- **Verification**: Verify **Property 3**（citations 引用链路可追溯、字段完整）。

# Checklist
- [ ] Retrieval adapter interface defined.
- [ ] RAGFlow adapter implemented (ingest + retrieve).
- [ ] Property 3 verified.

Please generate the code.
```

### Task 6: 实现文档摄入与预处理（通过 RAGFlow）

```markdown
# Context
You are the Lead Engineer. **Phase 2: 核心引擎实现**.
Your goal is **Task 6: 实现文档摄入与预处理（通过 RAGFlow）** (Sub-tasks 6.1 - 6.7).

# Global Constraints
- TypeScript (Strict), Zod, Fast-Check.

# References
- **Design Specs**: Document Ingest（通过 RAGFlow）/ 数据清洗与脱敏.
- **Correctness Properties**:
    - **Property 8**: Cleaning Idempotency.
    - **Property 9**: PII Redaction Integrity.

# Execution Plan

## Task 6.1: 文档摄入入口（加载 + 透传给 RAGFlow）
- **Files**:
  - `packages/core/src/services/document-processor.ts`
  - `packages/core/src/services/loaders/...`（按格式拆分：pdf/markdown/html/text/office）
  - `packages/core/src/adapters/retrieval/ragflow.ts`（复用 Task 5 的 ingest 调用）
- **Verification**: `tests/integration/task-6-1.test.ts`（fixture 输入 => 统一结构 + 可发起 ingest 请求）

## Task 6.2: 对接 RAGFlow 的分块/索引配置（不实现内部 Chunker）
- **Requirements**: 分块策略/索引能力由 RAGFlow 侧配置；框架仅透传必要参数（如 `knowledgeBaseId/collectionId` 与 metadata）。

## Task 6.4 & 6.5: Cleaning Pipeline
- **Files**: `packages/core/src/services/cleaner.ts`
- **Verification**: `tests/property/task-6-5.test.ts`（Verify **Property 8**）

## Task 6.6 & 6.7: PII Redaction
- **Files**: `packages/core/src/services/pii-redactor.ts`
- **Verification**: `tests/property/task-6-7.test.ts`（Verify **Property 9**）

# Checklist
- [ ] Loaders implemented.
- [ ] Ingest entry wired to RAGFlow (no internal chunker).
- [ ] Cleaning pipeline is idempotent (Prop 8).
- [ ] PII redaction works (Prop 9).

Please generate the code.
```

### Task 7: 实现 RAG 管道

```markdown
# Context
You are the Lead Engineer. **Phase 2: 核心引擎实现**.
Your goal is **Task 7: 实现 RAG 管道** (Sub-tasks 7.1 - 7.5).

# Global Constraints
- TypeScript (Strict), Zod, Fast-Check.

# References
- **Design Specs**: RAG Pipeline / Stream Handler.
- **Correctness Properties**:
    - **Property 3**: Citation Traceability (Retrieval Source Integrity).
    - **Property 21**: Stream Rendering Consistency.

# Execution Plan

## Task 7.1 & 7.2: RAG Pipeline & Coordinates
- **Files**:
  - `packages/core/src/core/rag-pipeline.ts`
  - `packages/core/src/types/core.ts`（`ICitation` 等）
- **Verification**: `tests/integration/task-7-2.test.ts`（citations 坐标字段完整、可供前端定位）

## Task 7.3: Citation Traceability Property Test
- **Files**: `tests/property/task-7-3.test.ts`
- **Verification**: Verify **Property 3**（citations 引用的 docId 存在；offset 落在 chunk 边界内；链路可追溯）

## Task 7.4: Reranker
- **Files**: `packages/core/src/services/reranker.ts`
- **Verification**: `tests/unit/task-7-4.test.ts`（同输入 => 稳定排序）

## Task 7.5: streamGenerate
- **Files**:
  - `packages/core/src/core/rag-pipeline.ts`
  - `packages/core/src/core/stream-handler.ts`
- **Verification**:
  - Property: `tests/property/task-7-3.test.ts`（Property 3）
  - E2E: `tests/e2e/task-7-5.test.ts`（API/核心输出数据流里必须携带 citations data blocks）

# Checklist
- [ ] RAG Pipeline implemented.
- [ ] Reranker integrated.
- [ ] Citations tracked and streamed.
- [ ] Property 3 verified.

Please generate the code.
```

### Task 8: 实现模型路由器

```markdown
# Context
You are the Lead Engineer. **Phase 2: 核心引擎实现**.
Your goal is **Task 8: 实现模型路由器** (Sub-tasks 8.1 - 8.4).

# References
- **Correctness Property**: **Property 4** (Model Routing Determinism).

# Execution Plan

## Task 8.1 & 8.2: Router & Complexity Analysis
- **Files**:
  - `packages/core/src/core/model-router.ts`
  - `packages/core/src/services/complexity-analyzer.ts`
- **Verification**: `tests/property/task-8-3.test.ts`（Verify **Property 4**）

## Task 8.4: Failover Logic
- **Files**: `packages/core/src/core/model-router.ts`
- **Verification**: `tests/integration/task-8-4.test.ts`（primary 失败 => fallback 成功且记录事件）

# Checklist
- [ ] ModelRouter implemented.
- [ ] Complexity analyzer implemented.
- [ ] Failover logic working.
- [ ] Property 4 verified.

Please generate the code.
```

### Task 9: Checkpoint - Phase 2 Review

```markdown
# Context
Act as a **QA Engineer**. Review Phase 2 (Core Engine).

# Review Objectives
1.  **RAGFlow Mapping Correctness**: Are `ingest/retrieve` payloads and result mappings aligned with `design.md`?
2.  **RAG Tracing**: Are citations correctly flowing from RAGFlow -> Pipeline -> Stream Output?
3.  **Security**: Are external HTTP calls authenticated and timeouts/retries handled safely?

# Verification
- Run `pnpm -r lint`
- Run `pnpm -r test`
- 若依赖外部 RAGFlow 服务，跑 `tests/integration` 并确认检索/摄入调用可用（或使用 mock/record-replay）。

# Output
Issues list or confirmation.
```

## Phase 3: Agent 和结构化输出

### Task 10: 实现 Agent 引擎

```markdown
# Context
You are the Lead Engineer. **Phase 3: Agent 和结构化输出**.
Your goal is **Task 10: 实现 Agent 引擎** (Sub-tasks 10.1 - 10.6).

# References
- **Design Specs**: Agent Engine.
- **Correctness Properties**:
    - **Property 6**: Tool Argument Zod Validation.
    - **Property 7**: Agent Max Steps enforcement.

# Execution Plan

## Task 10.1 - 10.3: Engine & Tool Validation
- **Files**:
  - `packages/core/src/core/agent-engine.ts`
  - `packages/core/src/utils/validation.ts`
- **Verification**: `tests/property/task-10-3.test.ts`（Verify **Property 6**）

## Task 10.4 & 10.5: Max Steps & Limits
- **Files**: `packages/core/src/core/agent-engine.ts`
- **Verification**: `tests/property/task-10-5.test.ts`（Verify **Property 7**）

## Task 10.6: Multi-Agent
- **Files**:
  - `packages/core/src/core/agent-engine.ts`
  - `packages/core/src/core/agent-registry.ts`
- **Verification**: `tests/integration/task-10-6.test.ts`

# Checklist
- [ ] Agent Loop implemented.
- [ ] Tools validated via Zod (Prop 6).
- [ ] Max Steps enforced (Prop 7).
- [ ] Multi-agent support.

Please generate the code.
```

### Task 11: 实现结构化输出 (Complex)

```markdown
# Context
You are the Lead Engineer. **Phase 3**.
Your goal is **Task 11: 实现结构化输出** (Sub-tasks 11.1 - 11.5).

# References
- **Correctness Properties**:
  - **Property 16**: Structured output type safety.
  - **Property 17**: Auto-fix / Structure integrity.

# Execution Plan

## Task 11.1 - 11.2: generateObject & streamObject Wrappers
- **Files**:
  - `packages/core/src/core/structured-output.ts`
  - `packages/core/src/types/errors.ts`（如需 `StructureValidationError`）
- **Verification**: `tests/property/task-11-3.test.ts`（Property 16 的主覆盖）

## Task 11.3: Type Safety Property Test
- **Files**: `tests/property/task-11-3.test.ts`
- **Verification**: Verify **Property 16**

## Task 11.4: Auto-Correction Logic (CRITICAL)
- **Files**: `packages/core/src/core/structured-output.ts`
- **Verification**: `tests/property/task-11-5.test.ts`（Verify **Property 17**）

## Task 11.5: Auto-fix Property Test
- **Files**: `tests/property/task-11-5.test.ts`
- **Verification**: Verify **Property 17**

# Checklist
- [ ] `structured-output` wrappers (`generateObject`/`streamObject`) implemented with strict Zod validation (Prop 16).
- [ ] Auto-fix retry loop implemented (Prop 17).
- [ ] `tests/property/task-11-3.test.ts` passes (Prop 16).
- [ ] `tests/property/task-11-5.test.ts` passes (Prop 17).

Please generate the code.
```

### Task 12: Checkpoint - Phase 3 Review

```markdown
# Context
Act as **QA Engineer**. Review Phase 3 (Agents).

# Review Objectives
1.  **Agent Safety**: Can an agent loop infinitely? (Check `maxSteps`).
2.  **Tool Security**: Are arbitrary code execution tools prevented?
3.  **Auto-fix**: Is the retry limit hardcoded or configurable?

# Verification
- Run `pnpm -r lint`
- Run `pnpm -r test`
- Ensure: `tests/property/task-10-3.test.ts`, `tests/property/task-10-5.test.ts`, `tests/property/task-11-3.test.ts`, `tests/property/task-11-5.test.ts`

# Output
Issues list or confirmation.
```

## Phase 4: 安全与缓存

### Task 13: 实现安全护栏

```markdown
# Context
You are the Lead Engineer. **Phase 4: 安全与缓存**.
Your goal is **Task 13: 实现安全护栏** (Sub-tasks 13.1 - 13.5).

# References
- **Correctness Property**: **Property 10** (Guardrail Injection Detection).

# Execution Plan

## Task 13.1 - 13.3: Injection Detection
- **Files**: `packages/core/src/middleware/guardrails.ts`
- **Verification**: `tests/property/task-13-3.test.ts`（Verify **Property 10**）

## Task 13.4 & 13.5: Content Filter & Fallback
- **Files**:
  - `packages/core/src/middleware/guardrails.ts`
  - `packages/core/src/types/errors.ts`（若定义统一错误/降级结果）
- **Verification**: `tests/integration/task-13-5.test.ts`（违规 => 降级响应 + 事件记录）

# Checklist
- [ ] Guardrails middleware implemented.
- [ ] Injection detection active (Prop 10).
- [ ] Content filtering working.

Please generate the code.
```

### Task 14: 实现缓存系统

```markdown
# Context
You are the Lead Engineer. **Phase 4**.
Your goal is **Task 14: 实现缓存系统** (Sub-tasks 14.1 - 14.5).

# References
- **Correctness Properties**:
    - **Property 11**: Cache Hit Consistency.
    - **Property 12**: Semantic Similarity Threshold.

# Execution Plan

## Task 14.1 - 14.3: Redis Cache Adapter
- **Files**: `packages/core/src/adapters/cache/redis.ts`.
- **Requirements**: Exact match caching (Hash of prompt -> Response).
- **Verification**: Verify **Property 11**.

## Task 14.4 - 14.5: Semantic Cache
- **Requirements**: Vector search on prompt. If distance < threshold, return cached response.
- **Verification**: Verify **Property 12**.

# Checklist
- [ ] Redis adapter implemented.
- [ ] Semantic caching implemented.
- [ ] Properties 11 & 12 verified.

Please generate the code.
```

### Task 15: Checkpoint - Phase 4 Review

```markdown
# Context
Act as **QA Engineer**. Review Phase 4.

# Review Objectives
1.  **Cache Poisoning**: Is Semantic Cache susceptible to poisoning?
2.  **Guardrail Latency**: Does injection detection add too much latency?

# Verification
- Run `pnpm -r lint`
- Run `pnpm -r test`

# Output
Issues list or confirmation.
```

## Phase 5: 租户与可观测性

### Task 16: 实现租户管理（后续/暂不实现）

```markdown
# Context
You are the Lead Engineer. **Phase 5**.
Your goal is **Task 16: 实现租户管理** (Sub-tasks 16.1 - 16.5).

IMPORTANT: **当前迭代不实现多租户与配额**。本任务仅作为后续迭代的占位符；请不要在本迭代生成实现代码。

# References
- **Correctness Property**: **Property 18** (Quota Enforcement).

# Execution Plan

## Task 16.1: Prisma Schema
- **Files**: `prisma/schema.prisma`
- **Requirements**: 至少包含 tasks.md 指定的 `Tenant/ApiKey/Document/Chunk/UsageRecord`
- **Verification**: `tests/integration/task-16-1.test.ts`（schema 迁移/生成可用）

## Task 16.2 - 16.4: TenantManager & Quotas
- **Files**: `packages/core/src/tenant/manager.ts`
- **Verification**: `tests/property/task-16-4.test.ts`（Verify **Property 18**）

## Task 16.5: API Key Management
- **Files**:
  - `packages/core/src/tenant/manager.ts`（或独立 `packages/core/src/tenant/api-key.ts`）
  - `packages/core/src/middleware/auth.ts`
- **Verification**: `tests/integration/task-16-5.test.ts`（生成/校验/吊销全链路）

# Checklist
- [ ] Prisma Schema configured.
- [ ] Tenant/Quota manager implemented.
- [ ] Quota enforcement verified (Prop 18).

本迭代跳过，无需生成代码。
```

### Task 17: 实现可观测性系统

```markdown
# Context
You are the Lead Engineer. **Phase 5**.
Your goal is **Task 17: 实现可观测性系统** (Sub-tasks 17.1 - 17.4).

# References
- **Correctness Property**: **Property 13** (Token Tracking).

# Execution Plan

## Task 17.1 & 17.2: Tracer & onFinish
- **Files**: `packages/core/src/observability/{tracer.ts, metrics.ts, logger.ts}`
- **Verification**: `tests/property/task-17-2.test.ts`（Verify **Property 13**）

## Task 17.3 & 17.4: Analysis & Alerts
- **Files**: `packages/core/src/observability/alerts.ts`, `packages/core/src/observability/cost.ts`
- **Verification**: `tests/integration/task-17-4.test.ts`（错误率/延迟阈值触发告警）

# Checklist
- [ ] Tracer/metrics/logger implemented.
- [ ] `onFinish` integrated and `tests/property/task-17-2.test.ts` passes (Prop 13).
- [ ] Cost/alerts implemented and `tests/integration/task-17-4.test.ts` passes.

Please generate the code.
```

### Task 18: Checkpoint - Phase 5 Review

```markdown
# Context
Act as **QA Engineer**. Review Phase 5.

# Review Objectives
1.  **Observability Correctness**: Are tracing/metrics/logging wired correctly and consistently?
2.  **Token Tracking**: Is token usage recorded reliably for both streaming and non-streaming?

# Verification
- Run `pnpm -r lint`
- Run `pnpm -r test`
- 多租户/配额相关检查在本迭代不适用（Task 16 延后）。

# Output
Issues list or confirmation.
```

## Phase 6: API 层实现

### Task 19: 实现 API 路由

```markdown
# Context
You are the Lead Engineer. **Phase 6: API 层实现**.
Your goal is **Task 19: 实现 API 路由** (Sub-tasks 19.1 - 19.5).

# References
- **Correctness Properties**:
    - **Property 14**: Stream Protocol.
    - **Property 7**: Agent Steps.

# Execution Plan

## Task 19.1: Chat Endpoint (Complex)
- **Files**:
  - `apps/api/src/routes/chat.ts`
  - `packages/core/src/core/stream-handler.ts`
- **Verification**:
  - `tests/e2e/task-19-1.test.ts`（Verify **Property 14**：协议块格式 + Header `X-Vercel-AI-Data-Stream: v1`）

## Task 19.2: /rag
- **Files**: `apps/api/src/routes/rag.ts`
- **Verification**: `tests/integration/task-19-2.test.ts`（返回 citations 坐标）

## Task 19.3: /documents
- **Files**: `apps/api/src/routes/documents.ts`
- **Verification**: `tests/integration/task-19-3.test.ts`（上传/摄入/查询/删除）

## Task 19.4: /agents
- **Files**: `apps/api/src/routes/agents.ts`
- **Verification**: `tests/property/task-19-4.test.ts`（Verify **Property 7**：maxSteps 不得超限）

## Task 19.5: /api/admin
- IMPORTANT: `/api/admin` 属于多租户/配额相关能力，当前迭代不实现（延后）。
- **Files**: （后续）另行补充
- **Verification**: （后续）另行补充

# Checklist
- [ ] `/chat` implements Protocol v1 strictly and `tests/e2e/task-19-1.test.ts` passes (Prop 14).
- [ ] `/rag`, `/documents` endpoints implemented and corresponding integration tests pass.
- [ ] `/agents` enforces maxSteps and `tests/property/task-19-4.test.ts` passes (Prop 7).
- [ ] Streaming headers compliant (`X-Vercel-AI-Data-Stream: v1`).

NOTE: `/api/admin` 属于多租户/配额相关能力，当前迭代不实现（延后）。

Please generate the code.
```

### Task 20: 实现认证和限流

```markdown
# Context
You are the Lead Engineer. **Phase 6**.
Your goal is **Task 20: 实现认证和限流** (Sub-tasks 20.1 - 20.3).

# Execution Plan

## Task 20.1: API Key Middleware
- **Files**: `packages/core/src/middleware/auth.ts`
- **Verification**: `tests/integration/task-20-1.test.ts`（无 key/坏 key => 401；好 key => 放行）

## Task 20.2: Rate Limiting
- **Files**: `packages/core/src/middleware/rate-limit.ts`
- **Verification**: `tests/integration/task-20-2.test.ts`（滑动窗口：超过阈值必阻断）

## Task 20.3: JWT Support
- **Files**: `packages/core/src/middleware/auth.ts`
- **Verification**: `tests/integration/task-20-3.test.ts`

# Checklist
- [ ] API Key auth middleware implemented and `tests/integration/task-20-1.test.ts` passes.
- [ ] Rate limiting active and `tests/integration/task-20-2.test.ts` passes.
- [ ] JWT support implemented and `tests/integration/task-20-3.test.ts` passes.

Please generate the code.
```

### Task 21: 实现 WebSocket 支持

```markdown
# Context
You are the Lead Engineer. **Phase 6**.
Your goal is **Task 21: 实现 WebSocket 支持**.

# Execution Plan
- **Files**: `apps/api/src/routes/ws.ts`
- **Verification**: `tests/integration/task-21.test.ts`（连接建立、消息收发、断线处理）

# Checklist
- [ ] WS Plugin configured.
- [ ] Message handling implemented.

Please generate the code.
```

### Task 22: Checkpoint - Phase 6 Review

```markdown
# Context
Act as **QA Engineer**. Review Phase 6 (API).

# Review Objectives
1.  **Protocol Compliance**: Curl the `/chat` endpoint. Does it look exactly like the Vercel spec?
2.  **Auth Coverage**: Are any routes accidentally public?

# Verification
- Run `pnpm -r lint`
- Run `pnpm -r test`
- curl/chat 路由：确认协议 + header + 鉴权覆盖

# Output
Issues list or confirmation.
```

## Phase 7: 前端实现

### Task 23: 初始化前端项目

```markdown
# Context
You are the Lead Engineer. **Phase 7: 前端实现**.
Your goal is **Task 23: 初始化前端项目** (23.1 - 23.3).

# Execution Plan
- **Files**:
  - `apps/web/{package.json,vite.config.ts,tsconfig.json,index.html}`
  - `apps/web/src/{main.tsx,App.tsx}`
  - `apps/web/src/store/...`（Zustand）
  - `apps/web/src/components/...`（shadcn/ui）
- **Verification**:
  - `pnpm -r lint`
  - `pnpm -r test`（若无前端测试，至少能 build）

# Checklist
- [ ] Project running.
- [ ] UI components installed.

Please generate the code.
```

### Task 24: 实现聊天界面

```markdown
# Context
You are the Lead Engineer. **Phase 7**.
Your goal is **Task 24: 实现聊天界面** (24.1 - 24.5).

# References
- **Correctness Property**: **Property 21** (Stream Rendering).

# Execution Plan

## Task 24.1 - 24.3: Interface & Streaming
- **Files**:
  - `apps/web/src/components/chat/ChatInterface.tsx`
  - `apps/web/src/hooks/useChat.ts`
  - `apps/web/src/lib/stream-parser.ts`
- **Verification**: `tests/property/task-24-4.test.ts`（Verify **Property 21**）

## Task 24.5: Tool UI
- **Files**: `apps/web/src/components/chat/ToolCallIndicator.tsx`
- **Verification**: `tests/unit/task-24-5.test.ts`

# Checklist
- [ ] Streaming rendering consistent and `tests/property/task-24-4.test.ts` passes (Prop 21).
- [ ] Tool states visible and `tests/unit/task-24-5.test.ts` passes.

Please generate the code.
```

### Task 25: 实现文档查看器

```markdown
# Context
You are the Lead Engineer. **Phase 7**.
Your goal is **Task 25: 实现文档查看器** (25.1 - 25.5).

# References
- **Correctness Property**: **Property 22** (Highlight Accuracy).

# Execution Plan

## Task 25.1 - 25.3: Viewer & Highlighting
- **Files**:
  - `apps/web/src/components/doc/DocumentViewer.tsx`
  - `apps/web/src/lib/highlight.ts`
- **Verification**: `tests/property/task-25-3.test.ts`（Verify **Property 22**）

## Task 25.4: Selection
- **Files**: `apps/web/src/components/doc/selection.ts`
- **Verification**: `tests/property/task-25-5.test.ts`（Verify **Property 23**）

# Checklist
- [ ] Document viewer active.
- [ ] Highlights align correctly and `tests/property/task-25-3.test.ts` passes (Prop 22).
- [ ] Text selection -> Ask AI works and `tests/property/task-25-5.test.ts` passes (Prop 23).

Please generate the code.
```

### Task 26: 实现引用面板

```markdown
# Context
You are the Lead Engineer. **Phase 7**.
Your goal is **Task 26: 实现引用面板**.

# References
- **Correctness Property**: **Property 3** (Traceability).

# Execution Plan
- **Files**: `apps/web/src/components/citations/CitationPanel.tsx`
- **Verification**: `tests/integration/task-26.test.ts`（点击 citation => viewer 滚动/高亮联动）

# Checklist
- [ ] Citation panel renders.
- [ ] Click-to-scroll works.

Please generate the code.
```

### Task 27: 实现反馈系统

```markdown
# Context
You are the Lead Engineer. **Phase 7**.
Your goal is **Task 27: 实现反馈系统**.

# References
- **Correctness Property**: **Property 24** (Feedback Integrity).

# Execution Plan
- **Files**:
  - `apps/web/src/components/feedback/FeedbackButtons.tsx`
  - `apps/web/src/lib/api-client.ts`
- **Verification**: `tests/property/task-27.test.ts`（Verify **Property 24**）

# Checklist
- [ ] Feedback buttons active.
- [ ] Data submission verified.

Please generate the code.
```

### Task 28: Checkpoint - Phase 7 Review

```markdown
# Context
Act as **QA Engineer**. Review Phase 7 (Frontend).

# Review Objectives
1.  **UX Smoothness**: Does streaming jitter?
2.  **Offset alignment**: Do highlights actually match the text in the viewer?

# Verification
- Run `pnpm -r lint`
- Run `pnpm -r test`
- 手动验收：流式渲染无抖动；高亮 offset 精确匹配

# Output
Issues list or confirmation.
```

## Phase 8: 评估与工具

### Task 29: 实现评估框架

```markdown
# Context
You are the Lead Engineer. **Phase 8: 评估与工具**.
Your goal is **Task 29: 实现评估框架**.

# Execution Plan
- **Files**:
  - `packages/core/src/services/eval.ts`
  - `packages/core/src/types/eval.ts`
- **Verification**: `tests/integration/task-29.test.ts`（最小数据集跑通 + 报告生成）

# Checklist
- [ ] Eval framework running.
- [ ] Reports generating.

Please generate the code.
```

### Task 30: 实现合成数据生成

```markdown
# Context
You are the Lead Engineer. **Phase 8**.
Your goal is **Task 30: 实现合成数据生成**.

# Execution Plan
- **Files**:
  - `packages/core/src/services/synthetic-data.ts`
  - `packages/core/src/types/synthetic-data.ts`
- **Verification**: `tests/integration/task-30.test.ts`（JSONL 导出格式合法）

# Checklist
- [ ] Generator working.

Please generate the code.
```

### Task 31: 实现提示词管理

```markdown
# Context
You are the Lead Engineer. **Phase 8**.
Your goal is **Task 31: 实现提示词管理**.

# Execution Plan
- **Files**: `packages/core/src/core/prompt-manager.ts`
- **Verification**: `tests/integration/task-31.test.ts`（版本化 + A/B 路由最小闭环）

# Checklist
- [ ] Prompt Manager implemented.

Please generate the code.
```

### Task 32: 实现 CLI 工具

```markdown
# Context
You are the Lead Engineer. **Phase 8**.
Your goal is **Task 32: 实现 CLI 工具**.

# Execution Plan
- **Files**:
  - `packages/cli/src/index.ts`
  - `packages/cli/src/commands/{init.ts,eval.ts,ingest.ts,serve.ts}`
- **Verification**: `tests/integration/task-32.test.ts`（CLI 参数解析 + 子命令可运行）

# Checklist
- [ ] CLI commands functional.

Please generate the code.
```

### Task 33: Checkpoint - Phase 8 Review

```markdown
# Context
Act as **QA Engineer**. Review Phase 8.

# Review Objectives
1.  **CLI Usability**: Is the DX good?
2.  **Eval Cost**: Does the LLM-Judge burn too many tokens?

# Verification
- Run `pnpm -r lint`
- Run `pnpm -r test`
- 审核：eval 成本可控（LLM-judge 有开关/采样策略）

# Output
Issues list or confirmation.
```

## Phase 9: 集成与文档

### Task 34: 实现配置管理 (Advanced)

```markdown
# Context
You are the Lead Engineer. **Phase 9: 集成与文档**.
Your goal is **Task 34: 实现配置管理**.

# Execution Plan
- **Files**:
  - `packages/core/src/config/{index.ts,schema.ts,defaults.ts}`
  - `packages/core/src/config/watch.ts`（热更新可选）
- **Verification**: `tests/integration/task-34.test.ts`（dev/prod 隔离 + 校验失败可观测）

# Checklist
- [ ] Config management finalized.

Please generate the code.
```

### Task 35: 实现插件系统

```markdown
# Context
You are the Lead Engineer. **Phase 9**.
Your goal is **Task 35: 实现插件系统**.

# Execution Plan
- **Files**:
  - `packages/core/src/core/plugin-system.ts`
  - `packages/core/src/types/plugin.ts`
- **Verification**: `tests/integration/task-35.test.ts`（插件加载顺序 + 错误隔离）

# Checklist
- [ ] Plugin system active.

Please generate the code.
```

### Task 36: 编写文档

```markdown
# Context
You are the Lead Engineer. **Phase 9**.
Your goal is **Task 36: 编写文档**.

# Execution Plan
- **Files**:
  - `docs/quick-start.md`
  - `docs/architecture.md`
  - `docs/openapi.md`（或从 swagger 生成的产物说明）
- **Verification**: `tests/integration/task-36.test.ts`（可选：检查链接/示例命令可运行）

# Checklist
- [ ] Docs written.

Please generate the code.
```

### Task 37: 配置 Docker 开发环境

```markdown
# Context
You are the Lead Engineer. **Phase 9**.
Your goal is **Task 37: 配置 Docker 开发环境**.

# Execution Plan
- **Files**: `Dockerfile`, `docker-compose.yml`
- **Verification**:
  - `docker-compose up` 能拉起 Redis/DB/API
  - `tests/e2e/task-37.test.ts`（可选：最小链路 smoke test）

# Checklist
- [ ] Docker builds successfully.
- [ ] Compose up works.

Please generate the code.
```

### Task 38: Final Checkpoint

```markdown
# Context
Act as **Lead Architect & Security Officer**. Perform the **Final Audit**.

# Review Objectives
1.  **End-to-End**: Run `docker-compose up`. Can I upload a doc, chat with it, and see citations?
2.  **Security Audit**: Check headers, auth, injection guards, PII.
3.  **Code Quality**: Lint clean? Tests pass?

# Verification
- `docker-compose up`
- E2E：上传文档 -> /chat 流式对话 -> citations 可见且可定位
- Run `pnpm -r lint` and `pnpm -r test`

# Output
Final Sign-off or Blocking Issues List.

## Addendum: Agentic RAG & Research Copilot Extensions

> 本附录用于对齐 `tasks.md` 新增的 Agentic RAG / Research Copilot 任务（Req 32-37, 36.x, 37.x 等），确保执行提示与最新 `design.md`/`requirements.md` 一致。

### Task 42: 实现强引用模式（Strict Citation Mode）

```markdown
# Context
You are the Lead Engineer. Your goal is **Task 42: 强引用模式**.

# References
- **Requirements**: Requirement 28 acceptance criteria (incl. answerPolicy=strict/force)
- **Design Specs**: `StrictCitationConfigSchema.answerPolicy`, `ChatResponseSchema.citationQuality`
- **Correctness Property**: Property 28

# Execution Plan
- Implement `StrictCitationConfig`:
  - `enabled`
  - `answerPolicy: 'strict' | 'force'`
  - `maxRetries`
- Enforce field-level citations for "关键结论":
  - If missing citations: retry/self-repair up to `maxRetries`
  - If still missing:
    - `strict`: return structured error with `missingFields`
    - `force`: return best-effort output, and set machine-checkable metadata:
      - `citationQuality.missingFields`
      - `citationQuality.evidenceStatus = 'insufficient'`
- Prevent fake citations:
  - Any returned `citations[]` must be traceable to actual retrieval/read results
  - If a citation cannot be traced, drop it and mark evidence as insufficient

# Verification
- Unit tests for policy behavior (strict vs force)
- Property test (Property 28):
  - For force: must return content + evidenceStatus/missingFields when citations are insufficient
  - For strict: must error with missingFields
  - For both: no untraceable citations allowed

# Output
Code + tests.
```

### Task 6.8: 验证并对齐 Deep Parsing 能力（RAGFlow/解析侧）

```markdown
# Context
You are the Lead Engineer. **Phase 2: 核心引擎实现**.
Your goal is **Task 6.8: Deep Parsing 能力验证与降级策略对齐**.

# References
- **Design Specs**: `ICitation.boundingBoxes` / Deep Parsing 降级策略.
- **Requirements**: 30.2, 32.1, 32.2, 32.4, 33.1, 33.3
- **Correctness Properties**: Property 32, Property 33, Property 30

# Execution Plan
- 实现/补齐 RAGFlow ingest/retrieve 映射中的字段探测：
  - 是否返回 `pageNumber`/offset/toc
  - 是否返回坐标信息（映射为 `ICitation.boundingBoxes`）
- 当字段缺失：
  - 触发降级（页码/offset/chunkId）
  - 记录可观测性告警（capability missing）

# Verification
- 增加 `tests/integration`：在 mock 响应中覆盖“字段齐全/字段缺失”两种情况
- 确保缺失时系统仍返回可追溯引用并打出告警

# Output
Patch list + tests added.
```

### Task 10.7: 实现 Agent Step Events（Thinking UI 事件流）

```markdown
# Context
You are the Lead Engineer. **Phase 3: Agent 和结构化输出**.
Your goal is **Task 10.7: Agent Step Events**.

# References
- **Design Specs**: `IAgentEvent` event types + `AgentStepEventSchema`.
- **Requirements**: 36.1, 36.2, 36.3
- **Correctness Property**: Property 36

# Execution Plan
- 扩展 agent 流式执行：
  - 在 thinking/tool_call/tool_result/reading/generating 阶段 emit event
  - 在结束时 emit `complete` / `cancelled` / `error`
- 支持取消：收到 cancel 信号后终止后续 steps 并收敛事件

# Verification
- 增加属性测试：随机生成 steps 序列，验证事件流可解析且最终收敛（Property 36）

# Output
Code changes + tests.
```

## Phase 12: Agentic RAG 增强能力落地

### Task 49: 实现混合检索工具（Hybrid Search）

```markdown
# Context
You are the Lead Engineer. **Phase 12: Agentic RAG 增强能力落地**.
Your goal is **Task 49: Hybrid Search Tool**.

# References
- **Design Specs**: `SearchKnowledgeBaseSchema` / `IRetrieveOptions.filter`.
- **Requirements**: 34.1, 34.2, 34.3, 34.4
- **Correctness Property**: Property 34

# Execution Plan
- 在 tools/service 层实现 `search_knowledge_base`：
  - query + filters（projectId/documentId/year）
  - 映射到 RAGFlow 的检索参数（collectionId/filters）
- projectId 过滤：必须限制检索范围在项目绑定集合内

# Verification
- `tests/integration`：构造不同 projectId 的集合，验证不会跨项目混入
- `tests/property`：Property 34

# Output
Code + tests.
```

### Task 50: 实现深读工具（read_document）

```markdown
# Context
You are the Lead Engineer. **Phase 12**.
Your goal is **Task 50: read_document**.

# References
- **Design Specs**: `ReadDocumentSchema` / citation 保留.
- **Requirements**: 35.1, 35.2, 35.3
- **Correctness Property**: Property 35

# Execution Plan
- 实现 `read_document(documentId, pageStart, pageEnd)`：
  - 页范围校验
  - 返回内容 + 页码/引用定位信息

# Verification
- 边界用例：pageStart/pageEnd 越界必须结构化错误
- Property 35

# Output
Code + tests.
```

### Task 51: 引用坐标可视化（前端）

```markdown
# Context
You are the Frontend Lead. **Phase 12**.
Your goal is **Task 51: Citation Visualization**.

# References
- **Design Specs**: `ICitation.boundingBoxes` + Citation Panel.
- **Requirements**: 33.1, 33.2, 33.3
- **Correctness Property**: Property 33

# Execution Plan
- 扩展引用面板：
  - boundingBoxes 存在则按坐标高亮/截图定位
  - 不存在则回退页码/offset，并标注降级原因

# Verification
- UI 单测（或 e2e）：点击引用能定位；缺坐标时正确回退

# Output
Component changes + tests.
```

### Task 52: 本地模型 Provider（llama.cpp server）

```markdown
# Context
You are the Lead Engineer. **Phase 12**.
Your goal is **Task 52: llama.cpp Provider**.

# References
- **Design Specs**: Provider interface + local provider notes.
- **Requirements**: 37.1, 37.2

# Execution Plan
- 新增 llama.cpp HTTP Provider：
  - 请求/响应映射
  - 超时/重试
  - 结构化输出失败时的防御性校验与回退

# Verification
- 集成测试：mock llama.cpp server 返回
- 失败用例：结构化输出不合规 => 触发校验重试/回退

# Output
Code + tests.
```

### Task 53: 异步摄入/解析队列（Job Queue）

```markdown
# Context
You are the Lead Engineer. **Phase 12**.
Your goal is **Task 53: Ingest Job Queue**.

# References
- **Design Specs**: `IIngestJobQueue` / `IIngestJob`.
- **Requirements**: 37.3, 37.4, 29.2
- **Correctness Property**: Property 37

# Execution Plan
- 引入任务队列（例如 BullMQ）：
  - enqueue 摄入任务
  - job 状态查询
  - 失败时结构化错误 + retryable
- tenantId 隔离：job 查询必须按 tenantId 校验

# Verification
- Property 37：状态机只能 queued -> processing -> completed/failed

# Output
Code + tests.
```

### Task 54: Checkpoint - Agentic RAG 能力验收

```markdown
# Context
Act as **Lead Architect & QA Engineer**. Perform Phase 12 Sign-off.

# Verification
1. Hybrid Search：projectId 范围过滤正确
2. read_document：页范围边界与引用保留正确
3. Thinking UI：step events 顺序正确且收敛
4. Citation Visualization：有坐标可定位，缺坐标可降级
5. Local Provider：可用且失败可回退/结构化报错
6. Job Queue：状态机正确且 tenantId 隔离

# Output
Final Sign-off or Blocking Issues List.