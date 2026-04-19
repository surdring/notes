# OpenClaw WhatsApp 开通与排错（2026.2.9）

本文记录在 Ubuntu 本机使用 OpenClaw 2026.2.x 开通 WhatsApp 渠道的**完整流程**，以及常见问题的定位方式。

约定：

- OpenClaw Gateway：本机 `ws://127.0.0.1:18789`
- 配置文件：`~/.openclaw/openclaw.json`
- WhatsApp 账号：`default`

## 0. 前置检查（Gateway 必须可达）

```bash
curl -sS -m 2 http://127.0.0.1:18789/health
systemctl --user status openclaw-gateway --no-pager
```

若 Gateway 不可达，先修复 systemd 启动与 token（见你的安装/重装笔记）。

## 1. 确认 WhatsApp 插件已启用

如果你遇到以下报错：

- `Unknown channel: whatsapp`
- `Unsupported channel: whatsapp`

先启用插件并重启 Gateway：

```bash
openclaw plugins enable whatsapp
systemctl --user restart openclaw-gateway
```

验证：

```bash
openclaw plugins list
openclaw channels list
```

## 2. 配置 WhatsApp 账号（可选，但建议明确写入 access policy）

### 2.1 方案 A（推荐）：白名单放行（dmPolicy=allow + allowFrom）

目标：仅允许你指定的手机号能私聊触发机器人。

在 `~/.openclaw/openclaw.json` 写入：

- `channels.whatsapp.accounts.default.dmPolicy = "allow"`
- `channels.whatsapp.accounts.default.allowFrom = ["+86xxxxxxxxxxx"]`

说明：

- `allowFrom` 使用 **E.164**（例如 `+8613774618186`）。
- 如果你不配置 access policy，WhatsApp DM 常见会走 `pairing` 流程并提示 `access not configured`。

改完建议重启 Gateway 使其加载新配置：

```bash
systemctl --user restart openclaw-gateway
```

## 3. 登录（扫码绑定 WhatsApp Web）

```bash
openclaw channels login --channel whatsapp --account default
```

正常情况下会出现二维码（在终端里），扫码路径：

- WhatsApp → 设置 → 已连接设备（Linked Devices）→ 连接设备 → 扫码

常见成功输出：

- `✅ Linked! Credentials saved for future sends.`
- 或者出现重启提示：
  - `WhatsApp asked for a restart after pairing (code 515); creds are saved. Restarting connection once…`
  - `✅ Linked after restart; web session ready.`

### 3.1 重要：扫码成功后，必要时重启 Gateway

在 2026.2.9 的实际表现中：

- CLI 显示已 `Linked`，但 `openclaw channels status --probe` 仍可能显示 `error:not linked`

此时执行：

```bash
systemctl --user restart openclaw-gateway
openclaw channels status --probe
```

直到看到类似状态：

- `running, connected`

## 4. 验证通道运行状态

```bash
openclaw channels status --probe
```

期望看到：

- `WhatsApp default: enabled, configured, linked, running, connected`

查看 WhatsApp 通道日志（从 gateway 日志文件抽取）：

```bash
openclaw channels logs --channel whatsapp --lines 200
```

典型正常日志：

- `[default] starting provider (+86...)`
- `Listening for personal WhatsApp inbound messages.`

## 5. 处理 "OpenClaw: access not configured"（pairing）

当 WhatsApp 回复类似：

- `OpenClaw: access not configured.`
- `Pairing code: XXXXXXXX`

说明当前 access policy 没放行该号码。

### 5.1 临时处理：approve pairing code

```bash
openclaw pairing approve whatsapp <code>
```

### 5.2 推荐处理：改为方案 A 白名单放行

将 `dmPolicy` 设置为 `allow` 并配置 `allowFrom`，避免每次都 pairing。

## 6. 退出/重绑

退出并清理 WhatsApp Web 凭据：

```bash
openclaw channels logout --channel whatsapp --account default
```

重绑：

```bash
openclaw channels login --channel whatsapp --account default
systemctl --user restart openclaw-gateway
openclaw channels status --probe
```

## 7. 凭据位置（备份/迁移/排错）

- `~/.openclaw/credentials/whatsapp/default/creds.json`
- 回滚备份：`creds.json.bak`

## 8. 常见故障与快速定位

### 8.1 现象：机器人完全没反应

优先按顺序检查：

1. `openclaw channels status --probe` 是否 `running, connected`
2. `openclaw channels logs --channel whatsapp --lines 200` 是否出现 `Listening...`
3. 如果 WhatsApp 收到 `access not configured`，走 pairing approve 或配置 allowFrom

### 8.2 现象：CLI 已 Linked，但 status 还是 not linked

做：

```bash
systemctl --user restart openclaw-gateway
openclaw channels status --probe
```

### 8.3 现象：status 提示 Gateway 不可达（1006）

一般是你刚重启 gateway 的瞬间查询状态导致的短暂断连，稍等几秒后重试即可。

---

最后更新：2026-02-13
