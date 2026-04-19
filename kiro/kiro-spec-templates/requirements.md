# requirements.md（Kiro Spec 模式）

本文件用于描述“要做什么”（What），以结构化、可测试、可追踪的方式表达需求。

核心原则：
- 每条需求必须可测试（能被验证为满足/不满足）
- 每条需求必须可观察（有明确的系统外部行为或可验证输出）
- 覆盖正常路径、异常路径、边界条件
- 需求应尽量使用一致的语法：EARS（Easy Approach to Requirements Syntax）

---

## 1. 术语与约定

### 1.1 EARS 句式
在本文件中，功能性需求以如下句式表达：

WHEN <条件/事件> THE SYSTEM SHALL <期望行为>

写作要求：
- **WHEN** 后面只写触发条件或事件（用户动作、系统事件、外部回调、定时触发等）
- **THE SYSTEM SHALL** 后面只写系统必须做到的可验证行为（返回、展示、记录、拒绝、触发工作流等）
- 一句话只表达一个主要行为，避免“并且/以及”串联多个动作；如必须表达多个动作，拆成多条需求

### 1.2 需求分组
- 用一级/二级标题按功能域（Feature Area / Epic）分组
- 用三级标题按用户故事/场景（User Story / Scenario）分组

### 1.3 可追踪性（推荐）
为便于在 `tasks.md` 里引用，建议给需求编号：
- 格式：`R1`、`R2`、…（或 `AUTH-R1` 等带前缀）
- 编号应稳定：新增需求使用新编号，避免重排导致引用失效

---

## 2. 背景与目标

### 2.1 背景
（在这里用 3-8 行说明业务背景、问题、现状与痛点）

### 2.2 目标（Goals）
- （例如）实现端到端的注册/登录/退出流程
- （例如）提升输入校验与错误提示的一致性

### 2.3 非目标（Non-goals）
- （例如）不在本次范围内引入 SSO
- （例如）不重构既有用户中心的存量数据模型

---

## 3. 用户与权限模型

### 3.1 用户角色
- 匿名用户（未登录）
- 已登录用户
- 管理员（如适用）

### 3.2 权限边界
- 说明哪些操作必须登录、哪些可匿名
- 说明敏感操作的二次验证策略（如适用）

---

## 4. 功能性需求（EARS）

> 下面提供一个“写法完整”的示例结构。你可以直接替换标题与内容，保持句式即可。

### R1：账号注册
WHEN a visitor submits a registration form with valid required fields THE SYSTEM SHALL create a new user account and persist it

### R2：注册邮箱唯一性
WHEN a visitor submits a registration form with an email that already exists THE SYSTEM SHALL reject the request and present an "Email already registered" message

### R3：注册字段校验
WHEN a visitor submits a registration form with an invalid email format THE SYSTEM SHALL present a field-level validation error for email

### R4：登录
WHEN a user submits valid credentials THE SYSTEM SHALL create an authenticated session for the user

### R5：登录失败
WHEN a user submits invalid credentials THE SYSTEM SHALL deny authentication and present a generic error message without revealing which field is incorrect

### R6：退出
WHEN an authenticated user initiates logout THE SYSTEM SHALL invalidate the user session and require re-authentication for protected actions

### R7：访问控制（受保护资源）
WHEN an unauthenticated user attempts to access a protected resource THE SYSTEM SHALL redirect the user to the login screen (or return 401 for APIs)

### R8：密码重置请求
WHEN a visitor requests password reset for an existing account email THE SYSTEM SHALL generate a one-time reset token and send a reset link to that email

### R9：密码重置令牌安全性
WHEN a reset token is used after expiration or after it has already been consumed THE SYSTEM SHALL reject the reset attempt

### R10：密码更新
WHEN a visitor submits a valid new password with a valid reset token THE SYSTEM SHALL update the password and invalidate all existing sessions for that user

---

## 5. 错误处理与边界条件（EARS）

### R11：速率限制（示例）
WHEN a client exceeds the allowed authentication request rate THE SYSTEM SHALL throttle requests and return a rate-limit response

### R12：系统异常提示
WHEN an unexpected server error occurs during a user-facing operation THE SYSTEM SHALL present a generic error message and log a correlated error identifier

### R13：幂等性（示例）
WHEN the same password reset request is submitted multiple times within a short interval THE SYSTEM SHALL avoid leaking account existence and respond consistently

---

## 6. 数据与合规性要求（如适用）

### 6.1 数据保留
- 说明日志、审计记录、token 记录的保留时长

### 6.2 隐私与合规
- 说明敏感字段（密码、token、PII）不得以明文写入日志

---

## 7. 非功能性需求（NFRs）

> 这里不强制使用 EARS，但建议同样写成可验证条目。

- 性能：关键接口在正常负载下的响应时间目标
- 可用性：错误恢复策略、降级策略
- 可观测性：日志、指标、追踪的最低要求
- 安全性：密码策略、会话策略、CSRF/XSS 防护要求

---

## 8. 验收清单（可选）

- 每条需求均可映射到至少一个测试用例
- 正常路径、异常路径与边界条件均被覆盖
- `tasks.md` 中每个任务都能追溯到一个或多个需求编号（如 R1、R2…）
