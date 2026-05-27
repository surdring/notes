# 聊天机器人——从规则到神经到 LLM Agent

> ELIZA 用模式匹配回复。DialogFlow 映射意图。GPT 从权重中回答。Claude 运行工具并验证。每个时代解决了上一个时代最严重的失败。

**类型：** 学习
**语言：** Python
**前置要求：** 第 5 阶段 · 13（问答），第 5 阶段 · 14（信息检索）
**时间：** 约 75 分钟

## 问题

用户说"I want to change my flight。"系统必须弄清楚他们想要什么、缺少什么信息、如何获取，以及如何完成操作。然后用户说"wait, what if I cancel instead?"，系统必须记住上下文、切换任务并保持状态。

对话对 ML 系统来说很难。输入是开放式的。输出必须在多轮中保持连贯。系统可能需要对现实世界进行操作（改签航班、扣款）。每一个错误步骤对用户都是可见的。

聊天机器人架构经历了四种范式的循环，每种范式都是因为前一种失败得太明显而被引入。本课按顺序讲解它们。2026 年生产环境是后两种的混合体。

## 概念

![聊天机器人演进：基于规则 → 检索式 → 神经 → Agent](../assets/chatbot.svg)

**基于规则（ELIZA、AIML、DialogFlow）。** 手工编写的规则匹配用户输入并生成回复。意图分类器路由到预定义的流程。槽位填充状态机收集所需信息。在其设计的狭窄范围内表现完美。超出范围立刻失败。仍然部署在安全关键领域（银行认证、机票预订），这些领域不允许幻觉。

**检索式。** 类似 FAQ 的系统。编码每一对（用户话语，回复）。运行时编码用户消息并检索最相似的存储回复。想想 Zendesk 经典的"相似文章"功能。比规则更好地处理同义改写。不生成，所以没有幻觉。

**神经（seq2seq）。** 在对话日志上训练的编码器-解码器。从头生成回复。流畅但倾向于产生通用输出（"I don't know"）和事实漂移。从不可靠地保持话题。这就是 Google、Facebook 和 Microsoft 在 2016-2019 年都有令人失望的聊天机器人的原因。

**LLM Agent。** 一个语言模型被包装在一个循环中，循环包括规划、调用工具和验证结果。不是一个带有长提示的聊天机器人。Agent 循环：规划 → 调用工具 → 观察结果 → 决定下一步。检索优先的接地（RAG）防止幻觉。工具调用让它能真正做事情。这是 2026 年的架构。

这四种范式不是顺序替代。一个 2026 年的生产聊天机器人通过全部四种方式路由：基于规则处理认证和破坏性操作，检索式处理 FAQ，神经生成为自然措辞，LLM Agent 处理模糊的开放式查询。

## 构建

### 步骤 1：基于规则的模式匹配

```python
import re


class RulePattern:
    def __init__(self, pattern, response_template):
        self.regex = re.compile(pattern, re.IGNORECASE)
        self.template = response_template


PATTERNS = [
    RulePattern(r"my name is (\w+)", "Nice to meet you, {0}."),
    RulePattern(r"i (need|want) (.+)", "Why do you {0} {1}?"),
    RulePattern(r"i feel (.+)", "Why do you feel {0}?"),
    RulePattern(r"(.*)", "Tell me more about that."),
]


def rule_based_respond(user_input):
    for pattern in PATTERNS:
        m = pattern.regex.match(user_input.strip())
        if m:
            return pattern.template.format(*m.groups())
    return "I don't understand."
```

ELIZA 用 20 行代码。反射技巧（"I feel sad" → "Why do you feel sad"）是 Weizenbaum 1966 年经典的心理学演示。今天仍然有教育意义。

### 步骤 2：检索式（FAQ）

这个示例代码需要 `pip install sentence-transformers`（会拉取 torch）。本课的 `code/main.py` 改为使用标准库 Jaccard 相似度，因此本课无需外部依赖即可运行。

```python
from sentence_transformers import SentenceTransformer
import numpy as np


FAQ = [
    ("how do i reset my password", "Go to Settings > Security > Reset Password."),
    ("how do i cancel my order", "Go to Orders, find the order, click Cancel."),
    ("what is your return policy", "30-day returns on unused items, original packaging."),
]


encoder = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2")
faq_questions = [q for q, _ in FAQ]
faq_embeddings = encoder.encode(faq_questions, normalize_embeddings=True)


def faq_respond(user_input, threshold=0.5):
    q_emb = encoder.encode([user_input], normalize_embeddings=True)[0]
    sims = faq_embeddings @ q_emb
    best = int(np.argmax(sims))
    if sims[best] < threshold:
        return None
    return FAQ[best][1]
```

基于阈值的拒绝是关键设计选择。如果最佳匹配不够接近，返回 `None` 让系统升级处理。

