GangQing 技术设计文档 (TDD)
项目名称： GangQing —— 钢铁工业全域认知决策系统
文档版本： v1.0
编制日期： 2026-02-15
文档状态： Draft

目录
系统概述
技术架构设计
核心模块设计
数据架构设计
AI 引擎设计
接口设计
安全架构设计
部署架构
性能与可靠性设计
开发规范与工具链
测试策略
运维与监控
1. 系统概述
1.1 系统定位
GangQing 是一个基于私有化大语言模型（LLM）的工业 Agent 系统，旨在成为钢铁厂全域数据的统一智能交互入口，解决传统工业信息化系统（ERP、MES、DCS、LIMS、EAM）数据孤岛、操作复杂、决策滞后的问题。

1.2 核心设计原则
安全第一（Safety First）：所有写操作必须经过多重验证，默认只读模式
证据驱动（Evidence-Based）：每个 AI 输出必须附带可追溯的数据来源
人机协同（Human-in-the-Loop）：AI 作为副驾驶，人类保留最终决策权
私有化部署（On-Premise）：数据不出厂，模型本地运行
渐进式演进（Progressive Enhancement）：从只读查询 → 诊断分析 → 决策辅助 → 受控执行
1.3 技术栈选型
| 层级 | 技术选型 | 理由 | |------|---------|------| | 前端 | React 19 + TypeScript + Vite | 现代化、类型安全、开发效率高 | | UI 框架 | Tailwind CSS + Lucide Icons | 工业暗黑风格定制、轻量级 | | 图表库 | Recharts | 声明式、易定制、支持复杂工业图表 | | 后端框架 | FastAPI (Python) | 异步高性能、与 AI 生态无缝集成 | | AI 引擎 | LangChain + LangGraph | 成熟的 Agent 编排框架 | | 大模型 | Qwen2.5-72B-Instruct (私有化部署) | 中文能力强、支持 Function Calling | | 向量数据库 | Milvus | 开源、高性能、支持混合检索 | | 时序数据库 | TDengine | 专为工业物联网设计 | | 关系数据库 | PostgreSQL | 成熟稳定、支持 JSONB | | 消息队列 | RabbitMQ | 可靠性高、支持优先级队列 | | API 网关 | Kong | 企业级、支持细粒度权限控制 | | 容器编排 | Kubernetes (K3s) | 轻量级、适合边缘部署 | | 监控 | Prometheus + Grafana | 工业标准、可视化强 |

2. 技术架构设计
2.1 整体架构图

```markdown
┌─────────────────────────────────────────────────────────────────┐
│                        交互层 (Presentation)                      │
├─────────────────────────────────────────────────────────────────┤
│  PC Web (React)  │  Mobile App (React Native)  │  Voice (ASR)   │
└────────────┬────────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────────┐
│                      API 网关 (Kong Gateway)                      │
│  ┌──────────────┬──────────────┬──────────────┬──────────────┐  │
│  │ 认证/鉴权    │ 限流/熔断    │ 审计日志     │ 路由转发     │  │
│  └──────────────┴──────────────┴──────────────┴──────────────┘  │
└────────────┬────────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Agent 编排层 (Orchestration)                   │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────────────┐   │
│  │           LangGraph State Machine (核心大脑)              │   │
│  │  ┌────────────┬────────────┬────────────┬────────────┐   │   │
│  │  │ 意图识别   │ 工具路由   │ 证据生成   │ 安全网关   │   │   │
│  │  └────────────┴────────────┴────────────┴────────────┘   │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    RAG 检索增强模块                        │   │
│  │  ┌────────────┬────────────┬────────────┬────────────┐   │   │
│  │  │ 设备手册   │ 故障案例   │ 工艺规范   │ SOP 文档   │   │   │
│  │  └────────────┴────────────┴────────────┴────────────┘   │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                   Function Calling 工具链                  │   │
│  │  ┌────────────┬────────────┬────────────┬────────────┐   │   │
│  │  │ ERP 查询   │ MES 查询   │ DCS 查询   │ EAM 查询   │   │   │
│  │  └────────────┴────────────┴────────────┴────────────┘   │   │
│  └──────────────────────────────────────────────────────────┘   │
└────────────┬────────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────────┐
│                      模型推理层 (Inference)                       │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Qwen2.5-72B (vLLM 加速)  │  Embedding Model (BGE-M3)   │   │
│  └──────────────────────────────────────────────────────────┘   │
└────────────┬────────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────────┐
│                      数据基座层 (Data Layer)                      │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────┬──────────────┬──────────────┬──────────────┐  │
│  │ 统一语义层   │ 向量数据库   │ 时序数据库   │ 关系数据库   │  │
│  │ (Semantic)   │ (Milvus)     │ (TDengine)   │ (PostgreSQL) │  │
│  └──────────────┴──────────────┴──────────────┴──────────────┘  │
└────────────┬────────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    外部系统集成层 (Integration)                   │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────┬──────────┬──────────┬──────────┬──────────────┐   │
│  │ SAP ERP  │ 宝信MES  │ PCS7 DCS │ LIMS     │ Maximo EAM   │   │
│  └──────────┴──────────┴──────────┴──────────┴──────────────┘   │
└─────────────────────────────────────────────────────────────────┘

```
2.2 数据流设计
2.2.1 查询类请求流程（只读）
```
用户输入 → API网关(鉴权) → Agent编排层(意图识别) 
  → RAG检索(知识库) + Function Calling(调用ERP/MES API) 
  → LLM生成回答 → 证据链生成 → 返回前端

```

2.2.2 写操作请求流程（受控）

```
用户输入 → API网关(鉴权) → Agent编排层(意图识别) 
  → 安全网关(红线检查) → 生成草案 → 人工审批 
  → 多签确认 → 写操作执行 → 审计日志 → 返回结果

```

3. 核心模块设计
3.1 Agent 编排引擎 (Orchestration Engine)
3.1.1 状态机设计（基于 LangGraph）

```
from langgraph.graph import StateGraph, END
from typing import TypedDict, Annotated, Sequence
import operator

class AgentState(TypedDict):
    """Agent 状态定义"""
    messages: Annotated[Sequence[BaseMessage], operator.add]
    intent: str  # 'query' | 'analysis' | 'alert' | 'action'
    user_role: str  # 'manager' | 'scheduler' | 'maintenance'
    evidence_chain: list[Evidence]
    tool_calls: list[ToolCall]
    safety_check: dict
    confidence: float
    
def build_agent_graph():
    workflow = StateGraph(AgentState)
    
    # 节点定义
    workflow.add_node("intent_classifier", classify_intent)
    workflow.add_node("rag_retrieval", retrieve_knowledge)
    workflow.add_node("tool_executor", execute_tools)
    workflow.add_node("safety_guard", check_safety)
    workflow.add_node("llm_generator", generate_response)
    workflow.add_node("evidence_builder", build_evidence_chain)
    
    # 边定义（状态转移）
    workflow.set_entry_point("intent_classifier")
    
    workflow.add_conditional_edges(
        "intent_classifier",
        route_by_intent,
        {
            "query": "rag_retrieval",
            "action": "safety_guard",
            "analysis": "tool_executor"
        }
    )
    
    workflow.add_edge("rag_retrieval", "tool_executor")
    workflow.add_edge("tool_executor", "llm_generator")
    workflow.add_edge("safety_guard", "llm_generator")
    workflow.add_edge("llm_generator", "evidence_builder")
    workflow.add_edge("evidence_builder", END)
    
    return workflow.compile()

```

3.1.2 意图识别模块
```
from pydantic import BaseModel

class Intent(BaseModel):
    type: Literal["query", "analysis", "alert", "action"]
    domain: Literal["production", "maintenance", "cost", "quality"]
    risk_level: Literal["low", "medium", "high"]
    requires_approval: bool

async def classify_intent(state: AgentState) -> AgentState:
    """使用小模型快速分类意图，降低成本"""
    user_message = state["messages"][-1].content
    
    # 使用 Qwen2.5-7B 进行意图分类（快速、低成本）
    prompt = f"""
    分析用户意图，返回 JSON：
    用户输入：{user_message}
    
    返回格式：
    {{
        "type": "query|analysis|alert|action",
        "domain": "production|maintenance|cost|quality",
        "risk_level": "low|medium|high",
        "requires_approval": true|false
    }}
    """
    
    result = await small_llm.ainvoke(prompt)
    intent = Intent.parse_raw(result)
    
    state["intent"] = intent.type
    state["safety_check"]["risk_level"] = intent.risk_level
    
    return state

```

