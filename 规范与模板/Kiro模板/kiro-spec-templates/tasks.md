# tasks.md（Kiro Spec 模式）

本文件用于把 `requirements.md` 与 `design.md` 落到“可执行的实现计划”。

任务拆分原则：
- 每个任务都应**可独立完成并可验收**
- 每个任务都写清：描述、产出（Expected outcome）、依赖、是否可选
- 建议在任务里标注可追溯的需求编号（例如 R1、R2…）

状态约定（供执行与跟踪）：
- Not Started / In Progress / Done（具体状态由执行工具更新）

---

## Phase 0: 项目约定与准备

### Task 0.1：确认接口契约与错误响应格式
- Description:
  - 定义统一的成功/失败响应结构、错误码与错误消息策略
  - 明确字段级校验错误的返回格式
- Expected outcome:
  - 文档化的响应格式（可写在 README 或 API 文档中）
  - 后端与前端/调用方对齐
- Dependencies:
  - None
- Optional:
  - No
- Traceability:
  - R3, R5, R12

### Task 0.2：确定会话与鉴权方案
- Description:
  - 明确使用 cookie session 还是 JWT
  - 明确 session 失效与退出策略
- Expected outcome:
  - 在配置/代码结构中确定鉴权中间件与会话存储方式
- Dependencies:
  - Task 0.1
- Optional:
  - No
- Traceability:
  - R4, R6, R7, R10

---

## Phase 1: 数据模型与迁移

### Task 1.1：实现用户实体与唯一性约束
- Description:
  - 建立 User 表/集合
  - 为 email 增加唯一约束与必要索引
- Expected outcome:
  - 数据库迁移完成
  - 能创建/查询用户
- Dependencies:
  - Task 0.2
- Optional:
  - No
- Traceability:
  - R1, R2

### Task 1.2：实现会话存储（如采用 server-side session）
- Description:
  - 建立 Session 表（或使用已有 session store）
  - 支持 revoke 与过期
- Expected outcome:
  - 登录成功后可创建 session
  - 退出后 session 被撤销
- Dependencies:
  - Task 0.2, Task 1.1
- Optional:
  - Yes（若使用 JWT）
- Traceability:
  - R4, R6, R10

### Task 1.3：实现密码重置 token 存储
- Description:
  - 建立 PasswordResetToken 表
  - token 仅存 hash，支持 expires/consumed 字段
- Expected outcome:
  - 能创建、查询、标记 consumed、判断过期
- Dependencies:
  - Task 1.1
- Optional:
  - No
- Traceability:
  - R8, R9

---

## Phase 2: 核心 API 与业务逻辑

### Task 2.1：注册接口（含输入校验）
- Description:
  - 实现 `POST /auth/register`
  - 校验 email 格式与必填字段
  - 处理邮箱冲突
- Expected outcome:
  - 有效输入可创建用户
  - 冲突与校验错误按约定返回
- Dependencies:
  - Task 1.1, Task 0.1
- Optional:
  - No
- Traceability:
  - R1, R2, R3

### Task 2.2：登录接口（含失败泛化与速率限制挂钩）
- Description:
  - 实现 `POST /auth/login`
  - 错误信息泛化，避免泄露账号是否存在
  - 预留/接入速率限制
- Expected outcome:
  - 正确凭证登录成功
  - 错误凭证返回统一错误
- Dependencies:
  - Task 2.1, Task 0.2
- Optional:
  - No
- Traceability:
  - R4, R5, R11

### Task 2.3：退出接口与受保护资源访问控制
- Description:
  - 实现 `POST /auth/logout`
  - 为受保护接口添加鉴权中间件
- Expected outcome:
  - 退出后 session/JWT 失效（按方案）
  - 未登录访问受保护资源被拒绝
- Dependencies:
  - Task 2.2, Task 0.2
- Optional:
  - No
- Traceability:
  - R6, R7

### Task 2.4：密码重置请求接口
- Description:
  - 实现 `POST /auth/password-reset/request`
  - 对外响应一致（不泄露邮箱是否存在）
  - 对内创建 token 并触发邮件发送
- Expected outcome:
  - 用户存在时生成 token 记录
  - 邮件发送被触发（可先 stub/mock）
- Dependencies:
  - Task 1.3, Task 0.1
- Optional:
  - No
- Traceability:
  - R8, R13

### Task 2.5：密码重置确认接口
- Description:
  - 实现 `POST /auth/password-reset/confirm`
  - 校验 token：存在、未过期、未 consumed
  - 更新密码并撤销旧 session
- Expected outcome:
  - token 过期/复用/不存在时被拒绝
  - 成功时密码更新，token 标记 consumed，旧 session 失效
- Dependencies:
  - Task 2.4, Task 1.2
- Optional:
  - No
- Traceability:
  - R9, R10

---

## Phase 3: 邮件与异步能力（可选增强）

### Task 3.1：实现邮件发送适配层
- Description:
  - 抽象 EmailSender 接口
  - 支持本地开发环境的 mock 发送
- Expected outcome:
  - 可替换不同邮件服务
  - 本地可验证发送行为
- Dependencies:
  - Task 2.4
- Optional:
  - Yes
- Traceability:
  - R8

### Task 3.2：失败重试与告警
- Description:
  - 为发送失败增加重试策略
  - 超过阈值触发告警
- Expected outcome:
  - 可观测的重试与失败记录
- Dependencies:
  - Task 3.1
- Optional:
  - Yes
- Traceability:
  - R12

---

## Phase 4: 测试与质量门禁

### Task 4.1：单元测试覆盖关键规则
- Description:
  - 覆盖校验逻辑、token 过期/复用、错误消息泛化
- Expected outcome:
  - 核心规则具备单元测试保护
- Dependencies:
  - Phase 2 完成
- Optional:
  - No
- Traceability:
  - R3, R5, R9, R10

### Task 4.2：集成测试覆盖端到端流程
- Description:
  - 注册→登录→访问受保护资源→退出
  - 密码重置 request→confirm→旧 session 失效
- Expected outcome:
  - 核心流程可回归验证
- Dependencies:
  - Task 4.1
- Optional:
  - No
- Traceability:
  - R1-R10

### Task 4.3：属性测试（可选）
- Description:
  - 为关键不变量增加属性级验证（如 token 不可复用）
- Expected outcome:
  - 随机化用例下不变量仍成立
- Dependencies:
  - Task 4.2
- Optional:
  - Yes
- Traceability:
  - R9, R10

---

## Phase 5: 文档与交付

### Task 5.1：验收回填与运行说明
- Description:
  - 补充运行方式、配置项、已知限制
  - 回填每条需求的验收结果（可在 PR 或 release note）
- Expected outcome:
  - 交付可复现、可验收
- Dependencies:
  - Phase 4 完成
- Optional:
  - No
- Traceability:
  - R1-R13
