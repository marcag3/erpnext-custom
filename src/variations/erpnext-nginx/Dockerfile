ARG PYTHON_VERSION=3.11.6
ARG DEBIAN_BASE=bookworm
FROM python:${PYTHON_VERSION}-slim-${DEBIAN_BASE} AS base

# Copy common scripts
COPY --chmod=755 src/common/usr/local/bin/ /usr/local/bin/

# Set default user and group IDs (linuxserver.io approach)
ARG PUID=1000
ARG PGID=1000

# Create frappe user and group with specified IDs
RUN groupadd -g ${PGID} frappe && useradd -u ${PUID} -g frappe -d /home/frappe -s /bin/bash frappe \
    && mkdir -p /home/frappe \
    && chown frappe:frappe /home/frappe

# Install base dependencies
RUN apt-get update \
    && apt-get install --no-install-recommends -y \
    curl \
    git \
    vim \
    nginx \
    gettext-base \
    execline \
    file \
    # weasyprint dependencies
    libpango-1.0-0 \
    libharfbuzz0b \
    libpangoft2-1.0-0 \
    libpangocairo-1.0-0 \
    # For backups
    restic \
    gpg \
    # MariaDB
    mariadb-client \
    less \
    # Postgres
    libpq-dev \
    postgresql-client \
    # For healthcheck
    wait-for-it \
    jq \
    # For S6 overlay installation
    xz-utils \
    # NodeJS - Install directly instead of using NVM for better system integration
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g yarn \
    # Create basic .bashrc for frappe user
    && echo 'export PATH="/usr/local/bin:$PATH"' >> /home/frappe/.bashrc \
    # Install wkhtmltopdf
    && if [ "$(uname -m)" = "aarch64" ]; then export ARCH=arm64; fi \
    && if [ "$(uname -m)" = "x86_64" ]; then export ARCH=amd64; fi \
    && downloaded_file=wkhtmltox_0.12.6.1-3.bookworm_${ARCH}.deb \
    && curl -sLO https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/${downloaded_file} \
    && apt-get install -y ./${downloaded_file} \
    && rm ${downloaded_file} \
    # Clean up
    && rm -rf /var/lib/apt/lists/* \
    && rm -fr /etc/nginx/sites-enabled/default \
    && pip3 install frappe-bench \
    # Fixes for non-root nginx and logs to stdout
    && sed -i '/user www-data/d' /etc/nginx/nginx.conf \
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log \
    && touch /run/nginx.pid \
    && chown -R frappe:frappe /etc/nginx/conf.d \
    && chown -R frappe:frappe /etc/nginx/nginx.conf \
    && chown -R frappe:frappe /var/log/nginx \
    && chown -R frappe:frappe /var/lib/nginx \
    && chown -R frappe:frappe /run/nginx.pid

##########
# S6 Build
##########
FROM base AS s6-build

ARG S6_DIR='/opt/s6/'
ARG S6_SRC_URL="https://github.com/just-containers/s6-overlay/releases/download"

# Install S6 Overlay
RUN docker-erpnext-s6-install

# Copy S6 service definitions
COPY --chmod=755 src/s6/ /etc/s6-overlay/

####################
# Builder Stage
####################
FROM base AS builder

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
    wget \
    libcairo2-dev \
    libpango1.0-dev \
    libjpeg-dev \
    libgif-dev \
    librsvg2-dev \
    libpq-dev \
    libffi-dev \
    liblcms2-dev \
    libldap2-dev \
    libmariadb-dev \
    libsasl2-dev \
    libtiff5-dev \
    libwebp-dev \
    redis-tools \
    rlwrap \
    tk8.6-dev \
    cron \
    gcc \
    build-essential \
    libbz2-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy apps.json to the container
COPY apps.json /opt/frappe/apps.json

USER frappe

ARG FRAPPE_BRANCH=version-15
ARG FRAPPE_PATH=https://github.com/frappe/frappe
RUN   bash -c "source /home/frappe/.bashrc && bench init --apps_path=/opt/frappe/apps.json\
    --frappe-branch=${FRAPPE_BRANCH} \
    --frappe-path=${FRAPPE_PATH} \
    --no-procfile \
    --no-backups \
    --skip-redis-config-generation \
    /home/frappe/frappe-bench" && \
  cd /home/frappe/frappe-bench && \
  find apps -mindepth 1 -path "*/.git" | xargs rm -fr

####################
# Final Stage
####################
FROM s6-build AS final

USER root

# Copy built frappe-bench from builder
COPY --from=builder --chown=frappe:frappe /home/frappe/frappe-bench /home/frappe/frappe-bench

# Copy apps.json to final stage for runtime initialization
COPY apps.json /opt/frappe/apps.json

# Copy S6 overlay from s6-build stage
# NOTE: This copies S6 binaries (init system, commands, etc.)
COPY --from=s6-build /opt/s6/ /

# Copy S6 service definitions from s6-build stage
# NOTE: This copies our custom services (nginx, gunicorn, websocket)
# The nested path is due to how we copy src/s6/ in the s6-build stage
COPY --from=s6-build /etc/s6-overlay/etc/s6-overlay/s6-rc.d /etc/s6-overlay/s6-rc.d

# Copy variation-specific files (but preserve S6 services)
COPY --chmod=755 src/variations/erpnext-nginx/etc/entrypoint.d/ /etc/entrypoint.d/
COPY --chmod=755 src/variations/erpnext-nginx/etc/nginx/ /etc/nginx/

# Set file permissions
RUN docker-erpnext-permissions

# Fix S6 Overlay issues
RUN chown -R frappe:frappe /run

USER frappe

WORKDIR /home/frappe/frappe-bench

VOLUME "/home/frappe/frappe-bench/sites/frontend"

EXPOSE 80

ENTRYPOINT ["docker-erpnext-entrypoint"]

# Set stop signal for graceful shutdown
STOPSIGNAL SIGQUIT

CMD ["/init"]

HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD [ "sh", "-c", "curl --silent --fail http://localhost:80 || exit 1" ]
