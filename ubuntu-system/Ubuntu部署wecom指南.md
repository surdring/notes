# 企微应用回复机器人 - Ubuntu 部署指南

本指南详细说明如何在 Ubuntu 服务器上部署企微应用回复机器人，特别关注 Oracle 数据库连接配置。

## 系统要求

- Ubuntu 20.04 LTS 或更高版本
- Python 3.11 或更高版本
- 至少 2GB RAM
- 至少 10GB 磁盘空间

## 一、准备工作

### 1.1 更新系统

```bash
sudo apt update
sudo apt upgrade -y
```

### 1.2 安装系统依赖

```bash
sudo apt install -y \
    python3.11 \
    python3.11-venv \
    python3-pip \
    git \
    curl \
    wget \
    unzip \
    libaio1 \
    build-essential
```

## 二、安装 Oracle Instant Client（重要）

物料启用功能需要连接 Oracle 数据库，必须安装 Oracle Instant Client。

### 2.1 下载 Oracle Instant Client

访问 Oracle 官网下载页面：
https://www.oracle.com/database/technologies/instant-client/linux-x86-64-downloads.html

下载以下两个包（选择与你的 Oracle 数据库版本兼容的版本）：
- `instantclient-basic-linux.x64-<version>.zip`
- `instantclient-sqlplus-linux.x64-<version>.zip`（可选，用于测试）

**推荐版本**：
- Oracle 11g 数据库：使用 Instant Client 11.2
- Oracle 19c 数据库：使用 Instant Client 19.x 或 21.x

### 2.2 安装 Instant Client

```bash
# 创建安装目录
sudo mkdir -p /opt/oracle

# 解压下载的文件（假设下载到 ~/downloads）
cd ~/downloads
sudo unzip instantclient-basic-linux.x64-11.2.0.4.0.zip -d /opt/oracle
sudo unzip instantclient-sqlplus-linux.x64-11.2.0.4.0.zip -d /opt/oracle

# 创建符号链接
cd /opt/oracle/instantclient_11_2
sudo ln -s libclntsh.so.11.1 libclntsh.so
sudo ln -s libocci.so.11.1 libocci.so
```

### 2.3 配置环境变量

编辑 `/etc/profile.d/oracle.sh`：

```bash
sudo nano /etc/profile.d/oracle.sh
```

添加以下内容：

```bash
export ORACLE_HOME=/opt/oracle/instantclient_11_2
export LD_LIBRARY_PATH=$ORACLE_HOME:$LD_LIBRARY_PATH
export PATH=$ORACLE_HOME:$PATH
```

使配置生效：

```bash
source /etc/profile.d/oracle.sh
```

### 2.4 验证安装

```bash
# 检查库文件
ls -l $ORACLE_HOME/libclntsh.so

# 测试 sqlplus（如果安装了）
sqlplus -v
```

## 三、部署应用

### 3.1 创建应用用户

```bash
# 创建专用用户
sudo useradd -m -s /bin/bash wecombot

# 切换到应用用户
sudo su - wecombot
```

### 3.2 克隆代码

```bash
cd ~
git clone <your-repo-url> wecom-bot
cd wecom-bot
```

或者通过 SCP 上传代码：

```bash
# 在本地执行
scp -r wecom-bot user@server-ip:/home/wecombot/
```

### 3.3 创建虚拟环境

```bash
cd ~/wecom-bot
python3.11 -m venv venv
source venv/bin/activate
```

### 3.4 安装 Python 依赖

```bash
pip install --upgrade pip
pip install -r requirements.txt
```

**注意**：如果 `oracledb` 安装失败，确保已正确安装 Oracle Instant Client。

### 3.5 配置环境变量

```bash
cp .env.example .env
nano .env
```

填写配置信息（参考主 README）：

```bash
# 企微配置
WECOM_CORP_ID=your_corp_id
WECOM_TOKEN=your_token
WECOM_ENCODING_AES_KEY=your_aes_key
WECOM_AGENT_ID=your_agent_id
WECOM_CORP_SECRET=your_corp_secret

# LLM 配置
LLM_PROVIDER=openrouter
LLM_BASE_URL=https://openrouter.ai/api/v1
LLM_API_KEY=your_api_key
LLM_MODEL=z-ai/glm-4.5-air:free

# Oracle 数据库配置
DB_HOST=192.168.80.90
DB_PORT=1521
DB_USER=dhnc65
DB_PASSWORD=dhnc65
DB_NAME=ORCL

# 服务配置
APP_HOST=0.0.0.0
APP_PORT=8001
```

### 3.6 测试运行

```bash
# 激活虚拟环境
source venv/bin/activate

# 启动服务
python run.py
```

访问 `http://server-ip:8001/healthz` 检查服务是否正常。

