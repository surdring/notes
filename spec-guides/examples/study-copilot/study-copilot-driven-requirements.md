# 需求文档（Study Copilot 驱动重排版）

## 简介

**Niche** 是一个基于 **Vercel AI SDK Core** 构建的智能体代理（Agent Proxy），用于编排与管理多个子代理。它拒绝过度抽象，利用 **TypeScript** 强类型特性和 **Fastify** 的高性能 I/O，实现对大模型交互的精确控制。

核心设计理念：**统一的 Provider 接口 + Zod 严格结构化输出 + 标准化流式传输协议**。

Niche 以“代理管理 + 工作流编排”为中心，提供从 RAG 管道、多模型路由、Agent 工作流、评估体系、数据处理、安全护栏到 LLMOps 运维的能力，让用户以可控、可追溯的方式完成学习、研究与个人效率任务。

Niche 不限定于单一垂直场景，而是通过“场景模板（Scenario Template）”机制，让用户在开始前选择或提供模板，以快速获得可用的提示词、子代理与工具集、结构化输出与工作流编排。

## 范围与关键决策（当前迭代）

- **RAG（检索）**：集成 RAGFlow 作为外部知识库服务，仅负责“文档摄入/检索/引用溯源”；回答生成仍由系统通过 Vercel AI SDK 调用模型完成。
- **多租户/配额**：当前迭代不实现多租户与配额管理能力（见需求 21 延后）。
- **场景模板**：用户在开始前可选择或提供模板（提示词/工具集/输出 Schema/工作流策略）；模板以结构化形式存储与校验。
- **API 主干**：GraphQL 作为主要业务接口；REST/流式接口用于上传、事件流与高吞吐场景。
- **目标用户**：当前主要面向个人与家庭（个人效率/学习/研究）。
- **产品形态**：必须提供人机交互且体验良好的 UI。
- **非目标（当前迭代）**：不做多租户 SaaS；不做向量库/检索内核（交由 RAGFlow）；不做模型训练/微调（只做推理与流程）。

## 产品定位与设计原则（基于竞品分析）

- **定位与价值观**
  - Niche 优先服务 **研究/知识工作、Explain & Verify 学习任务**，而非“代做作业/刷题作弊”型应用。
  - 在学习/学生场景中，系统应鼓励理解与推理（解释、提示、批改与纠错），而非单纯输出最终答案。
- **场景模板与垂直 App Studio 内核**
  - Niche 通过 **Scenario Template（场景模板）** 承载垂直能力，将 Provider 接口、Agent 编排、RAG、Guardrails、Eval 等基础设施封装为“可一键孵化垂直 AI 应用”的内核。
  - 官方将提供一组示例模板（如 Research Copilot、Study Copilot 等），但核心代码须保持对模板无侵入、插件化扩展。
- **旗舰模板：Research Copilot**
  - 当前迭代优先将 “研究协作（Research Copilot）” 作为旗舰场景模板；其他模板可在其架构之上扩展。
- **学习/作业场景的合规与学术诚信原则**
  - 对涉及作业/考试的场景，模板与 Guardrails **不得默认以“直接给出最终答案”作为主要交付方式**，而应优先采用解释、提示、步骤批改等模式。
  - Guardrails 与 `wrapLanguageModel` 中间件在此类模板中 **必须显式约束**：禁止伪造引用、禁止绕过 Honor Code，并在需要时提供合规提示。
- **能力分级与未来商业化预留（当前不实现多租户）**
  - API/Schema 设计应允许对成本敏感能力进行“能力分级/开关控制”。
  - 本迭代仍不实现多租户与配额，仅在数据模型与上下文中预埋 `tenantId` 与 Project 维度。

## 技术栈

- **语言**：TypeScript
- **运行时**：Node.js
- **核心 SDK**：Vercel AI SDK Core
- **API 框架**：Fastify
- **GraphQL（主干）**：GraphQL Schema + Fastify GraphQL（如 Mercurius）
- **外部检索服务**：RAGFlow（HTTP API）
- **本地推理服务（可选）**：llama.cpp server（如 GPT-OSS-20B 等）
- **业务数据库（可选）**：PostgreSQL
- **缓存**：Redis
- **监控**：OpenTelemetry + Prometheus
- **Schema 验证**：Zod

## 术语表

- **RAG**：检索增强生成
- **Model Router**：模型路由器
- **Agent Proxy**：管理与编排多个子代理的入口代理
- **Scenario Template**：面向特定场景的可复用配置包（提示词/工具集/Schema/策略）
- **Guardrails**：安全护栏
- **LLMOps**：大语言模型运维

---

## 需求（按 Study Copilot 落地路径重排，需求编号保持不变）

> 说明：以下内容仅改变排序与分组，不改变每条需求的语义与编号。便于你从 Study Copilot（学习场景）出发，优先实现“模板可运行、可控、可观测、可交互”的主干能力。

