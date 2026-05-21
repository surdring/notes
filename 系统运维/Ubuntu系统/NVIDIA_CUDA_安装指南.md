# Ubuntu NVIDIA 驱动与 CUDA 安装指南

> 硬件：NVIDIA GeForce RTX 3080 (20GB)
> 系统：Ubuntu 24.04
> 日期：2026-04-29

---

## 一、安装前准备

### 1. 更新系统
```bash
sudo apt update && sudo apt upgrade -y
```

### 2. 安装必要依赖
```bash
sudo apt install -y ubuntu-drivers-common linux-headers-$(uname -r) build-essential dkms
```

### 3. 查看可用驱动
```bash
ubuntu-drivers devices
```

输出示例（RTX 3080）：
```
model    : GA102 [GeForce RTX 3080] (GA102 [GeForce RTX 3080 20GB])
driver   : nvidia-driver-595-open - distro non-free recommended
```

**推荐驱动版本**：`nvidia-driver-595-open`（系统已标记 recommended）

---

## 二、安装 NVIDIA 驱动

### 方法一：使用 ubuntu-drivers（推荐，简单）
```bash
sudo ubuntu-drivers autoinstall
sudo reboot
```

或手动安装特定版本：
```bash
sudo apt install -y nvidia-driver-595-open
sudo reboot
```

### 方法二：使用官方 Runfile（已下载的 .run 文件）

#### 步骤 1：关闭图形界面
```bash
sudo systemctl isolate multi-user.target
```

#### 步骤 2：清理旧驱动（如有）
```bash
sudo apt purge -y "nvidia-*" "libnvidia-*"
sudo apt autoremove -y
```

#### 步骤 3：运行安装程序
```bash
chmod +x NVIDIA-Linux-x86_64-595.58.03.run
sudo ./NVIDIA-Linux-x86_64-595.58.03.run
```

#### 步骤 4：重启
```bash
sudo reboot
```

#### Runfile 常用参数
| 参数 | 作用 |
|------|------|
| `--no-x-check` | 跳过 X 服务器检测（不建议，可能导致失败） |
| `--no-opengl-files` | 不安装 OpenGL 文件（纯计算服务器可用，桌面环境不要加） |

---

## 三、验证驱动安装

```bash
nvidia-smi
```

预期输出：
```
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 595.58.03              Driver Version: 595.58.03      CUDA Version: 13.2     |
+-----------------------------------------+------------------------+----------------------+
|   0  NVIDIA GeForce RTX 3080        Off |   00000000:01:00.0  On |                  N/A |
+-----------------------------------------------------------------------------------------+
```

**注意**：`CUDA Version: 13.2` 是该驱动支持的最高 CUDA 版本，**不是**已安装的 CUDA 版本。

---

## 四、安装 CUDA Toolkit

### 1. 添加 CUDA 仓库
```bash
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt update
```

> **说明**：`cuda-keyring` 是 NVIDIA 的 GPG 密钥环包，用于验证软件包真实性，并自动配置 APT 源。

### 2. 选择 CUDA 版本

| 版本 | 适用场景 | 命令 |
|------|---------|------|
| CUDA 12.9 | 实际安装版本 | `sudo apt install -y cuda-toolkit-12-9` |
| CUDA 12.8 | 稳定推荐（模型部署）| `sudo apt install -y cuda-toolkit-12-8` |
| CUDA 13.2 | 最新版（驱动支持，但框架可能不兼容）| `sudo apt install -y cuda-toolkit` |

**建议**：模型部署推荐 **CUDA 12.8**，因为 vLLM、PyTorch、TensorRT-LLM 等框架对 CUDA 13.x 支持尚不完善。

### 3. 配置环境变量
```bash
echo 'export PATH="/usr/local/cuda/bin:$PATH"' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH="/usr/local/cuda/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"' >> ~/.bashrc
source ~/.bashrc
```

### 4. 验证 CUDA 安装
```bash
nvcc -V
```

预期输出：
```
nvcc: NVIDIA (R) Cuda compiler driver
Copyright (c) 2005-2026 NVIDIA Corporation
Cuda compilation tools, release 12.9, V12.9.xx
```

---

## 五、常见问题

### 1. 依赖冲突（libnvidia-egl-gbm1）
**现象**：
```
libnvidia-gl-580 : 冲突: libnvidia-egl-gbm1
E: 无法修正错误
```

