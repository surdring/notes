# Hugging Face 模型下载指南

本文档整理了从 Hugging Face Hub 下载大语言模型的常用方法。

---

## 方法一：使用 hf 命令行工具（推荐）

`huggingface-cli` 已弃用，请使用新的 `hf` 工具。

### 安装

```bash
pip install huggingface-hub
```

> **注意**：如果系统提示 `externally-managed-environment` 错误，请使用虚拟环境：
> ```bash
> python3 -m venv ~/huggingface_env
> source ~/huggingface_env/bin/activate
> pip install huggingface-hub
> ```

### 下载模型

```bash
# 基本用法
hf download zhiqing/Huihui-Qwen3.6-27B-abliterated-AWQ

# 指定本地保存路径
hf download zhiqing/Huihui-Qwen3.6-27B-abliterated-AWQ --local-dir /home/zheng/models/zhiqing-Huihui-Qwen3.6-27B-abliterated-AWQ

# 进入目标目录后下载
mkdir -p /home/zheng/models
hf download zhiqing/Huihui-Qwen3.6-27B-abliterated-AWQ
```

### 登录（如需访问受限模型）

```bash
hf auth login
# 按提示输入 Hugging Face Access Token
```

---

## 方法二：使用 Python 代码

```python
from huggingface_hub import snapshot_download

# 下载到当前目录
snapshot_download(
    repo_id="zhiqing/Huihui-Qwen3.6-27B-abliterated-AWQ",
    local_dir="./Huihui-Qwen3.6-27B-abliterated-AWQ",
    local_dir_use_symlinks=False
)
```

---

## 方法三：使用 git-lfs

适用于需要完整仓库历史或特定分支的情况。

```bash
# 安装 git-lfs
sudo apt install git-lfs
git lfs install

# 克隆仓库（需要 Hugging Face 登录）
git clone https://huggingface.co/zhiqing/Huihui-Qwen3.6-27B-abliterated-AWQ
```

---

## 配置 pip 国内镜像源

模型下载工具依赖 pip 安装，配置国内镜像可大幅加速：

### 临时使用（单次命令）

```bash
pip install huggingface-hub -i https://pypi.tuna.tsinghua.edu.cn/simple
```

### 永久配置

```bash
# 清华镜像
pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple

# 其他可选镜像
# 阿里云: https://mirrors.aliyun.com/pypi/simple/
# 腾讯云: https://mirrors.cloud.tencent.com/pypi/simple/
# 豆瓣: https://pypi.douban.com/simple/
```

---

## 常见问题

### 1. externally-managed-environment 错误

**现象**：
```
error: externally-managed-environment
× This environment is externally managed
```

**解决**：使用虚拟环境

```bash
# 创建并激活虚拟环境
python3 -m venv ~/huggingface_env
source ~/huggingface_env/bin/activate

# 安装并使用
pip install -U huggingface_hub
hf download zhiqing/Huihui-Qwen3.6-27B-abliterated-AWQ
```

### 2. huggingface-cli 已弃用

**现象**：
```
Warning: `huggingface-cli` is deprecated and no longer works. Use `hf` instead.
```

**解决**：改用 `hf` 命令

```bash
# 旧命令（已弃用）
huggingface-cli download zhiqing/Huihui-Qwen3.6-27B-abliterated-AWQ

# 新命令
hf download zhiqing/Huihui-Qwen3.6-27B-abliterated-AWQ
```

### 3. 模型下载中断

`hf` 和 `huggingface-cli` 都支持断点续传，重新运行相同命令即可继续下载。

---

## 模型存储路径示例

```
/home/zheng/models/
└── zhiqing-Huihui-Qwen3.6-27B-abliterated-AWQ/
    ├── config.json
    ├── model.safetensors.index.json
    ├── model-00001-of-00005.safetensors
    ├── model-00002-of-00005.safetensors
    ├── ...
    └── tokenizer.json
```

---

## 相关资源

- [Hugging Face Hub 文档](https://huggingface.co/docs/huggingface_hub)
- [模型仓库示例](https://huggingface.co/zhiqing/Huihui-Qwen3.6-27B-abliterated-AWQ)

---

*创建时间: 2026-05-02*
