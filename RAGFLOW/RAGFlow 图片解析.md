# RAGFlow 图片解析（PNG）



## 解析链路确认（代码对照结论）

该日志内容与 `rag/app/picture.py::chunk(...)` 的处理流程一致：

- 先使用 `deepdoc.vision.OCR` 进行 OCR（本地 ONNX OCR）
- 将 OCR box 合并为文本行（`OCR merged lines`）
- 当 OCR 结果文本过长时触发保护逻辑：`OCR results is too long to use CV LLM.`
  - 该分支会跳过 `LLMType.IMAGE2TEXT`（VLM/多模态）调用
  - 改为只基于 OCR 文本分块入库（`Generate 37 chunks`）

涉及代码位置：

- OCR 实现：`deepdoc/vision/ocr.py`（onnxruntime，本地模型目录优先为 `rag/res/deepdoc`）
- 图片入库解析入口：`rag/app/picture.py`（OCR 优先，OCR 结果过长时跳过 VLM）

## 备注

- 本次图片解析未调用 VLM（`LLMType.IMAGE2TEXT`）的原因是 OCR 文本长度超出阈值，触发了“跳过 CV LLM”的分支逻辑。
