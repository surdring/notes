# NCV6.5产品手册-数据方案
## Page 1

yonyou

![yonyou NC logo, featuring red NC text with a thin horizontal line underneath]()

产品手册- V6.5

---

# 数据方案

yonyou

## Page 2

NC

大型企业管理与电子商务平台

# 版权

© 用友集团版权所有

未经用友集团的书面许可，本操作手册任何整体或部分的内容不得被复制、复印、翻译或缩减以用于任何目的。本操作手册的内容在未经通知的情形下可能会发生改变，敬请留意。请注意：本操作手册的内容并不代表用友软件所做的承诺。

用友网络科技股份有限公司

## Page 3

# 目录

|  |  |
| --- | --- |
| 版权 | 1 |
| 第一章 概述 | 3 |
| 1.1 产品概述 | 3 |
| 1.2 产品价值 | 3 |
| 第二章 应用场景 | 5 |
| 2.1 业务数据模型准备 | 5 |
| 2.1.1 查询预算数据 | 5 |
| 2.1.2 查询总账数据 | 24 |
| 2.1.3 查询报表数据 | 43 |
| 2.2 报表数据分析 | 77 |
| 2.2.1 报表数据分折 | 77 |
| 2.3 V65 业务数据提取 | 85 |
| 2.3.1 V65 业务数据提取 | 85 |
| 2.4 V57 业务数据提取 | 104 |
| 2.4.1 V57 业务数据提取 | 104 |

用友网络科技股份有限公司

## Page 4

大型企业管理与电子商务平台

上海易企秀信息技术有限公司

# 第一章 概述

## 1.1 产品概述

数据方案提供面向业务过程的建模过程，和简洁报表设计过程。让用户用所熟悉的业务术语建立数据模型，使得报表系统得以实现数据建模由面向 IT 转向面向业务，如提供财务人员熟悉的报表项目、科目发生额余额、会计期间、辅助核算等，让用户用报表项目拖拽式方式设计报表，解决了以前报表公式书写复杂且不直观的问题。

## 1.2 产品价值

V63 起提供的“数据方案”功能，还能实现不同领域数据的对比查询与分析。此功能具有以下特点：面向跨领域的财务数据使用者，通过事先定义的“数据方案”，支持后续快速报表查询与分析。支持跨领域的数据对比与分析，数据来源包括“总账、预算、企业报表、合并报表”。支持数据快速预览，结合“总账/预算/企业报表”的相关功能实现“无公式取数”。单独设计的“报表项目”提供“一次科目映射，多次报表使用”的特性。简化报表维护与管理。

1. 支持报表项目体系。
   1. 报表项目体系支持上下级关系的报表项目;
   2. 支持报表项目成员多级管控;
   3. 支持于集团、成员单位的通过下级科目表对上级管控的报表项目成员进行个性化映射取数;
   4. 报表项目的映射关系支持多对多、模糊匹配映射。
2. 支持数据方案集成报表数据。
   1. 支持集成同构系统数据：
      1. 通过按报表项目、辅助核算、财务常用度量展示的业务数据模型，可方便的进行财务报表数据输出;
      2. 报表项目类型包括会计科目、现金流量表项目;
      3. 可集成总账、企业报表、合并报表、预算的同版本数据;

## Page 5

**NC**

大型企业管理与电子商务平台

2) 支持V5X财务数据方案集成NC57总账数据；

3) 支持集成其他异构系统的数据。

3. 采集报表工具增加提供全新取数模型和取数画表工具（数据方案、行列画表）。

1) 支持按数据方案设置取数，可直接把财务数据方案的报表项目、度量、组织、时间、辅助核算等直接拖拽到表样行头列表头快速设置取数关系；

2) 支持行向、列向多层自由拖拽设置，支持报表项目智能匹配，支持时间期间易用性设置、支持预

实分析对比设置。

4. 增强报表数据分析。

1) 实现“预、实分析”等常见报表；

2) 提供多维形式的财务数据方案预览功能，预览结果支持压缩空行、排除、数据追踪、数据钻取、交叉显示等功能，财务数据方案支持发布至NC功能点；

3) 多维转换报表数据：支持按报表项目供给报表和合并报表数据，通过映射报表关键字、指标到财务数据中的报表项目、度量、期间等维度，输出报表结构化数据；

4) 支持报表多维结构化数据进行多维报表分析，如多维透视表。

5. V633增强数据方案取数的业务计算灵活性

1) 支持按维度属性设置过滤条件

2) 支持按报表项目重分类

3) 支持报表多维结构化数据进行多维报表分析，如多维透视表。

6. V633优化完善数据方案功能

1) 在数据方案下去掉【发布节点】功能。

2) 数据方案下去掉【报表数据分析】功能节点，迁移至企业报表。

## Page 6

## 第二章 应用场景

### 2.1 业务数据模型准备

#### 2.1.1 查询预算数据

##### 2.1.1.1 业务描述

➢ 主管组织通过设置报表项目，以及报表项目的对应关系，则可以查看全面预算系统的部分数据。

## Page 7

## 2.1.1.2 业务流程

![流程图：查看预算数据。流程从起始点开始，依次经过以下步骤：新建报表项目体系或使用现有体系，新建报表项目或使用现有项目，设置报表项目与预算项目的映射关系，新建数据方案，最后进行数据预览，然后到达结束点。]()

图 2.1.1.2-1 查看预算数据

## Page 8

## 2.1.1.3 功能清单

| 领域 | 产品模块 | 功能节点 |
| --- | --- | --- |
| 企业绩效管理 | 数据方案 | 报表组织体系 |
|  |  | 报表项目-全局/集团/组织 |
|  |  | 映射关系-全局/集团/组织 |
|  |  | 财务数据方案-全局/集团/组织 |

## 2.1.1.4 产品解决方案

### 2.1.1.4.1 报表项目体系

1. 预置的报表项目体系
   * 为了方便使用，系统已经预置了报表项目体系—“新准则财务报表”。用户可以直接使用该体系。

| 报表项目体系 | | | | | | |
| --- | --- | --- | --- | --- | --- | --- |
| 功能导航 | | 消息中心 | | 报表项目体系 | | |
| 新增 | 修改 | 删除 | 刷新 |  |  |  |
|  | 编码 | 名称 | 备注 | 创建人 | 被财务报表使用 | |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 0001 | 新准则财务报表 | NC |  |  |  |
| 2 | 0002 | 会计科目 | s2 |  |  |  |
| 3 | 0003 | 客户档案 | s2 |  |  |  |
| 4 | 0005 | 供应商档案 | s2 |  |  |  |

图 2.1.1.4.1-1

1. 新建报表项目体系
   * 不需要使用预置的体系时，可以新增一个报表项目体系。点击【新增】按钮。

## Page 9

![Figure 2.1.1.4-2 shows a screenshot of the 'Report Project List' interface. It is a table with columns: Code (编码), Name (名称), Remarks (备注), Creator (创建人), and Used in Financial Reports (被财务报表使用). The table lists several predefined reports. The first row, 'New Standard Financial Report' (新准则财务报表), is highlighted with a red arrow pointing to the 'Save' button (保存) in the top left of the table, indicating it can be edited. Subsequent rows include 'Accounting Items' (会计科目), 'Customer List' (客户档案), 'Supplier List' (供应商档案), and an empty row.]()

图 2.1.1.4-2

输入编码、名称后点【保存】按钮。

* 注意：编码为全局唯一、禁止重复。
* 被财务报表使用勾选项禁止修改，他是财务三大表所使用的标志。

#### 2.1.1.4.2 报表项目

1. 预置的报表项目
   * 为了方便使用，系统已经预置了报表项目—“新准则财务报表”。用户可以直接使用这些报表项目。

## Page 10

NC
大型企业管理与电子商务平台

![Figure 2.1.1.4.2-1: Screenshot of the Report Project Master Data interface (NC ERP system). The interface shows tabs for New Report, Reference Generation, Modify, Delete, Print, etc. The main section displays the Report Project List, including fields for Report Group, Report Type, Category, and Item Properties. A search/filter area is visible, along with a list of existing projects like 01 Property and Liability Accounts, 0101 Property and Liability Accounts, etc.]()

图 2.1.1.4.2-1

## 2. 新增报表项目

* 不需要使用预置的报表项目时,可以新增报表项目。报表项目的新增方法有两种

* **第一种: 直接点击【新增】按钮新增。根据要求,录入相应的字段,点【保存】即可。**

![Figure 2.1.1.4.2-2: Screenshot of the Report Project Master Data interface showing the '新增' (Add New) button highlighted, and fields for entering report project details.]()

图 2.1.1.4.2-2

* **第二种: 参照生成。**

![Figure 2.1.1.4.2-3: Screenshot of a context menu showing options: 参照生成 (Reference Generation), 修改 (Modify), and 删除 (Delete). Sub-options include 会计科目 (Chart of Accounts) and 现金流量项目 (Cash Flow Item), both with a shortcut key Ctrl+N.]()

图 2.1.1.4.2-3

## Page 11

NC
大拿企业管理与电子商务平台

可以通过参照会计科目、现金流量项目生成对应的报表项目。

科目选择

至
条件

确定(Ω)
取消(Ω)

图 2.1.1.4.2-4

选择对应的条件,根据该条件可以将科目编码和名称直接生成为报表项目的编码和报表项目的名称。

**注意:**

* 现金流量项目没有参照界面,会直接生成报表项目,所生成的报表编码前面会自动追加 CF\_, 报表项目的名称为现金流量项目名称。
* 只有通过参照生成的报表项目,会自动设置报表项目与科目(或者现金流量项目)的映射关系。其他两种方法生成的报表项目,不会自动设置映射关系。

* 第三种:导入

通过基础数据功能页点自带的导入功能,可以导入报表项目。

![NC software interface showing the 'Data Import' (数据导入) tab. The main window displays 'Export Format Document' (导出格式文件) and 'Import' (导入). The 'Import' section has fields labeled 'Source Document' (所属类别) and 'Import Interface' (导入界面) with dropdown menus.]()

## Page 12

图 2.1.1.4-2-5

选择所属类别和待导入档案。

![Screenshot of the NC system interface showing 'Export Template' and 'Import Data' tabs selected, and options for 'Report Category' and 'Project Level'.]()

图 2.1.1.4-2-6

先导出格式文件，然后在 Excel 上维护需要导入的报表项目信息，然后通过导入按钮导入。

![Screenshot of the NC system interface showing the import screen with fields for Report Category, Organization, Project Level, etc.]()

3. 报表项目的管控模式

> 报表项目-集团只能维护集团级的报表项目不能修改全局级的报表项目

> 报表项目-组织只能维护组织级的报表项目不能修改全局级、集团级的报表项目

注意：

> 只有通过参照生成功能生成的报表项目，才会自动设置与会计科目或现金流量项目的映射关系。

2.1.1.4.3 映射关系

1. 预置的映射关系

> 为了方便使用，系统已经设置了预置的报表项目与预置会计科目的映射关系，用户可以直接使用，也可以修改。

## Page 13

✓ 注意: 系统不提供“还原至预算映射关系”的功能。

## 2. 新增映射关系

新增映射关系有两种方法。A 直接修改原有的映射关系; B 按管控模式进行个性化的设置

### A 直接修改

![Screenshot of the NC financial system interface showing the '新增映射关系' (New Mapping Relationship) setup page. The screen displays a list of budget items and their corresponding mapping relationships, including fields for budget item code, budget item name, budget project type, budget item classification, and associated checkboxes for various cost centers and cost items.]()

![Screenshot of the NC financial system interface showing a different view of the '新增映射关系' (New Mapping Relationship) setup page. This screen displays a table listing budget items with detailed columns for budget item code, budget item name, budget project type, budget item classification, and associated checkboxes for various cost centers and cost items. The table includes entries for different cost centers (Business Center, Asset Center, Other Cost Centers, etc.).]()

## Page 14

图 2.11.4.3-1

选择报表项目体系, 选择会计科目体系后, 点击映射按钮, 可以对报表项目现有的映射关系进行修改。修改后需要点击保存按钮进行存储。

* ■ 按管控模式进行个性化的设置

## Page 15

![Screenshot of the NC system interface showing two related pages. Both pages are titled '报表项目目录' (Report Item Directory). The top screenshot displays a list of report items with columns for '编号' (Number), '名称' (Name), '所属单位' (Belonging Unit), '预算科目分类' (Budget Subject Classification), '科目编码' (Subject Code), '科目名称' (Subject Name), and checkboxes for '科目是否' (Is Subject). The bottom screenshot shows the same list, but with the row for '1.11' (名称: 经济发展基金) highlighted, indicating an edit or detail view. Below the table, there are buttons like '取消' (Cancel) and '保存' (Save). A red box highlights the '科目编码' column in the second screenshot, showing a detailed subject code structure.]()

图 2.114-3-2

在映射关系、集团、映射关系组织功能节点中,可以通过个性化按钮,针对报表项目的映射关系进行修改。修改后个性化标识会被勾选。通过取消个性化按钮可以去掉个性化映射。

## Page 16

### 2.1.1.4.4 财务数据方案

1. 新建财务数据方案

► 在报表项目以及映射关系均完成后, 可以建立数据方案。

![Screenshot of the financial data plan management interface, showing a table listing various financial data plans (e.g., 0001, 0002, 0003, 0004, 0005) with details such as report type, category, status, and associated accounting items and periods.]()

图 2.1.1.4-1

1) 首次建立数据方案时, 需要先建立分类, 同一二级次下分类的名称禁止重复。

![Screenshot of the new data plan creation form. It includes fields for name and description, and a section for accounting information.]()

图 2.1.1.4-2

2) 然后点新增按钮, 建立报表项目。根据需要输入方案编码、名称、报表项目体系、会计期间方案等信息

## Page 17

大型企业管理与电子商务平台

**NC**

![Screenshot of the NC ERP system showing the 'Scheme Dimension Settings' interface. It displays a table with columns for 维度名称 (Dimension Name), 筛选条件 (Filter Conditions), and 数据来源 (Data Source).]()

**图 2.11.4.4-3**

3) 然后依次选择该方案所包含的维度、度量、数据来源信息。

![Schematic diagram of a table row showing four action buttons: 1. (Icon: Add) 2. (Icon: Delete) 3. (Icon: Edit) 4. (Icon: View).]()

**图 2.11.4.4-4**

4) 维度页签下，四个按钮的作用分别为选择维度、设置自定义维度成员范围、维度属性与规定属性的关联设置、分析维度设置。

## Page 18

NC

大型企业管理与电子商务平台

维度选择

#### 待选维度

* 可选维度
  + 公共档案
  + 基础档案
  + 自定义档案
* 固定资产
  + 使用状况

- 增减方式
  * 资产类别
- 预算
- 总账

#### 已选维度

* 可选维度
  + 账套信息
  + 报表组织
  + 报表项目
  + 时间维度

确定(Q) 撤销(O)

图 2.1.1.4.4-5

维度选择时提供四个默认维度,默认维度不可删除。

待选维度是由所有的自定义档案、各业务模块预置的特有维度档案以及一部分公共档案构成。

这部分公共档案来自于动态建模平台->基础数据->会计辅助核算项目功能节点的数据对象列,去重之后的结果。

## Page 19

### 图 2.11.4.4-5

![A screenshot of a data dictionary management interface, likely within the NC software. The interface is titled '数据字典管理' (Data Dictionary Management) and shows a grid listing various data elements (编号, 模块, 字段, 数据类型, 可空, 输入长度, 精度, 前置人). The fields listed include: 编号 (0001), 模块 (部门), 字段 (部门), 数据类型 (文本), 可空 (否), 输入长度 (50), 精度 (0), 前置人 (张三). The grid includes additional data elements such as 人员档案, 地区分类, 客户档案, 内部客商, 供应商档案, 库房档案, 项目, 银行客户子户, 等.]()

当某些自定义档案成员过多，害怕会影响到取数效率，可以通过设置其成员范围来提升效率。

### 图 2.11.4.4-6

![A screenshot of a data range management interface. The interface is titled '数据范围' (Data Range) and shows a grid listing data ranges (编号, 数据范围名称). The fields listed include: 编号 (0001), 数据范围名称 (数据范围名称). The interface also includes navigation buttons like '新建', '修改', '删除', '保存', '取消' (New, Modify, Delete, Save, Cancel), and a red line indicating a search or selection operation.]()

图 2.11.4.4-6

## Page 20

