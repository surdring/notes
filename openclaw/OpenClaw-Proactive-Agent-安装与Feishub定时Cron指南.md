# OpenClaw Proactive Agent 安装与 Feishub 定时 Cron 指南（workspace-butler）

> 目标：
> - 在 `workspace-butler` 正确启用 Proactive Agent 的 onboarding / 记忆文件体系。
> - 让 `feishub` 在白天（09:00-22:30，Asia/Shanghai）每 30 分钟主动发起一次“固定模板”的英语练习对话。
> - 全程遵循安全边界：**不对外**（除你本人 DM），可随时停用/删除。

---

## 0. 前置条件与安全约束

- OpenClaw Gateway 正常运行（本机 loopback）：`http://127.0.0.1:18789/`
- Feishu channel 已配置且可收发。
- **不写密钥**：文档/仓库/命令输出中不要出现 token/key。
- **不暴露公网**：默认保持 gateway 仅本机可访问，除非已配置认证与访问控制。

---

## 1. Proactive Agent 是什么（在 OpenClaw 里的“正确用法”）

你安装的 `proactive-agent` 更像一套 **workspace 模板/协议（OS）**：

- `SKILL.md`：说明书与方法论
- `assets/*.md`：需要复制到 **agent workspace 根目录** 的工作文件（ONBOARDING / SOUL / USER / MEMORY / HEARTBEAT / TOOLS 等）
- `scripts/*`：可选脚本

它不一定会被 `openclaw skills info` 当作“可执行 skill”识别；真正生效的关键是：

- `workspace` 根目录出现 `ONBOARDING.md` 等文件
- butler 在对话中读取这些文件并按流程更新它们

---

## 2. 安装/启用 Proactive Agent（workspace-butler）

### 2.1 目录结构

已安装位置（示例）：

- `~/.openclaw/workspace-butler/skills/proactive-agent/`
  - `SKILL.md`
  - `assets/ONBOARDING.md`
  - `assets/HEARTBEAT.md`
  - `assets/TOOLS.md`
  - ...

### 2.2 安装到 butler 的 workspace（推荐）

先装到 butler 的 workspace 是更稳的灰度方式（只影响 `agent:butler:main`），命令如下：

```bash
npx clawhub@latest --workdir ~/.openclaw/workspace-butler --dir skills install proactive-agent
```

如果提示需要登录：

```bash
npx clawhub@latest login
npx clawhub@latest whoami
```

#### 2.2.1 安全审计（可选但推荐）

如果安装时出现 “VirusTotal Code Insight flagged as suspicious” 提示，建议先审计再决定是否安装启用：

```bash
npx clawhub@latest inspect proactive-agent --files --tag latest
npx clawhub@latest inspect proactive-agent --file scripts/security-audit.sh --tag latest
```

#### 2.2.2 更新（只更新 butler workspace 下安装的 skills）

```bash
npx clawhub@latest --workdir ~/.openclaw/workspace-butler --dir skills update proactive-agent
# 或更新该 workspace 下所有 skills
npx clawhub@latest --workdir ~/.openclaw/workspace-butler --dir skills update --all
```

### 2.3 验证是否安装成功

最快方式是检查目录是否存在：

```bash
ls -la ~/.openclaw/workspace-butler/skills | head
ls -la ~/.openclaw/workspace-butler/skills/proactive-agent | head
```

说明：`openclaw skills info` / `openclaw skills list` 默认只扫描 **默认 agent(main)** 的 workspace（通常是 `~/.openclaw/workspace`），因此你可能会看到“not found”。这并不影响 `butler` 运行时从其 workspace 加载 `skills/`。

### 2.4 复制 assets 到 workspace 根目录

> 关键点：`cp assets/*.md ./` 这里的 `./` 指的是 **workspace 根目录**。

执行：

```bash
cp ~/.openclaw/workspace-butler/skills/proactive-agent/assets/*.md ~/.openclaw/workspace-butler/
mkdir -p ~/.openclaw/workspace-butler/memory
```

### 2.5 触发 onboarding

在飞书里对 `feishub/butler` 发送：

- `let's do onboarding`

#### 推荐的 onboarding 回答模板（英语教练模式）：

将以下内容根据你的实际情况修改后，一次性发给 butler：

```text
Step 1: Define YOUR identity (Butler)
1) Name: Butler
2) Style: Direct & efficient + Warm & patient (coach-style).
3) Emoji signature: 🎓
Boundaries: Nothing external without my approval. Ask forgiveness, not permission for safe internal work.
Coach Rules: Every reply must include [Corrections], [Better alternatives], [Mini practice] (2 questions). Default language is English.

Step 2: Define MY profile (the user)
- Call me: Surdring
- Timezone: GMT+8
- English goal: Workplace communication + speaking fluency.
- Current level: B1.
Preferred mode: Short daily practice (10-15 min), corrections + exactly 2 follow-up questions.
```

完成后通常会看到：

- `ONBOARDING.md` 的进度被更新
- `USER.md` / `SOUL.md` 等文件被填充

---

## 3. 常见坑（排错要点）

### 3.1 `openclaw skills info` 找不到 proactive-agent

原因通常是：

