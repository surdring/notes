# 综合项目 12 — 视频理解管道（场景、问答、搜索）

> Twelve Labs 将 Marengo + Pegasus 产品化。VideoDB 发布了视频 CRUD API。AI2 的 Molmo 2 发布了开源 VLM 检查点。Gemini 长上下文原生处理数小时的视频。TimeLens-100K 定义了大尺度时间定位。2026 年的管道已经定型：场景分割、每场景字幕 + 嵌入、转录对齐、多向量索引，以及一个以 (开始, 结束) 时间戳和帧预览回答的查询。本综合项目旨在摄入 100 小时视频，达到公开基准测试，并衡量计数和动作类问题上的幻觉。

**类型：** 综合项目
**语言：** Python（管道）、TypeScript（UI）
**前置知识：** 阶段 4（计算机视觉）、阶段 6（语音）、阶段 7（Transformer）、阶段 11（LLM 工程）、阶段 12（多模态）、阶段 17（基础设施）
**涵盖阶段：** P4 · P6 · P7 · P11 · P12 · P17
**时间：** 30 小时

## 问题

长视频问答（long-form video QA）是 2026 年规模下最消耗带宽的多模态问题。Gemini 2.5 Pro 可以原生读取 2 小时视频，但将 100 小时视频摄入到一个可查询的语料库中仍然需要场景级索引。生产形态结合了场景分割（TransNetV2 或 PySceneDetect）、使用 VLM（Gemini 2.5、Qwen3-VL-Max 或 Molmo 2）的每场景字幕生成、转录对齐（Whisper-v3-turbo 带词级时间戳），以及一个将字幕、帧嵌入和转录并排存储的多向量索引。查询管道以 (开始, 结束) 时间戳和帧预览作答。

基准测试是公开的（ActivityNet-QA、NeXT-GQA）加上你自己的 100 个查询自定义集合。计数和动作类型问题上的幻觉是已知困难失败类别；本综合项目明确衡量它。

## 概念

三个管道在摄入时并行运行。**场景分割**将视频切割为场景。**VLM 字幕生成**为每个场景生成字幕和关键帧的帧嵌入。**ASR 对齐**生成词级时间戳。三个流通过 (scene_id, 时间范围) 连接。每个场景在多向量索引（Qdrant）中获得三种向量类型：字幕嵌入、关键帧嵌入、转录嵌入。

在查询时，自然语言问题对三种向量发出查询；结果通过倒数排名融合（RRF）合并；时间定位适配器（TimeLens 风格）在 top 场景内精炼 (开始, 结束) 窗口。VLM 合成器（Gemini 2.5 Pro 或 Qwen3-VL-Max）接受 查询 + top 场景 + 裁剪帧，并以带引用时间戳和帧预览的方式作答。

幻觉衡量很重要。计数（"有多少人进入房间？"）和动作类型（"厨师是在搅拌之前倒的油吗？"）问题 notoriously 不可靠。将准确性与描述性问题分开报告。

## 架构

```
视频文件 / URL
      |
      v
PySceneDetect / TransNetV2  （场景分割）
      |
      +--- 每场景关键帧 --- VLM 字幕 + 帧嵌入
      |                     （Gemini 2.5 Pro / Qwen3-VL-Max / Molmo 2）
      |
      +--- 音频通道 --- Whisper-v3-turbo ASR + 词级时间戳
      |
      v
多向量 Qdrant：{caption_emb, keyframe_emb, transcript_emb}
      |
查询：
  对三种向量进行稠密查询 -> RRF 合并 -> top-k 场景
      |
      v
TimeLens / VideoITG 时间定位（在场景内精炼 start/end）
      |
      v
VLM 合成：查询 + top 场景 + 帧预览
      |
      v
答案 + (开始, 结束) 时间戳 + 帧缩略图 + 引用
```

## 技术栈

- 场景分割：TransNetV2（2024-26 年最先进技术）或 PySceneDetect
- ASR：Whisper-v3-turbo 通过 faster-whisper 带词级时间戳
- VLM 字幕生成器 + 回答器：Gemini 2.5 Pro 或 Qwen3-VL-Max 或 Molmo 2
- 时间定位：TimeLens-100K 训练的适配器或 VideoITG
- 索引：Qdrant 支持多向量（字幕 / 帧 / 转录）
- UI：Next.js 15 配合 HTML5 视频播放器和场景缩略图
- 评估：ActivityNet-QA、NeXT-GQA、自定义 100 问题人工标注集
- 幻觉基准测试：带人工标签的计数和动作类型子集

## 构建步骤

1. **摄入遍历器。** 接受 YouTube URL 或本地 MP4。如有需要降采样到 720p。持久化 `{video_id, file_path}`。

2. **场景分割。** 运行 TransNetV2 或 PySceneDetect 生成 `[{scene_id, start_ms, end_ms, keyframe_path}]`。目标 100 小时：约 6k-8k 个场景。

