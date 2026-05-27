# 为什么需要多 Agent？

> 一个代理会碰壁。聪明的做法不是更大的代理——而是更多的代理。

**类型：** 学习
**语言：** TypeScript
**前置知识：** 第 14 阶段（Agent 工程）
**时间：** 约 60 分钟

## 学习目标

- 识别单代理天花板（Single-Agent Ceiling）（上下文溢出、混合专业知识、顺序瓶颈），并解释何时拆分为多个代理是正确之举
- 比较编排模式（管道、并行扇出、监督者、层次化），并为给定的任务结构选择合适的模式
- 设计一个具有清晰角色边界、共享状态和通信契约的多代理系统
- 分析多代理复杂性的权衡（延迟、成本、调试难度）与单代理简单性的对比

## 问题

你在第 14 阶段构建了一个单代理。它能用。它可以读取文件、运行命令、调用 API 并对结果进行推理。然后你把它指向一个真实的代码库：200 个文件、三种语言、依赖于基础设施的测试，以及在编写代码之前需要研究外部 API 的需求。

代理卡住了。不是因为 LLM 不够聪明，而是因为任务超出了单个代理循环能处理的范围。上下文窗口被文件内容填满。代理忘记了 40 个工具调用之前读过什么。它试图同时成为研究员、程序员和审查者，但三者都做得不好。

这就是单代理天花板。每当任务需要以下内容时，你就会碰到它：

- **超出单窗口容纳的上下文** — 读 50 个文件就超过 20 万 token
- **不同阶段需要不同专业能力** — 研究需要不同于代码生成的提示
- **可以并行完成的工作** — 为什么按顺序读三个文件，而不能同时读？

## 概念

### 单代理天花板

一个单代理是一个循环、一个上下文窗口、一个系统提示。想象一下：

```
┌─────────────────────────────────────────┐
│            单代理                        │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │         上下文窗口                 │  │
│  │                                   │  │
│  │  研究笔记                         │  │
│  │  + 代码文件                       │  │
│  │  + 测试输出                       │  │
│  │  + 审查反馈                       │  │
│  │  + API 文档                       │  │
│  │  + ...                            │  │
│  │                                   │  │
│  │  ██████████████████████ 已满 ███  │  │
│  └───────────────────────────────────┘  │
│                                         │
│  一个系统提示试图覆盖                    │
│  研究 + 编码 + 审查 + 测试              │
│                                         │
│  结果：每样都平庸                        │
└─────────────────────────────────────────┘
```

三个东西会崩溃：

1. **上下文饱和（Context Saturation）** — 工具结果不断堆积。到第 30 轮时，代理已经消耗了 15 万 token 的文件内容、命令输出和先前推理。第 5 轮的关键细节已经丢失。

2. **角色混淆（Role Confusion）** — 一个写着「你是研究员、程序员、审查者和测试者」的系统提示，会产生一个半研究、半编码、从不完成审查的代理。

3. **顺序瓶颈（Sequential Bottleneck）** — 代理先读文件 A，然后文件 B，然后文件 C。三次串行 LLM 调用。三次串行工具执行。没有并行。

### 多代理解决方案

拆分工作。给每个代理一个任务、一个上下文窗口和一个针对该任务调优的系统提示：

```
┌──────────────────────────────────────────────────────────┐
│                    编排者                                │
│                                                          │
│  "为用户管理构建 REST API"                                │
│                                                          │
│         ┌──────────┬──────────┬──────────┐               │
│         │          │          │          │               │
│         ▼          ▼          ▼          ▼               │
│   ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐  │
│   │ 研究员   │ │  程序员  │ │  审查者  │ │  测试者  │  │
│   │          │ │          │ │          │ │          │  │
│   │ 读文档   │ │ 写代码   │ │ 检查代码 │ │ 运行测试 │  │
│   │ 找模式   │ │ 基于研究 │ │ 质量      │ │ 报告结果 │  │
│   │          │ │ + 规格   │ │ 找 Bug   │ │          │  │
│   └─────┬────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘  │
│         │           │            │             │         │
│         └───────────┴────────────┴─────────────┘         │
│                          │                               │
│                     合并结果                             │
└──────────────────────────────────────────────────────────┘
```

每个代理拥有：
- 专注的系统提示（「你是一个代码审查者。你唯一的工作是找 Bug。」）
- 自己的上下文窗口（不被其他代理的工作污染）
- 清晰的输入/输出契约（接收研究笔记，输出代码）

