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

# Add Citus repository and find available package
RUN curl -s https://install.citusdata.com/community/deb.sh | bash && \
    apt-get update

# Install the latest available Citus package for PostgreSQL 17
RUN CITUS_PACKAGE=$(apt-cache search postgresql-17-citus | grep -E 'postgresql-17-citus-[0-9]+\.[0-9]+' | head -n 1 | awk '{print $1}') && \
    echo "Installing Citus package: $CITUS_PACKAGE" && \
    apt-get install -y $CITUS_PACKAGE && \
    rm -rf /var/lib/apt/lists/*

# Add TimescaleDB repository
RUN echo "deb https://packagecloud.io/timescale/timescaledb/debian/ $(lsb_release -c -s) main" > /etc/apt/sources.list.d/timescaledb.list && \
    wget --quiet -O - https://packagecloud.io/timescale/timescaledb/gpgkey | gpg --dearmor > /etc/apt/trusted.gpg.d/timescaledb.gpg && \
    apt-get update

# Install TimescaleDB (find latest available version)
RUN TIMESCALEDB_PACKAGE=$(apt-cache search timescaledb-2-postgresql-17 | head -n 1 | awk '{print $1}') && \
    echo "Installing TimescaleDB package: $TIMESCALEDB_PACKAGE" && \
    apt-get install -y $TIMESCALEDB_PACKAGE && \
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
    git checkout REL17_1_6_0 && \
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

# Update shared_preload_libraries
RUN echo "shared_preload_libraries = 'citus,timescaledb,pg_stat_statements,pg_hint_plan,pg_cron'" >> /usr/share/postgresql/17/postgresql.conf.sample

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