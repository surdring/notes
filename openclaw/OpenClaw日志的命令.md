# 实时跟踪日志（最常用）
openclaw logs --follow --plain

# 或带行数限制的实时日志
openclaw logs --follow --plain --limit 500

# 系统日志方式（若使用systemd）
journalctl --user -u openclaw-gateway -f

# 查看最近200条后持续跟踪
openclaw logs --limit 200 --plain && openclaw logs --follow --plain