# Clash Verge 规则方式使用指南

## 一、Clash Verge 是什么

Clash Verge 是 Clash 内核的 GUI 客户端（Windows / macOS / Linux），提供一个可视化的配置管理界面，核心功能：

- **订阅管理**：导入机场/自建代理订阅
- **规则管理**：通过规则控制哪些域名/IP 走代理、哪些直连
- **代理模式**：切换全局/规则/直连模式
- **日志查看**：实时查看请求匹配了哪条规则

---

## 二、安装

| 平台 | 下载地址 |
|---|---|
| GitHub Releases | https://github.com/clash-verge-rev/clash-verge-rev/releases |
| Windows | `.exe` / `.msix` 安装包 |
| macOS | `.dmg`（Intel / Apple Silicon） |
| Linux | `.deb` / `.AppImage` |

Linux 示例（Ubuntu/Debian）：

```bash
# 下载最新 deb 包
wget https://github.com/clash-verge-rev/clash-verge-rev/releases/latest/download/Clash.Verge_x86-64.deb

sudo dpkg -i Clash.Verge_x86-64.deb
```

---

## 三、理解 Clash 的三种代理模式

| 模式 | 行为 | 适用场景 |
|---|---|---|
| **规则（Rule）** | 按规则文件匹配，命中的走对应策略，未命中的走直连 | **日常推荐** |
| **全局（Global）** | 所有流量都走代理 | 临时需要全部翻墙 |
| **直连（Direct）** | 所有流量都直连 | 排查网络问题时 |

通常保持 **规则模式** 即可。

---

## 四、规则系统详解

### 4.1 规则匹配顺序

Clash 的规则是**从上到下逐条匹配**，匹配到第一条就停止，不再继续匹配后面的规则。

```
规则 A  →  规则 B  →  规则 C  →  规则 D
└─ 命中则停   └─ 命中则停   └─ 命中则停   └─ 兜底
```

**所以：精确的规则放前面，宽泛的兜底规则放最后。**

### 4.2 规则类型

| 规则类型 | 格式 | 说明 | 示例 |
|---|---|---|---|
| **DOMAIN** | `DOMAIN,example.com,Proxy` | 精确匹配完整域名 | `DOMAIN,google.com,Proxy` |
| **DOMAIN-SUFFIX** | `DOMAIN-SUFFIX,example.com,Proxy` | 匹配域名后缀 | `DOMAIN-SUFFIX,google.com,Proxy` → 匹配 `www.google.com`、`api.google.com` 等 |
| **DOMAIN-KEYWORD** | `DOMAIN-KEYWORD,keyword,Proxy` | 匹配域名中包含的关键词 | `DOMAIN-KEYWORD,youtube,Proxy` → 匹配任何含有 `youtube` 的域名 |
| **IP-CIDR** | `IP-CIDR,192.168.0.0/16,DIRECT` | 匹配 IP 段 | `IP-CIDR,10.0.0.0/8,DIRECT` → 内网直连 |
| **SRC-IP-CIDR** | `SRC-IP-CIDR,192.168.1.100/32,Proxy` | 匹配来源 IP | 指定某台设备走代理 |
| **DST-PORT** | `DST-PORT,80,DIRECT` | 匹配目标端口 | `DST-PORT,80,DIRECT` → HTTP 直连 |
| **SRC-PORT** | `SRC-PORT,7890,Proxy` | 匹配来源端口 |  |
| **GEOIP** | `GEOIP,CN,DIRECT` | 匹配 IP 地理位置 | `GEOIP,CN,DIRECT` → 国内 IP 直连 |
| **GEOSITE** | `GEOSITE,youtube,Proxy` | 匹配域名分类集合 | `GEOSITE,google,Proxy` → 所有 Google 系域名走代理 |
| **MATCH** | `MATCH,Proxy` | 兜底规则，匹配所有未被前面规则命中的流量 | **必须放在最后一条** |

