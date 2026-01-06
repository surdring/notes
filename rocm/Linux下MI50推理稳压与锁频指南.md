# Linux 下 MI50 推理稳压与锁频指南（ROCm）

## 适用范围
- GPU：AMD Instinct MI50（常见为 `gfx906`）
- 场景：本地推理（例如 llama.cpp / ollama）
- 目标：在散热条件一般时，通过“限功耗 + 锁定 DPM 档位”降低温度尖峰与频率波动，提高稳定性

> 说明：MI50 在 Linux 下通常无法像 CPU 那样直接“调电压曲线”。所谓“稳压”在实践中主要是 **限制功耗上限** 与 **限制/锁定频率档位**，从而降低瞬态功耗与热冲击。

---

## 1. 先确认 MI50 对应的 DRM 设备节点
多卡机器里，`/sys/class/drm/card0` 不一定是 MI50（可能是 framebuffer 或其他显卡）。

### 1.1 列出所有 DRM 节点
```bash
ls -l /sys/class/drm/
```

### 1.2 通过 vendor 判断哪张是 AMD
AMD vendor 为 `0x1002`。

```bash
for d in /sys/class/drm/card*/device/vendor; do echo "$d: $(cat $d)"; done
```

如果输出中出现类似：
- `/sys/class/drm/card1/device/vendor: 0x1002`

则说明 MI50 对应 `card1`，后续所有 sysfs 路径都应替换为 `card1`。

---

## 2. 推理负载时先采集状态（用于选档）
建议在推理真正跑起来（GPU 有负载）时执行：

```bash
rocm-smi --showpower --showtemp --showclocks --showperflevel
```

关注这些指标：
- **Current Socket Graphics Package Power (W)**：当前功耗
- **Temperature (Sensor junction)**：热点温度（最关键）
- **sclk clock level / mclk clock level**：当前频率档位
- **Performance Level**：auto / manual

经验目标：
- `junction` 尽量稳定在 `<= 85°C`（更低更稳）

---

## 3. 限功耗（最有效、风险最低）
散热一般时，优先通过设置功耗上限让 GPU 不再频繁冲高功耗。

例如将功耗上限设为 180W：
```bash
sudo rocm-smi --setpoweroverdrive 180
```

如果仍偏热或仍有不稳定，可进一步降到 160W：
```bash
sudo rocm-smi --setpoweroverdrive 160
```

> 注意：功耗上限通常重启后会恢复默认。

---

## 4. 锁定 DPM 档位（降低频率抖动，减少温度尖峰）
### 4.1 查看可用 DPM 档位（以 MI50 的 `card1` 为例）
```bash
cat /sys/class/drm/card1/device/pp_dpm_sclk
cat /sys/class/drm/card1/device/pp_dpm_mclk
cat /sys/class/drm/card1/device/power_dpm_force_performance_level
```

示例输出（不同机器会略有差异）：
- `pp_dpm_sclk`：
  - `0: 925Mhz *`
  - ...
  - `7: 1606Mhz`
  - `8: 1725Mhz`
- `pp_dpm_mclk`：
  - `0: 350Mhz *`
  - `1: 800Mhz`
  - `2: 1000Mhz`
- `power_dpm_force_performance_level`：
  - `auto`

`*` 表示当前选中的档位。

### 4.2 推荐推理稳态配置（散热一般）
思路：
- 将 `Performance Level` 从 `auto` 设为 `manual`
- SCLK 从最高档（如 8=1725MHz）降到 **次高档**（如 7=1606MHz）
- MCLK 保持较高（如 2=1000MHz），若显存温度高再降到 800MHz

执行（需要 root）：
```bash
echo manual | sudo tee /sys/class/drm/card1/device/power_dpm_force_performance_level

echo 7 | sudo tee /sys/class/drm/card1/device/pp_dpm_sclk
echo 2 | sudo tee /sys/class/drm/card1/device/pp_dpm_mclk
```

