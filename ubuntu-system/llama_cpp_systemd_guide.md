# Llama.cpp Systemd 服务持久化运行指南

## 概述

本指南详细介绍如何将 Llama.cpp 服务器配置为 systemd 服务，实现持久化运行、自动重启和系统启动时自动加载。

## 前置条件

### 系统要求
- **操作系统**: Linux (Ubuntu/Debian/CentOS 等)
- **systemd**: 现代 Linux 发行版默认支持
- **用户权限**: 普通用户权限（用户级服务）或 sudo 权限（系统级服务）

### Llama.cpp 环境
- Llama.cpp 已编译安装
- 模型文件已下载到指定位置
- GPU 驱动和 ROCm/HIP 环境已配置

## 服务类型选择

### 用户级服务 vs 系统级服务

| 特性 | 用户级服务 | 系统级服务 |
|------|------------|------------|
| 配置位置 | `~/.config/systemd/user/` | `/etc/systemd/system/` |
| 启动权限 | 普通用户 | 需要 sudo |
| 适用场景 | 个人开发、测试 | 生产环境、多用户 |
| 开机启动 | 用户登录后启动 | 系统启动时启动 |

**推荐**: 用户级服务（更安全、更简单）

## 单实例服务配置

### 1. 创建服务文件

```bash
# 创建用户级服务目录
mkdir -p ~/.config/systemd/user

# 创建服务文件
nano ~/.config/systemd/user/llama-server.service
```

### 2. 服务文件内容

```ini
[Unit]
Description=Llama.cpp Server
After=network.target

[Service]
Type=simple
WorkingDirectory=/home/zhengxueen/workspace/llama.cpp
Environment="HIP_VISIBLE_DEVICES=0"
ExecStart=/home/zhengxueen/workspace/llama.cpp/build-hip/bin/llama-server -m /mnt/ssd/models/gpt-oss-20b-mxfp4.gguf -c 0 --n-gpu-layers 9999 --jinja --host 0.0.0.0 --port 8080
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
```

### 3. 服务管理命令

```bash
# 重新加载 systemd 配置
systemctl --user daemon-reload

# 启用服务（开机自启）
systemctl --user enable llama-server.service

# 启动服务
systemctl --user start llama-server.service

# 查看服务状态
systemctl --user status llama-server.service

# 停止服务
systemctl --user stop llama-server.service

# 重启服务
systemctl --user restart llama-server.service

# 查看服务日志
journalctl --user -u llama-server.service -f
```

## 多实例服务配置

### 1. 创建多个服务文件

#### 服务1: GPT模型 (端口8080)

```ini
# nano ~/.config/systemd/user/llama-server-8080.service
[Unit]
Description=Llama.cpp Server on Port 8080
After=network.target

[Service]
Type=simple
WorkingDirectory=/home/zhengxueen/workspace/llama.cpp
Environment="HIP_VISIBLE_DEVICES=0"
Environment="GGML_LOG_LEVEL=debug"
ExecStart=/usr/bin/env -i HOME=%h USER=%u LOGNAME=%u PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HIP_VISIBLE_DEVICES=1 GGML_LOG_LEVEL=debug /home/zhengxueen/workspace/llama.cpp/build-hip/bin/llama-server -m /mnt/ssd/models/gpt-oss-safeguard-20b-Q4_K_M.gguf --ctx-size 65536 --n-gpu-layers 9999 --jinja --api-key sk-local-gpt20b --host 0.0.0.0 --port 8080  --alias gpt-oss-20b
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target


```

