# Docker Ollama 完全卸载指南

> 目标：完全删除 Docker 中安装的 Ollama 服务及其拉取的所有模型文件，释放存储空间和系统资源。
>
> 适用系统：Ubuntu 24.04 + Docker

---

## 1. 卸载前检查

### 1.1 检查 Ollama 容器状态

```bash
# 查看所有 Ollama 相关容器
docker ps -a | grep ollama

# 查看 Ollama 镜像
docker images | grep ollama

# 查看 Docker 卷（包含模型数据）
docker volume ls | grep ollama
```

### 1.2 检查模型文件大小

```bash
# 查看 Ollama 数据卷占用空间
docker system df

# 查看具体卷的大小
sudo du -sh /var/lib/docker/volumes/*ollama*
```

---

## 2. 停止并删除 Ollama 容器

### 2.1 停止运行中的 Ollama 容器

```bash
# 停止所有 Ollama 容器
docker stop $(docker ps -q --filter "name=ollama")

# 或者指定容器名
docker stop ollama
```

### 2.2 删除 Ollama 容器

```bash
# 删除所有 Ollama 容器
docker rm $(docker ps -aq --filter "name=ollama")

# 或者指定容器名
docker rm ollama

# 强制删除（如果容器正在运行）
docker rm -f ollama
```

### 2.3 验证容器删除

```bash
# 确认没有 Ollama 容器
docker ps -a | grep ollama
```

---

## 3. 删除 Ollama 镜像

### 3.1 删除 Ollama 镜像

```bash
# 删除 Ollama 镜像
docker rmi ollama/ollama

# 删除所有 Ollama 相关镜像
docker rmi $(docker images -q "ollama/*")

# 强制删除（如果有依赖问题）
docker rmi -f ollama/ollama
```

### 3.2 清理悬空镜像

```bash
# 清理所有悬空镜像
docker image prune -f

# 清理所有未使用的镜像
docker image prune -a -f
```

### 3.3 验证镜像删除

```bash
# 确认没有 Ollama 镜像
docker images | grep ollama
```

---

## 4. 删除 Ollama 数据卷（重要！）

### 4.1 查看所有 Ollama 相关卷

```bash
# 查看 Ollama 数据卷
docker volume ls | grep ollama

# 查看卷详细信息
docker volume inspect ollama
```

### 4.2 删除 Ollama 数据卷

```bash
# 删除 Ollama 数据卷（这会删除所有模型文件！）
docker volume rm ollama

# 删除所有 Ollama 相关卷
docker volume rm $(docker volume ls -q | grep ollama)
```

### 4.3 手动删除残留数据

```bash
# 检查并手动删除残留的 Ollama 数据
sudo rm -rf /var/lib/docker/volumes/ollama*
sudo rm -rf /var/lib/docker/volumes/*ollama*

# 删除 Ollama 配置目录
sudo rm -rf ~/.ollama
sudo rm -rf /root/.ollama
```

---

## 5. 清理 Docker 系统

### 5.1 全面清理 Docker

```bash
# 清理所有未使用的容器、网络、镜像、卷
docker system prune -a --volumes -f

# 清理构建缓存
docker builder prune -a -f
```

### 5.2 检查清理效果

```bash
# 查看 Docker 系统使用情况
docker system df

# 查看磁盘空间释放情况
df -h
```

---

## 6. 完全卸载脚本（一键执行）

### 6.1 自动卸载脚本

