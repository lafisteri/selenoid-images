#!/usr/bin/env bash
set -euo pipefail

if command -v xvfb-start >/dev/null 2>&1; then
  /usr/local/bin/xvfb-start &
fi

/usr/local/bin/devtools -listen :7070 &

chromedriver_args=(
  --port=4444
  --url-base=/
  --whitelisted-ips=
  --allowed-ips=
  --verbose
  --log-path=/tmp/chromedriver.log
  --allowed-origins='*'
  --append-log
  --disable-gpu
  --no-sandbox
  --disable-dev-shm-usage
  --remote-allow-origins="*"
)

if [[ "${ENABLE_VNC:-0}" != "1" ]]; then
  chromedriver_args+=(--headless=new)
fi

/usr/bin/chromedriver "${chromedriver_args[@]}" &

wait -n