### A. 模板与运行时契约（Template-first）

#### 需求 39

**用户故事：** 作为用户，我希望在开始一个新任务/项目之前能够选择或提供“场景模板”，以便快速获得符合目标的提示词、工具集、结构化输出与工作流策略。

**验收标准**

1. WHEN 用户创建任务/项目 THEN 系统 SHALL 支持指定 `templateId` 或直接提交 `templateDefinition`（二选一）作为启动参数
2. WHEN 使用模板启动 THEN 系统 SHALL 将模板解析为运行时配置（System Prompt、tools、结构化输出 schema、工作流/重试策略、引用/安全策略等）并注入到编排层
3. WHEN 用户提供模板定义 THEN 系统 SHALL 对模板进行结构化校验（例如使用 Zod Schema），校验失败 MUST 返回结构化错误并指出违规字段
4. WHEN 未指定模板 THEN 系统 SHALL 使用默认模板启动（例如通用对话、研究、学习等），且默认模板 MUST 可配置
5. WHEN 模板包含工具声明 THEN 系统 SHALL 校验工具参数与返回结构是否可被系统支持（例如工具必须有 Zod 参数定义），不支持的工具 MUST 被拒绝并返回原因
6. WHEN 模板包含输出结构 THEN 系统 SHALL 复用需求 22 的结构化输出机制，保证输出严格符合模板所声明的 Schema
7. WHEN 模板需要复用/迁移 THEN 系统 SHOULD 支持模板的导入/导出（JSON/YAML 等）与版本化，且每次运行记录所使用的模板版本以便复现
8. WHEN 模板面向本地开源模型（例如 GPT-OSS-20B） THEN 模板 SHOULD 支持声明并注入防御性提示词约束，以提高指令遵循与结构化输出稳定性

#### 需求 23

**用户故事：** 作为用户，我希望在不修改核心编排代码的情况下，统一注入 Prompt 前缀或修改模型参数。

**验收标准**

1. WHEN 核心函数被调用前 THEN 系统 SHALL 支持 `wrapLanguageModel` 中间件模式，用于统一添加 System Prompt 或安全护栏
2. WHEN 需要模拟测试 THEN 系统 SHALL 支持注入 `MockLanguageModel`，在不消耗 Token 的情况下进行单元测试
3. WHEN 中间件链执行 THEN 系统 SHALL 按注册顺序依次执行，支持短路返回
4. WHEN 中间件需要访问上下文 THEN 系统 SHALL 提供请求级别的上下文对象（包含用户信息、请求 ID 等）
5. WHEN 中间件发生错误 THEN 系统 SHALL 捕获错误并执行配置的错误处理策略
6. WHEN 需要条件性中间件 THEN 系统 SHALL 支持基于请求特征动态启用/禁用特定中间件

---

### B. UI 与交互体验（UI-first）

#### 需求 40

**用户故事：** 作为用户，我希望 Niche 提供人机交互且体验良好的 UI，以便我能选择模板、管理任务/项目、查看中间步骤与引用，并导出成果。

**验收标准**

1. WHEN 用户进入系统 THEN UI SHALL 提供模板选择与启动入口，并支持展示模板的说明、适用场景与所启用的工具/子代理概览
2. WHEN 用户启动任务/项目 THEN UI SHALL 支持输入必要参数，并能展示运行中状态与可取消操作
3. WHEN Agent Proxy 运行多步工作流 THEN UI SHALL 以流式方式呈现中间步骤并区分阶段
4. WHEN 输出包含引用信息 THEN UI SHALL 支持点击引用查看原文定位信息或等价证据展示
5. WHEN 用户需要沉淀结果 THEN UI SHALL 支持导出为 Markdown/Obsidian 友好格式，并保留引用元数据
6. WHEN 用户浏览核心界面 THEN UI SHALL 保持统一的视觉语言且交互模式一致
7. WHEN 系统提供主题能力 THEN UI SHOULD 支持明暗主题切换
8. WHEN 用户在 UI 中阅读长内容 THEN UI SHALL 提供适合阅读的排版并支持折叠/展开
9. WHEN 任务处于运行中 THEN UI SHALL 明确展示阶段、步骤与可取消入口，失败时提供可读错误与重试入口
10. WHEN UI 渲染中间步骤事件流 THEN UI SHALL 支持按步骤筛选/搜索并支持复制单步内容
11. WHEN 用户点击引用 THEN UI SHALL 以侧栏/弹层展示证据（来源标识、定位信息、可复制原文摘录）
12. WHEN 引用证据不可用或发生降级 THEN UI SHALL 显式标注降级原因并提示恢复方式
13. WHEN 用户导出成果 THEN UI SHALL 提供导出预览与导出选项，并在完成后提供可复制路径/链接
14. WHEN 用户使用键盘导航 THEN UI SHOULD 支持不依赖鼠标完成核心流程且焦点状态清晰
15. WHEN UI 展示状态反馈 THEN UI SHALL 使用一致的状态样式与文案，避免阻塞式全屏等待
16. WHEN 页面在常见窗口尺寸下使用 THEN UI SHALL 保证布局不溢出且主要操作无需水平滚动
17. WHEN 前端首屏加载 THEN UI SHOULD 在可接受时间内完成可交互渲染，并在慢网下优先呈现骨架屏

