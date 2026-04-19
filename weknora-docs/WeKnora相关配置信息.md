**base_url**：http://172.16.100.211:18080
**健康检查**：http://172.16.100.211:18080/health
APIKEY: sk-S34V_exAGZCmplZSywqg0XsfoneZxBHku3o6AB8SH4f7oq9c
Neo4j 的访问地址是：

## 1) Neo4j 浏览器（Web 控制台）

- **URL**：`http://172.16.100.211:7474`
    

如果你在**其它电脑**访问（同一局域网），用运行 Neo4j 那台机器的 IP：

- `http://172.16.100.211:7474`
    

## 2) Neo4j Bolt（后端程序连接用）

- **Bolt URI**：`bolt://172.16.100.211:7687`
    

其它电脑/其它服务跨机器连接：

- `bolt://172.16.100.211:7687`
    

## 3) 你的 WeKnora 后端实际会用哪个

在 `./scripts/dev.sh app` 里会覆盖设置：

- `NEO4J_URI=bolt://172.16.100.211:7687`

# Neo4j的用户名和密码

NEO4J_USERNAME=neo4j

  

# Neo4j的密码

NEO4J_PASSWORD=neo4j123!@#