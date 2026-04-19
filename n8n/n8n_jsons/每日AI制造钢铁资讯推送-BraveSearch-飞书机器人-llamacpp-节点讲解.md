# 每日 AI×制造/钢铁资讯推送（Brave Search + llama.cpp + 飞书机器人）节点讲解

对应工作流文件：`每日AI制造钢铁资讯推送-BraveSearch-飞书机器人-llamacpp.json`

## 0. 总览

### 0.1 目标

每天 08:30 自动检索过去 1 天内的 AI×制造（尤其钢铁/冶金）相关资讯，抓取原文全文（含兜底），调用本地 `llama.cpp`（OpenAI 兼容接口）进行翻译与深度解读，最终通过飞书自定义机器人 Webhook 推送。

### 0.2 外部依赖

- Brave Search API（Web Search）
- 本地 llama.cpp（OpenAI 兼容 `/v1/chat/completions`）
- 飞书自定义机器人 Webhook
- `r.jina.ai`（抓取失败兜底的文本抽取）

### 0.3 使用到的环境变量（必须通过 systemd/Docker 等方式注入给 n8n 进程）

- `BRAVE_SEARCH_API_KEY`
- `FEISHU_BOT_WEBHOOK_URL`
- `LLAMA_CPP_BASE_URL`（建议形如 `http://127.0.0.1:8080`，不要带 `/v1`，因为工作流会自行拼接 `/v1/chat/completions`）
- `LLAMA_CPP_MODEL`
- `LLAMA_CPP_API_KEY`（可选；若本地模型启用了鉴权则需要）

### 0.4 数据流（主干）

1. `Cron 08:30` 触发
2. `Init Run Config` 初始化本次运行参数（查询、条数、LLM 配置、Webhook）
3. `Reset Accumulator` 清空全局累加器（用于收集多条 LLM 输出）
4. `Brave Search (freshness=day)` 拉取候选列表
5. `Pick Candidates` 去重、标准化、截断候选
6. `Split In Batches` 逐条处理候选（批大小 = 1）
7. 抓全文：`Fetch Article (direct)` → 失败则 `Fetch Article (jina.ai)`
8. `Select Article Text` 选择正文文本字段并截断
9. `LLM: Translate + Analyze` 生成结构化解读
10. `Accumulate Result` 写入全局累加器
11. 循环回 `Split In Batches` 处理下一条，直到候选处理完
12. `Format Final Message` 把前 5 条拼成一条长消息
13. `Send to Feishu Bot` 推送到飞书群

---

## 1. 节点逐个讲解

### 1.1 `Cron 08:30`（`n8n-nodes-base.cron`）

- **用途**
  - 每天 08:30 自动触发一次工作流。
- **关键参数**
  - `triggerTimes.item[0].mode = everyDay`
  - `hour = 8`, `minute = 30`
- **输入 / 输出**
  - 输入：无
  - 输出：一个触发 item（通常为空 JSON），用于启动后续链路。
- **常见问题**
  - 时区不符：检查 n8n 实例时区设置（容器/系统时区）。

### 1.2 `Init Run Config`（`n8n-nodes-base.set`）

- **用途**
  - 统一生成“本次运行”的配置对象，避免在后续节点重复硬编码。
- **关键字段**
  - `braveEndpoint`：Brave 搜索 endpoint
  - `query`：检索式（偏召回，后续靠 LLM 解读阶段再判断价值）
  - `candidateCount`：候选数量（默认 30）
  - `finalCount`：最终推送条数（默认 5）
  - `freshness`：Brave freshness（默认 `day`）
  - `llamaBaseUrl`：从 `$env.LLAMA_CPP_BASE_URL` 读取（带默认值）
  - `llamaModel`：从 `$env.LLAMA_CPP_MODEL` 读取（带默认值）
  - `feishuWebhookUrl`：从 `$env.FEISHU_BOT_WEBHOOK_URL` 读取
- **输入 / 输出**
  - 输入：Cron 输出
  - 输出：包含上述字段的一条 JSON item
- **注意事项**
  - `LLAMA_CPP_BASE_URL` 不建议带 `/v1`，否则后续 URL 拼接会出现 `/v1/v1/...`。

### 1.3 `Reset Accumulator`（`n8n-nodes-base.code`）

- **用途**
  - 清空全局静态数据中的 `items` 数组，作为“本次运行”的结果收集容器。
- **关键实现**
  - 使用 `$getWorkflowStaticData('global')` 获取工作流全局静态存储。
  - `data.items = []`
