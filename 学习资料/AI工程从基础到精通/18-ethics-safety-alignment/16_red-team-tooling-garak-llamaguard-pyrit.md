# 红队工具 — Garak、Llama Guard、PyRIT

> 三种生产工具构成了 2026 年红队技术栈。Llama Guard（Meta）——在 14 个 MLCommons 危害类别上微调的 Llama-3.1-8B 分类器；2025 年 Llama Guard 4 是从 Llama 4 Scout 剪枝的 12B 原生多模态分类器。Garak（NVIDIA）——开源 LLM 漏洞扫描器，带有针对幻觉、数据泄露、提示词注入、毒性和越狱的静态、动态和自适应探针。PyRIT（Microsoft）——多轮红队活动，带有 Crescendo、TAP 和自定义转换链用于深度利用。Llama Guard 3 文档记录在 Meta 的"Llama 3 Herd of Models"（arXiv:2407.21783）中；Llama Guard 3-1B-INT4 在 arXiv:2411.17713 中；Garak 的探针架构在 github.com/NVIDIA/garak。这些工具是红队研究（第 12-15 课）与部署（第 17+ 课）之间的 2026 年生产接口。

**类型：** 构建
**语言：** Python（标准库，工具架构模拟器和 Llama Guard 风格分类器模拟）
**前置知识：** 第 18 阶段 · 12-15（越狱和 IPI）
**时间：** 约 75 分钟

## 学习目标

- 描述 Llama Guard 3/4 在安全栈中的位置：输入分类器、输出分类器，或两者兼有。
- 说出 14 个 MLCommons 危害类别并陈述一个非显而易见的一个（Code Interpreter Abuse）。
- 描述 Garak 的探针架构：探针、检测器、工具链。
- 描述 PyRIT 的多轮活动结构以及它如何与 Garak 探针组合。

## 问题

第 12-15 课呈现了攻击面。生产部署需要可重复、可扩展的评估。三种工具主导 2026 年：Llama Guard（防御分类器）、Garak（扫描器）、PyRIT（活动编排器）。每种针对红队生命周期的不同层次。

## 概念

### Llama Guard（Meta）

Llama Guard 3 是在 MLCommons AILuminate 14 个类别上微调用于输入/输出分类的 Llama-3.1-8B 模型：
- 暴力犯罪、非暴力犯罪、性相关、CSAM、诽谤
- 专业建议、隐私、知识产权、无差别武器、仇恨
- 自杀/自残、色情内容、选举、代码解释器滥用

支持 8 种语言。用法：放置在 LLM 前（输入审核）、LLM 后（输出审核），或两者兼有。两种用法产生不同的训练分布——Llama Guard 3 作为处理两者的单一模型发货。

Llama Guard 3-1B-INT4（arXiv:2411.17713, 440MB, 移动 CPU 上约 30 tokens/s）是量化边缘变体。

Llama Guard 4（2025 年 4 月）是 12B，原生多模态，从 Llama 4 Scout 剪枝。它用一个摄入文本 + 图像的分类器替换了 8B 文本和 11B 视觉前代。

### Garak（NVIDIA）

开源漏洞扫描器。架构：
- **探针（Probes）。** 攻击生成器，用于幻觉、数据泄露、提示词注入、毒性、越狱。静态（固定提示词）、动态（生成提示词）、自适应（响应目标输出）。
- **检测器（Detectors）。** 根据预期失败模式——毒性、泄露、已越狱——对输出打分。
- **工具链（Harnesses）。** 管理探针-检测器对，运行活动，生成报告。

TrustyAI 将 Garak 与 Llama-Stack 盾牌（Prompt-Guard-86M 输入分类器、Llama-Guard-3-8B 输出分类器）集成，用于端到端的受保护目标评估。基于层级的评分（Tier-Based Scoring, TBSA）替换了二元通过/失败——模型可以在严重性层级 3 上通过，在同一探针的严重性层级 5 上失败。

### PyRIT（Microsoft）

