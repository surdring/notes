# 综合项目 04 —— 多模态文档问答（视觉优先的 PDF、表格、图表）

> 2026 年文档问答的前沿从 OCR 然后文本转向了视觉优先的延迟交互（Late Interaction）。ColPali、ColQwen2.5 和 ColQwen3-omni 将每个 PDF 页面作为图像处理，用多向量延迟交互嵌入，并让查询直接关注图像块（patch）。在财务 10-K 报表、科学论文和手写笔记上，这种模式大幅优于 OCR 优先方案。在 10k 页面上端到端构建管道，并与 OCR 然后文本方案进行并排比较。

**类型：** 综合项目
**语言：** Python（管道），TypeScript（查看器 UI）
**前置知识：** Phase 4（计算机视觉），Phase 5（NLP），Phase 7（transformers），Phase 11（LLM 工程），Phase 12（多模态），Phase 17（基础设施）
**涉及的 Phase：** P4 · P5 · P7 · P11 · P12 · P17
**时间：** 30 小时

## 问题

企业拥有被 OCR 管道破坏的 PDF：带有旋转表格的扫描版 10-K、密集方程的科学论文、只有作为图像才有意义的图表、手写批注。将这些视为文本优先意味着丢失一半信号。2026 年的答案是在原始页面图像上进行延迟交互多向量检索。ColPali（Illuin Tech）引入了它；ColQwen2.5-v0.2 和 ColQwen3-omni 推动了准确性。在 ViDoRe v3 上，视觉优先检索的得分以显著优势高于 OCR 然后文本 —— 并且在图表、表格和手写上的差距更大。

权衡在于存储和延迟。ColQwen 嵌入约每页 2048 个 patch 向量，而非单个 1024 维向量。原始存储膨胀。DocPruner（2026）在无明显准确率损失的情况下实现了 50% 剪枝。你需要为 10k 页面建立索引，度量 ViDoRe v3 nDCG@5，在 2 秒内提供答案，并直接与 OCR 然后文本基线对比。

## 概念

延迟交互意味着每个查询 token 与每个 patch token 独立评分，每个查询 token 的最大分数被求和。你可以获得细粒度匹配，而不需要单个池化向量。多向量索引（Vespa、Qdrant multi-vector 或 AstraDB）存储每个 patch 的嵌入，并在检索时运行 MaxSim。

回答器是一个视觉语言模型（VLM），接收查询加上 top-k 检索页面作为图像，并写出带有证据区域（边界框或页面引用）的答案。Qwen3-VL-30B、Gemini 2.5 Pro 和 InternVL3 是 2026 年的前沿选择。对于方程和科学符号，OCR 后备方案（Nougat、dots.ocr）作为可选的文本通道被拼接进去。

评估是一个二维矩阵。一个轴：内容类型（纯文本段落、密集表格、柱/折线图、手写笔记、方程）。另一个轴：检索方法（视觉优先延迟交互 vs OCR 然后文本 vs 混合）。每个单元格得到 nDCG@5 和答案准确率。报告是可交付成果。

## 架构

```
PDFs -> page renderer (PyMuPDF, 180 DPI)
           |
           v
  ColQwen2.5-v0.2 embed (多向量每页, ~2048 patches)
           |
           +------> DocPruner 50% 压缩
           |
           v
   multi-vector index (Vespa 或 Qdrant multi-vector)
           |
query ----+----> retrieve top-k pages (MaxSim)
           |
           v
  VLM answerer: Qwen3-VL-30B | Gemini 2.5 Pro | InternVL3
    输入: query + top-k page images + optional OCR text
           |
           v
  带引用页码 + 证据区域的答案
           |
           v
  Streamlit / Next.js viewer: 源页面上高亮边界框
```

## 技术栈

- 页面渲染：PyMuPDF (fitz)，180 DPI，纵向标准化
- 延迟交互模型：ColQwen2.5-v0.2 或 ColQwen3-omni（Hugging Face 上的 vidore 团队）
- 索引：Vespa 配合多向量字段，或 Qdrant multi-vector，或 AstraDB 配合 MaxSim
- 剪枝：DocPruner 2026 策略（保留高方差 patch，50% 压缩，< 0.5% 准确率损失）
- OCR 后备方案（方程/密集表格）：dots.ocr 或 Nougat
- VLM 回答器：自托管 Qwen3-VL-30B 或托管 Gemini 2.5 Pro；InternVL3 作为后备
- 评估：ViDoRe v3 基准，M3DocVQA 用于多页推理
- 查看器 UI：Next.js 15 配合 canvas 叠加层用于证据区域

## 构建步骤

1. **摄入。** 遍历包含 10-K、科学论文和扫描文档的 10k PDF 页面语料库。将每个页面渲染为 1536x2048 PNG。持久化 `{doc_id, page_num, image_path}`。

2. **嵌入。** 在每个页面图像上运行 ColQwen2.5-v0.2。输出形状约 2048 patch 嵌入，维度 128。应用 DocPruner 保留最高信号的一半。写入 Vespa 多向量字段或 Qdrant multi-vector。

3. **查询。** 对每个传入查询，用查询塔（token 级嵌入）进行嵌入。对索引运行 MaxSim：对每个查询 token，取页面 patch 嵌入的最大点积，求和。返回 top-k 页面。