当某些维度档案需要与组织进行关联时，可以通过维度属性关联设置进行关联。

![图 2.1.1.4.4-7：界面截图，显示了维度属性关联设置的窗口。左侧是维度列表，右侧是属性列表。底部有‘新建’和‘编辑’按钮。]()

**图 2.1.1.4.4-7**

![图 2.1.1.4.4-8：界面截图，显示了维度属性关联设置的详细界面。包含维度属性、属性值和关联属性的列表，并有‘新建’和‘编辑’按钮。]()

**图 2.1.1.4.4-8**

最后一个分析维度设置，是使该数据方案用于企业报表模板下的多维数据分析功能所用，满足其分析特定字段的要求。

![界面截图，显示了分析维度设置的详细界面。包含多列属性列表和复选框，用于选择特定分析字段。底部有‘新建’和‘编辑’按钮。]()

## Page 21

①全面预算

**企业预算**

①公开预算
②公开数据

③预算方案

④ NC-XBRL

⑤ 企业属性
⑥ 复核于
⑦ 数据源

**预算管理**

①预算表样-全局
②预算表样-预算组织
③任务-全局
④任务-集团
⑤任务-预算组织
⑥审核方案-全局
⑦审核方案-集团
⑧审核方案-预算组织
⑨打切方案-全局
⑩打切方案-集团
⑪打切方案-预算组织
⑫条件平衡条件
⑬透义模型-全局
⑭透义模型-集团

**业务管理**

①透义模型-预算组织
②预算模型-全局
③预算模型-集团

①任务分配
②接收的任务
③汇总规则
④预算数据跟踪
⑤个性化公式管理
⑥审批流设置
⑦任务再分配
⑧预算一致性调整

**数据中心**

①预算数据源
②预算数据管理
③预算数据中心
④审批执行
⑤汇总执行
⑥预算上报
⑦预算管理

①预算报表
②指标计算
③预算数据汇总
④计划任务
⑤预算数据审批

**外部接口**

①大天单据的接口
②大天单据的接口-收量
③大天单据的接口-数据传输

**移动订购**

①移动订购
②审批订购
③推送订购

**系统监控**

①预算计算监控
②预算计算监控-变更
③预算数据订阅监控

**数据分析**

①预算数据分析
②多维数据分析

图 2.1.1.4.4-9

维度设置完成后,需要选择度量。

![图 2.1.1.4-10: 一个弹出框，标题为“度量”，左侧列表显示“全量”和“增量”，右侧显示“选择度量”和“选择维度”的选项。下方的“全量”选项被选中，其对应的度量列表中，“增量”、“增量(半年期)”、“增量(一年期)”等选项被勾选。]()

图 2.1.1.4-10

度量至少选择一个,待选择度量不支持前台认为新增。


## Page 22

度量设置完成后，需要设置数据来源。

![Figure 2.1.1.4.4-12: Screenshot of a data source configuration dialog (Data Source tab). It shows a list of data items with fields like Data Item, Data Type, and Data Source, along with an Add button and a Delete button at the top right.]()

图 2.1.1.4.4-12

第一次进入数据来源时，为空白。点击新增后系统会自动带出计划-预算：实际-总额两个来源。可以根据需要来添加或者删除数据来源。

![Figure 2.1.1.4.4-13: Screenshot of a data source configuration dialog (Data Source tab). It shows a list of data items with fields like Data Item, Data Type, and Data Source. Two items are visible: '计划' (Plan) and '预算' (Budget), with '实际-总额' (Actual - Total) in the Data Source field for the Budget item.]()

图 2.1.1.4.4-13

然后双击取数规则进行设置，在弹出界面设置预算取数规则。

![Figure 2.1.1.4.4-14: Screenshot of a data rule configuration dialog (Data Rule tab). It shows a table with columns '维度' (Dimension), '度量' (Measure), '数据来源' (Data Source), and '取数规则' (Data Extraction Rule). The row shows '计划' (Plan) and '预算' (Budget) under '维度' and '度量', respectively. The '取数规则' field is an input box containing the number 63.]()

图 2.1.1.4.4-14

## Page 23

NC 大型企业管理和电子商务平台

![Figure 21.1.4.4-15: A screenshot of the 'Budget Calculation Flow' page. The page title is '预算数据流' (Budget Data Flow). The application model is KUFO. The page consists of '取数条件' (Data Extraction Conditions) and '组织选择' (Organization Selection) sections. '取数条件' includes fields for: 预算维度 (Budget Dimension) - 默认版本 (Default Version); 版本 (Version) - 默认版本 (Default Version); 目标币种 (Target Currency) - 默认币 (Default Currency); 业务方案 (Business Plan) - 默认预算 (Default Budget); 指标 (Indicator) - 计划现金、人民币、黄金、英镑、法郎、欧元、日元、银行存款、活期存款、银行存款10020101, 银行存款10020102, 银行存款10...; 度量维度 (Measurement Dimension) - 期初数、期末数、全年累计 (Beginning Balance, Ending Balance, Annual Accumulated). The '组织选择' (Organization Selection) section is blank. Buttons for 确定 (Confirm) and 取消 (Cancel) are visible at the bottom right.]()

图 21.1.4.4-15

首先选择一个预算应用模型，然后依次根据需要设置版本、原币、目标币种、业务方案、指标、度量维度。接着切换至组织选择页签，至少选择一个组织。

## Page 24

#### 2. 财务数据方案预览

▶ 建立数据方案完成后可以通过数据预览查看该数据方案数据。

![Figure 2.1.1.4-16: Screenshot of the 'Select Allocation Method' window (选择分配方法). The left panel shows available allocation methods (e.g., 0109 驾率 1143, 0109 驾率 1107). The right panel shows selected methods (0145 已选 2411). The bottom options allow selecting the entire node, only the node, direct selection, or no selection. Buttons 'Confirm' and 'Cancel' are also visible.]()

图 2.1.1.4-16

![Figure 2.1.1.4-17: Screenshot of the 'NC Financial Data Plan - Main View' interface (NC 财务数据方案 - 主界面). The interface shows menu tabs and a data preview table. The table header displays '方案名称' (Scheme Name), '测试计算数据' (Test Calculation Data), '方案分类' (Scheme Category), '测试专用' (Test Special Use), '启用状态' (Enable Status), and '已启用' (Enabled). The main content area shows a preview of data for the scheme name '0002'.]()

图 2.1.1.4-17

▶ 数据预览。

## Page 25

大型企业管理与电子商务平台

NC

![图 2.1.1.4.4-18: A screenshot of the NC (New Century) ERP system interface. The screenshot shows a data query window, likely a spreadsheet or report template, with a toolbar above and data entries below. The main area displays columns and rows, possibly representing inventory or financial data. A red arrow points from the top-left to the bottom-left, highlighting a specific area of the interface, possibly indicating the location of the '查询' (Query) button.]()

图 2.1.1.4.4-18

选择需要查询的成员，然后点击查询，如果有数据的，就可以查询。否则会显示无数据。
如果无数据，请检查映射关系是否设置正确，以及业务系统是否存在对应的数据。

注意：

* 数据方案中度量不能为空。
* 数据方案中组织选择不能为空。

## 2.1.2 查询总账数据

### 2.1.2.1 业务描述

* > 主管组织通过设置报表项目，以及报表项目的对应关系，则可以查看总账业务系统的数据。

## Page 26

## 2.1.2.2 业务流程

![流程图：查看总账数据。该流程图从一个起始圆圈开始，依次经过以下步骤：
1. 新建报表项目体系或使用现有体系。
2. 新建报表项目或使用现有项目。
3. 设置报表项目与会计科目现金流量项目的映射关系。
4. 新建数据方案。
5. 进行数据预览。
流程图的终点是一个圆圈。图片上有“用友网络科技股份有限公司”的水印。]()

图 2.1.2-1 查看总账数据

## Page 27

2.1.2.3 功能清单

| 领域 | 产品模块 | 功能节点 |
| --- | --- | --- |
| 企业绩效管理 | 数据方案 | 报表组织体系 报表项目-全局/集团/组织 映射关系-全局/集团/组织 财务数据方案-全局/集团/组织 |

2.1.2.4 产品解决方案

整体解决方案与查看预算业务数据大体相同,仅在设置报表项目映射关系和数据来源选择时有所不同,其余操作与查询预算数据的操作相同。

2.1.2.4.1 报表项目体系

1. 预置的报表项目体系
   > 为了方便使用,系统已经预置了报表项目体系一“新准则财务报表”。用户可以直接使用该体系。

![NC 功能导航 报表项目体系 界面截图，显示预置的报表项目体系：新准则财务报表、会计科目、客户档案、供应商档案。]()

图 2.1.2.4.1-1

1. 新建报表项目体系
   > 不需要使用预置的体系时,可以新增一个报表项目体系。点击【新增】按钮

## Page 28

![图 2.1.2.4-2 截图：NC 财务项目体系界面，显示了报表项目列表，包括编码、名称、备注、创建人和被财务报表使用。列表中包含4条记录：1. 0001 新准则财务报表 (NC, 选中); 2. 0002 会计科目 (s2); 3. 0003 客户档案 (s2); 4. 0005 供应商档案 (s2)。界面顶部有'功能导航'、'消息中心'和'报表项目体系'标签。界面底部有'保存'和'取消'按钮。]()

**图 2.1.2.4-2**

> 输入编码、名称后点【保存】按钮。

* 注意：编码为全局唯一、禁止重复。
* 被财务报表使用勾选项禁止修改，他是财务三大表所使用的标志。

#### 2.1.2.4.2 报表项目

1. 预置的报表项目

> 为了方便使用，系统已经预置了报表项目一“新准则财务报表”，用户可以直接使用这些报表项目。

## Page 29

### 2. 新增报表项目

▷ 不需要使用预置的报表项目时，可以新增报表项目。报表项目的新增方法有三种

* 第一种：直接点击【新增】按钮新增

![Screenshot of the NC ERP system interface showing the '报表项目-全局' (Report Items - Global) page. It lists various report items such as '01 财产负债表项目' (01 Balance Sheet Items) and '02 利润表项目' (02 Income Statement Items), each with sub-items. The navigation breadcrumb is '功能导航 > 浏览中心 > 报表项目体系 > 报表项目-全局'. A search bar is visible.]()

图 2.1.2.4-2-1

![Screenshot of the NC ERP system interface showing the detailed view of a report item, likely the Balance Sheet. It displays fields such as '报表组织' (Report Organization), '档案类型' (Archive Type), '编号' (Number), '项目性质' (Project Nature), '计算符' (Calculation Symbol), and '备注' (Remarks), along with a list of specific balance sheet items like '0101 流动资产合计' (0101 Total Current Assets) and '0102 非流动资产合计' (0102 Total Non-current Assets).]()

图 2.1.2.4-2-2

根据要求，录入相应的字段，点【保存】即可

* 第二种：参照生成

![Screenshot showing the process of generating new report items by reference. A menu is displayed with options: 参照生成 (Generate by Reference), 修改 (Modify), and 删除 (Delete). The user is hovering over '参照生成'. The background shows a list of accounting subjects and cash flow items, with codes like CSH-H (Current Asset) and CSH-N (Non-current Asset).]()


## Page 30

#### 图 2.1.2.4-3

可以通过参照会计科目、现金流量项目生成对应的报表项目

![图 2.1.2.4-3: 项目选择对话框截图。显示了科目体系、科目表、科目版本的输入框，以及科目和额度的下拉选择框，以及确定和取消按钮。]()

#### 图 2.1.2.4-4

选择对应的条件，根据该条件可以将科目编码和名称直接生成为报表项目的编码和报表项目的名称。

* 注意：现金流量项目没有参照界面，会直接生成报表项目，所生成的报表编码前面会自动追加 CF\_。报表项目的名称为现金流量项目名称。
* 只有通过参照生成的报表项目，会自动设置报表项目与科目（或者现金流量项目）的映射关系。其他两种方法生成的报表项目，不会自动设置映射关系。
  + 第三种：导入

通过基础数据功能点自带的导入功能，可以导入报表项目。

![图 2.1.2.4-5: 系统界面截图。显示了功能导航、消息中心、报表项目全览和数据导入选项卡。数据导入页面提供了导出格式文件和导入选项。]()

#### 图 2.1.2.4-5

## Page 31

![NC Logo and header text: 大型企业管理与电子商务平台]()

## 选择所属类别和待导入档案

![Screenshot of the NC import interface showing options for selecting report template, entering report project, and importing data.]()

图 2.1.2.4.2-6

先导出格式文件，然后在 Excel 上维护需要导入的报表项目信息，然后通过导入按钮导入。

### 3. 报表项目的管控模式

* 报表项目-集团只能维护集团级的报表项目不能修改全局级的报表项目
* 报表项目-组织只能维护组织级的报表项目不能修改全局级、集团级的报表项目

**注意：**

* 只有通过参照生成功能生成的报表项目，才会自动设置与会计科目或现金流量项目的映射关系。

### 2.1.2.4.3 映射关系

#### 1. 预置的映射关系

* 为了方便使用，系统已经设置了预置的报表项目与预置会计科目的映射关系。用户可以直接使用，也可以修改。
* 注意：系统不提供“还原至预置映射关系”的功能。

## Page 32

## 2. 新增映射关系

* 新增映射关系有两种方法。A 直接修改原有的映射关系；B 按管控模式进行个性化的设置
  + A 直接修改

![Screenshot of the NC software interface showing the '新增映射关系' (New Mapping Relationship) screen. The screen displays a list of business units (1 to 14, plus '中电') and their corresponding mapping details. Columns include: 序号 (Serial Number), 业务单元 (Business Unit), 成本流量项目 (Cost Flow Item), 预算科目 (Budget Subject), 应收应付科目 (Accounts Receivable/Payable Subject), 项目编码 (Project Code), 权益科目 (Equity Subject), 权益科目余额 (Equity Subject Balance), 权益科目余额方向 (Equity Subject Balance Direction), and 权益科目余额 (Equity Subject Balance). The screen also shows buttons for 清空 (Clear) and 重置 (Reset), and checkboxes for 显示项目 (Display Items) and 业务项目 (Business Items).]()

图 2.1.2.4-3-1

## Page 33

选报表项目体系、选择会计科目体系后，点击映射按钮，可以对报表项目现有的映射关系进行修改。修改后需要点击保存按钮进行存储。

现金流量项目的映射方法与会计科目项目的映射方法相同。

**B 按管控模式进行个性化的设置**

![Screenshot 1: NC system interface showing the configuration of the cash flow statement mapping relationships (映射关系设置). The screen shows a table listing various cash flow items (e.g., 收回投资收到的现金, 收到其他与经营活动有关的现金) mapped to corresponding accounting subjects (e.g., 主营业务收入, 管理费用). Each item has fields for subject code, subject name, original subject code, original subject name, and checkboxes for whether it is a basic subject or a detail subject.]()

![Screenshot 2: NC system interface showing the configuration of the cash flow statement mapping relationships, with detailed fields expanded for entry. This screen shows specific entries for 主营业务收入 (Main Business Income) and 投资收益 (Investment Income), including detailed subject codes and names for the original subjects.]()

图 2.12.4-32

## Page 34

在映射关系-集团、映射关系-组织功能节点中，可以通过个性化按钮，针对报表项目的映射关系进行修改。修改后个性化标识会被勾选。通过取消个性化按钮可以去掉个性化映射。

现金流量项目的映射方法与会计科目的映射方法相同。

#### 2.1.2.4.4 财务数据方案

**1. 新建财务数据方案**

在报表项目以及映射关系均完成后，可以建立数据方案。

![系统界面截图：显示了财务数据方案管理页面，包含项目列表、筛选条件、数据预览等，左侧有导航标签。表头包括：项目名称、项目代码、所属集团、所属组织、数据类型、数据来源、数据状态、数据说明、预计使用次数、备注。示例数据行：项目名称：集团本部/项目部/集团本部/项目部/集团本部/项目部/集团本部/项目部；项目代码：0001/0002/0003/0004/0005/0006；所属集团：集团本部；所属组织：集团本部；数据类型：集团本部；数据来源：已启用；数据状态：已启用；数据说明：销售费用-差旅费；预计使用次数：458；备注：无。]()

图 2.1.2.4-4-1

首次建立数据方案时，需要先建立分类。同一级次下分类的名称禁止重复。

## Page 35

大宏企业管理与电子商务平台

### 新增方案分类

