
### 先停容器，改启动命令，再起容器
```bash
sudo docker stop vllm-gfx906
sudo docker rm vllm-gfx906
```
### 方案 A：只用 单卡
```bash
sudo docker run -itd \
  --name vllm-gfx906 \
  --restart=unless-stopped \
  --network=host \
  --ipc=host \
  --shm-size=32g \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add video \
  --group-add render \
  -e ROCR_VISIBLE_DEVICES=1 \
  -e HSA_OVERRIDE_GFX_VERSION=9.0.6 \
  -e HCC_AMDGPU_TARGET=gfx906 \
  -v /home/zhengxueen/model:/model \
  -v /home/zhengxueen/workspace/localworkspace:/workspace \
  -v /home/zhengxueen/vllm-root:/root \
  nalanzeyu/vllm-gfx906
```

### 方案 B：用 **两张卡 GPU0+GPU1**

```bash
sudo docker run -itd \
  --name vllm-gfx906 \
  --restart=unless-stopped \
  --network=host \
  --ipc=host \
  --shm-size=32g \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add video \
  -e ROCR_VISIBLE_DEVICES=0,1 \
  -e HSA_OVERRIDE_GFX_VERSION=9.0.6 \
  -e HCC_AMDGPU_TARGET=gfx906 \
  -v /home/zhengxueen/model:/model \
  -v /home/zhengxueen/workspace/localworkspace:/workspace \
  -v /home/zhengxueen/vllm-root:/root \
  nalanzeyu/vllm-gfx906
```

## 进入容器 + 启动 PaddleOCR‑VL‑1.5（vLLM OpenAI 兼容服务）

## 1) 先进入容器（交互式
```bash
sudo docker exec -it vllm-gfx906 bash
```

## 2) 在容器里确认模型目录（你需要把路径填进启动命令）
```bash
ls -lah /model
```
(假设你看到模型目录类似：

- `/model/PaddleOCR-VL-1.5` 或
    
- `/model/PaddlePaddle/PaddleOCR-VL-1.5`
    

并且目录内至少有：`config.json`、`model.safetensors`、tokenizer/processor 相关文件。)

## 3) 启动 vLLM 服务（推荐：本地路径方式，不依赖外网下载）



**先验证再启动 vLLM**
```bash
unset HIP_VISIBLE_DEVICES
export ROCR_VISIBLE_DEVICES=1

python - <<'PY'
import torch
print("cuda.is_available:", torch.cuda.is_available())
print("device_count:", torch.cuda.device_count())
if torch.cuda.is_available():
    p = torch.cuda.get_device_properties(0)
    print(0, p.name, getattr(p, "gcnArchName", None), f"{p.total_memory/1024**3:.1f} GiB")
PY
```

下面的 `MODEL_DIR` 真实目录：
```bash
unset HIP_VISIBLE_DEVICES
export ROCR_VISIBLE_DEVICES=1

MODEL_DIR="/model/PaddlePaddle"

vllm serve "$MODEL_DIR" \
  --served-model-name "PaddlePaddle" \
  --host 0.0.0.0 \
  --port 8011 \
  --trust-remote-code \
  --dtype float16 \
  --max-num-batched-tokens 8192 \
  --no-enable-prefix-caching \
  --mm-processor-cache-gb 0
```
## vLLM 的“张量并行”

```bash
unset HIP_VISIBLE_DEVICES
export ROCR_VISIBLE_DEVICES=0,1

MODEL_DIR="/model/PaddlePaddle"

vllm serve "$MODEL_DIR" \
  --served-model-name "PaddlePaddle" \
  --host 0.0.0.0 \
  --port 8011 \
  --trust-remote-code \
  --dtype float16 \
  --tensor-parallel-size 2 \
  --max-num-batched-tokens 8192 \
  --no-enable-prefix-caching \
  --mm-processor-cache-gb 0
```

## 先试单卡（GPU1），再试双卡

- **单卡**：用 `HIP_VISIBLE_DEVICES=1` + 不加 `--tensor-parallel-size`
    
- **双卡**：用 `HIP_VISIBLE_DEVICES=0,1` + `--tensor-parallel-size 2`

