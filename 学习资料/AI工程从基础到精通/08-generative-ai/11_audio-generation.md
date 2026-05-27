# 音频生成

> 音频是以 16-48 kHz 采样的 1-D 信号。一个五秒的片段是 80-240k 个采样点。没有 transformer 直接关注那个序列。2026 年每个生产音频模型的解决方案都是一样的：神经编解码器（Encodec、SoundStream、DAC）在 50-75 Hz 将音频压缩为离散标记，一个 transformer 或扩散模型生成标记。

**类型：** 构建
**语言：** Python
**前置要求：** 第 6 阶段 · 02（音频特征），第 6 阶段 · 04（ASR），第 8 阶段 · 06（DDPM）
**时间：** 约 45 分钟

## 问题

三个音频生成任务：

1. **文本到语音。** 给定文本，生成语音。干净语音是窄带的，具有强语音结构 —— 由 transformer-over-tokens 很好地解决。VALL-E（Microsoft）、NaturalSpeech 3、ElevenLabs、OpenAI TTS。
2. **音乐生成。** 给定提示（文本、旋律、和弦进行、流派），生成音乐。分布更广泛。MusicGen（Meta）、Stable Audio 2.5、Suno v4、Udio、Riffusion。
3. **音频效果 / 声音设计。** 给定提示，生成环境音或拟音。AudioGen、AudioLDM 2、Stable Audio Open。

三者运行在相同的底层上：神经音频编解码器 + 标记自回归或扩散生成器。

## 概念

![音频生成：编解码器标记 + transformer 或扩散](../assets/audio-generation.svg)

### 神经音频编解码器

Encodec（Meta, 2022）、SoundStream（Google, 2021）、Descript Audio Codec（DAC, 2023）。卷积编码器将波形压缩为每个时间步的向量；残差向量量化（RVQ）将每个向量转换为 K 个码本索引的级联。解码器逆转它。24 kHz 音频在 2 kbps 使用 8 个 RVQ 码本在 75 Hz = 600 个标记/秒。

```
波形 (16000 采样/秒)
    └─ 编码器卷积 ─┐
                   ├─ RVQ 第 1 层 → 索引在 75 Hz
                   ├─ RVQ 第 2 层 → 索引在 75 Hz
                   ├─ ...
                   └─ RVQ 第 8 层
```

### 之上的两种生成范式

**标记自回归。** 将 RVQ 标记展平为序列，运行仅解码器 transformer。MusicGen 使用"延迟并行"以每个流的偏移并行发出 K 个码本流。VALL-E 从文本提示 + 3 秒语音样本生成语音标记。

**潜在扩散。** 将编解码器标记打包为连续潜在或用分类扩散建模它们。Stable Audio 2.5 在连续音频潜在上使用流匹配。AudioLDM 2 使用文本到梅尔到音频扩散。

2024-2026 趋势：流匹配在音乐方面获胜（更快推理，更干净样本），而标记自回归在语音方面仍占主导，因为它自然因果且流式传输良好。

## 生产格局

| 系统 | 任务 | 骨干 | 延迟 |
|--------|------|----------|---------|
| ElevenLabs V3 | TTS | 标记 AR + 神经声码器 | 首标记约 300ms |
| OpenAI GPT-4o 音频 | 全双工语音 | 端到端多模态 AR | 约 200ms |
| NaturalSpeech 3 | TTS | 潜在流匹配 | 非流式 |
| Stable Audio 2.5 | 音乐 / SFX | DiT + 音频潜在上的流匹配 | 1 分钟片段约 10s |
| Suno v4 | 完整歌曲 | 未公开；疑似标记 AR | 每首歌约 30s |
| Udio v1.5 | 完整歌曲 | 未公开 | 每首歌约 30s |
| MusicGen 3.3B | 音乐 | Encodec 32kHz 上的标记 AR | 实时 |
| AudioCraft 2 | 音乐 + SFX | 流匹配 | 5 秒片段约 5s |
| Riffusion v2 | 音乐 | 频谱图扩散 | 约 10s |

## 构建

`code/main.py` 模拟核心思想：在从两种不同"风格"生成的合成"音频标记"序列上训练一个微型下一个标记 transformer（风格 A 交替低和高标记，风格 B 单调递增）。条件在风格上并采样。

### 步骤 1：合成音频标记

```python
def make_tokens(style, length, vocab_size, rng):
    if style == 0:  # "类语音"：交替
        return [i % vocab_size for i in range(length)]
    # "类音乐"：递增
    return [(i * 3) % vocab_size for i in range(length)]
```

### 步骤 2：训练微型标记预测器

一个以风格为条件的 bigram 风格预测器。重点是模式：编解码器标记 → 交叉熵训练 → 自回归采样。

### 步骤 3：条件采样

给定风格标记和起始标记，从预测分布采样下一个标记。继续 20-40 个标记。

## 陷阱