![图 2.1.2.4.4-2: 新增方案分类弹窗。显示 '名称' 输入框和 '上级分类' 选择框，下方有 '描述' 文本域，底部有 '确定' 和 '取消' 按钮。]()

**图 2.1.2.4.4-2**

然后点击新增按钮,建立报表项目

![图 2.1.2.4.4-3: 报表项目界面。显示了报表项目列表，包括方案编码、名称、维度、度量等信息。界面底部有导航栏。]()

**图 2.1.2.4.4-3**

根据需要输入方案编码、名称、报表项目体系、会计期间方案等信息。
然后依次选择该方案所包含的维度、度量、数据来源信息。

## Page 36

NC

大企业集团管理与电子商务平台

![图 2.1.2.4.4-4: 展示了维度设置界面，左侧显示维度列表（1. 购置商品，2. 购置组织，3. 购置项目，4. 时间维度），右侧有四个按钮。]()

**图 2.1.2.4.4-4**

维度页签下，四个按钮的作用分别为选择维度、设置自定义维度成员范围、维度属性与规定属性的关联设置、分析维度设置。

![图 2.1.2.4.4-5: 展示了维度选择界面。左侧为‘待选维度’，右侧为‘已选维度’。待选维度列出了可选维度及其公共/自定义属性。已选维度显示了已选择的维度及其属性。界面底部有确定和取消按钮。]()

**图 2.1.2.4.4-5**

维度选择时提供四个默认维度，默认维度不可删除。

待选维度是由所有的自定义档案、各业务模块预置的特有维度档案以及一部分公共档案构成。这部分公共档案来自于动态建模平台->基础数据->会计辅助核算项目功能节点的数据对象，去重之后的结果。

## Page 37

NC

大型企业管理与电子商务平台

功能导航 业务中心 供财关系云图 供财关系集团 制本创意方案云图 合计编制批复项目

| 编号 | 项目 | 操作 | 帮助 | 项目设置 | | | |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 辅助核算设置编码 | 辅助核算设置名称 | 数量对象 | 参照名称 | 输入长度 | 精度 | 创建人 |
| 1 | 0001 | 部门 | 项目设置 | 部门 | 部门 | 部门 |  |  |
| 2 | 0002 | 人员档案 | 人员档案 | 人员档案 | 人员 |  |  |
| 3 | 0003 | 地区分类 | 地区分类 | 地区分类 | 地区分类 |  |  |
| 4 | 0004 | 客商 | 客商 | 客商档案 | 客商档案 |  |  |
| 5 | 0005 | 内部客商 | 内部客商 | 内部客商 | 内部客商 |  |  |
| 6 | 0006 | 物料基本信息 | 物料基本信息 | 物料基本信息 | 物料 |  |  |
| 7 | 0007 | 现金流量项目 | 现金流量项目 | 现金流量项目 | 现金流量项目 |  |  |
| 8 | 0008 | 收支项目 | 收支项目 | 收支项目 | 收支项目 |  |  |
| 9 | 0009 | 现金计划项目 | 现金计划项目 | 现金计划项目 | 现金计划项目 |  |  |
| 10 | 0010 | 项目 | 项目 | 项目 | 项目 |  |  |
| 11 | 0011 | 银行账户 | 银行账户子户 | 银行账户子户 | 银行账户子户 |  |  |
| 12 | 0012 | 物料成本分类 | 物料成本分类 | 物料成本分类 | 物料成本分类 |  |  |
| 13 | 0013 | 结算方式 | 结算方式 | 结算方式 | 结算方式 |  |  |
| 14 | 0014 | 仓库档案 | 仓库 | 仓库 | 仓库 |  |  |
| 15 | 0015 | 运输方式 | 运输方式 | 运输方式 | 运输方式 |  |  |
| 16 | 0016 | 客户基本分类 | 客户基本分类 | 客户基本分类 | 客户基本分类 |  |  |
| 17 | 0017 | 客户档案 | 客户档案 | 客户档案 | 客户 |  |  |
| 18 | 0018 | 供应商基本分类 | 供应商基本分类 | 供应商基本分类 | 供应商基本分类 |  |  |
| 19 | 0019 | 供应商档案 | 供应商档案 | 供应商档案 | 供应商档案 |  |  |
| 20 | 0020 | 产品档案 | 产品线 | 产品线 | 产品档案 |  |  |
| 21 | 0021 | 地点档案 | 地点档案 | 地点档案 | 地点档案 |  |  |
| 22 | 0022 | 银行类别 | 银行类别 | 银行类别 | 银行类别 |  |  |
| 23 | 0023 | 银行档案 | 银行档案 | 银行档案 | 银行档案 |  |  |
| 24 | 0024 | 现金账户 | 现金账户 | 现金账户 | 现金账户 |  |  |
| 25 | 0025 | 业务单元 | 组织 | 组织 | 业务单元 |  |  |
| 26 | 0026 | 账套组织 | 组织、业务单元 | 组织、业务单元 | 账套组织 |  |  |

图 2.1.2.4.4-6

当某些自定义档案成员过多，害怕会影响到取数效率，可以通过设置其成员范围来提升效率。

![A screenshot of the '项目设置' (Project Settings) window. It shows a list of items (编号 1 to 26) on the left, and the properties panel on the right. A horizontal line is drawn across the properties panel, indicating a section that can be configured.]()
## Page 38

NC

大型企业管理与电子商务平台

图 2.1.2.4.4-7

当某些维度档案需要与组织进行关联时，可以通过维度属性关联设置进行关联。

图 2.1.2.4.4-8

最后一个分析维度设置，是使该数据方案用于企业报表模板下的多维数据分析功能所用，满足其分析特定字段的要求。

图 2.1.2.4.4-9

## Page 39

![图 2.1.2.4-10: 管理后台界面截图，显示了企业资源计划 (ERP) 模块下的详细选项，包括主题配置、企业报表、关开报表、关开指标等。左侧菜单栏显示：主题配置、企业报表、关开报表、关开指标、数据方案、NC-DBRLL。右侧内容区显示了多个配置项，如系统设置、报表组织、指标配置等。]()

图 2.1.2.4-10

维度设置完成后，需要选择度量

![图 2.1.2.4-11: 软件界面截图，显示了一个数据透视表设置窗口，用于选择度量。左侧列出了可选度量，如销售额、销售数量、利润等。右侧是预览区域，红色箭头指向了被选中的度量项。下方有备注说明度量至少选择一个，且特定度量不支持前台认为新增。]()

图 2.1.2.4-11

度量至少选择一个，特定度量不支持前台认为新增。

## Page 40

度量设置完成后，需要设置数据来源。

![Figure 2.1.2.4.4-12 shows a data source interface. It displays three data sources (1, 2, 3) in a table. Columns include 度量, 数据来源, 计算方式, and 权重比例. Source 1 is named '实际', with 数据来源 '实际' and 计算方式 '求和'. Source 2 is named '总账', with 数据来源 '总账' and 计算方式 '求和'. Source 3 has an empty name, 数据来源 '实际', and 计算方式 '求和'. The interface has a '确定' (Confirm) button and a red arrow indicating a process flow.]()

图 2.1.2.4.4-12

第一次进入数据来源时，为空白。点击新增后系统会自动带出计划、预算：实际、总账两个来源。可以根据需要添加或者删除数据来源。

![Figure 2.1.2.4.4-13 shows the data source interface after adding sources. The table now contains three rows corresponding to '计划' (Plan), '预算' (Budget), '实际' (Actual), and '总账' (General Ledger). Columns include 度量, 数据来源, 计算方式, and 权重比例. Data source '实际' has 数据来源 '实际' and 计算方式 '求和'. Data source '总账' has 数据来源 '总账' and 计算方式 '求和'. The other sources have empty data entries.]()

图 2.1.2.4.4-13

然后双击取数规则进行设置，在弹出界面设置预算取数规则。

![Figure 2.1.2.4.4-14 shows the data rule interface. It is titled '取数规则' (Data Rule). The table shows '维度' (Dimension) 1, '度量' (Measure) '实际' (Actual), and '数据来源' (Data Source) '总账' (General Ledger). A text box for '取数规则' (Data Rule) is empty, with a red arrow pointing to the input area.]()

图 2.1.2.4.4-14

## Page 41

大型企业管理与电子商务平台

NC

总账取数规则

|  |  |
| --- | --- |
| 基础规则 | 业务单元 |
| |  |  | | --- | --- | | 账簿类型 | 按主账簿取数  按账簿类型取数 (带搜索图标) | | 金额性质 | [组织本币] (带搜索图标) | | 币种 | (带搜索图标)  包含未记账凭证  按二级核算单位取数 | | |
| 辅助核算   | 核算类型 | 核算内容 | | --- | --- | |  |  | |  |  | | |
| 确定 (Y)  取消 (C) | |

图2.1.2.4.4-15

根据需要设置账簿类型、金额性质、币种、辅助核算。
其中: 辅助核算选择一个后, 会新增出一个空白行。

|  |  |
| --- | --- |
| 辅助核算 | |
| 核算类型 | 核算内容 |
|  |  |
|  |  |

图2.1.2.4.4-16

## Page 42

大秦企业管理与电子商务平台

#### 辅助核算

**核算类型**

部门
人员档案
地区分类
客商
内部客商
物料基本信息
现金流量项目

#### 辅助核算

| 核算类型 | 核算内容 |
| --- | --- |
| 客商 |  |

客商档案

**我的常用**

按客户分类
 按供应商分类

**客户分类**

* 内部客户
  + 01 外部客户
  + 01 外部客户\_321
  + 1 广州总
  + 10 广州分部
  + 2 品牌部

**已选数据**

 显示停用数据

**全部数据**

过滤或搜索全部(A-F)
 全部

| 序号 | 所属组织 | 客户 |
| --- | --- | --- |
| 1 | 全局 | 0106 |
| 2 | 全局 | 010601 |
| 3 | 全局 | 0106010 |
| 4 | 全局 | 0106010 |
| 5 | 全局 | 0106010 |
| 6 | 全局 | 0106010 |
| 7 | 全局 | 0106010 |

当前: 第1页 <上一页 > 下一页

辅助核算

| 核算类型 | 核算内容 |
| --- | --- |
| 客商 | 税率915,税率916 |

## Page 43

NC
大型企业管理与电子商务平台

### 图 2.1.2.4.4-17

接着切换至组织选择页签，至少选择一个组织。

![截图显示了组织取数规则界面，左侧是待选组织列表，右侧是已选组织列表。界面包含“基础规则”和“业务单元”页签。底部显示了节点选中方式选项：不包含、所有下级、直接下级、本级。右侧有“确定”和“取消”按钮。]()

### 图 2.1.2.4.4-18

### 2. 财务数据方案预览

> 建立数据方案完成后可以通过数据预览查看该数据方案数据。

![截图显示了财务数据方案主页面，导航栏中高亮了“数据预览”选项。下方显示了方案编号0002，方案名称测试核算参数，方案类型测试专用，以及启用状态已启用。]()

### 图 2.1.2.4.4-19

> 数据预览。

## Page 44

2.1.2.4.4 报表查询

![A screenshot of a reporting tool interface, likely Microsoft Excel, showing a pivot table and a filter pane (数据源选项卡) on the left side. The filter pane allows selecting specific data ranges (e.g., 2017年10月1日至2018年10月1日) and different metrics (e.g., 项目数量, 项目金额).]()

图 2.1.2.4.4-20

选择需要查询的成员，然后点点击查询，如果有数据时，就可以查询，否则会显示无数数据。如果无数数据，请检查映射关系是否设置正确，以及业务系统是否存在对应的数据。对于部分数据，系统在右键菜单中提供联查明细、联查汇总功能。

**注意：**

* 数据方案中度量不能为空。
* 数据方案中组织选择不能为空。

### 2.1.3 查询报表数据

#### 2.1.3.1 业务描述

* 主组织通过设置报表项目，以及报表项目与报表指标的对应关系，则可以查看报表系统的数据。包含企业报表和合并报表的数据均可以通过数据方案展示出来。

## Page 45

大型企业管理与电子商务平台

![NC logo]()

#### 2.1.3.2 业务流程

![流程图: 查看报表数据。流程步骤依次是: 1. 新建报表项目体系或使用现有体系。2. 新建报表项目或使用现有项目。3. 设置报表项目与企业报表指标的映射关系。4. 新建数据方案。5. 进行数据预览。流程图底部为结束符号。]()

图 2.1.3.2-1 查看报表数据


## Page 46

## 2.1.3 功能清单

| 领域 | 产品模块 | 功能节点 |
| --- | --- | --- |
| 企业绩效管理 | 数据方案 | 报表组织体系 |
|  | 报表项目-全局/集团/组织 |
|  | 映射关系-全局/集团/组织 |
|  | 财务数据方案-全局/集团/组织 |
| 企业报表 | 数据类型管理 |
|  |  | 报表表样-全局/集团/组织 |

## 2.1.3.4 产品解决方案

整体解决方案与查看预算业务数据、总账业务大体相同,仅在设置报表项目映射关系和数据来源选择时有所不同,其余操作与查询预算数据、总账数据的操作相同。

### 2.1.3.4.1 报表项目体系

#### 1. 预置的报表项目体系

为了方便使用,系统已经预置了报表项目体系-“新准则财务报表”。用户可以直接使用该体系。

![截图显示了NC系统中的报表项目体系界面。导航栏包含'功能导航'和'消息中心'，当前选中的是'报表项目体系'。下方有'新增'、'修改'、'删除'和'刷新'四个按钮。列表显示了四个预置的报表项目：1. 0001 新准则财务报表 (NC, 已选中); 2. 0002 会计科目 (S2, 未选中); 3. 0003 客户档案 (S2, 未选中); 4. 0005 供应商档案 (S2, 未选中)。列表右侧有创建人和是否被财务报表使用等字段。]()
## Page 47

大型企业管理与电子商务平台

**2. 新建报表项目体系**

► 不需要使用预置的体系时，可以新增一个报表项目体系。点击【新增】按钮

![Screenshot of the NC Reporting Project System interface showing a table with columns: Code, Name, Remarks, Creator, and Whether Used for Financial Statements. Rows 1-5 are listed. Row 5 has a red arrow pointing to the 'New' button, which is highlighted.]()

图 2.1.3.4.1-2

► 输入编码、名称后点【保存】按钮。

✓ 注意：编码为全局唯一、禁止重复。

✓ 被财务报表使用勾选项禁止修改，他是财务三大表所使用的标志。

**2.1.3.4.2 报表项目**

1. 预置的报表项目

► 为了方便使用，系统已经预置了报表项目——“新准则财务报表”。用户可以直接使用这些报表项目。

## Page 48

![Figure 2.1.3.4.2-1: Screenshot of the NC (New Century) financial management system. The '报表项目体系' (Report Item System) section shows options like '新增' (Add), '参数生成' (Parameter Generation), and '模板' (Template). A list of existing report items (e.g., '01 资产负债表项目', '0101 资产合计') is visible.]()

图 2.1.3.4.2-1

## 2. 新增报表项目

▷ 不需要使用预置的报表项目时，可以新增报表项目。报表项目的新增方法有三种

**第一种：**直接点击【新增】按钮新增，根据要求，录入相应的字段，点【保存】即可

![Figure 2.1.3.4.2-2: Screenshot of the NC system showing a modal for adding a new report item. Fields are visible for entering report item name, category, code, and parent-child relationships (e.g., '0101 资产合计', '010102 负债和所有者权益合计').]()

图 2.1.3.4.2-2

■ 第二种：参照生成

![Figure 2.1.3.4.2-3: Screenshot showing a right-click context menu with options: 参照生成 (Referencing Generation), 会计科目 (Accounting Subject), and 现金流量项目 (Cash Flow Project). Keyboard shortcuts are shown for the latter two options.]()

图 2.1.3.4.2-3

## Page 49

NC
大型企业管理与电子商务平台

可以通过参照会计科目、现金流量项目生成对应的报表项目

![图 2.1.3.4.2-4: 科目选择弹窗界面，包含科目体系、科目表、科目版本的下拉选择框，以及科目和级次的范围设置框，以及确定和取消按钮。]()

图 2.1.3.4.2-4

选择对应的条件，根据该条件可以将科目编码和名称直接生成为报表项目的编码和报表项目的名称。

* ✓ 注意：现金流量项目没有参照界面，会直接生成报表项目，所生成的报表编码前面会自动追加 CF\_。报表项目名称为现金流量项目名称。
* ✓ 只有通过参照生成的报表项目，会自动设置报表项目与科目（或者现金流量项目）的映射关系。其他两种方法生成的报表项目，不会自动设置映射关系。
* ■ 第三种：导入

