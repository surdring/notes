# 实时音频处理

> 批量流水线处理文件。实时流水线在下一个 20 毫秒到达之前处理当前这 20 毫秒。每个对话式 AI、广播工作室和电话机器人都取决于这个延迟预算的成败。

**类型：** 构建
**语言：** Python、Rust
**前置要求：** 第 6 阶段 · 02（频谱图），第 6 阶段 · 04（ASR），第 6 阶段 · 07（TTS）
**时间：** 约 75 分钟

## 问题

你想要一个感觉鲜活的语音助手。人类对话轮换延迟约为 230 ms（静音到响应）。超过 500 ms 感觉机械；超过 1500 ms 感觉坏了。2026 年完整 **听 → 理解 → 响应 → 说话** 循环的预算为：

| 阶段 | 预算 |
|-------|--------|
| 麦克风 → 缓冲区 | 20 ms |
| VAD | 10 ms |
| ASR（流式） | 150 ms |
| LLM（首个标记） | 100 ms |
| TTS（首个分块） | 100 ms |
| 渲染 → 扬声器 | 20 ms |
| **总计** | **约 400 ms** |

Moshi（Kyutai，2024）实现 200 ms 全双工。GPT-4o-realtime（2024）约 320 ms。2022 年的级联流水线以 2500 ms 发布。10 倍改进来自三种技术：(1) 处处流式，(2) 带部分结果的异步流水线，(3) 可中断生成。

## 概念

![带环形缓冲区、VAD 门控、中断的流式音频流水线](../assets/real-time.svg)

**帧 / 分块 / 窗口。** 实时音频以固定大小块流动。常见选择：20 ms（16 kHz 下 320 采样）。所有下游必须跟上这个节奏。

**环形缓冲区。** 固定大小的循环缓冲区。生产者线程写入新帧，消费者线程读取。防止热路径中的内存分配。大小 ≈ 最大延迟 × 采样率；2 秒 16 kHz 环形 = 32000 采样。

**VAD（语音活动检测）。** 当没有人说话时门控下游工作。Silero VAD 4.0（2024）在 CPU 上每 30 ms 帧运行 <1 ms。`webrtcvad` 是较旧的替代方案。

**流式 ASR。** 在音频到达时发出部分转录的模型。流式模式下的 Parakeet-CTC-0.6B（NeMo，2024）在 320 ms 延迟下实现 2-5% WER。Whisper-Streaming（Macháček et al.，2023）分块 Whisper 实现约 2 秒延迟的近流式。

**中断。** 当用户在助手说话时说话，你必须 (a) 检测打断，(b) 停止 TTS，(c) 丢弃剩余的 LLM 输出。全部在 100 ms 内，否则用户会感觉到聋的助手。

**WebRTC Opus 传输。** 20 ms 帧，48 kHz，自适应比特率 8-128 kbps。浏览器和移动端标准。LiveKit、Daily.co、Pion 是 2026 年构建语音应用的技术栈。

**抖动缓冲区。** 网络数据包乱序/延迟到达。抖动缓冲区重新排序和平滑；太小 → 可听间隙，太大 → 延迟。典型 60-80 ms。

### 常见陷阱

- **线程争用。** Python 的 GIL + 重模型可能饿死音频线程。使用 C 回调音频库（sounddevice、PortAudio）并将 Python 移出热路径。
- **采样率转换延迟。** 流水线内的重采样增加 5-20 ms。要么预先重采样，要么使用零延迟重采样器（PolyPhase、`soxr_hq`）。
- **TTS 预热。** 即使像 Kokoro 这样的快速 TTS 在第一次请求时也有 100-200 ms 预热。缓存模型 + 在第一次真实轮次前用虚拟运行预热它。
- **回声消除。** 没有 AEC，TTS 输出重新进入麦克风并在机器人自己的声音上触发 ASR。WebRTC AEC3 是开源默认。

## 构建

### 步骤 1：环形缓冲区

```python
import collections

class RingBuffer:
    def __init__(self, capacity):
        self.buf = collections.deque(maxlen=capacity)
    def write(self, frame):
        self.buf.extend(frame)
    def read(self, n):
        return [self.buf.popleft() for _ in range(min(n, len(self.buf)))]
    def level(self):
        return len(self.buf)
```

容量决定最大缓冲延迟。16 kHz 下 32000 采样 = 2 秒。

### 步骤 2：VAD 门控

```python
def simple_energy_vad(frame, threshold=0.01):
    return sum(x * x for x in frame) / len(frame) > threshold ** 2
```