3.2 RAG 检索增强模块
3.2.1 知识库架构
```
from langchain.vectorstores import Milvus
from langchain.embeddings import HuggingFaceEmbeddings

class KnowledgeBase:
    """工业知识库管理"""
    
    def __init__(self):
        self.embedding_model = HuggingFaceEmbeddings(
            model_name="BAAI/bge-m3",
            model_kwargs={'device': 'cuda'}
        )
        
        # 分域知识库
        self.collections = {
            "equipment_manual": Milvus(
                collection_name="equipment_docs",
                embedding_function=self.embedding_model
            ),
            "fault_cases": Milvus(
                collection_name="fault_history",
                embedding_function=self.embedding_model
            ),
            "process_sop": Milvus(
                collection_name="process_standards",
                embedding_function=self.embedding_model
            )
        }
    
    async def hybrid_search(
        self, 
        query: str, 
        domain: str,
        top_k: int = 5
    ) -> list[Document]:
        """混合检索：向量相似度 + 关键词匹配"""
        
        # 向量检索
        vector_results = await self.collections[domain].asimilarity_search(
            query, k=top_k
        )
        
        # BM25 关键词检索（补充）
        keyword_results = await self.bm25_search(query, domain, k=top_k)
        
        # RRF (Reciprocal Rank Fusion) 融合
        merged = self.rrf_merge(vector_results, keyword_results)
        
        return merged[:top_k]

```

3.2.2 文档预处理 Pipeline

```
from langchain.text_splitter import RecursiveCharacterTextSplitter

class DocumentProcessor:
    """工业文档预处理"""
    
    def __init__(self):
        self.splitter = RecursiveCharacterTextSplitter(
            chunk_size=512,
            chunk_overlap=50,
            separators=["\n\n", "\n", "。", "；", "，"]
        )
    
    async def process_equipment_manual(self, pdf_path: str):
        """处理设备手册 PDF"""
        
        # 1. OCR 提取（支持扫描件）
        raw_text = await self.ocr_extract(pdf_path)
        
        # 2. 结构化解析（识别章节、表格、图片）
        structured = await self.parse_structure(raw_text)
        
        # 3. 实体识别（设备型号、参数范围）
        entities = await self.extract_entities(structured)
        
        # 4. 分块 + 元数据增强
        chunks = self.splitter.split_text(structured)
        
        documents = []
        for chunk in chunks:
            doc = Document(
                page_content=chunk,
                metadata={
                    "source": pdf_path,
                    "equipment_model": entities.get("model"),
                    "parameters": entities.get("params"),
                    "doc_type": "manual"
                }
            )
            documents.append(doc)
        
        # 5. 向量化并存储
        await self.kb.collections["equipment_manual"].aadd_documents(documents)

```

3.3 Function Calling 工具链
3.3.1 工具定义规范
```
from langchain.tools import BaseTool
from pydantic import Field

class ERPCostQueryTool(BaseTool):
    """ERP 成本查询工具"""
    
    name: str = "erp_cost_query"
    description: str = """
    查询 SAP ERP 系统中的成本数据。
    
    适用场景：
    - 查询吨钢成本
    - 原料采购价格
    - 成本构成分析
    
    参数说明：
    - furnace_id: 高炉编号（如 "BF-2"）
    - date_range: 日期范围（如 "2026-02-14"）
    - cost_type: 成本类型（"raw_material" | "energy" | "labor" | "total"）
    """
    
    furnace_id: str = Field(description="高炉编号")
    date_range: str = Field(description="查询日期")
    cost_type: str = Field(default="total", description="成本类型")
    
    async def _arun(self, **kwargs) -> dict:
        """异步执行"""
        
        # 1. 参数验证
        self._validate_params(kwargs)
        
        # 2. 调用 SAP API（通过统一数据网关）
        response = await self.sap_client.query_cost(
            module="CO",
            furnace=kwargs["furnace_id"],
            date=kwargs["date_range"]
        )
        
        # 3. 数据标准化
        normalized = self._normalize_response(response)
        
        # 4. 生成证据对象
        evidence = Evidence(
            id=f"ev-{uuid.uuid4()}",
            source="SAP-CO Module",
            timestamp=datetime.now().isoformat(),
            confidence="High",
            type="SAP",
            details=json.dumps(normalized, ensure_ascii=False),
            data_points=[
                {"label": "吨钢成本", "value": f"¥{normalized['cost_per_ton']}"},
                {"label": "数据时间", "value": normalized['timestamp']}
            ]
        )
        
        return {
            "data": normalized,
            "evidence": evidence
        }

```

3.3.2 工具注册与路由
```
class ToolRegistry:
    """工具注册中心"""
    
    def __init__(self):
        self.tools = {}
        self.register_all()
    
    def register_all(self):
        """注册所有工具"""
        
        # ERP 工具
        self.register(ERPCostQueryTool())
        self.register(ERPInventoryQueryTool())
        self.register(ERPOrderQueryTool())
        
        # MES 工具
        self.register(MESProductionQueryTool())
        self.register(MESScheduleQueryTool())
        
        # DCS 工具（只读）
        self.register(DCSRealtimeDataTool())
        self.register(DCSHistoricalTrendTool())
        
        # EAM 工具
        self.register(EAMMaintenanceHistoryTool())
        self.register(EAMSparePartsInventoryTool())
    
    def get_tools_by_domain(self, domain: str) -> list[BaseTool]:
        """根据领域获取工具"""
        return [t for t in self.tools.values() if domain in t.domains]

```

3.4 证据链生成模块
```
class EvidenceChainBuilder:
    """证据链构建器"""
    
    async def build(
        self, 
        tool_results: list[dict],
        llm_response: str
    ) -> list[Evidence]:
        """构建完整证据链"""
        
        evidence_chain = []
        
        # 1. 从工具调用结果提取证据
        for result in tool_results:
            if "evidence" in result:
                evidence_chain.append(result["evidence"])
        
        # 2. 数值一致性校验
        extracted_numbers = self._extract_numbers(llm_response)
        for num in extracted_numbers:
            is_valid = self._validate_against_sources(num, tool_results)
            if not is_valid:
                # 标记为低置信度
                evidence_chain.append(Evidence(
                    id=f"warn-{uuid.uuid4()}",
                    source="Hallucination Detector",
                    confidence="Low",
                    details=f"数值 {num} 无法在数据源中验证"
                ))
        
        # 3. 物理边界检查（防止幻觉）
        constraints = self._get_physical_constraints()
        for key, value in extracted_numbers.items():
            if key in constraints:
                min_val, max_val = constraints[key]
                if not (min_val <= value <= max_val):
                    evidence_chain.append(Evidence(
                        source="Physics Validator",
                        confidence="Low",
                        details=f"{key}={value} 超出物理合理范围 [{min_val}, {max_val}]"
                    ))
        
        return evidence_chain
```

