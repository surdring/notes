# Git 操作日志（notes 仓库清理与推送）

时间：2026-01-06（UTC+08:00）
仓库路径：`/mnt/sata/knowledge/notes`
远程仓库：`https://github.com/surdring/notes.git`

## 背景
- 初始 `git push` 报错：未配置推送目标（无 remote）。
- 添加远程 `origin` 后，首次推送被拒绝（远端包含本地没有的提交）。
- 用户选择使用强制推送覆盖远端，并随后发现仓库内包含大量（约 4000）对象/文件，怀疑上传了不该上传的内容。

## 关键命令与结果摘要

### 1) 配置远程仓库
```bash
git remote -v
# 无输出

git remote add origin https://github.com/surdring/notes.git
git remote -v
# origin  https://github.com/surdring/notes.git (fetch)
# origin  https://github.com/surdring/notes.git (push)
```

### 2) 处理远端非快进导致的推送拒绝
（当时选择强推覆盖远端）
```bash
git push -f origin main
```

### 3) 发现仓库对象较多、清理历史（重写 Git 历史）
安装 `git-filter-repo`（系统包）：
```bash
sudo apt update
sudo apt install git-filter-repo

git filter-repo --help
```

从 **整个 Git 历史** 删除不需要的路径：
```bash
git filter-repo --force --path .trash/ --invert-paths

git filter-repo --force --path .obsidian/plugins/ --invert-paths

git filter-repo --force --path llama.cpp-master.zip --invert-paths
```

### 4) filter-repo 后远程被移除，重新添加并强推
`git-filter-repo` 默认会移除 `origin`：
```bash
git remote -v
# 无输出
```

重新添加并强制推送清理后的历史：
```bash
git remote add origin https://github.com/surdring/notes.git

git push --force origin main
git push --force origin --tags
```

### 5) 防止未来再次提交不需要内容（.gitignore）
已在 `.gitignore` 中加入（至少）：
- `.trash/`
- `.obsidian/plugins/`
- `*.zip`

并推送到远端。

### 6) 验证（本地当前追踪文件中不再包含这些路径）
```bash
git ls-files | grep -E '^\.trash/|^\.obsidian/plugins/|\.zip$'
# 无输出表示这些内容已不再被 Git 跟踪
```

## 重要注意事项
- `git filter-repo` 会 **重写历史**，后续其它机器上的旧克隆仓库建议重新 `git clone`，避免把旧历史带回。
- 如果未来仍想同步 `.obsidian` 的部分配置，建议只保留你需要的文件，避免同步 `workspace.json` 这类强依赖本机路径/布局的配置（按你的使用习惯决定）。