在生产中替换为 Silero VAD：

```python
import torch
vad, _ = torch.hub.load("snakers4/silero-vad", "silero_vad")
is_speech = vad(torch.tensor(frame), 16000).item() > 0.5
```

### 步骤 3：流式 ASR

```python
# 通过 NeMo 的 Parakeet-CTC-0.6B 流式
from nemo.collections.asr.models import EncDecCTCModelBPE
asr = EncDecCTCModelBPE.from_pretrained("nvidia/parakeet-ctc-0.6b")
# chunk_ms=320 ms, look_ahead_ms=80 ms
for chunk in audio_stream():
    partial_text = asr.transcribe_streaming(chunk)
    print(partial_text, end="\r")
```

### 步骤 4：中断处理器

```python
class Dialog:
    def __init__(self):
        self.tts_task = None

    def on_user_speech(self, frame):
        if self.tts_task and not self.tts_task.done():
            self.tts_task.cancel()   # 打断
        # 然后喂入流式 ASR

    def on_final_user_utterance(self, text):
        self.tts_task = asyncio.create_task(self.reply(text))

    async def reply(self, text):
        async for tts_chunk in llm_then_tts(text):
            speaker.write(tts_chunk)
```

关键在于异步 I/O 和可取消的 TTS 流。音频轨道上的 WebRTC peerconnection.stop() 是规范方式。

## 使用

2026 年技术栈：

| 层 | 选择 |
|------|------|
| 传输 | LiveKit（WebRTC）或 Pion（Go） |
| VAD | Silero VAD 4.0 |
| 流式 ASR | Parakeet-CTC-0.6B 或 Whisper-Streaming |
| LLM 首个标记 | Groq、Cerebras、vLLM-streaming |
| 流式 TTS | Kokoro 或 ElevenLabs Turbo v2.5 |
| 回声消除 | WebRTC AEC3 |
| 端到端原生 | OpenAI Realtime API 或 Moshi |

## 2026 年仍会发布的陷阱

- **为安全缓冲 500 ms。** 缓冲区*就是*你的延迟下限。缩小它。
- **不固定线程。** 优先级低于 UI 的音频回调 = 负载下的毛刺。
- **TTS 分块太小。** 低于 200 ms 的分块使声码器伪影可闻。320 ms 分块是甜点。
- **无抖动缓冲区。** 真实网络有抖动；不平滑你就是爆音。
- **单次错误处理。** 音频流水线必须是防崩溃的。一次异常就杀死会话。

## 交付

保存为 `outputs/skill-realtime-designer.md`。设计一个有每个阶段具体延迟预算的实时音频流水线。

## 练习

1. **简单。** 运行 `code/main.py`。模拟环形缓冲区 + 能量 VAD；打印假 10 秒流的阶段延迟。
2. **中等。** 使用 `sounddevice`，构建一个环回，以 20 ms 帧处理你的麦克风并在每帧打印 VAD 状态。
3. **困难。** 用 `aiortc` 构建完整双工回声测试：浏览器 → WebRTC → Python → WebRTC → 浏览器。用 1 kHz 脉冲测量端到端延迟。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| 环形缓冲区 | 循环队列 | 固定大小、无锁（或 SPSC 锁）FIFO 用于音频帧。 |
| VAD | 静音门控 | 标记语音 vs 非语音的模型或启发式。 |
| 流式 ASR | 实时 STT | 音频到达时发出部分文本；有界前瞻。 |
| 抖动缓冲区 | 网络平滑器 | 重新排序乱序包的队列；典型 60-80 ms。 |
| AEC | 回声消除 | 减去扬声器到麦克风的反馈路径。 |
| 打断 | 用户中断 | 系统在 TTS 中间检测到用户语音；必须取消播放。 |
| 全双工 | 同时双向 | 用户和机器人可以同时说话；Moshi 是全双工。 |

## 扩展阅读

- [Macháček et al. (2023). Whisper-Streaming](https://arxiv.org/abs/2307.14743)——分块近流式 Whisper。
- [Kyutai (2024). Moshi](https://kyutai.org/Moshi.pdf)——全双工 200 ms 延迟。
- [LiveKit Agents 框架 (2024)](https://docs.livekit.io/agents/)——生产音频代理编排。
- [Silero VAD 仓库](https://github.com/snakers4/silero-vad)——低于 1 ms VAD，Apache 2.0。
- [WebRTC AEC3 论文](https://webrtc.googlesource.com/src/+/main/modules/audio_processing/aec3/)——开源下的回声消除。