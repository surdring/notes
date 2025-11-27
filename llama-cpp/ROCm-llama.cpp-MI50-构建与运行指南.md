# 在 Ubuntu 24.04 + ROCm 7.x 上为 AMD MI50 构建 ROCm/llama.cpp

> 目标：在已正确安装 **ROCm 7.x** 的 Ubuntu 24.04 系统上，为 AMD Instinct **MI50（gfx906）** 从 AMD 官方仓库 **ROCm/llama.cpp** 构建并运行 HIP 版 `llama.cpp`。
>
> 适用 GPU：AMD Instinct MI50（`gfx906`）。

---

## 1. 环境前提

- 操作系统：Ubuntu 24.04（noble）
- GPU：AMD Instinct MI50，架构代号 `gfx906`
- ROCm：7.x 系列（例如 7.0.2 / 7.0.3），已通过 AMD 官方仓库安装
- 驱动：`amdgpu-dkms` 已正确加载

### 1.1 验证 ROCm 是否正常

```bash
/opt/rocm/bin/rocminfo | grep -i gfx
/opt/rocm/bin/hipcc --version
```

确认输出中包含 `gfx906`，且 `hipcc` 可以正常运行。

---

## 2. 获取 llama.cpp 官方源码（ggml-org）

```bash
# 建议放在一个单独的工作目录
mkdir -p ~/workspace && cd ~/workspace

# 克隆 llama.cpp 官方仓库（ggml-org）
git clone https://github.com/ggml-org/llama.cpp
cd llama.cpp
```

> 说明：该仓库是 llama.cpp 的官方主线仓库，由 ggml 社区维护，已经内置了 ROCm/HIP 后端和多模态（如 Qwen3-VL）等最新特性。

---

## 3. 为 MI50 设置 ROCm 架构

AMD 官方文档推荐通过环境变量 `LLAMACPP_ROCM_ARCH` 指定要编译的 GPU 架构列表。

### 3.1 只针对 MI50（gfx906）

```bash
# 仅编译针对 MI50 的 kernel（推荐本机构建）
export LLAMACPP_ROCM_ARCH=gfx906
```

### 3.2 同时支持多种 AMD GPU（可选）

如果希望一个二进制在多种 AMD GPU 上通用，可以使用 AMD 文档给出的“宽范围”配置（编译时间更长）：

```bash
export LLAMACPP_ROCM_ARCH=gfx803,gfx900,gfx906,gfx908,\
  gfx90a,gfx942,gfx1010,gfx1030,gfx1032,gfx1100,gfx1101,gfx1102
```

> 对于单机、只在 MI50 上使用的场景，**推荐只保留 `gfx906`**，编译速度更快、体积更小。

---

## 4. 使用 CMake + HIP 编译 ROCm/llama.cpp

这里直接采用 AMD 官方文档中的推荐命令，只是将 `LLAMACPP_ROCM_ARCH` 固定为 MI50 的 `gfx906`。

### 4.1 配置与构建

在 `llama.cpp` 源码根目录下执行：

```bash
# 确认当前目录是 ROCm/llama.cpp 源码根目录
pwd
# 例如：/home/zhengxueen/workspace/llama.cpp

# 为 MI50 设置架构
export LLAMACPP_ROCM_ARCH=gfx906

# 使用 ROCm 自带工具自动探测 hipclang 和 HIP 路径
HIPCXX="$(hipconfig -l)/clang" HIP_PATH="$(hipconfig -R)" cmake -S . -B build-hip -DGGML_HIP=ON -DAMDGPU_TARGETS=gfx906 -DCMAKE_BUILD_TYPE=Release -DLLAMA_CURL=ON
&& cmake --build build-hip --config Release -j"$(nproc)"
```

#### 选项说明

