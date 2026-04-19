# NCV6.5产品手册-采购计划
## Page 1

yonyou

NC

产品手册- V6.5

---

## 采购计划

## Page 2

大型企业管理与电子商务平台

# 版权

● 用友集团版权所有

未经用友集团的书面许可，本操作手册任何整体或部分的内容不得被复制、复印、翻译或缩减以用于任何目的。本操作手册的内容在未经通知的情形下可能会发生改变，敬请留意。请注意：本操作手册的内容并不代表用友软件所做的承诺。

用友网络科技股份有限公司

## Page 3

大型企业管理与电子商务平台

NC

## 目录

|  |  |
| --- | --- |
| 版权 | 1 |
| 导读 | 3 |
| 名词解释 | 4 |
| 第一章 概述 | 5 |
| 第二章 产品应用 | 7 |
| 2.1 基本应用 | 7 |
| 2.1.1 采购计划体系建立 | 7 |
| 2.1.2 采购计划表编制 | 11 |
| 2.1.3 采购计划任务管理 | 22 |
| 2.1.4 计划对业务的控制 | 29 |
| 2.1.5 采购计划调整调剂 | 32 |
| 2.2 相关主题 | 33 |
| 2.2.1 采购计划发布 | 33 |
| 2.2.2 计划预占及执行 | 35 |
| 第三章 初始准备 | 37 |
| 第四章 操作指南 | 38 |
| 附录 | 39 |
| 附录 1: 接口说明 | 39 |
| 附录 2: 本文参见其他手册清单 | 39 |

## Page 4

# 导读

此手册面向实施顾问以及企业关键用户，旨在为实施规划、解决方案制定和落实提供指导。手册围绕产品能够解决的主要业务场景展开，并以此为依托展现产品的关键应用功能，提供业务需求与产品功能相匹配的思路。

本手册包括四大部分，第一部分是对产品及其价值的概要介绍；第二部分是对有关本模块的主要业务场景、流程、以及对应的业务功能的介绍；第三部分是初始准备设置；第四部分是关于本模块功能点的重要操作，此部分未就详细条目展开，详情可查阅产品相关模块的在线帮助说明。

此外，为了便于用户对整体内容加深理解，手册中对一些关键的名词进行了解释，并在附录中对一些可能需要对照查询的关键点进行了补充说明，以使用户查找对照。

为突出重点，本手册定位方案性说明，仅对产品操作中的重要控制点有所描述。若读者希望深入了解特定模块的产品应用，可结合本手册，查阅如下资料：

1. 《产品手册-组织管理》——深入阐述了产品关键概念（如集团、组织、业务委托关系等）以及建模思路，是实施规划、蓝图设计的重要参考资料。
2. 产品帮助——针对具体功能点的关键字段、按钮操作进行详细解释，并提供关键应用示例。
3. 《产品手册-流程管理》——提供关于交易类型、流程设计工具的应用指导。
4. 《产品手册-基础数据》——可对手册第三部分（即初始准备设置）中的有关基础数据的理解和应用进行更详细深入地了解。

## Page 5

![NC logo]()
大型企业管理与电子商务平台

---

# 名词解释

## 控制单据

采购计划控制所针对的单据，目前支持的控制单据有：请购单、采购订单。控制单据在某个时点会形成对采购计划的预占，同时要检查是否超预算。预占的释放是在控制单据被关闭时。

## 执行单据

执行单据是相对控制单据而言，首先，执行单据必须是控制单据的后续单据；其次，控制单据可对应多个执行单据。在一定的时点，控制单据的预占数释放，同时将执行单据的数量形成采购计划的执行数。如果控制单据为请购单，则对应的执行单据可以是采购订单、到货单、采购入库单、采购发票；如果控制单据为采购订单，则对应的执行单据可以是采购订单、到货单、采购入库单、采购发票。

## 预占数

采购计划被占用的数量，在请购单或采购订单审批后就会占用。占用数量在请购单或采购订单关闭时会被释放。

## 执行数

采购计划的执行数量，反映的是采购计划的执行单据的执行情况，通常是在控制单据的某个动作触发预占数的释放、执行数的增加。

## 计划占用金额

采购计划被占用的金额，在请购单或采购订单审批后就会占用。占用金额在请购单或采购订单关闭时会被释放。

## 计划执行金额

采购计划的执行金额，反映的是采购计划的执行单据的执行情况，通常是在控制单据的某个动作触发预占数的释放、执行数的增加。

## Page 6

## 第一章 概述

采购计划目的是通过制定计划来对后续的请购、采购业务进行控制，以及通过预算和实际执行的对比分析，合理控制采购成本和对将来的采购业务改进提供参照依据。采购计划产品的适用背景是 MRO/ROP 类物资、按项目运作类的物资或者日常运维物资采购预算控制，注意区别于针对正常生产用原材料的采购的计划，比如 MRP 计划等。

采购计划产品支持按照采购计划体系，下级组织对采购计划填报、审批、批复，上级组织对下级计划汇总、修订、调整。支持采购计划按照指定的审批流流转，同时支持按照计划平台的工作流程进行多级批复。

采购计划产品是搭建在计划平台产品上的，与计划平台产品有依赖关系，另外需要牢记的一点就是：采购计划是全面预算的一个分支，其应用方式与全面预算几乎完全一致。

