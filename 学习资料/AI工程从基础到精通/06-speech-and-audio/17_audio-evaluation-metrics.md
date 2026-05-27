# 音频评估——WER、MOS、UTMOS、MMAU、FAD 和开放排行榜

> 你不能发布无法衡量的东西。本课列出 2026 年每个音频任务的指标：ASR（WER、CER、RTFx）、TTS（MOS、UTMOS、SECS、WER-on-ASR-round-trip）、音频语言（MMAU、LongAudioBench）、音乐（FAD、CLAP）和说话人（EER）。以及你用来比较的排行榜。

**类型：** 学习
**语言：** Python
**前置要求：** 第 6 阶段 · 04、06、07、09、10；第 2 阶段 · 09（模型评估）
**时间：** 约 60 分钟

## 问题

每个音频任务有多个指标，每个衡量不同的轴。使用错误的指标会让你发布一个仪表盘上看起来很好但生产中很糟糕的模型。2026 规范列表：

| 任务 | 主要 | 次要 |
|------|---------|-----------|
| ASR | WER | CER · RTFx · 首标记延迟 |
| TTS | MOS / UTMOS | SECS · WER-on-ASR-round-trip · CER · TTFA |
| 声音克隆 | SECS（ECAPA 余弦） | MOS · CER |
| 说话人验证 | EER | minDCF · 工作点 FAR / FRR |
| 说话人分离 | DER | JER · 说话人混淆 |
| 音频分类 | top-1 · mAP | 宏 F1 · 每类召回率 |
| 音乐生成 | FAD | CLAP · 听力小组 MOS |
| 音频语言模型 | MMAU-Pro | LongAudioBench · AudioCaps FENSE |
| 流式 S2S | 延迟 P50/P95 | WER · MOS |

## 概念

![音频评估矩阵——指标 vs 任务 vs 2026 排行榜](../assets/eval-landscape.svg)

### ASR 指标

**WER（词错误率）。** `(S + D + I) / N`。评分前小写、去标点、规范化数字。使用 `jiwer` 或 OpenAI 的 `whisper_normalizer`。< 5% = 朗读语音的人类水平。

**CER（字符错误率）。** 相同公式，字符级。用于词分割模糊的声调语言（普通话、粤语）。

**RTFx（逆实时因子）。** 每墙钟秒处理的音频秒数。越高越好。Parakeet-TDT 达到 3380×。Whisper-large-v3 约 30×。

**首标记延迟。** 从音频输入到第一个转录标记的墙钟时间。流式关键。Deepgram Nova-3：约 150 ms。

### TTS 指标

**MOS（平均意见分）。** 1-5 人类评分。金标准但慢。每个样本收集 20+ 听众，每个模型 100+ 样本。

**UTMOS（2022-2026）。** 学习到的 MOS 预测器。在标准基准上与人类 MOS 相关性约 0.9。F5-TTS：UTMOS 3.95；真实语音：4.08。

**SECS（说话人编码器余弦相似度）。** 用于声音克隆。参考和克隆输出之间的 ECAPA 嵌入余弦。> 0.75 = 可识别的克隆。

**ASR 环回 WER。** 在 TTS 输出上运行 Whisper，计算相对于输入文本的 WER。捕获可理解性退化。2026 最先进：< 2% CER。

**TTFA（首音频时间）。** 墙钟延迟。Kokoro-82M：约 100 ms；F5-TTS：约 1 秒。

### 声音克隆专用

**SECS + MOS + CER** 作为三元组。SECS 高但 MOS 低的克隆意味着音色正确但不自然；反之意味着自然声音但说话人错误。

### 说话人验证

**EER（等错误率）。** 错误接受率等于错误拒绝率的阈值。ECAPA 在 VoxCeleb1-O 上：0.87%。

**minDCF（最小检测成本）。** 在选定工作点（通常 FAR=0.01）的加权成本。比 EER 更面向生产。

### 说话人分离

**DER（分离错误率）。** `(FA + Miss + Confusion) / total_speaker_time`。遗漏语音 + 误报语音 + 说话人混淆，各为比例。AMI 会议：DER ~10-20% 是现实的。pyannote 3.1 + Precision-2 商业版：良好录制音频上 <10% DER。

