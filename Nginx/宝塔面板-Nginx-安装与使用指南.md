# 宝塔面板中安装与使用 Nginx 指南

## 1. 前提条件与适用场景

本指南基于：
- 操作系统：Ubuntu / Debian / CentOS 等，已安装 **宝塔面板**（BT）
- 你可以通过浏览器访问宝塔面板，例如：`http://服务器IP:8888`

典型使用场景：
- **内网使用**：仅在局域网中访问，例如 `172.16.100.202` 或 `n8n.huanan`
- **外网使用**：通过已备案/已解析的公网域名访问，例如 `n8n.example.com`

---

## 2. 在宝塔面板中安装 Nginx

### 2.1 登录宝塔面板

1. 浏览器访问：`http://服务器IP:8888`
2. 使用安装宝塔时生成的账号密码登录（或你已修改后的账号密码）。

### 2.2 在“软件商店”中安装 Nginx

1. 左侧菜单点击：**软件商店**
2. 在顶部搜索框输入：`Nginx`
3. 找到 **Nginx** 软件：
   - 如果右侧显示 **已安装**：说明 Nginx 已安装，可以直接使用
   - 如果显示 **安装** 按钮：
     - 点击 **安装**
     - 安装方式选择：**快速安装（推荐）**
     - 版本一般选择默认稳定版即可
4. 安装完成后，宝塔会自动启动 Nginx，并监听 80 端口。

### 2.3 确认 Nginx 服务状态

1. 在“软件商店 → 已安装”中找到 **Nginx**
2. 确认状态为 **运行中**
3. 如未运行，可点击右侧 **启动** 按钮

---

## 3. 在宝塔中创建基于 Nginx 的网站

宝塔里的网站其实就是 Nginx 的一个 `server` 配置。我们可以为不同用途创建不同站点，例如：
- 仅内网访问的 n8n 后台
- 面向公网用户的 HTTPS 站点

### 3.1 新建网站的通用步骤

1. 左侧菜单点击：**网站**
2. 点击右上角：**添加站点**
3. 在弹出的表单中填写：
   - **域名**：
     - 内网场景可以填写：内网 IP（如 `172.16.100.202`）或者内网域名（如 `n8n.huanan`）
     - 外网场景必须填写：已解析到本服务器公网 IP 的真实域名（如 `n8n.example.com`）
   - **根目录**：默认即可（如 `/www/wwwroot/域名`）
   - **网站类型**：
     - 如仅做反向代理，选 **纯静态** 即可
   - 其他选项（PHP、数据库等）按实际需要，做反代 n8n 则一般不需要数据库
4. 点击 **提交**，宝塔会自动生成 Nginx 配置并创建站点目录。

之后，你可以在“网站”列表中看到这个站点，点击右侧 **设置** 进入详细配置界面。

---

## 4. 内网使用场景配置（无公网域名）

### 4.1 场景说明

- 服务器仅在局域网中访问，例如 IP 为 `172.16.100.202`
- 你只需要在内网访问 n8n 或其他服务
- 通常使用 **HTTP + IP 或内网域名** 即可，不需要 HTTPS 证书

### 4.2 使用 IP 创建内网站点

1. 在“添加站点”时：
   - 域名直接填写：`172.16.100.202`
   - 类型：**纯静态**
   - 其他默认
2. 创建后，在“网站 → 设置”中进行反向代理配置（见下一小节）。

### 4.3 使用内网域名（配合 hosts）

如果你希望浏览器里访问友好一点，如 `http://n8n.huanan`：

1. 在宝塔添加站点时：
   - 域名填写：`n8n.huanan`
2. 在**你本地机器**的 `/etc/hosts` 文件中添加映射：

```text
172.16.100.202  n8n.huanan
```

3. 保存后，在浏览器中访问：`http://n8n.huanan` 即可访问这台服务器。

> 注意：这种方式只对配置了 hosts 的机器生效，适合小范围内部使用。

### 4.4 内网反向代理到 n8n（示例）

假设 n8n 在服务器上监听：`http://127.0.0.1:5678`

1. 在宝塔中，打开对应站点的 **设置**
2. 左侧选择：**反向代理**
3. 点击：**添加反向代理**，填写：
   - **名称**：`n8n-proxy`（随便起）
   - **目标URL**：`http://127.0.0.1:5678`  
   - 其他保持默认（发送域名 `$host` 即可）
