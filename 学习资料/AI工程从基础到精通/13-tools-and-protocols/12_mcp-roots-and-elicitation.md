# Roots 与 Elicitation —— 作用域限定与流程中途的用户输入

> 硬编码路径在用户打开不同项目的那一刻就失效了。预填的工具参数在用户说明不足时也会失效。Roots 将服务器的访问范围限定在用户控制的一组 URI 中；Elicitation 在工具调用中途暂停，通过表单或 URL 向用户请求结构化输入。两个客户端原语，解决了两种常见的 MCP 失败模式。SEP-1036（URL 模式引导，2025-11-25）在 2026 年上半年仍是实验性的——依赖之前请检查 SDK 版本。

**类型：** 构建
**语言：** Python（标准库，roots + elicitation 演示）
**前置知识：** Phase 13 · 07（MCP 服务器）
**时间：** ~45 分钟

## 学习目标

- 声明 `roots` 并响应 `notifications/roots/list_changed`。
- 将服务器文件操作限制在声明的 root 集合内的 URI。
- 使用 `elicitation/create` 在工具调用中途向用户请求确认或结构化输入。
- 在表单模式（Form Mode）和 URL 模式（URL Mode）引导之间做出选择（后者是实验性的；漂移风险已标注）。

## 问题

一个笔记 MCP 服务器在生产中遇到的两个具体失败。

**路径假设破裂。** 服务器是针对 `~/notes` 编写的。一个用户在不同的机器上，笔记在 `~/Documents/Notes` 中，工具调用静默失败（找不到文件），或者更糟，写入到了错误位置。

**用户知道但缺失的参数。** 用户要求"删除旧的 TPS 报告笔记"。模型调用 `notes_delete(title: "TPS report")`，但 2023、2024 和 2025 年有三条匹配的笔记。工具无法猜测。返回"模糊"很恼人；对三条都执行是灾难性的。

Roots 解决第一个问题：客户端在 `initialize` 时声明服务器可以访问的 URI 集合。Elicitation 解决第二个问题：服务器暂停工具调用并发送 `elicitation/create`，请求用户选择哪一个。

## 核心概念

### Roots

客户端在 `initialize` 时声明 root 列表：

```json
{
  "capabilities": {"roots": {"listChanged": true}}
}
```

服务器然后可以调用 `roots/list`：

```json
{"roots": [{"uri": "file:///Users/alice/Documents/Notes", "name": "Notes"}]}
```

服务器 MUST 将 roots 视为边界：任何 root 集之外的文件读取或写入都被拒绝。这不是由客户端强制执行的（服务器仍然是用户信任的代码），但符合规范的服务器会遵守这一点。

当用户添加或移除 root 时，客户端发送 `notifications/roots/list_changed`。服务器重新调用 `roots/list` 并更新其边界。

### 为什么 roots 是客户端原语

Roots 由客户端声明，因为它们代表用户的同意模型。用户告诉 Claude Desktop"让这个笔记服务器访问这两个目录"。服务器不能扩大这个范围。

### Elicitation：默认的表单模式

`elicitation/create` 接收一个表单 Schema 加上一个自然语言提示词：

```json
{
  "method": "elicitation/create",
  "params": {
    "message": "Delete 'TPS report'? Multiple notes match; pick one.",
    "requestedSchema": {
      "type": "object",
      "properties": {
        "note_id": {
          "type": "string",
          "enum": ["note-3", "note-7", "note-14"]
        },
        "confirm": {"type": "boolean"}
      },
      "required": ["note_id", "confirm"]
    }
  }
}
```

客户端渲染一个表单，收集用户的答案，返回：

```json
{
  "action": "accept",
  "content": {"note_id": "note-14", "confirm": true}
}
```

三种可能的操作：`accept`（用户填写了）、`decline`（用户关闭了）、`cancel`（用户中止了整个工具调用）。

表单 Schema 是扁平的——v1 中不支持嵌套对象。SDK 通常拒绝任何比单层更复杂的内容。

### Elicitation：URL 模式（SEP-1036，实验性）

2025-11-25 新增。服务器发送一个 URL 而不是 Schema：

```json
{
  "method": "elicitation/create",
  "params": {
    "message": "Sign in to GitHub",
    "url": "https://github.com/login/oauth/authorize?client_id=..."
  }
}
```

客户端在浏览器中打开 URL，等待完成，在用户返回后返回。适用于 OAuth 流程、支付授权和文档签名——这些场景中表单是不够的。

