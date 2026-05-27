# 音频基础——波形、采样、傅里叶变换

> 波形是原始信号。频谱图是表示。Mel 特征是 ML 友好的形式。每个现代 ASR 和 TTS pipeline 都走这个阶梯，而第一级台阶是理解采样和傅里叶。

**类型：** 学习
**语言：** Python
**前置要求：** 第 1 阶段 · 06（向量与矩阵），第 1 阶段 · 14（概率分布）
**时间：** 约 45 分钟

## 问题

麦克风产生压强-时间信号。你的神经网络消费张量。两者之间坐着一套常规，当被违反时会产生静默 bug：模型训练正常但 WER 翻倍，或者 TTS 发布时带嘶嘶声，或者语音克隆系统记忆了麦克风而非说话人。

语音系统中的每个 bug 都可以追溯到以下三个问题之一：

1. 数据是以什么采样率录制的，模型期望什么？
2. 信号是否混叠？
3. 你是在原始采样上操作还是在频率表示上操作？

把这些问题搞对，Phase 6 的其余部分就是可处理的。搞错了，即使 Whisper-Large-v4 也会产生垃圾。

## 概念

![波形、采样、DFT 和频率 bin 可视化](../assets/audio-fundamentals.svg)

**波形。** 一维 float 数组，在 `[-1.0, 1.0]` 范围内。按采样编号索引。转换为秒：除以采样率 `t = n / sr`。10 秒 16 kHz 的片段是 160,000 个 float 的数组。

**采样率（sr）。** 每秒采样数。2026 年常见采样率：

| 采样率 | 用途 |
|------|-----|
| 8 kHz | 电话、遗留 VOIP。Nyquist 在 4 kHz 会丢失辅音。ASR 避免使用。 |
| 16 kHz | ASR 标准。Whisper、Parakeet、SeamlessM4T v2 都消费 16 kHz。 |
| 22.05 kHz | 较旧模型的 TTS 声码器训练。 |
| 24 kHz | 现代 TTS（Kokoro、F5-TTS、xTTS v2）。 |
| 44.1 kHz | CD 音频、音乐。 |
| 48 kHz | 电影、专业音频、高保真 TTS（VALL-E 2、NaturalSpeech 3）。 |

**Nyquist-Shannon。** 采样率为 `sr` 可以明确表示最高 `sr/2` 的频率。`sr/2` 边界是 *Nyquist 频率*。高于 Nyquist 的能量会*混叠*——折叠到更低频率——并破坏信号。降采样前始终进行低通滤波。

**位深度。** 16 位 PCM（有符号 int16，范围 ±32,767）是通用交换格式。音乐用 24 位，内部 DSP 用 32 位浮点。像 `soundfile` 这样的库读取 int16 但暴露 `[-1, 1]` 范围内的 float32 数组。

**傅里叶变换。** 任何有限信号都是不同频率正弦波的和。离散傅里叶变换（DFT）为 `N` 个采样计算 `N` 个复数系数——每个频率 bin 一个。`bin k` 映射到频率 `k · sr / N` Hz。幅度是该频率的振幅，角度是相位。

**FFT。** 快速傅里叶变换：当 `N` 是 2 的幂时的 `O(N log N)` DFT 算法。每个音频库底层都使用 FFT。16 kHz 下 1024 采样的 FFT 给出 512 个可用频率 bin，跨越 0-8 kHz，分辨率为 15.6 Hz。

**分帧 + 加窗。** 我们不对整个片段做 FFT。我们将其切分成重叠的*帧*（通常是 25 ms，10 ms 跳跃），每帧乘以窗函数（Hann、Hamming）以消除边缘不连续性，然后对每帧做 FFT。这就是短时傅里叶变换（STFT）。第 02 课从此继续。

## 构建

### 步骤 1：读取片段并绘制波形

`code/main.py` 仅使用标准库 `wave` 模块保持演示无依赖。生产环境中你会使用 `soundfile` 或 `torchaudio.load`（两者都返回 `(waveform, sr)` 元组）：

```python
import soundfile as sf
waveform, sr = sf.read("clip.wav", dtype="float32")  # shape (T,), sr=int
```

### 步骤 2：从第一性原理合成正弦波

```python
import math

def sine(freq_hz, sr, seconds, amp=0.5):
    n = int(sr * seconds)
    return [amp * math.sin(2 * math.pi * freq_hz * i / sr) for i in range(n)]
```

16 kHz 下 440 Hz 正弦（音乐会 A）1 秒是 16,000 个 float。使用 16 位 PCM 编码通过 `wave.open(..., "wb")` 写入。

### 步骤 3：手写 DFT

