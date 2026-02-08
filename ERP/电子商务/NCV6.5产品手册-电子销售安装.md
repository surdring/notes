# NCV6.5产品手册-电子销售安装
## Page 1

yonyou

**NC**

---

产品手册- V6.5

# 电子销售安装

用友网络科技股份有限公司

yonyou

## Page 2

版权

* 用友集团版权所有

未经用友集团的书面许可，本操作手册任何整体或部分的内容不得被复制、复印、翻译或缩减以用于任何目的。本操作手册的内容在未经通知的情形下可能会发生改变，敬请留意。请注意：本操作手册的内容并不代表用友软件所做的承诺。

## Page 3
# 目录
| 版权 | 1 |
| :--- | --- |
| 1 | 环境要求 | 3 |
| 2 | 产品安装 | 3 |
| 2.1 | 单机环境 | 3 |
| 2.1.1 | 单机集成 | 3 |
| 2.1.2 | 单机分离 | 5 |
| 2.2 | 集群环境 | 7 |
| 2.2.1 | 集群集成 | 7 |
| 2.2.2 | 集群分离 | 10 |
| 2.3 | 索引配置 | 14 |
| 2.3.1 | 配置索引数据源 | 14 |
| 2.3.2 | 解决索引创建失败 | 15 |
| 3 | 集成 CA 认证 | 15 |
| 3.1 | 门户登陆 CA 认证配置 | 15 |
| 3.2 | 门户在线支付的 CA 认证配置 | 16 |
| 4 | 集成 ICC | 16 |
| 5 | 集成经销商助手 APP | 17 |
| 6 | AIX 系统配置 | 17 |
| 7 | 隐藏门户上维护收货地址功能 | 17 |
| 8 | 常见问题 | 17 |
| 9 | 附录 1: was 配置 jvm 参数 | 17 |
## Page 4

大商企业管理和电子商务平台

## 1 环境要求

同 NC。

## 2 产品安装

### 2.1 单机环境

#### 2.1.1 单机集成

经销商门户 (ECP) 和 NC 后台部署在一台 UAPServer 服务器或者 WAS 服务器上，如图表 1。

安装电子销售的所有模块的代码，即可直接使用。

![图表1: 单机集成结构图。图中显示 UAPServer/WAS 应用服务器（绿色方框）部署在一台服务器上。UAPServer/WAS 连接至数据库（灰色圆柱体）。UAPServer/WAS 内部包含三个模块：经销商门户、NC 后台和应用服务器。经销商门户和 NC 后台均通过应用服务器与外部交互（用三个小圆圈表示的连接点）。]()

图表 1

* **安装后：**

  需要做如下配置。

  1. 修改 \u001c/home/HotWeb/ecp/WEB-INF/classes 下 eccp\system.properties 文件

     ```
     #NC 服务器地址
     ejbaddress= (NC 后台服务器地址, 需要带端口号 例如: 192.168.125.27:80)

     #对应的 NC 数据源
     datasource=(NC 后台数据库的数据源)

     #对应的 NC 帐套编码
     accountcode=(NC 后台帐套)
     ```
  2. 登录 NC 后台

     打开节点【业务参数设置-集团】, 选择【电子商务】-【电子销售】。

     更改参数【经销商门户 IP 地址】的参数值为 NC 后台服务器 ip。

     如图表 3

## Page 5

![NC Logo]()

大宏企业管理与电子商务平台

![NC system configuration screen showing port settings for various components like 服务端口设置, 客户端口设置, and 服务端口设置(SSL).]()

图 2

用友新道科技有限公司

备注:

服务器通信默认使用 9011 端口，如果端口被占用需要使用其他端口。需要做如下更改：

1. 修改 \uchome\hotweb\scsp\WEB-INF\classes \Fccp\system.properties 文件

   更改前
   web.com.port=9011
   更改后
   web.com.port=（未被使用的端口）
2. 登录 NC 后台

   打开节点【业务参数设置-集团】，选择【电子商务】-【电子销售】。
   更改参数【经销商门户管理端口】的参数值为 第一步配置的端口号。如图 4

## Page 6

![NC logo]()

大企业管理和电子商务平台

![Figure 3: Screenshot of the NC ERP interface showing modules like 采购管理 (Procurement Management) and 销售管理 (Sales Management).]()

图 3

**注:** 以下【ECF】和【经销商门户】同义。

## 2.1.2 单机分离

经销商门户和 NC 后台分离部署，分别部署在二台单独的 UAPServer 或 WAS 服务器上。

如图表 2

