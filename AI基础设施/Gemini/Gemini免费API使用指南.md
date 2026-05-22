### 一、获取 API Key（免费，无需信用卡）

只需 3 步：

1. **访问 Google AI Studio**  
   打开 https://aistudio.google.com/

2. **登录 Google 账号**，点击右上角 **"Get API Key"**

3. **创建并复制 API Key**（以 `AIzaSy...` 开头），保存好

> **注意**：免费层不需要绑定账单信息，直接用即可。

---

### 二、当前可免费使用的模型与配额

根据 Google 官方定价页和文档，当前免费层支持的模型及配额如下：

| 模型 | RPM | RPD | 上下文 | 特点 |
|---|---|---|---|---|
| **Gemini 3.5 Flash** | - | 免费 | 1M tokens | **最新最快**，推荐首选 |
| **Gemini 2.5 Flash** | 10 | 250 | 1M tokens | 性能速度均衡 |
| **Gemini 2.5 Flash-Lite** | 15 | 1,000 | 1M tokens | 极致速度，高频调用 |
| **Gemini 2.5 Pro** | 5 | 100 | 1M tokens | 最强推理能力 |

> 参考来源：[Google Gemini API Pricing](https://ai.google.dev/pricing)、[Gemini API 免费层级完整指南](https://juejin.cn/post/7572434032518365230)

---

### 三、快速上手代码示例

#### Python（推荐使用最新的 `google-genai` SDK）

```bash
pip install -q -U google-genai
```

```python
import os
from google import genai

# 方式1：设置环境变量 GEMINI_API_KEY
client = genai.Client()

# 方式2：或直接传入 key
# client = genai.Client(api_key="你的API_KEY")

response = client.models.generate_content(
    model="gemini-3.5-flash",
    contents="用中文解释什么是机器学习"
)
print(response.text)
```

如有代理需要，在代码中设置代理环境变量：

```python
import os
os.environ["HTTP_PROXY"] = "http://127.0.0.1:7897"
os.environ["HTTPS_PROXY"] = "http://127.0.0.1:7897"

from google import genai
client = genai.Client(api_key=os.environ["GEMINI_API_KEY"])
response = client.models.generate_content(
    model="gemini-3.5-flash",
    contents="用中文解释什么是机器学习"
)
print(response.text)
```

#### 流式响应

```python
response = client.models.generate_content_stream(
    model="gemini-3.5-flash",
    contents="写一首关于人工智能的短诗"
)
for chunk in response:
    print(chunk.text, end="", flush=True)
```

#### JavaScript / Node.js

```bash
npm install @google/genai
```

```javascript
import { GoogleGenAI } from "@google/genai";

const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY });

const response = await ai.models.generateContent({
    model: "gemini-3.5-flash",
    contents: "用中文解释什么是机器学习",
});
console.log(response.text);
```

#### cURL（最直接的方式）

```bash
export GEMINI_API_KEY="你的API_KEY"

curl -x http://127.0.0.1:7897 -k \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent" \
  -H "Content-Type: application/json" \
  -H "x-goog-api-key: $GEMINI_API_KEY" \
  -X POST \
  -d '{
    "contents": [{
      "parts": [{"text": "用中文解释什么是机器学习"}]
    }]
  }'
```

> **注意**：
> - `-x http://127.0.0.1:7897`：代理地址，按自己实际情况修改，如无代理则删掉这行
> - `-k`：跳过 SSL 证书验证，本地代理常有证书问题，加此参数可避免 `TLS connect error`
> - `x-goog-api-key` 的值**必须用双引号**（`"$GEMINI_API_KEY"`），单引号不会展开变量

---

### 四、多模态能力（免费也支持）

Gemini 原生支持图片、音频、视频、PDF 等：

```python
import PIL.Image

image = PIL.Image.open("screenshot.png")
response = client.models.generate_content(
    model="gemini-3.5-flash",
    contents=["这张图片里有什么？", image]
)
print(response.text)
```

---

### 五、OpenAI 兼容接口

如果你使用的工具/库只支持 OpenAI 格式，Gemini 也提供了兼容端点：

```python
from openai import OpenAI

client = OpenAI(
    api_key=os.environ["GEMINI_API_KEY"],
    base_url="https://generativelanguage.googleapis.com/v1beta/openai/"
)

response = client.chat.completions.create(
    model="gemini-3.5-flash",
    messages=[{"role": "user", "content": "你好！"}]
)
print(response.choices[0].message.content)
```

这样就能在 Cursor、Continue.dev、Aider 等工具中直接使用 Gemini 免费模型了。

---

### 六、常见错误排查

| 错误信息 | 原因 | 解决方法 |
|---|---|---|
| `Could not connect to server` | 网络无法直连 Google | 配置代理，加 `-x` 参数 |
| `TLS connect error: unexpected eof` | 代理的 SSL 证书不被信任 | 加 `-k` 跳过证书验证 |
| `403 PERMISSION_DENIED` / "Your project has been denied access" | 项目被封禁（常见：API Key 泄露后被滥用） | 在 AI Studio **创建新项目**生成新 Key，旧项目已无效 |
| `429 RESOURCE_EXHAUSTED` | 超出免费配额限制 | 等待配额重置（北京时间下午 4 点），或改用 Flash-Lite 模型（额度更高） |
| `curl: (3) URL rejected` | 模型名错误或不合法 | 检查模型名，如 `gemini-flash-latest` 是无效名，应使用 `gemini-3.5-flash` |

#### 关键排查技巧

- 分步测试：先测代理连通性 `curl -x http://127.0.0.1:7897 -I https://www.google.com`
- 环境变量：`x-goog-api-key` 必须用双引号 `"$KEY"`，不要用单引号
- 模型名：`gemini-flash-latest` 不是合法名，当前有效的是 `gemini-3.5-flash`、`gemini-2.5-flash` 等

---

### 七、注意事项

1. **配额重置时间**：每日太平洋时间午夜（北京时间下午 4 点）自动重置
2. **超限错误**：超出限制会返回 `429 RESOURCE_EXHAUSTED` 错误
3. **国内访问**：需要能够访问 Google 服务的网络环境（代理/VPN）
4. **模型名称**：目前最新的免费模型是 `gemini-3.5-flash`，此外还有 `gemini-2.5-flash`、`gemini-2.5-flash-lite` 等
5. **API Key 安全**：不要泄露 Key，泄露后立即去 AI Studio 撤销并创建新 Key