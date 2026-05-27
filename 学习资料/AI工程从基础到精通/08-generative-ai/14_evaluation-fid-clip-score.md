# 评估——FID、CLIP 分数、人类偏好

> 每个生成模型排行榜都引用 FID、CLIP 分数和来自人类偏好竞技场的胜率。每个数字都有一个有决心的研究者可以钻空子的失败模式。如果你不了解失败模式，就无法区分真正的改进和钻空子。

**类型：** 构建
**语言：** Python
**前置要求：** 第 8 阶段 · 01（分类法），第 2 阶段 · 04（评估指标）
**时间：** 约 45 分钟

## 问题

生成模型通过*样本质量*和*条件遵循度*来评判。两者都没有闭式度量。你的模型必须渲染 10,000 张图像；某物必须给它们分配数字；你必须跨模型家族、跨分辨率、跨架构信任这些数字。三个指标经受了 2014-2026 年的考验：

- **FID（Fréchet Inception Distance）。** 在 Inception 网络的特征空间中，真实与生成两个分布之间的距离。越低越好。
- **CLIP 分数。** 生成图像的 CLIP-图像嵌入与提示的 CLIP-文本嵌入之间的余弦相似度。越高越好。衡量提示遵循度。
- **人类偏好。** 在相同提示上将两个模型正面交锋，让人类（或 GPT-4 类模型）选择更好的一个，汇总为 Elo 分数。

你还会看到：IS（inception score，基本已退役）、KID、CMMD、ImageReward、PickScore、HPSv2、MJHQ-30k。每个都纠正了前一个的一个失败。

## 概念

![FID、CLIP 和偏好：三个轴，不同的失败模式](../assets/evaluation.svg)

### FID——样本质量

Heusel et al. (2017)。步骤：

1. 为 N 张真实图像和 N 张生成图像提取 Inception-v3 特征（2048-D）。
2. 对每个池拟合高斯：计算均值 `μ_r, μ_g` 和协方差 `Σ_r, Σ_g`。
3. FID = `||μ_r - μ_g||² + Tr(Σ_r + Σ_g - 2 · (Σ_r · Σ_g)^0.5)`。

解释：特征空间中两个多元高斯之间的 Fréchet 距离。越低 = 分布越相似。

失败模式：
- **小 N 有偏。** FID 是特征分布上的均方——小 N 低估协方差，给出虚假的低 FID。始终使用 N ≥ 10,000。
- **依赖 Inception。** Inception-v3 在 ImageNet 上训练。远离 ImageNet 的领域（人脸、艺术、文本图像）产生无意义的 FID。使用领域特定的特征提取器。
- **钻空子。** 过拟合 Inception 先验可以在没有视觉质量改进的情况下得到低 FID。用 CMMD（见下）击败它。

### CLIP 分数——提示遵循度

Radford et al. (2021)。对于生成的图像 + 提示：

```
clip_score = cos_sim( CLIP_image(x_gen), CLIP_text(prompt) )
```

在 30k 生成图像上平均 → 模型间可比较的标量。

失败模式：
- **CLIP 自身的盲点。** CLIP 的组合推理很弱（"蓝色球体上的红色立方体"经常失败）。模型可以在 CLIP 分数上排名高而不真正遵循复杂提示。
- **短提示偏差。** 短提示在野外有更多 CLIP-图像匹配。较长提示机械地有较低 CLIP 分数。
- **提示钻空子。** 在提示中包含"高质量、4k、杰作"会膨胀 CLIP 分数而不改善图像-文本绑定。

CMMD（Jayasumana et al., 2024）修复其中一些：使用 CLIP 特征而不是 Inception，最大均值差异代替 Fréchet。更好地检测细微质量差异。

### 人类偏好——真实标准

选择一组提示。用模型 A 和模型 B 生成。向人类（或强 LLM 裁判）展示配对。将胜利汇总为 Elo 或 Bradley-Terry 分数。基准：

