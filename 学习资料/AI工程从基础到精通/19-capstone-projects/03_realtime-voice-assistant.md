# 综合项目 03 —— 实时语音助手（ASR 到 LLM 到 TTS）

> 一个感觉好的语音 agent，端到端延迟低于 800ms，知道用户何时停止说话，能处理打断，能调用工具而不卡顿。Retell、Vapi、LiveKit Agents 和 Pipecat 在 2026 年都达到了这个标准。它们采用相同的架构：流式 ASR、轮次检测器、流式 LLM 和流式 TTS，全部通过 WebRTC 连接，每一跳都有严格的延迟预算。构建一个，度量 WER、MOS 和错误截断率，并在丢包条件下运行。

**类型：** 综合项目
**语言：** Python（agent + 管道），TypeScript（Web 客户端）
**前置知识：** Phase 6（语音与音频），Phase 7（transformers），Phase 11（LLM 工程），Phase 13（工具），Phase 14（Agent），Phase 17（基础设施）
**涉及的 Phase：** P6 · P7 · P11 · P13 · P14 · P17
**时间：** 30 小时

## 问题

语音是 2025-2026 年变化最快的 AI 用户体验类别。技术上限每个季度都在下降。OpenAI Realtime API、Gemini 2.5 Live、Cartesia Sonic-2、ElevenLabs Flash v3、LiveKit Agents 1.0 和 Pipecat 0.0.70 都使低于 800ms 的首段音频输出成为现实。标准不仅仅是延迟。它是交互感觉：不打断用户、不被用户打断、从句子中间的中断中恢复、在对话中途调用工具而不使音频卡顿、在抖动的移动网络中存活。

你无法通过拼接三个 REST 调用来达到这个目标。架构是端到端的管道化流式处理。构建它，失效模式会变得可见：一个为电话音频调优的 VAD 在背景电视上触发、一个等待永远不会出现的标点符号的轮次检测器、一个在发出前缓冲 400ms 的 TTS。综合项目是在负载下一一修复这些问题，并发布延迟和质量报告。

## 概念

管道有五个流式阶段：**音频输入**（来自浏览器或 PSTN 的 WebRTC）、**ASR**（来自 Deepgram Nova-3 或 faster-whisper 的流式部分转录）、**轮次检测**（VAD 加上一个读取部分转录以寻找完成线索的小型轮次检测器模型）、**LLM**（一旦判定轮次完成即流式输出 token）、**TTS**（在第一个 LLM token 后约 200ms 内流式输出音频）。

三个横切关注点。**打断（Barge-in）**：当用户在 agent 说话时开始说话，TTS 取消，ASR 立即接管。**工具使用**：对话中途的函数调用（天气、日历）必须在不使音频卡顿的侧通道上运行；如果延迟超过 300ms，agent 预先输出一个确认 token（"请稍等……"）。**背压（Backpressure）**：在丢包情况下，部分转录被搁置，VAD 提高语音门限，agent 避免在未确认消息上继续说话。

度量标准是量化的。在 15 dB SNR 的 Hamming VAD 基准上 WER 低于 8%。在 100 个测量通话上首段音频输出 p50 低于 800ms。错误截断率低于 3%。TTS MOS 高于 4.2。单个 g5.xlarge 上 50 并发通话。这些数字就是可交付成果。

## 架构

```
browser / Twilio PSTN
        |
        v
   WebRTC / SIP edge
        |
        v
  LiveKit Agents 1.0  (或 Pipecat 0.0.70)
        |
   +----+--------------+--------------+-----------------+
   |                   |              |                 |
   v                   v              v                 v
  ASR              VAD v5         轮次检测器         侧通道
(Deepgram         (Silero)          (LiveKit)        工具
 Nova-3 /         每 20ms         对部分转录         (天气,
 Whisper-v3)      语音门限        完成度评分          日历)
   |                   |              |
   +--------+----------+--------------+
            v
        LLM (流式)
     GPT-4o-realtime / Gemini 2.5 Flash /
     级联 Claude Haiku 4.5
            |
            v
        TTS 流式
     Cartesia Sonic-2 / ElevenLabs Flash v3
            |
            v
     音频返回给呼叫者
            |
            v
   OpenTelemetry 语音 traces -> Langfuse
```

## 技术栈

- 传输：LiveKit Agents 1.0（WebRTC）加 Twilio PSTN 网关；Pipecat 0.0.70 作为替代框架
- ASR：Deepgram Nova-3（流式，首次部分转录低于 300ms）或自托管的 faster-whisper Whisper-v3-turbo
- VAD：Silero VAD v5 加 LiveKit 轮次检测器（读取部分转录的小型 transformer）
- LLM：OpenAI GPT-4o-realtime 用于紧密集成，Gemini 2.5 Flash Live，或级联 Claude Haiku 4.5（流式补全，独立的音频路径）
- TTS：Cartesia Sonic-2（最低首字节延迟），ElevenLabs Flash v3，或自托管开源 Orpheus
- 工具：FastMCP 侧通道用于天气/日历/预订；如果工具耗时超过 300ms，agent 预先发出填充词
- 可观测性：OpenTelemetry 语音 span，Langfuse 语音 traces 带音频回放
- 部署：单个 g5.xlarge（24GB VRAM）用于自托管 Whisper + Orpheus；最低延迟使用托管 API

## 构建步骤

1. **WebRTC 会话。** 启动一个 LiveKit 房间和一个流式传输麦克风音频的 Web 客户端。在服务器上，附加一个加入房间的 agent worker。

2. **ASR 流式。** 将 20ms PCM 帧送入 Deepgram Nova-3（或 GPU 上的 faster-whisper）。订阅部分和最终转录。记录每次部分转录的延迟。

