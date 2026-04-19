# ROCm 7.0.3 在 Ubuntu 24.04 (Noble) 上的完整安装与故障排除指南

本文档记录了在 Ubuntu 24.04 上从零开始安装 ROCm 7.0.3，并解决顽固依赖关系错误的完整步骤。

问题的核心在于 Ubuntu 24.04 的软件包与为 Ubuntu 22.04 (Jammy) 构建的 ROCm 官方包之间存在冲突，且系统中可能已存在损坏的、版本不匹配的 ROCm 包。

---

## 步骤 0: 安装基础依赖

在开始之前，必须确保系统拥有编译内核模块所需的基础组件。

```bash
# 更新软件包列表
sudo apt update

# 安装与当前内核版本匹配的头文件，这对于 DKMS 驱动编译至关重要
sudo apt install "linux-headers-$(uname -r)" "linux-modules-extra-$(uname -r)"

# 安装一些常见的 Python 工具
sudo apt install python3-setuptools python3-wheel
```

---

## 步骤 1: 添加 AMD ROCm 官方软件仓库

确保系统能够找到 ROCm 7.0.3 的软件包。这些包是为 `jammy` 构建的，但兼容 `noble`。

```bash
# 创建 GPG 密钥环目录
sudo mkdir --parents --mode=0755 /etc/apt/keyrings

# 下载并添加 AMD 的 GPG 密钥
wget https://repo.radeon.com/rocm/rocm.gpg.key -O - | \
    sudo gpg --dearmor -o /etc/apt/keyrings/rocm.gpg

# 添加 ROCm 7.0.3 软件源
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/7.0.3 jammy main" | \
    sudo tee /etc/apt/sources.list.d/rocm.list

# 再次更新软件包列表以包含新的仓库
sudo apt update
```

---

## 步骤 2: （如果遇到依赖错误）彻底清理旧的 ROCm 包

如果在执行安装命令时遇到依赖关系错误（例如 `E: 无法修正错误...`），这通常意味着系统中有损坏或版本冲突的包。必须进行彻底清理。

1.  **安装 `aptitude`**

    `aptitude` 是一个比 `apt` 更强大的包管理器，能够解决复杂的依赖问题。
    ```bash
    sudo apt install aptitude
    ```

2.  **使用 `aptitude` 移除所有冲突包**

    运行以下命令，`aptitude` 会计算出完整的依赖链并提供一个卸载所有相关包的解决方案。
    ```bash
    sudo aptitude remove rocm-core
    ```
    在提示 `是否接受该解决方案？[Y/n/q/?]` 时，检查它建议删除的是否都是 ROCm 相关包，然后输入 `Y` 并按回车确认。

---

## 步骤 3: 执行最终安装

在系统清理干净后，执行以下命令来安装 ROCm 驱动和软件平台。

```bash
sudo apt install amdgpu-dkms rocm
```

---

## 步骤 4: 配置用户权限

为了让当前用户无需 `sudo` 就能访问 GPU 设备，需要将其添加到 `render` 和 `video` 组。

```bash
sudo usermod -a -G render,video $LOGNAME
```

**注意**: 此更改需要您完全注销并重新登录系统后才能生效。

此时，`apt` 将会从正确的 AMD 仓库中下载并安装所有版本匹配的软件包，完成安装。
