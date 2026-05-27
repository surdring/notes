# 基准测试：WebArena 与 OSWorld

> WebArena 在四个自托管应用中测试 Web 代理能力。OSWorld 在 Ubuntu、Windows、macOS 上测试桌面代理能力。在发布时（2023-2024），两者都显示了最佳代理与人类之间的巨大差距。差距正在缩小；失败模式没有改变。

**类型：** 学习
**语言：** Python（标准库）
**前置条件：** Phase 14 · 19（SWE-bench、GAIA）
**时间：** ~60 分钟

## 学习目标

- 描述 WebArena 的四个自托管应用以及为什么基于执行的评估很重要。
- 解释为什么 OSWorld 使用真实操作系统截图而不是无障碍访问 API（Accessibility API）。
- 列举 OSWorld 的两种主要失败模式：GUI 定位和操作知识。
- 总结 OSWorld-G 和 OSWorld-Human 在基础基准测试上增加了什么。

## 问题

通用代理能调用工具。但它们能通过 20 次点击驱动浏览器完成购物结账吗？它们能仅用键盘和鼠标配置一台 Linux 机器吗？这些是 WebArena 和 OSWorld 回答的问题。

## 概念

### WebArena（Zhou 等人，ICLR 2024）

- 812 个长周期任务，跨四个自托管 Web 应用：购物网站、论坛、类 GitLab 开发工具、企业 CMS。
- 附加工具：地图、计算器、草稿本。
- 评估通过 Gym API 基于执行——订单是否下达，Issue 是否关闭，CMS 页面是否更新？
- 发布时：最佳 GPT-4 代理成功率为 14.41% vs 人类 78.24%。

自托管框架很重要——基准测试不会因为目标应用被锁定和可复现而出问题。

### 扩展

- **VisualWebArena** — 视觉定位任务，成功取决于解释图像（截图作为一等观察）。
- **TheAgentCompany**（2024 年 12 月）— 添加终端 + 编码；更像真实的远程工作环境。

### OSWorld（Xie 等人，NeurIPS 2024）

- 369 个真实计算机任务，跨 Ubuntu、Windows、macOS。
- 自由形式的键盘和鼠标控制真实应用。
- 1920×1080 截图作为观察。
- 发布时：最佳模型 12.24% vs 人类 72.36%。

### 主要失败模式

1. **GUI 定位（GUI Grounding）。** 像素到元素的映射。模型在 1920×1080 分辨率下难以可靠地定位 UI 元素。
2. **操作知识（Operational Knowledge）。** 哪个菜单包含该设置、哪个键盘快捷键、哪个偏好面板。人类多年积累的知识长尾。

### 后续工作

- **OSWorld-G** — 564 样本定位套件 + Jedi 训练集。将定位与规划解耦，以便分别测量。
- **OSWorld-Human** — 人工筛选的黄金行动轨迹。显示最佳代理使用的步骤比必要多 1.4-2.7 倍（轨迹效率差距）。

### 为什么这很重要

Claude Computer Use、OpenAI CUA、Gemini 2.5 Computer Use（第 21 课）都是在 WebArena 和 OSWorld 塑造的工作负载上训练的。基准测试是目标；生产模型是交付的答案。

### 基准测试的误区

- **仅截图评估。** OSWorld 是截图驱动的；在 OSWorld 上评估使用 DOM 或无障碍访问 API 的代理会错失定位挑战。
- **忽略轨迹长度。** 仅评分成功率会错失 OSWorld-Human 揭示的 1.4-2.7 倍步骤低效。
- **过时的自托管应用。** WebArena 的应用锁定特定版本；未经重新筛选就升级会破坏可比性。

## 构建

`code/main.py` 实现了一个玩具级 Web 代理工具链：

- 一个最小的"购物应用"状态机：list_items、add_to_cart、checkout。
- 3 个任务的黄金轨迹。
- 一个脚本化代理尝试每个任务。
- 基于执行的评估器（状态检查）和轨迹效率指标（步骤数 vs 黄金轨迹）。

运行方式：

```
python3 code/main.py
```

输出：每个任务的成功率和轨迹效率，反映了 OSWorld-Human 的方法论。

## 使用场景

- **WebArena Verified** — 在内部集群上自托管用于持续评估。
- **OSWorld** — 在 VM 集群中用于桌面代理。
- **计算机使用代理**（第 21 课）— Claude、OpenAI CUA、Gemini — 都是在类似这些基准测试的工作负载上训练的。
- **你自己的产品流程** — 为你最重要的 20 个任务捕获黄金轨迹；每周对它们运行代理。

## 部署

`outputs/skill-web-desktop-harness.md` 构建一个 Web/桌面代理工具链，包含基于执行的评估和轨迹效率指标。

## 练习

1. 用第二个应用（论坛）扩展玩具工具链。编写 3 个任务及黄金轨迹。
2. 为每个任务添加轨迹效率报告。在你的玩具上，代理是黄金轨迹的 1 倍、2 倍还是 3 倍？
3. 实现一个"干扰"工具——黄金轨迹从不使用的一个工具。脚本化代理会被诱惑吗？
4. 阅读 OSWorld-G。你在自己的评估中如何分离定位失败和规划失败？
5. 阅读 WebArena 的应用 README。当你升级某个锁定版本的应用时，什么会出错？

## 关键术语

| 术语 | 人们常说的 | 实际含义 |
|------|-----------|---------|
| WebArena | "Web 代理基准测试" | 812 个任务，跨 4 个自托管应用；Gym 风格评估 |
| VisualWebArena | "可视化 WebArena" | 视觉定位版 WebArena；截图是观察 |
| OSWorld | "桌面代理基准测试" | 369 个任务，真实 Ubuntu/Windows/macOS |
| GUI 定位（GUI Grounding） | "像素到元素映射" | 模型在 1920x1080 中定位 UI 元素 |
| 操作知识（Operational Knowledge） | "操作系统知识" | 哪个菜单、哪个快捷键、哪个偏好面板 |
| OSWorld-G | "定位套件" | 564 个纯定位样本 + 训练集 |
| OSWorld-Human | "黄金轨迹" | 手动专家操作序列，用于衡量效率 |
| 轨迹效率（Trajectory Efficiency） | "步骤数/黄金轨迹" | 代理步骤数除以人类最小值 |

## 进一步阅读

- [Zhou 等人，WebArena（arXiv:2307.13854）](https://arxiv.org/abs/2307.13854) — 四应用 Web 基准测试
- [Xie 等人，OSWorld（arXiv:2404.07972）](https://arxiv.org/abs/2404.07972) — 跨操作系统桌面基准测试
- [Anthropic，Introducing computer use](https://www.anthropic.com/news/3-5-models-and-computer-use) — Claude 的基准测试形态能力
- [OpenAI，Computer-Using Agent](https://openai.com/index/computer-using-agent/) — OSWorld 和 WebArena 数据