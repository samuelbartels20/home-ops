FROM ghcr.io/cloudnative-pg/postgresql:17.2 AS base

ARG IMAGE_VERSION=1.0.0
ARG BUILD_DATE=2025-08-01T20:49:47Z
ARG VCS_REF
ARG TARGETARCH

USER root

ENV DEBIAN_FRONTEND=noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN=true

# Build deps for extensions
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

# Citus (install only on amd64, via official Debian repo)
RUN if [ "$TARGETARCH" = "amd64" ]; then \
      curl -s https://install.citusdata.com/community/deb.sh | bash && \
      apt-get update && \
      CITUS_PACKAGE=$(apt-cache search postgresql-17-citus | grep -E 'postgresql-17-citus-[0-9]+\.[0-9]+' | sort -V | tail -n 1 | awk '{print $1}') && \
      if [ -z "$CITUS_PACKAGE" ]; then \
        CITUS_PACKAGE=$(apt-cache search postgresql-17-citus | head -n 1 | awk '{print $1}'); \
      fi && \
      if [ -n "$CITUS_PACKAGE" ]; then \
        echo "Installing Citus package: $CITUS_PACKAGE" && apt-get install -y "$CITUS_PACKAGE"; \
      else \
        echo "No Citus package available for PostgreSQL 17"; \
      fi && \
      rm -rf /var/lib/apt/lists/*; \
    else \
      echo "Skipping Citus installation for architecture: $TARGETARCH"; \
    fi

# TimescaleDB
RUN echo "deb https://packagecloud.io/timescale/timescaledb/debian/ $(lsb_release -c -s) main" > /etc/apt/sources.list.d/timescaledb.list && \
    wget --quiet -O - https://packagecloud.io/timescale/timescaledb/gpgkey | gpg --dearmor > /etc/apt/trusted.gpg.d/timescaledb.gpg && \
    apt-get update
RUN TIMESCALEDB_PACKAGE=$(apt-cache search timescaledb-2-postgresql-17 | head -n 1 | awk '{print $1}') && \
    if [ -n "$TIMESCALEDB_PACKAGE" ]; then \
      echo "Installing TimescaleDB package: $TIMESCALEDB_PACKAGE" && apt-get install -y "$TIMESCALEDB_PACKAGE"; \
    else \
      echo "No TimescaleDB package available for PostgreSQL 17"; \
    fi && \
    rm -rf /var/lib/apt/lists/*

# Extra extensions with fallback
RUN apt-get update && \
    for pkg in postgresql-17-partman postgresql-17-cron postgresql-17-hypopg postgresql-contrib-17; do \
      if apt-cache show "$pkg" > /dev/null 2>&1; then \
        echo "Installing $pkg"; apt-get install -y "$pkg"; \
      else \
        echo "Package $pkg not available, skipping"; \
      fi; \
    done && \
    rm -rf /var/lib/apt/lists/*

# pg_hint_plan from source (PG17 tag)
WORKDIR /tmp
RUN git clone https://github.com/ossc-db/pg_hint_plan.git && \
    cd pg_hint_plan && \
    git checkout REL17_1_7_0 && \
    make USE_PGXS=1 && make USE_PGXS=1 install && \
    cd / && rm -rf /tmp/pg_hint_plan

# Clean build deps
RUN apt-get remove -y \
      build-essential \
      postgresql-server-dev-17 \
      git \
      cmake \
      gnupg2 \
    && apt-get autoremove -y \
    && apt-get clean

# Generate shared_preload_libraries based on installed SOs
RUN echo '#!/bin/bash' > /usr/local/bin/configure-extensions.sh && \
    echo 'EXTENSIONS=""' >> /usr/local/bin/configure-extensions.sh && \
    echo 'if [ -f /usr/lib/postgresql/17/lib/citus.so ]; then EXTENSIONS="${EXTENSIONS},citus"; fi' >> /usr/local/bin/configure-extensions.sh && \
    echo 'if [ -f /usr/lib/postgresql/17/lib/timescaledb.so ]; then EXTENSIONS="${EXTENSIONS},timescaledb"; fi' >> /usr/local/bin/configure-extensions.sh && \
    echo 'EXTENSIONS="${EXTENSIONS},pg_stat_statements"' >> /usr/local/bin/configure-extensions.sh && \
    echo 'if [ -f /usr/lib/postgresql/17/lib/pg_hint_plan.so ]; then EXTENSIONS="${EXTENSIONS},pg_hint_plan"; fi' >> /usr/local/bin/configure-extensions.sh && \
    echo 'if [ -f /usr/lib/postgresql/17/lib/pg_cron.so ]; then EXTENSIONS="${EXTENSIONS},pg_cron"; fi' >> /usr/local/bin/configure-extensions.sh && \
    echo 'EXTENSIONS=$(echo $EXTENSIONS | sed "s/^,//")'  >> /usr/local/bin/configure-extensions.sh && \
    echo 'echo "shared_preload_libraries = '\''$EXTENSIONS'\''" >> /usr/share/postgresql/17/postgresql.conf.sample' >> /usr/local/bin/configure-extensions.sh && \
    chmod +x /usr/local/bin/configure-extensions.sh && \
    /usr/local/bin/configure-extensions.sh

USER 26

# Labels
LABEL maintainer="Samuel Bartels <samuelbartels20@github.com>"
LABEL description="PostgreSQL 17.x with CloudNative-PG, Citus (amd64), TimescaleDB and other extensions"
LABEL version="${IMAGE_VERSION}"
LABEL org.opencontainers.image.version="${IMAGE_VERSION}"
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.source="https://github.com/samuelbartels20/postgres-extended"
LABEL org.opencontainers.image.revision="${VCS_REF}"
LABEL org.opencontainers.image.vendor="Samuel Bartels"
LABEL org.opencontainers.image.title="PostgreSQL Extended"
LABEL org.opencontainers.image.description="PostgreSQL 17.x with CloudNative-PG, Citus (amd64), TimescaleDB and analytics extensions"
LABEL org.opencontainers.image.authors="Samuel Bartels <samuelbartels20@github.com>"
LABEL org.opencontainers.image.licenses="MIT"
LABEL postgres.version="17"
LABEL base.image="ghcr.io/cloudnative-pg/postgresql:17.2"
LABEL extensions.citus="conditional-amd64"
LABEL extensions.timescaledb="included"
LABEL extensions.pg_hint_plan="REL17_1_7_0"
LABEL extensions.additional="partman,cron,hypopg,contrib"

EXPOSE 5432

# IMPORTANT: keep CNPG entrypoint
ENTRYPOINT ["/manager"]