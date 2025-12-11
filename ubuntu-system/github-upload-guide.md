# GitHub 项目创建和上传操作指南

本指南详细介绍如何将本地项目创建并上传到 GitHub 仓库。

## 前提条件

- 已安装 Git
- 拥有 GitHub 账户
- 已生成 GitHub Personal Access Token

## 步骤一：创建 GitHub 仓库

### 1.1 设置环境变量

#### 临时设置（当前会话）

```bash
export GITHUB_TOKEN="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"
export GITHUB_USER="surdring"
```

#### 永久设置（所有会话）

将环境变量添加到 `~/.bashrc` 文件：

```bash
echo 'export GITHUB_TOKEN="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"' >> ~/.bashrc
echo 'export GITHUB_USER="surdring"' >> ~/.bashrc
source ~/.bashrc
```

**验证环境变量：**
```bash
echo $GITHUB_TOKEN && echo $GITHUB_USER
```

**说明：**
- `GITHUB_TOKEN`: GitHub 个人访问令牌，需要在 GitHub 设置中生成
- `GITHUB_USER`: GitHub 用户名
- 永久设置后，每次打开新终端都会自动加载这些环境变量

### 1.2 通过 API 创建仓库

使用 curl 命令创建新仓库：

```bash
curl -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/user/repos \
  -d '{
    "name": "convert-pdfs",
    "description": "Batch PDF → Markdown OCR converter with async processing and checkpointing",
    "private": false,
    "has_issues": true,
    "has_projects": false,
    "has_wiki": false
  }'
```

**参数说明：**
- `name`: 仓库名称
- `description`: 仓库描述
- `private`: 是否为私有仓库（false 为公开）
- `has_issues`: 是否启用 Issues 功能
- `has_projects`: 是否启用 Projects 功能
- `has_wiki`: 是否启用 Wiki 功能

### 1.3 验证仓库创建

成功创建后，GitHub API 会返回仓库信息，包括：
- 仓库 ID
- 完整名称（如：`surdring/convert-pdfs`）
- 克隆 URL
- SSH URL

## 步骤二：初始化本地 Git 仓库

### 2.1 初始化 Git 仓库

```bash
git init
```

### 2.2 添加所有文件到暂存区

```bash
git add .
```

### 2.3 提交初始版本

```bash
git commit -m "Initial commit: PDF to Markdown OCR converter with batch checkpointing"
```

**提交信息说明：**
- 使用清晰、描述性的提交信息
- 说明本次提交的主要功能和特点

## 步骤三：连接远程仓库并推送

### 3.1 添加远程仓库

```bash
git remote add origin https://github.com/your_username/your_repository.git
```

**示例：**
```bash
git remote add origin https://github.com/surdring/convert-pdfs.git
```

### 3.2 设置主分支

```bash
git branch -M main
```

**说明：**
- 将本地分支重命名为 `main`（GitHub 默认分支名）
- `-M` 选项表示强制重命名

### 3.3 推送到远程仓库

```bash
git push -u origin main
```

**参数说明：**
- `-u`: 设置上游分支，后续可以直接使用 `git push`
- `origin`: 远程仓库名称（默认）
- `main`: 要推送的分支名

## 步骤四：验证上传结果

### 4.1 检查推送输出

成功推送后会显示类似信息：
```
枚举对象中: 2206, 完成.
对象计数中: 100% (2206/2206), 完成.
使用 24 个线程进行压缩
压缩对象中: 100% (2161/2161), 完成.
写入对象中: 100% (2206/2206), 73.08 MiB | 5.67 MiB/s, 完成.
总共 2206（差异 150），复用 0（差异 0），包复用 0
remote: Resolving deltas: 100% (150/150), done.
To https://github.com/surdring/convert-pdfs.git
 * [new branch]      main -> main
分支 'main' 设置为跟踪 'origin/main'。
```

### 4.2 在 GitHub 网站验证

访问 GitHub 仓库页面（如：https://github.com/surdring/convert-pdfs）确认：
- 所有文件已上传
- README.md 正确显示
- 项目结构完整

## 常见问题解决

### 问题 1：认证失败

**错误信息：** `Authentication failed`

**解决方案：**
- 检查 `GITHUB_TOKEN` 是否正确
- 确认 token 有足够权限（至少需要 `repo` 权限）
- 检查 token 是否已过期

### 问题 2：仓库已存在

**错误信息：** `Repository already exists`

**解决方案：**
- 使用不同的仓库名称
- 或删除现有仓库后重新创建

### 问题 3：推送被拒绝

**错误信息：** `! [rejected] main -> main (fetch-first)`

**解决方案：**
```bash
git pull origin main --allow-unrelated-histories
git push origin main
```

### 问题 4：文件太大

**错误信息：** `fatal: the remote end hung up unexpectedly`

**解决方案：**
- 检查是否有大文件（>100MB）
- 考虑使用 Git LFS 处理大文件
- 或将大文件添加到 `.gitignore`

## 最佳实践

### 1. 提交信息规范

使用清晰的提交信息格式：
```
类型(范围): 简短描述

详细描述（可选）
```

**示例：**
- `feat: 添加 OCR 批量处理功能`
- `fix: 修复 Markdown 生成问题`
- `docs: 更新 README 文档`

### 2. 分支管理

- `main`: 主分支，用于生产环境
- `develop`: 开发分支
- `feature/*`: 功能分支
- `hotfix/*`: 热修复分支

### 3. .gitignore 配置

创建 `.gitignore` 文件排除不必要的文件：
```
# Python
__pycache__/
*.pyc
*.pyo
*.pyd
.Python
env/
venv/
.venv/

# IDE
.vscode/
.idea/
*.swp
*.swo

# 输出文件
output/
test_output/
*.log

# 临时文件
*.tmp
*.temp
.DS_Store
Thumbs.db
```

### 4. 安全注意事项

- 不要将敏感信息提交到仓库
- 使用环境变量存储 API 密钥
- 定期检查和更新依赖包
- 为仓库设置适当的权限

## 后续操作

### 添加协作者

1. 访问 GitHub 仓库页面
2. 点击 "Settings" 标签
3. 选择 "Collaborators"
4. 添加协作者用户名

### 创建 Release

1. 访问仓库页面
2. 点击 "Releases" 标签
3. 点击 "Create a new release"
4. 填写版本号和发布说明

### 设置 GitHub Pages

1. 访问仓库设置
2. 找到 "Pages" 选项
3. 选择源分支和文件夹
4. 保存设置

## 总结

通过以上步骤，您已成功：
1. 创建了 GitHub 仓库
2. 初始化了本地 Git 仓库
3. 将项目代码上传到 GitHub
4. 验证了上传结果

现在您的项目已经在 GitHub 上公开，其他开发者可以查看、克隆和贡献代码。记得定期维护和更新项目，保持代码质量和文档的完整性。
