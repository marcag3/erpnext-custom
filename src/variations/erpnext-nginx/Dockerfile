ARG FRAPPE_BRANCH=version-15
ARG PYTHON_VERSION=3.11.6
ARG DEBIAN_BASE=bookworm

# Use pre-built frappe/build image for the builder stage
FROM frappe/build:${FRAPPE_BRANCH} AS builder

ARG FRAPPE_BRANCH=version-15
ARG FRAPPE_PATH=https://github.com/frappe/frappe
ARG APPS_JSON_BASE64

USER root

# Handle apps.json if provided via base64
RUN if [ -n "${APPS_JSON_BASE64}" ]; then \
    mkdir -p /opt/frappe && echo "${APPS_JSON_BASE64}" | base64 -d > /opt/frappe/apps.json; \
  fi

# Copy apps.json from build context if not provided via base64
COPY apps.json /opt/frappe/apps.json

USER frappe

# Initialize frappe-bench with apps
RUN export APP_INSTALL_ARGS="" && \
  if [ -f "/opt/frappe/apps.json" ]; then \
    export APP_INSTALL_ARGS="--apps_path=/opt/frappe/apps.json"; \
  fi && \
  bench init ${APP_INSTALL_ARGS}\
    --frappe-branch=${FRAPPE_BRANCH} \
    --frappe-path=${FRAPPE_PATH} \
    --no-procfile \
    --no-backups \
    --skip-assets \
    --skip-redis-config-generation \
    --verbose \
    /home/frappe/frappe-bench && \
  cd /home/frappe/frappe-bench && \
  echo "{}" > sites/common_site_config.json && \
  find apps -mindepth 1 -path "*/.git" | xargs rm -fr

# Use pre-built frappe/base image for the runtime
FROM frappe/base:${FRAPPE_BRANCH} AS base

# Copy common scripts
COPY --chmod=755 src/common/usr/local/bin/ /usr/local/bin/

# Install additional packages needed for nginx and S6
USER root
RUN apt-get update \
    && apt-get install --no-install-recommends -y \
    nginx \
    gettext-base \
    execline \
    # weasyprint dependencies (if not already in frappe/base)
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