---

### C. 流式输出与中间步骤事件（Streaming-first）

#### 需求 9

**用户故事：** 作为用户，我希望拥有标准化流式响应支持，以便通过渐进式输出获得更好的体验。

**验收标准**

1. WHEN 建立流式连接 THEN 系统 SHALL 输出符合 **Vercel AI Data Stream Protocol** 标准的格式
2. WHEN 集成 Fastify THEN 系统 SHALL 将 SDK 的 `toDataStreamResponse()` 直接 pipe 到 HTTP 响应中
3. WHEN 流式传输响应 THEN 系统 SHALL 追踪首 Token 延迟（TTFT）
4. WHEN 流式传输中遇到错误 THEN 系统 SHALL 发送特定格式的错误块
5. WHEN 客户端在流式传输中断开 THEN 系统 SHALL 取消底层模型请求
6. WHEN 需要前端渲染 THEN 流式响应 SHALL 包含结构化标记以区分阶段
7. WHEN 流式输出完成 THEN 系统 SHALL 提供完整响应的回调钩子

#### 需求 36

**用户故事：** 作为研究者，我希望以流式方式展示 Agent 的中间步骤，以便在 Agentic 任务耗时较长时仍能获得可解释反馈与可控体验。

**验收标准**

1. WHEN Agent 执行多步任务 THEN 系统 SHALL 以事件流形式输出每一步的状态
2. WHEN 工具被调用 THEN 系统 SHALL 输出工具名称与参数摘要（脱敏后）并在返回时输出结果摘要
3. WHEN 用户取消请求 THEN 系统 SHALL 中止后续步骤并返回可恢复状态

---

### D. 结构化输出（Schema-first）

#### 需求 22

**用户故事：** 作为用户，我希望基于 Zod 强制模型输出符合预定义的结构化格式，以便输出可靠地进入后续工作流。

**验收标准**

1. WHEN 场景需要 JSON 输出 THEN 系统 SHALL 使用 `streamObject` 或 `generateObject`
2. WHEN 定义输出结构 THEN 模板作者 SHALL 必须提供 **Zod Schema**
3. WHEN 模型处于流式生成过程中 THEN 系统 SHALL 支持 Partial JSON Parsing（增量解析）
4. WHEN 模型生成的数据类型不匹配 THEN 系统 SHALL 抛出类型验证错误
5. WHEN 输出格式不符合 Schema THEN 系统 SHALL 自动触发修复重试（Self-correction）
6. WHEN 修复重试失败 THEN 系统 SHALL 返回结构化错误信息说明违规字段
7. WHEN 配置重试策略 THEN 系统 SHALL 支持设置最大重试次数和回退模型

---

### E. Guardrails（学习/作业合规优先）

#### 需求 6

**用户故事：** 作为用户，我希望拥有内置的安全护栏，以便保护我与家人的使用过程免受提示注入和不当输出的影响。

**验收标准**

1. WHEN 收到用户输入 THEN 护栏 SHALL 扫描提示注入模式并阻止恶意请求
2. WHEN 模型生成输出 THEN 护栏 SHALL 基于可配置规则过滤内容
3. WHEN 请求被阻止 THEN 护栏 SHALL 返回安全的降级响应并说明限制原因
4. WHEN 护栏事件发生 THEN 护栏 SHALL 记录事件以供安全审查
5. WHEN 配置内容策略 THEN 护栏 SHALL 支持自定义禁止话题和敏感词列表
6. WHEN 检测到越狱尝试 THEN 护栏 SHALL 立即终止请求并记录告警
7. WHEN 输出包含幻觉风险 THEN 护栏 SHALL 标记低置信度内容并建议人工复核

---

### F. 多模态输入与学习场景可用性（拍题/OCR/语音）

#### 需求 12

**用户故事：** 作为用户，我希望拥有多模态支持，以便处理图片、音频等非文本资料。

**验收标准**

1. WHEN 输入包含图片 THEN 系统 SHALL 支持视觉模型处理图片内容
2. WHEN 输入包含音频 THEN 系统 SHALL 支持语音转文字处理
3. WHEN 需要图片生成 THEN 系统 SHALL 集成图像生成模型 API
4. WHEN 处理多模态文档 THEN 系统 SHALL 提取并关联文本和图片内容
5. WHEN 配置多模态模型 THEN 系统 SHALL 支持 GPT-4V、Claude Vision 等视觉模型

