```bash

docker pull ollama/ollama:rocm

```

  

### 步骤 3: 启动并配置 Ollama 容器

  

这是整个配置过程的核心。以下命令将创建一个完整配置的容器，请直接复制并执行。

  

```bash

docker run -d \
  --name ollama \
  --device=/dev/kfd \
  --device=/dev/dri \
  -e HSA_OVERRIDE_GFX_VERSION=9.0.6 \
  -e HCC_AMDGPU_TARGET=gfx906 \
  -v ollama:/root/.ollama \
  -p 11434:11434 \
  --restart always \
  ollama/ollama:rocm

```

  

#### 命令参数详解:

  

-   `-d`: 在后台以分离模式运行容器。

-   `--name ollama`: 为容器指定一个易于管理的名称 `ollama`。

-   `--device=/dev/kfd --device=/dev/dri`: **[核心]** 将主机的 ROCm 内核设备挂载到容器内部，这是容器访问 GPU 硬件的桥梁。

-   `-e ROCR_VISIBLE_DEVICES=0`: **[核心]** 指定容器内可见的 GPU 设备 ID。如果您的 MI50 在 `rocm-smi` 中显示为设备 0，则设为 `0`。

-   `-e HSA_OVERRIDE_GFX_VERSION=9.0.6`: **[核心]** 强制 ROCm 运行时将 GPU 识别为 `gfx906` 架构。

-   `-e HCC_AMDGPU_TARGET=gfx906`: **[核心]** 强制 ROCm 底层编译器以 `gfx906` 为目标进行编译。

-   `-v ollama:/root/.ollama`: 创建一个 Docker 卷来持久化存储 Ollama 的模型文件，即使容器被删除，模型数据也不会丢失。

-   `-p 11434:11434`: 将主机的 11434 端口映射到容器的 11434 端口，以便从外部访问 Ollama 服务。

-   `--restart always`: 设置容器总是在退出后自动重启，确保服务的健壮性。

-   `ollama/ollama:rocm`: 指定使用我们下载的包含 ROCm 库的专用镜像。


常用命令参考

```bash
# 进入 Ollama 容器内部
sudo docker exec -it ollama bash

ollama run gpt-oss:20b

# 查看 Ollama 容器日志
docker logs -f ollama

# 监控 GPU 状态
watch -n 0.5 rocm-smi

# 拉取新模型
docker exec -it ollama ollama pull llama3:70b

# 重启 Ollama 服务
docker restart ollama
```