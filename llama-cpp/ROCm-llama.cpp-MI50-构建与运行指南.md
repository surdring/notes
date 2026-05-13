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

这里直接采用 llama.cpp 官方 build.md 中的 HIP 构建命令，将 `GPU_TARGETS` 固定为 MI50 的 `gfx906`。

### 4.1 配置与构建

在 `llama.cpp` 源码根目录下执行：

```bash
# 确认当前目录是 ROCm/llama.cpp 源码根目录
pwd
# 例如：/home/zhengxueen/workspace/llama.cpp

# 使用 ROCm 自带工具自动探测 hipclang 和 HIP 路径
export LLAMACPP_ROCM_ARCH=gfx803,gfx900,gfx906,gfx908,gfx90a,gfx942,gfx1010,gfx1030,gfx1032,gfx1100,gfx1101,gfx1102

rm -rf ~/workspace/llama.cpp/build-hip &&
HIPCXX="$(hipconfig -l)/clang" HIP_PATH="$(hipconfig -R)" \
  cmake -S . -B build-hip \
  -DGGML_HIP=ON \
  -DGPU_TARGETS="$LLAMACPP_ROCM_ARCH" \
  -DCMAKE_BUILD_TYPE=Release \
  -DGGML_CURL=ON \
  && cmake --build build-hip --config Release -j"$(nproc)"

# （可选）如需增强 CDNA 架构上的 Flash Attention 性能，可添加 rocWMMA 选项：
# -DGGML_HIP_ROCWMMA_FATTN=ON
# 该选项要求系统安装 rocWMMA 头文件（rocm-meta 包默认包含，或安装 rocwmma-dev/devel 包）
```

```bash
# mtp-clean
git fetch origin pull/22673/head:mtp-clean
git checkout mtp-clean


export LLAMACPP_ROCM_ARCH=gfx803,gfx900,gfx906,gfx908,gfx90a,gfx942,gfx1010,gfx1030,gfx1032,gfx1100,gfx1101,gfx1102

rm -rf ~/workspace/llama.cpp/build-mtp &&
HIPCXX="$(hipconfig -l)/clang" HIP_PATH="$(hipconfig -R)" \
  cmake -S . -B build-mtp \
  -DGGML_HIP=ON \
  -DGPU_TARGETS="$LLAMACPP_ROCM_ARCH" \
  -DCMAKE_BUILD_TYPE=Release \
  -DGGML_CURL=ON \
  && cmake --build build-mtp --config Release -j"$(nproc)"
  
# 构建完成后运行时使用 ./build-mtp/bin/llama-server
```

#### 选项说明

- `HIPCXX="$(hipconfig -l)/clang"`：使用 ROCm 自带的 `hipclang` 作为 HIP 编译器。
- `HIP_PATH="$(hipconfig -R)"`：自动发现当前 ROCm 安装前缀（通常为 `/opt/rocm`）。
- `-DGGML_HIP=ON`：启用 ROCm/HIP 后端，使推理在 AMD GPU 上运行。
- `-DGPU_TARGETS=gfx906`：指定要编译的 GPU 架构（旧版 `-DAMDGPU_TARGETS` 已弃用）。省略此选项则为当前系统所有 GPU 编译。
- `-DCMAKE_BUILD_TYPE=Release`：生成优化后的 Release 构建。
- `-DGGML_CURL=ON`：启用 HTTP/HTTPS 支持（例如下载模型、通过 URL 加载资源）。旧版 `-DLLAMA_CURL` 已弃用。
- `-DGGML_HIP_ROCWMMA_FATTN=ON`（可选）：利用 rocWMMA 增强 RDNA3+/CDNA 架构上的 Flash Attention 性能。需安装 rocWMMA 头文件。
- `-j"$(nproc)"`：使用全部 CPU 核心并行编译。


常见可执行文件包括：`llama-cli`、`llama-bench`、`llama-server` 等。

#### 常见构建错误

