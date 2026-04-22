#!/usr/bin/env python3
"""SMB 共享访问记录分析工具"""

import os
import re
from datetime import datetime
from pathlib import Path

SMB_LOG_DIR = "/var/log/samba"

def parse_log_file(filepath):
    """解析单个 Samba 日志文件，提取连接记录"""
    records = []
    current_ip = None
    current_user = None
    current_machine = None

    try:
        with open(filepath, "r", errors="replace") as f:
            lines = f.readlines()
    except PermissionError:
        print(f"  ⚠️ 无权限读取: {filepath}")
        return records
    except FileNotFoundError:
        return records

    for line in lines:
        line = line.strip()

        # 匹配连接信息: "connect to service share"
        m = re.search(r'connect to service (\w+) .*user \[(\w+)\]', line)
        if m:
            records.append({
                "type": "连接共享",
                "share": m.group(1),
                "user": m.group(2),
            })

        # 匹配 IP 地址连接
        m = re.search(r'Connection from (\d+\.\d+\.\d+\.\d+)', line)
        if m:
            current_ip = m.group(1)
            records.append({
                "type": "IP连接",
                "ip": current_ip,
            })

        # 匹配主机名
        m = re.search(r'Allowed connection from (.+)', line)
        if m:
            current_machine = m.group(1).strip()
            records.append({
                "type": "主机连接",
                "machine": current_machine,
            })

        # 匹配认证成功
        m = re.search(r'authenticated user \[(\w+)\]', line)
        if m:
            records.append({
                "type": "认证成功",
                "user": m.group(1),
            })

        # 匹配登录
        m = re.search(r'User \[(\w+)\] logged in', line)
        if m:
            records.append({
                "type": "用户登录",
                "user": m.group(1),
            })

        # 匹配时间戳行
        m = re.match(r'\[(\d{4}/\d{2}/\d{2}.*?\d{2}:\d{2}:\d{2})\]', line)
        if m and records:
            records[-1]["time"] = m.group(1)

        # 匹配断开连接
        m = re.search(r'disconnected', line, re.IGNORECASE)
        if m:
            records.append({
                "type": "断开连接",
            })

    return records


def get_log_files():
    """获取所有 Samba 日志文件"""
    log_dir = Path(SMB_LOG_DIR)
    if not log_dir.exists():
        print(f"日志目录不存在: {SMB_LOG_DIR}")
        return []

    log_files = []
    for f in sorted(log_dir.iterdir()):
        if f.is_file() and f.name.startswith("log."):
            # 跳过系统服务日志
            if f.name in ("log.smbd", "log.nmbd", "log.samba-bgqd",
                          "log.samba-dcerpcd", "log.rpcd_lsad",
                          "log.rpcd_spoolss", "log.rpcd_epmapper",
                          "log.rpcd_classic", "log.rpcd_winreg",
                          "log.rpcd_fsrvp", "log.rpcd_mdssvc", "log."):
                continue
            log_files.append(f)

    return log_files


def main():
    log_files = get_log_files()
    if not log_files:
        print("未找到设备日志文件")
        return

    print("=" * 70)
    print("SMB 共享访问记录汇总")
    print("=" * 70)

    for log_file in log_files:
        # 从文件名提取设备标识
        device_id = log_file.name.replace("log.", "")
        records = parse_log_file(log_file)

        if not records:
            print(f"\n📡 {device_id}")
            print(f"   无访问记录（日志为空）")
            continue

        print(f"\n📡 {device_id}")
        print("-" * 50)

        # 去重并整理
        seen = set()
        for r in records:
            key = str(r)
            if key in seen:
                continue
            seen.add(key)

            rtype = r.get("type", "")
            time_str = r.get("time", "未知时间")

            if rtype == "IP连接":
                print(f"   [{time_str}] 连接来自 IP: {r['ip']}")
            elif rtype == "主机连接":
                print(f"   [{time_str}] 主机: {r['machine']}")
            elif rtype == "连接共享":
                print(f"   [{time_str}] 访问共享: {r['share']} (用户: {r['user']})")
            elif rtype == "认证成功":
                print(f"   [{time_str}] 认证成功: {r['user']}")
            elif rtype == "用户登录":
                print(f"   [{time_str}] 用户登录: {r['user']}")
            elif rtype == "断开连接":
                print(f"   [{time_str}] 断开连接")

    print("\n" + "=" * 70)
    print(f"共扫描 {len(log_files)} 个设备日志")
    print("=" * 70)


if __name__ == "__main__":
    main()
