# 综合项目 02 —— 代码库 RAG（跨仓库语义搜索）

> 2026 年每个认真的工程组织都在运行一个理解语义而非仅字符串的内部代码搜索。Sourcegraph Amp、Cursor 的 codebase answers、Augment 的企业图谱、Aider 的 repomap、Pinterest 的内部 MCP —— 形态相同。摄入多个仓库，用 tree-sitter 解析，嵌入函数级和类级代码块，混合搜索，重排序，带引用作答。本综合项目要求你构建一个能处理 10 个仓库中 200 万行代码，并在每次 git push 时能生存增量重索引的系统。

**类型：** 综合项目
**语言：** Python（摄入），TypeScript（API + UI）
**前置知识：** Phase 5（NLP 基础），Phase 7（transformers），Phase 11（LLM 工程），Phase 13（工具），Phase 17（基础设施）
**涉及的 Phase：** P5 · P7 · P11 · P13 · P17
**时间：** 30 小时

## 问题

到 2026 年，每个前沿编程 agent 都配备了代码库检索层，因为单靠上下文窗口无法解决跨仓库问题。Claude 的 1M token 上下文有帮助；它不能消除排序检索的需求。对原始代码块进行朴素余弦搜索会在生成代码、单一仓库重复以及很少被导入的符号长尾上产生污染结果。生产环境的答案是：在 AST 感知的代码块上进行混合（稠密 + BM25）搜索，辅以重排序器，并由符号引用图支持。

你通过为一个真实的代码仓库群 —— 不是一个教程仓库 —— 建立索引来学习这一点，并度量 MRR@10、引用保真度和增量新鲜度。失效模式是基础设施层面的：一个 10 万文件的单体仓库、一次触及一半文件的 push、一个需要跨越四个仓库才能正确回答的查询。

## 概念

AST 感知的摄入管道用 tree-sitter 解析每个文件，提取函数和类节点，并在节点边界而非固定 token 窗口处切分代码块。每个代码块获得三种表示：稠密嵌入（Voyage-code-3 或 nomic-embed-code）、稀疏 BM25 词项，以及一个简短的自然语言摘要。摘要增加了第三种可检索模态 —— 用户问"X 是如何授权的"，摘要中提到"authz"，即使代码中只有 `check_permission`。

检索是混合的。一个查询同时触发稠密和 BM25 搜索，合并 top-k，将并集交给跨编码器重排序器（Cohere rerank-3 或 bge-reranker-v2-gemma-2b）。重排序后的列表交给长上下文合成器（Claude Sonnet 4.7 带提示缓存，或自托管的 Llama 3.3 70B），指令是按文件和行范围引用每个声明。没有引用的答案被后置过滤器拒绝。

增量新鲜度是基础设施问题。Git push 触发 diff：哪些文件发生了变化，哪些符号发生了变化。只有受影响的代码块被重新嵌入。受影响的跨文件符号边（导入、方法调用）被重新计算。索引保持一致，无需每次提交重新处理 200 万行。

## 架构

```
git push --> webhook --> ingest worker (LlamaIndex Workflow)
                           |
                           v
             tree-sitter parse + AST chunk
                           |
            +--------------+----------------+
            v              v                v
         稠密嵌入         BM25 索引         摘要 (LLM)
        (Voyage / bge)   (Tantivy)        (Haiku 4.5)
            |              |                |
            +------> Qdrant / pgvector <----+
                            |
                            v
                      symbol graph (Neo4j / kuzu)
                            |
  query --> LangGraph agent (retrieve -> rerank -> synth)
                            |
                            v
                 Claude Sonnet 4.7 1M context
                            |
                            v
                 带 file:line 引用的答案
```

## 技术栈

- 解析：tree-sitter，支持 17 种语言语法（Python、TS、Rust、Go、Java、C++ 等）
- 稠密嵌入：Voyage-code-3（托管）或 nomic-embed-code-v1.5（自托管），bge-code-v1 作为后备
- 稀疏索引：Tantivy（Rust）配合 BM25F，符号名 vs 函数体的字段加权
- 向量数据库：Qdrant 1.12 配合混合搜索，或 pgvector + pgvectorscale（适用于低于 5000 万向量的团队）
- 代码块摘要模型：Claude Haiku 4.5 或 Gemini 2.5 Flash，提示缓存
- 重排序器：Cohere rerank-3 或自托管的 bge-reranker-v2-gemma-2b
- 编排：LlamaIndex Workflows 用于摄入，LangGraph 用于查询 agent
- 合成器：Claude Sonnet 4.7（1M 上下文）配合提示缓存
- 符号图：Neo4j（托管）或 kuzu（嵌入）用于导入和调用边
- 可观测性：每个检索 + 合成步骤的 Langfuse span

## 构建步骤

1. **摄入遍历器。** 在每次 push 钩子上迭代 git 历史。收集变更文件。对每个文件，用 tree-sitter 解析，提取函数和类节点及其完整源代码范围。输出代码块记录 `{repo, path, start_line, end_line, symbol, body}`。

2. **代码块摘要器。** 将代码块分批发送到 Haiku 4.5 调用，在系统前言上使用提示缓存。提示："用一句话总结此函数，命名其公共契约和副作用。"将摘要与代码块一起存储。

3. **嵌入池。** 两个并行队列：稠密（Voyage-code-3 batch 128）和摘要（同一模型，但在摘要字符串上）。将向量写入 Qdrant，附带负载 `{repo, path, start_line, end_line, symbol, kind}`。

4. **BM25 索引。** 字段加权的 Tantivy 索引：符号名权重 4，符号体权重 1，摘要权重 2。既能支持"找到名为 X 的函数"的查询，也能支持"找到做 X 的函数"的查询。

