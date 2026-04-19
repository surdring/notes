# 在本地部署的 llama.cpp 上接入 n8n / Dify 指南（基于 MI50 + ROCm）

本指南说明如何将你目前在本机（MI50 + ROCm）上运行的 llama.cpp（llama-server）暴露为 **OpenAI 兼容接口**，并在 **n8n** 和 **Dify** 里当作「自建大模型」来使用。

> 假设前提：
>
> - 已按《ROCm-llama.cpp-MI50-构建与运行指南》编译好 llama-server（HIP 后端，目录为 /mnt/sata/knowledge/notes/llama.cpp-rocm/build-hip/bin）。
> - 模型文件位于 /mnt/ssd/models/...，例如 gpt-oss-20b-mxfp4.gguf 或 Qwen3-VL-8B-Thinking-1M-Q4_K_M.gguf。
> - 你希望通过 HTTP/OpenAI API 方式被 n8n / Dify 访问。

---

## 1. 启动本地 llama-server（OpenAI 兼容接口）

先在服务器（本机或内网机器）上启动 llama-server，开启 OpenAI 兼容接口。

### 1.1 文本模型示例（Qwen3VL-32B-Thinking）以模型部署指令集.md为参考配置

bash
cd /home/zhengxueen/workspace/llama.cpp

HIP_VISIBLE_DEVICES=0 \
./build-hip/bin/llama-server \
  --model /mnt/ssd/models/gpt-oss-20b-mxfp4.gguf \
  --ctx-size 0 \
  --n-gpu-layers -1 \
  --jinja \
  --flash-attn on \
  --top-p 0.95 \
  --top-k 20 \
  --temp 1.0 \
  --presence-penalty 0.0 \
  --host 0.0.0.0 \
  --port 8080 \
  --api-key local-llama-key \
  --alias gpt-oss-20b
# 如遇 GFX 版本报错，可在最前面额外加：
# HSA_OVERRIDE_GFX_VERSION=9.0.6 \


**模型信息**：
- **最大上下文长度**：131,072 tokens（约 131k）
- **词汇表大小**：201,088 tokens
- **参数量**：209.1 亿（20.9B）
- **模型文件大小**：约 11.3 GB

**Dify 配置参数**：
- **OpenAI-API-compatible**：✓ 已启用
- **模型名称***：gpt-oss-20b
- **模型类型***：LLM（大语言模型）

**模型凭据**：
- **凭据名称**：自定义（如：gpt-oss-20b-local）
- **模型显示名称**：自定义（如：GPT-OSS-20B (Local)）
- **API Key***：local-llama-key
- **API endpoint URL***：http://172.16.100.202:8080/v1
- **API endpoint中的模型名称***：gpt-oss-20b
- **Completion mode**：chat_completion

**高级配置**：
- **模型上下文长度***：131072（或根据需要设置更小值）
- **最大 token 上限**：4096（建议值，可调整）
- **Agent Thought**：✓ 支持
- **Function calling**：✓ 支持
- **Stream function calling**：✓ 支持
- **Vision**：✗ 不支持（纯文本模型）
- **Structured Output**：✓ 支持
- **Stream mode auth**：API Key 验证
- **流模式返回结果的分隔符**：data: （OpenAI 标准格式）

关键点：

- **--host 0.0.0.0**：允许局域网其他机器（运行 n8n / Dify 的节点）访问。
- **--port 8080**：HTTP 端口，下面会用到 http://服务器IP:8080。
- **--api-key local-llama-key**：开启简单的 API Key 验证，客户端需要在 HTTP 头里带 Authorization: Bearer local-llama-key。
- **--alias gpt-oss-20b**：给模型起一个别名，方便在 OpenAI 兼容接口里用 "model": "gpt-oss-20b" 引用。

### 1.2 多模态模型示例（Qwen3-VL-8B-Thinking-1M）

如需在将来被支持多模态的工具中使用（或直接用 curl 测试），可以这样启动：

bash
cd /home/zhengxueen/workspace/llama.cpp

