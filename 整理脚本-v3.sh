#!/bin/bash
# ==============================================================
# notes 知识库目录整理脚本 v3
#
# 功能：按主题域合并分散目录，统一中文命名，归档备份文件
# 原则：只移动，不删除任何文件
#
# 相对 v1 的修复：
#   - Phase 1 只建「父容器」不建「叶子目录」，彻底避免 mkdir+mv 多嵌套一层
#   - 所有 mv 前检查源是否存在
#   - 合并目录时包含隐藏文件（dotglob）
#   - 子目录名统一为中文
#   - 纳入 weknora-docs、代理、windsurf.json 等遗漏项
#   - 支持 --dry-run 预演
#   - 已整理检测 + tar 备份提醒
#   - 自动更新 .gitignore 中的 RAGFLOW/高中 路径
#   - 旧版本整理脚本自动归档
#
# 用法：
#   cd /mnt/sata/knowledge/notes
#   bash 整理脚本-v3.sh --dry-run       # 仅打印操作计划
#   bash 整理脚本-v3.sh                 # 实际执行
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
      echo "  --force    即使检测到已整理也继续执行（慎用）"
      exit 0
      ;;
    *) echo "未知参数: $arg" >&2; exit 1 ;;
  esac
done

cd "$BASE_DIR"

# ===================== 工具函数 =====================
plan()  { echo "  → $*"; }
ok()    { echo "  ✓ $*"; }
skip()  { echo "  ⊘ 跳过（不存在）: $*"; }

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    plan "[DRY-RUN] $*"
  else
    "$@"
  fi
}

# 安全移动：源不存在则跳过
safe_mv() {
  local src=$1 dest=$2
  if [[ ! -e "$src" ]]; then
    skip "$src"
    return 0
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    plan "mv $src → $dest"
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  mv -- "$src" "$dest"
  ok "$src → $dest"
}

