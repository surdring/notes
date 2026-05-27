# 文档与图表理解

> 文档不是照片。一份 PDF、科学论文、发票或手写表单具有版面布局、表格、图表、脚注、页眉和语义结构，这些都是纯图像理解无法捕获的。VLM 出现之前的栈是一个流水线：Tesseract OCR + LayoutLMv3 + 表格提取启发式规则。VLM 浪潮以无 OCR 模型（OCR-Free）取而代之——Donut（2022）、Nougat（2023）、DocLLM（2023）——直接输出结构化标记。到 2026 年，前沿水平就是"将页面图像以 2576px 原生分辨率输入 Claude Opus 4.7"，结构化标记输出自然可得。本课将解读文档 AI 的三个时代历程。

**类型：** 构建
**语言：** Python（标准库，版面感知文档解析器骨架）
**前置要求：** 第12阶段 · 05（LLaVA），第5阶段（NLP）
**时间：** ~180分钟

## 学习目标

- 解释文档 AI 的三个时代：OCR 流水线、无 OCR、VLM 原生。
- 描述 LayoutLMv3 的三路输入流：文本、版面布局（边界框）、图像块，以及统一掩码机制。
- 比较 Donut（无 OCR，图像 → 标记）、Nougat（科学论文 → LaTeX）、DocLLM（版面感知生成式）、PaliGemma 2（VLM 原生）。
- 为新任务选择合适的文档模型（发票、科学论文、手写表单、中文收据）。

## 问题

"理解这份 PDF"看似简单实则困难。信息分布在：

- 文本内容（90% 的信号）。
- 版面布局（页眉、脚注、侧边栏、双栏格式）。
- 表格（行、列、合并单元格）。
- 图形和图表。
- 手写批注。
- 字体和排版（标题 vs 正文）。

原始 OCR 转储文本而丢失其余信息。一个关心发票的系统需要知道"总计：¥1,245"来自右下角，而非脚注。

## 核心概念

### 时代 1——OCR 流水线（2021 年前）

经典栈：

1. PDF → 每页图像。
2. Tesseract（或商业 OCR）提取文本及每个词的边界框。
3. 版面分析器识别块（页眉、表格、段落）。
4. 表格结构识别器解析表格。
5. 领域规则 + 正则表达式提取字段。

对于干净的印刷文本效果良好。在手写、倾斜扫描、复杂表格、非英语文字上失败。每一种失败模式都需要自定义异常路径。

### TrOCR（2021）

TrOCR（Li et al.，arXiv:2109.10282）用一个在合成 + 真实文本图像上训练的 Transformer 编码器-解码器替代了 Tesseract 的经典 CNN-CTC。在手写和多语言文本上取得了显著优势。仍然是一个流水线（检测器然后 TrOCR 然后版面分析），但 OCR 步骤大幅改进。

### 时代 2——无 OCR（2022-2023）

第一批无 OCR 模型提出：完全跳过检测，直接将图像像素映射到结构化输出。

Donut（Kim et al.，arXiv:2111.15664）：
- 编码器-解码器 Transformer，编码器为 Swin-B。
- 输出：表单理解输出 JSON，摘要输出 Markdown，或任何任务特定的 Schema。
- 无 OCR、无版面分析、无检测。

Nougat（Blecher et al.，arXiv:2308.13418）：
- 专门针对科学论文训练。
- 输出 LaTeX / Markdown。
- 处理公式、多栏布局、图表。
- 每个 arXiv 解析器都在调用的模型。

这些是专家模型，不是通才。Donut 处理科学论文会失败；Nougat 处理发票会失败。

### LayoutLMv3（2022）

另一条路线。LayoutLMv3（Huang et al.，arXiv:2204.08387）保留 OCR 但添加版面理解：

- 三路输入流：OCR 文本 Token、每个 Token 的 2D 边界框、图像块。
- 跨三种模态的掩码训练目标（掩码文本、掩码图像块、掩码布局）。
- 下游：分类、实体提取、表格问答。

LayoutLMv3 是基于 OCR 的文档理解巅峰之作。在表单和发票上表现强劲。需要上游 OCR。在标准化文档基准测试上拥有 VLM 时代之前的最佳准确率。

### DocLLM（2023）

DocLLM（Wang et al.，arXiv:2401.00908）是 LayoutLM 的生成式姊妹模型。以版面 Token 为条件生成自由形式的答案。在文档问答方面更好；仍然依赖 OCR 输入。

### 时代 3——VLM 原生（2024+）

2024 年的 VLM 变得足够强大，可以完全替代流水线。将完整页面图像以高分辨率输入 VLM，提出问题，获得答案。

- LLaVA-NeXT 336-tile AnyRes 适用于小型文档。
- Qwen2.5-VL 动态分辨率原生处理 2048+ 像素。
- Claude Opus 4.7 支持 2576px 文档。
- PaliGemma 2（2025年4月）专门针对文档 + 手写训练。