### 4.3 策略类型

每条规则需要指定一个**策略**（即这条规则匹配后走哪里）：

| 策略 | 含义 |
|---|---|
| `Proxy` / 节点组名 | 走代理节点/节点组 |
| `DIRECT` | 直连（不经过代理） |
| `REJECT` | 拒绝连接（常用于屏蔽广告） |
| `PASS` | 跳过（不处理，留给后续规则） |

---

## 五、实战：编写一份完整的规则文件

### 5.1 规则文件结构

一份完整的 Clash 配置文件（`config.yaml`）大致结构：

```yaml
# HTTP 代理端口
port: 7890

# SOCKS5 代理端口
socks-port: 7891

# HTTP(S) 代理端口（用于给 curl 等命令行工具用，结合 -x）
mixed-port: 7897

# 允许局域网的连接
allow-lan: false

# 代理模式: Rule / Global / Direct
mode: Rule

# 日志级别: info / debug / warning / error
log-level: info

# ---------- 代理节点 ----------
proxies:
  - name: "香港节点-01"
    type: ss
    server: example.com
    port: 443
    cipher: chacha20-ietf-poly1305
    password: "your-password"

  - name: "日本节点-01"
    type: vmess
    server: example.jp
    port: 443
    uuid: "your-uuid"
    alterId: 0
    cipher: auto

# ---------- 代理组 ----------
proxy-groups:
  # 自动选择：Clash 会自动测速选择最快的节点
  - name: "Auto"
    type: url-test
    proxies:
      - "香港节点-01"
      - "日本节点-01"
    url: "http://www.gstatic.com/generate_204"
    interval: 300

  # 手动选择：在面板里手动切换
  - name: "Proxy"
    type: select
    proxies:
      - "Auto"
      - "香港节点-01"
      - "日本节点-01"
      - "DIRECT"

  # 广告拦截：走 REJECT
  - name: "AdBlock"
    type: select
    proxies:
      - "REJECT"
      - "DIRECT"

# ---------- 规则 ----------
rules:
  # 广告/追踪域名 - 屏蔽
  - DOMAIN-SUFFIX,doubleclick.net,AdBlock
  - DOMAIN-SUFFIX,googleadservices.com,AdBlock
  - DOMAIN-KEYWORD,adservice,AdBlock

  # 内网地址 - 直连
  - IP-CIDR,127.0.0.0/8,DIRECT
  - IP-CIDR,10.0.0.0/8,DIRECT
  - IP-CIDR,172.16.0.0/12,DIRECT
  - IP-CIDR,192.168.0.0/16,DIRECT

  # 国内常用 - 直连（加速访问）
  - DOMAIN-SUFFIX,cn,DIRECT
  - DOMAIN-SUFFIX,baidu.com,DIRECT
  - DOMAIN-SUFFIX,qq.com,DIRECT
  - DOMAIN-SUFFIX,aliyun.com,DIRECT

  # Google 系 - 走代理
  - DOMAIN-SUFFIX,google.com,Proxy
  - DOMAIN-SUFFIX,googleapis.com,Proxy
  - DOMAIN-SUFFIX,gstatic.com,Proxy
  - DOMAIN-SUFFIX,youtube.com,Proxy

  # OpenAI / AI 服务 - 走代理
  - DOMAIN-SUFFIX,openai.com,Proxy
  - DOMAIN-SUFFIX,aistudio.google.com,Proxy
  - DOMAIN-SUFFIX,generativelanguage.googleapis.com,Proxy

  # GitHub - 走代理（国内直连不稳定）
  - DOMAIN-SUFFIX,github.com,Proxy
  - DOMAIN-SUFFIX,githubusercontent.com,Proxy

  # 国外其他 - 走代理
  - GEOIP,CN,DIRECT
  - MATCH,Proxy
```

### 5.2 使用 GEOSITE 简化规则