HIP_VISIBLE_DEVICES=0 \
./build-hip/bin/llama-server \
  --model /mnt/ssd/models/Qwen3-VL-8B-Thinking-1M-Q4_K_M/Qwen3-VL-8B-Thinking-1M-Q4_K_M.gguf \
  --mmproj /mnt/ssd/models/Qwen3-VL-8B-Thinking-1M-Q4_K_M/mmproj-F16.gguf \
  --ctx-size 51200 \
  --n-gpu-layers -1 \
  --jinja \
  --flash-attn on \
  --top-p 0.95 \
  --top-k 20 \
  --temp 1.0 \
  --presence-penalty 0.0 \
  --host 0.0.0.0 \
  --port 8081 \
  --api-key local-llama-key \
  --alias qwen3vl-8b
# 如遇 GFX 版本报错，可在最前面额外加：
# HSA_OVERRIDE_GFX_VERSION=9.0.6 \


**模型信息**：
- **最大上下文长度**：1,000,000 tokens（约 1M）
- **词汇表大小**：151,936 tokens
- **参数量**：81.9 亿（8.1B）
- **模型文件大小**：约 4.68 GB
- **多模态支持**：文本 + 图像（需要 --mmproj 文件）

**Dify 配置参数**：
- **OpenAI-API-compatible**：✓ 已启用
- **模型名称***：qwen3vl-8b
- **模型类型***：LLM（大语言模型）

**模型凭据**：
- **凭据名称**：自定义（如：qwen3vl-8b-local）
- **模型显示名称**：自定义（如：Qwen3-VL-8B (Local)）
- **API Key***：local-llama-key
- **API endpoint URL***：http://172.16.100.202:8081/v1
- **API endpoint中的模型名称***：qwen3vl-8b
- **Completion mode**：chat_completion

**高级配置**：
- **模型上下文长度***：51200（或根据需要设置，最大支持 1000000）
- **最大 token 上限**：4096（建议值，可调整）
- **Agent Thought**：✓ 支持
- **Function calling**：✓ 支持
- **Stream function calling**：✓ 支持
- **Vision**：✓ 支持（多模态模型）
- **Structured Output**：✓ 支持
- **Stream mode auth**：API Key 验证
- **流模式返回结果的分隔符**：data: （OpenAI 标准格式）

> n8n / Dify 目前主要面向**文本对话**场景，多模态能力依赖它们自身是否支持图片输入。即便如此，上述命令仍然兼容文本聊天。

### 1.3多模态模型示例（gemma-3-27b）
cd /home/zhengxueen/workspace/llama.cpp
HIP_VISIBLE_DEVICES=0 \
./build-hip/bin/llama-server \
  --model /mnt/ssd/models/gemma-3-27b/gemma-3-27b-it-Q4_K_M.gguf \
  --mmproj /mnt/ssd/models/gemma-3-27b/mmproj-F16.gguf \
  --ctx-size 0 \
  --n-gpu-layers -1 \
  --jinja \
  --flash-attn on \
  --top-p 0.95 \
  --top-k 20 \
  --temp 1.0 \
  --presence-penalty 0.0 \
  --host 0.0.0.0 \
  --port 8082 \
  --api-key local-llama-key \
  --alias gemma-3-27b

### 1.4多模态模型示例（Qwen3-VL-32B）
cd /home/zhengxueen/workspace/llama.cpp
HIP_VISIBLE_DEVICES=0 \
./build-hip/bin/llama-server \
  --model /mnt/ssd/models/unsloth-Qwen3-VL-32B-Thinking-1M/Qwen3-VL-32B-Thinking-1M-Q4_K_M.gguf \
  --mmproj /mnt/ssd/models/unsloth-Qwen3-VL-32B-Thinking-1M/mmproj-F16.gguf\
  --ctx-size 8192 \
  --n-gpu-layers -1 \
  --jinja \
  --flash-attn on \
  --top-p 0.95 \
  --top-k 20 \
  --temp 1.0 \
  --presence-penalty 0.0 \
  --host 0.0.0.0 \
  --port 8082 \
  --api-key local-llama-key \
  --alias Qwen3-VL-32B

