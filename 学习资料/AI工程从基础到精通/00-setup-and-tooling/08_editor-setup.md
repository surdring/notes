# 编辑器设置

> 你的编辑器是你的副驾驶。一次配置好，让它不再碍事并开始发挥作用。

**类型：** 构建
**使用语言：** --
**前置课程：** 阶段 0，第 01 课
**预计时间：** ~20 分钟

## 学习目标

- 安装 VS Code 及 Python、Jupyter、代码检查和远程 SSH 等必要扩展
- 为 AI 工作流配置保存时格式化、类型检查和 notebook 输出滚动
- 设置 Remote SSH，像本地编辑一样在远程 GPU 机器上编辑和调试代码
- 评估编辑器替代方案（Cursor、Windsurf、Neovim）及其在 AI 工作中的权衡

## 问题

你将在编辑器中花费数千小时来编写 Python、运行 notebook、调试训练循环，以及通过 SSH 连接 GPU 机器。配置不当的编辑器会把每次会话都变成摩擦：没有自动补全、没有类型提示、没有行内错误、手动格式化，以及笨拙的终端工作流。

正确的设置只需要 20 分钟。跳过它每天会浪费你 20 分钟。

## 概念

AI 工程的编辑器设置需要五样东西：

```mermaid
graph TD
    L5["5. 远程开发<br/>SSH 连接 GPU 机器、云 VM"] --> L4
    L4["4. 终端集成<br/>运行脚本、调试、监控 GPU"] --> L3
    L3["3. AI 特定设置<br/>自动格式化、类型检查、标尺线"] --> L2
    L2["2. 扩展<br/>Python、Jupyter、Pylance、GitLens"] --> L1
    L1["1. 基础编辑器<br/>VS Code — 免费、可扩展、通用"]
```

## 构建它

### 步骤 1：安装 VS Code

VS Code 是推荐的编辑器。它免费、支持所有操作系统，具有一流的 Jupyter notebook 支持，扩展生态系统覆盖了你 AI 工作所需的一切。