# 合并目录内容：将 src_dir 下所有文件（含隐藏）移入 dest_dir，然后删除空 src_dir
merge_dir_contents() {
  local src_dir=$1 dest_dir=$2
  if [[ ! -d "$src_dir" ]]; then
    skip "$src_dir/"
    return 0
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    plan "合并内容: $src_dir/* → $dest_dir/"
    return 0
  fi
  mkdir -p "$dest_dir"
  shopt -s dotglob nullglob
  local items=("$src_dir"/*)
  if [[ ${#items[@]} -eq 0 ]]; then
    shopt -u dotglob nullglob
    skip "$src_dir/（空目录）"
    return 0
  fi
  mv -- "$src_dir"/* "$dest_dir"/
  shopt -u dotglob nullglob
  rmdir "$src_dir" 2>/dev/null || plan "ℹ $src_dir 非空，保留"
  ok "$src_dir/ 内容合并到 $dest_dir/"
}

# 智能移动目录：
#   - 若目标不存在 → 直接改名搬移（mv src dest）
#   - 若目标已存在 → 合并内容（mv src/* dest/ + rmdir src）
move_dir() {
  local src=$1 dest=$2
  if [[ ! -e "$src" ]]; then
    skip "$src"
    return 0
  fi
  if [[ -e "$dest" ]]; then
    merge_dir_contents "$src" "$dest"
  else
    if [[ "$DRY_RUN" -eq 1 ]]; then
      plan "mv $src → $dest"
      return 0
    fi
    mkdir -p "$(dirname "$dest")"
    mv -- "$src" "$dest"
    ok "$src/ → $dest/"
  fi
}

# ===================== 启动检查 =====================
echo "=========================================="
echo "  notes 知识库整理 v3"
echo "  工作目录: $BASE_DIR"
[[ "$DRY_RUN" -eq 1 ]] && echo "  模式: dry-run（不改动文件）" || echo "  模式: 执行"
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
  echo "⚠️  执行前请自行备份整个 notes 目录。"
  echo "    示例:"
  echo "      tar czf /mnt/sata/knowledge/notes-backup-\$(date +%Y%m%d).tar.gz \\"
  echo "           -C /mnt/sata/knowledge notes"
  echo ""
  read -r -p "已备份或确认风险，输入 yes 继续: " confirm
  if [[ "$confirm" != "yes" ]]; then
    echo "已取消。"
    exit 0
  fi
fi

# ==============================================================
# Phase 1: 创建目标父容器（不预建与源同名的叶子目录）
# ==============================================================
echo ""
echo "[Phase 1/7] 创建目标父级目录..."

for d in \
  ERP系统 \
  AI基础设施 \
  系统运维 \
  开发相关 \
  规范与模板 \
  项目文档 \
  学习资料 \
  个人工具 \
  _归档/OpenClaw \
  _归档/n8n \
  _归档/Git \
  _归档/脚本 \
  _归档/系统配置
do
  run mkdir -p "$d"
done

# 注意：开发运维/ 和 脚本工具/ 不在此建，
#       它们分别由 开发-运维/ 和 scripts/ 整目录改名而来

ok "父级目录就绪"

# ==============================================================
# Phase 2: 归档备份与冗余文件
# ==============================================================
echo ""
echo "[Phase 2/7] 归档备份与冗余文件..."

safe_mv "openclaw/openclaw (备份).json"    "_归档/OpenClaw/openclaw (备份).json"
safe_mv "n8n/n8n_jsons/bak"               "_归档/n8n/bak"
safe_mv "git-notes/_archived"             "_归档/Git/_archived"
safe_mv "ubuntu-system/bashrc (副本)"      "_归档/系统配置/bashrc (副本)"
safe_mv "git-notes/git-commit.js"         "_归档/脚本/git-commit.js.来自Git目录"
safe_mv "通用模板/git-commit.js"           "_归档/脚本/git-commit.js.来自通用模板"
safe_mv "整理脚本.sh"                     "_归档/脚本/整理脚本-v1.sh"
safe_mv "整理脚本-v2.sh"                  "_归档/脚本/整理脚本-v2.sh"

# 跨目录重复文档：仅提示，不做删改
if [[ -f "llama-cpp/新版llama.cpp-gfx906三角求解solve修复.md" && \
     -f "rocm/新版llama.cpp-gfx906三角求解solve修复.md" ]]; then
  plan "ℹ 两处各有同名文档 gfx906 修复说明，保留两份，路径如下："
  plan "   AI基础设施/llama-cpp/新版llama.cpp-gfx906三角求解solve修复.md"
  plan "   AI基础设施/ROCm/新版llama.cpp-gfx906三角求解solve修复.md"
fi

ok "归档阶段完成"

# ==============================================================
# Phase 3: 移动目录到新位置
# ==============================================================
echo ""
echo "[Phase 3/7] 移动目录到新位置..."

# -- ERP 系统（合并内容）
merge_dir_contents "ERP" "ERP系统"

# -- AI 基础设施
move_dir "llama-cpp"    "AI基础设施/llama-cpp"
move_dir "rocm"         "AI基础设施/ROCm"
move_dir "vllm"         "AI基础设施/vllm"
move_dir "RAGFLOW"      "AI基础设施/RAGFlow"
move_dir "openclaw"     "AI基础设施/OpenClaw"
move_dir "n8n"          "AI基础设施/n8n"
move_dir "claude_code"  "AI基础设施/Claude代码"
move_dir "weknora-docs" "AI基础设施/WeKnora文档"

# mi50_stress 二进制文件归入 ROCm
safe_mv "mi50_stress" "AI基础设施/ROCm/mi50_stress"

# -- 系统运维
move_dir "ubuntu-system" "系统运维/Ubuntu系统"
move_dir "ubuntu-tools"  "系统运维/工具"

# -- 开发运维（整目录改名，不会嵌套）
move_dir "开发-运维" "开发运维"

# 将 开发运维/ 顶层 Nginx 指南移入 Nginx 子目录
if [[ -f "开发运维/Nginx 配置与访问方式指南.md" ]]; then
  safe_mv "开发运维/Nginx 配置与访问方式指南.md" "开发运维/Nginx/Nginx 配置与访问方式指南.md"
fi

# -- 开发相关
move_dir "git-notes" "开发相关/Git"
move_dir "coding"    "开发相关/编码"
move_dir "rust"      "开发相关/Rust"

# -- 规范与模板
move_dir "spec-guides" "规范与模板/规范指南"
move_dir "kiro"        "规范与模板/Kiro模板"
move_dir "指南"        "规范与模板/方法论"
move_dir "通用模板"    "规范与模板/通用模板"

# -- 项目文档
merge_dir_contents "项目相关文档" "项目文档"

# -- 学习资料
move_dir "PLC" "学习资料/PLC"

# -- 个人工具（不预建 VPN/账号/代理 等空目录，避免嵌套）
if [[ "$DRY_RUN" -eq 1 ]]; then
  for x in VPN 账号 自用工具 代理; do
    [[ -e "$x" ]] && plan "mv $x → 个人工具/"
  done
  [[ -f "emails.md" ]] && plan "mv emails.md → 个人工具/"
else
  mkdir -p "个人工具"
  for x in VPN 账号 自用工具 代理; do
    [[ -e "$x" ]] && safe_mv "$x" "个人工具/"
  done
  [[ -f "emails.md" ]] && safe_mv "emails.md" "个人工具/"
fi

# -- 脚本工具（整目录改名）
move_dir "scripts" "脚本工具"

ok "目录移动完成"

# ==============================================================
# Phase 4: 扫描同名文件（仅报告）
# ==============================================================
echo ""
echo "[Phase 4/7] 扫描跨目录同名 .md（仅提示）..."

if [[ "$DRY_RUN" -ne 1 ]]; then
  dupes=$(find AI基础设施 系统运维 开发运维 开发相关 规范与模板 项目文档 学习资料 个人工具 \
    -type f -name '*.md' 2>/dev/null \
    | sed 's|.*/||' | sort | uniq -d | head -10)
  if [[ -n "${dupes:-}" ]]; then
    echo "  以下文件名在多个子目录中出现（保留全部，建议加交叉链接）："
    echo "$dupes" | sed 's/^/    /'
  else
    echo "  未发现需特别提醒的跨目录重名 .md"
  fi
fi

# ==============================================================
# Phase 5: 检查空壳目录（来自 merge 后残留）
# ==============================================================
echo ""
echo "[Phase 5/7] 检查是否有空壳目录残留..."

if [[ "$DRY_RUN" -ne 1 ]]; then
  leftovers=0
  for d in ERP 项目相关文档 PLC scripts; do
    if [[ -d "$d" ]]; then
      if [[ -z "$(ls -A "$d" 2>/dev/null)" ]]; then
        rmdir "$d" 2>/dev/null || true
        ok "移除空壳目录: $d/"
      else
        plan "ℹ $d/ 非空，保留（请手动检查）"
        leftovers=$((leftovers + 1))
      fi
    fi
  done
  if [[ "$leftovers" -eq 0 ]]; then
    ok "无残留空壳目录"
  fi
fi

# ==============================================================
# Phase 6: 更新 .gitignore
# ==============================================================
echo ""
echo "[Phase 6/7] 更新 .gitignore 路径..."

OLD_IGNORE='RAGFLOW/高中'
NEW_IGNORE='AI基础设施/RAGFlow/高中'
IGNORE_FILE=".gitignore"

if [[ -f "$IGNORE_FILE" ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    plan "sed: $OLD_IGNORE → $NEW_IGNORE"
  else
    if grep -qF "$OLD_IGNORE" "$IGNORE_FILE"; then
      sed -i "s|^RAGFLOW/高中$|$NEW_IGNORE|" "$IGNORE_FILE"
      ok ".gitignore 已更新: $NEW_IGNORE"
    elif grep -qF "$NEW_IGNORE" "$IGNORE_FILE"; then
      ok ".gitignore 已是新路径，无需更新"
    else
      plan "ℹ .gitignore 中未找到 $OLD_IGNORE，请手动确认教材库忽略规则"
    fi
  fi
fi

# ==============================================================
# Phase 7: 写入 README 索引
# ==============================================================
echo ""
echo "[Phase 7/7] 写入 README.md..."

if [[ "$DRY_RUN" -eq 1 ]]; then
  plan "写入 README.md"
else
  cat > README.md << 'INDEXEOF'
# 知识库笔记

本仓库按主题域组织，由 `整理脚本-v3.sh` 整理生成。

| 目录 | 说明 |
|------|------|
| [ERP系统](./ERP系统/) | 用友 NCV6.5 全模块产品手册 |
| [AI基础设施](./AI基础设施/) | llama-cpp / ROCm / vllm / RAGFlow / OpenClaw / n8n / WeKnora文档 / Claude代码 |
| [系统运维](./系统运维/) | Ubuntu系统配置、运维工具 |
| [开发运维](./开发运维/) | Docker、Nginx、InsForge、AI编码技能集 |
| [开发相关](./开发相关/) | Git、编码规范、Rust |
| [规范与模板](./规范与模板/) | 规范指南、Kiro模板、方法论、通用模板 |
| [项目文档](./项目文档/) | GangQing、LifeStream 等项目 |
| [学习资料](./学习资料/) | PLC 学习计划等 |
| [个人工具](./个人工具/) | VPN、代理、账号、自用工具（⚠️ 含敏感信息勿外泄） |
| [脚本工具](./脚本工具/) | 公用脚本（git-commit.js） |
| [_归档](./_归档/) | 备份、去重副本（保留不删） |

## 本地大资源（不进 Git）

- 高中教材 PDF：`AI基础设施/RAGFlow/高中/`（见 `.gitignore`）

## 整理与回滚

- 整理脚本：`_归档/脚本/` 下有历史版本
- **回滚**：请用整理前的 `tar` 备份恢复
INDEXEOF
  ok "README.md 已更新"
fi

# ==============================================================
echo ""
echo "=========================================="
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "  ✦ dry-run 完成（未改动任何文件）"
  echo "  确认无误后执行: bash 整理脚本-v3.sh"
else
  echo "  ✦ 整理完成"
  echo ""
  echo "  建议检查:"
  echo "    ls -la AI基础设施/RAGFlow/"
  echo "    ls -la 开发运维/"
  echo "    git status"
fi
echo ""
echo "  回滚请使用整理前创建的 tar 备份，例如:"
echo "    tar xzf /path/to/notes-backup-YYYYMMDD.tar.gz -C /mnt/sata/knowledge"
echo "=========================================="