**`clang: error: cannot find ROCm device library`**

如果遇到此错误，搜索 `HIP_PATH` 下包含 `oclc_abi_version_400.bc` 的目录，然后设置 `HIP_DEVICE_LIB_PATH`：

```bash
# 查找 ROCm device library 路径
find /opt/rocm -name 'oclc_abi_version_400.bc' 2>/dev/null
# 例如找到：/opt/rocm-7.2.2/amdgcn/bitcache

# 添加 HIP_DEVICE_LIB_PATH 后重新配置
HIPCXX="$(hipconfig -l)/clang" HIP_PATH="$(hipconfig -R)" \
HIP_DEVICE_LIB_PATH=/opt/rocm-7.2.2/amdgcn/bitcache \
  cmake -S . -B build-hip \
  -DGGML_HIP=ON \
  -DGPU_TARGETS=gfx906 \
  -DCMAKE_BUILD_TYPE=Release
```

**GPU 未被官方支持**

如果 GPU 不在官方支持列表中，可设置 `HSA_OVERRIDE_GFX_VERSION` 指定相似架构版本。MI50 (gfx906) 通常无需此设置，但如遇 GFX 版本识别问题可添加：

```bash
export HSA_OVERRIDE_GFX_VERSION=9.0.6
```

---

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

> 论文：*Closing the Gap: Trellis-Coded Quantization for KV Cache at 2-3 Bits*
>
> **注意**：buun-llama-cpp 的 TCQ 功能目前主要针对 CUDA 后端优化，HIP/ROCm 后端官方仅在 RDNA3 (gfx1100, RX 7900 XTX) + ROCm 7.2 上测试过。gfx906 构建可能需要额外调整，如遇 TCQ kernel 编译失败可降级到标量量化模式（`turbo3` / `turbo2`）。

### 9.1 获取 buun-llama-cpp 源码

```bash
mkdir -p ~/workspace && cd ~/workspace

git clone https://github.com/spiritbuun/buun-llama-cpp
cd buun-llama-cpp
```

### 9.2 配置与构建

官方 README 的 ROCm 构建命令如下（将 `AMDGPU_TARGETS` 改为 MI50 的 `gfx906`）：

```bash
# 为 MI50 设置架构
export LLAMACPP_ROCM_ARCH=gfx906

# 配置（官方 README 方式，使用 amdclang 编译器）
cmake -B build-hip \
  -DGGML_HIP=ON \
  -DAMDGPU_TARGETS=gfx906 \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLAMA_BUILD_SERVER=ON \
  -DCMAKE_C_COMPILER=/opt/rocm/bin/amdclang \
  -DCMAKE_CXX_COMPILER=/opt/rocm/bin/amdclang++

# 编译
cmake --build build-hip -j$(nproc)
```

> **编译器选择说明**：官方 README 使用 `amdclang`/`amdclang++` 硬编码路径，简单直接。如需可移植性更好的方式，可用 `hipconfig` 自动探测：
> ```bash
> HIPCXX="$(hipconfig -l)/clang" HIP_PATH="$(hipconfig -R)" \
> cmake -B build-hip \
>   -DGGML_HIP=ON \
>   -DAMDGPU_TARGETS=gfx906 \
>   -DCMAKE_BUILD_TYPE=Release \
>   -DLLAMA_BUILD_SERVER=ON
> ```

#### 与上游 llama.cpp 构建命令的差异

| 选项 | 上游 llama.cpp | buun-llama-cpp |
|------|---------------|----------------|
| 编译器指定 | `HIPCXX` + `HIP_PATH` 环境变量 | 官方 README 使用 `amdclang`/`amdclang++` 硬编码路径 |
| `-DLLAMA_BUILD_SERVER` | 未设置 | `ON`（显式编译 llama-server） |
| 构建目录 | `build-hip` | `build-hip` |

