# 实现计划

## 范围与关键决策（当前迭代）

- **RAG（检索）**: 集成 RAGFlow 作为外部知识库服务，仅负责“文档摄入/检索/引用溯源”；回答生成仍由本框架通过 Vercel AI SDK 调用模型完成。
- **多租户/配额**: 当前迭代不实现配额/计费与管理后台能力（任务 16、/api/admin 等延后），但会预埋 `tenantId` 并在全链路实现租户隔离（接口/数据模型/查询默认按 `tenantId` 过滤）。

## Phase 1: 项目骨架搭建

- [ ] 1. 初始化项目结构和基础配置
  - [ ] 1.1 创建 monorepo 结构（packages/core, packages/cli, apps/api, apps/web）
    - 使用 pnpm workspace + Turborepo 管理（利用缓存加速构建）
    - 配置 TypeScript、ESLint、Prettier
    - 集成 t3-env 实现环境变量类型安全校验
    - _Requirements: 17.5_
  - [ ] 1.2 配置 Fastify 服务器骨架
    - 集成 fastify-type-provider-zod
    - 集成 fastify-swagger 自动文档生成
    - _Requirements: 16.1, 16.3_
  - [ ] 1.3 配置 Vercel AI SDK Core 集成
    - 安装 ai, @ai-sdk/openai, @ai-sdk/anthropic
    - 创建基础 streamText 示例验证集成
    - _Requirements: 2.1, 2.7_
  - [ ] 1.4 配置 OpenTelemetry 追踪基础设施
    - 集成 @opentelemetry/sdk-node
    - 配置 Fastify 请求追踪
    - _Requirements: 8.1, 8.3_
  - [ ] 1.5 编写项目初始化属性测试
    - **Property 5: Provider 接口统一性**
    - **Validates: Requirements 2.1, 2.7**

- [ ] 2. 实现中间件层
  - [ ] 2.1 实现 wrapLanguageModel 中间件模式
    - 支持 System Prompt 注入
    - 支持请求上下文传递
    - _Requirements: 23.1, 23.4_
  - [ ] 2.2 编写中间件属性测试
    - **Property 19: 中间件执行顺序**
    - **Validates: Requirements 23.1**
  - [ ] 2.3 实现 MockLanguageModel 测试支持
    - 支持预定义响应
    - 零 Token 消耗
    - _Requirements: 23.2_
  - [ ] 2.4 编写 Mock 模型属性测试
    - **Property 20: Mock 模型注入**
    - **Validates: Requirements 23.2**

  - [ ] 2.5 实现请求级 tenantId 上下文贯穿
    - 在请求上下文对象中提供 tenantId，并贯穿到核心编排与日志/追踪属性
    - _Requirements: 29.3_

- [ ] 3. 实现流式处理器
  - [ ] 3.1 实现 StreamHandler 核心类
    - 实现 toFastifyReply 方法（含正确 Header）
    - 实现 Error Chunk 发送
    - _Requirements: 9.1, 9.2, 9.4_
  - [ ] 3.2 编写流式协议属性测试
    - **Property 14: 流式协议合规性**
    - **Validates: Requirements 9.1**
  - [ ] 3.3 编写错误块属性测试
    - **Property 15: 流式错误块格式**
    - **Validates: Requirements 9.4**
  - [ ] 3.4 实现 Token 用量估算回退
    - 实现 UsageEstimator 类
    - 处理流式中断场景
    - _Requirements: 8.2_
  - [ ] 3.5 编写 Token 追踪属性测试
    - **Property 13: Token 用量追踪完整性**
    - **Validates: Requirements 8.2**

- [ ] 4. Checkpoint - 确保所有测试通过
  - Ensure all tests pass, ask the user if questions arise.

## Phase 2: 核心引擎实现

- [ ] 5. 对接外部检索服务（RAGFlow）
  - [ ] 5.1 定义检索适配器与数据映射
    - 对齐 `IRAGPipeline.ingest/retrieve` 的输入输出结构
    - 支持 `knowledgeBaseId/collectionId` 作为外部知识库定位信息
    - _Requirements: 1.1, 1.4, 34.1, 34.3, 34.4_
  - [ ] 5.2 实现 RAGFlow HTTP API Client/Adapter
    - 实现 ingest（文档摄入）调用与错误处理
    - 实现 retrieve（检索）调用与结果映射（chunks + citations）
    - _Requirements: 1.1, 1.4, 19.1, 34.1, 34.2, 34.3, 34.4_
  - [ ] 5.3 编写检索适配器溯源测试
    - **Property 3: 检索结果溯源完整性**
    - **Validates: Requirements 1.4, 19.1**

