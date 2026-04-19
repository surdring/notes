# NCV6.5产品手册-供应商门户安装
## Page 1

yonyou

**NC**

产品手册- V6.5

---

供应商门户安装

yonyou

## Page 2

大型企业管理与电子商务平台

NC

---

## 版权

* 用友集团版权所有

未经用友集团的书面许可,本操作手册任何整体或部分的内容不得被复制、复印、翻译或缩减以用于任何目的。本操作手册的内容在未经通知的情形下可能会发生改变,敬请留意。请注意:本操作手册的内容并不代表用友软件所做的承诺。

## Page 3

# 配置文件

安装 V6 EC 安装盘后，有 2 个配置文件需要配置修改

**注意：**严格区分大小写

1) `ecconf.xml` 配置文件 (`ebpur` 电子采购在线竞价后台服务配置文件)

配置文件路径： `/nchome/modules/ebpur/config/ecconf.xml`

此文件只需在电子采购所在服务器对应 NCHOME 中配置（如服务器为集群，需要配置集群下各节点所在不同 NCHOME 路径下 `ecconf.xml` 文件）

文件内容如下：

```
<?xml version="1.0" encoding="UTF-8"?>
<jive>
  <locale>zh</locale>
  <setup>true</setup>
  <datasource>
    <oracle>design</oracle> // design: 数据源
    <!-- data source config example.
    <oracle>ec</oracle>1 <oracle>ec2</oracle>2 -->
  </datasource>
  <log>
    <debug>
      <enabled>true</enabled> // 设置为 true 则输出 debug 及以上级别日志，为 false 不输出 debug 级别日志，只输出 info 及以上级别日志。
    </debug>
  </log>
  <xmpp>
    <socket>
      <plain>
        <port>5222</port> //在线竞价通讯处理使用端口
      </plain>
    </socket>
    <xmpp>
      <serverip>20.10.10.58</serverip> //在线竞价通讯处理服务器 IP，在在线竞价通讯处理服务器 IP，如果 ebpur（电子采购）所在机器非集群，此处配置为 ebpur 安装机器所在机 IP，如果为集群，则此处配置为集群中某一具体节点的 IP，非集群 master 对外开放的 IP 及端口（即统一访问地址），同时 IP 必须使用真实 IP，不要使用 127.0.0.1（注意：集群部署方式中不同节点对应的 ecconf.xml 中该项均配置为同一真实 IP）
    </xmpp>
  </xmpp>
</jive>
```

## 二）`system.properties` 配置文件

配置文件所在路径：

## Page 4
```markdown
# nchome\hotwebs\ebvp\WEB-INF\conf\system.properties
文件内容如下：
mucaddress=20.10.10.58 //在线竞价通迅处理服务器 IP, 此处值必须与 ecfconf.xml 中
serverip 的值保持一致
ejbaddress=20.10.10.80 //如果 ebupr (电子采购) 所在机器非集群, 此处配置为 ebupr
安装机器所在机 IP 及中间件使用端口, 如果为集群, 则此处配置为对外开放的统一 IP 及端口
(即集群统一访问地址, 非某个具体节点的访问地址), 同时 IP 必须使用真实 IP, 不要使用
datasource=design //数据源
accountcode=develop //系统编码, 即登录时所选择的系统名称所对应的系统编码
ca\_factory=itrus //供应商门户的 CA 认证厂商, 取值范围: itrus 或 infosec 对应厂商分别为: "天威诚信"、"信安世纪"
integration\_sys=NCSYS //如果使用 NC 系统则配置为 NCSYS, 如果使用 NCVS 与 NCV6 系统通过
ESB 集成模式, 则需要配置为 ESBSYS
\*\*a) 电子采购、供应商门户访问地址均在同一 IP\*\*
NC V6 电子商务-电子采购: http://20.1.1.8
NC V6 供应商门户: http://201.1.8/ebvp
如上访问方式, 如非集群部署则按前述描述配置 20.1.1.8 服务器的 system.properties 即可, 如
为集群部署则需要配置集群下各节点所在不同 NCHOME 路径下 system.properties 文件。
\*\*b) 电子采购、供应商门户访问地址在不同 IP\*\*
NC V6 电子商务-电子采购: http://20.1.1.8
NC V6 供应商门户: http://201.1.9/ebvp
如上访问方式, 如非集群部署则按前述描述配置不同 IP 所在服务器上的 system.properties, 即
两台服务器 system.properties 均需配置。如 1.8 为集群部署, 则需要配置该集群下各节点所在
不同 NCHOME 路径下 system.properties 文件; 如 1.9 也为集群部署则同样需要配置该集群下各
节点所在不同 NCHOME 路径下 system.properties 文件。
```
## Page 5

## 附录

### 附录 1：参见其他手册清单

| 序号 | 手册名称 | 备注 |
| --- | --- | --- |
| 1 | 《产品手册-电子采购》 |  |

## Page 6

![NC logo]()
NC

大型企业管理与电子商务平台

![Stylized graphic of three figures holding hands, representing collaboration.]()

## 大型企业管理与电子商务平台

Large-scale Enterprise Management and E-business Solution Platform

用友网络科技股份有限公司

![Yonyou logo]()
用友

Yonyou

用友网络科技股份有限公司

Yonyou Network Tech Co., Ltd.

![Small triangular graphic pointing down]()