---

### G. 会话与持久化（学习记录/复盘基础）

#### 需求 13

**用户故事：** 作为用户，我希望拥有会话管理能力，以便维护多轮对话的上下文和状态。

**验收标准**

1. WHEN 用户开始对话 THEN 会话管理器 SHALL 创建唯一会话 ID 并初始化上下文
2. WHEN 对话继续 THEN 会话管理器 SHALL 维护对话历史并提供给模型
3. WHEN 对话历史过长 THEN 会话管理器 SHALL 执行上下文压缩或摘要
4. WHEN 会话超时 THEN 会话管理器 SHALL 自动清理并释放资源
5. WHEN 需要持久化会话 THEN 会话管理器 SHALL 支持将会话存储到数据库
6. WHEN 用户恢复会话 THEN 会话管理器 SHALL 加载历史上下文继续对话

---

### H. API 服务层（模板运行入口）

#### 需求 16

**用户故事：** 作为用户，我希望系统提供 API 服务层，以便在需要时将能力暴露为 RESTful 或 GraphQL 接口。

**验收标准**

1. WHEN 用户访问系统 API THEN 系统 SHALL 提供 GraphQL Endpoint 作为主要业务接口
2. WHEN 系统暴露 REST 能力 THEN 系统 SHALL 提供用于流式响应与大文件上传的 REST 端点
3. WHEN API 被调用 THEN 系统 SHALL 执行认证、限流和日志记录
4. WHEN 需要 API 文档 THEN 系统 SHALL 为 REST 使用 Zod + Swagger 生成 OpenAPI，并为 GraphQL 提供可探索 Schema
5. WHEN GraphQL Resolver 编排 RAGFlow 与数据库 THEN 系统 SHALL 默认注入并强制校验 `tenantId`/`projectId`
6. WHEN 发生写操作 THEN 系统 SHALL 在 PostgreSQL 中记录可复现的审计信息
7. WHEN 需要实时进度与事件 THEN 系统 SHOULD 支持 GraphQL Subscriptions 或等价事件通道
8. WHEN API 版本迭代 THEN 系统 SHALL 支持多版本 API 共存

---

### I. 可观测性、成本与可靠性（学习场景长期开销可控）

#### 需求 8

**用户故事：** 作为用户，我希望系统提供可观测性与监控能力，以便追踪系统健康、调试问题和优化性能。

**验收标准**

1. WHEN 模型调用结束 THEN 系统 SHALL 触发 SDK 的 `onFinish` 回调
2. WHEN 捕获 Token 用量 THEN 系统 SHALL 从 `usage` 读取 token 用量并写入 OpenTelemetry
3. WHEN 记录完整链路 THEN 系统 SHALL 将 SDK telemetry 与 Fastify Request ID 关联
4. WHEN 请求被处理 THEN 系统 SHALL 追踪完整生命周期（输入、检索、提示词、输出）
5. WHEN 收集指标 THEN 系统 SHALL 追踪延迟、Token 用量、错误率、缓存命中率
6. WHEN 检测到异常 THEN 系统 SHALL 触发告警
7. WHEN 开发者查询日志 THEN 系统 SHALL 支持按 requestId、时间戳与标签过滤
8. WHEN 需要成本分析 THEN 系统 SHALL 提供按模型、用户、功能维度的成本报表
9. WHEN 集成外部系统 THEN 系统 SHALL 支持导出到 Prometheus、Grafana、LangSmith 等

#### 需求 14

**用户故事：** 作为用户，我希望系统具备降级策略，以便在故障时仍保持可用性。

**验收标准**

1. WHEN 主模型提供商故障 THEN 系统 SHALL 自动切换到备用提供商
2. WHEN 模型响应超时 THEN 系统 SHALL 返回友好的降级消息
3. WHEN 检测到服务过载 THEN 系统 SHALL 启用限流保护
4. WHEN 配置限流规则 THEN 系统 SHALL 支持按用户、IP、API Key 限流
5. WHEN 服务恢复正常 THEN 系统 SHALL 自动切回主服务并记录事件
6. WHEN 需要熔断保护 THEN 系统 SHALL 在连续失败后暂停对故障服务的调用

#### 需求 7

**用户故事：** 作为用户，我希望拥有响应缓存能力，以便降低重复任务的成本和延迟。

**验收标准**

