# Ubuntu 国内镜像源测速与配置指南

## 背景

Ubuntu 默认的软件源 `archive.ubuntu.com` 位于海外，国内访问速度较慢（实测约 177 KB/s，延迟 166ms）。通过切换至国内镜像源，可显著提升 `apt` 操作的下载速度。

## 主流国内 Ubuntu 镜像站

| 镜像站 | 域名 | 提供方 |
|:---|:---|:---|
| 阿里云 | `mirrors.aliyun.com` | 阿里巴巴 |
| 华为云 | `mirrors.huaweicloud.com` | 华为 |
| 清华大学 | `mirrors.tuna.tsinghua.edu.cn` | TUNA 镜像站 |
| 中科大 | `mirrors.ustc.edu.cn` | 中国科学技术大学 |
| 上海交大 | `mirrors.sjtug.sjtu.edu.cn` | SJTUG 镜像站 |
| 南京大学 | `mirrors.nju.edu.cn` | NJU 镜像站 |
| 网易 | `mirrors.163.com` | 网易 |

## 一、测速脚本

以下脚本可批量测试各镜像站的延迟（ping）和下载速度（wget 下载 Release 文件），并自动排名。

```bash
#!/bin/bash

MIRRORS=(
    "http://archive.ubuntu.com/ubuntu/"
    "http://mirrors.aliyun.com/ubuntu/"
    "http://mirrors.tuna.tsinghua.edu.cn/ubuntu/"
    "http://mirrors.ustc.edu.cn/ubuntu/"
    "http://mirrors.huaweicloud.com/ubuntu/"
    "http://mirrors.163.com/ubuntu/"
    "http://mirrors.sjtug.sjtu.edu.cn/ubuntu/"
    "http://mirrors.nju.edu.cn/ubuntu/"
)

SUITE=$(lsb_release -cs)
TEST_FILE="dists/${SUITE}/Release"

echo "============================================"
echo " Ubuntu 镜像站测速报告"
echo " 系统版本: $(lsb_release -ds)"
echo " 测试时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================"
printf "%-40s %-12s %-12s %-12s\n" "镜像站" "延迟(ms)" "速度(KB/s)" "状态"
echo "--------------------------------------------------------------------------------"

RESULTS=()

for mirror in "${MIRRORS[@]}"; do
    url="${mirror}${TEST_FILE}"
    domain=$(echo "$mirror" | sed -E 's|https?://([^/]+)/.*|\1|')

    ping_time=$(ping -c 3 -W 3 "$domain" 2>/dev/null | tail -1 | awk -F/ '{print $5}' 2>/dev/null)
    if [ -z "$ping_time" ]; then
        ping_time="N/A"
    else
        ping_time=$(printf "%.0f" "$ping_time")
    fi

    result=$(wget --timeout=5 --tries=1 -O /dev/null "$url" 2>&1 | grep -o '\([0-9.]\+ [KM]B/s\)\|\([0-9.]\+ B/s\)')
    speed=$(echo "$result" | head -1)

    if [ -z "$speed" ]; then
        status="不可达"
        speed_str="N/A"
    else
        status="可用"
        if echo "$speed" | grep -q "MB/s"; then
            val=$(echo "$speed" | awk '{printf "%.0f", $1 * 1024}')
            speed_str="${val} KB/s"
        elif echo "$speed" | grep -q "KB/s"; then
            val=$(echo "$speed" | awk '{printf "%.0f", $1}')
            speed_str="${val} KB/s"
        elif echo "$speed" | grep -q "B/s"; then
            val=$(echo "$speed" | awk '{printf "%.0f", $1 / 1024}')
            speed_str="${val} KB/s"
        else
            speed_str="$speed"
        fi
    fi

    printf "%-40s %-12s %-12s %-12s\n" "$domain" "${ping_time}ms" "$speed_str" "$status"

    if [ "$status" = "可用" ]; then
        kb_val=$(echo "$speed_str" | grep -oP '^\d+')
        [ -z "$kb_val" ] && kb_val=0
        RESULTS+=("$kb_val|$mirror|$domain")
    fi
done

echo ""
echo "============================================"
echo " 速度排名 (前3名)"
echo "============================================"

IFS=$'\n' sorted=($(sort -t'|' -k1 -rn <<<"${RESULTS[*]}"))
unset IFS

rank=1
for entry in "${sorted[@]}"; do
    [ $rank -gt 3 ] && break
    kb_val=$(echo "$entry" | cut -d'|' -f1)
    domain=$(echo "$entry" | cut -d'|' -f3)
    echo "  No.$rank: $domain ($kb_val KB/s)"
    ((rank++))
done

if [ ${#sorted[@]} -gt 0 ]; then
    fastest=$(echo "${sorted[0]}" | cut -d'|' -f2)
    fastest_domain=$(echo "${sorted[0]}" | cut -d'|' -f3)
    echo ""
    echo "============================================"
    echo " 推荐最快镜像: $fastest_domain"
    echo "============================================"
fi
```

