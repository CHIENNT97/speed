# HƯỚNG DẪN ĐẨY LÊN GITHUB & CÀI ĐẶT QUA SSH OPENWRT

**Repository:** [https://github.com/CHIENNT97/openwrt_speed](https://github.com/CHIENNT97/openwrt_speed)

---

## 🚀 1. CÁCH ĐẨY CÁC FILE LÊN REPOSITORY CỦA BẠN

### Cách A (Nhanh nhất): Tải trực tiếp trên giao diện Web GitHub
1. Mở trang repo: **[https://github.com/CHIENNT97/openwrt_speed](https://github.com/CHIENNT97/openwrt_speed)**
2. Nhấn nút **Add file** (ở phía trên) ➔ Chọn **Upload files**.
3. Kéo toàn bộ file trong thư mục `C:\Users\NTChien97\Music\speed test` (bao gồm cả thư mục `cgi-bin`) thả vào trình duyệt.
4. Kéo xuống dưới bấm nút xanh **Commit changes**.

---

### Cách B: Đẩy bằng lệnh Git từ máy tính
Mở PowerShell tại thư mục `C:\Users\NTChien97\Music\speed test` và chạy:

```bash
git init
git add .
git commit -m "Khoi tao OpenWrt Speedtest"
git branch -M main
git remote add origin https://github.com/CHIENNT97/openwrt_speed.git
git push -u origin main
```

---

## ⚡ 2. LỆNH 1 DÒNG CHẠY MENU CÀI ĐẶT & GỠ BỎ TRÊN SSH OPENWRT

Sau khi file đã có trên repo, bạn mở SSH vào Modem OpenWrt (`ssh root@192.168.1.1`) và dán dòng lệnh sau:

### Lệnh chạy với `curl`:
```bash
sh -c "$(curl -kfsSL https://raw.githubusercontent.com/CHIENNT97/openwrt_speed/main/setup.sh)"
```

### Hoặc lệnh chạy với `wget`:
```bash
wget --no-check-certificate -qO- https://raw.githubusercontent.com/CHIENNT97/openwrt_speed/main/setup.sh | sh
```

---

## 🖥️ GIAO DIỆN MENU SẼ XUẤT HIỆN:

```text
======================================================
       🚀 OPENWRT SPEEDTEST MANAGER - QUẢN LÝ        
======================================================
 Trạng thái hiện tại: ○ CHƯA CÀI ĐẶT
------------------------------------------------------
  [1] Cài đặt / Cập nhật Speedtest (Install)
  [2] Gỡ cài đặt Speedtest (Uninstall)
  [3] Kiểm tra trạng thái (Status)
  [4] Khởi động lại dịch vụ web (Restart uhttpd)
  [0] Thoát (Exit)
======================================================
 Nhập lựa chọn của bạn [0-4]: 
```

- **Nhập `1` rồi nhấn Enter**: Tự động tải từ `CHIENNT97/openwrt_speed` về `/www/speedtest/`, bật quyền thực thi cho CGI và in link truy cập web (`http://192.168.1.1/speedtest/`).
- **Nhập `2` rồi nhấn Enter**: Tự động gỡ bỏ và xóa sạch hoàn toàn speedtest khỏi modem.
