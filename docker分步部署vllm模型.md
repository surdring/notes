### 创建vllm-gfx906容器

```bash
sudo docker run -itd \
--name vllm-gfx906 \
--restart=unless-stopped \
--network=host \
--ipc=host \
--shm-size=32g \
--device=/dev/kfd \
--device=/dev/dri \
-e ROCR_VISIBLE_DEVICES=0 \
-e HSA_OVERRIDE_GFX_VERSION=9.0.6 \
-e HCC_AMDGPU_TARGET=gfx906 \
--group-add video \
-p 8000:8000 \
-v /home/zhengxueen/model:/model \
-v /home/zhengxueen/workspace/localworkspace:/workspace \
-v /home/zhengxueen/vllm-root:/root \
nalanzeyu/vllm-gfx906
```

### 进入容器
```bash
docker exec -it vllm-gfx906 bash
```

### 运行模型
```bash
vllm serve /model/Qwen-32B-AWQ \
--quantization awq \
--max-model-len 5100 \
--disable-log-requests \
--dtype float16
```