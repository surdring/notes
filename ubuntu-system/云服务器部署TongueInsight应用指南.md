# ☁️ 云服务器部署 TongueInsight 应用指南（不依赖 FRP）

> 目标：将本地开发完成的 TongueInsight 应用部署到阿里云 ECS 上，通过 `https://she.tofly.top` 正式对外提供服务，**不再依赖 FRP 内网穿透**。
>
> 假设前提：
> - 已有阿里云 Ubuntu ECS，公网 IP：`47.96.159.100`；
> - 域名 `she.tofly.top` 已在阿里云完成解析到该 ECS；
> - 已按《FRP 内网穿透全流程部署指南》完成过本地调试，对项目结构已有基本了解。

---

## 1. 服务器基础环境准备

### 1.1 系统更新与基础工具

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y git python3 python3-venv python3-pip nginx
```

### 1.2 获取项目代码

推荐直接在服务器上从 Git 仓库拉取代码（不通过 FRP 上传）：

```bash
cd /opt
sudo git clone https://github.com/surdring/TongueInsight.git
sudo chown -R $USER:$USER TongueInsight
cd TongueInsight
```

> 若仓库为私有，可先在服务器上配置 SSH Key，再使用 `git@github.com:...` 地址拉取。

---

## 2. 后端部署（FastAPI + Uvicorn）

### 2.1 创建虚拟环境并安装依赖

```bash
cd /opt/TongueInsight
python3 -m venv .venv
source .venv/bin/activate

pip install --upgrade pip
pip install -r requirements.txt
```

确保 `requirements.txt` 中包含 FastAPI / Uvicorn 等依赖。

### 2.2 本地测试后端服务

在服务器上手动启动一次 Uvicorn，确认可以正常跑通：

```bash
cd /opt/TongueInsight
source .venv/bin/activate

uvicorn app.main:app --host 0.0.0.0 --port 8001
```

然后在服务器上测试健康检查：

```bash
curl http://127.0.0.1:8001/health
# 预期返回：{"status": "ok"}
```

确认无误后，按 Ctrl+C 停止服务，准备配置 systemd 后台运行。

### 2.3 配置 systemd 服务

创建服务文件：`sudo nano /etc/systemd/system/tongueinsight-backend.service`

```ini
[Unit]
Description=TongueInsight FastAPI Backend
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=/opt/TongueInsight
Environment="PATH=/opt/TongueInsight/.venv/bin"
ExecStart=/opt/TongueInsight/.venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8001
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
```

加载并启动服务：

```bash
sudo systemctl daemon-reload
sudo systemctl enable tongueinsight-backend
sudo systemctl start tongueinsight-backend

sudo systemctl status tongueinsight-backend
```

确保状态为 `active (running)`，且使用 `curl http://127.0.0.1:8001/health` 仍可返回 `{"status":"ok"}`。

---

## 3. 前端构建与部署

### 3.1 构建前端静态资源

在项目内构建 Vue 前端：

```bash
cd /opt/TongueInsight/frontend
npm install
npm run build
```

构建完成后会生成 `dist/` 目录，包含所有静态资源文件。

### 3.2 将前端交给 Nginx 托管

建议将构建产物复制到 Nginx 站点目录，例如：

```bash
sudo mkdir -p /var/www/tongueinsight
sudo cp -r dist/* /var/www/tongueinsight/

sudo chown -R www-data:www-data /var/www/tongueinsight
```

> 之后所有对外访问的 HTML/CSS/JS 都由 Nginx 从 `/var/www/tongueinsight` 提供。

---

## 4. Nginx 反向代理与 HTTPS

### 4.1 在阿里云申请 she.tofly.top 证书

1. 登录阿里云控制台 → 进入「SSL 证书（应用型）」。
2. 申请「免费证书 / 免费型 DV SSL」，域名填写 `she.tofly.top`。
3. 验证方式选择「DNS 自动验证」（推荐）。
4. 等证书状态变为「已签发」后，选择「Nginx」类型下载证书压缩包。
5. 解压后通常包含：
   - `she.tofly.top.pem`（或 `.crt`）
   - `she.tofly.top.key`

