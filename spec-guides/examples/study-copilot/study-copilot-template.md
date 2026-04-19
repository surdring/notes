# 场景模板规格：Study Copilot（高考学习协作）

> 版本：v0.1  
> 状态：草案（设计层，尚未落地到运行时代码）  
> 目标：为 Niche 提供一个完整的「Study Copilot」场景模板，用于支持高三学生（尤其是高考场景）的日常学习与备考。

---

## 1. 场景与目标

### 1.1 场景描述

Study Copilot 面向 **高三学生及家庭**，以「Explain & Verify」为核心价值，帮助学生在不违背学术诚信的前提下：

- 复盘错题、分析错因、定位知识漏洞；
- 针对薄弱考点生成巩固练习与讲解；
- 形成持续的复习计划与阶段性总结；
- 在语文/英语写作与阅读方面提供结构化反馈与改进建议。

它不会也不应该成为「代做作业/作弊工具」，而是一个鼓励主动思考与自我反思的学习协作伙伴。

### 1.2 典型用户故事

- **US-1：错题复盘**  
  作为高三学生，我希望在做错题目后，Study Copilot 能帮我分析哪里错了、错在什么知识点，并告诉我下一步该怎么补救，而不是只给我标准答案。

- **US-2：巩固练习生成**  
  作为高三学生，我希望针对某个知识点或题型，Study Copilot 能给我生成若干同类练习题并附上详细解析，以便我有针对性地练习。

- **US-3：知识点微课/总结**  
  作为高三学生，我希望 Study Copilot 能用我听得懂的方式讲解某个知识点（包括定义、常见考法和易错点），并给几个代表性例题帮助理解。

- **US-4：写作反馈（语文/英语）**  
  作为高三学生，我希望 Study Copilot 能对我的作文给出结构、论点和语言上的改进建议，而不是直接帮我写一篇可以交作业的成品。

- **US-5：阶段性复盘与计划**  
  作为学生或家长，我希望 Study Copilot 能基于一段时间的错题和练习记录，总结当前的强项和弱项，并生成一个可执行的短期练习计划。

---

## 2. 能力边界与 Guardrails

### 2.1 能力范围

- 支持科目（可扩展）：
  - 数学（文/理或新高考）
  - 英语
  - 物理、化学、生物（可后续扩展）
  - 语文（偏阅读与写作反馈）
- 支持任务类型（Mode）：
  - `wrong_review`：错题复盘与错因分析
  - `practice`：针对知识点的巩固练习生成
  - `explain`：知识点讲解与微课
  - `writing_feedback`：作文/写作反馈
  - `weekly_review`：每周/阶段性总结与计划

### 2.2 学术诚信与合规原则

- 对「正在进行的作业/考试」场景：
  - 若用户描述中包含：
    - “现在这道是我作业里的题”“明天要交作业”“考试题现在帮我算”等关键词，
  - **Behavior**：
    - 仅提供提示/思路/步骤检查，不直接给出完整数值/最终答案；
    - 要求学生先给出自己的解题思路，再进行评估与优化建议。

- 对作文/写作请求：
  - 优先模式为：
    - 帮助学生规划结构、优化论点、润色语言；
    - 可给出示例段落，但应避免整篇可直接交的文章。

- 对引用/资料（若接入 RAG）：
  - 不允许伪造教材/试题来源；
  - 若输出中包含“来源/出处”，必须能追溯到真实知识库文档。

---

## 3. 模板结构概览

### 3.1 模板标识

```ts
export const StudyCopilotTemplateId = 'study_copilot_gaokao';
```

- **category**: `"learning"`
- **description**: `"高三 Study Copilot：错题诊断 + 巩固练习 + 知识点微课 + 写作反馈"`

### 3.2 System Prompt 草案（高层意图）

> 伪代码形式，实际可在实现时以多段 Prompt 组织。

- 你是一个服务高三学生的 Study Copilot，帮助他们理解知识、反思错误、巩固练习。
- 你的优先级是：**帮助学生思考和自我修正，而不是直接给出标准答案**。
- 对于作业/考试中的题目，只能给提示和步骤分析，不能直接给出可抄写的完整答案。
- 对于复盘与练习场景，可以按照模板要求输出完整解析与建议。
- 用学生友好的语言表达，尽量给出可执行的建议（比如“本周多做 3–5 道同类题”“回看教材 XX 页的例题”）。

---

