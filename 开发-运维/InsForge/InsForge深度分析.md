## 项目深度分析报告：InsForge

### 📋 项目概览

**InsForge** 是一个**开源的全栈后端即服务（BaaS）平台**，专为 AI 编码代理（Agentic Coding）设计。它让 AI 编码代理能够像后端工程师一样操作后端基础设施。

- **许可证**: Apache-2.0
- **版本**: 2.1.6
- **技术栈**: TypeScript + Node.js (Express) + React 19
- **包管理器**: npm (workspaces monorepo)
- **构建工具**: Turborepo + Vite + tsup
- **数据库**: PostgreSQL + PostgREST (v12)
- **实时通信**: Socket.IO + PostgreSQL LISTEN/NOTIFY
- **边缘函数运行时**: Deno (v2.0.6)

---

### 🏗️ 项目架构（Monorepo）

项目采用 **Turborepo** 管理的 monorepo 结构，包含以下主要工作区：

| 工作区 | 路径 | 描述 |
|--------|------|------|
| **backend** | `backend/` | Express 后端服务 - 核心 BaaS API |
| **frontend** | `frontend/` | 自托管 Dashboard 宿主应用 (Vite + React 19) |
| **@insforge/dashboard** | `packages/dashboard/` | 共享 Dashboard 组件库（核心 UI） |
| **@insforge/ui** | `packages/ui/` | UI 组件库 |
| **@insforge/shared-schemas** | `packages/shared-schemas/` | 共享类型定义 |

---

### 🔧 后端核心模块 (`backend/src/`)

后端基于 **Express** 框架，按功能模块清晰划分：

#### API 路由 (`api/routes/`)
提供 18+ 个功能路由模块：

