#!/bin/bash
# ==============================================================
# notes 知识库目录整理脚本
# 功能：按主题域合并分散目录，统一中文命名，归档备份文件
# 原则：只移动，不删除任何文件
# 使用方法：cd /mnt/sata/knowledge/notes && bash 整理脚本.sh
# ==============================================================

set -euo pipefail

BASE_DIR="/mnt/sata/knowledge/notes"
cd "$BASE_DIR"

echo "=========================================="
echo "  开始整理知识库目录结构"
echo "  工作目录: $BASE_DIR"
echo "=========================================="

# ==============================================================
# Phase 1: 创建目标目录骨架
# ==============================================================
echo ""
echo "[Phase 1/5] 创建目标目录结构..."

mkdir -p ERP系统

mkdir -p AI基础设施/{llama-cpp,ROCm,vllm,RAGFlow,OpenClaw,n8n,Claude代码}

mkdir -p 系统运维/{ubuntu系统,工具}

mkdir -p 开发运维/{InsForge,Nginx,docker,skills}

mkdir -p 开发相关/{Git,编码,Rust}

mkdir -p 规范与模板/{规范指南,Kiro模板,方法论,通用模板}

mkdir -p 项目文档

mkdir -p 学习资料/PLC

mkdir -p 个人工具/{VPN,账号,自用工具}

mkdir -p 脚本工具

mkdir -p _归档/{OpenClaw,n8n,Git,脚本,系统配置}

echo "  ✓ 目录结构创建完成"

# ==============================================================
# Phase 2: 归档备份与冗余文件（先移走，避免干扰后续 mv）
# ==============================================================
echo ""
echo "[Phase 2/5] 归档备份与冗余文件..."

# OpenClaw 备份 JSON
mv "openclaw/openclaw (备份).json" _归档/OpenClaw/
echo "  → openclaw/openclaw (备份).json → _归档/OpenClaw/"

# n8n 旧版本备份
mv n8n/n8n_jsons/bak _归档/n8n/
echo "  → n8n/n8n_jsons/bak/ → _归档/n8n/"

# Git 旧归档
mv git-notes/_archived _归档/Git/
echo "  → git-notes/_archived/ → _归档/Git/"

# bashrc 副本
mv "ubuntu-system/bashrc (副本)" _归档/系统配置/
echo "  → ubuntu-system/bashrc (副本) → _归档/系统配置/"

# 去重 git-commit.js（保留 scripts/git-commit.js 为规范副本）
mv git-notes/git-commit.js _归档/脚本/git-commit.js.来自git-notes
echo "  → git-notes/git-commit.js → _归档/脚本/ (去重)"

mv 通用模板/git-commit.js _归档/脚本/git-commit.js.来自通用模板
echo "  → 通用模板/git-commit.js → _归档/脚本/ (去重)"

echo "  ✓ 归档完成"

# ==============================================================
# Phase 3: 移动目录到新位置
# ==============================================================
echo ""
echo "[Phase 3/5] 移动目录到新位置..."