### 这样做的真实系统

**Claude Code 子代理（Subagent）** — 当 Claude Code 通过 `Task` 生成子代理时，它创建一个具有限定任务的子代理。父代理保持其上下文干净。子代理做专注的工作并返回摘要。

**Devin** — 运行一个规划代理、一个编码代理和一个浏览器代理。规划者将工作分解为步骤。编码者编写代码。浏览器研究文档。每个都有独立的上下文。

**多代理编码团队（SWE-bench）** — 在 SWE-bench 上表现最好的系统使用一个读取代码库的研究员、一个设计修复方案的规划者和一个实现修复的程序员。单代理系统得分更低。

**ChatGPT Deep Research** — 并行生成多个搜索代理，每个探索不同的角度，然后综合结果。

### 频谱

多代理不是二元的。它是一个频谱：

```
简单 ──────────────────────────────────────────── 复杂

 单代理      子代理       管道        团队        集群

 ┌───┐       ┌───┐        ┌───┐───┐    ┌───┐───┐    ┌─┐┌─┐┌─┐
 │ A │       │ A │        │ A │ B │    │ A │ B │    │ ││ ││ │
 └───┘       └─┬─┘        └───┘─┬─┘    └─┬─┘─┬─┘    └┬┘└┬┘└┬┘
               │                │        │   │       ┌┴──┴──┴┐
             ┌─┴─┐          ┌───┘───┐    │   │       │共享   │
             │ a │          │ C │ D │  ┌─┴───┴─┐    │ 状态  │
             └───┘          └───┘───┘  │ 消息   │    └───────┘
                                       │ 总线   │
 1 个循环   父代理 +      逐阶段      │       │     N 个对等方
 1 个上下文 子任务        传递         └───────┘    涌现行为
                                      明确角色
```

**单代理（Single Agent）** — 一个循环，一个提示。适合简单任务。

**子代理（Subagent）** — 父代理为专注的子任务生成子代理。父代理维护计划。子代理报告回来。这就是 Claude Code 所做的。

**管道（Pipeline）** — 代理按顺序运行。代理 A 的输出成为代理 B 的输入。适合分阶段工作流：研究 -> 编码 -> 审查 -> 测试。

**团队（Team）** — 代理并行运行，共享消息总线。每个都有一个角色。编排者协调。适合需要同时使用不同技能的场景。

**集群（Swarm）** — 许多相同或几乎相同的代理，共享状态。没有固定的编排者。代理从队列中领取工作。适合高吞吐量并行任务。

### 四种多代理模式

#### 模式 1：管道

```
输入 ──▶ 代理 A ──▶ 代理 B ──▶ 代理 C ──▶ 输出
          (研究)     (编码)     (审查)
```

每个代理转换数据并向前传递。易于推理。一个阶段的失败会阻塞后续阶段。

#### 模式 2：扇出 / 扇入

```
                ┌──▶ 代理 A ──┐
                │              │
输入 ──▶ 拆分   ├──▶ 代理 B ──├──▶ 合并 ──▶ 输出
                │              │
                └──▶ 代理 C ──┘
```

将工作拆分到并行代理，然后合并结果。适合可分解为独立子任务的任务。

#### 模式 3：编排者-工作者

```
                    ┌──────────┐
                    │  编排者  │
                    └──┬───┬───┘
                 任务  │   │  任务
                 ┌─────┘   └─────┐
                 ▼               ▼
           ┌──────────┐   ┌──────────┐
           │ 工作者 A │   │ 工作者 B │
           └──────────┘   └──────────┘
```

一个智能编排者决定做什么，委托给工作者，并综合结果。编排者本身是一个具有生成工作者工具的代理。

#### 模式 4：对等集群

```
         ┌───┐ ◄──── 消息 ────▶ ┌───┐
         │ A │                  │ B │
         └─┬─┘                  └─┬─┘
           │                      │
     消息  │    ┌───────────┐     │ 消息
           └───▶│  共享     │◄────┘
                │  状态     │
           ┌───▶│  / 队列   │◄────┐
           │    └───────────┘     │
     消息  │                      │ 消息
         ┌─┴─┐                  ┌─┴─┐
         │ C │ ◄──── 消息 ────▶ │ D │
         └───┘                  └───┘
```

没有中央编排者。代理通过点对点通信。决策从交互中涌现。更难调试，但可扩展到很多代理。

