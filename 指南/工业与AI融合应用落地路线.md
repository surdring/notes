
现在的条件（React 前端 DEMO + 离线本地部署 + PostgreSQL + 小显存显卡做推理）非常适合走一条**“中台风格前端 + Python AI 后端（FastAPI）+ 本地推理服务”**的落地路线。

- **前端**：在现有 
    
    apps/web 的导航体系（`ERP_CAPABILITY_MAP`）里新增一个“质量/视觉质检”模块，并保持同样的布局、卡片、表格、按钮、i18n 用法。
    
- **后端**：用 **Python 更合适**（CV/推理生态成熟、部署简单、后续训练/微调也顺手）。推荐 **FastAPI + PostgreSQL + 本地文件存储（磁盘）+ 推理服务（GPU/CPU可切换）**。
    

---

# 1) AI 应用后端用 Python 是不是更好？

**是的，更推荐 Python**，理由很务实：

- **[生态]** 视觉推理常用的 PyTorch/ONNXRuntime/OpenCV/Ultralytics 等，Python 集成成本最低。
    
- **[工程化]** FastAPI 写接口快，类型提示/文档自动生成，便于和前端联调。
    
- **[离线部署]** Python 在内网/离线环境部署更常见（wheel 离线安装、镜像内置依赖都能搞）。
    
- **[小显存 GPU]** 更容易做“GPU优先、CPU兜底”的推理策略。
    

你也可以 Node/Java 做业务后端、Python 单独做推理服务，但你目前是 DEMO 起步，**先用一个 FastAPI 单体把闭环跑通最省时间**。

---

# 2) 你需要给 AI 的资料（按“能直接开工”整理）

下面这份你可以当成“给 AI 的资料包清单”，缺哪项 AI 就容易写偏、返工。

## 2.1 前端资料（对齐你现有 DEMO 的关键）

- **[项目入口与约束]**
    
    - 项目路径：
        
        /apps/web
        
    - 路由：`HashRouter`（不是 BrowserRouter）
        
    - 布局：
        
        components/Layout.tsx（侧边栏菜单来自 `ERP_CAPABILITY_MAP`）
        
    - 语言：
        
        useI18n() 的 `t()`/`tl()`，新增页面要补中英文 key
        
- **[风格与组件约定]**
    
    - 复用 class：`card`、`btn-primary`、`btn-secondary`、`input-field`、`tech-table-head`、`tech-table-row`
        
    - 复用页面结构：参考 
        
        pages/Dashboard.tsx 的卡片、表格、工具条风格
        
- **[菜单挂载方式]**
    
    - 当前导航完全由 
        
        constants.tsx 里的 `ERP_CAPABILITY_MAP` 驱动  
        你需要告诉 AI：视觉质检要以哪种方式接入：
        
    - 方案A：作为一个新的 `domain/capability/object` 出现在侧边栏（推荐）
        
    - 方案B：单独新路由，不走 `ERP_CAPABILITY_MAP`（更快但不够“中台一致”）
        

## 2.2 业务资料（视觉质检 MVP 必须明确的“口径”）

- **[缺陷字典]**（最少 10-30 类，先粗后细也行）
    
    - 缺陷名称（中/英）、等级（如 A/B/C 或 1/2/3）、是否必须拦截
        
- **[质检流程]**
    
    - 你要的是：仅提示+人工复核？还是可以自动判定隔离？
        
    - 状态流转：`待检 -> 已检 -> 复核中 -> 复核通过/驳回 -> 处置完成`（你确认最终版本）
        
- **[追溯字段]**
    
    - 最少要：产线/工位、时间、批次/卷号（如果暂时没有，就用“任务号+文件名”先跑通）
        

## 2.3 数据与样例（让 AI 写接口/页面不瞎猜）