通过基础数据功能点击自带的导入功能，可以导入报表项目。

![图 2.1.3.4.2-5: 数据导入界面，顶部显示功能导航和报表项目全局。左侧菜单栏显示导出格式文件、导入、刷新。下方显示所属类别和导入界面的下拉选择框。]()

图 2.1.3.4.2-5

选择所属类别和导入档案

## Page 50

![NC software interface showing Report Template Maintenance interface, including tabs like Export Template Files, Import, Report Template List, and Report Template Content.]()

图 2.1.3.4.2-6

先导出格式文件，然后在 Excel 上维护需要导入的报表项目信息，然后通过导入按钮导入。

**3. 报表项目的管控模式**

* 报表项目-集团只能维护集团级的报表项目不能修改全局级的报表项目
* 报表项目-组织只能维护组织级的报表项目不能修改全局级、集团级的报表项目

**注意：**

* 只有通过参照生成功能生成的报表项目，才会自动设置与会计科目或现金流量项目的映射关系。

### 2.1.3.4.3 映射关系

**1. 预置的映射关系**

* 系统未预置报表项目与企业报表指标的映射关系。

**2. 新增映射关系**

* 报表项目与企业报表指标的映射关系需要在报表表样的格式设计界面中进行映射。

## Page 51

NC
大商企业管理与电子商务平台

常用功能
动态建模平台
XERL
集成平台
应用管理平台
共享服务
企业绩效管理

财务会计
资金管理
管理会计
供应链

* 全面预算
* 企业报表
* 合并报表
* 合并账簿
* 数集方案
* NC-XERL

* 业务属性
* 关键字
* 数据源

资源管理

* 报表样表-全局
* 报表样表-集团
* 报表样表-报表组织
* 任务-全局
* 任务-集团
* 任务-报表组织
* 审核方案-全局
* 审核方案-集团

NC
功能导航
消息中心
报表样表-全局
查询
编制
格式设计
加入到任务
定位
导入导出

| 分类 | 查询 | 报表样表编码 | 报表名称 | 关键字组合 |
| --- | --- | --- | --- | --- |
| 报表样表分类 | 报表样表溯源 | | | |
| 不常用 | 财务样表 | 1 | 01 | 报表样表-全局 |
| 不常用 | 报表样表-集团 | 2 | 02 | 单位 |
| 不常用 | 大数智能测试问题记录 | 3 | KN00101类1 | 合并资产负债表 |
| 性能测试表 |  | 4 | KN00102类1 | 合并利润表 |
| 不常用 |  | 5 | KN00103类1 | 合并利润表附表 |
| 不常用 |  | 6 | KN00104类1 | 合并现金流量表 |
| 不常用 |  | 7 | KN00105类1 | 合并现金流量表(补充资料) |
| 不常用 |  | 8 | KN00106类1 | 合并所有者权益变动表 |
| 不常用 |  | 9 | KN0101类1 | 长期股权投资明细表 |
| 不常用 |  | 10 | KN0102类1 | 内部债权债务明细表 |
| 不常用 |  | 11 | KN0103类1 | 内部债权债务明细表2 |
| 不常用 |  | 12 | KN0104类1 | 内部销售明细表 |
| 不常用 |  | 13 | KN0105类1 | 现金内部往来明细表 |
| 单位:币种:合 | | | | |

图 2.1.3.4-1

如果系统中没有任何报表样表，建议按企业报表产品手册先进行建立，然后在继续进行报表项目映射。

## Page 52

#### 注意

请注意：只有会计期间的报表表样才能进行报表项目映射，例如：会计月、会计季度、会计半年、会计年。

在报表格式设计界面，选择报表项目页签。

![图 2.1.3.4-2: 在报表格式设计界面中，展示了合并资产负债表的格式设置。左侧列出了报表项目列表（如流动资产、固定资产等），右侧显示了合并资产负债表的表格结构，包含资产、负债和所有者权益等项目。]()

**图 2.1.3.4-2**

然后选择“供给映射”页签。

![图 2.1.3.3-1: 在报表格式设计界面中，选择“供给映射”页签，显示了报表项目映射界面。界面包含表样、指标、公式、报表项目和HR取数规则等选项。]()

**图 2.1.3.4-3**

在右侧选择需要映射的报表项目

## Page 53

![Figure 2.1.3.4-3: Screenshot of the NC ERP system showing the 'Consolidated Balance Sheet' report. The report displays consolidated assets, liabilities, and equity items, including the total for 'Consolidated Consolidated Liabilities and Equity'.]()

#### 图 2.1.3.4-3

会展出该报表项目的详细内容

![Figure 2.1.3.4-5: Screenshot of the NC ERP system showing the consolidated balance sheet report detail page (2001-2009). It displays detailed asset, liability, and equity items, including a total of 89 for 'Consolidated Consolidated Liabilities and Equity'.]()

#### 图 2.1.3.4-5

然后点击右上角的关键字映射按钮

## Page 54

![NC logo]()
大型企业管理与电子商务平台

---

图 2.1.3.4-6

设置除了单位、会计期间以外的其他关键字(包含动态区关键字)与财务数据方案维度的映射关系。

![Screenshot of the Key Word Mapping interface (2.1.3.4-6). The table lists Key Words and corresponding Financial Data Scheme Dimensions. The dimension for '会计月' (Accounting Month) is '时间维度' (Time Dimension), and for '单位' (Unit) is '报表组织' (Report Organization).]()

图 2.1.3.4-7

如果找不到对应的维度,则需要在数据方案的增加维度界面进行增加后,才能继续映射。
注意:只有映射完关键字才能继续报表项目与指标的映射工作。否则会报错。

![Warning dialog box (2.1.3.4-8) stating: 必须先进行关键字映射! (Must perform key word mapping first!).]()

图 2.1.3.4-8

关键字映射完成后,继续下一步映射。可以不分先后顺序,需要将报表项目、度量、数据类型还

## Page 55

有其他维度均映射后，才算完成整个映射工作。

下面以报表项目为例，详细说明映射流程：

![Figure 2.1.3-9: A screenshot of a report template titled '合并资产负债表' (Consolidated Balance Sheet). The template includes sections for 资产 (Assets) and 负债 (Liabilities), with columns for 项目 (Item), 报表数据 (Report Data), 行权 (Row Action), and 年初余额 (Opening Balance). The Assets section shows items like 流动资产 (Current Assets) and 非流动资产 (Non-current Assets), and the Liabilities section shows items like 流动负债 (Current Liabilities) and 非流动负债 (Non-current Liabilities). A right-click context menu is open, showing options like '选择映射' (Select Mapping) and '选择报表项目' (Select Report Item), highlighting the mapping process.]()

图 2.1.3-9

选中需要映射的报表项目，拖拉至表样单元格。

注意：系统不支持数据方案中的所有资源映射在指标单元格上。

![Figure 2.1.3-10: A screenshot of the Consolidated Balance Sheet template, showing the Assets section. The right-click context menu is open, displaying options like '选择报表项目' (Select Report Item), '选择映射' (Select Mapping), '选择表样' (Select Template), and '选择单元格' (Select Cell), illustrating the steps for dragging and dropping a report item into a template cell.]()

图 2.1.3-10

可以依次拖拉报表项目，直至完成映射。

另一种方法：也可以选中多个报表项目，然后选中多个表样单元格，再拖拉进行映射。

## Page 56

![Figure 2.1.3.4-3-11: A screenshot of the '合并资产负债表' (Consolidated Balance Sheet) spreadsheet in the NC platform. The table displays asset accounts, their codes, units, opening balances, and closing balances. A note indicates that the formula for the opening balance in cell K9 is =D9. A filter list on the right shows various asset items and their corresponding balances.]()

图 2.1.3.4-3-11

映射之后的效果：

![Figure 2.1.3.4-3-12: A screenshot of the '合并资产负债表' (Consolidated Balance Sheet) spreadsheet after the mapping has been applied. The data is now correctly sorted and displayed according to the specified order in the filter list. The table shows asset accounts, their codes, units, opening balances, and closing balances.]()

图 2.1.3.4-3-12

注意：通过此中方法映射需要保证两者的顺序完全一致，否则会出现映射串行、错位、出错的情况。

如果想通过模糊匹配进行映射，可以先选中需要映射的报表表样区域。

## Page 57

大数企业管理与电子商务平台

![Screenshot of a financial dashboard showing the '合并资产负债表' (Consolidated Balance Sheet). The table displays assets, liabilities, and equity items with '期末余额' (End Balance) and '年初余额' (Beginning Balance) values, alongside icons for data retrieval and formatting.]()

### 合并资产负债表

选择右测数据源的维度的名称,拖拉至左侧选中区域即可

图 2.1.3.4.3-13

## Page 58

### 合并资产负债表

| 项目 | 资产 | 年初余额 | 年初余额 | 年初余额 |
| --- | --- | --- | --- | --- |
| 流动资产 |  |  |  |  |
| 货币资金 | 1 |  |  |  |
| 应收账款 | 2 |  |  |  |
| 预付款项 | 3 |  |  |  |
| 存货 | 4 |  |  |  |
| 待摊费用 | 5 |  |  |  |
| 待处理流动资产 | 6 |  |  |  |
| 一年内到期的非流动资产 | 7 |  |  |  |
| 其他流动资产 | 8 |  |  |  |
| 流动资产合计 | 9 |  |  |  |
| 长期投资 | 10 |  |  |  |
| 长期股权投资 | 11 |  |  |  |
| 长期债权投资 | 12 |  |  |  |
| 其他长期投资 | 13 |  |  |  |
| 长期资产合计 | 14 |  |  |  |
| 固定资产 | 15 |  |  |  |
| 固定资产原价 | 16 |  |  |  |
| 固定资产累计折旧 | 17 |  |  |  |
| 固定资产净值 | 18 |  |  |  |
| 固定资产清理 | 19 |  |  |  |
| 固定资产合计 | 20 |  |  |  |
| 在建工程 | 21 |  |  |  |
| 在建工程减值准备 | 22 |  |  |  |
| 在建工程合计 | 23 |  |  |  |
| 无形资产 | 24 |  |  |  |
| 无形资产减值准备 | 25 |  |  |  |
| 无形资产合计 | 26 |  |  |  |
| 递延资产 | 27 |  |  |  |
| 递延资产减值准备 | 28 |  |  |  |
| 递延资产合计 | 29 |  |  |  |
| 其他长期资产 | 30 |  |  |  |
| 长期资产合计 | 31 |  |  |  |
| 资产合计 | 32 |  |  |  |

![Screenshot of a merged balance sheet (合并资产负债表) in a spreadsheet application, showing columns for items, beginning balance (年初余额), and beginning balance (年初余额).]()

图 2.1.3.4.3-14

模板匹配之后的效果

## Page 59

### NC 大型企业管理与电子商务平台

|  |  |  |  |  |
| --- | --- | --- | --- | --- |
| (03)会01表1)合并资产负债表 |  |  |  |  |
| 采样 | 指标 | 公式 | 报表项目 | IF取数规则 |
| 提取数据映射 |  | 得到数据映射 |  |  |
|  |  |  |  |  |
| 3 | 单位: |  | 报表组织 | 会计月: |
| 6 | 合并资产 |  |  |  |
| 8 | 资产 | 行次 | 期末余额 | 年初余额 |
| 10 | 流动资产 | 1 |  |  |
| 11 | 010101/货币资金 | 2 | 数 | 数 |
| 12 | 010102/结算备付金 | 3 | 数 | 数 |
| 13 | 010103/拆出资金 | 4 | 数 | 数 |
| 14 | 010104/交易性金融资产 | 5 | 数 | 数 |
| 15 | 010105/应收票据 | 6 | 数 | 数 |
| 16 | 010106/应收账款 | 7 | 数 | 数 |
| 17 | 010107/预付款项 | 8 | 数 | 数 |
| 18 | 010108/应收保费 | 9 | 数 | 数 |
| 19 | 010109/应收分保账款 | 10 | 数 | 数 |
| 20 | 010110/应收分保合同准备金 | 11 | 数 | 数 |
| 21 | 010111/应收利息 | 12 | 数 | 数 |
| 22 | 010112/其他应收款 | 13 | 数 | 数 |
| 23 | 010113/买入返售金融资产 | 14 | 数 | 数 |
| 24 | 010114/存货 | 15 | 数 | 数 |
| 25 | 010115/一年内到期的非流动资产 | 16 | 数 | 数 |
| 26 | 010116/其他流动资产 | 17 | 数 | 数 |
| 27 | 流动资产合计 | 18 | 数 | 数 |

图 2.1.3.4.3-15

**注意:**1.匹配的原则是先依据报表项目的编码、再依据报表项目名称的名称,以绝对匹配为最优先。模糊匹配时,以报表样表上的内容⇒报表项目的内容为规则进行匹配。在没有绝对匹配的前提下,模糊匹配时不会考虑模糊匹配的程度,即:同一个报表样表,分别与两个报表项目均可以模糊匹配,系统会自动以第一个模糊匹配结果为准。

2.当报表项目映射在空白报表样表单元格时,会将报表项目名称设置为该单元格的表样内容。参考报表项目的映射流程,可以继续映射数据类型、度量、以及其他维度信息。

## Page 60

![Figure 2.1.3.4.16 shows a screenshot of a software interface, likely an enterprise management and e-commerce platform (NC), displaying a 'Combined Assets and Liabilities Statement'. The interface shows a table with columns for Item, Debit Balance, Credit Balance, and Balance, along with a detailed view of asset and liability items.]()

图 2.1.3.4.16

如果存在多个单元格需要映射同一个成员时,可以通过映射至合并单元格来解决该问题。如上图: D5、E5 均需要映射实际数据类型。可以将 D4 和 E4 单元格合并,然后映射一个“实际”即可。

![Figure 2.1.3.4.17 shows a screenshot of a software interface, likely an enterprise management and e-commerce platform (NC), displaying a 'Combined Assets and Liabilities Statement'. The interface shows a table with columns for Item, Debit Balance, Credit Balance, and Balance, along with a detailed view of asset and liability items.]()

图 2.1.3.4.17

两种映射结果相同。

根据需要,在会计季度、会计半年、会计年报表中,可以映射时间维度,而会计月的报表不允许映射时间维度。(此设计主要为了按年度编制十二个月的预算数据,然后按月度进行取数所用。)

## Page 61

![NC logo]() 大宏企业管理与电子商务平台

![Screenshot of NC financial management software showing the budget report interface (预算指标) and user options (用户选项). The interface displays monthly budget data from January to December for several budget indicators (预算指标1 to 5). The user options panel on the right lists functions like budget adjustment, financial analysis, and report printing.]()

图 2.1.3.4-19

映射后效果:

![Screenshot of the budget report interface showing the results after mapping. The time period is adjusted from 12 months to 1 month for January.]()

图 2.1.3.4-20

也可以在报表表样选择十二个月，然后将时间维度“月”，拖拉至一月处，选择01月进行统一映射。

## Page 62

### 大型企业管理与电子商务平台

![A screenshot of an Excel spreadsheet showing data mapping for multiple metrics (Forecast Index 1 through 6). Columns A and B list the metrics and their calculation formulas. Columns C through N contain the corresponding numerical data. A sidebar lists the metrics and their associated formulas.]()

图 2.1.3.4-21

映射后效果:

单位:

报表组织 会计年: 时间维度 预算数

|  | 01月 | 02月 | 03月 | 04月 | 05月 | 06月 | 07月 | 08月 | 09月 | 10月 | 11月 | 12月 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 预算指标1 | 151 | 151 | 151 | 151 | 151 | 151 | 151 | 151 | 151 | 151 | 151 | 151 |
| 预算指标2 | 151 | 151 | 151 | 151 | 151 | 151 | 151 | 151 | 151 | 151 | 151 | 151 |
| 预算指标3 | 151 | 151 | 151 | 151 | 151 | 151 | 151 | 151 | 151 | 151 | 151 | 151 |
| 预算指标4 | 151 | 151 | 151 | 151 | 151 | 151 | 151 | 151 | 151 | 151 | 151 | 151 |
| 预算指标5 | 151 | 151 | 151 | 151 | 151 | 151 | 151 | 151 | 151 | 151 | 151 | 151 |
| 预算指标6 | 151 | 151 | 151 | 151 | 151 | 151 | 151 | 151 | 151 | 151 | 151 | 151 |

