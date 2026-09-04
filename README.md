# OpenWrt Web Speedtest

A lightweight, high-performance HTML5 Speedtest designed specifically for OpenWrt modems and routers.

## 🚀 One-Line Interactive Menu (SSH)

Run this single command on your OpenWrt terminal via SSH to display the interactive **Install / Uninstall** menu:

```bash
sh -c "$(curl -kfsSL https://raw.githubusercontent.com/CHIENNT97/speed/main/setup.sh)"
```

Or using `wget`:
```bash
wget --no-check-certificate -qO- https://raw.githubusercontent.com/CHIENNT97/speed/main/setup.sh | sh
```

### Interactive Menu
```text
======================================================
       🚀 OPENWRT SPEEDTEST MANAGER - QUẢN LÝ        
======================================================
 Trạng thái hiện tại: ● ĐÃ CÀI ĐẶT
------------------------------------------------------
  [1] Cài đặt / Cập nhật Speedtest (Install)
  [2] Gỡ cài đặt Speedtest (Uninstall)
  [3] Kiểm tra trạng thái (Status)
  [4] Khởi động lại dịch vụ web (Restart uhttpd)
  [0] Thoát (Exit)
======================================================
 Nhập lựa chọn của bạn [0-4]: 
```

## Features
- **Interactive SSH Menu**: Easy 1-click Install, Update, Uninstall, and Status check.
- **Ultra-lightweight** (<50KB total footprint), runs natively on OpenWrt's `uhttpd` without PHP or Python.
- **Zero Flash I/O strain**: Download stream generated from RAM `/dev/zero`, upload piped to `/dev/null`.
- **Multi-threaded testing**: Fully tests Gigabit Ethernet and high-throughput WiFi 5/6/7 connections.
- **Hardware telemetry**: Live display of OpenWrt router model, CPU load, RAM usage, temperature, client IP.
- **Modern Neon Glassmorphism UI**: Beautiful gauge, real-time live canvas graph, ping, jitter, test history.
