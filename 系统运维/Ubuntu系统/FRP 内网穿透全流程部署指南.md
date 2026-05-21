# FRP 内网穿透全流程部署指南

> 本文档已整合 `frps.toml`、`frpc.toml`、`frpc-systemd.md` 的全部内容，四合一统一文档。

## 0. 准备工作

- **云服务器 (Server)**：阿里云 Ubuntu，公网 IP `47.96.159.100`
- **本地电脑 (Client)**：运行 Web 开发环境（Vite），本地端口 `5173`
- **域名**：`tofly.top`（用于子域名访问）
- **FRP 程序**：服务端 `frps` / 客户端 `frpc` 已下载至对应机器

---

## 1. 服务端配置（云服务器）

### 1.1 安装与配置文件

确保 `frps` 程序已在服务器上，编辑配置文件 `frps.toml`：

```toml
# frps.toml
bindAddr = "0.0.0.0"
bindPort = 7700               # FRP 客户端与服务端通信的端口
kcpBindPort = 7700            # KCP 协议端口（可选，建议开启）

# --- HTTP 域名配置核心 ---
vhostHTTPPort = 7080          # 接收 HTTP 域名请求的端口 (访问域名时需带此端口)
subdomainHost = "tofly.top"   # 你的主域名
# -----------------------

# --- 仪表盘配置 ---
webServer.addr = "0.0.0.0"
webServer.port = 7500
webServer.user = "surdring"
webServer.password = "ZHENGxueen@1014"

# --- 日志与认证 ---
log.to = "/frpslog/frps.log"
log.level = "info"
log.maxDays = 3

auth.method = "token"
auth.token = "aliyun2025"

# --- 允许端口范围 ---
allowPorts = [
  { start = 6000, end = 9000 },
]
```

### 1.2 设置后台运行（Systemd 服务端）

创建系统级服务文件实现开机自启：

```bash
sudo nano /etc/systemd/system/frps.service
```

```ini
[Unit]
Description=Frp Server Service
After=network.target

[Service]
Type=simple
User=root
# 注意修改为你实际的 frps 文件路径
ExecStart=/usr/local/bin/frps -c /etc/frp/frps.toml
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
```

启动管理：

```bash
sudo systemctl daemon-reload
sudo systemctl enable frps
sudo systemctl restart frps

# 查看状态
sudo systemctl status frps

# 查看日志
sudo journalctl -u frps.service -f
```

---

## 2. 客户端配置（本地电脑）

### 2.1 修改配置文件

编辑本地的 `frpc.toml`，配置 TCP 直连和 HTTP 域名转发两种隧道：

```toml
# frpc.toml
serverAddr = "47.96.159.100"
serverPort = 7700
loginFailExit = true

log.to = "./frpc.log"
log.level = "info"
log.maxDays = 3

auth.method = "token"
auth.token = "aliyun2025"

# 全局心跳配置
transport.heartbeatInterval = 30
transport.heartbeatTimeout = 90

[[proxies]]
name = "gpt-oss-20b"
type = "tcp"
localIP = "127.0.0.1"
localPort = 8080
remotePort = 8080

[[proxies]]
name = "Qwen3.5-35B-A3B"
type = "tcp"
localIP = "127.0.0.1"
localPort = 8083
remotePort = 8083

[[proxies]]
name = "she_web"
type = "http"
localIP = "127.0.0.1"
localPort = 5173
subdomain = "she"

[[proxies]]
name = "lifestream_web"
type = "http"
localIP = "127.0.0.1"
localPort = 3001
subdomain = "lifestream"

[[proxies]]
name = "wecombot"
type = "http"
localIP = "127.0.0.1"
localPort = 8001
subdomain = "wecombot"

[[proxies]]
name = "she_web_https"
type = "https"
subdomain = "she"

[proxies.plugin]
type = "https2http"
localAddr = "127.0.0.1:5173"
crtPath = "/home/zhengxueen/frp/she.tofly.top.pem"
keyPath = "/home/zhengxueen/frp/she.tofly.top.key"
hostHeaderRewrite = "she.tofly.top"
```

### 2.2 设置后台运行（Systemd 客户端）

推荐使用**用户级 systemd 服务**，无需 root 权限即可管理 frpc。

#### 创建服务文件

```bash
# 创建用户级服务目录
mkdir -p ~/.config/systemd/user

# 创建服务文件
nano ~/.config/systemd/user/frpc.service

# 给 frpc 程序添加执行权限
chmod +x ~/frp/frpc
```

#### 服务文件内容

```ini
[Unit]
Description=frp client
After=network.target syslog.target
Wants=network.target

[Service]
Type=simple
ExecStart=%h/frp/frpc -c %h/frp/frpc.toml
Restart=always
RestartSec=3
StartLimitIntervalSec=0

[Install]
WantedBy=default.target
```

> `%h` 会被 systemd 自动替换为当前用户的家目录（`/home/用户名`）。
> 如果你的 frp 程序在其他路径，请相应调整 `ExecStart`。

