# syntax=docker/dockerfile:1.7

FROM --platform=linux/amd64 ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG AUTOPSY_VERSION=4.23.0
ARG AUTOPSY_ZIP=
ARG SLEUTHKIT_VERSION=4.15.0

ENV AUTOPSY_HOME=/opt/autopsy \
    JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
    ant \
    ant-optional \
    autoconf \
    autoconf-archive \
    automake \
    build-essential \
    ca-certificates \
    curl \
    dbus-x11 \
    fluxbox \
    fonts-dejavu \
    gosu \
    libafflib-dev \
    libasound2t64 \
    libde265-dev \
    libewf-dev \
    libfreetype6 \
    libgbm1 \
    libgl1 \
    libglu1-mesa \
    libgtk-3-0 \
    libheif-dev \
    libnss3 \
    libpq-dev \
    libsqlite3-dev \
    libtool \
    libvhdi-dev \
    libvmdk-dev \
    libxcursor1 \
    libxi6 \
    libxinerama1 \
    libxrandr2 \
    libxrender1 \
    libxt6 \
    libxtst6 \
    novnc \
    openjdk-17-jdk \
    pkg-config \
    procps \
    python3 \
    python3-websockify \
    testdisk \
    unzip \
    x11vnc \
    xauth \
    x11-utils \
    xvfb \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --system autopsy \
    && useradd --system --create-home --home-dir /home/autopsy --gid autopsy --shell /bin/bash autopsy \
    && mkdir -p /cases /config /evidence /downloads /tmp/runtime-autopsy \
    && chown -R autopsy:autopsy /cases /config /evidence /downloads /tmp/runtime-autopsy /home/autopsy

WORKDIR /tmp

RUN curl -fsSL -o sleuthkit.tar.gz "https://github.com/sleuthkit/sleuthkit/releases/download/sleuthkit-${SLEUTHKIT_VERSION}/sleuthkit-${SLEUTHKIT_VERSION}.tar.gz" \
    && tar -xzf sleuthkit.tar.gz \
    && cd "sleuthkit-${SLEUTHKIT_VERSION}" \
    && ./configure --enable-java \
    && make -j"$(nproc)" \
    && make install \
    && ldconfig \
    && rm -rf /tmp/sleuthkit*

COPY release/ /tmp/release/

RUN set -eux; \
    autopsy_zip=""; \
    if [ -n "${AUTOPSY_ZIP}" ] && [ -f "/tmp/${AUTOPSY_ZIP}" ]; then \
        autopsy_zip="/tmp/${AUTOPSY_ZIP}"; \
    else \
        autopsy_zip="$(find /tmp/release -maxdepth 1 -type f -name 'autopsy-*.zip' | sort | head -n 1 || true)"; \
    fi; \
    if [ -z "${autopsy_zip}" ]; then \
        autopsy_url="$(python3 -c "import json, urllib.request; data = json.load(urllib.request.urlopen('https://api.github.com/repos/sleuthkit/autopsy/releases/latest')); assets = [a['browser_download_url'] for a in data.get('assets', []) if a.get('name', '').startswith('autopsy-') and a.get('name', '').endswith('.zip')]; print(assets[0] if assets else '', end='')")"; \
        test -n "${autopsy_url}"; \
        autopsy_zip="/tmp/autopsy-latest.zip"; \
        curl -fsSL -o "${autopsy_zip}" "${autopsy_url}"; \
    fi; \
    unzip -q "${autopsy_zip}" -d /opt; \
    autopsy_root="$(unzip -Z1 "${autopsy_zip}" | head -n 1 | cut -d/ -f1)"; \
    test -n "${autopsy_root}"; \
    mv "/opt/${autopsy_root}" "${AUTOPSY_HOME}" \
    && chmod +x "${AUTOPSY_HOME}/unix_setup.sh" \
    && cd "${AUTOPSY_HOME}" \
    && ./unix_setup.sh -j "${JAVA_HOME}" -n autopsy \
    && rm -rf /tmp/release /tmp/autopsy-latest.zip

COPY docker/entrypoint.sh /usr/local/bin/autopsy-entrypoint
COPY docker/novnc-index.html /usr/share/novnc/index.html

RUN chmod 755 /usr/local/bin/autopsy-entrypoint

WORKDIR /cases

EXPOSE 5900 6080

ENTRYPOINT ["/usr/local/bin/autopsy-entrypoint"]
