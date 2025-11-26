# Llama.cpp 本地部署与多 GPU 环境配置指南

## 1. 问题描述

在 AMD MI50 32GB 显卡上部署 Qwen3VL-32B-Thinking-Q4_K_M.gguf 模型时遇到问题：

- 系统检测到多个 GPU（NVIDIA GeForce GT 1030 和 AMD Radeon Graphics (RADV VEGA20)）
- 默认使用 NVIDIA GPU 导致显存不足（仅 1.7GB）
- 需要强制使用 AMD GPU 进行模型推理

## 2. 环境准备

### 2.1 硬件信息

- **目标 GPU**：AMD MI50 32GB
- **其他 GPU**：NVIDIA GeForce GT 1030 (1.7GB)
- **CPU**：24 线程
- **内存**：未指定（建议至少 64GB）

### 2.2 软件环境

- **操作系统**：Ubuntu 22.04 LTS
- **Vulkan 驱动**：RADV (Mesa)
- **ROCm 版本**：未指定（建议 5.x 或更高）
- **llama.cpp 版本**：b7136

## 3. 解决方案

### 3.1 环境变量配置

创建或编辑 `~/.bashrc` 文件：

bash



```# AMD GPU 配置 
export VK_DEVICE_INDEX=1           # 选择第二个 GPU (AMD) 
export ROCR_VISIBLE_DEVICES=0      # 显示第一个 ROCm 设备 
export HSA_OVERRIDE_GFX_VERSION=9.0.6  # 指定 GFX 版本 
export HIP_VISIBLE_DEVICES=0       # 显示第一个 HIP 设备 
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/radeon_icd.x86_64.json  # 指定 Vulkan ICD 文件 
export VK_LAYER_PATH=/usr/share/vulkan/explicit_layer.d  # Vulkan 层路径 
# 应用配置 
source ~/.bashrc
```

### 3.2 验证 GPU 选择

bash

`# 检查 Vulkan 设备 vulkaninfo --summary | grep -A 5 "GPU id" # 检查 ROCm 设备 rocm-smi`

### 3.3 启动 llama-server

bash

`cd /mnt/ssd/models/llama-b7136-bin-ubuntu-vulkan-x64/build/bin/ ./llama-server \   -m /mnt/ssd/models/Qwen3VL-32B-Thinking-Q4_K_M.gguf \   --ctx-size 8192 \   --n-gpu-layers -1 \   --jinja \   -ub 2048 \   -b 2048 \   --threads $(nproc) \   --host 127.0.0.1 \   --port 8080`

## 4. 常见问题排查

### 4.1 权限问题

bash

`# 检查文件权限 ls -l /mnt/ssd/models/Qwen3VL-32B-Thinking-Q4_K_M.gguf # 修改权限 chmod +x /mnt/ssd/models/llama-b7136-bin-ubuntu-vulkan-x64/build/bin/llama-server`

### 4.2 文件系统挂载选项

bash

`# 检查挂载选项 mount | grep /mnt/ssd # 重新挂载（如果需要） sudo mount -o remount,exec /mnt/ssd`

### 4.3 Vulkan 驱动问题

bash

`# 检查 Vulkan 驱动 vulkaninfo --summary  # 安装必要驱动 sudo apt update sudo apt install mesa-vulkan-drivers vulkan-tools`

## 5. 性能优化建议

1. **调整批处理大小**：
    
    bash
    
    `-b 2048      # 批处理大小 -ub 2048     # 统一批处理大小`
    
2. **调整线程数**：
    
    bash
    
    `--threads $(nproc)  # 使用所有 CPU 核心`
    
3. **GPU 层设置**：
    
    bash
    
    `--n-gpu-layers -1  # 使用所有可用的 GPU 层`
    

## 6. 持久化配置

### 6.1 系统启动时自动挂载

编辑 fstab 文件：

`UUID=609ADBF79ADBC7A4 /mnt/ssd ntfs-3g defaults,auto,users,rw,exec,nofail 0 0`

### 6.2 系统服务配置

创建 systemd 服务文件 `/etc/systemd/system/llama-server.service`：

ini

`[Unit] Description=Llama.cpp Server After=network.target [Service] User=your_username WorkingDirectory=/mnt/ssd/models/llama-b7136-bin-ubuntu-vulkan-x64/build/bin Environment="VK_DEVICE_INDEX=1" Environment="ROCR_VISIBLE_DEVICES=0" Environment="HSA_OVERRIDE_GFX_VERSION=9.0.6" Environment="HIP_VISIBLE_DEVICES=0" ExecStart=/mnt/ssd/models/llama-b7136-bin-ubuntu-vulkan-x64/build/bin/llama-server \   -m /mnt/ssd/models/Qwen3VL-32B-Thinking-Q4_K_M.gguf \   --ctx-size 8192 \   --n-gpu-layers -1 \   --jinja \   -ub 2048 \   -b 2048 \   --threads 24 \   --host 127.0.0.1 \   --port 8080 Restart=always [Install] WantedBy=multi-user.target`

启用并启动服务：

bash

`sudo systemctl daemon-reload sudo systemctl enable llama-server sudo systemctl start llama-server`

## 7. 监控与维护

### 7.1 查看服务状态

bash

`sudo systemctl status llama-server journalctl -u llama-server -f`

### 7.2 性能监控

bash

`# 查看 GPU 使用情况 rocm-smi  # 查看系统资源 htop nvidia-smi  # 如果同时使用 NVIDIA GPU`

## 8. 故障排除

### 8.1 常见错误

1. **Vulkan 设备未找到**：
    
    - 确认 Vulkan 驱动已正确安装
    - 检查 `VK_ICD_FILENAMES` 环境变量
    
2. **显存不足**：
    
    - 减少批处理大小 (`-b` 和 `-ub`)
    - 减少上下文大小 (`--ctx-size`)
    
3. **权限问题**：
    
    - 确保用户有执行权限
    - 检查文件系统挂载选项
    

### 8.2 日志分析

bash

`# 查看系统日志 journalctl -xe  # 查看 Vulkan 调试信息 VK_LOADER_DEBUG=all vulkaninfo`

## 9. 参考链接

1. [llama.cpp GitHub](https://github.com/ggml-org/llama.cpp)
2. [ROCm 文档](https://rocm.docs.amd.com/)
3. [Vulkan 文档](https://vulkan.lunarg.com/doc/)

## 10. 更新历史

- 2025-11-24: 初始版本
- 2025-11-24: 添加系统服务配置
- 2025-11-24: 完善故障排除部分

---

**注意**：本指南基于特定硬件和软件环境编写，实际使用时可能需要根据具体情况进行调整。