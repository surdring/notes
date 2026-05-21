# Ubuntu 配置 SMB 服务器共享指南

将本机目录共享给局域网内其他设备访问。

---

## 1. 安装 Samba 服务器

```bash
sudo apt update
sudo apt install samba samba-common-bin
```

## 2. 配置共享目录 `/mnt/easystore`

### 2.1 确保目录存在且有正确权限

```bash
# 检查目录是否存在
ls -la /mnt/easystore

# 设置目录权限（允许所有用户读写）
sudo chmod 777 /mnt/easystore

# 或者设置特定用户组权限
sudo chown -R $(whoami):$(whoami) /mnt/easystore
sudo chmod 755 /mnt/easystore
```

### 2.2 备份并编辑 Samba 配置文件

```bash
# 备份原配置
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.backup

# 编辑配置文件
sudo nano /etc/samba/smb.conf
```

### 2.3 在文件末尾添加共享配置

```ini
[easystore]
   comment = EasyStore Shared Folder
   path = /mnt/easystore
   browseable = yes
   read only = no
   writable = yes
   create mask = 0777
   directory mask = 0777
   # 允许所有用户访问（无需密码）
   guest ok = yes
   # 或者使用用户认证（更安全）
   # valid users = @smbusers
   # guest ok = no
```

## 3. 配置用户认证（可选，推荐用于家庭网络）

如果不想让共享完全开放，可以设置用户密码：

```bash
# 创建系统用户（如果还没有）
sudo useradd -M -s /sbin/nologin smbuser

# 设置 Samba 密码（会提示输入密码）
sudo smbpasswd -a smbuser

# 启用用户
sudo smbpasswd -e smbuser
```

然后修改 `smb.conf`：

```ini
[easystore]
   comment = EasyStore Shared Folder
   path = /mnt/easystore
   browseable = yes
   read only = no
   writable = yes
   create mask = 0775
   directory mask = 0775
   valid users = smbuser
   guest ok = no
```

## 4. 重启 Samba 服务

```bash
sudo systemctl restart smbd
sudo systemctl restart nmbd

# 设置开机自启
sudo systemctl enable smbd
sudo systemctl enable nmbd

# 检查服务状态
sudo systemctl status smbd
```

## 5. 防火墙配置（如果启用 UFW）

```bash
# 允许 Samba 服务通过防火墙
sudo ufw allow samba

# 或者允许特定端口
sudo ufw allow 139/tcp
sudo ufw allow 445/tcp
sudo ufw allow 137/udp
sudo ufw allow 138/udp
```

## 6. 测试配置

```bash
# 测试 smb.conf 语法是否正确
testparm

# 查看本机 IP 地址
ip addr show | grep "inet " | head -5
```

## 7. 在其他设备上访问

### Windows 访问

1. 打开文件资源管理器
2. 地址栏输入：`\\你的服务器IP\easystore`
   - 例如：`\\192.168.1.100\easystore`
3. 如果设置了用户认证，输入用户名 `smbuser` 和密码

### macOS 访问

1. 打开 Finder
2. 按 `Cmd+K`，输入：`smb://你的服务器IP/easystore`
3. 选择注册用户并输入凭据（如果设置了认证）

### Linux 访问

使用文件管理器或命令行：

```bash
# 文件管理器地址栏输入
smb://你的服务器IP/easystore

# 或者命令行挂载
sudo mount -t cifs //你的服务器IP/easystore /mnt/easystore_client -o username=smbuser
```

## 8. 一键配置脚本

创建脚本快速配置：

```bash
cat > ~/setup_smb_server.sh << 'EOF'
#!/bin/bash

SHARE_PATH="/mnt/easystore"
SHARE_NAME="easystore"

echo "=== 安装 Samba ==="
sudo apt update
sudo apt install -y samba samba-common-bin

echo "=== 配置共享目录 ==="
if [ ! -d "$SHARE_PATH" ]; then
    echo "创建目录: $SHARE_PATH"
    sudo mkdir -p "$SHARE_PATH"
fi

sudo chmod 777 "$SHARE_PATH"

echo "=== 备份并配置 Samba ==="
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.backup.$(date +%Y%m%d)

# 添加共享配置
sudo tee -a /etc/samba/smb.conf > /dev/null <<EOL

[$SHARE_NAME]
   comment = EasyStore Shared Folder
   path = $SHARE_PATH
   browseable = yes
   read only = no
   writable = yes
   create mask = 0777
   directory mask = 0777
   guest ok = yes
EOL

echo "=== 重启 Samba 服务 ==="
sudo systemctl restart smbd nmbd
sudo systemctl enable smbd nmbd

echo "=== 配置完成 ==="
echo "共享路径: $SHARE_PATH"
echo "共享名称: $SHARE_NAME"
echo ""
echo "本机 IP 地址:"
ip addr show | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | cut -d/ -f1
echo ""
echo "在其他设备上访问:"
echo "  Windows: \\\\$(ip addr show | grep 'inet ' | grep -v '127.0.0.1' | head -1 | awk '{print \$2}' | cut -d/ -f1)\\$SHARE_NAME"
echo "  macOS/Linux: smb://$(ip addr show | grep 'inet ' | grep -v '127.0.0.1' | head -1 | awk '{print $2}' | cut -d/ -f1)/$SHARE_NAME"
EOF

chmod +x ~/setup_smb_server.sh
```

运行脚本：

```bash
~/setup_smb_server.sh
```

## 9. 常用管理命令

```bash
# 查看当前连接
sudo smbstatus

# 列出所有共享
smbclient -L localhost -N

# 测试配置语法
testparm

# 查看 Samba 日志
sudo tail -f /var/log/samba/log.smbd

# 删除共享（编辑 smb.conf 删除对应段落后重启服务）
sudo nano /etc/samba/smb.conf
sudo systemctl restart smbd
```

## 10. 故障排除

### 无法访问共享

1. 检查服务是否运行：
   ```bash
   sudo systemctl status smbd
   ```

2. 检查防火墙：
   ```bash
   sudo ufw status
   ```

3. 检查 SELinux/AppArmor（如果有）：
   ```bash
   sudo getenforce  # 如果是 Enforcing，尝试临时设为 Permissive
   sudo setenforce 0
   ```

4. 检查目录权限：
   ```bash
   ls -la /mnt/easystore
   ```

### Windows 无法发现共享

- 确保 `nmbd` 服务正在运行
- 检查网络发现和文件共享是否开启

### 权限 denied

- 检查 `smb.conf` 中的 `valid users` 设置
- 检查目录文件系统权限
- 查看 Samba 日志：`sudo tail /var/log/samba/log.smbd`

## 注意事项

1. **安全性**：`guest ok = yes` 允许任何人访问，仅在可信的家庭网络使用
2. **备份数据**：共享前确保重要数据已备份
3. **网络隔离**：如果连接到公共网络，建议配置防火墙规则限制访问
4. **性能**：Samba 在千兆网络下传输速度通常可达 100MB/s 左右

---

完成配置后，家里的其他设备就可以通过网络访问 `/mnt/easystore` 目录了！
