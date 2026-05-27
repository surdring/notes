# 语音代理：Pipecat 与 LiveKit

> 语音代理（Voice Agents）是 2026 年的一等生产类别。Pipecat 提供基于帧（Frame-based）的 Python 流水线（VAD → STT → LLM → TTS → 传输）。LiveKit Agents 通过 WebRTC 将 AI 模型桥接到用户。优质方案的生产延迟目标为端到端 450–600ms。

**类型：** 学习
**语言：** Python（标准库）
**前置条件：** Phase 14 · 01（Agent 循环），Phase 14 · 12（工作流模式，Workflow Patterns）
**时间：** ~60 分钟

## 学习目标

- 描述 Pipecat 基于帧的流水线：DOWNSTREAM（源→接收器）和 UPSTREAM（控制）。
- 列举规范的语音流水线阶段以及 Pipecat 支持的传输协议。
- 解释 LiveKit Agents 的两种语音代理类（MultimodalAgent、VoicePipelineAgent）以及各自适用场景。
- 总结 2026 年生产延迟预期及其如何驱动架构选择。

## 问题

语音代理不是简单的文本循环加上 TTS。延迟预算非常苛刻（~600ms），部分音频是默认状态，轮次检测（Turn Detection）本身就是一个模型，传输从电话 SIP 到 WebRTC 各有不同。你要么构建基于帧的流水线（Pipecat），要么依赖一个平台（LiveKit）。

## 概念

### Pipecat（pipecat-ai/pipecat）

- Python 基于帧的流水线框架。
- `Frame` → `FrameProcessor` 链。
- 两个流方向：
  - **DOWNSTREAM** — 源 → 接收器（音频输入，TTS 输出）。
  - **UPSTREAM** — 反馈和控制（取消、指标、打断 Barge-in）。
- `PipelineTask` 通过事件（`on_pipeline_started`、`on_pipeline_finished`、`on_idle_timeout`）管理生命周期，以及用于指标/追踪/RTVI 的观察器。

典型流水线：

```
VAD (Silero) → STT → LLM（上下文交替用户/助手） → TTS → 传输
```

传输协议：Daily、LiveKit、SmallWebRTCTransport、FastAPI WebSocket、WhatsApp。

Pipecat Flows 添加了结构化对话（状态机）。Pipecat Cloud 是托管运行时。

### LiveKit Agents（livekit/agents）

- 通过 WebRTC 将 AI 模型桥接到用户。
- 关键概念：`Agent`、`AgentSession`、`entrypoint`、`AgentServer`。
- 两种语音代理类：
  - **MultimodalAgent** — 通过 OpenAI Realtime 或等效方案直接音频输入/输出。
  - **VoicePipelineAgent** — STT → LLM → TTS 级联；提供文本级控制。
- 通过 Transformer 模型实现语义轮次检测（Semantic Turn Detection）。
- 原生 MCP 集成。
- 通过 SIP 支持电话。
- 通过 LiveKit Inference 支持 50+ 个模型无需 API 密钥；通过插件支持 200+ 个更多模型。

### 商业平台

Vapi（在优化优质方案上 ~450–600ms）和 Retell（180 次测试调用中端到端 ~600ms）建立在这些基础之上。当你想要托管语音方案但不想组建 WebRTC 团队时选择平台。

### 这种模式的陷阱

- **没有打断（Barge-in）处理。** 用户打断；代理继续说话。需要在 Pipecat 中使用 UPSTREAM 取消帧，在 LiveKit 中使用等效机制。
- **忽略 STT 置信度。** 低置信度转录如真理般喂给 LLM。根据置信度设置门控或请求确认。
- **TTS 句子中途截断。** 当流水线在话语中间取消时，TTS 需要知道或截断音频。
- **忽略延迟预算。** 每个组件增加 50–200ms。在发布前对链路求和。

### 典型的 2026 年延迟

- VAD：20–60ms
- STT 部分：100–250ms
- LLM 首 Token：150–400ms
- TTS 首音频：100–200ms
- 传输 RTT：30–80ms

端到端 450–600ms 是优质级别。800–1200ms 是常见水平。任何超过 1500ms 的都会感觉卡顿。

## 构建

`code/main.py` 是一个基于帧的玩具流水线，包含：

- `Frame` 类型（音频、转录、文本、tts_audio、控制）。
- `Processor` 接口，带有 `process(frame)`。
- 五阶段流水线（VAD → STT → LLM → TTS → 传输），作为脚本化处理器。
- 一个 UPSTREAM 取消帧，用于演示打断（Barge-in）。

运行方式：

```
python3 code/main.py
```

追踪显示正常流程和一个打断取消，在话语中途停止了 TTS。

## 使用场景

- **Pipecat** — 用于完全控制：自定义处理器、Python 优先、可插拔提供商。
- **LiveKit Agents** — 用于 WebRTC 优先部署和电话。
- **Vapi / Retell** — 用于无需 WebRTC 团队的托管语音代理。
- **OpenAI Realtime / Gemini Live** — 用于直接音频输入/输出（MultimodalAgent）。

## 部署

`outputs/skill-voice-pipeline.md` 搭建一个 Pipecat 形态的语音流水线脚手架，包含 VAD + STT + LLM + TTS + 传输以及打断处理。

## 练习

1. 为你的玩具流水线添加指标观察器：统计每个阶段每秒的帧数。延迟在哪里累积？
2. 实现置信度门控 STT：低于阈值时请求"您可以重复一遍吗？"
3. 添加语义轮次检测：简单规则——如果转录以"？"结尾，则轮次结束。
4. 阅读 Pipecat 的传输文档。将标准库传输替换为 SmallWebRTCTransport 配置（桩代码）。
5. 在同一查询上测量 OpenAI Realtime vs STT+LLM+TTS 级联。文本级控制带来了多少延迟成本？

## 关键术语

| 术语 | 人们常说的 | 实际含义 |
|------|-----------|---------|
| 帧（Frame） | "事件" | 流水线中类型化的数据单元（音频、转录、文本、控制） |
| 处理器（Processor） | "流水线阶段" | 带有 process(frame) 的处理程序 |
| DOWNSTREAM | "前向流" | 源到接收器：音频输入，语音输出 |
| UPSTREAM | "反馈流" | 控制：取消、指标、打断 |
| VAD | "语音活动检测" | 检测用户何时在说话 |
| 语义轮次检测（Semantic Turn Detection） | "智能轮次结束" | 基于模型的判断用户已完成说话 |
| MultimodalAgent | "直接音频代理" | 音频输入，音频输出；中间不含文本 |
| VoicePipelineAgent | "级联代理" | STT + LLM + TTS；文本级控制 |

## 进一步阅读

- [Pipecat 文档](https://docs.pipecat.ai/getting-started/introduction) — 基于帧的流水线、处理器、传输
- [LiveKit Agents 文档](https://docs.livekit.io/agents/) — WebRTC + 语音原语
- [Vapi](https://vapi.ai/) — 托管语音平台
- [Retell AI](https://www.retellai.com/) — 托管语音，延迟基准测试