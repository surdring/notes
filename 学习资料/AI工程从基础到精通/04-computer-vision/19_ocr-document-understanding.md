# OCR 与文档理解

> OCR 是一个三阶段管线——检测文本框、识别字符、然后排版。每个现代 OCR 系统都对这三个阶段进行重新排序或合并。

**类型：** 学习 + 使用
**语言：** Python
**前置知识：** Phase 4 Lesson 06（检测）、Phase 7 Lesson 02（自注意力）
**时间：** ~45 分钟

## 学习目标

- 梳理经典 OCR 管线（检测 -> 识别 -> 排版）和现代端到端替代方案（Donut、Qwen-VL-OCR）
- 为序列到序列 OCR 训练实现 CTC（Connectionist Temporal Classification）损失
- 使用 PaddleOCR 或 EasyOCR 无需训练进行生产级文档解析
- 区分 OCR、版面解析和文档理解——并为每个任务选择正确的工具

## 问题

充满文本的图像无处不在：收据、发票、身份证件、扫描书籍、表格、白板、标志、截图。从中提取结构化数据——不仅是字符，而是"这是总金额"——是应用视觉中价值最高的方向之一。

这个领域分为三个技能层次：

1. **OCR 本身**：将像素转为文本。
2. **版面解析**：将 OCR 输出分组到区域（标题、正文、表格、页眉）。
3. **文档理解**：从版面中提取结构化字段（"invoice_total = $42.50"）。

每个层次都有经典和现代方法，而"我想要图像中的文本"和"我需要这张收据的总金额"之间的差距比大多数团队意识到的更大。

## 核心概念

### 经典管线

```mermaid
flowchart LR
    IMG["图像"] --> DET["文本检测<br/>(DB, EAST, CRAFT)"]
    DET --> BOX["词/行<br/>边界框"]
    BOX --> CROP["裁剪每个区域"]
    CROP --> REC["识别<br/>(CRNN + CTC)"]
    REC --> TXT["文本字符串"]
    TXT --> LAY["版面<br/>排序"]
    LAY --> OUT["阅读顺序文本"]

    style DET fill:#dbeafe,stroke:#2563eb
    style REC fill:#fef3c7,stroke:#d97706
    style OUT fill:#dcfce7,stroke:#16a34a
```

- **文本检测**产生每行或每个词的四边形容器。
- **识别**将每个区域裁剪到固定高度，运行 CNN + BiLSTM + CTC 产生字符序列。
- **版面**重建阅读顺序（拉丁语为从上到下、从左到右；阿拉伯语、日语不同）。

### CTC 一图通

OCR 识别从固定长度特征图产生变长序列。CTC（Graves 等人，2006）让你在没有字符级对齐的情况下训练。模型在每个时间步输出（词汇 + blank）上的分布；CTC 损失在所有对齐上边缘化，这些对齐在合并重复并移除 blank 后归约为目标文本。

```
原始输出: "h h h _ _ e e l l _ l l o _ _"
合并重复并移除 blank 后: "hello"
```

CTC 是 CRNN 在 2015 年有效的理由，到 2026 年仍在训练大多数生产级 OCR 模型。

### 现代端到端模型

- **Donut**（Kim 等人，2022）——ViT 编码器 + 文本解码器；读取图像直接输出 JSON。没有文本检测器，没有版面模块。
- **TrOCR**——ViT + transformer 解码器用于行级 OCR。
- **Qwen-VL-OCR / InternVL**——为 OCR 任务微调的完整视觉语言模型；2026 年复杂文档上准确率最高。
- **PaddleOCR**——生产级包装中的经典 DB + CRNN 管线；仍然是开源主力。

端到端模型需要更多数据和算力，但跳过了多阶段管线的错误累积。

### 版面解析

对于结构化文档，运行版面检测器（LayoutLMv3、DocLayNet），为每个区域标注：Title、Paragraph、Figure、Table、Footnote。阅读顺序变成"按版面顺序遍历区域，拼接"。

对于表单，使用**键值提取**模型（Donut 用于视觉丰富文档，LayoutLMv3 用于纯扫描）。它们接收图像 + 检测到的文本 + 位置并预测结构化键值对。

### 评估指标

