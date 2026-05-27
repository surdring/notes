# 红队：PAIR 与自动化攻击

> Chao, Robey, Dobriban, Hassani, Pappas, Wong（NeurIPS 2023, arXiv:2310.08419）。PAIR——提示词自动迭代精炼（Prompt Automatic Iterative Refinement）——是经典的自动化黑盒越狱。一个带有红队系统提示词的攻击者 LLM 迭代地提出针对目标 LLM 的越狱方案，在其自身的聊天历史中积累尝试和响应作为上下文内反馈。PAIR 通常在 20 次查询内成功，比 GCG（Zou et al. 的 token 级梯度搜索）效率高数个数量级，且无需白盒访问。PAIR 现在是 JailbreakBench（arXiv:2404.01318）和 HarmBench 中的标准基线，与 GCG、AutoDAN、TAP 和 Persuasive Adversarial Prompt 并列。

**类型：** 构建
**语言：** Python（标准库，针对玩具目标的模拟 PAIR 循环）
**前置知识：** 第 18 阶段 · 01（指令遵循），第 14 阶段（Agent 工程）
**时间：** 约 75 分钟

## 学习目标

- 描述 PAIR 算法：攻击者系统提示词、迭代精炼、上下文内反馈。
- 解释为什么当目标为黑盒时 PAIR 严格比 GCG 更高效。
- 说出四种其他自动化攻击基线（GCG、AutoDAN、TAP、PAP）并陈述每种的一个区别特征。
- 描述 JailbreakBench 和 HarmBench 评估协议以及每种框架下"攻击成功率"的含义。

## 问题

红队过去是一项人工活动。少数专家测试者构建对抗提示词并跟踪哪些有效。这不可扩展：攻击成功率需要统计样本，且目标是随每个模型发布而变化的移动目标。PAIR 将红队操作化为一个针对黑盒目标的优化问题。

## 概念

### PAIR 算法

输入：
- 目标 LLM T（我们正在攻击的模型）。
- 裁判 LLM J（评分响应是否构成越狱）。
- 攻击者 LLM A（红队优化器）。
- 目标字符串 G："respond with [有害指令]。"
- 预算 K（通常 20 次查询）。

循环，对于 k 从 1 到 K：
1. 用目标 G 和迄今为止的 (提示词, 响应) 对历史提示 A。
2. A 产生新提示词 p_k。
3. 将 p_k 提交给 T；接收响应 r_k。
4. J 在目标上对 (p_k, r_k) 打分。
5. 如果分数 >= 阈值，停止——越狱找到。
6. 否则，将 (p_k, r_k) 追加到 A 的历史；继续。

经验结果（NeurIPS 2023）：对 GPT-3.5-turbo、Llama-2-7B-chat 的攻击成功率 >50%；成功平均查询在 10-20 范围内。

### 为什么 PAIR 高效

GCG（Zou et al. 2023）通过梯度搜索对抗 token 后缀；它需要白盒模型访问并产生不可读后缀。PAIR 是黑盒的，产生跨模型迁移的自然语言攻击。PAIR 的上下文内反馈让攻击者从每次拒绝中学习；GCG 没有等价机制（每次新的 token 更新必须重新发现先前的进展）。

### 相关自动化攻击

- **GCG（Zou et al. 2023, arXiv:2307.15043）。** token 级梯度搜索对抗后缀。白盒、可迁移、产生不可读字符串。
- **AutoDAN（Liu et al. 2023）。** 在提示词上的进化搜索，由分层目标引导。
- **TAP（Mehrotra et al. 2024）。** 带剪枝的攻击树——分支多个 PAIR 风格的展开。
- **PAP（Zeng et al. 2024）。** 说服性对抗提示词（Persuasive Adversarial Prompts）——将人类说服技术编码为提示词模板。

### JailbreakBench 和 HarmBench

两者（2024）标准化了评估：

