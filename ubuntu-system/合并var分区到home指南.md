# 合并 /var 分区到 / 根分区，释放空间给 /home

> 目标：将 /var (sdb5, 134G) 的数据合并到 / 根分区 (sdb3)，然后删除 sdb5，将空间合并给 /home (sdb4)
> 操作后 /home 从 140G 扩展到约 274G

## 当前分区布局

```
/dev/sdb1  4.7G   /boot
/dev/sdb2  1G     /boot/efi
/dev/sdb3  186G   /          (已用 46G，可用 128G)
/dev/sdb4  140G   /home      (已用 56G，可用 75G)
/dev/sdb5  134G   /var       (实际数据 14G，df 显示 58G)
```

---

## ⚠️ 风险警告

- **必须备份重要数据**，操作失误可能导致系统无法启动
- **不要跳过任何验证步骤**
- 建议准备一个 Ubuntu Live USB，万一系统起不来可以修复
- 整个过程约需 30-60 分钟

---

## 第零步：清理缓存与构建产物（强烈建议）

备份前先清理可自动重建的缓存和构建产物，可减少约 **20+ GB** 备份体积，大幅缩短 rsync 时间。

```bash
# 使用清理脚本（推荐）
bash ~/workspace/clean-cache.sh              # 安全模式：仅清理可自动重建项
# bash ~/workspace/clean-cache.sh --all      # 全量模式：额外清理 rustup/vscode扩展等

# 或手动清理核心项
rm -rf ~/.npm/_cacache ~/.cache/uv ~/.cache/yarn ~/.cache/google-chrome ~/.cache/microsoft-edge
rm -rf ~/.cache/go-build ~/.cache/electron ~/.cache/thumbnails ~/.cache/JetBrains
rm -rf ~/.bun/install ~/.cargo/registry ~/.codeium
find ~/workspace -type d \( -name "node_modules" -o -name "debug" -o -name "target" -o -name "__pycache__" \) \
    -not -path "*/.git/*" -exec rm -rf {} + 2>/dev/null
```

> 清理后 /home 从约 68G 降至约 47G，备份时间可缩短近一半。

---

## 第一步：备份数据（必须）

```bash
# 备份 fstab
sudo cp /etc/fstab /etc/fstab.bak

# 备份 /home 中重要数据到外部存储
# （清理后再备份，体积更小、速度更快）
rsync -av --progress /home/zhengxueen/ /mnt/sata/home-backup-$(date +%Y%m%d)/
```

---

## 第二步：复制 /var 数据到根分区

在**当前运行的系统**中执行：

```bash
# 1. 确认根分区可用空间（需要至少 20G）
df -h /

# 2. 创建临时挂载点，挂载根分区
sudo mkdir -p /tmp/rootpart
sudo mount /dev/sdb3 /tmp/rootpart

# 3. 确认根分区的 /var 目录存在
ls /tmp/rootpart/var/
# 应该看到 cache lib log snap 等目录

# 4. 复制 /var 数据（-a 保留权限、属主、时间戳）
sudo cp -a /var/* /tmp/rootpart/var/

# 5. 验证复制结果
echo "=== 源 /var ==="
du -sh /var/* | sort -rh | head -10
echo "=== 目标 /tmp/rootpart/var ==="
du -sh /tmp/rootpart/var/* | sort -rh | head -10

# 6. 对比文件数量
echo "源文件数: $(find /var -type f | wc -l)"
echo "目标文件数: $(find /tmp/rootpart/var -type f | wc -l)"

# 7. 确认无误后卸载
sudo umount /tmp/rootpart
sudo rmdir /tmp/rootpart
```

---

## 第三步：修改 fstab，禁用 /var 挂载

```bash
# 查看当前 fstab
cat /etc/fstab

# 找到挂载 /var 的那行，类似：
# /dev/sdb5  /var  ext4  defaults  0  2
# 或
# UUID=xxxx-xxxx  /var  ext4  defaults  0  2

# 注释掉该行（在行首加 #）
sudo nano /etc/fstab
# 改为：
# # /dev/sdb5  /var  ext4  defaults  0  2

# 保存退出
```

---

## 第四步：重启验证

```bash
sudo reboot
```

重启后检查：

