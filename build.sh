#!/bin/bash

echo "🏗️  Building ERPNext Docker Image"
echo "=================================================="

# Check if docker buildx is available
if ! docker buildx version > /dev/null 2>&1; then
    echo "❌ Docker Buildx is not available. Please install it first."
    exit 1
fi

# Check current builder
CURRENT_BUILDER=$(docker buildx inspect --bootstrap | grep "Driver:" | awk '{print $2}')
echo "🔧 Current builder: $CURRENT_BUILDER"

# Try to build with bake first
echo "🔨 Building image with docker buildx bake..."
if docker buildx bake erpnext-nginx; then
    echo "✅ Build completed successfully!"
    echo ""
    echo "🚀 To start services:"
    echo "   docker compose up -d"
    echo ""
    echo "🌐 Access ERPNext at: http://localhost:8080"
    exit 0
fi