GEOSITE 是 Clash 内置的域名分类数据库，可以一条规则覆盖一大类域名。需要配合规则集（rule-provider）使用：

```yaml
rule-providers:
  google:
    type: http
    behavior: domain
    url: "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/google.txt"
    path: ./ruleset/google.yaml
    interval: 86400

  openai:
    type: http
    behavior: domain
    url: "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/openai.txt"
    path: ./ruleset/openai.yaml
    interval: 86400

  ads:
    type: http
    behavior: domain
    url: "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/reject.txt"
    path: ./ruleset/reject.yaml
    interval: 86400

rules:
  - RULE-SET,ads,AdBlock
  - RULE-SET,google,Proxy
  - RULE-SET,openai,Proxy
  - GEOIP,CN,DIRECT
  - MATCH,Proxy
```

### 5.3 针对你场景的关键规则

如果你的需求是让 Gemini API 和其他被墙服务走代理，国内服务走直连，核心规则就这几条：

```yaml
rules:
  # --- 必须走代理的 ---
  # Gemini API
  - DOMAIN-SUFFIX,generativelanguage.googleapis.com,Proxy

  # Google 账号认证
  - DOMAIN-SUFFIX,googleapis.com,Proxy
  - DOMAIN-SUFFIX,accounts.google.com,Proxy
  - DOMAIN-SUFFIX,aistudio.google.com,Proxy

  # Brave Search API（如果需要）
  - DOMAIN-SUFFIX,api.search.brave.com,Proxy

  # GitHub
  - DOMAIN-SUFFIX,github.com,Proxy
  - DOMAIN-SUFFIX,githubusercontent.com,Proxy

  # Docker 镜像拉取
  - DOMAIN-SUFFIX,docker.com,Proxy

  # --- 直连的 ---
  - DOMAIN-SUFFIX,cn,DIRECT
  - DOMAIN-SUFFIX,baidu.com,DIRECT
  - DOMAIN-SUFFIX,qq.com,DIRECT

  # --- 兜底 ---
  - GEOIP,CN,DIRECT
  - MATCH,Proxy
```

---

## 六、在 Clash Verge 中配置规则

### 6.1 通过订阅自动获取规则

大多数机场的订阅链接自带规则，导入后直接在 Clash Verge 中使用：

1. **订阅** → **添加**
2. 粘贴订阅链接 → **导入**
3. 在 **代理** 面板选择节点
4. 在 **设置** 中确认 mode 为 **Rule**

### 6.2 手动编辑规则文件

在 Clash Verge 中：

1. 点击 **设置** → **配置文件**
2. 选择当前使用的配置文件
3. 点击 **编辑**（或直接用文本编辑器打开）
4. 编辑 `rules:` 部分后保存
5. Clash Verge 会自动重新加载配置

配置文件位置（Linux）：

```
~/.local/share/io.github.clash-verge-rev.clash-verge-rev/clash/profiles/
```

### 6.3 在 Clash Verge 中查看规则匹配情况

这是排查问题的关键功能：

1. 点击 **日志** 面板
2. 将日志级别设为 **info**（不要用 debug，太刷屏）
3. 发起一个请求（如 `curl https://generativelanguage.googleapis.com/...`）
4. 看日志中显示：

```
[Info] [TCP] 172.16.100.1:54321 --> generativelanguage.googleapis.com:443 match DOMAIN-SUFFIX,googleapis.com,Proxy using 香港节点-01
```

如果看到 `match MATCH,Proxy` 而不是具体的规则名，说明该域名没有被前面的精确规则捕获，走的兜底规则。你可以根据这个决定是否要加一条更精确的规则。

---

## 七、配合命令行工具使用

你的 curl 和程序走代理有两种方式：

### 方式一：通过 Clash 的 HTTP 代理端口 + 环境变量

