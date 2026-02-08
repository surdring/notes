### 1. 创建服务文件

```bash
# 创建用户级服务目录
mkdir -p ~/.config/systemd/user

# 创建服务文件
nano ~/.config/systemd/user/frpc.service

# 添加执行权限
chmod +x ./frpc
```

### 2. 服务文件内容

```ini
[Unit]
# 服务名称，可自定义
Description = frp server
After = network.target syslog.target
Wants = network.target

[Service]
Type=simple
ExecStart=%h/frp/frpc -c %h/frp/frpc.toml
Restart=always
RestartSec=3
StartLimitIntervalSec=0

[Install]
WantedBy=default.target

```

### 3. 服务管理命令

```bash
# 重新加载 systemd 配置
systemctl --user daemon-reload
systemctl daemon-reload

# 启用服务（开机自启）
systemctl --user enable frpc.service
systemctl enable frps.service

# 启动服务
systemctl --user start frpc.service
systemctl start frps.service

# 查看服务状态
systemctl --user status frpc.service
systemctl status frps.service

# 停止服务
systemctl --user stop frpc.service
systemctl stop frps.service

# 重启服务
systemctl --user restart frpc.service

# 查看服务日志
journalctl --user -u frpc.service -f

systemctl --user stop frpc.service
systemctl --user disable frpc.service

# 执行：
systemctl --user stop frpc.service
systemctl --user daemon-reload
systemctl --user enable --now frpc
systemctl --user status frpc.service
journalctl --user -u frpc.service -f
```