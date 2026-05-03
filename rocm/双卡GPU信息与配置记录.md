# 双卡 AMD GPU 信息与配置记录

## 1. 硬件概况

本机安装了两张 AMD Vega 20 架构 GPU，均为 `gfx906`，但型号与显存不同。

| 属性 | GPU[0] | GPU[1] |
|---|---|---|
| **Card Series** | AMD Radeon Graphics | AMD Radeon (TM) Pro VII |
| **SKU** | D1631711 | D1640600 |
| **Subsystem ID** | `0x0834` | `0x081E` |
| **Device Rev** | `0x01` | `0x06` |
| **GFX Version** | `gfx906` | `gfx906` |
| **VRAM** | 16 GB (~16GiB) | 32 GB (~32GiB) |
| **PCI 地址** | `0000:08:00.0` | `0000:05:00.0` |
| **sysfs 节点** | `/sys/class/drm/card0` | `/sys/class/drm/card1` |
| **lspci 描述** | Display controller: Vega 20 | VGA compatible controller: Vega 20 |

> **注意**：GPU[0] 是 MI50 16GB（Display controller，无显示输出），GPU[1] 是 Radeon Pro VII 32GB（VGA controller，有 DP 输出）。两者架构相同但 SKU/显存/频率档位不同。

---

## 2. 编号映射关系

| 编号体系 | GPU[0] (16GB) | GPU[1] (32GB) |
|---|---|---|
| `rocm-smi` 索引 | `GPU[0]` | `GPU[1]` |
| sysfs DRM 节点 | `card0` | `card1` |
| PCI Bus | `0000:08:00.0` | `0000:05:00.0` |
| `HIP_VISIBLE_DEVICES` | `0` | `1` |
| Node ID | 1 | 2 |

> 本机 `rocm-smi` 索引与 `cardX` 编号恰好一致（GPU[0]=card0, GPU[1]=card1），但 PCI 地址顺序相反（card0 在 08:00.0，card1 在 05:00.0）。换卡/换槽位后映射可能变化，务必用 PCI 地址确认。

验证映射命令：
```bash
readlink -f /sys/class/drm/card0/device   # 应输出 .../0000:08:00.0
readlink -f /sys/class/drm/card1/device   # 应输出 .../0000:05:00.0
rocm-smi -i                                # 对比 PCI Bus
```

---

## 3. DPM 档位表

两张卡的 sclk 档位频率不同，必须分别记录。

### 3.1 GPU[0] (card0, MI50 16GB, PCI 08:00.0)

**sclk 档位：**
| Level | 频率 |
|---|---|
| 0 | 925 MHz |
| 1 | 930 MHz |
| 2 | 1032 MHz |
| 3 | 1143 MHz |
| 4 | 1282 MHz |
| 5 | 1386 MHz |
| 6 | 1485 MHz |
| 7 | 1606 MHz |
| 8 | 1725 MHz（最高档） |

**mclk 档位：**
| Level | 频率 |
|---|---|
| 0 | 350 MHz |
| 1 | 800 MHz |
| 2 | 1000 MHz（最高档） |

### 3.2 GPU[1] (card1, Radeon Pro VII 32GB, PCI 05:00.0)

**sclk 档位：**
| Level | 频率 |
|---|---|
| 0 | 859 MHz |
| 1 | 860 MHz |
| 2 | 1153 MHz |
| 3 | 1316 MHz |
| 4 | 1425 MHz |
| 5 | 1514 MHz |
| 6 | 1583 MHz |
| 7 | 1654 MHz |
| 8 | 1700 MHz（最高档） |

**mclk 档位：**
| Level | 频率 |
|---|---|
| 0 | 350 MHz |
| 1 | 800 MHz |
| 2 | 1000 MHz（最高档） |

> **关键差异**：GPU[0] 最高 sclk 为 1725MHz，GPU[1] 最高 sclk 为 1700MHz。相同 level 编号对应的频率不同，锁频时不能混用。

---

## 4. 当前运行状态（采集时间：2026-05-02）

### 4.1 性能模式
两张卡当前均为 `manual` 模式。

### 4.2 当前频率
| | GPU[0] (16GB) | GPU[1] (32GB) |
|---|---|---|
| sclk | 930 MHz (level 1) | 1583 MHz (level 6) |
| mclk | 350 MHz (level 0) | 800 MHz (level 1) |
| fclk | 1180 MHz (level 7) | 550 MHz (level 0) |
| socclk | 971 MHz (level 7) | 309 MHz (level 0) |

> GPU[0] 当前处于低频空闲状态，GPU[1] 已锁频到推理工作点。

### 4.3 温度
| 传感器 | GPU[0] (16GB) | GPU[1] (32GB) |
|---|---|---|
| Edge | 43°C | 31°C |
| **Junction** | **45°C** | **32°C** |
| Memory | 43°C | 34°C |

### 4.4 功耗
| | GPU[0] (16GB) | GPU[1] (32GB) |
|---|---|---|
| 当前功耗 | 17W | 22W |
| GPU 使用率 | 0% | 0% |

### 4.5 显存使用
| | GPU[0] (16GB) | GPU[1] (32GB) |
|---|---|---|
| VRAM 总量 | ~16 GiB | ~32 GiB |
| VRAM 已用 | ~841 MiB | ~20 MiB |

