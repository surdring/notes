# Ubuntu 创建 NTFS 分区桌面快捷方式指南

## 1. 创建桌面快捷方式

### 方法一：使用图形界面（推荐）

1. 右键点击桌面，选择"新建" > "到位置的链接"
2. 在"位置"中输入：`/mnt/win_c`（C盘）或 `/mnt/win_d`（D盘）
3. 输入名称，如"Windows C盘"
4. 点击"确定"创建快捷方式

### 方法二：使用命令行

```bash
# 创建 C 盘快捷方式
cat > ~/桌面/win_c.desktop << 'EOL'
[Desktop Entry]
Version=1.0
Type=Application
Name=Windows C 盘
Comment=访问 Windows C 盘数据
Exec=xdg-open /mnt/win_c
Icon=folder
Terminal=false
StartupNotify=true
EOL

# 创建 D 盘快捷方式
cat > ~/桌面/win_d.desktop << 'EOL'
[Desktop Entry]
Version=1.0
Type=Application
Name=Windows D 盘
Comment=访问 Windows D 盘数据
Exec=xdg-open /mnt/win_d
Icon=folder
Terminal=false
StartupNotify=true
EOL

# 设置执行权限
chmod +x ~/桌面/win_*.desktop

# 标记为可信
gio set ~/桌面/win_c.desktop "metadata::trusted" true
gio set ~/桌面/win_d.desktop "metadata::trusted" true

# 刷新桌面（如果快捷方式未立即显示）
dbus-send --type=method_call --dest=org.gnome.Shell /org/gnome/Shell org.gnome.Shell.Eval string:'global.reexec_self()'
```

## 2. 验证快捷方式

1. 双击桌面上的"Windows C 盘"或"Windows D 盘"图标
2. 应该会打开文件管理器并显示对应分区的内容

## 3. 故障排除

### 如果提示"未信任的启动器"
```bash
# 确保设置了可执行权限
chmod +x ~/桌面/win_*.desktop

# 确保标记为可信
gio set ~/桌面/win_c.desktop "metadata::trusted" true
gio set ~/桌面/win_d.desktop "metadata::trusted" true
```

### 如果快捷方式无法打开
1. 右键点击快捷方式，选择"属性"
2. 在"权限"标签页中，勾选"允许作为程序执行文件"
3. 点击"关闭"后重试

## 4. 自定义图标（可选）

要更改图标，可以：
1. 右键点击快捷方式，选择"属性"
2. 点击左上角的图标
3. 从系统图标中选择，或指定自定义图标路径

## 5. 删除快捷方式

要删除快捷方式，只需将其拖到回收站，或右键点击选择"移动到回收站"。

## 注意事项

1. 确保 NTFS 分区已正确挂载到 `/mnt/win_c` 和 `/mnt/win_d`
2. 如果更改了挂载点，需要相应更新快捷方式中的路径
3. 这些快捷方式会随着系统重启而保持有效
4. 如果遇到权限问题，可以尝试使用 `sudo` 运行命令

## 相关链接

- [NTFS 挂载指南](./ubuntu_mount_ntfs_guide.md)
- [SMB 共享挂载指南](./mount_smb_share_guide.md)
