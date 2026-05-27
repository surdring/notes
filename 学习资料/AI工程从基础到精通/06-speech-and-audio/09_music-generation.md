# 音乐生成——MusicGen、Stable Audio、Suno 和许可地震

> 2026 年音乐生成：Suno v5 和 Udio v4 主导商业；MusicGen、Stable Audio Open 和 ACE-Step 领衔开源。技术问题基本解决。法律问题（华纳音乐 5 亿美元和解、UMG 和解）在 2025-2026 年重塑了该领域。

**类型：** 构建
**语言：** Python
**前置要求：** 第 6 阶段 · 02（频谱图），第 4 阶段 · 10（扩散模型）
**时间：** 约 75 分钟

## 问题

文本 → 一段 30 秒到 4 分钟的音乐片段，包含歌词、人声和结构。三个子问题：

1. **器乐生成。** 文本如"lo-fi hip-hop drums with warm keys" → 音频。MusicGen、Stable Audio、AudioLDM。
2. **歌曲生成（带人声 + 歌词）。** "关于德克萨斯雨夜的乡村歌曲" → 完整歌曲。Suno、Udio、YuE、ACE-Step。
3. **条件/可控。** 扩展现有片段、重新生成副歌、切换流派、音轨分离或修复。Udio 的修复 + 音轨分离是 2026 年需要匹配的功能。

## 概念

![音乐生成：标记-LM vs 扩散，2026 模型地图](../assets/music-generation.svg)

### 神经编解码器标记上的标记 LM

Meta 的 **MusicGen**（2023，MIT）和许多衍生品：以文本/旋律嵌入为条件，自回归预测 EnCodec 标记（32 kHz，4 个码本），用 EnCodec 解码。3 亿-33 亿参数。强基线；在超过 30 秒时挣扎。

**ACE-Step**（开源，4B XL 于 2026 年 4 月发布）将其扩展为完整歌曲的歌词条件生成。开源社区最接近 Suno 的产物。

### Mel 或潜变量上的扩散

**Stable Audio（2023）** 和 **Stable Audio Open（2024）**：压缩音频上的潜扩散。擅长循环、声音设计、氛围纹理。不擅长结构化完整歌曲。

**AudioLDM / AudioLDM2**：通过 T2I 风格潜扩散的文本到音频，泛化到音乐、音效、语音。

### 混合（生产）——Suno、Udio、Lyria

闭源权重。可能是 AR 编解码器 LM + 基于扩散的声码器，带有专门的语音/鼓/旋律头。Suno v5（2026）是 ELO 1293 的质量领先者。Udio v4 添加了修复 + 音轨分离（低音、鼓、人声分别下载）。

### 评估

- **FAD（Fréchet 音频距离）。** 使用 VGGish 或 PANNs 特征的生成 vs 真实音频分布之间的嵌入级距离。越低越好。MusicGen small：MusicCaps 上 4.5 FAD；最先进约为 3.0。
- **音乐性（主观）。** 人类偏好。Suno v5 ELO 1293 领先。
- **文本-音频对齐。** 提示和输出之间的 CLAP 分数。
- **音乐性伪影。** 节奏错位、人声短语漂移、超过 30 秒的结构丧失。

## 2026 模型地图

| 模型 | 参数 | 时长 | 人声 | 许可 |
|-------|--------|------|------|---------|
| MusicGen-large | 3.3B | 30 s | 无 | MIT |
| Stable Audio Open | 1.2B | 47 s | 无 | Stability 非商业 |
| ACE-Step XL（2026年4月） | 4B | > 2 min | 有 | Apache-2.0 |
| YuE | 7B | > 2 min | 有，多语言 | Apache-2.0 |
| Suno v5（闭源） | ? | 4 min | 有，ELO 1293 | 商业 |
| Udio v4（闭源） | ? | 4 min | 有 + 音轨 | 商业 |
| Google Lyria 3（闭源） | ? | 实时 | 有 | 商业 |
| MiniMax Music 2.5 | ? | 4 min | 有 | 商业 API |

## 法律格局（2025-2026）

- **华纳音乐 vs Suno 和解。** 5 亿美元。WMG 现对 Suno 上的 AI 相似性、音乐权利和用户生成曲目拥有监督权。类似的 UMG 和解在 Udio 上。
- **欧盟 AI 法案** + **加州 SB 942**：AI 生成的音乐必须被披露。
- **Riffusion / MusicGen** 在 MIT 下没有合规包袱，但也没有商业人声。

安全的发布模式：

1. 仅生成器乐（MusicGen、Stable Audio Open、MIT/CC0 输出）。
2. 使用商业 API（Suno、Udio、ElevenLabs Music）并携带每次生成的许可。
3. 在自有或许可的目录上训练（大多数企业最终选择此路径）。
4. 用水印 + 元数据标记生成内容。

## 构建

### 步骤 1：用 MusicGen 生成

