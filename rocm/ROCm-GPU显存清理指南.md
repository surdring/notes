# ROCm GPU 显存清理指南 - AMD MI50

> 目标：解决 llama.cpp 退出后 ROCm GPU 显存仍被占用的问题，提供完整的监控、清理和预防方案。
>
> 适用 GPU：AMD Instinct MI50（`gfx906`）及其他 ROCm GPU。

---

## 1. 显存占用监控

### 1.1 基础监控命令

```bash
# 查看 GPU 状态和显存占用
rocm-smi

# 更详细的显存信息
rocm-smi --showmemuse

# 实时监控（每2秒刷新一次）
watch -n 2 rocm-smi

# 查看特定 GPU 的详细信息
rocm-smi -d 0 --showmemuse --showtemp --showpower
```

### 1.2 输出解读

```
=============================== ROCm System Management Interface =============================
==============================================================================================
|  GPU[0]    Temp   AvgPwr   Sclk     Pclk     Mclk     Fan  Perf  PwrCap  VRAM%  GPU% |
| 0: MI50    52C    245W    1201Mhz  1201Mhz  1200Mhz  0%   auto 300W    75%    98%  |
==============================================================================================
=============================== End of ROCm SMI Log ================================
```

- **VRAM%**：显存使用率百分比
- **GPU%**：GPU 计算单元使用率百分比
- **Temp**：GPU 温度
- **AvgPwr**：平均功耗

---

## 2. 显存占用常见原因

### 2.1 llama.cpp 相关问题

1. **进程未完全退出**
   - llama.cpp 进程仍在后台运行
   - 子进程或线程未正确清理

2. **ROCm 运行时缓存**
   - ROCm 运行时保留显存缓存以提高性能
   - HIP 内核编译缓存占用

3. **内存泄漏**
   - 程序异常退出导致的显存泄漏
   - 长时间运行后的累积泄漏

### 2.2 系统级问题

1. **其他 GPU 进程**
   - 系统中其他程序在使用 GPU
   - 守护进程或后台服务

2. **驱动问题**
   - AMDGPU 驱动异常
   - ROCm 运行时状态异常

---

## 3. 显存清理方案

### 3.1 方案一：进程级清理（推荐首选）

```bash
#!/bin/bash
# 文件名: clean_llama_processes.sh

echo "=== 清理 llama.cpp 相关进程 ==="

# 1. 查找所有 llama.cpp 相关进程
echo "当前 llama.cpp 进程："
ps aux | grep llama | grep -v grep

# 2. 优雅终止进程
echo "正在优雅终止 llama.cpp 进程..."
pkill -SIGTERM llama-cli
pkill -SIGTERM llama-server
pkill -SIGTERM llama-mtmd-cli
pkill -SIGTERM llama-quantize

# 等待进程退出
sleep 3

# 3. 强制终止残留进程
echo "检查并强制终止残留进程..."
if pgrep -f "llama" > /dev/null; then
    echo "发现残留进程，强制终止..."
    pkill -9 -f llama-cli
    pkill -9 -f llama-server
    pkill -9 -f llama-mtmd-cli
    pkill -9 -f llama-quantize
fi

# 4. 验证清理结果
echo "清理后的进程状态："
ps aux | grep llama | grep -v grep || echo "无 llama.cpp 进程"

echo "=== 显存状态 ==="
rocm-smi --showmemuse
```

使用方法：
```bash
chmod +x clean_llama_processes.sh
./clean_llama_processes.sh
```

### 3.2 方案二：ROCm 运行时清理

```bash
#!/bin/bash
# 文件名: clean_rocm_runtime.sh

echo "=== 清理 ROCm 运行时缓存 ==="

# 1. 清理临时文件
echo "清理 HIP/ROCm 临时文件..."
rm -rf /tmp/hip*
rm -rf /tmp/rocm*
rm -rf /tmp/amd*

# 2. 清理用户级 ROCm 缓存
echo "清理用户 ROCm 缓存..."
rm -rf ~/.cache/hip*
rm -rf ~/.cache/rocm*

# 3. 清理系统级缓存（需要 sudo）
echo "清理系统级 ROCm 缓存..."
sudo rm -rf /opt/rocm/.cache/*
sudo rm -rf /var/tmp/hip*

echo "=== ROCm 缓存清理完成 ==="
```

### 3.3 方案三：驱动级重置（谨慎使用）

```bash
#!/bin/bash
# 文件名: reset_amdgpu_driver.sh

echo "=== 重置 AMDGPU 驱动 ==="
echo "警告：此操作将终止所有 GPU 进程！"
read -p "确认继续？(y/N): " confirm

if [[ $confirm == "y" || $confirm == "Y" ]]; then
    echo "正在卸载 AMDGPU 驱动..."
    sudo modprobe -r amdgpu
    
    echo "等待 3 秒..."
    sleep 3
    
    echo "正在重新加载 AMDGPU 驱动..."
    sudo modprobe amdgpu
    
    echo "等待驱动初始化..."
    sleep 5
    
    echo "=== 驱动重置完成 ==="
    rocm-smi
else
    echo "操作已取消"
fi
```

### 3.4 方案四：一键完整清理脚本

