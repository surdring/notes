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
HIPCXX="$(hipconfig -l)/clang" HIP_PATH="$(hipconfig -R)" cmake -S . -B build-hip -DGGML_HIP=ON -DAMDGPU_TARGETS=gfx906 -DCMAKE_BUILD_TYPE=Release -DLLAMA_CURL=ON && cmake --build build-hip --config Release -j"$(nproc)"
```

#### 选项说明

- `HIPCXX="$(hipconfig -l)/clang"`：使用 ROCm 自带的 `hipclang` 作为 HIP 编译器。
- `HIP_PATH="$(hipconfig -R)"`：自动发现当前 ROCm 安装前缀（通常为 `/opt/rocm`）。
- `-DGGML_HIP=ON`：启用 ROCm/HIP 后端，使推理在 AMD GPU 上运行。
- `-DAMDGPU_TARGETS=$LLAMACPP_ROCM_ARCH`：指定要编译的 GPU 架构，本机设置为 `gfx906`。
- `-DCMAKE_BUILD_TYPE=Release`：生成优化后的 Release 构建。
- `-DLLAMA_CURL=ON`：启用 HTTP/HTTPS 支持（例如下载模型、通过 URL 加载资源）。
- `-j"$(nproc)"`：使用全部 CPU 核心并行编译。


常见可执行文件包括：`llama-cli`、`llama-bench`、`llama-server` 等。



# 源码更新、重新编译到最终运行 Ministral-3-14B 模型
---

### 第一步：更新 llama.cpp 源代码

为了支持 `Ministral-3` 架构，必须将代码更新到最新版本。

1.  **进入源代码目录**
    请修改为你的实际路径：
    ```bash
    cd /home/zhengxueen/workspace/llama.cpp
    ```

2.  **清理旧的编译文件 (非常重要)**
    为了防止缓存冲突，建议先删除旧的构建目录：
    ```bash
    rm -rf build-hip
    ```

3.  **拉取最新代码**
    ```bash
    git checkout master
    git pull origin master
    ```

4.  **更新子模块 (关键步骤)**
    llama.cpp 依赖许多第三方库（如 ggml），必须同步更新：
    ```bash
    git submodule update --init --recursive
    ```

---

### 第二步：编译 llama.cpp (同上)


---

### 第三步：运行 Ministral-3-14B 模型

现在使用的是新版程序，它能够识别 `mistral3` 架构。

```bash
HIP_VISIBLE_DEVICES=0 \
./build-hip/bin/llama-server \
  --model /mnt/ssd/models/Ministral-3-14B/Ministral-3-14B-Reasoning-2512-Q4_K_M.gguf \
  --mmproj /mnt/ssd/models/Ministral-3-14B/mmproj-F16.gguf \
  --ctx-size 32684 \
  --n-gpu-layers -1 \
  --jinja \
  --flash-attn on \
  --top-p 0.95 \
  --temp 0.7 \
  --host 0.0.0.0 \
  --threads 12 \
  --port 8082
```

**参数微调建议：**
1.  **`--n-gpu-layers 999`**:  
    你之前设置为 `-1` (自动)，但有时手动设置为一个大数字（如 999）能强制让所有层都加载到显卡上（前提是显存足够）。你的日志显示有 32GB 显存，跑 14B Q4 量化模型（约 9GB）绰绰有余。
2.  **`--ctx-size 32768`**:
    Ministral 支持 128k 上下文，但考虑到显存和速度，32k 是一个很好的平衡点。

---

### 第四步：测试视觉功能 (可选)

由于你加载了 `--mmproj`，你可以测试一下它的看图能力。

使用 `curl` 发送一张图片进行测试（假设服务器在本地）：

```bash
curl http://localhost:8082/completion \
    -H "Content-Type: application/json" \
    -d '{
        "prompt": "User: <image>\nDescribe this image.\nAssistant:",
        "image_data": [{"data": "<BASE64_STRING_OF_YOUR_IMAGE>", "id": 10}],
        "n_predict": 100
    }'
```
*(注意：你需要将图片转换为 Base64 字符串填入)*

或者直接使用支持 OpenAI 格式的客户端（如 Chatbox, Cherry Studio），将 API 地址设置为 `http://localhost:8082/v1`，并在聊天界面上传图片即可。
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
  --port 8080 \
  --alias gpt-oss-20b
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
  --port 8081

# unslothQwen3-VL-32B-Thinking-1M-GGUF/Qwen3-VL-32B-Thinking-1M-Q4_K_M.gguf
HIP_VISIBLE_DEVICES=0 \
./build-hip/bin/llama-server \
  --model /mnt/ssd/models/unslothQwen3-VL-32B-Thinking-1M-GGUF/Qwen3-VL-32B-Thinking-1M-Q4_K_M.gguf \
  --mmproj /mnt/ssd/models/unslothQwen3-VL-32B-Thinking-1M-GGUF/mmproj-F16.gguf \
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
  --port 8082
  
  
# Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf
HIP_VISIBLE_DEVICES=0 \
./build-hip/bin/llama-server \
  --model /mnt/ssd/models/Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf \
  --ctx-size 32684 \
  --n-gpu-layers -1 \
  --jinja \
  --flash-attn on \
  --top-p 0.8 \
  --top-k 20 \
  --temp 0.7 \
  --presence-penalty 0.0 \
  --host 0.0.0.0 \
  --threads -1 \
  --repeat-penalty 1.05 \
  --port 8080
  --alias Qwen3-Coder-30B-A3B
  
  
  
# 多模态模型（chandra-ocr）
cd /home/zhengxueen/workspace/llama.cpp

HIP_VISIBLE_DEVICES=0 \
./build-hip/bin/llama-server \
  --model /mnt/ssd/models/chandra-ocr/chandra-Q4_K_M.gguf \
  --mmproj /mnt/ssd/models/chandra-ocr/chandra-mmproj-f16.gguf\
  --ctx-size 51200\
  --n-gpu-layers -1 \
  --jinja \
  --flash-attn on \
  --presence-penalty 0.0 \
  --host 0.0.0.0 \
  --port 8082 \
  --alias chandra-ocr

HIP_VISIBLE_DEVICES=0 \
./build-hip/bin/llama-server \
  --model /mnt/ssd/models/chandra-ocr/chandra-F16.gguf \
  --mmproj /mnt/ssd/models/chandra-ocr/chandra-mmproj-f16.gguf\
  --ctx-size 32684\
  --n-gpu-layers -1 \
  --jinja \
  --flash-attn on \
  --presence-penalty 0.0 \
  --host 0.0.0.0 \
  --port 8080 \
  --alias chandra-ocr
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

> 以上 8.x 小节的内容来自你早期在 Ubuntu 22.04 + ROCm 5.x 环境下的 MI50 部署实践，已经过抽象和更新，适用于当前基于官方 llama.cpp + ROCm 7.x 的环境，仅作"进阶排障与运维"参考。

---

## 9. 在 MI50 上构建 buun-llama-cpp（TCQ KV Cache 压缩）

