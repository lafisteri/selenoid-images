ARG CHROME_VERSION
ARG CHROME_APT_PATTERN=""
ARG DRIVER_VERSION
ARG ENABLE_VNC=0
ARG LOCALE="en_US.UTF-8"
ARG TZ="UTC"

FROM golang:1.22-bullseye AS devtools-builder

WORKDIR /src/devtools

COPY devtools/go.mod .
COPY devtools/go.sum .
COPY devtools/*.go .

ENV GOPROXY=https://proxy.golang.org,direct \
    GO111MODULE=on

RUN go mod tidy -e && \
    go mod verify && \
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /out/devtools

FROM debian:bullseye-slim

ARG CHROME_VERSION
ARG CHROME_APT_PATTERN=""
ARG DRIVER_VERSION
ARG ENABLE_VNC=0
ARG LOCALE="en_US.UTF-8"
ARG TZ="UTC"

ENV DEBIAN_FRONTEND=noninteractive \
    TZ="${TZ}" \
    LANG="${LOCALE}" \
    LANGUAGE="${LOCALE}" \
    LC_ALL="${LOCALE}" \
    DISPLAY=:99 \
    CHROME_BIN=/usr/bin/google-chrome \
    CHROMEDRIVER=/usr/bin/chromedriver \
    DBUS_SESSION_BUS_ADDRESS=/dev/null

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
    ca-certificates curl unzip gnupg dumb-init jq locales tzdata \
    fonts-noto fonts-liberation fonts-dejavu-core \
    libnss3 libasound2 libxss1 libgbm1 libx11-xcb1 xvfb; \
    sed -i 's/# ru_UA.UTF-8/ru_UA.UTF-8/' /etc/locale.gen || true; \
    if [ "${LOCALE}" != "ru_UA.UTF-8" ]; then \
    sed -i "s/# ${LOCALE}/${LOCALE}/" /etc/locale.gen || true; \
    fi; \
    locale-gen; \
    rm -rf /var/lib/apt/lists/*

# Google Chrome: APT by pattern or exact .deb
RUN set -eux; \
    curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-linux.gpg; \
    echo "deb [signed-by=/usr/share/keyrings/google-linux.gpg arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" \
    > /etc/apt/sources.list.d/google-chrome.list; \
    apt-get update; \
    RESOLVED=""; \
    if [ -n "$CHROME_APT_PATTERN" ]; then \
    RESOLVED="$(apt-cache madison google-chrome-stable | awk '{print $3}' | grep -E "^${CHROME_APT_PATTERN}$" | head -n1 || true)"; \
    fi; \
    if [ -n "$RESOLVED" ]; then \
    echo "Installing google-chrome-stable=${RESOLVED} from APT"; \
    apt-get install -y --no-install-recommends google-chrome-stable="${RESOLVED}"; \
    else \
    echo "APT has no match; fetching exact .deb ${CHROME_VERSION}"; \
    curl -fSL "https://dl.google.com/linux/chrome/deb/pool/main/g/google-chrome-stable/google-chrome-stable_${CHROME_VERSION}_amd64.deb" -o /tmp/chrome.deb; \
    apt-get install -y --no-install-recommends /tmp/chrome.deb || (dpkg -i /tmp/chrome.deb || true && apt-get -f install -y); \
    rm -f /tmp/chrome.deb; \
    fi; \
    rm -rf /var/lib/apt/lists/*

# Chromedriver from Chrome-for-Testing
RUN set -eux; \
    CHROME_VERSION="$(google-chrome --version | awk '{print $3}')" ; \
    CHROME_MAJOR="${CHROME_VERSION%%.*}" ; \
    curl -fsSL https://googlechromelabs.github.io/chrome-for-testing/known-good-versions-with-downloads.json -o /tmp/versions.json; \
    if [ -n "${DRIVER_VERSION}" ]; then \
    echo "Using requested DRIVER_VERSION=${DRIVER_VERSION}"; \
    DRIVER_URL="$(jq -r --arg v "${DRIVER_VERSION}" \
    '.versions[] | select(.version==$v) | .downloads.chromedriver[] | select(.platform=="linux64") | .url' \
    /tmp/versions.json)"; \
    test -n "$DRIVER_URL"; \
    else \
    echo "Picking latest known-good for MAJOR=${CHROME_MAJOR}"; \
    DRIVER_VERSION="$(jq -r --arg m "$CHROME_MAJOR" \
    '.versions | map(select(.version | startswith($m+"."))) | map(.version) | last' \
    /tmp/versions.json)"; \
    test -n "$DRIVER_VERSION"; \
    DRIVER_URL="$(jq -r --arg v "$DRIVER_VERSION" \
    '.versions[] | select(.version==$v) | .downloads.chromedriver[] | select(.platform=="linux64") | .url' \
    /tmp/versions.json)"; \
    fi; \
    curl -fsSL -o /tmp/chromedriver.zip "$DRIVER_URL"; \
    unzip -q /tmp/chromedriver.zip -d /tmp; \
    install -m 0755 /tmp/chromedriver-linux64/chromedriver /usr/bin/chromedriver; \
    rm -rf /tmp/chromedriver.zip /tmp/chromedriver-linux64 /tmp/versions.json

# COPY static/policies.json /etc/opt/chrome/policies/managed/policies.json

# VNC stack (optional)
RUN set -eux; \
    if [ "$ENABLE_VNC" = "1" ]; then \
    apt-get update; \
    apt-get install -y --no-install-recommends x11vnc fluxbox websockify novnc; \
    rm -rf /var/lib/apt/lists/*; \
    fi

COPY --from=devtools-builder /out/devtools /usr/local/bin/devtools

RUN useradd -m -s /bin/bash selenium && \
    chown -R selenium:selenium /home/selenium /etc/opt/chrome || true

COPY scripts/entrypoint.sh /entrypoint.sh
COPY scripts/xvfb-start.sh /usr/local/bin/xvfb-start
RUN chmod +x /entrypoint.sh /usr/local/bin/xvfb-start

RUN cat >/usr/local/bin/start-with-devtools.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec /entrypoint.sh
EOF
RUN chmod +x /usr/local/bin/start-with-devtools.sh

USER selenium

EXPOSE 4444 5900 7900 7070

HEALTHCHECK --interval=20s --timeout=3s --retries=3 CMD curl -fsS http://127.0.0.1:4444/status || exit 1

ENTRYPOINT ["/usr/bin/dumb-init","--"]
CMD ["/usr/local/bin/start-with-devtools.sh"]