#### 服务2-1: OCR模型 (端口8082)
```ini
# nano ~/.config/systemd/user/llama-server-8081.service
[Unit]
Description=Llama.cpp Chandra-OCR Server on Port 8081
After=network.target

[Service]
Type=simple
WorkingDirectory=/home/zhengxueen/workspace/llama.cpp
Environment="HIP_VISIBLE_DEVICES=1"
Environment="GGML_LOG_LEVEL=debug"
ExecStart=/usr/bin/env -i HOME=%h USER=%u LOGNAME=%u PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HIP_VISIBLE_DEVICES=1 GGML_LOG_LEVEL=debug /home/zhengxueen/workspace/llama.cpp/build-hip/bin/llama-server --model /mnt/ssd/models/chandra-ocr/chandra-Q4_K_M.gguf --mmproj /mnt/ssd/models/chandra-ocr/chandra-mmproj-f16.gguf --ctx-size 32768 --n-gpu-layers 9999 --threads 4 --batch-size 512 --ubatch-size 128 --parallel 4 --jinja --api-key sk-local-ocr --flash-attn on --host 0.0.0.0 --port 8082 --alias chandra-ocr
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target




```
#### 服务2-2: OCR模型2 (端口8082)
```ini
# nano ~/.config/systemd/user/llama-server-8082.service
[Unit]
Description=Llama.cpp qwen3-vl Server on Port 8082
After=network.target

[Service]
Type=simple
WorkingDirectory=/home/zhengxueen/workspace/llama.cpp
Environment="HIP_VISIBLE_DEVICES=1"
Environment="GGML_LOG_LEVEL=debug"
ExecStart=/usr/bin/env -i HOME=%h USER=%u LOGNAME=%u PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HIP_VISIBLE_DEVICES=1 GGML_LOG_LEVEL=debug /home/zhengxueen/workspace/llama.cpp/build-hip/bin/llama-server --model /mnt/ssd/models/Qwen3-VL-32B-Instruct/Qwen3-VL-32B-Instruct-UD-Q4_K_XL.gguf --mmproj /mnt/ssd/models/Qwen3-VL-32B-Instruct/mmproj-F16.gguf --ctx-size 32768 --n-gpu-layers 9999 --threads 4 --jinja --api-key apikey --top-p 0.8 --top-k 20 --temp 0.7 --flash-attn on --host 0.0.0.0 --port 8082 --alias qwen3-vl
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
```

#### 服务3: Qwopus3.5-9B-v3模型 (端口8080)
```ini
[Unit]
Description=Llama.cpp Server on Port 8080
After=network.target

[Service]
Type=simple
WorkingDirectory=/home/zhengxueen/workspace/llama.cpp
Environment="HIP_VISIBLE_DEVICES=0"
Environment="GGML_LOG_LEVEL=debug"
ExecStart=/usr/bin/env -i HOME=%h USER=%u LOGNAME=%u PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HIP_VISIBLE_DEVICES=0 GGML_LOG_LEVEL=debug /home/zhengxueen/workspace/llama.cpp/build-hip/bin/llama-server -m /mnt/ssd/models/Qwopus3.5-9B-v3/Qwen3.5-9B.Q8_0.gguf --ctx-size 65536 --n-gpu-layers 9999 --flash-attn on --top-p 0.95 --top-k 20 --temp 1.0 --min-p 0.00 --jinja --host 0.0.0.0 --port 8080  --alias Qwen3.5-9B
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
```




#### 服务4: Qwen3-Reranker-4B模型 (端口8084)
```
[Unit]
Description=Llama.cpp Qwen3-Reranker-4B Server on Port 8084
After=network.target

[Service]
Type=simple
WorkingDirectory=/home/zhengxueen/workspace/llama.cpp
Environment="HIP_VISIBLE_DEVICES=1"
Environment="GGML_LOG_LEVEL=debug"
ExecStart=/usr/bin/env -i HOME=%h USER=%u LOGNAME=%u PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HIP_VISIBLE_DEVICES=1 GGML_LOG_LEVEL=debug /home/zhengxueen/workspace/llama.cpp/build-hip/bin/llama-server --model /mnt/ssd/models/Qwen3-Reranker-4B-q4_k_m.gguf --reasoning-format deepseek --ctx-size 32684 -n 32768 --n-gpu-layers 9999 --threads 8 --jinja --flash-attn auto -sm row --top-p 0.95 --temp 0.6 --top-k 20 --host 0.0.0.0 --no-context-shift --port 8084
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target

```


#### 服务5: Qwen3.5-35B-A3B-Claude-4.6-Opus模型 (端口8080)
```ini
[Unit]
Description=Llama.cpp Server on Port 8083
After=network.target

[Service]
Type=simple
WorkingDirectory=/home/zhengxueen/workspace/llama.cpp
Environment="HIP_VISIBLE_DEVICES=0"
Environment="GGML_LOG_LEVEL=debug"
ExecStart=/usr/bin/env -i HOME=%h USER=%u LOGNAME=%u PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HIP_VISIBLE_DEVICES=0 GGML_LOG_LEVEL=debug /home/zhengxueen/workspace/llama.cpp/build-hip/bin/llama-server -m /mnt/ssd/models/Qwen3.5-35B-A3B-Claude-4.6-Opus/Qwen3.5-35B-A3B-Claude-4.6-Opus-Reasoning-Distilled-MXFP4_MOE_BF16.gguf --mmproj /mnt/ssd/models/Qwen3.5-35B-A3B-Claude-4.6-Opus/mmproj-F32.gguf --ctx-size 32768 --n-gpu-layers 9999 --flash-attn on --top-p 0.95 --top-k 20 --temp 1.0 --min-p 0.00 --jinja --host 0.0.0.0 --port 8080 --chat-template-kwargs '{"enable_thinking":false}' --threads 8 --alias Qwen3.5
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
```