### 什么时候不要用多代理

多代理增加了复杂性。代理之间的每条消息都是潜在的故障点。调试从「读一个对话」变成「追踪五个代理之间的消息」。

**保持单代理的情况：**
- 任务适合一个上下文窗口（工作数据低于约 10 万 token）
- 不同阶段不需要不同的系统提示
- 顺序执行足够快
- 任务足够简单，拆分带来的开销大于收益

**复杂性成本：**
- 每个代理边界都是一次有损压缩：代理 A 的完整上下文被压缩成一条消息传给代理 B
- 协调逻辑（谁做什么、何时、什么顺序）本身是 Bug 来源
- 延迟增加：N 个代理意味着最少 N 次串行 LLM 调用，如果它们需要来回沟通则更多
- 成本倍增：每个代理独立消耗 token

经验法则：如果任务需要的工具调用少于 20 次且适合 10 万 token，保持单代理。

## 构建

### 步骤 1：过载的单代理

这里是一个试图做所有事情的单代理。它有一个庞大的系统提示和一个同时容纳研究、代码和审查的上下文窗口：

```typescript
type AgentResult = {
  content: string;
  tokensUsed: number;
  toolCalls: number;
};

async function singleAgentApproach(task: string): Promise<AgentResult> {
  const systemPrompt = `你是一个全栈开发者。你必须：
1. 研究需求
2. 编写代码
3. 审查代码中的 Bug
4. 编写测试
在单个对话中完成所有这些。`;

  const contextWindow: string[] = [];
  let totalTokens = 0;
  let totalToolCalls = 0;

  const research = await fakeLLMCall(systemPrompt, `研究: ${task}`);
  contextWindow.push(research.output);
  totalTokens += research.tokens;
  totalToolCalls += research.calls;

  const code = await fakeLLMCall(
    systemPrompt,
    `根据以下研究:\n${contextWindow.join("\n")}\n\n现在为: ${task} 编写代码`
  );
  contextWindow.push(code.output);
  totalTokens += code.tokens;
  totalToolCalls += code.calls;

  const review = await fakeLLMCall(
    systemPrompt,
    `根据所有先前上下文:\n${contextWindow.join("\n")}\n\n审查代码。`
  );
  contextWindow.push(review.output);
  totalTokens += review.tokens;
  totalToolCalls += review.calls;

  return {
    content: contextWindow.join("\n---\n"),
    tokensUsed: totalTokens,
    toolCalls: totalToolCalls,
  };
}
```

这种方法的问题：
- 上下文窗口在每个阶段都在增长。到审查步骤时，它包含研究笔记 AND 代码 AND 先前的推理。
- 系统提示是通用的。无法为每个阶段调优。
- 没有并行运行。

### 步骤 2：专业代理

现在拆分。每个代理一个任务：

```typescript
type SpecialistAgent = {
  name: string;
  systemPrompt: string;
  run: (input: string) => Promise<AgentResult>;
};

function createSpecialist(name: string, systemPrompt: string): SpecialistAgent {
  return {
    name,
    systemPrompt,
    run: async (input: string) => {
      const result = await fakeLLMCall(systemPrompt, input);
      return {
        content: result.output,
        tokensUsed: result.tokens,
        toolCalls: result.calls,
      };
    },
  };
}

const researcher = createSpecialist(
  "研究员",
  "你是一个技术研究员。阅读文档，找到模式，总结发现。只输出实现所需的事实。"
);

const coder = createSpecialist(
  "程序员",
  "你是一个高级 TypeScript 开发者。根据需求和调研笔记，编写干净、经过测试的代码。仅此而已。"
);

const reviewer = createSpecialist(
  "审查者",
  "你是一个代码审查者。找到 Bug、安全问题和逻辑错误。要具体。引用行号。"
);
```

每个专业代理都有专注的提示。每个都获得一个干净的上下文窗口，只包含它需要的输入。

### 步骤 3：通过消息协调

通过显式的消息传递将专业代理连接起来：

