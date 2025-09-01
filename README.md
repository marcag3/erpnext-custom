# ERPNext Docker Setup Guide

This is a simplified, single-image Docker setup for ERPNext that eliminates the need for manual configuration and enables automatic updates.

## Features

- **Single Image**: All services use the same pre-built image
- **Automatic Setup**: Site creation and app installation happens automatically
- **Update-Friendly**: Works seamlessly with Watchtower for automatic updates
- **Health Checks**: Proper dependency management with Docker Compose health checks

## Quick Start

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

## How It Works

### Service Types
Each service uses the same image but runs different functionality based on the `SERVICE_TYPE` environment variable:

- **backend**: Gunicorn web server
- **frontend**: Nginx reverse proxy
- **worker**: Background job processing (all queue types)
- **scheduler**: Cron job scheduling
- **websocket**: Real-time communication

### Automatic Initialization
On first run, the startup script automatically:
1. Waits for database and Redis services to be healthy
2. Creates the ERPNext site if it doesn't exist
3. Installs all required apps (ERPNext, HRMS, Payments, etc.)
4. Starts the appropriate service

### Health Checks
- **Database**: Waits for MariaDB to be ready
- **Redis**: Waits for both cache and queue instances
- **Dependencies**: Services only start after dependencies are healthy

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DB_PASSWORD` | - | MariaDB root password (required) |
| `ADMIN_PASSWORD` | `admin` | ERPNext admin user password |
| `FRAPPE_SITE_NAME_HEADER` | - | Custom site header |

## Automatic Updates with Watchtower

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
  command: --include-stopped --revive-stopped
```

## Troubleshooting

### Check Service Status
```bash
docker compose ps
```

### View Logs
```bash
docker compose logs -f [service-name]
```

### Rebuild and Restart
```bash
docker compose down
docker compose up -d --build
```

### Reset Everything
```bash
docker compose down -v
rm -rf sites/ db-data/
docker compose up -d
```

## Architecture

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Frontend  │    │   Backend   │    │   Worker    │
│   (Nginx)   │    │ (Gunicorn)  │    │ (Background)│
└─────────────┘    └─────────────┘    └─────────────┘
       │                   │                   │
       └───────────────────┼───────────────────┘
                           │
                    ┌─────────────┐
                    │   Database  │
                    │  (MariaDB)  │
                    └─────────────┘
                           │
                    ┌─────────────┐
                    │    Redis    │
                    │ (Cache+Q)   │
                    └─────────────┘
```

All services use the same Docker image with different `SERVICE_TYPE` configurations.