**JER（Jaccard 错误率）。** DER 的替代方案，对短片段偏差鲁棒。

### 音频分类

多标签：所有类别上的 **mAP（平均精确率均值）**。AudioSet：BEATs-iter3 为 0.548 mAP。

多类互斥：**top-1、top-5 准确率**。Speech Commands v2：99.0% top-1（Audio-MAE）。

不平衡：**宏 F1** + **每类召回率**。报告每类——聚合准确率隐藏哪些类别失败。

### 音乐生成

**FAD（Fréchet 音频距离）。** 真实 vs 生成音频的 VGGish 嵌入分布之间的距离。MusicGen-small 在 MusicCaps 上：4.5。MusicLM：4.0。越低越好。

**CLAP 分数。** 使用 CLAP 嵌入的文本-音频对齐分数。> 0.3 = 合理对齐。

**听力小组 MOS。** 消费级音乐的最终裁定。Suno v5 在 TTS Arena 上 ELO 1293（来自成对人类偏好）。

### 音频语言基准

**MMAU（大规模多音频理解）。** 10k 音频 QA 对。

**MMAU-Pro。** 1800 个困难项，四个类别：语音 / 声音 / 音乐 / 多音频。4 选 1 随机概率 25%。Gemini 2.5 Pro 总体约 60%；所有模型多音频约 22%。

**LongAudioBench。** 带语义查询的多分钟片段。Audio Flamingo Next 击败 Gemini 2.5 Pro。

**AudioCaps / Clotho。** 描述基准。SPICE、CIDEr、FENSE 指标。

### 流式语音到语音

**延迟 P50 / P95 / P99。** 从用户语音结束到第一个可听响应的墙钟时间。Moshi：200 ms；GPT-4o Realtime：300 ms。

输出的 **WER / MOS**。

**打断响应性。** 从用户中断到助手静音的时间。目标 < 150 ms。

### 2026 排行榜

| 排行榜 | 赛道 | URL |
|------------|--------|-----|
| Open ASR Leaderboard (HF) | 英语 + 多语言 + 长格式 | `huggingface.co/spaces/hf-audio/open_asr_leaderboard` |
| TTS Arena (HF) | 英语 TTS | `huggingface.co/spaces/TTS-AGI/TTS-Arena` |
| Artificial Analysis Speech | TTS + STT，来自成对投票的 ELO | `artificialanalysis.ai/speech` |
| MMAU-Pro | LALM 推理 | `mmaubenchmark.github.io` |
| SpeakerBench / VoxSRC | 说话人识别 | `voxsrc.github.io` |
| MMAU 音乐子集 | 音乐 LALM | （MMAU 内） |
| HEAR benchmark | 自监督音频 | `hearbenchmark.com` |

## 构建

### 步骤 1：带规范化的 WER

```python
from jiwer import wer, Compose, ToLowerCase, RemovePunctuation, Strip

transform = Compose([ToLowerCase(), RemovePunctuation(), Strip()])
score = wer(
    truth="Please turn on the lights.",
    hypothesis="please turn on the light",
    truth_transform=transform,
    hypothesis_transform=transform,
)
# ~0.17
```

### 步骤 2：TTS 环回 WER

```python
def ttr_wer(tts_model, asr_model, texts):
    errors = []
    for txt in texts:
        audio = tts_model.synthesize(txt)
        recog = asr_model.transcribe(audio)
        errors.append(wer(truth=txt, hypothesis=recog))
    return sum(errors) / len(errors)
```

### 步骤 3：声音克隆的 SECS

```python
from speechbrain.inference.speaker import EncoderClassifier
sv = EncoderClassifier.from_hparams("speechbrain/spkrec-ecapa-voxceleb")

emb_ref = sv.encode_batch(load_wav("reference.wav"))
emb_clone = sv.encode_batch(load_wav("cloned.wav"))
secs = torch.nn.functional.cosine_similarity(emb_ref, emb_clone, dim=-1).item()
```

### 步骤 4：音乐生成的 FAD