按 `Ctrl+C` 停止服务。

## 四、配置 systemd 服务

### 4.1 创建服务文件

退出 wecombot 用户，切换回 root 或 sudo 用户：

```bash
exit  # 退出 wecombot 用户
sudo nano /etc/systemd/system/wecombot.service
```

添加以下内容：

```ini
[Unit]
Description=WeCom Bot Application
After=network.target

[Service]
Type=simple
User=wecombot
Group=wecombot
WorkingDirectory=/home/wecombot/wecom-bot
Environment="PATH=/home/wecombot/wecom-bot/venv/bin"
Environment="ORACLE_HOME=/opt/oracle/instantclient_11_2"
Environment="LD_LIBRARY_PATH=/opt/oracle/instantclient_11_2"
ExecStart=/home/wecombot/wecom-bot/venv/bin/python run.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

### 4.2 启动服务

```bash
# 重载 systemd 配置
sudo systemctl daemon-reload

# 启动服务
sudo systemctl start wecombot

# 设置开机自启
sudo systemctl enable wecombot

# 查看服务状态
sudo systemctl status wecombot

# 查看日志
sudo journalctl -u wecombot -f
```

### 4.3 常用命令

```bash
# 停止服务
sudo systemctl stop wecombot

# 重启服务
sudo systemctl restart wecombot

# 查看日志（最近 100 行）
sudo journalctl -u wecombot -n 100

# 实时查看日志
sudo journalctl -u wecombot -f
```

## 五、配置 Nginx 反向代理（可选）

如果需要使用域名访问或配置 HTTPS：

### 5.1 安装 Nginx

```bash
sudo apt install -y nginx
```

### 5.2 配置 Nginx

```bash
sudo nano /etc/nginx/sites-available/wecombot
```

添加以下内容：

```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://127.0.0.1:8001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

启用配置：

```bash
sudo ln -s /etc/nginx/sites-available/wecombot /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

### 5.3 配置 HTTPS（推荐）

使用 Let's Encrypt 免费证书：

```bash
# 安装 Certbot
sudo apt install -y certbot python3-certbot-nginx

# 获取证书并自动配置 Nginx
sudo certbot --nginx -d your-domain.com

# 测试自动续期
sudo certbot renew --dry-run
```

## 六、Oracle 数据库连接测试

### 6.1 使用 Python 测试连接

创建测试脚本 `test_oracle.py`：

```python
import oracledb

# 连接信息
dsn = "192.168.80.90:1521/ORCL"
user = "dhnc65"
password = "dhnc65"

try:
    # 连接数据库
    connection = oracledb.connect(
        user=user,
        password=password,
        dsn=dsn
    )
    
    print("✅ Oracle 数据库连接成功！")
    print(f"Oracle 版本: {connection.version}")
    
    # 测试查询
    cursor = connection.cursor()
    cursor.execute("SELECT 1 FROM DUAL")
    result = cursor.fetchone()
    print(f"测试查询结果: {result}")
    
    cursor.close()
    connection.close()
    
except Exception as e:
    print(f"❌ 连接失败: {e}")
```

运行测试：

```bash
source venv/bin/activate
python test_oracle.py
```

### 6.2 常见问题

**问题1：找不到 libclntsh.so**

```bash
# 解决方法：确认环境变量
echo $LD_LIBRARY_PATH
# 应该包含 /opt/oracle/instantclient_11_2

# 如果没有，重新加载环境变量
source /etc/profile.d/oracle.sh
```

**问题2：TNS 无法解析**

```bash
# 检查 DSN 格式
# 正确格式：host:port/service_name
# 示例：192.168.80.90:1521/ORCL
```

**问题3：权限不足**

```bash
# 确保 wecombot 用户可以访问 Oracle 库文件
sudo chmod -R 755 /opt/oracle/instantclient_11_2
```

## 七、防火墙配置

### 7.1 开放端口

```bash
# 开放应用端口（如果使用 Nginx，可以不开放）
sudo ufw allow 8001/tcp

# 开放 HTTP/HTTPS（如果使用 Nginx）
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# 启用防火墙
sudo ufw enable

# 查看状态
sudo ufw status
```

## 八、监控和维护

### 8.1 日志管理

```bash
# 查看应用日志
sudo journalctl -u wecombot -n 100

# 查看错误日志
sudo journalctl -u wecombot -p err

# 清理旧日志（保留最近 7 天）
sudo journalctl --vacuum-time=7d
```

### 8.2 性能监控

```bash
# 查看进程状态
ps aux | grep python

# 查看资源占用
top -p $(pgrep -f "python run.py")

