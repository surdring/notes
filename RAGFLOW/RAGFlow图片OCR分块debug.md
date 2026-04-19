# RAGFlow图片OCR分块详细日志说明

本文档说明 RAGFlow 在解析图片（`ParserType=Picture`）时，任务详情里新增的更详细日志字段，用于定位 OCR 结果与分块行为（尤其是表格图片“按单元格爆炸式分块”的问题）。

## 1. 日志出现位置

这些日志通过 `progress_callback(...)` 写入，显示在：

- 知识库 -> 文件列表 -> 选择文件 -> 任务详情（详情/日志时间线）

它们不是容器 stdout 的 `docker logs`，而是任务进度日志（便于在 UI 中直接查看）。

## 2. 新增日志字段

图片解析流程中，OCR 阶段与分块阶段新增了以下日志：

- `OCR boxes: N`
  - **含义**：OCR 返回的 box 数量。
  - **解释**：对表格图片来说，box 往往接近“单元格数”（行数×列数）。

- `OCR merged lines: M`
  - **含义**：将 OCR box 按 y 坐标聚合后的“行”数量。
  - **解释**：这是为避免表格按单元格分块而增加的聚合步骤。理想情况下，M 更接近表格的“行数”。

- `Split by <source>='<raw>' -> <normalized>`
  - **含义**：本次分块使用的子分隔符（children delimiter）来源与归一化结果。
  - **source** 可能为：
    - `children_delimiter`
    - `children_delimiters[0]`
  - **normalized** 可能为：
    - `\n(default)`：表示未显式配置且 OCR 文本含换行，于是默认按换行分割。
    - `\n`/`\r`/`\t` 等被归一化成真实字符。

- `Split result: K chunks, len(min/avg/max)=a/b/c`
  - **含义**：分块后的 chunk 数量，以及每块文本长度的最小/平均/最大值。
  - **用途**：快速判断是否出现异常碎片化（K 过大、min 过小），或是否分隔符配置不生效（K=1）。

## 3. 为什么表格图片会“分块爆炸”

如果 OCR 的文本拼接方式是“每个 box 一行”，且分隔符配置为 `\n`，那么分块会退化为“按 box 分块”。

为解决该问题，现已采用：

- **先按 y 坐标聚合 box 为行**
- **行内按 x 坐标排序后使用 `\t` 拼接**
- 最终用 `\n` 将行连接为 OCR 文本

这样分块粒度更接近“表格行”，而不是“表格单元格”。

## 4. 推荐配置

- **子分隔符（children delimiter）**
  - 推荐使用：`\n`
  - 注意：如果 UI 中出现 `\\n`（双反斜杠），后端也做了兼容，但建议尽量保持为 `\n` 以避免链路转义差异。

- **chunk token 数**
  - 建议根据业务调整（例如 256/512/768）。

## 5. 生效方式（Docker）

如果你通过 bind mount 覆盖了 `rag/app/picture.py`：

### 5.1 修改 docker-compose.yml（bind mount）

编辑 `docker/docker-compose.yml`，在对应服务的 `volumes:` 下增加本地文件到容器文件的挂载。

以 `ragflow-cpu` 为例（容器内代码路径以 `/ragflow` 为根）：

```yaml
services:
  ragflow-cpu:
    volumes:
      - ../rag/app/picture.py:/ragflow/rag/app/picture.py
      - ../rag/flow/splitter/splitter.py:/ragflow/rag/flow/splitter/splitter.py
```

如果你使用 `ragflow-gpu`（profile 为 `gpu`），同样在 `ragflow-gpu` 的 `volumes:` 下增加对应挂载：

```yaml
services:
  ragflow-gpu:
    volumes:
      - ../rag/app/picture.py:/ragflow/rag/app/picture.py
      - ../rag/flow/splitter/splitter.py:/ragflow/rag/flow/splitter/splitter.py
```

注意：上面的 `../` 是相对于 `docker/docker-compose.yml` 的路径（你的项目结构是 `docker/` 与 `rag/` 同级）。

### 5.2 重建服务进程以加载新逻辑

- 修改代码后需要重建服务进程以加载新逻辑：

```bash
docker compose -f docker/docker-compose.yml --profile cpu up -d --force-recreate ragflow-cpu
```

然后对目标文件重新解析，即可在任务详情看到新增日志。

### 5.3 验证容器确实加载了本地文件

你可以进入容器确认源码内容（以 `ragflow-cpu` 为例）：

```bash
docker exec -it docker-ragflow-cpu-1 python -c "import inspect; import rag.app.picture as p; print(inspect.getsource(p._ocr_boxes_to_lines)[:400])"
```

能打印出 `_ocr_boxes_to_lines` / 详细 `callback(...)` 日志相关代码片段，说明 bind mount 生效。
