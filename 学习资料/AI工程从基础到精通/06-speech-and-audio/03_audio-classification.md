# 音频分类——从 MFCC 上的 k-NN 到 AST 和 BEATs

> 从"狗叫 vs 警报"到"这是哪种语言"，一切都是音频分类。特征是 Mel。架构每十年变化一次。评估保持不变：AUC、F1 和每类召回率。

**类型：** 构建
**语言：** Python
**前置要求：** 第 6 阶段 · 02（频谱图与 Mel），第 3 阶段 · 06（CNN），第 5 阶段 · 08（文本的 CNN 与 RNN）
**时间：** 约 75 分钟

## 问题

你得到一段 10 秒的片段。你想知道："这是什么？"城市声音（警报、电钻、狗）、语音命令（yes/no/stop）、语言识别（en/es/ar）、说话人情绪（生气/中性）或环境声音（室内/室外、嘈杂声）。所有这些都是*音频分类*，在 2026 年基线架构已经成熟：对数 Mel → CNN 或 Transformer → softmax。

核心困难不是网络。是数据。音频数据集存在严重的类别不平衡、强烈的领域偏移（干净 vs 嘈杂）和标签噪声（谁决定了"城市嘈杂声"vs"餐厅噪声"？）。80% 的问题是策划、增强和评估，而不是将 CNN 换成 Transformer。

## 概念

![音频分类阶梯：MFCC 上的 k-NN 到 AST 到 BEATs](../assets/audio-classification.svg)

**MFCC 上的 k-NN（1990 年代基线）。** 每段片段展平 MFCC，计算到标注库的余弦相似度，返回 top K 的多数投票。在干净的小数据集上惊人地强（Speech Commands、ESC-50）。无需 GPU 即可运行。

**对数 Mel 上的 2D CNN（2015-2019）。** 将 `(T, n_mels)` 对数 Mel 视为图像。应用 ResNet-18 或 VGG 风格。时间轴全局平均池化。类别上 softmax。仍然是 2026 年大多数 Kaggle 竞赛的基线。

**音频频谱图 Transformer，AST（2021-2024）。** 将对数 Mel 分块（如 16×16 块），添加位置嵌入，馈入 ViT。监督学习的 AudioSet 最先进水平（mAP 0.485）。

**BEATs 和 WavLM-base（2024-2026）。** 在数百万小时上的自监督预训练。用你原本所需监督数据的 1-10% 在你的任务上微调。在 2026 年这是非语音音频的默认起点。BEATs-iter3 在 AudioSet 上以 1/4 计算量超过 AST 1-2 mAP。

**Whisper-encoder 作为冻结骨干（2024）。** 取 Whisper 的编码器，去掉解码器，附加线性分类器。零音频增强下在语言识别和简单事件分类上接近最先进。这就是"免费午餐"基线。

### 类别不平衡是真正的挑战

ESC-50：50 类，每类 40 个片段——平衡，简单。UrbanSound8K：10 类，不平衡 10:1。AudioSet：632 类，长尾 100,000:1。有效的技术：

- 训练时平衡采样（非评估时）。
- Mixup：线性插值两个片段（及其标签）作为增强。
- SpecAugment：屏蔽随机时间和频率带。简单；关键。

### 评估

- 多类互斥（Speech Commands）：top-1 准确率，top-5 准确率。
- 多类多标签（AudioSet、UrbanSound 风格）：平均精确率均值（mAP）。
- 严重不平衡：每类召回率 + 宏 F1。

2026 年你应该知道的数字：

| 基准 | 基线 | 2026 最先进 | 来源 |
|-----------|----------|-----------|--------|
| ESC-50 | 82%（AST） | 97.0%（BEATs-iter3） | BEATs 论文（2024） |
| AudioSet mAP | 0.485（AST） | 0.548（BEATs-iter3） | HEAR 排行榜 2026 |
| Speech Commands v2 | 98%（CNN） | 99.0%（Audio-MAE） | HEAR v2 结果 |

## 构建

### 步骤 1：特征化

```python
def featurize_mfcc(signal, sr, n_mfcc=13, n_mels=40, frame_len=400, hop=160):
    mag = stft_magnitude(signal, frame_len, hop)
    fb = mel_filterbank(n_mels, frame_len, sr)
    mels = apply_filterbank(mag, fb)
    log = log_transform(mels)
    return [dct_ii(frame, n_mfcc) for frame in log]
```

### 步骤 2：固定长度摘要

```python
def summarize(mfcc_frames):
    n = len(mfcc_frames[0])
    mean = [sum(f[i] for f in mfcc_frames) / len(mfcc_frames) for i in range(n)]
    var = [
        sum((f[i] - mean[i]) ** 2 for f in mfcc_frames) / len(mfcc_frames) for i in range(n)
    ]
    return mean + var
```

简单但强：时间上的均值 + 方差为 13 系数 MFCC 给出 26 维固定嵌入。即时运行。在 2017 年仍然在 ESC-50 上击败最先进的 NN 基线。

### 步骤 3：k-NN

