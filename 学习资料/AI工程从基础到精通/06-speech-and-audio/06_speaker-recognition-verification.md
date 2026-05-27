# 说话人识别与验证

> ASR 问"他们说了什么？"说话人识别问"谁说的？"数学看起来相同——嵌入加上余弦——但每个生产决策都取决于一个 EER 数字。

**类型：** 构建
**语言：** Python
**前置要求：** 第 6 阶段 · 02（频谱图与 Mel），第 5 阶段 · 22（嵌入模型）
**时间：** 约 45 分钟

## 问题

一个用户说了一句口令。你想知道：这是他们声称的人吗（*验证*，1:1），还是你注册库中的第一个人（*识别*，1:N）？还是都不是——这是个未知说话人（*开集*）？

2018 年之前：GMM-UBM + i-vector。EER 合理但对信道偏移（手机 vs 笔记本）和情绪脆弱。2018-2022：x-vector（TDNN 骨干用角度间隔训练）。2022+：ECAPA-TDNN 和 WavLM-large 嵌入。到 2026 年该领域由三个模型和一个指标主导。

指标是 **EER**——等错误率。设置你的决策阈值使得错误接受率 = 错误拒绝率。交点就是 EER。每篇论文、每个排行榜、每次采购呼叫中使用。

## 概念

![注册 + 带嵌入 + 余弦 + EER 的验证流水线](../assets/speaker-verification.svg)

**流水线。** 注册：录制 5-30 秒目标说话人；计算固定维度嵌入（ECAPA-TDNN 为 192 维，WavLM-large 为 256 维）。验证：获取测试话语嵌入；计算余弦相似度；与阈值比较。

**ECAPA-TDNN（2020，2026 年仍占主导）。** 强调通道注意力、传播和聚合——时延神经网络。1D 卷积块带 squeeze-excitation、多头注意力池化，后接线性层到 192 维。在 VoxCeleb 1+2（2700 说话人，110 万话语）上以加性角度间隔损失（AAM-softmax）训练。

**WavLM-SV（2022+）。** 用 AAM 损失微调预训练 WavLM-large SSL 骨干。质量更高但更慢——300+ MB vs 15 MB。

**x-vector（基线）。** TDNN + 统计池化。经典；在 CPU / 边缘上仍然有用。

**AAM-softmax。** 标准 softmax 在角度空间中加入间隔 `m`：`cos(θ + m)` 用于正确类别。强制类间角度分离。典型 `m=0.2`，尺度 `s=30`。

### 评分

- **余弦** 在注册和测试嵌入之间。基于阈值的决策。
- **PLDA（概率 LDA）。** 将嵌入投影到潜在空间，其中相同说话人 vs 不同说话人具有闭式似然比。在余弦之上添加可获得 +10-20% EER 降低。2020 年前的标准；现在仅用于闭集设置。
- **分数归一化。** `S-norm` 或 `AS-norm`：将每个分数对冒名者均值和标准差的队列归一化。对跨域评估至关重要。

### 你应该知道的数字（2026）

| 模型 | VoxCeleb1-O EER | 参数 | 吞吐量（A100） |
|-------|-----------------|------|----------------|
| x-vector（经典） | 3.10% | 5 M | 400× RT |
| ECAPA-TDNN | 0.87% | 15 M | 200× RT |
| WavLM-SV large | 0.42% | 316 M | 20× RT |
| Pyannote 3.1 分割 + 嵌入 | 0.65% | 6 M | 100× RT |
| ReDimNet（2024） | 0.39% | 24 M | 100× RT |

### 说话人分离

多说话人片段中的"谁在何时说话"。流水线：VAD → 分段 → 嵌入每个片段 → 聚类（凝聚或谱聚类）→ 平滑边界。现代技术栈：`pyannote.audio` 3.1，在一次调用中捆绑说话人分割 + 嵌入 + 聚类。2026 年 AMI 上最先进的 DER 约为 15%（从 2022 年的 23% 下降）。

## 构建

### 步骤 1：从 MFCC 统计量的玩具嵌入

```python
def embed_mfcc_stats(signal, sr):
    frames = featurize_mfcc(signal, sr, n_mfcc=13)
    mean = [sum(f[i] for f in frames) / len(frames) for i in range(13)]
    std = [
        math.sqrt(sum((f[i] - mean[i]) ** 2 for f in frames) / len(frames))
        for i in range(13)
    ]
    return mean + std  # 26-d
```

远非最先进——仅用于教学。`code/main.py` 在合成说话人数据上用此作为概念验证。

### 步骤 2：余弦相似度 + 阈值

```python
def cosine(a, b):
    dot = sum(x * y for x, y in zip(a, b))
    na = math.sqrt(sum(x * x for x in a))
    nb = math.sqrt(sum(x * x for x in b))
    return dot / (na * nb) if na and nb else 0.0

def verify(enroll, test, threshold=0.75):
    return cosine(enroll, test) >= threshold
```

