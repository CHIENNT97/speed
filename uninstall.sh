#!/bin/sh
# ==============================================================================
# OpenWrt Speedtest Uninstaller
# ==============================================================================

echo "Đang gỡ cài đặt OpenWrt Speedtest..."

# Xóa thư mục web
rm -rf /www/speedtest

# Xóa symlinks nếu có
rm -f /www/cgi-bin/speedtest_*.cgi

# Khởi động lại uhttpd
/etc/init.d/uhttpd restart >/dev/null 2>&1 || true

echo "Đã gỡ cài đặt hoàn tất!"
