# 流式语音到语音——Moshi、Hibiki 和全双工对话

> 2024-2026 年重新定义了语音 AI。Moshi 发布了一个单一模型，以 200 ms 延迟同时听和说。Hibiki 逐块进行语音到语音翻译。两者都放弃了 ASR → LLM → TTS 流水线，转而采用基于 Mimi 编解码器标记的统一全双工架构。这是新的参考设计。

**类型：** 学习
**语言：** Python
**前置要求：** 第 6 阶段 · 13（神经音频编解码器），第 6 阶段 · 11（实时音频），第 7 阶段 · 05（完整 Transformer）
**时间：** 约 75 分钟

## 问题

每个从第 11 + 12 课构建的语音代理都有一个约 300-500 ms 的基本延迟下限：VAD 触发、STT 处理、LLM 推理、TTS 生成。每个阶段都有其自己的最小延迟。你可以调优和并行化，但流水线的形状限制了上限。

Moshi（Kyutai，2024-2026）问了一个不同的问题：如果没有流水线呢？如果一个模型直接接收音频并直接发出音频，连续地，文本作为中间"内心独白"而非必需阶段？

答案是**全双工语音到语音**。理论延迟 160 ms（80 ms Mimi 帧 + 80 ms 声学延迟）。在单个 L4 GPU 上实际延迟 200 ms。这是最佳级联语音代理的一半。

## 概念

![Moshi 架构：两条并行 Mimi 流 + 内心独白文本](../assets/moshi-hibiki.svg)

### Moshi 架构

**输入。** 两条 Mimi 编解码器流，均在 12.5 Hz × 8 个码本：

- 流 1：用户音频（Mimi 编码，持续到达）
- 流 2：Moshi 自己的音频（Moshi 生成）

**Transformer。** 一个 7B 参数的时序 Transformer 处理两条流和一条文本"内心独白"流。在每个 80 ms 步骤中，它：

1. 消费最新的用户 Mimi 标记（8 个码本）。
2. 消费最近的 Moshi Mimi 标记（8 个码本，已生成）。
3. 生成下一个 Moshi 文本标记（内心独白）。
4. 生成下一个 Moshi Mimi 标记（通过小型深度 Transformer 的 8 个码本）。

所有三条流——用户音频、Moshi 音频、Moshi 文本——并行运行。Moshi 可以在说话时听到用户；可以在用户打断时自我中断；可以回馈（"嗯哼"）而不中断其主要话语。

**深度 Transformer。** 在一帧内，8 个码本不是并行预测的——它们有码本间依赖。一个小型 2 层"深度 Transformer"在 80 ms 内顺序预测它们。这是 AR 编解码器 LM 的标准分解（VALL-E、VibeVoice 也使用）。

### 为什么内心独白文本有帮助

没有显式文本，模型必须在其声学流中隐式建模语言。Moshi 的洞察：强制它同时发出文本标记和音频。文本流本质上是 Moshi 所说内容的转录。这提高了语义连贯性，使语言模型头的替换更容易，并免费提供转录。

### Hibiki：流式语音到语音翻译

相同架构，在翻译对上训练。源音频输入，目标语言音频输出，连续地。Hibiki-Zero（2026 年 2 月）消除了对词级对齐训练数据的需求——使用句子级数据 + GRPO 强化学习进行延迟优化。

初始支持四种语言对；可以用约 1000 小时适应新语言。

### 更广泛的 Kyutai 技术栈（2026）

- **Moshi**——全双工对话（法语优先，英语支持良好）
- **Hibiki / Hibiki-Zero**——同步语音翻译
- **Kyutai STT**——流式 ASR（500 ms 或 2.5 秒前瞻）
- **Kyutai Pocket TTS**——1 亿参数 TTS 在 CPU 上运行（2026 年 1 月）
- **Unmute**——在公共服务器上组合这些的完整流水线

L40S GPU 上的吞吐量：64 个并发会话，3 倍实时。

### Sesame CSM——表亲

Sesame CSM（2025）使用类似的想法——带 Mimi 编解码器头的 Llama-3 骨干。但 CSM 是单向的（接收上下文 + 文本，产生语音）而非全双工。它是市场上最好的"语音存在感"TTS；与 Moshi 的全双工能力不完全相同。

### 2026 性能数字

| 模型 | 延迟 | 用例 | 许可 |
|-------|---------|----------|---------|
| Moshi | 200 ms（L4） | 全双工英语/法语对话 | CC-BY 4.0 |
| Hibiki | 12.5 Hz 帧率 | 法语 ↔ 英语流式翻译 | CC-BY 4.0 |
| Hibiki-Zero | 相同 | 5 个语言对，无对齐数据 | CC-BY 4.0 |
| Sesame CSM-1B | 200 ms TTFA | 上下文条件 TTS | Apache-2.0 |
| GPT-4o Realtime | ~300 ms | 闭源，OpenAI API | 商业 |
| Gemini 2.5 Live | ~350 ms | 闭源，Google API | 商业 |

## 构建

### 步骤 1：接口

