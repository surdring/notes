# 开源 VLM 方案：真正重要的是什么

> 2024-2026 年的开源 VLM 文献是一片消融表格的森林。Apple 的 MM1 测试了图像编码器、连接器和数据混合的 13 种组合。Allen AI 的 Molmo 证明了详细的人工描述优于 GPT-4V 蒸馏。Cambrian-1 运行了 20+ 编码器比较。Idefics2 正式化了五轴设计空间。Prismatic VLMs 在受控基准上比较了 27 种训练方案。在所有噪声中，一小部分结果跨论文成立：图像编码器比连接器架构更重要，数据混合比两者都更重要，详细的人工描述优于蒸馏合成数据。本课阅读这些表格，让你不必亲自阅读。

**类型：** 学习 + 实验
**语言：** Python（标准库，消融表解析器 + 方案选择器）
**前置条件：** Phase 12 · 05（LLaVA 基线）
**时间：** 约 180 分钟

## 学习目标

- 指出五轴 VLM 设计空间：图像编码器、连接器、LLM、数据混合、分辨率调度。
- 阅读 MM1 / Idefics2 / Cambrian-1 消融表，预测哪个旋钮会推动给定基准。
- 在给定算力预算和任务混合的情况下，为新 VLM 选择方案（编码器、连接器、数据、分辨率）。
- 解释为什么详细的人工描述在相同 token 数下优于 GPT-4V 蒸馏。

## 问题所在

存在数百个开源 VLM。「好」和「最先进」之间的大部分差距不是架构。是数据、分辨率调度和编码器选择。知道当模型表现不佳时先转哪个旋钮，可以避免 500 万 GPU 小时的错误。

2023 年浪潮（LLaVA-1.5、InstructBLIP、MiniGPT-4）运行在描述对预训练 + LLaVA-Instruct-150k 上。好的基线。MMMU 上限约 35%。

2024 年浪潮（MM1、Idefics2、Molmo、Cambrian-1、Prismatic VLMs）运行了详尽的消融实验。结果令人惊讶且实用。

## 核心概念

### 五轴设计空间

Idefics2（Laurençon 等人，2024）命名了这些轴：

1. 图像编码器。CLIP ViT-L/14、SigLIP SO400m/14、DINOv2 ViT-g/14、InternViT-6B。编码器在块大小、分辨率和预训练目标上有所不同。
2. 连接器。MLP（2-4 层）、Q-Former（32 个查询 + 交叉注意力）、Perceiver 重采样器（64 个查询）、C-Abstractor（卷积 + 双线性池化）。
3. 语言模型。Llama-3 8B / 70B、Mistral 7B、Phi-3、Gemma-2、Qwen2.5。LLM 大小是主要的参数成本。
4. 训练数据。描述对（CC3M、LAION）、交错（OBELICS、MMC4）、指令（LLaVA-Instruct、ShareGPT4V、PixMo、Cauldron）。
5. 分辨率调度。固定 224/336/448、AnyRes、原生动态。训练期间逐步提升或恒定。

每个生产 VLM 在每个轴上都做出选择。MMMU 分数的大部分方差由轴 1、4 和 5 解释——不是你选择了哪个连接器。

### 轴 1：编码器 > 连接器

MM1 第 3.2 节显示：从 CLIP ViT-L/14 换成 SigLIP SO400m/14 增加了 3+ 个 MMMU 点。将连接器从 MLP 换成 Perceiver 重采样器增加不到 1 个点。Idefics2 复现：SigLIP > CLIP，Q-Former ≈ MLP ≈ Perceiver，在相同 token 数下。

Cambrian-1 的「Cambrian Vision Encoders Match-Up」（Tong 等人，2024）在视觉中心基准（CV-Bench）上运行了 20+ 个编码器。排行榜顶部是 DINOv2 和 SigLIP 的混合；CLIP 位于中游；ImageBind 和 ViT-MAE 较低。CLIP ViT-L 到 DINOv2 ViT-g/14 的差距在 CV-Bench 上约为 5-7 个点。

2026 年开源 VLM 的默认编码器是 SigLIP 2 SO400m/14 用于语义+密集特征，有时与 DINOv2 ViT-g/14 特征拼接（Cambrian 的「Spatial Vision Aggregator」就是这样做的）。

