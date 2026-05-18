# AstronRPA 后端轻量化改造 —— InsForge 规范修复方案

> **部署模式**：本方案基于 **InsForge 自托管（Self-hosting）** 模式设计。AstronRPA 使用 Docker Compose 在本地/内网部署 InsForge 平台，所有服务运行在本地容器中。与 Cloud 模式的关键差异见 [自托管与 Cloud 模式差异](#自托管与-cloud-模式差异)。

## 概述

### 部署架构（自托管）

AstronRPA 自托管 InsForge 的 Docker Compose 架构如下：

```
┌──────────────────────────────────────────────────────┐
│                    Docker Network                     │
│                                                      │
│  ┌──────────┐  ┌───────────┐  ┌──────────────────┐  │
│  │ postgres │  │ postgrest │  │    insforge       │  │
│  │  :5432   │  │  :3000    │  │  :7130 (API)     │  │
│  │          │◄─│           │◄─│  :7131 (Auth)    │  │
│  └──────────┘  └───────────┘  └────────┬─────────┘  │
│                                        │             │
│  ┌──────────┐  ┌───────────┐          │             │
│  │  deno    │  │rpa-core   │          │             │
│  │  :7133   │  │  :8000    │          │             │
│  │          │  │ (FastAPI) │          │             │
│  └──────────┘  └───────────┘          │             │
│       │                                │             │
│       └────────────────────────────────┘             │
│            Edge Functions 通过 SDK 调用               │
│            rpa-core 通过 HTTP 验证 JWT                │
└──────────────────────────────────────────────────────┘
```

### 问题诊断

当前 AstronRPA 改造方案的**架构设计完全符合 InsForge 规范**，但**实现方式存在一个根本性偏离**：前端和 Edge Functions 未使用 InsForge 官方 `@insforge/sdk`，而是用 axios/fetch 裸调 HTTP API。这导致：

| 维度 | InsForge 规范做法 | AstronRPA 当前做法 | 影响 |
|------|------------------|-------------------|------|
| 数据库查询 | `client.database.from('posts').select('*').eq('status', 'active')` | `axios.get('/c_atom_meta_new', { params: {...} })` | 无类型安全、无链式过滤、绕过 InsForge App 代理 |
| 用户认证 | `client.auth.signInWithPassword({ email, password })` | `axios.post('/api/auth/sessions', { email, password })` | 手动管理 token、无自动刷新、无 session 恢复 |
| Token 管理 | SDK 自动存储/刷新/httpOnly cookie | 手动 `localStorage` + 手动 401 拦截 | 安全性差、无 CSRF 保护 |
| 错误处理 | 统一 `{data, error}` 模式 | axios try/catch + 手动判断 | 不一致的错误处理 |
| Edge Functions | `createClient({ edgeFunctionToken })` 使用 SDK | `fetch(POSTGREST_URL + '/table')` 裸调 | 无法利用 RLS、无类型安全 |
| Python 验证 | 调用 InsForge `/api/auth/sessions/current` 验证 token | 本地 `jose.jwt.decode()` 解析 JWT | 需要共享 JWT_SECRET、无法验证 token 是否已撤销 |

### 修复目标

将当前「把 InsForge 当普通 PostgreSQL + REST API 用」的实现方式，升级为「使用 InsForge 官方 SDK 的完整 BaaS 集成」。

### 修复范围

| 序号 | 修复项 | 涉及文件 | 优先级 |
|------|--------|---------|--------|
| Fix-1 | 安装 SDK + 创建统一客户端 | `package.json`, 新建 `insforge-client.ts` | P0 |
| Fix-2 | 认证模块迁移到 SDK | `login.ts`, `http.ts` | P0 |
| Fix-3 | 数据库 CRUD 迁移到 SDK | `api-client.ts` | P0 |
| Fix-4 | Edge Functions 调用迁移到 SDK | `api-client.ts` (notify 部分) | P1 |
| Fix-5 | Python JWT 验证改为远程验证 | `auth.py`, `config.py` | P1 |
| Fix-6 | Edge Functions 内部使用 SDK | `functions/notify/index.ts`, `functions/blacklist/index.ts` | P1 |
| Fix-7 | 环境变量和配置更新 | `.env.example`, `docker-compose.yml` | P2 |
| Fix-8 | 清理冗余依赖 | `package.json` | P2 |

---

## Fix-1: 安装 @insforge/sdk 并创建统一客户端

### 目标
在 frontend 项目中安装 `@insforge/sdk`，创建全局单例客户端，替代当前的多个 axios 实例。

### 涉及文件
- `frontend/package.json` — 添加依赖
- `frontend/packages/shared/src/insforge-client.ts` — **新建**，SDK 客户端单例
- `frontend/packages/shared/src/index.ts` — 导出新客户端

### 操作步骤

#### Step 1.1: 安装 SDK 依赖

在 `frontend/` 目录下执行：

```bash
cd frontend
pnpm add @insforge/sdk@latest
```

#### Step 1.2: 创建 `frontend/packages/shared/src/insforge-client.ts`

```typescript
import { createClient } from '@insforge/sdk';

// 自托管模式：InsForge 运行在本地 Docker 容器中
const INSFORGE_BASE_URL = import.meta.env.VITE_INSFORGE_URL || 'http://localhost:7130';
const INSFORGE_ANON_KEY = import.meta.env.VITE_INSFORGE_ANON_KEY || '';

export const insforge = createClient({
  baseUrl: INSFORGE_BASE_URL,
  anonKey: INSFORGE_ANON_KEY,
});
```

> **自托管注意**：`ANON_KEY` 需要从 InsForge Dashboard 的 **Settings → API** 页面手动获取。首次部署后，使用 `.env` 中配置的 `ADMIN_EMAIL` / `ADMIN_PASSWORD` 登录 Dashboard（`http://localhost:7130`），在 API 设置页面复制 Anon Key。

#### Step 1.3: 在 `frontend/packages/shared/src/index.ts` 中导出

```typescript
export { insforge } from './insforge-client';
```

### 验证方式
- `pnpm install` 成功，无版本冲突
- `import { insforge } from '@rpa/shared'` 可在其他包中正常导入

---

## Fix-2: 认证模块迁移到 InsForge SDK

### 目标
将 `login.ts` 和 `http.ts` 中的手动 axios 认证调用替换为 InsForge SDK 的 `auth` 方法。

### 涉及文件
- `frontend/packages/components/src/components/Auth/api/login.ts` — 重写认证 API
- `frontend/packages/components/src/components/Auth/api/http.ts` — 简化/移除手动 token 管理

### 当前代码问题

**`login.ts` 当前写法**：
```typescript
// 手动 POST 到 /api/auth/sessions
export async function login(params: { email: string, password: string }) {
  const { data } = await http.post('/api/auth/sessions', params)
  return data
}
```

**`http.ts` 当前写法**：
```typescript
// 手动从 localStorage 读取 token 并附加到 header
const token = localStorage.getItem('insforge_token')
headers: { ...(token ? { Authorization: `Bearer ${token}` } : {}) }
```

### 修复后代码

#### Step 2.1: 重写 `login.ts`

```typescript
import { insforge } from '@rpa/shared';
import { message } from 'ant-design-vue';
import i18next from 'i18next';
import type { ConsultFormData, LoginFormData, RegisterFormData, TenantItem } from '../interface';

// ============================================================
// 认证相关 — 使用 InsForge SDK
// ============================================================

export async function loginStatus() {
  const { data, error } = await insforge.auth.getCurrentUser();
  if (error) throw error;
  return data;
}

export async function getToken() {
  const { data, error } = await insforge.auth.getCurrentUser();
  if (error) throw error;
  return data;
}

export async function logout() {
  const { error } = await insforge.auth.signOut();
  if (error) throw error;
}

export async function isHistory(_params: LoginFormData) {
  return false;
}

export async function preAuthenticate(params: { email: string; password: string }) {
  const { data, error } = await insforge.auth.signInWithPassword({
    email: params.email,
    password: params.password,
  });
  if (error) throw error;
  return data;
}

export async function login(params: { email: string; password: string }) {
  const { data, error } = await insforge.auth.signInWithPassword({
    email: params.email,
    password: params.password,
  });
  if (error) throw error;
  return data;
}

export async function register(params: RegisterFormData) {
  const { data, error } = await insforge.auth.signUp({
    email: params.email,
    password: params.password,
    name: params.name,
  });
  if (error) throw error;
  return data;
}

// ============================================================
// 以下为 InsForge Auth 暂不直接支持的功能，保留 HTTP 调用
// ============================================================

export async function sendCaptcha(phone: string, scene: string, _isRegister: boolean = true) {
  // InsForge Auth 内置验证码发送，通过 Edge Function 桥接
  const { data, error } = await insforge.functions.invoke('send-captcha', {
    body: { phone, scene },
  });
  if (error) throw error;
  return data;
}

export async function tenantList(_tempToken?: string) {
  // 租户列表通过数据库查询
  const { data, error } = await insforge.database
    .from('tenants')
    .select('*');
  if (error) throw error;
  return data;
}

export async function checkRegistered({ phone }: { phone: string }) {
  return true;
}

export async function setPassword(_params: { email: string; password: string; tempToken: string }) {
  // InsForge 密码重置通过 Edge Function 或直接 API
  throw new Error('Password reset via SDK not yet implemented');
}

export async function switchTenant(params: { tenantId: string }) {
  const { data, error } = await insforge.functions.invoke('tenant-switch', {
    body: params,
  });
  if (error) throw error;
  return data;
}

export async function userInfo() {
  const { data, error } = await insforge.auth.getCurrentUser();
  if (error) throw error;
  return data;
}

export async function modifyPassword(_params: LoginFormData) {
  throw new Error('Password change via SDK not yet implemented');
}

export async function submitConsult(params: ConsultFormData) {
  const { data, error } = await insforge.database
    .from('feedback_report')
    .insert([params])
    .select();
  if (error) throw error;
  return data;
}

export async function submitRenewal(params: ConsultFormData) {
  const { data, error } = await insforge.database
    .from('feedback_report')
    .insert([params])
    .select();
  if (error) throw error;
  return data;
}
```

#### Step 2.2: 简化 `http.ts`

SDK 接管认证后，`http.ts` 仅需保留非 InsForge 服务的通用 HTTP 请求能力：

```typescript
import axios from 'axios';
import type { AxiosRequestConfig } from 'axios';
import { message } from 'ant-design-vue';
import i18next from 'i18next';

const RPA_CORE_URL = import.meta.env.VITE_RPA_CORE_URL || 'http://localhost:8040';

export interface ResponseData<T = any> {
  data: T;
  message?: string;
  msg?: string;
}

export async function request<T = any, P = any>(
  config: AxiosRequestConfig<P> & { url: string },
): Promise<ResponseData<T>> {
  try {
    const { data: res } = await axios<ResponseData<T>>({
      baseURL: RPA_CORE_URL,
      timeout: 20000,
      withCredentials: false,
      headers: {
        'Content-Type': 'application/json;charset=UTF-8',
      },
      ...config,
      data: config.data && JSON.parse(JSON.stringify(config.data)),
    });
    return res;
  } catch (err: any) {
    const msg = err.response
      ? `${err.response.status} ${err.response.statusText || err.response.data?.message || ''}`
      : err.message || i18next.t('components.auth.serviceError');
    message.error(msg);
    return Promise.reject(err);
  }
}

export const http = {
  get: <T = any>(url: string, params?: any, config?: AxiosRequestConfig) =>
    request<T>({ method: 'GET', url, params, ...config }),
  post: <T = any>(url: string, data?: any, config?: AxiosRequestConfig) =>
    request<T>({ method: 'POST', url, data, ...config }),
  postparams: <T = any>(url: string, params?: any, config?: AxiosRequestConfig) =>
    request<T>({ method: 'POST', url, params, ...config }),
  put: <T = any>(url: string, data?: any, config?: AxiosRequestConfig) =>
    request<T>({ method: 'PUT', url, data, ...config }),
  del: <T = any>(url: string, params?: any, config?: AxiosRequestConfig) =>
    request<T>({ method: 'DELETE', url, params, ...config }),
};

export default request;
```

**关键变化**：
- 移除 `localStorage.getItem('insforge_token')` — SDK 自动管理
- 移除手动 `Authorization` header 附加 — SDK 自动处理
- 移除 401 拦截中的 `localStorage.removeItem` — SDK 自动处理 session
- `http.ts` 仅保留对 `rpa-core-service` 的通用 HTTP 调用

### 验证方式
- 登录流程：`signInWithPassword` → 获取 `{data, error}` → data.user 包含用户信息
- 注册流程：`signUp` → 获取 `{data, error}` → 检查 `data.requireEmailVerification`
- 获取当前用户：`getCurrentUser` → 返回已登录用户或 null
- 登出：`signOut` → 清除 session

---

## Fix-3: 数据库 CRUD 迁移到 InsForge SDK

### 目标
将 `api-client.ts` 中所有通过 axios 直接调用 PostgREST 的 CRUD 操作，替换为 InsForge SDK 的 `database` 链式查询 API。

### 涉及文件
- `frontend/packages/shared/src/api-client.ts` — 重写 CRUD 部分
- `frontend/packages/shared/src/insforge-client.ts` — 已在上一步创建

### 当前代码问题

```typescript
// 当前：直接 axios 调用 PostgREST，绕过 InsForge App
const postgrestClient = axios.create({ baseURL: 'http://localhost:5430' });

export const crudApi = {
  atomMeta: {
    list: (params) => postgrestClient.get('/c_atom_meta_new', { params: { select: '*', ...params } }),
    get: (id) => postgrestClient.get(`/c_atom_meta_new?id=eq.${id}`, { params: { select: '*' } }),
    create: (data) => postgrestClient.post('/c_atom_meta_new', data),
    update: (id, data) => postgrestClient.patch(`/c_atom_meta_new?id=eq.${id}`, data),
    delete: (id) => postgrestClient.patch(`/c_atom_meta_new?id=eq.${id}`, { deleted: 1 }),
  },
  // ... 22 more tables
};
```

### 修复后代码

#### Step 3.1: 重写 `api-client.ts` 的 CRUD 部分

```typescript
import { insforge } from './insforge-client';
import axios, { type AxiosInstance } from 'axios';

const RPA_CORE_URL = import.meta.env.VITE_RPA_CORE_URL || 'http://localhost:8040';

// ============================================================
// InsForge SDK Database CRUD — 替代 PostgREST 直接调用
// ============================================================

export const crudApi = {
  atomMeta: {
    list: (params?: Record<string, unknown>) => {
      let query = insforge.database.from('c_atom_meta_new').select('*');
      if (params?.order) query = query.order(params.order as string);
      if (params?.limit) query = query.limit(params.limit as number);
      if (params?.offset) query = query.range(
        params.offset as number,
        (params.offset as number) + (params.limit as number) - 1
      );
      return query;
    },
    get: (id: number) =>
      insforge.database.from('c_atom_meta_new').select('*').eq('id', id).single(),
    create: (data: Record<string, unknown>) =>
      insforge.database.from('c_atom_meta_new').insert([data]).select(),
    update: (id: number, data: Record<string, unknown>) =>
      insforge.database.from('c_atom_meta_new').update(data).eq('id', id).select(),
    delete: (id: number) =>
      insforge.database.from('c_atom_meta_new').update({ deleted: 1 }).eq('id', id),
  },

  element: {
    list: (params?: Record<string, unknown>) => {
      let query = insforge.database.from('c_element').select('*');
      if (params?.order) query = query.order(params.order as string);
      if (params?.limit) query = query.limit(params.limit as number);
      return query;
    },
    get: (id: number) =>
      insforge.database.from('c_element').select('*').eq('id', id).single(),
    create: (data: Record<string, unknown>) =>
      insforge.database.from('c_element').insert([data]).select(),
    update: (id: number, data: Record<string, unknown>) =>
      insforge.database.from('c_element').update(data).eq('id', id).select(),
    delete: (id: number) =>
      insforge.database.from('c_element').update({ deleted: 1 }).eq('id', id),
  },

  globalVar: {
    list: (params?: Record<string, unknown>) => {
      let query = insforge.database.from('c_global_var').select('*');
      if (params?.order) query = query.order(params.order as string);
      if (params?.limit) query = query.limit(params.limit as number);
      return query;
    },
    get: (id: number) =>
      insforge.database.from('c_global_var').select('*').eq('id', id).single(),
    create: (data: Record<string, unknown>) =>
      insforge.database.from('c_global_var').insert([data]).select(),
    update: (id: number, data: Record<string, unknown>) =>
      insforge.database.from('c_global_var').update(data).eq('id', id).select(),
    delete: (id: number) =>
      insforge.database.from('c_global_var').update({ deleted: 1 }).eq('id', id),
  },

  group: {
    list: (params?: Record<string, unknown>) => {
      let query = insforge.database.from('c_group').select('*');
      if (params?.order) query = query.order(params.order as string);
      if (params?.limit) query = query.limit(params.limit as number);
      return query;
    },
    get: (id: number) =>
      insforge.database.from('c_group').select('*').eq('id', id).single(),
    create: (data: Record<string, unknown>) =>
      insforge.database.from('c_group').insert([data]).select(),
    update: (id: number, data: Record<string, unknown>) =>
      insforge.database.from('c_group').update(data).eq('id', id).select(),
    delete: (id: number) =>
      insforge.database.from('c_group').update({ deleted: 1 }).eq('id', id),
  },

  component: {
    list: (params?: Record<string, unknown>) => {
      let query = insforge.database.from('component').select('*');
      if (params?.order) query = query.order(params.order as string);
      if (params?.limit) query = query.limit(params.limit as number);
      return query;
    },
    get: (id: number) =>
      insforge.database.from('component').select('*').eq('id', id).single(),
    create: (data: Record<string, unknown>) =>
      insforge.database.from('component').insert([data]).select(),
  },

  feedback: {
    list: (params?: Record<string, unknown>) => {
      let query = insforge.database.from('feedback_report').select('*');
      if (params?.order) query = query.order(params.order as string);
      if (params?.limit) query = query.limit(params.limit as number);
      return query;
    },
    create: (data: Record<string, unknown>) =>
      insforge.database.from('feedback_report').insert([data]).select(),
  },

  agent: {
    list: (params?: Record<string, unknown>) => {
      let query = insforge.database.from('agent_table').select('*');
      if (params?.order) query = query.order(params.order as string);
      if (params?.limit) query = query.limit(params.limit as number);
      return query;
    },
    get: (agentId: string) =>
      insforge.database.from('agent_table').select('*').eq('agent_id', agentId).single(),
    create: (data: Record<string, unknown>) =>
      insforge.database.from('agent_table').insert([data]).select(),
    update: (agentId: string, data: Record<string, unknown>) =>
      insforge.database.from('agent_table').update(data).eq('agent_id', agentId).select(),
    delete: (agentId: string) =>
      insforge.database.from('agent_table').update({ deleted: 1 }).eq('agent_id', agentId),
  },

  module: {
    list: (params?: Record<string, unknown>) => {
      let query = insforge.database.from('c_module').select('*');
      if (params?.order) query = query.order(params.order as string);
      if (params?.limit) query = query.limit(params.limit as number);
      return query;
    },
    get: (id: number) =>
      insforge.database.from('c_module').select('*').eq('id', id).single(),
    create: (data: Record<string, unknown>) =>
      insforge.database.from('c_module').insert([data]).select(),
    update: (id: number, data: Record<string, unknown>) =>
      insforge.database.from('c_module').update(data).eq('id', id).select(),
    delete: (id: number) =>
      insforge.database.from('c_module').update({ deleted: 1 }).eq('id', id),
  },

  param: {
    list: (params?: Record<string, unknown>) => {
      let query = insforge.database.from('c_param').select('*');
      if (params?.order) query = query.order(params.order as string);
      if (params?.limit) query = query.limit(params.limit as number);
      return query;
    },
    get: (id: number) =>
      insforge.database.from('c_param').select('*').eq('id', id).single(),
    create: (data: Record<string, unknown>) =>
      insforge.database.from('c_param').insert([data]).select(),
    update: (id: number, data: Record<string, unknown>) =>
      insforge.database.from('c_param').update(data).eq('id', id).select(),
    delete: (id: number) =>
      insforge.database.from('c_param').update({ deleted: 1 }).eq('id', id),
    validate: (data: Record<string, unknown>) =>
      insforge.functions.invoke('param-validate', { body: data }),
  },

  require: {
    list: (params?: Record<string, unknown>) => {
      let query = insforge.database.from('c_require').select('*');
      if (params?.order) query = query.order(params.order as string);
      if (params?.limit) query = query.limit(params.limit as number);
      return query;
    },
    get: (id: number) =>
      insforge.database.from('c_require').select('*').eq('id', id).single(),
    create: (data: Record<string, unknown>) =>
      insforge.database.from('c_require').insert([data]).select(),
    update: (id: number, data: Record<string, unknown>) =>
      insforge.database.from('c_require').update(data).eq('id', id).select(),
    delete: (id: number) =>
      insforge.database.from('c_require').update({ deleted: 1 }).eq('id', id),
  },

  smartVersion: {
    list: (params?: Record<string, unknown>) => {
      let query = insforge.database.from('c_smart_version').select('*');
      if (params?.order) query = query.order(params.order as string);
      if (params?.limit) query = query.limit(params.limit as number);
      return query;
    },
    get: (id: number) =>
      insforge.database.from('c_smart_version').select('*').eq('id', id).single(),
    create: (data: Record<string, unknown>) =>
      insforge.database.from('c_smart_version').insert([data]).select(),
    update: (id: number, data: Record<string, unknown>) =>
      insforge.database.from('c_smart_version').update(data).eq('id', id).select(),
    delete: (id: number) =>
      insforge.database.from('c_smart_version').update({ deleted: 1 }).eq('id', id),
  },

  atomLike: {
    list: (params?: Record<string, unknown>) => {
      let query = insforge.database.from('atom_like').select('*');
      if (params?.order) query = query.order(params.order as string);
      if (params?.limit) query = query.limit(params.limit as number);
      return query;
    },
    create: (data: Record<string, unknown>) =>
      insforge.database.from('atom_like').insert([data]).select(),
    delete: (id: number) =>
      insforge.database.from('atom_like').delete().eq('id', id),
  },

  clientUpdate: {
    list: (params?: Record<string, unknown>) => {
      let query = insforge.database.from('client_update_version').select('*');
      if (params?.order) query = query.order(params.order as string);
      if (params?.limit) query = query.limit(params.limit as number);
      return query;
    },
    get: (id: number) =>
      insforge.database.from('client_update_version').select('*').eq('id', id).single(),
    create: (data: Record<string, unknown>) =>
      insforge.database.from('client_update_version').insert([data]).select(),
    update: (id: number, data: Record<string, unknown>) =>
      insforge.database.from('client_update_version').update(data).eq('id', id).select(),
    delete: (id: number) =>
      insforge.database.from('client_update_version').update({ deleted: 1 }).eq('id', id),
  },

  componentVersion: {
    list: (params?: Record<string, unknown>) => {
      let query = insforge.database.from('component_version').select('*');
      if (params?.order) query = query.order(params.order as string);
      if (params?.limit) query = query.limit(params.limit as number);
      return query;
    },
    get: (id: number) =>
      insforge.database.from('component_version').select('*').eq('id', id).single(),
    create: (data: Record<string, unknown>) =>
      insforge.database.from('component_version').insert([data]).select(),
    update: (id: number, data: Record<string, unknown>) =>
      insforge.database.from('component_version').update(data).eq('id', id).select(),
    delete: (id: number) =>
      insforge.database.from('component_version').update({ deleted: 1 }).eq('id', id),
  },

  componentRobotBlock: {
    list: (params?: Record<string, unknown>) => {
      let query = insforge.database.from('component_robot_block').select('*');
      if (params?.order) query = query.order(params.order as string);
      if (params?.limit) query = query.limit(params.limit as number);
      return query;
    },
    get: (id: number) =>
      insforge.database.from('component_robot_block').select('*').eq('id', id).single(),
    create: (data: Record<string, unknown>) =>
      insforge.database.from('component_robot_block').insert([data]).select(),
    update: (id: number, data: Record<string, unknown>) =>
      insforge.database.from('component_robot_block').update(data).eq('id', id).select(),
    delete: (id: number) =>
      insforge.database.from('component_robot_block').delete().eq('id', id),
  },

  componentRobotUse: {
    list: (params?: Record<string, unknown>) => {
      let query = insforge.database.from('component_robot_use').select('*');
      if (params?.order) query = query.order(params.order as string);
      if (params?.limit) query = query.limit(params.limit as number);
      return query;
    },
    create: (data: Record<string, unknown>) =>
      insforge.database.from('component_robot_use').insert([data]).select(),
    delete: (id: number) =>
      insforge.database.from('component_robot_use').delete().eq('id', id),
  },

  robotIcon: {
    list: (params?: Record<string, unknown>) => {
      let query = insforge.database.from('robot_design').select('*');
      if (params?.order) query = query.order(params.order as string);
      if (params?.limit) query = query.limit(params.limit as number);
      return query;
    },
    get: (id: number) =>
      insforge.database.from('robot_design').select('*').eq('id', id).single(),
    create: (data: Record<string, unknown>) =>
      insforge.database.from('robot_design').insert([data]).select(),
    update: (id: number, data: Record<string, unknown>) =>
      insforge.database.from('robot_design').update(data).eq('id', id).select(),
    delete: (id: number) =>
      insforge.database.from('robot_design').update({ deleted: 1 }).eq('id', id),
  },

  sharedVar: {
    list: (params?: Record<string, unknown>) => {
      let query = insforge.database.from('shared_var').select('*');
      if (params?.order) query = query.order(params.order as string);
      if (params?.limit) query = query.limit(params.limit as number);
      return query;
    },
    get: (id: number) =>
      insforge.database.from('shared_var').select('*').eq('id', id).single(),
    create: (data: Record<string, unknown>) =>
      insforge.database.from('shared_var').insert([data]).select(),
    update: (id: number, data: Record<string, unknown>) =>
      insforge.database.from('shared_var').update(data).eq('id', id).select(),
    delete: (id: number) =>
      insforge.database.from('shared_var').update({ deleted: 1 }).eq('id', id),
  },

  sharedFile: {
    list: (params?: Record<string, unknown>) => {
      let query = insforge.database.from('shared_file').select('*');
      if (params?.order) query = query.order(params.order as string);
      if (params?.limit) query = query.limit(params.limit as number);
      return query;
    },
    get: (id: number) =>
      insforge.database.from('shared_file').select('*').eq('id', id).single(),
    create: (data: Record<string, unknown>) =>
      insforge.database.from('shared_file').insert([data]).select(),
    update: (id: number, data: Record<string, unknown>) =>
      insforge.database.from('shared_file').update(data).eq('id', id).select(),
    delete: (id: number) =>
      insforge.database.from('shared_file').update({ deleted: 1 }).eq('id', id),
  },

  astronAgent: {
    list: (params?: Record<string, unknown>) => {
      let query = insforge.database.from('astron_agent_auth').select('*');
      if (params?.order) query = query.order(params.order as string);
      if (params?.limit) query = query.limit(params.limit as number);
      return query;
    },
    get: (id: number) =>
      insforge.database.from('astron_agent_auth').select('*').eq('id', id).single(),
    create: (data: Record<string, unknown>) =>
      insforge.database.from('astron_agent_auth').insert([data]).select(),
    update: (id: number, data: Record<string, unknown>) =>
      insforge.database.from('astron_agent_auth').update(data).eq('id', id).select(),
    delete: (id: number) =>
      insforge.database.from('astron_agent_auth').update({ deleted: 1 }).eq('id', id),
  },

  // Edge Functions 调用 — 使用 SDK functions.invoke
  notify: {
    send: (data: Record<string, unknown>) =>
      insforge.functions.invoke('notify', { body: data }),
  },
};

// ============================================================
// RPA Core Service API — 保留 axios（非 InsForge 服务）
// ============================================================

const rpaCoreClient: AxiosInstance = axios.create({
  baseURL: RPA_CORE_URL,
  headers: { 'Content-Type': 'application/json' },
});

export const rpaApi = {
  processes: {
    list: (params?: Record<string, unknown>) =>
      rpaCoreClient.get('/api/processes', { params }),
    get: (id: number) =>
      rpaCoreClient.get(`/api/processes/${id}`),
    create: (data: Record<string, unknown>) =>
      rpaCoreClient.post('/api/processes', data),
    update: (id: number, data: Record<string, unknown>) =>
      rpaCoreClient.patch(`/api/processes/${id}`, data),
    delete: (id: number) =>
      rpaCoreClient.delete(`/api/processes/${id}`),
    getTree: () =>
      rpaCoreClient.get('/api/processes/tree'),
  },

  robots: {
    list: (params?: Record<string, unknown>) =>
      rpaCoreClient.get('/api/robots', { params }),
    get: (robotId: string) =>
      rpaCoreClient.get(`/api/robots/${robotId}`),
    create: (data: Record<string, unknown>) =>
      rpaCoreClient.post('/api/robots', data),
    update: (robotId: string, data: Record<string, unknown>) =>
      rpaCoreClient.patch(`/api/robots/${robotId}`, data),
    delete: (robotId: string) =>
      rpaCoreClient.delete(`/api/robots/${robotId}`),
    executeList: (data: Record<string, unknown>) =>
      rpaCoreClient.post('/api/robots/execute-list', data),
  },

  versions: {
    publish: (data: Record<string, unknown>) =>
      rpaCoreClient.post('/api/versions/publish', data),
    rollback: (id: number) =>
      rpaCoreClient.post(`/api/versions/${id}/rollback`),
    history: (robotId: string) =>
      rpaCoreClient.get(`/api/versions/${robotId}/history`),
    compare: (params: Record<string, unknown>) =>
      rpaCoreClient.get('/api/versions/compare', { params }),
  },

  records: {
    list: (params?: Record<string, unknown>) =>
      rpaCoreClient.get('/api/records', { params }),
    get: (id: number) =>
      rpaCoreClient.get(`/api/records/${id}`),
    getLogs: (id: number) =>
      rpaCoreClient.get(`/api/records/${id}/logs`),
    getStats: () =>
      rpaCoreClient.get('/api/records/stats'),
  },

  schedules: {
    list: (params?: Record<string, unknown>) =>
      rpaCoreClient.get('/api/schedules', { params }),
    get: (id: number) =>
      rpaCoreClient.get(`/api/schedules/${id}`),
    create: (data: Record<string, unknown>) =>
      rpaCoreClient.post('/api/schedules', data),
    update: (id: number, data: Record<string, unknown>) =>
      rpaCoreClient.patch(`/api/schedules/${id}`, data),
    delete: (id: number) =>
      rpaCoreClient.delete(`/api/schedules/${id}`),
  },

  dispatches: {
    list: (params?: Record<string, unknown>) =>
      rpaCoreClient.get('/api/dispatches', { params }),
    get: (id: number) =>
      rpaCoreClient.get(`/api/dispatches/${id}`),
    create: (data: Record<string, unknown>) =>
      rpaCoreClient.post('/api/dispatches', data),
    update: (id: number, data: Record<string, unknown>) =>
      rpaCoreClient.patch(`/api/dispatches/${id}`, data),
    delete: (id: number) =>
      rpaCoreClient.delete(`/api/dispatches/${id}`),
    poll: (id: number) =>
      rpaCoreClient.get(`/api/dispatches/${id}/poll`),
  },

  triggers: {
    list: (params?: Record<string, unknown>) =>
      rpaCoreClient.get('/api/triggers', { params }),
    get: (id: number) =>
      rpaCoreClient.get(`/api/triggers/${id}`),
    create: (data: Record<string, unknown>) =>
      rpaCoreClient.post('/api/triggers', data),
    update: (id: number, data: Record<string, unknown>) =>
      rpaCoreClient.patch(`/api/triggers/${id}`, data),
    delete: (id: number) =>
      rpaCoreClient.delete(`/api/triggers/${id}`),
  },

  terminals: {
    list: (params?: Record<string, unknown>) =>
      rpaCoreClient.get('/api/terminals', { params }),
    get: (terminalId: string) =>
      rpaCoreClient.get(`/api/terminals/${terminalId}`),
    register: (data: Record<string, unknown>) =>
      rpaCoreClient.post('/api/terminals/register', data),
    heartbeat: (data: Record<string, unknown>) =>
      rpaCoreClient.post('/api/terminals/heartbeat', data),
    update: (id: number, data: Record<string, unknown>) =>
      rpaCoreClient.patch(`/api/terminals/${id}`, data),
    delete: (id: number) =>
      rpaCoreClient.delete(`/api/terminals/${id}`),
  },

  market: {
    markets: {
      list: () => rpaCoreClient.get('/api/market/markets'),
      create: (data: Record<string, unknown>) => rpaCoreClient.post('/api/market/markets', data),
      update: (id: number, data: Record<string, unknown>) => rpaCoreClient.patch(`/api/market/markets/${id}`, data),
      delete: (id: number) => rpaCoreClient.delete(`/api/market/markets/${id}`),
    },
    applications: {
      list: (params?: Record<string, unknown>) => rpaCoreClient.get('/api/market/applications', { params }),
      create: (data: Record<string, unknown>) => rpaCoreClient.post('/api/market/applications', data),
      review: (id: number, data: Record<string, unknown>) => rpaCoreClient.patch(`/api/market/applications/${id}/review`, data),
    },
    invitations: {
      list: () => rpaCoreClient.get('/api/market/invitations'),
      create: (data: Record<string, unknown>) => rpaCoreClient.post('/api/market/invitations', data),
    },
    resources: {
      list: () => rpaCoreClient.get('/api/market/resources'),
      create: (data: Record<string, unknown>) => rpaCoreClient.post('/api/market/resources', data),
    },
  },

  quotas: {
    info: () => rpaCoreClient.get('/api/quotas/info'),
    check: () => rpaCoreClient.get('/api/quotas/check'),
    recordExecution: (data: Record<string, unknown>) => rpaCoreClient.post('/api/quotas/record-execution', data),
  },
};

export { rpaCoreClient };
```

#### Step 3.2: 关键 API 变化对照表

| 操作 | 旧写法 (axios → PostgREST) | 新写法 (InsForge SDK) |
|------|--------------------------|---------------------|
| 列表查询 | `postgrestClient.get('/c_atom_meta_new', { params: { select: '*', order: 'create_time.desc', limit: 20 } })` | `insforge.database.from('c_atom_meta_new').select('*').order('create_time', { ascending: false }).limit(20)` |
| 单条查询 | `postgrestClient.get('/c_atom_meta_new?id=eq.123', { params: { select: '*' } })` | `insforge.database.from('c_atom_meta_new').select('*').eq('id', 123).single()` |
| 创建 | `postgrestClient.post('/c_atom_meta_new', data)` | `insforge.database.from('c_atom_meta_new').insert([data]).select()` |
| 更新 | `postgrestClient.patch('/c_atom_meta_new?id=eq.123', data)` | `insforge.database.from('c_atom_meta_new').update(data).eq('id', 123).select()` |
| 软删除 | `postgrestClient.patch('/c_atom_meta_new?id=eq.123', { deleted: 1 })` | `insforge.database.from('c_atom_meta_new').update({ deleted: 1 }).eq('id', 123)` |
| 硬删除 | `postgrestClient.delete('/atom_like?id=eq.123')` | `insforge.database.from('atom_like').delete().eq('id', 123)` |

### 重要注意事项

1. **insert 必须传数组**：SDK 的 `.insert()` 要求数据为数组格式 `[{...}]`，不是单对象
2. **返回 `{data, error}`**：所有 SDK 方法返回 `{data, error}` 结构，调用方需要适配
3. **不再需要手动 token**：SDK 自动从已登录 session 中获取 token 并附加到请求
4. **不再直连 PostgREST 端口 5430**：SDK 通过 InsForge App (7130) 代理数据库请求，前端无需暴露 PostgREST 端口

### 验证方式
- 调用 `crudApi.atomMeta.list()` → 返回 `{data: [...], error: null}`
- 调用 `crudApi.atomMeta.create({...})` → 返回 `{data: [{...}], error: null}`
- 未登录时调用 → 返回 `{data: null, error: { message: '...' }}`

---

## Fix-4: Edge Functions 调用迁移到 SDK

### 目标
将 `api-client.ts` 中通过 axios 调用 Edge Functions 的方式替换为 SDK 的 `functions.invoke()`。

### 涉及文件
- `frontend/packages/shared/src/api-client.ts` — 已在 Fix-3 中一并修复

### 当前代码问题

```typescript
// 旧写法：通过 axios 调用 /functions/v1/notify
notify: {
  send: (data) => insforgeAuthClient.post('/functions/v1/notify', data),
},
// 旧写法：通过 axios 调用 /functions/v1/param-validate
param: {
  validate: (data) => insforgeAuthClient.post('/functions/v1/param-validate', data),
},
```

### 修复后代码（已在 Fix-3 中包含）

```typescript
// 新写法：通过 SDK functions.invoke
notify: {
  send: (data: Record<string, unknown>) =>
    insforge.functions.invoke('notify', { body: data }),
},
param: {
  validate: (data: Record<string, unknown>) =>
    insforge.functions.invoke('param-validate', { body: data }),
},
```

### 重要注意事项

1. **路径变化**：Edge Functions 通过 InsForge App 代理访问，路径为 `/functions/{slug}`（不带 `/v1` 前缀）
2. **SDK 自动附加认证**：`functions.invoke()` 自动携带当前用户的 JWT token
3. **返回 `{data, error}`**：统一错误处理模式

---

## Fix-5: Python rpa-core-service JWT 验证改为远程验证

### 目标
将 Python 服务中本地 `jose.jwt.decode()` 解析 JWT 的方式，改为调用 InsForge App 的 `/api/auth/sessions/current` 端点进行远程 token 验证。

### 涉及文件
- `backend/rpa-core-service/app/dependencies/auth.py` — 重写 JWT 验证逻辑
- `backend/rpa-core-service/app/config.py` — 添加 `INSFORGE_API_URL` 配置

### 当前代码问题

```python
# 当前：本地解析 JWT，需要共享 JWT_SECRET
payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
```

**问题**：
- 需要 Python 服务和 InsForge 共享同一个 `JWT_SECRET`
- 无法验证 token 是否已被撤销
- 无法获取 InsForge 侧的最新用户状态
- 如果 InsForge 更换签名密钥，Python 服务会全部 401

### 修复后代码

#### Step 5.1: 修改 `config.py` — 添加 InsForge API URL

```python
from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    APP_NAME: str = "RPA Core Service"
    API_VERSION: str = "1.0"
    DATABASE_URL: str = ""
    DATABASE_USERNAME: str = ""
    DATABASE_PASSWORD: str = ""
    REDIS_URL: str = ""

    LOG_LEVEL: str = "INFO"
    LOG_DIR: str = "/var/log/rpa-core-service"

    # InsForge API URL — 用于远程 token 验证
    # 自托管模式：使用 Docker 容器名 insforge，容器间通过 Docker 网络通信
    # 本地开发（非容器）：可改为 http://localhost:7130
    INSFORGE_API_URL: str = Field(
        default="http://insforge:7130",
        description="InsForge App base URL for token verification (Docker network)",
    )

    # 保留 JWT 配置作为降级方案（当 InsForge 不可用时使用本地验证）
    SECRET_KEY: str = Field(
        default="change-me-in-production",
        validation_alias="JWT_SECRET",
        description="JWT signing secret (env: JWT_SECRET) — fallback only",
    )
    ALGORITHM: str = Field(
        default="HS256",
        validation_alias="JWT_ALGORITHM",
        description="JWT signing algorithm (env: JWT_ALGORITHM)",
    )
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30

    # Token 验证模式: "remote" (推荐) 或 "local" (降级)
    AUTH_VERIFY_MODE: str = Field(
        default="remote",
        description="Token verification mode: 'remote' (call InsForge API) or 'local' (decode JWT locally)",
    )

    model_config = SettingsConfigDict(
        env_file=None,
        case_sensitive=False,
        extra="ignore",
    )


@lru_cache
def get_settings() -> Settings:
    return Settings()
```

#### Step 5.2: 重写 `auth.py` — 远程验证 + 本地降级

```python
from collections.abc import Callable
from dataclasses import dataclass
from typing import Annotated, Any

import httpx
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt

from app.config import get_settings

settings = get_settings()

security_scheme = HTTPBearer()


@dataclass
class UserContext:
    user_id: str
    email: str
    role: str
    tenant_id: str | None = None


async def _verify_token_remote(token: str) -> UserContext:
    """通过 InsForge API 远程验证 token（推荐方式）。

    调用 GET /api/auth/sessions/current 验证 token 有效性，
    InsForge 负责 JWT 解析、过期检查、用户状态验证。
    """
    async with httpx.AsyncClient(timeout=10.0) as client:
        try:
            response = await client.get(
                f"{settings.INSFORGE_API_URL}/api/auth/sessions/current",
                headers={"Authorization": f"Bearer {token}"},
            )
            if response.status_code == 401:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Invalid or expired token",
                )
            if response.status_code != 200:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail=f"Token verification failed: {response.status_code}",
                )

            data = response.json()
            user = data.get("user", {})
            if not user or not user.get("id"):
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Invalid token payload",
                )

            return UserContext(
                user_id=str(user["id"]),
                email=user.get("email", ""),
                role=user.get("role", "authenticated"),
                tenant_id=user.get("tenant_id"),
            )
        except httpx.RequestError as e:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"InsForge auth service unreachable: {e}",
            )


async def _verify_token_local(token: str) -> UserContext:
    """本地 JWT 解析验证（降级方案）。

    仅在 InsForge API 不可用时使用。
    需要 JWT_SECRET 与 InsForge 配置一致。
    """
    try:
        payload: dict[str, Any] = jwt.decode(
            token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM]
        )
        user_id: str | None = payload.get("sub") or payload.get("user_id")
        email: str | None = payload.get("email")
        role: str | None = payload.get("role")
        tenant_id: str | None = payload.get("tenant_id")

        if user_id is None or email is None or role is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token payload",
            )

        return UserContext(
            user_id=str(user_id),
            email=email,
            role=role,
            tenant_id=tenant_id,
        )
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        )


async def get_current_user(
    credentials: Annotated[HTTPAuthorizationCredentials, Depends(security_scheme)],
) -> UserContext:
    """验证 JWT token 并返回用户上下文。

    优先使用远程验证（调用 InsForge API），
    降级使用本地 JWT 解析。
    """
    token = credentials.credentials

    if settings.AUTH_VERIFY_MODE == "remote":
        try:
            return await _verify_token_remote(token)
        except HTTPException as e:
            if e.status_code == 502:
                # InsForge 不可用，降级到本地验证
                return await _verify_token_local(token)
            raise

    return await _verify_token_local(token)


def require_role(required_role: str) -> Callable[[UserContext], UserContext]:
    async def role_checker(
        current_user: Annotated[UserContext, Depends(get_current_user)],
    ) -> UserContext:
        if current_user.role != required_role:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Role '{required_role}' required",
            )
        return current_user

    return role_checker


async def get_tenant_context(
    current_user: Annotated[UserContext, Depends(get_current_user)],
) -> str | None:
    return current_user.tenant_id
```

#### Step 5.3: 添加 `httpx` 依赖

在 `backend/rpa-core-service/pyproject.toml` 中添加：

```toml
[project]
dependencies = [
    # ... 现有依赖 ...
    "httpx>=0.27.0",
]
```

### 重要注意事项

1. **远程验证是推荐方式**：通过 `AUTH_VERIFY_MODE=remote` 启用
2. **本地验证是降级方案**：当 InsForge API 不可用时自动降级
3. **不再强依赖 JWT_SECRET 共享**：远程模式下 Python 服务无需知道 JWT_SECRET
4. **token 撤销即时生效**：远程验证可以检测到已被 InsForge 撤销的 token

### 验证方式
- 正常模式：携带有效 token → InsForge API 返回 200 → 解析用户信息
- 降级模式：InsForge 不可用 → 自动降级到本地 JWT 解析
- 无效 token：InsForge API 返回 401 → Python 服务返回 401

---

## Fix-6: Edge Functions 内部使用 InsForge SDK

### 目标
将 Edge Functions 中通过 `fetch(POSTGREST_URL + '/table')` 裸调 PostgREST 的方式，替换为 InsForge SDK 的 `createClient` + `database` API。

> **自托管注意**：自托管模式下，Edge Functions 运行在本地 Deno 容器（端口 7133），而非云端 Deno Subhosting。函数源码通过 Docker volume 挂载到容器中。SDK 的 `createClient` 在 Edge Functions 中同样可用，通过 `npm:@insforge/sdk` 导入。

### 涉及文件
- `functions/notify/index.ts` — 使用 SDK 替代裸 fetch
- `functions/blacklist/index.ts` — 使用 SDK 替代裸 fetch
- `functions/param-validate/index.ts` — 无需修改（纯验证逻辑，不访问数据库）

### 当前代码问题

```typescript
// 当前：裸 fetch 调用 PostgREST
const POSTGREST_URL = Deno.env.get('POSTGREST_BASE_URL') || 'http://postgrest:3000';

async function logNotification(record: {...}) {
  await fetch(`${POSTGREST_URL}/notification_logs`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Prefer': 'return=minimal' },
    body: JSON.stringify({...}),
  });
}
```

### 修复后代码

#### Step 6.1: 重写 `functions/notify/index.ts`

```typescript
// Edge Function: Notification Sending (replaces NotifySendController)
// Uses InsForge SDK for database access

import { createClient } from 'npm:@insforge/sdk';

const INSFORGE_BASE_URL = Deno.env.get('INSFORGE_BASE_URL') || 'http://insforge:7130';
const ANON_KEY = Deno.env.get('ANON_KEY') || '';

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const PHONE_REGEX = /^\+?[1-9]\d{6,14}$/;
const MAX_CONTENT_LENGTH = 10000;
const MAX_SUBJECT_LENGTH = 200;
const MAX_RECIPIENT_LENGTH = 320;

interface NotifyRequest {
  type: 'email' | 'sms' | 'in_app';
  recipient: string;
  subject?: string;
  content: string;
  template_id?: string;
  params?: Record<string, string>;
}

interface NotifyResponse {
  success: boolean;
  message: string;
  type: string;
  notification_id?: string;
}

function validateRequest(body: NotifyRequest): string[] {
  const errors: string[] = [];

  if (!body.type || !body.recipient || !body.content) {
    errors.push('Missing required fields: type, recipient, content');
    return errors;
  }

  const validTypes = ['email', 'sms', 'in_app'];
  if (!validTypes.includes(body.type)) {
    errors.push(`Invalid notification type: ${body.type}. Must be one of: ${validTypes.join(', ')}`);
  }

  if (body.recipient.length > MAX_RECIPIENT_LENGTH) {
    errors.push(`Recipient exceeds maximum length of ${MAX_RECIPIENT_LENGTH} characters`);
  }

  if (body.type === 'email' && !EMAIL_REGEX.test(body.recipient)) {
    errors.push(`Invalid email format: ${body.recipient}`);
  }

  if (body.type === 'sms' && !PHONE_REGEX.test(body.recipient)) {
    errors.push(`Invalid phone number format: ${body.recipient}. Use E.164 format (e.g. +1234567890)`);
  }

  if (body.content.length > MAX_CONTENT_LENGTH) {
    errors.push(`Content exceeds maximum length of ${MAX_CONTENT_LENGTH} characters`);
  }

  if (body.subject && body.subject.length > MAX_SUBJECT_LENGTH) {
    errors.push(`Subject exceeds maximum length of ${MAX_SUBJECT_LENGTH} characters`);
  }

  if (body.template_id && typeof body.template_id !== 'string') {
    errors.push('template_id must be a string');
  }

  return errors;
}

async function logNotification(
  client: ReturnType<typeof createClient>,
  record: {
    type: string;
    recipient: string;
    subject: string | null;
    content_preview: string;
    status: string;
    error_message?: string;
  },
): Promise<void> {
  const { error } = await client.database
    .from('notification_logs')
    .insert([{
      type: record.type,
      recipient: record.recipient,
      subject: record.subject,
      content_preview: record.content_preview,
      status: record.status,
      error_message: record.error_message || null,
      created_at: new Date().toISOString(),
    }]);

  if (error) {
    console.error('[NOTIFY] Failed to log notification:', error);
  }
}

async function sendEmail(
  recipient: string,
  subject: string | undefined,
  content: string,
): Promise<{ success: boolean; message: string }> {
  const smtpHost = Deno.env.get('SMTP_HOST');

  if (!smtpHost) {
    console.log(`[NOTIFY] Email to ${recipient}: ${subject || content.substring(0, 50)}`);
    return { success: true, message: 'Email logged (SMTP not configured)' };
  }

  // TODO: Integrate with actual SMTP/SendGrid/Resend service
  console.log(`[NOTIFY] Email sent to ${recipient}: ${subject || content.substring(0, 50)}`);
  return { success: true, message: 'Email sent successfully' };
}

async function sendSms(
  recipient: string,
  content: string,
): Promise<{ success: boolean; message: string }> {
  const smsProvider = Deno.env.get('SMS_PROVIDER');
  const smsApiKey = Deno.env.get('SMS_API_KEY');

  if (!smsProvider || !smsApiKey) {
    console.log(`[NOTIFY] SMS to ${recipient}: ${content.substring(0, 50)}`);
    return { success: true, message: 'SMS logged (SMS provider not configured)' };
  }

  // TODO: Integrate with actual SMS service (Twilio, Aliyun SMS, etc.)
  console.log(`[NOTIFY] SMS sent to ${recipient}: ${content.substring(0, 50)}`);
  return { success: true, message: 'SMS sent successfully' };
}

async function sendInApp(
  client: ReturnType<typeof createClient>,
  recipient: string,
  content: string,
): Promise<{ success: boolean; message: string; notification_id?: string }> {
  const { data, error } = await client.database
    .from('in_app_notifications')
    .insert([{
      user_id: recipient,
      content: content,
      is_read: false,
      created_at: new Date().toISOString(),
    }])
    .select();

  if (error) {
    console.error(`[NOTIFY] Failed to store in-app notification:`, error);
    return { success: false, message: `Failed to store notification: ${error.message}` };
  }

  const notificationId = Array.isArray(data) && data[0]?.id ? String(data[0].id) : undefined;
  return { success: true, message: 'In-app notification stored', notification_id: notificationId };
}

Deno.serve(async (req: Request) => {
  // CORS headers
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  };

  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  // Extract user token for authenticated SDK access
  const authHeader = req.headers.get('Authorization');
  const userToken = authHeader ? authHeader.replace('Bearer ', '') : null;

  // Create SDK client — use edgeFunctionToken for authenticated access
  const client = createClient({
    baseUrl: INSFORGE_BASE_URL,
    anonKey: ANON_KEY,
    ...(userToken ? { edgeFunctionToken: userToken } : {}),
  });

  let body: NotifyRequest;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON body' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const validationErrors = validateRequest(body);
  if (validationErrors.length > 0) {
    return new Response(JSON.stringify({
      success: false,
      message: validationErrors.join('; '),
      type: body.type || 'unknown',
    }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const contentPreview = body.content.substring(0, 100);
  let result: NotifyResponse;

  try {
    switch (body.type) {
      case 'email': {
        const emailResult = await sendEmail(body.recipient, body.subject, body.content);
        result = { ...emailResult, type: 'email' };
        break;
      }
      case 'sms': {
        const smsResult = await sendSms(body.recipient, body.content);
        result = { ...smsResult, type: 'sms' };
        break;
      }
      case 'in_app': {
        const inAppResult = await sendInApp(client, body.recipient, body.content);
        result = { ...inAppResult, type: 'in_app' };
        break;
      }
      default:
        result = { success: false, message: 'Unknown notification type', type: body.type };
    }
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    result = { success: false, message: errorMessage, type: body.type };
  }

  // Log notification using SDK
  await logNotification(client, {
    type: body.type,
    recipient: body.recipient,
    subject: body.subject || null,
    content_preview: contentPreview,
    status: result.success ? 'sent' : 'failed',
    error_message: result.success ? undefined : result.message,
  });

  return new Response(JSON.stringify(result), {
    status: result.success ? 200 : 500,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
});
```

#### Step 6.2: 重写 `functions/blacklist/index.ts`

```typescript
// Edge Function: Blacklist Checking (replaces BlacklistController)
// Uses InsForge SDK for database access

import { createClient } from 'npm:@insforge/sdk';

const INSFORGE_BASE_URL = Deno.env.get('INSFORGE_BASE_URL') || 'http://insforge:7130';
const ANON_KEY = Deno.env.get('ANON_KEY') || '';

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const IP_REGEX = /^(?:(?:25[0-5]|2[0-4]\d|[01]?\d\d?)\.){3}(?:25[0-5]|2[0-4]\d|[01]?\d\d?)$/;
const MAX_CHECK_ITEMS = 10;

interface BlacklistCheckRequest {
  user_id?: string;
  email?: string;
  ip_address?: string;
}

interface BlacklistCheckResponse {
  blacklisted: boolean;
  details: Record<string, boolean>;
  errors?: string[];
}

function validateRequest(body: BlacklistCheckRequest): string[] {
  const errors: string[] = [];

  if (!body.user_id && !body.email && !body.ip_address) {
    errors.push('At least one of user_id, email, or ip_address is required');
    return errors;
  }

  const checkCount = [body.user_id, body.email, body.ip_address].filter(Boolean).length;
  if (checkCount > MAX_CHECK_ITEMS) {
    errors.push(`Maximum ${MAX_CHECK_ITEMS} check items allowed`);
  }

  if (body.email && !EMAIL_REGEX.test(body.email)) {
    errors.push(`Invalid email format: ${body.email}`);
  }

  if (body.ip_address && !IP_REGEX.test(body.ip_address)) {
    errors.push(`Invalid IP address format: ${body.ip_address}`);
  }

  if (body.user_id && typeof body.user_id !== 'string') {
    errors.push('user_id must be a string');
  }

  return errors;
}

async function checkBlacklist(
  client: ReturnType<typeof createClient>,
  field: string,
  value: string,
): Promise<boolean> {
  const { data, error } = await client.database
    .from('blacklist')
    .select('id')
    .eq(field, value)
    .limit(1);

  if (error) {
    console.error(`[BLACKLIST] Query failed for ${field}=${value}:`, error);
    return false;
  }

  return Array.isArray(data) && data.length > 0;
}

Deno.serve(async (req: Request) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  };

  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  const url = new URL(req.url);

  // Health check endpoint
  if (req.method === 'GET' && url.pathname === '/status') {
    return new Response(JSON.stringify({
      checks: ['user_id', 'email', 'ip_address'],
      max_items_per_check: MAX_CHECK_ITEMS,
    }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  // Create SDK client with anon key (blacklist check is a public operation)
  const client = createClient({
    baseUrl: INSFORGE_BASE_URL,
    anonKey: ANON_KEY,
  });

  let body: BlacklistCheckRequest;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON body' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const validationErrors = validateRequest(body);
  if (validationErrors.length > 0) {
    return new Response(JSON.stringify({
      blacklisted: false,
      details: {},
      errors: validationErrors,
    }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const results: Record<string, boolean> = {};

  if (body.user_id) {
    results.user_blacklisted = await checkBlacklist(client, 'user_id', body.user_id);
  }

  if (body.email) {
    results.email_blacklisted = await checkBlacklist(client, 'email', body.email);
  }

  if (body.ip_address) {
    results.ip_blacklisted = await checkBlacklist(client, 'ip_address', body.ip_address);
  }

  const isBlacklisted = Object.values(results).some((v) => v);

  const response: BlacklistCheckResponse = {
    blacklisted: isBlacklisted,
    details: results,
  };

  return new Response(JSON.stringify(response), {
    status: 200,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
});
```

### 重要注意事项

1. **Deno 环境导入 SDK**：使用 `npm:@insforge/sdk` 格式（Deno npm 兼容）
2. **`edgeFunctionToken`**：当 Edge Function 需要以用户身份访问数据库时，从请求头提取 token 并传入 `createClient({ edgeFunctionToken })`
3. **`anonKey`**：公开操作（如黑名单检查）使用 anon key 即可
4. **不再需要 `POSTGREST_URL` 环境变量**：SDK 通过 InsForge App 代理所有数据库请求

---

## Fix-7: 环境变量和配置更新

### 目标
更新前端和后端的环境变量配置，移除不再需要的变量，添加 SDK 所需的新变量。所有配置基于 AstronRPA 自托管 InsForge 的实际部署架构。

### 涉及文件
- `frontend/.env.example` — 更新前端环境变量
- `docker/.env.example` — 更新 Docker 环境变量（AstronRPA 统一配置）
- `docker/.env.insforge` — 更新 InsForge 专用环境变量
- `docker/docker-compose.yml` — 移除 PostgREST 端口暴露

### 操作步骤

#### Step 7.1: 更新前端 `.env.example`

AstronRPA 前端通过 `VITE_*` 前缀的环境变量配置服务地址。修改 `frontend/.env.example`（或各子包的 `.env.example`）：

```bash
# ============================================================
# InsForge SDK 配置（自托管模式）
# ============================================================
# InsForge App 地址 — SDK 通过此地址代理所有请求（数据库、认证、存储、函数）
VITE_INSFORGE_URL=http://localhost:7130
# InsForge 匿名密钥 — 从 Dashboard Settings → API 页面获取
VITE_INSFORGE_ANON_KEY=

# ============================================================
# RPA Core Service 配置
# ============================================================
# Python FastAPI 服务地址（RPA 专用业务逻辑，非 InsForge 服务）
VITE_RPA_CORE_URL=http://localhost:8040

# ============================================================
# 已移除的配置（不再需要）
# ============================================================
# VITE_POSTGREST_URL — 不再直连 PostgREST，SDK 通过 InsForge App (7130) 代理
# VITE_INSFORGE_AUTH_URL — 不再直连 Auth 服务，SDK 自动管理认证
```

#### Step 7.2: 更新 `docker/.env.example`（AstronRPA 统一环境变量）

AstronRPA 使用 `docker/.env.example` 作为所有 Docker 服务的统一环境变量文件。需要新增 `VITE_INSFORGE_ANON_KEY`：

```bash
# ============================================================
# InsForge Platform Configuration（自托管）
# ============================================================
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=rpa
JWT_SECRET=a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2
ENCRYPTION_KEY=f1e2d3c4b5a69788796a5b4c3d2e1f0a
AWS_S3_BUCKET=rpa-files
AWS_REGION=us-east-1
OPENROUTER_API_KEY=

# ============================================================
# Frontend Configuration（新增/修改）
# ============================================================
VITE_INSFORGE_URL=http://localhost:7130
VITE_INSFORGE_ANON_KEY=           # 从 Dashboard Settings → API 获取后填入
VITE_RPA_CORE_URL=http://localhost:8040
# VITE_POSTGREST_URL 已移除 — 前端不再直连 PostgREST

# ============================================================
# Redis
# ============================================================
REDIS_HOST=rpa-redis
REDIS_PORT=6379
REDIS_DB=0
REDIS_PASSWORD=
```

#### Step 7.3: 更新 `docker/.env.insforge`（InsForge 专用配置）

```bash
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=rpa
JWT_SECRET=a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2
ENCRYPTION_KEY=f1e2d3c4b5a69788796a5b4c3d2e1f0a
AWS_S3_BUCKET=rpa-files
AWS_REGION=us-east-1
OPENROUTER_API_KEY=placeholder-openrouter-api-key

# Edge Functions 环境变量（新增）
# 自托管模式下，Edge Functions 运行在本地 Deno 容器中
# SDK 通过此地址访问 InsForge App（Docker 网络内部通信）
INSFORGE_BASE_URL=http://insforge:7130
```

#### Step 7.4: 更新 `docker/docker-compose.yml` — 移除 PostgREST 端口暴露

AstronRPA 的 `docker/docker-compose.yml` 中 PostgREST 当前暴露了 5430 端口给宿主机，前端直接通过此端口访问。修复后应移除该端口暴露：

```yaml
# 修改前：PostgREST 端口暴露给前端直连
postgrest:
  image: postgrest/postgrest:v12.2.12
  container_name: rpa-postgrest
  ports:
    - '5430:3000'       # ← 移除此行

# 修改后：PostgREST 仅内部使用
postgrest:
  image: postgrest/postgrest:v12.2.12
  container_name: rpa-postgrest
  # ports 已移除 — 前端通过 InsForge App (7130) 代理访问
  expose:
    - '3000'            # 仅暴露给 Docker 网络内部
```

> **注意**：`docker/docker-compose.insforge.yml`（仅 InsForge 平台）中的 PostgREST 本身就没有暴露端口，无需修改。

#### Step 7.5: 更新 `docker/docker-compose.yml` — rpa-core-service 环境变量

确保 `rpa-core-service` 容器能通过 Docker 网络访问 InsForge：

```yaml
rpa-core-service:
  environment:
    # InsForge API URL — 自托管模式下使用 Docker 容器名
    INSFORGE_API_URL: http://insforge:7130
    # JWT_SECRET 保留作为降级验证方案
    JWT_SECRET: ${JWT_SECRET}
```

---

## Fix-8: 清理冗余依赖

### 目标
移除不再需要的 axios 实例和 PostgREST 直连相关代码。

### 涉及文件
- `frontend/packages/shared/src/api-client.ts` — 移除 `postgrestClient` 和 `insforgeAuthClient` 导出
- `frontend/packages/components/src/components/Auth/api/http.ts` — 简化（已在 Fix-2 中处理）

### 操作步骤

#### Step 8.1: 移除 `api-client.ts` 中的冗余导出

```typescript
// 移除以下导出（不再需要）：
// export { postgrestClient, rpaCoreClient, insforgeAuthClient };

// 仅保留：
export { rpaCoreClient };
```

#### Step 8.2: 检查 axios 依赖是否仍需保留

`axios` 在以下场景仍需保留：
- `rpaCoreClient` — 调用 Python rpa-core-service（非 InsForge 服务）
- `http.ts` — 通用 HTTP 请求工具

因此 `axios` 依赖**保留**，不移除。

---

## 调用方适配指南

由于 SDK 方法返回 `{data, error}` 结构（而非 axios 的 `response.data`），所有调用 `crudApi` 和 `authApi` 的前端代码需要适配返回值解构。

### 适配模式

```typescript
// ============================================================
// 旧写法（axios 风格）
// ============================================================
try {
  const response = await crudApi.atomMeta.list({ limit: 20 });
  const items = response.data;  // axios 包装
  // 使用 items...
} catch (error) {
  // 处理错误
}

// ============================================================
// 新写法（InsForge SDK 风格）
// ============================================================
const { data, error } = await crudApi.atomMeta.list({ limit: 20 });
if (error) {
  // 处理错误
  console.error(error.message);
  return;
}
// 使用 data...
const items = data;
```

### 批量适配脚本（可选）

如果调用方数量很大，可以编写一个 codemod 脚本自动转换。以下是关键转换规则：

| 旧模式 | 新模式 |
|--------|--------|
| `const res = await crudApi.xxx.yyy()` | `const { data, error } = await crudApi.xxx.yyy()` |
| `res.data` | `data` |
| `try { ... } catch (e) { ... }` | `if (error) { ... }` |
| `response.data.access_token` | SDK 自动管理，无需手动提取 |
| `localStorage.getItem('insforge_token')` | 移除，SDK 自动管理 |
| `localStorage.setItem('insforge_token', token)` | 移除，SDK 自动管理 |

---

## 完整修复执行顺序

为保证修复过程可逐步验证，建议按以下顺序执行：

```
Phase 1: 基础设施准备
├── Fix-1: 安装 @insforge/sdk + 创建 insforge-client.ts
├── Fix-7: 更新环境变量和 docker-compose.yml
└── 验证: pnpm install 成功，insforge 客户端可导入

Phase 2: 认证模块迁移（影响面最大，优先修复）
├── Fix-2: 重写 login.ts + 简化 http.ts
└── 验证: 登录/注册/登出流程正常

Phase 3: 数据访问层迁移
├── Fix-3: 重写 api-client.ts CRUD 部分
├── Fix-4: Edge Functions 调用改为 SDK invoke
└── 验证: 所有 23 张表的 CRUD 操作正常

Phase 4: 后端适配
├── Fix-5: Python JWT 验证改为远程验证
└── 验证: rpa-core-service token 验证正常

Phase 5: Edge Functions 内部适配
├── Fix-6: notify + blacklist 使用 SDK
└── 验证: Edge Functions 数据库操作正常

Phase 6: 清理收尾
├── Fix-8: 移除冗余导出
├── 适配所有调用方（{data, error} 解构）
└── 验证: 全量回归测试通过
```

---

## 验证清单

完成所有修复后，逐项验证：

### 认证模块
- [ ] `insforge.auth.signUp()` — 注册新用户成功
- [ ] `insforge.auth.signInWithPassword()` — 登录成功，返回 `{data: {user, accessToken}, error: null}`
- [ ] `insforge.auth.getCurrentUser()` — 获取当前用户成功
- [ ] `insforge.auth.signOut()` — 登出成功，session 清除
- [ ] 登录后刷新页面 — `getCurrentUser()` 自动恢复 session（httpOnly cookie）
- [ ] 401 响应 — SDK 自动处理，无需手动 `localStorage.removeItem`

### 数据库 CRUD 模块
- [ ] `insforge.database.from('c_atom_meta_new').select('*')` — 列表查询返回 `{data: [...], error: null}`
- [ ] `.eq('id', 123).single()` — 单条查询返回 `{data: {...}, error: null}`
- [ ] `.insert([{...}]).select()` — 创建返回 `{data: [{...}], error: null}`
- [ ] `.update({...}).eq('id', 123).select()` — 更新返回 `{data: [{...}], error: null}`
- [ ] `.delete().eq('id', 123)` — 删除返回 `{error: null}`
- [ ] `.order('create_time', {ascending: false}).limit(20)` — 排序分页正常
- [ ] 未登录调用 — 返回 `{data: null, error: {message: '...'}}`
- [ ] 所有 23 张表 CRUD 操作正常

### Edge Functions 模块
- [ ] `insforge.functions.invoke('notify', {body: {...}})` — 通知发送正常
- [ ] `insforge.functions.invoke('param-validate', {body: {...}})` — 参数验证正常
- [ ] `insforge.functions.invoke('blacklist', {body: {...}})` — 黑名单检查正常

### Python rpa-core-service
- [ ] 携带有效 InsForge JWT → `get_current_user` 返回正确 UserContext
- [ ] 携带无效/过期 token → 返回 401
- [ ] 携带无 token → 返回 401
- [ ] InsForge 不可用时 → 自动降级到本地 JWT 验证
- [ ] `require_role('admin')` — 角色检查正常

### 配置验证
- [ ] 前端不再配置 `VITE_POSTGREST_URL`
- [ ] `docker/docker-compose.yml` 中 PostgREST 端口不再对外暴露（仅 `expose` 给 Docker 网络）
- [ ] `VITE_INSFORGE_ANON_KEY` 环境变量已从 Dashboard Settings → API 获取并配置
- [ ] `INSFORGE_BASE_URL=http://insforge:7130` 环境变量已配置（Edge Functions 容器内）
- [ ] `docker/.env.example` 中已添加 `VITE_INSFORGE_URL` 和 `VITE_INSFORGE_ANON_KEY`
- [ ] `docker/.env.insforge` 中已添加 `INSFORGE_BASE_URL`

### 自托管验证
- [ ] `docker compose ps` 所有 4 个 InsForge 容器正常运行
- [ ] `curl http://localhost:7130/api/health` 返回 `{"status": "ok"}`
- [ ] Dashboard 可访问 `http://localhost:7130`，可用 ADMIN_EMAIL/ADMIN_PASSWORD 登录
- [ ] Dashboard Settings → API 页面可看到 ANON_KEY
- [ ] `rpa-core-service` 容器可通过 `http://insforge:7130` 访问 InsForge（Docker 网络内）
- [ ] Deno 容器可正常加载 Edge Functions（检查容器日志无 npm 模块加载错误）

---

## 风险与注意事项

### 风险 1: 调用方适配工作量
**影响**：所有使用 `crudApi` 和 `authApi` 的前端组件需要适配 `{data, error}` 解构模式。
**缓解**：
- 可以保留一层薄封装，在 `api-client.ts` 中将 `{data, error}` 转换为原有格式
- 渐进式迁移：先改 API 层，再逐步适配调用方

### 风险 2: SDK 版本兼容性
**影响**：`@insforge/sdk` 的 API 可能在未来版本中变化。
**缓解**：
- 锁定 SDK 版本：`pnpm add @insforge/sdk@latest` 后记录具体版本号
- 在 `package.json` 中使用精确版本而非 `^` 范围

### 风险 3: Python 远程验证延迟
**影响**：每次请求需要额外一次 HTTP 调用到 InsForge App。
**缓解**：
- 添加 token 验证结果缓存（Redis，TTL = token 剩余有效期）
- 保留本地 JWT 验证作为降级方案

### 风险 4: Edge Functions 冷启动
**影响**：使用 SDK 后 Edge Functions 启动时需要加载 `@insforge/sdk` 模块。
**缓解**：
- Deno 会缓存 npm 模块，首次加载后后续调用无延迟
- 冷启动时间预计增加 50-200ms

### 风险 5: 自托管 Docker 网络配置（自托管特有）
**影响**：容器间通过 Docker 网络通信，如果网络配置错误会导致服务间无法通信。
**缓解**：
- 确保所有 InsForge 相关容器在同一 Docker 网络中（`rpa-network` 或 `insforge-network`）
- 容器间使用容器名（如 `insforge`、`postgrest`）而非 `localhost` 通信
- 验证：`docker exec rpa-core-service curl http://insforge:7130/api/health`

### 风险 6: JWT_SECRET 不一致（自托管特有）
**影响**：InsForge、PostgREST、rpa-core-service 使用不同的 JWT_SECRET 会导致 token 验证失败。
**缓解**：
- 所有服务从同一个 `.env` 文件读取 `JWT_SECRET`
- 验证：使用 InsForge 签发的 token 调用 rpa-core-service，确认返回 200 而非 401

---

## 自托管与 Cloud 模式差异

本修复方案基于自托管模式设计，与 Cloud 模式存在以下关键差异，AI-IDE 执行修复时需注意：

| 维度 | Cloud 模式 | 自托管模式（本方案） |
|------|-----------|-------------------|
| **InsForge baseUrl** | `https://your-app.region.insforge.app` | `http://localhost:7130`（或服务器 IP） |
| **ANON_KEY 获取** | CLI `get-backend-metadata` 自动获取 | Dashboard Settings → API 手动复制 |
| **SDK 初始化** | `createClient({ baseUrl: 'https://...', anonKey: '...' })` | `createClient({ baseUrl: 'http://localhost:7130', anonKey: '...' })` |
| **Edge Functions 运行时** | 云端 Deno Subhosting，通过 MCP 部署 | 本地 Deno 容器（端口 7133），源码通过 volume 挂载 |
| **Edge Functions SDK 导入** | `npm:@insforge/sdk`（Deno 从 npm 拉取） | 同左，Deno 容器自动缓存 npm 模块 |
| **Python JWT 验证 URL** | `https://your-app.../api/auth/sessions/current` | `http://insforge:7130/api/auth/sessions/current`（Docker 网络） |
| **PostgREST 访问** | 不可直连 | 可直连 `localhost:5430`（但不推荐，应通过 SDK） |
| **数据库管理** | Dashboard SQL 编辑器 | Dashboard SQL 编辑器 + 直接 psql 连接 |
| **存储后端** | 云端 S3 兼容存储 | 本地卷存储（`storage-data`），也可配置外部 S3 |
| **MCP 配置** | Dashboard 一键复制 | 手动配置 `INSFORGE_BASE_URL` 和 `INSFORGE_ANON_KEY` |
| **升级方式** | 自动升级 | `docker compose pull && docker compose up -d` |

### 自托管特有的注意事项

1. **Docker 网络通信**：容器间通过 Docker 网络通信，使用容器名（如 `insforge`、`postgrest`）而非 `localhost`
2. **端口管理**：确保 7130（App）、7131（Auth）、7133（Deno）、5432（PostgreSQL）端口不冲突
3. **JWT_SECRET 一致性**：所有服务（InsForge、PostgREST、rpa-core-service）必须使用相同的 `JWT_SECRET`
4. **ANON_KEY 持久化**：`ANON_KEY` 在容器重建后不会变化（存储在数据库中），但建议记录备份
5. **函数热重载**：自托管模式下修改 Edge Functions 源码后，需重启 Deno 容器或等待热重载

---

## 总结

本修复方案将 AstronRPA 从「把 InsForge 当普通 PostgreSQL + REST API 用」升级为「使用 InsForge 官方 SDK 的完整 BaaS 集成」，核心变化：

| 维度 | 修复前 | 修复后 |
|------|--------|--------|
| 数据库访问 | axios 直连 PostgREST :5430 | SDK `database.from().select()` 通过 InsForge App (:7130) 代理 |
| 用户认证 | axios POST `/api/auth/sessions` | SDK `auth.signInWithPassword()` |
| Token 管理 | 手动 localStorage | SDK 自动管理 + httpOnly cookie |
| 错误处理 | try/catch + 手动判断 | 统一 `{data, error}` 模式 |
| Edge Functions | fetch 裸调 PostgREST | SDK `createClient({edgeFunctionToken})`（本地 Deno 容器） |
| Python 验证 | 本地 `jose.jwt.decode()` | 远程调用 InsForge `http://insforge:7130/api/auth/sessions/current` |
| PostgREST 端口 | 对外暴露 :5430 | 仅 Docker 网络内部使用，前端不可见 |
| 部署模式 | — | 自托管 Docker Compose，所有服务本地容器化 |

修复完成后，AstronRPA 将完全符合 InsForge 开发规范，充分发挥自托管 BaaS 平台的价值。