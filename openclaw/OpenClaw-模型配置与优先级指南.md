# OpenClaw 模型配置与优先级指南

本文档详细介绍了如何在 OpenClaw 中配置 Agent 模型，以及 Cron 任务中的模型覆盖逻辑与优先级。

## 1. 模型优先级

OpenClaw 的模型选择遵循以下优先级顺序（从高到低）：

1.  **Cron 任务私有配置**：通过 `openclaw cron edit --model <model_id>` 设置。
```bash
openclaw cron edit 9e0bd11b-a08e-4bee-97d1-375d64b79095 --model llama/gpt-oss-20b
```

2.  **Agent 实例配置**：在 `~/.openclaw/openclaw.json` 的 `agents.list` 中为特定 Agent 设置。


3.  **全局 Agent 默认配置**：在 `~/.openclaw/openclaw.json` 的 `agents.defaults.model` 中设置。

```json
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "volcengine/ark-code-latest"
      },
      "models": {
        "volcengine/ark-code-latest": {},
        "llama/gpt-oss-20b": {}
      },
      "workspace": "/home/surdring/.openclaw/workspace",
      "maxConcurrent": 4,
      "subagents": {
        "maxConcurrent": 8
      },
      "compaction": {
        "mode": "safeguard"
      }
    },
    "list": [
      {
        "id": "main",
        "default": true,
        "workspace": "/home/surdring/.openclaw/workspace",
        "agentDir": "/home/surdring/.openclaw/agents/main/agent"
      },
      {
        "id": "butler",
        "model": {
          "primary": "llama/gpt-oss-20b"
        },
        "workspace": "/home/surdring/.openclaw/workspace-butler",
        "agentDir": "/home/surdring/.openclaw/agents/butler/agent"
      }
    ]
  }
}
```
---

## 2. Agent 默认模型配置

这是管理特定机器人（如 `butler`）最常用的方式。

### 2.1 配置文件位置
`~/.openclaw/openclaw.json`

### 2.2 配置示例
在 `agents.list` 数组中找到目标 Agent，修改其 `model.primary` 字段：

```json
{
  "agents": {
    "list": [
      {
        "id": "butler",
        "model": {
          "primary": "llama/gpt-oss-20b"
        }
      }
    ]
  }
}
```

### 2.3 常用模型 ID
- **本地 Llama**：`llama/gpt-oss-20b`
- **火山引擎 Ark**：`volcengine/ark-code-latest`

---

## 3. Cron 任务模型覆盖

Cron 任务默认会继承所属 Agent 的模型设置。但你可以为特定任务设置独立的模型。

### 3.1 查看当前 Cron 配置
使用 JSON 格式查看任务详情，确认是否存在 `model` 覆盖：
```bash
openclaw cron list --json
```

### 3.2 修改 Cron 私有模型
使用 CLI 命令直接修改：
```bash
openclaw cron edit <job_id> --model "volcengine/ark-code-latest"
```

### 3.3 移除覆盖（使其跟随 Agent 默认设置）
若要让 Cron 任务自动同步 Agent 的修改，请将 `model` 设为空字符串：
```bash
openclaw cron edit <job_id> --model ""
```

---

## 4. 重启生效

所有的 `openclaw.json` 配置修改后，必须重启 Gateway 才能生效：

```bash
systemctl --user restart openclaw-gateway
```

---

## 5. 常见问题：为什么修改了 Agent 模型，Cron 任务没变？

**原因**：该 Cron 任务存在“私有模型覆盖”。
**检查**：执行 `openclaw cron list --json`，观察该任务的 `payload.model` 字段。如果该字段不为空，它将无视 Agent 的默认设置。
**解决**：参考 [3.3 节](#33-移除覆盖使其跟随-agent-默认设置) 移除覆盖即可。
