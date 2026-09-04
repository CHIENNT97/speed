#!/bin/sh
# ==============================================================================
# OpenWrt Speedtest - Standalone All-In-One Quick Installer
# Copy và Paste toàn bộ nội dung này vào terminal SSH trên modem OpenWrt
# ==============================================================================

set -e

echo "=== Đang cài đặt OpenWrt Web Speedtest ==="

TARGET_DIR="/www/speedtest"
CGI_DIR="${TARGET_DIR}/cgi-bin"

mkdir -p "$TARGET_DIR"
mkdir -p "$CGI_DIR"

# 1. Tạo CGI download
cat << 'EOF' > "${CGI_DIR}/download.cgi"
#!/bin/sh
printf "Content-Type: application/octet-stream\r\n"
printf "Cache-Control: no-store, no-cache, must-revalidate, max-age=0\r\n"
printf "Pragma: no-cache\r\n"
printf "Connection: keep-alive\r\n"

SIZE=25
if [ -n "$QUERY_STRING" ]; then
    PARAM_SIZE=$(echo "$QUERY_STRING" | grep -o 'size=[0-9]*' | cut -d= -f2)
    if [ -n "$PARAM_SIZE" ] && [ "$PARAM_SIZE" -gt 0 ] && [ "$PARAM_SIZE" -le 500 ]; then
        SIZE=$PARAM_SIZE
    fi
fi

BYTES=$((SIZE * 1048576))
printf "Content-Length: %d\r\n\r\n" "$BYTES"
dd if=/dev/zero bs=65536 count=$((SIZE * 16)) 2>/dev/null
EOF

# 2. Tạo CGI upload
cat << 'EOF' > "${CGI_DIR}/upload.cgi"
#!/bin/sh
cat > /dev/null
printf "Content-Type: text/plain\r\n"
printf "Cache-Control: no-store, no-cache, must-revalidate, max-age=0\r\n"
printf "Pragma: no-cache\r\n"
printf "Connection: keep-alive\r\n\r\n"
printf "OK\n"
EOF

# 3. Tạo CGI empty (Ping/Jitter)
cat << 'EOF' > "${CGI_DIR}/empty.cgi"
#!/bin/sh
printf "Content-Type: text/plain\r\n"
printf "Cache-Control: no-store, no-cache, must-revalidate, max-age=0\r\n"
printf "Pragma: no-cache\r\n"
printf "Content-Length: 0\r\n\r\n"
EOF

# 4. Tạo CGI sysinfo
cat << 'EOF' > "${CGI_DIR}/sysinfo.cgi"
#!/bin/sh
printf "Content-Type: application/json\r\n"
printf "Cache-Control: no-store, no-cache, must-revalidate, max-age=0\r\n"
printf "Access-Control-Allow-Origin: *\r\n\r\n"

HOSTNAME=$(cat /proc/sys/kernel/hostname 2>/dev/null || uname -n)
MODEL=$(cat /tmp/sysinfo/model 2>/dev/null || cat /proc/cpuinfo | grep -i "machine\|model\|system type" | head -n1 | cut -d: -f2 | sed 's/^[ \t]*//')
[ -z "$MODEL" ] && MODEL=$(uname -m)

OS_NAME="OpenWrt"
[ -f /etc/openwrt_release ] && . /etc/openwrt_release && OS_NAME="$DISTRIB_DESCRIPTION"

UPTIME_SEC=$(cut -d. -f1 /proc/uptime 2>/dev/null || echo 0)
DAYS=$((UPTIME_SEC / 86400))
HOURS=$(( (UPTIME_SEC % 86400) / 3600 ))
MINS=$(( (UPTIME_SEC % 3600) / 60 ))
UPTIME_STR="${DAYS}d ${HOURS}h ${MINS}m"

LOAD=$(cat /proc/loadavg 2>/dev/null | awk '{print $1", "$2", "$3}')
[ -z "$LOAD" ] && LOAD="0.00, 0.00, 0.00"

CPU_MODEL=$(cat /proc/cpuinfo 2>/dev/null | grep -i "model name\|cpu model\|Processor" | head -n1 | cut -d: -f2 | sed 's/^[ \t]*//')
CPU_CORES=$(grep -c "^processor" /proc/cpuinfo 2>/dev/null || echo 1)
[ "$CPU_CORES" -le 0 ] && CPU_CORES=1

MEM_TOTAL=$(grep "MemTotal:" /proc/meminfo 2>/dev/null | awk '{print $2}')
MEM_FREE=$(grep "MemFree:" /proc/meminfo 2>/dev/null | awk '{print $2}')
MEM_BUFFERS=$(grep "Buffers:" /proc/meminfo 2>/dev/null | awk '{print $2}')
MEM_CACHED=$(grep "^Cached:" /proc/meminfo 2>/dev/null | awk '{print $2}')
[ -z "$MEM_BUFFERS" ] && MEM_BUFFERS=0
[ -z "$MEM_CACHED" ] && MEM_CACHED=0
[ -z "$MEM_FREE" ] && MEM_FREE=0
[ -z "$MEM_TOTAL" ] && MEM_TOTAL=1024

MEM_USED=$((MEM_TOTAL - MEM_FREE - MEM_BUFFERS - MEM_CACHED))
MEM_PCT=$((MEM_USED * 100 / MEM_TOTAL))

