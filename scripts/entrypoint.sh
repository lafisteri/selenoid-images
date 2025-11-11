#!/usr/bin/env bash
set -euo pipefail

# Если есть VNC-стек — поднимем Xvfb/fluxbox/x11vnc
if command -v xvfb-start >/dev/null 2>&1; then
  /usr/local/bin/xvfb-start &
fi

/usr/bin/chromedriver \
  --port=4444 \
  --url-base=/ \
  --whitelisted-ips= \
  --allowed-ips= \
  --verbose \
  --log-path=/tmp/chromedriver.log \
  --allowed-origins='*' \
  --append-log \
  --headless=new \
  --disable-gpu \
  --no-sandbox \
  --disable-dev-shm-usage \
  --remote-allow-origins="*" &

wait -n
