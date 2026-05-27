# 语音活动检测与轮次管理——Silero、Cobra 和 Flush 技巧

> 每个语音代理的成败取决于两个决策：用户现在在说话吗，他们说完没？VAD 回答第一个。轮次检测（VAD + 静音保持 + 语义端点模型）回答第二个。任何一个搞错，你的助手要么截断用户，要么永远不闭嘴。

**类型：** 构建
**语言：** Python
**前置要求：** 第 6 阶段 · 11（实时音频），第 6 阶段 · 12（语音助手）
**时间：** 约 45 分钟

## 问题

语音代理在每个 20 ms 分块上做出的三个不同决策：

1. **这一帧是语音吗？**——VAD。二值，逐帧。
2. **用户开始新话语了吗？**——起始检测。
3. **用户说完了吗？**——端点检测（轮次结束）。

朴素的答案（能量阈值）在任何噪声上都失效——交通、键盘、人群嘈杂声。2026 年的答案：Silero VAD（开源、深度学习）+ 轮次检测模型（语义端点检测）+ VAD 校准的静音保持。

## 概念

![VAD 级联：能量 → Silero → 轮次检测器 → flush 技巧](../assets/vad-turn-taking.svg)

### 三层 VAD 级联

**第 1 层：能量门控。** 最便宜。-40 dBFS 阈值 RMS。过滤明显静音，但在任何超过阈值的噪声上触发。

**第 2 层：Silero VAD**（2020-2026，MIT）。1M 参数。在 6000+ 语言上训练。单个 CPU 线程每 30 ms 分块约 1 ms 运行。5% FPR 下 87.7% TPR。开源默认。

**第 3 层：语义轮次检测器。** LiveKit 的轮次检测模型（2024-2026）或你自己的小分类器。区分"句中停顿"和"说完了"。使用语言上下文（语调 + 最近的词），而不仅仅是静音。

### 关键参数及其默认值

- **阈值。** Silero 输出概率；在 > 0.5（默认）或 > 0.3（敏感）时分类为语音。更低阈值 = 更少首词截断，更多误报。
- **最小语音时长。** 拒绝短于 250 ms 的语音——通常是咳嗽或椅子噪音。
- **静音保持（端点检测）。** VAD 回到 0 后，等待 500-800 ms 再宣布轮次结束。太短 → 打断用户。太长 → 感觉迟缓。
- **预滚缓冲区。** 在 VAD 触发前保留 300-500 ms 音频。防止"嘿"被截断。

### Flush 技巧（Kyutai 2025）

流式 STT 模型有前瞻延迟（Kyutai STT-1B 为 500 ms，STT-2.6B 为 2.5 秒）。通常你在语音结束后要等那么久才能拿到转录。Flush 技巧：当 VAD 触发语音结束，**向 STT 发送 flush 信号**强制立即输出。STT 以约 4 倍实时处理，所以 500 ms 缓冲区约 125 ms 完成。

端到端：125 ms VAD + flush STT = 对话级延迟。

### 2026 VAD 比较

| VAD | TPR @ 5% FPR | 延迟 | 许可 |
|-----|--------------|---------|---------|
| WebRTC VAD（Google，2013） | 50.0% | 30 ms | BSD |
| Silero VAD（2020-2026） | 87.7% | ~1 ms | MIT |
| Cobra VAD（Picovoice） | 98.9% | ~1 ms | 商业 |
| pyannote 分割 | 95% | ~10 ms | MIT 类似 |

Silero 是正确的默认。Cobra 是合规 / 准确度的升级。纯能量 VAD 在 2026 年的生产中没有任何位置。

## 构建

### 步骤 1：能量门控

```python
def energy_vad(chunk, threshold_dbfs=-40.0):
    rms = (sum(x * x for x in chunk) / len(chunk)) ** 0.5
    dbfs = 20.0 * math.log10(max(rms, 1e-10))
    return dbfs > threshold_dbfs
```

### 步骤 2：Python 中 Silero VAD

```python
from silero_vad import load_silero_vad, get_speech_timestamps

vad = load_silero_vad()
audio = torch.tensor(waveform_16k, dtype=torch.float32)
segments = get_speech_timestamps(
    audio, vad, sampling_rate=16000,
    threshold=0.5,
    min_speech_duration_ms=250,
    min_silence_duration_ms=500,
    speech_pad_ms=300,
)
for s in segments:
    print(f"{s['start']/16000:.2f}s - {s['end']/16000:.2f}s")
```

### 步骤 3：轮次结束状态机

