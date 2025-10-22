# Gazelle XDStarClient Docker Setup

A simple Docker Compose setup for running Gazelle XDStarClient with JBoss AS 7.2.0 and PostgreSQL 9.4.

## Features

- **Zero-configuration**: XDStarClient 3.1.0 downloads automatically during build
- **Complete stack**: PostgreSQL 9.4 + JBoss AS 7.2.0 + XDStarClient
- **Persistent data**: All application data stored in Docker volumes
- **Health checks**: Automatic service health monitoring

## Quick Start

```bash
# 1. Copy environment template
cp .env.example .env

# 2. Build and start (XDStarClient downloads automatically)
docker compose up -d --build

# 3. View logs
docker compose logs -f

# 4. Access the application
# http://localhost:8080/XDStarClient
```

That's it! The setup automatically downloads XDStarClient 3.1.0 from the Gazelle Nexus repository during build.

## Prerequisites

- Docker Engine 20.10+
- Docker Compose 1.29+
- 4GB+ RAM
- Internet connection (for initial build)

## Access Points

- **XDStarClient**: http://localhost:8080/XDStarClient
- **JBoss Admin Console**: http://localhost:9990/console (admin/admin123)
- **PostgreSQL**: localhost:5432 (gazelle/gazelle123)

## Configuration

Edit `.env` to customize:

```bash
# XDStarClient version
XDSTARCLIENT_VERSION=3.1.0

# Database password
POSTGRES_PASSWORD=gazelle123

# JBoss admin credentials
JBOSS_ADMIN_USER=admin
JBOSS_ADMIN_PASSWORD=admin123
```

## Common Commands

```bash
# Start services
docker compose up -d

# Stop services
docker compose down

# View logs
docker compose logs -f

# View logs for specific service
docker compose logs -f jboss
docker compose logs -f postgres

# Restart services
docker compose restart

# Rebuild with different XDStarClient version
docker compose build --build-arg XDSTARCLIENT_VERSION=3.0.0
docker compose up -d

# Connect to database
docker compose exec postgres psql -U gazelle -d xdstar-client

# Access JBoss shell
docker compose exec jboss /bin/bash

# Check service status
docker compose ps

# Remove everything (including data volumes)
docker compose down -v
```

## Data Persistence

All data is stored in Docker volumes:

- `postgres_data` - Database files
- `xdstar_data` - Application data
- `xdstar_uploads` - Uploaded files
- `jboss_deployments` - Application deployments
- `jboss_config` - JBoss configuration

## Backup and Restore

```bash
# Backup database
docker compose exec postgres pg_dump -U gazelle xdstar-client > backup.sql

# Restore database
docker compose exec -T postgres psql -U gazelle -d xdstar-client < backup.sql
```

## Troubleshooting

### Services won't start

```bash
# Check logs
docker compose logs

# Check if ports are in use
netstat -an | grep -E '8080|5432|9990'

# Restart everything
docker compose down
docker compose up -d
```

### Database connection errors

```bash
# Check PostgreSQL is running
docker compose ps postgres

# Test connection
docker compose exec jboss psql -h postgres -U gazelle -d xdstar-client
```

### XDStarClient download fails

If automatic download fails during build:

```bash
# Option 1: Use the download script
./download-xdstarclient.sh

# Option 2: Manual download
# Download from https://gazelle.ihe.net/nexus
# Place in: deployments/XDStarClient.ear
# Then rebuild: docker compose up -d --build
```

### Reset everything

```bash
# Stop and remove all containers, networks, and volumes
docker compose down -v

# Rebuild from scratch
docker compose up -d --build
```

## Manual XDStarClient Download

If you need to manually download XDStarClient:

```bash
# Using the provided script (version 3.1.0 or specify another)
./download-xdstarclient.sh
./download-xdstarclient.sh 3.0.0

# Then rebuild
docker compose up -d --build
```

## Architecture

Based on the [official IHE Catalyst installation guide](https://connectathon.ihe-catalyst.net/gazelle-documentation/XDStar-Client/installation.html):

- **OS**: Debian Jessie (containerized)
- **Java**: OpenJDK 7
- **App Server**: JBoss AS 7.2.0.Final
- **Database**: PostgreSQL 9.4
- **Application**: XDStarClient 3.1.0 (auto-downloaded from Gazelle Nexus)

## File Structure

```
.
├── docker-compose.yml          # Service orchestration
├── Dockerfile                  # JBoss + XDStarClient image
├── .env.example               # Configuration template
├── start-jboss.sh             # JBoss startup script
├── datasource-config.cli      # Database connection config
├── init-db.sql                # Database initialization
├── download-xdstarclient.sh   # Manual download script
└── TESTING.md                 # Detailed testing guide
```

## Support

- **This Docker setup**: Open an issue in this repository
- **XDStarClient application**: [IHE Gazelle Documentation](https://gazelle.ihe.net/content/xdstarclient)
- **Docker/Docker Compose**: [Docker Documentation](https://docs.docker.com/)

## License

This Docker setup is provided as-is. XDStarClient is an open source project under Apache 2 license by IHE-Europe/Gazelle team.

## References

- [XDStarClient Installation Manual](https://connectathon.ihe-catalyst.net/gazelle-documentation/XDStar-Client/installation.html)
- [IHE Catalyst Connectathon](https://connectathon.ihe-catalyst.net/)
- [Gazelle Nexus Repository](https://gazelle.ihe.net/nexus)