- **[图片来源]**三选一（你给 AI 明确）
    
    - A：手动上传图片/视频（最适合 DEMO）
        
    - B：读取本地目录（模拟相机落盘）
        
    - C：RTSP/工业相机实时流（MVP不建议一上来就做）
        
- **[样例数据]**
    
    - 至少 30-100 张脱敏样例图（正常/缺陷都要）
        
    - 5-10 张“极端情况”（模糊、过曝、遮挡、粉尘）
        
- **[推理输出格式]**（AI 输出什么，前端怎么画框）
    
    - bbox：`x,y,w,h` 还是 `x1,y1,x2,y2`
        
    - score、label、severity
        

## 2.4 部署与合规约束（离线环境必须交代）

- **[离线]** 是否完全无外网？如果是：你现在前端 
    
    index.html 里有 CDN（Tailwind、Phosphor icons、importmap 指向 esm.sh），**离线会打不开**。  
    你需要让 AI 明确：是否要把这些改成**本地打包依赖**（建议尽早改）。
    
- **[硬件]** GPU 型号/显存大概多少；是否允许长时间占用 GPU；是否需要 CPU fallback
    
- **[安全边界]** 是否允许“自动闭环控制”？你目前更像“建议+复核”，这要写进提示词避免 AI 生成危险方案
    

---

# 3) 视觉质检平台：建议的 MVP 功能范围（最小闭环）

为了最快落地，我建议你先做一个**“任务-图片-推理-复核-统计”**闭环：

- **[任务管理]**
    
    - 新建质检任务（选择产线/工位/批次，上传一批图片）
        
    - 任务列表（状态、数量、缺陷数、创建时间）
        
- **[质检工作台]**
    
    - 左侧：图片列表/缩略图
        
    - 中间：大图+框选结果+缺陷列表
        
    - 右侧：复核面板（修改缺陷类别/等级、确认/驳回、备注）
        
- **[统计看板]**（先做基础的）
    
    - 今日任务数、缺陷检出数、Top缺陷、复核通过率
        

---

# 4) 后端最小架构（离线 + PostgreSQL + 模拟边缘推理）

推荐拆成 2 层接口（不一定要两个进程，但逻辑要分清）：

- **[业务 API（FastAPI）]**
    
    - 任务/图片/结果/复核/统计：写 PostgreSQL
        
    - 图片文件：落本地磁盘（路径入库）
        
- **[推理 API（FastAPI 或同一服务内模块）]**
    
    - 输入图片路径/bytes
        
    - 输出检测框、类别、置信度
        
    - GPU/CPU 自动选择（`cuda` 有则用，无则 CPU）
        

**数据库最小表（概念层面）**：

- `inspection_task`（任务）
    
- `inspection_image`（图片）
    
- `inspection_result`（模型结果，可多条）
    
- `inspection_review`（人工复核结果）
    

---

# 5) 你可以直接复制去用的“主提示词包”（按你的工程定制）

下面这些提示词你可以在 IDE 的 AI 助手里直接贴，效果会比“帮我写个页面”稳定很多。

## 5.1 给 AI 的“项目上下文固定提示词”（建议每次都先贴一次）

text

你在一个已有 React + Vite + react-router-dom 的项目里开发，路径是 /apps/web。

路由使用 HashRouter。页面统一包在 components/Layout.tsx 中，侧边栏菜单由 constants.tsx 的 ERP_CAPABILITY_MAP 生成。

已有通用样式 class：card / btn-primary / btn-secondary / input-field / tech-table-head / tech-table-row。

国际化通过 useI18n() 的 t(key) 与 tl(text)；新增页面需要补齐 zh-CN 和 en-US 文案 key。

目标：新增“视觉质检平台”模块，要求视觉风格、布局结构、交互密度与现有页面保持一致，不要引入新的 UI 框架与大型依赖。

如需新增路由/菜单，请优先通过扩展 ERP_CAPABILITY_MAP 的方式接入。

在开始写代码前，请先说明你将修改哪些文件，以及每个文件的变更目的。

