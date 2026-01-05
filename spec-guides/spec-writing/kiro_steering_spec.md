# Kiro 规则设定规范（Steering / AGENTS.md）

## 1. 目的
本规范用于统一 Kiro 的“规则/行为设定”文档（Steering files 与 `AGENTS.md`）的**目录结构、文件职责、写法、包含方式与维护策略**，以便：
- 让 Kiro 持续遵守团队约定（技术栈、结构、代码风格、安全规则）
- 降低重复解释成本
- 形成可版本化、可评审、可演进的“项目知识库”

## 2. 概念与官方定义
Kiro 官方定义：Steering 通过 Markdown 文件为 Kiro 提供持久化项目知识与指令，使其在所有交互中持续遵循既定模式与标准。

## 3. 目录与作用域（Scope）

### 3.1 Workspace steering（推荐）
- 位置：`.kiro/steering/`
- 作用：仅对当前仓库/工作区生效

### 3.2 Global steering
- 位置：`~/.kiro/steering/`
- 作用：对所有工作区生效
- 优先级：若与 workspace steering 冲突，**workspace 优先**（官方说明）。

### 3.3 Team steering
- 方式：将全局 steering 作为团队统一分发（如通过 MDM/组策略/集中仓库）

## 4. 基础 steering 文件（Foundational files）
Kiro 支持一键生成三类基础文件（默认每次交互都会加载）：
- `product.md`：产品目的、目标用户、关键功能、业务目标
- `tech.md`：技术栈、框架库、工具、技术约束
- `structure.md`：目录结构、命名/导入约定、架构决策

## 5. 自定义 steering 文件规范

### 5.1 文件职责单一
- 每个文件聚焦一个领域（API 规范、测试规范、部署流程等）。

### 5.2 命名规则
- 使用 `kebab-case`，语义清晰，例如：
  - `api-rest-conventions.md`
  - `testing-standards.md`
  - `security-policies.md`

### 5.3 内容写法
- 使用自然语言 + 必要示例（代码片段、before/after）。
- 说明“为什么”（决策原因）而不仅仅是“做什么”。
- **安全红线**：不得写入 API key、密码、私密 token 等敏感信息（官方强调 steering 属于代码库的一部分）。

## 6. Inclusion modes（包含模式）
Kiro 允许通过 YAML front matter 控制 steering 文件何时被注入上下文。front matter 必须置于文件最顶部。

### 6.1 Always included（默认）
```yaml
---
inclusion: always
---
```
适用：通用规则（技术偏好、安全策略、全局编码规范）。

### 6.2 Conditional inclusion（fileMatch）
```yaml
---
inclusion: fileMatch
fileMatchPattern: "components/**/*.tsx"
---
```
适用：仅对特定文件类型/路径生效的规则。

### 6.3 Manual inclusion
```yaml
---
inclusion: manual
---
```
适用：偶尔需要的大段指南（迁移手册、疑难排障）。
使用方式：在 chat 中通过 `#steering-file-name` 手动引用。

## 7. AGENTS.md 规范
Kiro 支持 `AGENTS.md` 标准：
- 位置：
  - `~/.kiro/steering/`（全局）或
  - 工作区根目录（workspace）
- 行为：**始终包含**（不支持 inclusion modes）。

建议用途：
- 放置“必须遵守”的硬规则（如：必须写测试、提交信息规范、安全基线）。

## 8. File references（引用仓库内文件）
Kiro 支持在 steering 中引用“活的仓库文件”，减少过时：

```text
#[[file:<relative_file_name>]]
```

示例：
- `#[[file:api/openapi.yaml]]`
- `#[[file:components/ui/button.tsx]]`
- `#[[file:.env.example]]`

## 9. 维护与治理（强烈推荐）
- steering 文件作为“可执行标准”，应像代码一样 review。
- 当目录结构调整/技术栈变化时，同步更新相关 steering 与 file references。
- 定期（如每个 sprint 或架构变更时）审查 steering 是否过时。

## 10. 模板

### 10.1 通用 steering 模板
```markdown
---
inclusion: always
---

# <主题> Steering

## 目标

## 规则
- ...

## 示例
```ts
// ...
```

## 反例
- ...
```

### 10.2 API 规范 steering 模板（示例骨架）
```markdown
---
inclusion: fileMatch
fileMatchPattern: "app/api/**/*"
---

# API Standards

## 认证与授权

## 错误响应格式

## 版本策略

## 示例
```

## 11. 参考
- https://kiro.dev/docs/steering/
- https://kiro.dev/docs/getting-started/first-project/
- https://kiro.dev/docs/guides/learn-by-playing/01-improve-the-homepage/
- https://kiro.dev/blog/teaching-kiro-new-tricks-with-agent-steering-and-mcp/