### 1.5多模态模型示例（chandra-ocr）
cd /home/zhengxueen/workspace/llama.cpp

HIP_VISIBLE_DEVICES=0 \
./build-hip/bin/llama-server \
  --model /mnt/ssd/models/chandra-ocr/chandra-Q4_K_M.gguf \
  --mmproj /mnt/ssd/models/chandra-ocr/chandra-mmproj-f16.gguf\
  --ctx-size 51200\
  --n-gpu-layers -1 \
  --jinja \
  --flash-attn on \
  --presence-penalty 0.0 \
  --host 0.0.0.0 \
  --port 8080 \
  --alias chandra-ocr

HIP_VISIBLE_DEVICES=0 \
./build-hip/bin/llama-server \
  --model /mnt/ssd/models/chandra-ocr/chandra-F16.gguf \
  --mmproj /mnt/ssd/models/chandra-ocr/chandra-mmproj-f16.gguf\
  --ctx-size 8192\
  --n-gpu-layers -1 \
  --jinja \
  --flash-attn on \
  --top-p 0.95 \
  --top-k 20 \
  --temp 1.0 \
  --presence-penalty 0.0 \
  --host 0.0.0.0 \
  --port 8080 \
  --alias chandra-ocr
---

## 3. 在 n8n 中使用本地 llama.cpp

以下以 n8n 1.x 带的 **OpenAI / Chat Model** 节点为例，说明如何把本地服务器当作 OpenAI 兼容接口来使用。

### 3.1 创建 OpenAI 凭据（指向本地服务器）

1. 打开 n8n Web UI（例如 http://n8n.example.com/）。
2. 左侧点击 **Credentials / 凭据** → 新建 **OpenAI** 类型的凭据。
3. 在凭据表单中：
   - **API Key**：填写 local-llama-key。
   - 如果有 **Base URL / Host** 字段，填写：
     - http://<你的服务器 IP>:8080/v1
   - 如果有 **Organization** 字段，保持默认或留空即可。
4. 保存凭据。

> 不同版本的 n8n UI 字段名称略有不同，但核心是：
>
> - 把 API Key 改成你本地 llama-server --api-key 的值；
> - 把 Base URL 从 https://api.openai.com/v1 改成 http://你的服务器:8080/v1。

### 3.2 在工作流中调用本地模型

1. 新建一个 Workflow。
2. 添加一个 **OpenAI / Chat Model** 或 **OpenAI** 节点：
   - 在 **Credentials** 中选用刚才创建的 OpenAI 凭据。
   - 在 **Model** 字段填入：gpt-oss-20b（或者你设置的 --alias 名称）。
   - 在 Prompt / Messages 中输入你的问题，例如：“你好，请用中文回答”。
3. 运行节点，观察输出是否来自本地模型：
   - 同时在运行 llama-server 的终端中，可以看到对应的请求日志。

> 如果你在 8081 端口另起了一个多模态模型（如 qwen3vl-8b），可以在 n8n 里再创建一套凭据，将 Base URL 改成 http://服务器:8081/v1，Model 改成对应 alias。

---

## 4. 在 Dify 中使用本地 llama.cpp

Dify 支持配置「自定义 OpenAI 兼容模型提供商」，可以直接指向本地 llama-server。

> 下面步骤基于较新的 Dify Web 管理界面，具体菜单名称可能略有出入，但概念是相同的：

### 4.1 添加 OpenAI 兼容的模型提供商

1. 登录 Dify 管理后台（例如 http://dify.example.com/）。
2. 进入 **设置 / Settings** → **模型提供商 / Model Providers**。
3. 找到 **OpenAI API Compatible** 提供商，点击配置。
4. 在配置表单中填写：
   - **Base URL**：http://<你的服务器 IP>:8080/v1（注意：不能用 127.0.0.1）
   - **API Key**：local-llama-key
   - **模型名称**：gpt-oss-20b
1. 保存后，Dify 会把这个提供商当作一个 OpenAI 兼容源。