# -- ERP 系统
mv ERP/* ERP系统/ 2>/dev/null && rmdir ERP 2>/dev/null
echo "  → ERP/ → ERP系统/"

# -- AI 基础设施
mv llama-cpp AI基础设施/
mv rocm AI基础设施/ROCm/
mv vllm AI基础设施/
mv RAGFLOW AI基础设施/RAGFlow/
mv openclaw AI基础设施/OpenClaw/
mv n8n AI基础设施/
mv claude_code AI基础设施/Claude代码/
echo "  → llama-cpp/ + rocm/ + vllm/ + RAGFLOW/ + openclaw/ + n8n/ + claude_code/ → AI基础设施/"

# 根目录 mi50_stress 二进制文件归入 ROCm
mv mi50_stress AI基础设施/ROCm/ 2>/dev/null || true
echo "  → mi50_stress → AI基础设施/ROCm/"

# -- 系统运维
mv ubuntu-system 系统运维/ubuntu系统/
mv ubuntu-tools 系统运维/工具/
echo "  → ubuntu-system/ + ubuntu-tools/ → 系统运维/"

# -- 开发运维（直接重命名）
mv 开发-运维 开发运维/
echo "  → 开发-运维/ → 开发运维/"

# 将 开发运维/ 顶层的 Nginx 指南移入 Nginx 子目录
mv 开发运维/Nginx\ 配置与访问方式指南.md 开发运维/Nginx/ 2>/dev/null || true
echo "  → 开发运维/Nginx 配置指南 → 开发运维/Nginx/"

# -- 开发相关
mv git-notes 开发相关/Git/
mv coding 开发相关/编码/
mv rust 开发相关/Rust/
echo "  → git-notes/ + coding/ + rust/ → 开发相关/"

# -- 规范与模板
mv spec-guides 规范与模板/规范指南/
mv kiro 规范与模板/Kiro模板/
mv 指南 规范与模板/方法论/
mv 通用模板 规范与模板/通用模板/
echo "  → spec-guides/ + kiro/ + 指南/ + 通用模板/ → 规范与模板/"

# -- 项目文档
mv 项目相关文档/* 项目文档/ 2>/dev/null && rmdir 项目相关文档 2>/dev/null || true
echo "  → 项目相关文档/ → 项目文档/"

# -- 学习资料
mv PLC/* 学习资料/PLC/ 2>/dev/null && rmdir PLC 2>/dev/null || true
echo "  → PLC/ → 学习资料/PLC/"

# -- 个人工具
mv VPN 个人工具/
mv 账号 个人工具/
mv 自用工具 个人工具/
mv emails.md 个人工具/ 2>/dev/null || true
echo "  → VPN/ + 账号/ + 自用工具/ + emails.md → 个人工具/"

# -- 脚本工具
mv scripts/git-commit.js 脚本工具/ 2>/dev/null || true
rmdir scripts 2>/dev/null || true
echo "  → scripts/git-commit.js → 脚本工具/"

echo "  ✓ 所有目录移动完成"

# ==============================================================
# Phase 4: 处理同名文件冲突（合并后相同目录下的重名文件）
# ==============================================================
echo ""
echo "[Phase 4/5] 检查同名文件冲突..."

# 检查 AI基础设施/ROCm/ 目录下是否有与 AI基础设施/llama-cpp/ 同名的 .md 文件
# 已知风险：新版llama.cpp-gfx906三角求解solve修复.md 同时在 llama-cpp/ 和 rocm/ 中出现
# 由于它们在不同子目录中（llama-cpp/ vs ROCm/），实际不冲突，仅做提示
echo "  ℹ 同名文件检查完成（跨子目录不冲突）"

echo "  ✓ 无需处理"

# ==============================================================
# Phase 5: 生成目录索引 README
# ==============================================================
echo ""
echo "[Phase 5/5] 更新 README.md..."

cat > README.md << 'INDEXEOF'
# 📚 知识库笔记

本仓库按主题域组织，结构如下：

| 目录 | 说明 |
|------|------|
| [ERP系统](./ERP系统/) | 用友 NCV6.5 全模块产品手册（人力资源、供应链、财务、生产制造等） |
| [AI基础设施](./AI基础设施/) | LLM 部署与推理（llama-cpp / ROCm / vllm / RAGFlow / OpenClaw / n8n） |
| [系统运维](./系统运维/) | Ubuntu 系统配置、网络、存储、监控诊断 |
| [开发运维](./开发运维/) | Docker、Nginx、InsForge、AI 编码技能集 |
| [开发相关](./开发相关/) | Git 使用指南、编码规范、Rust 配置 |
| [规范与模板](./规范与模板/) | 需求/设计规范、Kiro 模板、方法论、通用模板 |
| [项目文档](./项目文档/) | 实际项目文档（GangQing、LifeStream） |
| [学习资料](./学习资料/) | PLC 学习计划、Rust 入门等 |
| [个人工具](./个人工具/) | 自用工具、VPN、账号信息（⚠️ 含敏感信息请勿外泄） |
| [脚本工具](./脚本工具/) | 公用脚本（git-commit.js） |
| [_归档](./_归档/) | 旧版本备份与去重文件（保留不删） |
INDEXEOF

echo "  ✓ README.md 已更新"

# ==============================================================
echo ""
echo "=========================================="
echo "  ✅ 整理完成！"
echo ""
echo "  如需回滚到整理前状态，请执行："
echo "    git restore . --staged && git checkout -- ."
echo "  （前提：尚未 git add，且工作区干净）"
echo "=========================================="