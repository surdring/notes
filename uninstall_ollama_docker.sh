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
