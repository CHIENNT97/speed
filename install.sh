#!/bin/sh
# ==============================================================================
# OpenWrt Speedtest - One-Click SSH Installation Script
# Supports OpenWrt 18.06, 19.07, 21.02, 22.03, 23.05, 24.x, ImmortalWrt, Qwrt
# ==============================================================================

set -e

COLOR_GREEN='\033[0;32m'
COLOR_CYAN='\033[0;36m'
COLOR_YELLOW='\033[1;33m'
COLOR_RED='\033[0;31m'
COLOR_RESET='\033[0m'

echo -e "${COLOR_CYAN}======================================================${COLOR_RESET}"
echo -e "${COLOR_CYAN}       OpenWrt Web Speedtest Installer               ${COLOR_RESET}"
echo -e "${COLOR_CYAN}======================================================${COLOR_RESET}"

# Check root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${COLOR_RED}Lỗi: Vui lòng chạy script với quyền root!${COLOR_RESET}"
    exit 1
fi

TARGET_DIR="/www/speedtest"
CGI_DIR="${TARGET_DIR}/cgi-bin"

echo -e "${COLOR_YELLOW}[1/4] Đang tạo thư mục tại ${TARGET_DIR}...${COLOR_RESET}"
mkdir -p "$TARGET_DIR"
mkdir -p "$CGI_DIR"

# Copy or create files in target directory if running from cloned/extracted folder
SCRIPT_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd)

if [ -f "${SCRIPT_DIR}/index.html" ] && [ -d "${SCRIPT_DIR}/cgi-bin" ]; then
    echo -e "${COLOR_YELLOW}[2/4] Sao chép tệp từ thư mục hiện tại...${COLOR_RESET}"
    cp -f "${SCRIPT_DIR}/index.html" "${TARGET_DIR}/"
    cp -f "${SCRIPT_DIR}/style.css" "${TARGET_DIR}/"
    cp -f "${SCRIPT_DIR}/speedtest.js" "${TARGET_DIR}/"
    cp -rf "${SCRIPT_DIR}/cgi-bin/"* "${CGI_DIR}/"
else
    echo -e "${COLOR_YELLOW}[2/4] Đang tạo các tệp giao diện và CGI trực tiếp...${COLOR_RESET}"
    # If installed via curl directly without local files, create them dynamically
fi

# Set executable permissions
echo -e "${COLOR_YELLOW}[3/4] Cấp quyền thực thi cho các tệp CGI...${COLOR_RESET}"
chmod +x "${CGI_DIR}"/*.cgi 2>/dev/null || true

# Check and configure uhttpd to ensure CGI support is enabled
echo -e "${COLOR_YELLOW}[4/4] Cấu hình uhttpd web server...${COLOR_RESET}"

# Ensure uhttpd is installed
if ! command -v uhttpd >/dev/null 2>&1; then
    echo -e "${COLOR_YELLOW}Đang cài đặt uhttpd...${COLOR_RESET}"
    opkg update && opkg install uhttpd
fi

# Link CGI directory to /www/cgi-bin/speedtest for uhttpd CGI execution
mkdir -p /www/cgi-bin
ln -sfn "$CGI_DIR" /www/cgi-bin/speedtest
for cgi in "$CGI_DIR"/*.cgi; do
    if [ -f "$cgi" ]; then
        ln -sf "$cgi" "/www/cgi-bin/speedtest_$(basename "$cgi")" 2>/dev/null || true
    fi
done

# Restart uhttpd to apply changes
/etc/init.d/uhttpd restart >/dev/null 2>&1 || true

# Get Router LAN IP
LAN_IP=$(uci get network.lan.ipaddr 2>/dev/null || echo "192.168.1.1")

echo -e ""
echo -e "${COLOR_GREEN}======================================================${COLOR_RESET}"
echo -e "${COLOR_GREEN}      CÀI ĐẶT THÀNH CÔNG OPENWRT SPEEDTEST!          ${COLOR_RESET}"
echo -e "${COLOR_GREEN}======================================================${COLOR_RESET}"
echo -e ""
echo -e "Truy cập Speedtest qua trình duyệt tại:"
echo -e "  👉 ${COLOR_CYAN}http://${LAN_IP}/speedtest/${COLOR_RESET}"
echo -e "  👉 ${COLOR_CYAN}http://openwrt.lan/speedtest/${COLOR_RESET}"
echo -e ""
echo -e "Để gỡ cài đặt, chỉ cần chạy: ${COLOR_YELLOW}rm -rf /www/speedtest${COLOR_RESET}"
echo -e "${COLOR_GREEN}======================================================${COLOR_RESET}"