### 轴 2：连接器设计是平局

MM1、Idefics2、Prismatic 和 MM-Interleaved 都达到了相同的结论：在固定的视觉 token 数量下，连接器架构几乎不重要。在平均池化块上的两层 MLP 在相同 token 预算下与 32 查询 Q-Former 的性能相差 1 个点以内。

真正重要的是 token 数量。更多的视觉 token = 更多的 LLM 计算 = 更好的性能，达到某一点后收益递减。每张图像 64 个 token 对 OCR 来说太少了。576-1024 个 token 是大多数开源 VLM 的最佳点。2048+ 仅对文档和图表有帮助。

Q-Former vs MLP 是成本问题，不是质量问题：Q-Former 无论图像分辨率如何都将 token 上限设在 32-64；MLP 发出所有 patch token。对于高分辨率输入，Q-Former 节省 LLM 上下文；对于低分辨率，差异是噪声。

### 轴 3：LLM 大小设定了上限

在每篇 VLM 论文中，将 LLM 从 7B 翻倍到 13B 可靠地增加 2-4 个 MMMU 点。在 70B 时你饱和了大多数基准。VLM 的多模态推理上限是 LLM 的文本推理上限——视觉编码器只能喂给它，不能替它推理。

这就是为什么 Qwen2.5-VL-72B 和 Claude Opus 4.7 在 MMMU-Pro 和 ScreenSpot-Pro 上碾压：语言大脑是巨大的。7B VLM 不能通过巧妙的连接器设计替代 70B VLM。

### 轴 4：数据——详细的人工描述优于蒸馏

Molmo + PixMo（Deitke 等人，2024）是 2024 年每个人都应该读的结果。Allen AI 让人类标注者在 1-3 分钟的密集语音转文字过程中描述图像，产生了 71.2 万张密集描述图像。训练数据中完全没有 GPT-4V 蒸馏。

Molmo-72B 在 11/11 基准上击败了 Llama-3.2-90B-Vision。差异不在于架构——而在于描述质量。详细的人工描述每张图像包含的信息量是简短网页描述的 5-10 倍，并且在 GPT-4V 蒸馏会产生幻觉的地方保持事实基础。

ShareGPT4V（Chen 等人，2023）和 Cauldron（Idefics2）遵循了相同的策略，混合人工 + GPT-4V 描述。趋势清晰：对于 2026 年的前沿，描述密度 > 描述数量 > 蒸馏便利性。

### 轴 5：分辨率及其调度

Idefics2 的消融：384 -> 448 增加 1-2 个点。448 -> 980 带图像分割（AnyRes）在 OCR 基准上增加 3-5 个点。平坦分辨率训练在中准确率处饱和；分辨率提升（从 224 开始，以 448 或原生结束）训练更快且最终更高。

Cambrian-1 运行了分辨率 vs token 的权衡：在固定算力下，你可以用更低分辨率获得更多 token，或者用更高分辨率获得更少 token。更高分辨率在 OCR 上胜出；更低分辨率更多 token 在一般场景理解上胜出。

2026 年生产方案：阶段 1 在 384 固定分辨率下训练，阶段 2 在 OCR 重度任务中动态分辨率最高到 1280。

### Prismatic 受控对比

Prismatic VLMs（Karamcheti 等人，2024）是控制所有轴的论文。相同的 13B LLM，相同的指令数据，相同的评估——只有一轴在一次实验中变化。结果：

- 每张图像的视觉 token 数量解释了约 60% 的方差。
- 编码器选择解释了约 20%。
- 连接器架构解释了约 5%。
- 其他所有（数据混合、调度器、LR）剩余约 15%。

这是一个粗略的分解，但它是文献中对于「我应该先消融什么」最干净的答案。

### 2026 年选择器

鉴于证据，2026 年新项目的默认开源 VLM 方案：

