# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A custom ERPNext/Frappe Docker image: one "web" container runs nginx + gunicorn + the socketio websocket under s6-overlay, while `queue` and `scheduler` reuse the same image with a `command:` override. It is derived from upstream `frappe_docker` but no longer shares its layout.

Branches are per Frappe major version: `v15` and `v16` (also `main`, `upgrade-to-v16`). CI builds and pushes on push to `v15`/`v16` and weekly on Mondays, tagging the image with the branch name (e.g. `ghcr.io/marcag3/erpnext-docker:v16`).

## Commands

```bash
# Build the image locally (docker buildx bake, target defined in docker-bake.hcl)
./build.sh                      # wraps: docker buildx bake erpnext-nginx
docker buildx bake erpnext-nginx-dev

# Run the dev stack (builds nothing; pulls ghcr.io/marcag3/erpnext-docker:latest, UI on http://localhost:8080)
cp .env.example .env            # then set DB_PASSWORD / ADMIN_PASSWORD / PUID
docker compose up -d
docker compose logs -f web

# Production-style stack (image from $ERPNEXT_IMAGE, external `home-server_proxy` network, no published ports)
docker compose -f docker-compose.server.yml up -d

# Run bench inside the container (site name is always `frontend`)
docker compose exec -u frappe web bench --site frontend migrate
docker compose exec -u frappe web bench --site frontend console
```

There is no lint config and no test suite (see Tests).

## Architecture

**Build (`src/variations/erpnext-nginx/Dockerfile`)** is multi-stage: `builder` (`frappe/build`) runs `bench init` with `apps.json` and deletes `.git` dirs → `base` (`frappe/base` + nginx, wkhtmltopdf, mariadb/postgres clients) → `s6-build` (installs s6-overlay via `docker-erpnext-s6-install`, copies `src/s6/`) → `final` (copies the bench from `builder`, entrypoint scripts, nginx config). `FRAPPE_BRANCH` (default `version-16`) selects both the `frappe/build`/`frappe/base` tag and the Frappe branch, so switching Frappe versions means changing that arg. CI passes `apps.json` as `APPS_JSON_BASE64`; the Dockerfile also COPYs `apps.json` from the context, so the file in the repo is what ends up baked in.

**Startup chain** (spans several files):
1. The container runs as `frappe` (uid 1000, gid 0, like upstream `frappe/base`; compose can override the uid with `user: "${PUID}:0"`), never as root. Files are group-writable (`chmod g=u`) and the entrypoint sets `umask 0002`.
2. `docker-erpnext-entrypoint` (`src/common/usr/local/bin/`) sources every `/etc/entrypoint.d/[0-9]*-*.sh`, then `exec`s the command. The only script is `10-erpnext-init.sh`: writes `common_site_config.json` (db host, redis URLs, socketio port) on every start, and, only when `AUTORUN_ENABLED=true` (web only), creates the `frontend` site with ERPNext if `sites/frontend/site_config.json` is missing, otherwise runs `bench migrate`, installs apps, then `bench build --production`.
3. The default command `/init` starts s6-overlay, which supervises `gunicorn` (:8000), `websocket` (:9000) and `nginx` (:80, depends on the other two). Service definitions are in `src/s6/etc/s6-overlay/s6-rc.d/`; the `user` bundle is in `user-bundles.d/` (not `s6-rc.d/user/`) so s6 needs no write access to `/etc` at startup and can run as `frappe`.

**App installation is hybrid**: apps in `apps.json` are cloned at image build time. At runtime `INSTALL_APPS` (comma-separated) picks which to install on the site; if unset, every directory in `apps/` except `frappe`/`erpnext` is installed. Apps not in `apps.json` are only fetched with `bench get-app` when `ENABLE_RUNTIME_APPS=true`. Removing an app from `apps.json` does not uninstall it from an existing site; see the README section "Removed apps" for the uninstall procedure.

**Data**: `./sites` is mounted at `/home/frappe/frappe-bench/sites/frontend` (the site dir itself, not the whole `sites/`); MariaDB data is in `./db-data`; both are gitignored and `db-data` is owned by a different uid, so don't try to read it.

## Things to know

- The image is `ghcr.io/marcag3/erpnext-docker` everywhere (bake, compose, CI, `.env.example`).
- `.env` and `.vscode/` are gitignored.

## Tests

There is no test suite (the inherited upstream `tests/` was removed because it could not run here). Verify changes by building the image and bringing up the compose stack.