## 5.2 前端：新增“视觉质检平台”页面（菜单+路由+页面）

text

请在 /apps/web 内新增“视觉质检平台”模块（中台风格一致）：

功能（MVP）：

1) 质检任务列表页：显示任务ID、状态、图片数、缺陷数、创建时间；支持搜索与进入详情

2) 质检任务详情/工作台：左侧缩略图列表，中间大图展示并叠加bbox框，右侧复核表单（缺陷类别、等级、备注、确认/驳回）

约束：

- 复用现有 Layout、Tailwind class、按钮/卡片风格

- i18n：所有新增文案必须进入 I18nContext 的中英文 messages

- 不要改动现有 Dashboard/DynamicERPPage 的行为（除非必要且说明原因）

- 数据先用 MockApi 模拟也可以，但需要保留未来切换真实后端 API 的接口层（例如新增 services/visionQcApi.ts）

验收标准：

- 从侧边栏可以进入“视觉质检平台”

- 列表页与工作台可正常切换

- 工作台在无后端时也能用 mock 数据渲染（至少展示2个bbox框示例）

## 5.3 后端：FastAPI + PostgreSQL + 本地文件存储 + 推理接口（离线）

text

请设计并实现一个离线可部署的后端（Python FastAPI + PostgreSQL）用于“视觉质检平台”。

需求：

- 提供任务CRUD、图片上传/登记、推理结果查询、人工复核提交、统计接口

- 图片文件存本地磁盘（例如 ./data/images），数据库只存路径与元数据

- 推理：提供 /infer 接口，输入图片路径或上传图片，输出bbox/label/score；优先使用GPU，失败则CPU

约束：

- 不能依赖外网服务；不要把任何 API Key 写进代码

- 输出清晰的 OpenAPI 文档

- 给出数据库表结构（DDL）与迁移建议

- 给出本地启动步骤与最小联调用例（curl 或 python requests）

## 5.4 联调提示词（前后端接口对齐用）

```markdown
我们要做前后端联调，请你给出“视觉质检平台”MVP 的接口契约（API Contract）：
- 每个接口：method、path、query/body、response、错误码、示例
- 字段命名统一使用 snake_case 还是 camelCase（请建议并说明）
- 返回结果要包含足够信息让前端画框（bbox坐标系、image宽高、score等）
同时给出前端 services 层的调用封装建议（fetch封装、错误处理、loading状态）。
```

# 6) 最终确认 4 个关键点

- **[菜单接入方式]**：放在“制造”下面（更符合现场业务心智）
    
- **[图片来源]**：读取本地目录（模拟相机落盘）
    
- **[缺陷字典]**：先用 10 个通用缺陷类
    
- **[离线要求强度]**：目前可外网,建议把前端 
    
    index.html 的 CDN/importmap 改为本地依赖打包（否则离线打不开）。


---

# 1) 菜单接入：放“制造”下面更好，一级“AI应用中心”建议后置

## 1.1 为什么放在“制造”更合适（你现在阶段）

- **[业务心智一致]** 质检属于制造现场的质量环节，用户会自然在“制造/车间/质量”里找，而不是在“AI中心”找。
    
- **[交付路径更短]** 你现有中台是 ERP 领域导航，按业务域挂载更容易通过管理层/现场验收。
    
- **[权限与组织结构更自然]** 质量/制造部门权限往往跟组织切换（Org Switcher）绑定，跟制造域匹配。
    

## 1.2 什么时候再做一级“AI应用中心”

当你后续要落地的不止视觉质检，而是一个“应用矩阵”（例如：设备预测维护、能碳、工艺推荐、知识助手），此时再加一级“AI应用中心”更合理，它承担：

- 应用市场/目录（按场景/产线/工厂）
    
- 模型与版本中心
    
- 数据与标注中心
    
- 运营与监控中心
    

**建议策略**：