## 4. Tool / Sub-agent 设计

> 这里只定义逻辑与数据结构，具体实现可基于 Vercel AI SDK 的 Tool Calling 机制与 Niche 的 Agent Engine。

### 4.1 Tool: AnalyzeWrongQuestion（错题诊断）

**用途**：分析错题，定位错误类型与知识点，并给出学习建议。

- **输入 Schema（Zod 草案）**：

```ts
const QuestionInput = z.object({
  // 二选一：文本或图片
  questionText: z.string().optional(),
  questionImage: z.string().optional(), // base64 或 URL
}).refine((data) => data.questionText || data.questionImage, {
  message: '必须提供题目文本或图片',
});

const AnalyzeWrongQuestionInput = z.object({
  subject: z.enum(['math', 'english', 'physics', 'chemistry', 'chinese']),
  question: QuestionInput,
  userSolution: z.string().min(1),
  correctAnswer: z.string().optional(), // 若有标准答案，可用于对比
  meta: z.object({
    fromHomework: z.boolean().default(false), // 是否来自当前作业
    examLike: z.boolean().default(false), // 是否模拟/真题
  }).optional(),
});
```

- **输出 Schema**：

```ts
const AnalyzeWrongQuestionOutput = z.object({
  errorType: z.enum([
    'concept',       // 概念不清
    'pattern',       // 题型/解题套路不熟
    'calculation',   // 计算错误
    'careless',      // 粗心
    'reading',       // 审题/理解题意错误
    'expression',    // 表达不清/逻辑链有问题
    'other',
  ]),
  knowledgePoints: z.array(z.string()).default([]),
  analysis: z.string(), // 哪一步错了，为什么
  suggestions: z.array(z.string()).default([]), // 具体学习建议
});
```

### 4.2 Tool: GeneratePracticeQuestions（生成练习题）

**用途**：围绕某个知识点生成同类练习题与解析。

- **输入 Schema**：

```ts
const GeneratePracticeQuestionsInput = z.object({
  subject: z.enum(['math', 'english', 'physics', 'chemistry', 'chinese']),
  knowledgePoints: z.array(z.string()).min(1),
  difficulty: z.enum(['easy', 'medium', 'hard']).default('medium'),
  count: z.number().int().positive().max(10).default(3),
});
```

- **输出 Schema**：

```ts
const PracticeQuestionSchema = z.object({
  id: z.string(),
  prompt: z.string(),
  options: z.array(z.string()).optional(), // 选择题可用
  answer: z.string(),
  explanation: z.string(),
  difficulty: z.enum(['easy', 'medium', 'hard']),
});

const GeneratePracticeQuestionsOutput = z.object({
  questions: z.array(PracticeQuestionSchema),
});
```

### 4.3 Tool: ExplainKnowledgePoint（知识点讲解）

**用途**：讲解指定知识点，并给出代表性例题。

- **输入 Schema**：

```ts
const ExplainKnowledgePointInput = z.object({
  subject: z.enum(['math', 'english', 'physics', 'chemistry', 'chinese']),
  knowledgePoint: z.string().min(1),
});
```

- **输出 Schema**：

```ts
const ExampleSchema = z.object({
  question: z.string(),
  explanation: z.string(),
});

const ExplainKnowledgePointOutput = z.object({
  definition: z.string(),
  examPatterns: z.array(z.string()).default([]),
  commonMistakes: z.array(z.string()).default([]),
  examples: z.array(ExampleSchema).default([]),
});
```

### 4.4 Tool: ReviewWriting（写作反馈）

**用途**：对语文/英语作文给出结构与语言反馈。

- **输入 Schema**：

```ts
const ReviewWritingInput = z.object({
  subject: z.enum(['chinese', 'english']),
  prompt: z.string().optional(), // 题目要求/材料摘要
  userEssay: z.string().min(1),
  targetScoreBand: z.string().optional(), // 期望分数/水平
});
```

- **输出 Schema**：

```ts
const ReviewWritingOutput = z.object({
  overallComment: z.string(),
  structureFeedback: z.array(z.string()),
  contentFeedback: z.array(z.string()),
  languageFeedback: z.array(z.string()),
  suggestedOutline: z.array(z.string()).optional(), // 推荐结构
  sampleParagraphs: z.array(z.string()).optional(), // 示例段落，而非整篇文章
});
```

### 4.5 Tool: WeeklyReview（阶段性总结与计划）

