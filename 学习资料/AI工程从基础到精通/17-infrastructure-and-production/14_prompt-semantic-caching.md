# 提示词缓存与语义缓存经济学

> **定价快照，记录于 2026-04。** 以下数字反映了本课发布时各供应商的费率表；在下游引用前请核对链接中的文档。

> 缓存发生在两个层面。L2（供应商层）提示词/前缀缓存为重复前缀复用注意力的 KV——Anthropic 的提示词缓存文档宣传长提示词上最高 90% 的成本降低和 85% 的延迟降低；Claude 3.5 Sonnet 的缓存读取为 $0.30/M vs 新鲜输入 $3.00/M，TTL 为 5 分钟，1 小时 TTL 选项有 2 倍写入溢价（docs.anthropic.com，2026-04）。OpenAI 提示词缓存自动应用于 ≥1024 token 的提示词，缓存输入价格约为新鲜输入的 10%（platform.openai.com，2026-04）；每个模型的具体缓存费率取决于实时费率表。L1（应用层）语义缓存在嵌入相似度命中时完全跳过 LLM。供应商"95% 准确率"指的是匹配正确性，而非命中率——报告的生产命中率从 10%（开放式对话）到 70%（结构化 FAQ）；没有供应商发布官方基准线，因此这些应被视为社区遥测数据而非保证。生产陷阱：并行化会破坏缓存（在第一次缓存写入完成之前发出的 N 个并行请求可能将支出膨胀数倍），以及缓存前缀中的动态内容会完全阻止缓存命中。ProjectDiscovery 报告通过将动态文本移出可缓存前缀，将命中率从 7% 提升到 74%（2025-11）。

**类型：** 学习
**语言：** Python（标准库，玩具级双层缓存模拟器）
**前置知识：** 第 17 阶段 · 04（vLLM 推理内部），第 17 阶段 · 06（SGLang RadixAttention）
**时间：** 约 60 分钟

## 学习目标

- 区分 L2 提示词/前缀缓存（供应商端 KV 复用）和 L1 语义缓存（相似提示词完全绕过 LLM）。
- 解释 Anthropic 的 `cache_control` 显式标记以及两种 TTL 选项（5 分钟 vs 1 小时）及其价格倍率。
- 在给定命中率、提示词/响应组合和 token 价格的情况下，计算预期月节省。
- 说出将账单膨胀 5-10 倍的并行化反模式，以及使命中率崩溃的动态内容反模式。

## 问题

你为 RAG 服务添加了提示词缓存。账单持平。你测量命中率；是 7%。你的提示词看起来是静态的，但实际上不是——系统提示词包含了格式化到分钟的当前日期、一个请求 ID 以及为了多样性而随机重排的示例。每次请求都写入新的缓存条目，读取为零。

另外，你的 agent 为每个用户问题并行运行十个工具调用。所有十个请求在第一个缓存写入完成之前到达供应商。十次写入，零次读取。你的账单是"启用缓存"应有成本的 5-10 倍。

缓存是一个协议，不是一个开关。两个层面，两种不同的失败模式。

## 概念

### L2 — 供应商提示词/前缀缓存

供应商存储可缓存前缀的注意力 KV，并在下一个匹配该前缀的请求中复用它。你支付一次写入成本，读取几乎免费。

**Anthropic（Claude 3.5 / 3.7 / 4 系列）**：请求中显式的 `cache_control` 标记。你标记哪些块可缓存。TTL：5 分钟（写入成本为基础价的 1.25 倍）或 1 小时（写入成本为基础价的 2 倍）。缓存读取：Claude 3.5 Sonnet 上 $0.30/M vs 新鲜输入 $3.00/M——便宜 10 倍（docs.anthropic.com，截至 2026-04）。不同模型的费率不同（Opus/Haiku 单独发布）；始终交叉核对实时定价页面。

**OpenAI**：≥1024 token 的提示词自动缓存（platform.openai.com，2026-04）。无显式标记。在当前 gpt-4o/gpt-5 费率表上，缓存输入约为新鲜输入的十分之一。文档和发布说明均未发布官方命中率基准线；社区报告在精心设计提示词的情况下集中在 30-60%。监控 `usage.cached_tokens` 来测量你自己的命中率。

**Google（Gemini）**：通过显式 API 进行上下文缓存；1M token 上下文意味着缓存回报更大。

**自托管（vLLM、SGLang）**：第 17 阶段 · 06 介绍了 RadixAttention——相同的模式，基于你自己的算力。

### L1 — 应用层语义缓存

在调用 LLM 之前，对提示词做哈希，进行嵌入，查找相似的已缓存请求（余弦相似度（Cosine Similarity）高于阈值，通常 0.95+）。命中时返回已缓存的响应。未命中时调用 LLM 并缓存结果。

开源：Redis Vector Similarity、GPTCache、Qdrant。商业：Portkey Cache、Helicone Cache。

供应商的准确率声明指的是返回的缓存响应在语义上适当的频率——而非你命中的频率。生产命中率：

- 开放式对话：10-15%。
- 结构化 FAQ / 支持：40-70%。
- 代码问题：20-30%（微小变体即破坏命中）。
- 语音代理重复提示词：50-80%（语音归一化固定集）。

