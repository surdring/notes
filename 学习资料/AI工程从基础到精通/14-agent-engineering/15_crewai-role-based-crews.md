# CrewAI：基于角色的 Crew 与 Flow

> CrewAI 是 2026 年基于角色的多 Agent 框架。四个原语：Agent、Task、Crew、Process。两种顶层形态：Crews（自动、基于角色的协作）和 Flows（事件驱动、确定性）。文档很直白："对于任何生产级应用，从 Flow 开始。"

**类型：** 学习 + 构建
**语言：** Python（标准库）
**前置要求：** Phase 14 · 12（工作流模式），Phase 14 · 14（Actor 模型）
**时间：** ~75 分钟

## 学习目标

- 说出 CrewAI 的四个原语（Agent、Task、Crew、Process）以及每个负责什么。
- 区分 Sequential、Hierarchical 和 Consensual 过程；按工作负载选择一种。
- 区分 Crews（自动基于角色）和 Flows（事件驱动确定性），并解释文档的生产级建议。
- 使用 `@tool` 装饰器和 `BaseTool` 子类连接工具；推理结构化输出 vs 自由文本。
- 说出四种 CrewAI 记忆类型以及每种何时物有所值。
- 实现一个标准库三 Agent Crew（研究员、撰写者、编辑），产生一份简报。
- 识别三种 CrewAI 故障模式：提示词膨胀、Manager-LLM 税、脆弱的交接。

## 问题

采用多 Agent 框架的团队撞上同一堵墙。"自动协作"在演示中听起来很棒。然后客户提交了一个 bug，你需要确定性重放。或者财务部门问一个 LLM 路由的 Crew 每次运行成本是多少。或者值班人员需要知道哪个 Agent 在凌晨 3 点卡住了。

自由形式的 LLM 路由 Crew 对这些都无法干净地回答。纯 DAG 能回答所有这些，但失去了头脑风暴 Agent 所需的探索形态。

CrewAI 的划分诚实面对了这种权衡。Crews 用于协作、基于角色、探索性工作。Flows 用于事件驱动、代码拥有、可审计的生产。同一框架，两种形态，按场景选择。

## 概念

### 四个原语

CrewAI 的面很小。记住这些，剩下的都是配置。

- **Agent。** `role + goal + backstory + tools + (optional) llm`。背景故事承载着关键作用。它塑造语调、判断力以及 Agent 何时停止。工具是 Agent 可以调用的函数（详见下文）。
- **Task。** `description + expected_output + agent + (optional) context + (optional) output_pydantic`。一个可复用的工作单元。`expected_output` 是契约。`context` 列出上游任务，其输出被传入。`output_pydantic` 强制结构化形态。
- **Crew。** 容器。拥有 `agents` 列表、`tasks` 列表、`process` 以及可选的 `memory` + `verbose` + `manager_llm` 设置。
- **Process。** 执行策略。Sequential、Hierarchical、Consensual。选择运行的形态。

Agent 不直接看到彼此。Task 引用 Agent。Crew 序列化 Task。Process 决定谁选择下一个 Task。这就是完整的思维模型。

### Sequential vs Hierarchical vs Consensual

- **Sequential。** 任务按声明顺序运行。任务 N 的输出作为 `context` 可用于任务 N+1。成本最低。最可预测。当顺序固定时使用。
- **Hierarchical。** 一个 Manager Agent（单独的 LLM 调用）在专家之间路由。CrewAI 从你的 `manager_llm` 配置或默认生成 Manager。Manager 每轮选择下一个 Task，可以拒绝或重新路由。当你有四个或更多专家且顺序确实取决于先前的输出时使用。
- **Consensual。** Beta 阶段。Agent 投票决定下一步。在学术研究之外很少值得付出往返成本。

Hierarchical 在每个专家调用之上添加每轮 LLM 调用（Manager）。在五次步骤的运行上，令牌成本可能增加三倍。仅当需要路由时才为此付费。

### Crews vs Flows

这是 2026 年文档开篇引导的框架。

