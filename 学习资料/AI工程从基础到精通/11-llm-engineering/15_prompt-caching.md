# 提示词缓存与上下文缓存

> 你的系统提示词有 4,000 个 token。你的 RAG 上下文有 20,000 个 token。每次请求你都发送这两者。你也每次都为它们付费。提示词缓存（Prompt Caching）让提供商在其一侧保持此前缀处于热状态，并在重用时仅按正常费率的 10% 向你收费。正确使用时，它可将推理成本降低 50-90%，首 token 延迟降低 40-85%。

**类型：** 构建
**语言：** Python
**前置条件：** Phase 11 · 01（提示词工程）、Phase 11 · 05（上下文工程）、Phase 11 · 11（缓存与成本）
**时间：** 约 60 分钟

## 问题所在

一个编程 Agent 在对话的每一轮都向 Claude 发送相同的 15,000 token 系统提示词。以 $3/百万输入 token 计算，20 轮对话仅输入成本就达 $0.90——这还是在用户实际消息之前。乘以每天 10,000 次对话，账单达到 $9,000/天，而发送的文本从未改变。

你无法在不损害质量的情况下缩减提示词。你无法避免发送它——模型在每一轮都需要它。唯一的办法是停止为提供商已经见过的前缀支付全价。

这个办法就是提示词缓存。Anthropic 于 2024 年 8 月推出（2025 年增加了 1 小时延长 TTL 变体），OpenAI 在那年晚些时候自动实现，Google 随 Gemini 1.5 一起发布了显式上下文缓存，截至 2026 年三巨头都在其前沿模型上将其作为一级功能提供。

## 核心概念

![提示词缓存：写入一次，廉价读取](../assets/prompt-caching.svg)

**机制。** 当请求的前缀与最近某个请求匹配时，提供商直接从之前运行的 KV 缓存（KV-cache）中提供计算结果，而不是重新编码这些 token。第一次写入支付小额溢价，之后每次读取享受大额折扣。

**2026 年三种提供商风格。**

| 提供商 | API 风格 | 命中折扣 | 写入溢价 | 默认 TTL | 最小可缓存量 |
|---------|-----------|--------------|---------------|-------------|---------------|
| Anthropic | 在内容块上显式 `cache_control` 标记 | 输入 90% 折扣 | 25% 附加费 | 5 分钟（可延长至 1 小时） | 1,024 token（Sonnet/Opus），2,048（Haiku） |
| OpenAI | 自动前缀检测 | 输入 50% 折扣 | 无 | 最多 1 小时（尽力而为） | 1,024 token |
| Google (Gemini) | 显式 `CachedContent` API | 按存储计费；读取按正常的约 25% | 存储费按 token·小时计 | 用户设置（默认 1 小时） | 4,096 token（Flash），32,768（Pro） |

**不变量。** 三者都只缓存前缀。如果请求之间有任何 token 不同，则第一个不同 token 之后的所有内容都是未命中。将*稳定*部分放在顶部，*可变*部分放在底部。

### 缓存友好的布局

```
[系统提示词]              <-- 缓存这部分
[工具定义]                <-- 缓存这部分
[少样本示例]              <-- 缓存这部分
[检索到的文档]            <-- 如果重用则缓存，否则不缓存
[对话历史]                <-- 缓存到上一轮
[当前用户消息]            <-- 绝不缓存（每次不同）
```

违反顺序——将用户消息放在系统提示词之上、在少样本示例之间交错动态检索——缓存就永远不会命中。

### 盈亏平衡计算

Anthropic 的 25% 写入溢价意味着一个缓存块至少需要读取两次才能净省钱。1 次写入 + 1 次读取平均每次请求成本为 0.675x（节省 32%）；1 次写入 + 10 次读取平均为 0.205x（节省 80%）。经验法则：缓存任何你预期在 TTL 内至少重用 3 次的内容。

## 动手构建

### 步骤 1：使用显式标记的 Anthropic 提示词缓存

```python
import anthropic

client = anthropic.Anthropic()

SYSTEM = [
    {
        "type": "text",
        "text": "You are a senior Python reviewer. Follow the rubric exactly.\n\n" + RUBRIC_15K_TOKENS,
        "cache_control": {"type": "ephemeral"},
    }
]

def review(code: str):
    return client.messages.create(
        model="claude-opus-4-7",
        max_tokens=1024,
        system=SYSTEM,
        messages=[{"role": "user", "content": code}],
    )
```

`cache_control` 标记告诉 Anthropic 将此块存储 5 分钟。在该窗口内重用会命中；过期后重用则再次写入。

**响应用量字段：**

