# Llama.cpp 在 AMD MI50 上的部署指南

  

## 问题描述

  

在 AMD MI50 32GB 显卡上部署 Qwen3VL-32B-Thinking-Q4_K_M.gguf 模型时遇到以下问题：

  

1. 系统检测到多个 GPU，但默认使用了显存较小的 NVIDIA GPU

2. 尝试分配显存时失败，因为默认选择了错误的 GPU

3. 需要正确配置环境以使用 AMD MI50 GPU

  

## 系统环境

  

### 硬件配置

- **CPU**: 24 线程

- **GPU 1**: AMD MI50 32GB (目标设备)

- **GPU 2**: NVIDIA GeForce GT 1030 (1.7GB)

- **内存**: 大容量内存（建议至少 64GB）

  

### 软件环境

- **操作系统**: Ubuntu 22.04 LTS

- **Vulkan 驱动**: RADV (Mesa)

- **ROCm 版本**: 5.x 或更高版本

- **llama.cpp 版本**: b7136

  

## 问题分析

  

### 错误日志分析

  

从日志中可以看到以下关键信息：

  

```

ggml_vulkan: Found 2 Vulkan devices:

ggml_vulkan: 0 = NVIDIA GeForce GT 1030 (NVIDIA) | uma: 0 | fp16: 0 | bf16: 0 | warp size: 32 | shared memory: 49152 | int dot: 1 | matrix cores: none

ggml_vulkan: 1 = AMD Radeon Graphics (RADV VEGA20) (radv) | uma: 0 | fp16: 1 | bf16: 0 | warp size: 64 | shared memory: 65536 | int dot: 1 | matrix cores: none

```

  

```

ggml_vulkan: Device memory allocation of size 813760512 failed.

ggml_vulkan: vk::Device::allocateMemory: ErrorOutOfDeviceMemory

```

  

### 问题原因

  

1. 系统检测到两个 GPU，但默认使用了显存较小的 NVIDIA GPU (Vulkan0)

2. 尝试分配约 813MB 显存时失败，因为 NVIDIA GPU 只有 1.7GB 可用显存

3. 需要强制 `llama-server` 使用 AMD GPU (Vulkan1)

  

## 解决方案

  

### 1. 设置环境变量

  

创建或编辑 `~/.bashrc` 文件，添加以下内容：

  

```bash

# AMD GPU 配置

export VK_DEVICE_INDEX=1 # 选择第二个 GPU (AMD)

export ROCR_VISIBLE_DEVICES=0 # 显示第一个 ROCm 设备

export HSA_OVERRIDE_GFX_VERSION=9.0.6 # 指定 GFX 版本

export HIP_VISIBLE_DEVICES=0 # 显示第一个 HIP 设备

export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/radeon_icd.x86_64.json # 指定 Vulkan ICD 文件

export VK_LAYER_PATH=/usr/share/vulkan/explicit_layer.d # Vulkan 层路径

```

  

应用配置：

```bash

source ~/.bashrc

```

  

### 2. 验证 GPU 选择

  

```bash

# 检查 Vulkan 设备

vulkaninfo --summary | grep -A 5 "GPU id"

  

# 检查 ROCm 设备

rocm-smi

```

  

### 3. 启动 llama-server

  

使用以下命令启动 `llama-server`：

  

```bash

cd /mnt/ssd/models/llama-b7136-bin-ubuntu-vulkan-x64/build/bin/

  

VK_DEVICE_INDEX=1 \

ROCR_VISIBLE_DEVICES=0 \

HSA_OVERRIDE_GFX_VERSION=9.0.6 \

./llama-server \

-m /mnt/ssd/models/Qwen3VL-32B-Thinking-Q4_K_M.gguf \

--ctx-size 8192 \

--n-gpu-layers -1 \

--jinja \

-ub 2048 \

-b 2048 \

--threads $(nproc) \

--host 127.0.0.1 \

--port 8080

```

或

  

```bash

cd /mnt/ssd/models/llama-b7136-bin-ubuntu-vulkan-x64/build/bin/

  
VK_DEVICE_INDEX=1 \
ROCR_VISIBLE_DEVICES=0 \
HSA_OVERRIDE_GFX_VERSION=9.0.6 \
./llama-server \
-m /mnt/ssd/models/Qwen3VL-32B-Thinking-Q4_K_M.gguf \
-c 8192 \
--n-gpu-layers -1 \
--jinja \
--host 127.0.0.1 \
--threads 12 \
--port 8080

```

### 4. 参数说明

  

- `-m`: 模型文件路径

- `--ctx-size 8192`: 上下文窗口大小

- `--n-gpu-layers 32`: 在 GPU 上运行的层数（根据显存调整）

- `--jinja`: 启用 Jinja2 模板支持

- `-ub 2048`: 统一批处理大小

- `-b 2048`: 批处理大小

- `--threads $(nproc)`: 使用所有可用的 CPU 核心

- `--host 127.0.0.1`: 绑定到本地回环地址