5. **符号图。** 对每个代码块，记录边：导入（此文件使用来自仓库 Z 的符号 Y）、调用（此函数调用类 C 的方法 M）、继承。存储在 kuzu 中。在查询时用于跨仓库边界扩展检索。

6. **查询 agent。** 带三个节点的 LangGraph。`retrieve` 并行触发稠密 + BM25，按 (repo, path, symbol) 去重。`rerank` 在 top-50 上运行跨编码器，保留 top-10。`synth` 调用 Claude Sonnet 4.7，在上下文中使用重排序后的代码块，缓存系统提示，要求 file:line 引用。

7. **引用强制执行。** 解析模型输出；任何没有 `(repo/path:start-end)` 锚点的声明被标记为需要重新询问或丢弃。仅返回带引用的答案给用户。

8. **增量重索引。** 在每次 webhook 上，计算符号级 diff。仅重新嵌入文本发生变化的代码块。重新计算导入发生变化的代码块的符号边。度量：200 万行代码的仓库群中，50 文件 push 在 60 秒内完成重索引。

9. **评估。** 标注 100 个跨仓库问题，附带金标准 file:line 答案。度量 MRR@10、nDCG@10、引用保真度（可验证锚点的声明比例）以及 p50/p99 延迟。

## 使用方式

```
$ code-rag ask "how is S3 multipart abort wired into our retry budget?"
[retrieve]  12 chunks dense + 7 chunks bm25, 16 unique after dedup
[rerank]    top-5 kept (cohere rerank-3)
[synth]     claude-sonnet-4.7, cache hit rate 68%, 2.1s
answer:
  Multipart aborts are triggered by `AbortMultipartOnFail` in
  services/uploader/retry.go:122-148, which decrements the per-bucket
  retry budget defined in config/budgets.yaml:34-51 ...
  citations: [services/uploader/retry.go:122-148, config/budgets.yaml:34-51,
              libs/s3client/multipart.ts:44-61]
```

## 产出

可交付技能 `outputs/skill-codebase-rag.md`。给定一个仓库语料库，启动摄入管道、混合索引和查询 agent，并为任何跨仓库问题返回带引用的答案。评分标准：

| 权重 | 标准 | 度量方式 |
|:-:|---|---|
| 25 | 检索质量 | 在 100 问题留出集上的 MRR@10 和 nDCG@10 |
| 20 | 引用保真度 | 带可验证 file:line 锚点的答案声明比例 |
| 20 | 延迟和规模 | 在索引语料库规模下 10k QPS 的 p95 查询延迟 |
| 20 | 增量索引正确性 | 50 文件提交从 git push 到可搜索的时间 |
| 15 | 用户体验和答案格式 | 引用可点击性、片段预览、追问支持 |
| **100** | | |

## 练习

1. 将 Voyage-code-3 替换为自托管的 nomic-embed-code。度量 MRR@10 差值。报告启用重排序后差距是否缩小。

2. 向语料库注入 20% 生成代码（LLM 生成的样板代码）并重新评估。观察检索污染。在负载中添加"generated"标志并对这些命中降权。

3. 在你的语料库规模下基准测试 Qdrant 混合搜索 vs pgvector + pgvectorscale。报告 batch size 1 的 p99。

4. 添加基于采样的漂移检查：每周重新运行 100 问题的评估。对 MRR@10 下降 > 5% 告警。

5. 扩展到跨语言符号解析：一个 Python 函数通过 gRPC 调用 Go 服务。使用符号图将它们链接起来。

## 关键术语

| 术语 | 人们常说的 | 实际含义 |
|------|-----------|---------|
| AST 感知分块（AST-aware Chunking） | "函数级切分" | 在 tree-sitter 节点边界处而非固定 token 窗口处切割代码 |
| 混合搜索（Hybrid Search） | "稠密 + 稀疏" | 并行运行 BM25 和向量搜索，合并 top-k，重排序 |
| 跨编码器重排序（Cross-encoder Rerank） | "第二阶段排序" | 模型对每个 (查询, 候选) 对一起评分，比余弦相似度更准确 |
| 提示缓存（Prompt Caching） | "缓存系统提示" | 2026 年 Claude / OpenAI 特性，对重复前缀 token 折扣最高 90% |
| 符号图（Symbol Graph） | "代码图谱" | 跨文件和仓库的导入、调用、继承边 |
| 引用保真度（Citation Faithfulness） | "有根据的答案率" | 用户通过点击锚点并阅读引用范围可以验证的声明比例 |
| 增量重索引（Incremental Re-index） | "推送至可搜索时间" | 从 git push 到变更符号可查询的墙上时钟时间 |

## 扩展阅读

- [Sourcegraph Amp](https://ampcode.com) —— 生产环境跨仓库代码智能
- [Sourcegraph Cody RAG architecture](https://sourcegraph.com/blog/how-cody-understands-your-codebase) —— 本综合项目的参考深入分析
- [Aider repo-map](https://aider.chat/docs/repomap.html) —— tree-sitter 排序仓库视图
- [Augment Code enterprise graph](https://www.augmentcode.com) —— 商业符号图 RAG
- [Qdrant hybrid search docs](https://qdrant.tech/documentation/concepts/hybrid-queries/) —— 参考实现
- [Voyage AI code embeddings](https://docs.voyageai.com/docs/embeddings) —— Voyage-code-3 详情
- [Cohere rerank-3](https://docs.cohere.com/reference/rerank) —— 跨编码器参考
- [Pinterest MCP internal search](https://medium.com/pinterest-engineering) —— 内部平台参考