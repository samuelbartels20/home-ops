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
    && rm -rf /var/lib/apt/lists/*

# Install Citus extension
ARG CITUS_VERSION=12.1
RUN curl -s https://install.citusdata.com/community/deb.sh | bash && \
    apt-get update && \
    apt-get install -y postgresql-17-citus-12.1 && \
    rm -rf /var/lib/apt/lists/*

# Install TimescaleDB
ARG TIMESCALEDB_VERSION=2.17.2
RUN echo "deb https://packagecloud.io/timescale/timescaledb/debian/ $(lsb_release -c -s) main" > /etc/apt/sources.list.d/timescaledb.list && \
    wget --quiet -O - https://packagecloud.io/timescale/timescaledb/gpgkey | apt-key add - && \
    apt-get update && \
    apt-get install -y timescaledb-2-postgresql-17 && \
    rm -rf /var/lib/apt/lists/*

# Install additional extensions
RUN apt-get update && apt-get install -y \
    postgresql-17-partman \
    postgresql-17-cron \
    postgresql-17-hypopg \
    postgresql-contrib-17 \
    && rm -rf /var/lib/apt/lists/*

# Install pg_hint_plan from source (not available in package repos for PG17)
WORKDIR /tmp
RUN git clone https://github.com/ossc-db/pg_hint_plan.git && \
    cd pg_hint_plan && \
    git checkout REL17_1_6_0 && \
    make && make install && \
    cd / && rm -rf /tmp/pg_hint_plan

# Clean up build dependencies but keep runtime dependencies
RUN apt-get remove -y \
    build-essential \
    postgresql-server-dev-17 \
    git \
    cmake \
    && apt-get autoremove -y \
    && apt-get clean

# Update shared_preload_libraries to include all necessary extensions
RUN echo "shared_preload_libraries = 'citus,timescaledb,pg_stat_statements,pg_hint_plan,pg_cron'" >> /usr/share/postgresql/17/postgresql.conf.sample

# Switch back to postgres user
USER 26

# Set labels
LABEL maintainer="Samuel Bartels <samuelbartels20@github.com>"
LABEL description="PostgreSQL 17.2 with CloudNative-PG, Citus, TimescaleDB and analytics extensions"
LABEL version="17.2-citus12.1-cnpg"

# Expose PostgreSQL port
EXPOSE 5432

# Use the same entrypoint as the base CloudNative-PG image
ENTRYPOINT ["/manager"]