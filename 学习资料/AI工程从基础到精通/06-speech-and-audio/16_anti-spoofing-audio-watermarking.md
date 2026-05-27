# 语音反欺骗与音频水印——ASVspoof 5、AudioSeal、WaveVerify

> 声音克隆的发布速度超过了防御。2026 年生产语音系统需要两样东西：一个分类真实 vs 虚假语音的检测器（AASIST、RawNet2），以及一个能承受压缩和编辑的水印（AudioSeal）。两者都发布，否则就不要发布声音克隆。

**类型：** 构建
**语言：** Python
**前置要求：** 第 6 阶段 · 06（说话人识别），第 6 阶段 · 08（声音克隆）
**时间：** 约 75 分钟

## 问题

三种相关的防御：

1. **反欺骗 / 深度伪造检测。** 给定一段音频片段，它是合成的还是真实的？ASVspoof 基准（ASVspoof 2019 → 2021 → 5）是金标准。
2. **音频水印。** 在生成的音频中嵌入不可察觉的信号，检测器可以稍后提取。AudioSeal（Meta）和 WavMark 是开源选项。
3. **认证出处。** 音频文件 + 元数据的加密签名。C2PA / 内容真实性倡议。

检测处理不合作的对手。水印处理合规——AI 生成的音频应可识别。两者在 2026 年都是必需的。

## 概念

![反欺骗 vs 水印 vs 出处——三层防御](../assets/spoofing-watermark.svg)

### ASVspoof 5——2024-2025 基准

与之前版本的最大变化：

- **众包数据**（非录音室干净）——现实条件。
- **约 2000 说话人**（之前约 100）。
- **32 种攻击算法。** TTS + 声音转换 + 对抗性扰动。
- **两个赛道。** 对策（CM）独立检测；欺骗鲁棒 ASV（SASV）用于生物识别系统。

ASVspoof 5 上的最先进：约 7.23% EER。在较旧的 ASVspoof 2019 LA 上：0.42% EER。真实世界部署：在野外片段上预期 5-10% EER。

### AASIST 和 RawNet2——检测模型家族

**AASIST**（2021，更新至 2026）。频谱特征上的图注意力。当前 ASVspoof 5 对策任务最先进。

**RawNet2。** 原始波形上的卷积前端 + TDNN 骨干。更简单的基线；通过微调仍有竞争力。

**NeXt-TDNN + SSL 特征。** 2025 年变体：ECAPA 风格 + WavLM 特征 + focal 损失。在 ASVspoof 2019 LA 上实现 0.42% EER。

### AudioSeal——2024 水印默认

Meta 的 **AudioSeal**（2024 年 1 月，v0.2 2024 年 12 月）。关键设计：

- **本地化。** 在 16 kHz 采样分辨率（1/16000 秒）下逐帧检测水印。
- **生成器 + 检测器联合训练。** 生成器学习嵌入不可听信号；检测器学习通过增强找到它。
- **鲁棒。** 承受 MP3 / AAC 压缩、均衡器、速度偏移 ±10%、噪声混合 +10 dB SNR。
- **快速。** 检测器以 485 倍实时运行；比 WavMark 快 1000 倍。
- **容量。** 16 位 payload（可编码模型 ID、生成时间戳、用户 ID）可嵌入每个话语。

### WavMark

AudioSeal 之前的开源基线。可逆神经网络，32 位/秒。问题：

- 同步暴力搜索慢。
- 可被高斯噪声或 MP3 压缩移除。
- 不实时友好。

### WaveVerify（2025 年 7 月）

解决 AudioSeal 的弱点——特别是时序操作（反转、速度）。使用基于 FiLM 的生成器 + 混合专家检测器。在标准攻击上与 AudioSeal 有竞争力；处理时序编辑。

### 对手利用的缺口

来自 AudioMarkBench："在音高偏移下，所有水印显示比特恢复准确率低于 0.6，表明近乎完全移除。"**音高偏移是通用攻击。** 没有 2026 年的水印对激进音高修改完全鲁棒。这就是你为什么需要检测（AASIST）配合水印。

### C2PA / 内容真实性倡议

不是 ML 技术——清单格式。音频文件携带关于创建工具、作者、日期的加密签名元数据。Audobox / Seamless 使用。对出处好；如果恶意行为者重新编码并剥离元数据则无效。

## 构建

### 步骤 1：简单的频谱特征检测器（玩具）

```python
def spectral_rolloff(spec, percentile=0.85):
    cum = 0
    total = sum(spec)
    if total == 0:
        return 0
    threshold = total * percentile
    for k, v in enumerate(spec):
        cum += v
        if cum >= threshold:
            return k
    return len(spec) - 1

def is_suspicious(audio):
    spec = magnitude_spectrum(audio)
    rolloff = spectral_rolloff(spec)
    return rolloff / len(spec) > 0.92
```

合成语音通常具有异常平坦的高频能量。生产检测器使用 AASIST，不用这个。但直觉成立。

### 步骤 2：AudioSeal 嵌入 + 检测

