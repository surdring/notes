# Ubuntu 26.04 + ROCm 7.2.2 + llama.cpp 问题排查记录

> 环境：Ubuntu 26.04 LTS（resolute），AMD Instinct MI50（gfx906），ROCm 7.2.2

---

## 问题总览

| # | 问题 | 根因 | 解决方式 |
|---|------|------|----------|
| 1 | ROCm 7.2.2 安装失败，装成 7.1.1 | APT 源配置错误，系统自带旧版优先级更高 | 删除错误源，重新配置并设置 APT 优先级锁定 |
| 2 | `libxml2.so.2` 缺失，lld 无法启动 | Ubuntu 26.04 仅提供 `libxml2.so.16`，ROCm 依赖不兼容 | 创建软链接 `libxml2.so.16` → `libxml2.so.2` |
| 3 | cmake 找不到 `hip-config.cmake` | ROCm 7.2.2 模块在 `lib/cmake`，cmake 默认搜索 `lib64/cmake` | 添加 `-DCMAKE_PREFIX_PATH=/opt/rocm-7.2.2/lib/cmake` |
| 4 | rocBLAS 报错：无法读取 gfx906 的 TensileLibrary | ROCm 7.2.2 官方包已移除 gfx906 预编译内核 | 从 Arch Linux rocblas 包提取 gfx906 文件补充 |
| 5 | llama-server 启动段错误（signal=ILL） | ROCm 版本过旧（7.1.1），gfx906 kernel 未正确编译 | 升级到 ROCm 7.2.2 并补全 gfx906 rocBLAS 内核 |
| 6 | 安装 node | 系统未安装 Node.js | 使用 nodesource 官方脚本安装 |
| 7 | `sudo apt install rocm` 下载极慢（~2.7 KB/s） | 官方源 `repo.radeon.com` 国内直连速度极慢 | 切换国内镜像 `radeon.geekery.cn` 加速 |

---

## 问题 1：ROCm 安装版本错误（7.1.1 而非 7.2.2）

### 现象

执行 `sudo apt install rocm` 后，安装的是 ROCm 7.1.1 而非预期的 7.2.2。

### 排查过程

1. 检查源配置：
   ```bash
   cat /etc/apt/sources.list.d/rocm.list
   ```
   发现之前执行过时的 `graphics/7.2.1` 路径。

2. 之前的 `sed` 替换命令错误地将 graphics 路径从 `7.2.2` 改成了 `7.2.1`（因为 `7.2.2` 的 graphics 路径确实不存在，需回退到 `7.2.1`，但源中 rocm 主路径必须保持 `7.2.2`）。

3. Ubuntu 26.04 系统仓库自带了 ROCm 7.1.x，APT 默认选择了优先级更高的系统版本。

### 解决方案

```bash
# 1. 清理旧源配置
sudo rm -f /etc/apt/sources.list.d/rocm.list
sudo rm -f /etc/apt/preferences.d/rocm-pin-600
sudo rm -f /etc/apt/sources.list.d/amdgpu.list
sudo apt update

# 2. 重新安装 amdgpu-install（noble 版）
wget https://repo.radeon.com/amdgpu-install/7.2.2/ubuntu/noble/amdgpu-install_7.2.2.70202-1_all.deb
sudo apt install ./amdgpu-install_7.2.2.70202-1_all.deb

# 3. 注意：不要将 noble 改为 resolute！
#    AMD 官方仓库只有 noble（24.04）的包，包在 resolute（26.04）上兼容运行。
#    若改成 resolute 会导致 apt update 404 报错，apt 回退到 Ubuntu 系统自带的 7.1.0。
#    以下命令不要执行：
#   sudo sed -i 's|noble|resolute|g' /etc/apt/sources.list.d/rocm.list
#   sudo sed -i 's|noble|resolute|g' /etc/apt/sources.list.d/amdgpu.list

# 4. graphics 回退到 7.2.1（7.2.2 路径不存在）
sudo sed -i "s|graphics/7.2.2|graphics/7.2.1|" /etc/apt/sources.list.d/rocm.list

# 5. 设置 APT 优先级，覆盖系统自带版本
sudo tee /etc/apt/preferences.d/rocm-pin-600 << 'EOF'
Package: *
Pin: release o=AMD
Pin-Priority: 600

Package: rocm-*
Pin: release o=AMD
Pin-Priority: 600

Package: hip-*
Pin: release o=AMD
Pin-Priority: 600
EOF

sudo apt update

# 6. 确认候选版本
apt policy rocm
# 应显示候选为 7.2.2.70202-86~24.04（来自 AMD 源），
# 而非 7.1.x（来自 Ubuntu 仓库）

# 7. 安装 ROCm
sudo apt install rocm
```

