# GitHub 连接故障排查与协议切换指南

当 `git push` / `git pull` 长时间无响应或报错时，按以下流程排查和修复。

---

## 1. 快速诊断

### 1.1 确认当前使用的协议

```bash
git remote -v
```

- `https://github.com/...` → HTTPS 协议
- `git@github.com:...` → SSH 协议

### 1.2 测试连通性

**测试 HTTPS：**

```bash
curl -I https://github.com
```

**测试 SSH：**

```bash
ssh -T git@github.com -v
```

如果 SSH 在密钥交换阶段卡住（`expecting SSH2_MSG_KEX_ECDH_REPLY`），说明 SSH 端口被封锁。

如果 `curl` 长时间无响应或返回连接超时，说明 HTTPS 443 端口被封锁。

**两种协议在不同网络环境下都可能被封锁**，互相切换是最快的修复手段。

---

## 2. 检查代理配置

```bash
git config --global --get http.proxy
git config --global --get https.proxy
env | grep -i proxy
```

如果代理配置存在但代理不可用，会导致连接失败。清除代理：

```bash
git config --global --unset http.proxy
git config --global --unset https.proxy
```

> 注意：公司内网可能必须使用代理，清除前请确认。

如需设置代理：

```bash
git config --global http.proxy http://127.0.0.1:7897
git config --global https.proxy https://127.0.0.1:7897
```

---

## 3. 协议切换：互相兜底

### 3.1 HTTPS 不通 → 切换到 SSH

公司/机房网络可能封锁 HTTPS 443 端口或限制出站流量，此时 SSH 反而可用：

```bash
git remote set-url origin git@github.com:<username>/<repo>.git
git push
```

前提：已配置 SSH key 并通过 `ssh -T git@github.com` 验证成功（见 §4）。

### 3.2 SSH 不通 → 改用 443 端口

GitHub 提供通过 443 端口的 SSH 访问（`ssh.github.com`），绕过端口 22 的封锁。

编辑 `~/.ssh/config`：

```
Host github.com
  Hostname ssh.github.com
  Port 443
  User git
```

验证：

```bash
ssh -T git@github.com
```

首次连接需确认主机密钥（输入 `yes`），成功后显示：

```
Hi <username>! You've successfully authenticated, but GitHub does not provide shell access.
```

### 3.3 SSH 22 和 443 都不通 → 切换到 HTTPS

SSH 协议有明显的流量特征（握手阶段有明文版本字符串），即使走 443 端口也可能被 DPI 识别并干扰。HTTPS 流量与普通网页访问一致，通常不会被封锁。

```bash
git remote set-url origin https://github.com/<username>/<repo>.git
git push origin HEAD
```

### 3.4 SSH vs HTTPS 特性对比

| | SSH (端口22/443) | HTTPS (端口443) |
|---|---|---|
| **协议特征** | SSH 握手有明文版本字符串，易被 DPI 识别 | 标准 TLS，与网页浏览一致 |
| **典型封锁场景** | 家庭宽带/校园网 DPI 干扰 | 公司/机房防火墙限制出站 |
| **稳定性** | 家庭网络间歇性不可用 | 公司网络可能受限，家庭网络极少被封 |
| **认证方式** | SSH key（免密码） | PAT / gh auth（免密码） |

**核心原则：两种协议互相兜底，哪个通就用哪个。**

---

## 4. SSH Key 配置（从 HTTPS 切换到 SSH）

如果网络环境 SSH 可用，从 HTTPS 切换到 SSH：

### 4.1 生成 SSH Key

```bash
ssh-keygen -t ed25519 -C "你的邮箱"
```

- 默认保存到 `~/.ssh/id_ed25519`
- passphrase 可为空

### 4.2 添加公钥到 GitHub

```bash
cat ~/.ssh/id_ed25519.pub
```

将输出粘贴到 GitHub → Settings → SSH and GPG keys → New SSH key。

> 注意：公钥是 `ssh-ed25519 AAAAC3...` 开头的完整行，不是 `SHA256:...` 指纹。

### 4.3 验证认证

```bash
ssh -T git@github.com
```

### 4.4 切换 Remote URL

```bash
git remote set-url origin git@github.com:<owner>/<repo>.git
git push
```

### 4.5 密钥权限修复

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
```

### 4.6（可选）SSH Config 多密钥配置

```
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
```

---

## 5. HTTPS 认证配置

### 5.1 使用 GitHub CLI 登录

```bash
gh auth login
```

选择 GitHub.com → HTTPS → 浏览器验证。

### 5.2 使用 Personal Access Token (PAT)

HTTPS 推送时 GitHub 不再接受密码，需使用 PAT：

1. GitHub → Settings → Developer settings → Personal access tokens → Generate new token
2. 勾选 `repo` 权限
3. 推送时用 token 代替密码

### 5.3 缓存凭据（免密码）

```bash
# 使用 credential store（明文存储，方便但安全性低）
git config --global credential.helper store

