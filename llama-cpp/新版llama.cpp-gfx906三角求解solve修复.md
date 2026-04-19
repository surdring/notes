# gfx906（MI50）上运行 llama-server 报 `SOLVE_TRI failed / hipErrorInvalidDeviceFunction` 的定位与修复

本文记录一次在 **Ubuntu 24.04 + ROCm 7.0.2 + gfx906（MI50/同代 Vega20）** 上运行 `llama-server` 时，启动阶段 warmup 触发崩溃的完整定位与修复流程。

适用症状（关键日志特征）：

- 启动 `llama-server` 加载模型成功
- 在 `common_init_from_params: warming up the model with an empty run` 阶段崩溃
- 报错类似：

```text
rocBLAS error from hip error code: 'hipErrorInvalidDeviceFunction':98
.../ggml/src/ggml-cuda/ggml-cuda.cu:97: ROCm error
ggml_cuda_compute_forward: SOLVE_TRI failed
ROCm error: invalid device function
```

结论（最终根因）：

- 崩溃来自 `GGML_OP_SOLVE_TRI`（三角求解）
- 在 HIP/ROCm 下，当矩阵尺寸较大时，`ggml` 会走到 **hipBLAS/rocBLAS 的 `TRSM` batched** 路径（`hipblasStrsmBatched`）
- 在 gfx906 上该路径会触发 **`hipErrorInvalidDeviceFunction`**

最终修复：

- 在 `ggml/src/ggml-cuda/solve_tri.cu` 中 **禁用 hipBLAS/rocBLAS 的 TRSM 路径**
- 对小尺寸使用自定义 GPU kernel（保持原有 fast kernel 阈值）
- 对大尺寸直接 **回退到 CPU** 计算（避免 rocBLAS TRSM）

---

## 1. 复现命令（示例）

以 Qwen3.5 27B 为例（你的实际模型/参数可不同）：

```bash
env -u HSA_VISIBLE_DEVICES -u ROCR_VISIBLE_DEVICES -u CUDA_VISIBLE_DEVICES \
HIP_VISIBLE_DEVICES=1 \
./build-hip/bin/llama-server \
  --model /mnt/ssd/models/qwen3.5-27b-gguf/Qwen3.5-27B-Q4_K_M.gguf \
  --mmproj /mnt/ssd/models/qwen3.5-27b-gguf/mmproj-F16.gguf \
  --ctx-size 16384 \
  --n-gpu-layers -1 \
  --jinja \
  --flash-attn on \
  --host 0.0.0.0 \
  --port 8083
```

---

## 2. 初步误区：仅补齐 rocBLAS kernel 文件并不能解决

网上/社区常见建议是给 MI50(gfx906) 补齐 rocBLAS 的 Tensile kernel 文件（例如从 Arch Linux 的 `rocblas` 包拷贝 `*gfx906*` 到 `/opt/rocm/lib/rocblas/library/`）。

本次实践中：

- 即使从 `rocblas-7.2.0-1-x86_64.pkg.tar.zst` 里覆盖 `*gfx906*` 文件
- 崩溃仍然存在（`SOLVE_TRI failed` 不变）

原因是：**这次触发的调用链本质上来自 `SOLVE_TRI` 的实现选择（是否走 rocBLAS TRSM）**，而不是“缺少 Tensile 文件”这一单点问题。

（如果你的系统里原本完全没有 `gfx906` 的 TensileLibrary 文件，补齐可能是必要条件；但对本问题而言并非充分条件。）

---

## 3. 定位根因：`SOLVE_TRI` 的 cublas/hipblas 路径触发 rocBLAS TRSM

关键源码位置：

- `ggml/src/ggml-cuda/ggml-cuda.cu` 里对 `GGML_OP_SOLVE_TRI` 的分发
- `ggml/src/ggml-cuda/solve_tri.cu` 里 `ggml_cuda_op_solve_tri()` 的实现

其中 `solve_tri.cu` 存在两条路径：

- 小矩阵：走自定义 kernel（GPU）
- 大矩阵：走 `solve_tri_f32_cublas()`

`solve_tri_f32_cublas()` 内部会调用：

- `cublasStrsmBatched(...)`

在 HIP/ROCm 平台下，该调用会映射到 hipBLAS/rocBLAS 的 batched TRSM 实现，从而在 gfx906 上触发：

- `hipErrorInvalidDeviceFunction`

---

## 4. 正确修复：禁用 cublas/hipblas TRSM 路径（gfx906）

### 4.1 修改文件

编辑：

- `ggml/src/ggml-cuda/solve_tri.cu`

修复策略：

- 保持原先自定义 kernel 的 shared memory 约束（**gfx906 64KB**），因此阈值保持：
  - `MAX_N_FAST = 64`
  - `MAX_K_FAST = 32`