![Figure 4: Diagram showing the architecture for single-machine separation. The diagram illustrates that the 经销商门户 (Dealer Portal) and NC 后台 (NC Backend) components are deployed on two separate application servers (UAPServer/WAS), which communicate with each other via 远程通信, 资源同步 (Remote Communication, Resource Synchronization). Both components also connect to a central 数据库 (Database).]()

图 4

这时安装和配置有所不同。注意事项如下：

◆ **安装时:**

1. 首先在经销商门户服务器上安装 uap 和 EC 下的以下三个模块
   1. EC10 UAP 电子商务平台

## Page 7

大拿企业管理与电子商务平台

NC

1. 2) EC14 电子商务 WEB 应用公共项目
2. 3) EC40 经销商门户

2: 然后再 NC 后台服务器上安装 EC 下的如下模块

1. EC10 UAP 电子商务平台
2. EC12 电子商务后台应用公共项目
3. EC15 电子销售基本档案
4. EC30 电子销售
5. EC50 订单处理中心
6. EC60 订单处理中心自身执行系统
7. EC70 订单处理中心 NC 集成实现
8. EC72 客户要货计划

♦ 安装后:

因为两台服务器需要通信,所以需要做如下配置。

1: 修改【经销商门户服务器】的 /uhome/hotwebs/ecp/WEB-INF/classes 下 cpsystem.properties 文件

```
#NC 服务器地址
ejbaddress=NC 后台服务器地址,需要带端口号 例如: 192.168.125.27:80

#对应的 NC 数据源
datasource=NC 后台数据库的数据库源

#对应的 NC 帐套编码
accountcode=NC 后台帐套
```

2: 登录 NC 后台

打开节点【业务参数设置-集团】,选择【电子商务】-【电子销售】。

更改参数【经销商门户 IP 地址】的参数值为 **(NC 后台服务器 ip 地址:经销商门户服务器的 ip 地址)**,两个 ip 地址用分号隔开。

如表 3(a 后台访问地址是 192.168.125.27:80,分部署的门户网站地址是 192.168.125.26:80)

| 参数代码 | 参数名称 | 参数值 |
| --- | --- | --- |
| ES04 | 经销商门户 IP 地址 | 192.168.125.27;192.168.125.26 |
| ES05 | 经销商门户网站端口 | 80:80 |
| ES06 | 经销商门户管理端口 | 9011:9011 |

图表 5

备注:

服务器通讯默认使用 9011 端口,如果端口被占用需要用其他端口。需要做如下更改:

1: 修改【经销商门户服务器】的 /uhome/hotwebs/ecp/WEB-INF/classes 下 cpsystem.properties 文件

```
更改前
web.com.port=9011
更改后
web.com.port= (未被使用的端口)
```

2: 登录 NC 后台

打开节点【业务参数设置-集团】,选择【电子商务】-【电子销售】。

更改参数【经销商门户网站管理端口】的参数值为 第一步配置的端口号。如图 4


## Page 8

![NC logo]()

大型企业管理与电子商务平台

![Screenshot of the NC application interface showing server status and a warning message: '服务器内存不足' (Insufficient server memory). This is identified as Figure 6.]()

图表 6

## 2.2 集群环境

### 2.2.1 集群集成

集群集成分为垂直集群和水平集群两种情况

#### 2.2.1.1 垂直集群

垂直集群：一台物理机上安装一个 WAS 服务器，一个 WAS 服务器启动多个 JVM 节点，如图 5

## Page 9

![NC logo]()

大型企业级管理与电子商务平台

南京金恒科技有限公司

![Architectural diagram showing the UAPServer(WAS) application server (vertical cluster) running on a single machine (multiple nodes), connected to an NC backend and a database. The diagram illustrates a single machine hosting multiple nodes (master, node1, node2) with their respective ports (经销商门户, NC后台) accessible via external connections.]()

图表 7

#### 配置说明

1: 这种环境下每个节点运行在单独的 JVM 虚拟机上, 但是在同一台物理机上, 因此如果都是用同一个通信端口会导致冲突, 因此需要配置通信端口。

给每个节点的 JVM 虚拟机配置参数 -Dweb.com.port=端口号
每个节点的端口不同。例如:

master 节点 参数如: -Dweb.com.port=9011

node1 节点 参数如: -Dweb.com.port=9012

node2 节点 参数如: -Dweb.com.port=9013

备注: 关于如何添加 JVM 参数, 可参考附录2章节

2: 因为节点间需要数据同步, 因此需要注册节点的端口, 如图 6

集成安装: 所以 ip 地址是 127.0.0.1;

