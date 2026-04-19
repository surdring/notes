 `tasks.md` 的生成规范与最佳实践总结：

# 1. 核心生成规范

`tasks.md` 必须遵循结构化的 Markdown 格式，以便 Kiro IDE 能够识别并提供交互式执行界面。

### 标准文件结构

markdown

# Implementation Plan

- [ ] 1. 任务简短描述

  - 具体实现步骤 1

  - 具体实现步骤 2

  - _Requirements: 1.1, 2.3_ (关联需求编号，多个编号用逗号隔开)

- [ ] 2. 下一个任务描述

  - ...

### 关键要素

- **任务编号**：建议使用数字编号（如 `1.`, `2.`），方便在 Chat 中通过 `#spec:feature implement task 1` 进行引用。
    
- **关联需求 (Traceability)**：每个任务末尾应包含 `_Requirements: X.X_`，确保每个开发动作都能追溯到原始需求。
    
- **检查框 `- [ ]`**：Kiro IDE 会通过这些检查框实时追踪进度。
    

# 2. 任务拆分最佳实践

- **原子性 (Atomicity)**：每个任务应是一个独立的、可验证的开发单元。如果一个任务需要修改超过 3-5 个文件，建议进一步拆分。
    
- **阶段化顺序**：
    
    1. **基础架构/依赖**（如：定义接口、安装新包）。
        
    2. **核心逻辑**（如：API 路由、业务 Service）。
        
    3. **UI/组件**（如：React 组件、样式）。
        
    4. **测试与验证**（如：单元测试、集成测试）。
        
- **TDD 优先**：如果团队倾向于测试驱动开发，可以通过 `.kiro/steering/specs.md` 配置指令，让 Kiro 在生成 `tasks.md` 时优先安排测试任务。
    

# 3. 动态维护与交互

`tasks.md` 不是静态的，它是整个开发生命周期的“驾驶舱”：

- **自动更新进度**：在 Spec 会话中，可以要求 Kiro：`Check which tasks are already complete`。Kiro 会扫描代码并自动勾选已完成的任务。
    
- **同步变更**：
    
    - 如果修改了 `requirements.md`，需在 `design.md` 点击 **Refine**。
        
    - 随后在 `tasks.md` 中点击 **Update tasks**，Kiro 会增量添加新任务，而不会丢失已完成的任务状态。
        
- **一键执行**：点击 **Run all tasks** 按钮，Kiro 会按顺序自动执行所有标记为 `required` 且未完成的任务。
    

# 4. 专家级建议 (Steering)

- **避免过度膨胀**：不要在一个 `.kiro/specs/` 目录下放置过大的单体 Spec。应按功能模块（如 `user-auth`, `shopping-cart`）拆分多个 Spec 文件夹，每个文件夹拥有独立的 `tasks.md`。
    
- **非功能性任务**：不要遗漏文档更新、配置修改或迁移脚本任务。
    
- **使用 Steering Files**：通过 `.kiro/steering/` 下的文档定义全局规则（如“所有任务必须包含 Error Boundary”），Kiro 在生成 `tasks.md` 的实现步骤时会自动带入这些要求。
    

### 总结

一份优秀的 `tasks.md` 应该是**可追溯的（Traceable）**、**可执行的（Actionable）**且**保持同步的（Synchronized）**。它是连接设计蓝图与最终代码的桥梁。

已经为您整理了 Kiro 框架中 `tasks.md` 的生成规范与最佳实践。这些信息结合了官方文档和社区（如 Promptz）的经验：

# 1. 核心生成规范

`tasks.md` 是 Kiro 规范系统中的“执行蓝图”，必须遵循特定的 Markdown 结构以便 IDE 识别并提供交互功能。

### 标准文件结构示例

markdown

# Implementation Plan

- [ ] 1. 任务标题（简明扼要）

  - 具体的实现子步骤 1（如：创建 `src/components/Button.tsx`）

  - 具体的实现子步骤 2（如：定义 `ButtonProps` 接口）

  - _Requirements: 1.1, 2.3_ （必须标注关联的需求编号，用于双向追溯）

- [ ] 2. 下一个任务标题

  - ...

### 关键规范要素

- **任务编号**：使用数字（1, 2, 3...）作为一级任务的前缀。
    
- **状态追踪**：必须使用标准的 Markdown 任务列表语法 `- [ ]`。
    
- **需求映射 (Traceability)**：每个主任务下方必须包含 `_Requirements: X.X_`，这在 Kiro 评估任务完成度时至关重要。
    

# 2. 任务拆分的最佳实践

- **原子化 (Atomic Tasks)**：每个任务应专注于一个逻辑单元。理想情况下，一个任务的执行时间应在 5-15 分钟内。
    
- **依赖顺序**：按照“基础配置 -> 核心后端逻辑 -> 前端 UI -> 测试”的顺序排列。
    
- **详细的子步骤**：子步骤应包含具体的文件路径或函数名，这能显著提高 AI 自动执行任务的准确率。
    
- **测试集成**：建议将测试用例的编写作为任务的一部分，而不是放在最后。
    

# 3. 动态维护与协作

- **实时更新**：在开发过程中，可以直接在 `tasks.md` 中点击 **"Update tasks"**。Kiro 会扫描当前代码库，根据实现情况自动勾选已完成的任务。
    
- **Refine 流程**：如果 `requirements.md` 发生变更，应先在 `design.md` 点击 Refine，然后再更新 `tasks.md`，以保证任务列表与设计方案同步。
    
- **一键执行**：Kiro IDE 支持 **"Run all tasks"**，它会按顺序自动执行尚未完成的必要任务。
    

# 4. 专家级 Steering（转向设置）

如果您希望自定义 `tasks.md` 的生成逻辑，可以在 `.kiro/steering/specs.md` 中添加规则：

- **强制测试**：要求 Kiro 为每个功能任务自动生成对应的测试任务。
    
- **文档要求**：要求在每个任务完成后同步更新 `README` 或 `API 文档`。
    
- **技术栈约束**：明确要求在任务描述中使用特定的库（如 TailwindCSS 或 Shadcn/ui）。