**解决**：
```bash
sudo apt purge -y libnvidia-egl-gbm1 libnvidia-egl-gbm1:i386
sudo apt autoremove -y
sudo apt --fix-broken install
```

### 2. 清理旧驱动后重装
```bash
sudo apt purge -y "nvidia-*" "libnvidia-*" "cuda-*"
sudo apt autoremove -y
sudo apt clean
sudo ubuntu-drivers autoinstall
sudo reboot
```

### 3. Nouveau 驱动冲突

**现象**：安装 NVIDIA 驱动时提示：
```
ERROR: The Nouveau kernel driver is currently in use by your system.
This driver is incompatible with the NVIDIA driver...
```

#### 方法一：永久禁用 Nouveau（推荐）

```bash
# 1. 创建黑名单文件
sudo bash -c "echo 'blacklist nouveau
options nouveau modeset=0' > /etc/modprobe.d/blacklist-nouveau.conf"

# 2. 更新 initramfs
sudo update-initramfs -u

# 3. 重启系统
sudo reboot
```

重启后验证 Nouveau 是否禁用成功：
```bash
lsmod | grep nouveau
```

**预期输出**：无内容（空行），表示 Nouveau 未加载。

#### 方法二：临时禁用（当前会话）

如果不想重启，可以临时卸载 Nouveau 模块：
```bash
sudo rmmod -f nouveau
```

然后立即运行 NVIDIA 安装程序。注意：这只是临时卸载，下次开机 Nouveau 仍会加载。

#### 方法三：安装时自动禁用

NVIDIA Runfile 安装程序可以自动处理 Nouveau：
```bash
sudo ./NVIDIA-Linux-x86_64-595.58.03.run --disable-nouveau
```

---

## 六、模型部署环境配置

### 1. 配置 pip 国内源
```bash
mkdir -p ~/.config/pip
cat > ~/.config/pip/pip.conf << 'EOF'
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
trusted-host = pypi.tuna.tsinghua.edu.cn
EOF
```

### 2. 安装 Python 环境
```bash
sudo apt install -y python3 python3-pip python3-venv
python3 -m venv ~/model_env
source ~/model_env/bin/activate
```

### 3. 安装 PyTorch（CUDA 12.x 版本）
```bash
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128
```

### 4. 安装 vLLM（高性能 LLM 推理）
```bash
pip install vllm
```

### 5. 验证 PyTorch GPU 可用性
```bash
python3 -c "import torch; print(torch.cuda.is_available()); print(torch.cuda.get_device_name(0))"
```

预期输出：
```
True
NVIDIA GeForce RTX 3080
```

---

## 七、关键知识点

### cuda-keyring 版本
- 当前最新版本：`cuda-keyring_1.1-1_all.deb`（2023年4月发布）
- 无需更新，一直有效

### CUDA 版本选择建议
- **驱动版本**：`nvidia-smi` 显示的是驱动支持的最高 CUDA 版本
- **实际 CUDA**：`nvcc -V` 显示的是实际安装的 CUDA 版本
- **模型部署**：推荐 CUDA 12.4 ~ 12.8，兼容性最佳
- **CUDA 13.x**：驱动已支持，但 PyTorch/vLLM 等框架尚未适配

### 驱动与 CUDA 的关系
- 驱动负责与硬件通信
- CUDA Toolkit 提供开发工具（编译器 nvcc、库文件等）
- 驱动向后兼容：驱动 595 支持 CUDA 13.2 及以下所有版本

---

## 八、安装后检查清单

- [ ] `nvidia-smi` 显示驱动版本和 GPU 信息
- [ ] `nvcc -V` 显示 CUDA 编译器版本
- [ ] PyTorch 能识别 GPU：`torch.cuda.is_available()` 返回 `True`
- [ ] 模型推理服务能正常启动（如 vLLM、Ollama 等）

---

## 参考命令速查

```bash
# 查看驱动
nvidia-smi

# 查看 CUDA
nvcc -V

# 查看已加载的 NVIDIA 模块
lsmod | grep nvidia

# 查看驱动详细信息
cat /proc/driver/nvidia/version

# 重启 NVIDIA 驱动服务
sudo systemctl restart nvidia-persistenced
```
