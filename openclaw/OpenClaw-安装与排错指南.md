# OpenClaw 本地 QuickStart（Linux）安装、配置与“转圈圈”排查

> 适用场景：你在本机（127.0.0.1）运行 OpenClaw Gateway + Control UI，Web UI 里 Chat 发消息一直 loading/转圈，或 WS 连接反复断开。

## 0. 你的环境关键信息（本机示例）

- **Gateway 地址**
  - `http://127.0.0.1:18789/`
- **Gateway 认证模式**：Token
- **Token 保存位置**
  - `~/.openclaw/openclaw.json` → `gateway.auth.token`
  - 或环境变量 `OPENCLAW_GATEWAY_TOKEN`

## 1. 最常见的“转圈圈”原因（优先排查）

### 1.1 Control UI 没带 Token（最常见）

现象：

- Web UI 能打开，但 Chat 一直转圈，或者右上角显示连接问题。
- `journalctl` 里出现类似：
  - `unauthorized: gateway token missing`
  - `reason=token_missing`

解决：

- **务必使用带 token 的 Dashboard URL** 打开 Web UI，例如：
  - `http://127.0.0.1:18789/?token=59d92a1f9c0c6aa1a11a28caa028f761117fe00fe75562c3`
- 或者进入 Control UI 的设置，把 `Gateway Token` 填进去并保存。

验证：

- WS 不再报 `token_missing`。

### 1.2 默认模型字符串没写 provider，导致回退到未配置的 provider

现象：

- 你选择/配置了某个 provider（例如 volcengine），但日志里出现：
  - `Model "ark-code-latest" specified without provider. Falling back to "anthropic/ark-code-latest"`
- 之后发消息会一直 pending 或超时，因为 anthropic 没有配置 API key。

解决：

- 把默认模型写成**完整 id**：`<provider>/<model>`
- 例如：
  - `volcengine/ark-code-latest`

在 `~/.openclaw/openclaw.json` 中（示例片段）：

```json
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "volcengine/ark-code-latest"
      }
    }
  }
}
```

修改后需要重启 gateway。

### 1.4 火山引擎 Ark 报错 `invalid value: developer`

现象：
- 切换到 `volcengine/ark-code-latest` 后，调用报错 `Message ordering conflict`。
- `~/.openclaw/agents/main/sessions/*.jsonl` 日志中出现：`400 The parameter messages.role specified in the request are not valid: invalid value: developer`。

原因：
- 火山引擎的 Ark 接口目前不完全支持 OpenAI 的 `developer` 角色，仅支持 `system`, `user`, `assistant`, `tool`。

解决方法：
- 在 `~/.openclaw/openclaw.json` 的模型定义中显式禁用 `developer` 角色支持：
```json
{
  "id": "ark-code-latest",
  "name": "ark-code-latest",
  "compat": {
    "supportsDeveloperRole": false
  }
}
```
- 修改后需重启 Gateway，并清理当前冲突的会话（`/new` 或手动清空 `sessions.json`）。


- 这类报错通常对应的是“通用 hooks 开关”`hooks.enabled: true`（或等价配置）。在这种模式下，OpenClaw 会强制要求同时配置 `hooks.token`。
- 如果你使用的是 `hooks.internal.enabled: true`（内置 hooks），通常**不需要** `hooks.token`。

解决：

- **要么**先把 hooks 关掉（`hooks.enabled: false`）让 gateway 先稳定跑起来。
- **要么**补齐 `hooks.token` 后再启用 hooks。

## 2. 必备检查：Gateway 服务是否正常运行

### 2.1 systemd（用户服务）状态

```bash
systemctl --user status openclaw-gateway --no-pager
```

你希望看到：

- 服务是 `active (running)`
- 日志里有 `listening on ws://127.0.0.1:18789`

### 2.2 health 检查

```bash
curl -sS -m 2 http://127.0.0.1:18789/health
```

如果 health 不通：

- 先看端口是否被占用、服务是否已退出、或 systemd 日志。

## 3. 快速排查清单（按顺序执行）

### 3.1 先确认你用的是“带 token 的链接”

1) 打开：`http://127.0.0.1:18789/?token=59d92a1f9c0c6aa1a11a28caa028f761117fe00fe75562c3`
2) 刷新页面
3) 再发一句测试消息（如 `ping`）

### 3.2 看 journalctl 的关键错误

```bash
journalctl --user -u openclaw-gateway -n 400 --no-pager | egrep -i 'unauthorized|token_missing|anthropic|api key|apikey|401|403|auth|llm|model|error|exception|timeout|rate'
```

重点关注：

- `token_missing`：UI 没带 token
- `Falling back to "anthropic/..."`：模型 id 写法不对
- `401/403`：provider 的 API key/权限问题
- `timeout`：网络、provider 限流或模型端挂了

