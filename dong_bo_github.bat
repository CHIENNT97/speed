@echo off
chcp 65001 >nul
echo ======================================================
echo    ĐANG ĐỒNG BỘ CODE LÊN GITHUB: CHIENNT97/speed
echo ======================================================
echo.

set "GIT_EXE=C:\Program Files\Git\cmd\git.exe"
if not exist "%GIT_EXE%" (
    set "GIT_EXE=git"
)

"%GIT_EXE%" add .

set /p msg="Nhập ghi chú cập nhật (hoặc nhấn Enter để dùng mặc định): "
if "%msg%"=="" set msg=Update OpenWrt Speedtest %date% %time%

"%GIT_EXE%" commit -m "%msg%"
echo.
echo Đang đẩy dữ liệu lên GitHub...
"%GIT_EXE%" push -u origin main

if %ERRORLEVEL% equ 0 (
    echo.
    echo ======================================================
    echo    ✔ ĐÃ ĐỒNG BỘ THÀNH CÔNG LÊN GITHUB!
    echo    Xem tại: https://github.com/CHIENNT97/speed
    echo ======================================================
) else (
    echo.
    echo ======================================================
    echo    ⚠ Đang thử push đè nếu remote có sẵn README...
    "%GIT_EXE%" push -u origin main --force
    echo ======================================================
)

echo.
pause