图 2.1.3.4-22

当所有映射均完成后，可以通过生成映射区域按钮，来显示映射是否完整。

全部映射完成，则在指标上会以红色背景显示。

![Buttons for '生成映射区域' (Generate Mapping Area) and '完成' (Complete) are shown.]()

如果

## Page 63

图表：

![图 2.1.3.4.3-23: 资产总账界面。显示流动资产的期末数、实际数、年初数。流动资产合计显示为红色，表示需要补充映射。具体项目包括：货币资金、结算备付金、拆出资金、交易性金融资产、应收票据、应收账款、预付款项、应收保费、应收分保账款、应收分保合同准备金、应收利息、其他应收款、买入返售金融资产、存货、一年内到期的非流动资产、其他流动资产。]()

#### 图 2.1.3.4.3-23

注意：“生成映射区域”按钮不是必须点击。当刷新当前界面时，系统会自动判断是否映射完成。当鼠标指向指标时，会显示映射结果，如果缺少对应资源的映射，会以红色字体提示。

图表：

![图 2.1.3.4.3-24: 资产总账界面，显示全部映射完成的状态。流动资产各项目均显示为绿色，表示映射完成。具体项目包括：货币资金（期末数12，实际数12，年初数12）、结算备付金（期末数12，实际数12，年初数12）、拆出资金（期末数12，实际数12，年初数12）、买入返售金融资产（期末数12，实际数12，年初数12）、其他应收款（期末数12，实际数12，年初数12）。右侧显示负债和所有者权益项目，包括：短期借款、中央银行存放、拆入资金、应付账款。]()

#### 图 2.1.3.4.3-24

全部映射完成的状态。

## Page 64

图 2.1.3.4.3-25

| 资产 | 行次 | 期末数, 实际 | 年初数 | 负债和所有者权益 (或股东权益) | |
| --- | --- | --- | --- | --- | --- |
| 流动资产 | 1 | — | — | 流动负债 | |
| 01010101/货币资金 | 2 |  |  |  |  |
| 01010102/结算备付金 | 3 |  |  |  |  |
| 01010103/拆出资金 | 4 |  |  |  |  |
| 01010104/交易性金融资产 | 5 |  |  |  |  |
| 01010105/应收票据 | 6 |  |  |  |  |
| 01010106/应收账款 | 7 |  |  |  |  |
| 01010107/预付款项 | 8 |  |  |  |  |
| 01010108/应收保费 | 9 |  |  |  |  |
| 01010109/应收分保账款 | 10 |  |  |  |  |
| 01010110/应收分保合同准备金 | 11 |  |  |  |  |
| 01010111/应收利息 | 12 |  |  |  |  |
| 01010112/其他应收款 | 13 |  |  |  |  |
| 01010113/买入返售金融资产 | 14 |  |  |  |  |
| 01010114/存货 | 15 |  |  |  |  |
| 01010115/一年内到期的非流动资产 | 16 |  |  |  |  |
| 01010116/其他流动资产 | 17 |  |  |  |  |
|  | | | | 非流动负债 | |
|  | | | |  | 营业税金及附加 |
|  | | | |  | 销售费用 |
|  | | | |  | 管理费用 |
|  | | | |  | 财务费用 |
|  | | | |  | 资产减值损失 |
|  | | | |  | 公允价值变动收益 |
|  | | | |  | 投资收益 |
|  | | | |  | 营业利润 |
|  | | | |  | 营业外收入 |
|  | | | |  | 营业外支出 |
|  | | | |  | 利润总额 |
|  | | | |  | 所得税费用 |
|  | | | |  | 净利润 |
|  | | | |  | 持续经营净利润 |
|  | | | |  | 终止经营净利润 |
|  | | | |  | 综合收益总额 |

如果缺少对应的映射资源，系统会以红色字体提示。当所有需要映射的数据方案资源，已经全部映射后，完成映射关系的设置。

当进行映射后，系统默认显示映射之后的状态，如果想查看报表表样的原始状态，可以通过“显示表样/映射”按钮来切换显示。

图 2.1.3.4.3-26

| 资产 | 行次 | 期末数, 实际 |
| --- | --- | --- |
| 流动资产 | 1 | — |
| 01010101/货币资金 | 2 |  |
| 01010102/结算备付金 | 3 |  |
| 01010103/拆出资金 | 4 |  |
| 01010104/交易性金融资产 | 5 |  |
| 01010105/应收票据 | 6 |  |
| 01010106/应收账款 | 7 |  |
| 01010107/预付款项 | 8 |  |
| 01010108/应收保费 | 9 |  |
| 01010109/应收分保账款 | 10 |  |
| 01010110/应收分保合同准备金 | 11 |  |
| 01010111/应收利息 | 12 |  |
| 01010112/其他应收款 | 13 |  |
| 01010113/买入返售金融资产 | 14 |  |
| 01010114/存货 | 15 |  |
| 01010115/一年内到期的非流动资产 | 16 |  |
| 01010116/其他流动资产 | 17 |  |

| 资产 | 行次 | 期末金额 |
| --- | --- | --- |
| 流动资产 | 1 |  |
| 货币资金 | 2 |  |
| 结算备付金 | 3 |  |
| 拆出资金 | 4 |  |
| 交易性金融资产 | 5 |  |
| 应收票据 | 6 |  |
| 应收账款 | 7 |  |
| 预付款项 | 8 |  |
| 应收保费 | 9 |  |
| 应收分保账款 | 10 |  |
| 应收分保合同准备金 | 11 |  |
| 应收利息 | 12 |  |
| 其他应收款 | 13 |  |
| 买入返售金融资产 | 14 |  |
| 存货 | 15 |  |
| 一年内到期的非流动资产 | 16 |  |
| 其他流动资产 | 17 |  |

在一些特殊的地方，当需要将提取映射的映射关系，复制到供给映射中。为了减免重复工作量，系统只在供给映射时，提供复制按钮 ![复制按钮图标]()。作用是将提取数据映射的关系，复制到供给映射中。

## Page 65

**注意：**

* 报表表样提供数据给数据方案时，必须在“供给数据映射”中设置才能使用。
* 同一张报表支持给不同的数据方案设置映射。
* 不能映射在报表指标处。

## 2.1.3.4.4 数据类型管理

### 1. 新建数据类型

* 如果需要在同一个数据方案中，仅想查看企业报表一个模块的数据，则可以跳过此步骤。
* 如果需要在同一个数据方案中，同时查询企业报表和合并报表的数据，则需要增加数据类型。

功能导航：消息中心 职易类型管理

| 新增 | 修改 | 删除 | 刷新 |
| --- | --- | --- | --- |
| 编码 | 名称 | 预算 | 备注 |
| --- | --- | --- | --- |
| 1 | PLAN | 计划 | ☑ |  |
| 2 | FACT | 实际 | ☑ |  |

## Page 66

![图 2.1.3.4-1: 财务数据方案界面截图。界面显示一个表格，包含编号、名称、预置、备注等列。编号1对应名称PLAN，预置已勾选。编号2对应名称FACT，备注为实际，预置已勾选。编号3对应名称QYBB，备注为实际_个别，预置未勾选。编号4对应名称HBBB，备注为实际_合并，预置未勾选。界面顶部有导航栏和功能按钮。]()

图 2.1.3.4-1

## 2.1.3.4.5 财务数据方案

### 1. 新建财务数据方案

在报表项目以及映射关系均完成后，可以建立数据方案。

![图 2.1.3.4-5: 新建财务数据方案界面截图。界面显示一个表格，包含方案名称、科目、分组、方案内容、启用状态等列。方案名称包括QYBB_资产及负债、QYBB_流动资产等，均已启用。启用状态列显示了启用项目名称和会计期间方案。]()

图 2.1.3.4-5

首次建立数据方案时，需要先建立分类。同一级次下分类的名称禁止重复。

## Page 67

**NC**

大型企业管理与电子商务平台

![Screenshot of a dialog box titled '新增方案分类' (New Scheme Classification). Fields for '名称' (Name), '上级分类' (Superior Classification), '描述' (Description), and '审计信息' (Audit Information) are visible. Buttons '确定' (Confirm) and '取消' (Cancel) are present.]()

图 2.13.4.5-2

然后点新增按钮，建立报表项目

![Screenshot of a '方案管理' (Scheme Management) screen. It shows a list of items with columns for '方案编码' (Scheme Code), '名称' (Name), '维度体系' (Dimensional System), '报表项目体系' (Report Item System), and '会计期间方案' (Accounting Period Scheme). A large input area is available below the list.]()

图 2.13.4.5-3

根据需要输入方案编码、名称、报表项目体系、会计期间方案等信息。
然后依次选择该方案所包含的维度、度量、数据来源信息。

## Page 68

![Figure 2-1-3-4-5: Dimension Setting Interface. A dialog box titled '维度设置' (Dimension Setting) shows four buttons labeled '选择' (Select), '设置' (Set), '设置成员' (Set Member), and '属性' (Attribute). Below these is a list of items: 1. 指定角色 (Specify Role), 2. 组织机构 (Organization Structure), 3. 财务项目 (Financial Project), 4. 时间维度 (Time Dimension), all checked.]()

图 2-1-3-4-5

维度页签下，四个按钮的作用分别为选择维度、设置自定义维度成员范围、维度属性与规定属性的关联设置、分析维度设置。

![Figure 2-1-3-4-5: Dimension Selection Dialog Box. A dialog titled '选择维度' (Select Dimension). Left panel (待选维度) lists '可选维度' (Available Dimensions) items: 1. 公共档案, 2. 基础档案, 3. 自定义档案, 4. 基础资产, 5. 使用情况, 6. 增减方式, 7. 资产类别, 8. 财政, 9. 总账. Right panel (已选维度) shows selected dimensions: 1. 可选维度 (Available Dimensions), 2. 数量维度, 3. 组织机构, 4. 财务项目, 5. 时间维度. Navigation arrows are provided below the lists.]()

图 2-1-3-4-5

维度选择时提供四个默认维度，默认维度不可删除。

待选维度是由所有的自定义档案、各业务模块预置的特有维度档案以及一部分公共档案构成。

这部分公共档案来自于动态建模平台->基础数据->会计辅助核算项目功能节点的数据对象，去重之后的结果。

## Page 69

大型企业管理与电子商务平台

功能导航 信息中心 核心关系业务 财务报表类图 报表开发方案 会员 管理分析

| 编号 | 数据名称 | 数据对象 | 数据类型 | 输入长度 | 精度 | 创建人 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 0001 | 部门 | 部门 |  |  |  |
| 2 | 0002 | 人员档案 | 人员基本属性 |  |  |  |
| 3 | 0003 | 地区分类 | 地区分类 |  |  |  |
| 4 | 0004 | 客服 | 客服 |  |  |  |
| 5 | 0005 | 内部密级 | 密级 |  |  |  |
| 6 | 0006 | 物料基本信息 | 物料基本信息 |  |  |  |
| 7 | 0007 | 现金流量项目 | 现金流量项目 |  |  |  |
| 8 | 0008 | 收支项目 | 收支项目 |  |  |  |
| 9 | 0009 | 资金计划项目 | 资金计划项目 |  |  |  |
| 10 | 0010 | 项目 | 项目 |  |  |  |
| 11 | 0011 | 银行账户 | 银行账户 |  |  |  |
| 12 | 0012 | 物料基本分类 | 物料基本分类 |  |  |  |
| 13 | 0013 | 结算方式 | 结算方式 |  |  |  |
| 14 | 0014 | 仓库档案 | 仓库 |  |  |  |
| 15 | 0015 | 运输方式 | 运输方式 |  |  |  |
| 16 | 0016 | 客户基本分类 | 客户基本分类 |  |  |  |
| 17 | 0017 | 客户档案 | 客户基本分类 |  |  |  |
| 18 | 0018 | 供应商基本分类 | 供应商基本分类 |  |  |  |
| 19 | 0019 | 供应商档案 | 供应商基本信息 |  |  |  |
| 20 | 0020 | 产品档案 | 产品线 |  |  |  |
| 21 | 0021 | 地点档案 | 地点档案 |  |  |  |
| 22 | 0022 | 银行类别 | 银行类别 |  |  |  |
| 23 | 0023 | 银行档案 | 银行档案 |  |  |  |
| 24 | 0024 | 现金账户 | 现金账户 |  |  |  |
| 25 | 0025 | 业务单元 | 组织 |  |  |  |
| 26 | 0026 | 财务组织 | 组织-业务单元 |  |  |  |

图2.1.3.4.5-6

当某些自定义档案成员过多,害怕会影响到取数效率,可以通过设置其成员范围来提升效率。

68 图2.1.3.4.5-7

## Page 70

![图 2.1.3.4.5-7: 截图显示了NC大型企业管理与电子商务平台的界面。左侧是分析维度设置面板，包含多个列表和复选框。右侧是数据源面板，显示了数据表结构。红色箭头指示了设置过程。]()

图 2.1.3.4.5-7

当某些维度档案需要与组织进行关联时，可以通过维度属性关联设置进行关联。

![图 2.1.3.4.5-8: 截图显示了NC大型企业管理与电子商务平台的分析维度设置界面。左侧是维度属性面板，右侧是维度属性关联设置面板。红色箭头指示了设置过程。]()

图 2.1.3.4.5-8

最后一个分析维度设置，是使该数据方案用于企业报表模块下的多维数据分析功能所用，满足其分析特定字段的要求。

![截图显示了NC大型企业管理与电子商务平台的分析维度设置界面。左侧是维度属性面板，右侧是维度属性关联设置面板。红色箭头指示了设置过程。]()

## Page 71

![Figure 2.1.3.4-5-9: A screenshot of an enterprise management software interface. The main menu on the left lists sections like 全面预算 (Comprehensive Budgeting), 企业预算 (Enterprise Budget), 开发预算 (Development Budget), 开发预算 (Development Budget), 预算方案 (Budget Plan), and NC-XBRL. The main content area shows various management modules categorized under 业务管理 (Business Management) and 外部接口 (External Interface). The 业务管理 section includes modules such as 预算管理, 业务管理, 数据中心, 系统监控, 敏感分析, and 多维预算分析. The 业务管理 section has a red box highlighting 多维预算分析 (Multi-dimensional Budget Analysis).]()

**图 2.1.3.4-5-9**

维度设置完成后，需要选择度量。

![Figure 2.1.3.4-5-10: A screenshot of a dimension settings interface. The left panel shows a list of dimensions. The right panel shows a detailed view where dimensions are selected (indicated by red arrows pointing to dimensions 3, 4, and 5) before proceeding to the next step. This ensures that at least one dimension is selected, as the system does not support adding a new dimension if none is selected.]()

**图 2.1.3.4-5-10**

度量至少选择一个，待选度量不支持前台认为新增。

## Page 72

大型企业管理与电子商务平台

NC

度量设置完成后，需要设置数据来源。

![Figure 2.1.3.4.5-11: A screenshot showing data source settings. The interface includes fields for data type, name, and value, with a button labeled '增加(+)'. The data source type is set to '账簿科目' (Ledger Subject). The data source is empty.]()

图 2.1.3.4.5-11

第一次进入数据来源时，为空白。点击新增后系统会自动带出计划-预算：实际-总账两个来源。可以根据需要添加或者删除数据来源。

![Figure 2.1.3.4.5-12: A screenshot showing data source settings after adding a new source. The interface displays two sources: '计划-预算' (Plan-Budget) and '实际-总账' (Actual-General Ledger). The '实际-总账' source is highlighted, indicating it was added.]()

图 2.1.3.4.5-12

如果只预览企业报表数据，可以先将数据来源改为企业报表，然后双击取数规则进行设置，在弹出界面设置预算取数规则。

![Figure 2.1.3.4.5-12: A screenshot showing data source settings. The interface includes a table with columns for 维度 (Dimension), 度量 (Measure), 数据类型 (Data Type), 数据来源 (Data Source), and 取数规则 (Data Retrieval Rule). The data source type is set to '账簿科目' (Ledger Subject). The data source is empty.]()

图 2.1.3.4.5-12

## Page 73

![Screenshot of the 'Business Intelligence Reporting System' interface. The top menu bar shows 'NC' and '大型企业管理与电子商务平台'. The window title is '业务报表数据规划'. The content area is titled '报表组织体系' (Report Organization System) and shows two panels: '待选报表' (Pending Reports) and '已选报表' (Selected Reports). Between the panels are navigation buttons (> < >> <<). The '待选报表' panel contains a list item: '报表表样' (Report Template). Below the screenshot, there is a caption: '图 2.1.3.4.5-14 首先选择报表组织体系, 然后选择报表和组织。' (Figure 2.1.3.4.5-14 First select the report organization system, then select the report and organization.).]()

