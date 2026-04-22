# SMB 共享文件夹完整指南

> 本指南涵盖 **服务端（共享文件夹）** 和 **客户端（挂载共享）** 两部分配置

---

## 第一部分：服务端 — 共享文件夹

### 1. 安装 Samba

```bash
sudo apt update
sudo apt install samba
```

### 2. 创建 Samba 用户密码

Samba 密码独立于系统密码，需要单独设置：

```bash
# 添加 Samba 用户（用户必须已存在于系统中）
sudo smbpasswd -a zhengxueen

# 修改密码
sudo smbpasswd zhengxueen

# 删除用户
sudo smbpasswd -x zhengxueen
```

### 3. 配置共享

编辑配置文件：

```bash
sudo nano /etc/samba/smb.conf
```

在文件末尾添加共享配置：

```ini
[share]
   comment = share folder
   browseable = no
   path = /mnt/sata
   create mask = 0644
   directory mask = 0755
   valid users = zhengxueen
   invalid users = root
   force user = zhengxueen
   force group = zhengxueen
   public = no
   available = yes
   writable = yes
   hosts allow = 172.16.100.202, 172.16.100.180, 127.0.0.1
   hosts deny = ALL
   min protocol = SMB2
```

**配置说明：**

| 参数 | 值 | 说明 |
|------|----|------|
| `path` | `/mnt/sata` | 共享目录路径 |
| `valid users` | `zhengxueen` | 只允许此用户访问 |
| `invalid users` | `root` | 显式禁止 root 访问 |
| `public` | `no` | 禁止访客访问，必须输入密码 |
| `browseable` | `no` | 网络上不可被发现，需手动输入共享名 |
| `writable` | `yes` | 允许写入 |
| `force user` | `zhengxueen` | 所有操作以此用户身份执行 |
| `create mask` | `0644` | 新文件权限：所有者读写，其他人只读 |
| `directory mask` | `0755` | 新目录权限：所有者读写执行，其他人可读执行 |
| `hosts allow` | 特定 IP | 仅允许白名单 IP 连接 |
| `hosts deny` | `ALL` | 拒绝所有未在白名单的 IP |
| `min protocol` | `SMB2` | 禁止不安全的 SMB1 协议 |

### 4. 验证配置并重启服务

```bash
# 检查配置语法
sudo testparm

# 重启 Samba 服务
sudo systemctl restart smbd nmbd

# 设置开机自启
sudo systemctl enable smbd nmbd
```

### 5. 配置日志级别

默认日志级别为 1（仅记录错误），需设置为 2 才能记录连接和认证信息：

```bash
sudo nano /etc/samba/smb.conf
```

在 `[global]` 段添加：

```ini
   log level = 2
```

重启生效：

```bash
sudo systemctl restart smbd nmbd
```

**日志级别说明：**

| 级别 | 记录内容 |
|------|----------|
| 0 | 仅严重错误 |
| 1 | 默认，仅错误 |
| **2** | **连接/认证记录（推荐）** |
| 3 | 详细连接信息 |
| 5+ | 调试级别（日志量大） |

### 6. 查看当前共享状态

```bash
# 查看共享列表
smbclient -L localhost -U zhengxueen

# 查看当前活跃连接
sudo smbstatus

# 查看历史连接过的设备（日志文件名即设备标识）
sudo ls /var/log/samba/ | grep "^log\."
```

---

## 第二部分：客户端 — 挂载远程 SMB 共享

### 1. 安装必要工具

```bash
sudo apt update
sudo apt install cifs-utils
```

### 2. 创建本地挂载点

```bash
sudo mkdir -p /mnt/smb_share
```

### 3. 创建凭据文件

将用户名和密码保存在文件中，避免在命令行中暴露：

```bash
nano ~/.smb_credentials
```

写入以下内容（替换为实际的用户名和密码）：

```
username=zhengxueen
password=你的Samba密码
domain=WORKGROUP
```

设置安全权限（仅所有者可读写）：

```bash
chmod 600 ~/.smb_credentials
```

### 4. 手动挂载

```bash
sudo mount -t cifs //172.16.100.211/share /mnt/smb_share \
  -o credentials=$HOME/.smb_credentials,uid=$(id -u),gid=$(id -g),vers=3.0
```

### 5. 设置开机自动挂载

编辑 `/etc/fstab`：

```bash
sudo nano /etc/fstab
```

添加以下行（**注意：`uid` 和 `gid` 需替换为实际数值**）：

```
//172.16.100.211/share  /mnt/smb_share  cifs  credentials=/home/zhengxueen/.smb_credentials,uid=1000,gid=1000,vers=3.0  0  0
```

> ⚠️ `fstab` 中不能使用 `$HOME` 或 `$(id -u)` 等变量，必须写死实际数值。
> 可通过 `id zhengxueen` 查看 uid 和 gid。

### 6. 一键挂载脚本

创建脚本文件：

```bash
nano ~/mount_smb.sh
```

写入以下内容：