Python 风险识别工具包。多轮红队活动。围绕以下构建：
- **转换器（Converters）。** 转换种子提示词——释义、编码、翻译、角色扮演。
- **编排器（Orchestrators）。** 运行活动：Crescendo（升级）、TAP（分支）、RedTeaming（自定义循环）。
- **打分（Scoring）。** LLM 作为裁判或分类器作为裁判。

PyRIT 是 Garak 的更重量级表亲。Garak 运行数千次单轮探针；PyRIT 运行旨在攻破特定失败模式的深度多轮活动。

### 技术栈

将 Llama Guard 放在模型两侧。每晚运行 Garak 进行回归测试。在发布前运行 PyRIT 进行活动。这是大多数生产部署的 2026 年默认配置。

### 评估陷阱

- **裁判身份。** 三种工具都可以使用 LLM 裁判；裁判校准驱动报告中的 ASR（第 12 课）。与工具一起指定裁判。
- **探针陈旧性。** Garak 探针随模型针对它们打补丁而过时。自适应探针（PAIR 形状）比静态探针老化更慢。
- **Llama Guard 对良性内容的误报率。** 早期 Llama Guard 版本过度标记政治和 LGBTQ+ 内容；Llama Guard 3/4 校准有所改进但未按部署校准。

### 这在第 18 阶段中的位置

第 12-15 课是攻击族。第 16 课是生产工具。第 17 课（WMDP）是双重用途能力评估。第 18 课是将这些工具包裹在政策结构中的前沿安全框架。

## 使用它

`code/main.py` 构建一个玩具 Llama Guard 风格分类器（14 个类别上的关键词 + 语义特征），一个玩具 Garak 工具链（探针-检测器循环），以及一个 PyRIT 风格多轮转换器链。你可以针对模拟目标运行三种工具并观察不同的覆盖特征。

## 交付它

本课生成 `outputs/skill-red-team-stack.md`。给定部署描述，它命名三种工具中哪些是合适的，每个工具中配置什么，以及运行什么回归频率。

## 练习

1. 运行 `code/main.py`。比较 Llama Guard 风格分类器在单轮 vs 多轮攻击上的检测率。

2. 实现一个新的 Garak 探针：base64 编码的有害请求。测量其被 Llama Guard 风格分类器检测的情况。

3. 用"翻译为法语，然后释义"转换器扩展 PyRIT 风格转换器链。重新测量攻击成功。

4. 阅读 Llama Guard 3 的危害类别列表。识别两个训练数据可能在真实合法开发者内容上产生高误报率的类别。

5. 比较 Garak 和 PyRIT 的设计原则。论证一个每种工具都是正确选择工具的部署场景。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|------------------------|
| Llama Guard | "分类器" | 具有 14 个危害类别的微调 Llama-3.1-8B/4-12B 安全分类器 |
| Garak | "扫描器" | NVIDIA 开源漏洞扫描器；探针、检测器、工具链 |
| PyRIT | "活动工具" | Microsoft 多轮红队编排器；转换器、编排器、打分 |
| Prompt-Guard | "小分类器" | Meta 的 86M 提示词注入分类器，与 Llama Guard 配对 |
| TBSA | "基于层级的评分" | Garak 的基于层级的通过/失败，替换二元结果 |
| Converter chain | "释义 + 编码 + ……" | PyRIT 构图原语，用于构建多步攻击 |
| MLCommons hazard categories | "14 个分类法" | Llama Guard 所针对的行业标准分类法 |

## 延伸阅读

- [Meta — Llama Guard 3 (in Llama 3 Herd paper, arXiv:2407.21783)](https://arxiv.org/abs/2407.21783) — 8B 分类器
- [Meta — Llama Guard 3-1B-INT4 (arXiv:2411.17713)](https://arxiv.org/abs/2411.17713) — 量化移动分类器
- [NVIDIA Garak — GitHub](https://github.com/NVIDIA/garak) — 扫描器仓库和文档
- [Microsoft PyRIT — GitHub](https://github.com/Azure/PyRIT) — 活动工具包