> **注意**：`-DLLAMA_CURL` 已弃用，新版统一为 `-DGGML_CURL`。如需 HTTP 支持可添加 `-DGGML_CURL=ON`。

#### 常见构建错误

**`add_subdirectory given source "debug" which is not an existing directory`** / **`Cannot find source file: debug/mtmd-debug.cpp`** / **`fatal error: 'debug/mtmd-debug.h' file not found`**

buun-llama-cpp 的 CMakeLists.txt 和源码引用了上游新增的 `examples/debug` 和 `tools/mtmd/debug` 目录，但该 fork 尚未同步这些文件。需手动 patch 三处：

```bash
cd ~/workspace/buun-llama-cpp

# 1. 注释 examples/CMakeLists.txt 中的 debug 子目录
sed -i 's/^    add_subdirectory(debug)/    # add_subdirectory(debug)/' examples/CMakeLists.txt

# 2. 注释 tools/mtmd/CMakeLists.txt 中的 mtmd-debug 目标
sed -i 's/^add_executable(llama-mtmd-debug/#add_executable(llama-mtmd-debug/' tools/mtmd/CMakeLists.txt
sed -i 's/^set_target_properties(llama-mtmd-debug/#set_target_properties(llama-mtmd-debug/' tools/mtmd/CMakeLists.txt
sed -i 's/^target_link_libraries(llama-mtmd-debug/#target_link_libraries(llama-mtmd-debug/' tools/mtmd/CMakeLists.txt
sed -i 's/^target_compile_features(llama-mtmd-debug/#target_compile_features(llama-mtmd-debug/' tools/mtmd/CMakeLists.txt
sed -i 's/PRIVATE_HEADER debug\/mtmd-debug.h)/PRIVATE_HEADER "")/' tools/mtmd/CMakeLists.txt

# 3. 注释 tools/mtmd/mtmd.cpp 中的 debug include 和函数
sed -i 's/^#include "debug\/mtmd-debug.h"/\/\/ #include "debug\/mtmd-debug.h"/' tools/mtmd/mtmd.cpp
# 注释掉文件末尾的 mtmd_debug_* 函数（约第 1410 行到文件末尾）
sed -i '1410,$ s/^/\/\/ /' tools/mtmd/mtmd.cpp

# 4. 清除旧缓存并重新构建
rm -rf build-hip
# 然后重新执行上面的 cmake 配置与编译命令
```

> **注意**：这些 debug 工具仅用于开发调试，不影响 `llama-server` 和 `llama-cli` 的正常推理功能。

**`LLAMA_CURL is deprecated and will be ignored`**

新版 llama.cpp / buun-llama-cpp 已将 `LLAMA_*` CMake 选项统一为 `GGML_*` 前缀。将 `-DLLAMA_CURL=ON` 替换为 `-DGGML_CURL=ON` 即可消除此警告。

### 9.3 TCQ 量化配置一览

| 配置 | bpv | KV cache 压缩比 | 说明 |
|------|-----|-----------------|------|
| `turbo4` | 4.25 | ~3.8x | 推荐默认，几乎无损，无速度损失 |
| `turbo3_tcq` | 3.25 | ~5x | 短上下文质量优于 FP16，2K ctx 困惑度 5.802 < FP16 的 5.805 |
| `turbo2_tcq` | 2.25 | ~7x | 最大压缩，适合极限长上下文 |
| `turbo3_tcq` K + `turbo2_tcq` V | 2.75 | ~5.5x | 非对称最佳 2-bit 质量，KLD 比反向低 15-17% |
| `turbo3`（标量） | 3.25 | ~5x | 无 TCQ trellis，编码更快但质量不如 TCQ |
| `turbo2`（标量） | 2.25 | ~7x | 无 TCQ trellis，HIP 后端编译失败时的后备方案 |

