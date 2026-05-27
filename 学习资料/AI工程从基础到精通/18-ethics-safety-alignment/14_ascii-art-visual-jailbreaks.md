# ASCII Art 与视觉越狱

> Jiang, Xu, Niu, Xiang, Ramasubramanian, Li, Poovendran，"ArtPrompt: ASCII Art-based Jailbreak Attacks against Aligned LLMs"（ACL 2024, arXiv:2402.11753）。将有害请求中与安全相关的 token 遮罩，用相同字母的 ASCII-art 渲染替换它们，发送伪装提示词。GPT-3.5、GPT-4、Gemini、Claude、Llama-2 都不能鲁棒地识别 ASCII-art token。该攻击绕过了 PPL（困惑度过滤器）、释义防御和重新分词化。相关：ViTC 基准测量非语义视觉提示词的识别；StructuralSleight 泛化到非常见文本编码结构（树、图、嵌套 JSON）作为编码攻击的一个家族。

**类型：** 构建
**语言：** Python（标准库，ArtPrompt token 遮罩工具链）
**前置知识：** 第 18 阶段 · 12（PAIR），第 18 阶段 · 13（MSJ）
**时间：** 约 60 分钟

## 学习目标

- 描述 ArtPrompt 攻击：词汇识别步骤、ASCII-art 替换、最终伪装提示词。
- 解释为什么标准防御（PPL、释义、重新分词化）对 ArtPrompt 失败。
- 定义 ViTC 并描述它测量什么。
- 描述 StructuralSleight 作为对任意非常见文本编码结构的泛化。

## 问题

通过释义和角色扮演的攻击（第 12 课）以及通过长上下文的攻击（第 13 课）在文本级模式上运作。ArtPrompt 在识别层上运作：模型不解析被禁 token。它解析字符渲染的图像。安全过滤器看到无害标点符号。模型看到一个单词。

## 概念

### ArtPrompt，两步

步骤 1。词汇识别。给定有害请求，攻击者使用 LLM 识别与安全相关的词汇（例如，"how to make a bomb"中的"bomb"）。

步骤 2。伪装提示词生成。用其 ASCII-art 渲染替换每个识别出的词汇（形成字母形状的 7x5 或 7x7 字符块）。模型接收一个标点符号和空格的网格，一个足够强大的模型可以识别为单词；安全过滤器只看到网格。

结果：GPT-4、Gemini、Claude、Llama-2、GPT-3.5 全部失败。在其基准子集上攻击成功率超过 75%。

### 为什么标准防御失败

- **PPL（困惑度过滤器）。** ASCII art 具有高困惑度——但所有新输入都是如此。阻止 ArtPrompt 的阈值选择也会阻止合法的结构化输入。
- **释义。** 释义提示词会破坏 ASCII art。在实践中，释义 LLM 通常保留或重建该 art。
- **重新分词化。** 不同地拆分 token 不会改变模型的视觉识别能力正在识别字母形状的事实。

根本问题是安全过滤器是 token 级或语义级的；ArtPrompt 在视觉识别层上运作。

### ViTC 基准

非语义视觉提示词的识别。测量模型阅读 ASCII-art、wingdings 和其他非文本语义视觉内容的能力。ArtPrompt 的有效性与 ViTC 准确率相关：模型阅读视觉文本越好，ArtPrompt 对其效果越好。这是一种能力-安全权衡。

### StructuralSleight

泛化 ArtPrompt：非常见文本编码结构（Uncommon Text-Encoded Structures, UTES）。树、图、嵌套 JSON、CSV-in-JSON、diff 风格代码块。如果一个结构在训练安全数据中罕见但可被模型解析，它就可以隐藏有害内容。

防御含义：安全必须泛化到模型可以解析的所有结构化表示。该集合庞大且不断增长。

### 图像模态类比

视觉 LLM（GPT-5.2、Gemini 3 Pro、Claude Opus 4.5、Grok 4.1）扩展了攻击面。使用实际图像的 ArtPrompt 风格攻击比 ASCII-art 类比更强，因为图像编码器产生更丰富的信号。

### 这在第 18 阶段中的位置

第 12-14 课描述了三个正交攻击向量：迭代精炼（PAIR）、上下文长度（MSJ）和编码（ArtPrompt/StructuralSleight）。第 15 课从以模型为中心的攻击转向系统边界攻击（间接提示词注入）。第 16 课描述了防御工具响应。

## 使用它

`code/main.py` 构建一个玩具 ArtPrompt。你可以用 ASCII-art 字形遮盖有害查询中的特定词汇，验证伪装字符串是否通过关键词过滤器，并（可选）使用简单识别器解码伪装字符串。

## 交付它

本课生成 `outputs/skill-encoding-audit.md`。给定越狱防御报告，它枚举覆盖的编码攻击族（ASCII art、base64、leet-speak、UTF-8 同形字、UTES）以及捕获每种攻击的防御层。

## 练习

1. 运行 `code/main.py`。验证伪装字符串是否通过简单关键词过滤器。报告所需的字符级改变。

2. 实现第二种编码：对相同目标词汇使用 base64。比较 ArtPrompt 的过滤绕过率和恢复难度。

3. 阅读 Jiang et al. 2024 第 4.3 节（五模型结果）。提出一个原因解释为什么 Claude 的 ArtPrompt 抵抗力在同一基准上高于 Gemini。

4. 设计一个生成前防御，检测提示词中的 ASCII-art 形状区域。测量对合法代码、表格和数学符号的误报率。

5. StructuralSleight 列出了 10 种编码结构。勾勒处理全部 10 种的广义防御，并估计每个防守提示词的计算代价。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|------------------------|
| ArtPrompt | "ASCII-art 攻击" | 用 ASCII-art 渲染遮盖安全词汇的两步越狱 |
| Cloaking | "隐藏词汇" | 用模型可读但过滤器不可读的视觉表示替换禁用的 token |
| UTES | "非常见结构" | 非常见文本编码结构——树、图、嵌套 JSON 等用于走私内容 |
| ViTC | "视觉文本能力" | 模型阅读非语义视觉编码能力的基准 |
| Perplexity filter | "PPL 防御" | 拒绝高困惑度提示词；失败因为合法结构化输入也得分高 |
| Retokenization | "分词器偏移防御" | 用不同分词器预处理提示词；失败因为识别是视觉的 |
| Homoglyph | "形似字符" | 与拉丁字母看起来相同的 Unicode 字符；绕过子字符串检查 |

## 延伸阅读

- [Jiang et al. — ArtPrompt (ACL 2024, arXiv:2402.11753)](https://arxiv.org/abs/2402.11753) — ASCII-art 越狱论文
- [Li et al. — StructuralSleight (arXiv:2406.08754)](https://arxiv.org/abs/2406.08754) — UTES 泛化
- [Chao et al. — PAIR (Lesson 12, arXiv:2310.08419)](https://arxiv.org/abs/2310.08419) — 互补迭代攻击
- [Anil et al. — Many-shot Jailbreaking (Lesson 13)](https://www.anthropic.com/research/many-shot-jailbreaking) — 互补长度攻击