---

## 5. 推理稳态配置建议

由于两张卡型号不同，建议分别配置。

### 5.1 GPU[0] (MI50 16GB) 推荐配置

```bash
# manual 模式
echo manual | sudo tee /sys/class/drm/card0/device/power_dpm_force_performance_level

# sclk 锁定 level 6 (1485MHz) — 次高档为 level 7 (1606MHz)
echo 6 | sudo tee /sys/class/drm/card0/device/pp_dpm_sclk

# mclk 锁定 level 1 (800MHz) — 显存温度高可用 level 1，否则 level 2 (1000MHz)
echo 1 | sudo tee /sys/class/drm/card0/device/pp_dpm_mclk

# 功耗上限 180W
sudo rocm-smi --setpoweroverdrive 180 -d 0
```

### 5.2 GPU[1] (Radeon Pro VII 32GB) 推荐配置

```bash
# manual 模式
echo manual | sudo tee /sys/class/drm/card1/device/power_dpm_force_performance_level

# sclk 锁定 level 6 (1583MHz) — 次高档为 level 7 (1654MHz)
echo 6 | sudo tee /sys/class/drm/card1/device/pp_dpm_sclk

# mclk 锁定 level 1 (800MHz) — 显存温度高可用 level 1，否则 level 2 (1000MHz)
echo 1 | sudo tee /sys/class/drm/card1/device/pp_dpm_mclk

# 功耗上限 180W
sudo rocm-smi --setpoweroverdrive 180 -d 1
```

### 5.3 配置对照表

| 参数 | GPU[0] (16GB) | GPU[1] (32GB) |
|---|---|---|
| Performance Level | manual | manual |
| sclk level | 6 (1485 MHz) | 6 (1583 MHz) |
| mclk level | 1 (800 MHz) | 1 (800 MHz) |
| 功耗上限 | 180W | 180W |

> 若散热条件更差，可进一步：sclk 降到 level 5，功耗降到 160W。

---

## 6. Systemd 服务（双卡版）

```ini
[Unit]
Description=AMD GPU Power Limit and DPM Lock (Dual GPU)
After=systemd-modules-load.service
Wants=systemd-modules-load.service

[Service]
Type=oneshot
RemainAfterExit=yes

# === GPU[0] (card0, MI50 16GB, PCI 08:00.0) ===

# manual 模式
ExecStart=/bin/sh -c 'echo manual > /sys/class/drm/card0/device/power_dpm_force_performance_level'

# sclk level 6 (1485MHz)
ExecStart=/bin/sh -c 'echo 6 > /sys/class/drm/card0/device/pp_dpm_sclk'

# mclk level 1 (800MHz)
ExecStart=/bin/sh -c 'echo 1 > /sys/class/drm/card0/device/pp_dpm_mclk'

# 功耗上限 180W
ExecStart=/usr/bin/rocm-smi --setpoweroverdrive 180 -d 0

# === GPU[1] (card1, Radeon Pro VII 32GB, PCI 05:00.0) ===

# manual 模式
ExecStart=/bin/sh -c 'echo manual > /sys/class/drm/card1/device/power_dpm_force_performance_level'

# sclk level 6 (1583MHz)
ExecStart=/bin/sh -c 'echo 6 > /sys/class/drm/card1/device/pp_dpm_sclk'

# mclk level 1 (800MHz)
ExecStart=/bin/sh -c 'echo 1 > /sys/class/drm/card1/device/pp_dpm_mclk'

# 功耗上限 180W
ExecStart=/usr/bin/rocm-smi --setpoweroverdrive 180 -d 1

# === 恢复命令 ===
ExecStop=/bin/sh -c 'echo auto > /sys/class/drm/card0/device/power_dpm_force_performance_level'
ExecStop=/bin/sh -c 'echo auto > /sys/class/drm/card1/device/power_dpm_force_performance_level'
ExecStop=/usr/bin/rocm-smi --resetpoweroverdrive

[Install]
WantedBy=multi-user.target
```

部署方式：
```bash
sudo cp amd-gpu-power-limit.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now amd-gpu-power-limit.service
sudo systemctl status amd-gpu-power-limit.service
```

---

## 7. 固件版本（参考）

两张卡固件版本相同：

| 固件 | 版本 |
|---|---|
| SMC | 00.40.60.00 |
| SDMA / SDMA2 | 145 |
| CE | 80 |
| ME | 167 |
| MEC / MEC2 | 478 |
| PFP | 196 |
| RLC | 50 |

---

## 8. 快速验证命令

```bash
# 一行查看两张卡的核心状态
rocm-smi --showpower --showtemp --showclocks --showperflevel

# 查看 DPM 档位与当前选中
cat /sys/class/drm/card0/device/pp_dpm_sclk
cat /sys/class/drm/card0/device/pp_dpm_mclk
cat /sys/class/drm/card1/device/pp_dpm_sclk
cat /sys/class/drm/card1/device/pp_dpm_mclk

# 查看性能模式
cat /sys/class/drm/card0/device/power_dpm_force_performance_level
cat /sys/class/drm/card1/device/power_dpm_force_performance_level

# 实时监控
watch -n 2 rocm-smi
```