> **官方质量数据**（Qwen3.5-27B Q6_K, RTX 3090，KL-divergence，越低越好）：
>
> | 配置 | bpv | KLD @2K | KLD @7K |
> |------|-----|---------|--------|
> | turbo3_tcq | 3.25 | 0.058 | 0.074 |
> | turbo3_tcq K / turbo2_tcq V | 2.75 | 0.078 | 0.101 |
> | turbo2_tcq | 2.25 | 0.101 | 0.136 |
>
> **速度**：decode 速度在各上下文长度下恒定（~97% of q8_0），prefill 使用 tensor-core MMA 路径达 99%+ of q8_0 速度。

### 9.4 使用 TCQ KV Cache 运行推理

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

#### DFlash 投机解码 + TCQ（需搭配 Qwen3.6-27B target）

> ⚠️ DFlash drafter 的 cross-attention 层针对 **Qwen3.6-27B** 的 layer ids `[1, 16, 31, 46, 61]` 设计，与 35B-A3B **不兼容**。以下命令需使用 27B target 模型。

```bash
env -u HSA_VISIBLE_DEVICES -u ROCR_VISIBLE_DEVICES -u CUDA_VISIBLE_DEVICES \
HIP_VISIBLE_DEVICES=0 \
./build-hip/bin/llama-server \
  -m  /mnt/ssd/models/Qwen3.6-27B/googlecs-Huihui-Qwen3.6-27B-abliterated-Q4_K_M.gguf \
  -md /mnt/ssd/models/Qwen3.6-27B/dflash-draft-3.6-q8_0.gguf \
  --spec-type dflash \
  -ngl 99 -ngld 99 \
  -np 1 -c 65536 -cd 256 \
  -fa on -b 256 -ub 64 \
  --jinja \
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
  --alias Qwen3.6-27B-DFlash \
  --reasoning off
```

> ⚠️ 注意：`-ctk`/`-ctv` TCQ 量化（`turbo*_tcq`）在 HIP 后端会段错误，DFlash 模式下请勿使用。如需 KV cache 压缩，可尝试标量量化 `-ctk turbo3 -ctv turbo2`（无 `_tcq` 后缀）。

### 9.5 TCQ 参数说明

- **`-ctk`**：KV cache 中 Key 的量化类型
- **`-ctv`**：KV cache 中 Value 的量化类型
- **`-fa`**：启用 Flash Attention（TCQ 推荐开启）
- **`-ngl 99`**：将所有层 offload 到 GPU（等同于 `--n-gpu-layers -1`）

### 9.6 自定义 Codebook

TCQ 的训练 codebook 预置在 `codebooks/` 目录中，默认已编译进 CUDA kernel。可通过环境变量覆盖：

```bash
TURBO_TCQ_CB=codebooks/3bit/product_aware_iter080.bin \
TURBO_TCQ_CB2=codebooks/2bit/product_aware_iter090.bin \
./build-hip/bin/llama-server -m model.gguf -ngl 99 -fa \
  -ctk turbo3_tcq -ctv turbo3_tcq
```

Codebook 训练脚本位于 `scripts/tcq_train_*.py`。

### 9.7 支持的模型

- head_dim 为 128 的倍数的 GGUF 模型原生支持
- 其他 head_dim（如 Phi-3 的 96、Qwen3-0.6B 的 64）通过自动 zero-padding 支持
- 已测试：Qwen3.5-27B, Qwen3-32B, Gemma-3-27B, Gemma-4-31B, Harmonic-Hermes-9B, Phi-3-mini 等

### 9.8 MI50 上的注意事项

- MI50（gfx906）为 Vega20 架构，32GB HBM2 显存，TCQ 压缩在显存受限场景下收益最大
- MI50 不支持 BF16 数据类型，如遇 BF16 相关编译错误，可能需要额外补丁
- TCQ 的 CUDA kernel 可能尚未完全适配 HIP 后端，如遇编译失败，可先尝试不带 TCQ 的标量量化模式（`turbo3` / `turbo2`）
- 如遇 GFX 版本识别问题，添加 `HSA_OVERRIDE_GFX_VERSION=9.0.6`