```python
response = review(code_a)
response.usage
# InputTokensUsage(
#     input_tokens=120,
#     cache_creation_input_tokens=15023,   # 按 1.25x 付费
#     cache_read_input_tokens=0,
#     output_tokens=340,
# )

response_b = review(code_b)
response_b.usage
# cache_creation_input_tokens=0
# cache_read_input_tokens=15023           # 按 0.1x 付费
```

在 CI 中检查两个字段——如果跨请求 `cache_read_input_tokens` 始终为零，说明你的缓存键正在漂移。

### 步骤 2：一小时延长 TTL

对于长时间运行的批处理任务，5 分钟默认值在任务之间会过期。设置 `ttl`：

```python
{"type": "text", "text": RUBRIC, "cache_control": {"type": "ephemeral", "ttl": "1h"}}
```

1 小时 TTL 的写入溢价是 2 倍（超出基线的 50% 而非 25%），但对于任何重用前缀超过 5 次的批处理很快就能回本。

### 步骤 3：OpenAI 自动缓存

OpenAI 不需要你做任何配置。任何超过 1,024 token 且与最近请求匹配的前缀自动获得 50% 折扣。

```python
from openai import OpenAI
client = OpenAI()

resp = client.chat.completions.create(
    model="gpt-5",
    messages=[
        {"role": "system", "content": SYSTEM_PROMPT},   # 长且稳定
        {"role": "user", "content": user_msg},
    ],
)
resp.usage.prompt_tokens_details.cached_tokens  # 获得折扣的部分
```

相同的缓存友好布局规则适用。有两件事会破坏 OpenAI 的缓存而不会破坏 Anthropic 的：更改 `user` 字段（用作缓存键的组成部分）和重新排序工具。

### 步骤 4：Gemini 显式上下文缓存

Gemini 将缓存视为你可以创建并命名的第一类对象：

```python
from google import genai
from google.genai import types

client = genai.Client()

cache = client.caches.create(
    model="gemini-3-pro",
    config=types.CreateCachedContentConfig(
        display_name="rubric-v3",
        system_instruction=RUBRIC,
        contents=[FEW_SHOT_EXAMPLES],
        ttl="3600s",
    ),
)

resp = client.models.generate_content(
    model="gemini-3-pro",
    contents=["Review this code:\n" + code],
    config=types.GenerateContentConfig(cached_content=cache.name),
)
```

Gemini 在缓存存续期间按 token·小时收取存储费，读取按正常输入费率的约 25% 收费。当你在数天内跨多个会话重用相同的巨型提示词时，这是正确的选择。

### 步骤 5：在生产环境中测量命中率

参见 `code/main.py` 了解一个模拟的三提供商记账器，它追踪写入/读取/未命中计数并计算每 1000 个请求的混合成本。基于目标命中率控制部署——大多数生产级 Anthropic 设置在预热后应看到 >80% 的读取比例。

## 2026 年仍在出现的陷阱

- **顶部有动态时间戳。** 系统提示词顶部的 `"Current time: 2026-04-22 15:30:02"`。每个请求都未命中。将时间戳移到缓存断点之下。
- **工具重新排序。** 以稳定顺序序列化工具——部署间的字典重新排列会破坏每一次命中。
- **自由文本近似重复。** "You are helpful." vs "You are a helpful assistant."——一个字节的差异 = 完全未命中。
- **块太小。** Anthropic 强制最低 1,024 token（Haiku 为 2,048）。较小的块不会静默缓存。
- **不加区分的成本仪表盘。** 将「输入 token」拆分为已缓存和未缓存。否则流量下降看起来像是缓存胜利。

## 使用指南

2026 年的缓存技术栈：

| 场景 | 选择 |
|-----------|------|
| 具有稳定 10k+ 系统提示词、多轮对话的 Agent | Anthropic `cache_control` 配合 5 分钟 TTL |
| 批处理任务重用前缀超过 30 分钟 | Anthropic 配合 `ttl: "1h"` |
| GPT-5 上的无服务器端点，无自定义基础设施 | OpenAI 自动（只需让你的前缀稳定且长） |
| 跨多天重用巨型代码/文档语料库 | Gemini 显式 `CachedContent` |
| 跨提供商回退 | 在各提供商之间保持可缓存前缀布局一致，确保任何命中都能生效 |

配合用户消息层的语义缓存（Phase 11 · 11）：提示词缓存处理*token 完全相同*的重用，语义缓存处理*含义相同*的重用。

## 交付物

保存 `outputs/skill-prompt-caching-planner.md`：