- `HIPCXX="$(hipconfig -l)/clang"`：使用 ROCm 自带的 `hipclang` 作为 HIP 编译器。
- `HIP_PATH="$(hipconfig -R)"`：自动发现当前 ROCm 安装前缀（通常为 `/opt/rocm`）。
- `-DGGML_HIP=ON`：启用 ROCm/HIP 后端，使推理在 AMD GPU 上运行。
- `-DAMDGPU_TARGETS=$LLAMACPP_ROCM_ARCH`：指定要编译的 GPU 架构，本机设置为 `gfx906`。
- `-DCMAKE_BUILD_TYPE=Release`：生成优化后的 Release 构建。
- `-DLLAMA_CURL=ON`：启用 HTTP/HTTPS 支持（例如下载模型、通过 URL 加载资源）。
- `-j"$(nproc)"`：使用全部 CPU 核心并行编译。

编译完成后，所有可执行文件位于：

```bash
/home/zhengxueen/workspace/llama.cpp-rocm/build-hip
```

常见可执行文件包括：`llama-cli`、`llama-bench`、`llama-server` 等。

---

## 5. 在 MI50 上运行推理示例

以下以 `llama-server` 为例，展示如何在 MI50 上实际运行一个 GGUF 模型。你可以根据自己的模型路径和需求调整参数。

假设：

- 模型文件：`/mnt/ssd/models/gpt-oss-20b-mxfp4.gguf`
- 源码目录：`/home/zhengxueen/workspace/llama.cpp`

### 5.1 使用 HIP_VISIBLE_DEVICES 选择 GPU

```bash
cd /home/zhengxueen/workspace/llama.cpp

HIP_VISIBLE_DEVICES=0 \
./build-hip/bin/llama-server \
  -m /mnt/ssd/models/gpt-oss-20b-mxfp4.gguf \
  -c 0 \
  --n-gpu-layers -1 \
  --jinja \
  --host 0.0.0.0 \
  --threads 12 \
  --port 8080
# 如需覆盖 GFX 版本，可在命令前增加：
# HSA_OVERRIDE_GFX_VERSION=9.0.6 \
# Qwen3-VL-8B-Thinking-1M-Q4_K_M
HIP_VISIBLE_DEVICES=0 \
./build-hip/bin/llama-server \
  --model /mnt/ssd/models/Qwen3-VL-8B-Thinking-1M-Q4_K_M/Qwen3-VL-8B-Thinking-1M-Q4_K_M.gguf \
  --mmproj /mnt/ssd/models/Qwen3-VL-8B-Thinking-1M-Q4_K_M/mmproj-F16.gguf \
  --ctx-size 32768 \
  --n-gpu-layers -1 \
  --jinja \
  --flash-attn on \
  --top-p 0.95 \
  --top-k 20 \
  --temp 1.0 \
  --presence-penalty 0.0 \
  --host 0.0.0.0 \
  --threads 12 \
  --port 8081

# Qwen3-VL-8B-Thinking-1M-Q4_K_M
```

#### 使用 build-hip/llama-mtmd-cli 运行 Qwen3-VL Thinking（含视觉）