### 步骤 3：神经生成（基线）

使用小型指令微调的编码器-解码器（FLAN-T5）或微调的对话模型。在 2026 年单独使用不可用于生产（矛盾、离题漂移、事实性谬误），但在混合系统内部用于自然措辞。DialoGPT 风格的仅解码器模型需要显式的轮次分隔符和 EOS 处理才能产生连贯的回复；FLAN-T5 text2text pipeline 在教学示例中开箱即用。

```python
from transformers import pipeline

chatbot = pipeline("text2text-generation", model="google/flan-t5-small")

response = chatbot("Respond politely to: Hi there!", max_new_tokens=40)
print(response[0]["generated_text"])
```

### 步骤 4：LLM Agent 循环

2026 年生产形态：

```python
def agent_loop(user_message, tools, llm, max_steps=5):
    history = [{"role": "user", "content": user_message}]
    for _ in range(max_steps):
        response = llm(history, tools=tools)
        tool_call = response.get("tool_call")
        if tool_call:
            tool_name = tool_call.get("name")
            args = tool_call.get("arguments")
            if not isinstance(tool_name, str) or tool_name not in tools:
                history.append({"role": "assistant", "tool_call": tool_call})
                history.append({"role": "tool", "name": str(tool_name), "content": f"error: unknown tool {tool_name!r}"})
                continue
            if not isinstance(args, dict):
                history.append({"role": "assistant", "tool_call": tool_call})
                history.append({"role": "tool", "name": tool_name, "content": f"error: arguments must be a dict, got {type(args).__name__}"})
                continue
            fn = tools[tool_name]
            result = fn(**args)
            history.append({"role": "assistant", "tool_call": tool_call})
            history.append({"role": "tool", "name": tool_name, "content": result})
        else:
            return response["content"]
    return "I could not complete the task in the step budget."
```

三个需要命名的要点。工具是 LLM 可以调用的可调用函数。循环在 LLM 返回最终答案而非工具调用时终止。步骤预算防止在模糊任务上的无限循环。

真实生产还增加：检索优先接地（每次 LLM 调用前注入相关文档）、护栏（拒绝未经确认的破坏性操作）、可观测性（记录每一步）和评估（自动检查 Agent 行为保持合规）。

### 步骤 5：混合路由

```python
def hybrid_chat(user_input):
    if is_destructive_action(user_input):
        return structured_flow(user_input)

    faq_answer = faq_respond(user_input, threshold=0.6)
    if faq_answer:
        return faq_answer

    return agent_loop(user_input, tools, llm)


def is_destructive_action(text):
    danger_words = ["delete", "cancel", "charge", "refund", "transfer"]
    return any(w in text.lower() for w in danger_words)
```

模式：破坏性操作用确定性规则，FAQ 用检索式，其他所有用 LLM Agent。这是 2026 年客户支持系统的部署方式。

## 使用

2026 年技术栈：

| 用例 | 架构 |
|---------|---------------|
| 预订、支付、认证 | 基于规则的状态机 + 槽位填充 |
| 客户支持 FAQ | 基于精选答案的检索 |
| 开放式帮助对话 | 带 RAG + 工具调用的 LLM Agent |
| 内部工具 / IDE 助手 | 带工具调用的 LLM Agent（搜索、读取、写入） |
| 陪伴 / 角色聊天机器人 | 带角色系统提示的调优 LLM，知识检索 |

生产环境中始终使用混合路由。没有单一架构能处理好每种请求。路由层本身通常是一个小型意图分类器。

## 仍然在线上运行的失败模式

- **自信编造。** LLM Agent 声称完成了它没有执行的操作。缓解：验证结果，记录工具调用，绝不让 LLM 在没有成功的工具返回的情况下声称做了什么。
- **提示注入。** 用户插入覆盖系统提示的文本。在 2025 年 OWASP LLM 应用 Top 10 中排名 LLM01。两种形式：直接注入（粘贴到聊天中）和间接注入（隐藏在 Agent 读取的文档、邮件或工具输出中）。

  攻击率因场景而异。前沿模型在通用工具使用和编码基准上的测量成功率约为 0.5-8.5%。特定高风险设置（针对 AI 编码 Agent 的自适应攻击、易受攻击的编排）可达约 84%。生产 CVE 包括 EchoLeak（CVE-2025-32711，CVSS 9.3）——通过攻击者控制的邮件触发的 Microsoft 365 Copilot 零点击数据泄露缺陷。

  缓解措施：在整个循环中将用户输入视为不可信；在工具调用前清理；将工具输出与主提示隔离；使用规划-验证-执行（PVE）模式，即 Agent 先规划，然后在执行前验证每个操作是否符合该计划（这阻止工具结果注入新的非计划操作）；破坏性操作需要用户确认；对工具权限应用最小特权。

  没有任何提示工程能完全消除这一风险。需要外部运行时防御层（LLM Guard、白名单验证、语义异常检测）。
