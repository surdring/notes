# OpenClaw × WhatsApp 语音陪练接入指南（Linux，本地优先）

> 目标：把 WhatsApp 作为 OpenClaw 的主要“对话入口”，并支持“语音陪练”（收语音 → 转写 → 生成回复 →（可选）合成语音发回）。
>
> 安全基线：
>
> - **不写密钥**：token / api key 不进入仓库、不出现在截图和示例 URL。
> - **不暴露公网**：默认只在 `127.0.0.1:18789` 监听；需要远程访问时优先 tailnet / 可信反代。
> - **可追踪**：每次 WhatsApp 触发都能定位到 OpenClaw 日志；若引入 n8n，也能定位到执行记录。

---

## 0. 你会用到的 3 条链路（先选型）

- **主线（推荐）：WhatsApp Web Channel（OpenClaw 内置）**
  - 你用一个 WhatsApp 账号（建议专号）通过“已连接设备”扫码登录。
  - OpenClaw Gateway 持有连接并收发消息。
  - 适合个人助理/陪练：不限 24h 窗口，交互更自然。

- **业务号链路（不推荐）：WhatsApp Business / Twilio**
  - 官方明确不适合个人助理：
    - 24 小时回复窗口限制（无法随时发起对话）
    - 高强度对话更易触发风控
    - 可靠性差，相关支持在早期版本后被移除

- **编排增强（可选）：WhatsApp → n8n → OpenClaw（用于长耗时/重试/告警/ASR/TTS）**
  - OpenClaw 仍作为“主对话/工具执行”中枢。
  - n8n 承担：
    - 语音转写（ASR）
    - 语音合成（TTS）
    - 重试、队列、补偿、失败告警
  - OpenClaw Webhooks（`/hooks/*`）用于 n8n 与 OpenClaw 互相触发。

---

## 1. 前置条件

- **OpenClaw Gateway 本地已跑通**
  - 健康检查：`curl -sS -m 2 http://127.0.0.1:18789/health`
  - 常用日志：
    - `openclaw logs --limit 200 --plain`
    - `journalctl --user -u openclaw-gateway -n 200 --no-pager`

- **准备 WhatsApp 两机两号（强烈推荐）**
  - **专号（助理号）**：用于登录 WhatsApp Web，并长期在线
  - **你的个人号**：与助理号私聊、拉群测试

- **明确 DM 安全策略**（不要 open-to-world）
  - 推荐：`dmPolicy: "pairing"`（默认）或 `dmPolicy: "allowlist"`

---

## 2. WhatsApp Web Channel 接入（推荐主线）

### 2.1 最小可用配置（MVP）

在 `~/.openclaw/openclaw.json` 配置 WhatsApp（示例仅占位）：

```json
{
  "channels": {
    "whatsapp": {
      "dmPolicy": "allowlist",
      "allowFrom": ["+<YOUR_E164_NUMBER>"]
    }
  }
}
```

说明：

- `allowFrom` 使用 **E.164**（如 `+8613xxxxxxxxx`）。
- 如果你用默认 `dmPolicy: "pairing"`，则陌生号码会收到配对码，需你批准。

### 2.2 登录（扫码绑定 WhatsApp Web）

如果你遇到以下报错：

- `Unknown channel: whatsapp`
- `Unsupported channel: whatsapp`

说明当前机器上的 WhatsApp Channel 插件未启用。先执行：

```bash
openclaw plugins enable whatsapp
systemctl --user restart openclaw-gateway
```

- 单账号：

```bash
openclaw channels login --channel whatsapp
```

如果出现二维码，按以下路径扫码：

- WhatsApp → 设置 → 已连接设备（Linked Devices）→ 连接设备 → 扫码

- 多账号（可选）：

```bash
openclaw channels login --channel whatsapp --account <accountId>
```

凭据位置（用于备份/迁移/排错）：

- `~/.openclaw/credentials/whatsapp/<accountId>/creds.json`
- 损坏回滚：`creds.json.bak`

退出：

```bash
openclaw channels logout --channel whatsapp
```

登录成功的典型输出（用于对照排错）：

- `Scan this QR in WhatsApp (Linked Devices):`（出现二维码）
- `WhatsApp Web connected.`（成功建立连接）
- 首次配对后可能出现：
  - `WhatsApp asked for a restart after pairing (code 515); creds are saved. Restarting connection once…`
  - `✅ Linked after restart; web session ready.`

