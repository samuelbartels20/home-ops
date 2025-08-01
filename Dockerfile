# syntax=docker/dockerfile:1.4

FROM ghcr.io/cloudnative-pg/postgresql:17.2 AS base

USER root

ARG TARGETARCH
ARG CITUS_VERSION=12.1.3
ARG TIMESCALEDB_VERSION=2.14.2
ARG HINT_PLAN_TAG=REL17_1_7_0

ENV DEBIAN_FRONTEND=noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN=true

# Install build tools and base dev packages
RUN apt-get update && apt-get install -y \
    build-essential \
    postgresql-server-dev-17 \
    libcurl4-openssl-dev \
    libssl-dev \
    libkrb5-dev \
    libicu-dev \
    pkg-config \
    cmake \
    git \
    curl \
    wget \
    ca-certificates \
    lsb-release \
    gnupg2 \
    flex \
    bison \
    liblz4-1 \
    liblz4-dev \
    libzstd-dev \
    libzstd1 \
    && rm -rf /var/lib/apt/lists/*

# Install Citus (amd64 only)
RUN if [ "$TARGETARCH" = "amd64" ]; then \
      curl -s https://install.citusdata.com/community/deb.sh | bash && \
      apt-get update && \
      apt-get install -y postgresql-17-citus-${CITUS_VERSION} && \
      rm -rf /var/lib/apt/lists/*; \
    else \
      echo "Skipping Citus installation for arch: $TARGETARCH"; \
    fi

# Add and install pinned TimescaleDB
RUN echo "deb https://packagecloud.io/timescale/timescaledb/debian/ $(lsb_release -c -s) main" > /etc/apt/sources.list.d/timescaledb.list && \
    wget --quiet -O - https://packagecloud.io/timescale/timescaledb/gpgkey | gpg --dearmor > /etc/apt/trusted.gpg.d/timescaledb.gpg && \
    apt-get update && \
    apt-get install -y timescaledb-2-postgresql-17=${TIMESCALEDB_VERSION}* && \
    rm -rf /var/lib/apt/lists/*

# Install additional extensions
RUN apt-get update && \
    for pkg in postgresql-17-partman postgresql-17-cron postgresql-17-hypopg postgresql-contrib-17; do \
        if apt-cache show $pkg > /dev/null 2>&1; then \
            echo "Installing $pkg"; \
            apt-get install -y $pkg; \
        else \
            echo "Package $pkg not available, skipping"; \
        fi; \
    done && \
    rm -rf /var/lib/apt/lists/*

# Build and install pg_hint_plan from source (tagged)
WORKDIR /tmp
RUN git clone https://github.com/ossc-db/pg_hint_plan.git && \
    cd pg_hint_plan && \
    git checkout ${HINT_PLAN_TAG} && \
    make USE_PGXS=1 && make USE_PGXS=1 install && \
    cd / && rm -rf /tmp/pg_hint_plan

# Remove build dependencies
RUN apt-get purge -y \
    build-essential \
    postgresql-server-dev-17 \
    git \
    cmake \
    gnupg2 && \
    apt-get autoremove -y && apt-get clean

# Create extension preload config script
RUN echo '#!/bin/bash' > /usr/local/bin/configure-extensions.sh && \
    echo 'EXTENSIONS=""' >> /usr/local/bin/configure-extensions.sh && \
    echo 'if [ -f /usr/lib/postgresql/17/lib/citus.so ]; then EXTENSIONS="${EXTENSIONS},citus"; fi' >> /usr/local/bin/configure-extensions.sh && \
    echo 'if [ -f /usr/lib/postgresql/17/lib/timescaledb.so ]; then EXTENSIONS="${EXTENSIONS},timescaledb"; fi' >> /usr/local/bin/configure-extensions.sh && \
    echo 'EXTENSIONS="${EXTENSIONS},pg_stat_statements"' >> /usr/local/bin/configure-extensions.sh && \
    echo 'if [ -f /usr/lib/postgresql/17/lib/pg_hint_plan.so ]; then EXTENSIONS="${EXTENSIONS},pg_hint_plan"; fi' >> /usr/local/bin/configure-extensions.sh && \
    echo 'if [ -f /usr/lib/postgresql/17/lib/pg_cron.so ]; then EXTENSIONS="${EXTENSIONS},pg_cron"; fi' >> /usr/local/bin/configure-extensions.sh && \
    echo 'EXTENSIONS=$(echo $EXTENSIONS | sed "s/^,//")' >> /usr/local/bin/configure-extensions.sh && \
    echo 'echo "shared_preload_libraries = '\''$EXTENSIONS'\''" >> /usr/share/postgresql/17/postgresql.conf.sample' >> /usr/local/bin/configure-extensions.sh && \
    chmod +x /usr/local/bin/configure-extensions.sh && \
    /usr/local/bin/configure-extensions.sh

USER 26

# SemVer-compatible labels
LABEL org.opencontainers.image.authors="Samuel Bartels <samuelbartels20@github.com>"
LABEL org.opencontainers.image.version="17.2.0"
LABEL org.opencontainers.image.description="PostgreSQL 17.2.0 with CNPG, Citus ${CITUS_VERSION}, TimescaleDB ${TIMESCALEDB_VERSION}, pg_hint_plan ${HINT_PLAN_TAG}"

EXPOSE 5432

CMD ["postgres"]
