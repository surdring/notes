# ColPali 与视觉原生文档 RAG

> 传统 RAG 将 PDF 解析为文本，分割成块，嵌入块，存储向量。每一步都丢失信息：OCR 丢失图表数据，分块破坏表格行，文本嵌入忽略图形。ColPali（Faysse et al.，2024年7月）提出了一个更简单的问题：为什么要提取文本？直接通过 PaliGemma 嵌入页面图像，使用 ColBERT 风格的后期交互（Late Interaction）进行检索，保留文档所携带的全部版面布局、图形、字体和格式信号。发表的基准测试结果：在视觉丰富的文档上，端到端准确率比文本 RAG 高 20-40%。ColQwen2、ColSmol 和 VisRAG 扩展了这一模式。本课将解读视觉原生 RAG 的核心理念，并构建一个小型 ColPali 风格的索引器。

**类型：** 构建
**语言：** Python（标准库，多向量索引器 + MaxSim 评分器）
**前置要求：** 第11阶段（LLM 工程——RAG 基础），第12阶段 · 05（LLaVA）
**时间：** ~180分钟

## 学习目标

- 解释双编码器检索（每个文档一个向量）与后期交互检索（每个文档多个向量）之间的区别。
- 描述 ColBERT 的 MaxSim 操作，以及 ColPali 如何将其从文本 Token 推广到图像块（Image Patch）。
- 构建一个小型 ColPali 风格索引器：页面 → 图像块嵌入 → 对查询词嵌入进行 MaxSim → top-k 页面。
- 在发票/财务报告用例上比较 ColPali + Qwen2.5-VL 生成器 vs 文本 RAG + GPT-4。

## 问题

对 PDF 进行文本 RAG 丢弃了文档的大部分信息。财务报告的 Q3 收入增长通常出现在图表中；医疗报告的结果存在于带标注的图像中；法律合同的签名块是一个版面事实，而非文本事实。

文本 RAG 流水线：

1. PDF → 通过 OCR / pdftotext 提取文本。
2. 文本 → 300-500 Token 的块。
3. 块 → 双编码器嵌入（一个向量）。
4. 用户查询 → 嵌入 → 余弦相似度 → top-k 块。
5. 块 + 查询 → LLM。

五个有损步骤。图表未被捕获。表格跨块断开。多栏布局被展平。图表标注消失。

ColPali 的修正：跳过 OCR，直接嵌入页面图像。使用 ColBERT 风格的后期交互进行检索，使模型在查询时能够关注细粒度的图像块。

## 核心概念

### ColBERT（2020）

ColBERT（Khattab & Zaharia，arXiv:2004.12832）是一种文本检索方法。不是每个文档一个向量，而是每个 Token 一个向量。在查询时：

- 查询 Token 获得各自的嵌入（N_q 个向量）。
- 文档 Token 获得嵌入（N_d 个向量，通常缓存）。
- 得分 = 对查询 Token 求和对文档 Token 取最大余弦相似度：Σ_i max_j cos(q_i, d_j)。

这就是 MaxSim 操作。每个查询 Token"选择"其最佳匹配的文档 Token。最终得分是总和。

优点：强召回率，处理词级语义。缺点：每个文档 N_d 个向量，存储昂贵。

### ColPali

ColPali（Faysse et al.，arXiv:2407.01449）将 ColBERT 模式应用于图像。

- 每个页面通过 PaliGemma（ViT + 语言）编码为图像块嵌入：每页 N_p 个向量。
- 每个用户查询（文本）编码为查询 Token 嵌入：N_q 个向量。
- 得分 = Σ_i max_j cos(q_i, p_j)，即在查询文本 Token 和页面图像块上的 MaxSim。
- 按总分检索 top-k 页面。

文档摄入时：用 PaliGemma 嵌入每个页面，存储所有图像块嵌入。查询时：嵌入查询 Token，对所有存储的页面嵌入计算 MaxSim，返回 top-k 页面。

优点：在视觉丰富的文档上端到端优于文本 RAG 20-40%。每个图像块向量捕获局部版面布局和内容。

缺点：每页 N_p 个图像块 × 4字节浮点 × D 维向量 = 存储增长快。通过 PQ / OPQ 量化缓解。

### ColQwen2 和 ColSmol

ColQwen2（illuin-tech，2024-2025）将 PaliGemma 替换为 Qwen2-VL。更好的基座编码器，更好的检索。

ColSmol 是用于本地/边缘场景的较小规模变体。约 1B 参数的 ColSmol 检索器可在消费级 GPU 上运行。

### VisRAG

VisRAG（Yu et al.，arXiv:2410.10594）是另一种变体：不使用图像块上的 MaxSim，而是用 VLM 将每个页面池化为一个向量，然后进行双编码器检索。索引更快 + 存储更小，召回率较弱。