**图 2.1.3.4.5-14**

首先选择报表组织体系，然后选择报表和组织。

## Page 74

## 企业报表取数规则

| 报表组织体系 | 报表测试体系 |
| --- | --- |
| 报表选择请选择 报表样式   * 公司报表样式 * 报表自建测试 * 不用的 * 财务报表 * 大数据智能测试问题记录 * 性能测试表 | 组织选择 已选报表  0248 01表1企业资产负债表  ▶  ▶▶  ▶▶▶  ▶▶▶▶ |

确定 (D) 取消 (C)

## Page 75

![A screenshot of a software interface titled '企业报表取数规则' (Corporate Report Data Extraction Rules). The interface displays a list of reports grouped under '报表测试库' (Report Test Library) and '组合选择' (Combination Selection). Users can select reports using checkboxes, and the '已选组织' (Selected Organization) panel shows details like '集团1883' (Group 1883) and '集团787' (Group 787). There is a button labeled '确定 (OK)' and '取消 (Cancel)' at the bottom right.]()

图 2.1.3-4-5

注意: 请确认已选择的报表必须设置了隶属关系, 否则无法选取正确的结果。

如果需要同时预览企业报表、合并报表的数据, 可以在数据类型管理中增加对应数据类型的前提下, 建立对应取数规则, 分别设置即可。

![A screenshot showing a table interface for data extraction rules. The table has columns: 维度 (Dimensions), 度量 (Metrics), 数据来源 (Data Source), 数据来源 (Data Source), and 取数规则 (Data Extraction Rule). The table shows two dimensions and two metrics. For metric '合计' (Total) of dimension '实际_个制' (Actual_Individual), the data source is '报表取数' (Report Data Extraction) and the rule is '已选择了11条取数和2个报表组织' (11 extraction rules selected and 2 report organizations selected). For metric '合计' (Total) of dimension '实际_合并' (Actual_Merge), the data source is '合并报表' (Consolidated Report) and the rule is '已选择了合并方案: 001部分个体' (Consolidation scheme selected: 001 Partial Individual).]()

图 2.1.3-4-6

合并报表的取数规则界面如下:

## Page 76

![Figure 2.1.3.4.5-17: A screenshot of the NC (New Century) software interface showing a window titled '合并拆销账务规则' (Merge/Cancel Journal Entry Rules). It displays a list of journal entries under '待选组织' (Pending Organization) and '已选组织' (Selected Organization). The pending list shows 0001 (初始账本) and 01 精品一 (selected). The selected list shows 01 精品一, 1101 元流, 1111-01 精光01, hy01 新旧计算, and ZZ ZZ. There are buttons for moving entries between lists and options for '包含所有下级' (Include all subordinates), '仅自己' (Only self), and '仅直接下级' (Only direct subordinates).]()

图 2.1.3.4.5-17

选择合并方案、合并体系版本后，选择对应的组织即可。

## 2. 财务数据方案预览

▷ 建立数据方案完成后可以通过数据预览查看该数据方案数据。

![Figure 2.1.3.4.5-18: A screenshot of the NC (New Century) software interface showing the '财务数据方案预览' (Financial Data Plan Preview) screen. The menu path '财务中心 - 财务数据方案 - 预览' is highlighted. The preview area shows details for 方案编码 0002 (Scheme Code 0002) with associated 会计期间方案 and 业务会计期间方案 (Accounting Period Scheme and Business Accounting Period Scheme). Other tabs like '概览', '指标', '结构', '数据', '复制', '编辑', '过账', '批量修改', '启用', '分析设计', and '重分类规则' are visible.]()

图 2.1.3.4.5-18

▷ 数据预览。

## Page 77

![Figure 2.1.3.4-5-19: A screenshot of a data query interface (likely NC system). The interface shows a grid with columns for 项目名称, 项目编号, and other fields. A side panel lists 查询条件 (Query Conditions), including various project categories and status filters. The interface is titled '数据查询' (Data Query).]()

图 2.1.3.4-5-19

选择需要查询的成员，然后点击查询，如果有数据时，就可以查询。否则会显示无数据。

如果没有数据，请检查映射关系是否设置正确，以及系统是否存在对应的数据。

系统提供数据查至原始报表的功能。

同时预览企业报表与合并报表数据的界面：

![Figure 2.1.3.4-5-20: A screenshot of the data query interface (likely NC system) showing the results of a query. The grid displays rows of data with numerical values under columns like 项目编号 and 项目名称. A side panel shows 查询条件 (Query Conditions) and the results of the query. The interface is titled '数据查询' (Data Query).]()

图 2.1.3.4-5-20

## Page 78

![NC logo]()

大型企业管理与电子商务平台
用友网络科技股份有限公司

如果需要同时预览，可以拖拉选中实际\_个别、实际\_合并两个数据类型。

如果无数据，请检查映射关系是否设置正确，以及报表系统是否存在对应的数据。

**注意：**

* 同一个数据类型、不同数据来源下，取数规则中的组织不允许重复。
* 数据方案中组织选择不能为空。
* 数据方案中度量选择不能为空。

## 2.2 报表数据分析

### 2.2.1 报表数据分析

#### 2.2.1.1 业务描述

* 系统提供针对部分数据方案的多维分析功能。
* 数据方案中如果是由企业报表、合并报表作为取数规则，则支持多维分析，可以通过企业绩效管理下企业报表模块中的多维数据分析功能点进行分析。

## Page 79

![图 2.2.1.2-1 数据方案多维分析流程图。流程从一个起始圆圈开始，依次经过以下步骤：新建报表项目体系或使用现有体系；新建报表项目或使用现有项目；设置报表项目与企业报表指标的映射关系；新建数据方案；多维数据分析，最后到达一个结束圆圈。]()

图 2.2.1.2-1 数据方案多维分析

## Page 80

## 2.2.1.3 功能清单

| 领域 | 产品模块 | 功能节点 |
| --- | --- | --- |
| 企业绩效管理 | 数据方案 | 报表组织体系 |
| 报表项目-全局/集团/组织 |
| 映射关系-全局/集团/组织 |
| 企业报表 | 财务数据方案-全局/集团/组织 |
| 数据类型管理 |
| 报表表样-全局/集团/组织 |
|  |  | 多维数据分析 |

## 2.2.1.4 产品解决方案

### 2.2.1.4.1 多维数据分析

![Screenshot of the NC enterprise management platform interface showing the '多维数据分析' (Multi-dimensional Data Analysis) module highlighted in the navigation menu and its detailed content area.]()

## Page 81

![Figure 2.2.1.4-1: A screenshot of the NC system interface showing the '多维数据集分析' (Multidimensional Dataset Analysis) section. The left navigation bar shows '功能导航' (Function Navigation), '消息中心' (Message Center), '财务数据方案' (Financial Data Plan), and '数据类型管理' (Data Type Management). The main content area displays '报表主组织' (Report Main Organization) with the value '0001'. The right side shows a table with columns '报表编码' (Report Code), '报表名称' (Report Name), and '报表分类' (Report Category). A menu on the left is open, showing options like '新增' (Add New), '修改' (Modify), '删除' (Delete), '分析' (Analysis), and '发布节点' (Publish Node). A submenu '报表分类' (Report Category) is highlighted, indicating the need to create a classification before setting up the report.]()

图 2.2.1.4-1

首次进入时，在选择报表主组织前需要先建立分类，然后才能建立多维数据分析表。

![Figure 2.2.1.4-2: A screenshot of the NC system interface showing the report creation form for the Multidimensional Dataset Analysis section. Fields include '报表编码' (Report Code), '报表名称' (Report Name), and '报表分类' (Report Category), all pre-filled with asterisks, indicating they are required fields. Below these fields is a large text box for '说明' (Description).]()

图 2.2.1.4-2

点击新增按钮，录入报表编码、报表名称，编码的唯一规则为全局唯一。

## Page 82

![NC Enterprise Management and E-Business Platform logo]()

功能导航 消息中心 多维数据分析

新增 修改 删除 分析 发布节点

报表编码 a 报表名称

说明

返回

图 2.2.1.4.1-3

点击分析进入分析设计界面

报表数据分析 - a

文件(F) 编辑(E) 视图(V) 格式(M) 透视表 下 分析 工具


将维度或字段拖拽

当前选择条件


清空 查询

1 A


创建简单透视区域

创建透视区域

基础数据透视表

钻取

添加小计

添加公式

分割显示

添加空行

添加空列

关联上下文

参数管理

天量管理

数看设计

有限公司

图 2.2.1.4.1-4

系统预置了快速通过数据方案，生成多维数据分析表的功能。选择透视表->创建简单透视区域功能即可按流程创建出一个多维数据分析表。


## Page 83

### 分析设置

财务数据方案 0001

报表样式

|  |  |  |
| --- | --- | --- |
| 报表组织 | 报表项目 | 期间 |

|  |  |  |
| --- | --- | --- |
| 报表组织 | 期间 | 报表项目 |

|  |  |  |
| --- | --- | --- |
| 报表项目 | 报表组织 | 期间 |

|  |  |  |
| --- | --- | --- |
| 报表项目 | 期间 | 报表组织 |

|  |  |  |
| --- | --- | --- |
| 期间 | 报表项目 | 报表组织 |

|  |  |  |
| --- | --- | --- |
| 期间 | 报表组织 | 报表项目 |

度量

 期初数
 期末数
 年初数
 发生数

度量高级选项

 同比增长值
 同比增长率
 环比增长值
 环比增长率

## Page 84

点更新按钮即可生成对应的分析表。

![图 22:1.4-6: 企业采购成本明细表分析报告界面截图。界面显示了一个数据表格（企业采购成本明细表分析报告），左侧有“分析”和“更新”按钮，右侧有分类选项和“更新”按钮。]()

图 22:1.4-6

## Page 85

![Screenshot of a financial report analysis software interface (NC). The main screen shows a grid of financial data (rows 1-28) and a side panel detailing selected data ranges (E2 to E28) and related financial metrics (如 营业利润, 固定资产, 应收账款) with corresponding charts.]()

#### 图 22.1.4-7

此界面的功能大多数均与商业分析模块下多维分析表的功能相同。

**注意:**

* 多维数据分析表仅支持报表数据作为数据来源的财务数据方案。不支持总账、预算、固定资产、57总账和57应收应付等其他业务模块作为数据来源的财务数据方案。
* 创建简单透视区域功能只允许点击一次。一旦生成了透视区域设置功能,则在同一透视区域下禁止再次点击。
* 可以不通过“创建简单透视区域”功能,而直接通过“创建透视区域”新建分析表。

## Page 86

### 2.3 V65 业务数据提取

#### 2.3.1 V65 业务数据提取

##### 2.3.1.1 业务描述

➤ 系统提供针对部分 V65 业务数据提取至企业报表中的功能。

➤ 当数据方案通过预览可以查看数据时, 此数据就可以通过设置映射关系, 然后通过企业报表的计算功能, 提取至企业报表中。

##### 2.3.1.2 业务流程

![流程图：数据方案数据提取。流程从开始符号开始，连接到第一个处理框：新建数据方案流程。随后，流程连接到第二个处理框：设置数据方案与报表表样的映射关系。接着，流程连接到第三个处理框：进行数据计算。最后，流程终止于终止符号。]()
## Page 87

#### 2.3.1.3 功能清单

| 领域 | 产品模块 | 功能节点 |
| --- | --- | --- |
| 企业绩效管理 | 数据方案 | 报表组织体系 |
| 报表项目-全局/集团/组织 |
| 映射关系-全局/集团/组织 |
| 财务数据方案-全局/集团/组织 |
|  | 数据类型管理 |  |
| 企业报表 | 报表表样-全局/集团/组织 |  |
| 多维数据分析 |  |
| 报表数据中心 |  |

#### 2.3.1.4 产品解决方案

##### 2.3.1.4.1 准备工作

依据2.1业务数据查询章节所写流程,首先保障数据方案可以预览出需要的数据,然后才能进行下一步设置。

##### 2.3.1.4.2 数据方案映射工作

* 在报表表样的格式设计界面下,进行映射数据方案工作。
* 系统未预置报表项目与企业报表指标的映射关系。
* 需要在报表项目页签下,选择提取数据映射页签进行映射。

## Page 88

**NC**

• 客户功能
• 动态建模平台
• XBRL
• 集成平台
• 应用管理平台
• 共享服务

**企业绩效管理**

• 财务会计
• 资金管理
• 管理会计
• 供应链

• 全面预算
• 企业报表
• 合并报表
• 合并账簿
• 数量方案
• NC-XBRL

• 业务属性
• 关键字
• 数据源
**资源管理**
• 报表表样-全局
• 报表表样-集团
• 报表表样-报单组织
• 任务-全局
• 任务-集团
• 任务-报单组织
• 审核方案-全局
• 审核方案-集团

图 2.3.1.4-2-1

**NC**

功能导航 消息中心 报表表样-全局

| 新增 | 修改 | 删除 | 锁定 | 查询 | 取数 | 格式设计 | 加入到任务 | 导出 | 导入导出 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 分类 | | 报表表样编辑 | | | | | | | 关键字组合 |
| 查询 | | 报表名称 | | | | | | | 单位/币种:合... |
|  | | test01 | | | | | | | 单位/币种:合... |
|  | | test02 | | | | | | | 单位/币种:合... |
|  | | 单位 | | | | | | | 单位/币种:合... |
| 报表表样分类 | | 打开资产负债表 | | | | | | | 单位/币种:合... |
| • 报表自排测试 | |  | | | | | | | 单位/币种:合... |
| • 不用的 | | 合并利润表 | | | | | | | 单位/币种:合... |
| • 财务报表 | | 合并利润表附表 | | | | | | | 单位/币种:合... |
| • 大家要性能测试问题记录 | | 合并现金流量表 | | | | | | | 单位/币种:合... |
| • 性能测试表 | | 合并现金流量表(补充资料) | | | | | | | 单位/币种:合... |
|  | | 合并所有者权益变动表 | | | | | | | 单位/币种:合... |
|  | | 长期股权投资明细表 | | | | | | | 单位/币种:合... |
|  | | 内部债权债务明细表2 | | | | | | | 单位/币种:合... |
|  | | 内部销售明细表 | | | | | | | 单位/币种:合... |
|  | | 现金内部往来明细表 | | | | | | | 单位/币种:合... |

## Page 89


请注意: 只有会计期间的报表表样才能进行报表项目映射。例如: 会计月、会计季度、会计半年、会计年。

![图 2.3.1.4-2-2: 企业资源计划 (ERP) 系统中的合并资产负债表 (Consolidated Balance Sheet) 界面。该界面显示了多个会计科目及其对应的金额，包括资产和负债项目，并标注了合并科目、科目映射、科目余额和科目类型。界面底部显示了该表在报表模板中的位置 (32)。]()

### 图 2.3.1.4.2-2

请注意: 只有会计期间的报表表样才能进行报表项目映射。例如: 会计月、会计季度、会计半年、会计年。

![图 2.3.1.4.2-3: 企业资源计划 (ERP) 系统中的固定资产卡片表 (Fixed Assets Card Table) 界面。该界面显示了固定资产的详细信息，如部门、类别、资产名称、资产编号、原始价值、累计折旧、净值等。界面右上角显示了数据表的结构信息。]()

### 图 2.3.1.4.2-3

选择数据表方案后, 需要进行关键字映射。

## Page 90

![Figure 2.3.1.4.2-4: A screenshot of a financial reporting interface showing a list of dimensions: 0001, 所有指标 (All Indicators), 数据类型 (Data Type), 报表项目 (Report Item), 时间维度 (Time Dimension).]()

**图 2.3.1.4.2-4**

➤ 设置除了单位、会计期间以外的其他关键字 (包含动态区关键字) 与财务数据方案维度的映射关系。

![Figure 2.3.1.4.2-5: A screenshot of a 'Liabilities Statement' (资产负债表) interface. An overlay titled '关键字映射' (Key Mapping) shows mappings between keywords (会计月, 单位), 财务数据方案维度 (Financial Data Plan Dimensions, 时间维度, 报表组织), and 维度条件 (Dimension Conditions, empty cells). A red arrow points to the dimension condition cell for the keyword '会计月' (Accounting Month). A side panel lists available dimensions for mapping, including 报表项目 (Report Item) and specific liability items like 011资产负债表项目 (011 Balance Sheet Items), 02利润表项目 (02 Profit and Loss Items), and 03现金流量表项目 (03 Cash Flow Statement Items).]()

