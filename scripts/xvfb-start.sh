#!/usr/bin/env bash
set -euo pipefail

Xvfb :99 -screen 0 1920x1080x24 -ac +extension RANDR +render -noreset &>/tmp/xvfb.log &
sleep 0.5

fluxbox &>/tmp/fluxbox.log &
x11vnc -display :99 -nopw -forever -rfbport 5900 -shared -o /tmp/x11vnc.log &

if [ -d /usr/share/novnc ]; then
  websockify --web=/usr/share/novnc/ 7900 localhost:5900 &>/tmp/novnc.log &
fi

wait
