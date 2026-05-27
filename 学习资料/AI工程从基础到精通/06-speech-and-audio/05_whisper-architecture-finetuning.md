# Whisper——架构与微调

> Whisper 是一个 30 秒窗口的 Transformer 编码器-解码器，在 680k 小时多语言弱监督音频-文本对上训练。一个架构，多个任务，跨 99 种语言鲁棒。2026 年的参考 ASR。

**类型：** 构建
**语言：** Python
**前置要求：** 第 6 阶段 · 04（ASR），第 5 阶段 · 10（注意力），第 7 阶段 · 05（完整 Transformer）
**时间：** 约 75 分钟

## 问题

OpenAI 于 2022 年 9 月发布的 Whisper 是第一个作为商品发布的 ASR 模型：粘贴音频，得到文本，99 种语言，鲁棒抗噪，在笔记本电脑上运行。到 2024 年 OpenAI 发布了 Large-v3 和 Turbo 变体；到 2026 年，Whisper 是从播客转录到语音助手到 YouTube 字幕的一切的默认基线。

但 Whisper 不是你可以永远当作黑盒的 pipeline。领域偏移会杀死它——技术术语、说话人口音、专有名词、短片段、静音。你需要知道：

1. 它内部到底是什么。
2. 如何正确地给它分块的、流式的或长格式的音频。
3. 何时微调以及如何微调。

## 概念

![Whisper 编码器-解码器、任务、分块推理、微调](../assets/whisper.svg)

**架构。** 标准 Transformer 编码器-解码器。

- 输入：30 秒对数 Mel 频谱图，80 Mel，10 ms 跳跃 → 3000 帧。更短的片段零填充，更长的片段分块。
- 编码器：卷积降采样（步幅 2）+ `N` 个 Transformer 块。对于 Large-v3：32 层，1280 维，20 个头。
- 解码器：`N` 个 Transformer 块，带因果自注意力 + 对编码器输出的交叉注意力。与编码器大小相同。
- 输出：51,865 标记词汇表上的 BPE 标记。

Large-v3 有 1.55B 参数。Turbo 使用 4 层解码器（从 32 层），延迟降低 8×，WER 损失 <1%。

**提示格式。** Whisper 是一个多任务模型，由解码器提示中的特殊标记引导：

```
<|startoftranscript|><|en|><|transcribe|><|notimestamps|> Hello world.<|endoftext|>
```

- `<|en|>`——语言标签；强制翻译 vs 转录行为。
- `<|transcribe|>` 或 `<|translate|>`——从任意语言输入翻译为英语输出，或逐字转录。
- `<|notimestamps|>`——跳过词级时间戳（更快）。

提示是让一个模型完成多个任务的关键。将 `<|en|>` 改为 `<|fr|>` 它就转录法语。

**30 秒窗口。** 一切固定为 30 秒。更长的片段需要分块；更短的片段被填充。窗口不原生流式——这就是 WhisperX、Whisper-Streaming 和 faster-whisper 存在的原因。

**对数 Mel 归一化。** `(log_mel - mean) / std`，其中统计数据来自 Whisper 自己的训练语料库。你*必须*使用 Whisper 的预处理（`whisper.audio.log_mel_spectrogram`），而不是 `librosa.feature.melspectrogram`。

### 2026 年变体

| 变体 | 参数 | 延迟（A100） | WER（LibriSpeech-clean） |
|---------|--------|----------------|------------------------|
| Tiny | 39M | 1× 实时 | 5.4% |
| Base | 74M | 1× | 4.1% |
| Small | 244M | 1× | 3.0% |
| Medium | 769M | 1× | 2.7% |
| Large-v3 | 1.55B | 2× | 1.8% |
| Large-v3-turbo | 809M | 8× | 1.58% |
| Whisper-Streaming (2024) | 1.55B | streaming | 2.0% |

### 微调

2026 年规范工作流：

1. 收集 10-100 小时目标领域音频及对齐转录。
2. 带 `generate_with_loss` 回调运行 `transformers.Seq2SeqTrainer`。
3. 参数高效：注意力层的 `q_proj`、`k_proj`、`v_proj` 上的 LoRA，将 GPU 内存减少 4×，WER 损失 <0.3。
4. 如果你有 <10 小时，冻结编码器。只调优解码器。
5. 使用 Whisper 自己的分词器和提示格式；永远不要替换分词器。

社区结果：在 20 小时医疗听写数据上微调 Medium 将医疗词汇的 WER 从 12% 降至 4.5%。在 4 小时冰岛语上微调 Turbo 将 WER 从 18% 降至 6%。

## 构建

### 步骤 1：开箱即用运行 Whisper

```python
import whisper
model = whisper.load_model("large-v3-turbo")
result = model.transcribe(
    "clip.wav",
    language="en",
    task="transcribe",
    temperature=0.0,
    condition_on_previous_text=False,  # 防止失控重复
)
print(result["text"])
for seg in result["segments"]:
    print(f"[{seg['start']:.2f}–{seg['end']:.2f}] {seg['text']}")
```

你应该始终覆盖的关键默认值：`temperature=0.0`（采样默认值为 0.0 → 0.2 → 0.4 … 回退链），`condition_on_previous_text=False`（防止级联幻觉问题），以及 `no_speech_threshold=0.6`（静音检测）。