- **PartiPrompts（Google）**：1600 个多样化提示，12 个类别。
- **HPSv2**：107k 人类标注，广泛用作自动代理。
- **ImageReward**：137k 提示-图像偏好对，MIT 许可。
- **PickScore**：在 Pick-a-Pic 260 万偏好上训练。
- **Chatbot-Arena 风格图像竞技场**：https://imagearena.ai/ 等。

失败模式：
- **裁判方差。** 非专家与专家有不同的偏好。两者都使用。
- **提示分布。** 精选提示有利于某个家族。始终记录。
- **LLM 裁判奖励攻击。** GPT-4 裁判会被漂亮但错误的输出愚弄。与人类三角验证。

## 一起使用

生产评估报告应包括：

1. 在 10-30k 样本上的 FID，对照保留的真实分布（样本质量）。
2. 在相同样本上的 CLIP 分数 / CMMD 对照其提示（遵循度）。
3. 在盲测竞技场中对比前模型的胜率（总体偏好）。
4. 失败模式分析：50 个随机采样输出，标记已知问题（手部解剖、文本渲染、一致物体数量）。

任何单一指标都是谎言。三个相互印证的指标 + 定性审查才构成声明。

## 构建

`code/main.py` 在合成"特征向量"（我们使用 4-D 向量作为 Inception 特征的替身）上实现 FID、类 CLIP 分数和 Elo 聚合。你看到：

- 小 N 和大 N 上的 FID 计算——偏差。
- "CLIP 分数"作为特征池之间的余弦相似度。
- 来自合成偏好流的 Elo 更新规则。

### 步骤 1：四行 FID

```python
def fid(real_features, gen_features):
    mu_r, cov_r = mean_and_cov(real_features)
    mu_g, cov_g = mean_and_cov(gen_features)
    mean_diff = sum((a - b) ** 2 for a, b in zip(mu_r, mu_g))
    trace_term = trace(cov_r) + trace(cov_g) - 2 * sqrt_cov_product(cov_r, cov_g)
    return mean_diff + trace_term
```

### 步骤 2：CLIP 风格余弦相似度

```python
def clip_like(image_feat, text_feat):
    dot = sum(a * b for a, b in zip(image_feat, text_feat))
    norm = math.sqrt(dot_self(image_feat) * dot_self(text_feat))
    return dot / max(norm, 1e-8)
```

### 步骤 3：Elo 聚合

```python
def elo_update(r_a, r_b, winner, k=32):
    expected_a = 1 / (1 + 10 ** ((r_b - r_a) / 400))
    actual_a = 1.0 if winner == "a" else 0.0
    r_a_new = r_a + k * (actual_a - expected_a)
    r_b_new = r_b - k * (actual_a - expected_a)
    return r_a_new, r_b_new
```

## 陷阱

- **N=1000 的 FID。** 启发式在 N 低于 10k 时不可靠。报告低 N FID 的论文在钻空子。
- **跨分辨率比较 FID。** Inception 的 299×299 调整大小改变特征分布。仅在匹配分辨率下比较。
- **报告一个种子。** 最少运行 3 个种子。报告标准差。
- **通过负面提示膨胀 CLIP 分数。** 某些流水线通过过拟合提示来提高 CLIP。检查视觉饱和度。
- **提示重叠导致的 Elo 偏差。** 如果两个模型在训练期间都见过基准提示，Elo 无意义。使用保留提示集。
- **人类评估付费众包偏差。** Prolific、MTurk 标注者偏向年轻/技术友好。混合招募艺术/设计专家。

## 使用

2026 年生产评估协议：

| 支柱 | 最低 | 推荐 |
|--------|---------|-------------|
| 样本质量 | 10k 对照保留真实的 FID | + 5k 上的 CMMD + 每个类别子集的 FID |
| 提示遵循度 | 30k 上的 CLIP 分数 | + HPSv2 + ImageReward + VQA 风格问答 |
| 偏好 | 200 对基线盲测 | + 2000 配对人类 + LLM 裁判 + Chatbot Arena |
| 失败分析 | 50 个手工标记 | 500 个手工标记 + 自动安全分类器 |

