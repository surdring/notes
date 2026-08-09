

### 第一步：紧急释放磁盘空间（止血）

由于磁盘已满，禁止直接使用 `rm` 删除正在被进程引用的日志文件（会导致空间无法立即释放），必须使用 `truncate` 清空。

```bash
# 1. 瞬间清空巨型历史日志和当前日志
sudo truncate -s 0 /var/log/syslog.1
sudo truncate -s 0 /var/log/syslog

# 2. 清理 systemd journal 日志（限制在100M以内）
sudo journalctl --vacuum-size=100M

# 3. 确认空间已释放
df -h /
```

### 第二步：定位并终止异常刷屏进程

通过实时监控日志，找出疯狂写入错误的元凶进程并强制终止。

```bash
# 1. 实时查看报错进程（观察几秒后按 Ctrl+C 退出）
sudo tail -f /var/log/syslog | grep -iE "error|fail"

# 2. 获取元凶进程的 PID（以 update-notifier-crash 为例）
ps aux | grep update-notifier-crash

# 3. 强制杀掉该进程（将 <PID> 替换为实际查到的数字）
sudo kill -9 <PID>
```

### 第三步：修复日志目录权限

确保 `/var/log` 目录具备正确的属主和权限，防止后续 `logrotate` 和 `rsyslog` 因权限问题拒绝工作。

```bash
sudo chown root:syslog /var/log
sudo chmod 755 /var/log
```

### 第四步：优化日志轮转配置（加装安全阀）

修改 `logrotate` 配置，增加 `maxsize` 限制，确保单个日志文件永远不会超过 500MB。

```bash
sudo nano /etc/logrotate.d/rsyslog
```

**将文件内容替换为以下优化版本**（核心改动：增加 `su root syslog`、`daily`、`maxsize 500M`）：

```text
/var/log/syslog
/var/log/mail.log
/var/log/kern.log
/var/log/auth.log
/var/log/user.log
/var/log/cron.log
{
        su root syslog
        rotate 7
        daily
        maxsize 500M
        missingok
        notifempty
        compress
        delaycompress
        sharedscripts
        postrotate
                /usr/lib/rsyslog/rsyslog-rotate
        endscript
}
```

_保存并退出（Ctrl+O -> Enter -> Ctrl+X）。_

### 第五步：重建日志文件并重启服务

由于强制轮转和权限变更，`rsyslog` 可能会丢失日志文件句柄并报 `omfile suspended (error 2007)` 错误。需手动预创建文件并赋予正确权限。

```bash
# 1. 批量创建缺失的日志文件
sudo touch /var/log/syslog /var/log/auth.log /var/log/kern.log /var/log/mail.err

# 2. 设置正确的属主（syslog:adm）和权限（640）
sudo chown syslog:adm /var/log/syslog /var/log/auth.log /var/log/kern.log /var/log/mail.err
sudo chmod 640 /var/log/syslog /var/log/auth.log /var/log/kern.log /var/log/mail.err

# 3. 强制执行一次日志轮转，使新配置生效
sudo logrotate -f /etc/logrotate.d/rsyslog

# 4. 重启 rsyslog 服务
sudo systemctl restart rsyslog
```

### 第六步：最终验证与善后

确认系统日志服务恢复正常，且无报错。

```bash
# 1. 检查 rsyslog 是否还有 suspended 报错（预期输出为 0）
journalctl -u rsyslog --no-pager -n 10 | grep -c "suspended"

# 2. 确认日志文件正在正常写入
ls -lh /var/log/syslog /var/log/auth.log /var/log/kern.log

# 3. 彻底修复元凶软件（防止重启后再次崩溃刷屏）
sudo apt install --reinstall update-notifier update-notifier-common
# 或者如果不需要桌面更新提示，可直接禁用：
# systemctl --user mask update-notifier.service
```

---

### 💡 核心经验总结

1. **清理运行中的日志**：永远使用 `truncate -s 0` 而不是 `rm`。
2. **logrotate 必加双保险**：生产或开发环境务必配置 `maxsize`（如 500M），不能仅依赖 `daily` 或 `weekly`。
3. **rsyslog error 2007**：遇到 `omfile suspended` 报错，99% 是因为目标日志文件缺失或属主不是 `syslog:adm`，手动 `touch` 并 `chown` 即可解决。