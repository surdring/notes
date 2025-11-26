# ROCm7 卸载与安装指南（Ubuntu 24.04 + MI50）

> 适用场景：在 Ubuntu 24.04（noble） 上，**完全卸载当前 ROCm 与 amdgpu-dkms**，然后通过 AMD 官方仓库重新安装 **ROCm 7.0.2**。
>
> GPU 示例环境：AMD Instinct MI50（gfx906）。

---

## 0. 风险提示与准备

- 本文的命令会卸载：
  - 所有 `rocm*`、`hip-*`、HSA 相关包；
  - 所有 `amdgpu-dkms*` 与 `amdgpu*` 包。
- 如果这台机器同时承担桌面/显示用途，卸载 amdgpu 可能会影响图形界面，请谨慎操作。
- 建议在操作前：
  - 通过 SSH 或 TTY 登录，避免图形界面中断；
  - 备份重要配置（如 `/etc/apt/sources.list.d/rocm.list`、`/etc/apt/sources.list.d/amdgpu.list`）。

---

## 1. 停止正在使用 ROCm 的进程（建议）

```bash
# 如果你知道有哪些服务在用 ROCm，先手动停掉
sudo pkill -f llama-server || true
sudo pkill -f llama-cli || true
```

---

## 2. 卸载现有 ROCm 包

### 2.1 卸载 ROCm / HIP / HSA 相关包

```bash
sudo apt update

# 卸载 ROCm / HIP / HSA 相关包
sudo apt remove --purge -y \
  'rocm*' \
  'hip-*' \
  'hsa-rocr*' \
  'hsakmt-roct*' \
  'comgr*'

# 清理依赖
sudo apt autoremove -y
```

说明：

- `rocm*` 会卸载所有以 `rocm` 开头的元包和库（包括 `rocm7.x.x`）。
- `hip-*`、`hsa-rocr*`、`hsakmt-roct*` 是 HIP 与 HSA runtime 相关。
- `comgr*` 为 ROCm 工具链依赖（仅在已安装该包时会被卸载）。

---

## 3. 卸载 amdgpu-dkms 和相关驱动

### 3.1 尝试使用官方卸载脚本（如果存在）

```bash
# 如果安装过 amdgpu-install，则可能存在官方卸载脚本
if command -v amdgpu-uninstall >/dev/null 2>&1; then
  sudo amdgpu-uninstall
fi
```

### 3.2 若无 amdgpu-uninstall，则用 apt 强制卸载

```bash
sudo apt remove --purge -y \
  'amdgpu-dkms*' \
  'amdgpu*'

sudo apt autoremove -y
```

说明：

- 这一步会卸载 AMDGPU 内核模块包和用户态组件；
- 对纯计算节点一般没有问题；如有桌面环境，可在完成 ROCm 调试后再根据需要重装图形栈。

---

## 4. 清理旧 ROCm / AMDGPU APT 源

```bash
sudo rm -f /etc/apt/sources.list.d/rocm.list
sudo rm -f /etc/apt/preferences.d/rocm-pin-600
sudo rm -f /etc/apt/sources.list.d/amdgpu.list

sudo apt update
```

这一步确保后续安装使用的是最新、干净的 ROCm 7.0.2 仓库配置。

---

## 5. 按 Quick Start 安装 AMDGPU 驱动（amdgpu-dkms）

参考 AMD 官方 **ROCm 7.0.2 Quick start installation guide（Ubuntu 24.04 / noble）**：

### 5.1 安装 amdgpu-install 工具包

```bash
wget https://repo.radeon.com/amdgpu-install/7.0.2/ubuntu/noble/amdgpu-install_7.0.2.70002-1_all.deb
sudo apt install ./amdgpu-install_7.0.2.70002-1_all.deb
sudo apt update
```

> 说明：如果之前已经安装过相同版本的 `amdgpu-install`，再次安装是幂等的，可以直接覆盖。

### 5.2 安装内核头文件和 amdgpu-dkms 驱动

```bash
sudo apt install "linux-headers-$(uname -r)" "linux-modules-extra-$(uname -r)"
sudo apt install amdgpu-dkms
```

> 建议：`amdgpu-dkms` 安装完成后，**重启一次系统**，确保新内核模块和 `/dev/kfd`、`/dev/dri` 等设备节点正确加载，然后再进行下一步 ROCm 安装。

---

## 6. 按 Quick Start 安装 ROCm 7.0.2

完成驱动安装并重启后，继续使用 Quick Start 中的 Ubuntu noble 步骤安装 ROCm：

```bash
sudo apt update
sudo apt install python3-setuptools python3-wheel
sudo usermod -a -G render,video $LOGNAME   # 将当前用户加入 render、video 组
sudo apt install rocm
```

说明：

- `amdgpu-install` 包已经为你配置好了 ROCm 的 APT 源，上面的 `sudo apt install rocm` 会拉取 **当前 7.0.2 系列**的 ROCm meta package 及其依赖；
- 安装完成后，一般会在 `/opt/rocm-7.0.2`（以及 `/opt/rocm` 符号链接）下看到 ROCm 目录结构。

> 提示：执行 `sudo usermod -a -G render,video $LOGNAME` 后需要重新登录当前用户会话，新的组权限才会生效。

---

## 7.（可选）为 ROCm 7.0.2 配置环境变量

为确保使用 7.0.2 的工具链，可以通过 profile 脚本设置 PATH / LD_LIBRARY_PATH：

```bash
sudo tee /etc/profile.d/rocm-7.0.2.sh <<'EOF'
export PATH=/opt/rocm-7.0.2/bin:$PATH
export LD_LIBRARY_PATH=/opt/rocm-7.0.2/lib:/opt/rocm-7.0.2/lib64:$LD_LIBRARY_PATH
EOF
```