- [ ] 6. 实现文档摄入与预处理（通过 RAGFlow）
  - [ ] 6.1 实现文档摄入入口
    - 支持 PDF、Markdown、HTML、Word、Excel、纯文本
    - 将文档内容与元数据发送至 RAGFlow 完成摄入
    - _Requirements: 1.2_
  - [ ] 6.2 对接 RAGFlow 的分块/索引配置（不实现内部 Chunker）
    - 分块策略与索引能力由 RAGFlow 侧配置/模板驱动
    - 框架仅透传必要参数（如 `knowledgeBaseId/collectionId` 与 metadata）
    - _Requirements: 1.3_
  - [ ] 6.3 补齐 PDF 页码/章节元数据与引用定位信息
    - 保留页码（pageNumber）与章节层级信息（如 tocPath/chapterTitle/sectionTitle）到 metadata
    - 摄入时将页码/章节信息透传到 RAGFlow，确保检索返回的 citation 可映射为可定位引用
    - 补齐页内坐标信息（如 boundingBoxes/x_y_coordinates）时，透传并保持到 citation 元数据
    - _Requirements: 24.1, 24.2, 24.3, 32.3, 33.1_
  - [ ] 6.8 验证并对齐 Deep Parsing 能力（RAGFlow/解析侧）
    - 验证复杂版式还原（多栏/表格）与坐标字段可用性；不可用时走降级策略并记录告警
    - _Requirements: 30.2, 32.1, 32.2, 32.4, 33.1, 33.3_
  - [ ] 6.4 实现数据清洗管道
    - 移除 HTML 标签、修复编码
    - 规范化空白字符
    - _Requirements: 5.1_
  - [ ] 6.5 编写数据清洗属性测试
    - **Property 8: 数据清洗幂等性**
    - **Validates: Requirements 5.1**
  - [ ] 6.6 实现 PII 脱敏处理
    - 检测姓名、电话、邮箱、身份证号
    - 替换为占位符
    - _Requirements: 5.2_
  - [ ] 6.7 编写 PII 脱敏属性测试
    - **Property 9: PII 脱敏完整性**
    - **Validates: Requirements 5.2**

- [ ] 7. 实现 RAG 管道
  - [ ] 7.1 实现 RAGPipeline 核心类
    - 实现 ingest 方法（文档摄入）
    - 实现 retrieve 方法（检索）
    - 实现 generate 方法（生成）
    - _Requirements: 1.1, 1.4_
  - [ ] 7.2 实现引用坐标追踪
    - 在检索结果中包含完整 ICitation
    - 支持前端高亮定位
    - _Requirements: 19.1, 19.2, 33.1, 33.2, 33.3_
  - [ ] 7.3 编写检索溯源属性测试
    - **Property 3: 检索结果溯源完整性**
    - **Validates: Requirements 1.4, 19.1**
  - [ ] 7.4 实现 Reranker 组件
    - 支持可配置的重排序模型
    - _Requirements: 1.7_
  - [ ] 7.5 实现流式生成（streamGenerate）
    - 通过 Data Channel 发送引用
    - _Requirements: 9.1, 19.1_

- [ ] 8. 实现模型路由器
  - [ ] 8.1 实现 ModelRouter 核心类
    - 实现 route 方法
    - 实现 registerProvider 方法
    - 实现 setRoutingRules 方法
    - _Requirements: 2.1, 2.2_
  - [ ] 8.2 实现复杂度评估逻辑
    - 基于规则的评估
    - 支持分类器模型评估
    - _Requirements: 2.2, 2.3, 2.4_
  - [ ] 8.3 编写路由规则属性测试
    - **Property 4: 模型路由规则确定性**
    - **Validates: Requirements 2.2, 2.3, 2.4**
  - [ ] 8.4 实现故障转移逻辑
    - 自动切换备用 Provider
    - 记录故障事件
    - _Requirements: 2.5, 14.1_

- [ ] 9. Checkpoint - 确保所有测试通过
  - Ensure all tests pass, ask the user if questions arise.

## Phase 3: Agent 和结构化输出