从 [code.visualstudio.com](https://code.visualstudio.com) 下载。

从终端验证：

```bash
code --version
```

如果在 macOS 上找不到 `code`，打开 VS Code，按 `Cmd+Shift+P`，输入 "Shell Command"，选择"Install 'code' command in PATH"。

### 步骤 2：安装必要的扩展

在 VS Code 中打开集成终端（`` Ctrl+` `` 或 `` Cmd+` ``）并安装对 AI 工作重要的扩展：

```bash
code --install-extension ms-python.python
code --install-extension ms-python.vscode-pylance
code --install-extension ms-toolsai.jupyter
code --install-extension eamodio.gitlens
code --install-extension ms-vscode-remote.remote-ssh
code --install-extension ms-python.debugpy
code --install-extension ms-python.black-formatter
code --install-extension charliermarsh.ruff
```

每个扩展的作用：

| 扩展 | 为什么需要 |
|------|----------|
| Python | 语言支持、虚拟环境检测、运行/调试 |
| Pylance | 快速类型检查、自动补全、导入解析 |
| Jupyter | 在 VS Code 中运行 notebook、变量浏览器 |
| GitLens | 查看谁改了什么、行内 git blame |
| Remote SSH | 像本地打开文件夹一样打开远程 GPU 机器上的文件夹 |
| Debugpy | Python 的单步调试 |
| Black Formatter | 保存时自动格式化，保持风格一致 |
| Ruff | 快速代码检查，捕获常见错误 |

本课程中 `code/.vscode/extensions.json` 文件包含完整的推荐列表。当你打开项目文件夹时，VS Code 会提示安装它们。

### 步骤 3：配置设置

从本课程的 `code/.vscode/settings.json` 复制设置，或通过 `设置 > 打开设置 (JSON)` 手动应用。

AI 工作的关键设置：

```jsonc
{
    "python.analysis.typeCheckingMode": "basic",
    "editor.formatOnSave": true,
    "editor.rulers": [88, 120],
    "notebook.output.scrolling": true,
    "files.autoSave": "afterDelay"
}
```

为什么这些设置重要：

- **类型检查设为 basic**：在运行前捕获错误的参数类型。节省调试张量形状不匹配和错误 API 参数的时间。
- **保存时格式化**：永远不用再思考格式化。Black 自动处理。
- **标尺线在 88 和 120**：Black 在第 88 列换行。第 120 列的标记显示文档字符串和注释何时变得太长。
- **Notebook 输出滚动**：训练循环打印数千行。没有滚动，输出面板会爆炸。
- **自动保存**：你会忘记保存。你的训练脚本会运行旧代码。自动保存防止这种情况。

### 步骤 4：终端集成

VS Code 的集成终端是你运行训练脚本、监控 GPU 和管理环境的地方。

正确设置：

```jsonc
{
    "terminal.integrated.defaultProfile.osx": "zsh",
    "terminal.integrated.defaultProfile.linux": "bash",
    "terminal.integrated.fontSize": 13,
    "terminal.integrated.scrollback": 10000
}
```

常用快捷键：

| 操作 | macOS | Linux/Windows |
|------|------|---------------|
| 切换终端 | `` Ctrl+` `` | `` Ctrl+` `` |
| 新建终端 | `Ctrl+Shift+`` ` | `Ctrl+Shift+`` ` |
| 分割终端 | `Cmd+\` | `Ctrl+\` |

分割终端很有用：一个用来运行脚本，一个用来使用 `nvidia-smi -l 1` 或 `watch -n 1 nvidia-smi` 监控 GPU。

### 步骤 5：远程开发（SSH 连接 GPU 机器）

这是 AI 工作中最重要的扩展。你将在远程机器（云 VM、实验室服务器、Lambda、Vast.ai）上运行训练。Remote SSH 让你像本地一样打开远程文件系统、编辑文件、运行终端和调试。

设置：

1. 安装 Remote SSH 扩展（在步骤 2 中完成）。
2. 按 `Ctrl+Shift+P`（或 `Cmd+Shift+P`），输入 "Remote-SSH: Connect to Host"。
3. 输入 `user@your-gpu-box-ip`。
4. VS Code 自动在远程机器上安装其服务器组件。

如需无密码访问，设置 SSH 密钥：

```bash
ssh-keygen -t ed25519 -C "your-email@example.com"
ssh-copy-id user@your-gpu-box-ip
```

为方便起见，将主机添加到 `~/.ssh/config`：

```
Host gpu-box
    HostName 203.0.113.50
    User ubuntu
    IdentityFile ~/.ssh/id_ed25519
    ForwardAgent yes
```

现在 `Remote-SSH: Connect to Host > gpu-box` 可以即时连接。

## 替代方案

### Cursor

[cursor.com](https://cursor.com) 是 VS Code 的一个分支，内置了 AI 代码生成。它使用相同的扩展生态系统和设置格式。如果你使用 Cursor，本课中的所有内容仍然适用。导入相同的 `settings.json` 和 `extensions.json`。

### Windsurf

[windsurf.com](https://windsurf.com) 是另一个以 AI 为先的 VS Code 分支。同样的故事：相同的扩展、相同的设置格式、相同的 Remote SSH 支持。

### Vim/Neovim

如果你已经在使用 Vim 或 Neovim 并且效率很高，那就继续用。AI Python 工作的最小设置：

- **pyright** 或 **pylsp** 用于类型检查（通过 Mason 或手动安装）
- **nvim-lspconfig** 用于语言服务器集成
- **jupyter-vim** 或 **molten-nvim** 用于类似 notebook 的执行
- **telescope.nvim** 用于文件/符号搜索
- **none-ls.nvim** 配合 black 和 ruff 用于格式化/检查

如果你还不使用 Vim，现在不要开始。学习曲线会与学习 AI 工程竞争。用 VS Code。

## 使用它

有了这个设置，你的日常工作流看起来像这样：

1. 在 VS Code 中打开项目文件夹（或通过 Remote SSH 连接到 GPU 机器）。
2. 在编辑器中使用自动补全、类型提示和行内错误编写 Python。
3. 使用 Jupyter 扩展在行内运行 Jupyter notebook。
4. 使用集成终端进行训练脚本、`uv pip install` 和 GPU 监控。
5. 在提交前使用 GitLens 查看更改。

## 练习

1. 安装 VS Code 和步骤 2 中列出的所有扩展
2. 将本课程的 `settings.json` 复制到你的 VS Code 配置中
3. 打开一个 Python 文件，验证 Pylance 显示类型提示，Black 在保存时格式化
4. 如果你能访问远程机器，设置 Remote SSH 并在其上打开一个文件夹

## 关键术语

| 术语 | 人们常说的 | 实际含义 |
|------|-----------|---------|
| LSP | "自动补全引擎" | 语言服务器协议：编辑器获取类型信息、补全和诊断的标准协议 |
| Pylance | "Python 插件" | 微软的 Python 语言服务器，使用 Pyright 进行类型检查和 IntelliSense |
| Remote SSH | "在服务器上工作" | VS Code 扩展，在远程机器上运行轻量级服务器并将 UI 流传到你的本地编辑器 |
| 保存时格式化 | "自动美化" | 编辑器每次保存时运行格式化器（Black、Ruff），使代码风格始终保持一致 |