3. **VAD 和轮次检测器。** 在帧流上运行 Silero VAD v5。在语音结束事件上，对最新部分转录触发 LiveKit 轮次检测器。仅当 VAD 显示静音 500ms 且轮次检测器完成度评分 > 0.6 时，才确认"轮次完成"。

4. **LLM 流。** 轮次完成后，用对话上下文加上最终转录开始 LLM 调用。流式输出 token。在第一个 token 处，转交给 TTS。

5. **TTS 流。** Cartesia Sonic-2 流式返回音频块。第一个块必须在第一个 LLM token 后 200ms 内离开服务器。将块发送到 LiveKit 房间；客户端通过 WebRTC 抖动缓冲区播放。

6. **打断。** 当 VAD 在 TTS 播放期间检测到新的用户语音时，立即取消 TTS 流，丢弃剩余 LLM 输出，并重新启用 ASR。发布 `tts_canceled` span。

7. **工具侧通道。** 将天气和日历注册为函数调用工具。调用时，并发发起调用；如果在 300ms 内未解决，让 LLM 发出"请稍等，让我查看一下"作为填充词；工具返回后恢复。

8. **评估框架。** 录制 100 个通话。计算 WER（对照留出转录）、错误截断率（用户在句子中间时 TTS 被取消）、首段音频输出 p50、TTS MOS（人工或 NISQA），以及抖动丢包测试（丢弃 3% 数据包）。

9. **负载测试。** 在单个 g5.xlarge 上使用合成呼叫者驱动 50 并发通话。度量持续的首段音频输出 p95。

## 使用方式

```
caller: "what is the weather in tokyo tomorrow"
[asr  ] partial @280ms: "what is the"
[asr  ] partial @540ms: "what is the weather"
[turn ] completion score 0.82 at @820ms; commit
[llm  ] first token @960ms
[tool ] weather.tokyo tomorrow -> 68/52 partly cloudy @1140ms
[tts  ] first audio-out @1040ms: "Tokyo tomorrow will be partly cloudy..."
turn latency: 1040ms user-stop -> audio-out
```

## 产出

`outputs/skill-voice-agent.md` 是可交付成果。给定一个领域（客服、预约或信息亭），启动一个 LiveKit agent，ASR/VAD/LLM/TTS 管道调优到度量标准。评分标准：

| 权重 | 标准 | 度量方式 |
|:-:|---|---|
| 25 | 端到端延迟 | 100 个录制通话中的首段音频输出 p50 低于 800ms |
| 20 | 轮次轮流质量 | Hamming VAD 基准上的错误截断率低于 3% |
| 20 | 工具使用正确性 | 对话中途工具调用正确返回数据且不使音频卡顿 |
| 20 | 丢包下的可靠性 | 注入 3% 丢包下的 WER 和轮次轮流稳定性 |
| 15 | 评估框架完整性 | 可复现的度量，附公开配置 |
| **100** | | |

## 练习

1. 在 g5.xlarge 上将 Deepgram Nova-3 替换为 faster-whisper v3 turbo。度量延迟和 WER 差距。识别 CPU vs GPU 决策的关键点。

2. 添加一个打断仲裁策略：当用户在工具调用期间打断时，agent 该怎么做？比较三种策略（硬取消、完成工具然后停止、排队下一轮次）。

3. 运行对抗性轮次检测器测试：给用户句子中间的长停顿。调优 VAD 静音阈值和轮次检测器评分阈值，在不超出 900ms 的情况下实现最低错误截断率。

4. 通过 Twilio 在 PSTN 上部署相同的 agent。比较 PSTN 首段音频输出与 WebRTC。解释抖动缓冲区和编解码器差异。

5. 为非英语语言（日语、西班牙语）添加语音活动检测。度量 Silero VAD v5 错误触发率 vs 语言特定的微调模型。

## 关键术语

| 术语 | 人们常说的 | 实际含义 |
|------|-----------|---------|
| 轮次检测（Turn Detection） | "话语结束" | 给定 VAD 静音和部分转录，判断用户是否说完的分类器 |
| 打断（Barge-in） | "中断处理" | VAD 检测到新用户语音时取消 TTS 播放 |
| 首段音频输出（First-audio-out） | "延迟" | 从用户停止说话到第一个音频数据包离开服务器的时间 |
| VAD | "语音门限" | 将音频帧分类为语音与静音的模型；Silero VAD v5 是 2026 年默认选择 |
| 抖动缓冲区（Jitter Buffer） | "音频平滑" | 客户端缓冲区，短暂保持数据包以吸收网络变化 |
| 填充词（Filler） | "确认 token" | 当工具较慢时 agent 发出的短短语以避免静音 |
| MOS | "平均意见评分" | 感知语音质量评分；NISQA 是自动化代理指标 |

## 扩展阅读

- [LiveKit Agents 1.0](https://github.com/livekit/agents) —— 参考 WebRTC agent 框架
- [Pipecat](https://github.com/pipecat-ai/pipecat) —— 替代的 Python 优先流式 agent 框架
- [OpenAI Realtime API](https://platform.openai.com/docs/guides/realtime) —— 集成语音模型参考
- [Deepgram Nova-3 documentation](https://developers.deepgram.com/docs) —— 流式 ASR 参考
- [Silero VAD v5](https://github.com/snakers4/silero-vad) —— VAD 参考模型
- [Cartesia Sonic-2](https://docs.cartesia.ai) —— 低延迟 TTS 参考
- [Retell AI architecture](https://docs.retellai.com) —— 生产环境语音 agent 架构
- [Vapi.ai production stack](https://docs.vapi.ai) —— 替代的生产环境参考