```bash
#!/bin/bash
# 文件名: clear_gpu_memory.sh

echo "========================================"
echo "    ROCm GPU 显存完整清理脚本"
echo "========================================"

# 函数：检查命令执行结果
check_result() {
    if [ $? -eq 0 ]; then
        echo "✓ $1 成功"
    else
        echo "✗ $1 失败"
    fi
}

# 1. 清理 llama.cpp 进程
echo -e "\n[1/5] 清理 llama.cpp 进程..."
pkill -SIGTERM llama-cli 2>/dev/null
pkill -SIGTERM llama-server 2>/dev/null
pkill -SIGTERM llama-mtmd-cli 2>/dev/null
sleep 2

# 强制清理残留进程
pkill -9 -f llama 2>/dev/null
check_result "进程清理"

# 2. 清理 ROCm 缓存
echo -e "\n[2/5] 清理 ROCm 缓存..."
rm -rf /tmp/hip* 2>/dev/null
rm -rf /tmp/rocm* 2>/dev/null
rm -rf ~/.cache/hip* 2>/dev/null
rm -rf ~/.cache/rocm* 2>/dev/null
check_result "缓存清理"

# 3. 检查显存状态
echo -e "\n[3/5] 检查显存状态..."
rocm-smi --showmemuse

# 4. 验证进程清理
echo -e "\n[4/5] 验证进程状态..."
if pgrep -f "llama" > /dev/null; then
    echo "⚠️  仍有残留 llama 进程："
    ps aux | grep llama | grep -v grep
else
    echo "✓ 无 llama.cpp 进程"
fi

# 5. 显示清理后状态
echo -e "\n[5/5] 清理完成！当前 GPU 状态："
rocm-smi

echo -e "\n========================================"
echo "           显存清理完成！"
echo "========================================"
```

### 3.5 方案五：终极方案 - 系统重启

如果所有软件方法都无法清理显存：

```bash
# 重启系统（最可靠的方法）
sudo reboot

# 或者仅重启 GPU 服务（如果支持）
sudo systemctl restart amdgpu-dkms
```

---

## 4. 预防显存残留的最佳实践

### 4.1 优雅退出程序

```bash
# 使用 Ctrl+C 优雅退出
# 或发送 SIGTERM 信号
kill -SIGTERM <pid>

# 避免使用 SIGKILL（可能导致显存泄漏）
kill -9 <pid>  # 仅在必要时使用
```

### 4.2 监控脚本

```bash
#!/bin/bash
# 文件名: monitor_gpu_memory.sh

echo "开始监控 GPU 显存使用..."
echo "按 Ctrl+C 停止监控"

while true; do
    clear
    echo "========================================"
    echo "GPU 显存监控 - $(date)"
    echo "========================================"
    
    # 显示显存状态
    rocm-smi --showmemuse
    
    echo -e "\n----------------------------------------"
    echo "llama.cpp 进程状态："
    
    # 显示相关进程
    llama_processes=$(ps aux | grep llama | grep -v grep)
    if [ -n "$llama_processes" ]; then
        echo "$llama_processes"
    else
        echo "无 llama.cpp 进程运行"
    fi
    
    echo "========================================"
    sleep 5
done
```

### 4.3 合理配置显存使用

```bash
# 启动时预留显存余量
HIP_VISIBLE_DEVICES=0 \
./build-hip/bin/llama-server \
  --model /path/to/model.gguf \
  --n-gpu-layers 45 \     # 而不是 -1，留一些显存余量
  --ctx-size 4096 \       # 适当减小上下文大小
  --host 0.0.0.0 \
  --port 8080

# 监控显存使用趋势
watch -n 5 'rocm-smi --showmemuse && echo "---" && ps aux | grep llama'
```

---

## 5. 故障排除

### 5.1 常见问题

**问题1：清理后显存仍被占用**
```bash
# 检查是否有其他进程使用 GPU
sudo lsof /dev/dri/card0
sudo fuser -v /dev/dri/card0

# 检查内核模块状态
lsmod | grep amdgpu
```

**问题2：rocm-smi 命令无响应**
```bash
# 检查 ROCm 服务状态
sudo systemctl status rocm-smi

# 重启 ROCm 服务
sudo systemctl restart rocm-smi
```

**问题3：驱动异常**
```bash
# 检查驱动日志
dmesg | grep amdgpu
journalctl | grep -i rocm

# 重新安装驱动（如果需要）
sudo apt-get install --reinstall amdgpu-dkms
```

### 5.2 性能优化建议

1. **定期清理**：长时间运行后定期执行清理脚本
2. **监控趋势**：使用监控脚本观察显存使用模式
3. **合理配置**：根据模型大小合理设置 `--n-gpu-layers`
4. **及时更新**：保持 ROCm 和驱动程序为最新版本

---

## 6. 快速参考

### 6.1 常用命令速查

```bash
# 查看显存
rocm-smi --showmemuse

# 终止 llama 进程
pkill -f llama

# 清理缓存
rm -rf /tmp/hip*

# 完整清理
./clear_gpu_memory.sh

# 监控模式
watch -n 2 rocm-smi
```

### 6.2 脚本使用权限

```bash
# 设置脚本执行权限
chmod +x clean_llama_processes.sh
chmod +x clean_rocm_runtime.sh
chmod +x reset_amdgpu_driver.sh
chmod +x clear_gpu_memory.sh
chmod +x monitor_gpu_memory.sh
```

---

> 本指南基于 AMD MI50 + ROCm 7.x 环境的实际使用经验编写，可有效解决 llama.cpp 退出后显存占用不释放的问题。如有特殊情况，请结合具体环境调整方案。