# 或使用 libsecret（Linux 密钥环，更安全）
git config --global credential.helper /usr/share/doc/git/contrib/credential/libsecret/git-credential-libsecret
```

---

## 6. 常见报错排查

| 报错 | 原因 | 解决 |
|---|---|---|
| `Failed to connect to github.com port 443` | HTTPS 不通 | 切换到 SSH（§3.1）或检查代理（§2） |
| SSH 卡在 `KEX_ECDH_REPLY` | SSH 端口被封 | 改用 443 端口（§3.2）或切 HTTPS（§3.3） |
| `Permission denied (publickey)` | SSH key 未配置或未添加到 GitHub | 按 §4 配置 SSH key |
| `Repository not found` | 无仓库访问权限 | 确认仓库路径和账号权限 |
| `rejected (non-fast-forward)` | 远端有本地没有的提交 | `git pull --rebase && git push` |
| `src refspec main does not match any` | 尚无提交 | 先 `git add . && git commit` |

---

## 7. 快速决策流程

```
git push 卡住/报错
  │
  ├─ 用的是 HTTPS？
  │    ├─ curl -I https://github.com 不通 → 切换到 SSH（§3.1）
  │    └─ curl 通但 git 不行 → 检查代理配置（§2）
  │
  └─ 用的是 SSH？
       ├─ ssh -T 卡在 KEX → SSH 端口被封
       │    ├─ 改 443 端口（§3.2）
  │    └─ 443 也不行 → 切 HTTPS（§3.3）
       ├─ Permission denied → 配置 SSH key（§4）
       └─ SSH 通但 git 不行 → 检查 remote URL 和仓库权限
```

---

## 8. 快速操作步骤

### 8.1 HTTPS 不通 → 切换到 SSH

```bash
# 1. 确认 SSH 认证可用
ssh -T git@github.com
# 期望输出: Hi <username>! You've successfully authenticated...

# 2. 切换 remote URL
git remote set-url origin git@github.com:<user>/<repo>.git

# 3. 确认切换成功
git remote -v
# 期望: origin  git@github.com:<user>/<repo>.git

# 4. 推送
git push
```

> 如果 SSH 认证未通过，需先按 §4 配置 SSH key。

### 8.2 SSH 端口 22 不通 → 改用 443 端口

```bash
# 1. 编辑 SSH 配置
nano ~/.ssh/config
# 添加以下内容:
#   Host github.com
#     Hostname ssh.github.com
#     Port 443
#     User git

# 2. 测试连接
ssh -T git@github.com
# 首次连接输入 yes 确认主机密钥

# 3. 推送（remote URL 不需要改，仍是 git@github.com:...）
git push
```

### 8.3 SSH 22 和 443 都不通 → 切换到 HTTPS

```bash
# 1. 确认 HTTPS 可用
curl -I https://github.com
# 期望: HTTP/2 200

# 2. 切换 remote URL
git remote set-url origin https://github.com/<user>/<repo>.git

# 3. 确认切换成功
git remote -v
# 期望: origin  https://github.com/<user>/<repo>.git

# 4. 推送（使用 gh auth 或 PAT 自动认证）
git push
```

> 如果提示输入密码，使用 Personal Access Token（不是 GitHub 密码）。已配置 `gh auth login` 或 `credential.helper store` 则自动认证。

### 8.4 从零配置 SSH Key（HTTPS → SSH 前置步骤）

```bash
# 1. 生成密钥
ssh-keygen -t ed25519 -C "你的邮箱"
# 一路回车（默认路径，空 passphrase）

# 2. 查看公钥
cat ~/.ssh/id_ed25519.pub
# 复制输出（ssh-ed25519 AAAAC3... 开头的完整行）

# 3. 添加到 GitHub
# 浏览器打开: https://github.com/settings/ssh/new
# Title 随意填，Key 粘贴公钥，点击 Add SSH key

# 4. 验证
ssh -T git@github.com
# 期望: Hi <username>! You've successfully authenticated...

# 5. 切换 remote 并推送
git remote set-url origin git@github.com:<user>/<repo>.git
git push
```

### 8.5 恢复协议（反向切换）

```bash
# SSH → HTTPS
git remote set-url origin https://github.com/<user>/<repo>.git

# HTTPS → SSH
git remote set-url origin git@github.com:<user>/<repo>.git

# 取消 SSH 443 端口配置（恢复默认端口 22）
# 删除 ~/.ssh/config 中 github.com 相关段落，或:
sed -i '/Host github.com/,/User git/d' ~/.ssh/config
```