- **现在**：`Manufacturing -> Quality -> Vision QC`（或 `Manufacturing -> Shop Floor -> Vision QC`）
    
- **未来**：保留 `AI Center` 一级入口，但其内部仍按业务域或场景聚合，避免“AI孤岛”。
    

---

# 2) 前端信息架构（对齐你现有 React DEMO 的做法，不新增重框架）

你现有 DEMO 的核心特点是：

- 侧边栏完全由 `ERP_CAPABILITY_MAP` 生成
    
- 主页面用 `Layout + Outlet`
    
- 动态页 
    
    DynamicERPPage 适合“表单/列表型ERP对象”
    
- 视觉质检属于“工作台型应用”，建议**独立页面**，但仍挂在菜单里
    

## 2.1 页面与路由建议（MVP）

建议 2 个页面足够跑闭环：

- **[页面1：任务列表/任务创建]**
    
    - 入口：`/app/manufacturing/quality/vision_qc`
        
    - 功能：
        
        - 选择“本地目录”（模拟相机落盘）
            
        - 创建质检任务（扫描目录得到图片清单）
            
        - 展示任务列表（状态、图片数、缺陷数、创建时间）
            
- **[页面2：质检工作台（任务详情）]**
    
    - 入口：`/app/manufacturing/quality/vision_qc/:taskId`
        
    - 功能：
        
        - 左侧：图片缩略图/列表（可筛“有缺陷/已复核/未复核”）
            
        - 中间：大图展示 + bbox 叠加 + 缩放/适配
            
        - 右侧：缺陷列表 + 复核表单（类别、等级、备注、确认/驳回）
            
        - 顶部：任务信息、重新推理、导出复核结果（先预留按钮）
            

## 2.2 与现有 UI/交互对齐点（你给 AI 的明确约束）

- **[样式]** 复用你已有的 class：`card`、`btn-primary`、`btn-secondary`、`input-field`、`tech-table-head`、`tech-table-row`
    
- **[国际化]** 所有新增文案都走 
    
    useI18n().t() 或 `tl()`，不要写死中文/英文
    
- **[权限]** 先沿用 `permissions: ['*']` 的 DEMO 逻辑，但菜单项仍走 
    
    checkPermission(domain.id) 的框架（未来可收口到 `manufacturing.*` 或 `manufacturing.quality.*`）
    
- **[数据对接]** MVP 可以先 Mock，但建议从第一天开始抽一个 `services/visionQcApi.ts`（或者同风格的 service 层），这样从 Mock 切换到 FastAPI 不会大改页面
    

---

# 3) 本地目录“模拟相机落盘”的落地方式（关键点在浏览器限制）

这里需要你注意一个现实约束：**纯 Web 前端无法直接读取服务器本地目录**（除非用户在浏览器里手工选择文件/目录，或你做桌面端 Electron）。

所以你有三种方案，按推荐度排序：

- **[方案A：后端扫描目录（推荐，最贴近真实边缘部署）]**
    
    - 前端输入：目录路径（例如 `/data/camera/line1/`）
        
    - 后端负责：扫描、过滤图片、入库、返回清单
        
    - 优点：最像真实“边缘盒子”，也方便自动化
        
    - 风险：要处理权限与路径安全（防止扫任意目录）
        
- **[方案B：前端用目录选择器（最省事，但不完全等同落盘）]**
    
    - `<input type="file" webkitdirectory>` 让用户选目录
        
    - 前端拿到 FileList 后上传到后端
        
    - 优点：快、浏览器就能做
        
    - 缺点：不是“自动扫描落盘目录”，更像“批量上传”
        
- **[方案C：桌面端 Electron/本地代理]**
    
    - 强但重，不建议 MVP 做
        

你说“读取本地目录（模拟相机落盘）”，我理解你想要的是 **方案A**（更工业化）。如果你同意，我的 API 契约也按 A 来写。

---