#### 服务管理命令

```bash
# 重新加载 systemd 配置
systemctl --user daemon-reload
# 部分系统仍需同步系统级 daemon
sudo systemctl daemon-reload

# 启用服务（开机自启）
systemctl --user enable frpc.service

# 启动服务
systemctl --user start frpc.service

# 查看服务状态
systemctl --user status frpc.service

# 停止服务
systemctl --user stop frpc.service

# 重启服务
systemctl --user restart frpc.service

# 禁用服务（取消开机自启）
systemctl --user disable frpc.service

# 查看服务日志（实时跟踪）
journalctl --user -u frpc.service -f
```

> **注意**：如果希望系统级管理（如开机在登录前启动），可将服务文件放在 `/etc/systemd/system/frpc.service`，命令中去掉 `--user` 并使用 `sudo`。

### 2.3 调试启动

临时运行查看实时日志，方便排查配置问题：

```bash
./frpc -c ./frpc.toml
```

### 2.4 解决 SSH 连接中断：配置心跳保活

通过 FRP 暴露 SSH 端口（如 `remotePort = 6001`）时，常遇到连接自动中断问题。

#### 问题现象

```
Connection closed by 47.96.159.100 port 6001
```

#### 原因

- FRP TCP 代理默认 90 秒无活动即断开
- SSH 服务器不主动发送心跳

#### 解决方案

**关键：心跳配置必须在 `[[proxies]]` 之前，属于全局 `transport` 配置！**

```toml
serverAddr = "47.96.159.100"
serverPort = 7700

# 全局心跳配置（✅ 正确位置：在 [[proxies]] 之前）
transport.heartbeatInterval = 30
transport.heartbeatTimeout = 90

[[proxies]]
name = "client-a-ssh"
type = "tcp"
localIP = "127.0.0.1"
localPort = 22
remotePort = 6001
```

> ⚠️ **常见错误**：将 `transport.heartbeatInterval` 放在 `[[proxies]]` 之后，会导致启动失败：
> ```
> decode proxy: unmarshal ProxyConfig error: json: unknown field "heartbeatInterval"
> ```

#### 配套 SSH 客户端心跳（双保险）

连接时在 SSH 客户端也启用心跳：

```bash
ssh -p 6001 -o ServerAliveInterval=30 -o ServerAliveCountMax=3 user@host
```

或写入 `~/.ssh/config`：

```
Host frp-ssh
    HostName 47.96.159.100
    Port 6001
    User zheng
    ServerAliveInterval 30
    ServerAliveCountMax 3
```

### 2.5 一套"一台 frps + 两台 frpc（A/B）"的标准模板

#### 客户机 A：`frpc.toml`

```toml
serverAddr = "47.96.159.100"
serverPort = 7700

[auth]
method = "token"
token = "PLEASE_CHANGE_ME_TO_A_LONG_RANDOM_TOKEN"

transport.heartbeatInterval = 30
transport.heartbeatTimeout = 90

# A 的 LifeStream 前端（Vite 3000）
[[proxies]]
name = "client-a-lifestream-web"
type = "http"
localIP = "127.0.0.1"
localPort = 3000
customDomains = ["a.lifestream.tofly.top"]

# （可选）A 的 SSH 暴露
[[proxies]]
name = "client-a-ssh"
type = "tcp"
localIP = "127.0.0.1"
localPort = 22
remotePort = 6001
```

#### 客户机 B：`frpc.toml`

```toml
serverAddr = "47.96.159.100"
serverPort = 7700

[auth]
method = "token"
token = "PLEASE_CHANGE_ME_TO_A_LONG_RANDOM_TOKEN"

transport.heartbeatInterval = 30
transport.heartbeatTimeout = 90

[[proxies]]
name = "client-b-lifestream-web"
type = "http"
localIP = "127.0.0.1"
localPort = 3000
customDomains = ["b.lifestream.tofly.top"]

# （可选）B 的 SSH
[[proxies]]
name = "client-b-ssh"
type = "tcp"
localIP = "127.0.0.1"
localPort = 22
remotePort = 6002
```

---

## 3. 本地前端项目适配（Vite）

这是最容易被忽略的一步。**必须配置 Vite 允许外部 Host 访问**，否则会出现 `Invalid Host Header` 或拒绝连接。

修改 `vite.config.js`（或 `.ts`）：

```javascript
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  server: {
    host: '0.0.0.0',            // 允许监听局域网/公网请求
    port: 5173,

    // --- 关键安全配置（Vite 5.1+）---
    allowedHosts: [
      '47.96.159.100',          // 允许公网 IP 访问
      'she.tofly.top',          // 允许域名访问
      '.tofly.top',             // 允许所有子域名
    ],
    // ----------------------------
  },
})
```

修改后请务必重启前端项目：`npm run dev`

---

## 4. 网络与防火墙设置

请依次完成以下三项设置，缺一不可。

