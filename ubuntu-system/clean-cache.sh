#!/usr/bin/env bash
# ============================================================
# 缓存与构建产物清理脚本
# 用法: bash clean-cache.sh [--safe|--all|--workspace-only|--dry-run]
#   --safe           仅清理可自动重建的缓存（默认）
#   --all            包括需手动重装的项目（rustup/vscode扩展/venv等）
#   --workspace-only 仅清理 workspace 下的构建产物
#   --dry-run        预览模式，只统计不删除
# ============================================================

set -euo pipefail

WORKSPACE="/home/zhengxueen/workspace"
FREED_BYTES=0
DRY_RUN=false

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
info() { echo -e "${CYAN}[i]${NC} $1"; }

# 计算目录大小（字节），不存在则返回 0
dir_size() {
    if [ -d "$1" ]; then
        du -sb "$1" 2>/dev/null | awk '{print $1}'
    else
        echo 0
    fi
}

# 格式化字节数为人类可读
human() {
    local b=$1
    if [ "$b" -ge 1073741824 ]; then
        awk "BEGIN {printf \"%.1f GB\", $b/1073741824}"
    elif [ "$b" -ge 1048576 ]; then
        awk "BEGIN {printf \"%.1f MB\", $b/1048576}"
    elif [ "$b" -ge 1024 ]; then
        awk "BEGIN {printf \"%.1f KB\", $b/1024}"
    else
        echo "${b} B"
    fi
}

# 安全删除：先统计大小，再删除，最后累加
clean_dir() {
    local path="$1"
    local label="$2"
    if [ -d "$path" ]; then
        local sz
        sz=$(dir_size "$path")
        FREED_BYTES=$((FREED_BYTES + sz))
        if [ "$DRY_RUN" = true ]; then
            info "[预览] 将清理 ${label} ($(human $sz))"
        else
            rm -rf "$path"
            log "已清理 ${label} ($(human $sz))"
        fi
    else
        info "跳过 ${label}（不存在）"
    fi
}

# ============================================================
# 解析参数
# ============================================================
MODE="safe"
for arg in "$@"; do
    case "$arg" in
        --all)           MODE="all" ;;
        --workspace-only) MODE="workspace-only" ;;
        --safe)          MODE="safe" ;;
        --dry-run)       DRY_RUN=true ;;
        *)
            echo "用法: bash clean-cache.sh [--safe|--all|--workspace-only|--dry-run]"
            echo "  --safe           仅清理可自动重建的缓存（默认）"
            echo "  --all            包括需手动重装的项目（rustup/vscode扩展/venv等）"
            echo "  --workspace-only 仅清理 workspace 下的构建产物"
            echo "  --dry-run        预览模式，只统计不删除（可与其他模式组合）"
            exit 1
            ;;
    esac
done

echo "=========================================="
if [ "$DRY_RUN" = true ]; then
    echo "  缓存清理脚本  模式: ${MODE} [预览]"
else
    echo "  缓存清理脚本  模式: ${MODE}"
fi
echo "=========================================="
echo ""

# ============================================================
# 1. Workspace 构建产物清理
# ============================================================
if [ "$MODE" != "workspace-only" ] || [ "$MODE" = "workspace-only" ]; then
    info "=== 清理 workspace 构建产物 ==="

    WS_DIRS="node_modules debug target __pycache__"
    for d in $WS_DIRS; do
        # 统计总大小
        total=0
        while IFS= read -r dirpath; do
            s=$(dir_size "$dirpath")
            total=$((total + s))
        done < <(find "$WORKSPACE" -type d -name "$d" -not -path "*/.git/*" 2>/dev/null)

        if [ "$total" -gt 0 ]; then
            find "$WORKSPACE" -type d -name "$d" -not -path "*/.git/*" -exec rm -rf {} + 2>/dev/null || true
            FREED_BYTES=$((FREED_BYTES + total))
            log "已清理 ${d}/ ($(human $total))"
        else
            info "跳过 ${d}/（不存在）"
        fi
    done

    # --all 模式额外清理：.venv / venv / dist / build / .next
    OPTIONAL_WS_DIRS=".venv venv dist build .next .nuxt .svelte-kit .output"
    for d in $OPTIONAL_WS_DIRS; do
        total=0
        while IFS= read -r dirpath; do
            s=$(dir_size "$dirpath")
            total=$((total + s))
        done < <(find "$WORKSPACE" -maxdepth 5 -type d -name "$d" -not -path "*/.git/*" -not -path "*/node_modules/*" 2>/dev/null)

        if [ "$total" -gt 0 ]; then
            if [ "$MODE" = "all" ]; then
                if [ "$DRY_RUN" = true ]; then
                    info "[预览] 将清理 ${d}/ 共 $(human $total)"
                else
                    find "$WORKSPACE" -maxdepth 5 -type d -name "$d" -not -path "*/.git/*" -not -path "*/node_modules/*" -exec rm -rf {} + 2>/dev/null || true
                    log "已清理 ${d}/ ($(human $total))"
                fi
                FREED_BYTES=$((FREED_BYTES + total))
            else
                warn "发现 ${d}/ 共 $(human $total)（加 --all 可清理）"
            fi
        fi
    done

    echo ""