### 关键要点

- Ubuntu 26.04 系统仓库自带 ROCm 7.1.x，**必须**通过 APT 优先级锁定才能安装 7.2.2。
- `amdgpu-install` 官方仅支持 noble（24.04），在 resolute（26.04）上直接使用 noble 源即可（包向前兼容），**无需**修改源文件中的发行版代号。若改为 `resolute` 会导致 AMD 源 404。
- `graphics` 路径确实不存在 `7.2.2` 版本，需回退到 `7.2.1`（不影响 rocm 主包的版本）。

---

## 问题 2：libxml2.so.2 缺失（lld 链接器错误）

### 现象

编译 ROCm/llama.cpp 或运行 ROCm 工具链时，报错：

```
lld: error while loading shared libraries: libxml2.so.2: cannot open shared object file
```

### 根因

ROCm 7.2.2 的 `lld`（LLVM 链接器）链接了 `libxml2.so.2`（SONAME v2），而 Ubuntu 26.04 仅提供 `libxml2.so.16`（SONAME v16）。两者 ABI 向前兼容，但 SONAME 版本号不匹配导致动态链接器拒绝加载。

### 解决方案

```bash
# 检查系统提供的 libxml2 版本
ls /usr/lib/x86_64-linux-gnu/libxml2.so*

# 创建软链接（v16 → v2）
sudo ln -s /usr/lib/x86_64-linux-gnu/libxml2.so.16 /usr/lib/x86_64-linux-gnu/libxml2.so.2
sudo ldconfig

# 验证
ldd /opt/rocm-7.2.2/lib/llvm/bin/lld 2>/dev/null | grep libxml2
# 应输出：libxml2.so.2 => /usr/lib/x86_64-linux-gnu/libxml2.so.2
```

> `apt install libxml2` 在 Ubuntu 26.04 上找不到候选包，因为系统版本为 libxml2 3.x，SONAME 已升级为 v16。软链接方式安全无副作用。

---

## 问题 3：cmake 找不到 hip-config.cmake

### 现象

```bash
By not providing "Findhip.cmake" in CMAKE_MODULE_PATH
  CMake Error at CMakeLists.txt:... (find_package):
    Could not find a package configuration file provided by "hip" with any of
    the following names:
      hip-config.cmake
```

### 根因

llama.cpp 的 `CMakeLists.txt` 搜索 `${ROCM_PATH}/lib64/cmake`，但 ROCm 7.2.2 的 cmake 模块位于 `/opt/rocm-7.2.2/lib/cmake/`（**不含 `64` 后缀**）。

系统 24.04 下 `/opt/rocm/lib64/cmake/` 和 `/opt/rocm/lib/cmake/` 可能都存在（取决于安装方式），但 26.04 上 ROCm 7.2.2 的模块路径只有 `lib/cmake`。

### 解决方案

在 cmake 配置命令中添加：

```bash
-DCMAKE_PREFIX_PATH=/opt/rocm-7.2.2/lib/cmake
```

完整命令示例：