```python
class TurnDetector:
    def __init__(self, silence_hangover_ms=500, min_speech_ms=250):
        self.state = "idle"
        self.speech_ms = 0
        self.silence_ms = 0
        self.silence_hangover_ms = silence_hangover_ms
        self.min_speech_ms = min_speech_ms

    def update(self, is_speech, chunk_ms=20):
        if is_speech:
            self.speech_ms += chunk_ms
            self.silence_ms = 0
            if self.state == "idle" and self.speech_ms >= self.min_speech_ms:
                self.state = "speaking"
                return "START"
        else:
            self.silence_ms += chunk_ms
            if self.state == "speaking" and self.silence_ms >= self.silence_hangover_ms:
                self.state = "idle"
                self.speech_ms = 0
                return "END"
        return None
```

### 步骤 4：flush 技巧骨架

```python
def flush_on_end(stt_client, audio_buffer):
    stt_client.send_audio(audio_buffer)
    stt_client.send_flush()
    return stt_client.recv_transcript(timeout_ms=150)
```

STT（Kyutai、Deepgram、AssemblyAI）必须支持 flush 才能工作。Whisper streaming 不支持——它是基于块的，始终等待分块。

## 使用

| 场景 | VAD 选择 |
|-----------|-----------|
| 开源、快速、通用 | Silero VAD |
| 商业呼叫中心 | Cobra VAD |
| 设备端（手机） | Silero VAD ONNX |
| 研究 / 说话人分离 | pyannote 分割 |
| 零依赖回退 | WebRTC VAD（遗留） |
| 需要轮次结束质量 | Silero + LiveKit 轮次检测器分层 |

经验法则：除非你真的别无选择，否则永远不要发布纯能量 VAD。

## 2026 年仍会发布的陷阱

- **固定阈值。** 在安静中有效，在嘈杂中失效。要么在设备上校准，要么切换到 Silero。
- **太短的静音保持。** 代理在句中截断。500-800 ms 是对话语速的甜点。
- **太长的保持。** 感觉迟缓。与目标用户进行 A/B 测试。
- **无预滚缓冲区。** 用户音频的前 200-300 ms 丢失。始终保持滚动的预滚。
- **忽略语义端点检测。** "Hmm, let me think..." 包含长停顿。用户讨厌在思考中被截断。使用 LiveKit 的轮次检测器或类似工具。

## 交付

保存为 `outputs/skill-vad-tuner.md`。为工作负载选择 VAD 模型、阈值、保持、预滚和轮次检测策略。

## 练习

1. **简单。** 运行 `code/main.py`。模拟语音 + 静音 + 语音 + 咳嗽序列并测试三个 VAD 层级。
2. **中等。** 安装 `silero-vad`，处理 5 分钟录音，调优阈值以最小化首词截断和误触发。报告精确率/召回率。
3. **困难。** 构建一个迷你轮次检测器：Silero VAD + 在最后 10 个单词嵌入上的 3 层 MLP（使用 sentence-transformers）。在手工标注的轮次结束数据集上训练。以 10% F1 击败纯 Silero。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| VAD | 语音检测器 | 逐帧二值：这是语音吗？ |
| 轮次检测 | 端点检测 | VAD + 静音保持 + 语义端点。 |
| 静音保持 | 语音后等待 | 声明轮次结束前的等待时间；500-800 ms。 |
| 预滚 | 语音前缓冲区 | 在 VAD 触发前保留 300-500 ms 音频。 |
| Flush 技巧 | Kyutai 黑科技 | VAD → flush-STT → 125 ms 而非 500 ms 延迟。 |
| 语义端点 | "他们意思说完了吗？" | 查看单词而不仅仅是静音的 ML 分类器。 |
| TPR @ FPR 5% | ROC 点 | 标准 VAD 基准；Silero 87.7%，WebRTC 50%。 |

## 扩展阅读

- [Silero VAD](https://github.com/snakers4/silero-vad)——参考开源 VAD。
- [Picovoice Cobra VAD](https://picovoice.ai/products/cobra/)——商业准确度领先者。
- [Kyutai——Unmute + flush 技巧](https://kyutai.org/stt)——低于 200 ms 的工程技巧。
- [LiveKit——轮次检测](https://docs.livekit.io/agents/logic/turns/)——生产中的语义端点检测。
- [WebRTC VAD](https://webrtc.googlesource.com/src/)——遗留基线。
- [pyannote 分割](https://github.com/pyannote/pyannote-audio)——说话人分离级别的分割。