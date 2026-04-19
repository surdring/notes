# OpenClaw Butler：离线开放语料库轮换 + Feishub Cron 主动推送（Python Selector）

## 目标

- Butler 定时（cron）主动推送英语练习。
- 例句来自**离线开放许可**语料库（避免模型自造导致重复）。
- 每次推送通过本地 `state.json` 轮换下一条语料，尽量不重复。
- 每条消息附带 `Source / License / Sentence ID` 便于合规追溯。

---

## 0. 前提

- 你已经有：
  - `agent: butler`（workspace：`~/.openclaw/workspace-butler`）
  - Feishu 账号 `feishub`
  - 已知 P2P target：`oc_e722e244b303264aec6b620d27e63127`

---

## 1. 文件位置（Butler Workspace）

所有离线语料与轮换状态放在：

- `~/.openclaw/workspace-butler/memory/`
  - `corpus.tsv`：离线语料库（TSV）
  - `corpus.state.json`：轮换状态（index）
  - `corpus_selector.py`：按 index 轮换取 N 条语料（默认 5 条），并更新 state
  - `build_corpus_tatoeba.py`：从 Tatoeba 导出构建 `corpus.tsv`

---

## 2. Exec 工具配置（让 cron 可无人值守调用 python3）

在 `~/.openclaw/openclaw.json` 增加：

```json
"tools": {
  "exec": {
    "security": "allowlist",
    "ask": "off",
    "safeBins": ["python3"]
  }
}
```

然后重启 gateway：

```bash
systemctl --user restart openclaw-gateway
```

> 安全提醒：`ask:"off"` 会让 cron 的 `exec` 不弹审批。务必让 cron message 固定、不可被外部输入注入。

---

## 3. 语料格式（corpus.tsv）

`corpus.tsv` 每行 3 列（Tab 分隔）：

1) `sentence_id`
2) `sentence_text`
3) `source_and_license`

示例：

```tsv
1234567	This is a sample sentence.	Source: Tatoeba (https://tatoeba.org/) | License: See dataset page | id=1234567
```

---

## 4. 从 Tatoeba 构建离线语料库（推荐）

### 4.1 获取 Tatoeba sentences 导出文件

你需要先下载/准备 Tatoeba 的 sentences 导出文件（常见格式：`sentences.csv` 或 `sentences.tsv`），其字段通常为：

- `id`, `lang`, `text`

> 下载方式按你当下环境选择（浏览器手动下载也可以）。建议保存到：`~/.openclaw/workspace-butler/memory/raw/`

### 4.2 使用构建脚本生成 corpus.tsv

脚本位置：

- `~/.openclaw/workspace-butler/memory/build_corpus_tatoeba.py`

生成命令示例（只保留英文 `eng`）：

```bash
python3 ~/.openclaw/workspace-butler/memory/build_corpus_tatoeba.py \
  --sentences ~/.openclaw/workspace-butler/memory/raw/sentences.csv \
  --lang eng \
  --out ~/.openclaw/workspace-butler/memory/corpus.tsv \
  --limit 0 \
  --source "Tatoeba" \
  --sourceUrl "https://tatoeba.org/" \
  --license "See dataset page"
```

`--limit 0` 表示不限制条数（越多越好）。

---

## 5. Selector 脚本：按 index 轮换取句子

脚本位置：

- `~/.openclaw/workspace-butler/memory/corpus_selector.py`

状态文件：

- `~/.openclaw/workspace-butler/memory/corpus.state.json`

### 5.1 手动测试 selector

```bash
python3 ~/.openclaw/workspace-butler/memory/corpus_selector.py \
  --corpus ~/.openclaw/workspace-butler/memory/corpus.tsv \
  --state ~/.openclaw/workspace-butler/memory/corpus.state.json \
  --count 5 \
  --out -
```

预期：stdout 输出 JSON，包含 `items` 数组（每个 item 有 `sentence_text` / `source_and_license`），并把 state 的 `index` 前进 `count`。

---

## 6. Cron：先 exec selector，再 message send

Job ID（示例）：

- `9e0bd11b-a08e-4bee-97d1-375d64b79095`

核心原则：

- cron 仍然 `--session isolated`（避免对话污染）
- 通过 `exec` 运行 selector 拿到离线句子 JSON
- 再调用工具 `message` 发送固定格式的文本（本实现为一次推送 5 条句子）
- `message` 工具调用必须使用 `target`（不要用 `to`/`channelId`）

### 6.1 更新 cron message（示例模板）

```bash
openclaw cron edit 9e0bd11b-a08e-4bee-97d1-375d64b79095 \
  --message 'You are Butler. You must send exactly ONE Feishu DM by calling the OpenClaw tool named "message" ONCE.

Step 1 (mandatory): Call tool "exec" and run EXACTLY this command:
python3 ~/.openclaw/workspace-butler/memory/corpus_selector.py --corpus ~/.openclaw/workspace-butler/memory/corpus.tsv --state ~/.openclaw/workspace-butler/memory/corpus.state.json --count 5 --out -
Parse stdout as JSON with key: items (array). Each item has: sentence_text, source_and_license.

Step 2 (mandatory): Build the outgoing text EXACTLY in this format (plain text, no tables):
Line1: Hi surdring. Here are 5 English sentences for practice.
Line2: 1) <items[0].sentence_text>
Line3: 2) <items[1].sentence_text>
Line4: 3) <items[2].sentence_text>
Line5: 4) <items[3].sentence_text>
Line6: 5) <items[4].sentence_text>
Line7: Source: <items[0].source_and_license>

Step 3 (mandatory): Call tool "message" with EXACTLY this JSON object (no extra keys):
{"action":"send","channel":"feishu","accountId":"feishub","target":"oc_e722e244b303264aec6b620d27e63127","message":"<TEXT_FROM_STEP_2>"}

Hard rules:
- The message tool MUST include "target".
- DO NOT use "to".
- DO NOT use "channelId".
- English only. No emoji. No slang.'
```

### 6.2 手动试跑

```bash
openclaw cron run 9e0bd11b-a08e-4bee-97d1-375d64b79095
```

---

## 7. 回滚

### 7.1 回滚 exec 配置

从 `~/.openclaw/openclaw.json` 删除或修改：

- `tools.exec.ask` 改回 `on-miss` 或 `always`
- 或移除 `safeBins: ["python3"]`

然后重启：

```bash
systemctl --user restart openclaw-gateway
```

### 7.2 回滚 cron

- 禁用：

```bash
openclaw cron disable 9e0bd11b-a08e-4bee-97d1-375d64b79095
```

- 删除：

```bash
openclaw cron rm 9e0bd11b-a08e-4bee-97d1-375d64b79095
```

---

## 8. 排错

- `corpus.tsv` 为空：selector 会报 `Corpus is empty`。
- `exec` 被阻止：检查 `tools.exec` 配置，确认已重启 gateway。
- 例句出现 Tab/换行导致解析异常：构建脚本会替换 tab 并折叠换行；如果你自建语料，注意清洗。
