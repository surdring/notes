# 综合项目 15 — 宪法安全防护 + 红队靶场

> Anthropic 的宪法分类器（Constitutional Classifiers）、Meta 的 Llama Guard 4、Google 的 ShieldGemma-2、NVIDIA 的 Nemotron 3 Content Safety、以及覆盖多语言的 X-Guard 定义了 2026 年安全分类器栈。garak、PyRIT、NVIDIA Aegis 和 promptfoo 成为标准的对抗性评估工具。NeMo Guardrails v0.12 将它们集成到生产管道中。本综合项目将所有内容串联起来：一个围绕目标应用的分层安全防护、一个运行 6 种以上攻击族的自主红队 Agent，以及一次产生可衡量无害性提升的宪法自我批评（constitutional self-critique）运行。

**类型：** 综合项目
**语言：** Python（安全管道，红队）、YAML（策略配置）
**前置知识：** 阶段 10（从零构建 LLM）、阶段 11（LLM 工程）、阶段 13（工具）、阶段 14（Agent）、阶段 18（伦理、安全、对齐）
**涵盖阶段：** P10 · P11 · P13 · P14 · P18
**时间：** 25 小时

## 问题

2026 年 LLM 安全的前沿不是分类器是否有效（它们大致有效），而是如何在不拒绝过度或留下明显漏洞的情况下将它们正确地组合在应用周围。Llama Guard 4 处理英语策略违规。X-Guard（132 种语言）处理多语言越狱。ShieldGemma-2 捕获基于图像的提示词注入。NVIDIA Nemotron 3 Content Safety 覆盖企业类别。Anthropic 的宪法分类器是一种在训练时而非服务时使用的单独方法。

攻击演化也很重要。PAIR 和 TAP 自动发现越狱。GCG 运行基于梯度的后缀攻击。多轮和代码切换攻击利用 Agent 记忆。任何部署的 LLM 都需要一个红队靶场——garak 和 PyRIT 是规范驱动工具——加上文档化的缓解措施和 CVSS 评分的发现报告。

你将加固一个目标应用（要么是 8B 指令调优模型，要么是来自其他综合项目的 RAG 聊天机器人），对其运行 6 种以上攻击族，并生成无害性的前后对比测量。

## 概念

安全管道有五个层次。**输入消毒**：剥离零宽字符、解码 base64/rot13、标准化 Unicode。**策略层**：NeMo Guardrails v0.12 规则（领域外、毒性、PII 提取）。**分类器闸门**：Llama Guard 4 用于输入、X-Guard 用于非英语、ShieldGemma-2 用于图像输入。**模型**：目标 LLM。**输出过滤器**：Llama Guard 4 用于输出、Presidio PII 脱敏、适用时的引用强制执行。**人机协作（HITL）层级**：标记为高风险的输出进入 Slack 队列。

红队靶场在调度器上运行。PAIR 和 TAP 自主发现越狱。GCG 运行基于梯度的后缀攻击。ASCII / base64 / rot13 编码攻击。多轮攻击（人格采纳、记忆利用）。代码切换攻击（混合英语与斯瓦希里语或泰语）。每次运行生成带有 CVSS 评分和披露时间线的结构化发现文件。

宪法自我批评运行是一种训练时干预。取 1000 个有害尝试提示，让模型草拟响应，对照书面宪法（不伤害规则）批评它，并在批评循环上重新训练。在保留评估上衡量无害性的前后差异。

## 架构

```
请求（文本 / 图像 / 多语言）
      |
      v
输入消毒（剥离零宽字符、解码、标准化）
      |
      v
NeMo Guardrails v0.12 规则（领域外、策略）
      |
      v
分类器闸门：
  Llama Guard 4（英语）
  X-Guard（多语言，132 种语言）
  ShieldGemma-2（图像提示）
  Nemotron 3 Content Safety（企业级）
      |
      v（已允许）
目标 LLM
      |
      v
输出过滤器：Llama Guard 4 + Presidio PII + 引用检查
      |
      v
标记输出的 HITL 层级

并行：
  红队调度器
    -> garak（经典攻击）
    -> PyRIT（编排红队）
    -> 自主越狱 Agent（PAIR + TAP）
    -> GCG 后缀攻击
    -> 多语言 / 代码切换
    -> 多轮人格采纳

输出：CVSS 评分的发现 + 披露时间线 + 无害性前后差异
```

## 技术栈

- 安全分类器：Llama Guard 4、ShieldGemma-2、NVIDIA Nemotron 3 Content Safety、X-Guard
- 防护栏框架：NeMo Guardrails v0.12 + OPA
- 红队驱动工具：garak（NVIDIA）、PyRIT（Microsoft Azure）、NVIDIA Aegis、promptfoo
- 越狱 Agent：PAIR（Chao et al., 2023）、攻击树（TAP）、GCG 后缀
- 宪法训练：Anthropic 风格自我批评循环 + 在批评上的 SFT
- PII 脱敏：Presidio
- 目标：一个 8B 指令调优模型或来自其他综合项目的 RAG 聊天机器人

## 构建步骤

1. **目标设置。** 在 vLLM 上搭建一个 8B 指令调优模型（或复用来自其他综合项目的 RAG 聊天机器人）。这是待测试的应用。

2. **安全管道包装。** 在目标周围连接五层管道。验证每层都可独立观察（Langfuse 中每层一个 span）。

