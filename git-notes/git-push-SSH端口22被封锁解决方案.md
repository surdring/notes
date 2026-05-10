# git push 长时间无响应 — SSH 端口 22 被封锁解决方案

## 问题现象

执行 `git push` 时长时间无响应，最终超时或需手动中断。

## 诊断步骤

通过 `ssh -T git@github.com -v` 测试 SSH 连接，发现连接在密钥交换阶段卡住：

```
debug1: SSH2_MSG_KEXINIT sent
debug1: SSH2_MSG_KEXINIT received
debug1: kex: algorithm: sntrup761x25519-sha512@openssh.com
...
debug1: expecting SSH2_MSG_KEX_ECDH_REPLY
（卡住）
```

**原因**：GitHub SSH 端口 22 被网络防火墙/ISP 干扰或封锁，导致密钥交换无法完成。

## 解决方案：改用 443 端口

GitHub 提供了通过 443 端口的 SSH 访问（`ssh.github.com`），443 端口通常不会被封锁。

### 配置方法

编辑 `~/.ssh/config`，添加以下内容：

```
Host github.com
  Hostname ssh.github.com
  Port 443
  User git
```

### 验证连接

```bash
ssh -T git@github.com
```

首次连接会提示确认主机密钥，输入 `yes` 即可。成功后会显示：

```
Hi <username>! You've successfully authenticated, but GitHub does not provide shell access.
```

### 验证 git push

配置完成后 `git push` 即可正常使用，无需其他修改。

## 注意事项

- 首次通过 443 端口连接时，需确认主机指纹（输入 `yes`），系统会自动将 `ssh.github.com:443` 添加到 `~/.ssh/known_hosts`
- 该配置仅影响 GitHub 的 SSH 连接，不影响其他 SSH 连接
- 如果之后网络环境变化（端口 22 恢复正常），删除 `~/.ssh/config` 中的该段配置即可恢复默认行为
