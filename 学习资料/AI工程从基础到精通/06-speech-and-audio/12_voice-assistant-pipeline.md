# 构建语音助手流水线——第 6 阶段顶点项目

> 第 01-11 课的所有内容缝合在一起。构建一个听、推理和回话的语音助手。在 2026 年，这是一个已解决的工程问题，而非研究问题——但集成细节决定了它能否发布。

**类型：** 构建
**语言：** Python
**前置要求：** 第 6 阶段 · 04、05、06、07、11；第 11 阶段 · 09（函数调用）；第 14 阶段 · 01（代理循环）
**时间：** 约 120 分钟

## 问题

构建端到端助手：

1. 捕获麦克风输入（16 kHz 单声道）。
2. 检测用户语音的开始/结束。
3. 流式转录。
4. 将转录传递给可以调用工具的 LLM（计时器、天气、日历）。
5. 将 LLM 文本流式传送到 TTS。
6. 播放音频给用户。
7. 如果用户在回复中打断则停止。

延迟目标：在笔记本 CPU 上，用户说完话语后的 800 ms 内首个 TTS 音频字节到达。质量目标：无遗漏词、无静音幻觉字幕、无声音克隆泄漏、无提示注入成功。

## 概念

![语音助手流水线：麦克风 → VAD → STT → LLM+工具 → TTS → 扬声器](../assets/voice-assistant.svg)

### 七个组件

1. **音频捕获。** 麦克风 → 16 kHz 单声道 → 20 ms 分块。Python 中通常是 `sounddevice`，生产中为原生 AudioUnit/ALSA/WASAPI。
2. **VAD（第 11 课）。** Silero VAD @ 阈值 0.5，最小语音 250 ms，静音保持 500 ms。信号"开始"和"结束"。
3. **流式 STT（第 4-5 课）。** Whisper-streaming、Parakeet-TDT 或 Deepgram Nova-3（API）。部分 + 最终转录。
4. **带工具调用的 LLM。** GPT-4o / Claude 3.5 / Gemini 2.5 Flash。工具的 JSON schema。流式标记。
5. **流式 TTS（第 7 课）。** Kokoro-82M（最快开源）或 Cartesia Sonic（商业）。在 20 个 LLM 标记后启动 TTS。
6. **播放。** 扬声器输出；对低带宽网络进行 Opus 编码。
7. **中断处理器。** 如果 VAD 在 TTS 播放期间触发，停止播放，取消 LLM，重启 STT。

### 你会遇到的三种失败模式

1. **首词截断。** VAD 启动晚了一拍。用户的"嘿"丢失了。起始阈值设为 0.3，不是 0.5。
2. **回复中中断混乱。** LLM 在用户中断后继续生成；助手抢话。将 VAD 连接到取消 LLM。
3. **静音幻觉。** Whisper 在静音预热帧上输出"Thanks for watching"。始终 VAD 门控。

### 2026 生产参考技术栈

| 技术栈 | 延迟 | 许可 | 备注 |
|-------|---------|---------|-------|
| LiveKit + Deepgram + GPT-4o + Cartesia | 350-500 ms | 商业 API | 2026 行业默认 |
| Pipecat + Whisper-streaming + GPT-4o + Kokoro | 500-800 ms | 主要是开源 | 适合 DIY |
| Moshi（全双工） | 200-300 ms | CC-BY 4.0 | 单一模型；不同架构，第 15 课 |
| Vapi / Retell（托管） | 300-500 ms | 商业 | 最快启动；有限定制 |
| Whisper.cpp + llama.cpp + Kokoro-ONNX | 离线 | 开源 | 隐私 / 边缘 |

## 构建

### 步骤 1：带分块的麦克风捕获（伪代码）

```python
import sounddevice as sd

def mic_stream(chunk_ms=20, sr=16000):
    q = queue.Queue()
    def cb(indata, frames, time, status):
        q.put(indata.copy().flatten())
    with sd.InputStream(channels=1, samplerate=sr, blocksize=int(sr * chunk_ms/1000), callback=cb):
        while True:
            yield q.get()
```

### 步骤 2：VAD 门控轮次捕获

```python
def capture_turn(stream, vad, pre_roll_ms=300, silence_ms=500):
    buf, pre, triggered = [], collections.deque(maxlen=pre_roll_ms // 20), False
    silent = 0
    for chunk in stream:
        pre.append(chunk)
        if vad(chunk):
            if not triggered:
                buf = list(pre)
                triggered = True
            buf.append(chunk)
            silent = 0
        elif triggered:
            silent += 20
            buf.append(chunk)
            if silent >= silence_ms:
                return b"".join(buf)
```

