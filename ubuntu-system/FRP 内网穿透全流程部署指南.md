
# 🚀 FRP 内网穿透全流程部署指南

## 📋 0. 准备工作
*   **云服务器 (Server)**: 阿里云 Ubuntu，公网 IP: `47.96.159.100`。
*   **本地电脑 (Client)**: 运行 Web 开发环境 (Vite)，本地端口 `5173`。
*   **域名**: `tofly.top` (用于子域名访问)。

---

## ☁️ 1. 服务端配置 (云服务器)

### 1.1 安装与配置文件
确保 frp 程序已在服务器上，修改配置文件 `frps.toml`。

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
  { start = 6000, end = 9000},
]
```

### 1.2 设置后台运行 (Systemd)
创建服务文件以便开机自启：`sudo nano /etc/systemd/system/frps.service`

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

**启动命令：**
```bash
sudo systemctl daemon-reload
sudo systemctl enable frps
sudo systemctl restart frps
```

---

## 💻 2. 客户端配置 (本地电脑)

### 2.1 修改配置文件
修改本地的 `frpc.toml`，配置两条隧道：一条 TCP 直连，一条 HTTP 域名转发。

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

# [隧道1] TCP 模式：通过 http://IP:8080 访问
# 避开了浏览器封锁的 6000 端口
[[proxies]]
name = "tongue_insight_tcp"
type = "tcp"
localIP = "127.0.0.1"    # 强制指向本机回环地址
localPort = 5173         # 本地 Vite 端口
remotePort = 8080        # 云服务器对外暴露的端口

# [隧道2] HTTP 模式：通过 http://she.tofly.top:7080 访问
[[proxies]]
name = "she_web"
type = "http"
localIP = "127.0.0.1"
localPort = 5173
subdomain = "she"        # 子域名前缀，组合后为 she.tofly.top
```

### 2.2 启动客户端
```bash
# 调试模式（查看实时日志）：
./frpc -c ./frpc.toml

# 或者使用后台服务（如果已配置 systemctl）：
sudo systemctl restart frpc
```

---

## 🛠 3. 本地前端项目适配 (Vite)

这是最容易被忽略的一步。**必须配置 Vite 允许外部 Host 访问**，否则会出现 `Invalid Host Header` 或拒绝连接。

修改 `vite.config.js` (或 `.ts`)：

```javascript
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  server: {
    host: '0.0.0.0', // 允许监听局域网/公网请求
    port: 5173,
    
    // --- 关键安全配置 (Vite 5.1+) ---
    allowedHosts: [
      '47.96.159.100',  // 允许公网IP访问
      'she.tofly.top',  // 允许域名访问
      '.tofly.top'      // 或者允许所有子域名
    ],
    // ----------------------------
  },
})
```
*修改后请务必重启前端项目：`npm run dev`*

---

## 🛡 4. 网络与防火墙设置 (至关重要)

请依次完成以下三项设置，缺一不可。

### 4.1 阿里云安全组 (ECS 控制台)
前往阿里云后台 -> 安全组 -> 入方向 -> 手动添加规则：
*   **TCP 7700**: FRP 系统通信（必须）。
*   **TCP 7500**: 仪表盘（可选）。
*   **TCP 8080**: 你的 TCP 隧道入口。
*   **TCP 7080**: 你的 HTTP 域名隧道入口。
*   *(注意：不要使用 6000 端口，浏览器认为其不安全)*

### 4.2 服务器内部防火墙
如果服务器开启了 ufw 或 firewalld，也需放行上述端口：
```bash
sudo ufw allow 7700/tcp
sudo ufw allow 8080/tcp
sudo ufw allow 7080/tcp
```

### 4.3 域名解析 (DNS)
前往域名服务商控制台，添加 **A 记录**：
*   主机记录: **`she`**
*   记录值: **`47.96.159.100`**

---

## 🚀 5. 最终访问测试

完成以上所有步骤后，你可以通过以下两种方式访问：

1.  **IP 直接访问** (对应 TCP 配置):
    > http://47.96.159.100:8080/
    > *原理：流量 -> 阿里云:8080 -> frps -> frpc -> 本地:5173*

2.  **域名访问** (对应 HTTP 配置):
    > http://she.tofly.top:7080/
    > *原理：流量 -> 阿里云:7080 -> frps(识别域名 she) -> frpc -> 本地:5173*

---

## ⚡ 6. 进阶：去掉端口并启用 HTTPS（可选）

### 6.1 仅去掉端口号（HTTP 80 → 7080）