- [ ] 10. 实现 Agent 引擎
  - [ ] 10.1 实现 AgentEngine 核心类
    - 实现 defineAgent 方法
    - 实现 execute 方法
    - 实现 streamExecute 方法
    - _Requirements: 3.1, 3.4, 3.5_
  - [ ] 10.2 实现 Zod 工具参数验证
    - 自动参数解析
    - 验证失败反馈给模型
    - _Requirements: 3.1, 3.2_
  - [ ] 10.3 编写工具参数验证属性测试
    - **Property 6: 工具参数 Zod 验证**
    - **Validates: Requirements 3.1, 3.2**
  - [ ] 10.4 实现 maxSteps 限制
    - 控制最大迭代次数
    - 优雅终止并返回部分结果
    - _Requirements: 3.3_
  - [ ] 10.5 编写步数限制属性测试
    - **Property 7: Agent 步数限制**
    - **Validates: Requirements 3.3**
  - [ ] 10.6 实现多 Agent 协作
    - Agent 间消息传递
    - 任务委托机制
    - _Requirements: 3.7_

  - [ ] 10.7 实现 Agent Step Events（Thinking UI 事件流）
    - 流式输出 thinking/tool_call/tool_result/reading/generating/complete/cancelled 等事件
    - 支持用户取消请求并中止后续步骤
    - _Requirements: 36.1, 36.2, 36.3_

- [ ] 11. 实现结构化输出
  - [ ] 11.1 实现 generateObject 封装
    - 强制 Zod Schema 验证
    - 类型安全返回
    - _Requirements: 22.1, 22.2_
  - [ ] 11.2 实现 streamObject 封装
    - 支持 Partial JSON Parsing
    - 增量推送已解析字段
    - _Requirements: 22.3_
  - [ ] 11.3 编写结构化输出属性测试
    - **Property 16: 结构化输出类型安全**
    - **Validates: Requirements 22.2, 22.4**
  - [ ] 11.4 实现自动修复重试
    - 格式错误触发重试
    - 配置最大重试次数
    - _Requirements: 22.5, 22.6_
  - [ ] 11.5 编写自动修复属性测试
    - **Property 17: 结构化输出自动修复**
    - **Validates: Requirements 22.5**

- [ ] 12. Checkpoint - 确保所有测试通过
  - Ensure all tests pass, ask the user if questions arise.

## Phase 4: 安全与缓存

- [ ] 13. 实现安全护栏
  - [ ] 13.1 实现 Guardrails 核心类
    - 实现 checkInput 方法
    - 实现 checkOutput 方法
    - 实现 addRule 方法
    - _Requirements: 6.1, 6.2, 6.5_
  - [ ] 13.2 实现提示注入检测
    - 检测已知注入模式
    - 阻止恶意请求
    - _Requirements: 6.1, 6.6_
  - [ ] 13.3 编写注入检测属性测试
    - **Property 10: 护栏注入检测**
    - **Validates: Requirements 6.1**
  - [ ] 13.4 实现内容过滤规则
    - 关键词过滤
    - 话题过滤
    - _Requirements: 6.2, 6.5_
  - [ ] 13.5 实现降级响应
    - 返回安全的降级消息
    - 记录护栏事件
    - _Requirements: 6.3, 6.4_

- [ ] 14. 实现缓存系统
  - [ ] 14.1 实现 CacheSystem 核心类
    - 实现 get、set 方法
    - 实现 invalidateByTag 方法
    - _Requirements: 7.1, 7.2, 7.7_
  - [ ] 14.2 实现 Redis 缓存适配器
    - 支持 TTL 配置
    - 支持 LRU 淘汰
    - _Requirements: 7.2, 7.3, 7.5_
  - [ ] 14.3 编写缓存命中属性测试
    - **Property 11: 缓存命中一致性**
    - **Validates: Requirements 7.1**
  - [ ] 14.4 实现语义相似缓存
    - 基于嵌入向量相似度匹配
    - 可配置相似度阈值
    - _Requirements: 7.4_
  - [ ] 14.5 编写语义缓存属性测试
    - **Property 12: 语义缓存相似性**
    - **Validates: Requirements 7.4**

- [ ] 15. Checkpoint - 确保所有测试通过
  - Ensure all tests pass, ask the user if questions arise.

## Phase 5: 租户与可观测性