- 编码器：SigLIP 2 SO400m/14 以 NaFlex 的原生分辨率运行，如果需要分割/定位，拼接 DINOv2 ViT-g/14 用于密集特征。
- 连接器：在 patch token 上的两层 MLP。除非你受 token 约束，否则跳过 Q-Former。
- LLM：Qwen2.5 / Llama-3.1 / Gemma 2，7B 用于成本，70B 用于质量，根据目标延迟选择。
- 数据：PixMo + ShareGPT4V + Cauldron，补充特定任务的指令数据。
- 分辨率：动态（长边最小 256，最大 1280 像素）。
- 调度：阶段 1 对齐（仅投影器），阶段 2 全量微调，阶段 3 特定任务微调。

这些默认值中的每一个都可以追溯到本课末尾引用的论文中经过测量的消融实验。

## 使用指南

`code/main.py` 是一个消融表解析器和方案选择器。它编码了 MM1 和 Idefics2 消融表（浓缩），并让你查询：

- 「给定预算 X 和任务 Y，哪个方案胜出？」
- 「如果我在 7B Llama 上将 SigLIP 换成 CLIP，期望的 MMMU 差值是多少？」
- 「80% 置信度答案下我应该先消融哪个轴？」

输出是一个带有期望基准差值和「先消融」推荐的排名方案列表。

## 交付物

本课产出 `outputs/skill-vlm-recipe-picker.md`。给定目标任务混合、算力预算和延迟目标，它发出完整方案（编码器、连接器、LLM、数据混合、分辨率调度），并引用证明每个选择的消融实验。阻止工程师在每次新 VLM 项目启动时重新发明 Idefics2 消融表。

## 练习

1. 阅读 MM1 第 3.2 节。对于固定的 2B LLM，预算 5000 万张图像，哪个编码器胜出？在 13B LLM 下答案会反转吗？为什么？

2. Cambrian-1 发现拼接 DINOv2 + SigLIP 在视觉中心基准上优于单独使用任何一个，但在 MMMU 上没有增益。预测哪些基准会增益，哪些保持平坦。

3. 你的目标是在 2B LLM 上做一个移动 UI 代理。选择编码器、连接器、分辨率和数据混合。用具体的消融表为每个选择提供理由。

4. Molmo 发布了 4B 和 72B 模型。4B 与闭源 7B VLM 竞争；72B 在 11/11 基准上击败 Llama-3.2-90B-Vision。这告诉我们什么关于 LLM 大小平台期假说？

5. 设计一个消融表，在 7B VLM 上将数据混合质量与编码器质量隔离。至少需要多少次训练运行？提出四种轴设置。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|------------------------|
| 消融（Ablation） | 「转动一个旋钮」 | 训练多次运行，恰好在一个设计空间轴上不同，保持其他所有不变 |
| 连接器（Connector） | 「桥」/「投影器」 | 将视觉编码器输出映射到 LLM token 空间的可训练模块（MLP、Q-Former、Perceiver） |
| 详细人工描述 | 「密集描述」 | 多条句子的人类书写描述（通常 80-300 个 token），比网页 alt 文本更丰富 |
| 蒸馏（Distillation） | 「GPT-4V 描述」 | 由更强的专有 VLM 生成的训练数据；方便但容易继承幻觉 |
| AnyRes / 动态分辨率 | 「高分辨率路径」 | 通过平铺或 M-RoPE 将大于编码器原生分辨率的图像送入的策略 |
| 分辨率提升（Resolution ramp） | 「课程」 | 从低分辨率开始并逐步增加的训练调度，加速对齐学习 |
| 视觉中心基准 | 「CV-Bench / BLINK」 | 强调细粒度视觉感知而非语言密集推理的评估 |
| PixMo | 「Molmo 的数据」 | Allen AI 的 71.2 万张密集描述图像数据集；人类语音转录为密集描述 |

## 进一步阅读

- [McKinzie et al. — MM1 (arXiv:2403.09611)](https://arxiv.org/abs/2403.09611)
- [Laurençon et al. — Idefics2 / What matters building VLMs (arXiv:2405.02246)](https://arxiv.org/abs/2405.02246)
- [Deitke et al. — Molmo and PixMo (arXiv:2409.17146)](https://arxiv.org/abs/2409.17146)
- [Tong et al. — Cambrian-1 (arXiv:2406.16860)](https://arxiv.org/abs/2406.16860)
- [Karamcheti et al. — Prismatic VLMs (arXiv:2402.07865)](https://arxiv.org/abs/2402.07865)