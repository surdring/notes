# Tox (qTox) 安装与使用指南

## 概述

Tox 是一个免费、开源、去中心化的即时通讯应用，支持端到端加密。它无需服务器，通过 P2P 网络进行通信，非常适合局域网内的安全通讯。

## 系统要求

- **操作系统**: Linux、Windows、macOS、Android
- **网络**: 支持局域网和互联网通信
- **依赖**: OpenSSL、Qt5、libtoxcore

## 安装方法

### 1. Ubuntu/Debian 系统安装

#### 使用 APT 包管理器（推荐）

```bash
# 更新软件包列表
sudo apt update

# 安装 qTox 客户端
sudo apt install qtox

# 或者安装其他 Tox 客户端
sudo apt install toxic      # 终端版客户端
sudo apt install uTox      # 轻量级客户端
```

#### 从源码编译

```bash
# 安装编译依赖
sudo apt install build-essential cmake git libffmpeg-dev \
    libopenal-dev libqrencode-dev libsqlcipher-dev \
    libtoxcore-dev qt5-default qttools5-dev-tools

# 克隆源码
git clone https://github.com/qTox/qTox.git
cd qTox

# 编译安装
mkdir build && cd build
cmake ..
make -j$(nproc)
sudo make install
```

### 2. 其他 Linux 发行版

#### Arch Linux
```bash
sudo pacman -S qtox
```

#### Fedora
```bash
sudo dnf install qtox
```

#### openSUSE
```bash
sudo zypper install qtox
```

### 3. Windows 和 macOS

- **Windows**: 从官网下载安装包 https://qtox.github.io/
- **macOS**: 使用 Homebrew `brew install --cask qtox`

## 防火墙配置

### Ubuntu UFW 防火墙设置

```bash
# 开放 Tox 所需的 UDP 端口
sudo ufw allow 33445:33450/udp
sudo ufw allow 33445:33450/tcp

# 检查防火墙状态
sudo ufw status

# 重新加载防火墙规则
sudo ufw reload
```

### 其他防火墙配置

#### iptables
```bash
# 允许 Tox 端口
sudo iptables -A INPUT -p udp --dport 33445:33450 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 33445:33450 -j ACCEPT

# 保存规则
sudo iptables-save > /etc/iptables/rules.v4
```

#### firewalld (CentOS/RHEL)
```bash
# 开放端口
sudo firewall-cmd --permanent --add-port=33445-33450/udp
sudo firewall-cmd --permanent --add-port=33445-33450/tcp

# 重新加载
sudo firewall-cmd --reload
```

## 首次配置

### 1. 启动 qTox

```bash
# 从命令行启动
qtox &

# 或从应用菜单启动
# 应用程序 → 互联网 → qTox
```

### 2. 创建个人资料

1. **用户名**: 设置你的显示名称
2. **状态消息**: 设置个人状态
3. **头像**: 上传个人头像（可选）

### 3. 获取 Tox ID

- qTox 会自动生成唯一的 Tox ID
- ID 格式：`A1B2C3D4...` (76位十六进制字符)
- 这个 ID 就是你的"电话号码"，用于添加好友

## 添加好友

### 1. 通过 Tox ID 添加

1. 点击 qTox 界面的 "+" 按钮
2. 输入好友的 Tox ID
3. 添加好友消息（可选）
4. 点击 "发送请求"

### 2. 接受好友请求

1. 收到好友请求时会弹出通知
2. 在好友列表中查看待处理请求
3. 点击 "接受" 或 "拒绝"

## 基本使用

### 1. 文字聊天

- 双击好友名称开始聊天
- 支持表情符号和格式化文本
- 按 Enter 发送消息，Shift+Enter 换行

### 2. 文件传输

- 点击聊天窗口的 📎 图标
- 选择要发送的文件
- 等待对方接受传输

### 3. 语音通话

- 确保麦克风已连接
- 点击聊天窗口的 🎤 图标发起语音通话
- 对方接受后开始通话

### 4. 视频通话

- 确保摄像头已连接
- 点击聊天窗口的 📹 图标发起视频通话
- 支持语音+视频同时通话

### 5. 群聊

- 点击界面右上角的 "创建群组"
- 设置群组名称和描述
- 邀请好友加入群组