- [ ] 16. 实现租户管理（后续/暂不实现）
  - 当前迭代不实现多租户隔离与配额管理能力。
  - [ ] 16.1 配置 Prisma 数据库 Schema
    - 创建 Tenant、ApiKey、Document、Chunk、UsageRecord 模型
    - 配置索引和关系
    - _Requirements: 21.1_
  - [ ] 16.2 实现 TenantManager 核心类
    - 实现 createTenant 方法
    - 实现 checkQuota 方法
    - 实现 getUsageStats 方法
    - _Requirements: 21.1, 21.2, 21.6_
  - [ ] 16.3 实现配额检查和执行
    - Token 预算上限检查
    - 超限时限流或阻断
    - _Requirements: 21.3, 21.4_
  - [ ] 16.4 编写配额执行属性测试
    - **Property 18: 租户配额执行**
    - **Validates: Requirements 21.4**
  - [ ] 16.5 实现 API Key 管理
    - Key 生成和哈希存储
    - 权限和配额配置
    - _Requirements: 21.5_

- [ ] 17. 实现可观测性系统
  - [ ] 17.1 实现 Observability 核心类
    - 实现 startTrace 方法
    - 实现 recordMetric 方法
    - 实现 recordUsage 方法
    - _Requirements: 8.1, 8.4, 8.5_
  - [ ] 17.2 集成 onFinish 回调
    - 从 usage 对象读取 Token 用量
    - 异步写入 OpenTelemetry
    - _Requirements: 8.1, 8.2_
  - [ ] 17.3 实现成本分析报表
    - 按模型、用户、功能维度统计
    - _Requirements: 8.5_
  - [ ] 17.4 实现告警触发
    - 延迟飙升告警
    - 错误率上升告警
    - _Requirements: 8.3_

- [ ] 18. Checkpoint - 确保所有测试通过
  - Ensure all tests pass, ask the user if questions arise.

## Phase 6: API 层实现

- [ ] 19. 实现 API 路由
  - [ ] 19.1 实现 /api/chat 端点
    - 支持流式和非流式响应
    - 集成认证和限流中间件
    - _Requirements: 16.1, 16.2_
  - [ ] 19.2 实现 /api/rag 端点
    - 支持检索和生成
    - 返回引用坐标
    - _Requirements: 1.4, 19.1_
  - [ ] 19.3 实现 /api/documents 端点
    - 文档上传和摄入
    - 文档查询和删除
    - _Requirements: 1.2, 5.3_
  - [ ] 19.4 实现 /api/agents 端点
    - Agent 任务执行
    - 流式事件推送
    - _Requirements: 3.4, 3.5_
  - [ ] 19.5 实现 /api/admin 端点（后续/暂不实现）
    - 租户管理
    - 用量统计
    - _Requirements: 21.6_

- [ ] 20. 实现认证和限流
  - [ ] 20.1 实现 API Key 认证中间件
    - Key 验证和权限检查
    - _Requirements: 16.4_
  - [ ] 20.2 实现限流中间件
    - 按用户、IP、API Key 维度限流
    - _Requirements: 14.3, 14.4_
  - [ ] 20.3 实现 JWT 认证支持
    - Token 验证
    - _Requirements: 16.4_

  - [ ] 20.4 实现 tenantId 解析与租户隔离校验
    - 从 API Key/JWT/会话上下文解析 tenantId 并注入请求上下文
    - 所有数据读写默认按 tenantId 过滤
    - _Requirements: 29.1, 29.2, 29.3, 29.4_

- [ ] 21. 实现 WebSocket 支持
  - [ ] 21.1 配置 Fastify WebSocket 插件
    - 支持实时双向通信
    - _Requirements: 16.5_
  - [ ] 21.2 实现 WebSocket 消息处理
    - 流式响应推送
    - 连接状态管理
    - _Requirements: 9.5, 16.5_

- [ ] 22. Checkpoint - 确保所有测试通过
  - Ensure all tests pass, ask the user if questions arise.

## Phase 7: 前端实现

- [ ] 23. 初始化前端项目
  - [ ] 23.1 创建 React + Vite 项目
    - 配置 TypeScript
    - 配置 Tailwind CSS
    - _Requirements: 前端架构_
  - [ ] 23.2 安装和配置 Shadcn/ui
    - 初始化组件库
    - 配置主题和颜色
    - _Requirements: UI设计系统_
  - [ ] 23.3 配置 Zustand 状态管理
    - 创建 ConversationStore
    - 创建 DocumentStore
    - 创建 UIStore
    - _Requirements: 前端架构_