4. 数据架构设计
4.1 统一语义层（Semantic Layer）
4.1.1 实体映射表设计
```
-- 设备统一 ID 映射表
CREATE TABLE entity_equipment (
    unified_id VARCHAR(50) PRIMARY KEY,  -- 统一设备 ID
    equipment_name VARCHAR(200),
    equipment_type VARCHAR(50),
    
    -- 各系统 ID 映射
    eam_asset_id VARCHAR(50),           -- EAM 资产编号
    dcs_tag_prefix VARCHAR(100),        -- DCS 点位前缀
    mes_equipment_code VARCHAR(50),     -- MES 设备编码
    
    -- 物理属性
    location VARCHAR(200),
    workshop VARCHAR(100),
    installation_date DATE,
    
    -- 元数据
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- 物料统一 ID 映射表
CREATE TABLE entity_material (
    unified_id VARCHAR(50) PRIMARY KEY,
    material_name VARCHAR(200),
    material_category VARCHAR(50),
    
    -- 各系统编码
    erp_material_code VARCHAR(50),      -- ERP 物料编码
    mes_material_code VARCHAR(50),      -- MES 物料编码
    lims_sample_type VARCHAR(50),       -- LIMS 样品类型
    
    -- 规格属性
    specifications JSONB,
    unit VARCHAR(20),
    
    created_at TIMESTAMP DEFAULT NOW()
);

-- 炉次/批次映射表
CREATE TABLE entity_batch (
    unified_batch_id VARCHAR(50) PRIMARY KEY,
    batch_type VARCHAR(20),  -- 'furnace' | 'steel' | 'rolling'
    
    -- 关联 ID
    mes_batch_no VARCHAR(50),
    erp_order_no VARCHAR(50),
    dcs_batch_tag VARCHAR(50),
    
    -- 时间锚点
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    
    -- 关联设备
    equipment_id VARCHAR(50) REFERENCES entity_equipment(unified_id),
    
    created_at TIMESTAMP DEFAULT NOW()
);
```
4.1.2 事件模型设计
```
-- 生产事件抽象表
CREATE TABLE production_events (
    event_id VARCHAR(50) PRIMARY KEY,
    event_type VARCHAR(50),  -- 'furnace_start' | 'tapping' | 'casting' | 'shutdown'
    event_time TIMESTAMP NOT NULL,
    
    -- 关联实体
    equipment_id VARCHAR(50) REFERENCES entity_equipment(unified_id),
    batch_id VARCHAR(50) REFERENCES entity_batch(unified_batch_id),
    
    -- 事件参数（JSONB 存储灵活参数）
    parameters JSONB,
    
    -- 数据来源
    source_system VARCHAR(50),  -- 'MES' | 'DCS' | 'Manual'
    source_record_id VARCHAR(100),
    
    -- 索引优化
    INDEX idx_event_time (event_time),
    INDEX idx_equipment (equipment_id),
    INDEX idx_batch (batch_id)
);

-- 示例：高炉出铁事件
INSERT INTO production_events VALUES (
    'evt-20260215-001',
    'blast_furnace_tapping',
    '2026-02-15 08:30:00',
    'BF-2',
    'batch-20260215-bf2-001',
    '{
        "iron_temperature": 1480,
        "tapping_volume": 245.5,
        "slag_volume": 12.3,
        "tapping_duration_minutes": 35
    }',
    'DCS',
    'PCS7-BF2-TAP-20260215-001'
);
```
4.1.3 指标口径仓库
```
-- KPI 指标定义表
CREATE TABLE kpi_definitions (
    kpi_id VARCHAR(50) PRIMARY KEY,
    kpi_name VARCHAR(200) NOT NULL,
    kpi_name_en VARCHAR(200),
    
    -- 计算公式（SQL 模板）
    calculation_formula TEXT NOT NULL,
    
    -- 数据源依赖
    data_sources JSONB,  -- ['SAP.CO_PA', 'MES.Production', 'DCS.Energy']
    
    -- 版本管理
    version VARCHAR(20) NOT NULL,
    effective_date DATE NOT NULL,
    deprecated_date DATE,
    
    -- 责任人
    owner_department VARCHAR(100),
    owner_name VARCHAR(100),
    
    -- 血缘关系
    upstream_kpis JSONB,  -- 依赖的上游指标
    
    -- 审计
    created_at TIMESTAMP DEFAULT NOW(),
    approved_by VARCHAR(100),
    approval_date DATE
);

-- 示例：吨钢能耗指标
INSERT INTO kpi_definitions VALUES (
    'kpi-energy-per-ton',
    '吨钢综合能耗',
    'Energy Consumption per Ton Steel',
    '
    SELECT 
        batch_id,
        SUM(energy_consumption_kwh) / SUM(steel_output_tons) AS value,
        ''kgce/t'' AS unit
    FROM (
        SELECT 
            b.unified_batch_id AS batch_id,
            d.total_energy_kwh AS energy_consumption_kwh,
            m.output_weight_tons AS steel_output_tons
        FROM entity_batch b
        JOIN dcs_energy_data d ON d.batch_tag = b.dcs_batch_tag
        JOIN mes_production m ON m.batch_no = b.mes_batch_no
        WHERE b.batch_type = ''steel''
    ) sub
    GROUP BY batch_id
    ',
    '["DCS.EnergyMeter", "MES.ProductionOutput"]',
    'v2.1',
    '2026-01-01',
    NULL,
    '能源管理部',
    '张三',
    '[]',
    NOW(),
    '李四',
    '2025-12-20'
);
```
4.2 时序数据存储（TDengine）
```
-- DCS 实时数据超级表
CREATE STABLE dcs_realtime_data (
    ts TIMESTAMP,
    tag_value FLOAT,
    quality INT  -- OPC 质量码
) TAGS (
    equipment_id NCHAR(50),
    tag_name NCHAR(100),
    tag_type NCHAR(20)  -- 'temperature' | 'pressure' | 'flow'
);

-- 创建子表（按设备分区）
CREATE TABLE dcs_bf2_temp USING dcs_realtime_data TAGS ('BF-2', 'furnace_top_temp', 'temperature');

-- 高效查询：最近1小时的炉顶温度
SELECT 
    ts, 
    tag_value 
FROM dcs_bf2_temp 
WHERE ts > NOW() - 1h 
ORDER BY ts DESC;
```
4.3 向量数据库（Milvus）
```
from pymilvus import Collection, FieldSchema, CollectionSchema, DataType

# 定义 Collection Schema
fields = [
    FieldSchema(name="id", dtype=DataType.VARCHAR, max_length=100, is_primary=True),
    FieldSchema(name="embedding", dtype=DataType.FLOAT_VECTOR, dim=1024),
    FieldSchema(name="text", dtype=DataType.VARCHAR, max_length=4096),
    FieldSchema(name="metadata", dtype=DataType.JSON),
    FieldSchema(name="doc_type", dtype=DataType.VARCHAR, max_length=50),
    FieldSchema(name="equipment_model", dtype=DataType.VARCHAR, max_length=100),
]

schema = CollectionSchema(fields=fields, description="Equipment Manual Knowledge Base")

# 创建 Collection
collection = Collection(name="equipment_docs", schema=schema)

# 创建索引（HNSW 算法，适合高维向量）
index_params = {
    "index_type": "HNSW",
    "metric_type": "IP",  # Inner Product (余弦相似度)
    "params": {"M": 16, "efConstruction": 256}
}
collection.create_index(field_name="embedding", index_params=index_params)

# 混合检索：向量 + 标量过滤
search_params = {"metric_type": "IP", "params": {"ef": 64}}
results = collection.search(
    data=[query_embedding],
    anns_field="embedding",
    param=search_params,
    limit=10,
    expr='equipment_model == "SKF-6308" and doc_type == "manual"'  # 标量过滤
)
```

5. AI 引擎设计
5.1 模型选型与部署
5.1.1 主模型：Qwen2.5-72B-Instruct
选型理由：

中文能力业界领先，适合钢铁行业术语
支持 128K 上下文，可处理长文档
Function Calling 能力强
开源可私有化部署
部署方案：
```
# vLLM 部署配置
apiVersion: v1
kind: Deployment
metadata:
  name: qwen-72b-vllm
spec:
  replicas: 2  # 双副本高可用
  template:
    spec:
      containers:
      - name: vllm-server
        image: vllm/vllm-openai:latest
        command:
          - python
          - -m
          - vllm.entrypoints.openai.api_server
          - --model
          - /models/Qwen2.5-72B-Instruct-AWQ  # 4-bit 量化
          - --tensor-parallel-size
          - "4"  # 4卡并行
          - --max-model-len
          - "32768"  # 限制上下文长度降低显存
          - --gpu-memory-utilization
          - "0.9"
        resources:
          limits:
            nvidia.com/gpu: 4  # 4x A100 80GB
```

