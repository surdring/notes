# OpenClaw 双 Agent + 双 Feishu accounts + bindings 配置与路由绑定指南

> 目标：在 **同一个 OpenClaw Gateway 实例**中配置 **两个 Feishu 机器人账号**，并通过 `bindings` 把不同 Feishu 账号的消息路由到不同 Agent。

- `feishua` -> `main`
- `feishub` -> `butler`
- 默认模型（两套 Agent 的默认模型）：`volcengine/ark-code-latest`

本指南包含：
- 关键配置项说明
- 从零配置的步骤
- 必须的重启与验证命令
- 常见坑与排错（尤其是 `accountId` 大小写问题）

---

## 0. 前置条件

- 已安装 OpenClaw CLI，并且 `openclaw` 可用
- Gateway 可启动：

```bash
curl -sS -m 2 http://127.0.0.1:18789/health
```

- 已准备两套飞书自建应用（两个 Bot）：
  - 每套都有自己的 `App ID` 与 `App Secret`
  - 两个应用都启用了机器人能力，并已发布/生效

> 安全：本文件不会写入任何密钥。`App Secret` 不要提交到仓库/文档中。

---

## 1. 配置文件位置

OpenClaw 主配置文件：

- `~/.openclaw/openclaw.json`

---

## 2. 配置目标结构概览

你需要在 `openclaw.json` 同时具备以下 3 块内容：

1) `agents.list`：声明两个 Agent（`main`、`butler`）
2) `channels.feishu.accounts`：声明两个 Feishu 账号（**accountId 建议全小写**）
3) `bindings`：将 `feishu + accountId` 映射到 Agent

---

## 3. Step-by-step 配置过程

### 3.1 创建第二个 Agent（butler）目录

按你的实际路径创建 `workspace` 与 `agentDir`：

- `~/.openclaw/workspace-butler`
- `~/.openclaw/agents/butler/agent`

（如果你使用的是 OpenClaw 自动创建，也可以跳过手动 mkdir；但目录不存在时建议先建好。）

---

### 3.2 在 `agents` 里声明两个 Agent

在 `openclaw.json` 的 `agents.list` 中包含两项：

```json
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "volcengine/ark-code-latest"
      }
    },
    "list": [
      {
        "id": "main",
        "default": true,
        "workspace": "/home/USER/.openclaw/workspace",
        "agentDir": "/home/USER/.openclaw/agents/main/agent"
      },
      {
        "id": "butler",
        "workspace": "/home/USER/.openclaw/workspace-butler",
        "agentDir": "/home/USER/.openclaw/agents/butler/agent"
      }
    ]
  }
}
```

---

### 3.3 配置 Feishu Channel 的两个账号（accounts）

在 `channels.feishu.accounts` 下配置两个账号。

**强烈建议 `accountId` 全小写**（例如 `feishua`、`feishub`），因为运行时会对 `accountId` 做 normalize，小写不一致会导致 “configured 但不生效/绑定不命中”。

示例（将 `APP_ID_*` / `APP_SECRET_*` 替换为你的真实值）：

```json
{
  "channels": {
    "feishu": {
      "connectionMode": "websocket",
      "accounts": {
        "feishua": {
          "appId": "APP_ID_A",
          "appSecret": "APP_SECRET_A"
        },
        "feishub": {
          "appId": "APP_ID_B",
          "appSecret": "APP_SECRET_B"
        }
      }
    }
  }
}
```

说明：
- `connectionMode: "websocket"` 表示使用飞书“长连接”方式接收事件。

---

### 3.4 配置 bindings：把不同账号路由到不同 Agent

在根级 `bindings` 添加 2 条规则：

```json
{
  "bindings": [
    {
      "agentId": "main",
      "match": {
        "channel": "feishu",
        "accountId": "feishua"
      }
    },
    {
      "agentId": "butler",
      "match": {
        "channel": "feishu",
        "accountId": "feishub"
      }
    }
  ]
}
```

---

### 3.5 启用 Feishu 插件

确认配置里：

```json
{
  "plugins": {
    "entries": {
      "feishu": { "enabled": true }
    }
  }
}
```

---

## 4. 重启与验证（必做）

### 4.1 重启 Gateway

```bash
systemctl --user restart openclaw-gateway
```

### 4.2 验证 bindings 是否生效

```bash
openclaw agents list --bindings
```

预期看到：
- `main` 有 `feishu accountId=feishua`
- `butler` 有 `feishu accountId=feishub`

### 4.3 验证 channel 健康

```bash
openclaw channels status --probe
```

预期看到：
- `Feishu feishua: enabled, configured, running, works`
- `Feishu feishub: enabled, configured, running, works`

---

## 5. 端到端路由验证（发 ping 看落到哪个 agent）

1) 用 FeishuA 对应的 bot（`feishua`）发 `ping`
2) 用 FeishuB 对应的 bot（`feishub`）发 `ping`

然后查看 Feishu channel 日志：

```bash
openclaw channels logs --channel feishu --lines 200
```

在日志中定位两类关键行：

- `feishu[feishua]: dispatching to agent (session=agent:main:main)`
- `feishu[feishub]: dispatching to agent (session=agent:butler:main)`

只要看到第二行，说明 `feishub -> butler` 路由成功。

---

## 6. 常见坑与排错

### 6.1 `Feishu <id>: not configured` / `No Feishu accounts configured`

典型原因：
- `channels.feishu.accounts` 未配置/层级不对
- `accountId` 大小写不一致导致运行时索引不到

处理建议：
- 把 `channels.feishu.accounts` 的 key 全部改成小写
- 把 `bindings.match.accountId` 同步改成小写
- 重启 gateway 后再看 `openclaw channels status --probe`

---

### 6.2 配置“看起来对了”，但消息仍然落到 `main`

典型原因：
- `bindings.match.accountId` 写成了 `feishuA/feishuB`（含大写），运行时 normalize 成小写后不命中

修复：
- 统一使用 `feishua/feishub`（全小写）
- 重启 gateway
- 再看 `channels logs` 里的 `dispatching to agent (session=...)`

---

### 6.3 飞书后台长连接配置

当你使用 `connectionMode: websocket` 时，飞书侧需要开启“长连接接收事件/回调”。

如果 Feishu 账号显示 configured 但不 work / 收不到消息，优先检查：
- 飞书开发者后台 -> 事件与回调 -> 订阅方式 -> 长连接
- 应用权限范围是否满足收消息/发消息所需

---

## 7. 安全提醒（必须做）

- 如果你曾在聊天/日志/截图中暴露过 `App Secret`，请尽快去飞书开发者后台 **重新生成并替换**。
- `openclaw.json` 属于敏感配置文件，建议设置好系统权限与备份策略，避免被同步到公共位置。