fi

# ============================================================
# 2. 安全缓存清理（可自动重建）
# ============================================================
if [ "$MODE" != "workspace-only" ]; then
    info "=== 清理可自动重建的缓存 ==="

    # 包管理器缓存
    clean_dir ~/.npm/_cacache          "npm 缓存"
    clean_dir ~/.cache/uv              "uv 缓存"
    clean_dir ~/.cache/yarn            "yarn 缓存"
    clean_dir ~/.bun/install           "bun 缓存"
    clean_dir ~/.cargo/registry        "Cargo registry 缓存"
    clean_dir ~/.cache/go-build        "Go 构建缓存"
    clean_dir ~/go/pkg                 "Go 模块缓存（go mod download 可重建）"

    # 浏览器缓存
    clean_dir ~/.cache/google-chrome   "Chrome 缓存"
    clean_dir ~/.cache/microsoft-edge  "Edge 缓存"

    # IDE / 工具缓存
    clean_dir ~/.cache/JetBrains       "JetBrains 缓存"
    clean_dir ~/.cache/electron        "electron 缓存"
    clean_dir ~/.cache/node-gyp        "node-gyp 缓存"
    clean_dir ~/.cache/typescript      "TypeScript 缓存"
    clean_dir ~/.cache/tauri           "Tauri 缓存"
    clean_dir ~/.cache/LarkShell       "LarkShell 缓存"
    clean_dir ~/.cache/n8n             "n8n 缓存"
    clean_dir ~/.codeium              "Codeium 缓存"

    # 系统缓存
    clean_dir ~/.cache/thumbnails      "缩略图缓存"
    clean_dir ~/.cache/mesa_shader_cache_db "Mesa shader 缓存"
    clean_dir ~/.cache/mesa_shader_cache    "Mesa shader 缓存"
    clean_dir ~/.cache/fontconfig      "字体缓存"
    clean_dir ~/.cache/comgr           "comgr 缓存"

    # 临时文件
    clean_dir ~/tmp_rocblas_arch       "ROCm 临时构建文件"
    clean_dir ~/.duckdb                "DuckDB 临时文件"
    clean_dir ~/WattToolkit            "Watt Toolkit 缓存"

    # IDE 旧日志（仅清理 logs 子目录，保留配置）
    clean_dir "$HOME/.config/Kiro/logs"     "Kiro 日志"
    clean_dir "$HOME/.config/Trae CN/logs"  "Trae CN 日志"

    echo ""
fi

# ============================================================
# 3. 需手动重装的项（仅 --all 模式）
# ============================================================
if [ "$MODE" = "all" ]; then
    info "=== 清理需手动重装的缓存（--all 模式）==="

    warn "以下项删除后需手动重装："

    clean_dir ~/.rustup/toolchains     "Rustup 工具链（需 rustup install stable 重装）"
    clean_dir ~/.vscode/extensions     "VSCode 扩展（需重新安装扩展）"
    clean_dir ~/.windsurf/extensions   "Windsurf 扩展（需重新安装扩展）"
    clean_dir ~/.config/Code           "VSCode 工作区缓存"
    clean_dir ~/.cache/nvidia          "NVIDIA 缓存"

    # 独立 Python 虚拟环境（workspace 外）
    clean_dir ~/litellm-venv           "litellm 虚拟环境（需 pip install 重建）"
    clean_dir ~/.openclaw/workspace/venv    "OpenClaw venv（需 pip install 重建）"
    clean_dir ~/.openclaw/workspace-qq/venv "OpenClaw-qq venv（需 pip install 重建）"

    # Docker 未使用资源
    if command -v docker &>/dev/null && docker info &>/dev/null; then
        info "Docker 可回收空间："
        docker system df 2>/dev/null || true
        if [ "$DRY_RUN" = true ]; then
            info "[预览] 将执行 docker system prune -f（清理未使用的镜像/容器/网络）"
        else
            warn "执行 docker system prune -f ..."
            docker system prune -f 2>/dev/null || true
        fi
        # 删除旧版 paradedb 镜像（有新版 v0.22.2）
        for img in paradedb/paradedb:v0.21.4-pg17; do
            if docker image inspect "$img" &>/dev/null; then
                if [ "$DRY_RUN" = true ]; then
                    info "[预览] 将删除旧镜像 $img"
                else
                    docker rmi "$img" 2>/dev/null && log "已删除旧镜像 $img" || true
                fi
            fi
        done
    fi

    echo ""
fi

# ============================================================
# 汇总
# ============================================================
echo "=========================================="
echo -e "  清理完成！共释放 ${GREEN}$(human $FREED_BYTES)${NC}"
echo "=========================================="

echo ""
if [ "$DRY_RUN" = true ]; then
    echo "提示: 以上为预览结果，未实际删除。去掉 --dry-run 执行清理。"
fi
if [ "$MODE" = "safe" ]; then
    echo "提示: 使用 --all 可额外清理 venv/rustup/vscode扩展/Docker 等需重装项"
    echo "      使用 --workspace-only 仅清理 workspace 构建产物"
    echo "      使用 --dry-run 预览将清理的内容（可与其他模式组合）"
fi