```python
def dft(x):
    N = len(x)
    out = []
    for k in range(N):
        re = sum(x[n] * math.cos(-2 * math.pi * k * n / N) for n in range(N))
        im = sum(x[n] * math.sin(-2 * math.pi * k * n / N) for n in range(N))
        out.append((re, im))
    return out
```

`O(N²)`——适用于 `N=256` 以确认正确性，对真实音频无用。实际代码调用 `numpy.fft.rfft` 或 `torch.fft.rfft`。

### 步骤 4：找到主导频率

幅度峰值索引 `k_star` 映射到频率 `k_star * sr / N`。在 440 Hz 正弦上运行应该返回 bin `440 * N / sr` 处的峰值。

### 步骤 5：演示混叠

以 10 kHz 采样 7 kHz 正弦（Nyquist = 5 kHz）。7 kHz 音调高于 Nyquist，折叠到 `10 − 7 = 3 kHz`。FFT 峰值出现在 3 kHz。这是经典的混叠演示，也是每个 DAC/ADC 都配备砖墙低通滤波器的原因。

## 使用

2026 年实际部署的技术栈：

| 任务 | 库 | 原因 |
|------|---------|-----|
| 读/写 WAV/FLAC/OGG | `soundfile`（libsndfile 包装器） | 最快、稳定、返回 float32。 |
| 重采样 | `torchaudio.transforms.Resample` 或 `librosa.resample` | 内置正确的抗混叠。 |
| STFT / Mel | `torchaudio` 或 `librosa` | GPU 友好；PyTorch 生态。 |
| 实时流式 | `sounddevice` 或 `pyaudio` | 跨平台 PortAudio 绑定。 |
| 检查文件 | `ffprobe` 或 `soxi` | CLI，快速，报告 sr/channels/codec。 |

决策规则：**在匹配其他任何东西之前先匹配采样率**。Whisper 期望 16 kHz 单声道 float32。传入 44.1 kHz 立体声，你会得到看起来像模型 bug 的垃圾。

## 交付

保存为 `outputs/skill-audio-loader.md`。该技能帮助你检查音频输入是否匹配下游模型的期望，并在不匹配时正确重采样。

## 练习

1. **简单。** 以 16 kHz 合成 220 Hz + 440 Hz + 880 Hz 的 1 秒混合。运行 DFT。确认三个峰值在预期的 bin 处。
2. **中等。** 以 48 kHz 录制 3 秒你声音的 WAV。使用 `torchaudio.transforms.Resample`（带抗混叠）降采样到 16 kHz，然后使用简单抽取（每三个采样取一个）降采样到 16 kHz。对两者做 FFT。混叠出现在哪里？
3. **困难。** 仅使用 `math` 和步骤 3 中的 DFT 从零构建 STFT。帧大小 400，跳跃 160，Hann 窗。用 `matplotlib.pyplot.imshow` 绘制幅度。这就是第 02 课的频谱图。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| 采样率 | 每秒采样数 | ADC 测量信号的 Hz 频率。 |
| Nyquist | 你能表示的最大频率 | `sr/2`；高于此的能量会混叠回来。 |
| 位深度 | 每个采样的分辨率 | `int16` = 65,536 级；`float32` = `[-1, 1]` 中 24 位精度。 |
| DFT | 序列的傅里叶变换 | `N` 个采样 → `N` 个复数频率系数。 |
| FFT | 快速 DFT | 需要 `N` = 2 的幂的 `O(N log N)` 算法。 |
| Bin | 频率列 | `k · sr / N` Hz；分辨率 = `sr / N`。 |
| STFT | 底层的频谱图 | 随时间分帧加窗的 FFT。 |
| 混叠 | 奇怪的频率幽灵 | 高于 Nyquist 的能量镜像回更低的 bin。 |

## 扩展阅读

- [Shannon (1949). Communication in the Presence of Noise](https://people.math.harvard.edu/~ctm/home/text/others/shannon/entropy/entropy.pdf)——采样定理背后的论文。
- [Smith — The Scientist and Engineer's Guide to Digital Signal Processing](https://www.dspguide.com/ch8.htm)——免费、经典的 DSP 教材。
- [librosa docs — audio primer](https://librosa.org/doc/latest/tutorial.html)——带代码的实用教程。
- [Heinrich Kuttruff — Room Acoustics (6th ed.)](https://www.routledge.com/Room-Acoustics/Kuttruff/p/book/9781482260434)——真实世界音频为何不是干净正弦波的参考书。
- [Steve Eddins — FFT Interpretation notebook](https://blogs.mathworks.com/steve/2020/03/30/fft-spectrum-and-spectral-densities/)——10 分钟理清频率 bin 直觉。