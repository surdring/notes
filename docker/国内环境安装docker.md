## 国内环境 Docker 安装指南

### 前置问题处理

如果 `apt-get update` 报错 `NO_PUBKEY` 或签名校验失败（如 GitHub CLI 仓库），需要先处理：

```bash
# 查看有问题的仓库文件
ls /etc/apt/sources.list.d/

# 临时移除有问题的仓库（以 github-cli 为例）
sudo mv /etc/apt/sources.list.d/github-cli.list /etc/apt/sources.list.d/github-cli.list.bak
```

安装完成后再恢复：
```bash
sudo mv /etc/apt/sources.list.d/github-cli.list.bak /etc/apt/sources.list.d/github-cli.list
```

---

### 1. 使用阿里云镜像安装（推荐，已验证可用）

```bash
# 下载阿里云 Docker 安装脚本
curl -fsSL https://get.docker.com -o get-docker.sh

# 执行安装（使用阿里云镜像）
sudo sh get-docker.sh --mirror Aliyun
```

> 如果 `curl` 报 TLS 连接错误，尝试加 `-k` 参数或用 `wget`：
> ```bash
> curl -fsSLk https://get.docker.com -o get-docker.sh
> # 或
> wget --no-check-certificate https://get.docker.com -O get-docker.sh
> ```

### 2. 使用 DaoCloud 安装脚本（备选）

```bash
curl -sSL https://get.daocloud.io/docker | sh
```

### 3. Ubuntu/Debian 系统（手动添加国内源）

```bash
# 1. 卸载旧版本
sudo apt-get remove docker docker-engine docker.io containerd runc

# 2. 安装依赖
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg

# 3. 添加阿里云 GPG 密钥
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# 4. 添加阿里云仓库
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.aliyun.com/docker-ce/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 5. 安装 Docker
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### 4. CentOS/RHEL 系统

```bash
# 添加阿里云源
sudo yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

# 安装
sudo yum install docker-ce docker-ce-cli containerd.io
```

---

### 5. 配置 Docker 数据目录（可选，推荐）

将 Docker 的数据、镜像、容器、缓存全部放在指定目录（如 `/home/docker`）：

```bash
# 创建 Docker 数据目录
sudo mkdir -p /home/docker

# 停止 Docker 服务
sudo systemctl stop docker
sudo systemctl stop docker.socket

# 配置 daemon.json（数据目录 + 镜像加速）
sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "data-root": "/home/docker",
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com"
  ]
}
EOF

# 重载配置并启动 Docker
sudo systemctl daemon-reload
sudo systemctl start docker
sudo systemctl enable docker
```

### 6. 验证安装

```bash
# 检查 Docker 版本
sudo docker --version

# 确认数据目录
sudo docker info | grep "Docker Root Dir"

# 运行测试容器
sudo docker run hello-world
```

### 7. 将当前用户加入 docker 组（可选）

```bash
sudo usermod -aG docker $USER
```
执行完需要**注销重新登录**或重启后生效。

---

### 镜像加速源参考

| 镜像源 | 地址 |
|--------|------|
| DaoCloud | `https://docker.m.daocloud.io` |
| 网易 | `https://hub-mirror.c.163.com` |
| 百度 | `https://mirror.baidubce.com` |
| 中科大 | `https://docker.mirrors.ustc.edu.cn` |
| 腾讯云 | `https://ccr.ccs.tencentyun.com` |
| 阿里云（个人） | `https://<你的ID>.mirror.aliyuncs.com`（需登录 https://cr.console.aliyun.com 获取） |

---

### 常见问题

**Q: `apt-get update` 报 `NO_PUBKEY` 错误？**
A: 某个第三方仓库缺少 GPG 公钥，先临时移除该仓库文件（见顶部"前置问题处理"）。

**Q: `curl` 报 `TLS connect error` / `SSL routines::unexpected eof`？**
A: 网络环境对 HTTPS 有限制，尝试加 `-k` 参数、用 `wget --no-check-certificate`，或切换镜像源。

**Q: 如何恢复 GitHub CLI 仓库？**
A: 安装完成后执行 `sudo mv /etc/apt/sources.list.d/github-cli.list.bak /etc/apt/sources.list.d/github-cli.list`。