Moshi 暴露一个 WebSocket 服务器，接收 80 ms 的 Mimi 编码音频分块并返回 80 ms 的 Mimi 编码音频分块。双向。持续地。

```python
import asyncio
import websockets
from moshi.client_utils import encode_audio_mimi, decode_audio_mimi

async def moshi_chat():
    async with websockets.connect("ws://localhost:8998/api/chat") as ws:
        mic_task = asyncio.create_task(stream_mic_to(ws))
        spk_task = asyncio.create_task(stream_from_to_speaker(ws))
        await asyncio.gather(mic_task, spk_task)
```

### 步骤 2：全双工循环

```python
async def stream_mic_to(ws):
    async for chunk_80ms in mic_stream_at_12_5_hz():
        mimi_tokens = encode_audio_mimi(chunk_80ms)
        await ws.send(serialize(mimi_tokens))

async def stream_from_to_speaker(ws):
    async for msg in ws:
        mimi_tokens, text_token = deserialize(msg)
        audio = decode_audio_mimi(mimi_tokens)
        await play(audio)
```

两个方向同时运行。Python asyncio 或 Rust futures 是标准传输方式。

### 步骤 3：训练目标（概念）

对于每个 80 ms 帧 `t`：

- 输入：`user_mimi[0..t]`, `moshi_mimi[0..t-1]`, `moshi_text[0..t-1]`
- 预测：`moshi_text[t]`, 然后 `moshi_mimi[t, codebook_0..7]`

文本在音频之前预测（内心独白）；音频在深度 Transformer 内按码本顺序预测。

### 步骤 4：Moshi 在哪里胜利，在哪里不胜利

Moshi 胜利：

- 在廉价硬件上实现低于 250 ms 的端到端。
- 自然的回馈和中断。
- 没有流水线粘合代码。

Moshi 不胜利：

- 工具调用（未训练；你需要单独的 LLM 路径）。
- 长推理（Moshi 是约 8B 的对话模型，不是 Claude/GPT-4）。
- 利基主题的事实准确度。
- 大多数生产级企业用例（2026 年仍使用流水线）。

## 使用

| 场景 | 选择 |
|-----------|------|
| 最低延迟语音伴侣 | Moshi |
| 实时翻译通话 | Hibiki |
| 语音演示 / 研究 | Moshi、CSM |
| 带工具的企业代理 | 流水线（第 12 课），而非 Moshi |
| 上下文中的自定义语音 TTS | Sesame CSM |
| 语音到语音，任意语言 | GPT-4o Realtime 或 Gemini 2.5 Live（商业） |

## 2026 年仍会发布的陷阱

- **有限的工具调用。** Moshi 是对话模型，不是代理框架。结合流水线来处理工具。
- **特定语音条件。** Moshi 使用单一训练的人格；克隆是单独的训练运行。
- **语言覆盖。** 法语 + 英语出色；其他有限。Hibiki-Zero 有帮助，但你仍然需要训练数据。
- **资源成本。** 完整 Moshi 会话占用 GPU 槽；不是廉价的共享租户部署模式。

## 交付

保存为 `outputs/skill-duplex-pipeline.md`。为语音代理工作负载选择流水线 vs 全双工架构，附理由。

## 练习

1. **简单。** 运行 `code/main.py`。以符号方式模拟双流 + 内心独白架构。
2. **中等。** 从 HuggingFace 拉取 Moshi，运行服务器，测试一次对话。测量从用户语音结束到 Moshi 响应开始的墙钟时间延迟。
3. **困难。** 将你的第 12 课流水线代理与 Moshi 在 20 个匹配测试话语上比较 P50 延迟。写出流水线在架构上何时仍会胜出的分析。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| 全双工 | 同时听和说 | 同一模型上两条音频流同时活跃。 |
| 内心独白 | 模型的文本流 | Moshi 在音频输出旁发出文本标记。 |
| 深度 Transformer | 码本间预测器 | 在一个 80 ms 帧内预测 8 个码本的小型 Transformer。 |
| Mimi | Kyutai 的编解码器 | 12.5 Hz × 8 个码本；语义+声学；驱动 Moshi。 |
| 流式 S2S | 音频 → 音频实时 | 逐块翻译/对话，无流水线阶段。 |
| 回馈 | "嗯哼"反应 | Moshi 可以发出小的确认而不打断其轮次。 |

## 扩展阅读

- [Défossez et al. (2024). Moshi——语音-文本基础模型](https://arxiv.org/html/2410.00037v2)——论文。
- [Kyutai Labs (2026). Hibiki-Zero](https://arxiv.org/abs/2602.12345)——无需对齐数据的流式翻译。
- [Sesame (2025). Crossing the uncanny valley of voice](https://www.sesame.com/research/crossing_the_uncanny_valley_of_voice)——CSM 规格。
- [Kyutai——Moshi 仓库](https://github.com/kyutai-labs/moshi)——安装 + 服务器。
- [OpenAI——Realtime API](https://platform.openai.com/docs/guides/realtime)——闭源商业对标。
- [Kyutai——Delayed Streams Modeling](https://github.com/kyutai-labs/delayed-streams-modeling)——底层 STT/TTS 框架。