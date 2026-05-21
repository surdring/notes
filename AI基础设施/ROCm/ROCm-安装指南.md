# ROCm 安装与升级指南（Ubuntu 24.04/26.04 + MI50）

> 适用场景：在 Ubuntu 24.04 LTS（noble）或 26.04 LTS（resolute）上，卸载当前 ROCm 与 amdgpu-dkms，重新安装或升级到目标版本。
>
> GPU 示例环境：AMD Instinct MI50（gfx906）。

系统信息参考：
| Ubuntu 版本 | 代号 | 内核版本参考 | ROCm 支持情况 |
|-------------|------|-------------|--------------|
| 24.04 LTS | noble | 6.8+ | 需手动添加 ROCm 源 |
| 26.04 LTS | resolute | 7.0+ | 系统仓库已含 ROCm，但版本可能非最新 |

> 本文以 ROCm 7.2.2 为目标版本。若系统仓库中已有 ROCm（26.04+），需通过 APT 优先级锁定确保安装指定版本。

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

```bash
sudo apt update


sudo apt remove --purge -y 'rocm*'

sudo apt remove --purge -y 'hip-*'

sudo apt remove --purge -y 'hsa-rocr*'

sudo apt remove --purge -y 'hsakmt-roct*'

sudo apt remove --purge -y 'comgr*'

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

---

## 4. 清理旧 ROCm / AMDGPU APT 源

```bash
sudo apt purge amdgpu-install
sudo apt autoremove -y
sudo rm -f /etc/apt/sources.list.d/rocm.list
sudo rm -f /etc/apt/preferences.d/rocm-pin-600
sudo rm -f /etc/apt/sources.list.d/amdgpu.list
sudo rm -rf /var/cache/apt/*
sudo apt clean all
sudo apt update
```

---

## 5. 注册目标版本仓库

> 如果之前已经安装过相同版本的 `amdgpu-install`，再次安装是幂等的，可以直接覆盖。

### 方案 A：Ubuntu 24.04 (noble)

```bash
wget https://repo.radeon.com/amdgpu-install/7.2.2/ubuntu/noble/amdgpu-install_7.2.2.70202-1_all.deb
sudo apt install ./amdgpu-install_7.2.2.70202-1_all.deb
# graphics/7.2.2 路径不存在，需回退到 7.2.1
sudo sed -i "s|graphics/7.2.2|graphics/7.2.1|" /etc/apt/sources.list.d/rocm.list
sudo apt update
```

### 方案 B：Ubuntu 26.04 (resolute)

ROCm 7.2.2 的 `amdgpu-install` 官方仅支持 noble（24.04），在 26.04 上需手动配置仓库并设置 APT 优先级，以覆盖系统自带的 ROCm 版本。

```bash
# 1. 安装 noble 版本的 amdgpu-install（仅用于注册 key 和源）
wget https://repo.radeon.com/amdgpu-install/7.2.2/ubuntu/noble/amdgpu-install_7.2.2.70202-1_all.deb
sudo apt install ./amdgpu-install_7.2.2.70202-1_all.deb

# 2. 注意：不要将 noble 改为 resolute！
#    AMD 官方仓库只有 noble（24.04）的包，这些包在 resolute（26.04）上兼容运行。
#    若改为 resolute 会导致 apt update 404 报错，APT 回退到 Ubuntu 系统自带的 7.1.0。
#    以下命令不要执行：
#   sudo sed -i 's|noble|resolute|g' /etc/apt/sources.list.d/rocm.list
#   sudo sed -i 's|noble|resolute|g' /etc/apt/sources.list.d/amdgpu.list

# 3. graphics/7.2.2 路径不存在，回退到 7.2.1
sudo sed -i "s|graphics/7.2.2|graphics/7.2.1|" /etc/apt/sources.list.d/rocm.list

# 4. 设置 APT 优先级，确保 ROCm 7.2.2 覆盖系统自带的版本
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

# 5. 更新源
sudo apt update

# 6. 验证版本候选
apt policy rocm
# 应显示候选为 7.2.2.70202-86~24.04（来自 AMD 源），
# 而非 7.1.x（来自 Ubuntu 仓库）
```

---

## 6. 切换国内镜像（推荐）

`repo.radeon.com` 国内直连极慢（~10 KB/s，实测 `comgr` 58 MB 仅 ~1.3 KB/s），使用社区镜像 `radeon.geekery.cn` 加速：

```bash
curl -sSL https://www.geekery.cn/sh/radeon/set_radeon_mirror.sh | sudo bash
```

或手动替换 `/etc/apt/sources.list.d/` 下的域名：
- `rocm.list`: `repo.radeon.com/rocm` → `radeon.geekery.cn/rocm`
- `amdgpu.list`: `repo.radeon.com/amdgpu` → `radeon.geekery.cn/amdgpu`
- `rocm.list` 中的 graphics: `repo.radeon.com/graphics` → `radeon.geekery.cn/graphics`

> 镜像来源：https://xmind.fun/free-service/radeon-mirror
>
> **镜像不可达时**：该镜像偶尔会连接超时（实测偶发）。若 `apt update` 提示无法连接镜像，可暂时切回官方源：
> ```bash
> # 切回官方源
> sudo sed -i 's|radeon.geekery.cn|repo.radeon.com|g' /etc/apt/sources.list.d/rocm.list /etc/apt/sources.list.d/amdgpu.list
> sudo apt update
> # 安装完成后，待镜像恢复可再切回来
> ```
>
> 切换后建议执行 `sudo apt update` 确认源正常工作。

---

## 7. 安装内核驱动

### 方案 A：跳过 dkms，使用 in-tree 驱动（推荐纯推理场景）

Ubuntu 24.04 内核 6.8+、26.04 内核 7.0+ 均已内置 in-tree `amdgpu` 驱动，足够 ROCm 用户态库使用，无需额外安装 `amdgpu-dkms`。

```bash
# 阻止 dkms 被意外安装
sudo apt-mark hold amdgpu-dkms amdgpu-dkms-firmware

# 恢复安装：
# sudo apt-mark unhold amdgpu-dkms amdgpu-dkms-firmware
# sudo apt install amdgpu-dkms
```

### 方案 B：安装 amdgpu-dkms（需要显示输出时）

```bash
sudo apt install "linux-headers-$(uname -r)" "linux-modules-extra-$(uname -r)"
sudo apt install amdgpu-dkms
```

> `amdgpu-dkms` 安装完成后，**重启一次系统**，确保新内核模块和 `/dev/kfd`、`/dev/dri` 等设备节点正确加载。

---

## 8. 安装 ROCm

```bash
sudo apt update
sudo apt install python3-setuptools python3-wheel
sudo usermod -a -G render,video $LOGNAME
sudo apt install rocm
```

说明：

- `amdgpu-install` 包已配置好 ROCm 的 APT 源，`sudo apt install rocm` 会拉取目标版本的 ROCm meta package 及其依赖；
- 安装 `rocm` 元包会拉取约 223 个软件包，约 6.6 GB 下载、27.4 GB 磁盘占用，耗时较长；
  若下载速度仅几 KB/s（官方源直连典型速度），请检查是否已按[第 6 节](#6-切换国内镜像推荐)配置国内镜像；
- **Ubuntu 26.04 注意**：由于系统仓库自带 ROCm，必须确保已设置 [第 5 节方案 B](#5-注册目标版本仓库) 中的 APT 优先级配置文件 `/etc/apt/preferences.d/rocm-pin-600`，否则 apt 可能安装 Ubuntu 自带的旧版 ROCm（7.1.x）而非目标版本（7.2.2）；
- 安装完成后 `update-alternatives` 自动将 `/opt/rocm` 指向对应版本目录（如 `/opt/rocm-7.2.2`），并注册 `hipcc`、`rocm-smi`、`rocprof` 等命令到 `/usr/bin/`。

> 提示：执行 `sudo usermod -a -G render,video $LOGNAME` 后需要重新登录当前用户会话，新的组权限才会生效。

---

## 9. 配置环境变量（可选）

为确保使用指定版本的工具链，可以通过 profile 脚本设置 PATH / LD_LIBRARY_PATH：

```bash
# 将 <VERSION> 替换为实际版本号，如 7.2.2
sudo tee /etc/profile.d/rocm.sh <<'EOF'
export PATH=/opt/rocm/bin:$PATH
export LD_LIBRARY_PATH=/opt/rocm/lib:/opt/rocm/lib64:$LD_LIBRARY_PATH
EOF
```

> 由于 `update-alternatives` 已将 `/opt/rocm` 指向当前版本，直接使用 `/opt/rocm` 路径即可，无需硬编码版本号。

重新登录 shell（或 `source /etc/profile`）后，验证：

```bash
rocminfo
hipcc --version
```

---

## 10. 重启与验证

```bash
sudo reboot
```

重启后验证：

```bash
rocm-smi
rocminfo | grep "ROCm version"
python3 -c "import torch; print(torch.cuda.device_count(), torch.cuda.get_device_name(0))"
```

如果命令能成功运行并正确识别 MI50（gfx906），说明 ROCm 安装基本正常。

---

## 11. 使用 Arch `rocblas` 包为 MI50(gfx906) 补齐 rocBLAS 内核（可选）

> 仅在你需要在 MI50(gfx906) 上跑依赖 rocBLAS 的高性能计算负载，且发现缺少 `gfx906` 内核时报错时再考虑这一步。

### 11.1 背景说明

- 从 ROCm 6.x 起，官方逐步弱化/移除了对 `gfx906`（MI50/MI60） 的预编译内核支持，系统自带的 `rocblas` 内核文件中往往没有 `gfx906` 对应的 kernel。
- Arch Linux 的 `rocblas` 包中仍包含大量为 `gfx906` 预编译好的 `.hsaco/.co/.dat` 文件，可以"借用"到本机的 ROCm 安装中，让 MI50 正常跑 BLAS 运算。

### 11.2 下载 Arch 的 `rocblas` 包

在浏览器打开：

https://archlinux.org/packages/extra/x86_64/rocblas/

下载对应版本的包，例如：

- `rocblas-7.2.2-1-x86_64.pkg.tar.zst`

假设下载到：`~/下载/rocblas-7.2.2-1-x86_64.pkg.tar.zst`

### 11.3 从包中提取 `gfx906` 相关文件

```bash
mkdir -p ~/tmp_rocblas_arch
cd ~/tmp_rocblas_arch

# 解包（只解到 ~/tmp_rocblas_arch 目录，不覆盖系统 /opt/rocm）
tar --zstd -xvf ~/下载/rocblas-7.2.2-1-x86_64.pkg.tar.zst
```

检查有哪些 `gfx906` 相关文件：

```bash
# 列出解压目录中所有带 gfx906 的内核文件
ls ~/tmp_rocblas_arch/opt/rocm/lib/rocblas/library/*gfx906* 2>/dev/null | head -10

# 也可检查 gfx1010（如果本机需要）
ls ~/tmp_rocblas_arch/opt/rocm/lib/rocblas/library/*gfx1010* 2>/dev/null | head -10
```

常见文件示例（不完整，仅示意）：

- `Kernels.so-000-gfx906-xnack-.hsaco`
- `TensileLibrary_..._gfx906-xnack-.hsaco`
- `TensileLibrary_..._gfx906.co`
- `TensileLibrary_..._gfx906.dat`

### 11.4 拷贝到本机 ROCm 的 rocBLAS 目录

rocBLAS 运行时会从 `librocblas.so` 所在目录的相对路径 `../lib/rocblas/library/` 加载内核文件。因此，必须拷贝到版本化路径（如 `/opt/rocm-7.2.2/lib/rocblas/library/`），而非 `/opt/rocm/lib/rocblas/library/`（两者可能是不同目录）。

```bash
# � ROCm 版 ROCm 版本化路径
# 例如：ls -d /opt/rocm-*
# ROCM_VERSION_DIR="/opt/rocm-7.2.2"
# 或使用系统默认版本
ROCM_VERSION_DIR="/opt/rocm-$(rocm-config --version 2>/dev/null || echo '7.2.2')" && echo "$ROCM_VERSION_DIR"
ROCM_VERSION_DIR="/opt/rocm-7.2.2"
TARGET_DIR="${ROCM_VERSION_DIR}/lib/rocblas/library"

# 确保目标目录存在
sudo mkdir -p "${TARGET_DIR}"

# 从 Arch 包解压目录拷贝 gfx906/gfx1010 内核文件
cd ~/tmp_rocblas_arch/opt/rocm/lib/rocblas/library

sudo cp *gfx906* "${TARGET_DIR}/"
sudo cp *gfx1010* "${TARGET_DIR}/"

# 验证拷贝结果
echo "Target: ${TARGET_DIR}"
ls -la "${TARGET_DIR}"/*gfx906* | wc -l
ls -la "${TARGET_DIR}"/*gfx1010* | wc -l
```

### 11.5 注意事项

- **只拷贝 kernel 文件，不要替换系统主库**
  仅从 `~/tmp_rocblas_arch/opt/rocm/lib/rocblas/library/` 目录中选择 `*gfx906*` 文件复制到版本化路径（如 `/opt/rocm-7.2.2/lib/rocblas/library/`），**不要覆盖 `/opt/rocm-7.2.2/lib/librocblas.so*` 等主库**，以降低破坏现有 ROCm 环境的风险。
- **版本不完全匹配的风险**
  例如：Arch 包里的 `rocblas 6.4.4` 对应 ROCm 6.4，而当前系统使用的是 ROCm 7.x。理论上 ABI 不保证完全兼容，但社区实践中大部分场景可以正常加载并工作；若不兼容，会在运行时报 `rocblas` kernel 加载失败之类的错误。
- **建议测试**
  操作前可备份原来的 rocblas kernel 目录（如果已有内容），拷贝后先用简单的 `rocblas-bench` 或依赖 rocBLAS 的小程序测试一轮，再跑正式负载。例如：

  ```bash
  # 先确认 ROCm 版本化路径
  ROCM_VERSION_DIR="/opt/rocm-$(rocm-config --version 2>/dev/null || echo '7.2.2')"

  # 备份当前 rocblas kernel 目录（如果存在）
  if [ -d "${ROCM_VERSION_DIR}/lib/rocblas/library" ]; then
    sudo cp -a "${ROCM_VERSION_DIR}/lib/rocblas/library" \
      "${ROCM_VERSION_DIR}/lib/rocblas/library.backup-$(date +%Y%m%d-%H%M%S)"
  fi
  ```

---

## 备注

- 卸载旧驱动和安装新驱动之间**必须重启**（官方 Important 提示），确保内核卸载旧驱动模块
- `usermod -a -G render,video` 只对当前用户生效，如需所有用户都能访问 GPU，需参考 [Configuring permissions for GPU access](https://rocm.docs.amd.com/projects/install-on-linux/en/latest/install/prerequisites.html)
- 如果遇到问题，参考官方 [Troubleshooting](https://rocm.docs.amd.com/projects/install-on-linux/en/latest/reference/install-faq.html)
- `google-chrome.list` 和 `google.list` 重复配置了相同源，可清理但不影响功能
- PPA `deadsnakes` 和 `graphics-drivers` 在国内访问超时，不影响 ROCm 安装
- 首次从 `repo.radeon.com` 直连下载大包时速度极慢，切换国内镜像后正常
- 安装完成后 `update-alternatives` 自动将 `/opt/rocm` 指向当前版本目录，并注册常用命令到 `/usr/bin/`
- 如果后续想尝试多版本共存，可以参考 AMD 官方 **Ubuntu multi-version installation** 文档