- 当 `n > 64` 或 `k > 32` 时：
  - **不再调用** `solve_tri_f32_cublas()`（即 hipBLAS/rocBLAS TRSM）
  - 改为：把 `A/B` 从 GPU 拷贝到 host，在 CPU 上做三角求解，再把结果拷回 GPU

实现要点：

- 顶部增加 `#include <vector>`
- 在 `ggml_cuda_op_solve_tri()` 中：
  - `if (n <= MAX_N_FAST && k <= MAX_K_FAST)`：仍走 `solve_tri_f32_cuda()`
  - `else`：CPU fallback

### 4.1.1 代码变更记录（关键片段）

本次修复实际改动集中在 `ggml/src/ggml-cuda/solve_tri.cu`，核心点是：

- **新增头文件**：引入 `std::vector` 以承载 CPU fallback 的临时缓冲
- **禁用 cublas/hipBLAS 路径**：大尺寸时不再调用 `solve_tri_f32_cublas()`（其内部会走 `hipblasStrsmBatched` → `rocBLAS TRSM`）
- **大尺寸回退 CPU**：将 `A/B` 从 device 拷到 host，在 CPU 上做三角求解，再拷回 device

关键改动示意（非完整文件，仅展示核心逻辑）：

```cpp
// ggml/src/ggml-cuda/solve_tri.cu

#include <vector>

// Limits for the custom kernel (shared memory constraint: 64KB on gfx906)
// MAX_N_FAST * MAX_N_FAST * sizeof(float) must fit in shared memory
#define MAX_N_FAST 64
#define MAX_K_FAST 32

void ggml_cuda_op_solve_tri(ggml_backend_cuda_context & ctx, ggml_tensor * dst) {
    const ggml_tensor * src0 = dst->src[0];
    const ggml_tensor * src1 = dst->src[1];

    const int64_t n    = src0->ne[0];
    const int64_t k    = src1->ne[0];
    const int64_t ne02 = src0->ne[2];
    const int64_t ne03 = src0->ne[3];

    // Always use custom kernel to avoid rocBLAS TRSM issues on gfx906
    // The cublas/rocBLAS path triggers "hipErrorInvalidDeviceFunction" on MI50
    // For sizes beyond MAX_N_FAST/MAX_K_FAST, we fall back to CPU execution
    if (n <= MAX_N_FAST && k <= MAX_K_FAST) {
        solve_tri_f32_cuda(...);
    } else {
        const int64_t total_batches = ne02 * ne03;
        const int64_t total_A  = n * n * total_batches;
        const int64_t total_BX = n * k * total_batches;

        std::vector<float> h_A(total_A);
        std::vector<float> h_B(total_BX);
        std::vector<float> h_X(total_BX);

        CUDA_CHECK(cudaMemcpyAsync(h_A.data(), src0->data, total_A  * sizeof(float), cudaMemcpyDeviceToHost, ctx.stream()));
        CUDA_CHECK(cudaMemcpyAsync(h_B.data(), src1->data, total_BX * sizeof(float), cudaMemcpyDeviceToHost, ctx.stream()));
        CUDA_CHECK(cudaStreamSynchronize(ctx.stream()));

        // CPU triangular solve
        for (...) {
            ...
        }

        CUDA_CHECK(cudaMemcpyAsync(dst->data, h_X.data(), total_BX * sizeof(float), cudaMemcpyHostToDevice, ctx.stream()));
    }
}
```

建议你在仓库根目录用下面命令查看完整 diff（包含所有细节与上下文）：

```bash
git diff -- ggml/src/ggml-cuda/solve_tri.cu
```

### 4.2 重新编译

在仓库根目录执行：

```bash
cmake --build build-hip --config Release -j$(nproc)
```

### 4.3 验证

重新运行第 1 节的 `llama-server` 启动命令。

预期结果：

- 不再出现 `SOLVE_TRI failed`
- 能顺利完成 warmup 并启动服务

---

## 5. 备注与取舍

- **性能影响**：
  - 若运行时频繁触发 `SOLVE_TRI` 且尺寸超出阈值，将走 CPU fallback，可能影响吞吐。
  - 本次目标优先是“能稳定跑通大模型”。

- **为什么不把 `MAX_N_FAST/MAX_K_FAST` 改大？**
  - 自定义 kernel 使用 shared memory 存 `sA[MAX_N_FAST * MAX_N_FAST]`
  - gfx906 shared memory 限制约 64KB
  - 把 `MAX_N_FAST` 提到 256 会导致编译期报错：local/shared memory 超限

- **为什么不继续折腾 rocBLAS kernel 文件？**
  - 本问题核心是“代码走到了 rocBLAS TRSM 路径”，而该路径在 gfx906 上不稳定。
  - 从根上绕开这条路径更可靠。

---

## 6. 相关文件清单

- 报错分发：`ggml/src/ggml-cuda/ggml-cuda.cu`
- 问题根因与修复点：`ggml/src/ggml-cuda/solve_tri.cu`