```bash
# 确认 /var 不再是独立分区
df -h /var
# 应该显示 /dev/sdb3（根分区），而不是 /dev/sdb5

# 确认系统服务正常
systemctl status systemd-journald
systemctl status snapd
systemctl status docker

# 确认 /var 数据完整
ls /var/log/
ls /var/lib/snapd/
ls /var/cache/

# 确认根分区空间够用
df -h /
# 应该显示已用约 60G（原 46G + /var 的 14G），可用约 114G
```

**如果重启失败**（进不了系统）：
1. 用 Live USB 启动
2. 挂载根分区：`sudo mount /dev/sdb3 /mnt`
3. 恢复 fstab：`sudo cp /mnt/etc/fstab.bak /mnt/etc/fstab`
4. 重启，系统会恢复原样

---

## 第五步：用 GParted 删除 sdb5 并扩展 sdb4

**必须从 Live USB 启动**，不能在运行中的系统上操作 /home 分区。

### 5.1 制作 Live USB

```bash
# 下载 Ubuntu ISO（如果还没有）
# 用 dd 或 Startup Disk Creator 写入 U 盘
sudo dd if=ubuntu-24.04-desktop-amd64.iso of=/dev/sdX bs=4M status=progress && sync
# 注意：/dev/sdX 是你的 U 盘，不是硬盘！用 lsblk 确认
```

### 5.2 从 Live USB 启动，打开 GParted

1. 选择 U 盘启动
2. 打开 GParted：`sudo gparted`
3. 在右上角选择硬盘 **/dev/sdb**

### 5.3 操作步骤

当前布局：
```
sdb1 [boot  4.7G]
sdb2 [efi   1G  ]
sdb3 [/    186G ]
sdb4 [/home 140G]
sdb5 [/var  134G]  ← 要删除
```

操作：

1. **右键 sdb5 → Delete**（删除 /var 分区）
2. **右键 sdb4 → Resize/Move**
   - 拖动右边缘到磁盘末尾（把 sdb5 释放的空间全部纳入）
   - 新大小应约为 274G
   - 点击 Resize
3. **点击绿色 ✓ Apply** 执行操作
4. 等待完成（可能需要几分钟到十几分钟）

### 5.4 用命令行替代（如果 GParted 不可用）

```bash
# 确认分区顺序
sudo fdisk -l /dev/sdb

# 删除 sdb5
sudo fdisk /dev/sdb
# 输入 d → 5（删除分区 5）
# 输入 w（写入）

# 扩展 sdb4（需要 growpart 工具）
sudo apt install cloud-guest-utils -y
sudo growpart /dev/sdb 4

# 扩展文件系统
sudo resize2fs /dev/sdb4

# 验证
df -h /home
# 应显示约 274G
```

---

## 第六步：重启验证最终结果

```bash
sudo reboot

# 重启后检查
df -h / /home /var
# /     → /dev/sdb3  约 186G（已用 ~60G）
# /home → /dev/sdb4  约 274G（已用 ~56G）
# /var  → 应显示和 / 相同的 /dev/sdb3

# 确认所有服务正常
systemctl list-units --state=failed
# 应该没有 failed 的服务

# 确认 snap 应用正常
snap list

# 确认日志正常
journalctl --since today | tail -5
```

---

## 最终分区布局

```
/dev/sdb1  4.7G   /boot
/dev/sdb2  1G     /boot/efi
/dev/sdb3  186G   /          (含 /var)
/dev/sdb4  274G   /home
```

---

## 故障恢复

| 问题 | 解决方案 |
|------|---------|
| 重启后进不了系统 | Live USB 启动 → 恢复 fstab.bak → 重启 |
| /var 数据丢失 | Live USB 启动 → 重新挂载 sdb5 到 /var → 恢复 fstab |
| /home 扩展失败 | sdb5 未删除的话，数据还在，重新挂载即可 |
| GParted 操作中断 | 重新打开 GParted，它会提示恢复操作 |

---

## 操作清单（Checklist）

- [ ] 清理缓存与构建产物（bash ~/workspace/clean-cache.sh）
- [ ] 备份重要数据到外部存储
- [ ] 备份 fstab
- [ ] 挂载根分区，复制 /var 数据
- [ ] 验证复制完整性
- [ ] 注释 fstab 中 /var 挂载行
- [ ] 重启验证系统正常
- [ ] 制作 Live USB
- [ ] Live USB 启动，GParted 删除 sdb5
- [ ] GParted 扩展 sdb4
- [ ] 重启验证最终结果
