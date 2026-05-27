# 水印技术 —— SynthID、Stable Signature、C2PA

> 三项技术构建了 2026 年 AI 生成内容溯源体系。SynthID（Google DeepMind）—— 图像水印于 2023 年 8 月推出，文本+视频水印于 2024 年 5 月推出（Gemini + Veo），文本水印于 2024 年 10 月通过 Responsible GenAI Toolkit 开源，统一多模态检测器于 2025 年 11 月随 Gemini 3 Pro 推出。文本水印以不可察觉的方式调整下一个 token 的采样概率；图像/视频水印可抵抗压缩、裁剪、滤镜和帧率变化。Stable Signature（Fernandez et al., ICCV 2023, arXiv:2303.15435）—— 微调潜在扩散解码器，使每张输出图像包含固定的消息；对裁切至 10% 内容的生成图像，在 FPR<1e-6 时检测率 >90%。后续研究"Stable Signature is Unstable"（arXiv:2405.07145，2024 年 5 月）—— 微调解码器可去除水印同时保持质量。C2PA —— 加密签名、防篡改的元数据标准（C2PA 2.2 Explainer 2025）。水印与 C2PA 是互补的：元数据可被剥离但携带更丰富的溯源信息；水印可在转码后保留但携带的信息较少。

**类型：** 构建
**语言：** Python（标准库，token 水印嵌入 + 检测）
**前置知识：** Phase 10 · 04（采样），Phase 01 · 09（信息论）
**时间：** 约 75 分钟

## 学习目标

- 描述 token 级别的水印（SynthID-text 风格）及其可检测机制。
- 描述 Stable Signature 及 2024 年破解它的去除攻击。
- 陈述 C2PA 的角色及其为何与水印互补。
- 描述关键局限性：模型特定信号、释义鲁棒性及保留语义的攻击（arXiv:2508.20228）。

## 问题

2023-2024 年，深度伪造和 AI 生成内容大规模进入政治和消费场景。水印是拟议的技术溯源信号：在创建时标记生成内容，之后进行检测。2025 年证据：没有水印是绝对鲁棒的，但与 C2PA 元数据分层结合后，该组合提供了一个可用的溯源方案。

## 概念

### 文本水印（SynthID-text 风格）

Kirchenbauer et al. 2023 的机制，由 Google 产品化：

1. 在每个解码步骤，对前 K 个 token 进行哈希，生成词汇表的伪随机分区，分为"绿色"和"红色"两个集合。
2. 通过在绿色 logit 上添加 δ 来偏置采样，使其偏向绿色集合。
3. 生成文本中包含的绿色 token 比纯随机情况下更多。

检测：重新哈希每个前缀，统计生成中的绿色 token 数量，计算 z 分数。水印文本的 z 分数 >0，人类文本的 z 分数 ≈0。

特性：
- 对读者不可察觉（δ 足够小，质量损失轻微）。
- 在可访问词汇分区函数的情况下可检测。
- 对释义不鲁棒 —— 改写文本会破坏信号。

SynthID-text 于 2024 年 10 月通过 Google Responsible GenAI Toolkit 开源。

### Stable Signature（图像）

Fernandez et al. ICCV 2023。微调潜在扩散解码器，使每张生成图像在潜在表示中嵌入固定的二进制消息。通过神经解码器从潜在表示中解码检测。对裁切至 10% 内容的图像，在 FPR<1e-6 时检测率 >90%。

2024 年 5 月"Stable Signature is Unstable"（arXiv:2405.07145）：微调解码器可去除水印同时保持图像质量。对抗性后生成微调成本低廉；水印的对抗鲁棒性有限。

### SynthID 统一检测器（2025 年 11 月）

随 Gemini 3 Pro 推出：一个跨模态检测器，在单一 API 中读取文本、图像、音频和视频中的 SynthID 信号。统一了 Google 的溯源技术栈。

### C2PA

内容溯源与真实性联盟（Coalition for Content Provenance and Authenticity）。加密签名、防篡改的元数据标准。C2PA 2.2 Explainer（2025）。C2PA 清单记录溯源声明（谁创建、何时创建、经过什么转换），由创建者密钥签名。

与水印互补：
- 元数据可被剥离；水印不能（轻易）被剥离。
- 元数据信息丰富（完整溯源链）；水印仅携带若干比特。
- C2PA 依赖平台采用；水印自动嵌入。

