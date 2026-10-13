# ERPNext Docker

A modern, production-ready Docker setup for ERPNext that follows the [serversideup pattern](https://serversideup.net/open-source/docker-php/docs/getting-started/these-images-vs-others) of "one container, one thing" for optimal resource utilization and simplified management.

## 🏗️ Architecture

```
┌─────────────────────────────────────────┐
│           ERPNext Web Container         │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐   │
│  │ Nginx   │ │Gunicorn │ │WebSocket│   │
│  │(Proxy)  │ │(Python) │ │ (Node)  │   │
│  │ Port 80 │ │Port 8000│ │Port 9000│   │
│  └─────────┘ └─────────┘ └─────────┘   │
└─────────────────────────────────────────┘
```

## ✨ Features

- **Single Web Container**: Nginx + Gunicorn + WebSocket all in one container
- **S6-overlay Process Management**: Modern, reliable process supervisor for containers
- **ServersideUp Pattern**: Follows the proven pattern from serversideup/docker-php
- **Automatic Setup**: Site creation and app installation happens automatically
- **Production Ready**: Health checks, proper signal handling, and graceful shutdowns
- **Update-Friendly**: Works seamlessly with Watchtower for automatic updates
- **Non-root**: Runs as an unprivileged `frappe` user (uid 1000, gid 0), like upstream frappe_docker
- **Multi-Platform Support**: Builds for multiple architectures using Docker Buildx

## 🚀 Quick Start

### Prerequisites

- Docker and Docker Compose installed
- At least 4GB RAM available
- Ports 8080 (web) and 3306 (database) available

### 1. Clone and Setup

```bash
git clone https://github.com/marcag3/erpnext-docker.git
cd erpnext-docker
```

### 2. Environment Configuration

Copy the example environment file and customize it:

```bash
cp .env.example .env
```

Edit `.env` with your desired configuration:

```bash
# Database Configuration
DB_PASSWORD=your_secure_database_password

# ERPNext Admin Configuration  
ADMIN_PASSWORD=your_admin_password

# Host user ID the containers run as (optional - defaults to 1000)
PUID=1000

# App Installation (optional)
# Leave INSTALL_APPS unset to install all apps from apps.json (default)
# Or specify: INSTALL_APPS=print_designer
# ENABLE_RUNTIME_APPS=false
```

### 3. Start Services

```bash
# Start all services
docker compose up -d

# Check service status
docker compose ps
```

### 4. Access ERPNext

- **URL**: http://localhost:8080
- **Username**: `Administrator`
- **Password**: Value of `ADMIN_PASSWORD` from your `.env` file

> **Note**: Initial setup may take 5-10 minutes as ERPNext creates the site and installs apps automatically.

## 🔐 Users and Permissions

Like upstream [frappe_docker](https://github.com/frappe/frappe_docker), the containers run as the unprivileged `frappe` user (uid 1000, gid 0) and never as root. Files are group-writable, so any uid in group 0 can run the image.

The bind-mounted `./sites` folder must be writable by that user. Create it yourself before the first start (otherwise Docker creates it as `root`):

```bash
mkdir -p sites db-data
```

If your host user is not uid 1000, set `PUID` in `.env` (see `id -u`) and make sure `./sites` belongs to that uid:

```bash
sudo chown -R "$(id -u)" sites
```

Docker named volumes need no setup.

## 🏛️ Project Structure

Following the [serversideup pattern](https://github.com/serversideup/docker-php/blob/main/src/variations/fpm-nginx/Dockerfile):

```
src/
├── common/                          # Common scripts and utilities
│   └── usr/local/bin/
│       ├── docker-erpnext-s6-install
│       └── docker-erpnext-entrypoint
├── s6/                             # S6 Overlay service definitions
│   └── etc/s6-overlay/
│       ├── s6-rc.d/                # Services: nginx, gunicorn, websocket
│       └── user-bundles.d/user/    # Bundle that starts them
└── variations/                     # Different image variations
    └── erpnext-nginx/              # Main ERPNext + Nginx variation
        ├── Dockerfile              # Main Dockerfile
        └── etc/                    # Configuration files
            ├── nginx/              # Nginx configuration
            └── entrypoint.d/       # Entrypoint scripts
```

## 🔧 How It Works

### S6 Overlay Process Management
- **S6 Overlay**: Modern process supervisor designed for containers
- **Service Coordination**: Manages startup/shutdown order and health monitoring
- **Graceful Shutdown**: Proper signal handling for all processes

### Entrypoint Scripts
Following the [serversideup pattern](https://serversideup.net/open-source/docker-php/docs/customizing-the-image/adding-your-own-start-up-scripts):
- **`10-erpnext-init.sh`**: Runs during container startup
- **Site Creation**: Automatically creates ERPNext site if needed
- **Configuration**: Sets up database and Redis connections

### Service Configuration
- **Nginx**: Proxies requests to internal services
- **Gunicorn**: Python web application server
- **WebSocket**: Real-time communication server

## 📦 App Installation (Hybrid Approach)

This setup supports a **hybrid app installation** approach that combines the benefits of build-time and runtime app installation:

- **Build-time apps** (from `apps.json`): Fast, reproducible, always available
- **Runtime apps** (downloaded on-the-fly): Flexible, no rebuild needed

### How It Works

1. **Build-time apps**: Apps listed in `apps.json` are cloned into the Docker image during build
2. **Runtime apps**: Apps not in `apps.json` can be downloaded at runtime when `ENABLE_RUNTIME_APPS=true`

### Apps Included in Base Image

The following apps are included in the base Docker image (defined in `apps.json`):

| App | Repository | Branch |
|-----|------------|--------|
| **ERPNext** | [marcag3/erpnext](https://github.com/marcag3/erpnext) | `feat-bank-rec-accounting-dimensions` |
| **Print Designer** | [frappe/print_designer](https://github.com/frappe/print_designer) | `develop` |
| **Scout Manager** | [marcag3/scout-manager](https://github.com/marcag3/scout-manager) | `main` |

These apps are available for installation without requiring runtime downloads.

> **Note**: ERPNext is automatically installed when creating a new site and is excluded from the default app installation.

#### Removed apps (HRMS, Payments, Insights, Builder)

These apps are **not** included in `apps.json` for new builds:

| App | Why removed |
|-----|-------------|
| [HRMS](https://github.com/frappe/hrms) | HR/payroll module — not used. |
| [Payments](https://github.com/frappe/payments) | Online payment gateways for Web Forms — not used. ERPNext **Payment Entry** / **Mode of Payment** are core ERPNext and unaffected. |
| [Insights](https://github.com/frappe/insights) | BI/analytics app — not used for production reporting (custom Query Reports and dashboards are used instead). |
| [Builder](https://github.com/frappe/builder) | Website builder — not used. |

If an existing site still has one of these apps installed (for example, from an older image), uninstall it **before** deploying a new image:

```bash
# Stop workers first
docker compose stop queue scheduler

# Uninstall (run only the apps you still have installed)
docker compose exec -u frappe web bench --site frontend uninstall-app hrms --yes
docker compose exec -u frappe web bench --site frontend uninstall-app payments --yes
docker compose exec -u frappe web bench --site frontend uninstall-app insights --yes
docker compose exec -u frappe web bench --site frontend uninstall-app builder --yes

# Production (docker-compose.server.yml)
docker compose -f docker-compose.server.yml stop queue scheduler
docker compose -f docker-compose.server.yml exec -u frappe web bench --site frontend uninstall-app hrms --yes
docker compose -f docker-compose.server.yml exec -u frappe web bench --site frontend uninstall-app payments --yes
docker compose -f docker-compose.server.yml exec -u frappe web bench --site frontend uninstall-app insights --yes
docker compose -f docker-compose.server.yml exec -u frappe web bench --site frontend uninstall-app builder --yes

# Restart workers after uninstall
docker compose up -d
```

If you are still running an older image that bundles removed apps, set `INSTALL_APPS` explicitly so the entrypoint does not reinstall them on container restart:

```yaml
INSTALL_APPS: "print_designer"
```

### Default Behavior

**If `INSTALL_APPS` is not set**: All apps from `apps.json` (except `frappe` and `erpnext`) are automatically installed. This means by default, you'll get:
- Print Designer
- Scout Manager

**If `INSTALL_APPS` is set**: Only the specified apps are installed.

### Configuration

Add these environment variables to your `docker-compose.yml`:

```yaml
environment:
  # Comma-separated list of apps to install (optional)
  # If not set, all apps from apps.json are installed by default
  INSTALL_APPS: "print_designer"
  
  # Enable runtime app downloads (optional, defaults to false)
  ENABLE_RUNTIME_APPS: "true"
```

Or set them in your `.env` file:

```bash
# Leave INSTALL_APPS unset to install all apps from apps.json
# Or specify specific apps: INSTALL_APPS=print_designer
ENABLE_RUNTIME_APPS=false
```

### Usage Examples

#### Example 1: Default Behavior (Install All Apps from apps.json)

Don't set `INSTALL_APPS` - all apps from `apps.json` are installed automatically:

```yaml
environment:
  # INSTALL_APPS not set - installs all apps from apps.json
  # ENABLE_RUNTIME_APPS not set (defaults to false)
```

This will install: Print Designer and Scout Manager.

**Pros**: Zero configuration, all apps available, fast, reproducible, works offline

#### Example 2: Install Specific Apps Only

Only install selected apps from `apps.json`:

```yaml
environment:
  INSTALL_APPS: "print_designer"  # Only install these specific apps
  # ENABLE_RUNTIME_APPS not set (defaults to false)
```

**Pros**: Control which apps are installed

#### Example 3: Runtime Apps Enabled

Apps not in `apps.json` will be downloaded from GitHub:

```yaml
environment:
  INSTALL_APPS: "print_designer,new_app"  # new_app not in apps.json
  ENABLE_RUNTIME_APPS: "true"  # Allows downloading missing apps
```

**Pros**: Flexible, no rebuild needed  
**Cons**: Requires network access, slower first install

#### Example 4: Mixed Approach (Recommended)

Common apps in `apps.json`, optional apps at runtime:

```yaml
environment:
  INSTALL_APPS: "print_designer,optional_app"
  ENABLE_RUNTIME_APPS: "true"
```

- `print_designer` installs from build-time (fast)
- `optional_app` downloads at runtime (flexible)

### Best Practices

1. **Core apps in `apps.json`**: Add frequently-used apps to `apps.json` for fast installation
2. **Custom apps in `apps.json`**: Always include your custom app in `apps.json` for version control
3. **Optional apps at runtime**: Use runtime installation for project-specific or rarely-used apps
4. **Production**: Prefer build-time apps for reproducibility and offline capability

### Troubleshooting

**Error: "App not found and runtime installation is disabled"**
- Add the app to `apps.json` and rebuild, OR
- Set `ENABLE_RUNTIME_APPS=true` to allow runtime downloads

**Error: "Failed to download app from GitHub"**
- Check network connectivity
- Verify the app name is correct
- Ensure the app repository is publicly accessible

## 🐳 Docker Compose

The setup uses a simplified docker-compose.yml with:

- **Single web container** running all web services
- **Separate worker containers** using command overrides
- **Health checks** for proper dependency management
- **No more SERVICE_TYPE environment variables**

```yaml
services:
  web:                    # Single container for all web services
    image: ghcr.io/marcag3/erpnext-docker:latest
    
  queue:                  # Worker with command override
    image: ghcr.io/marcag3/erpnext-docker:latest
    command: ["bench", "worker", "--queue", "long,default,short"]
    
  scheduler:              # Scheduler with command override
    image: ghcr.io/marcag3/erpnext-docker:latest
    command: ["bench", "schedule"]
```

## 🏗️ Building

### Using Docker Buildx Bake
```bash
# Build for all platforms
docker buildx bake erpnext-nginx

# Build for specific platform
docker buildx bake --set "*.platform=linux/amd64" erpnext-nginx
```

### Using Docker Compose
```bash
# Build and start
docker compose up -d --build

# Build specific service
docker compose build web
```

## 🏭 Production Deployment

### Security Considerations

- **Change Default Passwords**: Always use strong, unique passwords for `DB_PASSWORD` and `ADMIN_PASSWORD`
- **Use HTTPS**: Configure a reverse proxy (nginx, traefik) with SSL certificates
- **Network Security**: Use `docker-compose.server.yml` for production with proper network isolation
- **Regular Backups**: Implement automated backups for database and site data

### Production Configuration

For production deployments, use `docker-compose.server.yml`:

```bash
# Use production configuration
docker compose -f docker-compose.server.yml up -d
```

Key differences in production mode:
- Services restart automatically (`restart: unless-stopped`)
- Health check dependencies ensure proper startup order
- External network support for reverse proxies
- Updated Redis versions (7.4-alpine)

### Resource Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **RAM** | 4GB | 8GB+ |
| **CPU** | 2 cores | 4+ cores |
| **Storage** | 20GB | 100GB+ SSD |
| **Network** | 100Mbps | 1Gbps+ |

### Monitoring and Maintenance

```bash
# Check service health
docker compose ps

# View logs
docker compose logs -f web

# Monitor resource usage
docker stats

# Backup database
docker compose exec db mysqldump -u root -p${DB_PASSWORD} --all-databases > backup.sql
```

## 🔄 Updates

### Automatic Updates with Watchtower

Add this service to your `docker-compose.yml` for automatic updates:

```yaml
watchtower:
  image: containrrr/watchtower
  restart: unless-stopped
  environment:
    - WATCHTOWER_CLEANUP=true
    - WATCHTOWER_POLL_INTERVAL=3600
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock
  command: --include-stopped --revise-stopped
```

### Manual Updates

```bash
# Pull latest images
docker compose pull

# Restart services with new images
docker compose up -d
```

## 🧪 Testing & Troubleshooting

### Service Health Checks

```bash
# Check all service status
docker compose ps

# View real-time logs
docker compose logs -f web

# Check specific service logs
docker compose logs -f db
docker compose logs -f queue
docker compose logs -f scheduler
```

### S6 Service Management

```bash
# Check S6 service status inside container
docker exec -it <container_name> s6-svstat /var/run/s6/services/*

# Restart specific S6 service
docker exec -it <container_name> s6-svc -r /var/run/s6/services/nginx
```

### Common Issues

#### Services Not Starting
```bash
# Check if all dependencies are healthy
docker compose ps

# Verify environment variables
docker compose config

# Check container logs for errors
docker compose logs web
```

#### Permission Issues
```bash
# The ./sites folder must be writable by PUID (default 1000), group 0
sudo chown -R "$(id -u)" sites

# Check which user the container runs as
docker compose exec web id
```

#### Database Connection Issues
```bash
# Test database connectivity
docker compose exec web bench --site frontend mariadb

# Check database logs
docker compose logs db
```

### Performance Monitoring

```bash
# Monitor resource usage
docker stats

# Check disk usage
docker system df

# View container resource limits
docker compose exec web cat /proc/meminfo
```

## 🆚 Architecture Comparison

| Aspect | Traditional Multi-Container | Current S6 Overlay |
|--------|----------------------------|-------------------|
| **Web Services** | 3 separate containers | 1 unified container |
| **Networking** | Inter-container communication | Internal localhost |
| **Resource Usage** | Higher memory overhead | Optimized resource usage |
| **Updates** | Multiple image updates | Single image update |
| **Complexity** | Complex orchestration | Simplified management |
| **Debugging** | Multiple log streams | Unified logging |
| **Startup Time** | Sequential dependencies | Parallel service startup |
| **Maintenance** | Multiple containers to manage | Single container focus |

## 📚 References & Resources

- [ERPNext Documentation](https://docs.erpnext.com/) - Official ERPNext documentation
- [Frappe Framework](https://frappeframework.com/) - The underlying framework
- [Serversideup Docker Pattern](https://serversideup.net/open-source/docker-php/) - Architecture inspiration
- [S6 Overlay Documentation](https://github.com/just-containers/s6-overlay) - Process management
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/) - Container optimization

## 🤝 Contributing

We welcome contributions! Please follow these guidelines:

1. **Fork the repository** and create a feature branch
2. **Follow the existing code style** and patterns
3. **Test your changes** thoroughly
4. **Update documentation** as needed
5. **Submit a pull request** with a clear description

### Development Setup

```bash
# Clone your fork
git clone https://github.com/your-username/erpnext-docker.git
cd erpnext-docker

# Build the development image
docker buildx bake erpnext-nginx-dev

# Test your changes
docker compose up -d --build
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Frappe Technologies](https://frappe.io/) for ERPNext
- [Serversideup](https://serversideup.net/) for the Docker architecture pattern
