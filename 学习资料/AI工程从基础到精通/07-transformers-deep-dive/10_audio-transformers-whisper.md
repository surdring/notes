# 音频 Transformer——Whisper 架构

> 音频是频率随时间变化的图像。Whisper 是一个吃 mel 频谱图的 ViT 并说话回应。

**类型：** 学习
**语言：** Python
**前置要求：** 第 7 阶段 · 05（完整 Transformer），第 7 阶段 · 08（编码器-解码器），第 7 阶段 · 09（ViT）
**时间：** 约 45 分钟

## 问题

在 Whisper（OpenAI，Radford et al. 2022）之前，最先进的自动语音识别（ASR）意味着 wav2vec 2.0 和 HuBERT——自监督特征提取器加微调头。高质量，昂贵的数据流水线，领域脆弱。多语言语音识别需要每个语言族单独模型。

Whisper 做了三个赌注：

1. **在所有数据上训练。** 从互联网抓取的 680,000 小时弱标注音频，跨越 97 种语言。没有干净的学术语料。没有音素标签。
2. **多任务单一模型。** 一个解码器在转录、翻译、语音活动检测、语言 ID 和时间戳上联合训练，通过任务标记。
3. **标准编码器-解码器 transformer。** 编码器消费 log-mel 频谱图。解码器自回归产生文本标记。无声码器、无 CTC、无 HMM。

结果：Whisper large-v3 对没有干净标注数据的语言在口音、噪声下鲁棒。它是 2026 年每个开源语音助手和大多数商业助手的事实语音前端。

## 概念

![Whisper 流水线：音频 → mel → 编码器 → 解码器 → 文本](../assets/whisper.svg)

### 步骤 1——重采样 + 窗口

16 kHz 音频。裁剪/填充到 30 秒。计算 log-mel 频谱图：80 个 mel 区间，10 ms 步长 → ~3,000 帧 × 80 特征。这是 Whisper 看到的"输入图像"。

### 步骤 2——卷积干

两层 Conv1D，核 3 步长 2，将 3,000 帧减为 1,500。将序列长度减半而不添加大量参数。

### 步骤 3——编码器

1,500 时间步上的 24 层（large）transformer 编码器。正弦位置编码，自注意力，GELU FFN。产生 1,500 × 1,280 隐藏状态。

### 步骤 4——解码器

24 层 transformer 解码器。它从 BPE 词汇自回归产生标记，该词汇是 GPT-2 的超集，有一些音频特定的特殊标记。

### 步骤 5——任务标记

解码器提示以控制标记开始，告诉模型做什么：

```
<|startoftranscript|>  <|en|>  <|transcribe|>  <|0.00|>
```

或

```
<|startoftranscript|>  <|fr|>  <|translate|>   <|0.00|>
```

模型在此约定上训练。你通过前缀控制任务。2026 年等价的指令微调，但应用于语音。

### 步骤 6——输出

带 log-prob 阈值的束搜索（宽度 5）。当 `<|notimestamps|>` 标记缺失时，每 0.02 秒音频预测时间戳。

### Whisper 大小

| 模型 | 参数 | 层 | d_model | 头 | VRAM（fp16） |
|-------|--------|--------|---------|-------|-------------|
| Tiny | 39M | 4 | 384 | 6 | ~1 GB |
| Base | 74M | 6 | 512 | 8 | ~1 GB |
| Small | 244M | 12 | 768 | 12 | ~2 GB |
| Medium | 769M | 24 | 1024 | 16 | ~5 GB |
| Large | 1550M | 32 | 1280 | 20 | ~10 GB |
| Large-v3 | 1550M | 32 | 1280 | 20 | ~10 GB |
| Large-v3-turbo | 809M | 32 | 1280 | 20 | ~6 GB（4 层解码器） |

Large-v3-turbo（2024）将解码器从 32 层减为 4 层。8× 更快的解码，< 1 WER 点退化。解码速度解锁是 Whisper-turbo 在 2026 年成为实时语音代理默认的原因。

### Whisper 不做什么

- 无说话人分离（谁在说话）。搭配 pyannote 实现。
- 原生无实时流式——30 秒窗口是固定的。现代包装器（`faster-whisper`、`WhisperX`）通过 VAD + 重叠附加流式。
- 无外部分块则无超 30 秒的长格式上下文。在实践中工作良好，因为人类语音很少需要长程上下文来进行转录。

### 2026 格局

| 任务 | 模型 | 注释 |
|------|-------|-------|
| 英语 ASR | Whisper-turbo、Moonshine | Moonshine 在边缘快 4 倍 |
| 多语言 ASR | Whisper-large-v3 | 97 种语言 |
| 流式 ASR | faster-whisper + VAD | 可实现 150 ms 延迟目标 |
| TTS | Piper、XTTS-v2、Kokoro | 编码器-解码器模式，但 Whisper 形状 |
| 音频 + 语言 | AudioLM、SeamlessM4T | 一个 transformer 中的文本标记 + 音频标记 |

## 构建

见 `code/main.py`。我们不训练 Whisper——我们构建 log-mel 频谱图流水线 + 任务标记提示格式化器。这些是你在生产中实际接触的部分。

### 步骤 1：合成音频

生成 1 秒 440 Hz 的正弦波，16 kHz 采样。16,000 个样本。

### 步骤 2：log-mel 频谱图（简化）