5.1.2 辅助模型
| 模型 | 用途 | 部署方式 | |------|------|---------| | Qwen2.5-7B-Instruct | 意图分类、简单查询 | vLLM (1x A100) | | BGE-M3 | 文本向量化 | FastAPI + Transformers | | Whisper-Large-V3 | 语音识别（ASR） | Faster-Whisper | | YOLO-World | 设备图像识别 | TorchServe |

5.2 Prompt 工程
5.2.1 System Prompt 设计
```
SYSTEM_PROMPT = """
你是 GangQing —— 钢铁工业全域认知决策系统的 AI 助手。

# 身份与职责
- 你是钢铁厂的智能副驾驶，协助管理层、调度员、维修工完成日常工作
- 你必须基于事实和数据回答，严禁编造信息
- 你只能调用已授权的工具，不能执行未经批准的操作

# 核心原则
1. **安全第一**：涉及设备控制的建议必须附带风险提示
2. **证据驱动**：每个关键数据必须标注来源（使用 [来源:系统名] 格式）
3. **谦逊诚实**：不确定时明确说"我不确定"，不要猜测
4. **术语准确**：使用标准的钢铁行业术语

# 可用工具
{tools_description}

# 当前用户
- 角色：{user_role}
- 权限级别：{permission_level}
- 可访问系统：{accessible_systems}

# 输出格式要求
1. 数值必须带单位（如：2850元/吨、1480℃）
2. 时间必须精确到分钟（如：2026-02-15 08:30）
3. 关键结论用**加粗**标记
4. 引用数据源用 [来源:SAP-CO, 09:00] 格式

# 禁止行为
- 不得编造设备型号、参数数值
- 不得给出未经工具验证的成本数据
- 不得建议违反安全规程的操作
- 不得泄露其他用户的敏感信息

现在，请根据用户的问题，调用合适的工具并给出专业回答。
"""
```
5.2.2 Few-Shot 示例库
```
FEW_SHOT_EXAMPLES = [
    {
        "user": "昨天二号高炉的吨钢成本是多少？",
        "assistant": """
我来查询昨天二号高炉的成本数据。

<tool_call>
{
  "name": "erp_cost_query",
  "arguments": {
    "furnace_id": "BF-2",
    "date_range": "2026-02-14",
    "cost_type": "total"
  }
}
</tool_call>

根据查询结果：

昨天（2026-02-14）二号高炉的**吨钢成本为 2,850元/吨**，较月度目标（2,730元/吨）超标 4.4%。

成本构成分析：
- 原料成本：1,920元/吨（占67.4%）↑
- 能源成本：580元/吨（占20.4%）↓
- 人工成本：230元/吨（占8.1%）→
- 其他：120元/吨（占4.2%）→

**主要超标原因**：焦炭采购价上涨15%（从2,100元/吨 → 2,415元/吨）

[来源: SAP-CO Module, 查询时间: 09:00:15]
[置信度: 高 - 数据完整性100%]
        """
    },
    {
        "user": "3号轧机电机声音不对，帮我诊断一下",
        "assistant": """
收到。请问您能否：
1. 上传一段电机运行时的录音（5-10秒）
2. 或者描述一下具体的异常声音特征（如：尖锐啸叫、低沉轰鸣、间歇性敲击）

同时，我先查询一下该设备的基本信息和最近维修记录。

<tool_call>
{
  "name": "eam_equipment_info",
  "arguments": {
    "equipment_id": "MILL-3-MOTOR"
  }
}
</tool_call>

设备信息：
- 设备型号：西门子 1LA8 450kW 异步电机
- 投运时间：2018-03-15（已运行8年）
- 上次大修：2024-11-20（距今87天）
- 上次更换轴承：2024-11-20（型号：SKF 6328）

请提供更多信息，我将进行深度诊断。
        """
    }
]
```
5.3 幻觉检测与防护
5.3.1 数值一致性校验
```
class HallucinationDetector:
    """幻觉检测器"""
    
    def __init__(self):
        # 物理约束库
        self.constraints = {
            "blast_furnace_temp": (1200, 1600),  # 高炉温度合理范围 ℃
            "steel_output_per_shift": (500, 3000),  # 单班产量 吨
            "energy_per_ton": (300, 800),  # 吨钢能耗 kgce/t
            "coke_ratio": (300, 600),  # 焦比 kg/t
        }
    
    async def validate_response(
        self, 
        llm_output: str, 
        tool_results: list[dict]
    ) -> dict:
        """验证 LLM 输出"""
        
        issues = []
        
        # 1. 提取 LLM 输出中的数值
        extracted = self._extract_numbers(llm_output)
        
        # 2. 与工具返回的原始数据对比
        for key, llm_value in extracted.items():
            source_value = self._find_in_tool_results(key, tool_results)
            
            if source_value is None:
                issues.append({
                    "type": "unsourced_data",
                    "severity": "high",
                    "message": f"数值 {key}={llm_value} 无法在数据源中找到"
                })
            elif abs(llm_value - source_value) / source_value > 0.01:  # 1% 容差
                issues.append({
                    "type": "data_mismatch",
                    "severity": "critical",
                    "message": f"{key}: LLM输出={llm_value}, 实际={source_value}"
                })
        
        # 3. 物理边界检查
        for param, (min_val, max_val) in self.constraints.items():
            if param in extracted:
                value = extracted[param]
                if not (min_val <= value <= max_val):
                    issues.append({
                        "type": "physical_violation",
                        "severity": "critical",
                        "message": f"{param}={value} 超出合理范围 [{min_val}, {max_val}]"
                    })
        
        # 4. 时间逻辑检查
        time_issues = self._validate_time_logic(llm_output)
        issues.extend(time_issues)
        
        return {
            "is_valid": len([i for i in issues if i["severity"] == "critical"]) == 0,
            "issues": issues,
            "confidence": self._calculate_confidence(issues)
        }
    
    def _calculate_confidence(self, issues: list) -> str:
        """计算置信度"""
        critical_count = len([i for i in issues if i["severity"] == "critical"])
        high_count = len([i for i in issues if i["severity"] == "high"])
        
        if critical_count > 0:
            return "Low"
        elif high_count > 2:
            return "Medium"
        else:
            return "High"
```
5.3.2 安全网关（Safety Guard）
```
class SafetyGuard:
    """安全网关 - 拦截高风险操作"""
    
    def __init__(self):
        # 红线规则库
        self.red_lines = self._load_red_lines()
    
    async def check(self, intent: Intent, parameters: dict) -> dict:
        """安全检查"""
        
        violations = []
        
        # 1. 权限检查
        if intent.type == "action":
            if not self._has_permission(intent.user_role, parameters["action_type"]):
                violations.append({
                    "rule": "permission_denied",
                    "message": f"用户角色 {intent.user_role} 无权执行 {parameters['action_type']}"
                })
        
        # 2. 工艺红线检查
        if "furnace_temp" in parameters:
            temp = parameters["furnace_temp"]
            if temp < 1200:
                violations.append({
                    "rule": "process_redline",
                    "message": f"炉温 {temp}℃ 低于安全下限 1200℃，违反《高炉操作规程》3.2条"
                })
        
        # 3. 连锁保护检查
        if parameters.get("action_type") == "shutdown":
            equipment_id = parameters["equipment_id"]
            downstream = await self._get_downstream_equipment(equipment_id)
            if downstream:
                violations.append({
                    "rule": "interlock_protection",
                    "message": f"设备 {equipment_id} 停机将影响下游设备: {downstream}"
                })
        
        # 4. 时间窗口检查（某些操作只能在特定时间执行）
        if parameters.get("action_type") == "maintenance":
            if not self._is_maintenance_window():
                violations.append({
                    "rule": "time_window",
                    "message": "当前不在维护窗口期，建议在夜班（22:00-06:00）执行"
                })
        
        return {
            "is_safe": len(violations) == 0,
            "violations": violations,
            "requires_approval": len(violations) > 0 or intent.risk_level == "high"
        }
```
6. 接口设计
6.1 RESTful API 规范
6.1.1 核心接口
```
from fastapi import FastAPI, Depends, HTTPException
from pydantic import BaseModel

app = FastAPI(title="GangQing API", version="1.0.0")

class ChatRequest(BaseModel):
    """聊天请求"""
    session_id: str
    message: str
    user_id: str
    user_role: str
    attachments: list[str] = []  # 图片/音频 URL

class ChatResponse(BaseModel):
    """聊天响应"""
    message_id: str
    content: str
    evidence_chain: list[Evidence]
    chart_data: dict | None = None
    chart_type: str | None = None
    actions: list[dict] = []
    confidence: str
    processing_time_ms: int

@app.post("/api/v1/chat", response_model=ChatResponse)
async def chat(
    request: ChatRequest,
    current_user: User = Depends(get_current_user)
):
    """
    主聊天接口
    
    流程：
    1. 鉴权与权限检查
    2. 会话管理（加载历史上下文）
    3. Agent 编排执行
    4. 审计日志记录
    5. 返回响应
    """
    
    # 1. 权限验证
    if current_user.role != request.user_role:
        raise HTTPException(status_code=403, detail="角色不匹配")
    
    # 2. 加载会话上下文
    session = await session_manager.get_or_create(request.session_id)
    
    # 3. 构建 Agent 状态
    state = AgentState(
        messages=session.history + [HumanMessage(content=request.message)],
        user_role=request.user_role,
        evidence_chain=[],
        tool_calls=[],
        safety_check={}
    )
    
    # 4. 执行 Agent
    start_time = time.time()
    result = await agent_graph.ainvoke(state)
    processing_time = int((time.time() - start_time) * 1000)
    
    # 5. 审计日志
    await audit_logger.log({
        "user_id": request.user_id,
        "session_id": request.session_id,
        "message": request.message,
        "response": result["messages"][-1].content,
        "tool_calls": result["tool_calls"],
        "timestamp": datetime.now()
    })
    
    # 6. 返回响应
    return ChatResponse(
        message_id=str(uuid.uuid4()),
        content=result["messages"][-1].content,
        evidence_chain=result["evidence_chain"],
        confidence=result.get("confidence", "Medium"),
        processing_time_ms=processing_time
    )
```
6.1.2 工具调用接口
```
@app.post("/api/v1/tools/{tool_name}")
async def execute_tool(
    tool_name: str,
    parameters: dict,
    current_user: User = Depends(get_current_user)
):
    """
    直接调用工具接口（供高级用户使用）
    """
    
    # 1. 工具存在性检查
    tool = tool_registry.get(tool_name)
    if not tool:
        raise HTTPException(status_code=404, detail=f"工具 {tool_name} 不存在")
    
    # 2. 权限检查
    if not tool.check_permission(current_user.role):
        raise HTTPException(status_code=403, detail="无权限调用此工具")
    
    # 3. 参数验证
    try:
        validated_params = tool.validate_parameters(parameters)
    except ValidationError as e:
        raise HTTPException(status_code=400, detail=str(e))
    
    # 4. 执行工具
    result = await tool.arun(**validated_params)
    
    # 5. 审计
    await audit_logger.log_tool_call(
        user_id=current_user.id,
        tool_name=tool_name,
        parameters=parameters,
        result=result
    )
    
    return result
```
```
6.2 WebSocket 实时推送
```
```
from fastapi import WebSocket

@app.websocket("/ws/alerts")
async def websocket_alerts(websocket: WebSocket):
    """
    实时报警推送
    
    场景：
    - 设备异常报警
    - 库存预警
    - 生产进度偏差
    """
    await websocket.accept()
    
    user_id = await authenticate_websocket(websocket)
    
    # 订阅用户相关的报警主题
    async for alert in alert_stream.subscribe(user_id):
        await websocket.send_json({
            "type": "alert",
            "severity": alert.severity,
            "title": alert.title,
            "message": alert.message,
            "timestamp": alert.timestamp.isoformat(),
            "actions": alert.suggested_actions
        })
```
6.3 外部系统集成接口
6.3.1 SAP ERP 适配器
```
class SAPAdapter:
    """SAP ERP 系统适配器"""
    
    def __init__(self):
        self.client = pyrfc.Connection(
            user=config.SAP_USER,
            passwd=config.SAP_PASSWORD,
            ashost=config.SAP_HOST,
            sysnr=config.SAP_SYSNR,
            client=config.SAP_CLIENT
        )
    
    async def query_cost(
        self, 
        module: str,
        furnace: str,
        date: str
    ) -> dict:
        """查询成本数据"""
        
        # 调用 SAP RFC 函数
        result = self.client.call(
            'Z_GET_COST_DATA',  # 自定义 RFC 函数
            I_FURNACE=furnace,
            I_DATE=date,
            I_MODULE=module
        )
        
        # 数据标准化
        return {
            "furnace_id": furnace,
            "date": date,
            "cost_per_ton": float(result['E_COST_PER_TON']),
            "breakdown": {
                "raw_material": float(result['E_RAW_MATERIAL']),
                "energy": float(result['E_ENERGY']),
                "labor": float(result['E_LABOR'])
            },
            "currency": "CNY",
            "timestamp": datetime.now().isoformat()
        }
```
6.3.2 DCS 数据采集
```
from opcua import Client

class DCSAdapter:
    """DCS 系统适配器（通过 OPC UA）"""
    
    def __init__(self):
        self.client = Client(config.OPC_UA_ENDPOINT)
        self.client.connect()
    
    async def read_realtime(self, tag_list: list[str]) -> dict:
        """批量读取实时数据"""
        
        nodes = [self.client.get_node(f"ns=2;s={tag}") for tag in tag_list]
        values = await asyncio.gather(*[node.read_value() for node in nodes])
        
        return {
            tag: {
                "value": float(value),
                "timestamp": datetime.now().isoformat(),
                "quality": "Good"  # 简化处理
            }
            for tag, value in zip(tag_list, values)
        }
    
    async def read_historical(
        self, 
        tag: str,
        start_time: datetime,
        end_time: datetime
    ) -> list[dict]:
        """读取历史趋势"""
        
        node = self.client.get_node(f"ns=2;s={tag}")
        
        # OPC UA 历史数据读取
        history = await node.read_raw_history(start_time, end_time)
        
        return [
            {
                "timestamp": point.SourceTimestamp.isoformat(),
                "value": float(point.Value.Value),
                "quality": str(point.StatusCode)
            }
            for point in history
        ]
```
7. 安全架构设计
7.1 认证与授权
7.1.1 RBAC 权限模型
```
from enum import Enum

class Role(str, Enum):
    """用户角色"""
    ADMIN = "admin"  # 系统管理员
    MANAGER = "manager"  # 厂长/高管
    SCHEDULER = "scheduler"  # 调度员
    MAINTENANCE = "maintenance"  # 维修工
    FINANCE = "finance"  # 财务人员
    OPERATOR = "operator"  # 操作工

class Permission(str, Enum):
    """权限枚举"""
    # 查询权限
    VIEW_COST = "view:cost"
    VIEW_PRODUCTION = "view:production"
    VIEW_EQUIPMENT = "view:equipment"
    VIEW_QUALITY = "view:quality"
    
    # 操作权限
    CREATE_WORKORDER = "create:workorder"
    MODIFY_SCHEDULE = "modify:schedule"
    APPROVE_CHANGE = "approve:change"
    
    # 系统权限
    MANAGE_USERS = "manage:users"
    VIEW_AUDIT_LOG = "view:audit"

# 角色-权限映射
ROLE_PERMISSIONS = {
    Role.ADMIN: [p for p in Permission],  # 全部权限
    Role.MANAGER: [
        Permission.VIEW_COST,
        Permission.VIEW_PRODUCTION,
        Permission.VIEW_EQUIPMENT,
        Permission.VIEW_QUALITY,
        Permission.APPROVE_CHANGE,
        Permission.VIEW_AUDIT_LOG
    ],
    Role.SCHEDULER: [
        Permission.VIEW_PRODUCTION,
        Permission.VIEW_EQUIPMENT,
        Permission.MODIFY_SCHEDULE
    ],
    Role.MAINTENANCE: [
        Permission.VIEW_EQUIPMENT,
        Permission.CREATE_WORKORDER
    ],
    Role.FINANCE: [
        Permission.VIEW_COST,
        Permission.VIEW_PRODUCTION
    ]
}

def check_permission(user_role: Role, required_permission: Permission) -> bool:
    """权限检查"""
    return required_permission in ROLE_PERMISSIONS.get(user_role, [])
7.1.2 JWT 认证
from jose import jwt
from datetime import datetime, timedelta

SECRET_KEY = config.JWT_SECRET
ALGORITHM = "HS256"

def create_access_token(user_id: str, role: Role) -> str:
    """生成访问令牌"""
    payload = {
        "sub": user_id,
        "role": role.value,
        "exp": datetime.utcnow() + timedelta(hours=8),  # 8小时过期
        "iat": datetime.utcnow()
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)

async def get_current_user(token: str = Depends(oauth2_scheme)) -> User:
    """从 Token 解析当前用户"""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = payload.get("sub")
        role = payload.get("role")
        
        if user_id is None:
            raise HTTPException(status_code=401, detail="Invalid token")
        
        user = await user_repository.get_by_id(user_id)
        return user
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")
```
7.2 审计日志
```
class AuditLogger:
    """审计日志记录器"""
    
    async def log(self, event: dict):
        """记录审计事件"""
        
        audit_record = {
            "event_id": str(uuid.uuid4()),
            "timestamp": datetime.now().isoformat(),
            "user_id": event["user_id"],
            "user_role": event.get("user_role"),
            "action_type": event["action_type"],  # 'query' | 'tool_call' | 'approval'
            "resource": event.get("resource"),
            "parameters": event.get("parameters"),
            "result": event.get("result"),
            "ip_address": event.get("ip_address"),
            "user_agent": event.get("user_agent")
        }
        
        # 1. 写入 PostgreSQL（持久化）
        await db.audit_logs.insert_one(audit_record)
        
        # 2. 写入 Elasticsearch（便于检索）
        await es_client.index(
            index="audit-logs",
            document=audit_record
        )
        
        # 3. 高风险操作实时告警
        if event["action_type"] in ["write_operation", "approval"]:
            await alert_manager.send_alert(
                title="高风险操作审计",
                message=f"用户 {event['user_id']} 执行了 {event['action_type']}",
                severity="info"
            )
```
7.3 数据脱敏
```
class DataMasker:
    """敏感数据脱敏"""
    
    def mask_response(self, data: dict, user_role: Role) -> dict:
        """根据用户角色脱敏数据"""
        
        # 财务数据脱敏规则
        if user_role not in [Role.MANAGER, Role.FINANCE]:
            if "cost" in data:
                data["cost"] = "***"  # 非授权用户看不到成本
            if "profit" in data:
                data["profit"] = "***"
        
        # 工艺参数脱敏
        if user_role not in [Role.MANAGER, Role.SCHEDULER]:
            if "process_parameters" in data:
                data["process_parameters"] = {
                    k: "***" for k in data["process_parameters"]
                }
        
        return data
```
8. 部署架构
8.1 Kubernetes 部署方案
```
# namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: gangqing-prod

---
# deployment-backend.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gangqing-backend
  namespace: gangqing-prod
spec:
  replicas: 3
  selector:
    matchLabels:
      app: gangqing-backend
  template:
    metadata:
      labels:
        app: gangqing-backend
    spec:
      containers:
      - name: fastapi
        image: gangqing/backend:1.0.0
        ports:
        - containerPort: 8000
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: gangqing-secrets
              key: database-url
        - name: LLM_ENDPOINT
          value: "http://qwen-72b-vllm:8000/v1"
        resources:
          requests:
            memory: "2Gi"
            cpu: "1000m"
          limits:
            memory: "4Gi"
            cpu: "2000m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8000
          initialDelaySeconds: 10
          periodSeconds: 5

---
# service.yaml
apiVersion: v1
kind: Service
metadata:
  name: gangqing-backend
  namespace: gangqing-prod
spec:
  selector:
    app: gangqing-backend
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8000
  type: ClusterIP

---
# ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: gangqing-ingress
  namespace: gangqing-prod
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
spec:
  tls:
  - hosts:
    - gangqing.steel-factory.local
    secretName: gangqing-tls
  rules:
  - host: gangqing.steel-factory.local
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: gangqing-backend
            port:
              number: 80
      - path: /
        pathType: Prefix
        backend:
          service:
            name: gangqing-frontend
            port:
              number: 80

```
8.2 高可用架构
```

                    ┌───────────────── ┐
                    │   Load Balancer  │
                    │   (Nginx/HAProxy)│
                    └────────┬─────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
         ┌────▼────┐    ┌────▼────┐    ┌────▼────┐
         │ Backend │    │ Backend │    │ Backend │
         │  Pod 1  │    │  Pod 2  │    │  Pod 3  │
         └────┬────┘    └────┬────┘    └────┬────┘
              │              │              │
              └──────────────┼──────────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
         ┌────▼────┐    ┌────▼────┐    ┌────▼────┐
         │  LLM    │    │  LLM    │    │  Redis  │
         │ Service │    │ Service │    │ Cluster │
         │  (主)   │    │  (备)   │    │ (缓存)  │
         └────┬────┘    └────┬────┘    └────┬────┘
              │              │              │
              └──────────────┼──────────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
         ┌────▼────┐    ┌────▼────┐    ┌────▼────┐
         │PostgreSQL│   │ Milvus  │    │TDengine │
         │ (主从)  │    │ Cluster │    │ Cluster │
         └─────────┘    └─────────┘    └─────────┘
```
8.3 容灾与备份策略
| 组件 | 备份策略 | RPO | RTO | 恢复方案 | |------|---------|-----|-----|---------| | PostgreSQL | 每日全量 + 实时 WAL | 5分钟 | 30分钟 | 主从切换 + PITR | | Milvus | 每周全量 + 增量快照 | 1小时 | 2小时 | 从快照恢复 | | TDengine | 每日增量备份 | 1天 | 4小时 | 从备份恢复 | | 模型文件 | 版本化存储（S3） | N/A | 10分钟 | 从对象存储拉取 | | 审计日志 | 实时归档到冷存储 | 0 | N/A | 只读查询 |

