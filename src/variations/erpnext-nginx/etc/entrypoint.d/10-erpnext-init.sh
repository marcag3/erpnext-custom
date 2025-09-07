#!/bin/sh
# ERPNext initialization script
# Based on serversideup pattern

if [ "${AUTORUN_ENABLED:-true}" != "true" ]; then
    echo "AUTORUN_ENABLED is false, skipping ERPNext initialization"
    exit 0
fi

# Always update global configuration to ensure Redis URLs are correct
echo "Updating global configuration..."
bench set-config -g db_host ${DB_HOST:-db}
bench set-config -gp db_port ${DB_PORT:-3306}
bench set-config -g redis_cache "redis://${REDIS_CACHE:-redis-cache:6379}"
bench set-config -g redis_queue "redis://${REDIS_QUEUE:-redis-queue:6379}"
bench set-config -g redis_socketio "redis://${REDIS_QUEUE:-redis-queue:6379}"
bench set-config -gp socketio_port ${SOCKETIO_PORT:-9000}

# Check if site exists, if not create it
if [ ! -f "sites/frontend/site_config.json" ]; then
    echo "Creating new ERPNext site..."
    
    # Create site
    bench new-site frontend --force \
        --mariadb-user-host-login-scope='%' \
        --admin-password=${ADMIN_PASSWORD:-admin} \
        --db-root-password=${DB_PASSWORD} \
        --install-app erpnext \
        --set-default
    
    # Install additional apps
    bench --site frontend install-app hrms
    bench --site frontend install-app payments
    bench --site frontend install-app insights
    bench --site frontend install-app builder
    bench --site frontend install-app print_designer
    
    
    echo "ERPNext site creation completed"
else
    echo "ERPNext site already exists, running migrations..."
    bench --site frontend migrate
    
    bench --site frontend install-app print_designer
    # Check and install apps if not already installed
    # apps=("hrms" "payments" "insights" "builder" "print_designer")
    # for app in "${apps[@]}"; do
    #     if ! bench --site frontend list-apps | grep -q "$app"; then
    #         echo "Installing $app app..."
    #         bench --site frontend install-app "$app"
    #     else
    #         echo "$app app already installed, skipping..."
    #     fi
    # done
fi

echo "Build assets..."
bench build --production

# Return 0 to continue with other entrypoint scripts
return 0
