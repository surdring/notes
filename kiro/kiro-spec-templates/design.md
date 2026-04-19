# design.md（Kiro Spec 模式）

本文件用于描述“怎么做”（How）：技术架构、组件职责、数据模型、交互流程、错误处理与测试策略。

写作原则：
- 先给总览，再给可落地的细节
- 让实现者可以依据本文直接拆任务（见 `tasks.md`）并开始编码
- 对关键决策给出理由（trade-offs）

---

## 1. Overview

### 1.1 Goals
- 将 `requirements.md` 中的需求逐条落到可实现方案
- 明确组件边界、数据流、接口契约

### 1.2 Non-goals
- 不在本文件中写具体代码实现细节（除非必要）

### 1.3 Assumptions
- 列出你默认成立的前提：已有的认证框架/数据库/消息系统/第三方服务等

---

## 2. Architecture

### 2.1 High-level components
（按你的项目实际情况替换）
- **Web/UI**：表单与交互、错误提示一致性
- **API/Backend**：鉴权、会话、业务规则、输入校验
- **Persistence**：用户表、会话表、token 表、审计日志
- **Email/Notification**：发送重置邮件、失败重试

### 2.2 Component responsibilities
- 明确每个组件“负责什么/不负责什么”
- 明确边界：哪些规则在 API 层，哪些在 domain/service 层

### 2.3 Interfaces
- API 端点（示例）：
  - `POST /auth/register`
  - `POST /auth/login`
  - `POST /auth/logout`
  - `POST /auth/password-reset/request`
  - `POST /auth/password-reset/confirm`
- 返回契约：成功/失败的响应结构、错误码/错误消息策略

---

## 3. Data model & storage

### 3.1 Entities（示例）
- **User**
  - `id`
  - `email`（唯一）
  - `password_hash`
  - `created_at`
  - `status`
- **Session**
  - `id`
  - `user_id`
  - `created_at`
  - `expires_at`
  - `revoked_at`
- **PasswordResetToken**
  - `id`
  - `user_id`
  - `token_hash`
  - `created_at`
  - `expires_at`
  - `consumed_at`

### 3.2 Indexes & constraints
- `User.email` 唯一索引
- token 表按 `user_id`、`expires_at` 索引以支持清理

### 3.3 Security considerations
- token 只存 hash，不存明文
- 密码使用强哈希（如 bcrypt/argon2，按你的技术栈）
- 会话固定攻击防护（登录后重建 session）

---

## 4. Flows (Sequence / Data flow)

> 这里用“步骤列表”表达序列图信息；如果你习惯画图，可在 Kiro 中配合图片，但本文件应包含纯文本可读流程。

### 4.1 Registration flow
1. Client 提交注册表单
2. API 校验字段格式与必填
3. 查询邮箱是否已存在
4. 创建用户记录（存 password_hash）
5. 返回成功响应（可选：创建会话并登录）

关键点：
- 冲突与校验错误要可区分（但不要泄露敏感信息）

### 4.2 Login flow
1. Client 提交邮箱与密码
2. API 校验输入格式
3. 查找用户
4. 验证密码哈希
5. 创建 session（或签发 JWT）
6. 返回成功响应

关键点：
- 失败响应必须“泛化”，避免用户名枚举
- 速率限制/锁定策略（按 `requirements.md`/NFRs）

### 4.3 Password reset flow
**Request**
1. Client 提交 email
2. API 返回一致的响应（不泄露 email 是否存在）
3. 若用户存在，生成一次性 token（存 hash + expiry）
4. 发送邮件（带 token 或链接）

**Confirm**
1. Client 提交 token + new password
2. 校验 token（存在、未过期、未使用）
3. 更新密码 hash
4. 标记 token 已使用
5. 使所有旧 session 失效

---

## 5. Error handling

### 5.1 Validation errors
- 字段级错误（如 email 格式）
- 业务级错误（如邮箱已存在）

### 5.2 Auth errors
- 凭证错误返回统一信息
- 未授权访问：UI 重定向或 API 返回 401/403

### 5.3 Resilience
- 邮件发送失败：
  - 重试策略（指数退避）
  - 死信/告警（如使用队列）

### 5.4 Observability
- 关键日志字段：request id、user id（如可用）、错误码
- 不记录：密码、token 明文、敏感 PII

---

## 6. Testing strategy

### 6.1 Unit tests
- 密码策略与校验
- token 校验逻辑（过期/复用/不存在）

### 6.2 Integration tests
- 注册/登录/退出端到端（API + DB）
- password reset request/confirm（含 token 生命周期）

### 6.3 E2E tests（如有 UI）
- 表单校验错误提示
- 受保护页面访问控制

### 6.4 Properties（可选，但与 EARS 很契合）
- token 一旦 consumed 永不可再次使用
- 过期 token 永不可使用
- 未登录永不可访问 protected resource

---

## 7. Open questions
- 会话策略：cookie session 还是 JWT？刷新机制？
- 密码策略：最小长度/复杂度/黑名单？
- 速率限制：按 IP、按账号、还是组合？
- 邮件服务：同步发送还是异步队列？
