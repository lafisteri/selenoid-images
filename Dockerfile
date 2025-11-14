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
    DBUS_SESSION_BUS_ADDRESS=/dev/null \
    ENABLE_VNC="${ENABLE_VNC}"

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      ca-certificates curl unzip gnupg dumb-init jq locales tzdata \
      fonts-noto fonts-liberation fonts-dejavu-core \
      libnss3 libasound2 libxss1 libgbm1 libx11-xcb1 xvfb; \
    # enable requested locale
    if ! grep -Eq "^${LOCALE}[[:space:]]+UTF-8" /etc/locale.gen; then \
      echo "${LOCALE} UTF-8" >> /etc/locale.gen; \
    fi; \
    locale-gen; \
    rm -rf /var/lib/apt/lists/*

COPY scripts/install-chrome.sh /usr/local/bin/install-chrome
RUN chmod +x /usr/local/bin/install-chrome && \
    CHROME_VERSION="${CHROME_VERSION}" \
    CHROME_APT_PATTERN="${CHROME_APT_PATTERN}" \
    /usr/local/bin/install-chrome && \
    rm -rf /var/lib/apt/lists/*

COPY scripts/install-chromedriver.sh /usr/local/bin/install-chromedriver
RUN chmod +x /usr/local/bin/install-chromedriver && \
    /usr/local/bin/install-chromedriver "${DRIVER_VERSION}"

# COPY static/policies.json /etc/opt/chrome/policies/managed/policies.json

RUN set -eux; \
    if [ "${ENABLE_VNC}" = "1" ]; then \
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
