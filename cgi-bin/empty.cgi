#!/bin/sh
# Ping / Jitter CGI - Returns empty 200 OK immediately
printf "Content-Type: text/plain\r\n"
printf "Cache-Control: no-store, no-cache, must-revalidate, max-age=0\r\n"
printf "Pragma: no-cache\r\n"
printf "Content-Length: 0\r\n\r\n"