### 3.3 看 OpenClaw 临时日志文件

日志里通常会提示模型调用失败的更完整错误（不同版本路径可能不同）：

```bash
tail -n 200 /tmp/openclaw/openclaw-*.log
```

## 4. 常用修复动作

### 4.1 重启 gateway 服务

```bash
systemctl --user restart openclaw-gateway
```

重启后建议立刻验证：

```bash
systemctl --user status openclaw-gateway --no-pager
```

### 4.1.1 重启后查看日志（确认是否真的重启成功）

优先用 OpenClaw 自带日志查看（不依赖你记 systemd 服务名）：

```bash
openclaw logs --limit 200 --plain
```

如果你要持续跟随（类似 tail -f）：

```bash
openclaw logs --follow --plain
```

如果你是用 systemd 用户服务启动的 gateway，也可以直接跟随 systemd 日志：

```bash
journalctl --user -u openclaw-gateway -f --no-pager
```

重启后常见的“健康确认”组合：

```bash
openclaw health
curl -sS -m 2 http://127.0.0.1:18789/health
```

### 4.2 重新拿到 Dashboard token 链接

如果你忘了 token：

- 从配置读：

```bash
cat ~/.openclaw/openclaw.json | sed -n '1,120p'
```

然后在其中找到：

- `gateway.auth.token`

### 4.3 修复“模型 provider 回退”

把模型 id 一律改成 `provider/model` 形式。

示例：

- 错误：`ark-code-latest`
- 正确：`volcengine/ark-code-latest`

修改配置后重启 gateway。

### 4.4 启用 Hooks（需要 hooks.token）

说明：

- 本节针对的是 `hooks.enabled: true` 这类“通用 hooks”模式。
- 如果你只是启用内置 hooks（`hooks.internal.enabled: true`），可跳到本节末尾的“内置 hooks 示例”。

1) 生成一个 token（任选其一）：

```bash
openssl rand -hex 32
```

或：

```bash
python - <<'PY'
import secrets
print(secrets.token_hex(32))
PY
```

2) 写入 `~/.openclaw/openclaw.json`：

```json
{
  "hooks": {
    "enabled": true,
    "token": "<YOUR_HOOKS_TOKEN>"
  }
}
```

3) 重启 gateway：

```bash
systemctl --user restart openclaw-gateway
```

4) 验证端口与健康状态：

```bash
ss -ltnp '( sport = :18789 )'
curl -sS -m 2 http://127.0.0.1:18789/health
```

提示：

- Hooks “开关 + token” 只是让 Hook 机制可用；你仍然需要进一步配置具体有哪些 hook、触发条件和执行动作。

内置 hooks 示例（不需要 hooks.token）：

```json
{
  "hooks": {
    "internal": {
      "enabled": true,
      "entries": {
        "command-logger": { "enabled": true },
        "session-memory": { "enabled": true }
      }
    }
  }
}
```

验证建议：

- 发起几次命令/对话后，观察 `journalctl --user -u openclaw-gateway -n 200 --no-pager` 是否出现 hook 相关日志。
- 如果启用了 `session-memory`，再结合 memory 后端（如 builtin）检查是否有会话记忆被写入（不同版本的查看方式可能不同）。

## 5. 常见问题（FAQ）

### 5.1 Web UI 能打开，但 Chat 只显示转圈

优先检查：

- **是否用带 token 的 URL** 打开的
- `journalctl` 是否有 `token_missing`
- 默认模型是否回退到没配 auth 的 provider

### 5.2 日志出现 embedded run timeout（10 分钟超时）

示例：

- `embedded run timeout ... timeoutMs=600000`

这通常意味着：

- 模型调用没成功（鉴权/网络/限流），请求一直挂起
- 或 provider 响应极慢

处理：

- 先解决 token_missing 与 provider/auth
- 再检查 provider 的 API key、baseUrl、网络连通性

### 5.3 WS 频繁断开 code=1001 / code=1012

- `1012 service restart`：服务在重启（配置热更新触发）
- `1001`：客户端正常断开/刷新

如果同时伴随 `unauthorized`，仍然按 token_missing 处理。

## 6. 建议的最小可用配置（本地）

- **Gateway bind**：loopback（127.0.0.1）
- **Gateway auth**：token（默认）
- **模型**：写全 provider 前缀
- **不要把 token 暴露到公网**（除非你了解并配置了安全策略）

## 7. 你可以贴出来我帮你看（最有效的三样）

- `systemctl --user status openclaw-gateway --no-pager`
- `journalctl --user -u openclaw-gateway -n 200 --no-pager`
- 浏览器 DevTools：`Network -> WS` 或 `Console` 的报错（尤其 401/403/unauthorized）
