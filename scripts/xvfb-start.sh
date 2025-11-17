#!/usr/bin/env bash
set -euo pipefail

pids=()

cleanup() {
  for pid in "${pids[@]}"; do
    if kill "${pid}" >/dev/null 2>&1; then
      :
    fi
  done
  wait || true
}

trap cleanup INT TERM

Xvfb :99 -screen 0 1920x1080x24 -ac +extension RANDR +render -noreset &>/tmp/xvfb.log &
pids+=("$!")
sleep 0.5

fluxbox &>/tmp/fluxbox.log &
pids+=("$!")

x11vnc -display :99 -nopw -forever -rfbport 5900 -shared -o /tmp/x11vnc.log &
pids+=("$!")

if [ -d /usr/share/novnc ]; then
  websockify --web=/usr/share/novnc/ 7900 localhost:5900 &>/tmp/novnc.log &
  pids+=("$!")
fi

wait