- `--port 8080`: 使用 8080 端口

  

## 常见问题排查

  

### 1. 权限问题

  

```bash

# 检查文件权限

ls -l /mnt/ssd/models/Qwen3VL-32B-Thinking-Q4_K_M.gguf

  

# 修改权限

chmod +x /mnt/ssd/models/llama-b7136-bin-ubuntu-vulkan-x64/build/bin/llama-server

```

  

### 2. 文件系统挂载选项

  

```bash

# 检查挂载选项

mount | grep /mnt/ssd

  

# 重新挂载（如果需要）

sudo mount -o remount,exec /mnt/ssd

```

  

### 3. Vulkan 驱动问题

  

```bash

# 检查 Vulkan 驱动

vulkaninfo --summary

  

# 安装必要驱动

sudo apt update

sudo apt install mesa-vulkan-drivers vulkan-tools

```

  

## 性能优化建议

  

1. **调整批处理大小**：

```bash

-b 2048 # 批处理大小

-ub 2048 # 统一批处理大小

```

如果遇到显存不足，可以减小这些值。

  

2. **调整线程数**：

```bash

--threads $(nproc) # 使用所有 CPU 核心

```

  

3. **GPU 层设置**：

```bash

--n-gpu-layers 32 # 根据显存调整

```

如果显存不足，减少此值；如果有足够显存，可以增加此值以提高性能。

  

## 持久化配置

  

### 1. 系统启动时自动挂载

  

编辑 `/etc/fstab` 文件：

  

```

UUID=609ADBF79ADBC7A4 /mnt/ssd ntfs-3g defaults,auto,users,rw,exec,nofail 0 0

```

  

### 2. 系统服务配置

  

创建 systemd 服务文件 `/etc/systemd/system/llama-server.service`：

  

```ini

[Unit]

Description=Llama.cpp Server

After=network.target

  

[Service]

User=your_username

WorkingDirectory=/mnt/ssd/models/llama-b7136-bin-ubuntu-vulkan-x64/build/bin

Environment="VK_DEVICE_INDEX=1"

Environment="ROCR_VISIBLE_DEVICES=0"

Environment="HSA_OVERRIDE_GFX_VERSION=9.0.6"

Environment="HIP_VISIBLE_DEVICES=0"

ExecStart=/mnt/ssd/models/llama-b7136-bin-ubuntu-vulkan-x64/build/bin/llama-server \

-m /mnt/ssd/models/Qwen3VL-32B-Thinking-Q4_K_M.gguf \

--ctx-size 8192 \

--n-gpu-layers 32 \

--jinja \

-ub 2048 \

-b 2048 \

--threads 24 \

--host 127.0.0.1 \

--port 8080

Restart=always

  

[Install]

WantedBy=multi-user.target

```

  

启用并启动服务：

  

```bash

sudo systemctl daemon-reload

sudo systemctl enable llama-server

sudo systemctl start llama-server

```

  

## 监控与维护

  

### 1. 查看服务状态

  

```bash

# 查看服务状态

sudo systemctl status llama-server

  

# 查看日志

journalctl -u llama-server -f

```

  

### 2. 性能监控

  

```bash

# 查看 GPU 使用情况

rocm-smi

  

# 查看系统资源

htop

```

  

## 故障排除

  

### 1. 常见错误

  

#### 错误：Vulkan 设备未找到

  

```

ggml_vulkan: Found 0 Vulkan devices

```

  

**解决方案**：

- 确认 Vulkan 驱动已正确安装

- 检查 `VK_ICD_FILENAMES` 环境变量

- 运行 `vulkaninfo` 检查 Vulkan 设备

  

#### 错误：显存不足

  

```

ggml_vulkan: Device memory allocation of size XXXX failed.

ggml_vulkan: vk::Device::allocateMemory: ErrorOutOfDeviceMemory

```

  

**解决方案**：

- 减少批处理大小 (`-b` 和 `-ub`)

- 减少上下文大小 (`--ctx-size`)

- 减少 GPU 层数 (`--n-gpu-layers`)

  

#### 错误：权限问题

  

```

sudo: unable to execute ./llama-server: Permission denied

```

  

**解决方案**：

- 确保文件有执行权限：`chmod +x llama-server`

- 检查文件系统挂载选项，确保没有 `noexec` 标志

  

## 参考链接

  

1. [llama.cpp GitHub](https://github.com/ggml-org/llama.cpp)

2. [ROCm 文档](https://rocm.docs.amd.com/)

3. [Vulkan 文档](https://vulkan.lunarg.com/doc/)

4. [AMD ROCm 安装指南](https://rocm.docs.amd.com/en/latest/Installation_Guide/Installation-Guide.html)

  

## 更新历史

  

- 2025-11-24: 初始版本

- 2025-11-24: 添加系统服务配置

- 2025-11-24: 完善故障排除部分

  

---

  

**注意**：本指南基于特定硬件和软件环境编写，实际使用时可能需要根据具体情况进行调整。