## 二、实测结果（2026-05-19）

测试环境：**Ubuntu 26.04 LTS** (Resolute Raccoon)

| 排名 | 镜像站 | 速度 | 延迟 |
|:---:|:---|:---:|:---:|
| 1 | **阿里云** mirrors.aliyun.com | **4659 KB/s** | 10ms |
| 2 | 华为云 mirrors.huaweicloud.com | 3727 KB/s | 15ms |
| 3 | 上海交大 mirrors.sjtug.sjtu.edu.cn | 1024 KB/s | 48ms |
| 4 | 网易 mirrors.163.com | 668 KB/s | 59ms |
| 5 | 中科大 mirrors.ustc.edu.cn | 518 KB/s | 21ms |
| 6 | 清华 mirrors.tuna.tsinghua.edu.cn | 439 KB/s | 57ms |
| 7 | 南京大学 mirrors.nju.edu.cn | 402 KB/s | 60ms |
| 8 | 官方 archive.ubuntu.com | 177 KB/s | 166ms |

**结论：阿里云镜像站速度最快，是官方源的 26 倍。**

## 三、切换软件源

### Ubuntu 26.04（deb822 格式）

自 Ubuntu 24.04 起，软件源配置采用新的 **deb822 格式**，配置文件位于：

```
/etc/apt/sources.list.d/ubuntu.sources
```

#### 1. 备份原配置

```bash
sudo cp /etc/apt/sources.list.d/ubuntu.sources /etc/apt/sources.list.d/ubuntu.sources.backup
```

#### 2. 修改为阿里云镜像源

```bash
sudo tee /etc/apt/sources.list.d/ubuntu.sources > /dev/null << 'EOF'
Types: deb
URIs: http://mirrors.aliyun.com/ubuntu/
Suites: resolute resolute-updates resolute-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: http://mirrors.aliyun.com/ubuntu/
Suites: resolute-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
```

> **注意**：将 `resolute` 替换为你的 Ubuntu 版本代号。可通过 `lsb_release -cs` 查看。

#### 3. 更新软件源

```bash
sudo apt update
```

### 旧版 Ubuntu（one-line 格式）

对于 Ubuntu 24.04 以下版本，修改 `/etc/apt/sources.list` 文件：

```bash
# 备份
sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup

# 替换为阿里云源（以 Ubuntu 22.04 Jammy 为例）
sudo sed -i 's|http://archive.ubuntu.com/ubuntu/|http://mirrors.aliyun.com/ubuntu/|g' /etc/apt/sources.list
sudo sed -i 's|http://security.ubuntu.com/ubuntu/|http://mirrors.aliyun.com/ubuntu/|g' /etc/apt/sources.list

# 更新
sudo apt update
```

## 四、验证配置

```bash
# 查看当前源配置
cat /etc/apt/sources.list.d/ubuntu.sources

# 更新软件包列表
sudo apt update

# 测试实际下载速度（安装一个小包）
sudo apt install -y tree
```

## 五、附：其他常用镜像源地址

| 镜像站 | 对应 URI |
|:---|:---|
| 阿里云 | `http://mirrors.aliyun.com/ubuntu/` |
| 华为云 | `http://mirrors.huaweicloud.com/ubuntu/` |
| 清华 | `http://mirrors.tuna.tsinghua.edu.cn/ubuntu/` |
| 中科大 | `http://mirrors.ustc.edu.cn/ubuntu/` |
| 上海交大 | `http://mirrors.sjtug.sjtu.edu.cn/ubuntu/` |
| 南京大学 | `http://mirrors.nju.edu.cn/ubuntu/` |
| 网易 | `http://mirrors.163.com/ubuntu/` |

## 六、注意事项

1. **选取最快的镜像**：不同网络环境下各镜像站速度不同，建议运行测速脚本后选择最快的。
2. **安全性**：国内镜像站同步官方源，使用相同的 GPG 签名密钥，安全性有保障。
3. **安全性（security 源）**：部分用户选择保留 `security.ubuntu.com` 以获取最快安全更新。如果对安全更新时效性要求极高，可将 security 套件保留为官方源。
4. **时效性**：镜像站通常每 2-6 小时同步一次官方源，普通使用场景下无明显差异。