[buun-llama-cpp](https://github.com/spiritbuun/buun-llama-cpp) 是 llama.cpp 的实验性 fork，核心特性是 **Trellis-Coded Quantization (TCQ)** 用于 KV cache 压缩，可在相同 VRAM 下获得 2-7 倍的上下文长度，质量接近甚至优于 FP16。

> **注意**：buun-llama-cpp 的 TCQ 功能目前主要针对 CUDA 后端优化，HIP/ROCm 后端的 TCQ 支持可能有限。构建前请确认目标功能在 ROCm 上的可用性。

### 9.1 获取 buun-llama-cpp 源码

```bash
mkdir -p ~/workspace && cd ~/workspace

git clone https://github.com/spiritbuun/buun-llama-cpp
cd buun-llama-cpp
```

### 9.2 配置与构建

在 MI50 上构建时，推荐结合 `hipconfig` 自动探测路径（可移植性更好）与 buun-llama-cpp README 中的选项：

```bash
# 为 MI50 设置架构
export LLAMACPP_ROCM_ARCH=gfx906

# 配置（使用 hipconfig 自动探测编译器路径）
HIPCXX="$(hipconfig -l)/clang" HIP_PATH="$(hipconfig -R)" \
cmake -B build-hip \
  -DGGML_HIP=ON \
  -DAMDGPU_TARGETS=gfx906 \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLAMA_BUILD_SERVER=ON \
  -DLLAMA_CURL=ON

# 编译
cmake --build build-hip -j$(nproc)
```

#### 与上游 llama.cpp 构建命令的差异

| 选项 | 上游 llama.cpp | buun-llama-cpp |
|------|---------------|----------------|
| 编译器指定 | `HIPCXX` + `HIP_PATH` 环境变量 | README 中硬编码 `amdclang` 路径；MI50 上推荐仍用 `hipconfig` 自动探测 |
| `-DLLAMA_BUILD_SERVER` | 未设置 | `ON`（显式编译 llama-server） |
| `-DLLAMA_CURL` | `ON` | 可选加入，启用 HTTP 支持 |
| 构建目录 | `build-hip` | `build-hip` |

> **编译器选择说明**：buun-llama-cpp README 使用 `-DCMAKE_C_COMPILER=/opt/rocm/bin/amdclang` 硬编码路径，简单直接但换环境需手动修改。对于 MI50 环境，推荐沿用 `hipconfig` 自动探测方式，可移植性更好。

### 9.3 使用 TCQ KV Cache 运行推理

构建完成后，在原有部署命令基础上添加 `-ctk` / `-ctv` 参数即可启用 TCQ KV cache 压缩。以下以 Qwen3.6-35B-A3B 为例：

#### turbo4（4.25 bpv）—— 推荐默认，几乎无损

```bash
cd /home/zhengxueen/workspace/buun-llama-cpp
```

```bash
env -u HSA_VISIBLE_DEVICES -u ROCR_VISIBLE_DEVICES -u CUDA_VISIBLE_DEVICES \
HIP_VISIBLE_DEVICES=0 \
./build-hip/bin/llama-server \
  --model /mnt/ssd/models/Qwen3.6-35B-A3B/huihui-qwen3.6-35b-a3b-claude-4.7-opus-abliterated-q5_k_m.gguf \
  --mmproj /mnt/ssd/models/Qwen3.6-35B-A3B/mmproj-BF16.gguf \
  --ctx-size 131072 \
  -ngl 999 -cram 0 -np 1 \
  -ctk turbo4 -ctv turbo4 \
  --jinja \
  --flash-attn on \
  --threads 8 \
  --temperature 0.7 \
  --top-p 0.8 \
  --top-k 20 \
  --host 0.0.0.0 \
  --min-p 0.00 \
  --port 8080 \
  --no-mmap \
  --presence-penalty 1.5 \
  --repeat-penalty 1.0 \
  --alias Qwen3.6-35B-A3B \
  --log-disable
```

```bash
env -u HSA_VISIBLE_DEVICES -u ROCR_VISIBLE_DEVICES -u CUDA_VISIBLE_DEVICES \
HIP_VISIBLE_DEVICES=0 \
./build-hip/bin/llama-server \
  --model /mnt/ssd/models/Qwen3.6-27B/Abiray-Huihui-Qwen3.6-27B-abliterated-Q8_0.gguf \
  --ctx-size 65536 \
  -ngl 999 -cram 0 -np 1 \
  -ctk turbo4 -ctv turbo4 \
  --jinja \
  --flash-attn on \
  --threads 8 \
  --temperature 0.7 \
  --top-p 0.8 \
  --top-k 20 \
  --host 0.0.0.0 \
  --min-p 0.00 \
  --port 8080 \
  --no-mmap \
  --presence-penalty 1.5 \
  --repeat-penalty 1.0 \
  --alias Qwen3.6-27B \
  --log-disable
```
#### 3-bit TCQ（3.25 bpv）—— 短上下文质量优于 FP16，~5x KV cache 压缩

```bash
env -u HSA_VISIBLE_DEVICES -u ROCR_VISIBLE_DEVICES -u CUDA_VISIBLE_DEVICES \
HIP_VISIBLE_DEVICES=0 \
./build-hip/bin/llama-server \
  --model /mnt/ssd/models/Qwen3.6-35B-A3B/huihui-qwen3.6-35b-a3b-claude-4.7-opus-abliterated-q5_k_m.gguf \
  --mmproj /mnt/ssd/models/Qwen3.6-35B-A3B/mmproj-BF16.gguf \
  --ctx-size 131072 \
  -ngl 999 -cram 0 -np 1 \
  -ctk turbo3_tcq -ctv turbo3_tcq \
  --jinja \
  --flash-attn on \
  --threads 8 \
  --temperature 0.7 \
  --top-p 0.8 \
  --top-k 20 \
  --host 0.0.0.0 \
  --min-p 0.00 \
  --port 8080 \
  --no-mmap \
  --presence-penalty 1.5 \
  --repeat-penalty 1.0 \
  --alias Qwen3.6-35B-A3B \
  --log-disable
```

#### 2-bit TCQ（2.25 bpv）—— 最大压缩，~7x KV cache 压缩，适合极限长上下文

```bash
env -u HSA_VISIBLE_DEVICES -u ROCR_VISIBLE_DEVICES -u CUDA_VISIBLE_DEVICES \
HIP_VISIBLE_DEVICES=0 \
./build-hip/bin/llama-server \
  --model /mnt/ssd/models/Qwen3.6-35B-A3B/huihui-qwen3.6-35b-a3b-claude-4.7-opus-abliterated-q5_k_m.gguf \
  --mmproj /mnt/ssd/models/Qwen3.6-35B-A3B/mmproj-BF16.gguf \
  --ctx-size 131072 \
  -ngl 999 -cram 0 -np 1 \
  -ctk turbo2_tcq -ctv turbo2_tcq \
  --jinja \
  --flash-attn on \
  --threads 8 \
  --temperature 0.7 \
  --top-p 0.8 \
  --top-k 20 \
  --host 0.0.0.0 \
  --min-p 0.00 \
  --port 8080 \
  --no-mmap \
  --presence-penalty 1.5 \
  --repeat-penalty 1.0 \
  --alias Qwen3.6-35B-A3B \
  --log-disable
```

#### 非对称 2.75 bpv —— 3-bit K + 2-bit V，最佳 2-bit 质量

```bash
env -u HSA_VISIBLE_DEVICES -u ROCR_VISIBLE_DEVICES -u CUDA_VISIBLE_DEVICES \
HIP_VISIBLE_DEVICES=0 \
./build-hip/bin/llama-server \
  --model /mnt/ssd/models/Qwen3.6-35B-A3B/huihui-qwen3.6-35b-a3b-claude-4.7-opus-abliterated-q5_k_m.gguf \
  --mmproj /mnt/ssd/models/Qwen3.6-35B-A3B/mmproj-BF16.gguf \
  --ctx-size 131072 \
  -ngl 999 -cram 0 -np 1 \
  -ctk turbo3_tcq -ctv turbo2_tcq \
  --jinja \
  --flash-attn on \
  --threads 8 \
  --temperature 0.7 \
  --top-p 0.8 \
  --top-k 20 \
  --host 0.0.0.0 \
  --min-p 0.00 \
  --port 8080 \
  --no-mmap \
  --presence-penalty 1.5 \
  --repeat-penalty 1.0 \
  --alias Qwen3.6-35B-A3B \
  --log-disable
```

### 9.4 TCQ 参数说明

- **`-ctk`**：KV cache 中 Key 的量化类型
- **`-ctv`**：KV cache 中 Value 的量化类型
- **`-fa`**：启用 Flash Attention（TCQ 推荐开启）
- **`-ngl 99`**：将所有层 offload 到 GPU（等同于 `--n-gpu-layers -1`）

### 9.5 MI50 上的注意事项

- MI50（gfx906）为 Vega20 架构，32GB HBM2 显存，TCQ 压缩在显存受限场景下收益最大
- MI50 不支持 BF16 数据类型，如遇 BF16 相关编译错误，可能需要额外补丁
- TCQ 的 CUDA kernel 可能尚未完全适配 HIP 后端，如遇编译失败，可先尝试不带 TCQ 的标量量化模式（`turbo3` / `turbo2`）
- 如遇 GFX 版本识别问题，添加 `HSA_OVERRIDE_GFX_VERSION=9.0.6`

---

## 10. 双 MI50/Pro VII 构建 buun-llama-cpp

> 本节基于双卡环境：GPU[0] = MI50 16GB (card0, PCI 08:00.0)，GPU[1] = Radeon Pro VII 32GB (card1, PCI 05:00.0)，均为 `gfx906`。详见 [双卡GPU信息与配置记录](../rocm/双卡GPU信息与配置记录.md)。

### 10.1 双卡环境特点

| 属性 | GPU[0] | GPU[1] |
|---|---|---|
| 型号 | MI50 16GB | Radeon Pro VII 32GB |
| VRAM | ~16 GiB | ~32 GiB |
| GFX | gfx906 | gfx906 |
| `HIP_VISIBLE_DEVICES` | 0 | 1 |
| sysfs | card0 | card1 |

**总可用 VRAM**：~48 GiB（16 + 32）

> **关键约束**：两张卡 VRAM 不对称（16:32 = 1:2），多 GPU 推理时必须通过 `-ts` 指定 tensor split 比例，否则默认均分会浪费 32GB 卡的显存。

### 10.2 获取与构建 buun-llama-cpp（双卡版）

buun-llama-cpp 的 ROCm/HIP 构建官方仅在 RDNA3 (gfx1100) 上测试过，gfx906 构建可能需要额外调整。

```bash
mkdir -p ~/workspace && cd ~/workspace

# 克隆 buun-llama-cpp
git clone https://github.com/spiritbuun/buun-llama-cpp
cd buun-llama-cpp
git submodule update --init --recursive

# 为双卡 gfx906 设置架构
export LLAMACPP_ROCM_ARCH=gfx906

# 配置（使用 hipconfig 自动探测，而非 README 中硬编码的 amdclang 路径）
HIPCXX="$(hipconfig -l)/clang" HIP_PATH="$(hipconfig -R)" \
cmake -B build-hip \
  -DGGML_HIP=ON \
  -DAMDGPU_TARGETS=gfx906 \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLAMA_BUILD_SERVER=ON \
  -DLLAMA_CURL=ON

# 编译
cmake --build build-hip -j$(nproc)
```

> **注意**：buun-llama-cpp 的 TCQ kernel 主要针对 CUDA 优化。HIP 后端编译可能遇到 TCQ 专用 kernel 不兼容的问题。如遇编译失败，可先尝试标量量化模式（`turbo3` / `turbo2`，不含 `_tcq` 后缀），这些不依赖 TCQ 专用 kernel。

### 10.3 双卡 llama-server 关键参数

llama-server 提供以下多 GPU 参数（参考 [官方 server 文档](https://github.com/ggml-org/llama.cpp/tree/master/tools/server)）：

| 参数 | 说明 | 双卡推荐值 |
|---|---|---|
| `-sm, --split-mode {none,layer,row}` | 多 GPU 分割模式 | `row`（tensor 并行，适合推理）或 `layer`（层分割） |
| `-ts, --tensor-split N0,N1,...` | 各 GPU 的 tensor 分配比例 | `1,2`（对应 16GB:32GB = 1:2） |
| `-mg, --main-gpu INDEX` | 主 GPU 索引 | `1`（32GB 卡为主，承担更多计算） |
| `-ngl, --gpu-layers N` | GPU offload 层数 | `999`（全部 offload） |
| `-dev, --device <dev1,dev2,..>` | 指定设备 | `hip:0,hip:1` |
| `-fa, --flash-attn` | Flash Attention | `on`（TCQ 推荐开启） |
| `-ctk, --cache-type-k` | KV cache Key 量化类型 | `turbo4`（默认推荐） |
| `-ctv, --cache-type-v` | KV cache Value 量化类型 | `turbo4`（默认推荐） |
| `-cram, --cache-ram N` | 固定大小 RAM 缓存 | `0`（全放 VRAM） |
| `-np, --parallel N` | 并行序列数 | `1`（双卡推理建议从 1 开始） |

> **split-mode 说明**：
> - `layer`：按层分割，不同 GPU 负责不同层。简单但层间通信开销较大。
> - `row`：按行分割（tensor parallelism），同一层的矩阵按行切到不同 GPU。通信更高效，推荐用于双卡推理。
> - `none`：不分割，仅使用单卡。

### 10.4 双卡运行示例

#### turbo4（4.25 bpv）—— 推荐默认，几乎无损

```bash
cd /home/zhengxueen/workspace/buun-llama-cpp

env -u HSA_VISIBLE_DEVICES -u ROCR_VISIBLE_DEVICES -u CUDA_VISIBLE_DEVICES \
HIP_VISIBLE_DEVICES=0,1 \
./build-hip/bin/llama-server \
  --model /mnt/ssd/models/Qwen3.6-35B-A3B/huihui-qwen3.6-35b-a3b-claude-4.7-opus-abliterated-q5_k_m.gguf \
  --mmproj /mnt/ssd/models/Qwen3.6-35B-A3B/mmproj-BF16.gguf \
  --ctx-size 131072 \
  -ngl 999 -cram 0 -np 1 \
  -sm row -ts 1,2 -mg 1 \
  -ctk turbo4 -ctv turbo4 \
  --jinja \
  --flash-attn on \
  --threads 8 \
  --temperature 0.7 \
  --top-p 0.8 \
  --top-k 20 \
  --host 0.0.0.0 \
  --min-p 0.00 \
  --port 8080 \
  --no-mmap \
  --presence-penalty 1.5 \
  --repeat-penalty 1.0 \
  --alias Qwen3.6-35B-A3B-dual \
  --log-disable
```

#### 3-bit TCQ（3.25 bpv）—— 短上下文质量优于 FP16，~5x KV cache 压缩

```bash
cd /home/zhengxueen/workspace/buun-llama-cpp

env -u HSA_VISIBLE_DEVICES -u ROCR_VISIBLE_DEVICES -u CUDA_VISIBLE_DEVICES \
HIP_VISIBLE_DEVICES=0,1 \
./build-hip/bin/llama-server \
  --model /mnt/ssd/models/Qwen3.6-35B-A3B/huihui-qwen3.6-35b-a3b-claude-4.7-opus-abliterated-q5_k_m.gguf \
  --mmproj /mnt/ssd/models/Qwen3.6-35B-A3B/mmproj-BF16.gguf \
  --ctx-size 131072 \
  -ngl 999 -cram 0 -np 1 \
  -sm row -ts 1,2 -mg 1 \
  -ctk turbo3_tcq -ctv turbo3_tcq \
  --jinja \
  --flash-attn on \
  --threads 8 \
  --temperature 0.7 \
  --top-p 0.8 \
  --top-k 20 \
  --host 0.0.0.0 \
  --min-p 0.00 \
  --port 8080 \
  --no-mmap \
  --presence-penalty 1.5 \
  --repeat-penalty 1.0 \
  --alias Qwen3.6-35B-A3B-dual \
  --log-disable
```

#### 2-bit TCQ（2.25 bpv）—— 最大压缩，适合极限长上下文

```bash
cd /home/zhengxueen/workspace/buun-llama-cpp

env -u HSA_VISIBLE_DEVICES -u ROCR_VISIBLE_DEVICES -u CUDA_VISIBLE_DEVICES \
HIP_VISIBLE_DEVICES=0,1 \
./build-hip/bin/llama-server \
  --model /mnt/ssd/models/Qwen3.6-35B-A3B/huihui-qwen3.6-35b-a3b-claude-4.7-opus-abliterated-q5_k_m.gguf \
  --mmproj /mnt/ssd/models/Qwen3.6-35B-A3B/mmproj-BF16.gguf \
  --ctx-size 131072 \
  -ngl 999 -cram 0 -np 1 \
  -sm row -ts 1,2 -mg 1 \
  -ctk turbo2_tcq -ctv turbo2_tcq \
  --jinja \
  --flash-attn on \
  --threads 8 \
  --temperature 0.7 \
  --top-p 0.8 \
  --top-k 20 \
  --host 0.0.0.0 \
  --min-p 0.00 \
  --port 8080 \
  --no-mmap \
  --presence-penalty 1.5 \
  --repeat-penalty 1.0 \
  --alias Qwen3.6-35B-A3B-dual \
  --log-disable
```

#### 非对称 2.75 bpv —— 3-bit K + 2-bit V，最佳 2-bit 质量

```bash
cd /home/zhengxueen/workspace/buun-llama-cpp

env -u HSA_VISIBLE_DEVICES -u ROCR_VISIBLE_DEVICES -u CUDA_VISIBLE_DEVICES \
HIP_VISIBLE_DEVICES=0,1 \
./build-hip/bin/llama-server \
  --model /mnt/ssd/models/Qwen3.6-35B-A3B/huihui-qwen3.6-35b-a3b-claude-4.7-opliterated-q5_k_m.gguf \
  --mmproj /mnt/ssd/models/Qwen3.6-35B-A3B/mmproj-BF16.gguf \
  --ctx-size 131072 \
  -ngl 999 -cram 0 -np 1 \
  -sm row -ts 1,2 -mg 1 \
  -ctk turbo3_tcq -ctv turbo2_tcq \
  --jinja \
  --flash-attn on \
  --threads 8 \
  --temperature 0.7 \
  --top-p 0.8 \
  --top-k 20 \
  --host 0.0.0.0 \
  --min-p 0.00 \
  --port 8080 \
  --no-mmap \
  --presence-penalty 1.5 \
  --repeat-penalty 1.0 \
  --alias Qwen3.6-35B-A3B-dual \
  --log-disable
```

#### 标量量化（无 TCQ）—— 如 TCQ kernel 在 HIP 上编译失败的后备方案

```bash
cd /home/zhengxueen/workspace/buun-llama-cpp

env -u HSA_VISIBLE_DEVICES -u ROCR_VISIBLE_DEVICES -u CUDA_VISIBLE_DEVICES \
HIP_VISIBLE_DEVICES=0,1 \
./build-hip/bin/llama-server \
  --model /mnt/ssd/models/Qwen3.6-35B-A3B/huihui-qwen3.6-35b-a3b-claude-4.7-opliterated-q5_k_m.gguf \
  --ctx-size 131072 \
  -ngl 999 -cram 0 -np 1 \
  -sm row -ts 1,2 -mg 1 \
  -ctk turbo3 -ctv turbo3 \
  --jinja \
  --flash-attn on \
  --threads 8 \
  --temperature 0.7 \
  --top-p 0.8 \
  --top-k 20 \
  --host 0.0.0.0 \
  --min-p 0.00 \
  --port 8080 \
  --no-mmap \
  --presence-penalty 1.5 \
  --repeat-penalty 1.0 \
  --alias Qwen3.6-35B-A3B-dual \
  --log-disable
```

### 10.5 VRAM 预算与 TCQ 上下文长度估算

双卡总 VRAM ~48 GiB，扣除系统开销后可用约 45 GiB。

| 模型大小 (Q4/Q5) | 模型占用 | 剩余 VRAM | turbo4 可用 ctx | turbo3_tcq 可用 ctx | turbo2_tcq 可用 ctx |
|---|---|---|---|---|---|
| ~10 GiB (14B Q4) | ~10 GiB | ~35 GiB | ~90K | ~120K | ~170K |
| ~20 GiB (35B Q5) | ~20 GiB | ~25 GiB | ~65K | ~85K | ~120K |
| ~30 GiB (70B Q4) | ~30 GiB | ~15 GiB | ~40K | ~50K | ~70K |

> 估算基于：turbo4 ≈ 3.8x 压缩，turbo3_tcq ≈ 5x 压缩，turbo2_tcq ≈ 7x 压缩（相对 FP16 KV cache）。实际可用上下文长度取决于模型 head_dim、层数等参数，以上仅为粗略参考。

### 10.6 双卡注意事项

1. **VRAM 不对称**：必须用 `-ts 1,2` 按 1:2 比例分配 tensor，否则默认均分会导致 16GB 卡 OOM
2. **主 GPU 选择**：建议 `-mg 1`（32GB 卡为主），主 GPU 承担更多计算和 KV cache 管理
3. **split-mode 选择**：`row` 比 `layer` 通信效率更高，推荐双卡推理使用
4. **TCQ + HIP 兼容性**：buun-llama-cpp 的 TCQ kernel 官方仅在 CUDA (RTX 3090) 和 ROCm RDNA3 (gfx1100) 上测试。gfx906 上可能需要降级到标量量化（`turbo3` / `turbo2`）
5. **锁频与限功耗**：双卡推理时两张卡均有负载，务必确认 [双卡锁频服务](../rocm/双卡GPU信息与配置记录.md#6-systemd-服务双卡版) 已启用，防止温度尖峰导致掉卡
6. **GFX 版本**：如遇 GFX 版本识别问题，添加 `HSA_OVERRIDE_GFX_VERSION=9.0.6`
7. **MI50 不支持 BF16**：如模型 mmproj 使用 BF16 格式，可能需要额外补丁或使用 F16 版本

### 10.7 双卡 Systemd 服务示例

```ini
# ~/.config/systemd/user/llama-server-dual.service
[Unit]
Description=Llama.cpp Server (Dual GPU: MI50 16GB + Pro VII 32GB)
After=network.target

[Service]
Type=simple
WorkingDirectory=/home/zhengxueen/workspace/buun-llama-cpp
Environment="HIP_VISIBLE_DEVICES=0,1"
ExecStart=/home/zhengxueen/workspace/buun-llama-cpp/build-hip/bin/llama-server \
  --model /mnt/ssd/models/Qwen3.6-35B-A3B/huihui-qwen3.6-35b-a3b-claude-4.7-opliterated-q5_k_m.gguf \
  --mmproj /mnt/ssd/models/Qwen3.6-35B-A3B/mmproj-BF16.gguf \
  --ctx-size 131072 \
  -ngl 999 -cram 0 -np 1 \
  -sm row -ts 1,2 -mg 1 \
  -ctk turbo4 -ctv turbo4 \
  --jinja \
  --flash-attn on \
  --threads 8 \
  --temperature 0.7 \
  --top-p 0.8 \
  --top-k 20 \
  --host 0.0.0.0 \
  --min-p 0.00 \
  --port 8080 \
  --no-mmap \
  --presence-penalty 1.5 \
  --repeat-penalty 1.0 \
  --alias Qwen3.6-35B-A3B-dual \
  --log-disable
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
```

启用与管理：
```bash
systemctl --user daemon-reload
systemctl --user enable --now llama-server-dual.service
systemctl --user status llama-server-dual.service
```

### 10.8 验证双卡是否生效

```bash
# 启动后观察两张卡的 VRAM 使用
rocm-smi --showmeminfo vram

# 两张卡都应有显著的 VRAM 占用（而非只有一张）
# GPU[0] 应占约 1/3，GPU[1] 应占约 2/3（对应 -ts 1,2）

# 实时监控温度与功耗
watch -n 2 rocm-smi

# 检查服务日志
journalctl --user -u llama-server-dual.service -f
```

---

## 11. ngram-mod 投机解码加速

> llama.cpp 原生支持多种投机解码方案，其中 **ngram-mod** 是最适合 MoE 模型（如 Qwen3.6-35B-A3B）的无额外模型加速方案。
> 它通过轻量哈希池（~16 MB）记录 n-gram → next token 映射，跨 slot 共享，在推理/总结/代码重写等场景下可显著提升 token 吞吐。

### 11.1 原理简述

- 对每个 n-gram 计算一个 LCG 哈希
- 对每个哈希值存储其下一个 token
- 推理时，滚动计算最近 n 个 token 的哈希，从哈希池中取出候选 token 作为草稿
- 主模型批量验证草稿 token，接受正确的、拒绝错误的

**特点**：
- 常量内存（~16 MB），不随上下文增长
- 不需要额外的小模型（Draft Model）
- 跨 slot 共享哈希池，不同请求可互相受益
- 可生成变长草稿（m 不固定）

### 11.2 单卡启动示例

```bash
HIP_VISIBLE_DEVICES=1 \
./build-hip/bin/llama-server \
  --model /mnt/ssd/models/Qwen3.6-35B-A3B/huihui-qwen3.6-35b-a3b-claude-4.7-opus-abliterated-q5_k_m.gguf \
  --mmproj /mnt/ssd/models/Qwen3.6-35B-A3B/mmproj-BF16.gguf \
  --ctx-size 131072 \
  -ngl 999 -cram 0 -np 1 \
  -ctk turbo3_tcq -ctv turbo3_tcq \
  --spec-type ngram-mod \
  --spec-ngram-size-n 24 \
  --draft-min 48 \
  --draft-max 64 \
  --jinja \
  --flash-attn on \
  --threads 8 \
  --temperature 0.7 \
  --top-p 0.8 \
  --top-k 20 \
  --host 0.0.0.0 \
  --port 8080 \
  --no-mmap \
  --presence-penalty 1.5 \
  --repeat-penalty 1.0 \
  --alias Qwen3.6-35B-A3B-ngram-mod \
  --log-disable
```

### 11.3 双卡启动示例

```bash
cd /home/zhengxueen/workspace/buun-llama-cpp

env -u HSA_VISIBLE_DEVICES -u ROCR_VISIBLE_DEVICES -u CUDA_VISIBLE_DEVICES \
HIP_VISIBLE_DEVICES=0,1 \
./build-hip/bin/llama-server \
  --model /mnt/ssd/models/Qwen3.6-35B-A3B/huihui-qwen3.6-35b-a3b-claude-4.7-opus-abliterated-q5_k_m.gguf \
  --mmproj /mnt/ssd/models/Qwen3.6-35B-A3B/mmproj-BF16.gguf \
  --ctx-size 131072 \
  -ngl 999 -cram 0 -np 1 \
  -sm row -ts 1,2 -mg 1 \
  -ctk turbo3_tcq -ctv turbo3_tcq \
  --spec-type ngram-mod \
  --spec-ngram-size-n 24 \
  --draft-min 48 \
  --draft-max 64 \
  --jinja \
  --flash-attn on \
  --threads 8 \
  --temperature 0.7 \
  --top-p 0.8 \
  --top-k 20 \
  --host 0.0.0.0 \
  --min-p 0.00 \
  --port 8080 \
  --no-mmap \
  --presence-penalty 1.5 \
  --repeat-penalty 1.0 \
  --alias Qwen3.6-35B-A3B-dual-ngram-mod \
  --log-disable
```

### 11.4 参数调优建议

| 参数 | 推荐值 | 说明 |
|---|---|---|
| `--spec-type` | `ngram-mod` | 投机解码类型，MoE 模型首选 |
| `--spec-ngram-size-n` | `24` | n-gram 长度，过小容易误匹配，推荐 16–32 |
| `--draft-min` | `48` | 最少草稿 token 数，MoE 需要较长草稿才能有效加速 |
| `--draft-max` | `64` | 最大草稿 token 数，越大潜在加速越高但验证成本也越高 |

**调优思路**：
- **n 值**：代码/结构化文本用较大值（24–32），自然语言对话可用较小值（12–16）
- **draft 范围**：MoE 模型单 token 计算快但 batch 不友好，建议 `--draft-min 48 --draft-max 64`；密集模型可降低到 `--draft-min 16 --draft-max 32`
- **观察接受率**：启动后通过日志观察草稿接受率，接受率 > 70% 说明参数合理，< 30% 则需减小 draft 范围或增大 n

### 11.5 其他投机解码方案对比

llama.cpp 还支持以下方案（通过 `--spec-type` 选择）：

| 方案 | 需要额外模型 | 内存开销 | 适合场景 |
|---|---|---|---|
| `draft` | ✅ 需要小模型 | 大（加载两个模型） | 通用，有合适小模型时 |
| `ngram-cache` | ❌ | 中 | 有外部统计文件 |
| `ngram-simple` | ❌ | 小 | 简单场景，最小开销 |
| `ngram-map-k` | ❌ | 小 | 有重复模式的文本 |
| `ngram-map-k4v` | ❌ | 小 | 长重复文本（实验性） |
| **`ngram-mod`** | ❌ | **~16 MB** | **MoE / 推理 / 总结 / 代码** |

> **注意**：Qwen3.5/3.6 的 MTP（Multi-Token Prediction）是模型架构内置的预测头，目前仅 vLLM 和 SGLang 支持，llama.cpp 尚未实现。在 llama.cpp 上，ngram-mod 是最接近 MTP 加速效果的替代方案。