采购计划产品的功能架构如图 1-01 所示：

## Page 7

大型企业管理与电子商务平台

NC

企业建模平台

采购计划体系

数据准备

维度管理

采购计划建模

应用模型

任务管理

控制规则

业务规则

表单设计 (EXCEL)

表单管理

控制方案

计划编制、发布、调整

采购计划编制 (EXCEL)

采购计划审批

采购计划发布

采购计划调整

采购计划调剂

调整单管理

分析查询

采购计划查询

采购计划版本查询

计划分析

图 1-01 采购计划产品的功能架构

## Page 8

![NC logo]()

大金企业管理与电子商务平台

## 第二章 产品应用

采购计划是全面预算的分支之一，若系统性地理解相关概念，请参照《产品手册-全面预算》。本手册侧重于告诉读者如何操作使用这个工具。读者在掌握基本操作的基础上，再进行扩展性的概念理解、功能应用，就会变得相对容易。

首先，假设我们在日常工作中需要制定一个采购预算计划，对未来的请购、采购业务活动进行指导和控制，达到控制成本的目的。那么通常的情景是怎样的呢：1)上面发一张表格下来，让各机构或各部门进行填写和上报，并进行汇总；2)计划经过相关领导审批通过后，各机构部门在获得的预算额度内进行请购、采购等业务；超过预算计划的业务可能被禁止，或被有条件地控制。

那么，我们需要面对的有五个主要问题：

1. 采购计划的参与者有哪些？他们之间是怎样的层级和汇总关系？
2. 表格是什么格式，怎么制作？
3. 谁将接到填报任务？需要填报哪些表格？
4. 采购计划怎样实现对业务的控制？
5. 万一计划需要变更怎么办？

对于以上四个问题的解决，对应到产品实现（以及本手册编写结构）上就是：

1. 采购计划体系建立
2. 采购计划样表编制
3. 采购计划任务管理
4. 计划对业务的控制
5. 采购计划调整调剂

这些是采购计划的基本应用部分，除此之外，还有一些相关主题，我们按此结构进行描述。

## 2.1 基本应用

### 2.1.1 采购计划体系建立

#### I. 采购计划体系

## Page 9

采购计划体系是指具有编制采购计划职能的业务单元所组成的组织体系，但是在 NC 系统中不存在特定的采购计划组织，而是通过将业务单元引入采购计划体系，组成一棵具有确定上下级关系的组织树。这棵树我们成为采购计划体系。同时，在计划体系中的组织就成为采购计划组织。

从应用场景来看，编制采购计划的主体涉及：工厂或者物资消耗部门（系统中的库存组织）、库存组织下的部门、负责库存组织采购的采购组织，以及需要对多个采购组织做预算控制的相关部门，也可能是一个虚拟的组织。

只有需要编制采购计划的主体，才会放到计划体系结构中来。主要考虑两种计划体系结构：

1. 单一组织计划体系，该计划体系中只有一个业务单元。该业务单元同时具有库存组织、采购组织的职能，自己制定采购计划，自己执行。
2. 多组织计划体系，该计划体系中包含多个业务单元、部门，可能有如下多种组织形式：
   * 单一采购组织+库存组织：

![图 2.1-01 单一采购组织+库存组织。这是一个组织结构图，采购组织1在顶部，向下分支连接到三个库存组织：库存组织1、库存组织2和库存组织n。]()

图 2.1-01 单一采购组织+库存组织

> 单一采购组织+库存组织+部门1：考虑部门非业务单元，可能会存在差异，单独列出：

![图 2.1-02 单一采购组织+库存组织+部门。这是一个组织结构图，采购组织1在顶部，向下分支连接到三个库存组织：库存组织1、库存组织2和库存组织n。库存组织1向下分支连接到部门1。库存组织2向下分支连接到部门2。库存组织n向下分支连接到部门n。]()

图 2.1-02 单一采购组织+库存组织+部门

> 顶级组织+多个采购组织+库存组织+部门：顶级组织可以认为是从集团的角度对下属的多个采购组织做汇总计划的一个角色（职责）。

## Page 10

![NC logo]()

大型企业管理与电子商务平台

虚拟组织

采购组织1

采购组织2

库存组织1

库存组织2

库存组织m...

部门11

部门12

部门m...

图 2-1-03 顶级组织+多个采购组织+库存组织+部门

## II. 业务示例

> 新世纪纸业集团公司的组织架构如下：

新世纪纸业集团

集团贸易事业部

供应链事业部

家用纸事业部

无锡宏远工厂

无锡兴达工厂

无锡宝达仓储

华北纸业公司

西南纸业公司

华南纸业公司

华东纸业公司

销售服务中心

纸业销售公司

华东纸业公司

华北分公司

东北分公司

华西分公司

华西分公司

华南纸业公司

华南分公司

华东分公司

图 2-1-04 示例组织架构图

> 集团总公司准备对无锡宏远工厂、无锡兴达工厂的部分物料进行采购计划控制；

> 其中无锡兴达工厂下设的一些部门偶尔可能也需要参与采购计划的填报，但要视情况而定（这是为了在示例中让读者区分“采购计划主体”和“具体任务接受者”的区别）；