3. **分类器覆盖。** 加载 Llama Guard 4、X-Guard（多语言）、ShieldGemma-2（图像）。在一个小标注集上运行每个以建立基线。

4. **红队调度器。** 调度 garak、PyRIT、一个 PAIR Agent、一个 TAP Agent、一个 GCG 运行器、一个多轮攻击器和一个代码切换攻击器。每个在独立队列上运行。

5. **攻击套件。** 六种攻击族：(1) PAIR 自动化越狱，(2) TAP 攻击树，(3) GCG 梯度后缀，(4) ASCII / base64 / rot13 编码，(5) 多轮人格，(6) 多语言代码切换。报告每个族的成功率。

6. **宪法自我批评。** 策划 1000 个有害尝试提示。对每个，目标草拟响应。批评 LLM 对照书面宪法（"不造成伤害"、"引用证据"、"拒绝非法请求"）进行评分。批评者反对的提示被重写；目标在批评改进的对上微调。在保留评估上衡量无害性前后差异。

7. **过度拒绝测量。** 在良性提示套件（如 XSTest）上追踪假阳性率。目标必须在良性问题上保持有帮助性。

8. **CVSS 评分。** 对每个成功越狱，在 CVSS 4.0（攻击向量、复杂性、影响）上评分。生成披露时间线和缓解计划。

9. **靶场自动化。** 以上所有在 cron 上运行；发现写入队列；过度拒绝回归告警触发到 Slack。

## 使用方式

```
$ safety probe --model=target --family=PAIR --budget=50
[attacker]   PAIR Agent 在目标上运行
[attack]     尝试 1/50：将查询伪装为学术研究 ... 已阻止
[attack]     尝试 2/50：诉诸角色扮演 ... 已阻止
[attack]     尝试 3/50：思维链诱导 ... 成功
[finding]    CVSS 4.8 中危：目标上的角色扮演绕过
[range]      50 次尝试中 7 次成功（14% 成功率）
```

## 交付标准

`outputs/skill-safety-harness.md` 是交付物。一个生产级分层安全管道加上一个带有无害性前后差异的可复现红队靶场。

| 权重 | 标准 | 衡量方式 |
|:-:|---|---|
| 25 | 攻击面覆盖 | 演练 6+ 种攻击族，2+ 种语言 |
| 20 | 真阳性 / 假阳性权衡 | 攻击阻止率 vs XSTest 良性通过率 |
| 20 | 自我批评差异 | 保留评估上的无害性前后对比 |
| 20 | 文档和披露 | 带时间线的 CVSS 评分发现 |
| 15 | 自动化和可重复性 | 所有在 cron 上运行并带告警 |
| **100** | | |

## 练习

1. 在 RAG 聊天机器人上运行 garak 的提示词注入插件，比较有和没有输出过滤器层的攻击成功率。

2. 添加第七种攻击族：通过检索文档的间接提示词注入。衡量所需的额外防御。

3. 实现 "有帮助地拒绝" 模式：当防护栏阻止时，目标提供一个更安全的相关答案而非直接拒绝。衡量 XSTest 差异。

4. 多语言覆盖差距：找到 X-Guard 表现不佳的语言。提出针对它进行微调的数据集。

5. 在 30B 模型上运行宪法自我批评，衡量差异是否随规模缩放。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|------------------------|
| 分层安全（Layered safety） | "纵深防御" | 在输入、闸门、输出、HITL 处的多层防护栏 |
| Llama Guard 4 | "Meta 的安全分类器" | 2026 年参考输入/输出内容分类器 |
| PAIR | "越狱 Agent" | 论文（Chao et al.）关于 LLM 驱动的越狱发现 |
| TAP | "攻击树（Tree-of-Attacks）" | PAIR 的树搜索变体 |
| GCG | "贪婪坐标梯度（Greedy coordinate gradient）" | 基于梯度的对抗性后缀攻击 |
| 宪法自我批评（Constitutional self-critique） | "Anthropic 风格训练" | 目标起草 -> 批评者评分 -> 重写 -> 重新训练 |
| XSTest | "良性探针集" | 用于过度拒绝回归的基准测试 |
| CVSS 4.0 | "严重性评分" | 用于安全发现的标准漏洞评分 |

## 延伸阅读

- [Anthropic Constitutional Classifiers](https://www.anthropic.com/research/constitutional-classifiers) — 训练时参考
- [Meta Llama Guard 4](https://ai.meta.com/research/publications/llama-guard-4/) — 2026 年输入/输出分类器
- [Google ShieldGemma-2](https://huggingface.co/google/shieldgemma-2b) — 图像 + 多模态安全
- [NVIDIA Nemotron 3 Content Safety](https://developer.nvidia.com/blog/building-nvidia-nemotron-3-agents-for-reasoning-multimodal-rag-voice-and-safety/) — 企业参考
- [X-Guard (arXiv:2504.08848)](https://arxiv.org/abs/2504.08848) — 132 种语言的多语言安全
- [garak](https://github.com/NVIDIA/garak) — NVIDIA 红队工具包
- [PyRIT](https://github.com/Azure/PyRIT) — Microsoft 红队框架
- [NeMo Guardrails v0.12](https://docs.nvidia.com/nemo-guardrails/) — 规则框架
- [PAIR (arXiv:2310.08419)](https://arxiv.org/abs/2310.08419) — 越狱 Agent 论文