```bash
cd /mnt/sata/knowledge/notes/llama.cpp-rocm

HIP_VISIBLE_DEVICES=0 \
./build-hip/bin/llama-mtmd-cli \
  --model /mnt/ssd/models/Qwen3-VL-8B-Thinking-1M-Q4_K_M/Qwen3-VL-8B-Thinking-1M-Q4_K_M.gguf \
  --mmproj /mnt/ssd/models/Qwen3-VL-8B-Thinking-1M-Q4_K_M/mmproj-F16.gguf \
  --ctx-size 8192 \
  --n-gpu-layers 99 \
  --jinja \
  --flash-attn on \
  --top-p 0.95 \
  --top-k 20 \
  --temp 1.0 \
  --presence-penalty 0.0
# 如遇 GFX 版本错误，可在命令前增加：
# HSA_OVERRIDE_GFX_VERSION=9.0.6 \
cd /mnt/sata/knowledge/notes/llama.cpp-rocm

HIP_VISIBLE_DEVICES=0 \
./build-hip/bin/llama-server \
  --model /mnt/ssd/models/Qwen3VL-32B-Thinking-Q4_K_M.gguf \
  --mmproj /mnt/ssd/models/Qwen3-VL-8B-Thinking-1M-Q4_K_M/mmproj-F16.gguf \
  --ctx-size 32768 \
  --n-gpu-layers -1 \
  --jinja \
  --flash-attn on \
  --top-p 0.95 \
  --top-k 20 \
  --temp 1.0 \
  --presence-penalty 0.0 \
  --host 0.0.0.0 \
  --threads 12 \
  --port 8081
# 若遇到 GFX 版本提示，可在最前面加上一行：
# HSA_OVERRIDE_GFX_VERSION=9.0.6 \   Qwen3VL-32B-Thinking-Q4_K_M.gguf  Qwen3-VL-8B-Thinking-1M-Q4_K_M.gguf

HIP_VISIBLE_DEVICES=0 \
./build-hip/bin/llama-server \
  -m /mnt/ssd/models/gpt-oss-20b-mxfp4.gguf \
  -c 0 \
  --n-gpu-layers -1 \
  --jinja \
  --host 0.0.0.0 \
  --threads 12 \
  --port 8080
```

> 说明：
> 1. `--mmproj` 指向同一模型目录内的视觉投影权重；若目录结构不同，请相应调整路径。
> 2. 以上采样/推理参数参考 Unsloth 官方建议（Thinking 版：`top_p=0.95`、`temp=1.0`、`presence_penalty=0.0` 等）。
> 3. 进入 CLI 后可用 `/image <路径>` 载入图像，再输入文本问题进行多轮对话。

#### 环境变量说明

- `HIP_VISIBLE_DEVICES=0`：只使用第 0 块 AMD GPU（单卡 MI50 时一般就是这块）。
- `HSA_OVERRIDE_GFX_VERSION=9.0.6`：当 `rocminfo` 未正确识别 MI50 的 `gfx906` 时，可临时覆盖 GFX 版本；正常情况下可以保持注释状态，仅在出现 GFX 版本报错时启用。
- `ROCR_VISIBLE_DEVICES=0`：在存在多块 AMD GPU 时，限制 ROCm 只看到指定设备；一般仅使用 `HIP_VISIBLE_DEVICES` 即可，如需更细粒度控制可结合本变量。

#### 运行参数说明

- `-m ...`：指定 GGUF 模型路径。
- `-c 8192`：上下文长度（根据模型和显存可调整）。
- `--n-gpu-layers -1`：将所有可 offload 的层都放到 GPU 上（充分利用 MI50）。
- `--jinja`：启用 Jinja 模板支持（便于使用复杂 prompt 模板）。
- `--threads 12`：CPU 推理线程数，根据你的 CPU 核心数调整。
- `--host 127.0.0.1 --port 8080`：监听地址与端口。

### 5.2 使用 llama-cli 简单验证

如果只想快速验证 HIP 后端是否正常，也可以使用 `llama-cli` 进行一次简单对话：

```bash
cd /home/zhengxueen/workspace/llama.cpp

HIP_VISIBLE_DEVICES=0 \
./build/bin/llama-cli \
  -m /mnt/ssd/models/Qwen3VL-32B-Thinking-Q4_K_M.gguf \
  -c 4096 \
  --n-gpu-layers -1
# 如需覆盖 GFX 版本，可在命令前增加：
# HSA_OVERRIDE_GFX_VERSION=9.0.6 \
```

看到 GPU 有明显显存占用 / 算力使用（可通过 `rocm-smi` 观察），说明 ROCm/llama.cpp 已经在 MI50 上正确启用 HIP 后端。

---

## 6. 调试与性能建议（简要）

- **查看 GPU 使用情况**

  ```bash
  rocm-smi
  ```

  观察功耗、显存利用率，确认计算主要跑在 GPU 上。

- **减少/增大显存占用**

  - 调整模型量化等级（如 Q4 / Q5 / Q6）。
  - 通过 `--n-gpu-layers` 控制 offload 层数（0 表示全部在 CPU，-1 表示能放多少放多少）。