1. WHEN 查询匹配缓存响应 THEN 缓存系统 SHALL 返回缓存结果而不调用模型
2. WHEN 生成新响应 THEN 缓存系统 SHALL 以可配置 TTL 存储响应
3. WHEN 缓存存储超限 THEN 缓存系统 SHALL 使用 LRU 策略淘汰
4. WHEN 启用语义相似缓存 THEN 缓存系统 SHALL 通过嵌入相似度匹配
5. WHEN 配置缓存后端 THEN 缓存系统 SHALL 支持 Redis、内存、磁盘等
6. WHEN 缓存命中 THEN 缓存系统 SHALL 在响应中标记缓存来源
7. WHEN 需要缓存失效 THEN 缓存系统 SHALL 支持按标签或模式批量清除

---

### J. 多模型路由与 Provider（成本/能力平衡）

#### 需求 2

**用户故事：** 作为用户，我希望拥有基于统一 Provider 接口的多模型路由系统，以便根据任务复杂度优化成本和性能。

**验收标准**

1. WHEN 用户切换模型提供商 THEN 代码逻辑无需修改，系统 SHALL 使用统一 `LanguageModel` 接口适配
2. WHEN 收到查询请求 THEN 模型路由器 SHALL 评估查询复杂度
3. WHEN 检测到简单查询 THEN 路由到经济型模型
4. WHEN 检测到复杂查询 THEN 路由到高能力模型
5. WHEN 需要自定义模型参数 THEN 支持通过 `providerOptions` 传递厂商参数
6. WHEN 模型提供商故障 THEN 自动故障转移到备用提供商
7. WHEN 路由逻辑执行 THEN 使用 `generateText/streamText` 统一调用
8. WHEN 模型调用发生 THEN 记录成本和延迟指标

---

### K. 工作流引擎与插件化（可扩展性）

#### 需求 3

**用户故事：** 作为用户，我希望 Niche 能提供可编排的多代理工作流引擎，以便完成具备规划、工具调用和自我反思的任务。

**验收标准**

1. WHEN 定义工具 THEN 模板作者 SHALL 使用 Zod Schema 定义工具参数，并注册到 SDK `tools`
2. WHEN 模型决定调用工具 THEN 系统 SHALL 自动解析参数并验证；失败反馈错误给模型自我修正
3. WHEN 执行多步推理 THEN 系统 SHALL 使用 `maxSteps` 控制最大迭代次数
4. WHEN 管理对话历史 THEN 系统 SHALL 遵守 `CoreMessage` 类型标准
5. WHEN Agent 执行多步骤任务 THEN 引擎 SHALL 维护执行状态和上下文记忆
6. WHEN Agent 遇到错误 THEN 引擎 SHALL 支持重试和回退策略
7. WHEN 需要多 Agent 协作 THEN 系统 SHALL 支持消息传递和任务委托

#### 需求 15

**用户故事：** 作为用户，我希望系统提供插件化架构，以便扩展自定义功能而不修改核心代码。

**验收标准**

1. WHEN 用户创建插件 THEN 系统 SHALL 提供标准化插件接口和生命周期钩子
2. WHEN 插件被注册 THEN 系统 SHALL 在适当生命周期阶段调用插件
3. WHEN 插件需要配置 THEN 系统 SHALL 支持插件级配置管理
4. WHEN 插件发生错误 THEN 系统 SHALL 隔离错误不影响核心功能
5. WHEN 需要禁用插件 THEN 系统 SHALL 支持运行时启用/禁用插件
6. WHEN 用户分享插件 THEN 系统 SHALL 支持插件打包与分发

---

### L. 配置与 CLI（开发/运维效率）

#### 需求 17

**用户故事：** 作为用户，我希望系统提供配置管理系统，以便集中管理和动态更新配置。

**验收标准**

1. WHEN 框架启动 THEN 从环境变量、配置文件和远程配置中心加载配置
2. WHEN 配置包含敏感信息 THEN 支持加密存储和安全访问
3. WHEN 配置被修改 THEN 支持热更新无需重启
4. WHEN 配置缺失必填项 THEN 启动时报错并提供明确提示
5. WHEN 需要环境隔离 THEN 支持开发/测试/生产配置分离
6. WHEN 配置变更 THEN 记录变更历史以便审计

#### 需求 18

**用户故事：** 作为用户，我希望系统提供完整的 CLI 工具，以便通过命令行管理和调试。

**验收标准**

1. WHEN 用户初始化项目 THEN CLI 提供脚手架命令生成项目结构
2. WHEN 用户运行评估 THEN CLI 提供命令执行评估并输出报告
3. WHEN 用户调试提示词 THEN CLI 提供交互式提示词测试环境
4. WHEN 用户管理数据 THEN CLI 提供数据导入/导出/清理命令
5. WHEN 用户部署服务 THEN CLI 提供健康检查与状态查询命令
6. WHEN CLI 执行命令 THEN 提供详细进度和错误信息

---

### M. 数据处理与 RAG（后续可接入学习资料/题库）

#### 需求 5