登录完成后建议立刻在 Gateway 上做一次状态验证：

```bash
openclaw channels status --probe
openclaw channels logs --channel whatsapp --lines 200
```

期望看到类似：

- `WhatsApp default: enabled, configured, linked, running, connected`
- 日志包含：`Listening for personal WhatsApp inbound messages.`

### 2.3 建议开启的“可用性配置”

WhatsApp 单条文本有长度上限（默认 4k 左右）。建议按需要调整：

- `channels.whatsapp.textChunkLimit`：默认 `4000`
- `channels.whatsapp.chunkMode`：
  - `length`（按长度切）
  - `newline`（更适合段落输出）

媒体大小建议：

- `agents.defaults.mediaMaxMb`：用于控制出站媒体上限（默认偏保守）

### 2.4 DM 策略与配对（强烈建议掌握）

- **pairing 模式**：陌生号码会收到配对码（有效期 1 小时）
- 查看待配对：

```bash
openclaw pairing list whatsapp
```

- 批准：

```bash
openclaw pairing approve whatsapp <code>
```

备注：你的“已登录 WhatsApp 账号本身”被视为可信，给自己发消息会跳过 `dmPolicy/allowFrom`。

---

## 3. 群聊与“点名才回应”（陪练/助理强烈推荐）

目标：避免群里噪音触发，让机器人只在你 **@ 它** 时回复。

建议策略：

- **群聊默认 requireMention**
- **命令权限**（如 `/reset`、`/new`、`/compact`）只放给管理员

具体键位在 OpenClaw 配置参考的 group policy / mention gating 章节；落地原则是：

- **群里不 @ 就不响应**
- **群里可以把 systemPrompt 缩短**（减少跑偏）

---

## 4. 语音陪练：端到端设计（推荐实践）

语音陪练的“可靠”路径，通常是把语音当作一条异步任务：

- **WhatsApp 收到语音**（PTT）
- **转写（ASR）**：得到文本 +（可选）时间戳
- **对话生成**：OpenClaw 以“转写文本”为输入，生成纠错/跟读/对话推进
- **（可选）合成语音（TTS）**：发回 WhatsApp 语音条

### 4.1 为什么推荐用 n8n 做 ASR/TTS 编排

满足以下任一条件就建议上 n8n：

- 语音转写耗时可能超交互时限
- 想要重试/补偿/告警
- 想做多分支（例如：音频过大、噪声过大、语言识别失败）
- 想审计每次语音任务（n8n execution）

### 4.2 OpenClaw Webhooks：作为编排触发入口

OpenClaw Gateway 支持 `hooks`：

- 开启：`hooks.enabled: true` 时 **必须** 配 `hooks.token`
- 鉴权建议用：`Authorization: Bearer <token>`（不要把 token 写进仓库/文档）
- 官方安全建议：hook endpoint 放在 loopback/tailnet/可信反代之后；hook payload 视为不可信

你会用到的两个“通用端点”：

- `POST /hooks/agent`：给某个 agent 投递一条消息（可指定 `agentId/sessionKey/model/...`）
- `POST /hooks/<name>`：通过 mappings 做结构化映射（更适合 n8n）

> 你可以让 n8n 在“转写完成后”调用 `POST /hooks/agent` 把转写文本投递给 OpenClaw；也可以用 `POST /hooks/<name>` 做模板化的 payload → message 映射。

### 4.3 关键难点：WhatsApp 入站语音如何拿到音频文件

这里取决于 OpenClaw WhatsApp channel 对“入站媒体”的落盘/引用方式（不同版本可能变化）。因此建议你按以下方式推进：

- **先用日志/调试确认**：入站媒体在 OpenClaw 会以什么形式进入上下文（URL、本地路径、附件对象等）
- **再决定 ASR 的实现位置**：
  - 若能稳定拿到本地文件路径：
    - 方案 1：OpenClaw 工具链本地调用转写（简单）
    - 方案 2：把文件交给 n8n（更可靠）
  - 若只能拿到可下载 URL：
    - 让 n8n 先下载再转写（更自然）

---

## 5. WhatsApp 出站语音（TTS / 语音条）要点

官方要点：

- 最佳格式：**OGG/Opus**
- OpenClaw 会把 `audio/ogg` 规范化为 `audio/ogg; codecs=opus`
- WhatsApp 上表现为语音条（PTT）

建议约束：

- 控制单条语音时长（比如 20-40 秒）
- 对长回复：优先“先发文字要点 + 再发短语音”