### 9.9 DFlash 投机解码（Speculative Decoding）

buun-llama-cpp 除 TCQ KV cache 压缩外，还内置了 **DFlash** 投机解码支持——用轻量级 block diffusion 模型作为 drafter 并行生成候选 token，由 target 大模型验证，从而加速推理。

> 论文：*DFlash: Block Diffusion for Flash Speculative Decoding* (arXiv:2602.06036)
> GitHub：https://github.com/z-lab/dflash

#### 原理简述

- **Target 模型**：你实际使用的大模型（如 Qwen3.6-27B）
- **Drafter 模型**：Qwen3.6-27B-DFlash（仅 2B 参数），5 层 transformer，层模式 `[S,S,S,S,F]`（4 层 sliding-window attention + 1 层 full-attention，窗口 2048）
- Drafter 快速"猜"出多个候选 token → Target 并行验证 → 接受的 token 直接输出，拒绝的重新生成
- 接受率越高，加速比越大

#### Drafter 模型获取与量化

```bash
# 1. 下载 DFlash drafter 权重
hf download z-lab/Qwen3.6-27B-DFlash --local-dir ./dflash-drafter-3.6

# 2. 从 target 模型复制 tokenizer（drafter 仓库不包含 tokenizer）
hf download Qwen/Qwen3.6-27B \
    tokenizer.json tokenizer_config.json vocab.json merges.txt \
    special_tokens_map.json \
    --local-dir ./dflash-drafter-3.6

# 3. 转换为 GGUF（F16 中间格式）
python convert_hf_to_gguf.py ./dflash-drafter-3.6 \
    --outtype f16 \
    --outfile dflash-draft-3.6-f16.gguf

# 4. 量化为 Q8_0（推荐）或 Q4_K_M
./build-hip/bin/llama-quantize dflash-draft-3.6-f16.gguf dflash-draft-3.6-q8_0.gguf Q8_0
```

#### 量化选择

| 量化 | 大小 | 接受率 (Chat) | 推荐 |
|------|------|--------------|------|
| **Q8_0** | 1.75 GB | ~43% | ✅ 推荐，与 F16 质量一致且更快 |
| Q4_K_M | 1.03 GB | ~28% | ❌ SWA 层对 Q4 脆弱，接受率暴跌 17 点 |
| F16 | ~3.5 GB | ~45% | 质量基准，但比 Q8_0 更大更慢 |

> **Q4_K_M 不推荐**：3.6 版 drafter 引入了滑动窗口注意力 (SWA)，SWA 层对 Q4 量化极度敏感，接受率从 ~43% 暴跌到 ~28%。Q8_0 是保持 F16 质量的最小量化。

#### 运行 DFlash 投机解码

以 Qwen3.6-27B 为 target，DFlash Q8_0 为 drafter：

```bash
cd /home/zhengxueen/workspace/buun-llama-cpp

env -u HSA_VISIBLE_DEVICES -u ROCR_VISIBLE_DEVICES -u CUDA_VISIBLE_DEVICES \
HIP_VISIBLE_DEVICES=0 \
./build-hip/bin/llama-server \
  -m  /mnt/ssd/models/Qwen3.6-27B/Abiray-Huihui-Qwen3.6-27B-abliterated-Q8_0.gguf \
  -md /mnt/ssd/models/dflash-draft-3.6-q8_0.gguf \
  --spec-type dflash \
  -ngl 99 -ngld 99 \
  -np 1 -c 6048 -cd 256 \
  -fa on -b 256 -ub 64 \
  --host 0.0.0.0 --port 8080 --jinja \
  --chat-template-kwargs '{"enable_thinking": false}'
```

#### 关键参数说明