- [ ] 24. 实现聊天界面
  - [ ] 24.1 实现 ChatInterface 组件
    - 消息列表渲染
    - 输入区域
    - _Requirements: 前端架构_
  - [ ] 24.2 实现 useChat Hook 扩展
    - 集成 Vercel AI SDK useChat
    - 扩展引用和反馈支持
    - _Requirements: 10.1, 19.1_
  - [ ] 24.3 实现流式文本渲染
    - 打字机效果
    - 光标动画
    - _Requirements: 9.1, 9.6_
  - [ ] 24.4 编写流式渲染属性测试
    - **Property 21: 流式文本渲染一致性**
    - **Validates: Requirements 9.1, 9.6**
  - [ ] 24.5 实现工具调用状态指示
    - 思考中、调用中、完成状态
    - Framer Motion 动画
    - _Requirements: 3.4_

- [ ] 25. 实现文档查看器
  - [ ] 25.1 实现 DocumentViewer 组件
    - 文档内容渲染
    - 高亮支持
    - _Requirements: 19.2, 19.3_
  - [ ] 25.2 实现引用高亮功能
    - 根据坐标高亮文本
    - 点击跳转
    - _Requirements: 19.1, 19.2_
  - [ ] 25.3 编写引用高亮属性测试
    - **Property 22: 引用高亮准确性**
    - **Validates: Requirements 19.1, 19.2**
  - [ ] 25.4 实现划词操作
    - 文本选择检测
    - 操作弹窗
    - _Requirements: 19.4_
  - [ ] 25.5 编写划词操作属性测试
    - **Property 23: 划词操作响应性**
    - **Validates: Requirements 19.4**

- [ ] 26. 实现引用面板
  - [ ] 26.1 实现 CitationPanel 组件
    - 引用列表展示
    - Glassmorphism 卡片样式
    - _Requirements: 19.1_
  - [ ] 26.2 实现引用与文档联动
    - 点击引用高亮原文
    - _Requirements: 19.2, 19.3_

- [ ] 27. 实现反馈系统
  - [ ] 27.1 实现 FeedbackButton 组件
    - 点赞/点踩按钮
    - 反馈提交
    - _Requirements: 10.1_
  - [ ] 27.2 实现反馈后续问卷
    - 负面反馈原因收集
    - _Requirements: 10.4_
  - [ ] 27.3 编写反馈完整性属性测试
    - **Property 24: 反馈数据完整性**
    - **Validates: Requirements 10.1, 10.2**

- [ ] 28. Checkpoint - 确保所有测试通过
  - Ensure all tests pass, ask the user if questions arise.

## Phase 8: 评估与工具

- [ ] 29. 实现评估框架
  - [ ] 29.1 实现 EvalFramework 核心类
    - 数据集管理
    - 评估运行
    - _Requirements: 4.1, 4.2_
  - [ ] 29.2 实现多维度评估
    - 准确性评估
    - 完整性评估
    - 格式合规性评估
    - 安全性评估
    - _Requirements: 4.2_
  - [ ] 29.3 实现 LLM-as-a-Judge 模式
    - 使用强模型评估弱模型输出
    - _Requirements: 4.5_
  - [ ] 29.4 实现评估报告生成
    - JSON、CSV、HTML 格式导出
    - 基线对比
    - _Requirements: 4.3, 4.6_

- [ ] 30. 实现合成数据生成
  - [ ] 30.1 实现 SyntheticDataGenerator 类
    - 基于文档生成 QA 对
    - 支持问题类型配置
    - _Requirements: 20.1, 20.2_
  - [ ] 30.2 实现数据增强
    - 问题变体生成
    - 同义替换
    - _Requirements: 20.4_
  - [ ] 30.3 实现数据导出
    - 评估框架格式
    - 微调 JSONL 格式
    - _Requirements: 20.3, 20.6_

- [ ] 31. 实现提示词管理
  - [ ] 31.1 实现 PromptManager 核心类
    - 模板变量支持
    - 条件逻辑支持
    - _Requirements: 11.1_
  - [ ] 31.2 实现版本管理
    - 自动版本化
    - 历史记录
    - _Requirements: 11.2_
  - [ ] 31.3 实现 A/B 测试支持
    - 流量分配
    - 效果对比
    - _Requirements: 11.3_
  - [ ] 31.4 实现动态 Few-shot 选择
    - 基于相似度选择示例
    - _Requirements: 11.4_