```python
from frechet_audio_distance import FrechetAudioDistance
fad = FrechetAudioDistance()
score = fad.get_fad_score("generated_folder/", "reference_folder/")
```

### 步骤 5：说话人验证的 EER（与第 6 课代码相同）

```python
def eer(same_scores, diff_scores):
    thresholds = sorted(set(same_scores + diff_scores))
    best = (1.0, 0.0)
    for t in thresholds:
        far = sum(1 for s in diff_scores if s >= t) / len(diff_scores)
        frr = sum(1 for s in same_scores if s < t) / len(same_scores)
        if abs(far - frr) < best[0]:
            best = (abs(far - frr), (far + frr) / 2)
    return best[1]
```

## 使用

每次部署配对固定的评估框架，在每次模型更新时运行。三条基本规则：

1. **评分前规范化。** 小写、去标点、数字展开。报告规范化规则。
2. **报告分布而非平均值。** 延迟的 P50/P95/P99。分类的每类召回率。MMAU 的每类别。
3. **运行一个规范的公开基准。** 即使你的生产数据不同，报告 Open ASR / TTS Arena / MMAU 让评审者能够同类比较。

## 2026 年仍会发布的陷阱

- **UTMOS 外推。** 在 VCTK 风格干净语音上训练；对嘈杂 / 克隆 / 情感音频评分差。
- **MOS 评委偏差。** 20 个 Amazon Mechanical Turk 工人 ≠ 20 个目标用户。如果 stakes 高则雇领域评委。
- **FAD 依赖参考集。** 在模型间比较相同参考分布。
- **聚合 WER。** 总体 5% 的 WER 可能隐藏口音语音上 30% 的 WER。按人口切片报告。
- **公开基准饱和。** 大多数前沿模型在标准基准上接近天花板。构建反映你流量的内部留出集。

## 交付

保存为 `outputs/skill-audio-evaluator.md`。为任何音频模型发布选择指标、基准和报告格式。

## 练习

1. **简单。** 运行 `code/main.py`。在玩具输入上计算 WER / CER / EER / SECS / 类 FAD / 类 MMAU。
2. **中等。** 构建 TTS 环回 WER 框架。通过 Whisper 运行你的 Kokoro 或 F5-TTS 输出。在 50 个提示上计算 WER。标记 WER > 10% 的提示。
3. **困难。** 在 MMAU-Pro 语音 + 多音频子集（各 50 项）上评分你的第 10 课 LALM 选择。报告每类别准确率并与已发布数字比较。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| WER | ASR 分数 | 规范化后词级别的 `(S+D+I)/N`。 |
| CER | 字符 WER | 用于声调语言或字符级系统。 |
| MOS | 人类意见 | 1-5 评分；20+ 听众 × 100 样本。 |
| UTMOS | ML MOS 预测器 | 学习模型；与人类 MOS 相关性约 0.9。 |
| SECS | 声音克隆相似度 | 参考与克隆之间的 ECAPA 余弦。 |
| EER | 说话人验证分数 | FAR = FRR 的阈值。 |
| DER | 分离分数 | (FA + 遗漏 + 混淆) / 总计。 |
| FAD | 音乐生成质量 | VGGish 嵌入上的 Fréchet 距离。 |
| RTFx | 吞吐量 | 每墙钟秒处理的音频秒数。 |

## 扩展阅读

- [jiwer](https://github.com/jitsi/jiwer)——带规范化工具的 WER/CER 库。
- [UTMOS (Saeki et al. 2022)](https://arxiv.org/abs/2204.02152)——学习到的 MOS 预测器。
- [Fréchet Audio Distance (Kilgour et al. 2019)](https://arxiv.org/abs/1812.08466)——音乐生成标准。
- [Open ASR Leaderboard](https://huggingface.co/spaces/hf-audio/open_asr_leaderboard)——2026 实时排名。
- [TTS Arena](https://huggingface.co/spaces/TTS-AGI/TTS-Arena)——人类投票 TTS 排行榜。
- [MMAU-Pro benchmark](https://mmaubenchmark.github.io/)——LALM 推理排行榜。
- [HEAR benchmark](https://hearbenchmark.com/)——音频 SSL 基准。