### 步骤 2：分块长格式

```python
# whisperx 是 2026 年带词级时间戳的长格式参考
import whisperx
model = whisperx.load_model("large-v3-turbo", device="cuda", compute_type="float16")
segments = model.transcribe("1hour.mp3", batch_size=16, chunk_size=30)
```

WhisperX 添加了 (1) Silero VAD 门控，(2) 通过 wav2vec 2.0 的词级对齐，(3) 通过 `pyannote.audio` 的说话人分离。2026 年生产转录的主力。

### 步骤 3：用 LoRA 微调

```python
from transformers import WhisperForConditionalGeneration, WhisperProcessor
from peft import LoraConfig, get_peft_model

model = WhisperForConditionalGeneration.from_pretrained("openai/whisper-large-v3-turbo")
lora = LoraConfig(
    r=16, lora_alpha=32, target_modules=["q_proj", "v_proj"],
    lora_dropout=0.1, bias="none", task_type="SEQ_2_SEQ_LM",
)
model = get_peft_model(model, lora)
# model.print_trainable_parameters()  -> ~3M trainable / 809M total
```

然后标准 Trainer 循环。每 1000 步保存检查点。在留出集上用 WER 评估。

### 步骤 4：检查每层学到什么

```python
# 在解码过程中获取交叉注意力权重，查看解码器关注什么。
with torch.inference_mode():
    out = model.generate(
        input_features=features,
        return_dict_in_generate=True,
        output_attentions=True,
    )
# out.cross_attentions: layer × head × step × src_len
```

用热图可视化——当解码器步骤扫描编码器帧时，你会看到对角线对齐。那条对角线就是 Whisper 的词时间戳概念。

## 使用

2026 年技术栈：

| 场景 | 选择 |
|-----------|------|
| 通用英语，离线 | 通过 `whisperx` 使用 Large-v3-turbo |
| 移动 / 边缘 | Whisper-Tiny 量化（int8）或 Moonshine |
| 多语言长格式 | 通过 `whisperx` + 说话人分离使用 Large-v3 |
| 低资源语言 | 用 LoRA 微调 Medium 或 Turbo |
| 流式（2 秒延迟） | Whisper-Streaming 或 Parakeet-TDT |
| 词级时间戳 | WhisperX（通过 wav2vec 2.0 的强制对齐） |

`faster-whisper`（CTranslate2 后端）是 2026 年最快的 CPU+GPU 推理运行时——比原始版本快 4×，输出相同。

## 2026 年仍会发布的陷阱

- **静音上的幻觉文本。** 在包含字幕的内容上训练的 Whisper 包括"Thanks for watching!"、"Subscribe!"、歌词。调用前始终 VAD 守护。
- **`condition_on_previous_text` 级联。** 一个幻觉污染后续窗口。除非需要跨块流畅性，否则设置为 `False`。
- **短片段填充。** 填充到 30 秒的 2 秒片段可能在后部静音中产生幻觉。使用 `pad=False` 或 VAD 守护。
- **错误的 Mel 统计。** 使用 librosa 的 Mel 而非 Whisper 的会产生近乎随机的输出。使用 `whisper.audio.log_mel_spectrogram`。

## 交付

保存为 `outputs/skill-whisper-tuner.md`。为给定领域设计 Whisper 微调或推理 pipeline。

## 练习

1. **简单。** 运行 `code/main.py`。它分词 Whisper 风格提示，计算解码形状预算，并打印 10 分钟片段的分块调度。
2. **中等。** 安装 `faster-whisper`，转录一个 10 分钟播客，比较与人工转录的 WER。尝试 `language="auto"` vs 强制 `language="en"`。
3. **困难。** 使用 HF `datasets`，选择一个 Whisper 处理困难的语言（如乌尔都语），用 LoRA 微调 Medium 2 个 epoch 共 2 小时数据，报告 WER 增量。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| 30 秒窗口 | Whisper 的限制 | 硬输入上限；分块更长音频。 |
| SOT | 转录开始 | `<|startoftranscript|>` 启动解码器提示。 |
| 时间戳标记 | 时序对齐 | 每 0.02 秒偏移是 51k 词汇中的特殊标记。 |
| Turbo | 快速变体 | 4 解码器层，8× 更快，<1% WER 回归。 |
| WhisperX | 长格式包装器 | VAD + Whisper + wav2vec 对齐 + 说话人分离。 |
| LoRA 微调 | 高效调优 | 向注意力添加低秩适配器；训练约 0.3% 的参数。 |
| 幻觉 | 静默失败 | Whisper 从噪声/静音中生成流畅的英语。 |

## 扩展阅读

- [Radford et al. (2022). Whisper paper](https://arxiv.org/abs/2212.04356)——原始架构和训练配方。
- [OpenAI (2024). Whisper Large-v3-turbo release](https://github.com/openai/whisper/discussions/2363)——4 层解码器，8× 加速。
- [Bain et al. (2023). WhisperX](https://arxiv.org/abs/2303.00747)——长格式、词对齐、说话人分离。
- [Systran — faster-whisper repo](https://github.com/SYSTRAN/faster-whisper)——CTranslate2 支持，4× 更快。
- [HuggingFace — Whisper fine-tune tutorial](https://huggingface.co/blog/fine-tune-whisper)——LoRA / 全量微调的规范教程。