```bash
#!/bin/bash
# Docker Ollama 完全卸载脚本 - 修复版本
# 解决权限问题和顽固容器问题

echo "=========================================="
echo "    Docker Ollama 完全卸载脚本 (修复版)"
echo "=========================================="
echo "⚠️  警告：此操作将删除所有 Ollama 容器、镜像和模型文件！"
read -p "确认继续？(y/N): " confirm

if [[ $confirm != "y" && $confirm != "Y" ]]; then
    echo "操作已取消"
    exit 0
fi

# 检查 Docker 是否运行
if ! sudo docker info >/dev/null 2>&1; then
    echo "Docker 未运行，正在启动..."
    sudo systemctl start docker
    sleep 3
fi

# 函数：检查命令执行结果
check_result() {
    if [ $? -eq 0 ]; then
        echo "✓ $1 成功"
    else
        echo "⚠️  $1 部分成功或跳过"
    fi
}

echo -e "\n[1/8] 停止 Ollama 容器..."
# 尝试优雅停止
sudo docker stop $(sudo docker ps -q --filter "name=ollama" 2>/dev/null) 2>/dev/null
sleep 2

# 强制停止顽固容器
echo "强制停止顽固容器..."
for container in $(sudo docker ps -aq --filter "name=ollama" 2>/dev/null); do
    # 获取容器进程ID
    pid=$(sudo docker inspect $container 2>/dev/null | grep '"Pid"' | head -1 | grep -o '[0-9]\+')
    if [ ! -z "$pid" ] && [ "$pid" != "0" ]; then
        echo "终止容器进程 PID: $pid"
        sudo kill -9 $pid 2>/dev/null
    fi
done
check_result "容器停止"

echo -e "\n[2/8] 删除 Ollama 容器..."
# 常规删除
sudo docker rm $(sudo docker ps -aq --filter "name=ollama" 2>/dev/null) 2>/dev/null
sleep 2

# 如果仍有容器，强制删除
remaining_containers=$(sudo docker ps -aq --filter "name=ollama" 2>/dev/null)
if [ ! -z "$remaining_containers" ]; then
    echo "发现顽固容器，使用强制删除..."
    for container in $remaining_containers; do
        sudo docker rm -f $container 2>/dev/null
    done
fi
check_result "容器删除"

echo -e "\n[3/8] 删除 Ollama 镜像..."
sudo docker rmi $(sudo docker images -q "ollama/*" 2>/dev/null) 2>/dev/null
# 强制删除镜像
sudo docker rmi -f $(sudo docker images -q "ollama/*" 2>/dev/null) 2>/dev/null
check_result "镜像删除"

echo -e "\n[4/8] 删除 Ollama 数据卷..."
sudo docker volume rm $(sudo docker volume ls -q | grep ollama 2>/dev/null) 2>/dev/null
# 强制删除数据卷
sudo docker volume rm -f $(sudo docker volume ls -q | grep ollama 2>/dev/null) 2>/dev/null
check_result "数据卷删除"

echo -e "\n[5/8] 重启 Docker 服务清理状态..."
echo "停止 Docker 服务..."
sudo systemctl stop docker.socket 2>/dev/null
sudo systemctl stop docker 2>/dev/null
sleep 3

echo "清理 Docker 容器配置文件..."
# 清理可能的残留容器配置
sudo find /var/lib/docker/containers -name "*$(sudo docker ps -aq --filter "name=ollama" 2>/dev/null | head -c 12)*" -type d -exec rm -rf {} + 2>/dev/null

echo "启动 Docker 服务..."
sudo systemctl start docker
sleep 5
check_result "Docker 服务重启"

echo -e "\n[6/8] 手动清理残留文件..."
# 清理 Docker 卷目录
sudo rm -rf /var/lib/docker/volumes/ollama* 2>/dev/null
sudo rm -rf /var/lib/docker/volumes/*ollama* 2>/dev/null

# 清理用户配置
sudo rm -rf ~/.ollama 2>/dev/null
sudo rm -rf /root/.ollama 2>/dev/null
sudo rm -rf /home/*/.ollama 2>/dev/null

# 清理临时文件
sudo rm -rf /tmp/ollama* 2>/dev/null
sudo rm -rf /tmp/rocm* 2>/dev/null
check_result "残留文件清理"

echo -e "\n[7/8] 清理 Docker 系统..."
sudo docker system prune -a --volumes -f > /dev/null 2>&1
check_result "Docker 系统清理"

echo -e "\n[8/8] 验证卸载结果..."
echo "检查容器..."
if sudo docker ps -a | grep -q ollama; then
    echo "⚠️  仍有 Ollama 容器残留"
else
    echo "✓ 无 Ollama 容器"
fi

echo "检查镜像..."
if sudo docker images | grep -q ollama; then
    echo "⚠️  仍有 Ollama 镜像残留"
else
    echo "✓ 无 Ollama 镜像"
fi

echo "检查数据卷..."
if sudo docker volume ls | grep -q ollama; then
    echo "⚠️  仍有 Ollama 数据卷残留"
else
    echo "✓ 无 Ollama 数据卷"
fi

echo -e "\n=========================================="
echo "         Ollama 卸载完成！"
echo "=========================================="

# 显示释放的空间
echo -e "\n磁盘空间使用情况："
df -h | grep -E "(Filesystem|/dev/)" | head -5

echo -e "\nDocker 系统使用情况："
sudo docker system df 2>/dev/null || echo "Docker 系统信息获取失败"

echo -e "\n=========================================="
echo "如仍有残留，请重启系统后再次运行此脚本"
echo "=========================================="

```

