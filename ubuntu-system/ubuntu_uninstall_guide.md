# Ubuntu 程序卸载指南

## 概述

本文档提供了在 Ubuntu 系统中卸载程序的完整指南，涵盖不同安装方式的卸载方法。

## 获取 package_name 的方法

在卸载程序之前，需要先确定准确的包名。以下是几种常用的查找方法：

### 1. 通过已安装包列表查找

```bash
# 查看所有已安装的包（过滤关键词）
dpkg -l | grep -i 关键词

# 使用 apt 查看已安装包
apt list --installed | grep -i 关键词

# 示例：查找包含 "sunlogin" 的包
dpkg -l | grep -i sunlogin
apt list --installed | grep -i sunlogin
```

### 2. 通过程序名称查找

```bash
# 查找可执行文件对应的包
dpkg -S $(which 程序名)

# 示例：查找 firefox 对应的包
dpkg -S $(which firefox)

# 如果程序不在 PATH 中，直接搜索
dpkg -S 程序名
```

### 3. 通过描述信息查找

```bash
# 在包描述中搜索关键词
apt search 关键词

# 示例：搜索媒体播放器
apt search media player
```

### 4. 查看特定包的详细信息

```bash
# 显示包的详细信息
apt show package_name

# 显示包包含的文件列表
dpkg -L package_name
```

### 5. 不同包管理器的查找命令

```bash
# APT 包
dpkg -l | grep package_name
apt list --installed | grep package_name

# Snap 包
snap list | grep package_name

# Flatpak 包
flatpak list | grep package_name
```

## 卸载方法

### 1. APT 包管理器卸载

适用于通过 `apt` 或 `apt-get` 从官方仓库安装的程序。

```bash
# 基本卸载（保留配置文件）
sudo apt remove package_name

# 完全卸载（删除配置文件）
sudo apt remove --purge package_name

# 清理不需要的依赖
sudo apt autoremove

# 清理下载的包缓存
sudo apt autoclean
```

**示例：**
```bash
sudo apt remove --purge vlc
sudo apt autoremove
```

### 2. DPKG 底层包管理器卸载

适用于通过 `.deb` 文件手动安装的程序。

```bash
# 卸载程序包（保留配置文件）
sudo dpkg -r package_name

# 完全卸载（删除配置文件）
sudo dpkg -P package_name
```

**示例：**
```bash
sudo dpkg -r sunloginclient
sudo dpkg -P sunloginclient
```

### 3. SNAP 包卸载

适用于通过 Snap 安装的程序。

```bash
# 查看已安装的 snap 包
snap list

# 卸载 snap 包
sudo snap remove package_name

# 查看已断开连接的 snap
sudo snap list --all

# 清理旧版本
sudo snap refresh --list
sudo snap remove package_name --revision=版本号
```

**示例：**
```bash
sudo snap remove spotify
```

### 4. Flatpak 应用卸载

适用于通过 Flatpak 安装的应用。

```bash
# 查看已安装的应用
flatpak list

# 卸载应用
flatpak uninstall package_name

# 清理不需要的运行时
flatpak uninstall --unused
```

**示例：**
```bash
flatpak uninstall org.mozilla.firefox
```

### 5. 源码编译程序卸载

适用于通过源码编译安装的程序。

```bash
# 进入源码目录
cd /path/to/source

# 查看是否有 Makefile
ls -la

# 如果有 Makefile，尝试卸载
sudo make uninstall

# 如果没有 uninstall 目标，手动删除
sudo make prefix=/usr/local uninstall
```

**手动删除方法：**
```bash
# 查找安装的文件
sudo find /usr/local -name "program_name*" 2>/dev/null

# 手动删除文件和目录
sudo rm -rf /usr/local/bin/program_name
sudo rm -rf /usr/local/lib/program_name
```

### 6. AppImage 程序卸载

适用于 AppImage 格式的便携程序。

```bash
# 删除 AppImage 文件
rm /path/to/program.AppImage

# 删除桌面快捷方式
rm ~/.local/share/applications/program.desktop
```

## 检查程序安装状态

### 查看已安装的包

```bash
# APT 包
dpkg -l | grep package_name
apt list --installed | grep package_name

# Snap 包
snap list | grep package_name

# Flatpak 包
flatpak list | grep package_name
```

### 查找程序文件

```bash
# 查找可执行文件
which program_name
whereis program_name

# 查找所有相关文件
sudo find / -name "*program_name*" 2>/dev/null
```

## 清理残留文件

### 用户配置文件

```bash
# 删除用户配置目录
rm -rf ~/.config/program_name
rm -rf ~/.local/share/program_name
rm -rf ~/.cache/program_name

# 删除配置文件
rm ~/.program_name
```

### 系统配置文件

```bash
# 删除系统配置
sudo rm -rf /etc/program_name
sudo rm /etc/program_name.conf
```

### 服务文件

```bash
# 停止并删除服务
sudo systemctl stop program_name.service
sudo systemctl disable program_name.service
sudo rm /etc/systemd/system/program_name.service
sudo systemctl daemon-reload
```

## 常见问题解决

### 1. 包依赖问题

```bash
# 强制卸载（谨慎使用）
sudo dpkg --remove --force-depends package_name

# 修复依赖关系
sudo apt install -f
```

### 2. 权限问题

```bash
# 更改文件所有权
sudo chown -R $USER:$USER ~/.config/program_name

# 然后删除
rm -rf ~/.config/program_name
```

### 3. 进程占用

```bash
# 查找占用进程
ps aux | grep program_name

# 终止进程
sudo pkill program_name
sudo killall program_name
```

## 最佳实践

1. **优先使用包管理器**：总是优先使用安装时使用的包管理器进行卸载
2. **备份重要配置**：卸载前备份可能需要的重要配置文件
3. **检查依赖关系**：卸载后检查是否有其他程序依赖已删除的包
4. **清理残留文件**：彻底清理配置文件和缓存
5. **验证卸载**：确认程序已完全移除

## 卸载验证

```bash
# 检查程序是否还存在
which program_name

# 检查包是否已卸载
dpkg -l | grep package_name

# 检查服务是否已停止
systemctl status program_name.service
```

## 总结

选择正确的卸载方法取决于程序的安装方式：

- **APT 安装** → `apt remove --purge`
- **DPKG 安装** → `dpkg -r` + `dpkg -P`
- **Snap 安装** → `snap remove`
- **Flatpak 安装** → `flatpak uninstall`
- **源码编译** → `make uninstall` 或手动删除
- **AppImage** → 直接删除文件

始终使用与安装方法对应的卸载方式，确保完全清理程序及其配置文件。
