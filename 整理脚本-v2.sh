#!/bin/bash
# ==============================================================
# notes 知识库目录整理脚本 v2（修正版）
#
# 相对 v1 的修复：
#   - Phase 1 只创建「父级」目录，避免 mkdir+mv 多嵌套一层
#   - 目录移动前检查源是否存在；归档项可选跳过
#   - 合并目录时包含隐藏文件；整目录改名用 mv 而非 mv 进已存在同名空目录
#   - 纳入 weknora-docs、代理、.trash；整理后更新 .gitignore 中的 RAGFLOW/高中 路径
#   - 支持 --dry-run；检测已整理则退出；回滚说明改为 tar 备份
#
# 原则：只移动，不删除任何文件
#
# 用法：
#   cd /mnt/sata/knowledge/notes
#   bash 整理脚本-v2.sh --dry-run    # 仅打印将执行的操作
#   bash 整理脚本-v2.sh              # 实际执行（执行前请先备份）
# ==============================================================

set -euo pipefail

BASE_DIR="/mnt/sata/knowledge/notes"
DRY_RUN=0
FORCE=0

for arg in "$@"; do
  case "$arg" in
    --dry-run|-n) DRY_RUN=1 ;;
    --force|-f)   FORCE=1 ;;
    -h|--help)
      echo "用法: bash $(basename "$0") [--dry-run] [--force]"
      echo "  --dry-run  只显示计划，不改动文件"
      echo "  --force    即使检测到 ERP系统/ 已存在也继续（慎用）"
      exit 0
      ;;
    *)
      echo "未知参数: $arg" >&2
      exit 1
      ;;
  esac
done

cd "$BASE_DIR"

# ---------- 工具函数 ----------
log()  { echo "$@"; }
ok()   { echo "  ✓ $*"; }
skip() { echo "  ⊘ 跳过（不存在）: $*"; }
plan() { echo "  → $*"; }

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    plan "[dry-run] $*"
  else
    "$@"
  fi
}

# 移动文件或目录；源不存在则跳过
safe_mv() {
  local src=$1
  shift
  local dest=$1
  if [[ ! -e "$src" ]]; then
    skip "$src"
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    plan "mv -- $src -> $dest"
    return 0
  fi
  mv -- "$src" "$dest"
  plan "mv -- $src -> $dest"
}