- **编解码器质量限制输出质量。** 如果编解码器无法忠实地表示声音，再多的生成器质量也无济于事。DAC 是当前开源最佳。
- **RVQ 错误累积。** 每个 RVQ 层建模前一层的残差。第 1 层的错误会传播。在更高层以温度 0 采样有帮助。
- **音乐结构。** 30 秒的标记在 75 Hz 是 20000+ 个标记。对 transformer 很难。MusicGen 使用滑动窗口 + 提示续写；Stable Audio 使用更短片段 + 交叉淡入淡出。
- **边界伪影。** 生成片段之间的交叉淡入淡出需要仔细的重叠相加。
- **干净数据需求。** 音乐生成器需要数万小时的授权音乐。Suno / Udio RIAA 诉讼（2024）将此暴露出来。
- **声音克隆伦理。** 3 秒样本加文本提示足以让 VALL-E / XTTS / ElevenLabs 克隆声音。每个生产模型都需要滥用检测 + 退出名单。

## 使用

| 任务 | 2026 年技术栈 |
|------|------------|
| 商业 TTS | ElevenLabs、OpenAI TTS 或 Azure Neural |
| 声音克隆（经同意验证） | XTTS v2（开源）或 ElevenLabs Pro |
| 背景音乐，快速 | Stable Audio 2.5 API、Suno 或 Udio |
| 带歌词的音乐 | Suno v4 或 Udio v1.5 |
| 音效 / 拟音 | AudioCraft 2、ElevenLabs SFX 或 Stable Audio Open |
| 实时语音代理 | GPT-4o 实时或 Gemini Live |
| 开源音乐研究 | MusicGen 3.3B、Stable Audio Open 1.0、AudioLDM 2 |
| 配音 / 翻译 | HeyGen、ElevenLabs Dubbing |

## 交付

保存 `outputs/skill-audio-brief.md`。技能接受音频简报（任务、时长、风格、声音、许可）并输出：模型 + 托管、提示格式（流派标签、风格描述符、结构标记）、编解码器 + 生成器 + 声码器链、种子协议，以及评估计划（MOS / CLAP 分数 / TTS 的 CER / 用户 A/B）。

## 练习

1. **简单。** 运行 `code/main.py` 并显式设置风格。验证生成的序列匹配风格模式。
2. **中等。** 添加延迟并行解码：模拟 2 个标记流，必须保持偏移 1 步。训练联合预测器。
3. **困难。** 使用 HuggingFace transformers 在本地运行 MusicGen-small。用三个不同提示生成 10 秒片段；对风格遵循性进行 A/B 测试。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|-----------------------|
| Codec | "神经压缩" | 音频的编码器/解码器；典型输出是 50-75 Hz 标记。 |
| RVQ | "残差 VQ" | K 个量化器的级联；每个建模前一层的残差。 |
| Token | "一个编解码器符号" | 码本中的离散索引；典型为 1024 或 2048。 |
| 延迟并行 | "偏移码本" | 以交错偏移发出 K 个标记流以减少序列长度。 |
| 流匹配 | "2024 年音频的胜利" | 扩散的替代方案，路径更直；采样更快。 |
| 语音提示 | "3 秒样本" | 引导克隆声音的说话人嵌入或标记前缀。 |
| 梅尔频谱图 | "可视化" | 对数幅度感知频谱图；许多 TTS 系统使用。 |
| 声码器 | "梅尔到波形" | 将梅尔频谱图转换回音频的神经组件。 |

## 生产说明：音频是流式传输问题

音频是用户期望*在生成时*到达的唯一输出模态，而不是一次性全部到达。在生产术语中，这意味着 TPOT（每个输出标记的时间）很重要，因为用户的收听速度是目标吞吐量——而不是他们的阅读速度。对于以约 75 个标记/秒（Encodec）标记化的 16kHz 音频，服务器必须每个用户生成 ≥75 个标记/秒以保持播放流畅。

两个架构后果：

- **流匹配音频模型不能简单地流式传输。** Stable Audio 2.5 和 AudioCraft 2 在一次传递中渲染固定片段长度。要流式传输，你对片段进行分块并重叠边界——想象滑动窗口扩散——与编解码器 AR 模型相比增加 100-300ms 的延迟开销。

如果产品是"实时语音聊天"或"实时音乐续写"，选择编解码器 AR 路径。如果是"提交后渲染 30 秒片段"，流匹配在质量和总延迟上获胜。

## 扩展阅读

- [Défossez et al. (2022). Encodec: High Fidelity Neural Audio Compression](https://arxiv.org/abs/2210.13438)——编解码器标准。
- [Zeghidour et al. (2021). SoundStream](https://arxiv.org/abs/2107.03312)——第一个广泛使用的神经音频编解码器。
- [Kumar et al. (2023). High-Fidelity Audio Compression with Improved RVQGAN (DAC)](https://arxiv.org/abs/2306.06546)——DAC。
- [Wang et al. (2023). Neural Codec Language Models are Zero-Shot Text to Speech Synthesizers (VALL-E)](https://arxiv.org/abs/2301.02111)——VALL-E。
- [Copet et al. (2023). Simple and Controllable Music Generation (MusicGen)](https://arxiv.org/abs/2306.05284)——MusicGen。
- [Liu et al. (2023). AudioLDM 2: Learning Holistic Audio Generation with Self-supervised Pretraining](https://arxiv.org/abs/2308.05734)——AudioLDM 2。
- [Stability AI (2024). Stable Audio 2.5](https://stability.ai/news/introducing-stable-audio-2-5)——2025 年带流匹配的文本到音乐。