- **范围蔓延。** Agent 偏离任务因为工具调用返回了切题但不相关的信息。缓解：收窄工具合约；保持系统提示聚焦；为离题率添加评估。
- **无限循环。** Agent 反复调用同一个工具。缓解：步骤预算、工具调用去重、LLM 判断"我们是否在取得进展"。
- **上下文窗口耗尽。** 长对话将最早几轮推出上下文。缓解：摘要早期轮次、按相似度检索相关过去轮次，或使用长上下文模型。

## 交付

保存为 `outputs/skill-chatbot-architect.md`：

```markdown
---
name: chatbot-architect
description: 为给定用例设计聊天机器人技术栈。
version: 1.0.0
phase: 5
lesson: 17
tags: [nlp, agents, chatbot]
---

给定产品上下文（用户需求、合规约束、可用工具、数据量），输出：

1. 架构。基于规则、检索式、神经、LLM Agent 或混合（指定哪些路径走哪条）。
2. 选用的 LLM。命名模型系列（Claude、GPT-4、Llama-3.1、Mixtral）。匹配工具使用质量和成本。
3. 接地策略。RAG 来源、检索方法（见第 14 课）、工具合约。
4. 评估计划。任务成功率、工具调用正确性、离题率、留出对话上的幻觉率。

拒绝为任何破坏性操作（支付、账户删除、数据修改）推荐纯 LLM Agent，除非有结构化确认流程。拒绝在 Agent 拥有对任何内容的写权限时跳过提示注入审计。
```

## 练习

1. **简单。** 用 10 个模式实现上述基于规则的回复，用于咖啡店订购机器人。测试边界情况：重复订单、修改、取消、模糊意图。
2. **中等。** 构建混合 FAQ + LLM 后备。50 条 SaaS 产品 FAQ，LLM 后备在文档站点上检索。在 100 个真实支持问题上衡量拒绝率和准确率。
3. **困难。** 用三个工具（搜索、读取用户数据、发送邮件）实现上述 Agent 循环。在包含提示注入尝试的 50 个测试场景上运行评估。报告离题率、失败任务率和任何注入成功。

## 关键术语

| 术语 | 人们怎么说 | 实际含义 |
|------|-----------|---------|
| 意图 | 用户想要什么 | 分类标签（book_flight, reset_password）。路由到处理函数。 |
| 槽位 | 一条信息 | 机器人需要收集的参数（日期、目的地）。槽位填充是依次询问的序列。 |
| RAG | 检索加生成 | 检索相关文档，然后为 LLM 的响应接地。 |
| 工具调用 | 函数调用 | LLM 发出带名称 + 参数的结构化调用。运行时执行，返回结果。 |
| Agent 循环 | 规划、执行、验证 | 控制器运行 LLM 调用，与工具调用交替，直至任务完成。 |
| 提示注入 | 用户攻击提示 | 试图覆盖系统提示的恶意输入。 |

## 扩展阅读

- [Weizenbaum (1966). ELIZA — A Computer Program For the Study of Natural Language Communication](https://web.stanford.edu/class/cs124/p36-weizenabaum.pdf)——原始基于规则的聊天机器人论文。
- [Thoppilan et al. (2022). LaMDA: Language Models for Dialog Applications](https://arxiv.org/abs/2201.08239)——Google 晚期的神经聊天机器人论文，就在 LLM Agent 接管之前。
- [Yao et al. (2022). ReAct: Synergizing Reasoning and Acting in Language Models](https://arxiv.org/abs/2210.03629)——命名 Agent 循环模式的论文。
- [Anthropic 关于构建有效 Agent 的指南](https://www.anthropic.com/research/building-effective-agents)——2024 年生产指导，在 2026 年仍然有效。
- [Greshake et al. (2023). Not what you've signed up for: Compromising Real-World LLM-Integrated Applications with Indirect Prompt Injection](https://arxiv.org/abs/2302.12173)——提示注入论文。
- [OWASP Top 10 for LLM Applications 2025 — LLM01 Prompt Injection](https://genai.owasp.org/llmrisk/llm01-prompt-injection/)——将提示注入列为最高安全关切的排名。
- [AWS — Securing Amazon Bedrock Agents against Indirect Prompt Injections](https://aws.amazon.com/blogs/machine-learning/securing-amazon-bedrock-agents-a-guide-to-safeguarding-against-indirect-prompt-injections/)——实用的编排层防御，包括规划-验证-执行和用户确认流程。
- [EchoLeak (CVE-2025-32711)](https://www.vectra.ai/topics/prompt-injection)——来自间接提示注入的经典零点击数据泄露 CVE。为什么有写权限的 Agent 需要运行时防御的参考案例。