漂移风险提示：SEP-1036 的响应形态仍在稳定中；有些 SDK 返回回调 URL，有些返回完成 Token。在生产环境中使用 URL 模式之前，请阅读 SDK 的发布说明。

### 何时引导是合适的工具

- 破坏性操作前的用户确认（destructive hint + elicitation）。
- 消歧（从 N 个候选中选一个）。
- 首次运行设置（API 密钥、目录、偏好）。
- OAuth 风格的流程（URL 模式）。

### 何时引导是错误的

- 填充模型本来可以用散文询问的工具必填参数。使用正常的重新提示，而不是引导对话框。
- 高频率调用。引导中断对话；不要在循环内触发它。
- 服务器可以在事后验证的任何内容。验证、返回错误、让模型在文本中询问用户。

### 人在回路中的桥接

Elicitation 加上 Sampling（采样）共同实现了 MCP 的"人在回路中"模型。服务器的 Agent 循环可以暂停等待用户输入（Elicitation）或模型推理（Sampling）。Phase 13 · 11 涵盖采样；本课涵盖引导。将它们组合起来实现完整的循环中途控制。

## 使用它

`code/main.py` 扩展笔记服务器，新增：

- `roots/list` 响应，服务器在 root 列表变更通知后重新查询。
- 一个 `notes_delete` 工具，当多条笔记匹配时使用 `elicitation/create` 进行消歧。
- 一个 `notes_setup` 工具，使用 URL 模式引导打开首次运行配置页面（模拟）。
- 边界检查，拒绝在声明 roots 之外的 URI 上的操作。

演示运行三种场景：顺利路径（一条匹配）、消歧（三条匹配，引导触发）、root 外写入（被拒绝）。

## 交付成果

本课产出 `outputs/skill-elicitation-form-designer.md`。给定一个可能需要用户确认或消歧的工具，该技能设计引导表单 Schema 和消息模板。

## 练习

1. 运行 `code/main.py`。触发消歧路径；确认模拟的用户答案被路由回工具。

2. 添加一个新工具 `notes_archive`，每次都需要引导确认（destructive hint）。检查 UX：这与模型在文本中重新询问相比如何？

3. 为首次运行 OAuth 流程实现 URL 模式引导。注意漂移风险，添加 SDK 版本守卫。

4. 扩展 `roots/list` 处理：当通知到达时，服务器应原子性地重新读取并重新扫描现在可能超出范围的打开文件句柄。

5. 阅读 GitHub 上的 SEP-1036 问题讨论线程。找出一个影响服务器应如何处理 URL 模式回调的未决问题。

## 关键术语

| 术语 | 人们的说法 | 实际含义 |
|------|----------------|------------------------|
| Root | "同意边界" | 客户端允许服务器访问的 URI |
| `roots/list` | "服务器请求范围" | 客户端返回当前的 root 集合 |
| `notifications/roots/list_changed` | "用户更改了范围" | 客户端发出信号 root 集合已变更 |
| Elicitation | "调用中途询问用户" | 服务器发起结构化用户输入请求 |
| `elicitation/create` | "该方法" | 用于引导请求的 JSON-RPC 方法 |
| 表单模式（Form Mode） | "Schema 驱动表单" | 在客户端 UI 中渲染为表单的扁平 JSON Schema |
| URL 模式（URL Mode） | "浏览器重定向" | SEP-1036 实验性；打开 URL 并等待 |
| `accept` / `decline` / `cancel` | "用户响应结果" | 服务器处理的三个分支 |
| 消歧（Disambiguation） | "选一个" | 常见的引导用例，当工具有 N 个候选时 |
| 扁平表单（Flat Form） | "仅顶层属性" | 引导 Schema 不能嵌套 |

## 延伸阅读

- [MCP — Client roots spec](https://modelcontextprotocol.io/specification/draft/client/roots) —— Roots 权威参考
- [MCP — Client elicitation spec](https://modelcontextprotocol.io/specification/draft/client/elicitation) —— Elicitation 权威参考
- [Cisco — What's new in MCP elicitation, structured content, OAuth enhancements](https://blogs.cisco.com/developer/whats-new-in-mcp-elicitation-structured-content-and-oauth-enhancements) —— 2025-11-25 新增内容演练
- [MCP — GitHub SEP-1036](https://github.com/modelcontextprotocol/modelcontextprotocol) —— URL 模式引导提案（实验性，漂移风险）
- [The New Stack — How elicitation brings human-in-the-loop to AI tools](https://thenewstack.io/how-elicitation-in-mcp-brings-human-in-the-loop-to-ai-tools/) —— UX 演练