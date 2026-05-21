# InsForge 完整使用指南：从零开始构建全栈应用

> 本文档面向希望使用 InsForge 构建全栈应用的开发者，涵盖从项目创建、环境配置到各功能模块使用的完整流程。

---

## 目录

1. [InsForge 是什么](#1-insforge-是什么)
2. [快速开始：创建项目](#2-快速开始创建项目)
3. [连接 AI 编码助手（MCP 配置）](#3-连接-ai-编码助手mcp-配置)
4. [SDK 安装与客户端初始化](#4-sdk-安装与客户端初始化)
5. [数据库操作](#5-数据库操作)
6. [用户认证系统](#6-用户认证系统)
7. [文件存储](#7-文件存储)
8. [AI 集成](#8-ai-集成)
9. [无服务器函数](#9-无服务器函数)
10. [实时通信](#10-实时通信)
11. [支付集成](#11-支付集成)
12. [邮件服务](#12-邮件服务)
12B. [日志系统](#12b-日志系统)
12C. [用量统计](#12c-用量统计)
13. [部署前端应用](#13-部署前端应用)
13B. [密钥管理](#13b-密钥管理)
13C. [定时任务](#13c-定时任务schedules)
13D. [计算服务](#13d-计算服务compute)
13E. [PostHog 分析集成](#13e-posthog-分析集成)
13F. [S3 兼容网关](#13f-s3-兼容网关)
14. [完整项目示例：构建一个博客应用](#14-完整项目示例构建一个博客应用)
15. [最佳实践与常见问题](#15-最佳实践与常见问题)

---

## 1. InsForge 是什么

**InsForge** 是一个开源的全栈后端即服务（BaaS）平台，专为 AI 辅助开发场景设计。它提供了一整套后端基础设施，让开发者（和 AI 编码代理）无需编写后端代码即可构建完整应用。

### 核心功能

| 功能 | 说明 |
|------|------|
| **PostgreSQL 数据库** | 自动生成 REST API，无需编写 CRUD 代码 |
| **用户认证** | 邮箱/密码 + OAuth（Google、GitHub、Apple 等 10+ 提供商） |
| **文件存储** | S3 兼容的对象存储，支持公开/私有桶 |
| **AI 模型网关** | OpenAI 兼容 API，支持多模型提供商（Claude、GPT、Gemini 等） |
| **无服务器函数** | 基于 Deno 的边缘函数，支持 TypeScript |
| **实时通信** | WebSocket 发布/订阅 |
| **支付集成** | Stripe Checkout 和 Billing Portal |
| **邮件服务** | SMTP 和云邮件发送 |
| **站点部署** | 前端应用构建与部署 |

### 两种使用方式

| 方式 | 适用场景 | 特点 |
|------|---------|------|
| **InsForge Cloud** | 快速原型、中小型项目 | 免运维、自动扩容、即开即用 |
| **自托管（Self-hosting）** | 企业内网、数据合规、定制化需求 | 完全掌控、数据本地化、无外部依赖 |

---

## 2. 快速开始：Cloud 托管

### 2.1 注册并创建项目

1. 访问 [insforge.dev](https://insforge.dev) 注册免费账号
2. 点击 **"Create New Project"**
3. 等待约 3 秒，后端自动就绪
4. 从浏览器 URL 中复制 **Project ID**：
   ```
   https://insforge.dev/dashboard/project/<your-project-id>
   ```

### 2.2 安装 CLI 并链接项目

在本地项目目录中运行：

```bash
npx @insforge/cli link --project-id <your-project-id>
```

### 2.3 获取后端元数据

通过 MCP 工具或 CLI 获取后端 URL 和匿名密钥：

```bash
npx @insforge/cli get-backend-metadata
```

你会得到类似以下信息：

```
Base URL: https://your-app.us-east.insforge.app
Anon Key: eyJhbGciOiJIUzI1NiIs...
```

---

## 2B. 自托管（Self-hosting）部署指南

> 本章节适用于需要在自有服务器或本地环境部署 InsForge 的场景。自托管模式下，所有数据存储在你自己的机器上，无需依赖外部云服务。

### 2B.1 前置条件

- **Docker** 和 **Docker Compose** 已安装
- 至少 2 核 CPU、4 GB 内存（生产环境建议 4 核 8 GB）
- 至少 20 GB 可用磁盘空间
- 操作系统：Linux（推荐 Ubuntu 22.04+）、macOS、Windows（WSL2）

### 2B.2 下载部署文件

```bash
# 创建项目目录
mkdir my-insforge-project && cd my-insforge-project

# 下载 Docker Compose 配置和环境变量模板
wget https://raw.githubusercontent.com/insforge/insforge/main/deploy/docker-compose/docker-compose.yml
wget https://raw.githubusercontent.com/insforge/insforge/main/deploy/docker-compose/.env.example
cp .env.example .env
```

### 2B.3 配置环境变量

编辑 `.env` 文件，**必须修改**以下关键配置：

```bash
# ============================================================
# 数据库配置
# ============================================================
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your-strong-password-here    # ⚠️ 必须修改
POSTGRES_DB=insforge

# ============================================================
# 端口配置（如需运行多个实例，修改端口避免冲突）
# ============================================================
POSTGRES_PORT=5432
POSTGREST_PORT=5430
APP_PORT=7130          # InsForge 主应用端口
AUTH_PORT=7131         # InsForge 认证服务端口
DENO_PORT=7133         # Deno 边缘函数运行时端口

# ============================================================
# API 地址（自托管使用 localhost 或服务器 IP）
# ============================================================
API_BASE_URL=http://localhost:7130
VITE_API_BASE_URL=http://localhost:7130

# ============================================================
# 安全配置 ⚠️ 生产环境必须修改
# ============================================================
JWT_SECRET=your-secret-key-at-least-32-characters-long-here
ADMIN_EMAIL=admin@example.com
ADMIN_PASSWORD=change-this-password

# 加密密钥（用于数据库加密和函数密钥解密，不设置则使用 JWT_SECRET）
ENCRYPTION_KEY=

# ============================================================
# AI 模型网关（可选）
# ============================================================
OPENROUTER_API_KEY=    # 从 https://openrouter.ai/keys 获取

# ============================================================
# OAuth 登录（可选）
# ============================================================
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
GITHUB_CLIENT_ID=
GITHUB_CLIENT_SECRET=
```

### 2B.4 启动 InsForge

```bash
docker compose up -d
```

验证所有服务正常运行：

```bash
docker compose ps
```

预期输出（4 个容器均为 `running` 或 `healthy` 状态）：

```
NAME            SERVICE     STATUS
insforge        insforge    running
postgres        postgres    healthy
postgrest       postgrest   healthy
deno            deno        running
```

验证健康检查：

```bash
curl http://localhost:7130/api/health
```

预期响应：

```json
{
  "status": "ok",
  "version": "1.x.x",
  "service": "Insforge OSS Backend",
  "timestamp": "2026-..."
}
```

#### 容器端口架构说明

Docker Compose 中每个服务的端口映射关系：

```
宿主机                         Docker 内部网络
───────                       ──────────────
                              ┌─────────────────┐
                              │   PostgreSQL     │
                              │   监听 :5432      │
                              └────────┬────────┘
                                       │
                              ┌────────┴────────┐
                              │   PostgREST      │
                              │   监听 :3000      │◄── 内部端口，仅容器间通信
                              └────────┬────────┘
                                       │  http://postgrest:3000
                              ┌────────┴────────┐
:7130 ◄──────────────────────►│   InsForge       │
:7131 ◄──────────────────────►│   监听 :7130      │◄── 外部唯一入口
                              └────────┬────────┘
                                       │
                              ┌────────┴────────┐
:7133 ◄──────────────────────►│   Deno           │
                              │   监听 :7133      │
                              └─────────────────┘
```

| 容器 | 内部端口 | 宿主机映射 | 用途 |
|------|---------|-----------|------|
| PostgreSQL | 5432 | `${POSTGRES_PORT:-5432}` | 数据库服务，仅容器间通信 |
| PostgREST | 3000 | `${POSTGREST_PORT:-5430}` | REST API 网关，**仅 InsForge 后端通过 `http://postgrest:3000` 调用** |
| InsForge | 7130 | `${APP_PORT:-7130}` | **外部唯一入口**，Dashboard + API |
| Deno | 7133 | `${DENO_PORT:-7133}` | 边缘函数运行时 |

> **关键理解**：PostgREST 的内部端口 3000 仅供 InsForge 后端在 Docker 内部网络中调用。外部请求的数据流是：
> ```
> 客户端 → InsForge(:7130) → PostgREST(postgrest:3000) → PostgreSQL(:5432)
> ```
> PostgREST 本身没有认证层，认证由 InsForge 后端注入 JWT。生产环境不应将 PostgREST 端口（5430）对外暴露，所有请求应统一经过 InsForge 后端。

### 2B.5 访问 Dashboard 并获取 ANON_KEY

1. 打开浏览器访问 `http://localhost:7130`
2. 使用 `.env` 中配置的 `ADMIN_EMAIL` 和 `ADMIN_PASSWORD` 登录
3. 进入 **Settings → API** 页面，复制 **Anon Key**（匿名密钥）

> **注意**：自托管模式下，`ANON_KEY` 不会自动生成。首次登录后需在 Dashboard 中手动获取。该密钥用于 SDK 客户端初始化。

### 2B.6 自托管 SDK 客户端初始化

自托管模式下的 SDK 初始化与 Cloud 模式**完全相同**，仅 `baseUrl` 不同：

```typescript
import { createClient } from '@insforge/sdk';

const insforge = createClient({
  baseUrl: 'http://localhost:7130',        // 自托管：本地地址
  anonKey: 'your-anon-key-from-dashboard', // 从 Dashboard Settings → API 获取
});
```

> **对比 Cloud 模式**：Cloud 模式的 `baseUrl` 为 `https://your-app.region.insforge.app`，其余用法完全一致。

### 2B.7 自托管 MCP 配置

自托管模式下，使用 `npx @insforge/install` 命令一键配置 MCP，或手动在 AI 编码工具的 MCP 配置中添加：

```json
{
  "mcpServers": {
    "insforge": {
      "command": "npx",
      "args": ["-y", "@insforge/mcp@latest"],
      "env": {
        "API_KEY": "your-api-key-here",
        "API_BASE_URL": "http://localhost:7130"
      }
    }
  }
}
```

> **提示**：API Key 以 `ik_` 为前缀，可从 Dashboard Settings → API 页面获取。MCP 配置的实际路径因工具而异（如 Trae 为 `~/.config/Trae/User/mcp.json`）。

### 2B.8 自托管与 Cloud 模式的关键差异

| 维度 | Cloud 模式 | 自托管模式 |
|------|-----------|-----------|
| **baseUrl** | `https://your-app.region.insforge.app` | `http://localhost:7130`（或服务器 IP） |
| **ANON_KEY 获取** | CLI `get-backend-metadata` 自动获取 | Dashboard Settings → API 手动复制 |
| **Edge Functions** | 云端 Deno Subhosting 自动部署 | 本地 Deno 容器（端口 7133），需挂载函数目录 |
| **数据库直连** | 不可直连 PostgreSQL | 可直连 `localhost:${POSTGRES_PORT}`（默认 5432），也可通过 PostgREST `localhost:${POSTGREST_PORT}`（默认 5430）访问 REST API |
| **存储** | 云端 S3 兼容存储 | 本地卷存储（`storage-data`），也可配置外部 S3 |
| **AI 模型** | 通过 OpenRouter 网关 | 需自行配置 `OPENROUTER_API_KEY` |
| **OAuth** | Dashboard 配置 | `.env` 文件中配置 |
| **SSL/HTTPS** | 自动提供 | 需自行配置反向代理（Nginx/Caddy） |
| **升级** | 自动升级 | 手动 `docker compose pull && docker compose up -d` |

### 2B.9 自托管多实例管理

在同一台机器上运行多个 InsForge 实例：

```bash
# 为每个实例创建独立的环境文件
cp .env .env.project1
cp .env .env.project2

# 修改各实例的端口（避免冲突）
# .env.project1: POSTGRES_PORT=5432, APP_PORT=7130
# .env.project2: POSTGRES_PORT=5442, APP_PORT=7230

# 使用不同的项目名称启动
docker compose --env-file .env.project1 -p project1 up -d
docker compose --env-file .env.project2 -p project2 up -d
```

### 2B.10 自托管生产环境建议

1. **使用反向代理**：通过 Nginx 或 Caddy 配置 HTTPS
2. **配置防火墙**：仅暴露 7130 端口（或通过反向代理暴露 80/443），内部端口（5432、5430、7133）不对外
3. **定期备份**：备份 PostgreSQL 数据卷和 `storage-data` 卷
4. **监控日志**：`docker compose logs -f` 查看实时日志
5. **锁定版本**：在 `docker-compose.yml` 中指定镜像版本号，避免意外升级

---

## 3. 连接 AI 编码助手（MCP 配置）

InsForge 提供 MCP（Model Context Protocol）服务器，让 AI 编码代理可以直接操作你的后端。

### 3.1 Cloud 模式 MCP 配置

在 Dashboard 中点击 **Connect MCP**，按提示复制配置到你的 AI 编码工具中。

### 3.2 自托管模式 MCP 配置

自托管模式下，使用安装命令一键配置：

```bash
npx @insforge/install --client <your-ai-tool> --env API_KEY=<your-api-key> --env API_BASE_URL=http://localhost:7130
```

或手动在 AI 编码工具的 MCP 配置中添加：

```json
{
  "mcpServers": {
    "insforge": {
      "command": "npx",
      "args": ["-y", "@insforge/mcp@latest"],
      "env": {
        "API_KEY": "your-api-key-here",
        "API_BASE_URL": "http://localhost:7130"
      }
    }
  }
}
```

### 3.3 支持的 AI 工具

- **Cursor** - 在 Settings → Tools & MCP 中添加 MCP JSON
- **Claude Code** - 在终端中运行安装命令
- **GitHub Copilot** - 在 Copilot 终端中运行安装命令
- **Windsurf** - 在终端中运行安装命令
- **Trae** - 在终端中运行安装命令
- **Cline / Roo Code / Qoder / Kiro** - 在对应工具中添加 MCP JSON
- **Antigravity** - 在终端中运行安装命令
- **Codex** - 在终端中运行安装命令
- **OpenClaw / OpenCode** - 在终端中运行安装命令

### 验证连接

向 AI 编码代理发送以下提示：

```
I'm using InsForge as my backend platform, call InsForge MCP's fetch-docs tool to
learn about InsForge instructions.
```

如果连接成功，InsForge Dashboard 右上角会显示 **Connected** 状态。

---

## 4. SDK 安装与客户端初始化

### 4.1 安装 SDK

```bash
npm install @insforge/sdk@latest
```

### 4.2 创建客户端实例

**Cloud 模式**：

```typescript
import { createClient } from '@insforge/sdk';

const insforge = createClient({
  baseUrl: 'https://your-app.us-east.insforge.app',
  anonKey: 'your-anon-key-here',
});
```

**自托管模式**：

```typescript
import { createClient } from '@insforge/sdk';

const insforge = createClient({
  baseUrl: 'http://localhost:7130',          // 自托管本地地址
  anonKey: 'your-anon-key-from-dashboard',   // 从 Dashboard Settings → API 获取
});
```

> **提示**：将客户端配置放在单独的文件中（如 `lib/insforge.ts`），方便全局引用。两种模式的 SDK API 完全一致，仅 `baseUrl` 不同。

### 4.3 SDK 返回结构

所有 SDK 操作都返回统一的 `{ data, error }` 结构：

```typescript
const { data, error } = await insforge.database.from('posts').select();

if (error) {
  console.error('操作失败:', error.message);
  return;
}

console.log('数据:', data);
```

---

## 5. 数据库操作

InsForge 使用 **PostgreSQL + PostgREST** 自动为每个表生成 REST API。你通过 SDK 进行类型安全的 CRUD 操作。

### 5.1 创建表

**方式一：通过 MCP 工具**

AI 编码代理可以直接调用 `run-raw-sql` MCP 工具创建表：

```sql
CREATE TABLE posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  content TEXT,
  user_id UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

**方式二：通过 Dashboard**

在 InsForge Dashboard 的 Database 页面中直接使用 SQL 编辑器。

### 5.2 查询数据（select）

```typescript
// 查询所有记录
const { data, error } = await insforge.database
  .from('posts')
  .select('*');

// 带条件查询
const { data, error } = await insforge.database
  .from('posts')
  .select('title, content, created_at')
  .eq('user_id', userId)
  .order('created_at', { ascending: false })
  .limit(10);

// 查询单条记录
const { data, error } = await insforge.database
  .from('posts')
  .select('*')
  .eq('id', postId)
  .single();

// 分页查询
const { data, error, count } = await insforge.database
  .from('posts')
  .select('*', { count: 'exact' })
  .range(0, 19);  // 第 1 页，每页 20 条
```

### 5.3 插入数据（insert）

```typescript
// 单条插入
const { data, error } = await insforge.database
  .from('posts')
  .insert({
    title: 'Hello World',
    content: '这是我的第一篇文章！',
    user_id: userId,
  })
  .select();

// 批量插入（注意：使用数组格式）
const { data, error } = await insforge.database
  .from('posts')
  .insert([
    { title: '文章一', content: '内容一' },
    { title: '文章二', content: '内容二' },
  ])
  .select();
```

### 5.4 更新数据（update）

```typescript
// 务必使用过滤器指定更新目标
const { data, error } = await insforge.database
  .from('posts')
  .update({ title: '更新后的标题', content: '更新后的内容' })
  .eq('id', postId)
  .select();
```

### 5.5 删除数据（delete）

```typescript
// 务必使用过滤器指定删除目标
const { error } = await insforge.database
  .from('posts')
  .delete()
  .eq('id', postId);
```

### 5.6 高级查询

```typescript
// 模糊查询
const { data } = await insforge.database
  .from('posts')
  .select('*')
  .ilike('title', '%hello%');

// 范围查询
const { data } = await insforge.database
  .from('posts')
  .select('*')
  .gte('created_at', '2024-01-01')
  .lte('created_at', '2024-12-31');

// IN 查询
const { data } = await insforge.database
  .from('posts')
  .select('*')
  .in('status', ['published', 'draft']);

// 关联查询（外键关系）
const { data } = await insforge.database
  .from('posts')
  .select('*, comments(*)');

// 嵌套关联
const { data } = await insforge.database
  .from('categories')
  .select('*, posts(*, comments(*))');
```

### 5.7 调用存储过程（RPC）

```typescript
const { data, error } = await insforge.database
  .rpc('get_posts_count', { user_id: userId });
```

### 5.8 高级数据库操作

**CSV 导入导出**：

```typescript
// 导出表数据为 CSV
const { data } = await insforge.database
  .from('posts')
  .select('*')
  .csv();

// 通过 Dashboard 的 Database 页面进行 CSV 导入/导出
// 支持大文件导入，自动处理字段映射
```

**批量 Upsert**：

```typescript
const { data, error } = await insforge.database
  .from('posts')
  .upsert([
    { id: 'existing-id', title: 'Updated Title', content: 'New content' },
    { title: 'New Post', content: 'Brand new post' },
  ], {
    onConflict: 'id',  // 冲突检测字段
    ignoreDuplicates: false,  // false = 更新，true = 忽略
  });
```

**原始 SQL 查询**：

```typescript
// 通过 MCP 工具执行原始 SQL
// run-raw-sql --query "SELECT * FROM posts WHERE created_at > NOW() - INTERVAL '7 days'"

// 通过 SDK 执行（需要 admin 权限）
const { data } = await insforge.database.runSql(`
  SELECT p.title, u.email
  FROM posts p
  JOIN auth.users u ON p.user_id = u.id
  WHERE p.created_at > NOW() - INTERVAL '7 days'
`);
```

### 5.9 数据库迁移

InsForge 支持通过 MCP 工具或 Dashboard 的 SQL 编辑器执行数据库迁移脚本。

**通过 MCP 工具执行迁移**：

```sql
-- 001_create_posts.sql
CREATE TABLE posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  content TEXT,
  user_id UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 002_add_status_column.sql
ALTER TABLE posts ADD COLUMN status TEXT DEFAULT 'draft';
```

**通过 Dashboard SQL 编辑器**：

在 Dashboard 的 Database → SQL Editor 页面中，可以直接编写和执行 SQL 语句。编辑器支持：
- SQL 语法高亮（CodeMirror）
- 多语句执行
- 结果表格展示
- 查询历史记录

**迁移最佳实践**：
1. 将迁移脚本按序号命名（如 `001_xxx.sql`、`002_xxx.sql`）
2. 将迁移脚本纳入 Git 版本管理
3. 在开发环境先测试迁移脚本
4. 使用事务包裹多个相关变更
5. 为迁移编写回滚脚本

### 5.10 数据库 Schema 管理

InsForge 提供完整的数据库 Schema 浏览和管理功能（通过 Dashboard 或 API）：

**浏览 Schema 信息**：

```typescript
// 列出所有 Schema
const { data: schemas } = await insforge.database.getSchemas();

// 列出所有表
const { data: tables } = await insforge.database.getTables();

// 获取表结构
const { data: tableSchema } = await insforge.database.getTableSchema('posts');

// 列出数据库函数
const { data: functions } = await insforge.database.getFunctions();

// 列出索引
const { data: indexes } = await insforge.database.getIndexes();

// 列出 RLS 策略
const { data: policies } = await insforge.database.getPolicies();

// 列出触发器
const { data: triggers } = await insforge.database.getTriggers();
```

**管理表结构**：

```typescript
// 创建表
const { data } = await insforge.database.createTable({
  tableName: 'products',
  columns: [
    { name: 'id', type: 'uuid', defaultValue: 'gen_random_uuid()', isPrimary: true },
    { name: 'name', type: 'text', isNullable: false },
    { name: 'price', type: 'numeric' },
  ],
  rlsEnabled: true,
});

// 修改表结构（添加/修改/删除列）
const { data: updated } = await insforge.database.updateTableSchema('products', [
  { type: 'add_column', column: { name: 'description', type: 'text' } },
]);

// 删除表
await insforge.database.deleteTable('old_table');
```

### 5.11 审计日志

所有数据库管理操作都会自动记录审计日志，可通过 Dashboard 的 Logs 页面查看：

```typescript
// 查询审计日志
const { data } = await insforge.logs.getAudits({
  limit: 50,
  offset: 0,
  actor: 'admin@example.com',   // 按操作者筛选
  action: 'CREATE_TABLE',        // 按操作类型筛选
  module: 'DATABASE',            // 按模块筛选
  start_date: '2026-01-01',
  end_date: '2026-12-31',
});

// 查看审计统计
const { data: stats } = await insforge.logs.getAuditStats({ days: 30 });
```

---

## 6. 用户认证系统

### 6.1 邮箱/密码注册

```typescript
const { data, error } = await insforge.auth.signUp({
  email: 'user@example.com',
  password: 'secure_password123',
  name: '张三',
  redirectTo: 'http://localhost:3000/sign-in',  // 用于邮箱验证链接
});

if (data?.requireEmailVerification) {
  // 需要邮箱验证
  // 如果验证方式为 code：引导用户输入 6 位验证码
  // 如果验证方式为 link：等待用户点击邮件中的链接
  console.log('请验证您的邮箱');
} else if (data?.accessToken) {
  // 注册成功且已登录
  console.log('欢迎！', data.user.email);
}
```

### 6.2 邮箱/密码登录

```typescript
const { data, error } = await insforge.auth.signInWithPassword({
  email: 'user@example.com',
  password: 'secure_password123',
});

if (data) {
  console.log('登录成功:', data.user.email);
  // data.accessToken 自动保存，后续请求自动携带
}
```

### 6.3 OTP 邮箱验证码

InsForge 支持通过邮件发送一次性验证码（OTP）进行身份验证：

```typescript
// 发送验证码
const { data, error } = await insforge.auth.sendOtp({
  email: 'user@example.com',
});

// 验证验证码并登录
const { data: verifyData, error: verifyError } = await insforge.auth.verifyOtp({
  email: 'user@example.com',
  token: '123456',  // 6 位验证码
  type: 'email',    // 'email' | 'signup' | 'recovery'
});

if (verifyData) {
  console.log('验证成功:', verifyData.user.email);
}
```

### 6.4 OAuth 登录

```typescript
// Google 登录（自动跳转）
await insforge.auth.signInWithOAuth({
  provider: 'google',
  redirectTo: 'http://localhost:3000/dashboard',
});

// GitHub 登录（手动处理跳转）
const { data } = await insforge.auth.signInWithOAuth({
  provider: 'github',
  skipBrowserRedirect: true,
});
window.location.href = data.url;
```

支持的 OAuth 提供商：`google`、`github`、`apple`、`discord`、`facebook`、`linkedin`、`microsoft`、`x`，以及自定义 OAuth 提供商。

### 6.5 获取当前用户

```typescript
// 应用启动时调用，自动恢复会话
const { data, error } = await insforge.auth.getCurrentUser();

if (data?.user) {
  console.log('当前用户:', data.user.email);
} else {
  // 未登录
  console.log('未登录');
}
```

### 6.6 退出登录

```typescript
const { error } = await insforge.auth.signOut();
```

### 6.7 邮箱验证

```typescript
// 发送验证码
const { error } = await insforge.auth.verifyEmail({
  email: 'user@example.com',
});

// 验证验证码
const { data, error } = await insforge.auth.verifyEmail({
  email: 'user@example.com',
  code: '123456',  // 用户输入的 6 位验证码
});
```

### 6.8 密码重置

```typescript
// 发送重置密码邮件
const { error } = await insforge.auth.resetPassword({
  email: 'user@example.com',
  redirectTo: 'http://localhost:3000/reset-password',
});

// 使用重置令牌设置新密码
const { data, error } = await insforge.auth.updatePassword({
  password: 'new_secure_password',
});
```

### 6.9 预构建 Auth UI 组件

InsForge 提供开箱即用的认证 UI 组件：

- **React + Vite（单页应用）**：`auth-components-react`
- **React + Vite + React Router（多页应用）**：`auth-components-react-router`
- **Next.js（SSR）**：`auth-components-nextjs`

通过 MCP 工具的 `fetch-docs` 获取对应文档。

---

## 7. 文件存储

### 7.1 创建存储桶

通过 MCP 工具或 Dashboard 创建桶：

```bash
# 通过 MCP 工具
create-bucket --name "images" --public true
```

### 7.2 上传文件

```typescript
// 指定路径上传
const { data, error } = await insforge.storage
  .from('images')
  .upload('posts/post-123/cover.jpg', fileObject);

// 保存 URL 和 key 到数据库
await insforge.database
  .from('posts')
  .update({
    image_url: data.url,
    image_key: data.key,  // 保存 key 用于后续下载/删除
  })
  .eq('id', 'post-123');

// 自动生成唯一 key 上传
const { data, error } = await insforge.storage
  .from('uploads')
  .uploadAuto(fileObject);
```

### 7.3 下载文件

```typescript
// 从数据库获取文件 key
const { data: post } = await insforge.database
  .from('posts')
  .select('image_key')
  .eq('id', 'post-123')
  .single();

// 下载文件
const { data: blob, error } = await insforge.storage
  .from('images')
  .download(post.image_key);

// 创建预览 URL
const url = URL.createObjectURL(blob);
document.querySelector('img').src = url;
```

### 7.4 删除文件

```typescript
const { error } = await insforge.storage
  .from('images')
  .remove(['posts/post-123/cover.jpg']);
```

### 7.5 文件列表

```typescript
const { data, error } = await insforge.storage
  .from('images')
  .list('posts/post-123/');
```

### 7.6 S3 兼容性

InsForge 提供完整的 S3 API 兼容网关，支持：

- AWS SDK 直接接入（`@aws-sdk/client-s3`）
- 多部分上传（大文件分片上传）
- 预签名 URL（临时访问链接）
- 桶策略管理（公开/私有桶）
- S3 访问密钥管理（Access Key + Secret Key）

### 7.7 桶策略与访问控制

```typescript
// 创建公开桶（文件可通过 URL 直接访问）
await insforge.storage.createBucket('public-assets', {
  public: true,
});

// 创建私有桶（需要认证才能访问）
await insforge.storage.createBucket('private-docs', {
  public: false,
});

// 更新桶策略
await insforge.storage.updateBucket('public-assets', {
  public: false,  // 改为私有
});
```

### 7.8 S3 访问密钥管理

在 Dashboard 的 Storage 页面中管理 S3 访问密钥：

```typescript
// 创建 S3 访问密钥对
const { data } = await insforge.storage.createS3Key('my-app-key');

console.log('Access Key:', data.accessKey);
console.log('Secret Key:', data.secretKey);  // 仅创建时可见，请妥善保存

// 列出所有 S3 访问密钥
const { data: keys } = await insforge.storage.listS3Keys();

// 删除 S3 访问密钥
await insforge.storage.deleteS3Key('key-id');
```

---

## 8. AI 集成

InsForge 提供 OpenAI 兼容的 AI API，支持多种模型。

### 8.1 聊天补全（非流式）

```typescript
const completion = await insforge.ai.chat.completions.create({
  model: 'anthropic/claude-3.5-haiku',
  messages: [
    { role: 'user', content: '法国的首都是什么？' }
  ],
});

console.log(completion.choices[0].message.content);
```

### 8.2 聊天补全（流式）

```typescript
const stream = await insforge.ai.chat.completions.create({
  model: 'openai/gpt-4',
  messages: [{ role: 'user', content: '给我讲个故事' }],
  stream: true,
});

for await (const chunk of stream) {
  if (chunk.choices[0]?.delta?.content) {
    process.stdout.write(chunk.choices[0].delta.content);
  }
}
```

### 8.3 带图片的对话

```typescript
const completion = await insforge.ai.chat.completions.create({
  model: 'anthropic/claude-3.5-haiku',
  messages: [
    {
      role: 'user',
      content: [
        { type: 'text', text: '这张图片里有什么？' },
        {
          type: 'image_url',
          image_url: {
            url: 'https://example.com/photo.jpg',
          },
        },
      ],
    },
  ],
});
```

### 8.4 联网搜索

```typescript
const completion = await insforge.ai.chat.completions.create({
  model: 'anthropic/claude-sonnet-4.5',
  messages: [
    { role: 'user', content: '今天有什么重要新闻？' }
  ],
  webSearch: { enabled: true, maxResults: 5 },
});

// 访问引用来源
completion.choices[0].message.annotations?.forEach(annotation => {
  console.log(`- ${annotation.urlCitation.title}: ${annotation.urlCitation.url}`);
});
```

### 8.5 文件解析（PDF 等）

```typescript
const completion = await insforge.ai.chat.completions.create({
  model: 'anthropic/claude-sonnet-4.5',
  messages: [
    {
      role: 'user',
      content: [
        { type: 'text', text: '分析这份研究论文' },
        {
          type: 'file',
          file: {
            filename: 'research-paper.pdf',
            file_data: 'https://example.com/research-paper.pdf',
          },
        },
      ],
    },
  ],
  fileParser: { enabled: true },
});
```

### 8.6 工具调用（Function Calling）

```typescript
const completion = await insforge.ai.chat.completions.create({
  model: 'openai/gpt-4o-mini',
  messages: [{ role: 'user', content: '查询北京的天气' }],
  tools: [{
    type: 'function',
    function: {
      name: 'get_weather',
      description: '获取指定城市的天气信息',
      parameters: {
        type: 'object',
        properties: {
          city: { type: 'string', description: '城市名称' },
        },
        required: ['city'],
      },
    },
  }],
  toolChoice: 'auto',
});
```

### 8.7 图像生成

```typescript
const image = await insforge.ai.images.generate({
  model: 'openai/dall-e-3',
  prompt: '一只可爱的猫咪在沙滩上晒太阳',
  n: 1,
  size: '1024x1024',
});

console.log(image.data[0].url);
```

---

## 9. 无服务器函数

InsForge 支持基于 Deno 的无服务器边缘函数。

> **自托管注意**：自托管模式下，Edge Functions 运行在本地 Deno 容器（端口 7133）。函数源码需挂载到容器的 `/app/functions` 目录。在 `docker-compose.yml` 中配置：
> ```yaml
> deno:
>   volumes:
>     - ./functions:/app/functions
> ```

### 9.1 创建函数

通过 MCP 工具创建：

```bash
create-function --slug "hello-world" --source ./functions/hello-world.ts
```

### 9.2 函数示例

```typescript
// functions/hello-world.ts
import { createClient } from 'npm:@insforge/sdk';

export default async function(req: Request): Promise<Response> {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  };

  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  const body = await req.json();
  const { name } = body;

  return new Response(
    JSON.stringify({ message: `Hello, ${name || 'World'}!` }),
    {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    }
  );
}
```

### 9.3 调用函数

```typescript
// POST 请求（默认）
const { data, error } = await insforge.functions.invoke('hello-world', {
  body: { name: 'InsForge' },
});

// GET 请求
const { data, error } = await insforge.functions.invoke('get-stats', {
  method: 'GET',
});
```

### 9.4 带认证的函数

```typescript
// functions/protected-api.ts
import { createClient } from 'npm:@insforge/sdk';

export default async function(req: Request): Promise<Response> {
  const authHeader = req.headers.get('Authorization');
  const userToken = authHeader ? authHeader.replace('Bearer ', '') : null;

  const client = createClient({
    baseUrl: Deno.env.get('INSFORGE_BASE_URL'),
    edgeFunctionToken: userToken,
  });

  // 获取当前用户
  const { data: userData } = await client.auth.getCurrentUser();
  if (!userData?.user?.id) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  // 操作用户私有数据
  const { data } = await client.database
    .from('user_posts')
    .select('*')
    .eq('user_id', userData.user.id);

  return new Response(JSON.stringify({ posts: data }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
}
```

### 9.5 定时任务（Schedules）

通过 MCP 工具创建定时触发的函数：

```bash
create-schedule --slug "daily-cleanup" --cron "0 0 * * *" --function-slug "cleanup-task"
```

---

## 10. 实时通信

InsForge 提供基于 WebSocket 的实时发布/订阅功能。

### 10.1 连接

```typescript
try {
  await insforge.realtime.connect();
  console.log('已连接:', insforge.realtime.isConnected);
} catch (error) {
  console.error('连接失败:', error.message);
}
```

### 10.2 订阅频道

```typescript
await insforge.realtime.connect();
const response = await insforge.realtime.subscribe('orders:123');

if (response.ok) {
  console.log('已订阅:', response.channel);
  console.log('在线成员:', response.presence.members);
}
```

### 10.3 在线状态（Presence）

实时通信系统支持追踪用户的在线状态：

```javascript
// 监听用户加入频道
insforge.realtime.onPresenceJoin('chat-room', (presence) => {
  console.log(`${presence.userId} 加入了频道`);
  console.log(`当前在线人数: ${presence.count}`);
});

// 监听用户离开频道
insforge.realtime.onPresenceLeave('chat-room', (presence) => {
  console.log(`${presence.userId} 离开了频道`);
});

// 获取当前在线用户列表
const { data: onlineUsers } = await insforge.realtime.getPresence('chat-room');
```

### 10.4 Webhook 推送

除了 WebSocket 实时推送，InsForge 还支持通过 Webhook 将消息推送到外部服务：

```javascript
// 配置 Webhook 端点（通过 Dashboard 或 MCP 工具）
// 当频道有新消息时，InsForge 会 POST 到你的 Webhook URL

// Webhook 接收到的消息格式：
{
  "type": "INSERT",
  "table": "messages",
  "schema": "public",
  "record": {
    "id": 1,
    "content": "Hello World",
    "user_id": "user-123"
  },
  "old_record": null
}
```

### 10.5 消息持久化与保留策略

```javascript
// 配置消息保留策略（通过 Dashboard）
// - 保留所有消息（默认）
// - 保留最近 N 条消息
// - 保留最近 N 天的消息
// - 不保留消息（仅实时推送）
```

### 10.6 完整聊天应用示例

### 10.7 发布消息

```typescript
// 必须先订阅才能发布
await insforge.realtime.subscribe('chat:room-1');

await insforge.realtime.publish('chat:room-1', 'new_message', {
  userId: 'user-123',
  text: '大家好！',
  timestamp: new Date().toISOString(),
});
```

### 10.8 监听事件

```typescript
// 连接事件
insforge.realtime.on('connect', () => {
  console.log('已连接到实时服务器');
});

insforge.realtime.on('disconnect', (reason) => {
  console.log('断开连接:', reason);
});

insforge.realtime.on('connect_error', (error) => {
  console.error('连接错误:', error);
});

// 自定义事件
insforge.realtime.on('new_message', (payload) => {
  console.log('新消息:', payload.text);
});

// 成员进出事件
insforge.realtime.on('presence:join', (member) => {
  console.log('成员加入:', member.presenceId);
});

insforge.realtime.on('presence:leave', (member) => {
  console.log('成员离开:', member.presenceId);
});
```

### 10.9 取消订阅

```typescript
insforge.realtime.unsubscribe('chat:room-1');
```

---

## 11. 支付集成

> **注意**：支付功能目前处于 Private Preview 阶段。

### 11.1 配置 Stripe

在 Dashboard 中配置 Stripe 密钥和产品目录，或通过 CLI：

```bash
npx @insforge/cli payments status
npx @insforge/cli payments catalog --environment test
```

### 11.2 创建 Checkout Session

```typescript
// 一次性支付
const { data, error } = await insforge.payments.createCheckoutSession({
  environment: 'test',
  mode: 'payment',
  lineItems: [{ stripePriceId: 'price_123', quantity: 1 }],
  successUrl: `${window.location.origin}/checkout/success`,
  cancelUrl: `${window.location.origin}/pricing`,
  customerEmail: user?.email ?? null,
});

if (data?.checkoutSession.url) {
  window.location.assign(data.checkoutSession.url);
}

// 订阅支付
const { data, error } = await insforge.payments.createCheckoutSession({
  environment: 'test',
  mode: 'subscription',
  subject: { type: 'team', id: teamId },
  lineItems: [{ stripePriceId: 'price_monthly_123', quantity: 1 }],
  successUrl: `${window.location.origin}/billing/success`,
  cancelUrl: `${window.location.origin}/billing`,
});
```

### 11.3 客户门户

```typescript
const { data, error } = await insforge.payments.createCustomerPortalSession({
  environment: 'test',
  subject: { type: 'team', id: teamId },
  returnUrl: `${window.location.origin}/billing`,
});

if (data?.customerPortalSession.url) {
  window.location.assign(data.customerPortalSession.url);
}
```

### 11.4 查询支付状态

```typescript
// 查询 Checkout Session 状态
const { data } = await insforge.payments.getCheckoutSession('cs_xxx');

console.log('支付状态:', data.paymentStatus);  // 'paid' | 'unpaid' | 'no_payment_required'
console.log('订阅状态:', data.subscriptionStatus);

// 查询订阅详情
const { data: subscription } = await insforge.payments.getSubscription('sub_xxx');
```

### 11.5 Stripe Webhook 处理

InsForge 自动处理 Stripe Webhook 事件，包括：
- `checkout.session.completed` - 支付完成
- `customer.subscription.updated` - 订阅更新
- `customer.subscription.deleted` - 订阅取消
- `invoice.paid` - 发票支付成功
- `invoice.payment_failed` - 发票支付失败

你可以在 Dashboard 的 Payments 页面查看支付事件日志。

---

## 12. 邮件服务

> **注意**：邮件功能目前处于 Private Preview 阶段。

### 12.1 发送自定义邮件

```typescript
const { data, error } = await insforge.emails.send({
  to: ['user@example.com'],
  subject: '欢迎使用我们的服务',
  html: '<h1>欢迎！</h1><p>感谢您注册我们的服务。</p>',
  from: '支持团队',
  replyTo: 'support@example.com',
});
```

### 12.2 配置自定义 SMTP

在 Dashboard 的 Authentication → Email 中配置 SMTP 设置，支持自定义发件人和邮件模板。

---

## 12B. 日志系统

InsForge 提供完整的日志系统，包括审计日志和系统日志。

### 12B.1 系统日志

```typescript
// 列出所有日志来源
const { data: sources } = await insforge.logs.getSources();
// 返回: ['api', 'auth', 'database', 'functions', 'realtime', ...]

// 获取日志来源统计
const { data: stats } = await insforge.logs.getStats();

// 查询特定来源的日志
const { data } = await insforge.logs.getBySource('api', {
  limit: 100,
  beforeTimestamp: '2026-01-01T00:00:00Z',
});

// 搜索日志
const { data: searchResults } = await insforge.logs.search({
  query: 'error',
  source: 'functions',  // 可选，限定来源
  limit: 50,
});
```

### 12B.2 函数构建日志

```typescript
// 查看边缘函数的构建日志
const { data } = await insforge.logs.getBuildLogs({
  deploymentId: 'deploy_xxx',
});
```

### 12B.3 审计日志管理

```typescript
// 清理旧审计日志（保留最近 90 天）
const { data } = await insforge.logs.cleanupAudits({ daysToKeep: 90 });
```

---

## 12C. 用量统计

InsForge 自动追踪 MCP 工具的使用情况，可在 Dashboard 的 Usage 页面查看。

### 12C.1 查看 MCP 工具使用记录

```typescript
// 获取最近的 MCP 工具使用记录
const { data } = await insforge.usage.getMCPUsage({
  limit: 20,
  success: true,  // 仅查看成功的调用
});

// data.records: [{ tool_name: 'run-raw-sql', success: true, created_at: '...' }, ...]
```

### 12C.2 实时用量通知

当 MCP 工具被调用时，Dashboard 会通过 Socket.IO 实时收到通知，无需手动刷新页面。

### 12C.3 项目用量统计

```typescript
// 获取项目用量统计（Cloud 模式）
const { data } = await insforge.usage.getStats({
  startDate: '2026-01-01',
  endDate: '2026-01-31',
});
```

---

## 13. 部署前端应用

通过 MCP 工具部署前端应用：

```bash
create-deployment --source-dir ./dist --framework vite
```

InsForge 支持多种框架：
- Vite / React
- Next.js
- Vue / Nuxt
- Svelte / SvelteKit

### 13.1 自托管部署

InsForge 支持通过 Docker Compose 在自有服务器上部署：

```bash
# 克隆仓库
git clone https://github.com/InsForge/InsForge.git
cd InsForge

# 配置环境变量
cp .env.example .env
# 编辑 .env 文件，设置必要的环境变量

# 启动服务（4 个容器）
docker compose up -d
```

**容器架构**：
| 容器 | 内部端口 | 说明 |
|------|---------|------|
| PostgreSQL | 5432 | 数据库服务（含 pg_cron、pg_net、pgjwt 等扩展） |
| PostgREST | 3000 | 自动 REST API（v12） |
| InsForge | 7130 | 主后端服务（Express.js） |
| Deno | 7133 | 边缘函数运行时 |

**关键环境变量**：
| 变量 | 说明 |
|------|------|
| `JWT_SECRET` | JWT 签名密钥（HS256） |
| `ENCRYPTION_KEY` | AES-256-GCM 加密密钥 |
| `DATABASE_URL` | PostgreSQL 连接字符串 |
| `SMTP_*` | 邮件服务配置 |
| `OPENROUTER_API_KEY` | AI 模型网关密钥 |
| `STRIPE_SECRET_KEY` | Stripe 支付密钥 |

**支持的部署平台**：
- AWS EC2
- Azure VM
- Google Cloud Compute Engine
- Render
- 任何支持 Docker 的 VPS

---

## 13B. 密钥管理

InsForge 提供安全的密钥存储和管理功能，密钥使用 AES-256-GCM 加密存储。

### 13B.1 创建密钥

通过 Dashboard 的 Secrets 页面或 MCP 工具创建密钥：

```bash
# 通过 MCP 工具
create-secret --key "STRIPE_API_KEY" --value "sk_live_xxx"
```

密钥命名规范：大写字母、数字和下划线（如 `STRIPE_API_KEY`、`DATABASE_URL`）。

### 13B.2 在边缘函数中使用密钥

密钥会自动注入到边缘函数的环境变量中：

```typescript
// functions/payment-processor.ts
export default async function(req: Request): Promise<Response> {
  // 密钥自动作为环境变量可用
  const stripeKey = Deno.env.get('STRIPE_API_KEY');
  const dbUrl = Deno.env.get('DATABASE_URL');

  // 使用密钥进行业务逻辑
  // ...
}
```

### 13B.3 管理 API Key

InsForge 支持创建和轮换 API Key（以 `ik_` 为前缀），用于服务端到服务端的认证：

```typescript
// 使用 API Key 初始化客户端
const insforge = createClient({
  baseUrl: 'https://your-app.us-east.insforge.app',
  anonKey: 'ik_your_api_key_here',  // API Key 认证
});
```

---

## 13C. 定时任务（Schedules）

定时任务允许你按 Cron 表达式周期性触发边缘函数。

### 13C.1 创建定时任务

通过 MCP 工具创建：

```bash
create-schedule \
  --slug "daily-report" \
  --cron "0 8 * * *" \
  --function-slug "generate-report" \
  --method POST \
  --body '{"type": "daily"}'
```

Cron 表达式格式：`分 时 日 月 星期`

| 表达式 | 说明 |
|--------|------|
| `0 8 * * *` | 每天早上 8:00 |
| `*/15 * * * *` | 每 15 分钟 |
| `0 0 * * 1` | 每周一午夜 |
| `0 0 1 * *` | 每月 1 号午夜 |

### 13C.2 查看执行日志

```typescript
// 通过 SDK 查询定时任务执行历史
const { data } = await insforge.schedules.getLogs('schedule-id', {
  limit: 20,
  offset: 0,
});
```

### 13C.3 管理定时任务

```bash
# 列出所有定时任务
list-schedules

# 更新定时任务
update-schedule --id "schedule-id" --cron "0 12 * * *"

# 删除定时任务
delete-schedule --id "schedule-id"
```

---

## 13D. 计算服务（Compute）

> **注意**：计算服务目前处于 Private Preview 阶段。

计算服务允许你运行长期运行的容器化应用（如 Express 服务器、WebSocket 服务等）。

### 13D.1 创建计算服务

通过 Dashboard 的 Compute 页面或 MCP 工具创建：

```bash
create-compute-service \
  --name "my-api-server" \
  --image "node:20-alpine" \
  --port 3000 \
  --env "NODE_ENV=production"
```

### 13D.2 管理服务

```bash
# 列出所有服务
list-compute-services

# 查看服务详情和事件日志
get-compute-service --id "service-id"

# 删除服务
delete-compute-service --id "service-id"
```

---

## 13E. PostHog 分析集成

InsForge 集成了 PostHog 产品分析，让你在 Dashboard 中直接查看应用的用户行为数据。

### 13E.1 连接 PostHog

在 Dashboard 的 Analytics 页面中，输入你的 PostHog API Key 和 Host URL 完成连接。

### 13E.2 可用的分析功能

- **Web 概览**: 页面浏览量、独立访客、会话数等 KPI
- **趋势图表**: 自定义时间范围的事件趋势分析
- **会话录制**: 回放用户会话，了解用户行为
- **留存分析**: 用户留存率曲线
- **Dashboard 嵌入**: 直接嵌入 PostHog Dashboard

---

## 13F. S3 兼容网关

InsForge 提供完整的 S3 API 兼容网关，支持使用 AWS SDK 或其他 S3 兼容工具直接操作存储。

### 13F.1 使用 AWS SDK 接入

```javascript
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';

const s3 = new S3Client({
  region: 'auto',
  endpoint: 'https://your-app.us-east.insforge.app/storage/v1/s3',
  credentials: {
    accessKeyId: 'your-s3-access-key',
    secretAccessKey: 'your-s3-secret-key',
  },
  forcePathStyle: true,
});

await s3.send(new PutObjectCommand({
  Bucket: 'my-bucket',
  Key: 'path/to/file.jpg',
  Body: fileBuffer,
}));
```

### 13F.2 支持的 S3 操作

| 操作 | 说明 |
|------|------|
| ListBuckets | 列出所有桶 |
| CreateBucket | 创建桶 |
| DeleteBucket | 删除桶 |
| HeadBucket | 检查桶是否存在 |
| ListObjectsV2 | 列出桶中对象 |
| PutObject | 上传对象 |
| GetObject | 下载对象 |
| HeadObject | 获取对象元数据 |
| DeleteObject | 删除单个对象 |
| DeleteObjects | 批量删除对象 |
| CopyObject | 复制对象 |
| CreateMultipartUpload | 创建多部分上传 |
| UploadPart | 上传分片 |
| CompleteMultipartUpload | 完成多部分上传 |
| AbortMultipartUpload | 取消多部分上传 |
| ListParts | 列出已上传分片 |

### 13F.3 创建 S3 访问密钥

在 Dashboard 的 Storage 页面中创建 S3 访问密钥对（Access Key + Secret Key），用于 S3 网关认证。

---

## 14. 完整项目示例：构建一个博客应用

下面演示如何使用 InsForge 从零构建一个完整的博客应用。

### 14.1 项目初始化

```bash
# 创建 React + Vite 项目
npm create vite@latest my-blog -- --template react-ts
cd my-blog

# 安装 InsForge SDK
npm install @insforge/sdk@latest

# 安装 Tailwind CSS 3.4
npm install -D tailwindcss@3.4 postcss autoprefixer
npx tailwindcss init -p
```

### 14.2 配置 InsForge 客户端

```typescript
// src/lib/insforge.ts
import { createClient } from '@insforge/sdk';

export const insforge = createClient({
  baseUrl: import.meta.env.VITE_INSFORGE_BASE_URL,
  anonKey: import.meta.env.VITE_INSFORGE_ANON_KEY,
});
```

### 14.3 创建数据库表

通过 MCP 工具执行 SQL：

```sql
-- 文章表
CREATE TABLE posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  content TEXT,
  user_id UUID REFERENCES auth.users(id),
  status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'published')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 评论表
CREATE TABLE comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id),
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 为公开查询创建索引
CREATE INDEX idx_posts_status ON posts(status);
CREATE INDEX idx_posts_created_at ON posts(created_at DESC);
CREATE INDEX idx_comments_post_id ON comments(post_id);
```

### 14.4 实现认证页面

```typescript
// src/components/Auth.tsx
import { useState } from 'react';
import { insforge } from '../lib/insforge';

export function Auth() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [isLogin, setIsLogin] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    if (isLogin) {
      const { error } = await insforge.auth.signInWithPassword({
        email,
        password,
      });
      if (error) setError(error.message);
    } else {
      const { error } = await insforge.auth.signUp({
        email,
        password,
      });
      if (error) setError(error.message);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50">
      <form onSubmit={handleSubmit} className="bg-white p-8 rounded-lg shadow-md w-96">
        <h2 className="text-2xl font-bold mb-6">
          {isLogin ? '登录' : '注册'}
        </h2>

        {error && (
          <div className="bg-red-50 text-red-600 p-3 rounded mb-4">
            {error}
          </div>
        )}

        <div className="mb-4">
          <label className="block text-sm font-medium mb-1">邮箱</label>
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="w-full px-3 py-2 border rounded-lg"
            required
          />
        </div>

        <div className="mb-6">
          <label className="block text-sm font-medium mb-1">密码</label>
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="w-full px-3 py-2 border rounded-lg"
            required
          />
        </div>

        <button
          type="submit"
          className="w-full bg-blue-600 text-white py-2 rounded-lg hover:bg-blue-700"
        >
          {isLogin ? '登录' : '注册'}
        </button>

        <p className="mt-4 text-center text-sm text-gray-600">
          {isLogin ? '没有账号？' : '已有账号？'}
          <button
            type="button"
            onClick={() => setIsLogin(!isLogin)}
            className="text-blue-600 ml-1"
          >
            {isLogin ? '注册' : '登录'}
          </button>
        </p>

        <div className="mt-4 space-y-2">
          <button
            type="button"
            onClick={() => insforge.auth.signInWithOAuth({ provider: 'google' })}
            className="w-full border py-2 rounded-lg hover:bg-gray-50"
          >
            使用 Google 登录
          </button>
          <button
            type="button"
            onClick={() => insforge.auth.signInWithOAuth({ provider: 'github' })}
            className="w-full border py-2 rounded-lg hover:bg-gray-50"
          >
            使用 GitHub 登录
          </button>
        </div>
      </form>
    </div>
  );
}
```

### 14.5 实现文章列表

```typescript
// src/components/PostList.tsx
import { useEffect, useState } from 'react';
import { insforge } from '../lib/insforge';

interface Post {
  id: string;
  title: string;
  content: string;
  created_at: string;
  user_id: string;
}

export function PostList() {
  const [posts, setPosts] = useState<Post[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function fetchPosts() {
      const { data, error } = await insforge.database
        .from('posts')
        .select('*')
        .eq('status', 'published')
        .order('created_at', { ascending: false });

      if (!error && data) {
        setPosts(data);
      }
      setLoading(false);
    }

    fetchPosts();
  }, []);

  if (loading) {
    return <div className="text-center py-8">加载中...</div>;
  }

  return (
    <div className="max-w-4xl mx-auto p-8">
      <h1 className="text-4xl font-bold mb-8">我的博客</h1>

      <div className="grid gap-6">
        {posts.map((post) => (
          <article
            key={post.id}
            className="bg-white p-6 rounded-lg shadow-md border hover:shadow-lg transition-shadow"
          >
            <h2 className="text-2xl font-semibold mb-2">{post.title}</h2>
            <p className="text-gray-600 mb-4">{post.content}</p>
            <time className="text-sm text-gray-400">
              {new Date(post.created_at).toLocaleDateString('zh-CN')}
            </time>
          </article>
        ))}
      </div>

      {posts.length === 0 && (
        <p className="text-center text-gray-500">暂无文章</p>
      )}
    </div>
  );
}
```

### 14.6 实现文章创建

```typescript
// src/components/CreatePost.tsx
import { useState } from 'react';
import { insforge } from '../lib/insforge';

export function CreatePost() {
  const [title, setTitle] = useState('');
  const [content, setContent] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setSuccess(false);

    const { data: user } = await insforge.auth.getCurrentUser();
    if (!user?.user) {
      setError('请先登录');
      return;
    }

    const { error } = await insforge.database
      .from('posts')
      .insert({
        title,
        content,
        user_id: user.user.id,
        status: 'published',
      })
      .select();

    if (error) {
      setError(error.message);
    } else {
      setSuccess(true);
      setTitle('');
      setContent('');
    }
  };

  return (
    <form onSubmit={handleSubmit} className="max-w-2xl mx-auto p-8">
      <h2 className="text-2xl font-bold mb-6">写文章</h2>

      {error && (
        <div className="bg-red-50 text-red-600 p-3 rounded mb-4">{error}</div>
      )}
      {success && (
        <div className="bg-green-50 text-green-600 p-3 rounded mb-4">
          文章发布成功！
        </div>
      )}

      <div className="mb-4">
        <label className="block text-sm font-medium mb-1">标题</label>
        <input
          type="text"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          className="w-full px-3 py-2 border rounded-lg"
          required
        />
      </div>

      <div className="mb-6">
        <label className="block text-sm font-medium mb-1">内容</label>
        <textarea
          value={content}
          onChange={(e) => setContent(e.target.value)}
          className="w-full px-3 py-2 border rounded-lg h-40"
          required
        />
      </div>

      <button
        type="submit"
        className="bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700"
      >
        发布文章
      </button>
    </form>
  );
}
```

### 14.7 添加 AI 功能

```typescript
// src/components/AIAssistant.tsx
import { useState } from 'react';
import { insforge } from '../lib/insforge';

export function AIAssistant() {
  const [prompt, setPrompt] = useState('');
  const [response, setResponse] = useState('');
  const [loading, setLoading] = useState(false);

  const handleAskAI = async () => {
    setLoading(true);
    setResponse('');

    const stream = await insforge.ai.chat.completions.create({
      model: 'anthropic/claude-3.5-haiku',
      messages: [{ role: 'user', content: prompt }],
      stream: true,
    });

    let fullResponse = '';
    for await (const chunk of stream) {
      if (chunk.choices[0]?.delta?.content) {
        fullResponse += chunk.choices[0].delta.content;
        setResponse(fullResponse);
      }
    }

    setLoading(false);
  };

  return (
    <div className="max-w-2xl mx-auto p-8">
      <h2 className="text-2xl font-bold mb-6">AI 助手</h2>

      <div className="mb-4">
        <textarea
          value={prompt}
          onChange={(e) => setPrompt(e.target.value)}
          placeholder="向 AI 提问..."
          className="w-full px-3 py-2 border rounded-lg h-24"
        />
      </div>

      <button
        onClick={handleAskAI}
        disabled={loading || !prompt}
        className="bg-purple-600 text-white px-6 py-2 rounded-lg hover:bg-purple-700 disabled:opacity-50"
      >
        {loading ? '思考中...' : '提问'}
      </button>

      {response && (
        <div className="mt-6 p-4 bg-gray-50 rounded-lg">
          <h3 className="font-semibold mb-2">AI 回答：</h3>
          <p className="whitespace-pre-wrap">{response}</p>
        </div>
      )}
    </div>
  );
}
```

### 14.8 添加文件上传

```typescript
// src/components/ImageUpload.tsx
import { useState } from 'react';
import { insforge } from '../lib/insforge';

export function ImageUpload() {
  const [uploading, setUploading] = useState(false);
  const [imageUrl, setImageUrl] = useState<string | null>(null);

  const handleUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    setUploading(true);

    const { data, error } = await insforge.storage
      .from('images')
      .uploadAuto(file);

    if (error) {
      console.error('上传失败:', error.message);
    } else if (data) {
      setImageUrl(data.url);
    }

    setUploading(false);
  };

  return (
    <div className="p-8">
      <h2 className="text-2xl font-bold mb-6">上传图片</h2>

      <input
        type="file"
        accept="image/*"
        onChange={handleUpload}
        disabled={uploading}
        className="mb-4"
      />

      {uploading && <p>上传中...</p>}

      {imageUrl && (
        <div>
          <p className="text-green-600 mb-2">上传成功！</p>
          <img src={imageUrl} alt="上传的图片" className="max-w-md rounded-lg shadow" />
        </div>
      )}
    </div>
  );
}
```

---

## 15. 最佳实践与常见问题

### 15.1 安全最佳实践

1. **环境变量管理**：将 `baseUrl` 和 `anonKey` 放在环境变量中，不要硬编码
2. **RLS 策略**：为数据库表启用行级安全策略，控制数据访问权限
3. **HTTPS**：生产环境始终使用 HTTPS
4. **令牌安全**：accessToken 存储在内存中，refreshToken 使用 httpOnly cookie
5. **输入验证**：始终在客户端和服务器端验证用户输入

### 15.2 性能优化

1. **选择性查询**：只查询需要的字段，避免 `select('*')`
2. **分页**：使用 `range()` 和 `limit()` 进行分页
3. **索引**：为常用查询字段创建数据库索引
4. **批量操作**：使用批量插入/更新减少请求次数
5. **缓存**：对不频繁变化的数据使用客户端缓存

### 15.3 常见问题

**Q: SDK 返回 `{ data: null, error: ... }` 怎么办？**

A: 检查网络连接、认证令牌是否有效、表名和字段名是否正确。

**Q: 如何调试数据库查询？**

A: 在 Dashboard 的 Logs 页面查看 API 请求日志，或使用 `console.log` 打印查询参数。

**Q: 数据库插入失败？**

A: 确保使用数组格式 `[{...}]` 进行插入，检查字段名是否与表结构匹配。

**Q: OAuth 登录后没有跳转？**

A: 确保 `redirectTo` URL 已添加到 Dashboard 的允许重定向 URL 列表中。

**Q: 文件上传大小限制？**

A: 默认限制为 50MB，可通过环境变量 `MAX_FILE_SIZE` 配置。

**Q: 如何重置项目？**

A: 在 Dashboard 的 Project Settings 中可以重置项目数据。

**Q: InsForge 支持哪些数据库操作？**

A: 支持完整的 PostgreSQL 操作，包括 CRUD、RPC（存储过程调用）、原始 SQL 查询、CSV 导入导出、批量 upsert、数据库迁移、Schema 浏览、RLS 策略管理等。

**Q: 如何保证数据安全？**

A: InsForge 使用多层安全机制：
- JWT Access Token（15 分钟）+ Refresh Token（7 天）双 Token 机制
- AES-256-GCM 加密存储密钥和敏感数据
- PostgreSQL 行级安全策略（RLS）
- 请求速率限制
- S3 SigV4 签名验证

**Q: 支持哪些 AI 模型？**

A: 通过 OpenRouter 支持 200+ 模型，包括 Claude (Anthropic)、GPT (OpenAI)、Gemini (Google)、DeepSeek、Llama (Meta) 等。支持聊天补全（流式/非流式）、图像生成、嵌入向量、工具调用、联网搜索、文件解析。

**Q: 边缘函数支持哪些语言？**

A: 目前支持 TypeScript/JavaScript，运行在 Deno 运行时上。支持 npm 包导入、环境变量、密钥注入、定时触发。

**Q: 如何自托管 InsForge？**

A: 使用 Docker Compose 一键部署，包含 4 个容器（PostgreSQL + PostgREST + InsForge + Deno）。支持 AWS EC2、Azure、GCP、Render 等平台部署。

**Q: S3 网关支持哪些操作？**

A: 支持 15+ S3 操作，包括 ListBuckets、CreateBucket、PutObject、GetObject、DeleteObject、CopyObject、多部分上传等。兼容 AWS SDK 和所有 S3 兼容工具。

**Q: 实时通信的消息可靠性如何？**

A: 采用双层架构：Socket.IO（客户端 WebSocket）+ PostgreSQL LISTEN/NOTIFY（服务端消息分发）。支持消息持久化、自动重连（指数退避）、Webhook 推送。

**Q: 支持哪些 AI 编码工具？**

A: 支持 Cursor、Claude Code、GitHub Copilot、Windsurf、Trae、Cline、Roo Code、Qoder、Kiro、Antigravity、Codex、OpenClaw、OpenCode 等 13+ AI 工具。

**Q: 如何管理 API Key？**

A: 在 Dashboard 的 Settings 页面创建和轮换 API Key（`ik_` 前缀）。API Key 永不过期，可用于服务端到服务端认证。

**Q: 定时任务的最小执行间隔是多少？**

A: Cron 表达式支持分钟级别精度，最小间隔为 1 分钟。定时任务触发边缘函数执行，支持查看执行日志。

### 15.4 开发工作流建议

1. **使用 AI 编码代理**：让 AI 代理通过 MCP 工具直接操作后端，大幅提升开发效率
2. **迭代开发**：先搭建核心功能（数据库 + 认证），再逐步添加存储、AI 等高级功能
3. **本地开发**：
   - **Cloud 模式**：直接使用 Cloud 项目进行开发，无需本地部署
   - **自托管模式**：使用 Docker Compose 在本地运行 InsForge 进行开发和测试
4. **版本控制**：将数据库迁移脚本纳入 Git 版本管理
5. **监控**：定期查看 Dashboard 的 Usage 和 Logs 页面，了解应用运行状态
6. **自托管升级**：定期执行 `docker compose pull && docker compose up -d` 更新到最新版本

---

## 附录

### A. 可用 AI 模型列表

InsForge 通过 OpenRouter 提供多种 AI 模型：

| 模型 | 标识符 |
|------|--------|
| Claude 3.5 Haiku | `anthropic/claude-3.5-haiku` |
| Claude Sonnet 4.5 | `anthropic/claude-sonnet-4.5` |
| GPT-4o | `openai/gpt-4o` |
| GPT-4o-mini | `openai/gpt-4o-mini` |
| Gemini 2.0 Flash | `google/gemini-2.0-flash` |
| DeepSeek V3 | `deepseek/deepseek-chat` |

### B. 支持的 OAuth 提供商

`google`、`github`、`apple`、`discord`、`facebook`、`linkedin`、`microsoft`、`x`，以及自定义 OAuth 提供商。

### C. 支持的 AI 编码工具

| 工具 | 配置方式 |
|------|---------|
| Cursor | Settings → Tools & MCP → 添加 MCP JSON |
| Claude Code | 终端运行安装命令 |
| GitHub Copilot | Copilot 终端运行安装命令 |
| Windsurf | 终端运行安装命令 |
| Trae | 终端运行安装命令 |
| Cline | 添加 MCP JSON |
| Roo Code | 添加 MCP JSON |
| Qoder | 添加 MCP JSON |
| Kiro | 添加 MCP JSON |
| Antigravity | 终端运行安装命令 |
| Codex | 终端运行安装命令 |
| OpenClaw | 终端运行安装命令 |
| OpenCode | 终端运行安装命令 |

### D. 相关资源

- **官网**: [https://insforge.dev](https://insforge.dev)
- **GitHub**: [https://github.com/InsForge/InsForge](https://github.com/InsForge/InsForge)
- **文档**: [https://insforge.dev/docs](https://insforge.dev/docs)
- **Discord**: [https://discord.com/invite/MPxwj5xVvW](https://discord.com/invite/MPxwj5xVvW)
- **SDK**: `npm install @insforge/sdk@latest`
- **CLI**: `npx @insforge/cli`