| 参数 | 含义 |
|------|------|
| `-md <path>` | 指定 drafter 模型路径 |
| `--spec-type dflash` | 投机解码类型设为 DFlash |
| `-ngld 99` | drafter 模型也全部 offload 到 GPU |
| `-cd 256` | drafter 的上下文长度 |
| `-b 256 -ub 64` | batch 大小和 micro-batch，影响投机并行度 |
| `-fa on` | Flash Attention（DFlash 硬性要求） |
| `--reasoning off` | **必须**禁用 thinking（drafter 未在 think 分布上训练） |

#### ⚠️ 关键注意事项

1. **Thinking footgun**：Qwen3.6 默认开启 thinking（输出 `<think>...</think>`），但 drafter 没在 think 分布上训练过，会导致接受率暴跌。**必须加** `--reasoning off`，可获得 ~1.8× 吞吐提升。

2. **SWA 支持需要特定 commit**：SWA 支持在 commit `b9d01582b` (SD-073) 才合入 buun-llama-cpp。更旧的构建会加载 drafter 但输出垃圾。确认你的构建包含此 commit：
   ```bash
   cd ~/workspace/buun-llama-cpp && git log --oneline b9d01582b -1
   ```

3. **MI50 / HIP 兼容性**：
   - DFlash 性能数据来自 RTX 3090（CUDA），**HIP/ROCm 后端未经验证**
   - `-fa on` 是 DFlash 硬性要求，需确认 MI50 的 HIP Flash Attention 正常工作
   - 建议先小上下文测试（`-c 4096`），确认接受率正常后再加大
   - Drafter 仅 2B 参数（Q8_0 = 1.75 GB），MI50 32GB 完全放得下

4. **⚠️ buun-llama-cpp 的 Gated Delta Net CUDA-only 限制需 patch**：Qwen3.6-27B 是 hybrid 架构（attention + SSM/Mamba 层交替，`full_attention_interval=4`），需要 fused Gated Delta Net kernel。buun-llama-cpp 在 `src/llama-context.cpp` 中硬编码了 CUDA-only 检查（`strncmp(reg_name, "CUDA", 4)`），导致 HIP/ROCm 后端直接禁用 GDN 并段错误。**修复方法**：将该检查改为同时接受 ROCm 后端：
   ```cpp
   // 原代码（仅 CUDA）：
   if (reg_name && strncmp(reg_name, "CUDA", 4) == 0) {
   // 修改为（CUDA + ROCm）：
   if (reg_name && (strncmp(reg_name, "CUDA", 4) == 0 || strncmp(reg_name, "ROCm", 4) == 0)) {
   ```
   修改后重新编译即可。原版 llama.cpp 无此限制，GDN 在 HIP 上自动启用。

5. **Drafter 与 TCQ 可叠加**：DFlash 投机解码和 TCQ KV cache 压缩可同时使用，进一步节省显存。在 target 模型参数中添加 `-ctk turbo4 -ctv turbo4` 即可。

#### 性能参考（RTX 3090，Qwen3.6-27B UD-Q4_K_XL target）

| Drafter 量化 | Raw (t/s) | Raw 接受率 | Chat (t/s) | Chat 接受率 |
|-------------|-----------|-----------|------------|------------|
| Q8_0 | 87 | 37% | 97 | 43% |
| F16 | 80 | 36% | 93 | 45% |
| Q4_K_M | 73 | 29% | 70 | 28% |

> MI50 上的实际性能可能不同，建议实测后记录。

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

# 配置（官方 README 方式，使用 amdclang 编译器）
cmake -B build-hip \
  -DGGML_HIP=ON \
  -DAMDGPU_TARGETS=gfx906 \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLAMA_BUILD_SERVER=ON \
  -DCMAKE_C_COMPILER=/opt/rocm/bin/amdclang \
  -DCMAKE_CXX_COMPILER=/opt/rocm/bin/amdclang++

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

---

## 12. 双卡 `-sm row` 崩溃与投机解码限制

### 12.1 现象

使用 `-sm row` 双卡推理时，prompt 处理阶段崩溃：

