#!/bin/bash

export APPS_JSON_BASE64=$(base64 -w 0 /path/to/apps.json)

docker build \
  --build-arg=APPS_JSON_BASE64=$APPS_JSON_BASE64 \
  --tag=ghcr.io/user/repo/custom:1.0.0 \
  --file=images/custom/Containerfile .