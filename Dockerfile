# Универсальный Dockerfile: собирает и обычный chrome, и vnc_chrome по флагу ENABLE_VNC
FROM debian:bullseye-slim

# --- build args ---
# CHROME_VERSION: точная версия deb-пакета, например 142.0.7444.61-1
# CHROME_APT_PATTERN: паттерн для apt (например 142.*). Если найдётся — ставим из APT; иначе качаем .deb.
# DRIVER_VERSION: версия chromedriver, например 142.0.7444.61
# ENABLE_VNC: 0 (по умолчанию) или 1 — включить x11vnc/fluxbox/noVNC
ARG CHROME_VERSION
ARG CHROME_APT_PATTERN=""
ARG DRIVER_VERSION
ARG ENABLE_VNC=0

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Europe/Kyiv \
    LANG=ru_UA.UTF-8 \
    LANGUAGE=ru_UA:ru:en \
    LC_ALL=ru_UA.UTF-8 \
    DISPLAY=:99 \
    CHROME_BIN=/usr/bin/google-chrome \
    CHROMEDRIVER=/usr/bin/chromedriver \
    DBUS_SESSION_BUS_ADDRESS=/dev/null

# Базовые пакеты, локали, шрифты
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
    ca-certificates curl unzip gnupg dumb-init jq locales tzdata \
    fonts-noto fonts-liberation fonts-dejavu-core \
    libnss3 libasound2 libxss1 libgbm1 libx11-xcb1 xvfb; \
    sed -i 's/# ru_UA.UTF-8/ru_UA.UTF-8/' /etc/locale.gen; \
    locale-gen; \
    rm -rf /var/lib/apt/lists/*

# Chrome: сначала пытаемся через APT по паттерну (например 142.*), иначе — точный .deb из pool
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

# Установка chromedriver
COPY scripts/install-chromedriver.sh /usr/local/bin/install-chromedriver
RUN chmod +x /usr/local/bin/install-chromedriver && /usr/local/bin/install-chromedriver "${DRIVER_VERSION}"

# (опционально) Корпоративные политики — раскомментируйте, если файл есть в репо
# COPY static/policies.json /etc/opt/chrome/policies/managed/policies.json

# VNC-стек ставим только при ENABLE_VNC=1
RUN set -eux; \
    if [ "$ENABLE_VNC" = "1" ]; then \
    apt-get update; \
    apt-get install -y --no-install-recommends x11vnc fluxbox websockify novnc; \
    rm -rf /var/lib/apt/lists/*; \
    fi

# Пользователь
RUN useradd -m -s /bin/bash selenium && chown -R selenium:selenium /home/selenium /etc/opt/chrome || true

# Скрипты запуска
COPY scripts/entrypoint.sh /entrypoint.sh
COPY scripts/xvfb-start.sh /usr/local/bin/xvfb-start
RUN chmod +x /entrypoint.sh /usr/local/bin/xvfb-start

USER selenium
EXPOSE 4444 5900 7900
HEALTHCHECK --interval=20s --timeout=3s --retries=3 CMD curl -fsS http://127.0.0.1:4444/status || exit 1
ENTRYPOINT ["/usr/bin/dumb-init","--"]
CMD ["/entrypoint.sh"]