- `openclaw skills ...` 默认只扫描 **默认 agent(main)** 的 workspace
- 你装的是一个目录包，loader 可能只识别 skills 目录下的“skill 文件”

结论：不要用 `skills info` 作为“是否可用”的唯一判断；以 **onboarding 是否触发** 为准。

### 3.2 Bash 反引号导致文本被当命令执行

在命令行参数中出现 `` `message` `` 会触发命令替换，shell 会尝试执行 `message` 命令。

解决：

- 参数文本里不要用反引号
- 复杂 payload 用单引号 `'...'` 包起来

### 3.3 `gateway timeout after 30000ms` 但实际仍发出消息

CLI 等待 Gateway 返回结果可能超时，但 Gateway 端任务可能仍继续执行完成。

解决：

- 将 cron job `timeoutSeconds` 调大，例如 90s

---

## 4. Feishu 多账号（feishua / feishub）与投递策略

你遇到的问题本质是：

- Feishu p2p chat `oc_...` 里 **feishub 在群里**，可以发送
- `feishua` 不在该 chat 里，发送会报：`Bot/User can NOT be out of the chat.`

验证命令（可用于排错）：

```bash
openclaw message send \
  --channel feishu \
  --account feishub \
  --target oc_<YOUR_P2P_CHAT_ID> \
  --message "Test from feishub"
```

---

## 5. 配置 Cron：白天每 30 分钟 + 离线语料库 + message 工具保真

> 设计目标：
> - 09:00-22:30（Asia/Shanghai）每 30 分钟一次
> - **离线语料库**：通过 `exec` 调用 `corpus_selector.py` 轮换 5 个句子。
> - **格式保真**：放弃 `delivery.mode=announce`（会总结/改写），改为让 Agent 在任务中显式调用 `message` 工具。
> - **模型控制**：默认跟随 Agent 模型，也可在 Job 中指定。

### 5.1 模型优先级与配置

详情参考：`@[openclaw-notes/notes/OpenClaw-模型配置与优先级指南.md]`

- **修改 Agent 默认模型**：在 `~/.openclaw/openclaw.json` 的 `agents.list` 中修改 `butler` 的 `model.primary`。
- **覆盖 Cron 模型**：`openclaw cron edit <ID> --model "volcengine/ark-code-latest"`。
- **跟随默认**：`openclaw cron edit <ID> --model ""`。

### 5.2 核心：使用 message 工具防止格式漂移

由于 `announce` 模式会由上层网关对 LLM 输出进行摘要提取（可能导致丢失 `Source` 行或增加客套话），**生产环境建议将 cron 投递设为 `none`，并让 LLM 调用 `message` 工具**。

#### 5.2.1 更新 Cron Payload (最终稳定版 - 中文解释版)

```bash
openclaw cron edit 9e0bd11b-a08e-4bee-97d1-375d64b79095 \
  --no-deliver \
  --message 'You are Butler, an English coach. 

Core Objective: Fetch sentences and send them as a DM to surdring using the "message" tool.

Step 1: Call "exec" to get sentences
Command: python3 ~/.openclaw/workspace-butler/memory/corpus_selector.py --corpus ~/.openclaw/workspace-butler/memory/corpus.tsv --state ~/.openclaw/workspace-butler/memory/corpus.state.json --count 5 --out -

Step 2: Format the text STRICTLY (no markdown, no bolding, no bullets):
Header line: Hi surdring. Here are 5 sentences with explanations.

[Repeat 5 times with actual numbers 1) to 5)]:
1) "<sentence_text>"
Explain: <用中文简要解释原句的意思和用法，1-2句话。>
Variation: <CRITICAL: Rewrite the sentence in English by significantly changing the structure, vocabulary, or tone. DO NOT repeat the original sentence.>
VarExplain: <用中文解释这个 Variation 和原句相比改了什么（语气/词汇/句式），以及更适合什么场景，1-2句话。>

Step 3: Call "message" tool with target="oc_xxx", accountId="feishub" and the exact text.

Hard Rules:
- "Explain:" MUST be in Chinese.
- "Variation:" MUST be in English and on its own new line.
- "VarExplain:" MUST be in Chinese and on its own new line.
- "Variation:" MUST NOT be identical to the original sentence.
- NO conversational filler, NO intro/outro.'
```

### 5.3 验证与生效
1. 修改 `openclaw.json` 后需重启：`systemctl --user restart openclaw-gateway`。
2. 手动测试：`openclaw cron run <ID> --timeout 120000`。


---

## 6. 观察、排错、回滚

### 6.1 查看 run 历史

```bash
openclaw cron runs --id <JOB_ID>
```

### 6.2 临时停用（推荐）

```bash
openclaw cron disable <JOB_ID>
```

### 6.3 删除

```bash
openclaw cron rm <JOB_ID>
```

---

## 7. 你这次实际配置结果（记录）

- Job ID：`9e0bd11b-a08e-4bee-97d1-375d64b79095`
- Schedule：`*/30 9-22 * * *`，`Asia/Shanghai`
- Session：`isolated`
- Delivery：`none`（不使用 cron announce）
- 发送账号：通过工具调用强制 `accountId=feishub`
- 目标 chat：`oc_e722e244b303264aec6b620d27e63127`

> 如需迁移到其他 chat，只需要替换 payload 里的 `target`。
