#include <hip/hip_runtime.h>

#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <iostream>

#ifndef HIP_CHECK
#define HIP_CHECK(x)                                                                 \
  do {                                                                              \
    hipError_t err = (x);                                                           \
    if (err != hipSuccess) {                                                        \
      std::cerr << "HIP error: " << hipGetErrorString(err)                          \
                << " (" << static_cast<int>(err) << ") at " << __FILE__ << ":"   \
                << __LINE__ << std::endl;                                           \
      std::exit(1);                                                                 \
    }                                                                               \
  } while (0)
#endif

static __global__ void stress_fma(const float* __restrict__ in, float* __restrict__ out,
                                 std::uint64_t iters) {
  const std::uint32_t tid = blockIdx.x * blockDim.x + threadIdx.x;

  float x = in[tid];
  float y = x * 1.000001f + 0.000001f;
  float z = 0.0f;

  // 通过大量 FMA 指令制造持续的计算负载
  // 使用 volatile 防止编译器把循环优化掉
  for (std::uint64_t i = 0; i < iters; ++i) {
    z = fmaf(x, y, z);
    x = fmaf(z, 0.999999f, x);
    y = fmaf(x, 1.000001f, y);
  }

  out[tid] = x + y + z;
}

int main(int argc, char** argv) {
  // 默认运行 600 秒（10 分钟）
  int duration_sec = 600;
  if (argc >= 2) {
    duration_sec = std::max(1, std::atoi(argv[1]));
  }

  int device = 0;
  HIP_CHECK(hipSetDevice(device));

  hipDeviceProp_t prop{};
  HIP_CHECK(hipGetDeviceProperties(&prop, device));

  std::cout << "Using device " << device << ": " << prop.name << std::endl;
  std::cout << "Running stress for " << duration_sec << " seconds" << std::endl;

  // 规模：让 GPU 持续有足够线程占用
  constexpr int threads = 256;
  constexpr int blocks = 4096; // 4096*256 = 1,048,576 threads
  constexpr std::size_t n = static_cast<std::size_t>(threads) * static_cast<std::size_t>(blocks);

  float* d_in = nullptr;
  float* d_out = nullptr;

  HIP_CHECK(hipMalloc(&d_in, n * sizeof(float)));
  HIP_CHECK(hipMalloc(&d_out, n * sizeof(float)));
  HIP_CHECK(hipMemset(d_in, 0, n * sizeof(float)));
  HIP_CHECK(hipMemset(d_out, 0, n * sizeof(float)));

  hipStream_t stream{};
  HIP_CHECK(hipStreamCreate(&stream));

  // 迭代次数：越大单次 kernel 越久。
  // 这里选择一个中等值，并在 host 端循环发射 kernel，适配不同 GPU。
  std::uint64_t iters = 1ull << 20; // ~1M

  auto start = std::chrono::steady_clock::now();
  auto end_time = start + std::chrono::seconds(duration_sec);

  std::uint64_t launches = 0;
  while (std::chrono::steady_clock::now() < end_time) {
    hipLaunchKernelGGL(stress_fma, dim3(blocks), dim3(threads), 0, stream, d_in, d_out, iters);
    HIP_CHECK(hipGetLastError());

    // 每隔若干次同步一次，避免无限排队导致内存压力
    if ((++launches % 8) == 0) {
      HIP_CHECK(hipStreamSynchronize(stream));
    }
  }

  HIP_CHECK(hipStreamSynchronize(stream));

  // 读回少量数据校验（避免编译器/驱动把计算短路）
  float sample = 0.0f;
  HIP_CHECK(hipMemcpy(&sample, d_out, sizeof(float), hipMemcpyDeviceToHost));

  auto finish = std::chrono::steady_clock::now();
  std::chrono::duration<double> elapsed = finish - start;

  std::cout << "Done. launches=" << launches << " elapsed=" << elapsed.count() << "s"
            << " sample=" << sample << std::endl;

  HIP_CHECK(hipStreamDestroy(stream));
  HIP_CHECK(hipFree(d_in));
  HIP_CHECK(hipFree(d_out));

  return 0;
}