垂直集群: 所以 ip 地址都相同, 但是端口各不同。

经销商门户访问端口设置: 如图 6 中的 80.81.82, 其中 80 需要和【经销商门户服务器】的 /home/hotweb/ecp/WEB-INF/classes 下 ecp system.properties 文件中的 ejb address 的端口保持一致, 其他端口只需和 80 不相同即可。

ecpsystem.properties 配置: 需要将 /home/hotweb/ecp/WEB-INF/classes 下的 ecp system.properties 文件中的 web.com.port = 9011 注释掉, 如改成# web.com.port = 9011

## Page 10

![NC logo]()大型企业管理与电子商务平台

![Screenshot of the NC management platform interface showing logs and configuration options.]()

图表 8

## 2.2.1.2 水平集群

水平集群，多台物理机，每个物理机上有一个 UAPServer 或者 WAS 服务器。共同组成一个集群，如图7

![Diagram illustrating a Horizontal Cluster (水平集群) architecture. It shows three physical machines, each running a UAPServer/WAS application server with an independent NCS3 instance and a corresponding HTTP port. All three servers connect to a shared Database.]()

图表 9

配置说明：

这种环境下，每台机器是单独的，因此不存在端口冲突问题，可以都使用默认的 9011 端口。只需要注册一下集群节点的 ip 即可。如图 8

## Page 11

![Screenshot of the NC (New Century) Enterprise Management System interface, showing a list of system components, configurations, and a highlighted error message related to security services (security services are not activated or installed).]()

图表 10

## 2.2.2 集群分离

门户和后台分离部署，后台是否集群不影响门户，所以不再关注后台的集群情况。重点关注门户的垂直和水平集群。

### 2.2.2.1 垂直集群

门户分离部署，垂直集群，如图 9

## Page 12

![图 11: 系统架构图。左侧显示三个会话图标分别指向三个蓝色框，每个框内包含一个master和一个店铺名（如店铺名(16)）。中间是一个绿色框，标记为UAPServer/W AS 应用服务器，内部包含NC后台。右侧是一个绿色圆柱体，标记为数据库。整个流程表示用户会话通过店铺服务器与应用服务器和数据库交互。]()

图 11

因为分离部署和集群安装，所以门户需要做如下配置。
分离部署：安装时参照【2.1.1 单机分离】。

### ◆ 安装时：

1. 首先在经销商门户服务器上安装 uap 和 EC 下的以下三个模块
   1. EC10 UAP 电子商务平台
   2. EC14 电子商务 WEB 应用公共项目
   3. EC40 经销商门户
2. 然后再 NC 后台服务器上安装 EC 下的如下模块
   1. EC10 UAP 电子商务平台
   2. EC12 电子商务后台应用公共项目
   3. EC15 电子销售基本档案
   4. EC30 电子销售
   5. EC50 订单处理中心
   6. EC60 订单处理中心自身执行系统
   7. EC70 订单处理中心 NC 集成实现
   8. EC72 客户要货计划

### ◆ 安装后：

因为两台服务器需要通信，所以需要做如下配置。

1. 修改【经销商门户服务器】的 \uhome\hotwebs\ecp\WEB-INF\classes 下 cc\system\properties 文件

   ```
   #NC 服务器地址
   ejbaddress=(NC 后台服务器地址, 需要带端口号 例如: 192.168.125.27:80)
   #对应的 NC 数据源
   datasource=(NC 后台数据库的数据源)
   #对应的 NC 帐套编码
   accountcode=(NC 后台帐套)
   ```

## Page 13

**NC** 大型企业管理与电子商务平台

**管理端口**

```
#web.com.port = 9011 (垂直集群需要将此行注释掉, 如当前所显示前面添加#)
```

2、给每个节点的 JVM 虚拟机配置参数 -Dweb.com.port=端口号
每个节点的端口不同，例如：

master 节点 参数如: -Dweb.com.port=9011
node1 节点 参数如: -Dweb.com.port=9012
node2 节点 参数如: -Dweb.com.port=9013

3、登录 NC 后台
打开节点【业务参数设置-集团】，选择【电子商务】-【电子销售】
更改三个参数，配置如图10

![图12：NC平台后台的业务参数设置界面截图。左侧显示参数列表，右侧显示详细配置。红色框标出三个需要更改的参数：营业员、地市、以及一个与销售相关的参数。界面显示了参数名称、当前值、建议值、生效时间等信息。界面顶部有搜索和过滤选项。]()<table border=

## Page 14

#### 2.2.2.2 水平集群

