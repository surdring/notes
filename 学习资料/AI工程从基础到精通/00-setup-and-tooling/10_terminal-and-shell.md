# 终端与 Shell

> 终端是 AI 工程师的家。在这里要感到舒适自在。

**类型：** 学习
**使用语言：** --
**前置课程：** 阶段 0，第 01 课
**预计时间：** ~35 分钟

## 学习目标

- 使用管道、重定向和 `grep` 从命令行过滤和处理训练日志
- 创建具有多个窗格的持久 tmux 会话，用于并行训练和 GPU 监控
- 使用 `htop`、`nvtop` 和 `nvidia-smi` 监控系统和 GPU 资源
- 使用 SSH、`scp` 和 `rsync` 在本地和远程机器之间传输文件

## 问题

你在终端中花费的时间将比任何编辑器都多。训练运行、GPU 监控、日志跟踪、远程 SSH 会话、环境管理。每个 AI 工作流都会接触到 shell。如果在这里慢，那在任何地方都慢。

本课程涵盖了对 AI 工作重要的终端技能。没有 Unix 历史课，没有 Bash 脚本深入。只讲你需要的。

## 概念

```mermaid
graph TD
    subgraph tmux["tmux 会话: training"]
        subgraph top["顶部行"]
            P1["窗格 1: 训练运行\npython train.py\n轮次 12/100 ..."]
            P2["窗格 2: GPU 监控\nwatch -n1 nvidia-smi\nGPU: 78% | 显存: 14/24G"]
        end
        P3["窗格 3: 日志 + 实验\ntail -f logs/train.log | grep loss"]
    end
```

三件事情同时运行。一个终端。你可以断开、回家、SSH 回来并重新连接。训练继续运行。

## 构建它

### 步骤 1：了解你的 shell

检查你运行的是哪个 shell：

```bash
echo $SHELL
```

大多数系统使用 `bash` 或 `zsh`。两者都可以。本课程中的命令在两者中都能工作。

需知的关键操作：

```bash
# 移动
cd ~/projects/ai-engineering-from-scratch
pwd
ls -la

# 历史搜索（你将学到的最有用的快捷键）
# Ctrl+R 然后输入之前命令的一部分
# 再次按 Ctrl+R 循环匹配

# 清屏
clear   # 或 Ctrl+L

# 取消运行中的命令
# Ctrl+C

# 挂起运行中的命令（用 fg 恢复）
# Ctrl+Z
```

### 步骤 2：管道和重定向

管道将命令连接在一起。这是你处理日志、过滤输出和串联工具的方式。你会经常使用这些。

```bash
# 统计日志中 "loss" 出现的次数
cat train.log | grep "loss" | wc -l

# 从训练输出中提取 loss 值
grep "loss:" train.log | awk '{print $NF}' > losses.txt

# 实时查看日志文件更新，过滤错误
tail -f train.log | grep --line-buffered "ERROR"

# 按最终准确率排序实验
grep "final_accuracy" results/*.log | sort -t= -k2 -n -r

# 将 stdout 和 stderr 重定向到不同文件
python train.py > output.log 2> errors.log

# 将两者重定向到同一个文件
python train.py > train_full.log 2>&1
```

你需要了解的三种重定向：

| 符号 | 作用 |
|------|-----|
| `>` | 将 stdout 写入文件（覆盖） |
| `>>` | 将 stdout 追加到文件 |
| `2>` | 将 stderr 写入文件 |
| `2>&1` | 将 stderr 发送到与 stdout 相同的位置 |
| `\|` | 将一个命令的 stdout 作为 stdin 发送给下一个命令 |

### 步骤 3：后台进程

训练运行需要数小时。你不想一直保持终端打开。

```bash
# 后台运行（输出仍到终端）
python train.py &

# 后台运行，免疫挂断信号（关闭终端不会杀死它）
nohup python train.py > train.log 2>&1 &

# 检查后台运行的内容
jobs
ps aux | grep train.py

# 将后台任务带回前台
fg %1

# 杀死后台进程
kill %1
# 或找到 PID 并杀死
kill $(pgrep -f "train.py")
```

`&`、`nohup` 和 `screen`/`tmux` 的区别：

| 方法 | 终端关闭后存活？ | 可以重新连接？ |
|------|---------------|--------------|
| `command &` | 否 | 否 |
| `nohup command &` | 是 | 否（检查日志文件） |
| `screen` / `tmux` | 是 | 是 |

对于超过几分钟的任务，使用 tmux。

### 步骤 4：tmux

tmux 让你创建具有多个窗格的持久终端会话。这是管理训练运行最有用的工具。

```bash
# 安装
# macOS
brew install tmux
# Ubuntu
sudo apt install tmux

# 启动命名会话
tmux new -s training

# 水平分割
# Ctrl+B 然后 "

# 垂直分割
# Ctrl+B 然后 %

# 在窗格之间导航
# Ctrl+B 然后 方向键

# 断开（会话继续运行）
# Ctrl+B 然后 d

# 重新连接
tmux attach -t training

# 列出会话
tmux ls

# 杀死会话
tmux kill-session -t training
```

典型的 AI 工作流会话：

```bash
tmux new -s train

# 窗格 1：启动训练
python train.py --epochs 100 --lr 1e-4

# Ctrl+B，" 分割，然后运行 GPU 监控
watch -n1 nvidia-smi

# Ctrl+B，% 垂直分割，跟踪日志
tail -f logs/experiment.log

# 现在用 Ctrl+B，d 断开
# SSH 登出，去喝咖啡，回来
# tmux attach -t train
```

