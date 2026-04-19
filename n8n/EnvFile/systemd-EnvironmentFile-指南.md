# n8n 使用 systemd EnvironmentFile 注入环境变量（$env）指南

## 目标

让 n8n 工作流里通过 `$env.xxx` 读取到系统环境变量（例如 `BRAVE_SEARCH_API_KEY`、`FEISHU_BOT_WEBHOOK_URL`、`LLAMA_CPP_BASE_URL`、`LLAMA_CPP_MODEL`）。

如果你的本地模型 API 也启用了鉴权（API Key），同样建议通过环境变量注入，例如 `LLAMA_CPP_API_KEY`。

该方式适用于：n8n 以 systemd service 形式运行（无论是 system service 还是 user service）。

## 1. 创建环境变量文件（推荐独立文件，便于权限控制）

建议路径（按你的实际运行方式二选一）：

- 若 n8n 以 **用户服务**运行：`~/.config/n8n/env`
- 若 n8n 以 **系统服务**运行：`/etc/n8n/env`（或 `/etc/default/n8n`）

说明：

- `/etc/n8n/` 是目录
- `/etc/n8n/env` 是文件（EnvironmentFile 会读取这个文件并注入环境变量）

### 1.1 用户服务：创建目录与 env 文件（完整命令）

```bash
mkdir -p ~/.config/n8n
cat > ~/.config/n8n/env <<'EOF'
BRAVE_SEARCH_API_KEY=REDACTED
FEISHU_BOT_WEBHOOK_URL=https://open.feishu.cn/open-apis/bot/v2/hook/491a7256-b700-45e7-bdb0-30323aa8317b
LLAMA_CPP_BASE_URL=http://127.0.0.1:8080
LLAMA_CPP_MODEL=gpt-oss-20b
LLAMA_CPP_API_KEY=sk-local-gpt20b
EOF

chmod 600 ~/.config/n8n/env
```

### 1.2 系统服务：创建目录与 env 文件（完整命令）

```bash
sudo mkdir -p /etc/n8n
sudo tee /etc/n8n/env >/dev/null <<'EOF'
BRAVE_SEARCH_API_KEY=BSAmcnrtr9Geq782bICLeGPwingahxb
FEISHU_BOT_WEBHOOK_URL=https://open.feishu.cn/open-apis/bot/v2/hook/491a7256-b700-45e7-bdb0-30323aa8317b
LLAMA_CPP_BASE_URL=http://127.0.0.1:8080
LLAMA_CPP_MODEL=gpt-oss-20b
LLAMA_CPP_API_KEY=sk-local-gpt20b
EOF

sudo chown root:root /etc/n8n/env
sudo chmod 600 /etc/n8n/env
```

文件内容示例（不要写入仓库；值仅示意）：

```bash
BRAVE_SEARCH_API_KEY=REDACTED
FEISHU_BOT_WEBHOOK_URL=https://open.feishu.cn/open-apis/bot/v2/hook/REDACTED
LLAMA_CPP_BASE_URL=http://127.0.0.1:8080
LLAMA_CPP_MODEL=REDACTED
LLAMA_CPP_API_KEY=REDACTED
```

权限建议：

- 用户服务：

```bash
chmod 600 ~/.config/n8n/env
```

- 系统服务：

```bash
sudo chown root:root /etc/n8n/env
sudo chmod 600 /etc/n8n/env
```

## 2. 在 systemd service 里引用 EnvironmentFile

你需要找到 n8n 的 service 文件位置。

- 用户服务常见：`~/.config/systemd/user/n8n.service`
- 系统服务常见：`/etc/systemd/system/n8n.service`

在 `[Service]` 段落增加（按你的 env 文件路径选择其一）：

- 用户服务：

```ini
EnvironmentFile=%h/.config/n8n/env
```

- 系统服务：

```ini
EnvironmentFile=/etc/n8n/env
```

注意：