# 4) 缺陷字典（10个通用类）建议版本

先定一个“可用于演示+可扩展”的字典结构（含中英文、等级、是否拦截）：

- Scratch（划伤）
    
- Dent（压痕/凹坑）
    
- Crack（裂纹）
    
- Inclusion（夹杂）
    
- Pitting（点蚀）
    
- Hole（孔洞）
    
- Stain（污渍/油斑）
    
- Edge Defect（边部缺陷）
    
- Roll Mark（辊印）
    
- Coating Defect（涂层缺陷）
    

等级建议先 3 档：`A/B/C`（A最严重）。  
后端/数据库里建议存：

- `defect_code`（稳定编码，例如 `scratch`）
    
- `defect_name`（展示名，可 i18n）
    
- `severity`（A/B/C）
    
- `is_blocking`（是否拦截）
    

---

# 5) 后端方案（FastAPI + PostgreSQL + 推理 + 复核闭环）

你要的是“业务系统 + AI推理”一体落地，MVP 最简结构：

- **[服务]** 1 个 FastAPI 服务即可（后续再拆推理服务）
    
- **[存储]**
    
    - PostgreSQL：任务、图片、推理结果、复核记录、缺陷字典
        
    - 本地磁盘：图片文件（相机落盘目录）+ 可选缓存/导出的标注结果
        
- **[推理]**
    
    - 先支持“离线对目录图片批处理推理”
        
    - GPU 优先，CPU fallback
        
    - 输出 bbox/label/score
        

---

# 6) API 契约（MVP，按“目录扫描 + 任务 + 推理 + 复核”闭环）

## 6.1 命名风格

建议：**后端返回 snake_case**（Python 习惯），前端 service 层做一次映射即可；或者统一 camelCase 也行。为了减少转换，我建议前端也接受 snake_case。

## 6.2 核心对象（Response 示例字段）

- **Task**
    
    - `task_id`, `name`, `status`, `source_dir`, `created_at`
        
    - `image_total`, `defect_total`, `reviewed_total`
        
- **Image**
    
    - `image_id`, `task_id`, `file_path`, `file_name`, `captured_at`
        
    - `width`, `height`
        
- **Detection**
    
    - `detection_id`, `image_id`, `defect_code`, `score`, `severity`
        
    - `bbox`: `{x1,y1,x2,y2}`（明确坐标系：像素坐标，以原图为基准）
        
- **Review**
    
    - `review_id`, `image_id`, `detection_id?`（可选：复核到某个框）
        
    - `review_status`: `confirmed/rejected/edited`
        
    - `final_defect_code`, `final_severity`, `note`, `reviewed_by`, `reviewed_at`
        

## 6.3 接口清单

- **[缺陷字典]**
    
    - `GET /api/v1/defects`
        
- **[任务]**
    
    - `POST /api/v1/qc/tasks`  
        body: `{ name?, source_dir, pattern?, recursive?, limit? }`  
        行为：扫描目录、登记图片、创建任务（不一定立刻推理）
        
    - `GET /api/v1/qc/tasks?query=&page=&page_size=`
        
    - `GET /api/v1/qc/tasks/{task_id}`
        
- **[推理]**
    
    - `POST /api/v1/qc/tasks/{task_id}/infer`  
        body: `{ model_version?, conf_thres?, iou_thres?, device?: 'auto'|'cpu'|'cuda' }`  
        行为：对任务下未推理图片执行推理，落库 detection
        
    - `GET /api/v1/qc/tasks/{task_id}/images?has_defect=&review_status=&page=&page_size=`
        
    - `GET /api/v1/qc/images/{image_id}`（含 detections + reviews）
        
- **[复核]**
    
    - `POST /api/v1/qc/images/{image_id}/reviews`  
        body: `{ detection_id?, review_status, final_defect_code?, final_severity?, note? }`
        
