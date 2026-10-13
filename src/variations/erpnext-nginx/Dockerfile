ARG FRAPPE_BRANCH=version-16
ARG PYTHON_VERSION=3.11.6
ARG DEBIAN_BASE=bookworm

# Use pre-built frappe/build image for the builder stage
FROM frappe/build:${FRAPPE_BRANCH} AS builder

ARG FRAPPE_BRANCH=version-16
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
# APPS_REV (hash of the upstream branch HEADs) busts the cache when any app has new commits
ARG APPS_REV
RUN echo "apps revision: ${APPS_REV:-unset}" && export APP_INSTALL_ARGS="" && \
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
  mkdir -p sites/frontend && \
  find apps -mindepth 1 -path "*/.git" | xargs rm -fr && \
  # print_designer downloads Chromium into <bench>/chromium when it is installed on a
  # site, which would be lost whenever the container is recreated: bake it in instead
  if [ -d apps/print_designer ]; then \
    (cd sites && ../env/bin/python -c "from print_designer.install import find_or_download_chromium_executable as f; f()") && \
    test -n "$(find chromium -type f -name headless_shell)"; \
  fi && \
  chmod -R g=u .

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
    # Chromium (print_designer)
    libatk-bridge2.0-0t64 \
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
    && chown -R frappe:0 /etc/nginx/conf.d /etc/nginx/nginx.conf /var/log/nginx /var/lib/nginx /run/nginx.pid \
    && chmod -R g=u /etc/nginx/conf.d /etc/nginx/nginx.conf /var/log/nginx /var/lib/nginx /run/nginx.pid

##########
# S6 Build
##########
FROM base AS s6-build

ARG S6_DIR='/opt/s6/'
ARG S6_SRC_URL="https://github.com/just-containers/s6-overlay/releases/download"

# Install S6 Overlay
RUN docker-erpnext-s6-install

####################
# Final Stage
####################
FROM s6-build AS final

USER root

# Copy built frappe-bench from builder
COPY --from=builder --chown=frappe:0 /home/frappe/frappe-bench /home/frappe/frappe-bench

# Copy apps.json to final stage for runtime initialization
COPY apps.json /opt/frappe/apps.json

# Copy S6 overlay from s6-build stage
# NOTE: This copies S6 binaries (init system, commands, etc.)
COPY --from=s6-build /opt/s6/ /

# Copy our S6 services (nginx, gunicorn, websocket) on top of the overlay. The user
# bundle lives in user-bundles.d because, unlike a bundle in s6-rc.d, it needs no
# write access to /etc at startup, so s6 can run as frappe
COPY --chmod=755 src/s6/etc/s6-overlay/ /etc/s6-overlay/

# Copy variation-specific files (but preserve S6 services)
COPY --chmod=755 src/variations/erpnext-nginx/etc/entrypoint.d/ /etc/entrypoint.d/
COPY --chmod=755 src/variations/erpnext-nginx/etc/nginx/ /etc/nginx/

# s6-overlay keeps its state in /run; HOME must be group-writable for the caches of
# yarn/pip/etc. when the uid is not frappe's
RUN chown -R frappe:0 /run && chmod g=u /home/frappe

# Same model as upstream frappe_docker: unprivileged frappe (uid 1000, gid 0),
# group-writable files, so any uid in group 0 can run the image
USER frappe
# A uid that is not frappe's (e.g. compose `user: "1234:0"`) has no /etc/passwd entry:
# Python then fails to look the user up unless $USER is set, and Docker sets HOME=/
ENV USER=frappe HOME=/home/frappe

WORKDIR /home/frappe/frappe-bench

VOLUME "/home/frappe/frappe-bench/sites/frontend"

EXPOSE 8080

ENTRYPOINT ["docker-erpnext-entrypoint"]

# Set stop signal for graceful shutdown
STOPSIGNAL SIGQUIT

CMD ["/init"]

# nginx only starts once the init script (site creation / migrate) is done, which takes minutes
HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=10m \
    CMD [ "sh", "-c", "curl --silent --fail http://localhost:8080 || exit 1" ]