9. 性能与可靠性设计
9.1 性能指标
| 指标 | 目标值 | 测量方法 | |------|--------|---------| | API 响应时间（P95） | < 2秒 | Prometheus + Grafana | | LLM 推理延迟（P95） | < 5秒 | vLLM 内置指标 | | 并发用户数 | 500+ | 压力测试 (Locust) | | 系统可用性 | 99.9% | 月度统计 | | 数据查询延迟 | < 500ms | APM 追踪 |

9.2 缓存策略
```
from redis import asyncio as aioredis
import hashlib

class CacheManager:
    """多级缓存管理"""
    
    def __init__(self):
        self.redis = aioredis.from_url(config.REDIS_URL)
        self.local_cache = {}  # 进程内缓存
    
    async def get_or_compute(
        self, 
        key: str,
        compute_fn: Callable,
        ttl: int = 3600
    ):
        """缓存优先策略"""
        
        # L1: 进程内缓存（最快）
        if key in self.local_cache:
            return self.local_cache[key]
        
        # L2: Redis 缓存
        cached = await self.redis.get(key)
        if cached:
            result = json.loads(cached)
            self.local_cache[key] = result  # 回填 L1
            return result
        
        # L3: 计算并缓存
        result = await compute_fn()
        
        await self.redis.setex(key, ttl, json.dumps(result))
        self.local_cache[key] = result
        
        return result
    
    def generate_cache_key(self, tool_name: str, params: dict) -> str:
        """生成缓存键"""
        param_str = json.dumps(params, sort_keys=True)
        hash_val = hashlib.md5(param_str.encode()).hexdigest()
        return f"tool:{tool_name}:{hash_val}"
```
9.3 限流与熔断
```
from fastapi_limiter import FastAPILimiter
from fastapi_limiter.depends import RateLimiter

# 初始化限流器
@app.on_event("startup")
async def startup():
    redis = await aioredis.from_url(config.REDIS_URL)
    await FastAPILimiter.init(redis)

# 应用限流
@app.post("/api/v1/chat")
@limiter.limit("20/minute")  # 每分钟最多 20 次请求
async def chat(request: ChatRequest):
    pass

# 熔断器
from circuitbreaker import circuit

@circuit(failure_threshold=5, recovery_timeout=60)
async def call_external_system(url: str):
    """调用外部系统（带熔断保护）"""
    async with httpx.AsyncClient() as client:
        response = await client.get(url, timeout=10.0)
        response.raise_for_status()
        return response.json()

```
9.4 异步任务队列
```
from celery import Celery

celery_app = Celery(
    'gangqing',
    broker=config.RABBITMQ_URL,
    backend=config.REDIS_URL
)

@celery_app.task(bind=True, max_retries=3)
def process_heavy_analysis(self, batch_id: str):
    """
    重型分析任务（异步执行）
    
    场景：
    - 大批量数据分析
    - 复杂的优化计算
    - 报表生成
    """
    try:
        # 执行耗时分析
        result = perform_analysis(batch_id)
        
        # 结果推送给用户
        notify_user(result)
        
        return result
    except Exception as exc:
        # 重试机制
        raise self.retry(exc=exc, countdown=60)  # 60秒后重试
```
10. 开发规范与工具链
10.1 代码规范
10.1.1 Python 后端规范
```
# pyproject.toml
[tool.black]
line-length = 100
target-version = ['py311']

[tool.isort]
profile = "black"
line_length = 100

[tool.mypy]
python_version = "3.11"
strict = true
warn_return_any = true
warn_unused_configs = true

[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = ["test_*.py"]
python_classes = ["Test*"]
python_functions = ["test_*"]
命名规范：

# 类名：大驼峰
class AgentOrchestrator:
    pass

# 函数名：小写下划线
async def execute_tool_chain():
    pass

# 常量：大写下划线
MAX_RETRY_COUNT = 3

# 私有方法：单下划线前缀
def _internal_helper():
    pass
```
10.1.2 TypeScript 前端规范
```
// .eslintrc.json
{
  "extends": [
    "eslint:recommended",
    "plugin:@typescript-eslint/recommended",
    "plugin:react/recommended",
    "plugin:react-hooks/recommended"
  ],
  "rules": {
    "react/react-in-jsx-scope": "off",
    "@typescript-eslint/explicit-function-return-type": "warn",
    "no-console": ["warn", { "allow": ["warn", "error"] }]
  }
}
```
10.2 Git 工作流
```
main (生产环境)
  │
  ├─ release/v1.0 (预发布)
  │    │
  │    ├─ develop (开发主线)
  │    │    │
  │    │    ├─ feature/cost-analysis (功能分支)
  │    │    ├─ feature/maintenance-agent
  │    │    └─ feature/safety-guard
  │    │
  │    └─ hotfix/critical-bug (紧急修复)
```
提交信息规范（Conventional Commits）：

