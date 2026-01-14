#!/bin/sh
# ERPNext initialization script


# Always update global configuration to ensure Redis URLs are correct
echo "Updating global configuration..."
bench set-config -g db_host ${DB_HOST:-db}
bench set-config -gp db_port ${DB_PORT:-3306}
bench set-config -g redis_cache "redis://${REDIS_CACHE:-redis-cache:6379}"
bench set-config -g redis_queue "redis://${REDIS_QUEUE:-redis-queue:6379}"
bench set-config -g redis_socketio "redis://${REDIS_QUEUE:-redis-queue:6379}"
bench set-config -gp socketio_port ${SOCKETIO_PORT:-9000}
bench set-config -g server_script_enabled 1

# Configure logging to stdout/stderr for Docker
# Redirect log files to stdout/stderr to prevent disk space issues
bench set-config -g log_file "/dev/stdout"
bench set-config -g error_log_file "/dev/stderr"


if [ "${AUTORUN_ENABLED:-true}" != "true" ]; then
    echo "AUTORUN_ENABLED is false, skipping ERPNext initialization"
    return 0
fi
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
    

    
    echo "ERPNext site creation completed"
else
    echo "ERPNext site already exists, running migrations..."
    bench --site frontend migrate
fi

# Install additional apps from environment variable (hybrid approach)
# Supports both build-time apps (from apps.json) and runtime apps (downloaded on-the-fly)
# Format: INSTALL_APPS="app1,app2,app3" or leave empty to install all apps from apps.json
# Set ENABLE_RUNTIME_APPS=true to allow downloading apps not in apps.json
if [ -n "${INSTALL_APPS}" ]; then
    echo "Installing apps from INSTALL_APPS: ${INSTALL_APPS}"
    # Use POSIX-compatible method to split comma-separated string
    OLD_IFS="$IFS"
    IFS=','
    for app in ${INSTALL_APPS}; do
        app=$(echo "$app" | xargs)  # Trim whitespace
        if [ -n "$app" ]; then
            echo "Processing app: $app"
            
            # Check if app exists in bench (build-time app from apps.json)
            if [ ! -d "apps/$app" ]; then
                # App not found in bench, check if runtime installation is enabled
                if [ "${ENABLE_RUNTIME_APPS:-false}" = "true" ]; then
                    echo "App '$app' not found in bench, attempting to download from GitHub..."
                    if bench get-app "$app"; then
                        echo "Successfully downloaded app '$app'"
                    else
                        echo "Error: Failed to download app '$app' from GitHub"
                        echo "Make sure the app name is correct and the repository is accessible"
                        continue
                    fi
                else
                    echo "Error: App '$app' not found in bench and runtime app installation is disabled"
                    echo "To fix this, either:"
                    echo "  1. Add '$app' to apps.json and rebuild the image, or"
                    echo "  2. Set ENABLE_RUNTIME_APPS=true to allow downloading apps at runtime"
                    continue
                fi
            else
                echo "App '$app' found in bench (build-time app)"
            fi
            
            # Install app to site
            echo "Installing app '$app' to site..."
            if bench --site frontend install-app "$app"; then
                echo "Successfully installed app '$app'"
            else
                echo "Warning: Failed to install app '$app' to site. It may already be installed or there was an error."
            fi
        fi
    done
    IFS="$OLD_IFS"
else
    # INSTALL_APPS not set, install all apps from apps.json (default behavior)
    echo "INSTALL_APPS not set, installing all apps from apps.json (default behavior)"
    
    # Discover all apps in apps/ directory (excluding frappe and erpnext)
    # frappe is the framework, erpnext is already installed during site creation
    if [ -d "apps" ]; then
        for app_dir in apps/*; do
            # Check if glob matched any files (not literal "apps/*")
            [ "$app_dir" = "apps/*" ] && break
            if [ -d "$app_dir" ]; then
                app=$(basename "$app_dir")
                # Skip frappe (framework) and erpnext (already installed)
                if [ "$app" != "frappe" ] && [ "$app" != "erpnext" ]; then
                    echo "Processing app: $app (from apps.json)"
                    
                    # Install app to site
                    echo "Installing app '$app' to site..."
                    if bench --site frontend install-app "$app"; then
                        echo "Successfully installed app '$app'"
                    else
                        echo "Warning: Failed to install app '$app' to site. It may already be installed or there was an error."
                    fi
                fi
            fi
        done
    fi
fi


echo "Build assets..."
bench build --production

# Return 0 to continue with other entrypoint scripts
return 0
