# ToDesk 安装与问题处理指南

## 目录
- [安装](#安装)
- [服务管理](#服务管理)
- [启动图形界面](#启动图形界面)
- [常见问题](#常见问题)
- [参考链接](#参考链接)

---

## 安装

### 下载安装包

从 ToDesk 官网下载对应系统的 `.deb` 包：

```bash
wget https://dl.todesk.com/linux/todesk-v4.8.6.2-amd64.deb
```

### 安装

```bash
sudo apt install ./todesk-v4.8.6.2-amd64.deb
```

若报依赖错误，执行修复：

```bash
sudo apt --fix-broken install -y
```

---

## 服务管理

### 启动服务

```bash
sudo systemctl start todeskd
```

### 设置开机自启

```bash
sudo systemctl enable todeskd
```

### 查看服务状态

```bash
sudo systemctl status todeskd
```

### 重启服务

```bash
sudo systemctl restart todeskd
```

---

## 启动图形界面

```bash
env LIBVA_DRIVER_NAME=iHD LIBVA_DRIVERS_PATH=/opt/todesk/bin GDK_BACKEND=x11 /opt/todesk/bin/ToDesk
```

也可直接双击桌面图标或从应用菜单启动。

---

## 常见问题

### 问题 1：安装后点击图标无反应

**现象**：安装成功，但双击图标或从菜单启动无任何反应。

**排查步骤**：

1. **检查服务状态**

   ```bash
   sudo systemctl status todeskd
   ```

   关注输出中的 `Main PID` 行，查看 `code=` 状态。

2. **检查缺失的依赖库**

   ```bash
   ldd /opt/todesk/bin/ToDesk_Service 2>/dev/null | grep "not found"
   ldd /opt/todesk/bin/ToDesk 2>/dev/null | grep "not found"
   ```

3. **安装缺失的依赖库**

   常见缺失的 X11 相关库：

   ```bash
   sudo apt install -y libxcb-icccm4 libxcb-keysyms1 libxcb-xkb1
   ```

   也可一次性安装 ToDesk 常用依赖：

   ```bash
   sudo apt install -y libgtk-3-0 libnotify4 libnss3 libxss1 libxtst6 \
                       xdg-utils libatspi2.0-0 libuuid1 libappindicator3-1 \
                       libsecret-1-0 libxcb-icccm4 libxcb-keysyms1 libxcb-xkb1
   ```

4. **重启服务后重试**

   ```bash
   sudo systemctl restart todeskd
   ```

### 问题 2：服务启动报错 `status=127`

**现象**：

```
Process: 245043 ExecStart=/opt/todesk/bin/ToDesk_Service (code=exited, status=127)
```

**原因**：缺少共享库依赖。

**解决**：使用 `ldd` 查找缺失的 `.so` 文件，然后通过 `apt install` 安装对应的软件包。

### 问题 3：服务启动报错 `signal=ILL`（非法指令）

**现象**：

```
Process: 4734 ExecStart=/opt/todesk/bin/ToDesk_Service (code=dumped, signal=ILL)
```

**原因**：ToDesk 4.8+ 版本要求 CPU 支持 AVX/AVX2 指令集，老 CPU 不支持。

**检查 CPU 是否支持 AVX**：

```bash
grep -E 'avx|avx2' /proc/cpuinfo
```

- 有输出 → 支持，可安装新版
- 无输出 → 不支持，需安装旧版

**解决**：卸载当前版本，安装 ToDesk 4.7.2 旧版：

```bash
sudo apt remove todesk
wget https://dl.todesk.com/linux/todesk-v4.7.2.0-amd64.deb
sudo apt install ./todesk-v4.7.2.0-amd64.deb
```

### 问题 4：Wayland 下无法运行（被控端黑屏/无法显示界面）

**现象**：
- 在 Ubuntu 22.04+（包括 Ubuntu 26.04）默认 Wayland 会话下，ToDesk 黑屏或无法正常显示
- **控制端**（Ubuntu 26.04）查看 **被控端**（Ubuntu 26.04）时无法显示界面
- 但控制 **Windows 被控端** 时一切正常

**原因**：

Ubuntu 26.04 默认使用 **Wayland** 显示服务器，而 ToDesk 依赖 X11 协议来捕获屏幕内容。Wayland 出于安全考虑，限制了跨进程的屏幕捕获，导致 ToDesk 无法获取被控端的画面。而 Windows 使用自己的桌面会话协议，不受此限制。

**检查当前会话类型**：

```bash
echo $XDG_SESSION_TYPE
```

输出 `wayland` 即表示当前处于 Wayland 会话。

---

**解决方案一（推荐）：切换到 Xorg 会话**

**临时切换**（一次有效）：
1. 注销当前用户
2. 在登录界面点击密码框旁边的齿轮图标
3. 选择 **"Ubuntu on Xorg"**
4. 重新登录

**永久切换**（禁用 Wayland）：

```bash
sudo sed -i 's/#WaylandEnable=false/WaylandEnable=false/' /etc/gdm3/custom.conf
```

然后重启系统：

```bash
sudo reboot
```

切换回 Xorg 后，ToDesk 即可正常工作。

---

**解决方案二：安装 Wayland 屏幕捕获依赖（实验性）**

如果不方便切换到 Xorg，可尝试安装 Wayland 屏幕共享所需的基础组件：

```bash
sudo apt install -y pipewire pipewire-pulse wireplumber \
                    xdg-desktop-utils xdg-dbus-proxy
```

但请注意：ToDesk 对 Wayland 的原生支持有限，此方案**不一定能完全解决问题**，仍建议切换到 Xorg。

---

**解决方案三：使用支持 Wayland 的替代远程工具**

如果必须使用 Wayland，推荐以下对 Wayland 支持更好的远程桌面工具：

| 工具 | 安装命令 | Wayland 支持 |
|------|----------|-------------|
| **RustDesk** | `sudo apt install rustdesk` | 部分支持 |
| **GNOME Remote Desktop**（RDP） | 系统自带 | 原生支持 |
| **KRDC** | `sudo apt install krdc` | 支持 |

其中 **GNOME Remote Desktop**（设置 → 共享 → 远程桌面）对 Ubuntu 26.04 的 Wayland 支持最好，推荐使用。

### 问题 5：查看 ToDesk 日志

```bash
# 服务日志
journalctl --user -u todeskd.service -b --no-pager | tail -n 50

# 客户端日志
tail -f ~/.local/share/todesk/log/todesk.log

# 服务端日志
tail -f /var/log/todesk/todeskd.log
```

---

## 参考链接

- ToDesk 官网下载：[https://www.todesk.com/linux.html](https://www.todesk.com/linux.html)
- ToDesk 官方帮助中心：[https://todesk.com/helpcenter](https://todesk.com/helpcenter)