TEMP="N/A"
if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
    RAW_TEMP=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
    if [ -n "$RAW_TEMP" ]; then
        if [ "$RAW_TEMP" -gt 1000 ]; then
            TEMP="$((RAW_TEMP / 1000))°C"
        else
            TEMP="${RAW_TEMP}°C"
        fi
    fi
fi

CLIENT_IP="$REMOTE_ADDR"
[ -z "$CLIENT_IP" ] && CLIENT_IP="127.0.0.1"

cat << JSON_EOF
{
  "hostname": "$HOSTNAME",
  "model": "$MODEL",
  "os": "$OS_NAME",
  "uptime": "$UPTIME_STR",
  "load": "$LOAD",
  "cpu_model": "$CPU_MODEL",
  "cpu_cores": $CPU_CORES,
  "mem_total_kb": $MEM_TOTAL,
  "mem_used_kb": $MEM_USED,
  "mem_pct": $MEM_PCT,
  "temperature": "$TEMP",
  "client_ip": "$CLIENT_IP"
}
JSON_EOF
EOF

chmod +x "${CGI_DIR}"/*.cgi

# Copy html, css, js files if script is running locally, otherwise create standard files
cat << 'EOF' > "${TARGET_DIR}/index.html"
<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>OpenWrt Speedtest - Kiểm Tra Tốc Độ Mạng</title>
  <link rel="stylesheet" href="style.css">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;600;700;800;900&family=JetBrains+Mono:wght@400;600&display=swap" rel="stylesheet">
</head>
<body>
  <div class="bg-glow bg-glow-1"></div>
  <div class="bg-glow bg-glow-2"></div>
  <div class="bg-grid"></div>

  <div class="app-container">
    <header class="header">
      <div class="logo-group">
        <div class="logo-icon">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M12 2v4M12 18v4M4.93 4.93l2.83 2.83M16.24 16.24l2.83 2.83M2 12h4M18 12h4M4.93 19.07l2.83-2.83M16.24 7.76l2.83-2.83"/>
            <circle cx="12" cy="12" r="3"/>
          </svg>
        </div>
        <div class="logo-text">
          <h1>OPENWRT <span>SPEEDTEST</span></h1>
          <p class="subtitle">Kiểm tra tốc độ kết nối Modem / Router</p>
        </div>
      </div>
      <div class="header-badges">
        <div class="badge badge-router" id="badge-router">
          <span class="dot dot-online"></span>
          <span id="router-hostname">OpenWrt</span>
        </div>
        <button class="icon-btn" id="btn-settings" title="Cài đặt">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <circle cx="12" cy="12" r="3"></circle>
            <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"></path>
          </svg>
        </button>
      </div>
    </header>

    <main class="main-content">
      <div class="metrics-row">
        <div class="metric-card" id="card-ping">
          <div class="metric-header">
            <span class="metric-icon icon-ping">●</span>
            <span class="metric-label">ĐỘ TRỄ (PING)</span>
          </div>
          <div class="metric-value-box">
            <span class="metric-value" id="val-ping">--</span>
            <span class="metric-unit">ms</span>
          </div>
          <div class="metric-sub">Jitter: <b id="val-jitter">--</b> ms</div>
        </div>

        <div class="metric-card" id="card-download">
          <div class="metric-header">
            <span class="metric-icon icon-dl">↓</span>
            <span class="metric-label">TẢI VỀ (DOWNLOAD)</span>
          </div>
          <div class="metric-value-box">
            <span class="metric-value val-cyan" id="val-download">0.0</span>
            <span class="metric-unit">Mbps</span>
          </div>
          <div class="metric-sub">Đã truyền: <b id="bytes-download">0 MB</b></div>
        </div>

        <div class="metric-card" id="card-upload">
          <div class="metric-header">
            <span class="metric-icon icon-ul">↑</span>
            <span class="metric-label">TẢI LÊN (UPLOAD)</span>
          </div>
          <div class="metric-value-box">
            <span class="metric-value val-purple" id="val-upload">0.0</span>
            <span class="metric-unit">Mbps</span>
          </div>
          <div class="metric-sub">Đã truyền: <b id="bytes-upload">0 MB</b></div>
        </div>
      </div>

      <div class="gauge-section">
        <div class="gauge-wrapper">
          <svg class="gauge-svg" viewBox="0 0 300 300">
            <defs>
              <linearGradient id="gaugeGrad" x1="0%" y1="0%" x2="100%" y2="100%">
                <stop offset="0%" stop-color="#00f2fe"/>
                <stop offset="50%" stop-color="#4facfe"/>
                <stop offset="100%" stop-color="#a855f7"/>
              </linearGradient>
              <filter id="glow" x="-20%" y="-20%" width="140%" height="140%">
                <feGaussianBlur stdDeviation="6" result="blur"/>
                <feComposite in="SourceGraphic" in2="blur" operator="over"/>
              </filter>
            </defs>
            <circle class="gauge-track" cx="150" cy="150" r="120" />
            <circle class="gauge-progress" id="gauge-arc" cx="150" cy="150" r="120" />
            <g class="gauge-ticks" id="gauge-ticks"></g>
          </svg>

          <div class="gauge-center">
            <div class="gauge-status-tag" id="test-status">SẴN SÀNG</div>
            <div class="gauge-speed-num" id="gauge-speed">0.0</div>
            <div class="gauge-speed-unit">Mbps</div>
            <button class="start-btn" id="btn-start">
              <span class="btn-text" id="btn-text">BẮT ĐẦU</span>
            </button>
          </div>
        </div>

        <div class="live-chart-container">
          <div class="chart-header">
            <span>BIỂU ĐỒ BĂNG THÔNG THỜI GIAN THỰC</span>
            <span class="chart-legend">
              <span class="dot-legend dot-dl"></span> Tải về
              <span class="dot-legend dot-ul"></span> Tải lên
            </span>
          </div>
          <canvas id="live-canvas" width="600" height="120"></canvas>
        </div>
      </div>

      <div class="info-grid">
        <div class="info-card">
          <div class="info-title">THÔNG TIN MODEM / ROUTER</div>
          <div class="info-list">
            <div class="info-item"><span class="label">Thiết bị:</span><span class="val" id="sys-model">Đang nạp...</span></div>
            <div class="info-item"><span class="label">Hệ điều hành:</span><span class="val" id="sys-os">OpenWrt</span></div>
            <div class="info-item"><span class="label">CPU / Nhiệt độ:</span><span class="val" id="sys-cpu">--</span></div>
            <div class="info-item"><span class="label">RAM / Tải:</span><span class="val" id="sys-ram">--</span></div>
            <div class="info-item"><span class="label">Uptime:</span><span class="val" id="sys-uptime">--</span></div>
          </div>
        </div>

        <div class="info-card">
          <div class="info-title">THÔNG TIN KẾT NỐI CLIENT</div>
          <div class="info-list">
            <div class="info-item"><span class="label">IP của bạn:</span><span class="val font-mono" id="client-ip">--</span></div>
            <div class="info-item"><span class="label">Trình duyệt:</span><span class="val" id="client-browser">--</span></div>
            <div class="info-item"><span class="label">Chế độ test:</span><span class="val" id="client-streams">Đa luồng</span></div>
            <div class="info-item"><span class="label">Mục tiêu:</span><span class="val text-success">Đo tốc độ tối đa qua Modem</span></div>
          </div>
        </div>
      </div>

      <div class="history-section" id="history-box" style="display: none;">
        <div class="history-header">
          <h3>LỊCH SỬ KIỂM TRA</h3>
          <button class="btn-clear" id="btn-clear-history">Xóa lịch sử</button>
        </div>
        <div class="history-table-wrap">
          <table class="history-table">
            <thead>
              <tr>
                <th>Thời gian</th>
                <th>Ping</th>
                <th>Jitter</th>
                <th>Download</th>
                <th>Upload</th>
              </tr>
            </thead>
            <tbody id="history-tbody"></tbody>
          </table>
        </div>
      </div>
    </main>

    <footer class="footer">
      <p>OpenWrt Speedtest Engine • Tối ưu hóa cho băng thông Gigabit & Môi trường Modem</p>
    </footer>
  </div>

  <div class="modal-overlay" id="modal-settings">
    <div class="modal-box">
      <div class="modal-header">
        <h3>Cài đặt kiểm tra</h3>
        <button class="modal-close" id="btn-close-settings">&times;</button>
      </div>
      <div class="modal-body">
        <div class="setting-row">
          <label>Số luồng song song:</label>
          <select id="set-threads">
            <option value="1">1 luồng</option>
            <option value="2">2 luồng</option>
            <option value="4" selected>4 luồng (Khuyên dùng)</option>
            <option value="8">8 luồng (Gigabit)</option>
          </select>
        </div>
        <div class="setting-row">
          <label>Thời gian đo mỗi chiều:</label>
          <select id="set-duration">
            <option value="5">5 giây</option>
            <option value="10" selected>10 giây</option>
            <option value="15">15 giây</option>
          </select>
        </div>
      </div>
      <div class="modal-footer">
        <button class="btn-save" id="btn-save-settings">Lưu & Áp dụng</button>
      </div>
    </div>
  </div>

  <script src="speedtest.js"></script>
</body>
</html>
EOF

# Write CSS
cat << 'EOF' > "${TARGET_DIR}/style.css"
:root {
  --bg-main: #0b0f19;
  --bg-card: rgba(18, 24, 38, 0.7);
  --border-subtle: rgba(255, 255, 255, 0.08);
  --border-glow: rgba(0, 242, 254, 0.3);
  --color-primary: #00f2fe;
  --color-secondary: #4facfe;
  --color-purple: #c084fc;
  --color-success: #10b981;
  --color-warning: #f59e0b;
  --color-text: #f8fafc;
  --color-text-muted: #94a3b8;
  --color-text-dim: #64748b;
  --font-main: 'Outfit', sans-serif;
  --font-mono: 'JetBrains Mono', monospace;
  --gauge-size: 280px;
}
* { margin:0; padding:0; box-sizing:border-box; }
body { font-family:var(--font-main); background:var(--bg-main); color:var(--color-text); min-height:100vh; display:flex; flex-direction:column; align-items:center; }
.bg-glow { position:fixed; border-radius:50%; filter:blur(120px); z-index:0; pointer-events:none; opacity:0.25; }
.bg-glow-1 { width:500px; height:500px; background:radial-gradient(circle, #00f2fe, #4facfe); top:-100px; left:10%; }
.bg-glow-2 { width:600px; height:600px; background:radial-gradient(circle, #a855f7, #6366f1); bottom:-150px; right:10%; }
.bg-grid { position:fixed; top:0; left:0; width:100%; height:100%; background-image:linear-gradient(rgba(255,255,255,0.02) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.02) 1px, transparent 1px); background-size:40px 40px; z-index:0; pointer-events:none; }
.app-container { position:relative; z-index:1; width:100%; max-width:960px; padding:24px 20px 40px; display:flex; flex-direction:column; min-height:100vh; }
.header { display:flex; justify-content:space-between; align-items:center; padding-bottom:20px; border-bottom:1px solid var(--border-subtle); margin-bottom:24px; }
.logo-group { display:flex; align-items:center; gap:14px; }
.logo-icon { width:44px; height:44px; background:rgba(0,242,254,0.15); border:1px solid var(--border-glow); border-radius:12px; display:flex; align-items:center; justify-content:center; color:var(--color-primary); }
.logo-icon svg { width:24px; height:24px; }
.logo-text h1 { font-size:1.35rem; font-weight:800; color:#fff; }
.logo-text h1 span { background:linear-gradient(90deg, var(--color-primary), var(--color-purple)); -webkit-background-clip:text; -webkit-text-fill-color:transparent; }
.subtitle { font-size:0.8rem; color:var(--color-text-muted); }
.header-badges { display:flex; align-items:center; gap:12px; }
.badge { display:flex; align-items:center; gap:8px; background:rgba(255,255,255,0.05); border:1px solid var(--border-subtle); padding:6px 14px; border-radius:20px; font-size:0.82rem; }
.dot { width:8px; height:8px; border-radius:50%; }
.dot-online { background:var(--color-success); box-shadow:0 0 8px var(--color-success); }
.icon-btn { background:rgba(255,255,255,0.05); border:1px solid var(--border-subtle); width:38px; height:38px; border-radius:10px; display:flex; align-items:center; justify-content:center; color:var(--color-text-muted); cursor:pointer; }
.icon-btn svg { width:18px; height:18px; }
.metrics-row { display:grid; grid-template-columns:repeat(3, 1fr); gap:16px; margin-bottom:24px; }
.metric-card { background:var(--bg-card); border:1px solid var(--border-subtle); border-radius:16px; padding:18px 20px; backdrop-filter:blur(16px); position:relative; }
.metric-card.active { border-color:rgba(0,242,254,0.4); box-shadow:0 8px 24px rgba(0,242,254,0.12); }
.metric-header { display:flex; align-items:center; gap:8px; margin-bottom:10px; }
.icon-ping { color:var(--color-warning); font-weight:bold; }
.icon-dl { color:var(--color-primary); font-size:1.1rem; }
.icon-ul { color:var(--color-purple); font-size:1.1rem; }
.metric-label { font-size:0.72rem; font-weight:700; color:var(--color-text-muted); }
.metric-value-box { display:flex; align-items:baseline; gap:6px; margin-bottom:6px; }
.metric-value { font-size:2.2rem; font-weight:800; font-family:var(--font-mono); color:#fff; }
.val-cyan { color:var(--color-primary); }
.val-purple { color:var(--color-purple); }
.metric-unit { font-size:0.9rem; font-weight:600; color:var(--color-text-dim); }
.metric-sub { font-size:0.78rem; color:var(--color-text-dim); }
.metric-sub b { color:var(--color-text-muted); font-family:var(--font-mono); }
.gauge-section { background:var(--bg-card); border:1px solid var(--border-subtle); border-radius:20px; padding:30px 24px 20px; backdrop-filter:blur(16px); display:flex; flex-direction:column; align-items:center; margin-bottom:24px; }
.gauge-wrapper { position:relative; width:var(--gauge-size); height:var(--gauge-size); display:flex; align-items:center; justify-content:center; margin-bottom:16px; }
.gauge-svg { position:absolute; top:0; left:0; width:100%; height:100%; transform:rotate(135deg); }
.gauge-track { fill:none; stroke:rgba(255,255,255,0.06); stroke-width:12; stroke-linecap:round; stroke-dasharray:565.48; stroke-dashoffset:0; }
.gauge-progress { fill:none; stroke:url(#gaugeGrad); stroke-width:12; stroke-linecap:round; stroke-dasharray:565.48; stroke-dashoffset:565.48; filter:url(#glow); transition:stroke-dashoffset 0.15s ease-out; }
.gauge-center { display:flex; flex-direction:column; align-items:center; justify-content:center; text-align:center; z-index:2; }
.gauge-status-tag { font-size:0.72rem; font-weight:700; letter-spacing:1.5px; padding:4px 12px; background:rgba(255,255,255,0.06); border-radius:12px; color:var(--color-primary); margin-bottom:4px; }
.gauge-speed-num { font-size:3.2rem; font-weight:900; font-family:var(--font-mono); color:#fff; text-shadow:0 0 20px rgba(0,242,254,0.4); }
.gauge-speed-unit { font-size:0.85rem; font-weight:700; color:var(--color-text-dim); margin-bottom:14px; }
.start-btn { background:linear-gradient(135deg, #00f2fe, #a855f7); border:none; border-radius:30px; padding:10px 28px; color:#0b0f19; font-weight:800; font-size:0.95rem; cursor:pointer; box-shadow:0 4px 20px rgba(0,242,254,0.35); transition:all 0.25s; }
.start-btn:hover { transform:scale(1.04); box-shadow:0 6px 28px rgba(0,242,254,0.55); }
.start-btn.running { background:linear-gradient(135deg, #ef4444, #f97316); color:#fff; }
.live-chart-container { width:100%; margin-top:10px; border-top:1px solid var(--border-subtle); padding-top:14px; }
.chart-header { display:flex; justify-content:space-between; font-size:0.72rem; font-weight:700; color:var(--color-text-dim); margin-bottom:8px; }
.dot-legend { display:inline-block; width:8px; height:8px; border-radius:50%; margin-right:4px; }
.dot-dl { background:var(--color-primary); }
.dot-ul { background:var(--color-purple); }
#live-canvas { width:100%; height:100px; border-radius:8px; background:rgba(0,0,0,0.2); }
.info-grid { display:grid; grid-template-columns:1fr 1fr; gap:16px; margin-bottom:24px; }
.info-card { background:var(--bg-card); border:1px solid var(--border-subtle); border-radius:16px; padding:18px 20px; backdrop-filter:blur(16px); }
.info-title { font-size:0.78rem; font-weight:700; color:var(--color-text-muted); margin-bottom:14px; border-bottom:1px solid var(--border-subtle); padding-bottom:8px; }
.info-list { display:flex; flex-direction:column; gap:8px; }
.info-item { display:flex; justify-content:space-between; font-size:0.82rem; }
.info-item .label { color:var(--color-text-dim); }
.info-item .val { font-weight:600; color:var(--color-text); font-family:var(--font-mono); }
.text-success { color:var(--color-success) !important; }
.history-section { background:var(--bg-card); border:1px solid var(--border-subtle); border-radius:16px; padding:18px 20px; margin-bottom:24px; }
.history-header { display:flex; justify-content:space-between; margin-bottom:12px; font-size:0.85rem; color:var(--color-text-muted); }
.btn-clear { background:none; border:none; color:var(--color-text-dim); cursor:pointer; }
.history-table { width:100%; border-collapse:collapse; font-size:0.82rem; font-family:var(--font-mono); }
.history-table th, .history-table td { padding:8px 12px; border-bottom:1px solid var(--border-subtle); text-align:left; }
.footer { text-align:center; padding-top:12px; margin-top:auto; font-size:0.75rem; color:var(--color-text-dim); }
.modal-overlay { position:fixed; top:0; left:0; width:100%; height:100%; background:rgba(0,0,0,0.7); backdrop-filter:blur(8px); display:flex; align-items:center; justify-content:center; z-index:100; opacity:0; pointer-events:none; transition:opacity 0.25s; }
.modal-overlay.open { opacity:1; pointer-events:auto; }
.modal-box { background:#131b2e; border:1px solid var(--border-subtle); border-radius:20px; width:90%; max-width:440px; padding:24px; }
.modal-header { display:flex; justify-content:space-between; align-items:center; margin-bottom:20px; }
.modal-close { background:none; border:none; color:var(--color-text-dim); font-size:1.5rem; cursor:pointer; }
.setting-row { margin-bottom:16px; display:flex; flex-direction:column; gap:6px; font-size:0.8rem; }
.setting-row select { background:rgba(255,255,255,0.05); border:1px solid var(--border-subtle); border-radius:10px; color:#fff; padding:10px 12px; }
.btn-save { width:100%; background:linear-gradient(135deg, var(--color-primary), var(--color-secondary)); border:none; border-radius:12px; padding:12px; color:#0b0f19; font-weight:700; cursor:pointer; }
@media (max-width:768px) { .metrics-row, .info-grid { grid-template-columns:1fr; } :root { --gauge-size:240px; } }
EOF

# Write JS
cat << 'EOF' > "${TARGET_DIR}/speedtest.js"
(() => {
  const getBasePath = () => {
    let p = window.location.pathname;
    if (p.endsWith('.html') || p.endsWith('.htm')) p = p.substring(0, p.lastIndexOf('/'));
    if (!p.endsWith('/')) p += '/';
    return p;
  };
  const BASE_URL = getBasePath();
  const CGI_PING = `${BASE_URL}cgi-bin/empty.cgi`;
  const CGI_DOWNLOAD = `${BASE_URL}cgi-bin/download.cgi`;
  const CGI_UPLOAD = `${BASE_URL}cgi-bin/upload.cgi`;
  const CGI_SYSINFO = `${BASE_URL}cgi-bin/sysinfo.cgi`;

  let config = { threads: 4, duration: 10, dlChunkSize: 25, ulChunkSize: 5 };
  try { const s = localStorage.getItem('openwrt_speedtest_cfg'); if (s) config = {...config, ...JSON.parse(s)}; } catch(e){}

  let isRunning = false;
  let abortController = null;
  let activeXHRs = [];

  const elBtnStart = document.getElementById('btn-start');
  const elBtnText = document.getElementById('btn-text');
  const elStatus = document.getElementById('test-status');
  const elGaugeSpeed = document.getElementById('gauge-speed');
  const elGaugeArc = document.getElementById('gauge-arc');
  const elValPing = document.getElementById('val-ping');
  const elValJitter = document.getElementById('val-jitter');
  const elValDownload = document.getElementById('val-download');
  const elValUpload = document.getElementById('val-upload');
  const elBytesDl = document.getElementById('bytes-download');
  const elBytesUl = document.getElementById('bytes-upload');
  const elCardPing = document.getElementById('card-ping');
  const elCardDl = document.getElementById('card-download');
  const elCardUl = document.getElementById('card-upload');

  const canvas = document.getElementById('live-canvas');
  const ctx = canvas.getContext('2d');
  let chartData = { dl: [], ul: [] };

  const initTicks = () => {
    const g = document.getElementById('gauge-ticks');
    if (!g) return;
    for (let i = 0; i <= 30; i++) {
      const angle = (135 + (i / 30) * 270) * Math.PI / 180;
      const isMaj = i % 5 === 0;
      const rIn = isMaj ? 122 : 126;
      const line = document.createElementNS('http://www.w3.org/2000/svg', 'line');
      line.setAttribute('x1', 150 + 134 * Math.cos(angle));
      line.setAttribute('y1', 150 + 134 * Math.sin(angle));
      line.setAttribute('x2', 150 + rIn * Math.cos(angle));
      line.setAttribute('y2', 150 + rIn * Math.sin(angle));
      line.setAttribute('stroke', isMaj ? 'rgba(0,242,254,0.5)' : 'rgba(255,255,255,0.1)');
      line.setAttribute('stroke-width', isMaj ? '2' : '1');
      g.appendChild(line);
    }
  };

  const updateGauge = (speed) => {
    elGaugeSpeed.textContent = speed.toFixed(speed >= 100 ? 0 : 1);
    let pct = 0;
    if (speed <= 10) pct = (speed / 10) * 0.2;
    else if (speed <= 100) pct = 0.2 + ((speed - 10) / 90) * 0.35;
    else if (speed <= 500) pct = 0.55 + ((speed - 100) / 400) * 0.25;
    else pct = 0.80 + (Math.min(speed - 500, 500) / 500) * 0.20;
    pct = Math.max(0, Math.min(1, pct));
    elGaugeArc.style.strokeDashoffset = 565.48 * (1 - pct);
  };

  const drawChart = () => {
    const w = canvas.width, h = canvas.height;
    ctx.clearRect(0, 0, w, h);
    ctx.strokeStyle = 'rgba(255,255,255,0.05)';
    for (let y = 20; y < h; y += 25) {
      ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(w, y); ctx.stroke();
    }
    const maxVal = Math.max(50, ...chartData.dl, ...chartData.ul) * 1.15;
    const drawLine = (data, col) => {
      if (data.length < 2) return;
      const step = w / Math.max(20, data.length - 1);
      ctx.beginPath();
      for (let i = 0; i < data.length; i++) {
        const x = i * step, y = h - (data[i] / maxVal) * (h - 10);
        if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
      }
      ctx.strokeStyle = col; ctx.lineWidth = 2.5; ctx.stroke();
    };
    drawLine(chartData.dl, '#00f2fe');
    drawLine(chartData.ul, '#c084fc');
  };

  const testPingAndJitter = async () => {
    elStatus.textContent = 'ĐANG ĐO ĐỘ TRỄ (PING)...';
    elCardPing.classList.add('active');
    const pings = [];
    for (let i = 0; i < 10; i++) {
      if (!isRunning) break;
      const t = performance.now();
      try {
        await fetch(`${CGI_PING}?t=${Date.now()}_${i}`, { cache: 'no-store', signal: abortController.signal });
        const rtt = performance.now() - t;
        pings.push(rtt);
        elValPing.textContent = Math.round(rtt);
        await new Promise(r => setTimeout(r, 50));
      } catch (e) { if (e.name === 'AbortError') return null; }
    }
    elCardPing.classList.remove('active');
    if (!pings.length) return { ping: 0, jitter: 0 };
    const minPing = Math.min(...pings);
    let jSum = 0;
    for (let i = 1; i < pings.length; i++) jSum += Math.abs(pings[i] - pings[i - 1]);
    const jitter = pings.length > 1 ? jSum / (pings.length - 1) : 0;
    elValPing.textContent = Math.round(minPing);
    elValJitter.textContent = jitter.toFixed(1);
    return { ping: minPing, jitter };
  };

  const testDownload = async () => {
    elStatus.textContent = 'ĐANG TẢI VỀ (DOWNLOAD)...';
    elCardDl.classList.add('active');
    const dur = config.duration * 1000;
    const start = performance.now();
    let totalBytes = 0, lastTime = start, lastBytes = 0, currentSpeed = 0;
    chartData.dl = [];

    const timer = setInterval(() => {
      if (!isRunning) return;
      const now = performance.now();
      const dt = (now - lastTime) / 1000;
      const db = totalBytes - lastBytes;
      if (dt >= 0.15) {
        const mbps = (db * 8) / (dt * 1000000);
        currentSpeed = currentSpeed === 0 ? mbps : (currentSpeed * 0.65 + mbps * 0.35);
        elValDownload.textContent = currentSpeed.toFixed(1);
        updateGauge(currentSpeed);
        elBytesDl.textContent = (totalBytes / 1048576).toFixed(1) + ' MB';
        chartData.dl.push(currentSpeed);
        drawChart();
        lastTime = now; lastBytes = totalBytes;
      }
    }, 150);

    const runStream = async (id) => {
      while (isRunning && (performance.now() - start < dur)) {
        try {
          const res = await fetch(`${CGI_DOWNLOAD}?size=${config.dlChunkSize}&_t=${Date.now()}&s=${id}`, {
            cache: 'no-store', signal: abortController.signal
          });
          const reader = res.body.getReader();
          while (isRunning && (performance.now() - start < dur)) {
            const { done, value } = await reader.read();
            if (done) break;
            totalBytes += value.length;
          }
        } catch (e) { if (e.name === 'AbortError') break; await new Promise(r => setTimeout(r, 100)); }
      }
    };

    const p = [];
    for (let i = 0; i < config.threads; i++) p.push(runStream(i));
    await new Promise(res => {
      const c = setInterval(() => {
        if (!isRunning || (performance.now() - start >= dur)) { clearInterval(c); res(); }
      }, 100);
    });

    clearInterval(timer);
    elCardDl.classList.remove('active');
    const elapsed = (performance.now() - start) / 1000;
    const finalSpeed = elapsed > 0 ? (totalBytes * 8) / (elapsed * 1000000) : 0;
    elValDownload.textContent = finalSpeed.toFixed(1);
    return finalSpeed;
  };

  const testUpload = async () => {
    elStatus.textContent = 'ĐANG TẢI LÊN (UPLOAD)...';
    elCardUl.classList.add('active');
    const dur = config.duration * 1000;
    const start = performance.now();
    let totalBytes = 0, lastTime = start, lastBytes = 0, currentSpeed = 0;
    chartData.ul = [];

    const dummy = new Uint8Array(config.ulChunkSize * 1048576);
    const uploadBlob = new Blob([dummy], { type: 'application/octet-stream' });

    const timer = setInterval(() => {
      if (!isRunning) return;
      const now = performance.now();
      const dt = (now - lastTime) / 1000;
      const db = totalBytes - lastBytes;
      if (dt >= 0.15) {
        const mbps = (db * 8) / (dt * 1000000);
        currentSpeed = currentSpeed === 0 ? mbps : (currentSpeed * 0.65 + mbps * 0.35);
        elValUpload.textContent = currentSpeed.toFixed(1);
        updateGauge(currentSpeed);
        elBytesUl.textContent = (totalBytes / 1048576).toFixed(1) + ' MB';
        chartData.ul.push(currentSpeed);
        drawChart();
        lastTime = now; lastBytes = totalBytes;
      }
    }, 150);

    const runStreamXHR = (id) => new Promise(resolve => {
      const sendChunk = () => {
        if (!isRunning || (performance.now() - start >= dur)) return resolve();
        const xhr = new XMLHttpRequest();
        activeXHRs.push(xhr);
        let prev = 0;
        xhr.upload.onprogress = (e) => {
          if (!isRunning) return;
          const diff = e.loaded - prev;
          if (diff > 0) { totalBytes += diff; prev = e.loaded; }
        };
        xhr.onload = xhr.onerror = () => {
          const idx = activeXHRs.indexOf(xhr);
          if (idx !== -1) activeXHRs.splice(idx, 1);
          if (isRunning && (performance.now() - start < dur)) sendChunk();
          else resolve();
        };
        xhr.open('POST', `${CGI_UPLOAD}?_t=${Date.now()}&s=${id}`, true);
        xhr.setRequestHeader('Content-Type', 'application/octet-stream');
        xhr.send(uploadBlob);
      };
      sendChunk();
    });

    const p = [];
    for (let i = 0; i < config.threads; i++) p.push(runStreamXHR(i));
    await new Promise(res => {
      const c = setInterval(() => {
        if (!isRunning || (performance.now() - start >= dur)) { clearInterval(c); res(); }
      }, 100);
    });

    clearInterval(timer);
    elCardUl.classList.remove('active');
    activeXHRs.forEach(x => { try{x.abort();}catch(e){} });
    activeXHRs = [];

    const elapsed = (performance.now() - start) / 1000;
    const finalSpeed = elapsed > 0 ? (totalBytes * 8) / (elapsed * 1000000) : 0;
    elValUpload.textContent = finalSpeed.toFixed(1);
    return finalSpeed;
  };

  const startSpeedTest = async () => {
    if (isRunning) { stopSpeedTest(); return; }
    isRunning = true;
    abortController = new AbortController();
    activeXHRs = [];

    elBtnStart.classList.add('running');
    elBtnText.textContent = 'DỪNG LẠI';
    elStatus.textContent = 'ĐANG KHỞI TẠO...';

    elValPing.textContent = '--'; elValJitter.textContent = '--';
    elValDownload.textContent = '0.0'; elValUpload.textContent = '0.0';
    chartData = { dl: [], ul: [] };
    drawChart(); updateGauge(0);

    try {
      const pingRes = await testPingAndJitter();
      if (!isRunning) return;
      await new Promise(r => setTimeout(r, 300));
      if (!isRunning) return;
      const dlRes = await testDownload();
      if (!isRunning) return;
      await new Promise(r => setTimeout(r, 300));
      if (!isRunning) return;
      const ulRes = await testUpload();
      if (!isRunning) return;

      elStatus.textContent = 'HOÀN THÀNH!';
      updateGauge(dlRes);
      saveHistory({
        time: new Date().toLocaleTimeString(),
        ping: Math.round(pingRes?.ping || 0),
        jitter: pingRes?.jitter?.toFixed(1) || 0,
        dl: dlRes.toFixed(1),
        ul: ulRes.toFixed(1)
      });
    } catch (e) {
      console.error(e);
      elStatus.textContent = 'ĐÃ DỪNG';
    } finally {
      isRunning = false;
      elBtnStart.classList.remove('running');
      elBtnText.textContent = 'BẮT ĐẦU';
      elCardPing.classList.remove('active');
      elCardDl.classList.remove('active');
      elCardUl.classList.remove('active');
    }
  };

  const stopSpeedTest = () => {
    isRunning = false;
    if (abortController) abortController.abort();
    activeXHRs.forEach(x => { try{x.abort();}catch(e){} });
    activeXHRs = [];
    elStatus.textContent = 'ĐÃ DỪNG';
    elBtnStart.classList.remove('running');
    elBtnText.textContent = 'BẮT ĐẦU';
  };

  const saveHistory = (rec) => {
    try {
      let h = JSON.parse(localStorage.getItem('openwrt_speedtest_history') || '[]');
      h.unshift(rec);
      if (h.length > 20) h = h.slice(0, 20);
      localStorage.setItem('openwrt_speedtest_history', JSON.stringify(h));
      renderHistory();
    } catch(e){}
  };

  const renderHistory = () => {
    const box = document.getElementById('history-box');
    const tbody = document.getElementById('history-tbody');
    if (!box || !tbody) return;
    try {
      const h = JSON.parse(localStorage.getItem('openwrt_speedtest_history') || '[]');
      if (!h.length) { box.style.display = 'none'; return; }
      box.style.display = 'block';
      tbody.innerHTML = h.map(r => `
        <tr>
          <td>${r.time}</td>
          <td>${r.ping} ms</td>
          <td>${r.jitter} ms</td>
          <td class="val-cyan">${r.dl} Mbps</td>
          <td class="val-purple">${r.ul} Mbps</td>
        </tr>
      `).join('');
    } catch(e){}
  };

  const fetchSysInfo = async () => {
    try {
      const res = await fetch(CGI_SYSINFO, { cache: 'no-store' });
      if (!res.ok) return;
      const d = await res.json();
      if (d.hostname) document.getElementById('router-hostname').textContent = d.hostname;
      if (d.model) document.getElementById('sys-model').textContent = d.model;
      if (d.os) document.getElementById('sys-os').textContent = d.os;
      if (d.cpu_model || d.temperature) {
        document.getElementById('sys-cpu').textContent = `${d.cpu_model || 'CPU'} (${d.cpu_cores || 1}c) • ${d.temperature || 'N/A'}`;
      }
      if (d.mem_pct !== undefined) {
        document.getElementById('sys-ram').textContent = `RAM: ${d.mem_pct}% • Load: ${d.load ? d.load.split(',')[0] : '0'}`;
      }
      if (d.uptime) document.getElementById('sys-uptime').textContent = d.uptime;
      if (d.client_ip) document.getElementById('client-ip').textContent = d.client_ip;
    } catch(e){}
  };

  const initSettings = () => {
    const modal = document.getElementById('modal-settings');
    const btnOpen = document.getElementById('btn-settings');
    const btnClose = document.getElementById('btn-close-settings');
    const btnSave = document.getElementById('btn-save-settings');
    const selThreads = document.getElementById('set-threads');
    const selDuration = document.getElementById('set-duration');

    selThreads.value = config.threads;
    selDuration.value = config.duration;
    btnOpen.addEventListener('click', () => modal.classList.add('open'));
    btnClose.addEventListener('click', () => modal.classList.remove('open'));
    modal.addEventListener('click', (e) => { if (e.target === modal) modal.classList.remove('open'); });

    btnSave.addEventListener('click', () => {
      config.threads = parseInt(selThreads.value, 10) || 4;
      config.duration = parseInt(selDuration.value, 10) || 10;
      try { localStorage.setItem('openwrt_speedtest_cfg', JSON.stringify(config)); } catch(e){}
      document.getElementById('client-streams').textContent = `${config.threads} luồng (${config.duration}s)`;
      modal.classList.remove('open');
    });

    const btnClear = document.getElementById('btn-clear-history');
    if (btnClear) btnClear.addEventListener('click', () => {
      localStorage.removeItem('openwrt_speedtest_history');
      renderHistory();
    });
  };

  window.addEventListener('DOMContentLoaded', () => {
    initTicks();
    drawChart();
    initSettings();
    fetchSysInfo();
    renderHistory();
    setInterval(fetchSysInfo, 15000);
    elBtnStart.addEventListener('click', startSpeedTest);
  });
})();
EOF

# Restart uhttpd
/etc/init.d/uhttpd restart >/dev/null 2>&1 || true

LAN_IP=$(uci get network.lan.ipaddr 2>/dev/null || echo "192.168.1.1")

echo ""
echo "======================================================"
echo "    CÀI ĐẶT THÀNH CÔNG OPENWRT SPEEDTEST!"
echo "======================================================"
echo "Mở trình duyệt và truy cập:"
echo "  👉 http://${LAN_IP}/speedtest/"
echo "  👉 http://openwrt.lan/speedtest/"
echo "======================================================"
