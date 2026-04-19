# RAGFlow 重新拉取/升级并成功添加本地 OCR（llama.cpp OpenAI-Compatible）过程日志

- 日期：2026-01-04
- 目标：在 RAGFlow 中通过 `OpenAI-API-Compatible` 接入本地 `llama.cpp server` 的 `chandra-ocr` 模型，并作为 `image2text`（VLM/OCR）使用。

## 环境信息

- RAGFlow 部署方式：Docker Compose
- Compose 目录：`/home/zhengxueen/workspace/ragflow/docker`
- 本地 OCR 服务：llama.cpp server（OpenAI-compatible）
- OCR Base URL：http://172.16.100.211:8082/v1
- OCR API Key：`sk-local-ocr`
- OCR 模型：`chandra-ocr`

## 1. 初始问题（v0.22.1）

### 1.1 在 RAGFlow 添加本地模型时报错（参数不兼容）

当在 RAGFlow 中添加 `OpenAI-API-Compatible/chandra-ocr`（用于 `image2text`）时，返回：

```json
{
  "code": 102,
  "message": "\nFail to access model(OpenAI-API-Compatible/chandra-ocr).Completions.create() got an unexpected keyword argument 'unused'"
}
```

结论：RAGFlow 端调用 OpenAI Python SDK 的 `Completions.create()` 时携带了不被 SDK 接受的参数 `unused`，导致在客户端侧直接异常，HTTP 请求可能尚未到达 llama.cpp。

### 1.2 llama.cpp 服务端验证（模型存在、支持 chat、但需要鉴权）

#### 查看模型列表

```bash
curl http://172.16.100.211:8082/v1/models
```

返回中包含模型：

- `id/name/model`: `chandra-ocr`
- `capabilities`: `completion`, `multimodal`

#### 测试 chat/completions（未带 key 时 401）

```bash
curl http://172.16.100.211:8082/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model":"chandra-ocr",
    "messages":[{"role":"user","content":"hello"}]
  }'
```

返回：

```json
{"error":{"message":"Invalid API Key","type":"authentication_error","code":401}}
```

#### 测试 chat/completions（带 Bearer key 成功）

```bash
curl http://172.16.100.211:8082/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-local-ocr" \
  -d '{
    "model":"chandra-ocr",
    "messages":[{"role":"user","content":"hello"}]
  }'
```

成功返回（示例）：

```json
{"choices":[{"finish_reason":"stop","index":0,"message":{"role":"assistant","content":"Hello! How can I assist you today?"}}],"object":"chat.completion"}
```

结论：llama.cpp 服务端 OK，但必须正确传 `Authorization: Bearer sk-local-ocr`。

## 2. 版本与依赖确认（定位 RAGFlow 侧问题）

### 2.1 确认当前运行镜像

```bash
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}'
```

当时显示：

- `docker-ragflow-cpu-1` 使用 `.../ragflow:v0.22.1`

### 2.2 确认容器内 openai SDK 版本

```bash
docker exec docker-ragflow-cpu-1 python -c "import openai; print(openai.__version__)"
```

当时返回：

- `openai==1.99.9`

并验证 `Completions.create()` 的签名不包含 `unused`，因此 `unused` 会触发 `unexpected keyword argument`。

## 3. 尝试 nightly（失败，镜像不稳定）

### 3.1 将 `RAGFLOW_IMAGE` 切到 `nightly`

在 `docker/.env` 调整 `RAGFLOW_IMAGE` 后执行：

```bash
docker compose --env-file .env -f docker-compose.yml pull ragflow-cpu
docker compose --env-file .env -f docker-compose.yml up -d ragflow-cpu
```

### 3.2 nightly 启动出现 ImportError

```text
ImportError: cannot import name 'init_root_logger' from 'api.utils.log_utils'
```

结论：nightly 在该环境下不稳定，不能作为解决方案。

## 4. 切换到稳定版 v0.23.1（成功路线）

参考 RAGFlow 官方文档建议的稳定 tag（文档示例为 v0.23.1）。

### 4.1 将 `RAGFLOW_IMAGE` 切到 v0.23.1

`/home/zhengxueen/workspace/ragflow/docker/.env`：

- 从 `...:nightly` 改为 `...:v0.23.1`

### 4.2 拉取并重启 ragflow-cpu

```bash
docker compose --env-file .env -f docker-compose.yml pull ragflow-cpu
docker compose --env-file .env -f docker-compose.yml up -d ragflow-cpu
```

### 4.3 验证容器镜像与 SDK 版本

```bash
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
```

确认：

- `docker-ragflow-cpu-1` 使用 `.../ragflow:v0.23.1`

验证容器内 OpenAI SDK 版本：

```bash
docker exec docker-ragflow-cpu-1 python -c "import openai; print(openai.__version__)"
```

返回：

- `openai==2.11.0`

## 5. 在 RAGFlow UI 添加本地 OCR 模型（最终成功）

### 5.1 Provider 选择

- 选择：`OpenAI-API-Compatible`

### 5.2 模型添加参数

- 模型类型：`image2text`
- 模型名：`chandra-ocr`
- 基础 URL：`http://172.16.100.211:8082/v1`
- API-Key：`sk-local-ocr`

注意：RAGFlow 会将 API key 组装为 `Authorization: Bearer <key>` 形式转发到上游。

### 5.3 过程中出现的 401（鉴权问题）

在 v0.23.1 下，若 RAGFlow 侧仍报：

```json
{
  "code": 102,
  "message": "Fail to access model(OpenAI-API-Compatible/chandra-ocr). Error code: 401 - { ... Invalid API Key ... }"
}
```

处理方式：

- 确认 UI 中 API-Key 字段仅填写：`sk-local-ocr`
- 避免前后空格/换行
- 确认 base_url 为 `.../v1`

之后成功添加 `chandra-ocr`，并可在应用模型配置的 `VLM` 下拉中选中。

## 6. 备注：聊天入口未必会触发 OCR（重要）

即便已在 `VLM` 中选择了 `chandra-ocr`，在“聊天”入口发送消息时，RAGFlow 仍可能优先使用默认 `LLM`（例如 `z-ai/glm-4.5-air:free`），导致：

- 后端日志显示 LiteLLM 调用 `glm-4.5-air:free`
- `chandra-ocr` 未被实际请求
- GPU 使用率为 0

这属于产品路由/工作流设计差异：OCR 多数情况下更偏向“文档解析/导入/工具能力”，需要通过对应入口/工具链路触发。

## 7. 版本切换与部署文件位置（补充）

- Compose 文件：`/home/zhengxueen/workspace/ragflow/docker/docker-compose.yml`
- 环境变量：`/home/zhengxueen/workspace/ragflow/docker/.env`

## 8. 最终结果

- RAGFlow：`v0.23.1`
- `OpenAI-API-Compatible` 已成功添加本地 OCR：`chandra-ocr`（image2text）
- 可在应用配置中选择 `VLM = chandra-ocr`

