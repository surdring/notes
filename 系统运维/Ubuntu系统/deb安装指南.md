# DEB 包安装指南

## 方法一：使用 apt（推荐）

适用于 Ubuntu 18.04+ 及 Debian 系统，自动处理依赖关系。

```bash
sudo apt install ./google-chrome-stable_current_amd64.deb
```

**优点：**
- 自动处理依赖关系
- 安装过程更智能

**注意：**
- 如果 deb 包在用户目录（如 ~/下载/），可能会出现沙盒权限警告，不影响安装结果

---

## 方法二：使用 dpkg

传统方式，直接安装 deb 包。

```bash
sudo dpkg -i google-chrome-stable_current_amd64.deb
```

**如有依赖问题：**
```bash
sudo apt-get install -f
```

**优点：**
- 无沙盒机制，不会出现权限警告
- 更直接的安装方式

---

## 避免 apt 沙盒警告

将 deb 包复制到 `/tmp` 目录后再安装：

```bash
sudo cp /path/to/file.deb /tmp/
sudo apt install /tmp/file.deb
```

---

## 验证安装

```bash
google-chrome --version
```

或启动应用：
```bash
google-chrome
```