**图 2.3.1.4.2-5**

## Page 91

如果找不到对应的维度，则需要在数据方案的增加维度界面进行增加后，才能继续映射。

注意：只有映射完关键字才能继续报表项目与指标的映射工作，否则会报错。

![Screenshot of a dialog box titled '警告' (Warning), showing a green checkmark and the message '必须先进行关键字映射!' (Must perform keyword mapping first!).]()

图 23142-6

关键字映射完成后，继续下一步映射。可以不分先后顺序，需要将报表项目、度量、数据类型还有其他维度均映射后，才算完成整个映射工作。

以下内容与查询报表数据章节中的新增映射关系流程相同，仅在选择“提取数据映射”页签有所差别。

下面以报表项目为例，详细说明映射流程：

![Screenshot of an Excel spreadsheet titled '合并资产负债表' (Consolidated Balance Sheet). The left side shows data entry (Data Source) and the right side shows the data view (Data View) with calculated metrics like '总资产' (Total Assets) and '总负债和所有者权益' (Total Liabilities and Equity).]()

图 23142-7

## Page 92

![NC Logo]()

大型企业管理与电子商务平台

![Sinochem Logo]()

![Sinochem Logo]()

![Sinochem Logo]()

![Sinochem Logo]()

1) 选中需要映射的报表项目，拖拉至表样单元格。

注意：系统不支持数据方案中的所有资源映射在指标单元格上。

![图 2.3.1.4-2-8：显示了合并资产负债表的截图，其中部分资产项目（如流动资产、应收账款、预付账款等）被红色框选，准备进行映射操作。右侧显示了映射的指标项目列表，如0121110101流动资产合计。]()

图 2.3.1.4-2-8

2) 可以依次拖拉报表项目，直至完成映射。

另一种方法，也可以选中多个报表项目，然后选中多个表样单元格，再拖拉进行映射。

![图 2.3.1.4-2-9：显示了合并资产负债表的截图，其中所有资产项目（第1至第11行）都被选中并映射到了表样单元格。右侧显示了映射的指标项目列表。]()

图 2.3.1.4-2-9

映射之后的效果：

![图 2.3.1.4-2-10：显示了合并资产负债表映射完成后的效果。左侧是资产部分，右侧是资产负债表的指标项目列表，显示了所有资产项目的映射关系。]()

图 2.3.1.4-2-10

![A large Sinochem watermark covering the right side of the page content.]()

第 91 页

## Page 93

## 案例：合并资产负债表

**注意：**通过此中方法映射需要保证两者的顺序完全一致。否则会出现映射串行、错位、出错的情况。

1. 如果想通过模版匹配进行映射，可以先选中需要映射的报表表样区域。

![Screenshot of a merged balance sheet template. Row 1 is header. Row 2 contains tabs: 公式, 提取项目, 和 数据透视。 Row 3: 提取对应映射, 提取数据映射. Data starts from Row 4. The template includes fields for 会计年度, 单位, and 合并资产负债表 (Merged Balance Sheet). Columns A, B, C, D, E, F are visible, with B and C containing data, and D, E, F containing formulas or merged cells.]()

**合并资产负债表** (Merged Balance Sheet)

| 单位: | 报表组织 | 会计年度: | | | | |
| --- | --- | --- | --- | --- | --- | --- |
| 资产 | 行次 | 期末余额 | 年初余额 | | | 负债和所有者权益(或股东) |
| 非流动资产 | 1 | --- | --- |  |  |  | 流动负债 |
| 5 | 流动资产 | 1 | --- | --- |  | 短期借款 |
| 6 | 货币资金 | 3 | 120,000 | 80,000 | 100,000 | 向中央银行借款 |
| 7 | 结算备付金 | 3 | 120,000 | 80,000 | 100,000 | 吸收存款及同业存放 |
| 8 | 拆出资金 | 4 | 120,000 | 80,000 | 100,000 | 拆入资金 |
| 9 | 交易性金融资产 | 5 | 120,000 | 80,000 | 100,000 | 卖出回购金融资产款 |
| 10 | 应收票据 | 6 | 120,000 | 80,000 | 100,000 | 应付票据 |
| 11 | 应收账款 | 7 | 120,000 | 80,000 | 100,000 | 应付账款 |
| 12 | 预付款项 | 8 | 120,000 | 80,000 | 100,000 | 预收款项 |
| 13 | 应收保费 | 9 | 120,000 | 80,000 | 100,000 | 应付手续费及佣金 |
| 14 | 应收分保账款 | 10 | 120,000 | 80,000 | 100,000 | 应付职工薪酬 |
| 15 | 应收分保合同准备金 | 11 | 120,000 | 80,000 | 100,000 | 应交税费 |
| 16 | 应收利息 | 12 | 120,000 | 80,000 | 100,000 | 应付利息 |
| 17 | 其他应收款 | 13 | 120,000 | 80,000 | 100,000 | 其他应付款 |
| 18 | 买入返售金融资产 | 14 | 120,000 | 80,000 | 100,000 | 应付分保账款 |
| 19 | 存货 | 15 | 120,000 | 80,000 | 100,000 | 保单质押借款 |
| 20 | 一年内到期的非流动资产 | 16 | 120,000 | 80,000 | 100,000 | 待摊费用 |
| 21 | 其他流动资产 | 17 | 120,000 | 80,000 | 100,000 | 待处理财产损溢 |
| 22 | 流动资产合计 | 18 | 1,200,000 | 800,000 | 1,000,000 | 代理承销证券款 |
| 23 | 非流动资产 | 19 | --- | --- | --- | 代理买卖证券款 |

**图 2.3.1.4.2-11**

1. 然后选择右侧数据方案的维度的名称，拖拉至左侧选中区域即可

## Page 94

![NC ERP software interface screenshot showing the 'Consolidated Assets' report. The left pane displays the report structure with detailed asset classifications (e.g., Current Assets, Fixed Assets, Other Assets). The right pane shows detailed entries, including 'Asset Category' (e.g., 'Current Asset', 'Fixed Asset', 'Intangible Asset'), 'Asset Number', 'Initial Amount', and 'Ending Amount'. The report is titled 'Consolidated Assets'.]()

图 2.3.1.4.2-12
模版匹配之后的效果：

## Page 95

![NC logo]()
大型企业管理与电子商务平台

| (续01表)合并资产负债表 | |  | | | | | |  | | | | | |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 项目 | 指标 | 公式 | 报表项目 | HR参数规则 | | | | | | | | | | | |
| 报表取数规则 | | 供给数据维护 | | | | | | | | | |
|  |  | A | B | C | D | E | F |  | | | | | |
| **合并资产负债表** | | | | | | | | | | | | | | | | | | | |
| 3 | 单位： | 报表期： | | | 会计期： | | | | 负债和所有者权益（或股东权益） | | | | | | | | | | | |
| 4 |  |  | 资产 | 行次 | 期末余额 | 年初余额 | |  | | | | | | | | | |
| 5 | 流动资产： |  |  | 流动负债： | | | | | | | | | | | |
| 6 | 1010101/101/货币资金 |  |  | 1 | --- | --- |  |  | | | | | | | | | | | |
| 7 | 1010102/102/应收账款 |  |  | 2 |  |  |  | 短期借款 | | | | | | | | | | | |
| 8 | 1010103/103/预付款项 |  |  | 3 |  |  |  | 向中央银行借款 | | | | | | | | | | | |
| 9 | 1010104/104/交易性金融资产 |  |  | 4 |  |  |  | 吸收存款及同业存放 | | | | | | | | | | | |
| 10 | 1010105/105/存货 |  |  | 5 |  |  |  | 拆入资金 | | | | | | | | | | | |
| 11 | 1010106/106/应收票据 |  |  | 6 |  |  |  | 交易性金融负债 | | | | | | | | | | | |
| 12 | 1010107/107/预付款项 |  |  | 7 |  |  |  | 应付票据 | | | | | | | | | | | |
| 13 | 1010108/108/应收保费 |  |  | 8 |  |  |  | 应付账款 | | | | | | | | | | | |
| 14 | 1010109/109/分保账款 |  |  | 9 |  |  |  | 卖出回购金融资产款 | | | | | | | | | | | |
| 15 | 1010110/110/应收分保合同准备金 |  |  | 10 |  |  |  | 应付手续费及佣金 | | | | | | | | | | | |
| 16 | 1010111/111/应收利息 |  |  | 11 |  |  |  | 应付职工薪酬 | | | | | | | | | | | |
| 17 | 1010112/112/应收款项 |  |  | 12 |  |  |  | 应交税费 | | | | | | | | | | | |
| 18 | 1010113/113/买入返售金融资产 |  |  | 13 |  |  |  | 应付利息 | | | | | | | | | | | |
| 19 | 1010114/114/存货 |  |  | 14 |  |  |  | 其他应付款 | | | | | | | | | | | |
| 20 | 1010115/115/一年内到期的非流动资产 |  |  | 15 |  |  |  | 应付分保账款 | | | | | | | | | | | |
| 21 | 1010116/116/其他流动资产 |  |  | 16 |  |  |  | 保险合同准备金 | | | | | | | | | | | |
| 22 | 流动资产合计 |  |  | 17 |  |  |  | 代理买卖证券款 | | | | | | | | | | | |
| 23 | 非流动资产： |  |  | 18 |  |  |  | 代理承销证券款 | | | | | | | | | | | |

图 2.3.1.4.2-13

注意：

1. 匹配的规则是先依据报表项目的编码、再依据报表项目的名称，以绝对配对为最优先，模糊匹配时，以报表样式上的内容≥报表项目的内容为规则进行匹配。在没有绝对匹配的前提下，模糊匹配时不会考虑模糊匹配的程度，即：同一个报表样式，分别与两个报表项目均可模糊匹配，系统会自动以第一个模糊匹配结果为准。
2. 当报表项目映射在空白报表样本单元格时，会将报表项目名称设置为该单元格的表样内容。参考报表项目的映射流程，可以继续映射数据源类型、度量、以及其他维度信息。

## Page 96

![Figure 23.14.2-14: Screenshot of the 'NC 合并资产负债表' (Consolidated Balance Sheet) in the NC system, showing the trial balance adjustment interface. The interface lists various asset and liability accounts (e.g., 应收账款, 长期借款, 应付账款, 预计负债, 应付职工薪酬, 应交税费, 应付利润) with their original values, adjusted values, and differences. Red annotations indicate that certain accounts need to be matched to the '应付账款' (Accounts Payable) account.]()

图 23.14.2-14

如果存在多个单元格需要映射同一个成员时，可以通过映射至合并单元格来解决该问题。如上图：D5、E5 均需要映射实际数据类型。可以将 D4 和 E4 单元格合并，然后映射一个“实际”即可。

![Figure 23.14.2-15: Screenshot of the 'NC 合并资产负债表' (Consolidated Balance Sheet) in the NC system, showing the adjusted trial balance after merging cells D4 and E4. The '应付账款' (Accounts Payable) account now has a single adjusted value of 48, with a difference of 0.]()

图 23.14.2-15

两种映射结果相同。

## Page 97

![NC logo]()

NC

大型企业管理与电子商务平台

![A screenshot of a financial application (NC) showing a ledger entry form. It includes fields for company name, date, voucher number, account name, and a list of general ledger accounts (like 银行存款, 营业收入, 应付账款).]()

图2.3.1.4-2-16

映射时间关键字时,需要选择具体的期间

![A screenshot of a financial spreadsheet (NC) titled '资产负债表' (Balance Sheet). It shows columns for 期末余额 (Ending Balance), 借方 (Debit), 贷方 (Credit), and 借/贷 (Debit/Credit). The sheet is used for mapping data to specific accounting periods.]()

图2.3.1.4-2-17

当所有映射均完成后,可以通过生成映射区域按钮,来显示映射是否完整。如果全部映射完成,则在指标上会以红色背景显示。

## Page 98

![NC logo]()

大型企业管理与电子商务平台

单位： 报表组织
会计月:

| 资产 | | 行次 | 期末数, 实际 | | 年初数 | |
| --- | --- | --- | --- | --- | --- | --- |
| 流动资产: | | 1 | --- | | --- | |
| 01010101/货币资金 | 2 |  | 123 | 是 | 123 | 是 |
| 01010102/结算备付金 | 3 |  | 123 | 是 | 123 | 是 |
| 01010103/拆出资金 | 4 |  | 123 | 是 | 123 | 是 |
| 01010104/交易性金融资产 | 5 |  | 123 | 是 | 123 | 是 |
| 01010105/应收票据 | 6 |  | 123 | 是 | 123 | 是 |
| 01010106/应收账款 | 7 |  | 123 | 是 | 123 | 是 |
| 01010107/预付款项 | 8 |  | 123 | 是 | 123 | 是 |
| 01010108/应收保费 | 9 |  | 123 | 是 | 123 | 是 |
| 01010109/应收分保账款 | 10 |  | 123 | 是 | 123 | 是 |
| 01010110/应收分保合同准备金 | 11 |  | 123 | 是 | 123 | 是 |
| 01010111/应收利息 | 12 |  | 123 | 是 | 123 | 是 |
| 01010112/其他应收款 | 13 |  | 123 | 是 | 123 | 是 |
| 01010113/买入返售金融资产 | 14 |  | 123 | 是 | 123 | 是 |
| 01010114/存贷 | 15 |  | 123 | 是 | 123 | 是 |
| 01010115/一年内到期的非流动资产 | 16 |  | 123 | 是 | 123 | 是 |
| 01010116/其他流动资产 | 17 |  | 123 | 是 | 123 | 是 |
| 流动资产合计 | | 18 | 是 | | 是 | |

图 2.3.1.4.2-18

注意：“生成影射区域”按钮不是必须点击。当刷新当前界面时，系统会自动判断是否映射完成。当鼠标指向指标时，会显示映射结果，如果缺少对应资源的映射，会以红色字体提示。

| 资产 | 行次 | 期末数, 实际 | 年初数 | 负债和所有 |
| --- | --- | --- | --- | --- |
| 流动资产: | 1 | --- | --- | 流动负债: |
| 01010101/货币资金 | 2 | 123 |  | 期借款 |
| 01010102/结算备付金 | 3 | 123 |  | 中央银行 |
| 01010103/拆出资金 | 4 | 123 |  | 拆入资金 |
| 01010104/交易性金融资产 | 5 |  |  | 交易性金融资产 |
| 01010105/应收票据 | 6 | 123 |  | 应付票据 |
| 01010106/应收账款 | 7 | 123 |  |  |

图 2.3.1.4.2-19

全部映射完成的状态：


## Page 99

![NC logo]() 大型企业管理与电子商务平台

---

资产 行次 期末数\_实际 年初数 负债和所有者权益 (或股东权益)

|  |  |  |  |  |
| --- | --- | --- | --- | --- |
| 流动资产 | 1 |  |  | 流动负债 |
| 01010101/货币资金 | 2 |  |  | 短期借款 |
| 01010102/结算备付金 | 3 |  |  | 营业: 借: 01010102/结算备付金 |
| 01010103/拆出资金 | 4 |  |  | 贷: 01010102/结算备付金 |
| 01010104/交易性金融资产 | 5 |  |  |  |
| 01010105/应收票据 | 6 |  |  | 交易性金融负债 |
| 01010106/应收账款 | 7 |  |  | 应付票据 |
| 01010107/预付款项 | 8 |  |  | 应付账款 |
| 01010108/应收保费 | 9 |  |  | 预收款项 |
| 01010109/应收分保账款 | 10 |  |  | 卖出回购金融资产款 |
| 01010110/应收分保合同准备金 | 11 |  |  | 应付手续费及佣金 |
| 01010111/应收利息 | 12 |  |  | 应付职工薪酬 |
| 01010112/其他应收款 | 13 |  |  | 应付税金 |
| 01010113/买入返售金融资产 | 14 |  |  | 应付利润 |
| 01010114/存货 | 15 |  |  | 其他应付款 |
| 01010115/-一年内到期的非流动资产 | 16 |  |  | 应付分保账款 |
| 01010116/其他流动资产 | 17 |  |  | 预付合同保证金 |