完整 mel 频谱图需要 FFT。我们做简化的分帧 + 每帧能量版本，在不使用 `librosa` 的情况下展示流水线：

```python
def frame_signal(x, frame_size=400, hop=160):
    frames = []
    for start in range(0, len(x) - frame_size + 1, hop):
        frames.append(x[start:start + frame_size])
    return frames
```

帧 = 25 ms，步长 = 10 ms。匹配 Whisper 的窗口化。每帧能量代表 mel 区间用于教学。

### 步骤 3：填充到 30 秒

Whisper 总是处理 30 秒分块。将频谱图填充（或裁剪）到 3,000 帧。

### 步骤 4：构建提示标记

```python
def whisper_prompt(lang="en", task="transcribe", timestamps=True):
    tokens = ["<|startoftranscript|>", f"<|{lang}|>", f"<|{task}|>"]
    if not timestamps:
        tokens.append("<|notimestamps|>")
    return tokens
```

这就是整个任务控制界面。一个 4 标记前缀。

## 使用

```python
import whisper
model = whisper.load_model("large-v3-turbo")
result = model.transcribe("meeting.wav", language="en", task="transcribe")
print(result["text"])
print(result["segments"][0]["start"], result["segments"][0]["end"])
```

更快，兼容 OpenAI：

```python
from faster_whisper import WhisperModel
model = WhisperModel("large-v3-turbo", compute_type="int8_float16")
segments, info = model.transcribe("meeting.wav", vad_filter=True)
for s in segments:
    print(f"{s.start:.2f} - {s.end:.2f}: {s.text}")
```

**2026 年何时选择 Whisper：**

- 用一个模型的多语言 ASR。
- 嘈杂、多样化音频的鲁棒转录。
- 研究/原型 ASR——最快的起点。

**何时选择其他：**

- 边缘上的超低延迟流式——Moonshine 在匹配质量上击败 Whisper。
- 需要 < 200 ms 的实时对话 AI——专用流式 ASR。
- 说话人分离——Whisper 不做这个；附加 pyannote。

## 交付

见 `outputs/skill-asr-configurator.md`。该技能为新的语音应用选择 ASR 模型、解码参数和预处理流水线。

## 练习

1. **简单。** 运行 `code/main.py`。确认 1 秒信号 16 kHz 10 ms 步长的帧数约 100 帧。30 秒：~3,000 帧。
2. **中等。** 使用 `numpy.fft` 构建完整 log-mel 频谱图。验证 80 mel 区间在数值误差内匹配 `librosa.feature.melspectrogram(n_mels=80)`。
3. **困难。** 实现流式推理：将音频分块为 10 秒窗口，2 秒重叠，在每个分块上运行 Whisper，合并转录。在 5 分钟播客样本上测量词错误率 vs 单次传递。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| Mel 频谱图 | "音频图像" | 2D 表示：一个轴频率区间，另一个轴时间帧；每个单元 log 缩放能量。 |
| Log-mel | "Whisper 看到的" | 通过 log 传递的 mel 频谱图；近似人类对响度的感知。 |
| 帧 | "一个时间切片" | 25 ms 样本窗口；以 10 ms 步长重叠。 |
| 任务标记 | "语音的提示前缀" | 解码器提示中的特殊标记，如 `<|transcribe|>` / `<|translate|>`。 |
| 语音活动检测（VAD） | "找到语音" | 在 ASR 前移除静音的闸门；大幅削减成本。 |
| CTC | "连接主义时序分类" | 用于无对齐训练的经典 ASR 损失；Whisper 不使用。 |
| Whisper-turbo | "小编码器，完整编码器" | large-v3 编码器 + 4 层解码器；8× 更快解码。 |
| Faster-whisper | "生产包装器" | CTranslate2 重新实现；int8 量化；比 OpenAI 参考快 4×。 |

## 扩展阅读

- [Radford et al. (2022). Robust Speech Recognition via Large-Scale Weak Supervision](https://arxiv.org/abs/2212.04356)——Whisper 论文。
- [OpenAI Whisper 仓库](https://github.com/openai/whisper)——参考代码 + 模型权重。阅读 ~400 行的 `whisper/model.py` 查看 Conv1D 干 + 编码器 + 解码器从上到下。
- [OpenAI Whisper — `whisper/decoding.py`](https://github.com/openai/whisper/blob/main/whisper/decoding.py)——步骤 5-6 描述的束搜索 + 任务标记逻辑在此；500 行，完全可读。
- [Baevski et al. (2020). wav2vec 2.0: A Framework for Self-Supervised Learning of Speech Representations](https://arxiv.org/abs/2006.11477)——前身；某些设置中仍是最先进特征。
- [SYSTRAN/faster-whisper](https://github.com/SYSTRAN/faster-whisper)——生产包装器，比参考快 4×。
- [Jia et al. (2024). Moonshine: Speech Recognition for Live Transcription and Voice Commands](https://arxiv.org/abs/2410.15608)——2024 边缘友好的 ASR，Whisper 形状但更小。
- [HuggingFace 博客——"Fine-Tune Whisper For Multilingual ASR with 🤗 Transformers"](https://huggingface.co/blog/fine-tune-whisper)——规范微调配方。
- [HuggingFace `modeling_whisper.py`](https://github.com/huggingface/transformers/blob/main/src/transformers/models/whisper/modeling_whisper.py)——完整实现（编码器、解码器、交叉注意力、生成）。