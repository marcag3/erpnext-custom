#!/bin/sh
# ERPNext Docker Fix Permissions Script
# Based on linuxserver.io approach for user/group ID management
# This script runs early in the entrypoint process to ensure proper permissions

set -e

echo "Running permission fix script..."

# Run the unified permission management script
docker-erpnext-permissions

echo "Permission fix completed, continuing with initialization..."

# Return 0 to continue with other entrypoint scripts
return 0