4. 保存后，宝塔会生成类似这样的 Nginx 配置：

```nginx
location / {
    proxy_pass http://127.0.0.1:5678;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

5. 此时：
   - 如果站点域名是 `172.16.100.202`，则访问 `http://172.16.100.202` 即可打开 n8n
   - 如果站点域名是 `n8n.huanan`，则访问 `http://n8n.huanan`

### 4.5 内网场景下 n8n 环境变量建议

由于你通过 IP 或内网域名 + HTTP 访问，可以这样配置 n8n：

- `N8N_HOST`：填写你实际访问的主机，如 `172.16.100.202` 或 `n8n.huanan`
- `N8N_PORT`：保持 `5678`
- `N8N_PROTOCOL`：`http`
- 如果遇到 secure cookie 报错，可设置：`N8N_SECURE_COOKIE=false`

在 systemd 服务中可以类似：

```ini
Environment=N8N_HOST=172.16.100.202
Environment=N8N_PORT=5678
Environment=N8N_PROTOCOL=http
Environment=N8N_SECURE_COOKIE=false
```

### 4.6 完整的子路径配置方案（推荐）

下面是一个完整的Nginx配置，将n8n、llama.cpp和Dify都部署在同一个IP的不同子路径下：

```nginx
server {
    listen 80;
    server_name 172.16.100.202;
    
    # n8n 主路径（放在根路径避免静态资源问题）
    location / {
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
}
```

#### 访问地址
- **n8n**: `http://172.16.100.202/` (根路径，避免静态资源问题)
- **llama.cpp**: `http://172.16.100.202/llama/`
- **Dify**: `http://172.16.100.202/dify/`

#### 4.6.1 n8n环境变量配置

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

#### 4.6.2 宝塔面板配置步骤

1. **设置n8n环境变量**（根路径模式）
2. **在宝塔面板中添加反向代理**：
   - **网站** → **反向代理** → **添加反向代理**
   
   **llama.cpp代理**：
   - 代理名称：`llama`
   - 目标URL：`http://127.0.0.1:8080/`
   - 代理目录：`/llama/`
   - 发送域名：`$host`
   - 高级设置：添加WebSocket支持
   
   **Dify代理**：
   - 代理名称：`dify`
   - 目标URL：`http://127.0.0.1:3000/`
   - 代理目录：`/dify/`
   - 发送域名：`$host`
   - 高级设置：添加WebSocket支持

3. **或者直接编辑Nginx配置**（推荐）：
   - 进入「网站」→「设置」→「配置文件」
   - 将上面的完整配置替换进去
   - 点击「保存」并「重载Nginx」

#### 4.6.3 故障排除

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

#### 4.6.4 最终配置总结

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

- `http://172.16.100.202:5678`（直连 n8n）

从功能角度看，**这样确实已经能用**，Nginx 不是“必需品”。但在下面这些场景中，引入 Nginx 反向代理会更有意义：

1. **统一访问入口，隐藏端口和实现细节**
   - 对用户暴露：`http://172.16.100.202` 或 `http://n8n.huanan`
   - 后端真实运行：`http://127.0.0.1:5678`
   - 以后如果你想改端口、换到另一个服务，只需要调整 Nginx 代理目标，无需让所有人改地址。

2. **多服务共存，一个 IP/域名挂多个服务**
   - 无 Nginx：
     - n8n：`172.16.100.202:5678`
     - llama.cpp WebUI：`172.16.100.202:8080`
     - 监控面板：`172.16.100.202:3000`
   - 有 Nginx：
     - `http://172.16.100.202/` → n8n
     - `http://172.16.100.202/llama` → llama.cpp
     - `http://172.16.100.202/monitor` → 监控面板
   - 对使用者来说，不需要记一堆端口，只需要记一个 IP/域名和不同路径即可。

3. **HTTPS / 证书 / 安全 Cookie 的统一入口**
   - n8n 自己直接在 5678 端口上做 HTTPS 会比较麻烦，也不方便和其他服务共享证书。
   - 用 Nginx：
     - 在 Nginx/宝塔上为域名配置 Let’s Encrypt 证书
     - 对外暴露：`https://n8n.example.com`
     - Nginx 内部转发到：`http://127.0.0.1:5678`
   - 这样 n8n 可以放心开启 `N8N_SECURE_COOKIE=true`，安全性更高，其他服务也可以共用同一个 HTTPS 入口。