```bash
#!/bin/bash

# 配置参数
SHARE="//172.16.100.211/share"
MOUNT_POINT="/mnt/smb_share"
CREDENTIALS_FILE="$HOME/.smb_credentials"

# 检查挂载点是否存在
if [ ! -d "$MOUNT_POINT" ]; then
    echo "创建挂载点: $MOUNT_POINT"
    sudo mkdir -p "$MOUNT_POINT"
fi

# 检查是否已挂载
if mount | grep -q "$MOUNT_POINT"; then
    echo "$MOUNT_POINT 已经挂载"
    exit 0
fi

# 检查凭据文件是否存在
if [ ! -f "$CREDENTIALS_FILE" ]; then
    echo "错误: 凭据文件 $CREDENTIALS_FILE 不存在"
    echo "请先创建凭据文件并设置正确的用户名和密码"
    exit 1
fi

# 挂载共享
echo "正在挂载 $SHARE 到 $MOUNT_POINT ..."
sudo mount -t cifs "$SHARE" "$MOUNT_POINT" \
  -o "credentials=$CREDENTIALS_FILE,uid=$(id -u),gid=$(id -g),vers=3.0"

# 检查挂载是否成功
if [ $? -eq 0 ]; then
    echo "挂载成功!"
    df -h | grep "$MOUNT_POINT"
else
    echo "挂载失败!"
    exit 1
fi
```

添加执行权限：

```bash
chmod +x ~/mount_smb.sh
```

### 7. 卸载共享

```bash
# 正常卸载
sudo umount /mnt/smb_share

# 设备忙时强制卸载
sudo umount -l /mnt/smb_share
```

---

## 第三部分：从其他设备访问

### Windows

1. 按 `Win + R`，输入：
   ```
   \\172.16.100.211\share
   ```
2. 输入用户名 `zhengxueen` 和 Samba 密码

### macOS

1. 打开 Finder → 前往 → 连接服务器（`⌘ + K`）
2. 输入地址：
   ```
   smb://172.16.100.211/share
   ```
3. 输入用户名和密码

### Linux（图形界面）

1. 打开文件管理器
2. 地址栏输入：
   ```
   smb://172.16.100.211/share
   ```

---

## 第四部分：常见问题

### 1. 挂载失败：协议错误

指定不同的 SMB 版本：

```bash
# 尝试 SMB 2.0
sudo mount -t cifs //172.16.100.211/share /mnt/smb_share \
  -o credentials=$HOME/.smb_credentials,vers=2.0

# 尝试 SMB 1.0（不推荐）
sudo mount -t cifs //172.16.100.211/share /mnt/smb_share \
  -o credentials=$HOME/.smb_credentials,vers=1.0
```

### 2. 权限问题

```bash
# 修改挂载点权限
sudo chmod 755 /mnt/smb_share
sudo chown zhengxueen:zhengxueen /mnt/smb_share
```

### 3. 连接超时

```bash
# 检查网络连通性
ping 172.16.100.211

# 检查 Samba 端口（445 和 139）
nc -zv 172.16.100.211 445
```

### 4. Windows 无法访问

- 确认 Windows 已启用 SMB 客户端：控制面板 → 程序 → 启用 Windows 功能 → SMB 1.0/CIFS 客户端
- 检查防火墙是否放行 445 端口

### 5. fstab 自动挂载失败导致无法开机

进入恢复模式后编辑 fstab 删除挂载行：

```bash
sudo nano /etc/fstab
# 删除或注释 SMB 挂载行
```

---

## 第五部分：访问记录监控

### 1. 当前活跃连接

```bash
sudo smbstatus
```

输出示例：

```
PID     Username     Group        Machine                                   Protocol Version
2221407 zhengxueen   zhengxueen   172.16.100.202 (ipv4:172.16.100.202:58196)  SMB3_11

Service      pid     Machine       Connected at
share        2221407 172.16.100.202 三 4月 22 10时18分51秒 2026 CST
```

### 2. 历史连接设备

日志文件名即设备标识（IP 或主机名）：

```bash
sudo ls /var/log/samba/ | grep "^log\."
```

当前已知连接过的设备：

| IP 地址 | 主机名 | 说明 |
|---------|--------|------|
| `172.16.100.180` | - | 曾连接 |
| `172.16.100.199` | - | 曾连接 |
| `172.16.100.202` | - | 当前在线 |
| `172.16.100.225` | - | 曾连接 |
| `172.16.100.245` | - | 曾连接 |
| - | `dell-pc` | Dell 电脑 |
| - | `desktop-bro9dm2` | 桌面设备 |
| - | `desktop-ilarfhm` | 桌面设备 |
| - | `win-20250623omg` | Windows 设备 |
| - | `vostro-3890` | Dell Vostro 笔记本 |

### 3. 访问记录分析脚本

使用 `smb_access_log.py` 自动扫描所有设备日志：

```bash
sudo python3 /mnt/sata/knowledge/notes/ubuntu-system/smb_access_log.py
```

> ⚠️ 需要 `log level = 2` 才能记录访问信息，否则日志为空。

---

## 注意事项

1. Samba 密码与系统登录密码**独立**，需通过 `smbpasswd` 单独设置
2. 凭据文件 `~/.smb_credentials` 包含敏感信息，权限必须设为 `600`
3. `fstab` 中不能使用 shell 变量，`uid`/`gid` 需写死数值
4. 建议使用 SMB 3.0 以获得更好的性能和安全性
5. 公共网络环境下务必设置密码，禁止访客访问（`public = no`）
6. 需设置 `log level = 2` 才能记录访问日志，默认级别不记录连接信息
