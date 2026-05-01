# Claude Code Haha CLI 安装与配置变更记录

> 日期：2026-04-30
> 环境：Linux (zhengxueen)

---

## 1. 安装步骤

### 1.1 Bun 运行时
- 已有 Bun v1.3.11，无需额外安装

### 1.2 项目依赖
```bash
bun install
# 613 packages installed
```

### 1.3 环境变量
```bash
cp .env.example .env
```

### 1.4 全局 PATH
在 `~/.bashrc` 末尾添加：
```bash
# claude-haha CLI
export PATH="/home/zhengxueen/workspace/cc-haha/bin:$PATH"
```

验证：`which claude-haha` → `/home/zhengxueen/workspace/cc-haha/bin/claude-haha`

---

## 2. 配置文件变更

### 2.1 `~/.claude/cc-haha/providers.json`

**变更**：`activeId` 从 LiteLLM provider 切换到 WindsurfAPI provider

```diff
- "activeId": "3d9dc11d-05d6-4be6-8d12-669b62ca2f37"
+ "activeId": "ce9c6bd5-484f-49a0-8dd2-6feea87b21f1"
```

三个 provider 保留不变：

| Provider | ID | Base URL | 模型 | API 格式 |
|----------|----|----------|------|---------|
| Custom (Qwen 直连) | `2a2db923...` | `http://127.0.0.1:8080` | Qwen3.6-35B-A3B | openai_chat |
| Custom (LiteLLM) | `3d9dc11d...` | `http://127.0.0.1:4000` | qwen | anthropic |
| windsurfapi | `ce9c6bd5...` | `http://127.0.0.1:3003` | kimi-k2-6 / kimi-k2.5 / swe-1.5 / gpt-5.2-low | anthropic |

### 2.2 `~/.claude/cc-haha/settings.json`

**变更**：从 LiteLLM (ANTHROPIC_AUTH_TOKEN) 切换到 WindsurfAPI (ANTHROPIC_API_KEY)

```diff
  {
    "skipWebFetchPreflight": true,
    "env": {
-     "ANTHROPIC_BASE_URL": "http://127.0.0.1:4000",
-     "ANTHROPIC_MODEL": "qwen",
-     "ANTHROPIC_DEFAULT_HAIKU_MODEL": "qwen",
-     "ANTHROPIC_DEFAULT_SONNET_MODEL": "qwen",
-     "ANTHROPIC_DEFAULT_OPUS_MODEL": "qwen",
-     "ANTHROPIC_AUTH_TOKEN": "sk-anything",
-     "activeId": "3d9dc11d-05d6-4be6-8d12-669b62ca2f37"
+     "ANTHROPIC_BASE_URL": "http://127.0.0.1:3003",
+     "ANTHROPIC_MODEL": "kimi-k2-6",
+     "ANTHROPIC_DEFAULT_HAIKU_MODEL": "swe-1.5",
+     "ANTHROPIC_DEFAULT_SONNET_MODEL": "kimi-k2.5",
+     "ANTHROPIC_DEFAULT_OPUS_MODEL": "gpt-5.2-low",
+     "ANTHROPIC_API_KEY": "sk-123",
+     "activeId": "ce9c6bd5-484f-49a0-8dd2-6feea87b21f1"
    },
-   "model": "qwen"
+   "model": "kimi-k2-6"
  }
```

### 2.3 `.env`

**变更**：注释掉 LiteLLM 的 `ANTHROPIC_AUTH_TOKEN`，新增 WindsurfAPI 配置段

```diff
  # OpenAI（通过 LiteLLM 代理）
  # 先启动: litellm --config litellm_config.yaml --port 4000
  # ============================================================
- ANTHROPIC_AUTH_TOKEN=sk-anything
- ANTHROPIC_BASE_URL=http://localhost:4000
- ANTHROPIC_MODEL=qwen
- ANTHROPIC_DEFAULT_SONNET_MODEL=qwen
- ANTHROPIC_DEFAULT_HAIKU_MODEL=qwen
- ANTHROPIC_DEFAULT_OPUS_MODEL=qwen
- API_TIMEOUT_MS=3000000
+ # ANTHROPIC_AUTH_TOKEN=sk-anything
+ # ANTHROPIC_BASE_URL=http://localhost:4000
+ # ANTHROPIC_MODEL=qwen
+ # ANTHROPIC_DEFAULT_SONNET_MODEL=qwen
+ # ANTHROPIC_DEFAULT_HAIKU_MODEL=qwen
+ # ANTHROPIC_DEFAULT_OPUS_MODEL=qwen
+ # API_TIMEOUT_MS=3000000
+
+ # ============================================================
+ # WindsurfAPI（Anthropic 兼容接口）
+ # 先启动: cd WindsurfAPI && node src/index.js
+ # ============================================================
+ ANTHROPIC_API_KEY=sk-123
+ ANTHROPIC_BASE_URL=http://127.0.0.1:3003
+ ANTHROPIC_MODEL=kimi-k2-6
+ ANTHROPIC_DEFAULT_SONNET_MODEL=kimi-k2.5
+ ANTHROPIC_DEFAULT_HAIKU_MODEL=swe-1.5
+ ANTHROPIC_DEFAULT_OPUS_MODEL=gpt-5.2-low
+ API_TIMEOUT_MS=3000000
```

---

## 3. Auth 冲突问题

### 现象
启动时出现警告：
```
⚠Auth conflict: Both a token (ANTHROPIC_AUTH_TOKEN) and an API key (ANTHROPIC_API_KEY) are set.
```

### 原因
`src/utils/statusNoticeDefinitions.tsx` 中的 `bothAuthMethodsNotice` 检测到 `ANTHROPIC_AUTH_TOKEN` 和 `ANTHROPIC_API_KEY` 同时存在（第 98-139 行）。

### 解决方案
- WindsurfAPI 使用 `ANTHROPIC_API_KEY`（见 WindsurfAPI README 第 213-215 行）
- 注释掉 `.env` 中的 `ANTHROPIC_AUTH_TOKEN`
- `settings.json` 中用 `ANTHROPIC_API_KEY` 替代 `ANTHROPIC_AUTH_TOKEN`
- 确保两者不同时存在

### 注意事项
- **桌面端会覆盖 `settings.json`**：桌面端 provider 系统以 `providers.json` 为源头，切换 provider 时会重写 `settings.json` 的 env 字段
- 如需在桌面端也使用 WindsurfAPI，需在桌面端 UI 中切换到 windsurfapi provider

---

## 4. 启动方式

### CLI 交互模式
```bash
./bin/claude-haha
```

### CLI 无头模式
```bash
./bin/claude-haha -p "your prompt here"
```

### 前置条件
确保 WindsurfAPI 服务已启动：
```bash
cd WindsurfAPI && node src/index.js
# 默认监听 http://127.0.0.1:3003
```