```bash
# 假设 Clash mixed-port 或 HTTP port = 7897
export HTTP_PROXY=http://127.0.0.1:7897
export HTTPS_PROXY=http://127.0.0.1:7897
export NO_PROXY=localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16

curl -I https://www.google.com
```

### 方式二：通过 Clash 的 TUN 模式（虚拟网卡）

在 Clash Verge 中开启 **TUN 模式**：

- **设置** → **TUN 模式** → 开启
- 所有系统流量自动经 Clash 规则过滤，无需设置代理
- 适合：不想给每个程序单独配代理的情况
- 注意：需要安装虚拟网卡驱动（Clash Verge 首次开启时会自动提示安装）

### 方式三：curl 显式指定代理

```bash
curl -x http://127.0.0.1:7897 -k \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent" \
  -H "x-goog-api-key: $GEMINI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"contents": [{"parts": [{"text": "hello"}]}]}'
```

---

## 八、调试技巧

### 8.1 快速验证代理是否工作

```bash
# 测试 Google 连通性
curl -x http://127.0.0.1:7897 -I https://www.google.com

# 查看当前出口 IP（如果返回的不是国内 IP 说明走代理成功）
curl -x http://127.0.0.1:7897 https://httpbin.org/ip
```

### 8.2 查看规则匹配日志

在 Clash Verge **日志**面板，日志级别设为 `info`：

```
[Info] [TCP] 请求 --> 域名:端口 match 规则名 using 节点名
```

如果发现某个域名匹配了你不想要的规则（比如想走代理却走了 DIRECT），检查规则顺序，把更精确的规则放到前面。

### 8.3 测试特定域名的规则匹配

不需要真正发起请求，Clash Verge 提供了**测试**功能：

- **规则** 面板 → 输入域名 → 查看预期匹配结果

---

## 九、推荐的规则项目

不想自己写规则，直接用社区维护的规则集：

| 项目 | 说明 | 地址 |
|---|---|---|
| Loyalsoldier/clash-rules | 最流行的规则集，含 geoip、google、openai 等分类 | https://github.com/Loyalsoldier/clash-rules |
| blackmatrix7/ios_rule_script | 非常全面的规则集，按服务商分类 | https://github.com/blackmatrix7/ios_rule_script |
| AC4SSR/ACL4SSR | 另一个流行的规则集 | https://github.com/AC4SSR/ACL4SSR |

使用方式示例（在配置文件中引用 rule-provider）：

```yaml
rule-providers:
  google:
    type: http
    behavior: domain
    url: "https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/google.txt"
    path: ./ruleset/google.yaml
    interval: 86400
```

---

## 十、常见问题

### 10.1 规则不生效

- 检查 **模式** 是否为 **Rule**（不是 Global 或 Direct）
- 规则是**从上到下**匹配的，精确规则放前面
- 保存配置后 Clash 是否重新加载了（点 **重新加载** 按钮）
- 看日志确认匹配了哪条规则

### 10.2 部分 Google 服务能访问，部分不能

例如 `google.com` 能访问，但 `generativelanguage.googleapis.com` 不行。

原因：你的规则里只写了 `DOMAIN-SUFFIX,google.com,Proxy`，但没有覆盖 `googleapis.com`。

解决：增加 `DOMAIN-SUFFIX,googleapis.com,Proxy`，或者直接用 GEOSITE：

```yaml
- GEOSITE,google,Proxy
```

### 10.3 内网服务走代理导致超时

症状：访问 `172.16.100.211:8080` 很慢或超时。

原因：没有让内网 IP 走直连。

解决：在规则列表**靠前的位置**加入：

```yaml
- IP-CIDR,172.16.0.0/12,DIRECT
```

### 10.4 TLS connect error / SSL 证书问题

在 curl 命令中加 `-k` 参数跳过证书验证：

```bash
curl -x http://127.0.0.1:7897 -k https://...
```

或者在 `~/.curlrc` 中写入：

```
-k
```