# 查看网络连接
sudo netstat -tlnp | grep 8001
```

### 8.3 备份配置

```bash
# 备份配置文件
sudo cp /home/wecombot/wecom-bot/.env /home/wecombot/wecom-bot/.env.backup.$(date +%Y%m%d)

# 备份数据库配置
sudo cp /etc/systemd/system/wecombot.service /etc/systemd/system/wecombot.service.backup
```

## 九、故障排查

### 9.1 服务无法启动

```bash
# 查看详细错误信息
sudo journalctl -u wecombot -n 50 --no-pager

# 检查配置文件
cat /home/wecombot/wecom-bot/.env

# 检查端口占用
sudo lsof -i :8001
```

### 9.2 Oracle 连接失败

```bash
# 检查网络连通性
telnet 192.168.80.90 1521

# 检查 Oracle 客户端
ls -l /opt/oracle/instantclient_11_2/libclntsh.so

# 检查环境变量
sudo -u wecombot env | grep ORACLE
```

### 9.3 企微回调失败

```bash
# 检查服务是否运行
sudo systemctl status wecombot

# 检查健康检查接口
curl http://localhost:8001/healthz

# 查看回调日志
sudo journalctl -u wecombot -f | grep "收到企微回调"
```

## 十、安全建议

1. **使用非 root 用户运行服务**（已配置）
2. **配置防火墙**，只开放必要端口
3. **使用 HTTPS**，保护数据传输
4. **定期更新系统和依赖**
5. **备份配置文件和数据库**
6. **监控日志**，及时发现异常
7. **限制数据库用户权限**，只授予必要的权限

## 十一、更新应用

```bash
# 切换到应用用户
sudo su - wecombot

# 拉取最新代码
cd ~/wecom-bot
git pull

# 更新依赖
source venv/bin/activate
pip install -r requirements.txt --upgrade

# 退出应用用户
exit

# 重启服务
sudo systemctl restart wecombot

# 查看日志确认启动成功
sudo journalctl -u wecombot -f
```

## 附录：完整部署脚本

创建自动化部署脚本 `deploy.sh`：

```bash
#!/bin/bash
set -e

echo "=== 企微应用回复机器人部署脚本 ==="

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then 
    echo "请使用 sudo 运行此脚本"
    exit 1
fi

# 1. 更新系统
echo "步骤 1/8: 更新系统..."
apt update && apt upgrade -y

# 2. 安装依赖
echo "步骤 2/8: 安装系统依赖..."
apt install -y python3.11 python3.11-venv python3-pip git curl wget unzip libaio1 build-essential

# 3. 创建用户
echo "步骤 3/8: 创建应用用户..."
if ! id "wecombot" &>/dev/null; then
    useradd -m -s /bin/bash wecombot
fi

# 4. 提示安装 Oracle Instant Client
echo "步骤 4/8: Oracle Instant Client"
echo "请手动安装 Oracle Instant Client 到 /opt/oracle/"
echo "按任意键继续..."
read -n 1

# 5. 部署应用
echo "步骤 5/8: 部署应用..."
sudo -u wecombot bash << 'EOF'
cd ~
if [ ! -d "wecom-bot" ]; then
    echo "请将代码上传到 /home/wecombot/wecom-bot"
    exit 1
fi
cd wecom-bot
python3.11 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
EOF

# 6. 配置 systemd
echo "步骤 6/8: 配置 systemd 服务..."
cat > /etc/systemd/system/wecombot.service << 'EOF'
[Unit]
Description=WeCom Bot Application
After=network.target

[Service]
Type=simple
User=wecombot
Group=wecombot
WorkingDirectory=/home/wecombot/wecom-bot
Environment="PATH=/home/wecombot/wecom-bot/venv/bin"
Environment="ORACLE_HOME=/opt/oracle/instantclient_11_2"
Environment="LD_LIBRARY_PATH=/opt/oracle/instantclient_11_2"
ExecStart=/home/wecombot/wecom-bot/venv/bin/python run.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 7. 启动服务
echo "步骤 7/8: 启动服务..."
systemctl daemon-reload
systemctl enable wecombot
systemctl start wecombot

# 8. 检查状态
echo "步骤 8/8: 检查服务状态..."
sleep 3
systemctl status wecombot

echo "=== 部署完成 ==="
echo "请编辑 /home/wecombot/wecom-bot/.env 配置文件"
echo "然后运行: sudo systemctl restart wecombot"
```

使用方法：

```bash
chmod +x deploy.sh
sudo ./deploy.sh
```

---

## 技术支持

如遇问题，请查看：
- 应用日志：`sudo journalctl -u wecombot -f`
- 主项目 README：`../README.md`
- 需求文档：`../docs/企微应用回复_需求文档.md`
- 架构文档：`../docs/架构设计文档.md`