### 并行化反模式

你的 agent 并行发起 10 个工具调用。所有 10 个调用共享相同的 4K token 系统提示词。Anthropic 缓存写入是按请求的；第一个缓存写入在供应商看到提示词后约 300 ms 完成。请求 2-10 在同一毫秒窗口内到达，每个都看到缓存未命中。你支付 10 次写入溢价，0 次读取折扣。

修复：先顺序再批量——先单独发出请求 1，等 1 的缓存填充后，再发出 2-10。增加 300 ms 到第一个工具调用；节省 5-10 倍的账单。

### 动态内容反模式

你的系统提示词看起来像：

```
You are a helpful assistant. The current time is 14:32:17.
User ID: abc123. Today is Tuesday...
```

每个请求都是唯一的。每个请求都写入。零命中。

修复：将所有真正静态的内容移到可缓存前缀中；在缓存边界之后附加动态内容：

```
[cacheable]
You are a helpful assistant. [rules, examples, instructions]
[/cacheable]
[dynamic, not cached]
Current time: 14:32:17. User: abc123.
```

ProjectDiscovery 通过这种方式将缓存命中率从 7% 提升到 74%，并发布了具体分析。

### 为夜间工作负载叠加批处理 + 缓存

批处理 API（第 17 阶段 · 15）在 24 小时周转下提供 50% 折扣。在此基础上叠加缓存输入可再获得约 10 倍的折扣。夜间分类、标注和报告生成工作负载的成本可降至同步无缓存成本的约 10%。

### 应记住的数字

定价数据记录于 2026-04，来自链接的供应商文档，每隔几个月就会变化——在依赖它们之前重新检查。

- Anthropic 缓存读取：Claude 3.5 Sonnet 上 $0.30/M，约为新鲜输入的十分之一（docs.anthropic.com）。
- Anthropic 缓存写入溢价：1.25 倍（5 分钟 TTL）或 2 倍（1 小时 TTL）。
- OpenAI 自动缓存：适用于 ≥1024 token 的提示词；在当前费率表上缓存输入价格约为新鲜输入的 10%（platform.openai.com）。
- 语义缓存命中率（社区报告）：约 10% 开放对话；最高约 70% 结构化 FAQ。非供应商记录的基准线。
- ProjectDiscovery：通过将动态内容移出前缀，命中率从 7% → 74%（项目博客，2025-11）。
- 并行化反模式：典型报告当 N 个并行请求错过第一次缓存写入时，账单膨胀 5-10 倍。

## 使用它

`code/main.py` 在混合工作负载上模拟 L1 + L2 缓存。报告命中率、账单，并展示并行化惩罚。

## 交付它

本课生成 `outputs/skill-cache-auditor.md`。根据提示词模板和流量，审查可缓存性并推荐结构重组。

## 练习

1. 运行 `code/main.py`。切换并行化标志。账单变化多少？
2. 你的系统提示词包含日期。将其移出。展示前后命中率计算。
3. 给定你的请求到达率，计算 1 小时 TTL（2 倍写入）与 5 分钟 TTL（1.25 倍写入）的盈亏平衡。
4. 语义缓存在 0.95 阈值下命中 20%。在 0.85 阈值下命中 50% 但你看到不正确的缓存响应。选择正确的阈值并说明理由。
5. 你为每个用户问题批处理 10 个并行子查询。重新设计以支持缓存友好，且不增加端到端延迟。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|----------------|------------------------|
| L2 prompt cache | "前缀缓存" | 供应商为重复前缀存储 KV |
| `cache_control` | "Anthropic 缓存标记" | 标记可缓存块的显式属性 |
| Cache write premium | "写入税" | 第一次未命中到缓存的额外成本（1.25x 或 2x） |
| L1 semantic cache | "嵌入缓存" | 调用 LLM 前的应用层哈希与嵌入查找 |
| GPTCache | "LLM 缓存库" | 流行的开源 L1 缓存库 |
| Cache hit rate | "命中数 / 总数" | 从缓存服务的请求占比 |
| Parallelization anti-pattern | "N 次写入陷阱" | N 个并行请求各自错过缓存 N 次 |
| Dynamic content trap | "提示词中的时间陷阱" | 前缀中的动态字节抹杀命中率 |
| RadixAttention | "副本内缓存" | SGLang 的前缀缓存实现 |

## 延伸阅读

- [Anthropic Prompt Caching](https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching) — 官方 `cache_control` 语义和 TTL。
- [OpenAI Prompt Caching](https://platform.openai.com/docs/guides/prompt-caching) — 自动缓存行为和资格。
- [TianPan — Semantic Caching for LLMs Production](https://tianpan.co/blog/2026-04-10-semantic-caching-llm-production)
- [ProjectDiscovery — Cut LLM Costs 59% With Prompt Caching](https://projectdiscovery.io/blog/how-we-cut-llm-cost-with-prompt-caching)
- [DigitalOcean / Anthropic — Prompt Caching](https://www.digitalocean.com/blog/prompt-caching-with-digital-ocean)