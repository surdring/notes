# OpenClaw Feishu（WebSocket / 长连接模式）后台配置与排错清单

> 适用场景：**不计划暴露公网回调**，使用 `channels.feishu.connectionMode: "websocket"`，由 OpenClaw 主动与飞书建立长连接来接收事件。

本清单目标：
- 让 Feishu Bot 在 OpenClaw 中显示 `configured + running + works`
- 能收消息、能回消息
- 双 Bot / 多 accountId 时，路由 bindings 能稳定命中

---

## 1. OpenClaw 侧关键配置（只列必须项）

`~/.openclaw/openclaw.json`：

- `plugins.entries.feishu.enabled: true`
- `channels.feishu.connectionMode: "websocket"`
- `channels.feishu.accounts.<accountId>.appId/appSecret` 配置齐全
- `bindings.match.accountId` 与 `channels.feishu.accounts` 的 key 一致

### 1.1 accountId 统一小写（强制建议）

实践中 `accountId` 会被 normalize，**建议全部使用小写**，否则可能出现：
- `channels list/status` 里显示账号为小写（例如 `feishua`），但配置里是 `feishuA`
- 进而导致：账号 “not configured” 或 bindings 不命中，消息回落到默认 agent

推荐：
- `feishua`、`feishub`（而不是 `feishuA/feishuB`）

---

## 2. 飞书开发者后台：必须核对的 3 块

以下每个自建应用（每个 Bot）都需要配置一遍。

### 2.1 应用类型与发布状态

- **自建应用**（企业自建 / 开发者自建）
- 应用处于可用状态（已发布到企业内可用 / 或已完成必要的发布流程）

如果未发布/未生效，常见现象：
- `configured` 但收不到事件
- 或 token 获取失败、权限不足

### 2.2 机器人能力与权限（Scope）

至少要具备“收消息/发消息”相关权限，否则常见现象：
- 能收到但不能回复
- 或回复时报 `permission denied`

建议做法：
- 先只开最小可用权限让“收发消息”跑通
- 需要文档/云盘/wiki 等能力时再按需加权限

> 你看到的日志中某些 Feishu 工具（如 bitable）提示“credentials not configured”并不影响基础收发；那是附加工具模块的额外能力。

### 2.3 事件与回调：订阅方式（关键）

在飞书开发者后台：

- **事件与回调**
  - **订阅方式**：选择/启用
    - “使用长连接接收事件/回调”（WebSocket / persistent connection）

如果这里没切到长连接，典型现象：
- OpenClaw 侧会提示类似：
  - `receive events ... through persistent connection ... Configured in Developer Console -> Events and Callbacks -> Mode ...`
- 可能出现 `running` 但始终收不到消息事件

---

## 3. 启动与健康检查（你每次改完配置都建议跑）

### 3.1 重启 gateway

```bash
systemctl --user restart openclaw-gateway
```

### 3.2 看配置是否被识别

```bash
openclaw channels list
openclaw channels status --probe
```

预期：
- `Feishu <accountId>: configured, enabled`
- `Feishu <accountId>: running, works`

### 3.3 看绑定是否生效

```bash
openclaw agents list --bindings
```

预期：
- 对每个 agent 都能看到对应的 `feishu accountId=...`

---

## 4. 端到端验证（推荐做成固定验收步骤）

1) 用该 Bot 对应的飞书账号给机器人发 `ping`
2) 拉 Feishu channel 日志：

```bash
openclaw channels logs --channel feishu --lines 200
```

你要找的关键行是：

- `feishu[<accountId>]: received message ...`
- `feishu[<accountId>]: dispatching to agent (session=agent:<agentId>:main)`

如果是双 Bot：
- `feishua` 应该落到 `agent:main:main`
- `feishub` 应该落到 `agent:butler:main`

---

## 5. 常见问题与快速定位

### 5.1 状态显示 `not configured`

优先检查：
- `plugins.entries.feishu.enabled` 是否为 `true`
- `channels.feishu.accounts` 是否真的存在（层级/拼写正确）
- `accountId` 是否大小写不一致（建议统一小写）

### 5.2 `works` 但收不到消息

优先检查飞书后台：
- 事件与回调 -> 订阅方式 -> 是否启用“长连接接收事件/回调”
- 应用是否已发布/生效

### 5.3 消息总是落到 default agent（例如总是 `main`）

优先检查：
- `bindings.match.accountId` 是否与运行时的 `accountId` 一致（尤其大小写）
- 是否存在更高优先级的绑定（peer 绑定会覆盖 accountId 绑定）

你可以用这个最小检查法确认当前 `openclaw.json` 里的 bindings 是否包含 peer：
- bindings 里如果出现 `match.peer`，它优先级高于 `match.accountId`

### 5.4 偶发断连

- 先重启：`systemctl --user restart openclaw-gateway`
- 再看：`openclaw channels status --probe`
- 需要更深排查时：

```bash
openclaw logs --limit 200 --plain
```

---

## 6. 最小安全建议

- 不用 webhook 的情况下：**不要开公网端口**，只要能出网即可
- 不要在文档/仓库/聊天记录中保存 `appSecret`
- 如果 secret 已暴露：尽快在飞书后台重置，并更新 `openclaw.json`
