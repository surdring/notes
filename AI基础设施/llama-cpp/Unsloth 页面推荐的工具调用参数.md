Unsloth 页面推荐的工具调用参数，以下是完整的启动指令：

## Qwen3.6 工具调用完整指令

```bash
llama-server \
  -m Qwen3.6-35B-A3B-Q4_K_M.gguf \
  --chat-template qwen3 \
  --chat-template-kwargs '{"enable_thinking":false}' \
  --temperature 0.7 \
  --top-p 0.8 \
  --top-k 20 \
  --presence-penalty 1.5 \
  --repeat-penalty 1.0 \
  -c 32768 \
  -ngl 999 \
  --host 0.0.0.0 \
  --port 8080
```

## Qwen3.5 工具调用完整指令

```bash
llama-server \
  -m Qwen3.5-35B-A3B-Q4_K_M.gguf \
  --chat-template qwen3 \
  --chat-template-kwargs '{"enable_thinking":false}' \
  --temperature 0.7 \
  --top-p 0.8 \
  --top-k 20 \
  --presence-penalty 1.5 \
  --repeat-penalty 1.0 \
  -c 32768 \
  -ngl 999 \
  --host 0.0.0.0 \
  --port 8080
```

## 参数说明

| 参数 | 值 | 说明 |
|-----|---|------|
| `--chat-template` | `qwen3` | 使用 Qwen3 聊天模板（兼容 3.5/3.6）|
| `--chat-template-kwargs` | `{"enable_thinking":false}` | **禁用思考模式**，工具调用更稳定 |
| `--temperature` | `0.7` | 低温度保证输出稳定 |
| `--top-p` | `0.8` | 核采样阈值 |
| `--top-k` | `20` | Top-K 采样 |
| `--presence-penalty` | `1.5` | 减少重复，提高工具调用成功率 |
| `--repeat-penalty` | `1.0` | 禁用重复惩罚（或设为 1.0）|
| `-c` | `32768` | 上下文长度（可根据需要调整）|
| `-ngl` | `999` | GPU 卸载层数（全部卸载到 GPU）|

## OpenAI 兼容调用示例

```python
from openai import OpenAI

client = OpenAI(base_url="http://localhost:8080/v1", api_key="dummy")

response = client.chat.completions.create(
    model="qwen3.5",  # 或 qwen3.6
    messages=[{"role": "user", "content": "查询北京天气"}],
    temperature=0.7,
    top_p=0.8,
    presence_penalty=1.5,
    tools=[{
        "type": "function",
        "function": {
            "name": "get_weather",
            "description": "获取城市天气",
            "parameters": {
                "type": "object",
                "properties": {
                    "city": {"type": "string", "description": "城市名称"}
                },
                "required": ["city"]
            }
        }
    }]
)
```