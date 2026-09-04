#!/bin/sh
# System Info CGI - Returns JSON of OpenWrt Router status
printf "Content-Type: application/json\r\n"
printf "Cache-Control: no-store, no-cache, must-revalidate, max-age=0\r\n"
printf "Access-Control-Allow-Origin: *\r\n\r\n"

# Hostname & Model
HOSTNAME=$(cat /proc/sys/kernel/hostname 2>/dev/null || uname -n)
MODEL=$(cat /tmp/sysinfo/model 2>/dev/null || cat /proc/cpuinfo | grep -i "machine\|model\|system type" | head -n1 | cut -d: -f2 | sed 's/^[ \t]*//')
[ -z "$MODEL" ] && MODEL=$(uname -m)

# OpenWrt OS release
OS_NAME="OpenWrt"
[ -f /etc/openwrt_release ] && . /etc/openwrt_release && OS_NAME="$DISTRIB_DESCRIPTION"

# Uptime
UPTIME_SEC=$(cut -d. -f1 /proc/uptime 2>/dev/null || echo 0)
DAYS=$((UPTIME_SEC / 86400))
HOURS=$(( (UPTIME_SEC % 86400) / 3600 ))
MINS=$(( (UPTIME_SEC % 3600) / 60 ))
UPTIME_STR="${DAYS}d ${HOURS}h ${MINS}m"

# CPU Load
LOAD=$(cat /proc/loadavg 2>/dev/null | awk '{print $1", "$2", "$3}')
[ -z "$LOAD" ] && LOAD="0.00, 0.00, 0.00"

# CPU Model & Cores
CPU_MODEL=$(cat /proc/cpuinfo 2>/dev/null | grep -E -i "model name|cpu model|Hardware|system type" | head -n1 | cut -d: -f2 | sed 's/^[ \t]*//')
[ -z "$CPU_MODEL" ] && CPU_MODEL=$(cat /tmp/sysinfo/board_name 2>/dev/null || uname -m)
CPU_CORES=$(grep -c "^processor" /proc/cpuinfo 2>/dev/null || echo 1)
[ "$CPU_CORES" -le 0 ] && CPU_CORES=1

# Memory
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

# Temperature (if sensor exists)
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

# Client Remote IP
CLIENT_IP="$REMOTE_ADDR"
[ -z "$CLIENT_IP" ] && CLIENT_IP="127.0.0.1"

# JSON Output (clean and escaped)
cat <<EOF
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
EOF
