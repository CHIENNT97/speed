#!/bin/sh
# ==============================================================================
# OpenWrt Speedtest Manager (Online GitHub Installer / Uninstaller)
# Tự động tải từ GitHub và quản lý Cài đặt / Gỡ cài đặt qua SSH
# ==============================================================================

# Thiết lập URL Repository GitHub
GITHUB_USER="${GITHUB_USER:-CHIENNT97}"
GITHUB_REPO="${GITHUB_REPO:-openwrt_speed}"
BRANCH="${BRANCH:-main}"

# URL cơ sở tải raw tệp từ GitHub
RAW_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${BRANCH}"

COLOR_CYAN='\033[0;36m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_RED='\033[0;31m'
COLOR_RESET='\033[0m'

TARGET_DIR="/www/speedtest"
CGI_DIR="${TARGET_DIR}/cgi-bin"

# Hàm tải tệp an toàn (hỗ trợ cả curl, wget và uclient-fetch trên OpenWrt)
download_file() {
    URL="$1"
    OUTPUT="$2"
    
    if command -v curl >/dev/null 2>&1; then
        curl -k -sSL "$URL" -o "$OUTPUT"
    elif command -v wget >/dev/null 2>&1; then
        wget --no-check-certificate -qO "$OUTPUT" "$URL"
    elif command -v uclient-fetch >/dev/null 2>&1; then
        uclient-fetch --no-check-certificate -qO "$OUTPUT" "$URL"
    fi
}

# Hàm Cài đặt
do_install() {
    echo ""
    echo -e "${COLOR_CYAN}>>> Đang tiến hành cài đặt OpenWrt Speedtest...${COLOR_RESET}"
    
    mkdir -p "$TARGET_DIR"
    mkdir -p "$CGI_DIR"

    # Kiểm tra xem đang chạy từ thư mục chứa tệp nội bộ hay tải từ GitHub
    SCRIPT_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
    
    if [ -f "${SCRIPT_DIR}/index.html" ] && [ -d "${SCRIPT_DIR}/cgi-bin" ]; then
        echo -e "${COLOR_YELLOW}[1/3] Sao chép tệp từ thư mục cục bộ...${COLOR_RESET}"
        cp -f "${SCRIPT_DIR}/index.html" "${TARGET_DIR}/"
        cp -f "${SCRIPT_DIR}/style.css" "${TARGET_DIR}/"
        cp -f "${SCRIPT_DIR}/speedtest.js" "${TARGET_DIR}/"
        cp -rf "${SCRIPT_DIR}/cgi-bin/"* "${CGI_DIR}/"
    else
        echo -e "${COLOR_YELLOW}[1/3] Đang tải các tệp từ GitHub (${RAW_URL})...${COLOR_RESET}"
        download_file "${RAW_URL}/index.html" "${TARGET_DIR}/index.html"
        download_file "${RAW_URL}/style.css" "${TARGET_DIR}/style.css"
        download_file "${RAW_URL}/speedtest.js" "${TARGET_DIR}/speedtest.js"
        download_file "${RAW_URL}/cgi-bin/download.cgi" "${CGI_DIR}/download.cgi"
        download_file "${RAW_URL}/cgi-bin/upload.cgi" "${CGI_DIR}/upload.cgi"
        download_file "${RAW_URL}/cgi-bin/empty.cgi" "${CGI_DIR}/empty.cgi"
        download_file "${RAW_URL}/cgi-bin/sysinfo.cgi" "${CGI_DIR}/sysinfo.cgi"
    fi

    echo -e "${COLOR_YELLOW}[2/3] Cấp quyền thực thi và tạo liên kết CGI...${COLOR_RESET}"
    chmod +x "${CGI_DIR}"/*.cgi 2>/dev/null || true
    mkdir -p /www/cgi-bin
    ln -sfn "${CGI_DIR}" /www/cgi-bin/speedtest
    for cgi in "$CGI_DIR"/*.cgi; do
        if [ -f "$cgi" ]; then
            ln -sf "$cgi" "/www/cgi-bin/speedtest_$(basename "$cgi")" 2>/dev/null || true
        fi
    done

    echo -e "${COLOR_YELLOW}[3/3] Khởi động lại uhttpd...${COLOR_RESET}"
    /etc/init.d/uhttpd restart >/dev/null 2>&1 || true

    LAN_IP=$(uci get network.lan.ipaddr 2>/dev/null || echo "192.168.1.1")

    echo ""
    echo -e "${COLOR_GREEN}======================================================${COLOR_RESET}"
    echo -e "${COLOR_GREEN}      🎉 CÀI ĐẶT THÀNH CÔNG OPENWRT SPEEDTEST!       ${COLOR_RESET}"
    echo -e "${COLOR_GREEN}======================================================${COLOR_RESET}"
    echo -e "Truy cập giao diện đo tốc độ tại:"
    echo -e "  👉 ${COLOR_CYAN}http://${LAN_IP}/speedtest/${COLOR_RESET}"
    echo -e "  👉 ${COLOR_CYAN}http://openwrt.lan/speedtest/${COLOR_RESET}"
    echo -e "${COLOR_GREEN}======================================================${COLOR_RESET}"
    echo ""
}

# Hàm Gỡ cài đặt
do_uninstall() {
    echo ""
    echo -e "${COLOR_YELLOW}>>> Đang gỡ bỏ OpenWrt Speedtest...${COLOR_RESET}"
    
    if [ -d "$TARGET_DIR" ]; then
        rm -rf "$TARGET_DIR"
        echo -e "${COLOR_GREEN}✔ Đã xóa thư mục /www/speedtest${COLOR_RESET}"
    else
        echo -e "${COLOR_YELLOW}ℹ Không tìm thấy thư mục cài đặt /www/speedtest${COLOR_RESET}"
    fi

    # Xóa symlink nếu có
    rm -rf /www/cgi-bin/speedtest 2>/dev/null || true
    rm -f /www/cgi-bin/speedtest_*.cgi 2>/dev/null || true

    # Khởi động lại uhttpd
    /etc/init.d/uhttpd restart >/dev/null 2>&1 || true

    echo -e "${COLOR_GREEN}✔ Khởi động lại uhttpd thành công.${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_GREEN}======================================================${COLOR_RESET}"
    echo -e "${COLOR_GREEN}      🗑️ ĐÃ GỠ BỎ HOÀN TOÀN OPENWRT SPEEDTEST!       ${COLOR_RESET}"
    echo -e "${COLOR_GREEN}======================================================${COLOR_RESET}"
    echo ""
}

# Hàm Kiểm tra trạng thái
do_status() {
    echo ""
    echo -e "${COLOR_CYAN}=== KIỂM TRA TRẠNG THÁI OPENWRT SPEEDTEST ===${COLOR_RESET}"
    if [ -d "$TARGET_DIR" ] && [ -f "${TARGET_DIR}/index.html" ]; then
        LAN_IP=$(uci get network.lan.ipaddr 2>/dev/null || echo "192.168.1.1")
        echo -e "Trạng thái: ${COLOR_GREEN}ĐÃ CÀI ĐẶT (Active)${COLOR_RESET}"
        echo -e "Đường dẫn:  ${TARGET_DIR}"
        echo -e "Địa chỉ:    ${COLOR_CYAN}http://${LAN_IP}/speedtest/${COLOR_RESET}"
    else
        echo -e "Trạng thái: ${COLOR_RED}CHƯA CÀI ĐẶT (Not installed)${COLOR_RESET}"
    fi
    echo ""
}

# Xử lý tham số truyền trực tiếp từ dòng lệnh (ví dụ: sh setup.sh install / sh setup.sh uninstall)
case "$1" in
    install|1)
        do_install
        exit 0
        ;;
    uninstall|remove|2)
        do_uninstall
        exit 0
        ;;
    status|3)
        do_status
        exit 0
        ;;
    restart|4)
        /etc/init.d/uhttpd restart
        echo -e "${COLOR_GREEN}✔ Đã khởi động lại uhttpd!${COLOR_RESET}"
        exit 0
        ;;
esac

# Hiển thị Menu Tương Tác nếu chạy không kèm tham số
show_menu() {
    clear 2>/dev/null || true
    echo -e "${COLOR_CYAN}======================================================${COLOR_RESET}"
    echo -e "${COLOR_CYAN}       🚀 OPENWRT SPEEDTEST MANAGER - QUẢN LÝ        ${COLOR_RESET}"
    echo -e "${COLOR_CYAN}======================================================${COLOR_RESET}"
    
    if [ -d "$TARGET_DIR" ] && [ -f "${TARGET_DIR}/index.html" ]; then
        echo -e " Trạng thái hiện tại: ${COLOR_GREEN}● ĐÃ CÀI ĐẶT${COLOR_RESET}"
    else
        echo -e " Trạng thái hiện tại: ${COLOR_YELLOW}○ CHƯA CÀI ĐẶT${COLOR_RESET}"
    fi
    
    echo -e "------------------------------------------------------"
    echo -e "  ${COLOR_GREEN}[1]${COLOR_RESET} Cài đặt / Cập nhật Speedtest (Install)"
    echo -e "  ${COLOR_RED}[2]${COLOR_RESET} Gỡ cài đặt Speedtest (Uninstall)"
    echo -e "  ${COLOR_CYAN}[3]${COLOR_RESET} Kiểm tra trạng thái (Status)"
    echo -e "  ${COLOR_YELLOW}[4]${COLOR_RESET} Khởi động lại dịch vụ web (Restart uhttpd)"
    echo -e "  [0] Thoát (Exit)"
    echo -e "${COLOR_CYAN}======================================================${COLOR_RESET}"
    printf " Nhập lựa chọn của bạn [0-4]: "
    read -r choice

    case "$choice" in
        1)
            do_install
            ;;
        2)
            do_uninstall
            ;;
        3)
            do_status
            ;;
        4)
            /etc/init.d/uhttpd restart
            echo -e "${COLOR_GREEN}✔ Đã khởi động lại uhttpd!${COLOR_RESET}"
            ;;
        0)
            echo "Tạm biệt!"
            exit 0
            ;;
        *)
            echo -e "${COLOR_RED}Lựa chọn không hợp lệ!${COLOR_RESET}"
            ;;
    esac
}

show_menu
