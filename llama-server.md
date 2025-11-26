# 设置环境变量
export VK_DEVICE_INDEX=1
export ROCR_VISIBLE_DEVICES=0
export HSA_OVERRIDE_GFX_VERSION=9.0.6
export HIP_VISIBLE_DEVICES=0

# 运行 llama-server
cd /mnt/ssd/models/llama-b7136-bin-ubuntu-vulkan-x64/build/bin/
./llama-server \
  -m /mnt/ssd/models/Qwen3VL-32B-Thinking-Q4_K_M.gguf \
  --ctx-size 8192 \
  --n-gpu-layers -1 \
  --jinja \
  -ub 2048 \
  -b 2048 \
  --threads $(nproc) \
  --host 127.0.0.1 \
  --port 8080