# OpenClaw 重装（卸载 NVM 版 → 切换系统 Node → 全新初始化）（Ubuntu 24.04）

> 适用场景：
>
> - 你之前使用 NVM 的 Node + npm 全局安装了 OpenClaw。
> - 你希望彻底卸载并改用系统 Node（/usr/bin/node，Node 22+）重新安装 OpenClaw。
> - 你希望全新初始化（不保留 ~/.openclaw），重新配置 WhatsApp / Feishu。
>
> 安全基线：
>
> - 不把任何 token / api key / appSecret 写入仓库、截图、聊天记录。
> - 本文中所有密钥均使用占位符表示（如 `<APP_SECRET>`）。

---

## 0. 术语与目标

- **NVM 版 Node**：`~/.nvm/versions/node/.../bin/node`
- **系统 Node**：`/usr/bin/node`（目标：Node 22+）
- **系统 OpenClaw**：通过系统 npm 安装到 `/usr/local/bin/openclaw`（常见）
- **全新初始化**：删除 `~/.openclaw` 后重新运行 `openclaw configure`
- **模型初始化**：初始化模型提供者（Providers）和渠道（Channels）

---

## 1) 停止 OpenClaw Gateway（systemd user）

```bash
systemctl --user stop openclaw-gateway
```

---

## 2) 删除 OpenClaw 数据目录（全新初始化，不备份）

⚠️ 不可逆：会清空配置、会话、凭据等。

```bash
rm -rf ~/.openclaw
```

---

## 3) 卸载 NVM 环境里的 OpenClaw

确认当前 openclaw 来自 NVM（示例）：

```bash
which node
node -v
which npm
npm -v
which openclaw || true
openclaw --version || true
```

卸载：

```bash
npm -g rm openclaw
hash -r
which openclaw || true
openclaw --version || true
```

预期：`openclaw: command not found`。

---

## 4) 安装系统 Node 22+（Ubuntu 24.04）

### 4.1 apt 更新（若遇到第三方源 GPG 过期）

如果 `apt-get update` 因为第三方源（例如 warp）GPG 过期导致告警，通常不会阻止后续安装，但建议你后续单独修该源（或临时禁用）。

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
```

### 4.2 使用 NodeSource 安装 Node 22

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs
```

验证系统 Node：

```bash
/usr/bin/node -v
/usr/bin/npm -v
```

预期：`/usr/bin/node` 存在且版本为 `v22.x`。

---

## 5) 让当前终端使用系统 Node（避免仍指向 NVM）

如果你的 shell 已加载 NVM，`which node` 仍可能指向 `~/.nvm/...`。

在当前终端临时切换到系统 PATH：

```bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
hash -r
which node
node -v
which npm
npm -v
```

预期：

- `which node` → `/usr/bin/node`
- `node -v` → `v22.x`
- `which npm` → `/usr/bin/npm`

---

## 6) 用系统 npm 安装 OpenClaw（全局）

```bash
sudo /usr/bin/npm i -g openclaw@latest
hash -r
which openclaw
openclaw --version
```

预期：

- `which openclaw` → `/usr/local/bin/openclaw`（常见）
- `openclaw --version` 输出版本号

---

## 7) 修正 systemd user service 的 PATH（确保 gateway 使用系统 Node/系统 openclaw）

编辑 drop-in：

```bash
systemctl --user edit openclaw-gateway
```

建议内容（至少包含 PATH；其余环境变量按需保留，但不要写入任何 secret 到仓库）：

```ini
[Service]
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
```

应用并启动：

```bash
systemctl --user daemon-reload
systemctl --user start openclaw-gateway
systemctl --user status openclaw-gateway --no-pager -n 80
```

---

## 8) 全新初始化 OpenClaw 配置

运行配置向导：

```bash
openclaw configure
```

### 8.1 WhatsApp

登录（需要扫码）：

```bash
openclaw channels login whatsapp
```

### 8.2 Feishu

按 OpenClaw 文档推荐：优先使用 **WebSocket 长连接模式**。

你需要准备：

- `appId`: `<FEISHU_APP_ID>`
- `appSecret`: `<FEISHU_APP_SECRET>`

注意：`appSecret` 只放在本机配置中，不要出现在任何仓库文件/截图。

---

## 9) 双 Agent + 路由建议（可选，但推荐）

目标：

- Feishu → `butler`（默认模型 `volcengine/ark-code-latest`）
- WhatsApp → `main`（固定模型例如 `llama/gpt-oss-20b`）

建议做法：

- `agents.list` 定义 `main` 与 `butler`，并设置 `butler.default=true`
- `bindings` 显式绑定：
  - `whatsapp accountId=*` → `main`
  - `feishu accountId=*` → `butler`

然后验证：

```bash
openclaw agents list --bindings
```

---

## 10) 健康检查（必做）

```bash
openclaw channels status --probe
openclaw health
```

---

## 11) 常见排错

### 11.1 `which node` 仍指向 NVM

- 这是 shell 初始化加载 NVM 的结果。
- 对于“临时执行一次系统 node”，用第 5 节 `export PATH=...` 即可。
- 对于“systemd 永久使用系统 node”，用第 7 节在 service drop-in 固定 PATH。

### 11.2 `apt-get update` 被第三方源 GPG 过期干扰

- 优先修复/更新该源的 key；或临时禁用该源。
- 但通常不影响 NodeSource/nodejs 的安装。

---

## 12) 验收标准

- `openclaw --version` 可用，且来自系统安装路径（通常 `/usr/local/bin/openclaw`）
- `systemctl --user status openclaw-gateway` 显示 running
- `openclaw channels status --probe` 显示 gateway reachable，WhatsApp/Feishu 按预期 running
- Feishu/WhatsApp 实际对话可收发
