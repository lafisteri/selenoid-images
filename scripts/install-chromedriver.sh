#!/usr/bin/env bash
set -euxo pipefail

REQUESTED_VERSION="${1:-}"
TMP="$(mktemp -d)"
cd "$TMP"

CHROME_VERSION="$(google-chrome --version | awk '{print $3}')"
CHROME_MAJOR="${CHROME_VERSION%%.*}"

curl -fsSL https://googlechromelabs.github.io/chrome-for-testing/known-good-versions-with-downloads.json -o versions.json

if [ -n "${REQUESTED_VERSION}" ]; then
  DRIVER_VERSION="${REQUESTED_VERSION}"
  DRIVER_URL="$(
    jq -r --arg v "${DRIVER_VERSION}" \
      '.versions[] | select(.version==$v) | .downloads.chromedriver[] | select(.platform=="linux64") | .url' \
      versions.json
  )"
  test -n "${DRIVER_URL}"
else
  DRIVER_VERSION="$(
    jq -r --arg m "${CHROME_MAJOR}" \
      '.versions | map(select(.version | startswith($m+"."))) | map(.version) | last' \
      versions.json
  )"
  test -n "${DRIVER_VERSION}"
  DRIVER_URL="$(
    jq -r --arg v "${DRIVER_VERSION}" \
      '.versions[] | select(.version==$v) | .downloads.chromedriver[] | select(.platform=="linux64") | .url' \
      versions.json
  )"
fi

curl -fsSLO "${DRIVER_URL}"
unzip -q chromedriver-linux64.zip
install -m 0755 chromedriver-linux64/chromedriver /usr/bin/chromedriver

cd /
rm -rf "${TMP}"