- [ ] 32. 实现 CLI 工具
  - [ ] 32.1 实现 init 命令
    - 项目脚手架生成
    - _Requirements: 18.1_
  - [ ] 32.2 实现 eval 命令
    - 运行评估并输出报告
    - _Requirements: 18.2_
  - [ ] 32.3 实现 ingest 命令
    - 文档导入
    - _Requirements: 18.4_
  - [ ] 32.4 实现 serve 命令
    - 启动 API 服务
    - 健康检查
    - _Requirements: 18.5_

- [ ] 33. Checkpoint - 确保所有测试通过
  - Ensure all tests pass, ask the user if questions arise.

## Phase 9: 集成与文档

- [ ] 34. 实现配置管理
  - [ ] 34.1 实现 ConfigManager 核心类
    - 多源配置加载（环境变量、文件、远程）
    - _Requirements: 17.1_
  - [ ] 34.2 实现配置验证
    - Zod Schema 验证
    - 必填项检查
    - _Requirements: 17.4_
  - [ ] 34.3 实现热更新支持
    - 配置变更监听
    - 无需重启更新
    - _Requirements: 17.3_
  - [ ] 34.4 实现环境隔离
    - 开发、测试、生产配置分离
    - _Requirements: 17.5_

- [ ] 35. 实现插件系统
  - [ ] 35.1 定义插件接口
    - 生命周期钩子
    - 配置管理
    - _Requirements: 15.1, 15.3_
  - [ ] 35.2 实现插件注册和执行
    - 按顺序调用插件
    - 错误隔离
    - _Requirements: 15.2, 15.4_
  - [ ] 35.3 实现运行时启用/禁用
    - 动态插件管理
    - _Requirements: 15.5_

- [ ] 36. 编写文档
  - [ ] 36.1 编写 API 文档
    - 自动生成 OpenAPI 文档
    - 使用示例
    - _Requirements: 16.3_
  - [ ] 36.2 编写快速开始指南
    - 安装和配置
    - 基础使用
  - [ ] 36.3 编写架构文档
    - 组件说明
    - 扩展指南

- [ ] 37. 配置 Docker 开发环境
  - [ ] 37.1 编写 docker-compose.yml
    - Redis 服务
    - PostgreSQL 服务
  - [ ] 37.2 编写 Dockerfile
    - 多阶段构建
    - 生产优化

- [ ] 38. Final Checkpoint - 确保所有测试通过
  - Ensure all tests pass, ask the user if questions arise.

## Phase 10: 研究协作智能体平台化（Research Copilot）

> 本阶段将新增的研究协作智能体需求（24-28, 38）完整落地为可用的平台能力：来源搜索/入库、研究项目工作台、课题启动（前期准备）、导出能力、强引用模式与质量验证。

- [ ] 39. 实现联网搜索与来源入库（Sources）
  - [ ] 39.1 实现 Web 搜索服务与来源结果标准化
    - 返回标题、URL、摘要、时间等基础字段
    - _Requirements: 25.1_
  - [ ] 39.2 实现来源抓取与合规降级策略
    - 抓取正文后清洗/脱敏再入库；遇到受限内容仅保存元数据与链接
    - _Requirements: 25.2, 25.4_
  - [ ] 39.3 实现来源去重与版本策略
    - 基于内容哈希或 URL 规范化去重
    - _Requirements: 25.5_
  - [ ] 39.4 编写来源去重属性测试
    - **Property 26: 来源去重确定性**
    - **Validates: Requirements 25.5**

