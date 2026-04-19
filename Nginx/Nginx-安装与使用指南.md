# Nginx 安装与使用指南

## 目录
1. [Nginx 简介与常见使用场景](#nginx-简介与常见使用场景)
2. [安装 Nginx](#安装-nginx)
3. [目录结构与核心配置文件](#目录结构与核心配置文件)
4. [基本管理命令](#基本管理命令)
5. [基础配置示例](#基础配置示例)
6. [为 n8n 提供反向代理](#为-n8n-提供反向代理)
7. [HTTPS 配置（含 Let’s Encrypt）](#https-配置含-lets-encrypt)
8. [性能与安全基础建议](#性能与安全基础建议)
9. [常见问题排查](#常见问题排查)

---

## Nginx 简介与常见使用场景

Nginx 是一个高性能的 Web 服务器和反向代理服务器，具有占用资源少、并发能力强、配置灵活等特点，常用于：

- **反向代理 / 负载均衡**：把外部请求转发到后端应用（如 n8n、llama.cpp HTTP server、Node.js、Python 服务）。
- **静态资源服务**：直接提供静态文件（HTML/CSS/JS/图片等）。
- **HTTPS 终结**：统一在 Nginx 上处理 TLS/SSL，再转发到后端明文 HTTP。
- **多站点管理**：一台机器上托管多个站点/服务，通过域名或路径区分。

---

## 安装 Nginx

以下以 **Ubuntu / Debian 系** 为例（你当前环境为 Ubuntu 24.04，可以直接使用）。

### 1. 使用 apt 安装（推荐）

```bash
# 更新包索引
sudo apt update

# 安装 Nginx
sudo apt install -y nginx

# 查看版本
nginx -v
```

安装完成后，Nginx 通常会自动启动，并监听 80 端口。

### 2. 检查服务状态

```bash
sudo systemctl status nginx
```

看到 `active (running)` 即表示运行正常。

### 3. 防火墙（如开启了 ufw）

```bash
# 允许 HTTP
sudo ufw allow 'Nginx HTTP'

# 如果后续配置 HTTPS
sudo ufw allow 'Nginx Full'
```

---

## 目录结构与核心配置文件

以默认安装为例：

- **主配置文件**：`/etc/nginx/nginx.conf`
- **站点配置目录**：
  - `/etc/nginx/sites-available/`：可用站点配置（单独的 server 块）
  - `/etc/nginx/sites-enabled/`：启用中的站点（通常是对 sites-available 的软链接）
- **模块级配置**：`/etc/nginx/conf.d/*.conf`
- **日志目录**：`/var/log/nginx/`
  - `access.log`：访问日志
  - `error.log`：错误日志
- **默认站点根目录**：`/var/www/html/`

主配置文件 `nginx.conf` 中通常会包含：

```nginx
include /etc/nginx/conf.d/*.conf;
include /etc/nginx/sites-enabled/*;
```

平时绝大部分操作只需要在 `sites-available` 里新建/修改站点配置，然后通过软链接启用即可。

---

## 基本管理命令

### 使用 systemd 管理 Nginx

```bash
# 启动
sudo systemctl start nginx

# 停止
sudo systemctl stop nginx

# 重启
sudo systemctl restart nginx

# 平滑重载配置（推荐）
sudo systemctl reload nginx

# 查看状态
sudo systemctl status nginx
```

### 测试配置是否正确

在重启/重载前，先测试语法：

```bash
sudo nginx -t
```

如输出 `syntax is ok` 和 `test is successful` 即表示配置语法无误。

---

## 基础配置示例

### 1. 静态网站示例

创建一个简单站点：

```bash
sudo mkdir -p /var/www/example
sudo chown -R $USER:$USER /var/www/example

cat > /var/www/example/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <title>Example Site</title>
</head>
<body>
  <h1>Nginx 示例站点</h1>
  <p>这里是通过 Nginx 提供的静态页面。</p>
</body>
</html>
EOF
```

创建站点配置：

```bash
sudo nano /etc/nginx/sites-available/example.conf
```

内容示例：

```nginx
server {
    listen 80;
    server_name example.local;

    root /var/www/example;
    index index.html;

    access_log /var/log/nginx/example_access.log;
    error_log  /var/log/nginx/example_error.log;

    location / {
        try_files $uri $uri/ =404;
    }
}
```

启用站点并重载：

```bash
sudo ln -s /etc/nginx/sites-available/example.conf /etc/nginx/sites-enabled/

sudo nginx -t
sudo systemctl reload nginx
```

如果本机访问，可在 `/etc/hosts` 中添加：

```bash
# 示例
127.0.0.1   example.local
```

然后用浏览器访问：`http://example.local`。

### 2. 基本反向代理示例

假设后端服务监听 `127.0.0.1:3000`，让 Nginx 代理 80 端口：

```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://127.0.0.1:3000;

        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

---

## 为 n8n 提供反向代理

假设：
- n8n 运行在同一台机器上
- n8n 监听：`http://localhost:5678`
- 你希望通过 IP 或域名访问，例如：
  - `http://172.16.100.202/` 或
  - `https://n8n.example.com/`

### 1. HTTP 反向代理（无 HTTPS）

创建配置文件：

```bash
sudo nano /etc/nginx/sites-available/n8n.conf
``;

示例配置：

```nginx
server {
    listen 80;
    server_name 172.16.100.202;  # 或者你的域名

    # 如果希望访问根路径就是 n8n，可直接反代到 / 
    location / {
        proxy_pass http://127.0.0.1:5678/;

        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

启用站点并重载：

```bash
sudo ln -s /etc/nginx/sites-available/n8n.conf /etc/nginx/sites-enabled/

sudo nginx -t
sudo systemctl reload nginx
```

然后使用：

- `http://172.16.100.202/` 访问 n8n

> **配合 n8n 环境变量建议**：
> - `N8N_HOST` 设置为你的访问主机名（如 `172.16.100.202` 或域名）
> - `N8N_PORT` 仍为 `5678`
> - 如果仅 HTTP，可保持 `N8N_PROTOCOL=http`
> - 如通过反代访问时触发 secure cookie 报错，可设置 `N8N_SECURE_COOKIE=false`

在 systemd 服务中可类似：

```ini
Environment=N8N_HOST=172.16.100.202
Environment=N8N_PORT=5678
Environment=N8N_SECURE_COOKIE=false
```

### 2. 使用子路径暴露 n8n（例如 `/n8n/`）

如果你想保留根路径给其他服务，可以这样：

```nginx
server {
    listen 80;
    server_name 172.16.100.202;

    # 其他站点内容 ...

    location /n8n/ {
        proxy_pass http://127.0.0.1:5678/;

        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

此时浏览器访问：`http://172.16.100.202/n8n/`

> 注意：n8n 默认对路径前缀支持一般，推荐使用根路径方式（`/`）反向代理，配置更简单、兼容性更好。

### 3. 同一 IP 下同时暴露 /n8n 与 /llama

如果你希望：

- `http://172.16.100.202/n8n` → 反向代理到本机 n8n（`http://127.0.0.1:5678`）
- `http://172.16.100.202/llama` → 反向代理到本机 llama.cpp HTTP server（假设为 `http://127.0.0.1:8080`）

可以使用如下完整的 `server` 配置示例：

```nginx
server {
    listen 80;
    server_name 172.16.100.202;

    # 可选：根路径返回一个简单文本，确认 Nginx 正常工作
    location = / {
        return 200 'OK';
        add_header Content-Type text/plain;
    }

    # 访问 /n8n 自动补斜杠，避免路径问题
    location = /n8n {
        return 301 /n8n/;
    }

    # n8n 子路径，假设 n8n 监听在 127.0.0.1:5678
    location /n8n/ {
        proxy_pass http://127.0.0.1:5678/;

        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # 访问 /llama 自动补斜杠
    location = /llama {
        return 301 /llama/;
    }

    # llama.cpp HTTP server 子路径，假设监听在 127.0.0.1:8080
    # 如果你的 llama-server 实际端口不是 8080，请把下面的 8080 改成对应端口
    location /llama/ {
        proxy_pass http://127.0.0.1:8080/;

        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

配置完成后：

- 访问 `http://172.16.100.202/n8n` 会被 301 跳转到 `http://172.16.100.202/n8n/`，并由 Nginx 反代到 `http://127.0.0.1:5678/`
- 访问 `http://172.16.100.202/llama` 会被 301 跳转到 `http://172.16.100.202/llama/`，并由 Nginx 反代到 `http://127.0.0.1:8080/`

如需与现有站点配置合并，可将上面的各个 `location` 段落拷贝到你自己的 `server { ... }` 中，并保持 `listen` / `server_name` 一致即可。

---

## HTTPS 配置（含 Let’s Encrypt）

### 1. 使用自签名证书（测试环境）

```bash
sudo mkdir -p /etc/nginx/ssl
cd /etc/nginx/ssl

sudo openssl req -new -newkey rsa:2048 -nodes -x509 \
  -days 365 \
  -keyout nginx-selfsigned.key \
  -out nginx-selfsigned.crt
```

创建一个 HTTPS 站点示例：

```nginx
server {
    listen 443 ssl http2;
    server_name your-domain.com;

    ssl_certificate     /etc/nginx/ssl/nginx-selfsigned.crt;
    ssl_certificate_key /etc/nginx/ssl/nginx-selfsigned.key;

    location / {
        proxy_pass http://127.0.0.1:5678/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### 2. 使用 Let’s Encrypt（生产环境推荐）

前提：
- 已有公网域名
- DNS 解析指向服务器公网 IP

安装 certbot：

```bash
sudo apt install -y certbot python3-certbot-nginx
```

一键获取证书并自动配置 Nginx：

```bash
sudo certbot --nginx -d your-domain.com
```

按提示输入邮箱、同意协议，即可自动：
- 生成证书
- 更新 Nginx 配置为 HTTPS
- 自动添加 80 → 443 跳转

证书续期：

```bash
# 测试
sudo certbot renew --dry-run

# 实际续期由 certbot 自带的定时任务负责，一般无需手动操作
```

---

## 性能与安全基础建议

- **开启 gzip 压缩**（在 `nginx.conf` 中或单独的 conf）：

```nginx
gzip on;
gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
```

- **限制请求体大小**，防止大文件攻击：

```nginx
client_max_body_size 10m;
```

- **使用独立日志**：为不同站点配置各自的 `access_log` / `error_log`，便于排查问题。
- **定期查看错误日志**：`/var/log/nginx/error.log`
- **只开放必要端口**：通过 ufw / 安全组控制 80/443 等端口。

---

## 常见问题排查

### 1. 修改配置后访问出错

- 先运行：`sudo nginx -t` 检查配置语法
- 再执行：`sudo systemctl reload nginx`
- 查看错误日志：`sudo tail -n 50 /var/log/nginx/error.log`

### 2. 80/443 端口被占用

检查端口占用：

```bash
sudo lsof -i:80
sudo lsof -i:443
```

如果有其他 Web 服务（如 Apache）在占用，考虑：
- 停止并禁用：`sudo systemctl stop apache2 && sudo systemctl disable apache2`
- 然后再启动 Nginx。

### 3. 通过域名访问失败，但 IP 访问正常

- 检查域名解析：`nslookup your-domain.com` 或 `dig your-domain.com`
- 确保 `server_name` 与访问的域名一致
- 若有 HTTPS，检查证书域名是否匹配。

### 4. 代理 WebSocket / SSE 出现问题

确保配置了：

```nginx
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection 'upgrade';
```

很多实时应用和 WebSocket 需要这些头部才能正常工作。

---

## 6.4 完整的子路径配置方案（推荐）

下面是一个完整的Nginx配置，将n8n、llama.cpp和Dify都部署在同一个IP的不同子路径下：

```nginx
server {
    listen 80;
    server_name 172.16.100.202;
    
    # 根路径可以放置一个默认页面或其他服务
    location / {
        return 200 'Welcome! Access services: /n8n/, /llama/, /dify/';
        add_header Content-Type text/plain;
    }
    
    # n8n 子路径
    location /n8n/ {
        proxy_pass http://127.0.0.1:5678/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket支持（n8n需要）
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # 增加超时时间
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
    }
    
    # n8n 静态资源路径处理
    location ~ ^/(n8nstatic|n8nassets)/ {
        proxy_pass http://127.0.0.1:5678;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # n8n favicon
    location = /n8nfavicon.ico {
        proxy_pass http://127.0.0.1:5678;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # llama.cpp 子路径
    location /llama/ {
        proxy_pass http://127.0.0.1:8080/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket支持（如果需要）
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    
    # Dify 子路径
    location /dify/ {
        proxy_pass http://127.0.0.1:3000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket支持
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    
    # 增加上传文件大小限制
    client_max_body_size 100M;
}
```

### 访问地址
- **n8n**: `http://172.16.100.202/` (根路径，避免静态资源问题)
- **llama.cpp**: `http://172.16.100.202/llama/`
- **Dify**: `http://172.16.100.202/dify/`

### 6.4.1 n8n环境变量配置

由于n8n在子路径模式下存在静态资源路径问题，推荐将n8n放在根路径：

```bash
# n8n根路径配置（推荐）
N8N_HOST=127.0.0.1
N8N_PORT=5678
N8N_PROTOCOL=http
N8N_SECURE_COOKIE=false  # 如果使用HTTP，必须设为false
```

如果坚持使用子路径，需要设置以下环境变量（可能有问题）：

```bash
# n8n使用子路径时必须设置（已知有问题）
N8N_PATH=/n8n
N8N_EDITOR_BASE_URL=http://172.16.100.202/n8n
N8N_HOST=127.0.0.1
N8N_PORT=5678
N8N_PROTOCOL=http
N8N_SECURE_COOKIE=false  # 如果使用HTTP，必须设为false
```

在systemd服务文件中添加环境变量：

```ini
[Unit]
Description=n8n
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu
Environment=NODE_ENV=production
Environment=N8N_HOST=127.0.0.1
Environment=N8N_PORT=5678
Environment=N8N_PROTOCOL=http
Environment=N8N_SECURE_COOKIE=false
# 根路径模式，不需要子路径配置
ExecStart=/usr/bin/npx n8n
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

### 6.4.2 配置步骤

1. **设置n8n环境变量**（根路径模式）
2. **创建Nginx配置文件**：`/etc/nginx/sites-available/multi-services`
3. **启用配置**：`sudo ln -s /etc/nginx/sites-available/multi-services /etc/nginx/sites-enabled/`
4. **测试配置**：`sudo nginx -t`
5. **重载Nginx**：`sudo systemctl reload nginx`

### 6.4.3 故障排除

**问题1：n8n白屏或静态资源加载失败**
- **原因**：n8n在子路径模式下存在静态资源路径问题
- **解决**：将n8n放在根路径，其他服务使用子路径
- **验证**：访问`http://172.16.100.202/`应该能看到完整的n8n界面

**问题2：llama.cpp或Dify无法访问**
- **原因**：对应服务未启动或端口配置错误
- **解决**：检查服务状态和端口配置
- **验证**：直接访问`http://127.0.0.1:8080/`（llama.cpp）或`http://127.0.0.1:3000/`（Dify）

**问题3：WebSocket连接失败**
- **原因**：缺少WebSocket支持配置
- **解决**：确保Nginx配置中包含WebSocket支持设置

### 6.4.4 最终配置总结

**推荐方案（已验证可用）：**
- **n8n**: `http://172.16.100.202/` (根路径)
- **llama.cpp**: `http://172.16.100.202/llama/`
- **Dify**: `http://172.16.100.202/dify/`

**关键配置要点：**
1. n8n使用根路径模式，避免静态资源问题
2. 其他服务使用子路径，统一访问入口
3. 所有服务都配置了WebSocket支持
4. 设置了合适的超时时间和文件大小限制

**为什么选择这个方案：**
- n8n的子路径功能存在已知问题，静态资源路径生成不正确
- 根路径模式确保n8n完全正常工作
- 其他服务（llama.cpp、Dify）对子路径支持良好

---

*最后更新：2025 年 11 月 27 日*