```markdown
---
name: prompt-caching-planner
description: Design a cache-friendly prompt layout and pick the right provider caching mode.
version: 1.0.0
phase: 11
lesson: 15
tags: [llm-engineering, caching, cost]
---

Given a prompt (system + tools + few-shot + retrieval + history + user) and a usage profile (requests per hour, TTL needed, provider), output:

1. Layout. Reordered sections with a single cache breakpoint marked; explain which sections are stable, which are volatile.
2. Provider mode. Anthropic cache_control, OpenAI automatic, or Gemini CachedContent. Justify from TTL and reuse pattern.
3. Break-even. Expected reads per write within TTL; net cost vs no-cache with math.
4. Verification plan. CI assertion that cache_read_input_tokens > 0 on the second identical request; dashboard split by cached vs uncached tokens.
5. Failure modes. List the three most likely reasons the cache will miss in this setup (dynamic timestamp, tool reorder, near-duplicate text) and how you will prevent each.

Refuse to ship a cache plan that places a dynamic field above the breakpoint. Refuse to enable 1h TTL without a reuse count that makes the 2x write premium pay back.
```

## 练习

1. **简单。** 对一个 10 轮对话、带有 5,000 token 系统提示词的 Claude 运行。分别在不使用 `cache_control` 和使用的情况下运行。报告每种情况的输入 token 账单。
2. **中等。** 编写一个测试框架：给定一个提示词模板和一个请求日志，计算每种提供商（Anthropic 5 分钟、Anthropic 1 小时、OpenAI 自动、Gemini 显式）的预期命中率和节省的美元金额。
3. **困难。** 构建一个布局优化器：给定一个提示词和一个标记了 `stable=True/False` 的字段列表，在不丢失信息的情况下将提示词重写为在最大缓存友好位置放置单个缓存断点。在真实的 Anthropic 端点上验证。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|-----------------------|
| 提示词缓存（Prompt Caching） | 「让长提示词变便宜」 | 为匹配前缀重用提供商端的 KV 缓存；重复输入 token 享受 50-90% 折扣。 |
| `cache_control` | 「Anthropic 的标记」 | 内容块属性，声明「到此为止的所有内容都可缓存」；`{"type": "ephemeral"}`。 |
| 缓存写入 | 「支付溢价」 | 填充缓存的首次请求；Anthropic 按约 1.25x 输入费率计费，OpenAI 免费。 |
| 缓存读取 | 「享受折扣」 | 匹配前缀的后续请求；按 10%（Anthropic）、50%（OpenAI）、约 25%（Gemini）计费。 |
| TTL | 「缓存存活多久」 | 缓存保持热状态的秒数；Anthropic 默认 5 分钟（可延长至 1 小时），OpenAI 尽力而为最多 1 小时，Gemini 由用户设置。 |
| 延长 TTL | 「1 小时 Anthropic 缓存」 | `{"type": "ephemeral", "ttl": "1h"}`；2 倍写入溢价，但对于批处理重用物有所值。 |
| 前缀匹配 | 「为什么我的缓存未命中」 | 缓存仅在从开始到断点的每个 token 字节完全相同时才会命中。 |
| 上下文缓存（Gemini） | 「显式的那个」 | Google 的命名化、按存储计费的缓存对象；最适合跨多天重用大型语料库。 |

## 进一步阅读

- [Anthropic — Prompt caching](https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching)——`cache_control`、1 小时 TTL、盈亏平衡表。
- [OpenAI — Prompt caching](https://platform.openai.com/docs/guides/prompt-caching)——自动前缀匹配。
- [Google — Context caching](https://ai.google.dev/gemini-api/docs/caching)——`CachedContent` API 和存储定价。
- [Anthropic engineering — Prompt caching for long-context workloads](https://www.anthropic.com/news/prompt-caching)——原始发布文章，含延迟数据。
- Phase 11 · 05（上下文工程）——在哪里切割提示词以便缓存能够生效。
- Phase 11 · 11（缓存与成本）——将提示词缓存与用户消息的语义缓存配对。
- [Pope et al., "Efficiently Scaling Transformer Inference" (2022)](https://arxiv.org/abs/2211.05102)——提示词缓存向用户暴露的 KV 缓存内存模型；解释了为什么缓存的 prefix 重读比重计算便宜约 10 倍。
- [Agrawal et al., "SARATHI: Efficient LLM Inference by Piggybacking Decodes with Chunked Prefills" (2023)](https://arxiv.org/abs/2308.16369)——预填充（prefill）是提示词缓存所加速的阶段；这篇论文解释了为什么缓存命中时首 token 时间（TTFT）大幅下降而每 token 时间（TPOT）不受影响。
- [Leviathan et al., "Fast Inference from Transformers via Speculative Decoding" (2023)](https://arxiv.org/abs/2211.17192)——提示词缓存与推测解码（Speculative Decoding）、Flash Attention 和 MQA/GQA 并列，作为弯曲推理成本曲线的杠杆；阅读本文了解另外三个。