- [ ] 40. 实现研究项目工作台（Projects/Notes/Claims）
  - [ ] 40.1 定义研究项目与笔记数据模型
    - ResearchProject、ResearchQuestion、Note、Claim、Evidence、TaskItem
    - _Requirements: 26.1, 26.3_
  - [ ] 40.2 实现研究项目服务层
    - 项目创建/查询/更新；资料与笔记归档
    - _Requirements: 26.1, 26.2_
  - [ ] 40.3 实现证据回溯能力
    - 从结论（Claim）反向定位引用片段与来源元数据
    - _Requirements: 26.4_

  - [ ] 40.4 实现课题启动（Research Bootstrap）
    - 生成初始问题列表（ResearchQuestion）与用途标签/分组
    - 生成待办队列（TaskItem：to-read/to-verify/to-write）并关联来源
    - 将 Sources 搜索/导入与 RAGFlow 摄入编排为可重复执行的启动流程
    - _Requirements: 38.1, 38.2, 38.3, 38.4, 38.6_

  - [ ] 40.5 实现 bootstrap 进度事件流与取消/可恢复
    - 输出 planning/searching/importing/ingesting/tasking/packaging/complete/cancelled/error 等阶段事件（或等价事件）
    - 支持用户取消并返回可恢复状态
    - _Requirements: 38.7, 38.8_

  - [ ] 40.6 编写课题启动属性测试
    - **Property 38: 课题启动幂等性与不重复入库**
    - **Validates: Requirements 38.4, 38.5**

- [ ] 41. 实现导出能力（Markdown/Obsidian + Notion）
  - [ ] 41.1 实现 Markdown/Obsidian 导出器
    - 支持 frontmatter、引用列表与可点击引用
    - _Requirements: 27.1, 27.3_
  - [ ] 41.2 实现 Notion 导出器
    - 通过 Notion API 创建/更新页面，保留引用信息
    - _Requirements: 27.2, 27.3_
  - [ ] 41.3 编写导出幂等性属性测试
    - **Property 27: 导出幂等性**
    - **Validates: Requirements 27.1, 27.2**

- [ ] 42. 实现强引用模式（Strict Citation Mode）
  - [ ] 42.1 实现强引用策略配置
    - 对“关键结论”字段强制至少 1 个 Citation
    - 支持回答策略（answerPolicy）：strict/force
    - _Requirements: 28.1_
  - [ ] 42.2 实现缺引用自修复与回退策略
    - 缺引用触发自修复重试/回退模型，达到上限按 answerPolicy 处理：
      - strict：结构化错误 + 缺失字段列表
      - force：最佳努力输出 + 机器可校验的证据不足标记（missingFields/evidenceStatus）
    - _Requirements: 28.2, 28.3_
  - [ ] 42.3 实现 force 模式的“禁止伪造引用”校验
    - 任何输出 citations 必须可追溯到真实检索/深读结果（documentId/chunk/page/offset 一致）
    - _Requirements: 28.7_
  - [ ] 42.4 实现引用质量标记与证据状态
    - 返回引用数量/覆盖率/置信度（可选）/missingFields/evidenceStatus 等质量信息
    - _Requirements: 28.4, 28.5, 28.6_
  - [ ] 42.5 编写强引用模式属性测试
    - **Property 28: 强引用模式合规性**
    - 覆盖 strict/force 两种策略下的行为差异
    - **Validates: Requirements 28.1, 28.2, 28.3, 28.7**

- [ ] 43. 实现研究平台 API 与前端工作区
  - [ ] 43.1 实现 Sources API
    - /api/sources/search, /api/sources/import
    - _Requirements: 25.1, 25.2, 25.3_
  - [ ] 43.2 实现 Projects/Notes API
    - /api/projects, /api/notes, /api/tasks
    - _Requirements: 26.1, 26.2, 26.5_
  - [ ] 43.3 实现 Export API
    - /api/export/markdown, /api/export/notion
    - _Requirements: 27.1, 27.2, 27.4_
  - [ ] 43.4 实现前端 Research Workspace
    - 项目列表、资料库、阅读与引用、笔记编辑、导出面板
    - _Requirements: 26.1, 26.2, 27.1, 27.2_

- [ ] 44. Checkpoint - Research Copilot 平台验收
  - 运行全量测试：`pnpm -r test` + `pnpm -r lint`
  - E2E 验证：上传 PDF -> 入库 -> 检索 -> 生成带引用笔记 -> 导出 Markdown/Notion
  - 强引用模式验证：缺引用时必须自修复；达到上限后按 answerPolicy 行为收敛（strict 报错；force 给出最佳努力输出并标注证据不足/缺失字段）

## Phase 11: 平台化稳健性与成本控制

> 本阶段针对需求 29-31：补齐多租户隔离验证、RAGFlow 字段契约与能力探测、长文档 Map-Reduce 策略与成本控制。

