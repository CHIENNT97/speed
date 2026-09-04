#!/bin/sh
# Download Test CGI - Stream dummy data without consuming disk space
printf "Content-Type: application/octet-stream\r\n"
printf "Cache-Control: no-store, no-cache, must-revalidate, max-age=0\r\n"
printf "Pragma: no-cache\r\n"
printf "Connection: keep-alive\r\n"

# Check size parameter (MB), default 25MB, max 500MB
SIZE=25
if [ -n "$QUERY_STRING" ]; then
    PARAM_SIZE=$(echo "$QUERY_STRING" | grep -o 'size=[0-9]*' | cut -d= -f2)
    if [ -n "$PARAM_SIZE" ] && [ "$PARAM_SIZE" -gt 0 ] && [ "$PARAM_SIZE" -le 500 ]; then
        SIZE=$PARAM_SIZE
    fi
fi

# Calculate chunk size (1MB blocks)
BYTES=$((SIZE * 1048576))
printf "Content-Length: %d\r\n\r\n" "$BYTES"

# Output zeros stream directly using dd from /dev/zero for maximum throughput and minimal CPU overhead
dd if=/dev/zero bs=65536 count=$((SIZE * 16)) 2>/dev/null