3. **ASR 阶段。** 在音频上运行 Whisper-v3-turbo；导出词级时间戳；分割为每个场景的转录切片。

4. **VLM 字幕生成。** 每个场景，使用 Gemini 2.5 Pro（或 Qwen3-VL-Max）传入关键帧和简短字幕模板。生成字幕 + 帧嵌入。

5. **多向量索引。** Qdrant 集合包含三个命名向量。载荷：`{video_id, scene_id, start_ms, end_ms, keyframe_url}`。

6. **查询。** 自然语言问题发起三个稠密查询；通过倒数排名融合合并；top-k=5 场景。

7. **时间定位。** 在 top 场景上运行 TimeLens 风格适配器，在场景内精炼 (开始, 结束) 窗口。

8. **VLM 合成。** 使用 Gemini 2.5 Pro，传入 查询 + top-3 场景剪辑（作为图像或短视频）+ 转录。要求 `(video_id, start_ms, end_ms)` 引用。

9. **评估。** 运行 ActivityNet-QA 和 NeXT-GQA。构建 100 个查询的自定义集合。报告总体准确性 + 每个类别的分解（计数、动作、描述）。

## 使用方式

```
$ video-qa ask --url=https://youtube.com/watch?v=X "第一分钟有多少辆车经过路口？"
[scene]    检测到 23 个场景
[asr]      转录完成，4m12s
[index]    写入 69 个向量（23 场景 x 3）
[query]    top 场景：场景 3 [01:32-01:54]，置信度 0.84
[ground]   精炼窗口：[00:12-00:58]
[synth]    gemini 2.5 pro，1.4s
答案：     在 00:12 到 00:58 之间，5 辆车经过路口。
引用：     [场景 3: 00:12-00:58]
           [帧预览于 00:14、00:27、00:44、00:51、00:57]
```

## 交付标准

`outputs/skill-video-qa.md` 是交付物。给定一个 YouTube URL 或上传的视频，管道索引场景并以带时间戳引用回答问题。

| 权重 | 标准 | 衡量方式 |
|:-:|---|---|
| 25 | 时间定位 IoU | 在保留定位集上的交并比 |
| 20 | 问答准确性 | NeXT-GQA 和自定义 100 查询 |
| 20 | 摄入吞吐量 | 每花费美元摄入的视频小时数 |
| 20 | UI 和引用体验 | 时间戳链接、缩略图条、跳转到帧 |
| 15 | 幻觉率 | 分别报告计数和动作类型准确性 |
| **100** | | |

## 练习

1. 将字幕生成阶段的 Gemini 2.5 Pro 替换为 Qwen3-VL-Max。在人工评分的 50 场景样本上报告字幕质量差异。

2. 将每场景帧嵌入减少为一个池化向量而非多向量。衡量检索退化。

3. 构建 "严格计数" 模式：合成器提取每个被计数的实例及其时间戳，用户点击验证。衡量用户验证是否减少幻觉。

4. 基准测试摄入成本：在三种 VLM 选择下的每小时视频每美元。选择最佳平衡点。

5. 添加说话人分离转录：在音频上运行 pyannote 说话人分离，并嵌入每个说话人的转录。演示 "Alice 关于 X 说了什么？" 查询。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|------------------------|
| 场景分割（Scene segmentation） | "镜头检测" | 在镜头边界将视频切割为场景 |
| 多向量索引（Multi-vector index） | "字幕 + 帧 + 转录" | 每个表示有命名向量的 Qdrant 集合 |
| 时间定位（Temporal grounding） | "确切发生在什么时候" | 为查询答案精炼 (开始, 结束) 窗口 |
| 帧嵌入（Frame embedding） | "视觉表示" | 关键帧的向量嵌入；用于场景视觉相似性 |
| RRF 融合 | "倒数排名融合（Reciprocal rank fusion）" | 跨多个排序列表的合并策略；经典的混合检索技巧 |
| 计数幻觉（Counting hallucination） | "误计数" | VLM 在 "有多少 X" 问题上的已知失败模式 |
| ActivityNet-QA | "视频 QA 基准" | 长视频 QA 准确性基准 |

## 延伸阅读

- [AI2 Molmo 2](https://allenai.org/blog/molmo2) — 开源 VLM 检查点
- [TimeLens (CVPR 2026)](https://github.com/TencentARC/TimeLens) — 大尺度时间定位
- [Gemini 视频长上下文](https://deepmind.google/technologies/gemini) — 托管参考
- [VideoDB](https://videodb.io) — 视频 CRUD API 参考
- [Twelve Labs Marengo + Pegasus](https://www.twelvelabs.io) — 商业参考
- [TransNetV2](https://github.com/soCzech/TransNetV2) — 场景分割模型
- [PySceneDetect](https://github.com/Breakthrough/PySceneDetect) — 经典开源替代
- [ActivityNet-QA](https://arxiv.org/abs/1906.02467) — 参考评估基准