- [ ] 45. 租户隔离验证（Tenant Isolation）
  - [ ] 45.1 编写租户隔离集成测试
    - A 租户写入资源，B 租户不可读/不可改/不可删
    - **Property 29: 租户隔离不泄漏**
    - **Validates: Requirements 29.1, 29.2, 29.3, 29.4**

- [ ] 46. RAGFlow 字段能力验证与契约测试
  - [ ] 46.1 实现 RAGFlow 字段映射与能力探测
    - 验证是否具备 pageNumber/offset/toc 等字段，缺失则触发降级并记录告警
    - _Requirements: 30.1, 30.2, 30.3_
  - [ ] 46.2 编写 RAGFlow 契约测试
    - 发现 API 行为变更并阻断回归
    - **Property 30: RAGFlow 字段契约稳定性**
    - **Validates: Requirements 30.1, 30.2, 30.3, 30.4**

- [ ] 47. 长文档处理策略（Map-Reduce）与成本控制
  - [ ] 47.1 实现长文档分段总结与汇总编排
    - 分段摘要（section/chapter）-> 汇总（book/project）
    - _Requirements: 31.1, 31.2_
  - [ ] 47.2 实现中间结果缓存与复用
    - 章节摘要/关键要点支持缓存命中，避免重复 Token 消耗
    - _Requirements: 31.3_
  - [ ] 47.3 编写长文档策略属性测试与评估
    - **Property 31: 长文档 Map-Reduce 产出一致性**
    - **Validates: Requirements 31.1, 31.2, 31.3, 31.4**

- [ ] 48. Checkpoint - 平台化稳健性验收
  - 运行全量测试：`pnpm -r test` + `pnpm -r lint`
  - 验证 tenantId 隔离：跨租户数据不可访问
  - 验证 RAGFlow 契约：字段缺失时降级且有告警
  - 验证长文档策略：分段摘要可复用，汇总稳定

## Phase 12: Agentic RAG 增强能力落地

> 本阶段将 Agentic RAG 作为默认范式补齐到产品级能力：混合检索与范围过滤、按页深读、引用坐标可视化、本地模型 Provider 与异步摄入。

- [ ] 49. 实现混合检索工具（Hybrid Search）
  - [ ] 49.1 定义 search_knowledge_base 工具 Schema 与服务接口
    - 支持 query + filters（projectId/documentId/year）
    - _Requirements: 34.1, 34.2_
  - [ ] 49.2 实现项目范围检索约束
    - projectId 下检索必须限制在项目绑定资料集合
    - **Property 34: 混合检索范围约束**
    - **Validates: Requirements 34.4**

- [ ] 50. 实现深读工具（read_document）
  - [ ] 50.1 定义 read_document 工具 Schema 与服务接口
    - documentId + pageStart/pageEnd
    - _Requirements: 35.1_
  - [ ] 50.2 实现页范围边界校验与引用保留
    - **Property 35: 深读工具边界正确性**
    - **Validates: Requirements 35.1, 35.2, 35.3**

- [ ] 51. 引用坐标可视化（前端）
  - [ ] 51.1 扩展引用面板支持 boundingBoxes 高亮/截图定位
    - 坐标不可用时回退到页码/offset
    - **Property 33: 坐标引用可视化定位一致性**
    - **Validates: Requirements 33.1, 33.2, 33.3**

- [ ] 52. 本地模型 Provider（llama.cpp server）
  - [ ] 52.1 实现 llama.cpp server 的 Provider 适配
    - 通过 HTTP 接入并遵循统一 Provider 接口
    - _Requirements: 37.1_
  - [ ] 52.2 增加防御性结构化输出与回退策略
    - 本地模型不满足工具调用/结构化输出时，触发校验重试与回退
    - _Requirements: 37.2_

- [ ] 53. 异步摄入/解析队列（Job Queue）
  - [ ] 53.1 实现摄入任务队列与状态机
    - queued/processing/completed/failed
    - _Requirements: 37.3, 37.4_
  - [ ] 53.2 编写异步摄入状态机属性测试
    - **Property 37: 异步摄入状态机正确性**
    - **Validates: Requirements 37.3, 37.4, 29.2**

- [ ] 54. Checkpoint - Agentic RAG 能力验收
  - 混合检索：项目范围过滤正确
  - 深读工具：页范围校验正确
  - Thinking UI：step events 顺序与收敛正确
  - 引用坐标：可高亮/截图定位，缺失时正确降级
  - 本地模型：可用且失败时有回退/结构化错误