### 步骤 5：使用 htop 和 nvtop 监控

```bash
# 系统进程（比 top 更好）
htop

# GPU 进程（如果有 NVIDIA GPU）
# 安装：sudo apt install nvtop (Ubuntu) 或 brew install nvtop (macOS)
nvtop

# 不用 nvtop 快速检查 GPU
nvidia-smi

# 每秒刷新 GPU 使用情况
watch -n1 nvidia-smi

# 查看哪些进程在使用 GPU
nvidia-smi --query-compute-apps=pid,name,used_memory --format=csv
```

你会用到的 `htop` 快捷键：
- `F6` 或 `>` 按列排序（按内存排序可以找到内存泄漏）
- `F5` 切换树形视图（查看子进程）
- `F9` 杀死进程
- `/` 搜索进程名称

### 步骤 6：远程 GPU 机器的 SSH

当你租用云 GPU（Lambda、RunPod、Vast.ai）时，通过 SSH 连接。

```bash
# 基本连接
ssh user@gpu-box-ip

# 使用特定密钥
ssh -i ~/.ssh/my_gpu_key user@gpu-box-ip

# 复制文件到远程
scp model.pt user@gpu-box-ip:~/models/

# 从远程复制文件
scp user@gpu-box-ip:~/results/metrics.json ./

# 同步整个目录（对于大量文件更快）
rsync -avz ./data/ user@gpu-box-ip:~/data/

# 端口转发（本地访问远程的 Jupyter/TensorBoard）
ssh -L 8888:localhost:8888 user@gpu-box-ip
# 现在在浏览器中打开 localhost:8888

# SSH 配置方便使用
# 添加到 ~/.ssh/config:
# Host gpu
#     HostName 192.168.1.100
#     User ubuntu
#     IdentityFile ~/.ssh/gpu_key
#
# 然后只需：
# ssh gpu
```

### 步骤 7：AI 工作的有用别名

将这些添加到你的 `~/.bashrc` 或 `~/.zshrc`：

```bash
source phases/00-setup-and-tooling/10-terminal-and-shell/code/shell_aliases.sh
```

或复制你想要的。关键别名：

```bash
# GPU 状态一览
alias gpu='nvidia-smi --query-gpu=index,name,utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader'

# 杀死所有 Python 训练进程
alias killtraining='pkill -f "python.*train"'

# 快速激活虚拟环境
alias ae='source .venv/bin/activate'

# 监控训练损失
alias watchloss='tail -f logs/*.log | grep --line-buffered "loss"'
```

完整集合见 `code/shell_aliases.sh`。

### 步骤 8：常见 AI 终端模式

这些在实践中反复出现：

```bash
# 运行训练，记录一切，完成时通知
python train.py 2>&1 | tee train.log; echo "DONE" | mail -s "训练完成" you@email.com

# 并排比较两个实验日志
diff <(grep "accuracy" exp1.log) <(grep "accuracy" exp2.log)

# 找到最大的模型文件（清理磁盘空间）
find . -name "*.pt" -o -name "*.safetensors" | xargs du -h | sort -rh | head -20

# 从 Hugging Face 下载模型
wget https://huggingface.co/model/resolve/main/model.safetensors

# 解压数据集
tar xzf dataset.tar.gz -C ./data/

# 统计所有 Python 文件的行数（查看项目有多大）
find . -name "*.py" | xargs wc -l | tail -1

# 检查磁盘空间（训练数据会迅速填满磁盘）
df -h
du -sh ./data/*

# 训练前的环境变量检查
env | grep -i cuda
env | grep -i torch
```

## 使用它

以下是在本课程中每个工具的使用场景：

| 工具 | 何时使用 |
|------|---------|
| tmux | 每次训练运行（阶段 3+） |
| `tail -f` + `grep` | 监控训练日志 |
| `nohup` / `&` | 快速后台任务 |
| `htop` / `nvtop` | 调试训练缓慢、OOM 错误 |
| SSH + `rsync` | 在云 GPU 上工作 |
| 管道 + 重定向 | 处理实验结果 |
| 别名 | 节省重复命令的时间 |

## 练习

1. 安装 tmux，创建包含三个窗格的会话，在其中一个运行 `htop`，另一个运行 `watch -n1 date`，第三个运行 Python 脚本。断开并重新连接。
2. 将 `code/shell_aliases.sh` 中的别名添加到你的 shell 配置中，并使用 `source ~/.zshrc`（或 `~/.bashrc`）重新加载。
3. 创建一个假训练日志 `for i in $(seq 1 100); do echo "epoch $i loss: $(echo "scale=4; 1/$i" | bc)"; sleep 0.1; done > fake_train.log`，然后使用 `grep`、`tail` 和 `awk` 提取 loss 值。
4. 为你能访问的服务器设置 SSH 配置条目（或使用 `localhost` 练习语法）。

## 关键术语

| 术语 | 人们常说的 | 实际含义 |
|------|-----------|---------|
| Shell | "终端" | 解释你命令的程序（bash、zsh、fish） |
| tmux | "终端复用器" | 让你在一个窗口中运行多个终端会话，并支持断开/重新连接的程序 |
| 管道 | "那个竖线" | `\|` 操作符，将一个命令的输出作为另一个命令的输入 |
| PID | "进程 ID" | 分配给每个运行中进程的唯一编号，用于监控或杀死它 |
| nohup | "不挂断" | 运行一个免疫挂断信号的命令，关闭终端不会杀死它 |
| SSH | "连接到服务器" | 安全 Shell，用于在远程机器上运行命令的加密协议 |