- **多 GPU（如果机器上不止一块 MI50）**

  - 通过 `HIP_VISIBLE_DEVICES=0,1` 选择多块 GPU；
  - 在 `llama.cpp` 的文档中查阅多 GPU 相关参数（如 tensor-parallel 配置）。

---

## 7. 与旧版 ROCm/llama.cpp 文档的关系

- 本文档现在针对的是 **官方 ggml-org/llama.cpp 仓库**，并在其基础上说明如何在 MI50 + ROCm 7.x 上启用 HIP：
  - 使用 `-DGGML_HIP=ON` 和 `-DAMDGPU_TARGETS=...`；
  - 使用 `LLAMACPP_ROCM_ARCH` 环境变量管理目标架构列表。
- 旧的 `llama.cpp-MI50-ROCm构建指南.md` 等文档中提到的 AMD ROCm fork（`ROCm/llama.cpp`）以及 hipBLAS / UMA 检测 / BF16 头文件等兼容性补丁，仅在使用旧版本或遇到类似问题时作为参考。
- 推荐以本文件为主流程，只有在需要排查历史问题或迁移旧环境时再查阅旧文档。

## 8. 常见问题与持久化部署（来自 MI50 实际排障经验，选摘）

### 8.1 文件权限与挂载选项

- **检查模型文件与可执行文件权限**（避免“权限不足”“无法执行”）：  
  ```bash
  ls -l /mnt/ssd/models/Qwen3VL-32B-Thinking-Q4_K_M.gguf
  ls -l /mnt/ssd/models
  ```
- **确保模型所在的 `/mnt/ssd` 支持执行权限（exec）**：  
  ```bash
  mount | grep /mnt/ssd
  # 如需临时启用 exec：
  sudo mount -o remount,exec /mnt/ssd
  ```
- 如果希望在开机时自动以可执行方式挂载 NTFS 盘，可在 `/etc/fstab` 中加入类似配置（请将 `UUID=` 替换成你自己磁盘的 UUID）：  
  ```fstab
  UUID=609ADBF79ADBC7A4 /mnt/ssd ntfs-3g defaults,auto,users,rw,exec,nofail 0 0
  ```

### 8.2 作为 systemd 服务持久化运行（示例）

下面示例展示如何将基于 HIP 的 `llama-server` 以 systemd 服务方式常驻运行，便于随系统启动自动拉起（路径和模型可按需调整）：  

```ini
# /etc/systemd/system/llama-server.service
[Unit]
Description=Llama.cpp Server (MI50 + ROCm HIP)
After=network.target

[Service]
User=your_username
WorkingDirectory=/mnt/sata/knowledge/notes/llama.cpp-rocm/build-hip/bin
Environment=HIP_VISIBLE_DEVICES=0
# 如遇 GFX 版本识别问题，可以按需启用下一行：
# Environment=HSA_OVERRIDE_GFX_VERSION=9.0.6
ExecStart=/mnt/sata/knowledge/notes/llama.cpp-rocm/build-hip/bin/llama-server \
  --model /mnt/ssd/models/Qwen3VL-32B-Thinking-Q4_K_M.gguf \
  --mmproj /mnt/ssd/models/mmproj-F16.gguf \
  --ctx-size 32768 \
  --n-gpu-layers -1 \
  --jinja \
  --flash-attn on \
  --top-p 0.95 \
  --top-k 20 \
  --temp 1.0 \
  --presence-penalty 0.0 \
  --host 0.0.0.0 \
  --threads 12 \
  --port 8081
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

启用与管理该服务：

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now llama-server.service
sudo systemctl status llama-server.service
```

> 以上 8.x 小节的内容来自你早期在 Ubuntu 22.04 + ROCm 5.x 环境下的 MI50 部署实践，已经过抽象和更新，适用于当前基于官方 llama.cpp + ROCm 7.x 的环境，仅作“进阶排障与运维”参考。