```bash
HIPCXX="$(hipconfig -l)/clang" HIP_PATH="$(hipconfig -R)" \
  cmake -S . -B build-hip \
  -DGGML_HIP=ON \
  -DGPU_TARGETS=gfx906 \
  -DCMAKE_BUILD_TYPE=Release \
  -DGGML_HIP_ROCWMMA_FATTN=ON \
  -DCMAKE_PREFIX_PATH=/opt/rocm-7.2.2/lib/cmake \
  -DGGML_CURL=ON
```

---

## 问题 4：rocBLAS gfx906 内核缺失

### 现象

llama-server 启动时输出：

```
rocBLAS error: Cannot read TensileLibrary.dat for gfx906
```

模型加载后推理结果错误或段错误。

### 根因

从 ROCm 6.x 起，AMD 逐步弱化了对 `gfx906`（MI50/MI60）的预编译内核支持。ROCm 7.2.2 官方包中不包含 gfx906 对应的 rocBLAS TensileLibrary 文件。

### 解决方案

从 Arch Linux 的 rocblas 包中提取 gfx906 内核文件，补充到本机 ROCm 目录。

```bash
# 1. 下载 Arch 的 rocblas 包
cd ~/下载
wget https://mirror.msys2.org/archlinux/extra/os/x86_64/rocblas-7.2.2-1-x86_64.pkg.tar.zst

# 2. 解包
mkdir -p ~/tmp_rocblas_arch
cd ~/tmp_rocblas_arch
tar --zstd -xvf ~/下载/rocblas-7.2.2-1-x86_64.pkg.tar.zst

# 3. 确认本机 ROCm 版本化路径
ROCM_VERSION_DIR="/opt/rocm-$(rocm-config --version 2>/dev/null || echo '7.2.2')"
TARGET_DIR="${ROCM_VERSION_DIR}/lib/rocblas/library"

# 4. 拷贝 gfx906/gfx1010 内核文件
sudo mkdir -p "${TARGET_DIR}"
cd ~/tmp_rocblas_arch/opt/rocm/lib/rocblas/library
sudo cp *gfx906* "${TARGET_DIR}/"
sudo cp *gfx1010* "${TARGET_DIR}/"

# 5. 验证
ls -la "${TARGET_DIR}"/*gfx906* | wc -l
# 应输出大量 gfx906 相关文件
```

### 关键要点

- **路径很重要**：必须拷贝到版本化路径（如 `/opt/rocm-7.2.2/lib/rocblas/library/`），而非 `/opt/rocm/lib/rocblas/library/`（两者可能是不同目录）。
- 只拷贝 kernel 文件（`*gfx906*`），**不要覆盖** `librocblas.so` 等主库文件。
- Arch 包的版本应与本机 ROCm 版本匹配（本例均为 7.2.2），避免 ABI 不兼容。

---

## 问题 5：llama-server 段错误（signal=ILL）

### 现象

```bash
signal=ILL
process killed by signal 4 (ILL)
```

启动时在 GPU 预热/权重加载阶段立即崩溃。

### 根因排查

该问题有两种可能：

1. **ROCm 版本过旧**：最初安装的是 ROCm 7.1.1（见问题 1），该版本对 gfx906 的支持不完整，编译时未正确生成对应架构的内核代码。
2. **rocBLAS 内核缺失**：即使安装正确版本（7.2.2），rocBLAS 也缺少 gfx906 的 TensileLibrary 文件（见问题 4）。

### 解决方案

- 先解决**问题 1**（安装正确的 ROCm 7.2.2）
- 再解决**问题 4**（补充 gfx906 内核文件）
- 最后重新编译 llama.cpp（确保 `-DGPU_TARGETS=gfx906`）

---

## 问题 6：安装 node

### 现象

需要安装 Node.js。

### 解决方案

```bash
# 安装 Node.js（LTS 版本）
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt install -y nodejs

# 验证
node --version
npm --version
```

---