- `EnvironmentFile=` 只是“读取文件并注入环境变量”，不会在日志里打印变量值。
- 若你的环境文件可能不存在、希望 service 仍可启动，可以用 `EnvironmentFile=-/path/to/env`（前面加 `-`）。

## 3. 让配置生效（重载 + 重启）

- 用户服务：

```bash
systemctl --user daemon-reload
systemctl --user restart n8n
```

- 系统服务：

```bash
sudo systemctl daemon-reload
sudo systemctl restart n8n
```

## 4. 验证环境变量是否注入成功（不泄露密钥）

### 4.1 在 n8n 工作流中验证

添加一个 `Code` 节点（临时），运行一次，检查输出是否为 `true`：

```js
return [{
  json: {
    hasBraveKey: !!$env.BRAVE_SEARCH_API_KEY,
    hasFeishuWebhook: !!$env.FEISHU_BOT_WEBHOOK_URL,
    llamaBaseUrl: $env.LLAMA_CPP_BASE_URL,
    llamaModel: $env.LLAMA_CPP_MODEL,
    hasLlamaApiKey: !!$env.LLAMA_CPP_API_KEY,
  }
}];
```

注意：不要把 key 本体输出到执行结果或日志。

### 4.2 在 systemd 侧验证（可选）

查看 n8n 进程是否已加载环境变量，通常可以通过查看启动日志或 `systemctl show` 的 Environment（可能会暴露敏感信息，不建议在共享环境中执行/截图）。

## 5. 常见问题

## 6. 需要代理才能访问外网 API（例如 Brave Search）的配置方法（Clash 场景）

如果你遇到类似下面的现象：

- `curl -I https://api.search.brave.com --max-time 10` 超时
- 但通过 Clash 代理可以访问

那么你必须把代理环境变量注入到 **n8n 的 systemd 服务进程**，否则 n8n 的 HTTP Request 节点仍会走直连而失败。

### 6.1 先用代理验证外网可达（基准测试）

以 Clash 的 HTTP 代理端口 `7897` 为例（按你的实际端口调整）：

```bash
HTTPS_PROXY=http://127.0.0.1:7897 \
HTTP_PROXY=http://127.0.0.1:7897 \
curl -I --max-time 10 https://api.search.brave.com
```

若你看到类似：

- `HTTP/1.1 200 Connection established`
- `HTTP/2 301` 或其他响应

说明代理通路 OK。

### 6.2 把代理写入 env 文件（让 n8n 进程生效）

在你的环境文件中增加以下变量（示例使用 7897）：

```bash
HTTP_PROXY=http://127.0.0.1:7897
HTTPS_PROXY=http://127.0.0.1:7897
NO_PROXY=localhost,127.0.0.1
```

说明：

- `NO_PROXY` 用于避免访问本机/内网地址也绕代理导致异常。
- 在 Node.js 环境里，`NO_PROXY` 对 CIDR 网段（如 `172.16.0.0/16`）的支持可能不稳定，建议直接写具体 IP。

例如你还需要访问内网服务 `172.16.100.211`，可写：

```bash
NO_PROXY=localhost,127.0.0.1,172.16.100.211
```

### 6.3 重启 n8n 使代理生效

修改 env 文件后必须重启 n8n：

- 用户服务：

```bash
systemctl --user restart n8n
```

- 系统服务：

```bash
sudo systemctl restart n8n
```

重启后再运行一次工作流的 `Brave Search` 节点验证。

- n8n UI 里改环境变量不生效：
  - `$env` 读取的是“启动 n8n 进程时的环境变量”。修改 EnvironmentFile 后必须重启 n8n。

- 工作流读不到 `$env.FEISHU_BOT_WEBHOOK_URL`：
  - 确认运行 n8n 的那套 systemd service（user/system）与你编辑的 service 文件是同一个。

- 不要把密钥放进工作流 JSON：
  - 推荐始终用 `$env` 或 n8n Credentials 管理敏感信息。
