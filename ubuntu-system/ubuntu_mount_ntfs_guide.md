# Ubuntu 下挂载 NTFS 分区指南

## 1. 安装必要工具

首先确保已安装 `ntfs-3g` 工具：

```bash
sudo apt update
sudo apt install ntfs-3g
```

## 2. 查看可用磁盘和分区

使用以下命令查看所有磁盘和分区：

```bash
sudo fdisk -l
```

或者使用更易读的方式：

```bash
lsblk -f
```

## 3. 创建挂载点

创建一个目录作为挂载点：

```bash
sudo mkdir -p /mnt/ntfs_drive
```

## 4. 临时挂载 NTFS 分区

```bash
sudo mount -t ntfs-3g /dev/sdXn /mnt/ntfs_drive
```

将 `/dev/sdXn` 替换为实际的 NTFS 分区设备名（例如：`/dev/sda1`）。

## 5. 设置开机自动挂载

编辑 `/etc/fstab` 文件：

```bash
sudo nano /etc/fstab
```

添加以下行（替换 `/dev/sdXn` 为您的 NTFS 分区）：

```
# NTFS 分区挂载
UUID=你的分区UUID  /mnt/ntfs_drive  ntfs-3g  defaults,windows_names,locale=zh_CN.UTF-8  0  0

# 宿舍电脑
UUID=5016E6F216E6D7CC  /mnt/easystore  ntfs-3g  rw,remove_hiberfile,windows_names,locale=zh_CN.UTF-8,uid=1000,gid=1000,umask=0022  0  0
```

> 注意：要获取分区的 UUID，可以使用 `sudo blkid` 命令。

## 6. 设置读写权限（可选）

如果需要让普通用户有读写权限，可以在挂载选项中添加 `uid=1000,gid=1000`（假设用户ID和组ID都是1000，可以使用 `id -u` 和 `id -g` 命令查看）。

## 7. 测试挂载

```bash
sudo mount -a
```

如果没有报错，说明配置正确。

## 8. 卸载分区（如需要）

```bash
sudo umount /mnt/ntfs_drive
```

## 常见问题

### 1. 只读挂载问题
如果分区被挂载为只读，可以尝试：
```bash
sudo ntfsfix /dev/sdXn
```
然后重新挂载。

### 2. 中文文件名乱码
确保在挂载时添加了 `locale=zh_CN.UTF-8` 选项。

### 3. 休眠后无法挂载
如果Windows启用了快速启动，可能会导致NTFS分区无法挂载为可写。可以在Windows中禁用快速启动，或者在Ubuntu中以只读方式挂载。

## 注意事项

1. 操作磁盘分区有风险，请确保已备份重要数据
2. 如果同时使用Windows和Ubuntu双系统，建议在Windows中完全关机（禁用快速启动）
3. 对于重要的NTFS分区，建议在挂载前先检查文件系统：
   ```bash
   sudo ntfsfix -d /dev/sdXn
   ```
