# Rust 国内镜像配置指南

国内访问 Rust 官方源速度较慢，需配置国内镜像以加速 `rustup`、`cargo` 等工具的下载。本文覆盖 Linux、macOS 和 Windows 三大平台。

---

## 1. rustup 镜像配置（Rust 工具链安装/更新）

rustup 通过环境变量 `RUSTUP_DIST_SERVER` 和 `RUSTUP_UPDATE_ROOT` 控制下载源。

### 可用镜像源

| 镜像 | RUSTUP_DIST_SERVER | RUSTUP_UPDATE_ROOT |
|------|-------------------|-------------------|
| 中科大 (USTC) | `https://mirrors.ustc.edu.cn/rust-static` | `https://mirrors.ustc.edu.cn/rust-static/rustup` |
| 清华 (Tuna) | `https://mirrors.tuna.tsinghua.edu.cn/rust-static` | `https://mirrors.tuna.tsinghua.edu.cn/rust-static/rustup` |
| 上海交大 (SJTUG) | `https://mirrors.sjtug.sjtu.edu.cn/rust-static` | `https://mirrors.sjtug.sjtu.edu.cn/rust-static/rustup` |

### Linux / macOS

**临时生效（当前终端）：**

```bash
export RUSTUP_DIST_SERVER=https://mirrors.ustc.edu.cn/rust-static
export RUSTUP_UPDATE_ROOT=https://mirrors.ustc.edu.cn/rust-static/rustup
```

**永久生效：**

使用 Bash（大多数 Linux 发行版、macOS Catalina 及更早版本）：

```bash
echo 'export RUSTUP_DIST_SERVER=https://mirrors.ustc.edu.cn/rust-static' >> ~/.bashrc
echo 'export RUSTUP_UPDATE_ROOT=https://mirrors.ustc.edu.cn/rust-static/rustup' >> ~/.bashrc
source ~/.bashrc
```

使用 Zsh（macOS Big Sur 及更新版本、部分 Linux）：

```bash
echo 'export RUSTUP_DIST_SERVER=https://mirrors.ustc.edu.cn/rust-static' >> ~/.zshrc
echo 'export RUSTUP_UPDATE_ROOT=https://mirrors.ustc.edu.cn/rust-static/rustup' >> ~/.zshrc
source ~/.zshrc
```

使用 Fish：

```bash
set -Ux RUSTUP_DIST_SERVER https://mirrors.ustc.edu.cn/rust-static
set -Ux RUSTUP_UPDATE_ROOT https://mirrors.ustc.edu.cn/rust-static/rustup
```

### Windows

**CMD（临时）：**

```cmd
set RUSTUP_DIST_SERVER=https://mirrors.ustc.edu.cn/rust-static
set RUSTUP_UPDATE_ROOT=https://mirrors.ustc.edu.cn/rust-static/rustup
```

**CMD（永久，写入注册表）：**

```cmd
setx RUSTUP_DIST_SERVER https://mirrors.ustc.edu.cn/rust-static
setx RUSTUP_UPDATE_ROOT https://mirrors.ustc.edu.cn/rust-static/rustup
```

> `setx` 设置的环境变量需重新打开终端才生效。

**PowerShell（临时）：**

```powershell
$env:RUSTUP_DIST_SERVER = "https://mirrors.ustc.edu.cn/rust-static"
$env:RUSTUP_UPDATE_ROOT = "https://mirrors.ustc.edu.cn/rust-static/rustup"
```

**PowerShell（永久）：**

```powershell
[Environment]::SetEnvironmentVariable("RUSTUP_DIST_SERVER", "https://mirrors.ustc.edu.cn/rust-static", "User")
[Environment]::SetEnvironmentVariable("RUSTUP_UPDATE_ROOT", "https://mirrors.ustc.edu.cn/rust-static/rustup", "User")
```

### 首次安装 Rust 时使用镜像

在设置好上述环境变量后，正常运行安装命令即可：

```bash
# Linux / macOS
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Windows
# 从 https://rustup.rs 下载 rustup-init.exe 运行
```