质量与成本的权衡：ColPali 追求质量，VisRAG 追求规模。

### M3DocRAG

M3DocRAG（Cho et al.，arXiv:2411.04952）将多模态检索扩展到多页面多文档推理。跨文档检索页面，组合多页面上下文供 VLM 使用。

### ViDoRe——基准测试

ColPali 的配套基准测试。视觉文档检索评估（Visual Document Retrieval Evaluation）。任务包括财务报告、科学论文、行政文档、医疗记录、操作手册。指标：nDCG@5。

ColPali-v1 在 ViDoRe 上得分约 80% nDCG@5；同一文档上的文本 RAG 得分约 50-60%。

### 端到端 RAG 流水线

对于视觉原生 RAG：

1. 摄入：PDF → 页面图像 → PaliGemma 编码 → 存储所有图像块嵌入。
2. 查询：用户文本 → 查询 Token 嵌入 → 对所有已索引页面进行 MaxSim → top-k 页面。
3. 生成：top-k 页面图像 + 查询 → VLM（Qwen2.5-VL 或 Claude）→ 答案。

全程无 OCR。图表、图形、字体、版面布局全部流入答案。

### 存储计算

一份 50 页的财务报告，每页 729 个图像块，128 维嵌入：

- ColPali：50 * 729 * 128 * 4 字节 = 约 18 MB 原始，PQ 后约 4 MB。
- 文本 RAG：50 个块 * 768 维 * 4 字节 = 约 150 kB。

ColPali 的存储量约为每个文档的 30 倍。大规模下，OPQ / PQ 将其降至约 5-10 倍，通常可接受。

### 文本 RAG 仍然胜出的场景

- 无版面信号的纯文本文档（维基文章、聊天日志）。文本 RAG 更简单且存储更便宜。
- 数百万页的存档，存储成本占主导地位。
- 严格的监管要求，需要在检索同时提供可提取的 OCR 文本。

对于 2026 年的其他一切——财务报告、科学论文、法律合同、医疗记录、UX 文档——视觉原生 RAG 胜出。

## 实践

`code/main.py`：

- 玩具级图像块编码器：将"页面"（特征向量的小网格）映射到图像块嵌入数组。
- MaxSim 评分器：计算查询 Token 嵌入集与页面图像块集之间的 ColBERT 风格得分。
- 索引 5 个玩具页面，运行 3 个查询，返回带得分的 top-k。

## 成果输出

本课产出 `outputs/skill-vision-rag-designer.md`。给定一个文档 RAG 项目，选择 ColPali / ColQwen2 / VisRAG / 文本 RAG 并计算存储大小。

## 练习

1. 一份 200 页的年报，每页 729 个图像块，128 维嵌入，4 字节浮点。计算原始存储和 PQ 压缩（8x）后的存储。

2. MaxSim 是 Σ_i max_j cos(q_i, p_j)。这个和捕获了什么简单平均相似度没有捕获的信息？

3. ColPali 将页面索引为图像块集。如果我们改为在词级别索引（如 ColBERT 那样），会有什么变化？权衡是什么？

4. 为 100 万页语料库设计端到端流水线，每次查询延迟预算 500ms。选择 ColQwen2 / VisRAG 并论证。

5. 阅读 M3DocRAG（arXiv:2411.04952）。描述多页面注意力模式，以及它与单页面 ColPali 检索的不同之处。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| 后期交互 | "ColBERT 风格" | 使用每个 Token 或图像块的嵌入 + MaxSim 进行检索，而非单个文档向量 |
| MaxSim | "图像块上取最大" | 对每个查询 Token，选择相似度最高的文档 Token；跨查询求和 |
| 双编码器 | "单向量" | 每个文档一个向量；更快但丢失细粒度信息 |
| 多向量 | "每个文档多个向量" | 每个文档/页面存储 N_p 个向量；存储成本增加但召回率提升 |
| 图像块嵌入 | "页面特征" | 来自 VLM 编码器的每个图像块一个向量，按页面缓存 |
| ViDoRe | "视觉文档基准测试" | ColPali 的视觉文档检索基准测试套件 |
| PQ 量化 | "乘积量化" | 在保持向量相似度的同时将存储压缩约 8 倍 |

## 延伸阅读

- [Faysse et al. — ColPali (arXiv:2407.01449)](https://arxiv.org/abs/2407.01449)
- [Khattab & Zaharia — ColBERT (arXiv:2004.12832)](https://arxiv.org/abs/2004.12832)
- [Yu et al. — VisRAG (arXiv:2410.10594)](https://arxiv.org/abs/2410.10594)
- [Cho et al. — M3DocRAG (arXiv:2411.04952)](https://arxiv.org/abs/2411.04952)
- [illuin-tech/colpali GitHub](https://github.com/illuin-tech/colpali)