### 5.1 最小可用：让“发语音 → 自动转写 → 回语音”跑通（本地优先）

你需要两块能力：

- **ASR（入站语音转写）**：把 WhatsApp 语音条转成文本（模型才能理解）
- **TTS（出站语音合成）**：把模型回复的文本合成音频，再以 WhatsApp 语音条（PTT）发回

#### 5.1.1 启用 TTS（Edge TTS，无需 API Key）

推荐设置为：仅当你发来语音时才回语音（避免每条都语音很吵）：

```bash
openclaw config set messages.tts --json '{
  "auto": "inbound",
  "provider": "edge",
  "edge": {
    "enabled": true,
    "voice": "zh-CN-XiaoxiaoNeural",
    "lang": "zh-CN",
    "outputFormat": "audio-24khz-48kbitrate-mono-mp3"
  }
}'
```

#### 5.1.2 启用 ASR（OpenClaw 音频理解）

```bash
openclaw config set tools.media.audio.enabled true
```

说明：该功能会自动探测可用的本地转写 CLI（或云端 key）。如果你没有安装任何 ASR 后端，OpenClaw 依然会“收到语音”，但无法转写。

#### 5.1.3 安装本地转写后端（Whisper CLI via pipx）

在 Ubuntu 上建议：`ffmpeg` + `pipx` + `openai-whisper`（命令名 `whisper`）。

```bash
sudo apt update
sudo apt install -y ffmpeg pipx python3-venv

pipx ensurepath
pipx install openai-whisper

command -v whisper
whisper --help | head
```

#### 5.1.4 让 systemd 常驻的 openclaw-gateway 也能找到 whisper

如果你是用 `systemctl --user` 常驻 gateway（推荐），它的 PATH 可能不包含 `~/.local/bin`，导致 OpenClaw 探测不到 `whisper`。

```bash
systemctl --user edit openclaw-gateway
```

加入（在你已有的 `ALL_PROXY`/`NODE_OPTIONS` 旁边即可）：

```ini
[Service]
Environment=PATH=%h/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
```

重启生效：

```bash
systemctl --user restart openclaw-gateway
```

#### 5.1.5 端到端验证与日志

```bash
openclaw logs --follow --plain
```

然后从 WhatsApp 发一条 10-20 秒语音给助理号，期望：

- 能看到入站语音被识别（WhatsApp inbound 会显示 `audio/ogg; codecs=opus`）
- 能看到 ASR 转写被触发（日志会出现转写/替换 body/Transcript 相关信息，不同版本字段可能略有差异）
- 机器人回你一条语音条（因为 `messages.tts.auto: inbound`）

备注：`openclaw channels logs` 目前不支持 `--follow`，实时滚动用 `openclaw logs --follow --plain`。

---

## 6. 可观测性与排错清单（WhatsApp 专项）

### 6.1 首先确认 Gateway 常驻与连接健康

- `curl -sS -m 2 http://127.0.0.1:18789/health`
- `openclaw logs --limit 200 --plain`
- `journalctl --user -u openclaw-gateway -n 200 --no-pager`

### 6.2 常见问题与定位

- **channels login 报 408（Request Time-out WebSocket Error）**
  - 现象：
    - `openclaw channels login --channel whatsapp --verbose` 输出：
      - `WhatsApp Web connection ended before fully opening. status=408 Request Time-out WebSocket Error ()`
  - 典型根因：
    - 直连被阻断（需要代理）
    - 但 WhatsApp Web 连接是 WebSocket（Baileys + Node `ws`），在部分环境下**不会自动读取** `HTTP_PROXY/HTTPS_PROXY/ALL_PROXY`，导致看起来“curl 走代理能通，但 login 仍超时”。
  - 先做两条基准验证：
    - 直连：`curl -I https://web.whatsapp.com --max-time 8`
    - 代理：
      - HTTP 代理示例：`HTTPS_PROXY=http://127.0.0.1:<PORT> HTTP_PROXY=http://127.0.0.1:<PORT> curl -I https://web.whatsapp.com --max-time 10`
      - SOCKS 示例：`ALL_PROXY=socks5h://127.0.0.1:<PORT> curl -I https://web.whatsapp.com --max-time 10`
  - 修复优先级（推荐从上到下尝试）：
    - 方案 A（推荐）：开启 Clash 的 **TUN 模式**（或系统级透明代理），让 OpenClaw 的出站 TCP/WSS 也被透明接管，然后重试 `openclaw channels login`。
    - 方案 B：启用本机 SOCKS5 端口，并用 `ALL_PROXY=socks5h://127.0.0.1:<SOCKS_PORT>` 包装执行登录命令（`socks5h` 让 DNS 也走代理）。
    - 方案 C：用 `proxychains` 之类的透明注入方式包装 `openclaw channels login`（适合不想开 TUN 的场景）。
    - 方案 D：确保代理客户端允许 WebSocket（WSS）与相关端口；WhatsApp Web 可能使用 `wss://web.whatsapp.com:5222` 等连接。

  - 如果你用的是 `systemctl --user` 常驻 gateway（推荐），并且处于需要代理的网络环境，建议把代理写进 `openclaw-gateway` 的 systemd 环境变量：

