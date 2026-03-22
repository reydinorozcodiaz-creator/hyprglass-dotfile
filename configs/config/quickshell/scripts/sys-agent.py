#!/usr/bin/env python3
import time
import json
import os
import subprocess
import glob

def get_cpu_temp():
    temp_files = glob.glob("/sys/class/thermal/thermal_zone*/temp")
    max_temp = 0
    for file in temp_files:
        type_file = file.replace("temp", "type")
        if os.path.exists(type_file):
            try:
                with open(type_file, "r") as f:
                    tz_type = f.read().strip()
                if tz_type == "x86_pkg_temp" or "k10temp" in tz_type:
                    with open(file, "r") as f:
                        t = int(f.read().strip())
                        if t > max_temp:
                            max_temp = t
            except:
                pass
    return int(max_temp / 1000) if max_temp > 0 else 0

def get_gpu_info():
    usage, temp = 0, 0
    try:
        # Check NVIDIA
        if os.system("command -v nvidia-smi > /dev/null 2>&1") == 0:
            out = subprocess.check_output(["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu", "--format=csv,noheader,nounits"], universal_newlines=True)
            parts = [p.strip() for p in out.split(",")]
            if len(parts) >= 2:
                usage = int(parts[0])
                temp = int(parts[1])
            return "nvidia", usage, temp
            
        # Check AMD
        gpu_stat_dir = glob.glob("/sys/class/drm/card*/device/gpu_busy_percent")
        if gpu_stat_dir:
            for path in gpu_stat_dir:
                try:
                    with open(path, "r") as f:
                        usage = int(f.read().strip())
                    hwmon_dir = os.path.dirname(os.path.dirname(path)) + "/hwmon/hwmon*"
                    temp_paths = glob.glob(hwmon_dir + "/temp1_input")
                    if temp_paths:
                        with open(temp_paths[0], "r") as f:
                            temp = int(int(f.read().strip()) / 1000)
                    return "amd", usage, temp
                except:
                    pass
    except:
        pass
    return "unknown", 0, 0

def read_cpu_stat():
    try:
        with open("/proc/stat", "r") as f:
            lines = f.readlines()
            for line in lines:
                if line.startswith("cpu "):
                    parts = line.split()
                    user, nice, system, idle, iowait, irq, softirq, steal = map(int, parts[1:9])
                    total = user + nice + system + idle + iowait + irq + softirq + steal
                    idle_total = idle + iowait
                    return total, idle_total
    except:
        pass
    return 0, 0

def get_ram_info():
    try:
        with open("/proc/meminfo", "r") as f:
            lines = f.readlines()
            mem_total = 0
            mem_avail = 0
            for line in lines:
                parts = line.split()
                if line.startswith("MemTotal:"):
                    mem_total = int(parts[1]) * 1024
                elif line.startswith("MemAvailable:"):
                    mem_avail = int(parts[1]) * 1024
            if mem_total > 0:
                used = mem_total - mem_avail
                percent = int((used / mem_total) * 100)
                return percent, used, mem_total
    except:
        pass
    return 0, 0, 0

def get_disk_info():
    try:
        st = os.statvfs("/")
        total = st.f_blocks * st.f_frsize
        free = st.f_bavail * st.f_frsize
        used = total - free
        percent = int((used / total) * 100) if total > 0 else 0
        return percent, used, total
    except:
        pass
    return 0, 0, 0

def get_net_bytes():
    rx = 0
    tx = 0
    try:
        for iface in glob.glob("/sys/class/net/*/statistics/rx_bytes"):
            if "lo/statistics" in iface:
                continue
            with open(iface, "r") as f:
                rx += int(f.read().strip())
        for iface in glob.glob("/sys/class/net/*/statistics/tx_bytes"):
            if "lo/statistics" in iface:
                continue
            with open(iface, "r") as f:
                tx += int(f.read().strip())
    except:
        pass
    return rx, tx

def get_uptime():
    try:
        with open("/proc/uptime", "r") as f:
            uptime = float(f.read().split()[0])
            hours = int(uptime // 3600)
            minutes = int((uptime % 3600) // 60)
            if hours > 0:
                return f"{hours}h {minutes}m"
            else:
                return f"{minutes}m"
    except:
        pass
    return "0m"

prev_total_cpu, prev_idle_cpu = read_cpu_stat()
prev_rx, prev_tx = get_net_bytes()
last_time = time.time()

# Initial static values
gpu_type, gpu_usage, gpu_temp = get_gpu_info()

while True:
    time.sleep(2)
    current_time = time.time()
    elapsed = current_time - last_time
    
    # CPU
    total_cpu, idle_cpu = read_cpu_stat()
    diff_total = total_cpu - prev_total_cpu
    diff_idle = idle_cpu - prev_idle_cpu
    cpu_usage = 0
    if diff_total > 0:
        cpu_usage = int(100 * (diff_total - diff_idle) / diff_total)
    prev_total_cpu = total_cpu
    prev_idle_cpu = idle_cpu
    
    cpu_temp = get_cpu_temp()
    
    # RAM
    ram_percent, ram_used, ram_total = get_ram_info()
    
    # Disk
    disk_percent, disk_used, disk_total = get_disk_info()
    
    # Network
    rx, tx = get_net_bytes()
    rx_rate = int((rx - prev_rx) / elapsed) if elapsed > 0 else 0
    tx_rate = int((tx - prev_tx) / elapsed) if elapsed > 0 else 0
    prev_rx = rx
    prev_tx = tx
    
    # Simple static GPU polling (gpu temp/usage might need more time depending on driver, polling less frequently might be better but 2s is ok for now)
    _, gpu_usage, gpu_temp = get_gpu_info()
    
    # Uptime
    uptime_str = get_uptime()
    
    data = {
        "cpu": {"usage": cpu_usage, "temp": cpu_temp},
        "gpu": {"type": gpu_type, "usage": gpu_usage, "temp": gpu_temp},
        "ram": {"usage": ram_percent, "used": ram_used, "total": ram_total},
        "disk": {"usage": disk_percent, "used": disk_used, "total": disk_total},
        "network": {"rx": rx_rate, "tx": tx_rate},
        "uptime": uptime_str
    }
    
    print(json.dumps(data), flush=True)
    last_time = current_time