### 步骤 3：从相似度对计算 EER

```python
def eer(same_scores, diff_scores):
    thresholds = sorted(set(same_scores + diff_scores))
    best = (1.0, 1.0, 0.0)  # (fa, fr, threshold)
    for t in thresholds:
        fr = sum(1 for s in same_scores if s < t) / len(same_scores)
        fa = sum(1 for s in diff_scores if s >= t) / len(diff_scores)
        if abs(fa - fr) < abs(best[0] - best[1]):
            best = (fa, fr, t)
    return (best[0] + best[1]) / 2, best[2]
```

返回 (eer, eer 处的阈值)。两者都要报告。

### 步骤 4：用 SpeechBrain 生产

```python
from speechbrain.pretrained import EncoderClassifier

clf = EncoderClassifier.from_hparams(source="speechbrain/spkrec-ecapa-voxceleb")

# 注册：平均 3-5 个干净样本的嵌入
enroll = torch.stack([clf.encode_batch(load(x)) for x in enrollment_clips]).mean(0)
# 验证
score = clf.similarity(enroll, clf.encode_batch(load("test.wav"))).item()
verdict = score > 0.25   # ECAPA 典型阈值；在你的数据上调优
```

### 步骤 5：用 pyannote 进行说话人分离

```python
from pyannote.audio import Pipeline

pipe = Pipeline.from_pretrained("pyannote/speaker-diarization-3.1")
diarization = pipe("meeting.wav", num_speakers=None)
for turn, _, speaker in diarization.itertracks(yield_label=True):
    print(f"{turn.start:.1f}–{turn.end:.1f}  {speaker}")
```

## 使用

2026 年技术栈：

| 场景 | 选择 |
|-----------|------|
| 闭集 1:1 验证，边缘 | ECAPA-TDNN + 余弦阈值 |
| 开集验证，云端 | WavLM-SV + AS-norm |
| 说话人分离（会议、播客） | `pyannote/speaker-diarization-3.1` |
| 反欺骗（重放 / 深度伪造检测） | AASIST 或 RawNet2 |
| 微嵌入（KWS + 注册） | Titanet-Small（NeMo） |

## 陷阱

- **信道不匹配。** 在 VoxCeleb（网络视频）上训练的模型 ≠ 电话通话音频。始终在目标信道上评估。
- **短话语。** EER 在测试音频低于 3 秒时急剧下降。
- **带噪声的注册。** 一个带噪声的注册样本污染锚点。使用 ≥3 个干净样本并取平均。
- **跨条件固定阈值。** 始终在目标领域的留出开发集上调优阈值。
- **在非归一化嵌入上使用余弦。** 先做 L2 归一化；否则幅度占主导。

## 交付

保存为 `outputs/skill-speaker-verifier.md`。选择模型、注册协议、阈值调优计划和欺诈防护措施。

## 练习

1. **简单。** 运行 `code/main.py`。构建合成"说话人"（不同音调轮廓），注册，在 100 对试验列表上计算 EER。
2. **中等。** 在 30 个 VoxCeleb1 话语（5 说话人 × 各 6 个）上使用 SpeechBrain ECAPA。用余弦 vs PLDA 计算 EER。
3. **困难。** 用 `pyannote.audio` 构建完整的注册 → 分离 → 验证流水线。在 AMI 开发集上评估 DER。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| EER | 头条指标 | 错误接受 = 错误拒绝时的阈值。 |
| 验证 | 1:1 | "这是 Alice 吗？" |
| 识别 | 1:N | "谁在说话？" |
| 开集 | 可能有未知 | 测试集可以包含未注册的说话人。 |
| 注册 | 录入 | 计算说话人的参考嵌入。 |
| AAM-softmax | 损失函数 | 带加性角度间隔的 softmax；强制簇分离。 |
| PLDA | 经典评分 | 概率 LDA；在嵌入之上的似然比评分。 |
| DER | 分离指标 | 分离错误率——漏检 + 误检 + 混淆。 |

## 扩展阅读

- [Snyder et al. (2018). X-Vectors: Robust DNN Embeddings for Speaker Recognition](https://www.danielpovey.com/files/2018_icassp_xvectors.pdf)——经典深度嵌入论文。
- [Desplanques et al. (2020). ECAPA-TDNN](https://arxiv.org/abs/2005.07143)——2020-2026 年主导架构。
- [Chen et al. (2022). WavLM: Large-Scale Self-Supervised Pre-Training for Full Stack Speech Processing](https://arxiv.org/abs/2110.13900)——SV 和分离的 SSL 骨干。
- [Bredin et al. (2023). pyannote.audio 3.1](https://github.com/pyannote/pyannote-audio)——生产级分离 + 嵌入栈。
- [VoxCeleb 排行榜（更新至 2026）](https://www.robots.ox.ac.uk/~vgg/data/voxceleb/)——跨模型的当前 EER 排名。