```
ROCm error: an illegal memory access was encountered
  current device: -1, in function ggml_cuda_op_mul_mat
  ggml_cuda_Memcpy2DPeerAsync(...)
已中止 (核心已转储)
```

### 12.2 根因

这是 gfx906（MI50 / Pro VII）上的 **已知 bug**，参见 GitHub Issues [#13545](https://github.com/ggml-org/llama.cpp/issues/13545) 和 [#16799](https://github.com/ggml-org/llama.cpp/issues/16799)。

`-sm row`（tensor parallelism）模式下，矩阵乘法需要跨 GPU 做 `Memcpy2DPeerAsync` 拷贝。gfx906 的 HIP 运行时在此调用上存在缺陷，无论是否启用 P2P peer access 都会触发非法内存访问。

**以下方案均无效**：
- `GGML_CUDA_DISABLE_PEER_ACCESS=1` — 非官方环境变量，不被 llama.cpp 识别
- `GGML_CUDA_P2P=0` — 官方环境变量用于**启用** P2P（`GGML_CUDA_P2P=1`），设为 0 等于不设置，不影响默认行为
- `GGML_CUDA_FORCE_MMQ=1` — 强制使用 MMQ kernel，不解决跨卡拷贝问题

### 12.3 唯一可行方案：改用 `-sm layer`

`-sm layer` 按层分割，层间数据传递走常规路径而非 `Memcpy2DPeerAsync`，可规避此崩溃：

```bash
env -u HSA_VISIBLE_DEVICES -u ROCR_VISIBLE_DEVICES -u CUDA_VISIBLE_DEVICES \
HIP_VISIBLE_DEVICES=0,1 \
./build-hip/bin/llama-server \
  --model /mnt/ssd/models/Qwen3.6-35B-A3B/huihui-qwen3.6-35b-a3b-claude-4.7-opus-abliterated-q8_0.gguf \
  --ctx-size 131072 \
  -ngl 999 -cram 0 -np 1 \
  -sm layer -ts 1,3 -mg 1 \
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
  --alias Qwen3.6-35B-A3B
```

> **代价**：layer 模式下不同 GPU 负责不同层，层间串行依赖更强，推理速度通常比 row 模式慢。但在 gfx906 上 row 模式完全不可用，layer 是唯一选择。

### 12.4 Qwen3.6-35B-A3B 不支持投机解码

无论是否加载 `--mmproj`，Qwen3.6-35B-A3B 都**无法使用投机解码**（包括 ngram-mod）。日志会显示：

```
common_speculative_is_compat: the target context does not support partial sequence removal
srv    load_model: speculative decoding not supported by this context
```

**原因**：Qwen3.6-35B-A3B 架构（`qwen35moe`）包含 **Gated Delta Net**（SSM/Mamba 循环层），其 recurrent state 不支持 partial sequence removal，而投机解码的验证-拒绝机制需要此能力。这是架构限制，不是 bug。参见 GitHub Issue [#20039](https://github.com/ggml-org/llama.cpp/issues/20039)。

> **注意**：添加 `--spec-type ngram-mod` 等参数不会报错，但会被静默忽略，投机解码不会生效。

### 12.5 Q8_0 模型 + 双卡的额外注意事项

Q8_0 模型（34.36 GiB）比 Q5_K_M（~20 GiB）大很多，双卡运行时需注意：

1. **`-ts` 比例需调整**：Q8_0 模型更大，16GB 卡放不下 1/3，建议 `-ts 1,3`（16GB 卡放 1/4，32GB 卡放 3/4）
2. **KV cache 压力**：Q8_0 模型参数占用更多 VRAM，留给 KV cache 的空间更少。如需长上下文，建议配合 TCQ 压缩（`-ctk turbo4 -ctv turbo4`）
3. **VRAM 预算**：Q8_0 模型 + 131072 ctx 在双卡上已接近极限，建议优先使用 Q5_K_M 或配合 TCQ 压缩
