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
- **LinuxServer.io User Management**: Dynamic user/group ID handling to prevent permission issues
- **Multi-Platform Support**: Builds for multiple architectures using Docker Buildx

## 🚀 Quick Start

### Prerequisites

- Docker and Docker Compose installed
- At least 4GB RAM available
- Ports 8080 (web) and 3306 (database) available

### 1. Clone and Setup

```bash
git clone https://github.com/marcag3/frappe_docker.git
cd frappe_docker
```

### 2. Environment Configuration

Copy the example environment file and customize it:

```bash
cp example.env .env
```

Edit `.env` with your desired configuration:

```bash
# Database Configuration
DB_PASSWORD=your_secure_database_password

# ERPNext Admin Configuration  
ADMIN_PASSWORD=your_admin_password

# User/Group IDs (optional - defaults to 1000)
PUID=1000
PGID=1000
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

## 🔐 User and Group ID Management

This setup uses the linuxserver.io approach for user and group ID management to prevent permission issues when mounting volumes.

### Setting Your User/Group IDs

1. **Find your user and group IDs**:
   ```bash
   id
   # Example output: uid=1000(mag) gid=1000(mag) groups=1000(mag),4(adm),24(cdrom),27(sudo),30(dip),46(plugdev),120(lpadmin),131(lxd),132(sambashare)
   ```

2. **Update your `.env` file**:
   ```bash
   PUID=1000  # Your user ID
   PGID=1000  # Your group ID
   ```

3. **Restart the containers**:
   ```bash
   docker compose down
   docker compose up -d
   ```

### How It Works

- The container creates a `frappe` user with the specified UID/GID
- At startup, the container checks if the user/group IDs need to be changed
- If needed, it dynamically changes the IDs and fixes ownership of all relevant directories
- This ensures that files created inside the container have the same ownership as your host user

## 🏛️ Project Structure

Following the [serversideup pattern](https://github.com/serversideup/docker-php/blob/main/src/variations/fpm-nginx/Dockerfile):

```
src/
├── common/                          # Common scripts and utilities
│   └── usr/local/bin/
│       ├── docker-erpnext-s6-install
│       ├── docker-erpnext-entrypoint
│       └── docker-erpnext-permissions
├── s6/                             # S6 Overlay service definitions
│   └── etc/s6-overlay/s6-rc.d/user/contents.d/
│       ├── nginx/                  # Nginx service
│       ├── gunicorn/               # Gunicorn service
│       └── websocket/              # WebSocket service
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

## 🐳 Docker Compose

The setup uses a simplified docker-compose.yml with:

- **Single web container** running all web services
- **Separate worker containers** using command overrides
- **Health checks** for proper dependency management
- **No more SERVICE_TYPE environment variables**

```yaml
services:
  web:                    # Single container for all web services
    image: ghcr.io/marcag3/erpnext-custom:latest
    
  queue:                  # Worker with command override
    image: ghcr.io/marcag3/erpnext-custom:latest
    command: ["bench", "worker", "--queue", "long,default,short"]
    
  scheduler:              # Scheduler with command override
    image: ghcr.io/marcag3/erpnext-custom:latest
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
# Fix file permissions
docker compose exec web chown -R frappe:frappe /home/frappe/frappe-bench/sites

# Check user/group IDs
docker compose exec web id frappe
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
git clone https://github.com/your-username/frappe_docker.git
cd frappe_docker

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
- [LinuxServer.io](https://www.linuxserver.io/) for user management approach
