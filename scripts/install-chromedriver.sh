#!/usr/bin/env bash
set -euxo pipefail
VER="${1:?chromedriver version required}"
TMP="$(mktemp -d)"
cd "$TMP"
curl -fsSLO "https://storage.googleapis.com/chrome-for-testing-public/${VER}/linux64/chromedriver-linux64.zip"
unzip -q chromedriver-linux64.zip
install -m 0755 chromedriver-linux64/chromedriver /usr/bin/chromedriver
rm -rf "$TMP"
