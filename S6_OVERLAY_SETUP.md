# ERPNext with S6 Overlay - Single Container Web Stack

This setup uses S6 Overlay to run multiple processes (Nginx, Gunicorn, WebSocket) in a single container, following the modern "one container, one thing" principle.

## Architecture

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

## How It Works

### S6 Overlay Process Management
- **S6 Overlay**: Modern process supervisor designed for containers
- **Service Coordination**: Manages startup/shutdown order and health monitoring
- **Graceful Shutdown**: Proper signal handling for all processes

### Service Configuration
- **Nginx**: Proxies requests to internal services
- **Gunicorn**: Python web application server
- **WebSocket**: Real-time communication server

### Entrypoint Scripts
Following the [serversideup pattern](https://serversideup.net/open-source/docker-php/docs/customizing-the-image/adding-your-own-start-up-scripts):
- **`10-erpnext-init.sh`**: Runs during container startup
- **Site Creation**: Automatically creates ERPNext site if needed
- **Configuration**: Sets up database and Redis connections

## Benefits

1. **Simplified Orchestration**: One container instead of three
2. **Better Resource Sharing**: Shared memory, file system, network
3. **Easier Updates**: Single image update
4. **Reduced Network Overhead**: No inter-container communication
5. **Modern Approach**: Follows current Docker best practices

## Container Structure

### Web Container (S6 Overlay)
- **Port 80**: Nginx proxy (mapped to host port 8080)
- **Port 8000**: Gunicorn backend (internal)
- **Port 9000**: WebSocket server (internal)

### Separate Containers
- **Queue**: Background job processing
- **Scheduler**: Cron job management
- **Database**: MariaDB
- **Redis**: Cache and queue storage

## Configuration

### Nginx Configuration
- **Internal Proxying**: Routes requests to localhost services
- **WebSocket Support**: Handles real-time connections
- **Static Files**: Serves assets and protected files
- **Gzip Compression**: Optimized for performance

### Environment Variables
```yaml
environment:
  DB_HOST: db
  DB_PORT: 3306
  REDIS_CACHE: redis-cache:6379
  REDIS_QUEUE: redis-queue:6379
  SOCKETIO_PORT: 9000
  DB_PASSWORD: "${DB_PASSWORD}"
  ADMIN_PASSWORD: "${ADMIN_PASSWORD:-admin}"
```

## Usage

### Start Services
```bash
docker compose up -d
```

### Access ERPNext
- **URL**: http://localhost:8080
- **Username**: Administrator
- **Password**: Value of ADMIN_PASSWORD in .env

### Check Status
```bash
docker compose ps
docker compose logs web
```

## Process Management

### S6 Services
- **nginx**: Web proxy and static file server
- **gunicorn**: Python application server
- **websocket**: Real-time communication

### Health Monitoring
- **Automatic Restart**: S6 monitors and restarts failed services
- **Graceful Shutdown**: Proper cleanup on container stop
- **Startup Order**: Services start in dependency order

## Troubleshooting

### View S6 Logs
```bash
docker compose logs web
```

### Check Service Status
```bash
docker exec -it <container> s6-svstat /var/run/s6/services/*
```

### Restart Specific Service
```bash
docker exec -it <container> s6-svc -r /var/run/s6/services/nginx
```

## Comparison with Previous Setup

| Aspect | Previous (Multi-Container) | Current (S6 Overlay) |
|--------|----------------------------|----------------------|
| **Containers** | 3 web containers | 1 web container |
| **Networking** | Inter-container | Internal (localhost) |
| **Updates** | Multiple images | Single image |
| **Resource Usage** | Higher overhead | Lower overhead |
| **Complexity** | Higher | Lower |
| **Debugging** | Multiple logs | Single log stream |

This approach gives you the best of both worlds: the simplicity of a single container with the reliability of proper process management.
