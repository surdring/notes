# Ubuntu 挂载 SMB 共享文件夹指南

## 1. 安装必要工具

```bash
sudo apt update
sudo apt install cifs-utils
```

## 2. 创建本地挂载点

```bash
sudo mkdir -p /mnt/smb_share
```

## 3. 创建凭据文件（推荐）

创建一个文件来存储SMB共享的用户名和密码：

```bash
sudo nano ~/.smb_credentials
```

添加以下内容（替换为实际的用户名和密码）：
```
username=your_username
password=your_password
domain=WORKGROUP  # 如果不需要可以删除这行
```

设置文件权限：
```bash
chmod 600 ~/.smb_credentials
```

## 4. 手动挂载SMB共享

```bash
sudo mount -t cifs //172.16.100.211/share /mnt/smb_share -o credentials=/home/$(whoami)/.smb_credentials,uid=$(id -u),gid=$(id -g),file_mode=0777,dir_mode=0777
```

## 5. 设置开机自动挂载

编辑 `/etc/fstab` 文件：

```bash
sudo nano /etc/fstab
```

添加以下行：
```
//172.16.100.211/share  /mnt/smb_share  cifs  credentials=/home/$(whoami)/.smb_credentials,uid=$(id -u),gid=$(id -g),file_mode=0777,dir_mode=0777,vers=3.0  0  0
```

> 注意：`vers=3.0` 指定SMB协议版本，根据服务器支持情况可以修改为 `2.0` 或 `1.0`

## 6. 一键挂载脚本

创建一个脚本文件 `mount_smb.sh`：

```bash
#!/bin/bash

# 配置参数
SHARE="//172.16.100.211/share"
MOUNT_POINT="/mnt/smb_share"
CREDENTIALS_FILE="$HOME/.smb_credentials"

# 检查挂载点是否存在，不存在则创建
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
sudo mount -t cifs "$SHARE" "$MOUNT_POINT" -o "credentials=$CREDENTIALS_FILE,uid=$(id -u),gid=$(id -g),file_mode=0777,dir_mode=0777,vers=3.0"

# 检查挂载是否成功
if [ $? -eq 0 ]; then
    echo "挂载成功!"
    echo "挂载点: $MOUNT_POINT"
    df -h | grep "$MOUNT_POINT"
else
    echo "挂载失败!"
    exit 1
fi
```

## 7. 使用说明

1. 给脚本添加执行权限：
   ```bash
   chmod +x mount_smb.sh
   ```

2. 运行脚本：
   ```bash
   ./mount_smb.sh
   ```

3. 访问共享文件夹：
   ```bash
   xdg-open /mnt/smb_share
   ```

4. 卸载共享（如需要）：
   ```bash
   sudo umount /mnt/smb_share
   ```

5. 创建桌面快捷方式（推荐使用第8节中的方法）

## 8. 创建桌面快捷方式

### 方法一：创建桌面启动器

1. 创建桌面启动器文件：

```bash
cat > ~/桌面/共享文件夹.desktop << 'EOL'
[Desktop Entry]
Version=1.0
Type=Application
Name=共享文件夹
Comment=访问 SMB 共享文件夹
Exec=/bin/bash -c "~/mount_smb.sh && xdg-open /mnt/smb_share"
Icon=network-server
Terminal=false
StartupNotify=true
EOL

# 设置执行权限
chmod +x ~/桌面/共享文件夹.desktop

# 标记为可信
gio set ~/桌面/共享文件夹.desktop "metadata::trusted" true
```

2. 如果双击没有反应，可以尝试以下替代方案：

### 方法二：使用 Nautilus 书签

1. 确保共享已挂载：
   ```bash
   ./mount_smb.sh
   ```

2. 打开文件管理器，导航到 `/mnt/smb_share`
3. 按 `Ctrl+D` 添加书签
4. 这样就会在左侧边栏看到这个书签

### 方法三：创建应用程序启动器

```bash
mkdir -p ~/.local/share/applications
cat > ~/.local/share/applications/smb-share.desktop << 'EOL'
[Desktop Entry]
Name=共享文件夹
Comment=打开 SMB 共享
Exec=/bin/bash -c "$HOME/mount_smb.sh && xdg-open /mnt/smb_share"
Icon=network-server
Terminal=false
Type=Application
Categories=Network;FileTools;
StartupNotify=true
EOL

# 复制到桌面
cp ~/.local/share/applications/smb-share.desktop ~/桌面/
chmod +x ~/桌面/smb-share.desktop
gio set ~/桌面/smb-share.desktop "metadata::trusted" true
```

## 9. 常见问题

### 1. 挂载失败：协议错误
如果遇到协议错误，可以尝试指定不同的SMB版本：
```bash
sudo mount -t cifs //172.16.100.211/share /mnt/smb_share -o credentials=/home/$(whoami)/.smb_credentials,vers=2.0
```

### 2. 权限问题
确保挂载点的权限设置正确：
```bash
sudo chmod 755 /mnt/smb_share
sudo chown $(whoami):$(whoami) /mnt/smb_share
```

### 3. 连接超时
检查网络连接和防火墙设置，确保可以访问SMB服务器：
```bash
ping 172.16.100.211
```

## 10. 故障排除

### 快捷方式无法正常工作
- 确保脚本有执行权限：`chmod +x ~/mount_smb.sh`
- 检查桌面环境是否支持 .desktop 文件
- 尝试在终端中直接运行脚本，查看错误信息

### 挂载点被占用
如果出现设备忙的错误，可以尝试强制卸载：
```bash
sudo umount -l /mnt/smb_share
```

## 注意事项

1. 确保SMB服务器已开启并允许来自您IP的连接
2. 凭据文件包含敏感信息，请确保其权限设置为600
3. 如果服务器支持，建议使用SMB 3.0或更高版本以获得更好的性能和安全性
4. 在公共计算机上使用时要特别小心，避免保存密码