---

## 2. Cargo 镜像配置（依赖包下载）

Cargo 通过 `~/.cargo/config.toml`（或 `config`）配置镜像源。

### 可用镜像源

| 镜像 | 地址 |
|------|------|
| 中科大 (USTC) | `https://mirrors.ustc.edu.cn/crates.io-index` |
| 清华 (Tuna) | `https://mirrors.tuna.tsinghua.edu.cn/git/crates.io-index.git` |
| 上海交大 (SJTUG) | `https://mirrors.sjtug.sjtu.edu.cn/crates.io-index` |
| 字节跳动 | `https://rsproxy.cn/crates.io-index` |

> **注意**：新版本 Cargo 支持 sparse 协议，下载更快，推荐优先使用 sparse 格式。

### Linux / macOS

创建或编辑 `~/.cargo/config.toml`：

**使用 sparse 协议（推荐）：**

```toml
[source.crates-io]
replace-with = "ustc"

[source.ustc]
registry = "sparse+https://mirrors.ustc.edu.cn/crates.io-index/"
```

**使用传统 git 协议：**

```toml
[source.crates-io]
replace-with = "ustc"

[source.ustc]
registry = "https://mirrors.ustc.edu.cn/crates.io-index"
```

**其他镜像示例：**

```toml
# 清华
[source.tuna]
registry = "sparse+https://mirrors.tuna.tsinghua.edu.cn/crates.io-index/"

# 字节跳动
[source.rsproxy]
registry = "sparse+https://rsproxy.cn/crates.io-index/"
```

### Windows

创建或编辑 `%USERPROFILE%\.cargo\config.toml`（即 `C:\Users\<用户名>\.cargo\config.toml`）：

```toml
[source.crates-io]
replace-with = "ustc"

[source.ustc]
registry = "sparse+https://mirrors.ustc.edu.cn/crates.io-index/"
```

**快速创建（PowerShell）：**

```powershell
New-Item -Path "$env:USERPROFILE\.cargo" -ItemType Directory -Force
Set-Content -Path "$env:USERPROFILE\.cargo\config.toml" -Value @"
[source.crates-io]
replace-with = "ustc"

[source.ustc]
registry = "sparse+https://mirrors.ustc.edu.cn/crates.io-index/"
"@
```

---

## 3. rust-analyzer 等工具的镜像

部分工具（如 rust-analyzer）通过 rustup 分发，其下载源同样受 `RUSTUP_DIST_SERVER` 控制，无需额外配置。

---

## 4. 一键配置脚本

### Linux / macOS（Bash/Zsh）

```bash
#!/usr/bin/env bash
set -e

MIRROR="${1:-ustc}"

case "$MIRROR" in
  ustc)
    DIST="https://mirrors.ustc.edu.cn/rust-static"
    UPDATE="https://mirrors.ustc.edu.cn/rust-static/rustup"
    REGISTRY="sparse+https://mirrors.ustc.edu.cn/crates.io-index/"
    ;;
  tuna)
    DIST="https://mirrors.tuna.tsinghua.edu.cn/rust-static"
    UPDATE="https://mirrors.tuna.tsinghua.edu.cn/rust-static/rustup"
    REGISTRY="sparse+https://mirrors.tuna.tsinghua.edu.cn/crates.io-index/"
    ;;
  rsproxy)
    DIST="https://rsproxy.cn/rustup"
    UPDATE="https://rsproxy.cn/rustup/rustup"
    REGISTRY="sparse+https://rsproxy.cn/crates.io-index/"
    ;;
  *)
    echo "Usage: $0 [ustc|tuna|rsproxy]"
    exit 1
    ;;
esac

# rustup 镜像
SHELL_RC="$HOME/.bashrc"
if [ -n "$ZSH_VERSION" ]; then
  SHELL_RC="$HOME/.zshrc"
fi

grep -q "RUSTUP_DIST_SERVER" "$SHELL_RC" 2>/dev/null || {
  echo "export RUSTUP_DIST_SERVER=$DIST" >> "$SHELL_RC"
  echo "export RUSTUP_UPDATE_ROOT=$UPDATE" >> "$SHELL_RC"
}
export RUSTUP_DIST_SERVER="$DIST"
export RUSTUP_UPDATE_ROOT="$UPDATE"

# Cargo 镜像
CARGO_DIR="$HOME/.cargo"
mkdir -p "$CARGO_DIR"
cat > "$CARGO_DIR/config.toml" <<EOF
[source.crates-io]
replace-with = "mirror"

[source.mirror]
registry = "$REGISTRY"
EOF

echo "Rust 镜像已配置为: $MIRROR"
echo "请运行 source $SHELL_RC 或重新打开终端使环境变量生效"
```