VLM 原生与 OCR 流水线之间的差距迅速缩小。到 2026 年，VLM 原生在以下方面胜出：

- 场景文本（手写 + 印刷，混合文字系统）。
- 带合并单元格的复杂表格。
- 嵌入文本中的数学公式。
- 带文本注释的图表。

OCR 流水线仍然在以下方面胜出：

- 大规模纯扫描工作负载，每页延迟至关重要。
- 流水线可靠性（确定性失败 vs VLM 幻觉）。
- 需要可审计 OCR 输出的受监管环境。

### Claude 4.7 / GPT-5 前沿

在 2576 像素原生输入下，前沿 VLM 的文档理解接近人类准确率。2026 年初的基准测试数据：

- DocVQA：Claude 4.7 ~95.1，PaliGemma 2 ~88.4，Nougat ~77.3，流水线 LayoutLMv3 ~83。
- ChartQA：Claude 4.7 ~92.2，GPT-4V ~78。
- VisualMRC：Claude 4.7 ~94。

闭源模型的差距主要在于分辨率和基座 LLM 规模。7B 开源模型落后几个百分点，但正在追赶。

### 数学公式和 LaTeX 输出

科学论文需要公式的精确 LaTeX 输出。Nougat 专门为此训练。使用 LaTeX 目标训练的 VLM（Qwen2.5-VL-Math、Nougat 衍生物）可生成可用的 LaTeX。没有明确 LaTeX 训练的 VLM 会产生可读但不精确的转写。

2026 年科学论文流水线：在 PDF 上串联 Nougat，再在棘手页面使用 VLM。

### 手写

仍然是最难的子任务。混合印刷 + 手写（医生笔记、填写的表单）是 OCR 流水线在成本上仍优于 VLM 的领域。纯手写 VLM 正在改进（Claude 4.7、PaliGemma 2）。

### 2026 年方案

对于新的文档 AI 项目：

- 大规模纯印刷发票：LayoutLMv3 + 规则，成本高效。
- 混合文档（科学 + 手写 + 表单）：VLM 原生（PaliGemma 2 或 Qwen2.5-VL）。
- 完整 arXiv 摄入：Nougat 用于数学，VLM 用于图表。
- 受监管环境：OCR 流水线 + VLM 验证器进行交叉检查。

## 实践

`code/main.py`：

- 一个玩具级版面感知分词器：给定 (文本, 边界框) 对，产生 LayoutLMv3 风格的输入。
- 一个 Donut 风格的任务 Schema 生成器：用于表单的 JSON 模板。
- 比较每页在 OCR 流水线、Donut、Nougat 和 VLM 原生下的 Token 预算。

## 成果输出

本课产出 `outputs/skill-document-ai-stack-picker.md`。给定一个文档 AI 项目（领域、规模、质量、监管要求），在 OCR 流水线、无 OCR 专家模型和 VLM 原生之间做出选择。

## 练习

1. 你的项目是每天 1000 万张发票。哪种方案在保持准确率的同时最小化每页成本？

2. 为什么 LayoutLMv3 在表单 QA 上优于纯 CLIP-VLM，但在场景文本上表现较差？边界框流舍弃了什么？

3. Nougat 生成 LaTeX。提出一个 VLM 原生输出在 LaTeX 保真度上优于 Nougat 的测试用例，以及一个 Nougat 胜出的用例。

4. 阅读 PaliGemma 2 论文（Google，2024）。相比 PaliGemma 1，提升文档准确率的关键训练数据新增是什么？

5. 设计一个监管安全的混合方案：OCR 流水线作为主要方案，VLM 作为辅助交叉检查。如何解决分歧？

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| OCR 流水线 | "Tesseract 风格" | 分阶段栈：检测 -> OCR -> 版面分析 -> 规则；确定性，但脆弱 |
| 无 OCR | "Donut 风格" | 跳过显式 OCR 的图像到输出 Transformer；单一模型 |
| 版面感知 | "LayoutLM" | 输入包含每个 Token 的边界框坐标；跨模态统一掩码 |
| VLM 原生 | "前沿 VLM" | 将页面图像以高分辨率直接输入 Claude/GPT/Qwen VLM；无需流水线 |
| DocVQA | "文档基准测试" | 文档 VQA 标准；引用最多的分数 |
| 标记输出 | "LaTeX / MD" | 结构化输出格式，而非自由形式文本；支持下游自动化 |

## 延伸阅读

- [Li et al. — TrOCR (arXiv:2109.10282)](https://arxiv.org/abs/2109.10282)
- [Blecher et al. — Nougat (arXiv:2308.13418)](https://arxiv.org/abs/2308.13418)
- [Huang et al. — LayoutLMv3 (arXiv:2204.08387)](https://arxiv.org/abs/2204.08387)
- [Kim et al. — Donut (arXiv:2111.15664)](https://arxiv.org/abs/2111.15664)
- [Wang et al. — DocLLM (arXiv:2401.00908)](https://arxiv.org/abs/2401.00908)