```python
from audioseal import AudioSeal
import torch

generator = AudioSeal.load_generator("audioseal_wm_16bits")
detector = AudioSeal.load_detector("audioseal_detector_16bits")

audio = load_wav("generated.wav", sr=16000)[None, None, :]
payload = torch.tensor([[1, 0, 1, 1, 0, 1, 0, 0, 1, 1, 0, 1, 0, 1, 1, 0]])
watermark = generator.get_watermark(audio, sample_rate=16000, message=payload)
watermarked = audio + watermark

result, decoded_payload = detector.detect_watermark(watermarked, sample_rate=16000)
# result: [0, 1] 中的浮点数——水印存在的概率
# decoded_payload: 16 位；与嵌入的 payload 匹配
```

### 步骤 3：评估——EER

```python
def eer(real_scores, fake_scores):
    thresholds = sorted(set(real_scores + fake_scores))
    best = (1.0, 0.0)
    for t in thresholds:
        far = sum(1 for s in fake_scores if s >= t) / len(fake_scores)
        frr = sum(1 for s in real_scores if s < t) / len(real_scores)
        if abs(far - frr) < best[0]:
            best = (abs(far - frr), (far + frr) / 2)
    return best[1]
```

### 步骤 4：生产集成

```python
def safe_tts(text, voice, clone_reference=None):
    if clone_reference is not None:
        verify_consent(user_id, clone_reference)
    audio = tts_model.synthesize(text, voice)
    audio_with_wm = audioseal_embed(audio, payload=build_payload(user_id, model_id))
    manifest = c2pa_sign(audio_with_wm, user_id, timestamp=now())
    return audio_with_wm, manifest
```

每个生成都附带：(1) 水印，(2) 签名清单，(3) 符合保留策略的审计日志。

## 使用

| 用例 | 防御 |
|----------|---------|
| 发布 TTS / 声音克隆 | 每个输出上嵌入 AudioSeal（不可协商） |
| 生物识别语音解锁 | AASIST + ECAPA 集成；活体挑战 |
| 呼叫中心欺诈检测 | 20% 来电样本上的 AASIST |
| 播客真实性 | 上传时 C2PA 签名，如果是 AI 生成则用 AudioSeal |
| 研究 / 训练检测器 | ASVspoof 5 train/dev/eval 集 |

## 2026 年仍会发布的陷阱

- **水印嵌入后检测器从未运行过。** 无意义。在你的 CI 中发布检测器。
- **检测未校准。** 在 ASVspoof LA 上训练的 AASIST 过拟合；真实世界准确度下降。在你的领域上校准。
- **音高偏移缺口。** 激进音高偏移移除大多数水印。有检测回退。
- **元数据剥离后重新托管。** C2PA 通过重新编码可轻易绕过。始终结合加密 + 感知（水印）防御。
- **活体即检测。** 要求用户说随机短语。防止重放攻击但不防止实时克隆。

## 交付

保存为 `outputs/skill-spoof-defender.md`。为声音生成部署选择检测模型、水印、出处清单和操作手册。

## 练习

1. **简单。** 运行 `code/main.py`。在合成音频上的玩具检测器 + 玩具水印嵌入/检测。
2. **中等。** 安装 `audioseal`，在 TTS 输出中嵌入 16 位 payload，重新解码。用噪声破坏音频并测量比特恢复准确率。
3. **困难。** 在 ASVspoof 2019 LA 上微调 RawNet2 或 AASIST。测量 EER。在 F5-TTS 生成片段的留出集上测试——查看 OOD 检测如何退化。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| ASVspoof | 基准 | 两年一度的挑战赛；2024 = ASVspoof 5。 |
| CM（对策） | 检测器 | 分类器：真实语音 vs 合成 / 转换。 |
| SASV | 说话人验证 + CM | 集成生物识别 + 欺骗检测。 |
| AudioSeal | Meta 水印 | 本地化，16 位 payload，比 WavMark 快 485 倍。 |
| 比特恢复准确率 | 水印存活率 | 攻击后恢复的 payload 比特比例。 |
| C2PA | 出处清单 | 关于创建 / 作者的加密元数据。 |
| AASIST | 检测器家族 | 基于图注意力的反欺骗最先进。 |

## 扩展阅读

- [Todisco et al. (2024). ASVspoof 5](https://dl.acm.org/doi/10.1016/j.csl.2025.101825)——当前基准。
- [Defossez et al. (2024). AudioSeal](https://arxiv.org/abs/2401.17264)——水印默认。
- [Chen et al. (2025). WaveVerify](https://arxiv.org/abs/2507.21150)——时序攻击的 MoE 检测器。
- [Jung et al. (2022). AASIST](https://arxiv.org/abs/2110.01200)——最先进的检测骨干。
- [AudioMarkBench (2024)](https://proceedings.neurips.cc/paper_files/paper/2024/file/5d9b7775296a641a1913ab6b4425d5e8-Paper-Datasets_and_Benchmarks_Track.pdf)——鲁棒性评估。
- [C2PA 规范](https://c2pa.org/specifications/specifications/)——出处清单格式。