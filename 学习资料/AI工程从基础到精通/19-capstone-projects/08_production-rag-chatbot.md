# 综合项目 08 — 面向受监管垂直领域的生产级 RAG 聊天机器人

> Harvey、Glean、Mendable 和 LlamaCloud 在 2026 年都运行相同的生产形态。使用 docling 或 Unstructured 和 ColPali 进行视觉内容摄入。混合搜索。使用 bge-reranker-v2-gemma 进行重排序。使用 Claude Sonnet 4.7 进行合成，配合 60-80% 命中率的提示缓存（prompt caching）。使用 Llama Guard 4 和 NeMo Guardrails 进行防护。使用 Langfuse 和 Phoenix 进行监控。使用 RAGAS 在 200 个问题的黄金集上进行评分。在一个受监管领域（法律、临床、保险）构建一个，综合项目要求通过黄金集、红队测试和漂移仪表板。

**类型：** 综合项目
**语言：** Python（管道 + API）、TypeScript（聊天 UI）
**前置知识：** 阶段 5（NLP）、阶段 7（Transformer）、阶段 11（LLM 工程）、阶段 12（多模态）、阶段 17（基础设施）、阶段 18（安全）
**涵盖阶段：** P5 · P7 · P11 · P12 · P17 · P18
**时间：** 30 小时

## 问题

受监管领域的 RAG（法律合同、临床试验方案、保险政策）是 2026 年部署最多的生产形态，因为投资回报率显而易见且风险具体。Harvey（Allen & Overy 律所）为法律领域构建了它。Mendable 提供开发者文档版本。Glean 覆盖企业搜索。其模式是：高保真摄入、带重排序的混合检索、带引用强制执行和提示缓存的合成、多层安全防护，以及持续监控漂移。

困难的部分不是模型。而是管辖权感知合规（HIPAA、GDPR、SOC2）、引用级可审计性、成本控制（当命中率高时，提示缓存可提供 60-90% 的折扣）、通过 RAGAS 忠实度检测幻觉，以及当源文档更新而索引未跟上的漂移检测。本综合项目要求你在 200 个问题的黄金集上交付所有这些功能，并附带红队套件。

## 概念

管道有两个方面。**摄入**：docling 或 Unstructured 解析结构化文档；ColPali 处理视觉丰富的文档；块获得摘要、标签和基于角色的访问标签。向量存入 pgvector + pgvectorscale（低于 5000 万向量）或 Qdrant Cloud；稀疏 BM25 并行运行。**对话**：LangGraph 处理记忆和多轮；每个查询运行混合检索，使用 bge-reranker-v2-gemma-2b 重排序，使用 Claude Sonnet 4.7（提示缓存）合成，输出通过 Llama Guard 4 和 NeMo Guardrails，并发出引用锚定的响应。

评估栈有四个层次。**黄金集**（200 个带引用的标注问答）用于正确性。**红队**（越狱、PII 提取尝试、领域外问题）用于安全性。**RAGAS** 用于每轮自动计算忠实度/答案相关性/上下文精确度。**漂移仪表板**（Arize Phoenix）每周监控检索质量和幻觉评分。

提示缓存是成本杠杆。Claude 4.5+ 和 GPT-5+ 支持缓存系统提示 + 检索到的上下文。在 60-80% 命中率下，每次查询成本下降 3-5 倍。管道必须为稳定前缀设计（系统提示 + 重排序上下文在前），以实现高缓存命中率。

## 架构

```
文档（合同、方案、政策）
      |
      v
docling / Unstructured 解析 + ColPali 用于视觉内容
      |
      v
块 + 摘要 + 角色标签 + 管辖权标签
      |
      v
pgvector + pgvectorscale  +  BM25（Tantivy）
      |
查询 + 角色 + 管辖权
      |
      v
LangGraph 对话 Agent
   +--- 检索（混合）
   +--- 按角色 + 管辖权过滤
   +--- 重排序（bge-reranker-v2-gemma-2b 或 Voyage rerank-2）
   +--- 合成（Claude Sonnet 4.7，提示缓存）
   +--- 防护（Llama Guard 4 + NeMo Guardrails + Presidio 输出 PII 脱敏）
   +--- 引用 + 返回
      |
      v
评估：
  RAGAS 忠实度 / 答案相关性 / 上下文精确度（在线）
  Langfuse 标注队列（采样）
  Arize Phoenix 漂移（每周）
  红队套件（发布前）
```

## 技术栈

- 摄入：Unstructured.io 或 docling 用于结构化文档；ColPali 用于视觉丰富的 PDF
- 向量数据库：pgvector + pgvectorscale（低于 5000 万向量）；否则使用 Qdrant Cloud
- 稀疏检索：Tantivy BM25 带字段权重
- 编排：LlamaIndex Workflows（摄入）+ LangGraph（对话）
- 重排序器：bge-reranker-v2-gemma-2b 自托管或 Voyage rerank-2 托管
- LLM：Claude Sonnet 4.7 配合提示缓存；备选为自托管 Llama 3.3 70B
- 评估：RAGAS 0.2 在线，DeepEval 用于幻觉和越狱套件
- 可观测性：Langfuse 自托管配合标注队列；Arize Phoenix 用于漂移
- 防护栏：Llama Guard 4 输入/输出分类器、NeMo Guardrails v0.12 策略、Presidio PII 脱敏
- 合规：块上的基于角色的访问标签；GDPR/HIPAA 的管辖权标签

## 构建步骤

1. **摄入。** 使用 Unstructured 或 docling 解析你的语料库（严肃构建需 1000-10000 份文档）。对于扫描/视觉密集型页面，路由到 ColPali。生成带摘要、角色标签、管辖权标签的块。