如果你想通过 `http://she.tofly.top` 直接访问（不带 :7080），你需要使用 **Nginx 反向代理**。

**前提条件：你的域名必须已在阿里云完成 ICP 备案。如果没有备案，使用 80 端口会被直接阻断。**

**Nginx 配置示例 (`/etc/nginx/conf.d/frp.conf`):**

```nginx
server {
    listen 80;
    server_name she.tofly.top;

    location / {
        # 将 80 端口的请求转发给 FRP 的 HTTP 端口 (7080)
        proxy_pass http://127.0.0.1:7080;
        
        # 传递头部信息，让 FRP 知道访问的是哪个域名
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

配置后重启 Nginx 即可。**未备案域名请继续使用 7080 端口访问调试环境。**

---

### 6.2 为 she.tofly.top 启用 HTTPS（推荐）

如果希望在浏览器和微信中都通过 `https://she.tofly.top` 访问，推荐在阿里云申请免费证书并在 ECS 上用 Nginx 终止 HTTPS。

**步骤 1：在阿里云申请 she.tofly.top 免费证书**

- 登录阿里云控制台，进入「SSL 证书（应用型）」。
- 选择「免费证书 / 免费型 DV SSL」，域名填写：`she.tofly.top`。
- 验证方式选择「DNS 自动验证」（域名 DNS 也在阿里云时最方便）。
- 等待状态变为「已签发」。

**步骤 2：下载证书并上传到 ECS**

- 在证书列表中找到 `she.tofly.top` 这张证书，点击「下载」。
- 服务器类型选择「Nginx」，解压后得到类似：
  - `she.tofly.top.pem`（或 `.crt`）
  - `she.tofly.top.key`
- 将这两个文件上传到 ECS，例如：`/etc/nginx/certs/she.tofly.top.pem`、`/etc/nginx/certs/she.tofly.top.key`。

**步骤 3：Nginx 配置 HTTPS（443 → 127.0.0.1:7080）**

```nginx
server {
    listen 443 ssl;
    server_name she.tofly.top;

    ssl_certificate     /etc/nginx/certs/she.tofly.top.pem;
    ssl_certificate_key /etc/nginx/certs/she.tofly.top.key;

    location / {
        # 将 HTTPS 请求转发给 FRP 的 HTTP 端口 (7080)
        proxy_pass http://127.0.0.1:7080;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}

server {
    listen 80;
    server_name she.tofly.top;
    # 所有 HTTP 请求 301 跳转到 HTTPS
    return 301 https://$host$request_uri;
}
```

检查配置并重载 Nginx：

```bash
sudo nginx -t
sudo systemctl reload nginx
```

若能正常返回前端 HTML，则说明 HTTPS + FRP https2http 流程已经打通。

---

## 7. 微信内置浏览器访问注意事项

在微信内置浏览器中访问通过 FRP 暴露的站点时，需要特别注意：

- **必须优先使用 HTTPS 链路**：
  - 纯 HTTP 链路可能被中间节点或安全网关插入提示页，导致前端拿到的不是后端 JSON，而是 HTML 提示页，从而触发诸如“后端返回的内容不是合法的 JSON 响应”之类错误；
  - 通过上面的 6.2（Nginx 终止 HTTPS）或 6.3（FRP https2http 插件）方案，将外部访问统一收敛为 `https://she.tofly.top` 可以极大降低这种风险。

- **HTTPS 证书必须为 she.tofly.top 签发，并由受信任 CA 提供**：
  - 推荐使用阿里云「免费型 DV SSL」证书，或 Let’s Encrypt；
  - 证书的 `Subject` / `SAN` 中必须包含 `she.tofly.top`，否则会出现域名不匹配警告。

- **微信的“风险提示”不一定代表配置错误**：
  - 即便证书、链路完全正常，微信仍可能因域名新、访问量低、未备案或使用内网穿透等因素，在进入页面前弹出“无法确认该网页的安全性”；
  - 这属于微信自身的风控策略，**不会影响后端 JSON 返回与前端正常解析**，只是在进入页面前多一层提示。

实际排查顺序建议：

1. 使用系统浏览器（在微信右上角菜单中选择“在浏览器中打开”）访问 `https://she.tofly.top`，确认无证书错误；
2. 在微信中访问同一链接，若仅有风险提示但页面与接口工作正常，可以视为“配置正确 + 风控提示存在”，后续可通过备案、正式部署到云服务器等方式逐步提升域名信誉。