- **字符错误率（CER）**——Levenshtein 距离 / 参考长度。越低越好。生产目标：干净扫描上 < 2%。
- **词错误率（WER）**——同样的指标在词级别。
- **结构化字段 F1**——用于键值任务；衡量 `{invoice_total: 42.50}` 是否出现正确。
- **JSON 编辑距离**——用于端到端文档解析；Donut 论文引入了归一化树编辑距离。

## 构建

### 步骤 1：CTC 损失 + 贪婪解码器

```python
import torch
import torch.nn as nn
import torch.nn.functional as F


def ctc_loss(log_probs, targets, input_lengths, target_lengths, blank=0):
    """
    log_probs:      (T, N, C) 词汇上的 log-softmax，blank 在索引 0
    targets:        (N, S) int 目标（无 blank）
    input_lengths:  (N,) 每个样本使用的时间步
    target_lengths: (N,) 每个样本的目标长度
    """
    return F.ctc_loss(log_probs, targets, input_lengths, target_lengths,
                      blank=blank, reduction="mean", zero_infinity=True)


def greedy_ctc_decode(log_probs, blank=0):
    """
    log_probs: (T, N, C) log-softmax
    返回: 索引序列列表（blank 已移除，重复已合并）
    """
    preds = log_probs.argmax(dim=-1).transpose(0, 1).cpu().tolist()
    out = []
    for seq in preds:
        decoded = []
        prev = None
        for idx in seq:
            if idx != prev and idx != blank:
                decoded.append(idx)
            prev = idx
        out.append(decoded)
    return out
```

`F.ctc_loss` 在可用时使用高效的 CuDNN 实现。贪婪解码器比 beam search 更简单，通常相差在 1% CER 以内。

### 步骤 2：微型 CRNN 识别器

行 OCR 的最小 CNN + BiLSTM。

```python
class TinyCRNN(nn.Module):
    def __init__(self, vocab_size=40, hidden=128, feat=32):
        super().__init__()
        self.cnn = nn.Sequential(
            nn.Conv2d(1, feat, 3, 1, 1), nn.BatchNorm2d(feat), nn.ReLU(inplace=True),
            nn.MaxPool2d(2),
            nn.Conv2d(feat, feat * 2, 3, 1, 1), nn.BatchNorm2d(feat * 2), nn.ReLU(inplace=True),
            nn.MaxPool2d(2),
            nn.Conv2d(feat * 2, feat * 4, 3, 1, 1), nn.BatchNorm2d(feat * 4), nn.ReLU(inplace=True),
            nn.MaxPool2d((2, 1)),
            nn.Conv2d(feat * 4, feat * 4, 3, 1, 1), nn.BatchNorm2d(feat * 4), nn.ReLU(inplace=True),
            nn.MaxPool2d((2, 1)),
        )
        self.rnn = nn.LSTM(feat * 4, hidden, bidirectional=True, batch_first=True)
        self.head = nn.Linear(hidden * 2, vocab_size)

    def forward(self, x):
        # x: (N, 1, H, W)
        f = self.cnn(x)                # (N, C, H', W')
        f = f.mean(dim=2).transpose(1, 2)  # (N, W', C)
        h, _ = self.rnn(f)
        return F.log_softmax(self.head(h).transpose(0, 1), dim=-1)  # (W', N, vocab)
```

固定高度输入（CNN 最大池化将高度降为 1）。宽度是 CTC 的时间维度。

### 步骤 3：合成 OCR

生成白底黑字的数字字符串用于端到端冒烟测试。

```python
import numpy as np

def synthetic_line(text, height=32, char_width=16):
    W = char_width * len(text)
    img = np.ones((height, W), dtype=np.float32)
    for i, c in enumerate(text):
        x = i * char_width
        shade = 0.0 if c.isalnum() else 0.5
        img[6:height - 6, x + 2:x + char_width - 2] = shade
    return img


def build_batch(strings, vocab):
    H = 32
    W = 16 * max(len(s) for s in strings)
    imgs = np.ones((len(strings), 1, H, W), dtype=np.float32)
    target_lengths = []
    targets = []
    for i, s in enumerate(strings):
        imgs[i, 0, :, :16 * len(s)] = synthetic_line(s)
        ids = [vocab.index(c) for c in s]
        targets.extend(ids)
        target_lengths.append(len(ids))
    return torch.from_numpy(imgs), torch.tensor(targets), torch.tensor(target_lengths)


vocab = ["_"] + list("0123456789abcdefghijklmnopqrstuvwxyz")
imgs, targets, lengths = build_batch(["hello", "world"], vocab)
print(f"images: {imgs.shape}   targets: {targets.shape}   lengths: {lengths.tolist()}")
```