![图 13 经销商门户水平集群部署示意图。左侧显示多个用户通过网络连接到一个“水平集群,多台机器”。该集群包含三个实例：uapServer/wA11 (经销商门户), uapServer/wA12 (经销商门户), 和 uapServer/wA13 (经销商门户)。这三个实例通过一个绿色的双向箭头连接到右侧的“[UAPServer/WAS] 应用服务器 NC后台”，后者再连接到一个“数据库”。整个部署模式为经销商门户水平集群，分离部署。]()
## Page 15

2. 登录NC后台

打开节点【业务参数设置-集团】，选择【电子商务】-【电子销售】，更改参数，配置如图 12

![图 12 NC后台配置界面，显示了电子商务设置下的参数列表，包括设置默认税率、设置默认税率类型等选项。]()

## 2.3 索引配置

### 2.3.1 配置索引数据源

该索引针对经销商门户，与门户网站商品相关。

通过 UAP 配置工具（nc/home/bin/syacconfig.bat）搜索引擎->搜索源分组内的 cecpGroup->cecSource 节点与 cecp->product 节点，设置数据源，选择当前系统所用数据源。

注：当更改数据源后需要重新配置。

如下图 15 所示：

## Page 16

# NC

大型企业管理与电子商务平台

北京木奇林软件股份有限公司

