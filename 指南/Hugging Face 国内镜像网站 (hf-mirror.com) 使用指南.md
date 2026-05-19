# Hugging Face 国内镜像网站 (hf-mirror.com) 使用指南

## 📋 目录
1. [简介](#简介)
2. [基础配置](#基础配置)
3. [使用方法](#使用方法)
4. [常见命令示例](#常见命令示例)
5. [注意事项](#注意事项)

---

## 简介

**hf-mirror.com** 是 Hugging Face 在中国的官方镜像站点，提供与原站相同的功能和内容，但访问速度更快，适合国内用户使用。

---

## 基础配置

### 方法一：设置环境变量（推荐）

在终端中执行以下命令：

```bash
export HF_ENDPOINT=https://hf-mirror.com
```

为了永久生效，可以将上述命令添加到 shell 配置文件中：

```bash
# 对于 bash 用户
echo 'export HF_ENDPOINT=https://hf-mirror.com' >> ~/.bashrc
source ~/.bashrc

# 对于 zsh 用户
echo 'export HF_ENDPOINT=https://hf-mirror.com' >> ~/.zshrc
source ~/.zshrc
```

### 方法二：使用 huggingface-cli 配置

```bash
huggingface-cli login --endpoint https://hf-mirror.com
```

或者：

```bash
huggingface-cli config set HF_ENDPOINT https://hf-mirror.com
```

---

## 使用方法

### 1. 使用 huggingface-cli 下载模型

```bash
# 下载模型
hf download model_name_or_path --local-dir ./local_model_dir

# 示例：下载 Llama 模型
hf download meta-llama/Llama-2-7b-hf --local-dir ./Llama-2-7b-hf
```

# 安装 pip install huggingface-hub

## 推荐方案：使用虚拟环境

```bash
# 创建虚拟环境（在项目目录下）
python3 -m venv hf-env

# 激活虚拟环境
source ~/huggingface_env/bin/activate

# 然后安装
pip install huggingface-hub
```

激活后终端提示符会显示 `(hf-env)`，之后在该终端中运行 Python 脚本都需要先激活这个环境。

使用完后退出虚拟环境：
```bash
deactivate
```

## 方案二：使用 pipx（适合命令行工具）

如果只是要用 `huggingface-cli` 这类命令行工具：

```bash
# 安装 pipx（如果没有的话）
sudo apt install pipx
pipx ensurepath

# 安装 huggingface-hub
pipx install huggingface-hub
```

## 方案三：临时绕过（不推荐）

```bash
pip install huggingface-hub --break-system-packages
```


