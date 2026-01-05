---
inclusion: always
---


# Project Rules & Coding Standards

## 1. 技术栈与环境 (Technology Stack)
- **Runtime**: Node.js (LTS), pnpm (Package Manager)
- **Language**: TypeScript 5.x (Strict Mode)
- **Core SDK**: Vercel AI SDK Core (`ai`, `@ai-sdk/openai`, etc.)
- **API Framework**: Fastify
- **Validation**: Zod (Runtime validation for input/output/env)
- **Testing**: Vitest (Runner) + fast-check (Property-based testing)
- **Monorepo**: Turborepo + pnpm workspaces

## 2. 架构原则 (Architecture Guidelines)
- **Hexagonal Architecture**: 核心逻辑 (`packages/core`) 必须与外部依赖（如 DB、具体的 LLM Provider）解耦。所有外部依赖必须通过**接口 (Interface)** 注入。
- **No Circular Dependencies**: 严格禁止模块间的循环依赖。
- **Type-First Development**: 先定义 Interface 和 Zod Schema，再编写实现代码。
- **Plugin System**: 遵循设计文档中的插件架构，核心功能应尽量保持精简。

## 3. 代码规范 (Coding Standards)

### 3.1 通用原则 (General Principles)
- **语义化命名**:
  - 变量名应当是**名词**（如 `userProfile`）。
  - 函数名应当是**动词**或动词短语（如 `calculateTotal`, `fetchUserData`）。
  - 布尔值使用 `is`, `has`, `can` 前缀（如 `isVisible`）。
  - 避免非通用缩写（除非是 `ID`, `URL`, `API` 等）。
- **提前返回 (Early Return)**: 减少 `if/else` 嵌套层级，优先处理错误或否定情况并返回。
- **避免魔法数字 (Magic Numbers)**: 禁止直接在代码中使用裸露的数字或字符串常量，应当定义为常量（`const MAX_RETRIES = 3`）。

### 3.2 TypeScript 详细规范
- **类型定义**:
  - 禁止使用 `any`。如果必须处理动态数据，使用 `unknown` 配合 Zod 解析或类型守卫。
  - 优先使用 `interface` 定义对象结构，除非需要联合类型 (`|`)。
  - 所有公共接口必须以 `I` 开头 (e.g., `IVectorStore`)。
  - 优先使用可选链 `?.` 和空值合并 `??` 处理空值。
- **命名约定**:
  - **类名 (Class)**: PascalCase (e.g., `RAGPipeline`)
  - **接口 (Interface)**: `I` + PascalCase (e.g., `ILLMProvider`)
  - **函数/变量**: camelCase (e.g., `generateText`)
  - **常量**: UPPER_SNAKE_CASE (e.g., `DEFAULT_TIMEOUT_MS`)
  - **私有成员**: 以 `_` 开头 (e.g., `_logger`)
- **文件与导入**:
  - **文件名**: 使用 **kebab-case** (e.g., `vector-store-adapter.ts`)。
  - **导入顺序**: 1. Node.js 内置 -> 2. 第三方库 -> 3. 项目绝对路径/别名 -> 4. 相对路径。
- **异步处理**: 必须使用 `async/await` 处理异步操作，避免链式 Promise。

### 3.3 Zod 规范
- 所有 API 输入/输出、工具参数 (Tools)、配置加载必须使用 Zod Schema 验证。
- 使用 `z.infer<typeof Schema>` 生成 TypeScript 类型，保持单的一致性来源。

### 3.4 错误处理 (Error Handling)
- **机制**: 不要直接 throw 原生 Error，使用自定义错误类 `IFrameworkError`。核心层方法应优先返回 Result 类型或抛出特定业务异常。
- **语言**: 错误消息内容 (Message) 必须使用 **英文**，以便于日志搜索和 LLM 分析。
- **上下文**: 错误抛出时必须包含上下文信息（如 ID、输入参数），使用 `fmt` 或对象包装。

### 3.5 注释规范 (Comments)
- **语言**:
  - **文档注释 (JSDoc)**: 使用 **中文** 描述业务逻辑、参数含义。
  - **行内注释**: 使用 **中文** 解释复杂的算法决策 ("Why" not "How")。
  - **TODO/FIXME**: 使用 **英文**，方便全局搜索 (e.g., `// TODO: Refactor after v2`).
- **内容**: 关键算法（如 chunking, routing）必须包含解释性注释。

## 4. Vercel AI SDK 最佳实践
- **Core Only**: 严禁使用 SDK 的 Legacy 代码或 UI specific hooks (在后端逻辑中)。只使用 `ai` 核心包中的 `generateText`, `streamText`, `generateObject`, `streamObject`。
- **Streaming**: 默认优先使用流式响应。遵循 Vercel AI Data Stream Protocol。
- **Tool Calling**: 工具定义必须包含详细的 `description` 和严格的 `parameters` (Zod Schema)，以便模型正确理解。

## 5. 测试策略 (Testing Strategy)
- **Unit Tests**: 使用 Vitest。每个核心组件必须有独立的单元测试。
- **Property-Based Testing**:
  - 核心算法（分块、路由规则、数据清洗）**必须**包含属性测试。
  - 使用 `fast-check` 生成随机输入，验证不变性 (Invariants)。
  - 测试用例需标注对应的 Property ID (e.g., `**Property 1: 向量库适配器接口一致性**`).
- **Mocking**: 外部服务（OpenAI, VectorDB）必须在测试中被 Mock，禁止在单元测试中发起真实网络请求。

## 6. 版本控制 (Git Workflow)
- **提交信息**: 遵循 **Conventional Commits** 规范：
  - `feat: ...` 新功能
  - `fix: ...` 修复 Bug
  - `docs: ...` 文档变更
  - `refactor: ...` 代码重构（不改变逻辑）
  - `chore: ...` 构建/依赖/工具变动

## 7. 文件结构 (File Structure)
```
/packages
  /core         # 核心业务逻辑 (Router, Agent, RAG Pipeline)
  /adapters     # 基础设施实现 (OpenAI Provider, ChromaDB Adapter)
/apps
  /api          # Fastify API Server
  /web          # Frontend
/tools          # CLI & Scripts
```