**用户故事：** 作为用户，我希望拥有完整的数据处理管道，以便清洗、转换和准备可用于检索/引用的资料。

**验收标准**

1. WHEN 原始文档被摄入 THEN 清洗内容（移除 HTML、修复编码、规范化空白）
2. WHEN 文档包含 PII THEN 检测并替换敏感信息为占位符
3. WHEN 文档被处理 THEN 输出适合向量数据库摄入的结构化记录
4. WHEN 处理某文档失败 THEN 记录错误并继续处理剩余文档
5. WHEN 处理 PDF THEN 正确处理表格、页眉页脚和多栏布局
6. WHEN 需要 OCR THEN 支持图片和扫描 PDF 的文字识别
7. WHEN 数据需要增强 THEN 支持元数据提取和自动标签生成

#### 需求 1

**用户故事：** 作为用户，我希望快速搭建 RAG 管道，以便将资料接入知识库并完成知识增强任务。

**验收标准**

1. WHEN 用户初始化 Niche THEN 创建包含文档加载器、清洗/脱敏与外部检索适配器的可配置 RAG 管道（摄入/检索由 RAGFlow 完成）
2. WHEN 用户提供文档 THEN 支持多种文件格式
3. WHEN 需要分块/索引策略 THEN 支持通过 RAGFlow 配置完成
4. WHEN 系统检索上下文 THEN 通过 RAGFlow 返回 chunks + citations
5. WHEN 用户选择外部知识库服务 THEN 支持 HTTP 适配器并映射为统一结构
6. WHEN 未来需要内部向量库 THEN MAY 提供标准化接口（后续）
7. WHEN 检索结果需要重排序 THEN 提供可配置 reranker

---

### N. 引用溯源与证据链（学习场景未来可选，但框架需统一支持）

#### 需求 19

**用户故事：** 作为用户，我希望系统响应包含精确的引用溯源信息，以便实现“点击引用高亮原文”的交互体验。

**验收标准**

1. WHEN RAG 检索返回结果 THEN 响应包含引用坐标或等价定位信息
2. WHEN 模型生成包含引用的回答 THEN 将引用标记与源文档坐标关联
3. WHEN 前端请求原文高亮 THEN 提供 API 返回指定引用的原文内容
4. WHEN 用户划词选中文本 THEN 提供预处理接口支持对选中文本执行 AI 技能
5. WHEN 引用来源不可用 THEN 响应标记引用状态为“不可验证”

---

### O. 反馈、提示词、评估与合成数据（持续迭代）

#### 需求 10

**用户故事：** 作为用户，我希望系统支持反馈收集机制，以便标注好/坏结果并持续改进模板与工作流。

**验收标准**

1. WHEN 响应被传递 THEN 提供捕获用户评分钩子
2. WHEN 收集反馈 THEN 与查询、上下文、响应一起存储
3. WHEN 正面反馈 THEN 标记为 Few-shot 候选
4. WHEN 负面反馈 THEN 标记为待审查与优化
5. WHEN 分析反馈 THEN 提供趋势和问题分类报表
6. WHEN 反馈数据积累 THEN 支持导出用于微调的数据集

#### 需求 11

**用户故事：** 作为用户，我希望拥有提示词管理系统，以便版本化、测试和优化提示词模板。

**验收标准**

1. WHEN 创建提示词 THEN 支持模板变量与条件逻辑
2. WHEN 提示词修改 THEN 自动版本化并保留历史
3. WHEN 需要 A/B 测试 THEN 支持多版本流量分配
4. WHEN 提示词包含 Few-shot THEN 支持动态示例选择
5. WHEN 需要提示词优化 THEN 集成评估框架自动对比
6. WHEN 部署提示词 THEN 支持热更新无需重启

#### 需求 4

**用户故事：** 作为用户，我希望拥有完整的评估框架，以便系统化衡量和追踪输出质量。

**验收标准**

1. WHEN 创建评估数据集 THEN 支持结构化测试用例（输入、上下文、期望输出、标签）
2. WHEN 运行评估 THEN 测量准确性、完整性、格式合规性、安全性
3. WHEN 评估完成 THEN 生成与基线对比报告
4. WHEN 修改提示词 THEN 支持修改前后对比检测回归
5. WHEN 自动评估 THEN 支持 LLM-as-a-Judge
6. WHEN 导出结果 THEN 支持 JSON/CSV/HTML
7. WHEN 持续评估 THEN 支持集成到 CI/CD

#### 需求 20

**用户故事：** 作为用户，我希望系统能自动生成合成数据，以便在冷启动阶段快速构建评估集和训练数据。

**验收标准**

