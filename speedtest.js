/**
 * OpenWrt Speedtest Engine v2.0
 * Dual-Mode Engine: Real-world Internet WAN (Cloudflare Global/VN Edge CDN) & Local LAN (Modem OpenWrt)
 */

(() => {
  // Endpoints Configuration
  const ENDPOINTS = {
    lan: {
      ping: '/cgi-bin/speedtest/empty.cgi',
      download: '/cgi-bin/speedtest/download.cgi',
      upload: '/cgi-bin/speedtest/upload.cgi',
      targetName: 'Modem OpenWrt (Mạng nội bộ LAN/WiFi)'
    },
    internet: {
      ping: 'https://speed.cloudflare.com/__down?bytes=0',
      download: 'https://speed.cloudflare.com/__down',
      upload: 'https://speed.cloudflare.com/__up',
      targetName: 'Cloudflare Speed CDN (Hanoi / VN)'
    }
  };

  const CGI_SYSINFO = '/cgi-bin/speedtest/sysinfo.cgi';

  // State & Config
  let currentMode = 'internet'; // Default to Real Internet Test
  let config = {
    threads: 4,
    duration: 10,       // seconds per test
    dlChunkSize: 25,    // MB
    ulChunkSize: 5,     // MB
  };

  // Load saved config
  try {
    const saved = localStorage.getItem('openwrt_speedtest_cfg');
    if (saved) config = { ...config, ...JSON.parse(saved) };
  } catch (e) {}

  let isRunning = false;
  let abortController = null;
  let activeXHRs = [];

  // DOM Elements
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

  const elServerLocation = document.getElementById('server-location');
  const pillInternet = document.getElementById('pill-internet');
  const pillLan = document.getElementById('pill-lan');

  // Chart Canvas
  const canvas = document.getElementById('live-canvas');
  const ctx = canvas.getContext('2d');
  let chartData = { dl: [], ul: [] };

  // Generate SVG Scale Ticks
  const initTicks = () => {
    const g = document.getElementById('gauge-ticks');
    if (!g) return;
    const totalTicks = 30;
    const startAngle = 135; // degrees
    const endAngle = 405;
    const cx = 150, cy = 150, rOuter = 134, rInner = 126;

    for (let i = 0; i <= totalTicks; i++) {
      const angleDeg = startAngle + (i / totalTicks) * (endAngle - startAngle);
      const angleRad = (angleDeg * Math.PI) / 180;
      const x1 = cx + rOuter * Math.cos(angleRad);
      const y1 = cy + rOuter * Math.sin(angleRad);
      const isMajor = i % 5 === 0;
      const rIn = isMajor ? rInner - 4 : rInner;
      const x2 = cx + rIn * Math.cos(angleRad);
      const y2 = cy + rIn * Math.sin(angleRad);

      const line = document.createElementNS('http://www.w3.org/2000/svg', 'line');
      line.setAttribute('x1', x1);
      line.setAttribute('y1', y1);
      line.setAttribute('x2', x2);
      line.setAttribute('y2', y2);
      line.setAttribute('stroke', isMajor ? 'rgba(0, 242, 254, 0.5)' : 'rgba(255, 255, 255, 0.1)');
      line.setAttribute('stroke-width', isMajor ? '2' : '1');
      g.appendChild(line);
    }
  };

  // Update Arc Progress (0 to 1000 Mbps scale with logarithmic / power easing)
  const updateGauge = (speedMbps) => {
    elGaugeSpeed.textContent = speedMbps.toFixed(speedMbps >= 100 ? 0 : 1);
    
    // Scale max mapped to 1000 Mbps
    let pct = 0;
    if (speedMbps <= 0) pct = 0;
    else if (speedMbps <= 10) pct = (speedMbps / 10) * 0.2;
    else if (speedMbps <= 100) pct = 0.2 + ((speedMbps - 10) / 90) * 0.35;
    else if (speedMbps <= 500) pct = 0.55 + ((speedMbps - 100) / 400) * 0.25;
    else pct = 0.80 + (Math.min(speedMbps - 500, 500) / 500) * 0.20;

    pct = Math.max(0, Math.min(1, pct));
    const maxOffset = 565.48;
    const offset = maxOffset * (1 - pct);
    elGaugeArc.style.strokeDashoffset = offset;
  };

  // Draw Live Chart
  const drawChart = () => {
    const width = canvas.width;
    const height = canvas.height;
    ctx.clearRect(0, 0, width, height);

    // Draw grid lines
    ctx.strokeStyle = 'rgba(255, 255, 255, 0.05)';
    ctx.lineWidth = 1;
    for (let y = 20; y < height; y += 25) {
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(width, y);
      ctx.stroke();
    }

    const maxVal = Math.max(50, ...chartData.dl, ...chartData.ul) * 1.15;

    // Draw series helper
    const drawLine = (data, color, fillGrad) => {
      if (data.length < 2) return;
      const step = width / Math.max(20, data.length - 1);

      ctx.beginPath();
      ctx.moveTo(0, height);
      for (let i = 0; i < data.length; i++) {
        const x = i * step;
        const y = height - (data[i] / maxVal) * (height - 10);
        if (i === 0) ctx.lineTo(x, y);
        else {
          const prevX = (i - 1) * step;
          const prevY = height - (data[i - 1] / maxVal) * (height - 10);
          const cx = (prevX + x) / 2;
          ctx.bezierCurveTo(cx, prevY, cx, y, x, y);
        }
      }

      if (fillGrad) {
        ctx.lineTo((data.length - 1) * step, height);
        ctx.closePath();
        ctx.fillStyle = fillGrad;
        ctx.fill();
      }

      // Draw stroke
      ctx.beginPath();
      for (let i = 0; i < data.length; i++) {
        const x = i * step;
        const y = height - (data[i] / maxVal) * (height - 10);
        if (i === 0) ctx.moveTo(x, y);
        else {
          const prevX = (i - 1) * step;
          const prevY = height - (data[i - 1] / maxVal) * (height - 10);
          const cx = (prevX + x) / 2;
          ctx.bezierCurveTo(cx, prevY, cx, y, x, y);
        }
      }
      ctx.strokeStyle = color;
      ctx.lineWidth = 2.5;
      ctx.stroke();
    };

    // Download gradient
    const dlGrad = ctx.createLinearGradient(0, 0, 0, height);
    dlGrad.addColorStop(0, 'rgba(0, 242, 254, 0.25)');
    dlGrad.addColorStop(1, 'rgba(0, 242, 254, 0.0)');
    drawLine(chartData.dl, '#00f2fe', dlGrad);

    // Upload gradient
    const ulGrad = ctx.createLinearGradient(0, 0, 0, height);
    ulGrad.addColorStop(0, 'rgba(192, 132, 252, 0.25)');
    ulGrad.addColorStop(1, 'rgba(192, 132, 252, 0.0)');
    drawLine(chartData.ul, '#c084fc', ulGrad);
  };

  // Ping & Jitter Test
  const testPingAndJitter = async () => {
    elStatus.textContent = 'ĐANG ĐO ĐỘ TRỄ (PING)...';
    elCardPing.classList.add('active');
    
    const count = 10;
    const pings = [];
    const pingUrl = ENDPOINTS[currentMode].ping;

    for (let i = 0; i < count; i++) {
      if (!isRunning) break;
      const tStart = performance.now();
      try {
        const sep = pingUrl.includes('?') ? '&' : '?';
        await fetch(`${pingUrl}${sep}_t=${Date.now()}_${i}`, {
          cache: 'no-store',
          mode: 'cors',
          signal: abortController.signal
        });
        const rtt = performance.now() - tStart;
        pings.push(rtt);
        elValPing.textContent = Math.round(rtt);
        await new Promise(r => setTimeout(r, 50));
      } catch (err) {
        if (err.name === 'AbortError') return null;
      }
    }

    elCardPing.classList.remove('active');
    if (pings.length === 0) return { ping: 0, jitter: 0 };

    // Discard outlier ping
    if (pings.length > 3) pings.sort((a, b) => a - b).pop();

    const minPing = Math.min(...pings);

    // Calculate jitter
    let jitterSum = 0;
    for (let i = 1; i < pings.length; i++) {
      jitterSum += Math.abs(pings[i] - pings[i - 1]);
    }
    const jitter = pings.length > 1 ? jitterSum / (pings.length - 1) : 0;

    elValPing.textContent = Math.round(minPing);
    elValJitter.textContent = jitter.toFixed(1);

    return { ping: minPing, jitter };
  };

  // Download Speed Test
  const testDownload = async () => {
    elStatus.textContent = currentMode === 'internet' 
      ? 'ĐANG TẢI INTERNET THỰC TẾ (DOWNLOAD)...' 
      : 'ĐANG TẢI VỀ TỪ MODEM (LAN DOWNLOAD)...';
    elCardDl.classList.add('active');

    const durationMs = config.duration * 1000;
    const startTime = performance.now();
    let totalBytes = 0;
    let lastTime = startTime;
    let lastBytes = 0;
    let currentSpeed = 0;

    chartData.dl = [];
    
    // Interval update for live Mbps & chart
    const timer = setInterval(() => {
      if (!isRunning) return;
      const now = performance.now();
      const deltaSec = (now - lastTime) / 1000;
      const deltaBytes = totalBytes - lastBytes;

      if (deltaSec >= 0.15) {
        const instantMbps = ((deltaBytes * 8) / (deltaSec * 1000000));
        currentSpeed = currentSpeed === 0 ? instantMbps : (currentSpeed * 0.65 + instantMbps * 0.35);
        
        elValDownload.textContent = currentSpeed.toFixed(1);
        updateGauge(currentSpeed);
        elBytesDl.textContent = (totalBytes / (1024 * 1024)).toFixed(1) + ' MB';

        chartData.dl.push(currentSpeed);
        drawChart();

        lastTime = now;
        lastBytes = totalBytes;
      }
    }, 150);

    // Single download XHR stream
    const runStreamXHR = (streamId) => {
      return new Promise((resolve) => {
        const fetchChunk = () => {
          if (!isRunning || (performance.now() - startTime >= durationMs)) {
            return resolve();
          }

          const xhr = new XMLHttpRequest();
          activeXHRs.push(xhr);
          let prevLoaded = 0;

          xhr.onprogress = (e) => {
            if (!isRunning) return;
            const diff = e.loaded - prevLoaded;
            if (diff > 0) {
              totalBytes += diff;
              prevLoaded = e.loaded;
            }
          };

          xhr.onload = xhr.onerror = () => {
            const idx = activeXHRs.indexOf(xhr);
            if (idx !== -1) activeXHRs.splice(idx, 1);
            if (isRunning && (performance.now() - startTime < durationMs)) {
              fetchChunk();
            } else {
              resolve();
            }
          };

          let url = '';
          if (currentMode === 'internet') {
            const bytesPerChunk = Math.min(config.dlChunkSize * 1000000, 50000000);
            url = `${ENDPOINTS.internet.download}?bytes=${bytesPerChunk}&_t=${Date.now()}_${Math.random()}&s=${streamId}`;
          } else {
            url = `${ENDPOINTS.lan.download}?size=${config.dlChunkSize}&_t=${Date.now()}_${Math.random()}&s=${streamId}`;
          }

          xhr.open('GET', url, true);
          xhr.responseType = 'blob';
          xhr.send();
        };

        fetchChunk();
      });
    };

    // Launch parallel streams
    const streamPromises = [];
    for (let i = 0; i < config.threads; i++) {
      streamPromises.push(runStreamXHR(i));
    }

    // Wait until duration expires
    await new Promise(resolve => {
      const checkEnd = setInterval(() => {
        if (!isRunning || (performance.now() - startTime >= durationMs)) {
          clearInterval(checkEnd);
          resolve();
        }
      }, 100);
    });

    clearInterval(timer);
    elCardDl.classList.remove('active');

    // Abort active download XHRs
    activeXHRs.forEach(xhr => {
      try { xhr.abort(); } catch(e){}
    });
    activeXHRs = [];

    // Final accurate calculation
    const elapsedSec = (performance.now() - startTime) / 1000;
    const finalSpeed = elapsedSec > 0 ? ((totalBytes * 8) / (elapsedSec * 1000000)) : 0;
    elValDownload.textContent = finalSpeed.toFixed(1);
    elBytesDl.textContent = (totalBytes / (1024 * 1024)).toFixed(1) + ' MB';
    return finalSpeed;
  };

  // Upload Speed Test
  const testUpload = async () => {
    elStatus.textContent = currentMode === 'internet'
      ? 'ĐANG TẢI LÊN INTERNET THỰC TẾ (UPLOAD)...'
      : 'ĐANG TẢI LÊN MODEM (LAN UPLOAD)...';
    elCardUl.classList.add('active');

    const durationMs = config.duration * 1000;
    const startTime = performance.now();
    let totalBytes = 0;
    let lastTime = startTime;
    let lastBytes = 0;
    let currentSpeed = 0;

    chartData.ul = [];

    // Pre-generate random upload chunk blob
    const chunkBytes = config.ulChunkSize * 1024 * 1024;
    const dummyBuffer = new Uint8Array(chunkBytes);
    for (let i = 0; i < dummyBuffer.length; i += 1024) {
      dummyBuffer[i] = (Math.random() * 255) | 0;
    }
    const uploadBlob = new Blob([dummyBuffer], { type: 'application/octet-stream' });

    // Update interval
    const timer = setInterval(() => {
      if (!isRunning) return;
      const now = performance.now();
      const deltaSec = (now - lastTime) / 1000;
      const deltaBytes = totalBytes - lastBytes;

      if (deltaSec >= 0.15) {
        const instantMbps = ((deltaBytes * 8) / (deltaSec * 1000000));
        currentSpeed = currentSpeed === 0 ? instantMbps : (currentSpeed * 0.65 + instantMbps * 0.35);

        elValUpload.textContent = currentSpeed.toFixed(1);
        updateGauge(currentSpeed);
        elBytesUl.textContent = (totalBytes / (1024 * 1024)).toFixed(1) + ' MB';

        chartData.ul.push(currentSpeed);
        drawChart();

        lastTime = now;
        lastBytes = totalBytes;
      }
    }, 150);

    // Single upload XHR stream
    const runStreamXHR = (streamId) => {
      return new Promise((resolve) => {
        const sendChunk = () => {
          if (!isRunning || (performance.now() - startTime >= durationMs)) {
            return resolve();
          }

          const xhr = new XMLHttpRequest();
          activeXHRs.push(xhr);
          let prevLoaded = 0;

          xhr.upload.onprogress = (e) => {
            if (!isRunning) return;
            const diff = e.loaded - prevLoaded;
            if (diff > 0) {
              totalBytes += diff;
              prevLoaded = e.loaded;
            }
          };

          xhr.onload = xhr.onerror = () => {
            const idx = activeXHRs.indexOf(xhr);
            if (idx !== -1) activeXHRs.splice(idx, 1);
            if (isRunning && (performance.now() - startTime < durationMs)) {
              sendChunk();
            } else {
              resolve();
            }
          };

          const uploadEndpoint = currentMode === 'internet' 
            ? `${ENDPOINTS.internet.upload}?_t=${Date.now()}_${Math.random()}&s=${streamId}`
            : `${ENDPOINTS.lan.upload}?_t=${Date.now()}&s=${streamId}`;

          xhr.open('POST', uploadEndpoint, true);
          xhr.setRequestHeader('Content-Type', 'application/octet-stream');
          xhr.send(uploadBlob);
        };

        sendChunk();
      });
    };

    const streamPromises = [];
    for (let i = 0; i < config.threads; i++) {
      streamPromises.push(runStreamXHR(i));
    }

    await new Promise(resolve => {
      const checkEnd = setInterval(() => {
        if (!isRunning || (performance.now() - startTime >= durationMs)) {
          clearInterval(checkEnd);
          resolve();
        }
      }, 100);
    });

    clearInterval(timer);
    elCardUl.classList.remove('active');

    // Abort active upload XHRs
    activeXHRs.forEach(xhr => {
      try { xhr.abort(); } catch(e){}
    });
    activeXHRs = [];

    const elapsedSec = (performance.now() - startTime) / 1000;
    const finalSpeed = elapsedSec > 0 ? ((totalBytes * 8) / (elapsedSec * 1000000)) : 0;
    elValUpload.textContent = finalSpeed.toFixed(1);
    elBytesUl.textContent = (totalBytes / (1024 * 1024)).toFixed(1) + ' MB';
    return finalSpeed;
  };

  // Main Speedtest Routine
  const startSpeedTest = async () => {
    if (isRunning) {
      stopSpeedTest();
      return;
    }

    isRunning = true;
    abortController = new AbortController();
    activeXHRs = [];

    elBtnStart.classList.add('running');
    elBtnText.textContent = 'DỪNG LẠI';
    elStatus.textContent = 'ĐANG KHỞI TẠO...';

    // Reset values
    elValPing.textContent = '--';
    elValJitter.textContent = '--';
    elValDownload.textContent = '0.0';
    elValUpload.textContent = '0.0';
    elBytesDl.textContent = '0 MB';
    elBytesUl.textContent = '0 MB';
    chartData = { dl: [], ul: [] };
    drawChart();
    updateGauge(0);

    try {
      // Step 1: Ping & Jitter
      const pingResult = await testPingAndJitter();
      if (!isRunning) return;

      // Small pause
      await new Promise(r => setTimeout(r, 300));
      if (!isRunning) return;

      // Step 2: Download
      const dlResult = await testDownload();
      if (!isRunning) return;

      // Small pause
      await new Promise(r => setTimeout(r, 300));
      if (!isRunning) return;

      // Step 3: Upload
      const ulResult = await testUpload();
      if (!isRunning) return;

      // Complete
      elStatus.textContent = 'HOÀN THÀNH!';
      updateGauge(dlResult);
      saveHistory({
        mode: currentMode === 'internet' ? 'Internet' : 'LAN',
        time: new Date().toLocaleTimeString(),
        ping: Math.round(pingResult?.ping || 0),
        jitter: pingResult?.jitter?.toFixed(1) || 0,
        dl: dlResult.toFixed(1),
        ul: ulResult.toFixed(1)
      });
    } catch (err) {
      console.error('Speedtest error:', err);
      elStatus.textContent = 'ĐÃ HỦY / LỖI';
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
    activeXHRs.forEach(xhr => {
      try { xhr.abort(); } catch(e){}
    });
    activeXHRs = [];
    elStatus.textContent = 'ĐÃ DỪNG';
    elBtnStart.classList.remove('running');
    elBtnText.textContent = 'BẮT ĐẦU';
  };

  // Save Result to LocalStorage History
  const saveHistory = (record) => {
    try {
      let history = JSON.parse(localStorage.getItem('openwrt_speedtest_history') || '[]');
      history.unshift(record);
      if (history.length > 20) history = history.slice(0, 20);
      localStorage.setItem('openwrt_speedtest_history', JSON.stringify(history));
      renderHistory();
    } catch(e){}
  };

  const renderHistory = () => {
    const box = document.getElementById('history-box');
    const tbody = document.getElementById('history-tbody');
    if (!box || !tbody) return;

    try {
      const history = JSON.parse(localStorage.getItem('openwrt_speedtest_history') || '[]');
      if (history.length === 0) {
        box.style.display = 'none';
        return;
      }

      box.style.display = 'block';
      tbody.innerHTML = history.map(h => `
        <tr>
          <td>${h.time} <span style="font-size:0.75rem; color:#64748b">(${h.mode || 'WAN'})</span></td>
          <td>${h.ping} ms</td>
          <td>${h.jitter} ms</td>
          <td class="val-cyan">${h.dl} Mbps</td>
          <td class="val-purple">${h.ul} Mbps</td>
        </tr>
      `).join('');
    } catch(e){}
  };

  // Fetch Public IP & ISP Info from Internet
  const fetchIspInfo = async () => {
    try {
      const res = await fetch('https://ipinfo.io/json', { cache: 'no-store' });
      if (res.ok) {
        const data = await res.json();
        if (data.ip) document.getElementById('client-ip').textContent = data.ip;
        if (data.org) document.getElementById('client-isp').textContent = data.org.replace(/^AS\d+\s*/, '');
        if (data.city) {
          const loc = `${data.city}, ${data.country || 'VN'}`;
          document.getElementById('client-city').textContent = loc;
          if (currentMode === 'internet') {
            elServerLocation.textContent = `Cloudflare Speed CDN (${loc})`;
          }
        }
      }
    } catch (e) {
      // Fallback: fetch from Cloudflare trace
      try {
        const res2 = await fetch('https://1.1.1.1/cdn-cgi/trace');
        if (res2.ok) {
          const text = await res2.text();
          const ipMatch = text.match(/ip=([^\n]+)/);
          const locMatch = text.match(/loc=([^\n]+)/);
          if (ipMatch) document.getElementById('client-ip').textContent = ipMatch[1];
          if (locMatch) document.getElementById('client-city').textContent = locMatch[1];
          document.getElementById('client-isp').textContent = 'Internet Provider';
        }
      } catch (err) {}
    }
  };

  // Fetch Router System Info
  const fetchSysInfo = async () => {
    try {
      const res = await fetch(CGI_SYSINFO, { cache: 'no-store' });
      if (!res.ok) throw new Error('Cannot fetch sysinfo');
      const data = await res.json();

      if (data.hostname) {
        document.getElementById('router-hostname').textContent = data.hostname;
      }
      if (data.model) {
        document.getElementById('sys-model').textContent = data.model;
      }
      if (data.os) {
        document.getElementById('sys-os').textContent = data.os;
      }
      if (data.cpu_model || data.temperature) {
        const cpuText = `${data.cpu_model || 'CPU'} (${data.cpu_cores || 1} Cores) • ${data.temperature || 'N/A'}`;
        document.getElementById('sys-cpu').textContent = cpuText;
      }
      if (data.mem_pct !== undefined) {
        const load = data.load ? `Load: ${data.load.split(',')[0]}` : '';
        document.getElementById('sys-ram').textContent = `RAM: ${data.mem_pct}% dùng • ${load}`;
      }
      if (data.uptime) {
        document.getElementById('sys-uptime').textContent = data.uptime;
      }
      if (currentMode === 'lan' && data.client_ip) {
        document.getElementById('client-ip').textContent = data.client_ip;
      }
    } catch(e) {
      console.warn('Sysinfo unavailable, using fallback stats');
      document.getElementById('sys-model').textContent = 'OpenWrt Gateway';
    }
  };

  // Switch Test Mode
  const setTestMode = (mode) => {
    if (isRunning) return;
    currentMode = mode;

    if (mode === 'internet') {
      pillInternet.classList.add('active');
      pillLan.classList.remove('active');
      elServerLocation.textContent = ENDPOINTS.internet.targetName;
      fetchIspInfo();
    } else {
      pillLan.classList.add('active');
      pillInternet.classList.remove('active');
      elServerLocation.textContent = ENDPOINTS.lan.targetName;
      document.getElementById('client-isp').textContent = 'Modem OpenWrt Localhost';
      document.getElementById('client-city').textContent = 'Mạng nội bộ LAN';
      fetchSysInfo();
    }
  };

  // Detect Client Browser Info
  const detectClientInfo = () => {
    const ua = navigator.userAgent;
    let browser = 'Modern Browser';
    if (ua.includes('Firefox')) browser = 'Mozilla Firefox';
    else if (ua.includes('Edg/')) browser = 'Microsoft Edge';
    else if (ua.includes('Chrome/')) browser = 'Google Chrome';
    else if (ua.includes('Safari/')) browser = 'Apple Safari';
    document.getElementById('client-browser').textContent = browser;
  };

  // Settings Modal Handlers
  const initSettings = () => {
    const modal = document.getElementById('modal-settings');
    const btnOpen = document.getElementById('btn-settings');
    const btnClose = document.getElementById('btn-close-settings');
    const btnSave = document.getElementById('btn-save-settings');

    const selThreads = document.getElementById('set-threads');
    const selDuration = document.getElementById('set-duration');
    const selDlSize = document.getElementById('set-dl-size');
    const selUlSize = document.getElementById('set-ul-size');

    // Populate current values
    selThreads.value = config.threads;
    selDuration.value = config.duration;
    selDlSize.value = config.dlChunkSize;
    selUlSize.value = config.ulChunkSize;

    btnOpen.addEventListener('click', () => modal.classList.add('open'));
    btnClose.addEventListener('click', () => modal.classList.remove('open'));
    modal.addEventListener('click', (e) => {
      if (e.target === modal) modal.classList.remove('open');
    });

    btnSave.addEventListener('click', () => {
      config.threads = parseInt(selThreads.value, 10) || 4;
      config.duration = parseInt(selDuration.value, 10) || 10;
      config.dlChunkSize = parseInt(selDlSize.value, 10) || 25;
      config.ulChunkSize = parseInt(selUlSize.value, 10) || 5;

      try {
        localStorage.setItem('openwrt_speedtest_cfg', JSON.stringify(config));
      } catch(e){}

      document.getElementById('client-streams').textContent = `${config.threads} luồng (${config.duration}s)`;
      modal.classList.remove('open');
    });

    document.getElementById('client-streams').textContent = `${config.threads} luồng (${config.duration}s)`;

    // Clear history button
    const btnClearHist = document.getElementById('btn-clear-history');
    if (btnClearHist) {
      btnClearHist.addEventListener('click', () => {
        localStorage.removeItem('openwrt_speedtest_history');
        renderHistory();
      });
    }
  };

  // Initialization
  window.addEventListener('DOMContentLoaded', () => {
    initTicks();
    drawChart();
    initSettings();
    detectClientInfo();
    fetchSysInfo();
    fetchIspInfo();
    renderHistory();

    // Mode Buttons
    pillInternet.addEventListener('click', () => setTestMode('internet'));
    pillLan.addEventListener('click', () => setTestMode('lan'));

    // Refresh sysinfo every 15s
    setInterval(fetchSysInfo, 15000);

    elBtnStart.addEventListener('click', startSpeedTest);
  });
})();
