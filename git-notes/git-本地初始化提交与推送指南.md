# Git 本地初始化、提交与推送指南（Windows / PowerShell）

> 适用场景：你在本地已有一个项目目录，希望将其初始化为 Git 仓库，并首次提交后推送到 GitHub（或其他 Git 远程仓库）。

## 1. 前置条件

- 已安装 **Git for Windows**
- 能在 PowerShell 中执行 `git --version`
- 你已在 GitHub 上创建好远程仓库（例如：`https://github.com/<你的账号>/<仓库名>`）

## 2. 建议的准备工作（强烈建议）

### 2.1 配置全局身份信息（只需一次）

> 用于写入提交作者信息。

```powershell
git config --global user.name "你的名字"
git config --global user.email "你的邮箱"
```

验证：

```powershell
git config --global --get user.name
git config --global --get user.email
```

### 2.2 准备 `.gitignore`

建议在初始化/提交前就准备好 `.gitignore`，确保以下内容不被提交：

- 依赖目录（如 `node_modules/`）
- 构建产物（如 `dist/`、`build/`）
- 本地配置（如 `.env.local`、`.env.*`）
- IDE/系统文件（如 `.idea/`、`.vscode/`、`Thumbs.db`）

验证 `.gitignore` 是否生效：

```powershell
git status
```

## 3. 初始化本地仓库

进入你的项目目录后执行：

```powershell
git init
```

### 3.1 设置默认分支为 `main`（推荐）

如果你希望默认分支为 `main`：

```powershell
git branch -M main
```

> 说明：
> - `-M` 会强制重命名分支（如果已存在 `master` 或其他默认分支）。

## 4. 首次提交（add + commit）

### 4.1 查看当前状态

```powershell
git status
```

### 4.2 添加文件到暂存区

提交全部文件（常用）：

```powershell
git add .
```

只添加部分文件：

```powershell
git add path/to/file
```

### 4.3 创建提交

```powershell
git commit -m "chore: initial commit"
```

> 提示：
> - 提交信息建议用英文，便于后续检索与协作。

## 5. 关联远程仓库（GitHub）

### 5.1 选择远程地址（HTTPS / SSH）

- HTTPS（最常见）：
  - `https://github.com/<账号>/<仓库>.git`
- SSH（需要提前配置 SSH key）：
  - `git@github.com:<账号>/<仓库>.git`

以下以 HTTPS 为例：

```powershell
git remote add origin https://github.com/<账号>/<仓库>.git
```

验证远程：

```powershell
git remote -v
```

### 5.2 远程已存在时如何处理

如果提示 `remote origin already exists`：

- 查看当前远程：

```powershell
git remote -v
```

- 修改远程地址：

```powershell
git remote set-url origin https://github.com/<账号>/<仓库>.git
```

- 或删除后重加：

```powershell
git remote remove origin
git remote add origin https://github.com/<账号>/<仓库>.git
```

## 6. 推送到远程（首次 push）

```powershell
git push -u origin main
```

> 说明：
> - `-u` 会建立上游跟踪关系，之后你可以直接 `git push` / `git pull`。

### 6.1 GitHub 身份验证（HTTPS 常见问题）

如果你使用 HTTPS 推送，GitHub 通常需要你进行身份验证：

- **推荐使用 Personal Access Token（PAT）** 作为密码
- 不要在代码库中保存 token

如果你使用 Git Credential Manager，系统可能会弹出登录窗口完成授权。

## 7. 推送后验收（建议必做）

### 7.1 查看分支跟踪关系

```powershell
git branch -vv
```

期望看到类似：

- `main ... [origin/main] ...`

### 7.2 查看工作区是否干净

```powershell
git status -sb
```

期望看到类似：

- `## main...origin/main`

### 7.3 访问 GitHub 仓库页面确认

打开：

- `https://github.com/<账号>/<仓库>`

确认代码、分支、提交记录都已存在。

## 8. 常见报错与排查

### 8.1 `src refspec main does not match any`

原因通常是：

- 你还没有任何提交（没有 `HEAD`）

解决：

```powershell
git add .
git commit -m "chore: initial commit"
git branch -M main
git push -u origin main
```

### 8.2 `fatal: not a git repository`

原因：

- 当前目录不是 Git 仓库

解决：

- 确认你在项目根目录
- 或执行 `git init`

### 8.3 `Permission denied` / `Authentication failed`

排查方向：

- HTTPS：确认使用 PAT、或重新登录 GitHub
- SSH：确认 key 已添加到 GitHub、并能 `ssh -T git@github.com`
- 确认仓库存在且你对该仓库有写权限

### 8.4 推送很慢或失败（网络/代理）

排查方向：

- 检查代理设置：

```powershell
git config --global --get http.proxy
git config --global --get https.proxy
```

- 必要时清除代理配置（谨慎操作）：

```powershell
git config --global --unset http.proxy
git config --global --unset https.proxy
```

## 9. 推荐的日常工作流（简版）

```powershell
git status
git add .
git commit -m "feat: ..."   # 或 fix/chore/docs/refactor/test

git push
```

## 10. 附：以本仓库为例（Niche-v2）

> 下面是本项目曾使用过的一组命令（示例），供你对照：

```powershell
git remote add origin https://github.com/surdring/Niche-v2.git
git push -u origin main
```
