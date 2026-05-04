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
# 基本用法（下载整个仓库）
hf download zhiqing/Huihui-Qwen3.6-27B-abliterated-AWQ

# 指定本地保存路径
hf download zhiqing/Huihui-Qwen3.6-27B-abliterated-AWQ --local-dir /home/zheng/models/zhiqing-Huihui-Qwen3.6-27B-abliterated-AWQ

# 只下载特定量化版本（GGUF 仓库推荐，避免下载全部量化文件）
hf download bartowski/huihui-ai_Huihui-gpt-oss-20b-BF16-abliterated-GGUF --include "*Q6_K_L*"

# 只下载特定文件并指定保存路径
HF_ENDPOINT=https://hf-mirror.com hf download bartowski/huihui-ai_Huihui-gpt-oss-20b-BF16-abliterated-GGUF \
  --include "*Q6_K_L*" \
  --local-dir /mnt/ssd/models/huihui-gpt-oss-20b
```

> **注意**：GGUF 仓库通常包含多种量化版本（Q3/Q4/Q5/Q6/Q8 等），不加 `--include` 会下载全部，占用大量磁盘空间。务必用 `--include` 过滤！
>
> **错误语法**：`hf download repo:Q8_0` —— `:` 不是合法字符，不支持此语法。

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

## 配置 HuggingFace 国内镜像源

国内访问 HuggingFace 经常超时，配置镜像源可大幅加速下载。

### 永久配置（推荐）

在 `~/.bashrc` 末尾添加：

```bash
# HuggingFace 国内镜像
export HF_ENDPOINT=https://hf-mirror.com
```

然后执行 `source ~/.bashrc` 使其生效。所有使用 `huggingface_hub` / `transformers` / `datasets` 的程序都会自动走镜像。

### 临时使用（单次命令）

```bash
HF_ENDPOINT=https://hf-mirror.com hf download zhiqing/Huihui-Qwen3.6-27B-abliterated-AWQ
```

### wget 直接下载单个文件

如果 `hf download` 有问题，可直接用 wget 从镜像下载：

```bash
wget https://hf-mirror.com/shennguyen/Huihui-Qwen3.6-35B-A3B-Claude-4.7-Opus-abliterated-GGUF/resolve/main/huihui-qwen3.6-35b-a3b-claude-4.7-opus-abliterated-q8_0.gguf
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

### 4. Invalid value: Repo id must use alphanumeric chars

**现象**：
```
Error: Invalid value. Repo id must use alphanumeric chars, '-', '_' or '.'.
```

**原因**：使用了 `repo:quantization` 语法（如 `repo:Q8_0`），`:` 不是合法字符。

**解决**：用 `--include` 过滤文件名
```bash
# 错误
hf download shennguyen/Huihui-Qwen3.6-35B-A3B-Claude-4.7-Opus-abliterated-GGUF:Q8_0

# 正确
hf download shennguyen/Huihui-Qwen3.6-35B-A3B-Claude-4.7-Opus-abliterated-GGUF --include "*q8_0*"
```

### 5. 下载了远大于模型大小的文件

**原因**：GGUF 仓库包含多种量化版本，不加 `--include` 会下载全部。

**解决**：始终使用 `--include` 指定所需量化版本。

### 6. 查找已下载的模型文件

```bash
# 查找特定模型文件
find /mnt/ssd /mnt/sata /home -name "*q8_0*.gguf" -type f 2>/dev/null

# 查看 HF 缓存目录
ls -lh ~/.cache/huggingface/hub/models--*/snapshots/*/

# 查看 HF 缓存大小
du -sh ~/.cache/huggingface/hub/
```

> **注意**：`hf download` 不加 `--local-dir` 时，文件缓存在 `~/.cache/huggingface/hub/` 下，snapshot 目录中的文件是符号链接指向 blobs 目录。可直接使用符号链接路径运行模型，但 `hf cache purge` 会清理缓存导致文件丢失，建议重要模型拷贝到独立目录。

---

## 模型存储路径示例

### safetensors 格式（完整模型）

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

### GGUF 格式（量化模型，llama.cpp 使用）

```
/mnt/ssd/models/
└── Qwen3.6-35B-A3B/
    ├── huihui-qwen3.6-35b-a3b-claude-4.7-opus-abliterated-q5_k_m.gguf
    ├── huihui-qwen3.6-35b-a3b-claude-4.7-opus-abliterated-q8_0.gguf
    └── mmproj-BF16.gguf
```

### HF 缓存目录结构

```
~/.cache/huggingface/hub/
└── models--shennguyen--Huihui-Qwen3.6-35B-A3B-Claude-4.7-Opus-abliterated-GGUF/
    ├── blobs/          # 实际文件（无后缀，按 hash 命名）
    │   └── 448b5954...  # 35G 的 Q8_0 模型文件
    ├── refs/
    │   └── main
    └── snapshots/      # 符号链接（恢复原始文件名）
        └── <commit-hash>/
            └── huihui-qwen3.6-35b-a3b-claude-4.7-opus-abliterated-q8_0.gguf -> ../../blobs/448b5954...
```

---

## 相关资源

- [Hugging Face Hub 文档](https://huggingface.co/docs/huggingface_hub)
- [模型仓库示例](https://huggingface.co/zhiqing/Huihui-Qwen3.6-27B-abliterated-AWQ)

---

*创建时间: 2026-05-02*
*更新时间: 2026-05-03*