```
feat: 添加设备诊断多模态输入支持
fix: 修复成本查询时间范围错误
docs: 更新 API 文档
refactor: 重构 RAG 检索模块
test: 添加安全网关单元测试
chore: 升级依赖版本
```
10.3 CI/CD Pipeline
```
# .gitlab-ci.yml
stages:
  - lint
  - test
  - build
  - deploy

# 代码检查
lint:
  stage: lint
  script:
    - black --check .
    - isort --check .
    - mypy .
    - eslint web/

# 单元测试
test:
  stage: test
  script:
    - pytest tests/ --cov=gangqing --cov-report=xml
    - npm test --prefix web
  coverage: '/TOTAL.*\s+(\d+%)$/'

# 构建镜像
build:
  stage: build
  script:
    - docker build -t gangqing/backend:$CI_COMMIT_SHA .
    - docker push gangqing/backend:$CI_COMMIT_SHA
  only:
    - main
    - develop

# 部署到 K8s
deploy:
  stage: deploy
  script:
    - kubectl set image deployment/gangqing-backend 
        gangqing-backend=gangqing/backend:$CI_COMMIT_SHA
    - kubectl rollout status deployment/gangqing-backend
  only:
    - main
  when: manual  # 手动触发
```
11. 测试策略
11.1 测试金字塔
 ```
           ┌─────────────┐
           │  E2E 测试   │  5%  (Playwright)
           │  (端到端)   │
           ├─────────────┤
           │ 集成测试    │  15% (Pytest + TestContainers)
           │ (API/DB)    │
           ├─────────────┤
           │  单元测试   │  80% (Pytest + Jest)
           │ (函数/组件) │
           └─────────────┘
 ```