# 将源目录「全部内容」（含隐藏项）合并进目标目录，再尝试删除空源目录
merge_dir_contents() {
  local src_dir=$1
  local dest_dir=$2
  if [[ ! -d "$src_dir" ]]; then
    skip "$src_dir/"
    return 0
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    plan "merge contents: $src_dir/* -> $dest_dir/"
    return 0
  fi
  mkdir -p "$dest_dir"
  shopt -s dotglob nullglob
  local items=("$src_dir"/*)
  if [[ ${#items[@]} -eq 0 ]]; then
    shopt -u dotglob nullglob
    skip "$src_dir/ (空目录)"
    return 0
  fi
  mv -- "$src_dir"/* "$dest_dir"/
  shopt -u dotglob nullglob
  rmdir "$src_dir" 2>/dev/null || true
  plan "merged: $src_dir/ -> $dest_dir/"
}

# 整目录迁移：目标不存在则改名；目标已存在则合并内容
move_dir() {
  local src=$1
  local dest=$2
  if [[ ! -e "$src" ]]; then
    skip "$src"
    return 0
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    if [[ -e "$dest" ]]; then
      plan "merge dir: $src/ -> $dest/"
    else
      plan "mv dir: $src -> $dest"
    fi
    return 0
  fi
  if [[ -e "$dest" ]]; then
    merge_dir_contents "$src" "$dest"
  else
    mkdir -p "$(dirname "$dest")"
    mv -- "$src" "$dest"
    plan "mv dir: $src -> $dest"
  fi
}

# ---------- 启动检查 ----------
echo "=========================================="
echo "  notes 知识库整理 v2"
echo "  工作目录: $BASE_DIR"
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "  模式: dry-run（不改动文件）"
else
  echo "  模式: 执行"
fi
echo "=========================================="

if [[ -d "ERP系统" && "$FORCE" -ne 1 ]]; then
  echo ""
  echo "检测到 ERP系统/ 已存在，可能已整理过。" >&2
  echo "若确需再次执行，请使用: bash $(basename "$0") --force" >&2
  echo "建议先: tar czf ../notes-backup-\$(date +%Y%m%d).tar.gz -C .. notes" >&2
  exit 1
fi

if [[ "$DRY_RUN" -ne 1 ]]; then
  echo ""
  echo "⚠️  执行前请自行备份整个 notes 目录（Git 无法恢复 gitignore 内的大文件）。"
  echo "    示例: tar czf /mnt/sata/knowledge/notes-backup-\$(date +%Y%m%d).tar.gz -C /mnt/sata/knowledge notes"
  echo ""
  read -r -p "已备份或确认风险，输入 yes 继续: " confirm
  if [[ "$confirm" != "yes" ]]; then
    echo "已取消。"
    exit 0
  fi
fi

# ==============================================================
# Phase 1: 仅创建父级与归档骨架（不预建与源同名的叶子目录）
# ==============================================================
echo ""
echo "[Phase 1/6] 创建目标父级目录..."

# 注意：不要预建「开发运维」（需由 开发-运维 整目录改名而来）
for d in \
  ERP系统 \
  AI基础设施 \
  系统运维 \
  开发相关 \
  规范与模板 \
  项目文档 \
  学习资料 \
  个人工具 \
  脚本工具 \
  _归档/OpenClaw \
  _归档/n8n \
  _归档/Git \
  _归档/脚本 \
  _归档/系统配置 \
  _归档/obsidian-trash
do
  if [[ "$DRY_RUN" -eq 1 ]]; then
    plan "mkdir -p $d"
  else
    mkdir -p "$d"
  fi
done
ok "父级目录就绪"

# ==============================================================
# Phase 2: 归档备份与冗余副本
# ==============================================================
echo ""
echo "[Phase 2/6] 归档备份与冗余文件..."

safe_mv "openclaw/openclaw (备份).json" "_归档/OpenClaw/"
safe_mv "n8n/n8n_jsons/bak" "_归档/n8n/"
safe_mv "git-notes/_archived" "_归档/Git/"
safe_mv "ubuntu-system/bashrc (副本)" "_归档/系统配置/"
safe_mv "git-notes/git-commit.js" "_归档/脚本/git-commit.js.来自git-notes"
safe_mv "通用模板/git-commit.js" "_归档/脚本/git-commit.js.来自通用模板"

# 跨目录重复文档：保留两份，仅在归档中记录第二份路径（不删除）
if [[ -f "llama-cpp/新版llama.cpp-gfx906三角求解solve修复.md" && -f "rocm/新版llama.cpp-gfx906三角求解solve修复.md" ]]; then
  plan "ℹ 重复文档保留两份: llama-cpp/ 与 rocm/ 各有一份 gfx906 修复说明"
fi

ok "归档阶段完成"

# ==============================================================
# Phase 3: 移动目录与文件
# ==============================================================
echo ""
echo "[Phase 3/6] 移动目录到新位置..."

# -- ERP：合并内容后删除空壳
if [[ -d "ERP" ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    plan "merge contents: ERP/* -> ERP系统/"
  else
    merge_dir_contents "ERP" "ERP系统"
  fi
else
  skip "ERP/"
fi

# -- AI 基础设施（目标名与 mv 一致，避免 RAGFLOW/RAGFLOW 嵌套）
move_dir "llama-cpp"   "AI基础设施/llama-cpp"
move_dir "rocm"        "AI基础设施/ROCm"
move_dir "vllm"        "AI基础设施/vllm"
move_dir "RAGFLOW"     "AI基础设施/RAGFlow"
move_dir "openclaw"    "AI基础设施/OpenClaw"
move_dir "n8n"         "AI基础设施/n8n"
move_dir "claude_code" "AI基础设施/Claude代码"
move_dir "weknora-docs" "AI基础设施/weknora-docs"
safe_mv "mi50_stress" "AI基础设施/ROCm/"

# -- 系统运维
move_dir "ubuntu-system" "系统运维/ubuntu-system"
move_dir "ubuntu-tools"  "系统运维/ubuntu-tools"

# -- 开发运维：整目录改名（不要先 mkdir 开发运维/子目录）
move_dir "开发-运维" "开发运维"

if [[ "$DRY_RUN" -eq 1 ]]; then
  plan "mv: 开发运维/Nginx 配置与访问方式指南.md -> 开发运维/Nginx/ (若存在)"
else
  if [[ -f "开发运维/Nginx 配置与访问方式指南.md" ]]; then
    mkdir -p "开发运维/Nginx"
    safe_mv "开发运维/Nginx 配置与访问方式指南.md" "开发运维/Nginx/"
  fi
fi

# -- 开发相关
move_dir "git-notes" "开发相关/git-notes"
move_dir "coding"    "开发相关/coding"
move_dir "rust"      "开发相关/rust"

# -- 规范与模板
move_dir "spec-guides" "规范与模板/spec-guides"
move_dir "kiro"        "规范与模板/kiro"
move_dir "指南"        "规范与模板/指南"
move_dir "通用模板"    "规范与模板/通用模板"

# -- 项目文档
if [[ -d "项目相关文档" ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    plan "merge contents: 项目相关文档/* -> 项目文档/"
  else
    merge_dir_contents "项目相关文档" "项目文档"
  fi
else
  skip "项目相关文档/"
fi

# -- 学习资料
move_dir "PLC" "学习资料/PLC"

# -- 个人工具（勿预建 VPN/账号 空目录）
if [[ "$DRY_RUN" -eq 1 ]]; then
  for x in VPN 账号 自用工具 代理; do
    [[ -e "$x" ]] && plan "mv: $x -> 个人工具/"
  done
  [[ -f "emails.md" ]] && plan "mv: emails.md -> 个人工具/"
else
  mkdir -p "个人工具"
  for x in VPN 账号 自用工具 代理; do
    [[ -e "$x" ]] && safe_mv "$x" "个人工具/"
  done
  [[ -f "emails.md" ]] && safe_mv "emails.md" "个人工具/"
fi

# -- 脚本
safe_mv "scripts/git-commit.js" "脚本工具/git-commit.js"
if [[ "$DRY_RUN" -ne 1 && -d "scripts" ]]; then
  rmdir "scripts" 2>/dev/null || plan "ℹ scripts/ 非空，保留目录"
fi

# -- Obsidian 回收站 -> 归档（保留全部内容）
move_dir ".trash" "_归档/obsidian-trash"

# -- 空目录 comfyui：仅加说明文件（不删目录）
if [[ -d "comfyui" ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    plan "touch comfyui/README.md (占位说明，若不存在)"
  else
    if [[ ! -f "comfyui/README.md" ]]; then
      cat > "comfyui/README.md" << 'EOF'
# ComfyUI

占位目录：后续 ComfyUI 相关笔记可放在此目录。
EOF
      plan "created comfyui/README.md"
    fi
  fi
fi

ok "目录移动完成"

# ==============================================================
# Phase 4: 同名文件扫描（仅报告，不自动删改）
# ==============================================================
echo ""
echo "[Phase 4/6] 扫描跨目录同名 .md（仅提示）..."

if [[ "$DRY_RUN" -ne 1 ]]; then
  dupes=$(find ERP系统 AI基础设施 系统运维 开发运维 开发相关 规范与模板 项目文档 学习资料 个人工具 \
    -type f -name '*.md' 2>/dev/null | sed 's|.*/||' | sort | uniq -d | head -10)
  if [[ -n "${dupes:-}" ]]; then
    echo "  以下文件名在多个子目录中出现（保留全部，请自行决定是否加交叉链接）："
    echo "$dupes" | sed 's/^/    /'
  else
    echo "  未发现需特别提醒的跨目录重名 .md"
  fi
else
  plan "skip dupe scan in dry-run"
fi

# ==============================================================
# Phase 5: 更新 .gitignore 中的教材库路径
# ==============================================================
echo ""
echo "[Phase 5/6] 更新 .gitignore（RAGFLOW/高中 路径）..."

OLD_IGNORE='RAGFLOW/高中'
NEW_IGNORE='AI基础设施/RAGFlow/高中'

if [[ -f ".gitignore" ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    plan "sed .gitignore: $OLD_IGNORE -> $NEW_IGNORE"
  else
    if grep -qF "$OLD_IGNORE" .gitignore; then
      sed -i "s|^RAGFLOW/高中$|$NEW_IGNORE|" .gitignore
      ok ".gitignore 已更新: $NEW_IGNORE"
    elif grep -qF "$NEW_IGNORE" .gitignore; then
      ok ".gitignore 已是新路径"
    else
      echo "  ℹ .gitignore 中未找到 $OLD_IGNORE，请手动确认教材库忽略规则"
    fi
  fi
else
  skip ".gitignore"
fi

# ==============================================================
# Phase 6: 生成目录索引 README
# ==============================================================
echo ""
echo "[Phase 6/6] 写入 README.md..."

if [[ "$DRY_RUN" -eq 1 ]]; then
  plan "write README.md"
else
  cat > README.md << 'INDEXEOF'
# 知识库笔记

本仓库按主题域组织（由 `整理脚本-v2.sh` 生成索引，可手工增改）。

| 目录 | 说明 |
|------|------|
| [ERP系统](./ERP系统/) | 用友 NCV6.5 全模块产品手册 |
| [AI基础设施](./AI基础设施/) | llama-cpp / ROCm / vllm / RAGFlow / OpenClaw / n8n / weknora-docs / Claude代码 |
| [系统运维](./系统运维/) | Ubuntu 系统与工具（ubuntu-system、ubuntu-tools） |
| [开发运维](./开发运维/) | 原「开发-运维」：Docker、Nginx、InsForge、skills 等 |
| [开发相关](./开发相关/) | git-notes、coding、rust |
| [规范与模板](./规范与模板/) | spec-guides、kiro、指南、通用模板 |
| [项目文档](./项目文档/) | GangQing、LifeStream 等项目 |
| [学习资料](./学习资料/) | PLC 学习计划等 |
| [个人工具](./个人工具/) | VPN、代理、账号、自用工具（含敏感信息，勿外泄） |
| [脚本工具](./脚本工具/) | 公用脚本（如 git-commit.js） |
| [_归档](./_归档/) | 备份、去重副本、原 Obsidian `.trash`（保留不删） |

## 本地大资源（不进 Git）

- 高中教材 PDF：`AI基础设施/RAGFlow/高中/`（见 `.gitignore`）

## 整理与回滚

- 整理脚本：`整理脚本-v2.sh`（`--dry-run` 预演）
- **回滚**：请用整理前的 `tar` 备份恢复；勿依赖 `git checkout` 恢复未跟踪或已移动的大目录。
INDEXEOF
  ok "README.md 已更新"
fi

# ==============================================================
echo ""
echo "=========================================="
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "  dry-run 完成（未改动任何文件）"
  echo "  确认无误后执行: bash 整理脚本-v2.sh"
else
  echo "  整理完成"
  echo ""
  echo "  建议检查:"
  echo "    ls -la AI基础设施/RAGFlow/高中 | head"
  echo "    ls -la 开发运维/"
  echo "    git status"
fi
echo ""
echo "  回滚请使用整理前创建的 tar 备份，例如:"
echo "    tar xzf /path/to/notes-backup-YYYYMMDD.tar.gz -C /mnt/sata/knowledge"
echo "=========================================="