将证书上传到 ECS，例如：

```bash
sudo mkdir -p /etc/nginx/certs
sudo cp she.tofly.top.pem /etc/nginx/certs/
sudo cp she.tofly.top.key /etc/nginx/certs/
```

### 4.2 配置 Nginx 站点

创建或编辑 `/etc/nginx/sites-available/tongueinsight.conf`：

```nginx
server {
    listen 443 ssl;
    server_name she.tofly.top;

    ssl_certificate     /etc/nginx/certs/she.tofly.top.pem;
    ssl_certificate_key /etc/nginx/certs/she.tofly.top.key;

    # 前端静态资源
    root /var/www/tongueinsight;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # 后端 API 反向代理
    location /api/ {
        proxy_pass http://127.0.0.1:8001/;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}

server {
    listen 80;
    server_name she.tofly.top;
    # 所有 HTTP 请求重定向到 HTTPS
    return 301 https://$host$request_uri;
}
```

启用站点并重载 Nginx：

```bash
sudo ln -s /etc/nginx/sites-available/tongueinsight.conf /etc/nginx/sites-enabled/

sudo nginx -t
sudo systemctl reload nginx
```

### 4.3 测试访问

在任意终端或浏览器中访问：

```text
https://she.tofly.top/
```

应能看到 TongueInsight 前端页面；打开浏览器开发者工具，发送一次正常请求后，在 Network 查看：

- `GET /api/hub/chat` 等接口请求指向 `https://she.tofly.top/api/hub/chat`；
- 响应状态码为 200；
- 返回体为结构化 JSON。

---

## 5. 与 FRP 方案的区别与建议

- 本文方案将 TongueInsight **直接部署到云服务器**，通过 Nginx + Uvicorn 对外提供服务：
  - 没有 FRP 中转，链路更简单、延迟更低；
  - 证书与 HTTPS 配置全部集中在 Nginx 层面，更易维护；
  - 更符合生产环境的典型架构。

- 若仅在内网临时测试、或本地开发需要外网访问，可以继续参考《FRP 内网穿透全流程部署指南》。

- 一旦准备对实际用户开放访问，**强烈建议使用本指南的「云服务器直接部署 + Nginx + HTTPS」方案**，并：
  - 为域名备案（中国大陆合规要求）；
  - 在微信公众号 / 微信开放平台中配置 `she.tofly.top` 为业务域名或 JS 安全域名；
  - 在微信中统一使用 `https://she.tofly.top` 链接访问，减少被拦截和风险提示的概率。

---

## 6. 常见问题（FAQ）

### Q1：`https://she.tofly.top` 在系统浏览器正常，但微信仍提示“无法确认该网页的安全性”？

A：
- 如果系统浏览器中证书与访问完全正常，说明 Nginx + 证书配置本身是正确的；
- 微信的风险提示往往与域名信誉、访问量、备案状态等因素相关，短时间内难以彻底消除；
- 只要用户点击“继续访问”后，页面和接口工作正常，就可以视为配置无误，后续通过备案和长期稳定服务逐步提升域名信誉。

### Q2：后端 API 返回仍然不是合法 JSON？

A：
- 在后端 FastAPI 中，可以通过访问 `/health` 或直接 `curl http://127.0.0.1:8001/api/hub/chat`（构造示例表单）确认本地返回是否规范 JSON；
- 若在服务器本机访问正常，但在浏览器端解析失败，优先检查：
  - Nginx 是否对 `/api/` 做了额外重写或返回 HTML 错误页；
  - 是否有中间层（例如代理、防火墙、WAF）插入了提示页；
- 使用浏览器开发者工具查看 `Response` 原文内容，是定位问题的关键步骤。

### Q3：如何回滚到仅 HTTP（调试环境）？

A：
- 可暂时注释掉 Nginx 中的 443 server 块，仅保留 `listen 80` 的 HTTP 配置；
- 或者在本地通过 `npm run dev` + Vite 内置服务器继续开发调试，不影响生产环境部署逻辑。