> 目前需要无锡宏远工厂、无锡兴达工厂分别制定 2012 年最后两个月的部分物料的采购计划；

> 新世纪纸业集团只是做计划数据汇总。

那么，我们构建一个采购计划体系，如下：

## Page 11

![NC logo]()

### 大企业经营管理与电子商务平台

![Figure 2.1-05 采购计划体系示例: A diagram showing the procurement planning system structure. The top is '新世纪纸业集团公司' (New Century Paper Group Co., Ltd.). It branches into '无锡兴达工厂' (Wuxi Xingda Factory) and '无锡宏远工厂' (Wuxi Hongyuan Factory). '无锡兴达工厂' further branches into '装备部' (Equipment Department) and '运输部' (Transportation Department).]()

图 2.1-05 采购计划体系示例

### III. 功能清单

| 领域 | 产品模块 | 功能节点 |
| --- | --- | --- |
| 动态建模平台 | 组织管理 | 业务单元 |
| 动态建模平台 | 组织管理 | 部门 |
| 动态建模平台 | 组织管理 | 采购计划体系 |

### IV. 产品解决方案

#### 1. 建立成员及属性

**路径:**【动态建模平台】→【组织管理】→【业务单元】/【部门】

建立业务单元以及部门 (如图 2.1-5), 并将所有成员都勾选“预算”属性, 这样才能被采购计划体系所参照引用到。同时, 宏远加工厂、兴达加工厂组织属性需要勾选“采购”和“库存”。

![Figure 2.1-06 业务单元的预算属性: A dialog box titled '组织职能' (Organization Function) showing various organizational roles and their associated attributes. The roles listed are: 1. 选人公司 (Selecting Company) and 工厂 (Factory). 2. 人力资源 (Human Resources). 3. 财务 (Finance). 4. 库存 (Inventory). 5. 物流 (Logistics). 6. 利润中心 (Profit Center). 7. 项目 (Project). 8. 计划中心 (Planning Center). 9. 资金 (Capital), 资信 (Credit), 资产 (Assets), and 行政 (Administrative). The checkbox for '预算' (Budget) is highlighted and checked.]()

图 2.1-06 业务单元的预算属性

#### 2. 建立采购计划体系

**路径:**【动态建模平台】→【组织管理】→【采购计划体系】

建立采购计划体系, 引入业务单元“新世纪纸业集团公司、无锡宏远工厂、无锡兴达工厂”以及无锡兴达工厂的“装备部、运输部”, 同时作为的计划汇总的结构, 如图:

## Page 12

![图 2.1-07 建立采购计划体系-01: A screenshot of a software interface (NC system) showing the steps to establish a procurement plan system. The '建立采购计划体系' menu is expanded, displaying options like '11-0101 采购计划' and '11-0102 采购计划主数据'.]()

图 2.1-07 建立采购计划体系-01

![图 2.1-08 建立采购计划体系-02: A screenshot of a software interface (NC system) showing the steps to establish a procurement plan system. The '11-0102 采购计划主数据' menu is expanded, displaying options like '11-0201 2019年采购计划工厂'.]()

图 2.1-08 建立采购计划体系-02

## 2.1.2 采购计划样表编制

### I. 业务描述

* 采购计划样表确定的是采购计划的展现形式，那些内容放在表头，那些内容作为行、列维度等等。
* 虽然采购计划主体都在一个计划体系内，但并不等于不同主体将来拿到的样表格式必须是一致的。比如，在一个采购计划体系内可以编制多种不同格式的样表，再根据情况分发给不同的主体进行填报，我们举两例：

样表一：

## Page 13

大蓝企业管理与电子商务平台

**NC**

|  |  |  |  |  |
| --- | --- | --- | --- | --- |
| 项目 | 2012 年 | | | |
| 11 月 | 12 月 | 采购数量 | 采购金额 | 采购数量 | 采购金额 |
| 电压表 |  |  |  |  |  |  |
| 电流表 |  |  |  |  |  |  |
| 机油 |  |  |  |  |  |  |
| 润滑油 |  |  |  |  |  |  |

样表二：

|  |  |
| --- | --- |
| 计划部门及项目 | 2012 年 12 月采购金额 |
| 装备部 | 机油 |
|  | 润滑油 |
| 运输部 | 机油 |
|  | 润滑油 |

## II. 业务示例

我们以“样表一”为例，进行样表制作的展示。

## III. 功能清单

| 领域 | 产品模块 | 功能节点 |
| --- | --- | --- |
| 动态建模平台 | 计划平台 | 维度管理 |
| 动态建模平台 | 计划平台 | 应用模型 |
| 供应链 | 采购计划 | 表单管理 |
| EXCEL 客户端 |  | 用于样表设计 |

## IV. 产品解决方案

### 1. 确定计划维度及数值范围

首先，在本例中，我们需要指定哪些物料可以参与采购计划编制。注意：如果不指定物料范围，那么在编制样表的时候，是参照不到物料的。

路径：【动态建模平台】→【计划平台】→【模型设置】→【维度管理】，选择“物料”后点击【控制

## Page 14

![NC logo]()

大型企业管理与电子商务平台

### 范围范围》-《指定物料范围》

![Figure 2.1-09: NC Inventory Management interface showing steps for selecting classification and new additions.]()

图 2.1-09 维度管理-01