图 2.3.1.4-2-20

如果缺少对应的映射资源，系统会以红色字体提示。当所有需要映射的数据方案资源，已经全部映射后，完成映射关系的设置。

当进行映射后，系统默认显示映射之后的状态，如果想查看报表样表的原始状态，可以通过“显示表样/映射”按钮来切换显示。

![截图显示了“显示表样/映射”按钮的状态切换。原始表样显示所有数据。点击“显示映射”后，显示为映射状态，数据用红色和绿色箭头/方框标记。再次点击“显示表样”后，恢复为原始表样。]()

![截图显示了映射后的表样。左侧为资产部分，右侧为负债和所有者权益部分，部分数据单元格用红色或绿色箭头和方框标记，表示数据的来源或流向。]() 资产 行次 期末数\_实际 期末余额

|  |  |  |  |
| --- | --- | --- | --- |
| 流动资产 | 1 |  |  |
| 01010101/货币资金 | 2 | 是 |  |
| 01010102/结算备付金 | 3 | 否 |  |
| 01010103/拆出资金 | 4 | 否 |  |
| 01010104/交易性金融资产 | 5 | 是 |  |
| 01010105/应收票据 | 6 | 是 |  |
| 01010106/应收账款 | 7 | 否 |  |
| 01010107/预付款项 | 8 | 否 |  |
| 01010108/应收保费 | 9 | 否 |  |
| 01010109/应收分保账款 | 10 | 否 |  |
| 01010110/应收分保合同准备金 | 11 | 否 |  |
| 01010111/应收利息 | 12 | 是 |  |
| 01010112/其他应收款 | 13 | 是 |  |
| 01010113/买入返售金融资产 | 14 | 否 |  |
| 01010114/存货 | 15 | 否 |  |
| 01010115/-一年内到期的非流动资产 | 16 | 否 |  |
| 01010116/其他流动资产 | 17 | 否 |  |
| 流动负债 |  |  |  |
| 货币资金 | 1 | 是 |  |
| 结算备付金 | 2 | 否 |  |
| 拆出资金 | 3 | 否 |  |
| 交易性金融资产 | 4 | 是 |  |
| 应收票据 | 5 | 是 |  |
| 应收账款 | 6 | 否 |  |
| 预付款项 | 7 | 否 |  |
| 应收保费 | 8 | 否 |  |
| 应收分保账款 | 9 | 否 |  |
| 应收分保合同准备金 | 10 | 否 |  |
| 应收利息 | 11 | 否 |  |
| 其他应收款 | 12 | 否 |  |
| 买入返售金融资产 | 13 | 否 |  |
| 存货 | 14 | 否 |  |
| -一年内到期的非流动资产 | 15 | 否 |  |
| 其他流动资产 | 16 | 否 |  |

图 2.3.1.4-2-21

在一些特殊的地方上，当需要将提取映射的映射关系，复制到供给映射中。为了减低重复工作量，系统只在提供数据映射时，提供复制按钮

![截图显示了在提供数据映射时的复制按钮界面。有四个图标按钮：第一个图标是复制按钮，第二个是粘贴按钮，第三个是删除按钮，第四个是取消按钮。]() 作用是将提取数据映射的关系，复制到供给映射
## Page 100

![NC logo]()
NC
大宏企业管理与电子商务平台

---

中。在提取数据映射时，不提供该复制按钮。

**注意：**

* 报表数据提取数据方案的映射，必须在“提取数据映射”页签中设置才能使用。
* 同一张报表，只能针对一个数据方案设置“提取数据映射”。如果想切换另一个数据方案，必须删除现有方案下的全部映射关系。
* 不能映射在报表指标处。
* “提取数据映射”与“供给数据映射”页签不同，前者不提供“复制”按钮。

### 2.3.1.4.3 数据提取工作

➤ 与公式函数的取数方式相同，在报表数据中心，通过计算按钮，就可以提取已经映射提取数据映射过的数据方案数据。

![Screenshot of the NC reporting system showing the 'Data Extraction' page (数据提取) with a table titled '资产负债表' (Balance Sheet). Columns show various financial metrics and their source data table names.]()

图 2.3.1.4.3-1

或者

用友

## Page 101

图 2.3.14-3-2

该图展示了 NC 软件“即时分析”下拉菜单中的“计算”选项，其中列出了几种计算方式及其快捷键：

* 专业业务函数计算 (Shift+F10)
* 多表计算 (Shift+F11)
* 动态区展示
* 删除
* 公式管理器 (U)
* 数据追溯 (T)
* 生成报告 (S)
* 查看关联公式
* 查看业务函数来源 (S)

交互示例：

* 当同一个单元格即有公式，又有数据方案映射时，系统会先计算数据方案，再计算公式。最终结果是以公式计算结果为准。
* 针对有且只有公式的单元格，数据追溯时，仅显示公式内容。

## Page 102

![图 2-3-1-4-3-3：数据追踪界面截图。左侧显示追踪目标为 P TOTAL(D6:D21)。右侧显示公式原理内容为 '合并资产负债表-202* = P TOTAL( B6:B21 )'，计算结果为 5,201.00。]()

图 2-3-1-4-3-3

> 针对即有公式、同时又设置了数据方案映射的单元格，数据追踪时，由于只有公式计算结果生效，所以也仅显示公式内容。


## Page 103

![NC logo]()

大型企业管理与电子商务平台

#### 数据源控

**数据项名：**PTOTAL(D6:D21)

**数据描述：**合并资产负债表(测试用\_2015-10).D22

| 公式处理内容 | 计算 | 关键字 |
| --- | --- | --- |
| 合并资产负债表(测试用\_2015-10).D22 = PTOTAL(**(10, 261)**) | **6,321.00** | 测试用\_2015-10 |

图 23.143-4

▶ 针对只有且只有数据方案映射的单元格，数据追溯时，仅显示数据方案的映射内容。

#### 数据源控

| 数据类型 [实时、个别/时段/维度] [月] [本期/报表项目] 01010103跨出资金(Measure) [测项目] | 选择 |
| --- | --- |
| **数据描述：**合并资产负债表(测试用\_2015-10).D38 |

| 数据来源 | 数据类型 | 数据组织 | 报表项目 | 年 | 半年 | 季度 | 月 | 度量 | 计算 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |

图 23.143-5

有且只有总账作为数据方案的数据来源时，才支持联合汇总和联合明细功能。

## Page 104

![Screenshot of an NC Enterprise Resource Planning (ERP) interface, likely for financial or inventory management. The screen shows transaction details, including product name, warehouse, location, category, item code, specifications, unit price, quantity, and total amount. A date range is displayed as 2014-01-01 to 2014-01-08.]()

图 2.3.1.4.3-6

分屏对应如下结果:

![Screenshot of the result screen (分屏对应结果), showing transaction data similar to the first image but in a different layout, possibly a report view, with columns for product, warehouse, location, category, item code, specifications, unit price, quantity, and total amount. The date range 2014-01-01 to 2014-01-08 is also visible.]()

图 2.3.1.4.3-7

### 2.3.1.4.4 其他功能

* > 数据方案取数后是否允许修改数据,可以通过表格页签下进行空值。

先选中需要设置的已经映射好的数据方案区域,然后在表页页签进行具体的控制方式即可。

## Page 105

![NC logo]() 大型企业管理体系与电子商务平台

![Sinochem logo]()

![A screenshot of an NC financial report titled '合并资产负债表 (Consolidated Balance Sheet)'. The table lists accounts in Chinese, showing columns for debit balance, credit balance, net debit/credit balance, and remarks. There are menu options visible on the left side of the table, including '取表样参数值', '取表行总数据', '允许编辑', and '禁止编辑'.]()

**图 2.3.1.4-4-1**

根据用户所选不同单元格，可以分别设置其对应的取数后是否允许编辑的设置功能。

> 注意：此设置是同时对公式和数据方案放射生效。但是对手工录入单元格不生效。

## 2.4 V57 业务数据提取

### 2.4.1 V57 业务数据提取

#### 2.4.1.1 业务描述

> 系统提供针对部分 V57 业务数据提取至企业报表中的功能。

> 当数据方案通过预览可以查看部分 V57 业务数据时，此数据就可以通过设置映射关系，然后通过企业报表的计算功能，提取至企业报表中。

> V65 产品数据方案仅支持通过数据方案提取 V57 总账、固定资产以及应收应付模块的部分业务数据。不支持提取包括 V57 UFO 数据在内的其他业务模块数据。

**注意：**以下本文所述 V5 系列如果不做特殊说明，均视为 V57。V65 水平产品不支持《V56》（含）以前版本。

## Page 106

本业务数据提取功能。

### 2.4.1.2 业务流程

![流程图：开始 -> 增加V57的数据源 -> V5财务取数设置 -> 新建数据方案流程(含一个加号图标) -> 进行数据预览/提取 -> 结束]()

图2.4.1.2-1 V57 业务数据提取

### 2.4.1.3 功能清单

| 领域 | 产品模块 | 功能节点 |
| --- | --- | --- |

## Page 107

企业绩效管理 数据方案 报表组织体系

报表项目-全局/集团/组织

映射关系-全局/集团/组织

财务数据方案-全局/集团/组织

数据类型管理

V5 财务取数初始化

V5 档案映射

企业报表 报表表样-全局/集团/组织

数据源

报表数据中心

### 2.4.1.4 产品解决方案

#### 2.4.1.4.1 增加数据库

➤ 通过 sysconfig 将 V57 数据源追加至 V65 系统中。

## Page 108

图 2.4.1.4.1-1

增加数据源。

![Screenshot of the NC ERP system interface showing the '增加数据源' (Add Data Source) function. The navigation path is 功能导航 (Function Navigation) > 信息中心 (Information Center) > 数据源 (Data Source), with the Data Source module highlighted. A submenu shows options like 企业报表 (Corporate Reports) and 数据源 (Data Source) highlighted. Below, a resource management section (资源管理) lists options such as 业务属性 (Business Attributes), 关键字 (Keywords), 数据源 (Data Source), and 报表样式-报表组织 (Report Style - Report Organization).]()

图 2.4.1.4.1-2 新增数据源

![Screenshot of the NC ERP system interface showing the '新增数据源' (Add New Data Source) dialog box. The dialog contains fields for 数据源名称 (Data Source Name), 系统名称 (System Name), 创建人 (Creator), and 说明 (Description). Row 1 shows example data: 数据源名称 is 20, 系统名称 is redacted, 创建人 is ncc89.]()

## Page 109

![Screenshot of an NC ERP software interface showing the database configuration screen. Fields include 登录类型 (Login Type) set to NCV5 数据源 (NCV5 Data Source), 登录账号 (Login Account), 密码 (Password), 默认库 (Default Database), 数据库类型 (Database Type) set to NCV5 数据源 (NCV5 Data Source), and various database connection parameters.]()

图 2.4.1.4-3 将类型设置为 NCV5 数据源

* > 录入 NCV5 系统的登录用户、密码、公司、地址、账套信息，以数据方案取数时使用。

#### 2.4.1.4.2 V5 财务取数设置

* > V5 财务取数初始化设置

## Page 110

大型企业管理与电子商务平台

## NC

功能导航

消息中心

数据源

* 常用功能
* 动态建模平台
* XBRIL
* 集成平台
* 应用管理平台
* 共享服务

### 企业绩效管理

* 财务会计
* 资金管理
* 管理会计
* 供应链
* 进出口
* 资产管理
* 项目管理
* 供应商管理

* 全面预算
* 企业报表
* 合并报表
* 合并账簿
* 数据方案
* NC>XBRIL

### 基础设置

* 报表项目体系
* 报表项目-全局
* 报表项目-集团
* 报表项目-组织
* 映射关系-全局
* 映射关系-集团
* 映射关系-组织
* 数据类型管理

### 数据方案

* 财务数据方案-全局
* 财务数据方案-集团
* 财务数据方案-组织

### vs财务取数

* vs财务取数初始化
* vs档案映射

### NC

功能导航

消息中心

VS取数参数初始化

数据源 [vs5]

| 数据源 | VS系统抽取核算类型 | VS系统辅助核算类型 | 同步档案 |
| --- | --- | --- | --- |
| 1 人员档案 | 人员档案 |  |  |
| 2 城区分类 | 城区分类 |  |  |

图 2-4-14-2-1

选择 vs5 数据源后，可以对 vs、v6 两者数据源的档案进行映射。

## Page 111

大家企业级管理与电子商务平台

如果完全以 v5 档案成员为准，则可以勾选同步档案选项，此时可以跳过后续 v5 档案映射操作，但需要保证两个系统的档案编码、名称一致。如果不勾选，则必须进行 v5 档案映射后才能正常使用。

➤ v5 档案映射

![图 24.14-2: NC 系统中 V5 档案映射界面截图，显示了多个档案成员及其对应的 V5 档案编码。]()

图 24.14-2

逐一设置每个 v5 档案成员与 v6 档案成员的映射关系

若在初始化时选择了“同步档案”则可以不进行此映射。

### 2.4.1.4.3 新建数据方案

➤ 与查询业务数据的建立流程相同。只是需要在数据来源页签下，选择对应的数据来源。

![图 24.14-3-1: 数据方案界面截图，显示了 V57 总账的数据来源设置。]()

图 24.14-3-1

✓ V57 总账:

## Page 112

![Software interface for 'S7 Accounts Receivable Setups', part of an ERP system. The title bar shows 'S7 应收账款规则设置' (S7 Accounts Receivable Setup Rules). The main window is titled '基础规则' (Basic Rules) under '业务单元' (Business Unit). Fields include '账套源' (Accounting Set Source), '核算账簿' (Accounting Ledger) with a search button, '币种' (Currency) with a search button, and an option '包含未记账' (Include Unrecorded). Buttons '确定' (Confirm) and '取消' (Cancel) are at the bottom.]()

图 2.4.1.4.3-2

✓ V57 应收应付:

## Page 113

![NC Software interface for setting up 57 accounts payable payment collection agencies, titled 'NC 大型企业管理与电子商务平台'. The screen shows fields for basic rules (基础规则), business unit (业务单元), data range (数据范围), voucher period (15期账区间), payment recipient (往来对象), and custom items (自定义项).]()

图 2-4-1-4-3-3

✓ V57 固定资产

## Page 114

![Image showing a UI window titled 'V57固定资产数据规则设置' (V57 Fixed Asset Data Rule Settings). The window contains fields for '基础规则' (Basic Rules) and '业务单元' (Business Unit), and input fields for '数据源' (Data Source) and '核算账簿' (Accounting Ledger). Buttons '确定' (Confirm) and '取消' (Cancel) are visible.]()

图2.4.1.4.3-4

注意: 虽然数据来源中固定资产没有标明V57, V65系统中数据方案也仅支持提取V57固定资产的数据, 不支持提取V65固定资产的数据。

#### 2.4.1.4.4 报表项目映射

* 虽然整体操作上与报表项目与会计科目映射流程相同, 但是映射的区域有变化。
* 会计科目的映射关系不变
* 应收应付项目的映射关系需要切换至应收应付项目页签下

## Page 115

![Screenshot of a financial management system interface showing the '应收应付项目' (Accounts Receivable and Payable Projects) tab selected, displaying fields for general ledger items and project definitions.]()

图 2.4.1.4-1

注意：应收应付项目虽然没有明确注明 V5 系列、V65 版本也只支持提取 V57 版本应收应付的业务数据，不支持通过数据方案提取 V65 应收应付的业务数据。

▷ 固定资产项目的映射关系需要切换至对应的页面下

![Screenshot of a financial management system interface showing the '固定资产项目' (Fixed Asset Project) tab selected, displaying fields for general ledger items and project definitions.]()

图 2.4.1.4-2

注意：固定资产项目虽然没有明确注明 V5 系列、V65 版本也只支持提取 V57 版本固定资产的业务数

## Page 116

据,不支持通过数据方案提取V65固定资产的业务数据。

#### 2.3.1.4.5 数据提取、数据预览工作

* 与前文所述的提取、预览操作完全相同,在此不做赘述。
* 注意:V57数据方案预览数据或者企业报表计算之后的数据,只有V57总账的数据支持数据追踪至V57业务系统,其余模块均不支持数据追踪;这种追踪也只有在IE浏览器下支持,其余浏览器均不支持。

## Page 117

大型企业管理与电子商务平台

Large-scale Enterprise Management and E-business Solution Platform

用友

用友网络科技股份有限公司

Yonyou Network Tech Co. Ltd.