```bash
systemctl --user edit openclaw-gateway
```

写入（示例使用本机 SOCKS 端口）：

```ini
[Service]
Environment=ALL_PROXY=socks5h://127.0.0.1:<SOCKS_PORT>
Environment=NODE_OPTIONS=--dns-result-order=ipv4first
```

应用并验证：

```bash
systemctl --user restart openclaw-gateway
systemctl --user show openclaw-gateway --property=Environment
openclaw channels status --probe
```

  - 推荐的一次性验证序列：
    - 确认端口监听（示例）：`ss -ltnp | egrep ':(7897|7898)\b' || true`
    - SOCKS 通路：`ALL_PROXY=socks5h://127.0.0.1:<SOCKS_PORT> curl -I https://web.whatsapp.com --max-time 10`
    - 登录：`ALL_PROXY=socks5h://127.0.0.1:<SOCKS_PORT> openclaw channels login --channel whatsapp --verbose`
    - 成功后凭据会写入：`~/.openclaw/credentials/whatsapp/<accountId>/creds.json`

- **发不出去消息**
  - 常见原因：Gateway 没在跑（WhatsApp web listener 不存在会 fail fast）

- **收不到入站消息**
  - 常见原因：掉线/登出/凭据损坏
  - 处理：检查是否 logged-out；必要时 `openclaw channels login` 重新扫码

- **陌生人 DM 打进来**
  - 预期行为：`dmPolicy: "pairing"` 下会发 pairing code
  - 操作：`openclaw pairing list whatsapp` + `openclaw pairing approve whatsapp <code>`

- **输出过长被截断/发送失败**
  - 调整：`channels.whatsapp.textChunkLimit` + `channels.whatsapp.chunkMode`

- **媒体发送失败/过大**
  - 调整：`agents.defaults.mediaMaxMb`
  - 降级：先发文字，再发压缩后媒体

---

## 7. 验收（你可以按这个顺序做端到端验证）

- **步骤 1：基础私聊**
  - 你的个人号 → 助理号：发 `ping`
  - 期望：OpenClaw 回复

- **步骤 2：pairing/allowlist 校验**
  - 用另一个号码发消息
  - 期望：
    - pairing：收到配对码
    - allowlist：被拒绝/忽略（按策略）

- **步骤 3：群聊点名**
  - 拉群，发不带 @ 的消息
  - 期望：不回复
  - 再 @ 助理发问
  - 期望：回复

- **步骤 4：语音链路（最小闭环）**
  - 发一条短语音
  - 期望：
    - 至少能看到入站媒体在日志里被识别
    - 你能明确媒体如何进入 agent 上下文（路径/URL/附件对象）

- **步骤 5：语音陪练（完整闭环，含 ASR/TTS）**
  - ASR：能稳定产出转写文本
  - LLM：能基于转写进行纠错/对练
  - TTS：能回发语音条（OGG/Opus）

---

## 8. 下一步我需要你确认的两件事（我再把“语音陪练”落到可执行配置）

- **问题 1：你希望 ASR/TTS 跑在哪里？**
  - A：全在 OpenClaw 本机（追求简单）
  - B：n8n 编排（追求可靠、重试、审计、告警）

- **问题 2：你用的 WhatsApp 是“专号助理号”还是“个人号复用”？**
  - 专号更稳定，也更安全

---

## 参考（官方关键页面）

- WhatsApp Channel：`https://docs.openclaw.ai/channels/whatsapp`
- Gateway 配置参考：`https://docs.openclaw.ai/gateway/configuration`
- Webhooks：`https://docs.openclaw.ai/automation/webhook`