```python
from audiocraft.models import MusicGen
import torchaudio

model = MusicGen.get_pretrained("facebook/musicgen-small")
model.set_generation_params(duration=10)
wav = model.generate(["upbeat synthwave with driving drums, 128 BPM"])
torchaudio.save("out.wav", wav[0].cpu(), 32000)
```

三种大小：`small`（300M，快）、`medium`（1.5B）、`large`（3.3B）。Small 足以判断"创意是否站得住"。

### 步骤 2：旋律条件生成

```python
melody, sr = torchaudio.load("humming.wav")
wav = model.generate_with_chroma(
    ["jazz piano cover"],
    melody.squeeze(),
    sr,
)
```

MusicGen-melody 接受半音阶图并在交换音色的同时保留旋律。用于"给我这个旋律的弦乐四重奏版"。

### 步骤 3：FAD 评估

```python
from frechet_audio_distance import FrechetAudioDistance
fad = FrechetAudioDistance()

fad.get_fad_score("generated_folder/", "reference_folder/")
```

计算 VGGish 嵌入距离。用于流派级别的回归测试；不能替代人类听众。

### 步骤 4：添加到 LLM-音乐工作流

结合第 7-8 课的想法：

```python
prompt = "Write a 30-second jazz loop. Describe the drums, bass, and piano voicing."
description = llm.complete(prompt)
music = musicgen.generate([description], duration=30)
```

## 使用

| 目标 | 技术栈 |
|------|-------|
| 器乐声音设计 | Stable Audio Open |
| 游戏 / 自适应音乐 | Google Lyria RealTime（闭源） |
| 带人声的完整歌曲（商业） | Suno v5 或 Udio v4 附带明确许可 |
| 带人声的完整歌曲（开源） | ACE-Step XL 或 YuE |
| 短广告铃音 | 以哼唱参考为旋律条件的 MusicGen |
| 音乐视频背景 | MusicGen + Stable Video Diffusion |

## 2026 年仍会发布的陷阱

- **版权洗钱提示。** "Taylor Swift 风格的歌曲"——商业 Suno/Udio 现在过滤这些，开源模型不。添加你自己的过滤列表。
- **超过 30 秒的重复/漂移。** AR 模型循环。交叉淡入淡出多个生成，或使用 ACE-Step 进行结构一致性。
- **节奏漂移。** 模型偏离 BPM。在提示中使用 BPM 标签并用 librosa 的 `beat_track` 后过滤。
- **人声可理解性。** Suno 出色；开源模型在歌词上通常模糊。如果歌词重要，使用商业 API 或微调。
- **单声道输出。** 开源模型生成单声道或伪立体声。用适当的立体声重构升级（ezst、Cartesia 的立体声扩散）。

## 交付

保存为 `outputs/skill-music-designer.md`。为音乐生成部署选择模型、许可策略、时长/结构计划和披露元数据。

## 练习

1. **简单。** 运行 `code/main.py`。它生成一个"生成式"和弦进行 + 鼓模式作为 ASCII 符号——音乐生成漫画。如果需要，可通过任何 MIDI 渲染器播放。
2. **中等。** 安装 `audiocraft`，用 MusicGen-small 在 4 种流派提示下各生成 10 秒片段，测量相对于参考流派集的 FAD。
3. **困难。** 使用 ACE-Step（或 MusicGen-melody），生成同一旋律的三个变体，使用不同音色提示。计算与提示的 CLAP 相似度以验证对齐。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| FAD | 音频 FID | 真实与生成嵌入分布之间的 Fréchet 距离。 |
| 半音阶图 | 旋律即音高 | 每帧 12 维向量；旋律条件生成的输入。 |
| 音轨 | 乐器音轨 | 分离的低音 / 鼓 / 人声 / 旋律作为 WAV。 |
| 修复 | 重新生成一段 | 遮罩时间窗口；模型只重新生成该部分。 |
| CLAP | 文本-音频 CLIP | 对比音频-文本嵌入；评估文本-音频对齐。 |
| EnCodec | 音乐编解码器 | Meta 的神经编解码器，被 MusicGen 使用；32 kHz，4 个码本。 |

## 扩展阅读

- [Copet et al. (2023). MusicGen](https://arxiv.org/abs/2306.05284)——开源自回归基准。
- [Evans et al. (2024). Stable Audio Open](https://arxiv.org/abs/2407.14358)——声音设计默认。
- [ACE-Step](https://github.com/ace-step/ACE-Step)——开源 4B 完整歌曲生成器，2026 年 4 月。
- [Suno v5 平台文档](https://suno.com)——商业质量领先者。
- [AudioLDM2](https://arxiv.org/abs/2308.05734)——音乐 + 音效的潜扩散。
- [WMG-Suno 和解报道](https://www.musicbusinessworldwide.com/suno-warner-music-settlement/)——2025 年 11 月先例。