| 模块 | 功能 |
|------|------|
| **auth/** | 认证系统 - 邮箱/密码、OAuth (Google, GitHub, Apple, Discord 等 10+ 提供商)、自定义 OAuth、OTP 验证、会话管理 |
| **database/** | PostgreSQL 数据库操作 - CRUD、RPC、迁移、高级查询（CSV 导入导出、批量 upsert）、管理接口、Schema 浏览 |
| **storage/** | 文件存储 - 上传/下载/管理、桶策略、公开/私有桶、S3 访问密钥管理 |
| **s3-gateway/** | **S3 兼容网关** - 完整的 S3 API 兼容层（ListBuckets、CreateBucket、PutObject、GetObject、多部分上传、CopyObject 等 15+ S3 操作） |
| **ai/** | AI 模型网关 - OpenAI 兼容 API，支持聊天补全（流式/非流式）、图像生成、嵌入向量、工具调用、联网搜索、文件解析 |
| **functions/** | 无服务器函数 - Deno Subhosting / 本地 Deno 运行时边缘函数 |
| **realtime/** | 实时通信 - WebSocket (Socket.IO) 发布/订阅、频道管理、消息持久化、在线状态（Presence）、Webhook 推送 |
| **payments/** | 支付系统 - Stripe Checkout、Customer Portal、订阅管理、价格目录 |
| **compute/** | 计算服务 - 长期运行的容器服务（Fly.io / Cloud 提供商） |
| **deployments/** | 部署服务 - Vercel 集成、直接上传部署、自定义域名、环境变量管理 |
| **email/** | 邮件服务 - SMTP/云邮件发送、自定义模板 |
| **webhooks/** | Webhook 处理 - Stripe、Vercel 事件接收 |
| **schedules/** | 定时任务 - Cron 调度、执行日志、保留策略 |
| **secrets/** | 密钥管理 - 加密存储、API Key 轮换、函数密钥注入 |
| **usage/** | 用量统计 - MCP 工具使用记录、项目统计 |
| **logs/** | 日志系统 - CloudWatch/Local、审计日志、系统日志 |
| **metadata/** | 后端元数据 - 项目配置信息（auth、database、storage、functions、realtime、deployments 等模块元数据聚合）、API Key 查询、数据库连接信息 |
| **docs/** | API 文档 - OpenAPI 规范 |
| **posthog/** | **PostHog 分析集成** - 产品分析 Dashboard、趋势图表、会话录制、留存分析 |

#### 服务层 (`services/`)
每个路由模块对应一个服务层，处理业务逻辑：
- **auth/**: 认证服务（注册/登录/会话）、认证配置（禁用注册、自动确认）、OTP 服务（邮件验证码）、OAuth PKCE 服务
- **database/**: 数据库管理（Schema/表/函数/索引/触发器/RLS 策略）、记录 CRUD、高级操作（CSV 导入导出、批量 upsert、原始 SQL）、迁移管理
- **storage/**: 存储服务（上传/下载/删除/列表）、S3 访问密钥管理、S3 签名（SigV4）、存储配置
- **ai/**: 聊天补全（流式/非流式）、图像生成、嵌入向量、AI 模型管理（启用/禁用/用量追踪）
- **functions/**: 函数部署与调用、Deno Subhosting 同步、代码预检查
- **payments/**: 支付状态、Checkout Session、Customer Portal、价格目录同步、Stripe Customer 镜像
- **realtime/**: 频道管理、消息持久化与保留策略、在线状态（Presence）、认证鉴权、Webhook 发送
- **logs/**: 审计日志（查询/统计/清理）、系统日志（多来源聚合）
- **schedules/**: 定时任务 CRUD、执行日志、保留策略
- **secrets/**: 密钥加密存储（AES-256-GCM）、API Key 管理
- **usage/**: MCP 工具使用统计
- **email/**: 邮件发送、SMTP 配置、邮件模板管理
- **deployments/**: 部署创建（传统/直接上传）、Vercel 集成、自定义域名
- **compute/**: 计算服务生命周期管理（创建/删除/监控）
- **posthog/**: PostHog 连接管理、Dashboard 代理、趋势/留存/录制数据
- **db/**: 用户上下文服务（RLS 角色映射）
- **database/postgrest-proxy/**: PostgREST 代理服务 - 将客户端 CRUD 请求代理转发到 PostgREST（v12），自动注入认证头和 Schema 信息
- **database/admin-record/**: 管理员记录服务 - 绕过 PostgREST 直接操作数据库，支持分页、搜索、排序、过滤
- **database/database-advance/**: 高级数据库操作 - SQL 清理（严格/宽松模式）、CSV 导入导出、批量 upsert、数据库导出
- **database/database-table/**: 表结构管理 - 创建/修改/删除表，自动审计日志记录

#### 提供商层 (`providers/`)
抽象化第三方服务集成：
- **OAuth**: 10+ 提供商 (Google, GitHub, Apple, Discord, Facebook, LinkedIn, Microsoft, X)，支持自定义 OAuth
- **Storage**: S3 (AWS)、Local (文件系统)、S3 兼容（Wasabi、MinIO 等）
- **AI**: OpenRouter (多模型网关，支持 Claude、GPT、Gemini、DeepSeek 等)
- **Compute**: Fly.io、Cloud 提供商
- **Database**: Cloud、Base
- **Email**: Cloud、SMTP、Base
- **Logs**: CloudWatch、Local、Base
- **Payments**: Stripe
- **Deployments**: Vercel
- **PostHog**: Cloud、Local、Base（产品分析集成）

#### 基础设施 (`infra/`)
- **Database Manager**: PostgreSQL 连接池管理（pg Pool，最大 20 连接）、列类型缓存（LRU，5 分钟 TTL）、Schema 缓存
- **Realtime Manager**: 基于 PostgreSQL `LISTEN/NOTIFY` 的实时消息分发，自动重连（最多 10 次，指数退避），消息路由到 WebSocket 和 Webhook
- **Socket Manager**: Socket.IO 服务器管理，支持 JWT 和 API Key 双认证，房间广播、在线状态（Presence）追踪
- **Token Manager**: JWT 令牌管理（HS256），Access Token（15 分钟）、Refresh Token（7 天）、API Key Token（永不过期），支持 Cloud JWKS 远程验证
- **Encryption Manager**: AES-256-GCM 加密，用于密钥和敏感数据保护，支持独立 ENCRYPTION_KEY 或回退到 JWT_SECRET

#### 数据访问架构

InsForge 采用 **双层数据访问架构**：

1. **客户端 CRUD → PostgREST 代理**:
   - 客户端 SDK 的 `select()`、`insert()`、`update()`、`delete()` 操作通过 `PostgrestProxyService` 转发到 PostgREST
   - PostgREST 自动将 REST 请求转换为 SQL 查询
   - 自动注入认证头（JWT Token）和 Schema 信息
   - 支持 PostgREST 的高级查询语法（过滤、排序、分页、嵌套资源）

2. **管理操作 → 直连数据库**:
   - Dashboard 的管理操作（表结构修改、Schema 浏览、原始 SQL）通过 `AdminRecordService` 直连 PostgreSQL
   - 绕过 PostgREST 的限制，支持 DDL 操作
   - 所有管理操作自动记录审计日志
   - 通过 Socket.IO 广播数据变更通知

```
Client SDK (select/insert/update/delete)
  → InsForge Backend (PostgrestProxyService)
    → PostgREST (port 3000)
      → PostgreSQL

Dashboard Admin (table management, raw SQL)
  → InsForge Backend (AdminRecordService)
    → PostgreSQL (direct)
```

#### 中间件层 (`api/middlewares/`)
- **auth.ts**: 多级认证 - `verifyUser`（用户/API Key）、`verifyAdmin`（管理员）、`verifyCloudBackend`（Cloud 后端间通信）、`verifyApiKey`（API Key 认证）
- **error.ts**: 统一错误处理，结构化错误响应（错误码、建议操作）
- **rate-limiters.ts**: 速率限制 - 全局限制（15 分钟 3000 次）、邮件 OTP 限制、S3 访问密钥管理限制
- **s3-sigv4.ts**: AWS Signature V4 验证中间件，支持 S3 网关的请求签名认证
- **upload.ts**: 动态文件上传处理（Multer），支持多种文件大小限制

#### 工具层 (`utils/`)
- **sql-parser.ts**: SQL 语句解析器 - 分析原始 SQL 中的 DDL/DML 操作，提取受影响的表名和操作类型，用于触发实时数据变更广播
- **response.ts**: 统一响应格式 - `successResponse`、`paginatedResponse`、`errorResponse`
- **validations.ts**: 输入验证工具 - 表名验证、Schema 名规范化
- **logger.ts**: 结构化日志（Winston），支持多级别日志输出

---

### 🎨 前端 Dashboard (`packages/dashboard/`)

基于 **React 19 + Vite + Tailwind CSS 4** 的共享 Dashboard 包，作为 npm 包发布（`@insforge/dashboard`），被 `frontend/` 宿主应用引用：

**功能模块**:
- **AI 管理**: 模型列表（启用/禁用）、信用额度追踪、OpenRouter 密钥管理、AI 快速入门指南
- **认证管理**: 用户管理（CRUD、分页）、OAuth 配置（10+ 提供商）、自定义 OAuth、SMTP 设置、邮件模板编辑、匿名 Token 管理
- **数据库管理**: 数据表格编辑（DataGrid，支持 Boolean/Date/JSON 单元格编辑器）、SQL 编辑器（CodeMirror，支持 SQL/JS/Python 语法高亮）、Schema 浏览、CSV 导入导出
- **计算服务**: 服务创建/删除/监控、服务事件日志
- **存储管理**: 桶列表、文件浏览、S3 访问密钥管理
- **Dashboard 首页**: 连接指南（MCP/CLI/连接字符串）、DTest 新手引导、指标监控（可观测性图表）、后端顾问建议系统
- **PostHog 分析**: 产品分析 Dashboard、KPI 趋势图、会话录制回放、留存分析、时间范围选择器
- **UI 组件**: Radix UI 原语（Avatar、Popover、ScrollArea、Separator、Label、Form）、代码编辑器、数据网格（排序、分页、行选择）、主题切换

**技术特点**:
- 使用 `@tanstack/react-query` 进行服务端状态管理
- 使用 `@hookform/resolvers` + Zod 进行表单验证
- 支持 Cloud Hosting 和 Self Hosting 两种宿主模式
- 通过 Socket.IO 接收实时数据更新通知

---

### 📚 文档系统 (`docs/`)

完整的 Mintlify 文档站点，包含：
- **核心概念**: AI、认证、计算、数据库、部署、邮件、函数、支付、实时、存储
- **SDK 文档**: TypeScript、Kotlin、Swift、REST API
- **部署指南**: AWS EC2、Azure、GCP、Render
- **框架指南**: Next.js、Nuxt、React、Svelte、Vue
- **设计规范**: S3 兼容网关、支付系统、后端分支等

---

### 🚀 部署方案 (`deploy/`)

- **Docker Compose**: 本地/自托管部署，4 个容器（PostgreSQL + PostgREST + InsForge + Deno）
- **Docker Init**: 数据库初始化脚本（JWT 配置、PostgreSQL 调优）、日志向量化配置（Vector）
- **Zeabur**: 一键部署模板
- **Dockerfile**: 多阶段构建（5 阶段：package-prep → deps → build → prod-deps → production），优化缓存和镜像大小
- **独立 Dockerfile**: Deno 运行时镜像、PostgreSQL 扩展镜像（含 pg_cron、pg_net、pgjwt 等）

### 🔄 CI/CD (`github/workflows/`)

- `build-image.yml` - Docker 镜像构建与发布
- `ci-premerge-check.yml` - 合并前检查（lint + typecheck + test）
- `e2e.yml` - 端到端测试
- `lint-and-format.yml` - 代码风格检查（ESLint + Prettier）
- `unit-tests.yml` - 单元测试（Vitest）

### 🔐 安全架构

**认证体系**:
- JWT Access Token（HS256，15 分钟有效期）
- JWT Refresh Token（HS256，7 天有效期，httpOnly Cookie）
- API Key 认证（`ik_` 前缀，永不过期）
- Cloud 后端间 JWT 验证（JWKS 远程密钥集）
- OAuth 2.0 PKCE 流程（防 CSRF）

**数据保护**:
- AES-256-GCM 加密存储密钥和敏感配置
- 独立的 ENCRYPTION_KEY 环境变量（回退到 JWT_SECRET）
- PostgreSQL 行级安全策略（RLS）
- 请求速率限制（全局 + 按端点）

**API 安全**:
- CORS 配置（支持凭证跨域）
- S3 SigV4 签名验证
- Webhook 原始 Body 签名验证（Stripe/Vercel）
- 结构化错误响应（不泄露内部细节）

### � 实时通信架构

InsForge 的实时系统采用 **双层架构**：

1. **客户端层（Socket.IO）**:
   - 基于 WebSocket 的长连接
   - 支持 JWT 和 API Key 双认证
   - 房间（Room）隔离：`role:project_admin`、`channel:<name>`
   - 在线状态（Presence）追踪：成员加入/离开事件
   - 自动重连机制

2. **服务端层（PostgreSQL LISTEN/NOTIFY）**:
   - 专用数据库连接监听 `realtime_message` 频道
   - 消息通过 `realtime.publish()` PostgreSQL 函数触发
   - 消息 ID 传递（绕过 8KB 通知载荷限制）
   - 自动重连（最多 10 次，指数退避 5s 起）
   - 消息分发：WebSocket 广播 + Webhook HTTP POST

**消息生命周期**:
```
Client publish → REST API → DB insert → pg_notify → RealtimeManager
  → fetch message + channel → WebSocket broadcast + Webhook POST
  → update delivery stats
```

### 📐 设计规范与规划 (`docs/superpowers/`)

项目采用 **Spec-driven development** 模式，每个重要功能都有对应的设计规范：

| 规范 | 描述 |
|------|------|
| Custom SMTP | 自定义邮件发送服务器配置 |
| Compute Dashboard UX | 计算服务管理界面设计 |
| Direct Deploy Flow | 前端直接上传部署流程 |
| Custom Database Migrations | 用户自定义数据库迁移系统 |
| Compute Cloud Provider | 计算服务云提供商抽象 |
| DTest Onboarding | 新手引导和快速入门体验 |
| S3 Compatible Storage Gateway | S3 兼容存储网关完整设计 |
| Backend Branching (OSS) | 后端数据库分支功能 |
| Stripe Payments Implementation | Stripe 支付系统完整实现 |
| Payments Customers Mirror | Stripe Customer 数据镜像同步 |

### 📦 共享包 (`packages/`)

| 包名 | 版本 | 描述 |
|------|------|------|
| `@insforge/dashboard` | 0.0.0-dev.11 | 共享 Dashboard 组件库，包含所有管理页面和功能模块 |
| `@insforge/ui` | 0.1.3 | UI 组件库，提供 Radix UI 封装、设计 Token、Tailwind 预设 |
| `@insforge/shared-schemas` | 1.1.52 | 共享 Zod Schema 定义，前后端类型一致性保证 |

### 📚 文档系统 (`docs/`)

基于 **Mintlify** 的文档站点，包含：
- **核心概念**: AI、认证、计算、数据库（含迁移/分支/pgvector）、部署、邮件（含自定义 SMTP）、函数（含定时任务）、支付、实时、存储（含 S3 兼容）
- **SDK 文档**: TypeScript、Kotlin、Swift、REST API
- **部署指南**: AWS EC2、Azure、GCP、Render、安全部署指南
- **框架指南**: Next.js、Nuxt、React、Svelte、Vue
- **OpenAPI 规范**: 13 个 API 参考文档（Tables、Auth、Records、Storage、AI、Functions、Realtime、Email、Payments、Secrets、Logs、Metadata、Health）
- **MCP 设置指南**: 支持 Cursor、Claude Code、Copilot、Windsurf、Trae、Cline、Roo Code、Qoder、Kiro、Antigravity、Codex 等 10+ AI 工具
- **社区展示**: 用户项目案例展示
- **更新日志**: 版本历史记录

### 🧪 测试体系 (`backend/tests/`)

| 测试类型 | 目录 | 框架 | 说明 |
|---------|------|------|------|
| 单元测试 | `tests/unit/` | Vitest | 40+ 测试文件，覆盖服务层、Provider、工具函数 |
| 端到端测试 | `tests/local/` | Shell 脚本 | 15+ 测试脚本，覆盖 Auth、Database、Storage、Functions、Schedules、Secrets、RLS 等 |
| 云端测试 | `tests/cloud/` | Shell 脚本 | S3 网关多租户测试 |
| 手动测试 | `tests/manual/` | SQL/Shell | 大数据量、AI 嵌入、批量 upsert 等场景测试 |

### 💡 核心设计理念

1. **AI 代理优先**: 通过 MCP Server 和 CLI 让 AI 编码代理直接操作后端，提供 `fetch-docs`、`run-raw-sql`、`create-bucket` 等专用工具
2. **S3 兼容存储**: 完整的 S3 API 兼容层（15+ S3 操作），支持 AWS S3 SDK 直接接入，兼容 Wasabi、MinIO 等 S3 兼容存储
3. **多租户架构**: 每个项目隔离的数据库和存储空间，Cloud 模式通过 JWT claim 中的 projectId 隔离
4. **提供商抽象**: 通过 Provider 模式支持多种第三方服务切换（Base/Cloud 双模式），所有 Provider 实现统一接口
5. **OpenAPI 规范**: 13 个 API 参考文档，完整的 OpenAPI 3.0 规范，自动生成 API 文档
6. **Spec-driven Development**: 重要功能先写设计规范（plan + design），再实现代码
7. **实时优先**: 通过 Socket.IO + PostgreSQL LISTEN/NOTIFY 双层架构实现实时数据推送
8. **安全默认**: AES-256-GCM 加密、JWT 双 Token 机制、速率限制、RLS 策略

---

### 🔌 API 路由总览

所有 API 挂载在 `/api` 前缀下：

| 路由前缀 | 认证要求 | 说明 |
|---------|---------|------|
| `/api/health` | 无 | 健康检查 |
| `/api/auth/*` | 混合 | 认证相关（注册/登录公开，管理需 admin） |
| `/api/database/*` | admin | 数据库管理操作 |
| `/api/storage/*` | 混合 | 存储操作（公开桶下载无需认证） |
| `/api/ai/*` | user | AI 模型调用 |
| `/api/functions/*` | admin | 函数管理 |
| `/api/realtime/*` | admin | 实时配置管理 |
| `/api/payments/*` | 混合 | 支付（Checkout 需 user，管理需 admin） |
| `/api/email/*` | user | 邮件发送 |
| `/api/deployments/*` | admin | 部署管理 |
| `/api/schedules/*` | admin | 定时任务管理 |
| `/api/secrets/*` | admin | 密钥管理 |
| `/api/usage/*` | 混合 | 用量统计 |
| `/api/logs/*` | admin | 日志查询 |
| `/api/metadata/*` | 无 | 后端元数据 |
| `/api/docs/*` | 无 | API 文档 |
| `/api/compute/services/*` | admin | 计算服务管理 |
| `/api/integrations/posthog/*` | user/admin | PostHog 分析集成 |
| `/api/webhooks/*` | 无（签名验证） | Stripe/Vercel Webhook |
| `/storage/v1/s3/*` | SigV4 | S3 兼容网关 |
| `/functions/:slug` | 无（代理） | 边缘函数调用代理 |

