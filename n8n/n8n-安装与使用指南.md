# n8n 安装与使用指南

## 目录
1. [n8n 简介](#n8n-简介)
2. [安装方法](#安装方法)
3. [启动与配置](#启动与配置)
4. [开机自启配置](#开机自启配置)
5. [基本使用](#基本使用)
6. [集成本地 llama.cpp 大模型](#集成本地-llamacpp-大模型)
7. [常见问题](#常见问题)

## n8n 简介

n8n 是一个开源的工作流自动化工具，可以通过可视化的方式连接不同的服务和 API，实现自动化任务。它支持数百种集成，包括数据库、云服务、通知工具等。

## 安装方法

### 方法一：全局安装（推荐）

```bash
# 全局安装 n8n
npm install -g n8n

# 验证安装
which n8n
n8n --version
```

### 方法二：使用 npx（临时使用）

```bash
# 直接运行（首次使用会自动下载）
npx n8n
```

### 方法三：Docker 安装

```bash
# 使用官方镜像
docker run -it --rm \
  --name n8n \
  -p 5678:5678 \
  -v ~/.n8n:/home/node/.n8n \
  n8nio/n8n
```

## 启动与配置

### 基本启动

```bash
# 全局安装后启动
n8n start

# 指定端口启动
n8n start --port 5678

# 后台运行
nohup n8n start > n8n.log 2>&1 &
```

### 环境变量配置

创建 `.env` 文件：

```bash
# 基本认证
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=your-username
N8N_BASIC_AUTH_PASSWORD=your-password

# 工作流设置
N8N_HOST=localhost
N8N_PORT=5678
N8N_PROTOCOL=http

# 数据存储
N8N_USER_FOLDER=/home/username/.n8n

# 时区设置
GENERIC_TIMEZONE=Asia/Shanghai
```

使用环境变量启动：

```bash
# 加载 .env 文件启动
source .env && n8n start
```

## 开机自启配置

### 使用 systemd（推荐）

1. **创建 systemd 服务文件**：

```bash
sudo nano /etc/systemd/system/n8n.service
```

2. **添加服务配置**：

```ini
[Unit]
Description=n8n - Workflow automation tool
After=network.target

[Service]
Type=simple
User=zhengxueen
Environment=PATH=/home/zhengxueen/.nvm/versions/node/v24.11.1/bin
Environment=GENERIC_TIMEZONE=Asia/Shanghai
Environment=N8N_HOST=localhost
Environment=N8N_PORT=5678
WorkingDirectory=/home/zhengxueen
ExecStart=/home/zhengxueen/.nvm/versions/node/v24.11.1/bin/n8n start
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

3. **启用并启动服务**：

```bash
# 重新加载 systemd 配置
sudo systemctl daemon-reload

# 设置开机自启
sudo systemctl enable n8n

# 启动服务
sudo systemctl start n8n

# 查看服务状态
sudo systemctl status n8n
```

4. **常用管理命令**：

```bash
# 查看服务状态
sudo systemctl status n8n

# 停止服务
sudo systemctl stop n8n

# 重启服务
sudo systemctl restart n8n

# 查看日志
sudo journalctl -u n8n -f
```

### 使用 PM2

1. **安装 PM2**：

```bash
npm install -g pm2
```

2. **创建 PM2 配置文件** `ecosystem.config.js`：

```javascript
module.exports = {
  apps: [{
    name: 'n8n',
    script: 'n8n',
    args: 'start',
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      GENERIC_TIMEZONE: 'Asia/Shanghai'
    }
  }]
};
```

3. **启动并设置开机自启**：

```bash
# 启动应用
pm2 start ecosystem.config.js

# 设置 PM2 开机自启
pm2 startup

# 保存当前进程列表
pm2 save
```

## 基本使用

### 访问 Web 界面

启动成功后，在浏览器中访问：
- 本地：http://localhost:5678
- 远程：http://your-server-ip:5678

### 创建第一个工作流

1. **登录界面**：首次访问需要创建管理员账户
2. **创建工作流**：点击 "Create new workflow"
3. **添加节点**：从右侧面板选择需要的节点
4. **配置节点**：设置节点的参数和认证
5. **连接节点**：拖拽连接各个节点
6. **测试工作流**：点击 "Test workflow" 按钮
7. **保存工作流**：配置完成后保存

### 常用节点类型

- **触发器**：Manual Trigger、Webhook、Cron、Schedule
- **HTTP 请求**：HTTP Request、Webhook
- **数据处理**：Set、Function、Code、IF
- **数据库**：MySQL、PostgreSQL、MongoDB
- **通知**：Email、Slack、DingTalk、WeChat
- **文件操作**：Read/Write Files、Google Drive

## 集成本地 llama.cpp 大模型

### 启动 llama.cpp 服务器

首先确保 llama.cpp 服务器正在运行：

```bash
# 设置环境变量
export HSA_OVERRIDE_GFX_VERSION=9.0.6
export HIP_VISIBLE_DEVICES=0

# 启动 llama-server
cd /path/to/llama.cpp/build-hip
./llama-server \
  --model /mnt/ssd/models/Qwen3VL-32B-Thinking-Q4_K_M.gguf \
  --ctx-size 32768 \
  --n-gpu-layers -1 \
  --host 0.0.0.0 \
  --port 8080 \
  --api-key local-llama-key \
  --alias qwen3-vl-32b
```

### 在 n8n 中配置 OpenAI 节点

1. **添加 HTTP Request 节点**
2. **配置节点参数**：

```json
{
  "method": "POST",
  "url": "http://localhost:8080/v1/chat/completions",
  "headers": {
    "Content-Type": "application/json",
    "Authorization": "Bearer local-llama-key"
  },
  "body": {
    "model": "qwen3-vl-32b",
    "messages": [
      {
        "role": "user",
        "content": "你好，请介绍一下自己"
      }
    ],
    "temperature": 0.7,
    "max_tokens": 2000
  }
}
```

3. **使用 OpenAI 兼容节点**：

如果使用 OpenAI 节点，配置如下：
- **Base URL**: `http://localhost:8080/v1`
- **API Key**: `local-llama-key`
- **Model**: `qwen3-vl-32b`

### 创建 AI 聊天工作流

1. **Manual Trigger** - 手动触发
2. **HTTP Request** - 调用本地 llama.cpp
3. **Set** - 处理响应数据
4. **Email** - 发送结果

示例配置：

```javascript
// Function 节点处理响应
const response = items[0].json;
return [{
  json: {
    model: response.model,
    content: response.choices[0].message.content,
    usage: response.usage
  }
}];
```

## 常见问题

### Q: n8n 启动失败怎么办？

**A:** 检查以下几点：
1. 端口是否被占用：`netstat -tulpn | grep 5678`
2. Node.js 版本是否兼容：`node --version`（推荐 v18+）
3. 查看错误日志：`sudo journalctl -u n8n -f`

### Q: 如何更改 n8n 的数据存储位置？

**A:** 设置环境变量 `N8N_USER_FOLDER`：

```bash
export N8N_USER_FOLDER=/path/to/your/n8n/data
n8n start
```

### Q: 如何配置反向代理？

**A:** 使用 Nginx 配置反向代理：

```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:5678;
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

### Q: 如何备份 n8n 数据？

**A:** 备份 n8n 数据目录：

```bash
# 停止 n8n 服务
sudo systemctl stop n8n

# 备份数据目录
tar -czf n8n-backup-$(date +%Y%m%d).tar.gz ~/.n8n

# 重启服务
sudo systemctl start n8n
```

### Q: 如何更新 n8n？

**A:** 全局安装的更新方法：

```bash
# 更新到最新版本
npm update -g n8n

# 或者卸载重装
npm uninstall -g n8n
npm install -g n8n
```

### Q: 性能优化建议？

**A:** 
1. 使用 SSD 存储 n8n 数据
2. 配置足够的内存（建议 4GB+）
3. 定期清理执行日志
4. 使用 PostgreSQL 替代 SQLite（生产环境推荐）

## 参考资源

- [n8n 官方文档](https://docs.n8n.io/)
- [n8n 社区](https://community.n8n.io/)
- [llama.cpp 文档](https://github.com/ggml-org/llama.cpp)
- [n8n 工作流示例](https://n8n.io/workflows/)

---

*最后更新：2025年11月26日*