### 4.1 阿里云安全组（ECS 控制台）

前往阿里云后台 → 安全组 → 入方向 → 手动添加规则：

| 端口 | 协议 | 用途 |
|------|------|------|
| TCP 7700 | TCP | FRP 系统通信（必须）|
| TCP 7500 | TCP | 仪表盘（可选）|
| TCP 8080 | TCP | TCP 隧道入口 |
| TCP 7080 | TCP | HTTP 域名隧道入口 |

> 注意：不要使用 6000 端口，浏览器认为其不安全。

### 4.2 服务器内部防火墙

如果服务器开启了 ufw 或 firewalld，也需放行上述端口：

```bash
sudo ufw allow 7700/tcp
sudo ufw allow 8080/tcp
sudo ufw allow 7080/tcp
```

### 4.3 域名解析（DNS）

前往域名服务商控制台，添加 **A 记录**：

- 主机记录：**`she`**
- 记录值：**`47.96.159.100`**

---

## 5. 最终访问测试

完成以上所有步骤后，你可以通过以下两种方式访问：

1. **IP 直接访问**（对应 TCP 配置）:
   ```
   http://47.96.159.100:8080/
   ```
   流量路径：阿里云:8080 → frps → frpc → 本地:5173

2. **域名访问**（对应 HTTP 配置）:
   ```
   http://she.tofly.top:7080/
   ```
   流量路径：阿里云:7080 → frps（识别域名 she）→ frpc → 本地:5173

---

## 6. 进阶：去掉端口并启用 HTTPS（可选）

### 6.1 仅去掉端口号（HTTP 80 → 7080）

使用 Nginx 反向代理，通过 `http://she.tofly.top`（不带 :7080）直接访问。

**前提条件**：域名必须在阿里云完成 ICP 备案，否则 80 端口会被阻断。

Nginx 配置（`/etc/nginx/conf.d/frp.conf`）：

```nginx
server {
    listen 80;
    server_name she.tofly.top;

    location / {
        proxy_pass http://127.0.0.1:7080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

重启 Nginx：`sudo systemctl reload nginx`

### 6.2 为 she.tofly.top 启用 HTTPS（推荐）

如果希望在浏览器和微信中都通过 `https://she.tofly.top` 访问，推荐在阿里云申请免费证书并在 ECS 上用 Nginx 终止 HTTPS。

#### 步骤 1：申请免费证书

登录阿里云控制台 → SSL 证书 → 免费型 DV SSL，域名 `she.tofly.top`，验证方式选择「DNS 自动验证」。

#### 步骤 2：下载证书并上传到 ECS

下载 Nginx 格式的证书，得到 `she.tofly.top.pem` 和 `she.tofly.top.key`，上传到 ECS：

```bash
# 例如放在 /etc/nginx/certs/
sudo mkdir -p /etc/nginx/certs
# 将两个文件上传至该目录
```

#### 步骤 3：Nginx 配置 HTTPS

```nginx
server {
    listen 443 ssl;
    server_name she.tofly.top;

    ssl_certificate     /etc/nginx/certs/she.tofly.top.pem;
    ssl_certificate_key /etc/nginx/certs/she.tofly.top.key;

    location / {
        proxy_pass http://127.0.0.1:7080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}

server {
    listen 80;
    server_name she.tofly.top;
    return 301 https://$host$request_uri;
}
```

检查并重载：

```bash
sudo nginx -t
sudo systemctl reload nginx
```

若能正常返回前端页面，则说明 HTTPS + FRP 链路已打通。

---

## 7. 微信内置浏览器访问注意事项

在微信内置浏览器中访问通过 FRP 暴露的站点时，需要特别注意：

- **必须优先使用 HTTPS 链路**：
  - 纯 HTTP 链路可能被中间节点或安全网关插入提示页，导致前端拿到的不是后端 JSON，而是 HTML 提示页，从而触发"后端返回的内容不是合法的 JSON 响应"之类错误；
  - 通过 6.2 节的 Nginx HTTPS 方案可避免此问题。

- **HTTPS 证书必须为 `she.tofly.top` 签发，并由受信任 CA 提供**：
  - 推荐使用阿里云免费型 DV SSL 证书，或 Let's Encrypt；
  - 证书的 Subject / SAN 中必须包含 `she.tofly.top`，否则会出现域名不匹配警告。

- **微信的"风险提示"不一定代表配置错误**：
  - 即便证书、链路完全正常，微信仍可能因域名新、访问量低、未备案或使用内网穿透等因素弹出安全提示；
  - 这属于微信自身的风控策略，**不会影响后端 JSON 返回与前端正常解析**；
  - 实际排查顺序：先用系统浏览器确认无证书错误 → 再在微信中验证功能是否正常 → 后续通过备案提升域名信誉。

---

## 附录：文件清单

| 文件 | 用途 |
|------|------|
| `FRP 内网穿透全流程部署指南.md` | 统一文档（已整合全部 4 个文件内容） |