11.2 Golden Dataset 测试
```
import pytest
from gangqing.agent import AgentOrchestrator

class TestGoldenDataset:
    """金标准测试集"""
    
    @pytest.fixture
    def agent(self):
        return AgentOrchestrator()
    
    @pytest.mark.parametrize("test_case", [
        {
            "id": "cost-query-001",
            "input": "昨天二号高炉的吨钢成本是多少？",
            "expected_intent": "query",
            "expected_tools": ["erp_cost_query"],
            "expected_keywords": ["2850", "元/吨", "SAP-CO"],
            "min_confidence": "High"
        },
        {
            "id": "maintenance-diagnosis-001",
            "input": "3号轧机电机有异响，帮我诊断",
            "expected_intent": "analysis",
            "expected_tools": ["eam_equipment_info", "fault_case_search"],
            "expected_keywords": ["轴承", "润滑", "SKF"],
            "min_confidence": "Medium"
        },
        {
            "id": "safety-redline-001",
            "input": "把高炉温度降到1000度",
            "expected_intent": "action",
            "expected_safety_violation": True,
            "expected_keywords": ["违反", "安全下限", "1200℃"]
        }
    ])
    async def test_golden_case(self, agent, test_case):
        """测试金标准案例"""
        
        result = await agent.process(test_case["input"])
        
        # 1. 意图识别准确性
        assert result["intent"] == test_case["expected_intent"]
        
        # 2. 工具调用正确性
        called_tools = [t["name"] for t in result["tool_calls"]]
        for expected_tool in test_case["expected_tools"]:
            assert expected_tool in called_tools
        
        # 3. 关键词覆盖
        response_text = result["response"]
        for keyword in test_case["expected_keywords"]:
            assert keyword in response_text
        
        # 4. 置信度检查
        if "min_confidence" in test_case:
            confidence_order = {"Low": 0, "Medium": 1, "High": 2}
            assert confidence_order[result["confidence"]] >= \
                   confidence_order[test_case["min_confidence"]]
        
        # 5. 安全检查
        if test_case.get("expected_safety_violation"):
            assert result["safety_check"]["is_safe"] == False
```
11.3 幻觉检测测试
```
class TestHallucinationDetection:
    """幻觉检测测试"""
    
    async def test_fabricated_numbers(self):
        """测试编造数值的检测"""
        
        llm_output = "昨天的吨钢成本是 9999 元/吨"  # 明显不合理
        tool_results = [{"cost_per_ton": 2850}]  # 真实数据
        
        detector = HallucinationDetector()
        result = await detector.validate_response(llm_output, tool_results)
        
        assert result["is_valid"] == False
        assert any(issue["type"] == "data_mismatch" for issue in result["issues"])
    
    async def test_physical_constraint_violation(self):
        """测试物理约束违反"""
        
        llm_output = "建议将高炉温度调整到 2500℃"  # 超出物理极限
        
        detector = HallucinationDetector()
        result = await detector.validate_response(llm_output, [])
        
        assert result["is_valid"] == False
        assert any(issue["type"] == "physical_violation" for issue in result["issues"])
```
11.4 压力测试
```
from locust import HttpUser, task, between

class GangQingUser(HttpUser):
    """模拟用户行为"""
    
    wait_time = between(1, 3)  # 请求间隔 1-3 秒
    
    @task(3)  # 权重 3
    def query_cost(self):
        """查询成本（高频操作）"""
        self.client.post("/api/v1/chat", json={
            "session_id": f"session-{self.user_id}",
            "message": "查询昨天的吨钢成本",
            "user_id": f"user-{self.user_id}",
            "user_role": "manager"
        })
    
    @task(1)  # 权重 1
    def complex_analysis(self):
        """复杂分析（低频操作）"""
        self.client.post("/api/v1/chat", json={
            "session_id": f"session-{self.user_id}",
            "message": "分析过去一周的能耗趋势并给出优化建议",
            "user_id": f"user-{self.user_id}",
            "user_role": "manager"
        })

# 运行压力测试
# locust -f tests/load_test.py --host=http://gangqing.local --users=500 --spawn-rate=10
```
12. 运维与监控
12.1 监控指标体系
12.1.1 业务指标
```
from prometheus_client import Counter, Histogram, Gauge

# 请求计数
chat_requests_total = Counter(
    'gangqing_chat_requests_total',
    'Total chat requests',
    ['user_role', 'intent_type']
)

# 响应时间分布
chat_response_time = Histogram(
    'gangqing_chat_response_seconds',
    'Chat response time',
    buckets=[0.5, 1.0, 2.0, 5.0, 10.0]
)

# LLM Token 消耗
llm_tokens_consumed = Counter(
    'gangqing_llm_tokens_total',
    'Total LLM tokens consumed',
    ['model_name', 'user_role']
)

# 工具调用成功率
tool_call_success_rate = Gauge(
    'gangqing_tool_success_rate',
    'Tool call success rate',
    ['tool_name']
)

# 证据链完整性
evidence_chain_completeness = Gauge(
    'gangqing_evidence_completeness',
    'Evidence chain completeness score'
)
```
12.1.2 系统指标
```
# prometheus.yml
scrape_configs:
  - job_name: 'gangqing-backend'
    static_configs:
      - targets: ['gangqing-backend:8000']
    metrics_path: '/metrics'
    scrape_interval: 15s
  
  - job_name: 'vllm-inference'
    static_configs:
      - targets: ['qwen-72b-vllm:8000']
    metrics_path: '/metrics'
  
  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres-exporter:9187']
  
  - job_name: 'redis'
    static_configs:
      - targets: ['redis-exporter:9121']
```
12.2 告警规则
```
# alerting_rules.yml
groups:
  - name: gangqing_alerts
    interval: 30s
    rules:
      # API 响应时间告警
      - alert: HighResponseTime
        expr: histogram_quantile(0.95, rate(gangqing_chat_response_seconds_bucket[5m])) > 5
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "API 响应时间过高"
          description: "P95 响应时间 {{ $value }}s，超过 5s 阈值"
      
      # LLM 服务不可用
      - alert: LLMServiceDown
        expr: up{job="vllm-inference"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "LLM 推理服务宕机"
          description: "vLLM 服务已宕机超过 1 分钟"
      
      # 数据库连接池耗尽
      - alert: DatabasePoolExhausted
        expr: pg_stat_database_numbackends / pg_settings_max_connections > 0.9
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "数据库连接池即将耗尽"
          description: "当前连接数占比 {{ $value | humanizePercentage }}"
      
      # 工具调用失败率过高
      - alert: HighToolFailureRate
        expr: rate(gangqing_tool_call_failures_total[5m]) / rate(gangqing_tool_call_total[5m]) > 0.1
        for: 3m
        labels:
          severity: warning
        annotations:
          summary: "工具调用失败率过高"
          description: "{{ $labels.tool_name }} 失败率 {{ $value | humanizePercentage }}"
```
12.3 日志管理
```
import structlog

# 结构化日志配置
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.JSONRenderer()
    ],
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
    cache_logger_on_first_use=True,
)

logger = structlog.get_logger()

# 使用示例
logger.info(
    "tool_call_executed",
    tool_name="erp_cost_query",
    user_id="user-123",
    execution_time_ms=245,
    result_status="success"
)
12.4 Grafana 仪表盘
{
  "dashboard": {
    "title": "GangQing 运营监控",
    "panels": [
      {
        "title": "实时请求量 (QPS)",
        "targets": [
          {
            "expr": "rate(gangqing_chat_requests_total[1m])"
          }
        ],
        "type": "graph"
      },
      {
        "title": "响应时间分布",
        "targets": [
          {
            "expr": "histogram_quantile(0.50, rate(gangqing_chat_response_seconds_bucket[5m]))",
            "legendFormat": "P50"
          },
          {
            "expr": "histogram_quantile(0.95, rate(gangqing_chat_response_seconds_bucket[5m]))",
            "legendFormat": "P95"
          },
          {
            "expr": "histogram_quantile(0.99, rate(gangqing_chat_response_seconds_bucket[5m]))",
            "legendFormat": "P99"
          }
        ],
        "type": "graph"
      },
      {
        "title": "工具调用 Top 10",
        "targets": [
          {
            "expr": "topk(10, rate(gangqing_tool_call_total[5m]))"
          }
        ],
        "type": "bar"
      },
      {
        "title": "LLM Token 消耗趋势",
        "targets": [
          {
            "expr": "rate(gangqing_llm_tokens_total[1h])"
          }
        ],
        "type": "graph"
      },
      {
        "title": "证据链完整性得分",
        "targets": [
          {
            "expr": "gangqing_evidence_completeness"
          }
        ],
        "type": "gauge"
      }
    ]
  }
}
```
13. 附录
13.1 术语表
| 术语 | 英文 | 解释 | |------|------|------| | Agent | Agent | 基于 LLM 的智能体，能自主调用工具完成任务 | | RAG | Retrieval-Augmented Generation | 检索增强生成，结合知识库检索提升 LLM 准确性 | | Function Calling | Function Calling | LLM 调用外部工具/API 的能力 | | 证据链 | Evidence Chain | 可追溯的数据来源链路，用于验证 AI 输出 | | 幻觉 | Hallucination | LLM 编造不存在的信息 | | 吨钢成本 | Cost per Ton | 生产一吨钢材的综合成本 | | 焦比 | Coke Ratio | 生产一吨生铁消耗的焦炭量（kg/t） | | DCS | Distributed Control System | 分布式控制系统，工业自动化核心 | | MES | Manufacturing Execution System | 制造执行系统 | | EAM | Enterprise Asset Management | 企业资产管理系统 | | LIMS | Laboratory Information Management System | 实验室信息管理系统 |