![A screenshot of the NC software's 'Basic Search Source' configuration window. The left navigation panel shows 'Search Source Configuration' under 'Basic Configuration'. The main window displays a list of fields under 'Search Source Config', with 'nc_product' highlighted. To the right, fields like 'Search Source' (ncProduct), 'Name (in English)' (电子销售清单), 'Name (in Chinese)' (电子销售清单), and 'Description' (商品) are visible. A 'Search Condition' section shows 'AND' logic and parameters like 'name' and 'code', with 'name' circled.]()

图表 15

### 2.3.2 解决索引创建失败

如遇到索引创建失败导致经销商门户无法查询到商品的问题，可先将 nchome/antindex/server 文件夹删除，正确配置索引源分组中的参数后重启服务，稍等约 2 分钟后可自动创建索引文件，此时可在搜索管理中重现全部索引数据，重新启用商品后即可。

## 3 集成 CA 认证

前提: 企业购买了信安或天威的 CA 产品。

### 3.1 门户登陆 CA 认证配置

如果企业需要使用 CA 认证，需要进行以下配置：

1. 修改 nchome/portal/web/component/webpub/btools/sca.js

#### 修改前

`var ca = null;`

如果是与信安做集成，修改后

`var ca = "infosec";`

## Page 17

如果是与天威做集成，修改后

var ca = "irtus";

2、修改 /nchome/hotwebs/ecp/WEB-INF/classes/ecpsystem.properties

修改前

#ca = irtus

如果是与信安做集成，修改后

ca = infosec

如果是与天威做集成，修改后

ca = irtus

注: 两个文件配置厂商保持一致，要么都是信安，要么都是天威。如果配置不一致，则 CA 不生效。

### 3.2 门户在线支付的 CA 认证配置

如果企业需要使用在线支付 CA 认证，需要进行以下配置:

1、修改 /nchome/hotwebs/web/component/webpub/tools/eca.js

修改前

var payca = null

如果是与信安做集成，修改后

var payca = "infosec";

如果是与天威做集成，修改后

var payca = "irtus";

2、修改 /nchome/hotwebs/ecp/WEB-INF/classes/ecpsystem.properties

修改前

#payca = irtus

如果是与信安做集成，修改后

payca = infosec

如果是与天威做集成，修改后

payca = irtus

注: 两个文件配置厂商保持一致，要么都是信安，要么都是天威。如果配置不一致，则 CA 不生效。

## 4 集成 ICC

前提: 企业购买了用友 ICC 产品，即：互联网呼叫中心。

如果企业需要在经销商门户中使用 ICC，需要进行以下配置:

修改 /nchome/hotwebs/ecp/WEB-INF/classes/ecpsystem.properties

修改前

#icc=

修改后

icc= 添加友联ICC生成访问地址 (类似<http://icc>服务器ip:端口号)/web/code/code.jsp?c=1&&1)

## Page 18

如果需要使用经销商助手APP,需要在\inhome\hotweb\ecp\WEB-INF\classes\ecpsystem.properties文件中修改 maserver 的值(外网能够访问的ip+端口号)

#MA 服务器地址 v633 版以后的经销商助手需要调用 maserver=172.16.50.250:80

## 6 AIX 系统配置

当服务器使用 aix 操作系统时需要打开 ecpsystem.properties 把 isAix=false 修改成 isAix=true

## 7 隐藏门户上维护收货地址功能

打开 hotweb\ecp\web-inf\classes\ccpui.properties iscustomaddrdeditable = true 改成 iscustomaddrdeditable = false

## 8 常见问题

1. 图片上传不上去,索引更新不了问题.

   答:检查远程通信端口是否被占用,默认9011端口.

## 9 附录 1: was 配置 jvm 参数

was 控制台 master

## Page 19

![Screenshot of the NC integrated solutions console showing the 'Integrated Solutions Console - WebSphere Settings' tab. It lists several managed servers with their host name, node, IP address, version, and status. The highlighted server is 'node01 node01 10.13.16.148 7.0.15 node01er'.]()

在 JVM 参数未尾增加如图: -Dweb.com.port=9011

![Screenshot of the NC integrated solutions console showing the 'Integrated Solutions Console - WebSphere Settings' tab. It lists several managed servers with their host name, node, IP address, version, and status. The highlighted server is 'node01 node01 10.13.16.148 7.0.15 node01er'. Below the list, the 'Additional JVM options' field contains the text '-Dweb.com.port=9011'.]()

ncMem01

## Page 20

**NC**

大金企业管理与电子商务平台

---

IBM

![Screenshot of IBM WebSphere Application Server (WAS) administration console. The top section shows 'Integrated Solutions Console - Welcome to the Deployment Manager'. The navigation path is 'Welcome home -> Manage Nodes -> Manage Applications'. The application overview table lists four applications (JSPHello, JSPHello2, JSPHello3, JSPHello4). JSPHello and JSPHello2 are running, while JSPHello3 and JSPHello4 are stopped. A warning box below the table states: This page lists only a list of the application servers in your environment and the status of each of these servers. You can also use this page to change the status of a specific application server. The application details table shows the node, server, application, module, version, cluster name, and status for each application.]()
![Screenshot of IBM WebSphere Application Server (WAS) administration console. The top section shows 'Integrated Solutions Console - Welcome to the Deployment Manager'. The navigation path is 'Welcome home -> Manage Nodes -> Manage Applications'. The application overview table lists four applications (JSPHello, JSPHello2, JSPHello3, JSPHello4). JSPHello and JSPHello2 are running, while JSPHello3 and JSPHello4 are stopped. The application details table shows the node, server, application, module, version, cluster name, and status for each application.]()

**在 JVM 参数末尾增加如图：-Dweb.com.port=9012**

![Screenshot of IBM WebSphere Application Server (WAS) administration console. The top section shows 'Integrated Solutions Console - Welcome to the Deployment Manager'. The navigation path is 'Welcome home -> Manage Nodes -> Manage Applications'. The application overview table lists four applications (JSPHello, JSPHello2, JSPHello3, JSPHello4). JSPHello and JSPHello2 are running, while JSPHello3 and JSPHello4 are stopped. The application details table shows the node, server, application, module, version, cluster name, and status for each application. The application details section displays detailed configuration for JSPHello2, showing JVM arguments including the line: -Dweb.com.port=9012.]()

ncMem02

## Page 21

**NC**

大企业级管理与电子商务平台

---

![Screenshot of the NC Integrated Solutions Console showing JVM settings. The console displays a list of applications (Data, TempFile, Imp, Imp, Imp) with their respective class, module, and version details.]()

在 JVM 参数末尾增加如图：`-Dweb.com.port=9013`

![Screenshot of the NC Integrated Solutions Console showing JVM parameters. The command line includes -Dweb.com.port=9013, which is highlighted.]()

ncMemo03

## Page 22

### 大拿企业管理与电子商务平台

![Screenshot of the Integrated Solutions Console (ISC) showing application servers, configurations, and logs. The console displays a list of applications and their status (e.g., WebSphere Application Server, WebSphere Process Server).]()

#### 在 JVM 参数末尾增加如图：Dweb.com.port=9014

![Screenshot of the Integrated Solutions Console (ISC) showing server configuration details, including JVM arguments. A specific line is highlighted: -Dcom.ibm.ws.http.maxHeaderSize=4096 -Dweb.com.port=9014]()

配置文件 Ecosystem.properties 需要注释掉 web.com.port=9011 这一行 每个 server 都要重复上述操作增加-Dweb.com.port=端口号，端口号不能重复

## Page 23

![NC logo]()

大型企业管理与电子商务平台

![Stylized figures logo]()

大型企业管理与电子商务平台

Large-scale Enterprise Management and E-business Solution Platform

![Yonyou logo]()

用友网络科技股份有限公司

Yonyou Network Tech Co. Ltd.