### 步骤 3：流式 STT → LLM → TTS

```python
async def turn(audio_bytes):
    transcript = await stt.transcribe(audio_bytes)
    async for token in llm.stream(transcript):
        async for audio in tts.stream(token):
            await speaker.play(audio)
```

### 步骤 4：LLM 循环内的工具调用

```python
tools = [
    {"name": "get_weather", "parameters": {"location": "string"}},
    {"name": "set_timer", "parameters": {"seconds": "int"}},
]

async for chunk in llm.stream(user_text, tools=tools):
    if chunk.type == "tool_call":
        result = dispatch(chunk.name, chunk.args)
        continue_streaming(result)
    if chunk.type == "text":
        await tts.stream(chunk.text)
```

### 步骤 5：中断处理

```python
tts_task = asyncio.create_task(tts_loop())
while True:
    chunk = await mic.get()
    if vad(chunk):
        tts_task.cancel()
        await speaker.stop()
        await new_turn()
        break
```

## 使用

查看 `code/main.py` 获取一个可运行的模拟，它用桩模块连接所有七个组件，这样你即使没有硬件也能看到流水线形状。对于真实实现，将桩替换为：

- `silero-vad`（`pip install silero-vad`）
- `deepgram-sdk` 或 `openai-whisper`
- `openai`（`gpt-4o`）或 `anthropic`
- `kokoro` 或 `cartesia`
- `sounddevice` 用于 I/O

## 2026 年仍会发布的陷阱

- **永久记录 PII。** 完整轮次音频在大多数司法管辖区是 PII。30 天保留，静态加密。
- **无打断。** 用户会打断。你的助手必须停止说话。
- **阻塞 TTS。** 同步 TTS 阻塞事件循环。使用异步或单独线程。
- **无工具调用错误处理。** 工具会失败。LLM 必须回传错误 + 重试一次，然后优雅降级。
- **过度积极的幻觉过滤器。** 过度过滤则助手重复"I can't help with that"。过滤不足则它会说任何东西。在留出集上校准。
- **无唤醒词选项。** 始终监听是隐私风险。添加唤醒词门控（Porcupine 或 openWakeWord）。

## 交付

保存为 `outputs/skill-voice-assistant-architect.md`。给定预算 + 规模 + 语言 + 合规约束，生成完整技术栈规格。

## 练习

1. **简单。** 运行 `code/main.py`。它用桩模块模拟一次完整的端到端轮次并打印各阶段延迟。
2. **中等。** 在预录制的 `.wav` 上替换 STT 桩为真实 Whisper 模型。测量 WER 和端到端延迟。
3. **困难。** 添加工具调用：实现 `get_weather`（任意 API）和 `set_timer`。通过工具路由 LLM 并验证当用户说"set a 5 minute timer"时正确的函数触发并且语音回复确认了它。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| 轮次 | 用户 + 助手往返 | 一次 VAD 边界的用户语音 + 一次 LLM-TTS 响应。 |
| 打断 | 中断 | 用户在助手说话时说话；助手停止。 |
| 唤醒词 | "嘿，助手" | 短关键词检测器；Porcupine、Snowboy、openWakeWord。 |
| 端点检测 | 轮次结束 | VAD + 最小静音判定用户已完成。 |
| 预滚 | 语音前缓冲区 | 在 VAD 触发前保留 200-400 ms 音频以避免首词截断。 |
| 工具调用 | 函数调用 | LLM 发出 JSON；运行时调度；结果循环内回传。 |

## 扩展阅读

- [LiveKit——语音代理快速入门](https://docs.livekit.io/agents/)——生产级参考。
- [Pipecat——语音代理示例](https://github.com/pipecat-ai/pipecat)——适合 DIY 的框架。
- [OpenAI Realtime API](https://platform.openai.com/docs/guides/realtime)——托管语音原生路径。
- [Kyutai Moshi](https://github.com/kyutai-labs/moshi)——全双工参考（第 15 课）。
- [Porcupine 唤醒词](https://picovoice.ai/products/porcupine/)——唤醒词门控。
- [Anthropic——工具使用指南](https://docs.anthropic.com/en/docs/build-with-claude/tool-use)——LLM 函数调用。