### Windows（PowerShell）

```powershell
param(
    [ValidateSet("ustc", "tuna", "rsproxy")]
    [string]$Mirror = "ustc"
)

switch ($Mirror) {
    "ustc" {
        $Dist = "https://mirrors.ustc.edu.cn/rust-static"
        $Update = "https://mirrors.ustc.edu.cn/rust-static/rustup"
        $Registry = "sparse+https://mirrors.ustc.edu.cn/crates.io-index/"
    }
    "tuna" {
        $Dist = "https://mirrors.tuna.tsinghua.edu.cn/rust-static"
        $Update = "https://mirrors.tuna.tsinghua.edu.cn/rust-static/rustup"
        $Registry = "sparse+https://mirrors.tuna.tsinghua.edu.cn/crates.io-index/"
    }
    "rsproxy" {
        $Dist = "https://rsproxy.cn/rustup"
        $Update = "https://rsproxy.cn/rustup/rustup"
        $Registry = "sparse+https://rsproxy.cn/crates.io-index/"
    }
}

# rustup 镜像
[Environment]::SetEnvironmentVariable("RUSTUP_DIST_SERVER", $Dist, "User")
[Environment]::SetEnvironmentVariable("RUSTUP_UPDATE_ROOT", $Update, "User")
$env:RUSTUP_DIST_SERVER = $Dist
$env:RUSTUP_UPDATE_ROOT = $Update

# Cargo 镜像
$CargoDir = "$env:USERPROFILE\.cargo"
New-Item -Path $CargoDir -ItemType Directory -Force | Out-Null
Set-Content -Path "$CargoDir\config.toml" -Value @"
[source.crates-io]
replace-with = "mirror"

[source.mirror]
registry = "$Registry"
"@

Write-Host "Rust 镜像已配置为: $Mirror" -ForegroundColor Green
Write-Host "请重新打开终端使环境变量生效" -ForegroundColor Yellow
```

---

## 5. 验证配置

```bash
# 检查 rustup 环境变量
echo $RUSTUP_DIST_SERVER
echo $RUSTUP_UPDATE_ROOT

# 检查 Cargo 配置
cat ~/.cargo/config.toml

# 测试下载速度
cargo search serde
```

---

## 6. 常见问题

### Q: 配置后 cargo build 仍然很慢？

确认 `config.toml` 使用了 **sparse** 协议（地址以 `sparse+https://` 开头），sparse 协议按需下载索引，比传统 git clone 整个仓库快得多。

### Q: Windows 上 setx 报错？

确保以普通用户身份运行，不要在管理员终端中使用 `setx`，否则可能写入系统级环境变量。

### Q: 切换镜像后仍从旧源下载？

1. 清除 Cargo 缓存：`cargo cache -a 2>/dev/null || rm -rf ~/.cargo/registry/cache ~/.cargo/registry/src`
2. 确认 `config.toml` 中 `replace-with` 的值与 `[source.xxx]` 的名称一致
3. 项目级 `.cargo/config.toml` 会覆盖全局配置，检查项目目录下是否有该文件

### Q: 如何恢复官方源？

删除或注释掉 `config.toml` 中的 `[source.crates-io]` 和 `replace-with` 行，并移除环境变量 `RUSTUP_DIST_SERVER` 和 `RUSTUP_UPDATE_ROOT`。
