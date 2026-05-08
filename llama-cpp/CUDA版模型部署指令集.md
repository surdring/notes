# CUDA 版 llama.cpp 模型部署指令集

> 硬件：NVIDIA RTX 3080 20GB  
> 构建：spiritbuun/buun-llama-cpp（支持 TCQ/TurboQuant KV Cache + DFlash）  
> llama-server 路径：`/home/zheng/workspace/buun-llama-cpp/build/bin/llama-server`  
> 模型路径：`/home/zheng/models`  

---

## 通用说明

### KV Cache 量化类型（buun-llama-cpp 支持）

| 类型 | 精度 | 压缩比 | 推荐场景 |
|------|------|--------|---------|
| `turbo4` | 4.25 bpv | 3.8x | 安全默认，几乎无损 |
| `turbo3_tcq` | 3.25 bpv | ~5x | 3-bit 最佳质量，短上下文超越 FP16 |
| `turbo3` | 3.25 bpv | ~5x | 标量版，更快编码但质量不如 TCQ |
| `turbo2_tcq` | 2.25 bpv | ~7x | 极端显存压力 |
| `turbo3_tcq + turbo2_tcq` | 2.75 bpv | ~5.5x | 非对称，2-bit 最佳质量 |
| `q8_0` | 8 bpv | 2x | 无损参考 |

### GPU 层数调整（-ngl）

20GB 显存有限，部分大模型需要将部分层 offload 到 CPU：

| 模型大小 | Q4_K_M 权重 | 推荐 -ngl | GPU 占用估算 |
|---------|------------|-----------|-------------|
| 9B | ~5.5 GB | 999 (全 GPU) | ~6 GB ✅ |
| 20B | ~12 GB | 999 (全 GPU) | ~13 GB ✅ |
| 27B Q4_K_M | ~16 GB | 50 | ~18 GB ✅ |
| 27B Q8_0 | ~29 GB | 30 | ~14 GB + CPU |
| 31B Q4_K_M | ~18 GB | 40 | ~15 GB + CPU |
| 35B MoE Q5_K_M | ~24 GB | 40 | ~16 GB + CPU |

### DFlash 投机解码

```bash
# 添加 drafter 模型参数
-md /home/zheng/models/dflash-draft-3.6-q8_0.gguf \
--spec-type dflash \
```

> 注意：Q3.6 drafter 的 SWA 层在 Q4 下接受率暴跌（~43% → ~28%），建议 drafter 用 Q8_0

---

## 模型启动命令

### Qwen3.6-27B（DFlash 投机解码 + TCQ）

```bash
CUDA_VISIBLE_DEVICES=0 \
/home/zheng/workspace/buun-llama-cpp/build/bin/llama-server \
  --model /home/zheng/models/TeichAI-Qwen3.6-27B-Claude-Opus-Reasoning-Distill-v2-q4_k_m.gguf \
  -md /home/zheng/models/dflash-draft-3.6-q8_0.gguf \
  --spec-type dflash \
  --ctx-size 8192 \
  -ngl 999 -fa on \
  -np 1 -cd 256 -b 256 -ub 64 \
  --jinja \
  --threads 8 \
  --temperature 0.7 \
  --top-p 0.8 \
  --top-k 20 \
  --host 0.0.0.0 \
  --min-p 0.00 \
  --port 8080 \
  --mlock \
  --alias Qwen3.6-27B
# --chat-template-kwargs '{"enable_thinking":false}' \  -ctk turbo3_tcq -ctv turbo3_tcq \
```

### Qwen3.6-27B（纯 TCQ，无 DFlash，更长上下文）

```bash
CUDA_VISIBLE_DEVICES=0 \
/home/zheng/workspace/buun-llama-cpp/build/bin/llama-server \
  --model /home/zheng/models/Qwen3.6-27B/Qwen3.6-27B-Q4_K_M.gguf \
  --ctx-size 32768 \
  -ngl 50 -fa on \
  -ctk turbo3_tcq -ctv turbo3_tcq \
  -np 1 \
  --jinja \
  --threads 8 \
  --temperature 0.7 \
  --top-p 0.8 \
  --top-k 20 \
  --host 0.0.0.0 \
  --min-p 0.00 \
  --port 8080 \
  --mlock \
  --alias Qwen3.6-27B
# --chat-template-kwargs '{"enable_thinking":false}' \
```

