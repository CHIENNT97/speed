#!/bin/sh
# Upload Test CGI - Consumes POST body to /dev/null
# Consume stdin (request body)
cat > /dev/null

printf "Content-Type: text/plain\r\n"
printf "Cache-Control: no-store, no-cache, must-revalidate, max-age=0\r\n"
printf "Pragma: no-cache\r\n"
printf "Connection: keep-alive\r\n\r\n"
printf "OK\n"