**用途**：基于一段时间的错题/练习记录，生成总结与下周练习计划。

- **输入 Schema**：（可由后端聚合后传入）

```ts
const WeeklyReviewInput = z.object({
  subject: z.enum(['math', 'english', 'physics', 'chemistry', 'chinese', 'mixed']),
  wrongQuestionStats: z.array(z.object({
    knowledgePoint: z.string(),
    wrongCount: z.number().int().nonnegative(),
  })),
  practiceStats: z.array(z.object({
    knowledgePoint: z.string(),
    practicedCount: z.number().int().nonnegative(),
  })).optional(),
  timeRange: z.object({
    start: z.string(), // ISO date
    end: z.string(),
  }),
});
```

- **输出 Schema**：

```ts
const PracticePlanItemSchema = z.object({
  knowledgePoint: z.string(),
  focusLevel: z.enum(['high', 'medium', 'low']),
  suggestedQuestionCount: z.number().int().positive(),
  notes: z.string().optional(),
});

const WeeklyReviewOutput = z.object({
  summary: z.string(),
  strengths: z.array(z.string()),
  weaknesses: z.array(z.string()),
  practicePlan: z.array(PracticePlanItemSchema),
});
```

### 4.6 错题记录数据模型（持久化层）

- 为支持 `WeeklyReview` 的统计与聚合，后端应在每次调用 `AnalyzeWrongQuestion` 后持久化一条错题记录，用于后续按知识点/错因进行聚合分析。

```ts
type Subject = 'math' | 'english' | 'physics' | 'chemistry' | 'chinese';

interface WrongQuestionRecord {
  id: string;
  tenantId: string; // 预埋，多租户扩展用
  userId: string;
  subject: Subject;

  // 原始输入（文本或图片）
  questionText?: string;
  questionImageUrl?: string;
  userSolution: string;

  // 分析结果（直接存 LLM 输出）
  analysis: AnalyzeWrongQuestionOutput;

  // 用于聚合
  knowledgePoints: string[];
  errorType: ErrorType;

  createdAt: Date;
}
```

- `WeeklyReviewInput.wrongQuestionStats` 可由此表通过 SQL/查询构建，例如按时间范围、按知识点与错误类型聚合。

---

## 5. 对话输出结构与模式（Runtime 输出 Schema）

Study Copilot 的统一输出结构建议如下（便于前端/UI 渲染与导出）：

```ts
const StudyCopilotMode = z.enum([
  'wrong_review',
  'practice',
  'explain',
  'writing_feedback',
  'weekly_review',
]);

const StudyCopilotResponseSchema = z.object({
  mode: StudyCopilotMode,
  summary: z.string(), // 一句话总结这次帮助了什么
  steps: z.array(z.string()).default([]), // 分步说明
  nextActions: z.array(z.string()).default([]), // 具体后续行动建议
  payload: z.unknown(), // 按 mode 解析为对应的 Output Schema
});
```

- 不同 mode 下：
  - `wrong_review`: `payload` = `AnalyzeWrongQuestionOutput`
  - `practice`: `payload` = `GeneratePracticeQuestionsOutput`
  - `explain`: `payload` = `ExplainKnowledgePointOutput`
  - `writing_feedback`: `payload` = `ReviewWritingOutput`
  - `weekly_review`: `payload` = `WeeklyReviewOutput`

---

## 6. 与现有框架的集成点

### 6.1 模板注入与选择

- 在 GraphQL / REST API 设计中，Study Copilot 可作为一个新的 `templateId`：
  - 例如：`templateId = "study_copilot_gaokao"`。
- 当用户在 UI 中选择 Study Copilot 模板时：
  - 编排层应加载该模板的 System Prompt、Tools 配置、输出 Schema 与 Guardrails 策略。

### 6.2 与 RAG 的关系

- **短期（Study Copilot v1）明确不依赖 RAGFlow**，仅用大模型内知识完成讲解与生成：
  - 高考核心知识点相对固定，主流大模型已基本覆盖；
  - 错题复盘、练习生成等场景的主要价值在于“分析错因 + 强化练习”，对外部检索依赖较低。
- **中长期**：
  - 当需要接入学校内部题库/模拟卷，或实现“按教材版本/章节讲解”时，可将：
    - 电子版讲义、错题集、学校模拟卷等资料摄入 RAGFlow；
    - Study Copilot 的 Explain/Practice 工具优先引用本地资料，再补充模型知识。