## 问题 7：`sudo apt install rocm` 下载极慢

### 现象

执行 `sudo apt install rocm` 后，下载速度仅 ~2.7 KB/s，预估耗时 27 天以上：

```
20% [13 amd-smi-lib 1,269 kB/2,478 kB 51%]  2,727 B/s 27天 11小时 38分 26秒
```

### 根因

ROCm 官方源 `repo.radeon.com` 位于海外，国内直连速度极慢（实测 ~2.7 KB/s）。需下载约 6.6 GB 数据，在官方源直连下几乎不可完成。

### 解决方案

使用国内社区镜像 `radeon.geekery.cn` 加速：

```bash
# 方案 A：使用自动脚本（推荐）
curl -sSL https://www.geekery.cn/sh/radeon/set_radeon_mirror.sh | sudo bash
sudo apt update
sudo apt install rocm

# 方案 B：手动替换源
sudo sed -i 's|repo.radeon.com/rocm|radeon.geekery.cn/rocm|g' /etc/apt/sources.list.d/rocm.list
sudo sed -i 's|repo.radeon.com/graphics|radeon.geekery.cn/graphics|g' /etc/apt/sources.list.d/rocm.list
sudo sed -i 's|repo.radeon.com/amdgpu|radeon.geekery.cn/amdgpu|g' /etc/apt/sources.list.d/amdgpu.list
sudo apt update
sudo apt install rocm
```

### 镜像不可达时的备用方案

如果镜像 `radeon.geekery.cn` 连接超时，可暂时切回官方源（速度慢但可用）：

```bash
sudo sed -i 's|radeon.geekery.cn|repo.radeon.com|g' /etc/apt/sources.list.d/rocm.list /etc/apt/sources.list.d/amdgpu.list
sudo apt update
```

> 镜像状态波动属偶发现象，等待一段时间后重试通常可恢复。

---

## 排查思路总结

在 Ubuntu 26.04 + ROCm 7.2.2 + MI50(gfx906) 环境中，问题的根本原因可归纳为两类：

### 一、Ubuntu 26.04 系统层面的不兼容

| 问题 | 原因 | 模式 |
|------|------|------|
| APT 版本冲突 | 系统自带 ROCm 7.1.x | 需手动锁定 APT 优先级 |
| libxml2 版本不匹配 | SONAME 从 v2 升级到 v16 | 软链接兼容旧 SONAME |

**规律**：新版系统提供更新的库版本，厂商工具链可能尚未适配。

### 二进制的 SONAME 要求。软链接通常可以安全解决这类问题。

### 二、ROCm 7.2.2 层面的兼容性退化

| 问题 | 原因 | 模式 |
|------|------|------|
| rocBLAS 无 gfx906 内核 | AMD 已移除旧架构支持 | 从其他发行版借用心核文件 |
| cmake 模块路径变更 | lib64 → lib | 显式指定 CMAKE_PREFIX_PATH |

**规律**：ROCm 新版本逐步淘汰旧 GPU 架构，旧设备（MI50/gfx906 发布于 2018 年）需要借助社区手段补齐支持。

### 通用排查流程

```
llama-server 崩溃/报错
        │
        ▼
  检查 ROCm 版本 ──── 版本不对？──→ 重装 ROCm（问题 1）
        │
        ▼
   版本正确，继续
        │
        ▼
  检查 rocBLAS 内核 ── 缺 gfx906？──→ 从 Arch 包提取（问题 4）
        │
        ▼
   内核完整，继续
        │
        ▼
  检查编译参数 ──────────→ 确认 GPU_TARGETS 含 gfx906
                           确认 CMAKE_PREFIX_PATH 正确（问题 3）
        │
        ▼
  检查运行时依赖 ────────→ ldd 检查缺失的 .so（问题 2）
        │
        ▼
   仍崩溃？──────────────→ 查看 dmesg / journalctl 获取 signal 信息
```