1. WHEN 用户提供原始文档 THEN 使用强模型生成 QA Pairs
2. WHEN 生成 QA THEN 支持配置问题类型
3. WHEN 生成完成 THEN 输出符合评估框架格式的数据集
4. WHEN 需要数据增强 THEN 支持生成变体
5. WHEN 需要质量控制 THEN 支持人工审核与标注流程
6. WHEN 导出训练数据 THEN 支持 JSONL

---

### P. 预埋隔离与后续平台化（当前迭代不实现配额，但要留接口）

#### 需求 29

**用户故事：** 作为平台维护者，我希望系统在第一天就预埋多租户隔离（tenantId）。

**验收标准**

1. WHEN 持久化任何业务数据 THEN 记录包含 `tenantId`
2. WHEN 执行任何读写查询 THEN 默认包含 `tenantId` 过滤
3. WHEN 认证成功 THEN 从认证上下文解析 `tenantId` 并贯穿请求级上下文对象
4. WHEN 隔离规则被违反 THEN 返回授权错误并记录安全事件

#### 需求 21（后续/暂不实现）

**用户故事：** 作为平台维护者，我希望系统支持多租户和配额管理。

**验收标准**

1. WHEN 创建租户 THEN 分配独立资源隔离空间
2. WHEN 配置租户配额 THEN 支持 Token 预算上限
3. WHEN 用量接近上限 THEN 发送预警
4. WHEN 超出配额 THEN 按策略限流或阻断
5. WHEN 管理 API Key THEN 支持按 Key 设置调用次数配额
6. WHEN 需要计费报表 THEN 提供按租户/时间段统计
7. WHEN 配置订阅计划 THEN 支持不同等级功能与配额

---

## 场景模板：研究协作（Research Copilot）扩展需求（不阻塞 Study Copilot MVP）

> 说明：以下需求在研究场景中优先，但作为平台能力，仍建议以“可被模板声明启用”的方式实现。

#### 需求 24

**用户故事：** 作为研究者，我希望系统能对 PDF 文档进行结构化解析并支持页码级引用溯源。

**验收标准**

1. WHEN 上传 PDF THEN 保留页码信息并生成可定位引用信息
2. WHEN PDF 有目录/章节 THEN SHOULD 提取层级写入元数据
3. WHEN 生成回答/笔记 THEN 关键结论与引用信息关联输出
4. WHEN 解析失败 THEN 返回可解释错误并允许重试/降级

#### 需求 25

**用户故事：** 作为研究者，我希望系统支持联网实时搜索并将结果沉淀到个人资料库。

**验收标准**

1. WHEN 联网搜索 THEN 返回可追溯来源列表
2. WHEN 选择来源 THEN 抓取正文清洗/脱敏入库
3. WHEN 来源为 PDF/可下载文件 THEN 支持下载并走摄入流程
4. WHEN 存在版权/访问限制 THEN 合规降级
5. WHEN 重复添加 THEN 去重并保留版本

#### 需求 26

**用户故事：** 作为研究者，我希望系统提供研究项目工作台。

**验收标准**

1. WHEN 创建研究项目 THEN 可配置研究主题、问题列表与目标输出格式
2. WHEN 添加资料/摘录 THEN 归档到项目并可检索筛选
3. WHEN 生成笔记/结论 THEN 结构化保存（Note/Claim/Evidence/Citation）
4. WHEN 回溯证据 THEN 从结论定位到引用片段与来源元数据
5. WHEN 拆解任务 THEN 维护待办队列并允许调整

#### 需求 27

**用户故事：** 作为研究者，我希望系统能将研究成果导出到本地 Markdown/Obsidian 和 Notion。

**验收标准**

1. WHEN 导出 Markdown THEN 输出 Obsidian 友好格式
2. WHEN 导出 Notion THEN 通过 Notion API 创建/更新页面并保留引用
3. WHEN 导出包含引用 THEN 保留可点击引用
4. WHEN 导出失败 THEN 返回结构化错误与可重试建议

#### 需求 28

**用户故事：** 作为研究者，我希望系统支持“强引用模式”。

**验收标准**

1. WHEN 启用强引用模式 THEN 所有关键结论字段必须附带至少一个 Citation
2. WHEN 输出缺少引用 THEN 触发自我修正重试或回退
3. WHEN 仍无法合规 THEN 按 answerPolicy（strict/force）处理并禁止伪造引用
4. WHEN 返回响应 THEN 标记引用质量信息
5. WHEN answerPolicy = force THEN 返回可读内容并显式给出证据不足信息
6. WHEN answerPolicy = force THEN 关键结论标注“无证据/不确定”且可机器校验
7. WHEN answerPolicy = force THEN citation 必须能映射到真实检索/深读结果

#### 需求 30

**用户故事：** 作为平台维护者，我希望系统能验证并约束 RAGFlow 的字段能力与契约。

**验收标准**