更保守（更稳、温度更低）的 SCLK：
```bash
echo 6 | sudo tee /sys/class/drm/card1/device/pp_dpm_sclk
```

如果显存温度偏高或想进一步降热，可将 MCLK 降到 800MHz：
```bash
echo 1 | sudo tee /sys/class/drm/card1/device/pp_dpm_mclk
```

---

## 5. 验证是否生效
推理跑起来后执行：

```bash
rocm-smi --showpower --showtemp --showclocks --showperflevel
cat /sys/class/drm/card1/device/pp_dpm_sclk
cat /sys/class/drm/card1/device/pp_dpm_mclk
cat /sys/class/drm/card1/device/power_dpm_force_performance_level
```

你应能看到：
- `Performance Level` 不再是 `auto`（或至少频率更稳定）
- `sclk clock level` 不再频繁冲到最高档
- `junction` 更平稳

---

## 6. 常见问题
### 6.1 `rocm-smi --showsclk/--showmclk` 提示 Not supported
这通常表示 **OD（OverDrive）接口不支持**，但不代表没有 DPM。优先使用 sysfs：
- `pp_dpm_sclk`
- `pp_dpm_mclk`

### 6.2 `/sys/class/drm/card0/...` 找不到 pp_dpm_sclk
多半是找错了 `cardX`。请按“第 1 节”用 vendor 确认 AMD 对应的 card。

### 6.3 设置后重启失效
`rocm-smi` 和 sysfs 设置一般都不会永久保存。需要的话可以用 systemd 在开机时自动执行（建议将命令写成脚本并以 root 运行）。

---

## 7. 建议的稳态组合（散热一般的推理机器）
- 功耗上限：`180W`（不稳或偏热再降到 `160W`）
- 性能模式：`manual`
- SCLK：`level 7`（更稳用 `level 6`）
- MCLK：`level 2 (1000MHz)`（显存温度偏高可降到 `level 1 (800MHz)`）

以上组合通常可以显著降低温度尖峰与频率抖动，从而提升推理稳定性。

---

## 8. 使用 HIP 压力测试程序验证“持续 10 分钟稳定”

为了验证“锁频 + 限功耗”的配置是否真的稳定，可使用一个纯算力压力测试，让 GPU 持续运行 600 秒。

### 8.1 程序说明
- 程序（中文文件名）：`MI50-HIP压力测试-持续10分钟.cpp`
- 路径：`rocm/MI50-HIP压力测试-持续10分钟.cpp`
- 行为：在 GPU 上持续发射高强度 FMA 计算 kernel，默认运行 `600` 秒。

### 8.2 编译
在仓库目录执行（文件名有中文，建议用引号）：

```bash
hipcc -O3 -std=c++17 "rocm/MI50-HIP压力测试-持续10分钟.cpp" -o mi50_stress
```

### 8.3 运行 10 分钟

```bash
./mi50_stress 600
```

如果你希望“即使程序异常也强制 10 分钟后结束”，也可以用：

```bash
timeout 600s ./mi50_stress 600
```

### 8.4 监控是否真的持续满载且稳定
另开一个终端窗口：

```bash
watch -n 2 rocm-smi
```

你应该看到：
- `Perf`：`manual`
- `sclk`：基本稳定在你锁的档位（例如 `6/7`）
- 功耗：不超过你设置的 `PwrCap`（例如 `160W`）
- `junction`：温度不上冲、不持续爬升

如果 10 分钟中途掉卡/重置，马上抓日志：

```bash
dmesg -T | tail -n 200 | grep -Ei 'amdgpu|kfd|ring|reset|gpu fault|fatal|timeout'
```

### 8.5 注意
这个程序是纯算力压力，不是大模型推理（大模型还会叠加显存带宽/显存占用/IO 等因素），但它非常适合验证你当前的稳压/锁频/限功耗配置能否“持续 10 分钟不崩”。
