#!/bin/bash

echo "🏗️  Building ERPNext Docker Image (Simple Build)"
echo "=============================================="

# Check if Docker is available
if ! docker version > /dev/null 2>&1; then
    echo "❌ Docker is not available. Please install Docker first."
    exit 1
fi

echo "🔨 Building image..."

# Build the image directly
docker build \
    --file src/variations/erpnext-nginx/Dockerfile \
    --tag ghcr.io/marcag3/erpnext-custom:latest \
    --build-arg PYTHON_VERSION=3.11.6 \
    --build-arg DEBIAN_BASE=bookworm \
    --build-arg FRAPPE_BRANCH=version-15 \
    --build-arg FRAPPE_PATH=https://github.com/frappe/frappe \
    .

if [ $? -eq 0 ]; then
    echo "✅ Build completed successfully!"
    echo ""
    echo "🚀 To start services:"
    echo "   docker compose up -d"
    echo ""
    echo "🌐 Access ERPNext at: http://localhost:8080"
fi