- **输入 / 输出**
  - 输入：来自 `Init Run Config`
  - 输出：原样传递 `items`（不改变主链数据），但会影响全局静态数据。
- **常见问题**
  - 若报 `this.getWorkflowStaticData is not a function`：应使用 `$getWorkflowStaticData`（此工作流已修复）。

### 1.4 `Brave Search (freshness=day)`（`n8n-nodes-base.httpRequest`）

- **用途**
  - 调用 Brave Search API 获取过去一天内的候选资讯列表。
- **关键参数**
  - `url`: `{{$json.braveEndpoint}}`
  - Headers:
    - `Accept: application/json`
    - `X-Subscription-Token: {{$env.BRAVE_SEARCH_API_KEY}}`
  - Query:
    - `q`: `{{$json.query}}`
    - `count`: `{{$json.candidateCount}}`
    - `freshness`: `{{$json.freshness}}`
- **输入 / 输出**
  - 输入：运行配置（包含 query/count 等）
  - 输出：Brave 返回的 JSON（常见路径：`web.results`）
- **失败模式 / 排查**
  - 401/403：`BRAVE_SEARCH_API_KEY` 未注入或无权限。
  - 429：触发限流，建议减少 `count` 或增加等待/重试策略。

### 1.5 `Pick Candidates`（`n8n-nodes-base.code`）

- **用途**
  - 从 Brave 搜索结果中挑选候选条目，做 URL 归一化、去重，并把字段规范成后续节点统一的结构。
- **关键逻辑**
  - 从 `web.results` 或 `results` 取数组
  - `normalizeUrl()`：删除 hash、UTM、gclid、fbclid 等参数
  - 去重：按归一化后的 URL
  - 输出字段：`title/url/description/source/page_age` 以及 LLM/飞书配置透传
  - 截断候选：保留 `max(finalCount*3, 15)` 条用于后续抓全文
- **输入 / 输出**
  - 输入：Brave 返回 JSON
  - 输出：多个 items（每个 item 对应一个候选文章）
- **注意事项**
  - 此处是“粗筛”，不要期望完全精确；精筛交由 LLM 解读阶段和最终人工观察。

### 1.6 `Split In Batches`（`n8n-nodes-base.splitInBatches`）

- **用途**
  - 把候选文章逐条（batchSize=1）送入“抓全文 + LLM 解读”链路，避免并发导致限流/资源爆炸。
- **关键参数**
  - `batchSize = 1`
- **输入 / 输出**
  - 输入：多条候选 items
  - 输出：每次只输出 1 条给下一节点；当遍历完成后，从第二个输出分支继续流向 `Format Final Message`。
- **注意事项**
  - 这是一个“循环控制节点”：后面 `Accumulate Result` 会连回它，推进下一条。

### 1.7 `Fetch Article (direct)`（`n8n-nodes-base.httpRequest`）

- **用途**
  - 直接 GET 抓取原文网页。
- **关键参数**
  - `url = {{$json.url}}`
  - `ignoreResponseCode = true`（不因 4xx/5xx 直接让工作流失败）
  - `responseFormat = text`, `fullResponse = true`
  - `timeout = 30000`
- **输入 / 输出**
  - 输入：候选文章 item（包含 url）
  - 输出：HTTP 响应（含 `statusCode` 与 `body`）
- **失败模式**
  - 反爬/Cloudflare/需要 JS 渲染时可能返回 403/空页面。

### 1.8 `Need Fallback?`（`n8n-nodes-base.if`）

- **用途**
  - 判断直抓是否成功，不成功则走 `r.jina.ai` 兜底。
- **条件**
  - `statusCode != 200` 认为需要兜底
- **输出分支**
  - True 分支：到 `Fetch Article (jina.ai)`
  - False 分支：直接到 `Select Article Text`

### 1.9 `Fetch Article (jina.ai)`（`n8n-nodes-base.httpRequest`）

- **用途**
  - 使用 `r.jina.ai` 代理获取“更干净”的网页正文文本（对动态网页/反爬场景更友好）。
- **关键参数**
  - URL 拼接：`https://r.jina.ai/http://` + 原 URL 去掉协议
  - `ignoreResponseCode = true`
  - `responseFormat = text`, `fullResponse = true`
- **输入 / 输出**
  - 输入：候选文章 item（含 url）
  - 输出：文本响应（通常更接近正文）
- **注意事项**
  - 依赖第三方服务可用性；若你希望完全内网闭环，可替换成自建抓取/抽取服务。