#### 服务6: TeichAI-gemma-4-31B-it-Claude-Opus-Distill-v2模型 (端口8080)
```ini
[Unit]
Description=Llama.cpp Server on Port 8083
After=network.target

[Service]
Type=simple
WorkingDirectory=/home/zhengxueen/workspace/llama.cpp
Environment="HIP_VISIBLE_DEVICES=0"
Environment="GGML_LOG_LEVEL=debug"
ExecStart=/usr/bin/env -i HOME=%h USER=%u LOGNAME=%u PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HIP_VISIBLE_DEVICES=0 GGML_LOG_LEVEL=debug /home/zhengxueen/workspace/llama.cpp/build-hip/bin/llama-server -m /mnt/ssd/models/TeichAI-gemma-4-31B/TeichAI-gemma-4-31B-it-Claude-Opus-Distill-v2.gguf --ctx-size 102400 --n-gpu-layers 9999 --flash-attn on --top-p 0.95 --top-k 64 --temp 1.0 --min-p 0.00 --jinja --host 0.0.0.0 --port 8080  --threads 8 --alias TeichAI-gemma-4-31B
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
```
### 2. 批量管理多个服务

```bash
# 批量启用所有服务
nano ~/.config/systemd/user/llama-server-8080.service
nano ~/.config/systemd/user/llama-server-8082.service

systemctl --user daemon-reload

systemctl --user enable llama-server-8080.service
systemctl --user enable llama-server-8082.service

systemctl --user enable --now llama-server-8080.service
systemctl --user enable --now llama-server-8084.service

# 批量启动所有服务
systemctl --user start llama-server-8080.service
systemctl --user start llama-server-8082.service
systemctl --user start llama-server-8083.service
systemctl --user start llama-server-8084.service

# 查看所有 llama 服务状态
systemctl --user list-units | grep llama

# 批量停止所有服务
systemctl --user stop llama-server-8080.service
systemctl --user stop llama-server-8082.service

systemctl --user status llama-server-8080.service
systemctl --user status llama-server-8082.service
systemctl --user status llama-server-8083.service --no-pager
systemctl --user status llama-server-8084.service --no-pager


# 停止并禁用服务

```bash
# 用户级服务
systemctl --user stop llama-server.service
systemctl --user disable llama-server.service
systemctl --user disable llama-server-8080.service
systemctl --user disable llama-server-8082.service

# 查看日志
journalctl --user -u llama-server-8080.service -n 100 --no-pager
journalctl --user -u llama-server-8082.service -n 100 --no-pager
journalctl --user -u llama-server-8083.service -f
journalctl --user -u llama-server-8084.service -f

# 系统级服务
sudo systemctl stop llama-server.service
sudo systemctl disable llama-server.service
```


#### 服务5: 多模态模型 (端口8085)
```ini
# nano ~/.config/systemd/user/llama-server-8082.service
[Unit]
Description=Llama.cpp Chandra-OCR Server on Port 8082
After=network.target

[Service]
Type=simple
WorkingDirectory=/home/zhengxueen/workspace/llama.cpp
Environment="HIP_VISIBLE_DEVICES=1"
Environment="GGML_LOG_LEVEL=debug"
ExecStart=/usr/bin/env -i HOME=%h USER=%u LOGNAME=%u PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HIP_VISIBLE_DEVICES=1 GGML_LOG_LEVEL=debug /home/zhengxueen/workspace/llama.cpp/build-hip/bin/llama-server --model /mnt/ssd/models/chandra-ocr/chandra-Q4_K_M.gguf --mmproj /mnt/ssd/models/chandra-ocr/chandra-mmproj-f16.gguf --ctx-size 32768 --n-gpu-layers 9999 --threads 4 --batch-size 512 --ubatch-size 128 --parallel 4 --jinja --api-key sk-local-ocr --flash-attn on --host 0.0.0.0 --port 8082 --alias chandra-ocr
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target

## 服务配置详解

### [Unit] 部分

```ini
[Unit]
Description=Llama.cpp Server          # 服务描述
After=network.target                  # 网络启动后启动
Wants=network-online.target           # 等待网络完全可用
```

### [Service] 部分

