#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="${VNC_LOG_FILE:-/var/log/vnc-stack.log}"

mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

if [ "${DEBUG_VNC:-0}" = "1" ]; then
  set -x
  echo "[VNC] DEBUG_VNC=1" >>"$LOG_FILE"
fi

pids=()

cleanup() {
  echo "[VNC] cleanup" >>"$LOG_FILE"
  for pid in "${pids[@]}"; do
    if kill "$pid" >/dev/null 2>&1; then
      echo "[VNC] killed pid ${pid}" >>"$LOG_FILE"
    fi
  done
  wait || true
}

trap cleanup INT TERM

echo "[VNC] starting Xvfb" >>"$LOG_FILE"
Xvfb :99 -screen 0 1920x1080x24 -ac +extension RANDR +render -noreset >>"$LOG_FILE" 2>&1 &
pids+=("$!")
sleep 0.5

echo "[VNC] starting fluxbox" >>"$LOG_FILE"
fluxbox >>"$LOG_FILE" 2>&1 &
pids+=("$!")

echo "[VNC] starting x11vnc" >>"$LOG_FILE"
x11vnc -display :99 -nopw -forever -rfbport 5900 -shared >>"$LOG_FILE" 2>&1 &
pids+=("$!")

if [ -d /usr/share/novnc ]; then
  echo "[VNC] starting websockify/novnc" >>"$LOG_FILE"
  websockify --web=/usr/share/novnc/ 7900 localhost:5900 >>"$LOG_FILE" 2>&1 &
  pids+=("$!")
fi

echo "[VNC] stack started" >>"$LOG_FILE"

wait