### 1.10 `Select Article Text`（`n8n-nodes-base.code`）

- **用途**
  - 从上一步 HTTP 节点结果中取出正文文本字段，统一塞到 `articleText`，并做长度截断。
- **关键逻辑**
  - 优先 `base.body`（fullResponse 的 body）
  - 其次 `base.data`
  - `articleText = text.slice(0, 60000)`（避免 LLM 输入过大）
- **输入 / 输出**
  - 输入：HTTP fullResponse item
  - 输出：标准化后的文章结构：`title/url/description/source/page_age/articleText` + LLM/飞书配置

### 1.11 `LLM: Translate + Analyze`（`n8n-nodes-base.httpRequest`）

- **用途**
  - 调用本地 `llama.cpp` 的 OpenAI 兼容接口生成“翻译 + 深度解读”。
- **关键参数**
  - URL：`{{$json.llamaBaseUrl}}` + `/v1/chat/completions`
  - Header：
    - `Authorization: Bearer {{$env.LLAMA_CPP_API_KEY}}`（若未设置则为空字符串）
  - Body：
    - `model = {{$json.llamaModel}}`
    - `temperature = 0.2`
    - `messages`：
      - system：约束风格为工业情报分析
      - user：包含标题/链接/摘要/全文，并要求固定结构输出
- **输入 / 输出**
  - 输入：标准化文章 item（含 `articleText`）
  - 输出：OpenAI 风格响应 JSON（用于下游从 `choices[0].message.content` 取文本）
- **失败模式 / 排查**
  - 401：`LLAMA_CPP_API_KEY` 不正确或服务未开启鉴权；确认是否需要 bearer。
  - 404：`LLAMA_CPP_BASE_URL` 配错（例如带了 `/v1` 导致 `/v1/v1/...`）。
  - 超时：增大 timeout 或缩短 `articleText` 截断长度。

### 1.12 `Accumulate Result`（`n8n-nodes-base.code`）

- **用途**
  - 把每篇文章的 LLM 输出内容写入全局静态数据 `data.items`，供最后汇总。
- **关键逻辑**
  - `content = choices[0].message.content`
  - `data.items.push({ content })`
  - 上限保护：最多 50 条，防止异常循环导致无限增长
  - 返回后连回 `Split In Batches`，触发下一条候选
- **输入 / 输出**
  - 输入：LLM 响应 JSON
  - 输出：原样传递（但主要作用是 side-effect：写入 static data）

### 1.13 `Format Final Message`（`n8n-nodes-base.code`）

- **用途**
  - 从 `data.items` 取前 5 条，拼成一条要发到飞书的长文本。
- **关键逻辑**
  - `itemsArr = (data.items || []).slice(0, 5)`
  - 空结果兜底：输出“今日未检索到合格资讯”
  - header + body（每条前加 `---` 与序号）
- **输入 / 输出**
  - 输入：来自 `Split In Batches` 的“遍历结束信号”分支
  - 输出：`{ text: '...' }`

### 1.14 `Send to Feishu Bot`（`n8n-nodes-base.httpRequest`）

- **用途**
  - 向飞书自定义机器人 Webhook 发送文本消息。
- **关键参数**
  - URL：`{{$json.feishuWebhookUrl || $env.FEISHU_BOT_WEBHOOK_URL}}`
  - Body：
    - `msg_type = text`
    - `content.text = {{$json.text}}`
- **输入 / 输出**
  - 输入：`Format Final Message` 输出的 `text`
  - 输出：飞书 webhook 的响应（用于确认发送成功/失败）
- **失败模式 / 排查**
  - 400/403：Webhook URL 无效、机器人未在群中、或安全策略限制。
  - 内容过长：飞书对文本长度有限制；若超限需要改为分条发送或卡片消息。

---

## 2. 关键约束与改造点（可选）

- **严格 24 小时**
  - Brave 的 `freshness=day` 是近似，若要严格到时间戳，需要额外从搜索结果/正文解析发布时间并过滤。

- **来源白名单/黑名单**
  - 可在 `Pick Candidates` 后增加一个 `Code/IF` 节点按域名过滤，提升可信度。

- **飞书消息长度**
  - 若 LLM 输出较长，建议改成“每条资讯单独发送一条消息”，或用飞书卡片（interactive）。

- **避免发送空 Authorization**
  - 当前实现会在 key 为空时发送空字符串 header 值。若你希望完全不带该 header，可进一步在节点层面加条件分支或把 `headerParameters` 改为动态拼装。