### Qwen3.6-27B Q8_0（高质量，大量 CPU offload）

```bash
CUDA_VISIBLE_DEVICES=0 \
/home/zheng/workspace/buun-llama-cpp/build/bin/llama-server \
  --model /home/zheng/models/Qwen3.6-27B/Qwen3.6-27B-Q8_0.gguf \
  --ctx-size 65536 \
  -ngl 30 -fa on \
  -ctk turbo4 -ctv turbo4 \
  -np 1 \
  --jinja \
  --threads 8 \
  --temperature 0.7 \
  --top-p 0.8 \
  --top-k 20 \
  --host 0.0.0.0 \
  --min-p 0.00 \
  --port 8080 \
  --mlock \
  --alias Qwen3.6-27B-Q8
# --chat-template-kwargs '{"enable_thinking":false}' \
```

### Qwen3.6-35B-A3B MoE（多模态 + TCQ）

```bash
CUDA_VISIBLE_DEVICES=0 \
/home/zheng/workspace/buun-llama-cpp/build/bin/llama-server \
  --model /home/zheng/models/Qwen3.6-35B-A3B/Qwen3.6-35B-A3B-Q5_K_M.gguf \
  --mmproj /home/zheng/models/Qwen3.6-35B-A3B/mmproj-BF16.gguf \
  --ctx-size 131072 \
  -ngl 40 -cram 0 -np 1 \
  -fa on \
  -ctk turbo3_tcq -ctv turbo3_tcq \
  --jinja \
  --threads 8 \
  --temperature 0.7 \
  --top-p 0.8 \
  --top-k 20 \
  --host 0.0.0.0 \
  --min-p 0.00 \
  --port 8080 \
  --mlock \
  --alias Qwen3.6-35B-A3B
# --chat-template-kwargs '{"enable_thinking":false}' \
```

### Gemma 4 31B（TCQ）

```bash
CUDA_VISIBLE_DEVICES=0 \
/home/zheng/workspace/buun-llama-cpp/build/bin/llama-server \
  --model /home/zheng/models/Gemma4/gemma-4-31B-Q4_K_M.gguf \
  --ctx-size 65536 \
  -ngl 40 -cram 0 -np 1 \
  -fa on \
  -ctk turbo3_tcq -ctv turbo3_tcq \
  --jinja \
  --threads 8 \
  --top-p 0.95 \
  --top-k 64 \
  --temp 1.0 \
  --host 0.0.0.0 \
  --min-p 0.00 \
  --port 8080 \
  --mlock \
  --alias gemma-4-31B
```

### Gemma 4 26B A4B MoE（TCQ）

```bash
CUDA_VISIBLE_DEVICES=0 \
/home/zheng/workspace/buun-llama-cpp/build/bin/llama-server \
  --model /home/zheng/models/gemma-4-26B-A4B/gemma-4-26B-A4B-Q4_K_M.gguf \
  --ctx-size 131072 \
  -ngl 50 -cram 0 -np 1 \
  -fa on \
  -ctk turbo3_tcq -ctv turbo3_tcq \
  --jinja \
  --threads 8 \
  --top-p 0.95 \
  --top-k 64 \
  --temp 1.0 \
  --host 0.0.0.0 \
  --min-p 0.00 \
  --port 8080 \
  --mlock \
  --alias gemma-4-26B
```

### Qwen3.5-9B（小模型，全 GPU）

```bash
CUDA_VISIBLE_DEVICES=0 \
/home/zheng/workspace/buun-llama-cpp/build/bin/llama-server \
  --model /home/zheng/models/Qwen3.5-9B/Qwen3.5-9B-Q8_0.gguf \
  --mmproj /home/zheng/models/Qwen3.5-9B/mmproj-BF16.gguf \
  --ctx-size 65536 \
  -ngl 999 -fa on \
  -ctk turbo4 -ctv turbo4 \
  --jinja \
  --threads 8 \
  --top-p 0.8 \
  --top-k 20 \
  --temp 0.7 \
  --host 0.0.0.0 \
  --min-p 0.00 \
  --port 8080 \
  --alias Qwen3.5-9B
```