1. WHEN 对接 RAGFlow THEN 定义并实现字段映射（chunks + citations）
2. WHEN 依赖页码/章节定位 THEN 验证字段能力，不满足触发降级
3. WHEN 降级 THEN 引用仍可追溯并记录告警
4. WHEN RAGFlow 变更 THEN 通过契约测试发现并阻断回归

#### 需求 31

**用户故事：** 作为研究者与平台维护者，我希望系统具备长文档处理策略与成本控制能力。

**验收标准**

1. WHEN 文档超过阈值 THEN 使用分段处理策略（Map-Reduce）
2. WHEN 生成分段摘要 THEN 支持结构化输出
3. WHEN 重复请求 THEN 优先命中缓存或复用中间结果
4. WHEN 失败 THEN 提供可恢复错误与重试/降级策略

#### 需求 32

**用户故事：** 作为研究者，我希望系统具备“深度解析（Deep Parsing）”能力。

**验收标准**

1. WHEN 摄入复杂 PDF THEN 尽可能还原阅读顺序
2. WHEN 文档包含表格 THEN 保留表格结构信息
3. WHEN 生成检索 chunk THEN 记录页码与可视化定位元数据
4. WHEN 能力不可用 THEN 可解释降级并记录告警

#### 需求 33

**用户故事：** 作为研究者，我希望引用能定位到页面坐标区域。

**验收标准**

1. WHEN 引用来自 PDF THEN citation SHOULD 附带页内坐标信息
2. WHEN 前端请求展示引用 THEN 能基于元数据定位并展示原文片段
3. WHEN 坐标缺失 THEN 退化为页码/offset 并标注原因

#### 需求 34

**用户故事：** 作为研究者，我希望 Agent 可调用“混合检索工具”。

**验收标准**

1. WHEN 调用混合检索工具 THEN 支持 query 与 filters
2. WHEN 执行检索 THEN 支持 keyword + vector 混合召回并 rerank
3. WHEN 返回结果 THEN 返回结构化列表（含 citation 定位字段等）
4. WHEN filters 指定 projectId THEN 将检索范围限制在该 Project 资料集合内

#### 需求 35

**用户故事：** 作为研究者，我希望 Agent 能按页范围深度阅读特定文档。

**验收标准**

1. WHEN 调用 read_document THEN 支持 documentId + pageStart/pageEnd
2. WHEN 返回内容 THEN 保留页码与引用定位信息
3. WHEN 页范围越界 THEN 返回结构化错误并给可重试建议

#### 需求 37

**用户故事：** 作为平台维护者，我希望系统支持本地模型与异步解析能力。

**验收标准**

1. WHEN 配置本地模型 THEN 支持 HTTP 适配器对接本地推理服务并作为 Provider 接入
2. WHEN 本地模型不支持所需能力 THEN 通过提示词与输出校验对齐，失败触发回退
3. WHEN 上传大文件触发耗时解析 THEN 使用异步任务队列并提供状态查询
4. WHEN 异步任务失败 THEN 返回结构化错误与可重试建议并记录事件
5. WHEN 使用 llama.cpp server THEN 记录关键运行参数
6. WHEN 提供推荐配置 THEN 配置层可表达关键建议项

#### 需求 38

**用户故事：** 作为研究者，我希望选定课题后系统能自动完成前期准备工作（bootstrap）。

**验收标准**

1. WHEN 创建研究项目 THEN 创建 ResearchProject 并生成初始问题列表，且绑定 tenantId
2. WHEN 生成初始问题 THEN SHOULD 附带用途标签
3. WHEN 触发 bootstrap THEN 联网搜索并返回可追溯候选来源
4. WHEN 确认导入 THEN 抓取/下载、清洗/脱敏，并通过 RAGFlow 摄入
5. WHEN 重复导入 THEN 去重并可保留版本
6. WHEN 入库完成 THEN 生成待办队列并可关联来源与推荐阅读范围
7. WHEN bootstrap 运行 THEN 以流式 progress events 返回阶段状态并支持取消
8. WHEN 用户取消 THEN 终止后续步骤并返回可恢复状态
9. WHEN 生成起步包 THEN 支持导出 Markdown/Obsidian 并 SHOULD 支持 Notion
10. WHEN 失败 THEN 返回结构化错误与可重试建议并记录事件

---

## Project/Workspace 隔离（补充强调）

#### 需求 41

**用户故事：** 作为用户，我希望当我在某个 Project/Workspace 下工作时，检索与引用严格限定在该 Project 绑定的资料范围内。

**验收标准**

1. WHEN 用户进入某个 Project THEN 注入 `projectId` 到请求级上下文
2. WHEN 执行检索 THEN 默认带 `projectId` 并限制范围
3. WHEN 跨 Project 检索 THEN 需要二次确认或显式开关，并标记来源 Project
4. WHEN 输出包含 citation THEN citation 必须映射回该 Project 的真实检索/深读结果