### 6.3 与 Guardrails / wrapLanguageModel 的结合

- 在模板初始化时，需通过 `wrapLanguageModel`：
  - 注入学术诚信相关 System Prompt 前缀；
  - 根据输入 `meta.fromHomework` 等字段，动态控制是否允许给出完整答案；
  - 对“整篇作文代写”“考试作弊”等意图给出拒绝或引导性回应。

- 实现建议：在 `wrapLanguageModel` 中实现一个基础的作业/考试意图检测，用于在提示语层面强制约束回答风格，例如：

```ts
const homeworkPatterns = [
  /作业/,
  /明天.*交/,
  /考试.*题/,
  /帮我.*做/,
  /直接.*答案/,
];

function detectHomeworkIntent(input: string): boolean {
  return homeworkPatterns.some((p) => p.test(input));
}
```

- 当 `detectHomeworkIntent` 返回 `true` 时，在原有 System Prompt 之后追加类似说明：

> 【重要】检测到这可能是正在进行的作业/考试。  
> 你只能：1）给出解题思路提示 2）指出用户解法中的错误  
> 你不能：直接给出完整答案或可抄写的解题过程

以在模型层面形成“只讲思路、不给作业答案”的硬约束。

---

## 7. 交互模式与产品策略

本节描述 Study Copilot 在 UI 与交互层面的推荐模式，方便前端与产品在实现时对齐预期行为。

### 7.1 模式入口设计（Mode 选择）

- 在启动 Study Copilot 时，UI 建议以「模式卡片」或「按钮组」的形式呈现不同任务类型，例如：
  - `错题复盘`（wrong_review）
  - `知识点讲解`（explain）
  - `巩固练习`（practice）
  - `写作反馈`（writing_feedback）
  - `周度/阶段总结`（weekly_review）
- 用户选择模式后，再收集必要参数（科目、题目/知识点、时间范围等），以减少自由输入带来的歧义。

### 7.2 错题场景下的按钮式追问

在错题复盘场景中，为鼓励学生主动探索而非直接要答案，推荐提供一组固定的快捷操作按钮，而不是单一的「你还有什么问题？」开放提问：

- **给我提示（不直接给答案）**：
  - 触发一种 Hint-only 模式，仅针对关键步骤给出提示或指出下一步思路，不给出完整数值/结论。
- **一步一步带我做**：
  - 触发一个分步讲解流程，将解题拆解为若干步骤，每一步后提醒学生先思考/填写，再展示参考解法，直至完整答案（在非作业场景下）。
- **检查我的解题过程**：
  - 要求学生先贴出自己的详细解题过程，再由系统对每一步进行「对/错标注 + 评论」，重点指出“从哪一步开始跑偏”。
- **再出几道类似题练习**：
  - 调用 `GeneratePracticeQuestions` 工具，自动生成 2–3 道同一知识点/相近难度的题目，并在学生作答后提供解析。

上述按钮对应不同的 mode/tool 组合，应在模板配置中显式建模，便于前端直接触发特定工具链路，而非通过自然语言推断。

### 7.3 练习 → 复盘闭环

- 在 `practice` 模式下，推荐形成固定闭环：
  1. 生成题目列表（含难度与知识点标签）；
  2. 学生逐题作答（本地填空或上传过程截图）；
  3. 触发「批改与讲解」动作，对每题给出对/错、解析与小结；
  4. 在本轮练习结束时，输出一个小结：本组题目中的错误类型分布与易错点总结。
- UI 层可以为每道题提供「我懂了/还不懂」的快速反馈按钮，作为 Eval 与模板迭代的信号。

### 7.4 周度/阶段复盘交互

- 每周或每个阶段结束时，Study Copilot 可基于错题/练习记录生成 `weekly_review`：
  - 强项/弱项的知识点列表；
  - 下周的练习计划条目（知识点 + 建议题量 + 备注）。
- UI 层建议以「小报告卡」形式呈现：
  - 提供「查看详细建议」「立即生成练习」等操作，将报告与后续行动串起来。

### 7.5 写作反馈的渐进式引导

- 在 `writing_feedback` 模式下，推荐以下渐进式交互：
  - 第一步：让学生先给出题目要求/材料摘要 + 自己的作文草稿；
  - 第二步：Study Copilot 输出结构/内容/语言三个维度的反馈，并给出一个建议大纲；
  - 第三步：如学生需要，可请求示例段落，但系统应明确提示「仅供参考，不建议直接照抄」。