- **[统计]**
    
    - `GET /api/v1/qc/tasks/{task_id}/stats`  
        返回：Top缺陷、A/B/C分布、复核进度、误报/修正统计（MVP先简化）
        

## 6.4 安全与路径保护（目录扫描必须做）

`source_dir` 必须限制在一个“白名单根目录”下，例如只允许 `/data/camera/` 子目录，避免用户输入 

etc 之类的路径。

---

# 7) 你可以直接复制给 AI 的“提示词”（不让它直接改代码）

你现在要求“不直接编码”，所以提示词要让 AI **输出设计与变更清单**，而不是直接生成 patch。

## 7.1 前端提示词（只输出设计/文件修改点）

text

你是资深前端架构师。请基于现有 React ERP DEMO（HashRouter + Layout + ERP_CAPABILITY_MAP 菜单）设计“视觉质检平台”接入方案，但不要直接写代码补丁。

约束：

- 模块挂在 Manufacturing 菜单下

- 两个页面：任务列表/创建、任务工作台

- 文案必须走 i18n（t/tl）

- 风格复用 card/btn/input-field/table 的现有类

- 图片来源：后端扫描本地目录（模拟相机落盘），前端输入目录路径即可

请输出：

1) 页面信息架构（路由、导航层级）

2) 需要改动/新增的文件清单（每个文件改什么）

3) 与现有 DynamicERPPage 的关系（为何独立页面更合适）

4) 未来扩展到“AI应用中心”一级菜单时的迁移策略

## 7.2 后端提示词（输出 API+表结构，不写完整代码）

text

你是后端架构师（Python FastAPI + PostgreSQL）。请为“视觉质检平台”设计 MVP 后端方案，不要直接写完整代码。

约束：

- 输入为本地目录路径（模拟相机落盘），后端扫描目录创建任务

- 推理 GPU 优先、CPU fallback

- 输出 bbox/label/score/severity，并支持人工复核

- 目录扫描需白名单根目录保护

请输出：

1) 数据库表结构（DDL，含索引建议）

2) REST API 契约（path、method、request/response、错误码、示例）

3) 推理模块的接口设计（如何选择 device，如何缓存结果）

4) 离线部署时要注意的依赖与打包建议

---

# 8) 后端契约“定稿补丁”（按你确认的：`./data/camera` + 文件名解析时间 + YOLO + 异步 Job）

---

## 1) 目录白名单根路径：项目内 `./data/camera`

### 1.1 配置项（建议）

- **`VQC_ROOT_DIR`**：默认值为 **`{PROJECT_ROOT}/data/camera`**
    
    - 这里的 `{PROJECT_ROOT}` 指 FastAPI 服务启动时的项目根目录（例如含 `pyproject.toml` 或 `requirements.txt` 的目录）
        

### 1.2 路径校验规则（必须）

服务端接收到 `source_dir` 后：

- **[规则1]** `source_dir` 允许两种写法：
    
    - **相对路径**：`./data/camera/line1/shiftA`
        
    - **绝对路径**：`/abs/path/to/project/data/camera/line1/shiftA`
        
- **[规则2]** 统一转成绝对真实路径：`real_source = realpath(source_dir)`
    
- **[规则3]** 校验 `real_source` 必须以 `real_root = realpath(VQC_ROOT_DIR)` 为前缀（防止 `..`、软链接逃逸）
    
- **[规则4]** 禁止扫描 root 之外目录，返回 `403`（更贴合“越权访问”语义）
    

---

## 2) `captured_at`：从文件名解析（失败回退 mtime）

### 2.1 约定：文件名时间格式（建议你定 1 个主格式）

建议主格式（优先级最高）：

- **格式A（推荐）**：`CAM1_YYYYMMDD_HHMMSS.jpg`
    
    - 例：`CAM1_20260205_165500.jpg`
        
    - 解析正则：`(\d{8})_(\d{6})`
        

可兼容备选（优先级低）：