### 4.2 添加多个模型

如果你同时运行了多个 llama-server（如 8080 和 8081 端口），可以：

1. **方法一：分别添加模型**
   - 在 OpenAI API Compatible 提供商中，点击「添加模型」
   - 为每个模型单独配置 Base URL 和模型名：
     - 模型 1：Base URL http://172.16.100.202:8080/v1，模型名 gpt-oss-20b
     - 模型 2：Base URL http://172.16.100.202:8081/v1，模型名 qwen3vl-8b

2. **方法二：使用同一个端点**
   - 如果两个模型在同一个 llama-server 实例中，只需配置一次 Base URL

### 4.3 在应用中选用本地模型

1. 在 Dify 中新建或编辑一个应用（Chatbot、Agent 等）。
2. 在模型选择处，将模型提供商切换为刚才添加的本地 OpenAI 兼容提供商。
3. 选择对应的模型名称：gpt-oss-20b 或 qwen3vl-8b。
4. 保存应用，开始对话：此时请求会通过 Dify → 本地 llama-server → MI50 上的 llama.cpp 执行推理。

---

## 5. 常见问题排查

### 5.1 401 Unauthorized / 鉴权失败

- 确认 llama-server 启动时是否带了 --api-key：
  - 若带了：客户端必须在 HTTP 头中使用：Authorization: Bearer local-llama-key。
  - 若没带：可以先去掉 n8n / Dify 里配置的 API Key，再测试。
- n8n 中如果还有「旧的」 OpenAI 凭据（指向官方 API），注意不要混用。

### 5.2 连接超时 / 无法连接

- 确认 llama-server 是否使用 --host 0.0.0.0，而不是默认的 127.0.0.1：
  - 如果是 127.0.0.1，只允许本机访问，其他机器上的 n8n / Dify 访问不到。
- 检查防火墙 / 安全组：
  - 本机 ufw 或云厂商安全组是否允许外部访问 8080 端口。

### 5.3 模型名不匹配 / 404

- Dify / n8n 中的 model 字段，要和你启动 llama-server 时指定的名字一致：
  - 若使用 --alias gpt-oss-20b，则客户端应使用："model": "gpt-oss-20b"。
  - 若使用 --alias qwen3vl-8b，则客户端应使用："model": "qwen3vl-8b"。
  - 若没用 --alias，则使用默认模型文件名（通常较长，不推荐）。

### 5.4 显存不足 / OOM

- 依旧遵循 MI50 上的调优经验：
  - 降低 --ctx-size；
  - 降低 --n-gpu-layers；
  - 使用更高量化等级（如 Q4_K_M）；
- 这些调整对 n8n / Dify 透明，只需重启 llama-server 即可。

### 5.5 Dify 400 错误 / PluginInvokeError

如果 Dify 中添加模型时出现 400 错误，通常是因为：

1. **Base URL 配置错误**
   - 不能使用 127.0.0.1 或 localhost
   - 必须使用宿主机 IP（如 172.16.100.202）
   - 确保端口正确（8080 或 8081）

2. **模型名称不匹配**
   - Dify 中的模型名必须与 --alias 完全一致
   - 区分大小写

3. **API Key 不一致**
   - 确保 Dify 中的 API Key 与 llama-server 的 --api-key 一致

4. **llama-server 未正常启动**
   - 检查对应端口的 /v1/models 是否可访问
   - 查看 llama-server 启动日志是否有错误

---

## 6. 小结与推荐实践

- **推荐做法**：
  - 在 MI50 上以 HIP 后端运行 llama-server，开启 --api-key 并监听 0.0.0.0:8080；
  - 在所有需要使用本地大模型的工具（n8n / Dify / 其他）里，统一配置：
    - Base URL：http://服务器IP:8080/v1
    - API Key：与你 --api-key 一致
    - Model：与你 --alias 一致
- 这样你的整套工作流都可以无缝切换到 MI50 上的本地 llama.cpp，既避免外网访问，又充分利用 GPU 资源。