- UI 可提供「按模块查看反馈」（结构/内容/语言）与「标记已修改」等操作，帮助学生逐项改进，而不是整体重写。

### 7.6 学习模式 vs 考试模式

- Study Copilot 建议在模板与 UI 层显式区分两种工作模式，以避免误用：
  - **学习模式（learning_mode）**：
    - 默认模式，适用于日常刷题、错题复盘与讲解。
    - 允许在非作业/考试场景下给出完整答案与详细解析，并推荐扩展练习。
  - **考试模式（exam_mode）**：
    - 适用于模拟考试或正式考试前的仿真训练。
    - 限制行为：
      - 不直接给出标准答案，只给提示/错误定位/时间管理建议；
      - 鼓励学生先在限定时间内独立作答，再进行复盘。
- UI 层应在模式切换时给出明确说明与警示文案，让学生理解两种模式的差异与使用边界。

### 7.7 轻量激励与可视化

- 为避免过度游戏化，又能给学生适度正反馈，Study Copilot 可在 UI 层提供轻量的进度与趋势可视化：
  - **学习连击（Streak）**：统计连续使用天数或连续完成错题复盘的天数。
  - **练习量与错题量趋势**：按周或按知识点展示完成题量与错题数的变化（例如图表或简单指标）。
  - **错因分布变化**：展示概念类错误、粗心类错误等占比随时间的变化，帮助学生看到“粗心变少了”“审题问题减少了”。
- 激励元素应保持低干扰：
  - 不鼓励重度勋章/排行榜等可能带来焦虑的机制；
  - 更偏向“学习仪表盘”，用数据让学生和家长感知进步，而不是追求对比。

---

## 8. 评估与迭代建议

### 8.1 Eval 方向

- **错题诊断**：
  - 指标：错误类型分类准确率、知识点覆盖率、学生主观满意度。
- **练习题质量**：
  - 指标：题目是否符合大纲/难度预期、解析是否清晰、是否有歧义。
- **知识点讲解**：
  - 指标：学生自评“是否听懂”“是否比课本更清晰”、是否指出关键易错点。
- **写作反馈**：
  - 指标：是否覆盖结构/内容/语言三方面、是否给出可执行的修改建议。

### 8.2 反馈闭环

- UI 层面为每次 Study Copilot 交互提供：
  - 点赞/点踩
  - “这次帮助了我”“没什么帮助”的快速评价
- 将高质量交互样本沉淀为 Few-shot 示例，用于模板 Prompt 优化。

---

## 9. 后续扩展方向（非当前迭代必需）

- 引入更多学科（生物、历史、地理、政治等），通过配置扩展 subject/knowledgePoint 体系。
- 深度接入学校/教辅资料，实现“按教材版本/章节”的讲解与练习。
- 为家长提供「家长视图」：
  - 查看孩子的弱项分布、练习完成情况与短期提分建议。

## 10. 功能优先级建议（Study Copilot）

> 本节为实现层提供一个推荐的先后顺序，可与 `docs/Niche-roadmap.md` 中的阶段规划对齐。

| 优先级 | 功能                           | 为什么重要                             |
| ------ | ------------------------------ | -------------------------------------- |
| P0     | 图片输入 + OCR/视觉理解       | 没有拍题能力，实际不可用               |
| P0     | 错题复盘（含错因分析）        | 核心价值，承接大部分使用场景           |
| P0     | 错题记录持久化                | 为周度总结、趋势分析打基础             |
| P1     | 知识点讲解                    | 高频需求，承接错题后的补救             |
| P1     | 巩固练习生成                  | 帮助学生在薄弱知识点上做强化练习       |
| P1     | 学术诚信检测（作业/考试识别） | 教育场景的合规“入场券”                 |
| P2     | 写作反馈                      | 语文/英语写作场景的重要补充           |
| P2     | 周度总结 + 练习计划           | 需要一定数据积累后才有价值             |
| P3     | 接入教材/题库 RAG             | 锦上添花，适合后期接入学校资源         |

> 本文档为 Study Copilot 场景模板的设计规格，实际实现需在代码中补充具体 Agent/Tool 注册与 Prompt 文案；如与 `vertical-ai-framework/requirements.md` 存在冲突，应优先更新规格以保持一致。
