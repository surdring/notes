# OpenClaw：配置 Brave API Key + Clash 代理，让 `web_search` 生效（含排错记录）

本文档记录一次完整的排查与修复过程：当 OpenClaw 在使用 `web_search`（Brave Search）时提示 **没有可用的 Brave API key** 或 **`fetch failed`**，如何在 Linux 上结合 **systemd user service** + **Clash 代理**完成配置，并验证全链路生效。

适用场景：

- OpenClaw Gateway 通过 `systemctl --user` 运行（`openclaw-gateway.service`）。
- 你处在需要代理才能访问外网（或特定域名/端点）的网络环境。

---

## 1. 背景：两类常见失败

### 1.1 缺少 Brave key

症状（示例）：

- OpenClaw 提示没有 Brave API key，无法执行 `web_search`。

根因：

- 未为 OpenClaw Gateway 进程提供 Brave Search API key。

### 1.2 已配置 key 但仍 `fetch failed`

症状（示例）：

- 第一次调用 `web_search` 仍报 `error: fetch failed`。

根因：

- 网络层请求失败（DNS/路由/防火墙/代理未注入到 systemd 服务等）。

---

## 2. 关键原则：要让 OpenClaw 生效，必须写进 Gateway 的 **systemd 环境变量**

你在终端里设置的环境变量（如 `export BRAVE_API_KEY=...`）不一定会被 `systemctl --user` 启动的服务继承。

因此：

- **最终权威配置位置**：`systemctl --user edit openclaw-gateway`
- **最终权威验证命令**：`systemctl --user show openclaw-gateway --property=Environment`

---

## 3. 配置步骤：Brave API key 注入到 OpenClaw Gateway

### 3.1 编辑 systemd drop-in

```bash
systemctl --user edit openclaw-gateway
```

在编辑器中写入（示例）：

```ini
[Service]
Environment=BRAVE_API_KEY=<YOUR_BRAVE_API_KEY>
```

保存退出后重启服务：

```bash
systemctl --user restart openclaw-gateway
```

### 3.2 验证环境变量已注入

```bash
systemctl --user show openclaw-gateway --property=Environment
```

期望看到：

- 输出中包含 `BRAVE_API_KEY=...`

---

## 4. 排错步骤：区分“key 问题”还是“网络问题”

### 4.1 先验证 DNS

```bash
getent hosts api.search.brave.com
```

能解析出 IPv4/IPv6 说明 DNS 基本工作，但不代表 443 可达。

### 4.2 验证 443 连通性（直连）

```bash
curl -I https://api.search.brave.com
```

如果出现超时/连接失败：

- 说明 **直连不可用**（常见：需要代理）。

### 4.3 用浏览器验证 API 端点是否可达（可选但很直观）

打开：

- `https://api.search.brave.com/res/v1/web/search?q=test`

如果返回类似下面的 JSON（422 缺 header）：

- 说明 **浏览器侧到 API 是通的**，只是缺少 `x-subscription-token`。

---

## 5. 必须代理的场景：使用 Clash（端口 7897）

你的网络环境中，不设代理无法访问 Brave API；同时你使用的是 Clash。

关键点：

- 必须确认 Clash 的代理端口与协议。
- 最终要把代理写入 systemd 服务环境变量（`HTTP_PROXY`/`HTTPS_PROXY`）。

### 5.1 用 Clash 代理验证 Brave API 可达（终端基准测试）

假设 Clash HTTP 代理端口为 `7897`：

```bash
HTTPS_PROXY=http://127.0.0.1:7897 \
HTTP_PROXY=http://127.0.0.1:7897 \
curl -I https://api.search.brave.com --max-time 10
```

可能返回：

- `HTTP/2 301 location: https://api-dashboard.search.brave.com`

这属于正常行为（根域名重定向），说明：

- **代理可用**
- **HTTPS 隧道建立成功**（常见会看到 `HTTP/1.1 200 Connection established`）

### 5.2 进一步验证“真正的 Search API” + key（强验证）

```bash
HTTPS_PROXY=http://127.0.0.1:7897 \
HTTP_PROXY=http://127.0.0.1:7897 \
curl -sS \
  -H 'Accept: application/json' \
  -H "X-Subscription-Token: BSAmcnrtr9Geq782bICLeGPwingahxb" \
  "https://api.search.brave.com/res/v1/web/search?q=test" | head -c 400
```

如果能看到以 `{"type":"search"...}` 开头的 JSON，说明：

- key 正确
- 代理正确
- API 端点可达

#### 关于 `curl: (23) Failure writing output to destination`

当你使用 `| head -c 400` 截断输出时，`head` 会提前关闭管道，`curl` 继续写入会触发 `(23)`。

这不代表请求失败。

避免该提示的方式：

```bash
HTTPS_PROXY=http://127.0.0.1:7897 HTTP_PROXY=http://127.0.0.1:7897 \
curl -sS --range 0-399 \
  -H 'Accept: application/json' \
  -H "X-Subscription-Token: BSAmcnrtr9Geq782bICLeGPwingahxb" \
  "https://api.search.brave.com/res/v1/web/search?q=test"
```

---

## 6. 让 OpenClaw `web_search` 也走 Clash：把代理注入 Gateway systemd 环境

编辑 drop-in：

```bash
systemctl --user edit openclaw-gateway
```

加入以下内容（示例使用 7897）：

```ini
[Service]
Environment=BRAVE_API_KEY=<YOUR_BRAVE_API_KEY>
Environment=HTTP_PROXY=http://127.0.0.1:7897
Environment=HTTPS_PROXY=http://127.0.0.1:7897
Environment=NO_PROXY=localhost,127.0.0.1,172.16.100.211
```

重启并验证：

```bash
systemctl --user restart openclaw-gateway
systemctl --user show openclaw-gateway --property=Environment
```

期望看到输出包含：

- `BRAVE_API_KEY=...`
- `HTTP_PROXY=http://127.0.0.1:7897`
- `HTTPS_PROXY=http://127.0.0.1:7897`

### 6.1 为什么需要 `NO_PROXY`

你同时在使用局域网模型（例如 `llama.cpp` 在 `172.16.100.211`），不希望访问内网也绕到代理导致超时或连接失败。

**重要提示**：在 Node.js 环境下，`NO_PROXY` 对 CIDR 网段（如 `172.16.0.0/16`）的支持可能不稳定。建议直接写具体的 **IP 地址**。

因此建议保留：

- `NO_PROXY=localhost,127.0.0.1,172.16.100.211`

---

## 7. 最终验证：在 Control UI 触发一次 `web_search`

在 OpenClaw Web UI（Control UI）里发送一条明确需要联网搜索的消息，例如：

- `搜索 n8n workflow 配置 方法，列出关键步骤`

如果能返回搜索结果且不再出现：

- “没有可用的 Brave API key”
- `fetch failed`

则说明 `web_search` 已经全链路生效。

---

## 8. 常见问题（FAQ）

### 8.1 我浏览器能打开 Brave 页面，但 curl 不行，为什么？

- 浏览器可能走了系统代理/扩展代理/不同 DNS 策略；
- `curl` 默认走系统直连；在需要代理的网络环境里会超时。

解决：

- 用 Clash 代理跑 `curl`（第 5 节），并把代理注入 systemd（第 6 节）。

### 8.2 为什么 `systemctl --user show ...` 是最权威的检查？

因为它展示的是 **正在运行的 OpenClaw Gateway 进程**实际拿到的环境变量。

---
