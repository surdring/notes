# OpenClaw：不同任务使用不同模型（/model、Sub-agents、Cron override）

本文档面向你当前的本地 OpenClaw Gateway（`18789`）+ 多 provider（例如 `llama.cpp` 与 `volcengine`）配置，解释并给出可落地的“按任务使用不同模型”的用法。

OpenClaw 官方推荐的三种方式：

- **会话内临时切换**：`/model`（最简单、最直观）
- **多 Agent / Sub-agents 路由**：把任务交给不同 agent，每个 agent 默认模型不同（最适合“不同功能/不同工作流用不同模型”）
- **Cron job per-job override**：定时/隔离任务可以为每个 job 单独指定模型（最适合自动化）

> 重点：通常不是“给每个 skill 固定绑定模型”，而是按 **会话 / agent / job** 来控制模型。

---

## 0. 先明确你现在有哪些模型可用

### 0.1 模型 ID 的格式

OpenClaw 里模型一般用 `provider/modelId` 表示，例如：

- `llama/gpt-oss-20b`
- `volcengine/ark-code-latest`

### 0.2 你的当前默认模型在哪里设置

默认主模型来自：

- `~/.openclaw/openclaw.json` → `agents.defaults.model.primary`

例如（示意）：

```json
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "llama/gpt-oss-20b"
      }
    }
  }
}
```

---

## 1) 会话内临时切模型：`/model`

适用场景：

- 你正在一个对话里工作，突然希望接下来的回答/推理/工具调用换个模型
- 例如：平时用本地 `llama.cpp`，遇到复杂 coding 再切到 `volcengine`

### 1.1 基本用法

在 Control UI 的聊天输入框直接输入：

```text
/model llama/gpt-oss-20b
```

或：

```text
/model volcengine/ark-code-latest
```

```bash
# 命令行切换模型和测试
openclaw message "ping" --model llama/gpt-oss-20b
openclaw agent --local --agent main -m "ping"

# 强制新建一个 session 再用 volcengine
openclaw models set volcengine/ark-code-latest
openclaw agent --local --agent main --session-id "test-$(date +%s)" -m "ping"
```

### 1.2 如何验证已经切换成功

- **方式 A（最直接）**：Control UI 顶部/右侧如果有“当前模型”显示，会随之变化
- **方式 B（日志）**：查看 `/tmp/openclaw/openclaw-YYYY-MM-DD.log`，搜索 `model=`、`provider=`、`llama`/`volcengine`

建议过滤：

```bash
rg -n "(model=|provider=|llama|volcengine)" /tmp/openclaw/openclaw-$(date +%F).log | tail -n 200
```

> 如果你用的是 LAN 的 `llama.cpp`，也可以在 `llama.cpp` 服务端日志里看到对应请求。

### 1.3 常见坑

- 如果你只写 `ark-code-latest` 不写 provider，可能会触发“provider 选择/回退”。**建议始终用 `provider/modelId` 的完整写法**。

---

## 2) Sub-agents / 多 Agent 路由：给不同“功能”配不同模型

适用场景：

- 你希望“写代码/重推理”自动走强模型，“日常对话/轻任务”走本地模型
- 你希望不同工作流（比如：总结、翻译、代码审查）由不同 agent 执行

核心思想：

- **主 agent**负责对话、拆解任务、决定把子任务交给哪个 sub-agent
- **不同 sub-agent**有不同默认模型

### 2.1 在 UI 里的最小操作路径（通用）

1. 打开会话
2. 用 `/subagents` 查看/管理子代理（如果你的版本支持该命令）
3. 创建/选择一个子代理（例如 `coder`）
4. 给该子代理设置不同的默认模型（例如 `volcengine/ark-code-latest`）

> 具体 UI 文案可能因版本不同略有差异；如果 UI 没有完整的创建入口，通常也能通过配置项来设默认值。

### 2.2 常见配置项（用于“默认子代理模型”）

FAQ 提到可用配置：

- `agents.defaults.subagents.model`

含义：当系统创建/使用 sub-agent 时，如果没有更细的 override，就用这个模型。

> 注意：不同版本的 schema 可能有差异。如果你打算在 `openclaw.json` 里配置，我建议先用 `openclaw doctor` 或查对应版本文档确认字段是否生效。

### 2.3 推荐的路由策略（实战）

你可以按下面的“人工规则”让主 agent 路由：

- **Coding / Debug / 大改动** → sub-agent（强模型：`volcengine/ark-code-latest`）
- **问答 / 总结 / 轻量任务** → 主 agent（本地模型：`llama/gpt-oss-20b`）

这在体验上就等价于“不同任务用不同模型”。

---

## 3) Cron job per-job override：按定时任务指定模型

适用场景：

- 每天定时总结
- 每小时检查某个指标/日志
- 后台自动跑一个隔离任务，把结果发到某个 chat

特点：

- Cron 任务是 **隔离** 的：你可以给每个 job 单独指定模型，不影响你的交互会话

### 3.1 你需要先满足的条件

- `cron.enabled` 需要开启（若版本有该配置）
- Gateway 需要常驻运行（不能休眠/频繁退出）

### 3.2 “每个 job 设 model override”的用法

官方 FAQ 明确：

- “Cron jobs: isolated jobs can set a model override per job.”

具体怎么写取决于你的 cron job 配置文件格式/版本。你可以按下面方式定位：

1. 打开文档：`https://docs.openclaw.ai/automation/cron-jobs`
2. 查找字段：`model` / `modelOverride` / `override` / `agent`

### 3.3 验证 cron 是否生效

（根据 FAQ）可用：

- `openclaw cron run <jobId> --force`
- `openclaw cron runs --id <jobId> --limit 50`

---

## 4) “按技能固定用某模型”这件事怎么做？（推荐替代法）

如果你的真实诉求是：

- “只要调用某个技能，就一定用强模型”

更稳妥的实现通常是：

- 让主 agent 在“将要调用该技能”的那一步：
  - **先切模型**（`/model ...`），或
  - **把该子任务交给指定 sub-agent**（该 agent 默认模型固定）

原因：

- Skills 通常是工具/动作集合，模型选择更像是“决策与推理层”的策略；把策略放在 agent / job 层更可控。

---

## 5) 快速参考：三种方式怎么选

- **我只想临时切一下，马上生效**
  - 用 `/_model`（实际命令是 `/model`）

- **我想稳定地把不同功能分给不同模型**
  - 用 Sub-agents / Multi-Agent Routing

- **我想定时任务各跑各的，互不影响**
  - 用 Cron job per-job model override

---

### 6.1 特殊模型兼容性处理（火山引擎 Ark）

如果你在使用 `volcengine/ark-code-latest` 时遇到 `Message ordering conflict` 报错，通常是因为 Ark 不支持 `developer` 角色。

**修复配置**：
在 `openclaw.json` 的模型定义中增加 `compat` 字段：
```json
{
  "id": "ark-code-latest",
  "compat": { "supportsDeveloperRole": false }
}
```
这将强制将系统提示作为 `system` 角色发送，从而解决兼容性导致的 400 错误。

---

## 7) 排错与观察（当你怀疑“没走我选的模型”）

- 看当前会话是否切过模型：用 `/model` 看当前状态（若命令支持展示）
- 看 gateway 日志：`/tmp/openclaw/openclaw-YYYY-MM-DD.log`
- 如果走的是 `llama.cpp`：看 `llama.cpp` 服务端是否收到 `/v1/chat/completions` 或 `/v1/completions` 请求
- 如果 UI 里显示多个模型：通常代表你配置了多个 provider；关键是**当前会话选择**以及**默认模型**是谁