Google 在搜索、广告和"关于此图片"中整合两者。

### 局限性

- **模型特定。** SynthID 仅为启用了 SynthID 的模型的生成内容添加水印。未启用 SynthID 的模型生成的输出没有水印，因此"无 SynthID 信号"不能作为真实性的证明。
- **释义。** 文本水印无法在保留语义的释义下存活。
- **转换攻击。** arXiv:2508.20228（2025）展示了破坏文本水印和许多图像水印的保留语义攻击。
- **微调去除。** 根据"Stable Signature is Unstable"，后生成微调可去除嵌入的水印。

### EU AI Act 第 50 条

AI 生成内容标注的透明度行为准则（第一稿 2025 年 12 月，第二稿 2026 年 3 月，最终版预计 2026 年 6 月，参见 [European Commission 状态页面](https://digital-strategy.ec.europa.eu/en/policies/code-practice-ai-generated-content)）。截至 2026 年 4 月，该准则仍为草案，时间表可能发生变化。这是要求技术实施的监管层。深度伪造必须标注。

### 在 Phase 18 中的定位

第 22-23 课关于模型输出的内容（隐私数据、溯源信号）。第 27 课涵盖训练数据治理。第 24 课是要求这些技术措施的监管框架。

## 实践

`code/main.py` 构建一个玩具文本水印。Token 是整数 0..N-1；水印采样偏向哈希定义的绿色集合。检测器计算绿色 token 的 z 分数。你可以观察 1000 token 生成文本的检测效果、观察释义如何破坏信号，并度量人类文本的假正例率。

## 产出

本课产出 `outputs/skill-provenance-audit.md`。给定一个带有溯源声明的内容部署，审计：水印机制（如有）、C2PA 签名链（如有）、各机制的对抗鲁棒性，以及按模态的覆盖范围。

## 练习

1. 运行 `code/main.py`。报告 1000 token 水印生成文本 vs 人类创作文本的 z 分数。在 95% 置信阈值下识别假正例率。

2. 实现一个释义攻击，将 30% 的 token 替换为同义词。重新度量 z 分数。

3. 阅读 Kirchenbauer et al. 2023 第 6 节关于鲁棒性的内容。为何文本水印在释义下失效而图像水印在裁剪下幸存？

4. 设计一个使用 SynthID-text + C2PA 元数据的部署。描述消费者看到的溯源链。识别每个组件的一个失效模式。

5. 2024 年"Stable Signature is Unstable"结果显示微调可去除图像水印。设计一种限制此攻击的部署控制 —— 例如，要求微调检查点的签名发布。

## 关键术语

| 术语 | 人们常说的 | 实际含义 |
|------|-----------|---------|
| SynthID | "Google 的水印" | 跨模态溯源信号；文本、图像、音频、视频 |
| Token 水印（Token Watermark） | "Kirchenbauer 风格" | 通过绿色 token z 分数可检测的有偏采样文本水印 |
| Stable Signature | "图像水印" | 微调解码器水印；ICCV 2023 |
| C2PA | "元数据标准" | 加密签名、防篡改的溯源元数据 |
| 释义鲁棒性（Paraphrase Robustness） | "改写是否破坏它" | 文本水印属性；目前有限 |
| 微调去除（Fine-tune Removal） | "对抗性去水印" | 通过解码器微调去除图像水印的攻击 |
| 跨模态检测器（Cross-modal Detector） | "统一 SynthID" | 2025 年 11 月跨模态统一 API |

## 扩展阅读

- [Kirchenbauer et al. — A Watermark for Large Language Models (ICML 2023, arXiv:2301.10226)](https://arxiv.org/abs/2301.10226) —— token 水印机制
- [Fernandez et al. — Stable Signature (ICCV 2023, arXiv:2303.15435)](https://arxiv.org/abs/2303.15435) —— 图像水印论文
- ["Stable Signature is Unstable" (arXiv:2405.07145)](https://arxiv.org/abs/2405.07145) —— 去除攻击
- [Google DeepMind — SynthID](https://deepmind.google/models/synthid/) —— 跨模态水印
- [C2PA 2.2 Explainer (2025)](https://c2pa.org/specifications/specifications/2.2/explainer/Explainer.html) —— 元数据标准