- JailbreakBench（arXiv:2404.01318）。跨 10 个 OpenAI 策略类别的 100 种有害行为。攻击成功率（Attack Success Rate, ASR）作为主要度量。需要裁判（GPT-4-turbo、Llama Guard 或 StrongREJECT）。
- HarmBench（Mazeika et al. 2024）。跨 7 个类别的 510 种行为，带有语义和功能危害测试。比较了 18 种攻击对 33 个模型。

ASR 通常在固定查询预算下报告。比较攻击需要匹配预算；200 次查询下的 90% ASR 与 20 次查询下的 85% ASR 不可比。

### 对 2026 年部署的意义

每个前沿实验室现在在发布前都对生产模型运行 PAIR 和 TAP。ASR 轨迹出现在模型卡（第 26 课）和安全论证附录（第 18 课）中。这种攻击并非异域——它是标准基础设施。

### 这在第 18 阶段中的位置

第 12 课是自动化攻击基础。第 13 课（多示例越狱）是互补的长度漏洞利用。第 14 课（ASCII Art / 视觉）是编码攻击。第 15 课（间接提示词注入）是 2026 生产攻击面。第 16 课涵盖防御工具对应（Llama Guard、Garak、PyRIT）。

## 使用它

`code/main.py` 构建一个玩具 PAIR 循环。目标是拒绝"明显"有害提示词（关键词过滤）的模拟分类器。攻击者是基于规则的优化器，尝试释义、角色扮演框架和编码。裁判对响应打分。你观察攻击者在约 5-15 次迭代中对关键词过滤器成功，对语义过滤器失败。

## 交付它

本课生成 `outputs/skill-attack-audit.md`。给定红队评估报告，它审计：运行了哪些攻击（PAIR、GCG、TAP、AutoDAN、PAP），每种攻击的预算，哪种裁判，在哪个有害行为集（JailbreakBench、HarmBench、内部）上。

## 练习

1. 运行 `code/main.py`。测量三种内置攻击者策略的平均查询到成功次数。解释每种策略利用了哪个目标防御假设。

2. 实现第四种攻击者策略（例如，翻译到另一种语言、base64 编码）。报告针对关键词过滤目标和语义过滤目标的新平均查询到成功次数。

3. 阅读 Chao et al. 2023 图 5（PAIR vs GCG 比较）。描述两个在 PAIR 效率优势下 GCG 仍被偏好的场景。

4. JailbreakBench 报告针对固定目标集的 ASR。设计一个额外的度量，测量攻击多样性（成功提示词的方差）。解释为什么多样性对防御评估很重要。

5. TAP（Mehrotra 2024）通过分支 + 剪枝扩展 PAIR。勾勒 `code/main.py` 的 TAP 风格扩展，描述计算代价 vs 成功率的权衡。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------------|------------------------|
| PAIR | "自动化越狱" | 提示词自动迭代精炼；攻击者 LLM + 裁判 LLM 循环 |
| GCG | "梯度越狱" | 白盒 token 级梯度搜索对抗后缀 |
| Attack success rate (ASR) | "k 次查询下的越狱百分比" | 主要度量；必须与查询预算和裁判身份一起报告 |
| Judge LLM | "打分器" | 评分响应是否满足有害目标的 LLM |
| JailbreakBench | "评估" | 带标记类别的标准化有害行为集 |
| HarmBench | "更广的基准" | 510 种行为，功能 + 语义危害测试 |
| TAP | "攻击树" | 带分支 + 剪枝的 PAIR；更高计算下的更好 ASR |

## 延伸阅读

- [Chao et al. — Jailbreaking Black Box LLMs in Twenty Queries (arXiv:2310.08419)](https://arxiv.org/abs/2310.08419) — PAIR 论文, NeurIPS 2023
- [Zou et al. — Universal and Transferable Adversarial Attacks on Aligned LLMs (arXiv:2307.15043)](https://arxiv.org/abs/2307.15043) — GCG 论文
- [Chao et al. — JailbreakBench (arXiv:2404.01318)](https://arxiv.org/abs/2404.01318) — 标准化评估
- [Mazeika et al. — HarmBench (ICML 2024)](https://arxiv.org/abs/2402.04249) — 更广的评估