选择分类，并【新增】：

![Figure 2.1-10: NC Inventory Management interface showing steps for selecting materials ready for purchase plan.]()

图 2.1-10 维度管理-02

找到准备做采购计划的物料。【确定】

## Page 15

图 2.1-11 维度管理-03

然后点击按钮【维度成员树】，就可以看到物料已经显示出来了。

![Screenshot of the NC system's Dimension Management (03) screen, showing the Dimension Member Tree view where materials are displayed.]()

图 2.1-12 维度管理-04

我们再选中“指标”一项，基本档案选择[预算科目]，在“业务指标”下可以看到针对采购计划的两个指标：采购数量、采购金额。这是系统预置的。

![Screenshot of the NC system's Dimension Management (04) screen. The user has selected '指标' (Indicators) and chosen [预算科目] (Budget Subject) as the basic archive. The '业务指标' (Business Indicators) section shows two pre-set indicators: '采购数量' (Purchase Quantity) and '采购金额' (Purchase Amount).]()

## Page 16

大麦企业管理与电子商务平台

![Figure 2-1-13: Dimension Management interface. The left panel lists various dimensions like '组织维度' (Organizational Dimension) and '业务维度' (Business Dimension). The main panel shows a detailed view of a selected dimension, possibly '员工维度' (Employee Dimension), displaying fields such as '姓名' (Name), '职位' (Position), '所属部门' (Department), '所在城市' (City), '入职时间' (Entry Date), and '离职时间' (Leaving Date). A search bar and filter options are visible at the top.]()

图 2-1-13 维度管理-05

1. **建立应用模型**

   有了维度来源以后,就相当于有了建筑材料。下一步就是对材料档案进行筛选,确定下一步设计样表所需要的组件。所谓模型,就是将来要制作的各种样表的材料,都是出自这个模型所设定的范围的。路径:【动态建模平台】→【计划平台】→【模型设置】→【应用模型】。【新增】一个应用模型,并在现有的维度基础上新增维度如“物料”、“部门”等,如下:

   ![Figure 2-1-14: Application Model interface. The interface shows a list of existing models (e.g., '员工维度应用模型'). A dialog box is open for creating a new model, titled '新建应用模型'. It prompts for input in fields like '应用模型名称' (Application Model Name) and '维度来源' (Dimension Source), listing available dimensions (e.g., '组织维度', '业务维度', '时间维度', '员工维度'). A table below lists dimensions selected for the new model, showing their sequence and status (e.g., 1: 组织维度 - 已选择, 2: 业务维度 - 已选择, 3: 时间维度 - 未选择).]()

   图 2-1-14 应用模型-01

   然后赋予每个维度的“汇总结构”以对应内容,比如对于“主体”,我们选择刚刚在采购计划体系中建立的“维护用品采购计划体系”。也就是说,应用这个模型的主体是这个采购计划体系。

## Page 17

大型企业管理与电子商务平台

![Figure 2.1-5 Application Model-02: A screenshot of a software interface showing the 'Plan Type' and 'Plan Cycle' setup screens, which include various input fields and options for defining planning parameters.]()

图 2.1-5 应用模型-02

同样，在本例中，维度“计划期间”选择[年月]，如下：

![Figure 2.1-6 Application Model-03: A screenshot of a software interface showing the 'Plan Type' and 'Plan Cycle' setup screens, which include various input fields and options for defining planning parameters.]()

图 2.1-6 应用模型-03

注意：在“一致性方案”页签里，我们可以引用一些规则，比如限制维度数值的取值范围等等，如将来制作样表，维度“计划期间”的取值仅限定在 2012 年 11、12 月，而其他的是参照不出来的。这样应用模型就更加具有针对性和控制性。这些规则是通过【供应链】→【采购计划】→【业务规则】来设置的，在本例中我们不采用，仅做提示让读者了解其用途。具体的应用可以参照《产品手册—全面预算》。

### 3. 表单设计

模型设置好以后，就是利用模型来制作产品——表单设计了。这一步是通过 EXCEL 客户端来完成的。

## Page 18

### EXCEL 客户端需要进行下载进行一些初始设置,这部分内容请参照“三、初始准备”部分,我们以下集中于应用。

路径: 选择“表单设计”页签,点击【设计向导】按钮,并选择我们刚刚设置好的应用模型:

![Screenshot of a Microsoft Excel spreadsheet showing a 'Form Design Wizard' dialog box. The dialog is titled '表单设计' and displays a list of fields and a button labeled '下一步' (Next step). A cell reference R2 is highlighted below the dialog.]()

图 2.1-17 表单设计-01

【下一步】后就是“选择任务参数维”,就是我们通常所说的“表头维”,右边的五个是预置的,也是不能被取消的。在本例中,我们不在表头增加其他维度,直接【下一步】。

## Page 19
![Figure 2.1-18: An Excel screen capture showing the process of selecting columns (行维度) and rows (列维度) for table design. A dialog box titled '选择应用模型' (Select Application Model) lists various business models, with 'INDUSTRIY 企业' (Industry Enterprise) selected. Another dialog titled '选择行维度' (Select Row Dimension) lists fields such as 'INDUSTRY 企业', 'UNITTYPE 设备类型', 'BRANDCLASS 品牌分类', and 'YEAR 年'.]()

图 2.1-18 表单设计-02

然后我们分别选择“行维度”和“列维度”：

![Figure 2.1-19: An Excel screen capture showing the selection of row and column dimensions. The dialog shows '选择应用模型' (Select Application Model) where 'INDUSTRY 企业' is selected. The '选择行维度' (Select Row Dimension) dialog shows 'INDUSTRY 企业' and 'BRANDCLASS 品牌分类' checked. The '选择列维度' (Select Column Dimension) dialog shows 'MONTH 月' checked.]()

图 2.1-19 表单设计-03

『下一步』后，表格出现了，如下。不过这仅仅是个默认的表格，我们需要对其调整以达到我们想要的格式。

## Page 20

![图 2.1-20: Excel 表单设计-04。显示了一个名为 'Tableau_04' 的 Excel 工作表，包含产品信息、单价和数量等数据。界面右侧有数据验证设置。]()

图 2.1-20 表单设计-04

调整后如下图。具体操作方式可参照《产品手册-全面预算》以及产品帮助。重点在于绿色的区域是维度，是不能随意删除的。

![图 2.1-21: 表单设计-05。显示了一个名为 'Tableau_05' 的 Excel 工作表，包含产品信息和计算公式。界面右侧有数据验证设置。]()

图 2.1-21 表单设计-05

## Page 21

然后，如法炮制，我们可以在另外一个页签如 Sheet2 从【设计向导】开始另外再制作一张样表，并为了后续方便识别，给两张样表页签进行重新命名，比如一个“宏远采购计划表”一个“兴达采购计划表”，如图：

![Microsoft Excel 窗口，显示了 Sheet1 和 Sheet2 两个工作表标签。Sheet2 包含宏远采购计划表的标题和数据。]()

图2-1-22 表单设计-06

样表制作好了，那么接下来就是要将表提交上去以供使用。在提交前如果觉得不放心，那么可以先【校验表单】，如果显示“校验通过”，就可以【提交表单】了。

![Microsoft Excel 窗口，显示了 Sheet2 中的 UFDIA UAP OBA 校验功能。红色框选中了校验表单和提交表单按钮。]()

图2-1-23 表单设计-07

## Page 22

给你表起一个名字:

表单设置

表单属性

表单名称: 网产品质量执行反馈表

文件路径: 无

所属分组: 销售反馈

文件夹: 无

上传取消

图 2-1-24 表单设计-08

【上传】

表单设置

表格设置

表格名称: 上传上一步表单,请确认

完成重试

图 2-1-25 表单设计-09

上传完成:

表单设置

表格设置

计算项目


|  |  |  |  |
| --- | --- | --- | --- |
| 部门 | 人员 | 计算项目 | 计算结果 |
| IT部 | 张三 | 计算项目 | 计算结果 |
| IT部 | 张三 | 计算项目 | 计算结果 |

编辑

图 2-1-26 表单设计-10

## Page 23

![NC logo]()
NC

大型企业管理与电子商务平台

### 4. 表单管理

样表制作完成，但可能会需要进行适度修改、分组等等，需要通过【供应链】→【采购计划】→【表单管理】来进行处理。本例中我们不关注这些，而是进行一个必须的动作《发布》。也就是说，样表是制作好了，但并不等于可以被随便用，而是要通过《发布》完成。

![Screenshot of the NC system interface showing the '表单管理' (Form Management) screen, which includes navigation tabs like '首页', '编辑', '发布', '删除', '导入', and a table listing form items.]()

图 2.1-27 表单管理

## 2.1.3 采购计划任务管理

### I. 业务描述

采购计划任务主要解决以下几个问题：

1. 哪些机构将具体执行采购计划预算表单的填制；
2. 任务中有哪些具体的规定和约束条件；
3. 采购计划任务的填报、提交、审批等。

### II. 业务示例

仍然接着上面所述例子继续。

### III. 功能清单

## Page 24

![NC logo]()
大型企业资源与电子商务平台

| 领域 | 产品模块 | 功能节点 |
| --- | --- | --- |
| 供应链 | 采购计划 | 任务管理 |
| 供应链 | 采购计划 | EXCEL 功能-计划编制 |
| 供应链 | 采购计划 | 采购计划审批 |

#### IV. 产品解决方案

首先,我们需要通过【供应链】→【采购计划】→【任务管理】建立一个任务,并指定此任务的“关联套表”为刚才我们所设置的套表,指定接收此任务的“组织体系”为此例中所设置的采购计划体系。

![Screenshot showing the task management interface in NC ERP. The screen is titled '任务管理' (Task Management). It displays a list of tasks on the left and a table of assigned organizations on the right. The highlighted task is '采购计划审批 (采购计划编制套表)' (Procurement Plan Approval (Procurement Plan Compilation Template)). The right table shows assignments, including '11-0201 无糖实业工厂' (Sugar-Free Industrial Factory 11-0201) appearing twice.]()

图2.1-28 任务管理-01

在上图中,我们要注意到,并不是采购计划体系中的所有成员都一定要参与计划填报的!本例中仅选择纸业集团总公司、兴达工厂、宏远工厂为任务接收对象。下一步就是给选出的这两个对象分配要填写的表格,如下:

## Page 25

![Figure 2.1-29: A screenshot of the '任务管理-02' (Task Management - 02) interface. The interface shows a list of tasks and a dialog box for '任务分单' (Task Division). The dialog box displays a task list, an '已选清单' (Selected List) with two items, and buttons for '确定' (Confirm) and '取消' (Cancel).]()

**图 2.1-29 任务管理-02**

【确认】后得到：

![Figure 2.1-30: A screenshot of the '任务管理-03' (Task Management - 03) interface. This interface displays a list of tasks under '待办任务' (Pending Tasks) and '已办任务' (Completed Tasks). The right panel shows a detailed view of a selected task, including fields like '项目名称' (Project Name), '项目负责人' (Project Manager), '计划完成时间' (Planned Completion Time), and a timeline/gantt chart showing task status (已开始, 未完成).]()

**图 2.1-30 任务管理-03**

注意任务虽然分配了，但目前是处于【未启动】状态，同时可能还需要进行一些相关的补充，比如这个采购计划任务将来由哪些人来审批，我们可以赋予其审批流。

## Page 26

![Figure 2.1-31: Screenshot of the '任务管理-04' interface, showing the '任务启动' (Task Initiation) tab. It displays a list of products and associated factories, with a red box highlighting the '启动' (Initiate) button for '产品A' (Product A) at '无锡宏达工厂' (Wuxi Hongda Factory).]()

**图 2.1-31 任务管理-04**

对任务进行【启动】，本例中仅对兴达工厂、宏远工厂进行任务启动，如图：

![Figure 2.1-32: Screenshot of the '任务管理-05' interface, showing the '任务启动' tab. It displays the status of task initiation. '产品A' (Product A) at '无锡宏达工厂' (Wuxi Hongda Factory) is marked as '已启动' (Initiated), highlighted by a red box. '产品B' (Product B) at '无锡宏达工厂' (Wuxi Hongda Factory) is marked as '已分配' (Assigned), highlighted by a blue box.]()

**图 2.1-32 任务管理-05**

任务分配并启动后，那么下一步就是接收到任务的主体要完成任务，即完成采购计划的预算填报工作。我们假设是无锡宏远工厂的相关人员接收到任务，打开【供应链】→【采购计划】→【EXCEL 功能】→【计划编制】，打开 EXCEL，选择“预算编制”页签，点击【任务下载】：

## Page 27

NC
大紫企业管理与电子商务平台

![Figure 2-1-33: A screenshot of a software interface titled 'NC' showing a task assignment view. The interface displays a table listing tasks for various users/roles (e.g., '张三', '李四'), including task names, planned time, and due time.]()

图 2-1-33 计划编制-01

我们可以看到刚才启动的两个任务，这里需要注意一个问题，就是为何宏远工厂的人可以看到其他任务，而不是仅仅是看到属于自己的任务呢？在本例中，没有对角色权限进行相关控制，所以如此。在实际业务中，我们可以通过角色与组织的对应关系来解决这个问题，读者可参考《产品手册—权限管理》，在此不赘述。

![Figure 2-1-34: A screenshot of a task table interface showing detailed task assignments. The table lists tasks like '张三任务 1', '李四任务 1', etc., along with planned time and due time.]()

图 2-1-34 计划编制-02

选择一个任务，【确定】后，就可以看到我们刚才编制的表格了：

## Page 28
![Excel spreadsheet template titled '计划编制-03' showing a table for budget allocation (元) across 11th and 12th months, with fields for total amount, unit price, and quantity.]()

### 图 2.1-35 计划编制-03

然后, 填写表格, 填好后【提交数据】

![Excel spreadsheet template titled '计划编制-04' showing completed budget allocation data for 11th and 12th months, including calculated values for total amount, unit price, and quantity.]()

### 图 2.1-36 计划编制-04

## Page 29

![NC logo]()
大型企业管理与电子商务平台

然后，提交审批。

![Screenshot of a financial software interface showing the 'Plan' section. A dialog box is open titled '提交审批' (Submit for Approval). The details shown are: Plan Type: 采购计划 (Purchase Plan); Approval Type: 请示 (Request); Approver: 刘经理 (Manager Liu); Plan Amount: 8,300.00; and a '提交' (Submit) button.]()

**图2.1-37 计划编制-05**

下一步就是各级相关人员对采购计划进行审批。若是在【任务管理】处加了审批流，就走对应的审批流。

本例略过，仅提示读者。路径【供应链】→【采购计划】→【采购计划审批】。

![Screenshot of the 'Purchase Plan Approval' interface. It shows a grid of pending approvals with columns for Approval Step, Approval Type, Approver, and Approval Status. The grid lists approvals for 刘经理 (Manager Liu) and 朱经理 (Manager Zhu), both pending approval. There is also a button labeled '审核提交' (Review and Submit) visible on the left.]()

**图2.1-38 计划审批-01**

## Page 30

NC

图 2.1-39 计划审批-02

同理，其他接收到任务的主体也按照以上步骤可完成采购计划填报。

### 2.1.4 计划对业务的控制

#### I. 业务描述

采购计划填报完毕，那么我们就要考虑——采购计划如何对后续业务进行指导或控制？采购计划控制分为：

1. 刚性控制：即强行控制，超出预算不允许业务再继续；
2. 柔性控制：超出预算将给出提示信息，并提示是否走特殊批准流程；
3. 预警型控制：超出预算将给出提示信息，但仍然允许业务发生；

#### II. 业务示例

接着上面的例子继续，以下仅简单演示“刚性控制”的效果。

#### III. 功能清单

| 领域 | 产品模块 | 功能节点 |
| --- | --- | --- |
| 供应链 | 采购计划 | 控制规则 |
| 供应链 | 采购计划 | 控制方案 |
| 供应链 | 采购管理 | 采购订单 |

## Page 31

## IV. 产品解决方案

这部分的详细应用介绍请参照《产品手册-全面预算》,本书主要示例给读者控制实现的基本方式和控制效果。路径【供应商】→【采购计划】→【控制规则】，选中我们之前定义的套表“维护品采购计划套表”，在打开的表单中选择一个单元格，此例中我们针对的目标是“12月对润滑油采购数量的控制”，选中单元格后点击【新增控制规则】，如图:

![Figure 2.1-40 shows a screenshot of the control rule interface. The left panel lists various control types, with '维护品采购计划' (Maintenance Item Procurement Plan) selected. The main panel displays a grid view for '润滑油采购计划' (Lubricant Procurement Plan), showing data for 11 and 12 months, with a red box highlighting a specific cell in the 12-month column.]()

图 2.1-40 控制规则-01

“控制类型”有三种，此例中我们选择【刚性控制】:

![Figure 2.1-41 shows a screenshot of the newly added control rule details. The control type is set to '刚性控制' (Rigid Control), the control value is '1000', and the comparison operator is '=' (equals).]()

图 2.1-41 控制规则-02

## Page 32

NC
大型企业管理与电子商务平台

简便起见,在本例中(控制数规则页签中的“预占数”和“执行数”的“单据类型”都选择[采购订单],
“取值内容”选择[数量],确定之后,发现该单元格变成了粉红色,代表设置成功。

![图 2.1-42 控制规则-03 截图。显示了一个表格界面，左侧有菜单栏。表格显示了2013年11月和12月的数据，包括采购计划、采购数量和执行数量。单元格被粉红色高亮，表示设置成功。]()

图 2.1-42 控制规则-03

同理,其他单元格可以做类似的设置,或是几个单元格联合起来一起设置,具体应用参照《产品手册-全面预算》。

规则设置好后,并不等于此方案已经生效,而是要通过【供应链】→【采购计划】→【控制方案】进行启用。注意,启用可以在列表状态下同时启用所有,也可以进入【切换】状态后针对单元格进行控制规则的启用。启用后,我们发现单元格变成了绿色:

![图 2.1-43 控制方案-01 截图。显示了控制方案设置界面，包含多个选项和复选框。单元格被绿色高亮，表示启用成功。]()

图 2.1-43 控制方案-01

## Page 33

![Figure 2.1-44: Control Plan interface. The table shows planning for November and December. For November, planned quantities (计划数量) for material 1 are 3,900, 1,300, and 2,000 respectively, with actual quantities (实耗数量) 3,900, 1,300, and 3,000. For December, planned quantities are 9,000, 9,000, and 8,000 respectively, with actual quantities 9,000, 9,000, and 0.]()

图 2.1-44 控制方案-02

控制方案设置成功后，下一步就是检验控制效果了。通过【供应商】→【采购管理】→【采购订单维护】新增一张订单。我们将物料润滑油的采购数量设置为 10（在采购计划中设置的预算数量为 6），在【审批】时，可以看到刚性控制的效果：

![Figure 2.1-45: Procurement Plan Business Control interface. The main screen displays the procurement plan and a red pop-up message detailing control violations for lubricating oil. The message states: '物料[润滑油]的计划数量: 采购计划数量[10]和采购计划日期[2012-12-20]的采购数量 - 采购计划日期[2012-12-20]的采购数量[6]不一致. 采购计划数量[10]大于采购计划预算数量[6]，请确认是否符合控制要求。' (Material [lubricating oil] plan quantity: Purchase plan quantity [10] and purchase plan date [2012-12-20] purchase quantity - Purchase plan date [2012-12-20] purchase quantity [6] are inconsistent. Purchase plan quantity [10] is greater than purchase plan budget quantity [6], please confirm whether it meets the control requirements.)]()

图 2.1-45 采购计划对业务进行控制

### 2.1.5 采购计划调整调剂

此部分可参照《产品手册-全面预算》中有关“预算调整”的章节，此处不再赘述。

## Page 34

**2.2 相关主题**

### 2.2.1 采购计划发布

#### I. 业务描述

计划发布是采购计划模块的重要功能之一,通过该节点,将批复生效的采购计划发布到电子商务模块;电子商务模块受理该发布,形成采购方案,即可按照采购方案做后续的采购业务。

图 2.2-01 采购计划发布流程图

![流程图：采购计划发布流程。采购计划阶段包含编制计划和批复计划。批复计划与编制计划相连，批复计划与计划发布阶段的发布计划相连。计划发布阶段包含发布计划和取消发布计划。发布计划与电子采购阶段的计划分配相连。计划分配与计划受理相连。]()
## Page 35

![Figure 2.2-02: Screenshot of the purchasing plan release interface (采购计划发布01). Shows a list of purchasing plans for various items (如 轴承, 电刷, 棉花, 灯泡, 等) for the year 2012. The interface allows selection and release of purchasing plans.]()

图 2.2-02 采购计划发布-01

进入【切换】状态，点击【发布电子商务】

![Figure 2.2-03: Screenshot of the purchasing plan release interface (采购计划发布-02). Shows a detailed table of purchasing plans for December (12月) and January (1月). Columns include 项目 (Project), 计划 (Plan), and budget/actual values for 12月 (December) and 1月 (January). Data shown includes: 轴承 (Bearing) 2000.00 / 4500.00; 电刷 (Brush) 1200.00 / 5000.00; 灯泡 (Light bulb) 2.00 / 5.00, 52000.00 / 60000.00; and 棉花 (Cotton) 0.00 / 6.00, -50000.00.]()

图 2.2-03 采购计划发布-02

注意: 只有为电子采购的物料或物料分类才可以发布到 EC。而不符合条件的计划行不可以发布到电子商务，则就会出现以下的情况:

## Page 36

**NC**大都会企业管理与电子商务平台

![Screenshot of a financial management platform (NC) showing a procurement plan table. The title bar reads '采购计划发布-03'. The table displays data for 2014 and 2015, broken down by product lines and amounts, and includes a warning message about the table being frozen to prevent data loss.]()

图 2.2-04 采购计划发布-03

## 2.2.2 计划预占及执行

### I. 业务描述

* 采购计划控制所针对的单据，目前支持的控制单据有：请购单、采购订单；如图：![Screenshot of a procurement control interface (NC) showing '请购单' and '采购订单' in the '计划控制设置' (Plan Control Settings). It allows enabling plan control for these documents, with options for '启用' (Enable) or '关闭' (Close), and associated field names like '请购单' and '采购订单'.]()

图 2.2-05 计划预占及执行-01

* 控制单据在审批时检查是否超预算，在审批通过时会形成对采购计划的预占；如果控制单据没有

## Page 37

大型企业管理与电子商务平台

NC

后续执行，则可以通过关闭操作释放对采购计划的预占。

* > 执行单据是相对控制单据而言，首先，执行单据必须是控制单据的后续单据，其次，控制单据可对应多个执行单据。
* > 执行单据关闭时，控制单据的预占数会释放，同时将执行单据的数量形成采购计划的执行数。
* > 执行单据可以是采购订单、到货单、库存采购入库单、采购发票；如图：

![Figure 2.2-06: A screenshot of the NC software interface showing two overlapping windows related to purchase planning. The main window (Purchase Order/Contract Control) shows 'Control Status' and 'Execution Status' (执行状态) highlighted in red. A submenu lists execution types: 321采购订单, 322到货单, 323发票, 324付款单, and 401库存采购入库单.]()

图 2.2-06 计划预占及执行-02

## Page 38

### 第三章 初始准备

![图 3-01 初始准备-01: 流程图。动态组织建模连接到安装预算Excel客户端。动态组织建模下级节点包括：业务单元、部门、采购计划体系。]()

图 3-01 初始准备-01

1. 动态组织建模请参见本手册“2.1.1 采购计划体系建立”。
2. 安装预算Excel客户端，才能进行本手册中EXCEL所实现的功能，如图：

![图 3-02 初始准备-02: 截图。显示了一个系统界面，左侧导航栏包含财务会计、资产管理、生产计划、资产管理、项目管理等模块。中间显示了不同管理类型的列表。右侧弹出窗口提示：【系统提示】下级预算Excel客户端。]()

图 3-02 初始准备-02

## Page 39

![NC logo]()

大型企业管理与电子商务平台

## 第四章 操作指南

本手册具体详细操作应用，请登录 NC 系统参见相关产品帮助。

用友网络科技股份有限公司

![Page number 38]()

## Page 40

附录

## 附录 1：接口说明

采购计划产品与其他 NC 产品模块的接口关系如下图所示：

![Diagram showing the interface relationship between modules. Plan platform (计划平台) leads to Build model (建模), which leads to Procurement Plan (采购计划). Procurement Plan receives input from Procurement Management (采购管理) via Execution Control (执行控制). Procurement Plan leads to Release (发布), which leads to E-commerce (电子商务).]()

附录 1-01 采购计划接口

1. 与计划平台接口
   * > 为采购计划编制提供必要的数据来源;
2. 与采购管理接口
   * > 采购计划控制后续采购单据的执行, 可通过查询采购计划了解采购单据的执行情况;
   * > 采购单据对采购计划占用数、执行数的回写;
3. 与电子商务接口
   * > 电子采购属性的物料或者物料分类的采购计划, 可以发布到电子商务;
   * > 发布到电子商务的采购计划, 可以取消发布;

## 附录 2：本文参见其他手册清单

| 序号 | 手册名称 | 备注 |
| --- | --- | --- |
| 1 | 《产品手册-全面预算》 |  |
| 2 | 《产品手册-电子采购》 |  |

## Page 41

大型企业管理与电子商务平台

![Logo showing three stylized figures holding hands, representing collaboration.]()

## 大型企业管理与电子商务平台

Large-scale Enterprise Management and E-business Solution Platform

用友网络科技股份有限公司

**用友**

用友网络科技股份有限公司

Yonyou Network Tech Co., Ltd.