真正的 OCR 数据集要添加字体、噪声、旋转、模糊和颜色。上述管线是相同的。

### 步骤 4：训练草图

```python
model = TinyCRNN(vocab_size=len(vocab))
opt = torch.optim.Adam(model.parameters(), lr=1e-3)

for step in range(200):
    strings = ["abc" + str(step % 10)] * 4 + ["xyz" + str((step + 1) % 10)] * 4
    imgs, targets, target_lens = build_batch(strings, vocab)
    log_probs = model(imgs)  # (W', 8, vocab)
    input_lens = torch.full((8,), log_probs.size(0), dtype=torch.long)
    loss = ctc_loss(log_probs, targets, input_lens, target_lens, blank=0)
    opt.zero_grad(); loss.backward(); opt.step()
```

损失在小样本合成数据上 200 步内应从 ~3 降到 ~0.2。

## 使用

三种生产路径：

- **PaddleOCR**——成熟、快速、多语言。一行用法：`paddleocr.PaddleOCR(lang="en").ocr(image_path)`。
- **EasyOCR**——Python 原生、多语言、PyTorch 骨干。
- **Tesseract**——经典；在模型困难的旧扫描文档上仍然有用。

对于端到端文档解析，使用 Donut 或 VLM：

```python
from transformers import DonutProcessor, VisionEncoderDecoderModel

processor = DonutProcessor.from_pretrained("naver-clova-ix/donut-base-finetuned-cord-v2")
model = VisionEncoderDecoderModel.from_pretrained("naver-clova-ix/donut-base-finetuned-cord-v2")
```

对于具有可重复结构的收据、发票和表单，微调 Donut。对于任意文档或带推理的 OCR，Qwen-VL-OCR 等 VLM 是当前的默认选择。

## 交付物

本课产出：

- `outputs/prompt-ocr-stack-picker.md`——一个 prompt，根据文档类型、语言和结构选择 Tesseract / PaddleOCR / Donut / VLM-OCR。
- `outputs/skill-ctc-decoder.md`——一个 skill，从零编写贪婪和 beam-search CTC 解码器，包含长度归一化。

## 练习

1. **（简单）** 在 5 位随机数字串上训练 TinyCRNN 500 步。在留出集上报告 CER。
2. **（中等）** 用 beam search（beam_width=5）替换贪婪解码。报告 CER 差异。beam search 在哪些输入上更优？
3. **（困难）** 在 20 张收据集上使用 PaddleOCR，提取行项目，对 {item_name, price} 对与人工标注的真值计算 F1。

## 关键术语

| 术语 | 别人说的 | 实际含义 |
|------|---------|---------|
| OCR | "从像素到文本" | 将图像区域转为字符序列 |
| CTC | "无对齐损失" | 无需每步标签即可训练序列模型的损失函数；在所有对齐上边缘化 |
| CRNN | "经典 OCR 模型" | 卷积特征提取器 + BiLSTM + CTC；2015 年的基线，仍在生产中 |
| Donut | "端到端 OCR" | ViT 编码器 + 文本解码器；直接从图像输出 JSON |
| 版面解析 | "查找区域" | 检测并标注文档中的 Title/Table/Figure/Paragraph 区域 |
| 阅读顺序 | "文本序列" | 将识别到的区域排序成句子；拉丁语简单，混合版面不简单 |
| CER / WER | "错误率" | 字符或词粒度的 Levenshtein 距离 / 参考长度 |
| VLM-OCR | "会读的 LLM" | 为 OCR 任务训练或提示的视觉语言模型；当前复杂文档 SOTA |

## 进一步阅读

- [CRNN (Shi et al., 2015)](https://arxiv.org/abs/1507.05717) — 原始 CNN+RNN+CTC 架构
- [CTC (Graves et al., 2006)](https://www.cs.toronto.edu/~graves/icml_2006.pdf) — 原始 CTC 论文；密集地包含了算法思想
- [Donut (Kim et al., 2022)](https://arxiv.org/abs/2111.15664) — 无 OCR 文档理解 transformer
- [PaddleOCR](https://github.com/PaddlePaddle/PaddleOCR) — 开源生产级 OCR 栈