# Ubuntu Python 环境准备（虚拟环境 + pip 镜像 + 常见报错）

本文整理在 Ubuntu 服务器上为本项目准备 Python 运行环境时，常见的安装、虚拟环境创建、pip 镜像配置与报错处理步骤。

## 1. Ubuntu 自带 Python，但版本可能不一致

Ubuntu 通常会预装 `python3`（版本随发行版不同而不同，例如 3.8/3.10/3.12）。

建议先确认当前系统的 Python：

```bash
python3 --version
which python3
ls -l /usr/bin/python3
```

如果项目文档或依赖明确要求特定版本（例如 3.11+），则需要按要求安装对应版本。

## 2. 安装/选择 Python 版本

### 2.1 使用 Ubuntu 源安装（推荐优先尝试）

如果系统提示找不到 `python3.11`，说明该版本未安装：

```bash
sudo apt update
sudo apt install python3.11
```

如果你希望在创建虚拟环境时直接使用 3.11：

```bash
python3.11 --version
```

### 2.2 如果系统源没有目标版本

部分 Ubuntu 版本默认源可能没有 3.11，可使用 PPA（例如 deadsnakes）获取。

```bash
sudo apt update
sudo apt install software-properties-common
sudo add-apt-repository ppa:deadsnakes/ppa
sudo apt update
sudo apt install python3.11 python3.11-venv
```

## 3. 创建虚拟环境（venv）

### 3.1 使用系统默认 Python 创建

```bash
python3 -m venv venv
```

激活虚拟环境：

```bash
source venv/bin/activate
```

### 3.2 使用指定版本创建（例如 Python 3.11）

```bash
python3.11 -m venv venv
source venv/bin/activate
```

## 4. 报错处理：ensurepip is not available

当执行：

```bash
python3 -m venv venv
```

出现类似报错：

```text
The virtual environment was not created successfully because ensurepip is not available.
On Debian/Ubuntu systems, you need to install the python3-venv package
```

原因是 Debian/Ubuntu 将 `venv/ensurepip` 拆分为独立软件包，需要额外安装。

解决方法：

- **安装通用包（匹配默认 python3）**

```bash
sudo apt update
sudo apt install python3-venv
```

- **安装指定版本包（例如报错提示 python3.12-venv）**

```bash
sudo apt update
sudo apt install python3.12-venv
```

如果你使用的是 3.11：

```bash
sudo apt update
sudo apt install python3.11-venv
```

安装完成后，建议删除旧的 `venv` 目录并重新创建虚拟环境：

```bash
rm -rf venv
python3 -m venv venv
```

## 5. pip 配置阿里云镜像

### 5.1 临时使用（单次命令）

```bash
pip install -r requirements.txt -i https://mirrors.aliyun.com/pypi/simple/
```

### 5.2 永久配置（推荐）

```bash
pip config set global.index-url https://mirrors.aliyun.com/pypi/simple/
pip config set install.trusted-host mirrors.aliyun.com
```

验证：

```bash
pip config list
```

### 5.3 手动写配置文件

```bash
mkdir -p ~/.config/pip
nano ~/.config/pip/pip.conf
```

写入：

```ini
[global]
index-url = https://mirrors.aliyun.com/pypi/simple/
trusted-host = mirrors.aliyun.com
```

## 6. 与本项目文档的关系

- 如果你使用项目根目录 `README.md` 的 Linux 命令示例，注意其中可能写了 `python3.11 -m venv venv`。
- 如果服务器上没有 3.11，则可以：
  - 安装 3.11 并按文档执行；或
  - 直接改用 `python3 -m venv venv`（前提是项目对版本无强制要求）。