一份报告中四个支柱全部 = 声明。任何单独一个 = 营销。

## 交付

保存 `outputs/skill-eval-report.md`。技能接受新模型检查点 + 基线并输出完整评估计划：样本大小、指标、失败模式探测、验收标准。

## 练习

1. **简单。** 运行 `code/main.py`。在相同合成分布上比较 N=100 vs N=1000 的 FID。报告偏差幅度。
2. **中等。** 从合成 CLIP 风格特征实现 CMMD（见 Jayasumana et al., 2024 的公式）。比较对质量差异的敏感性与 FID。
3. **困难。** 复现 HPSv2 设置：从 Pick-a-Pic 子集中取 1000 个图像-指派对，在偏好上微调小型 CLIP 评分器，测量其与保留集的一致性。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|-----------------------|
| FID | "Fréchet Inception Distance" | 真实与生成 Inception 特征的高斯拟合之间的 Fréchet 距离。 |
| CLIP 分数 | "文本-图像相似度" | CLIP 图像和文本嵌入之间的余弦相似度。 |
| CMMD | "FID 的替代品" | CLIP 特征 MMD；偏差更小，无高斯假设。 |
| IS | "Inception score" | Exp KL(p(y|x) || p(y))；与现代模型相关性差，已退役。 |
| HPSv2 / ImageReward / PickScore | "学到的偏好代理" | 在人类偏好上训练的小模型；用作自动裁判。 |
| Elo | "国际象棋评分" | 配对胜负的 Bradley-Terry 聚合。 |
| PartiPrompts | "基准提示集" | Google 策划的 1600 个提示，跨 12 个类别。 |
| FD-DINO | "自监督替代" | 使用 DINOv2 特征的 FD；对非 ImageNet 领域更好。 |

## 生产说明：评估也是推理工作负载

在 10k 样本上运行 FID 意味着生成 10k 张图像。对于在单个 L4 上 1024² 的 50 步 SDXL 基础模型，这是约 11 小时的单请求推理。评估预算真实存在，框架恰好是离线推理场景（最大化吞吐量，忽略 TTFT）：

- **大力批处理，忘记延迟。** 离线评估 = 以适合内存的最大大小静态批处理。在 80GB H100 上 `pipe(...).images` 使用 `num_images_per_prompt=8`，挂钟运行速度比单请求快 4-6 倍。
- **缓存真实特征。** 真实参考集上的 Inception（FID）或 CLIP（CLIP 分数、CMMD）特征提取运行*一次*，存储为 `.npz`。不要每次评估重新计算。

对于 CI / 回归门禁：每个 PR 在 500 样本子集上运行 FID + CLIP 分数（约 30 分钟）；每晚运行完整 10k FID + HPSv2 + Elo。

## 扩展阅读

- [Heusel et al. (2017). GANs Trained by a Two Time-Scale Update Rule Converge to a Local Nash Equilibrium (FID)](https://arxiv.org/abs/1706.08500)——FID 论文。
- [Jayasumana et al. (2024). Rethinking FID: Towards a Better Evaluation Metric for Image Generation (CMMD)](https://arxiv.org/abs/2401.09603)——CMMD。
- [Radford et al. (2021). Learning Transferable Visual Models from Natural Language Supervision (CLIP)](https://arxiv.org/abs/2103.00020)——CLIP。
- [Wu et al. (2023). HPSv2: A Comprehensive Human Preference Score](https://arxiv.org/abs/2306.09341)——HPSv2。
- [Xu et al. (2023). ImageReward: Learning and Evaluating Human Preferences for Text-to-Image Generation](https://arxiv.org/abs/2304.05977)——ImageReward。
- [Yu et al. (2023). Scaling Autoregressive Models for Content-Rich Text-to-Image Generation (Parti + PartiPrompts)](https://arxiv.org/abs/2206.10789)——PartiPrompts。
- [Stein et al. (2023). Exposing flaws of generative model evaluation metrics](https://arxiv.org/abs/2306.04675)——失败模式综述。