### GPT-OSS-20B

```bash
CUDA_VISIBLE_DEVICES=0 \
/home/zheng/workspace/buun-llama-cpp/build/bin/llama-server \
  -m /home/zheng/models/gpt-oss-20b-Q4_K_M.gguf \
  -c 32684 \
  -ngl 999 -fa on \
  -ctk turbo4 -ctv turbo4 \
  --jinja \
  --temp 1.0 --top-p 1.0 --top-k 0 \
  --host 0.0.0.0 \
  --port 8080 \
  --alias gpt-oss-20b
```

### OCR 模型（chandra）

```bash
CUDA_VISIBLE_DEVICES=0 \
/home/zheng/workspace/buun-llama-cpp/build/bin/llama-server \
  --model /home/zheng/models/chandra-ocr/chandra-Q4_K_M.gguf \
  --mmproj /home/zheng/models/chandra-ocr/chandra-mmproj-f16.gguf \
  --ctx-size 51200 \
  -ngl 999 -fa on \
  -ctk turbo4 -ctv turbo4 \
  --jinja \
  --threads 8 \
  --presence-penalty 0.0 \
  --host 0.0.0.0 \
  --api-key sk-local-ocr \
  --port 8082 \
  --alias chandra-ocr
```

---

## 极端省显存配置（20GB 3080 专用）

### Qwen3.6-27B 最大压缩：2-bit TCQ + CPU offload

```bash
CUDA_VISIBLE_DEVICES=0 \
/home/zheng/workspace/buun-llama-cpp/build/bin/llama-server \
  --model /home/zheng/models/Qwen3.6-27B/Qwen3.6-27B-Q4_K_M.gguf \
  --ctx-size 65536 \
  -ngl 40 -fa on \
  -ctk turbo3_tcq -ctv turbo2_tcq \
  -np 1 \
  --jinja \
  --threads 8 \
  --temperature 0.7 \
  --top-p 0.8 \
  --top-k 20 \
  --host 0.0.0.0 \
  --min-p 0.00 \
  --port 8080 \
  --mlock \
  --alias Qwen3.6-27B-extreme
```

### Qwen3.6-27B IQ4_XS + DFlash Q8_0（最佳 DFlash 方案）

```bash
CUDA_VISIBLE_DEVICES=0 \
/home/zheng/workspace/buun-llama-cpp/build/bin/llama-server \
  --model /home/zheng/models/Qwen3.6-27B/Qwen3.6-27B-IQ4_XS.gguf \
  -md /home/zheng/models/Qwen3.6-27B/dflash-draft-3.6-q8_0.gguf \
  --spec-type dflash \
  --ctx-size 8192 \
  -ngl 50 -fa on \
  -ctk turbo3_tcq -ctv turbo3_tcq \
  -np 1 -cd 256 -b 256 -ub 64 \
  --jinja \
  --threads 8 \
  --temperature 0.7 \
  --top-p 0.8 \
  --top-k 20 \
  --host 0.0.0.0 \
  --min-p 0.00 \
  --port 8080 \
  --mlock \
  --alias Qwen3.6-27B-dflash
# IQ4_XS ~12GB + Q8_0 drafter ~3.46GB + DDTree ~2GB ≈ 17.5GB，剩余 ~2.5GB KV
```

---

## 备注

- GGUF 模型需单独下载到 `/home/zheng/models/` 对应子目录
- DFlash drafter 模型从 `spiritbuun/Qwen3.6-27B-DFlash-GGUF` 下载
- `-ngl` 数值根据实际显存占用调整，OOM 时降低
- `--mlock` 防止模型被 swap 到磁盘，需要足够系统内存
- `--chat-template-kwargs '{"enable_thinking":false}'` 可关闭思维链输出