重新登录 shell（或 `source /etc/profile`）后，验证：

```bash
/opt/rocm-7.0.2/bin/rocminfo
/opt/rocm-7.0.2/bin/hipcc --version
```

如果命令能成功运行并正确识别 MI50（gfx906），说明 ROCm 7.0.2 安装基本正常。

---

## 7.5 使用 Arch `rocblas` 包为 MI50(gfx906) 补齐 rocBLAS 内核（可选）

> 仅在你需要在 MI50(gfx906) 上跑依赖 rocBLAS 的高性能计算负载，且发现缺少 `gfx906` 内核时报错时再考虑这一步。

### 7.5.1 背景说明

- 从 ROCm 6.x 起，官方逐步弱化/移除了对 `gfx906`（MI50/MI60） 的预编译内核支持，系统自带的 `rocblas` 内核文件中往往没有 `gfx906` 对应的 kernel。
- Arch Linux 的 `rocblas` 包中仍包含大量为 `gfx906` 预编译好的 `.hsaco/.co/.dat` 文件，可以“借用”到本机的 ROCm 安装中，让 MI50 正常跑 BLAS 运算。

### 7.5.2 下载 Arch 的 `rocblas` 包

在浏览器打开：

https://archlinux.org/packages/extra/x86_64/rocblas/

下载对应版本的包，例如：

- `rocblas-7.1.0-2-x86_64.pkg.tar.zst`

假设下载到：`~/下载/rocblas-7.1.0-2-x86_64.pkg.tar.zst`

### 7.5.3 从包中提取 `gfx906` 相关文件

```bash
mkdir -p ~/tmp_rocblas_arch
cd ~/tmp_rocblas_arch

# 解包（只解到 ~/tmp_rocblas_arch 目录，不覆盖系统 /opt/rocm）
tar --zstd -xvf ~/下载/rocblas-7.1.0-2-x86_64.pkg.tar.zst
```

检查有哪些 `gfx906` 相关文件：

```bash
cd ~/tmp_rocblas_arch/opt/rocm/lib/rocblas/library

# 列出所有带 gfx906 的内核文件
ls *gfx906* 2>/dev/null || find . -name '*gfx906*'
```

常见文件示例（不完整，仅示意）：

- `Kernels.so-000-gfx906-xnack-.hsaco`
- `TensileLibrary_..._gfx906-xnack-.hsaco`
- `TensileLibrary_..._gfx906.co`
- `TensileLibrary_..._gfx906.dat`

这些就是要“借用”的 **MI50(gfx906) 专用 kernel**。

### 7.5.4 拷贝到本机 ROCm 的 rocBLAS 目录

> 假设你系统的 ROCm 安装在 `/opt/rocm`（AMD 官方安装脚本的默认路径）。

```bash
# 确保目标目录存在
sudo mkdir -p /opt/rocm/lib/rocblas/library

# 在上一步的 ~/tmp_rocblas_arch/opt/rocm/lib/rocblas/library 目录中执行：
sudo cp *gfx906* /opt/rocm/lib/rocblas/library/
```

这样会把 Arch 包中所有 `gfx906` 相关的 `.hsaco/.co/.dat` 内核文件复制到系统 ROCm 的 rocBLAS kernel 目录。

### 7.5.5 注意事项

- **只拷贝 kernel 文件，不要替换系统主库**  
  仅从 `~/tmp_rocblas_arch/opt/rocm/lib/rocblas/library/` 目录中选择 `*gfx906*` 文件复制到 `/opt/rocm/lib/rocblas/library/`，**不要覆盖 `/opt/rocm/lib/librocblas.so*` 等主库**，以降低破坏现有 ROCm 环境的风险。
- **版本不完全匹配的风险**  
  例如：Arch 包里的 `rocblas 6.4.4` 对应 ROCm 6.4，而当前系统使用的是 ROCm 7.0.2。理论上 ABI 不保证完全兼容，但社区实践中大部分场景可以正常加载并工作；若不兼容，会在运行时报 `rocblas` kernel 加载失败之类的错误。
- **建议测试**  
  操作前可备份原来的 `/opt/rocm/lib/rocblas/library/`（如果已有内容），拷贝后先用简单的 `rocblas-bench` 或依赖 rocBLAS 的小程序测试一轮，再跑正式负载。例如：

  ```bash
  # 备份当前 rocblas kernel 目录（如果存在）
  if [ -d /opt/rocm/lib/rocblas/library ]; then
    sudo cp -a /opt/rocm/lib/rocblas/library \
      /opt/rocm/lib/rocblas/library.backup-"$(date +%Y%m%d-%H%M%S)"
  fi
  ```

---

## 8. 后续建议

- 完成 ROCm 7.0.2 安装后，可以重新编译 / 运行：
  - 本机构建的 `llama.cpp` HIP 版本（使用 `GGML_HIP=ON` + `AMDGPU_TARGETS=gfx906`）；
  - 或使用 AMD 官方 `rocm/llama.cpp` Docker 镜像进行对比测试。
- 如果后续想尝试多版本共存（例如再装一个更高版本的 ROCm 做实验），可以参考 AMD 官方 **Ubuntu multi-version installation** 文档，在当前 7.0.2 基础上额外添加其他版本的 ROCm 元包和仓库。

> 本文命令基于 AMD ROCm 7.0.2 官方文档（Quick Start + Ubuntu multi-version 安装）整理，并结合 Ubuntu 24.04 + MI50 的实际环境做了适当精简与注释。使用前请根据自己系统情况再次确认。
