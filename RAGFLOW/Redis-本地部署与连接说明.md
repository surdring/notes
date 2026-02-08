# Redis（Valkey）本地部署与连接说明

## 1. 当前结论

本机当前可用的 Redis 服务为 **Docker 容器部署**（实际镜像为 **Valkey**，Redis 协议/命令基本兼容）。

- **容器名称**：`docker-redis-1`
- **镜像**：`valkey/valkey:8`
- **宿主机监听端口**：`6381`（映射到容器内 `6379`）
- **监听地址**：`0.0.0.0:6381` / `[::]:6381`（对局域网可达，前提是防火墙放行）
- **认证方式**：启用密码（`requirepass`）
- **密码**：`infini_rag_flow`

> 说明：本机 systemd 的 `redis-server.service` 目前处于 failed 状态，且 `/etc/redis/redis.conf` 缺失；因此不作为当前可用 Redis 服务来源。

## 2. 本机连接方式

### 2.1 直接连接（带密码）

```bash
redis-cli -h 127.0.0.1 -p 6381 -a 'infini_rag_flow' ping
```

预期输出：`PONG`

### 2.2 推荐连接（避免命令行明文密码警告）

```bash
export REDISCLI_AUTH='infini_rag_flow'
redis-cli -h 127.0.0.1 -p 6381 ping
```

## 3. 局域网连接方式

本机局域网 IP：`172.16.100.211`

在局域网其它机器上连接：

```bash
redis-cli -h 172.16.100.211 -p 6381 -a 'infini_rag_flow' ping
```

或：

```bash
export REDISCLI_AUTH='infini_rag_flow'
redis-cli -h 172.16.100.211 -p 6381 ping
```

### 3.1 连接不上时的排查要点

- 检查宿主机端口监听：

```bash
ss -lntp | grep -E ':6381\b'
```

- 检查容器是否运行：

```bash
docker ps --filter name=docker-redis-1
```

- 检查宿主机防火墙是否拦截 `6381/tcp`（按实际系统选择）：

```bash
sudo ufw status
# 或
sudo iptables -S | head
```

## 4. 运维与确认命令

- 查看容器端口映射：

```bash
docker port docker-redis-1 6379
```

- 查看容器日志：

```bash
docker logs --tail 200 docker-redis-1
```

- 基础信息确认：

```bash
export REDISCLI_AUTH='infini_rag_flow'
redis-cli -h 127.0.0.1 -p 6381 info server
redis-cli -h 127.0.0.1 -p 6381 dbsize
```

## 5. 安全建议（重要）

- 当前为 `0.0.0.0:6381` 监听，意味着**局域网可访问**；请务必确保防火墙策略不要把 `6381` 暴露到公网。
- 建议至少做到其一：
  - 仅放行内网网段对 `6381/tcp` 的访问
  - 通过 VPN/WireGuard/Tailscale 等方式接入后再访问
  - 使用 SSH 隧道转发访问（不对外开放端口）

---

## 6. 给应用的连接参数（建议统一）

- `REDIS_HOST=172.16.100.211`（同机可用 `127.0.0.1`）
- `REDIS_PORT=6381`
- `REDIS_PASSWORD=infini_rag_flow`