- **Crew。** LLM 驱动的自动性。框架在运行时选择形态。适合：研究、头脑风暴、初稿，任何路径是答案一部分的地方。难以重放。难以测试。原型开发便宜。
- **Flow。** 你拥有的事件驱动图。`@start` 标记入口。`@listen(topic)` 标记一个步骤，当另一个步骤发出该 topic 时触发。每个步骤是纯 Python（可以在内部调用一个 Crew）。适合：生产。可观测。可测试。确定性。

2026 年文档的生产级建议：从 Flow 开始。当自动性物有所值时，在 Flow 步骤内将 Crews 折叠为 `Crew.kickoff()` 调用。Flow 给你审计轨迹，Crew 给你探索。组合，不要二选一。

### 工具集成

三种方式给 Agent 一个工具。选择适合的最简单方式。

1. **`@tool` 装饰器。** 纯函数成为工具。签名是 schema；文档字符串是 LLM 看到的描述。最适合一次性辅助工具。

   ```python
   from crewai.tools import tool

   @tool("Search the web")
   def search(query: str) -> str:
       """Return top results for the query."""
       return run_search(query)
   ```

2. **`BaseTool` 子类。** 基于类的工具，带有显式的 args schema、异步支持、重试。当工具有状态（客户端、缓存）或需要结构化参数时使用。

   ```python
   from crewai.tools import BaseTool
   from pydantic import BaseModel

   class SearchArgs(BaseModel):
       query: str
       limit: int = 10

   class SearchTool(BaseTool):
       name = "web_search"
       description = "Search the web and return top results."
       args_schema = SearchArgs

       def _run(self, query: str, limit: int = 10) -> str:
           return self.client.search(query, limit=limit)
   ```

3. **内置工具包。** CrewAI 提供一等适配器：`SerperDevTool`、`FileReadTool`、`DirectoryReadTool`、`CodeInterpreterTool`、`RagTool`、`WebsiteSearchTool`。一次导入即连接。

结构化输出使用 Pydantic。在 Task 上传递 `output_pydantic=MyModel`。CrewAI 根据模型验证 LLM 响应，要么转换要么重试。将此与紧凑的 `expected_output` 字符串配合使用。自由文本输出对草稿没问题；结构化输出是下游 Flow 可以消费的格式。

### 记忆钩子

CrewAI 开箱即提供四种记忆类型。它们是可组合的：一个 Crew 可以同时启用全部四种。

- **短期。** 单次运行内的对话缓冲区。运行结束时清除。
- **长期。** 跨运行持久化。存储在向量数据库中（默认 Chroma，可替换）。通过与当前任务的相似度检索。
- **实体。** 每个实体的事实。"客户 X 是企业版计划。"按实体键存储，而非按相似度。跨运行存活。
- **上下文。** 组装时检索。在 Agent 需要时才拉取相关记忆，而非预加载。

在 Crew 上通过 `memory=True` 或按类型配置启用。由你配置的嵌入提供商支撑（默认 OpenAI，可替换为本地）。记忆是 CrewAI 相对于更薄框架的一个重要优势；纯 LangGraph 需要你自己连接每一个。

### 何时适合 CrewAI

- 三到六个具有命名角色和协作工作流的 Agent。起草、审查、规划、头脑风暴。
- LLM 关于下一步的判断是价值一部分的路由（Hierarchical）。
- 团队更喜欢读 `role + goal + backstory` 而非读图定义的任何场景。

### 何时不适合 CrewAI

- 具有严格顺序的确定性 DAG。使用 LangGraph（第 13 课）。图形状是正确的抽象；CrewAI 的角色框架是摩擦。
- 亚秒延迟预算。Hierarchical 增加往返。即使 Sequential 也会序列化包含背景故事和之前输出的提示词。
- 单 Agent 循环。跳过框架；一个 Agent 循环（第 1 课）加一个工具注册表更短。

第 17 课（Agent 框架权衡）以矩阵形式呈现。简短版本：CrewAI 位于"协作基于角色"角落。

### 依赖形态

