FROM ghcr.io/cloudnative-pg/postgresql:17.2 as base

# Switch to root to install packages
USER root

# Install dependencies for building extensions
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
    && rm -rf /var/lib/apt/lists/*

# Add Citus repository
RUN curl -s https://install.citusdata.com/community/deb.sh | bash && \
    apt-get update

# Install the latest available Citus package for PostgreSQL 17
RUN CITUS_PACKAGE=$(apt-cache search postgresql-17-citus | grep -E 'postgresql-17-citus-[0-9]+\.[0-9]+' | sort -V | tail -n 1 | awk '{print $1}') && \
    if [ -z "$CITUS_PACKAGE" ]; then \
        echo "No Citus package found for PostgreSQL 17, trying alternative approach"; \
        CITUS_PACKAGE=$(apt-cache search postgresql-17-citus | head -n 1 | awk '{print $1}'); \
    fi && \
    if [ -n "$CITUS_PACKAGE" ]; then \
        echo "Installing Citus package: $CITUS_PACKAGE" && \
        apt-get install -y $CITUS_PACKAGE; \
    else \
        echo "No Citus package available for PostgreSQL 17"; \
    fi && \
    rm -rf /var/lib/apt/lists/*

# Add TimescaleDB repository
RUN echo "deb https://packagecloud.io/timescale/timescaledb/debian/ $(lsb_release -c -s) main" > /etc/apt/sources.list.d/timescaledb.list && \
    wget --quiet -O - https://packagecloud.io/timescale/timescaledb/gpgkey | gpg --dearmor > /etc/apt/trusted.gpg.d/timescaledb.gpg && \
    apt-get update

# Install TimescaleDB (find latest available version)
RUN TIMESCALEDB_PACKAGE=$(apt-cache search timescaledb-2-postgresql-17 | head -n 1 | awk '{print $1}') && \
    if [ -n "$TIMESCALEDB_PACKAGE" ]; then \
        echo "Installing TimescaleDB package: $TIMESCALEDB_PACKAGE" && \
        apt-get install -y $TIMESCALEDB_PACKAGE; \
    else \
        echo "No TimescaleDB package available for PostgreSQL 17"; \
    fi && \
    rm -rf /var/lib/apt/lists/*

# Install additional extensions (with fallback if not available)
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

# Install pg_hint_plan from source
WORKDIR /tmp
RUN git clone https://github.com/ossc-db/pg_hint_plan.git && \
    cd pg_hint_plan && \
    git checkout REL17_1_7_0 && \
    make USE_PGXS=1 && make USE_PGXS=1 install && \
    cd / && rm -rf /tmp/pg_hint_plan

# Clean up build dependencies
RUN apt-get remove -y \
    build-essential \
    postgresql-server-dev-17 \
    git \
    cmake \
    gnupg2 \
    && apt-get autoremove -y \
    && apt-get clean

# Create a script to dynamically configure shared_preload_libraries based on installed extensions
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

# Switch back to postgres user
USER 26

# Set labels
LABEL maintainer="Samuel Bartels <samuelbartels20@github.com>"
LABEL description="PostgreSQL 17.2 with CloudNative-PG, Citus, TimescaleDB and analytics extensions"
LABEL version="17.2-latest-cnpg"

# Expose PostgreSQL port
EXPOSE 5432

# Use the same entrypoint as the base CloudNative-PG image
ENTRYPOINT ["/manager"]