```ini
[Service]
Type=simple                          # 服务类型
User=zhengxueen                      # 运行用户（可选）
Group=zhengxueen                     # 运行组（可选）
WorkingDirectory=/path/to/llama.cpp  # 工作目录

# 环境变量
Environment="HIP_VISIBLE_DEVICES=0"
Environment="CUDA_VISIBLE_DEVICES=0"

# 启动命令
ExecStart=/path/to/llama-server [参数...]

# 重启策略
Restart=always                       # 总是重启
RestartSec=10                       # 重启间隔（秒）
StartLimitInterval=60                # 时间窗口
StartLimitBurst=3                   # 最大重启次数

# 日志配置
StandardOutput=journal               # 输出到系统日志
StandardError=journal                # 错误输出到系统日志
SyslogIdentifier=llama-server       # 日志标识符

# 资源限制
MemoryLimit=4G                       # 内存限制
CPUQuota=200%                        # CPU限制
```

### [Install] 部分

```ini
[Install]
WantedBy=default.target              # 用户级服务开机启动
# WantedBy=multi-user.target         # 系统级服务开机启动
```

## 高级配置

### 1. 环境变量文件

创建独立的环境变量文件：
```bash
# ~/.config/llama-server.env
HIP_VISIBLE_DEVICES=0
MODEL_PATH=/mnt/ssd/models/gpt-oss-20b-mxfp4.gguf
HOST=0.0.0.0
PORT=8080
```

在服务文件中引用：
```ini
[Service]
EnvironmentFile=/home/zhengxueen/.config/llama-server.env
ExecStart=/home/zhengxueen/workspace/llama.cpp/build-hip/bin/llama-server -m ${MODEL_PATH} --host ${HOST} --port ${PORT}
```

### 2. GPU 资源管理

#### 多GPU配置
```ini
[Service]
Environment="HIP_VISIBLE_DEVICES=0,1"  # 使用GPU 0和1
# 或
Environment="CUDA_VISIBLE_DEVICES=0,1"
```

#### GPU内存限制
```ini
[Service]
ExecStart=/path/to/llama-server --gpu-memory 4096
```

### 3. 性能优化

```ini
[Service]
# 并行处理
ExecStart=/path/to/llama-server --parallel 4 --batch-size 512

# 线程配置
ExecStart=/path/to/llama-server --threads 16

# 上下文大小
ExecStart=/path/to/llama-server --ctx-size 8192
```

## 故障排除

### 1. 常见错误

#### 权限错误
```
Failed to determine supplementary groups: Operation not permitted
```
**解决方案**: 移除 `Group=` 配置项

#### 端口占用
```
Address already in use
```
**解决方案**:
```bash
# 查看端口占用
sudo netstat -tlnp | grep 8080
# 或
sudo lsof -i :8080

# 停止占用进程
sudo kill -9 <PID>
```

#### 模型文件不存在
```
No such file or directory
```
**解决方案**:
```bash
# 检查文件路径
ls -la /path/to/model.gguf

# 检查权限
chmod 644 /path/to/model.gguf
```

### 2. 调试方法

#### 查看详细日志
```bash
# 查看完整日志
journalctl --user -u llama-server.service -n 100

# 实时跟踪日志
journalctl --user -u llama-server.service -f

# 查看特定时间段的日志
journalctl --user -u llama-server.service --since "2025-11-30 10:00"
```

#### 手动运行测试
```bash
# 切换到工作目录
cd /home/zhengxueen/workspace/llama.cpp

# 设置环境变量
export HIP_VISIBLE_DEVICES=0

# 手动运行命令
./build-hip/bin/llama-server -m /path/to/model.gguf --host 0.0.0.0 --port 8080
```

#### 检查服务配置
```bash
# 验证服务文件语法
systemctl --user daemon-reload

# 检查服务配置
systemctl --user cat llama-server.service
```

### 3. 性能监控

#### 资源使用情况
```bash
# 查看进程资源占用
ps aux | grep llama-server

# 实时监控
htop -p $(pgrep llama-server)

# GPU使用情况
rocm-smi
# 或
nvidia-smi
```

#### 网络连接测试
```bash
# 测试服务端口
curl http://localhost:8080/health

# 查看监听端口
netstat -tlnp | grep 8080
```

## 服务管理脚本

### 1. 批量管理脚本

```bash
#!/bin/bash
# llama-manager.sh

SERVICES=("llama-server-8080" "llama-server-8082")

case "$1" in
    start)
        for service in "${SERVICES[@]}"; do
            echo "Starting $service..."
            systemctl --user start "$service.service"
        done
        ;;
    stop)
        for service in "${SERVICES[@]}"; do
            echo "Stopping $service..."
            systemctl --user stop "$service.service"
        done
        ;;
    restart)
        for service in "${SERVICES[@]}"; do
            echo "Restarting $service..."
            systemctl --user restart "$service.service"
        done
        ;;
    status)
        for service in "${SERVICES[@]}"; do
            echo "=== $service ==="
            systemctl --user status "$service.service"
            echo ""
        done
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
```