独立于 LangChain。Python 3.10 到 3.13。使用 `uv`。2026 年初 30k+ GitHub stars。AWS Bedrock 集成已文档化；他们的基准测试引用在 QA 任务上比 LangGraph 快 5.76 倍。将框架供应商数字视为方向性的。

### 此模式出错的地方

- **来自背景故事的提示词膨胀。** 每个 Agent 2000 字的背景故事和一个五 Agent Crew 在第一次工具调用之前就烧光了上下文预算。保持背景故事在 200 字以内。跨 Agent 复用短语；不要重复内部风格五次。
- **Manager-LLM 令牌税。** Hierarchical 过程在每个专家调用之前添加一个 Manager LLM 调用。在一个五任务 Crew 上，这是六次 LLM 调用而非五次，且 Manager 调用携带完整的任务列表加上之前的输出。除非路由取决于输出，否则切换到 Sequential。
- **脆弱的交接。** 任务 N 的 `expected_output` 是"一个大纲"。任务 N+1 将其作为 `context` 读取并尝试解析三个部分。LLM 产生了四个部分。下游 Agent 自由发挥。通过任务 N 上的 `output_pydantic` 修复，使任务 N+1 读取类型化对象而非自由文本。
- **Crew 即生产。** 在没有 Flow 包装的情况下直接交付自由形式 Crew 到生产。输出变异性高；重放不可能；值班人员无法对比坏运行和好运行。用 Flow 包装。

## 构建

`code/main.py` 实现两种形态的标准库版本加一个三 Agent Crew。

形态：

- `Agent`、`Task` 数据类，匹配 CrewAI 的面。
- `SequentialCrew.kickoff(inputs)` 按声明顺序运行任务，将输出作为 `context` 传递。
- `HierarchicalCrew.kickoff(topic)` 添加一个 Manager Agent 每轮选择下一个专家，在 "done" 时停止。
- `Flow` 带有 `@start` 和 `@listen(topic)` 装饰器、一个小型事件循环和一个轨迹。
- `tool(name)` 装饰器镜像 CrewAI 的 `@tool` 形态。
- `Memory` 带有 `short_term`、`long_term`、`entity` 存储；模拟相似度使用 numpy。
- 模拟 LLM 响应是基于角色加输入前缀键控的硬编码字符串。无网络。确定性。

具体演示：研究员、撰写者、编辑 Crew 生成关于"agent engineering 2026"的简报。研究员拉取（模拟的）源材料。撰写者起草。编辑收紧。同一个 Crew 通过 Flow 运行以展示确定性形态。

运行：

```bash
python3 code/main.py
```

轨迹涵盖：顺序 Crew 将输出通过 `context` 传递、层级 Crew 带 Manager 选择（研究员、撰写者、编辑，然后 "done"）、Flow 以显式 topic（`researched`、`drafted`、`edited`）运行相同三步、通过 `@tool` 路由的工具调用、以及在两次 kickoff 之间存活的长期记忆。

Crew 轨迹是流动的；Manager 原则上可以重新排序。Flow 轨迹是固定的。那个选择就是课程。

## 使用

- **CrewAI Flow** 用于生产。即使 Flow 只有一步调用 `Crew.kickoff()`。Flow 提供审计边界。
- **CrewAI Crew（Sequential）** 用于清晰排序的协作工作，特别是初稿和审查循环。
- **CrewAI Crew（Hierarchical）** 当路由取决于输出且有四个或更多专家时。
- **LangGraph**（第 13 课）用于显式状态机、持久恢复、严格排序。
- **AutoGen v0.4**（第 14 课）用于 Actor 模型并发和故障隔离。
- **OpenAI Agents SDK**（第 16 课）用于 OpenAI 优先产品，带交接和护栏。
- **Claude Agent SDK**（第 17 课）用于 Claude 优先产品，带子 Agent 和会话存储。

## 交付物

`outputs/skill-crew-or-flow.md` 为任务选择 Crew vs Flow 并搭建最小实现。硬拒绝：无背景故事的 Crew、无显式 topic 的 Flow、少于三个专家的 Hierarchical。