4. **合成。** 用查询和 top-5 页面图像调用 Qwen3-VL-30B。提示："仅使用提供的页面回答。每个声明引用 (doc_id, page) 并命名区域（figure, table, paragraph）。"

5. **证据区域。** 后处理答案以提取引用区域。如果 VLM 输出边界框（Qwen3-VL 可以），在查看器中将它们渲染为叠加层。

6. **OCR 后备方案。** 对于被识别为方程密集的页面（基于图像方差的启发式），运行 Nougat 或 dots.ocr，并将 OCR 文本作为额外通道与图像一起传递。

7. **评估。** 运行 ViDoRe v3（检索 nDCG@5）和 M3DocVQA（多页 QA 准确率）。在同一语料库上使用相同合成器运行 OCR 然后文本管道。生成内容类型 × 方法矩阵。

8. **UI。** 先使用 Streamlit 原型；Next.js 15 生产环境查看器，带逐页证据区域叠加层。

## 使用方式

```
$ doc-qa ask "what was the 2024 operating margin change for segment EMEA?"
[retrieve]   top-5 pages in 320ms (ColQwen2.5, MaxSim, Vespa)
[synth]      qwen3-vl-30b, 1.4s, cited (form-10k-2024, p. 88) + (..., p. 92)
answer:
  EMEA operating margin moved from 18.2% to 16.8%, a 140bp decline.
  cited: 10-K-2024.pdf p.88 (Table 4, Segment Operating Margin)
         10-K-2024.pdf p.92 (MD&A, Operating Performance)
[viewer]     open with highlighted bounding boxes overlaid on p.88 Table 4
```

## 产出

`outputs/skill-doc-qa.md` 描述可交付成果：一个视觉优先的多模态文档 QA 系统，针对特定语料库调优，并在 ViDoRe v3 上与 OCR 然后文本基线进行对比评估。

| 权重 | 标准 | 度量方式 |
|:-:|---|---|
| 25 | ViDoRe v3 / M3DocVQA 准确率 | 基准数据 vs OCR-text 基线和已发表排行榜 |
| 20 | 证据区域定位 | 实际包含答案范围的引用区域比例 |
| 20 | 存储和延迟工程 | DocPruner 压缩比、索引 p95、答案 p95 |
| 20 | 多页推理 | 手工标注的 100 问题多页集合的准确率 |
| 15 | 源文件检查用户体验 | 查看器清晰度、叠加保真度、并排比较工具 |
| **100** | | |

## 练习

1. 在同一语料库上度量 ColQwen2.5-v0.2 vs ColQwen3-omni。一个模型做对了哪些页面而另一个做错了？在索引中添加"内容类别"标签按类型路由。

2. 激进地剪枝嵌入（75%、90%）。找到压缩悬崖：ViDoRe nDCG@5 降至 OCR 基线以下的点。

3. 构建混合方案：并行运行 OCR 然后文本和 ColQwen，用 RRF 融合，跨编码器重排序。混合方案是否优于单独任一方法？它在何处帮助最大？

4. 将 Qwen3-VL-30B 替换为较小的 VLM（Qwen2.5-VL-7B）。度量准确率-每美元曲线。

5. 添加手写笔记支持。渲染手写语料库，用 ColQwen 嵌入，度量检索。与手写 OCR 管道对比。

## 关键术语

| 术语 | 人们常说的 | 实际含义 |
|------|-----------|---------|
| 延迟交互（Late Interaction） | "ColPali 风格检索" | 查询 token 与页面 patch 独立评分；MaxSim 聚合 |
| 多向量（Multi-vector） | "每个 patch 的嵌入" | 每个文档有多个向量，而非一个池化向量 |
| MaxSim | "延迟交互评分" | 对每个查询 token，取文档向量的最大相似度；求和 |
| DocPruner | "Patch 压缩" | 2026 年剪枝，保留 50% patch 且准确率损失可忽略 |
| ViDoRe v3 | "文档检索基准" | 2026 年度量视觉文档检索的标准 |
| 证据区域（Evidence Region） | "引用边界框" | 源页面上定位答案范围的边界框 |
| OCR 后备方案（OCR Fallback） | "方程通道" | 在方程或表格密集页面上与视觉并用的文本管道 |

## 扩展阅读

- [ColPali (Illuin Tech) repository](https://github.com/illuin-tech/colpali) —— 参考延迟交互文档检索
- [ColPali paper (arXiv:2407.01449)](https://arxiv.org/abs/2407.01449) —— 基础方法论文
- [ColQwen family on Hugging Face](https://huggingface.co/vidore) —— 生产就绪的检查点
- [M3DocRAG (Adobe)](https://arxiv.org/abs/2411.04952) —— 多页多模态 RAG 基线
- [Vespa multi-vector tutorial](https://docs.vespa.ai/en/colpali.html) —— 参考服务栈
- [Qdrant multi-vector support](https://qdrant.tech/documentation/concepts/vectors/#multivectors) —— 替代索引
- [AstraDB multi-vector](https://docs.datastax.com/en/astra-db-serverless/databases/vector-search.html) —— 替代托管索引
- [Nougat OCR](https://github.com/facebookresearch/nougat) —— 支持方程的 OCR 后备方案