4. **访问控制、限流、日志和统一运维**
   - 在 Nginx 层可以：
     - 针对不同路径/站点配置访问日志、错误日志
     - 做简单 IP 白名单/黑名单
     - 限制请求体大小、连接数，避免单个服务被恶意请求拖垮
   - 所有这些配置集中在 Nginx/宝塔里，运维和排查问题更统一。

5. **如何取舍**
   - 如果只是你自己在局域网里临时玩、且只有 n8n 一个服务：
     - 直接用 `http://172.16.100.202:5678` 完全可以，不一定非要 Nginx。
   - 如果你：
     - 计划长期使用 n8n
     - 需要同时运行多个服务（llama.cpp、Dify等）
     - 希望有统一的访问入口
     - 未来可能需要HTTPS
     - **推荐使用上面的子路径方案**

### 4.8 子路径 vs 子域名选择

| 特性 | 子路径方案 | 子域名方案 |
|------|------------|------------|
| **配置复杂度** | 低（只需服务端配置） | 高（需要客户端hosts） |
| **访问地址** | `172.16.100.202/n8n` | `n8n.huanan` |
| **静态资源兼容性** | 可能有问题 | 完全兼容 |
| **URL美观度** | 一般 | 好 |
| **后续迁移** | 需要重新配置 | 容易迁移到公网域名 |
| **推荐场景** | 个人使用、快速部署 | 团队使用、长期部署 |

**最终建议**：
- 如果不想配置hosts，坚持使用子路径方案（现在的配置）
- 如果遇到n8n静态资源问题，必须设置`N8N_PATH`和`N8N_EDITOR_BASE_URL`环境变量
- 如果问题仍然存在，可以考虑将n8n放在根路径，其他服务用子路径
- 如果团队使用或长期部署，建议一次性配置hosts使用子域名方案
     - 还会让其他人一起用
     - 未来可能接入 llama.cpp WebUI、监控面板等更多服务
     - 有可能需要通过外网域名 + HTTPS 暴露服务
     
     那么现在用 Nginx 把访问入口标准化（域名/路径），后续扩展和维护会轻松很多。

### 4.7 完整示例：同一 IP 下同时暴露 /n8n 与 /llama

下面给出一个完整的 `server` 配置示例，满足：

- `http://172.16.100.202/n8n` → 反向代理到本机 n8n（`http://127.0.0.1:5678`）
- `http://172.16.100.202/llama` → 反向代理到本机 llama.cpp HTTP server（假设为 `http://127.0.0.1:8080`）

```nginx
server {
    listen 80;
    server_name 172.16.100.202;

    # 可选：根路径返回一个简单文本，确认 Nginx 正常工作
    location = / {
        return 200 'OK';
        add_header Content-Type text/plain;
    }

    # 访问 /n8n 自动补斜杠
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

在宝塔中使用这段配置的典型做法：

1. 在“网站”中新建一个以 `172.16.100.202` 为域名的站点（纯静态即可）。
2. 打开该站点的 **设置 → 配置文件**，可以看到一个 `server { ... }` 块。
3. 将原有的 `server { ... }` 内容替换为上面的完整示例（或把其中各个 `location` 段合并到你的现有 `server` 中，保持 `listen` / `server_name` 一致）。
4. 保存后，宝塔会自动检测语法并重载 Nginx，如报错按提示修正。
5. 然后在浏览器中测试：
   - 访问 `http://172.16.100.202/n8n` → 自动跳转到 `/n8n/`，并打开 n8n 页面
   - 访问 `http://172.16.100.202/llama` → 自动跳转到 `/llama/`，并访问到 llama.cpp HTTP server 提供的 Web/API 界面

> 提醒：n8n 对子路径 `/n8n` 的支持有限，如遇前端资源 404 或回调 URL 问题，可以考虑给 n8n 单独使用根路径站点（如 `http://n8n.huanan/`），而把 `/llama` 留给 llama.cpp 使用。

---

## 5. 外网使用场景配置（公网域名 + HTTPS）

### 5.1 场景说明