- **格式B**：`YYYY-MM-DD_HH-MM-SS_xxx.png`
    

### 2.2 字段口径

- **`captured_at`**：解析得到的拍摄时间（带时区或统一存 UTC）
    
- 若解析失败：
    
    - **回退**使用文件 `mtime`（最后修改时间）
        
- 建议额外存一个：
    
    - **`captured_at_source`**：`"filename" | "mtime"`（便于排查数据质量）
        

---

## 3) 推理基线：YOLO（先跑通框）与参数口径

### 3.1 推理请求字段（收口版）

`POST /api/v1/qc/tasks/{task_id}/infer`

**Request**

json

{

  "device": "auto",

  "model_key": "yolo",

  "model_version": "0.1.0",

  "img_size": 640,

  "conf_thres": 0.5,

  "iou_thres": 0.45,

  "max_det": 100,

  "only_uninferred": true

}

字段解释：

- **`device`**：`auto | cpu | cuda`
    
- **`model_key`**：先固定 `yolo`
    
- **`img_size`**：YOLO 推理输入尺寸（MVP 可固定 640）
    
- **`only_uninferred`**：只对未推理图片跑（避免重复消耗）
    

### 3.2 推理输出（检测框）

Detection `bbox` 定义为像素坐标：

json

"bbox": { "x1": 120, "y1": 300, "x2": 420, "y2": 520 }

---

## 4) 异步 Job：新增 Job 状态接口（用于进度条/可观测）

你之前的契约里已有 `job_id`，现在补齐状态查询与取消（取消可后置）。

### 4.1 创建推理 Job（保持不变）

`POST /api/v1/qc/tasks/{task_id}/infer`

**Response 200**

json

{

  "code": 200,

  "message": "Infer started",

  "data": {

    "task_id": "vqc_20260205_0001",

    "job_id": "job_9f3a",

    "status": "queued",

    "queued": 356

  }

}

### 4.2 查询 Job 状态

`GET /api/v1/qc/jobs/{job_id}`

**Response 200**

json

{

  "code": 200,

  "message": "OK",

  "data": {

    "job_id": "job_9f3a",

    "task_id": "vqc_20260205_0001",

    "type": "infer",

    "status": "running",

    "progress": {

      "total": 356,

      "processed": 120,

      "succeeded": 118,

      "failed": 2

    },

    "started_at": "2026-02-05T17:05:00+08:00",

    "updated_at": "2026-02-05T17:06:10+08:00",

    "ended_at": null,

    "error_message": null

  }

}

状态枚举建议：

- `queued | running | succeeded | failed | canceled`
    

### 4.3 （可选）取消 Job

`POST /api/v1/qc/jobs/{job_id}/cancel`

- MVP 可以先不实现，但契约预留对前端更友好。
    

---

## 5) 任务创建接口：按 `./data/camera` 场景收口

`POST /api/v1/qc/tasks`

**Request（推荐用相对路径）**

json

{

  "name": "Line1 ShiftA 2026-02-05",

  "source_dir": "./data/camera/line1/shiftA",

  "recursive": true,

  "extensions": ["jpg","jpeg","png","bmp","webp"],

  "limit": 2000

}

**错误码补丁**

- `403`：`source_dir` 不在 `{PROJECT_ROOT}/data/camera` 下
    
- `422`：文件名时间解析规则非法（如果你未来允许前端传 `filename_time_pattern` 才需要；MVP不需要）
    

---

## 6) 数据库结构补丁（只列与本次确认强相关的字段）

在 `vqc_image` 表建议加：

- `captured_at TIMESTAMP WITH TIME ZONE`
    
- `captured_at_source VARCHAR(16)`（`filename/mtime`）
    
- `file_rel_path TEXT`（相对于 `VQC_ROOT_DIR` 的路径，便于迁移与安全）
    
- `file_abs_path TEXT`（可选；更安全的做法是只存 rel_path + root_dir）