#!/bin/sh
# ERPNext initialization script
# Based on serversideup pattern

if [ "${AUTORUN_ENABLED:-true}" != "true" ]; then
    echo "AUTORUN_ENABLED is false, skipping ERPNext initialization"
    exit 0
fi
# Check if bench instance already exists
if [ ! -f "sites/apps.txt" ]; then
    echo "No apps.txt found, checking bench structure..."
    
    # Debug: show current directory and contents
    echo "Current directory: $(pwd)"
    echo "Directory contents:"
    ls -la
    echo "Sites directory contents (if exists):"
    ls -la sites/ 2>/dev/null || echo "Sites directory does not exist"
    
    # If sites directory exists but is owned by root, fix permissions first
    if [ -d "sites" ] && [ "$(stat -c '%U' sites)" = "root" ]; then
        echo "Fixing sites directory ownership..."
        chown -R frappe:frappe sites/
    fi
    
    # If we have a bench structure but no apps.txt, we need to create the site
    if [ -d "apps" ] && [ -d "config" ]; then
        echo "Bench structure exists, creating site..."
        
        # Create sites directory if it doesn't exist
        mkdir -p sites
        
        # Create a basic site configuration
        echo '{}' > sites/common_site_config.json
        
        # Create apps.txt with default apps
        echo "frappe" > sites/apps.txt
        
        echo "Site created successfully"
    else
        echo "No bench structure found, initializing new bench environment..."
        
        # Initialize bench with apps configuration
        bench init --ignore-exist --apps_path=/opt/frappe/apps.json \
            --frappe-branch=version-15 \
            --frappe-path=https://github.com/frappe/frappe \
            --no-procfile \
            --no-backups \
            --skip-redis-config-generation \
            --verbose \
            .
    fi
    
    # Verify apps.txt was created
    if [ ! -f "sites/apps.txt" ]; then
        echo "ERROR: Failed to create apps.txt"
        exit 1
    fi
    
    echo "Bench environment setup completed successfully"
else
    echo "Bench instance already exists, skipping initialization"
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
if [ ! -f "sites/default/site_config.json" ]; then
    echo "Creating new ERPNext site..."
    
    # Create site
    bench new-site default \
        --no-mariadb-socket \
        --admin-password=${ADMIN_PASSWORD:-admin} \
        --db-root-password=${DB_PASSWORD} \
        --install-app erpnext \
        --set-default
    
    # Install additional apps
    bench --site default install-app hrms
    bench --site default install-app payments
    bench --site default install-app print_designer
    bench --site default install-app insights
    bench --site default install-app builder
    
    echo "ERPNext site creation completed"
else
    echo "ERPNext site already exists, skipping creation"
fi

# Return 0 to continue with other entrypoint scripts
return 0