### 6.2 使用脚本

```bash
# 创建脚本文件
cat > uninstall_ollama_docker.sh << 'EOF'
#!/bin/bash
# [上面的脚本内容]
EOF

# 设置执行权限
chmod +x uninstall_ollama_docker.sh

# 执行卸载
./uninstall_ollama_docker.sh
```

---

## 7. 验证卸载结果

### 7.1 检查 Docker 环境

```bash
# 确认没有 Ollama 容器
docker ps -a | grep ollama || echo "✓ 无 Ollama 容器"

# 确认没有 Ollama 镜像
docker images | grep ollama || echo "✓ 无 Ollama 镜像"

# 确认没有 Ollama 数据卷
docker volume ls | grep ollama || echo "✓ 无 Ollama 数据卷"
```

### 7.2 检查系统文件

```bash
# 检查用户目录
ls -la ~/.ollama 2>/dev/null || echo "✓ 用户 Ollama 目录已删除"

# 检查系统目录
sudo ls -la /root/.ollama 2>/dev/null || echo "✓ 系统 Ollama 目录已删除"

# 检查 Docker 卷目录
sudo ls -la /var/lib/docker/volumes/ | grep ollama || echo "✓ Docker 卷已清理"
```

---

## 8. 故障排除

### 8.1 常见问题

**问题1：容器无法删除**
```bash
# 强制删除容器
docker rm -f $(docker ps -aq --filter "name=ollama")

# 如果仍有问题，重启 Docker 服务
sudo systemctl restart docker
```

**问题2：数据卷无法删除**
```bash
# 检查卷是否被使用
docker volume inspect ollama

# 强制删除卷
docker volume rm -f ollama

# 手动删除卷目录
sudo rm -rf /var/lib/docker/volumes/ollama
```

**问题3：权限问题**
```bash
# 使用 sudo 执行删除操作
sudo docker volume rm ollama
sudo rm -rf /var/lib/docker/volumes/ollama
```

### 8.2 残留进程检查

```bash
# 检查是否有 Ollama 进程
ps aux | grep ollama | grep -v grep

# 如果有，手动终止
sudo pkill -f ollama
```

---

## 9. 预防措施

### 9.1 未来安装建议

```bash
# 使用数据卷管理模型（便于备份和迁移）
docker run -d \
  -v ollama:/root/.ollama \
  -p 11434:11434 \
  --name ollama \
  ollama/ollama

# 定期清理不用的模型
docker exec ollama ollama rm <model-name>

# 监控磁盘使用
docker system df
```

### 9.2 备份重要模型

```bash
# 在卸载前备份重要模型
docker run --rm -v ollama:/data -v $(pwd):/backup alpine tar czf /backup/ollama-backup.tar.gz -C /data .

# 恢复时重新导入
docker run --rm -v ollama:/data -v $(pwd):/backup alpine tar xzf /backup/ollama-backup.tar.gz -C /data
```

---

## 10. 快速参考

### 10.1 一行命令卸载

```bash
# 完全卸载 Ollama（一行命令）
docker stop $(docker ps -q --filter "name=ollama" 2>/dev/null) && docker rm $(docker ps -aq --filter "name=ollama" 2>/dev/null) && docker rmi $(docker images -q "ollama/*" 2>/dev/null) && docker volume rm $(docker volume ls -q | grep ollama 2>/dev/null) && docker system prune -a --volumes -f
```

### 10.2 检查命令

```bash
# 检查 Ollama 是否完全删除
docker ps -a | grep ollama && docker images | grep ollama && docker volume ls | grep ollama
```

---

> 本指南提供了完整的 Docker Ollama 卸载流程，包括容器、镜像、数据卷和系统文件的清理。执行前请确保已备份重要数据。卸载后可释放数GB到数十GB的磁盘空间，具体取决于下载的模型大小。
