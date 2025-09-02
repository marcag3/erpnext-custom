# ERPNext Docker - Serversideup Style

This is a simplified, single-image Docker setup for ERPNext that follows the modern [serversideup pattern](https://serversideup.net/open-source/docker-php/docs/getting-started/these-images-vs-others) of "one container, one thing" instead of the old "one container, one process" mantra.

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
- **S6 Overlay Process Management**: Modern, reliable process supervisor
- **Entrypoint Scripts**: Following serversideup's pattern for initialization
- **Separate Worker Containers**: Using command overrides instead of SERVICE_TYPE
- **Automatic Setup**: Site creation and app installation happens automatically
- **Update-Friendly**: Works seamlessly with Watchtower for automatic updates
- **LinuxServer.io User Management**: Dynamic user/group ID handling to prevent permission issues

## 🚀 Quick Start

1. **Clone and Setup**:
   ```bash
   git clone <your-repo>
   cd frappe_docker
   cp example.env .env
   # Edit .env with your desired passwords
   ```

2. **Start Services**:
   ```bash
   docker compose up -d
   ```

3. **Access ERPNext**:
   - Wait for all services to be healthy (check with `docker compose ps`)
   - Access at `http://localhost:8080`
   - Username: `Administrator`
   - Password: Value of `ADMIN_PASSWORD` in your `.env` file

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

## 🔄 Updates

### Automatic Updates with Watchtower
Add this service to your `docker-compose.yml`:

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

## 🧪 Testing

### Check Service Status
```bash
docker compose ps
```

### View Logs
```bash
docker compose logs -f web
```

### Check S6 Services
```bash
docker exec -it <container> s6-svstat /var/run/s6/services/*
```

## 🆚 Comparison with Previous Setup

| Aspect | Previous (Multi-Container) | Current (S6 Overlay) |
|--------|----------------------------|----------------------|
| **Containers** | 3 web containers | 1 web container |
| **Networking** | Inter-container | Internal (localhost) |
| **Updates** | Multiple images | Single image |
| **Resource Usage** | Higher overhead | Lower overhead |
| **Complexity** | Higher | Lower |
| **Debugging** | Multiple logs | Single log stream |

## 📚 References

- [Serversideup Docker PHP Images](https://github.com/serversideup/docker-php)
- [S6 Overlay Documentation](https://github.com/just-containers/s6-overlay)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)

## 🤝 Contributing

This project follows the serversideup pattern for Docker images. Contributions are welcome!

## 📄 License

MIT License - see LICENSE file for details.