### 2. 健康检查脚本

```bash
#!/bin/bash
# health-check.sh

PORTS=(8080 8082)
HOST="localhost"

for port in "${PORTS[@]}"; do
    echo "Checking port $port..."
    
    if curl -s "http://$HOST:$port/health" > /dev/null; then
        echo "✅ Port $port is healthy"
    else
        echo "❌ Port $port is not responding"
        systemctl --user restart "llama-server-$port.service"
    fi
done
```

## 系统级服务配置

如果需要配置系统级服务（需要 sudo 权限）：

### 1. 创建系统级服务文件

```bash
sudo nano /etc/systemd/system/llama-server.service
```

### 2. 修改路径和用户

```ini
[Unit]
Description=Llama.cpp Server
After=network.target

[Service]
Type=simple
User=zhengxueen
Group=zhengxueen
WorkingDirectory=/home/zhengxueen/workspace/llama.cpp
Environment="HIP_VISIBLE_DEVICES=0"
ExecStart=/home/zhengxueen/workspace/llama.cpp/build-hip/bin/llama-server -m /mnt/ssd/models/gpt-oss-20b-mxfp4.gguf -c 0 --n-gpu-layers 9999 --jinja --host 0.0.0.0 --port 8080
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

### 3. 系统级服务管理

```bash
# 重新加载
sudo systemctl daemon-reload

# 启用服务
sudo systemctl enable llama-server.service

# 启动服务
sudo systemctl start llama-server.service

# 查看状态
sudo systemctl status llama-server.service
```

## 安全考虑

### 1. 文件权限

```bash
# 限制模型文件权限
chmod 640 /path/to/model.gguf
chown zhengxueen:zhengxueen /path/to/model.gguf

# 限制服务文件权限
chmod 644 ~/.config/systemd/user/llama-server.service
```

### 2. 网络安全

```ini
[Service]
# 绑定到本地地址
ExecStart=... --host 127.0.0.1

# 或使用防火墙限制访问
# sudo ufw allow from 192.168.1.0/24 to any port 8080
```

### 3. 资源限制

```ini
[Service]
# 内存限制
MemoryLimit=8G

# CPU限制
CPUQuota=300%

# 文件描述符限制
LimitNOFILE=65536
```

## 备份和恢复

### 1. 备份服务配置

```bash
# 备份用户级服务
tar -czf llama-systemd-backup.tar.gz ~/.config/systemd/user/llama-server*.service

# 备份系统级服务
sudo cp /etc/systemd/system/llama-server*.service ~/llama-systemd-backup/
```

### 2. 恢复服务配置

```bash
# 恢复用户级服务
tar -xzf llama-systemd-backup.tar.gz -C ~/.config/systemd/user/
systemctl --user daemon-reload

# 恢复系统级服务
sudo cp ~/llama-systemd-backup/llama-server*.service /etc/systemd/system/
sudo systemctl daemon-reload
```

## 卸载服务

### 1. 停止并禁用服务

```bash
# 用户级服务
systemctl --user stop llama-server.service
systemctl --user disable llama-server.service

# 系统级服务
sudo systemctl stop llama-server.service
sudo systemctl disable llama-server.service
```

### 2. 删除服务文件

```bash
# 用户级服务
rm ~/.config/systemd/user/llama-server.service
systemctl --user daemon-reload

# 系统级服务
sudo rm /etc/systemd/system/llama-server.service
sudo systemctl daemon-reload
```

## 最佳实践

### 1. 服务命名规范
- 使用描述性名称：`llama-server-gpt.service`
- 包含端口信息：`llama-server-8080.service`
- 包含模型信息：`llama-server-chandra.service`

### 2. 配置管理
- 使用版本控制管理服务文件
- 为不同环境创建不同配置
- 定期备份重要配置

### 3. 监控和告警
- 设置日志监控
- 配置健康检查
- 设置资源使用告警

### 4. 性能优化
- 根据硬件配置调整参数
- 监控GPU和内存使用
- 定期清理日志文件

## 总结

通过 systemd 配置 Llama.cpp 服务可以实现：

- ✅ **持久化运行**: 服务崩溃自动重启
- ✅ **开机自启**: 系统启动时自动加载
- ✅ **集中管理**: 统一的服务管理接口
- ✅ **日志管理**: 集成的日志记录和查看
- ✅ **资源控制**: CPU、内存等资源限制
- ✅ **多实例**: 同时运行多个不同配置的服务

这种配置方式适合生产环境和个人开发使用，提供了稳定可靠的服务运行环境。