```python
def cosine(a, b):
    dot = sum(x * y for x, y in zip(a, b))
    na = math.sqrt(sum(x * x for x in a)) or 1e-12
    nb = math.sqrt(sum(x * x for x in b)) or 1e-12
    return dot / (na * nb)

def knn_classify(q, bank, labels, k=5):
    sims = sorted(range(len(bank)), key=lambda i: -cosine(q, bank[i]))[:k]
    votes = Counter(labels[i] for i in sims)
    return votes.most_common(1)[0][0]
```

### 步骤 4：升级到对数 Mel 上的 CNN

PyTorch 中：

```python
import torch.nn as nn

class AudioCNN(nn.Module):
    def __init__(self, n_mels=80, n_classes=50):
        super().__init__()
        self.body = nn.Sequential(
            nn.Conv2d(1, 32, 3, padding=1), nn.ReLU(), nn.MaxPool2d(2),
            nn.Conv2d(32, 64, 3, padding=1), nn.ReLU(), nn.MaxPool2d(2),
            nn.Conv2d(64, 128, 3, padding=1), nn.ReLU(),
            nn.AdaptiveAvgPool2d(1),
        )
        self.head = nn.Linear(128, n_classes)

    def forward(self, x):  # x: (B, 1, T, n_mels)
        return self.head(self.body(x).flatten(1))
```

3M 参数。在 ESC-50 上用单张 RTX 4090 约 10 分钟训练。80%+ 准确率。

### 步骤 5：2026 年默认——微调 BEATs

```python
from transformers import ASTFeatureExtractor, ASTForAudioClassification

ext = ASTFeatureExtractor.from_pretrained("MIT/ast-finetuned-audioset-10-10-0.4593")
model = ASTForAudioClassification.from_pretrained(
    "MIT/ast-finetuned-audioset-10-10-0.4593",
    num_labels=50,
    ignore_mismatched_sizes=True,
)

inputs = ext(audio, sampling_rate=16000, return_tensors="pt")
logits = model(**inputs).logits
```

对于 BEATs，通过 `beats` 库使用 `microsoft/BEATs-base`；transformers API 形状相同。

## 使用

2026 年技术栈：

| 场景 | 从什么开始 |
|-----------|-----------|
| 微小数据集（<1000 片段） | MFCC 均值上的 k-NN（你的基线）+ 音频增强 |
| 中等数据集（1K-100K） | BEATs 或 AST 微调 |
| 大数据集（>100K） | 从头训练或微调 Whisper-encoder |
| 实时、边缘 | 40-MFCC CNN，量化为 int8（KWS 风格） |
| 多标签（AudioSet） | BEATs-iter3 带 BCE 损失 + mixup + SpecAugment |
| 语言识别 | MMS-LID、SpeechBrain VoxLingua107 基线 |

决策规则：**从冻结骨干开始，而不是全新模型**。微调 BEATs 头部在数小时内让你达到 95% 的最先进水平，而非数周。

## 交付

保存为 `outputs/skill-classifier-designer.md`。为给定音频分类任务选择架构、增强、类别平衡策略和评估指标。

## 练习

1. **简单。** 运行 `code/main.py`。它在 4 类合成数据集（不同音高的纯音）上训练 k-NN MFCC 基线。报告混淆矩阵。
2. **中等。** 将 `summarize` 替换为 [mean, var, skew, kurtosis]。4 阶矩池化是否在相同合成数据集上击败 mean+var？
3. **困难。** 使用 `torchaudio`，在 ESC-50 fold 1 上训练 2D CNN。报告 5 折交叉验证准确率。添加 SpecAugment（时间 mask = 20，频率 mask = 10）并报告增量。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| AudioSet | 音频的 ImageNet | Google 的 2M 片段、632 类弱标注 YouTube 数据集。 |
| ESC-50 | 小型分类基准 | 50 类 × 40 个环境声音片段。 |
| AST | 音频频谱图 Transformer | 对数 Mel 块上的 ViT；2021 年最先进。 |
| BEATs | 自监督音频 | 微软模型，iter3 截至 2026 年领先 AudioSet。 |
| Mixup | 成对增强 | `x = λ·x1 + (1-λ)·x2; y = λ·y1 + (1-λ)·y2`。 |
| SpecAugment | 基于掩码的增强 | 将频谱图的随机时间和频率带清零。 |
| mAP | 主要多标签指标 | 跨类别和阈值的平均精确率均值。 |

## 扩展阅读

- [Gong, Chung, Glass (2021). AST: Audio Spectrogram Transformer](https://arxiv.org/abs/2104.01778)——2021-2024 年的记录架构。
- [Chen et al. (2022, rev. 2024). BEATs: Audio Pre-Training with Acoustic Tokenizers](https://arxiv.org/abs/2212.09058)——2024+ 默认选择。
- [Park et al. (2019). SpecAugment](https://arxiv.org/abs/1904.08779)——主导的音频增强方法。
- [Piczak (2015). ESC-50 dataset](https://github.com/karolpiczak/ESC-50)——持续存在的 50 类基准。
- [Gemmeke et al. (2017). AudioSet](https://research.google.com/audioset/)——632 类 YouTube 分类法；仍是黄金标准。