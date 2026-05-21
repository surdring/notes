# OpenSSH Server 安装与使用指南

## 目录
- [安装](#安装)
- [服务管理](#服务管理)
- [基本配置](#基本配置)
- [用户登录配置](#用户登录配置)
- [安全加固](#安全加固)
- [防火墙设置](#防火墙设置)
- [客户端连接](#客户端连接)
- [常见问题](#常见问题)

---

## 安装

### 安装 OpenSSH Server

```bash
sudo apt update
sudo apt install openssh-server
```

### 验证安装

```bash
ssh -V                    # 查看版本
sudo systemctl status ssh # 查看服务状态
```

---

## 服务管理

### 启动、停止、重启

```bash
# 启动服务
sudo systemctl start ssh

# 停止服务
sudo systemctl stop ssh

# 重启服务
sudo systemctl restart ssh

# 重载配置（不中断连接）
sudo systemctl reload ssh
```

### 开机自启

```bash
# 启用开机自启
sudo systemctl enable ssh

# 禁用开机自启
sudo systemctl disable ssh
```

---

## 基本配置

配置文件路径：`/etc/ssh/sshd_config`

### 修改配置

```bash
sudo nano /etc/ssh/sshd_config
# 或
sudo vim /etc/ssh/sshd_config
```

### 常用配置项

```bash
# 修改默认端口（推荐，提高安全性）
Port 2222

# 监听地址（默认监听所有）
ListenAddress 0.0.0.0

# 允许的用户
AllowUsers zheng admin

# 禁止的用户
DenyUsers root guest

# 允许的组
AllowGroups sshusers

# 禁止 root 密码登录（仅密钥）
PermitRootLogin prohibit-password

# 完全禁止 root 登录
PermitRootLogin no

# 允许 root 密码登录（不推荐）
PermitRootLogin yes

# 密码认证
PasswordAuthentication yes

# 密钥认证
PubkeyAuthentication yes

# 空密码禁止登录
PermitEmptyPasswords no

# 最大认证尝试次数
MaxAuthTries 3

# 客户端超时时间（秒）
ClientAliveInterval 300
ClientAliveCountMax 2
```

### 配置生效

```bash
sudo systemctl reload ssh
# 或
sudo systemctl restart ssh
```

### ⚠️ 修改端口后仍监听 22 的问题

Ubuntu 使用 systemd socket 激活 SSH，可能覆盖 `sshd_config` 中的端口设置。

**症状**：已设置 `Port 2222`，但 `sshd` 仍监听 22 端口。

**解决方法**——修改 socket 配置：

```bash
# 创建 socket 覆盖配置
sudo mkdir -p /etc/systemd/system/ssh.socket.d
sudo tee /etc/systemd/system/ssh.socket.d/port.conf << 'EOF'
[Socket]
ListenStream=
ListenStream=0.0.0.0:2222
ListenStream=[::]:2222
EOF

# 重载并重启
sudo systemctl daemon-reload
sudo systemctl restart ssh.socket ssh

# 验证端口
sudo ss -tlnp | grep 2222
```

---

## 用户登录配置

### 默认行为

| 用户类型 | 默认能否登录 | 方式 |
|---------|-------------|------|
| 普通用户 | ✅ 可以 | 密码 / 密钥 |
| root | ⚠️ 仅密钥 | 禁止密码 |

### 启用 root 密码登录（不推荐用于生产环境）

```bash
# 1. 设置 root 密码
sudo passwd root

# 2. 修改 SSH 配置
sudo nano /etc/ssh/sshd_config

# 添加或修改这一行
PermitRootLogin yes

# 3. 重启服务
sudo systemctl restart ssh
```

### 查看当前生效配置

```bash
sudo sshd -T | grep -E "permitrootlogin|passwordauthentication|port"
```

---

## 安全加固

### 1. 修改默认端口

```bash
# 编辑配置
sudo nano /etc/ssh/sshd_config

# 修改端口
Port 2222

# 重启服务
sudo systemctl restart ssh
```

连接时使用新端口：
```bash
ssh -p 2222 user@hostname

# 更多连接示例
# 使用 IP 地址
ssh -p 6001 zheng@47.96.159.100

# 使用域名
ssh -p 2222 admin@server.example.com

# 使用特定私钥
ssh -p 2222 -i ~/.ssh/my_key user@hostname

# 执行远程命令后直接退出
ssh -p 2222 user@hostname "ls -la /var/log"

# 启用压缩（适合慢速网络）
ssh -p 2222 -C user@hostname
```

### 2. 禁用密码认证（仅使用密钥）

```bash
# 生成密钥对（客户端执行）
ssh-keygen -t ed25519 -C "your_email@example.com"

# 复制公钥到服务器
ssh-copy-id user@server_ip

# 服务器禁用密码登录
sudo nano /etc/ssh/sshd_config
PasswordAuthentication no
ChallengeResponseAuthentication no

sudo systemctl restart ssh
```

### 3. 使用 Fail2Ban 防止暴力破解

```bash
# 安装
sudo apt install fail2ban

# 配置
sudo nano /etc/fail2ban/jail.local
```

```ini
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
```

```bash
sudo systemctl restart fail2ban
```

### 4. 解决 SSH 空闲连接中断问题

通过 FRP 等内网穿透工具连接时，经常遇到 `Connection closed by remote host` 错误。

#### 问题原因

| 来源 | 默认超时 | 说明 |
|-----|---------|------|
| FRP TCP 代理 | 90 秒无活动 | 没有心跳检测 |
| SSH 服务器 | 不主动检测 | `ClientAliveInterval` 默认为 0 |
| NAT 网关 | 5-15 分钟 | 路由器清理空闲连接 |

#### 解决方法（可同时使用）

**方案 A：SSH 客户端心跳（在连接端配置）**

命令行参数：
```bash
ssh -p 6001 -o ServerAliveInterval=30 -o ServerAliveCountMax=3 user@host

ssh -p 6001 -o ServerAliveInterval=30 -o ServerAliveCountMax=3 zheng@47.96.159.100

```

或写入 `~/.ssh/config`：
```bash
Host frp-ssh
    HostName 47.96.159.100
    Port 6001
    User zheng
    ServerAliveInterval 30
    ServerAliveCountMax 3
```

**方案 B：SSH 服务器端配置（推荐，一劳永逸）**

编辑 `/etc/ssh/sshd_config`：
```bash
# 每 30 秒发送心跳检测
ClientAliveInterval 30
# 连续 3 次无响应才断开
ClientAliveCountMax 3
```

然后重载配置：
```bash
sudo systemctl reload ssh
```

**方案 C：FRP 心跳配置**

在 `frpc.toml` 全局部分添加：
```toml
transport.heartbeatInterval = 30
transport.heartbeatTimeout = 90
```

或旧版 `frpc.ini`：
```ini
[common]
heartbeat_interval = 30
heartbeat_timeout = 90
```

> 💡 **建议**：方案 B + 方案 C 同时使用，服务端和隧道双保活，最稳定。
>
> 📖 详细 FRP 配置（含 TOML 格式注意事项）请参考：[FRP 内网穿透全流程部署指南](./FRP%20内网穿透全流程部署指南.md)

---

## 防火墙设置

### UFW 防火墙

```bash
# 允许 SSH（默认端口 22）
sudo ufw allow ssh

# 允许指定端口（如修改为 2222）
sudo ufw allow 2222/tcp

# 删除旧规则
sudo ufw delete allow ssh

# 查看状态
sudo ufw status
```

### iptables

```bash
# 允许端口 22
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# 允许端口 2222
sudo iptables -A INPUT -p tcp --dport 2222 -j ACCEPT
```

---

## 客户端连接

### 基本连接

```bash
# 默认端口 22
ssh username@server_ip

# 指定端口
ssh -p 2222 username@server_ip

# 使用密钥
ssh -i ~/.ssh/private_key username@server_ip

# 指定用户和端口
ssh -p 2222 -l username server_ip
```

### SCP 文件传输

```bash
# 上传文件
scp -P 2222 local_file username@server_ip:/remote/path/

# 下载文件
scp -P 2222 username@server_ip:/remote/file ./local/

# 上传目录
scp -r -P 2222 local_dir username@server_ip:/remote/path/
```

---

## 常见问题

### 问题 1：连接被拒绝

```bash
# 检查服务是否运行
sudo systemctl status ssh

# 检查端口监听
sudo ss -tlnp | grep ssh

# 检查防火墙
sudo ufw status
```

### 问题 2：认证失败

```bash
# 查看认证日志
sudo tail -f /var/log/auth.log

# 检查用户是否存在
id username

# 检查用户密码
sudo passwd username
```

### 问题 3：配置错误导致无法连接

```bash
# 测试配置语法
sudo sshd -t

# 查看详细日志
sudo sshd -d -p 2223  # 调试模式，端口 2223
```

### 问题 4：权限被拒绝（公钥认证）

```bash
# 服务器上检查权限
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys

# 检查 SELinux（如启用）
ls -Z ~/.ssh/authorized_keys
restorecon -R ~/.ssh
```

---

## 快速参考

| 操作 | 命令 |
|-----|------|
| 安装 | `sudo apt install openssh-server` |
| 启动 | `sudo systemctl start ssh` |
| 停止 | `sudo systemctl stop ssh` |
| 重启 | `sudo systemctl restart ssh` |
| 查看状态 | `sudo systemctl status ssh` |
| 开机自启 | `sudo systemctl enable ssh` |
| 测试配置 | `sudo sshd -t` |
| 查看生效配置 | `sudo sshd -T` |

---

## 相关文件路径

| 文件 | 路径 |
|-----|------|
| 服务器配置文件 | `/etc/ssh/sshd_config` |
| 客户端配置文件 | `/etc/ssh/ssh_config` |
| 主机密钥 | `/etc/ssh/ssh_host_*` |
| 认证日志 | `/var/log/auth.log` |
| 用户公钥 | `~/.ssh/authorized_keys` |

---

*文档版本: 1.0*  
*适用系统: Ubuntu 20.04/22.04/24.04*