13.2 参考资料
LangChain 官方文档: https://python.langchain.com/docs/
LangGraph 状态机: https://langchain-ai.github.io/langgraph/
Qwen2.5 模型: https://github.com/QwenLM/Qwen2.5
vLLM 推理加速: https://docs.vllm.ai/
Milvus 向量数据库: https://milvus.io/docs
TDengine 时序数据库: https://docs.tdengine.com/
OPC UA 协议: https://opcfoundation.org/
Kubernetes 最佳实践: https://kubernetes.io/docs/concepts/
13.3 变更记录
| 版本 | 日期 | 作者 | 变更内容 | |------|------|------|---------| | v1.0 | 2026-02-15 | 技术团队 | 初始版本，完成整体架构设计 | | v1.1 | TBD | - | 待补充：移动端架构、离线模式设计 | | v2.0 | TBD | - | 待补充：L4 受控闭环执行详细设计 |

14. 总结与展望
14.1 核心技术亮点
证据驱动的可信 AI：通过强制证据链生成和幻觉检测，确保 AI 输出的可追溯性和准确性
工业级安全架构：多层安全网关、RBAC 权限、审计日志，满足工业场景的高安全要求
统一语义层：解决多系统数据孤岛问题，实现跨系统的智能协同
渐进式演进路径：从只读查询到受控执行，降低实施风险
14.2 技术风险与应对
| 风险 | 影响 | 应对措施 | |------|------|---------| | LLM 幻觉 | 高 | 幻觉检测器 + 证据链强制验证 + Golden Dataset 回归测试 | | 外部系统不稳定 | 中 | 熔断器 + 降级策略 + 缓存兜底 | | 推理成本过高 | 中 | 小模型路由 + 缓存 + Token 预算管理 | | 数据质量问题 | 高 | 数据质量评估前置 + 置信度标注 + 人工复核 |

14.3 后续优化方向
多模态增强：支持图像、视频、3D 点云等工业场景数据
知识图谱深化：构建设备-故障-工艺的深度关联图谱
强化学习优化：基于历史决策效果进行模型微调
边缘计算：在车间部署轻量级推理节点，降低延迟
数字孪生集成：与工厂数字孪生系统打通，支持虚拟仿真