2. **索引。** 稠密嵌入（Voyage-3 或 Nomic-embed-v2）存入 pgvector + pgvectorscale。通过 Tantivy 建立 BM25 侧索引。角色和管辖权过滤器作为载荷。

3. **混合检索。** 先按角色+管辖权过滤；然后并行稠密 + BM25；使用倒数排名融合（reciprocal rank fusion）合并；top-20 送重排序器；top-5 送合成。

4. **使用提示缓存合成。** 系统提示 + 静态策略在缓存头部；重排序上下文作为缓存扩展；用户问题作为未缓存后缀。稳态下目标 60-80% 缓存命中率。

5. **防护栏。** Llama Guard 4 用于输入；NeMo Guardrails 规则阻止领域外问题或策略禁止的话题；Presidio 脱敏输出中的意外 PII；引用强制执行后置过滤器。

6. **黄金集。** 200 个由领域专家标注的问答对，包含（答案、引用）。根据精确引用匹配、答案正确性、忠实度（RAGAS）对 Agent 评分。

7. **红队。** 50 个对抗性提示：越狱（PAIR、TAP）、PII 外泄尝试、领域外、跨管辖权泄露。按通过/失败和严重性评分。

8. **漂移仪表板。** Arize Phoenix 每周追踪检索质量（nDCG、引用忠实度）。在 5% 下降时告警。

9. **成本报告。** Langfuse：提示缓存命中率、每次查询 Token 数、按阶段拆分的每次查询美元成本。

## 使用方式

```
$ chat --role=analyst --jurisdiction=GDPR
> 根据我们的合同，欧盟用户档案的数据保留义务是什么？
[retrieve]  混合 top-20 过滤至 GDPR + 分析师角色
[rerank]    保留 top-5
[synth]     claude-sonnet-4.7，缓存命中 74%，0.8s
答案：
  合同（第 12.4 条，主服务协议，日期 2024-03-11）要求根据 GDPR 第 17 条，
  在终止后 30 天内删除欧盟用户档案。DPA 修正案（DPA-v2.1，第 5 条）
  将"受限"类别数据的期限延长至 14 天。
  引用：[MSA-2024-03-11 s12.4, DPA-v2.1 s5]
```

## 交付标准

`outputs/skill-production-rag.md` 描述交付物。一个带合规标签部署的受监管领域聊天机器人，通过评分标准，并通过实时漂移监控观察。

| 权重 | 标准 | 衡量方式 |
|:-:|---|---|
| 25 | RAGAS 忠实度 + 答案相关性 | 黄金集（200 问答）上的在线评分 |
| 20 | 引用正确性 | 具有可验证源锚点的答案比例 |
| 20 | 防护栏覆盖 | Llama Guard 4 通过率 + 越狱套件结果 |
| 20 | 成本/延迟工程 | 提示缓存命中率、p95 延迟、每次查询美元成本 |
| 15 | 漂移监控仪表板 | Phoenix 实时仪表板，包含每周检索质量趋势 |
| **100** | | |

## 练习

1. 在不同管辖权下构建第二个语料库切片（例如，HIPAA 与 GDPR 并列）。在 20 个问题的跨管辖权探针上演示角色+管辖权过滤防止交叉泄露。

2. 衡量一周生产流量中的提示缓存命中率。识别哪些查询破坏了缓存前缀。重构。

3. 添加 1 万 Token 摘要缓冲区的多轮记忆。衡量忠实度是否随对话增长而下降。

4. 将 Claude Sonnet 4.7 替换为自托管 Llama 3.3 70B。衡量每次查询美元成本和忠实度差异。

5. 添加"不确定"模式：如果 top 重排序分数低于阈值，Agent 说"我没有置信度足够的引用"而不是回答。衡量假置信度降低。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|------------------------|
| 提示缓存（Prompt caching） | "缓存的系统 + 上下文" | Claude/OpenAI 功能：缓存前缀 Token 在命中时享受 60-90% 折扣 |
| RAGAS | "RAG 评估器" | 忠实度、答案相关性、上下文精确度的自动评分 |
| 黄金集（Golden set） | "标注评估" | 200+ 专家标注的带引用问答；作为基础真相 |
| 管辖权标签（Jurisdiction tag） | "合规标签" | 附加到块的 GDPR/HIPAA/SOC2 范围；由检索过滤器强制执行 |
| 引用忠实度（Citation faithfulness） | "有根据的回答率" | 由可检索源范围支撑的声明比例 |
| 漂移（Drift） | "检索质量衰减" | nDCG 或引用评分的每周变化；告警阈值 5% |
| 红队（Red team） | "对抗性评估" | 发布前越狱、PII 提取、领域外探测 |

## 延伸阅读

- [Harvey AI](https://www.harvey.ai) — 参考法律生产技术栈
- [Glean 企业搜索](https://www.glean.com) — 参考企业级 RAG
- [Mendable 文档](https://mendable.ai) — 开发者文档 RAG 参考
- [LlamaCloud Parse + Index](https://docs.llamaindex.ai/en/stable/examples/llama_cloud/llama_parse/) — 托管摄入
- [Anthropic 提示缓存](https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching) — 成本杠杆参考
- [RAGAS 0.2 文档](https://docs.ragas.io/) — 规范 RAG 评估框架
- [Arize Phoenix](https://github.com/Arize-ai/phoenix) — 参考漂移可观测性
- [Llama Guard 4](https://ai.meta.com/research/publications/llama-guard-4/) — 2026 安全分类器
- [NeMo Guardrails v0.12](https://docs.nvidia.com/nemo-guardrails/) — 策略规则框架