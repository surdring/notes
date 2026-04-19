## 国内环境 Docker 安装指南

### 1. 使用阿里云镜像安装（推荐）

```bash
# 下载阿里云 Docker 安装脚本
curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun

# 或执行
curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/static/stable/$(uname -m)/docker-24.0.7.tgz
```

### 2. 使用 DaoCloud 安装脚本

```bash
curl -sSL https://get.daocloud.io/docker | sh
```

### 3. Ubuntu/Debian 系统（换国内源）

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

### 5. 配置国内镜像加速（必需）

```bash
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com"
  ]
}
EOF

sudo systemctl daemon-reload
sudo systemctl restart docker
```

### 验证安装

```bash
sudo docker --version
sudo docker run hello-world
```

---

**建议**：执行完安装后，务必配置镜像加速，否则拉取镜像会非常慢或失败。
是 **4 个不同方案**，不是顺序执行：

- **方案 1、2**：一键安装脚本（二选一，适合快速安装）
- **方案 3、4**：手动添加国内源（根据系统选 Ubuntu 或 CentOS）
- **步骤 5**：镜像加速配置（**所有方案都必须执行**，否则拉取镜像很慢）

**推荐路径**：
- Ubuntu/Debian → 用 **方案 3** + 步骤 5
- CentOS/RHEL → 用 **方案 4** + 步骤 5
- 想最快安装 → 用 **方案 1**（阿里云脚本）+ 步骤 5

镜像源连接失败，中科大镜像可能不稳定。换一个可用的：

```bash
# 更换为 DaoCloud 镜像（通常可用）
sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com"
  ]
}
EOF

sudo systemctl daemon-reload
sudo systemctl restart docker

# 测试
sudo docker pull hello-world
```

如果还不行，尝试**腾讯云镜像**：
```json
{
  "registry-mirrors": [
    "https://ccr.ccs.tencentyun.com"
  ]
}
```

或者**阿里云个人加速器**（需登录 https://cr.console.aliyun.com 获取专属地址）。
个人：https://53rt81ff.mirror.aliyuncs.com