- 你有一个公网域名，例如：`n8n.example.com`
- 已在域名服务商处添加解析：
  - `n8n.example.com -> 你的服务器公网 IP`
- 希望通过 **HTTPS + 域名** 访问 n8n 等服务

### 5.2 使用公网域名创建站点

1. 在宝塔“添加站点”时：
   - 域名填写：`n8n.example.com`
   - 类型：**纯静态**（作为反向代理入口即可）
   - 其余按默认
2. 创建完成后，在“网站 → 设置”中继续配置。

### 5.3 为站点申请 Let’s Encrypt 证书（HTTPS）

1. 打开网站 **设置 → SSL**
2. 选择：**Let’s Encrypt**
3. 在“域名列表”中勾选：`n8n.example.com`
4. 填写邮箱（用于证书通知）
5. 点击：**申请** 或 **申请并部署**
6. 成功后：
   - 宝塔会自动配置 `listen 443 ssl;` 和证书路径
   - 通常会自动添加 80 → 443 的重定向（强制 HTTPS）

> 如果申请失败，常见问题：
> - 域名解析未生效或指向错误 IP
> - 80 端口被防火墙或安全组拦截

### 5.4 外网反向代理到 n8n

假设 n8n 仍然监听：`http://127.0.0.1:5678`

1. 在 `n8n.example.com` 站点的 **设置 → 反向代理** 中：
   - 添加反向代理，目标 URL：`http://127.0.0.1:5678`
2. 保存后，宝塔会在对应 server 块中生成反代配置，效果类似：

```nginx
location / {
    proxy_pass http://127.0.0.1:5678;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

3. 配合 HTTPS：
   - 用户浏览器访问：`https://n8n.example.com`
   - Nginx 终结 TLS 后，通过 HTTP 把请求转发给本地的 n8n 服务。

### 5.5 外网场景下 n8n 环境变量建议

- `N8N_HOST=n8n.example.com`
- `N8N_PORT=5678`
- `N8N_PROTOCOL=https`（如果你希望 n8n 识别到自己是通过 HTTPS 对外）
- 可以保持：`N8N_SECURE_COOKIE=true`，提高安全性

在 systemd 服务中可以类似：

```ini
Environment=N8N_HOST=n8n.example.com
Environment=N8N_PORT=5678
Environment=N8N_PROTOCOL=https
Environment=N8N_SECURE_COOKIE=true
```

---

## 6. 内网 vs 外网 配置差异总结

| 项目 | 内网使用 | 外网使用 |
|------|----------|----------|
| 域名 | 可用 IP 或自定义内网域名（`n8n.huanan`） | 必须是已解析到本机的公网域名（`n8n.example.com`） |
| 访问协议 | 一般使用 HTTP 即可 | 强烈推荐使用 HTTPS（Let’s Encrypt） |
| 证书 | 一般不需要证书 | 需要申请并部署 TLS 证书 |
| n8n `N8N_PROTOCOL` | `http` | `https` |
| n8n `N8N_SECURE_COOKIE` | 多数情况设置为 `false`，避免 IP 访问被拦 | 一般保持 `true`，配合 HTTPS 更安全 |
| 访问范围 | 局域网内机器 | 任何能访问公网的人 |

---

## 7. 常见问题与排查

### 7.1 添加站点后访问不到

- 检查：
  - 站点是否已启用（网站列表中状态是否正常）
  - Nginx 是否在运行（软件商店 → Nginx 状态）
  - 防火墙/安全组是否放行 80/443 端口

### 7.2 域名访问失败但 IP 可以访问

- 检查域名解析：
  - 使用 `ping 域名` 看是否指向正确 IP
  - 在域名服务商控制台确认 A 记录生效
- 检查站点配置中的域名是否与访问的域名一致。

### 7.3 HTTPS 证书申请失败

- 确保：
  - 80 端口对外开放
  - 域名解析到当前服务器公网 IP
  - 同一域名没有被其他服务器占用（CDN / 其他反向代理）

### 7.4 通过 IP 访问 n8n 提示 secure cookie 问题

- 方案一：在 n8n 环境变量中设置 `N8N_SECURE_COOKIE=false`
- 方案二：使用域名 + HTTPS，并保持 `N8N_SECURE_COOKIE=true`

---

*最后更新：2025 年 11 月 26 日*