## 陷阱

- **背景故事作为风格。** 它塑造输出。每个 Agent 测试三个变体；方差是真实的。选一个，冻结它。
- **跳过 `expected_output`。** 每个任务没有契约，下游任务接收 LLM 生成的任何内容。Crew 运行；审计失败。
- **记忆始终开启。** 长期记忆每次运行都写入。向量数据库增长。检索变得嘈杂。将写入范围限定到事实是持久性的任务。
- **Manager 提示词漂移。** Hierarchical 的 Manager 提示词是隐式的。如果路由变得奇怪，在 verbose 模式下转储它并阅读。
- **Crew 中的工具副作用。** 一个 Crew 调用工具的次数可能比预期的多。POST、DELETE、支付属于 Flow 步骤，绝不应该是 Crew 工具。

## 练习

1. 将 Sequential Crew 转换为 Flow。计算变异性下降的接触点数量。注意可读性下降的位置。
2. 向 Crew 添加实体记忆：关于客户的事实跨 kickoff 持久化。验证检索拉取了正确的实体。
3. 实现一个 Hierarchical 过程，其中 Manager 拒绝路由到编辑，直到撰写者的输出至少有三个段落。追踪重试。
4. 为（模拟的）网络搜索连接一个 `BaseTool` 子类。比较轨迹形态与 `@tool` 装饰器版本。
5. 向编辑任务添加 `output_pydantic=Brief`，其中 `Brief` 有 `title`、`summary`、`sections`。使撰写者任务输出一次格式错误的 JSON；在轨迹中验证 CrewAI 的重试行为。
6. 阅读 CrewAI 文档介绍。将玩具移植到真实的 `crewai` API。标准库版本跳过了哪些保证？
7. 连接 AgentOps 或 Langfuse（第 24 课）到真实运行。标准库版本中你错过了哪些轨迹？

## 关键术语

| 术语 | 常见说法 | 实际含义 |
|------|----------|----------|
| Agent | "人设" | Role + goal + backstory + tools |
| Task（任务） | "工作单元" | Description + expected output + 被分配者 + 可选结构化输出 |
| Crew | "Agent 团队" | Agent + Task + Process 的容器 |
| Process（过程） | "执行策略" | Sequential / Hierarchical / Consensual |
| Flow | "确定性工作流" | 事件驱动、代码拥有、可测试 |
| Backstory（背景故事） | "人设提示词" | Agent 的语调和判断力塑造器 |
| `@tool` | "函数工具" | 将函数转换为 Agent 可以调用的工具的装饰器 |
| `BaseTool` | "类工具" | 基于类的工具，带有 args schema、重试、异步支持 |
| Entity memory（实体记忆） | "每个实体的事实" | 范围限定到客户/账户/问题的记忆 |
| Long-term memory（长期记忆） | "跨运行记忆" | 在 kickoff 之间存活的向量支撑记忆 |
| Contextual memory（上下文记忆） | "即时检索" | 在 Agent 需要时才拉取的记忆 |
| Manager LLM | "路由 Agent" | Hierarchical 过程中选择下一个任务的额外 LLM |
| `expected_output` | "任务契约" | 告诉 Agent（和审计）返回什么形态的字符串 |

## 扩展阅读

- [CrewAI docs introduction](https://docs.crewai.com/en/introduction)：概念和推荐的生产路径
- [CrewAI Flows guide](https://docs.crewai.com/en/concepts/flows)：事件驱动形态，`@start`，`@listen`
- [CrewAI tools reference](https://docs.crewai.com/en/concepts/tools)：`@tool`，`BaseTool`，内置工具包
- [CrewAI memory](https://docs.crewai.com/en/concepts/memory)：短期、长期、实体、上下文
- [Anthropic, Building Effective Agents](https://www.anthropic.com/research/building-effective-agents)：何时多 Agent 有帮助，何时无帮助
- [LangGraph overview](https://docs.langchain.com/oss/python/langgraph/overview)：状态机替代方案