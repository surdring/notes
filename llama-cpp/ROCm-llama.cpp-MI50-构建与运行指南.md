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