```typescript
type AgentMessage = {
  from: string;
  to: string;
  content: string;
  timestamp: number;
};

async function multiAgentApproach(task: string): Promise<AgentResult> {
  const messages: AgentMessage[] = [];
  let totalTokens = 0;
  let totalToolCalls = 0;

  const researchResult = await researcher.run(task);
  messages.push({
    from: "研究员",
    to: "程序员",
    content: researchResult.content,
    timestamp: Date.now(),
  });
  totalTokens += researchResult.tokensUsed;
  totalToolCalls += researchResult.toolCalls;

  const coderInput = messages
    .filter((m) => m.to === "程序员")
    .map((m) => `[来自 ${m.from}]: ${m.content}`)
    .join("\n");

  const codeResult = await coder.run(coderInput);
  messages.push({
    from: "程序员",
    to: "审查者",
    content: codeResult.content,
    timestamp: Date.now(),
  });
  totalTokens += codeResult.tokensUsed;
  totalToolCalls += codeResult.toolCalls;

  const reviewerInput = messages
    .filter((m) => m.to === "审查者")
    .map((m) => `[来自 ${m.from}]: ${m.content}`)
    .join("\n");

  const reviewResult = await reviewer.run(reviewerInput);
  messages.push({
    from: "审查者",
    to: "编排者",
    content: reviewResult.content,
    timestamp: Date.now(),
  });
  totalTokens += reviewResult.tokensUsed;
  totalToolCalls += reviewResult.toolCalls;

  return {
    content: messages.map((m) => `[${m.from} -> ${m.to}]: ${m.content}`).join("\n\n"),
    tokensUsed: totalTokens,
    toolCalls: totalToolCalls,
  };
}
```

每个代理只接收发给它的消息。没有上下文污染。研究员的 5 万 token 文档阅读永远不会进入审查者的上下文。

### 步骤 4：比较

```typescript
async function compare() {
  const task = "为 Express.js API 构建一个限流中间件";

  console.log("=== 单代理 ===");
  const single = await singleAgentApproach(task);
  console.log(`Token: ${single.tokensUsed}`);
  console.log(`工具调用: ${single.toolCalls}`);

  console.log("\n=== 多代理 ===");
  const multi = await multiAgentApproach(task);
  console.log(`Token: ${multi.tokensUsed}`);
  console.log(`工具调用: ${multi.toolCalls}`);
}
```

多代理版本使用更多的总 token（三个代理，三次独立的 LLM 调用），但每个代理的上下文保持干净。每个阶段的质量提高，因为系统提示是专业化的。

## 实践

本课生成一个可复用的提示，用于决定何时采用多代理。见 `outputs/prompt-multi-agent-decision.md`。

## 练习

1. 添加第四个专业代理：一个「测试者」代理，接收程序员的代码和审查者的审查反馈，然后编写测试
2. 修改管道，使审查者可以将反馈发回程序员进行修订循环（最多 2 轮）
3. 将顺序管道转换为扇出：并行运行研究员和「需求分析者」代理，然后合并它们的输出再传递给程序员

## 关键术语

| 术语 | 人们说的 | 实际含义 |
|------|---------|---------|
| 集群（Swarm） | 「一个 AI 代理的蜂巢思维」 | 一组对等代理，共享状态，没有固定领导者。行为从局部交互中涌现。 |
| 编排者（Orchestrator） | 「老板代理」 | 工具包括生成和管理其他代理的代理。它规划和委托，但可能不实际工作。 |
| 协调者（Coordinator） | 「交通警察」 | 一个非代理组件（通常只是代码，非 LLM），根据规则在代理之间路由消息。 |
| 共识（Consensus） | 「代理们达成一致」 | 多个代理必须在继续之前达成一致的协议。用于需要解决冲突输出的场景。 |
| 涌现行为（Emergent Behavior） | 「代理们自己想出来的」 | 从代理交互中产生但未被显式编程的系统级模式。可能有用也可能有害。 |
| 扇出/扇入（Fan-Out/Fan-In） | 「代理的 Map-Reduce」 | 将任务拆分到并行代理（扇出），然后合并它们的结果（扇入）。 |
| 消息传递（Message Passing） | 「代理互相通信」 | 代理间的通信机制：从一个代理发送到另一个代理的结构化数据，取代共享上下文窗口。 |

## 扩展阅读

- [新兴 AI 代理架构的格局](https://arxiv.org/abs/2409.02977) — 多代理模式综述
- [AutoGen：赋能下一代 LLM 应用](https://arxiv.org/abs/2308.08155) — 微软的多代理对话框架
- [Claude Code 子代理文档](https://docs.anthropic.com/en/docs/claude-code) — Claude Code 如何通过 Task 委托
- [CrewAI 文档](https://docs.crewai.com/) — 基于角色的多代理框架