## 网络设置

### 1. 基本网络配置

打开 qTox → 设置 → 网络：

- **启用 UDP**: 勾选（推荐）
- **启用 IPv6**: 根据网络情况选择
- **代理设置**: 如需要可配置 HTTP/SOCKS 代理

### 2. 局域网优化

对于纯局域网使用：

```bash
# 确保局域网内设备可以互相发现
ping <好友IP地址>

# 检查网络连通性
nmap -p 33445-33450 <局域网IP段>
```

## 常见问题解决

### 1. 连接问题（消息转圈圈）

**症状**: 消息发送后一直转圈，无法送达

**解决方案**:
```bash
# 1. 检查防火墙设置
sudo ufw status verbose

# 2. 重启 qTox
pkill qtox
qtox &

# 3. 检查网络连接
ping 8.8.8.8

# 4. 等待 P2P 连接建立（通常需要1-3分钟）
```

### 2. 无法添加好友

**可能原因**:
- Tox ID 输入错误
- 网络连接问题
- 防火墙阻止

**解决方案**:
1. 仔细检查 Tox ID 是否正确
2. 确保双方网络连接正常
3. 检查防火墙端口开放情况

### 3. 语音/视频通话问题

**检查步骤**:
```bash
# 检查音频设备
pactl list sinks
pactl list sources

# 检查摄像头
ls /dev/video*
```

**qTox 内设置**:
- 设置 → 音频/视频
- 选择正确的输入/输出设备
- 测试音频和视频设备

### 4. 性能优化

```bash
# 降低 CPU 使用率
# qTox 设置 → 界面 → 降低动画效果

# 减少内存占用
# 定期清理聊天历史
# 设置 → 隐私 → 自动清理历史记录
```

## 高级配置

### 1. 配置文件位置

```bash
# qTox 配置目录
~/.config/qTox/

# Tox 配置文件
~/.config/tox/

# 日志文件
~/.local/share/qTox/qtox.log
```

### 2. 备份和恢复

```bash
# 备份 Tox 配置
cp -r ~/.config/tox ~/tox_backup/

# 恢复配置
cp -r ~/tox_backup/* ~/.config/tox/
```

### 3. 命令行参数

```bash
# 指定配置文件
qtox --profile <profile_name>

# 静默模式启动
qtox --background

# 显示帮助
qtox --help
```

## 安全注意事项

### 1. Tox ID 安全

- Tox ID 是你的唯一标识
- 只分享给可信的人
- 定期检查好友列表

### 2. 文件传输安全

- 只接受来自可信好友的文件
- 扫描接收的文件（病毒检查）
- 注意文件类型和大小

### 3. 网络安全

- Tox 使用端到端加密
- 通信内容无法被中间人窃听
- 但元数据（连接时间等）可能可见

## 替代客户端

### 1. 终端客户端

```bash
# Toxic - 终端版 Tox 客户端
sudo apt install toxic

# 使用方法
toxic
```

### 2. 轻量级客户端

```bash
# uTox - 最小化客户端
sudo apt install utox
```

### 3. 移动端

- **Android**: Antox、Toxy
- **iOS**: Antidote

## 卸载指南

### 1. 卸载 qTox

```bash
# Ubuntu/Debian
sudo apt remove --purge qtox
sudo apt autoremove

# 清理配置文件
rm -rf ~/.config/qTox
rm -rf ~/.local/share/qTox
```

### 2. 关闭防火墙端口

```bash
# 移除 Tox 端口规则
sudo ufw delete allow 33445:33450/udp
sudo ufw delete allow 33445:33450/tcp
```

## 总结

Tox 是一个优秀的去中心化通讯解决方案，特别适合：

- **局域网通讯**: 无需外部服务器
- **安全通讯**: 端到端加密
- **跨平台**: 支持所有主流操作系统
- **隐私保护**: 无需手机号或邮箱注册

通过正确配置防火墙和网络设置，Tox 可以在局域网内提供稳定、安全的即时通讯服务。

## 技术支持

- **官方网站**: https://tox.chat/
- **qTox GitHub**: https://github.com/qTox/qTox
- **社区论坛**: https://lists.tox.chat/
- **问题报告**: https://github.com/qTox/qTox/issues
