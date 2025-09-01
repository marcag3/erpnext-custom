#!/bin/sh
# ERPNext initialization script for S6 Overlay
# This script runs once during container startup

# Check if site exists, if not create it
if [ ! -f "sites/frontend/site_config.json" ]; then
    echo "Creating new ERPNext site..."
    
    # Set basic config
    bench set-config -g db_host ${DB_HOST:-db}
    bench set-config -gp db_port ${DB_PORT:-3306}
    bench set-config -g redis_cache "redis://${REDIS_CACHE:-redis-cache}:6379"
    bench set-config -g redis_queue "redis://${REDIS_QUEUE:-redis-queue}:6379"
    bench set-config -g redis_socketio "redis://${REDIS_QUEUE:-redis-queue}:6379"
    bench set-config -gp socketio_port ${SOCKETIO_PORT:-9000}
    
    # Create site
    bench new-site frontend \
        --no-mariadb-socket \
        --admin-password=${ADMIN_PASSWORD:-admin} \
        --db-root-password=${DB_PASSWORD} \
        --install-app erpnext \
        --set-default
    
    # Install additional apps
    bench --site frontend install-app hrms
    bench --site frontend install-app payments
    bench --site frontend install-app print_designer
    bench --site frontend install-app insights
    bench --site frontend install-app builder
    
    echo "ERPNext site creation completed"
else
    echo "ERPNext site already exists, skipping creation"
fi

# Return 0 to continue with other entrypoint scripts
return 0
