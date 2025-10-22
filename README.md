# Gazelle XDStarClient Docker Setup

A Docker Compose setup for running Gazelle XDStarClient with JBoss AS 7.2.0 and PostgreSQL 9.4.

## Overview

This project provides a containerized environment for the Gazelle XDStarClient application, based on the official installation documentation from [IHE Catalyst](https://connectathon.ihe-catalyst.net/gazelle-documentation/XDStar-Client/installation.html).

### Components

- **PostgreSQL 9.4**: Database server for XDStarClient data
- **JBoss AS 7.2.0.Final**: Application server running on OpenJDK 7
- **XDStarClient**: IHE testing tool (EAR file needs to be provided)

## Prerequisites

- Docker Engine 20.10 or later
- Docker Compose 1.29 or later (both `docker compose` and `docker-compose` supported)
- At least 4GB of available RAM
- XDStarClient.ear file (to be placed in deployments folder)

**Note**: The Makefile automatically detects whether you have `docker-compose` (standalone) or `docker compose` (plugin) and uses the appropriate command.

## Quick Start

### 1. Clone and Configure

```bash
# Clone the repository
git clone <repository-url>
cd gazelle-docker

# Copy the environment configuration
cp .env.example .env

# Edit .env with your preferred settings
nano .env
```

### 2. Add XDStarClient Application

Place your `XDStarClient.ear` file in the project directory:

```bash
# Create a deployments directory
mkdir -p deployments

# Copy your XDStarClient.ear file
cp /path/to/XDStarClient.ear deployments/
```

### 3. Start the Services

```bash
# Build and start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Check service status
docker-compose ps
```

### 4. Access the Application

- **XDStarClient Web Interface**: http://localhost:8080/XDStarClient
- **JBoss Admin Console**: http://localhost:9990/console
  - Username: `admin` (or as configured in .env)
  - Password: `admin123` (or as configured in .env)
- **PostgreSQL**: localhost:5432
  - Database: `xdstar-client`
  - Username: `gazelle`
  - Password: as configured in .env

## Configuration

### Environment Variables

Edit the `.env` file to customize your deployment:

```bash
# Database
POSTGRES_PASSWORD=gazelle123

# JBoss Admin
JBOSS_ADMIN_USER=admin
JBOSS_ADMIN_PASSWORD=admin123
```

### Volumes and Persistence

The setup uses Docker volumes for data persistence:

- `postgres_data`: PostgreSQL database files
- `xdstar_data`: Main application data
- `xdstar_xsd`: XML Schema files
- `xdstar_uploads`: Uploaded/registered files
- `xdstar_tmp`: Temporary upload folder
- `xdstar_attachments`: Attachment storage
- `jboss_deployments`: JBoss deployment files
- `jboss_config`: JBoss configuration

### Deploying XDStarClient

To deploy the XDStarClient application:

```bash
# Copy the EAR file to the deployments volume
docker cp XDStarClient.ear gazelle-jboss:/opt/jboss/standalone/deployments/

# Monitor deployment
docker-compose logs -f jboss
```

Alternatively, you can modify the Dockerfile to include the EAR file during build:

```dockerfile
# Add to Dockerfile before CMD
COPY deployments/XDStarClient.ear ${JBOSS_HOME}/standalone/deployments/
```

## Management Commands

### Starting and Stopping

```bash
# Start services
docker-compose up -d

# Stop services
docker-compose down

# Stop and remove volumes (WARNING: deletes all data)
docker-compose down -v

# Restart a specific service
docker-compose restart jboss
```

### Viewing Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f jboss
docker-compose logs -f postgres

# Last 100 lines
docker-compose logs --tail=100 jboss
```

### Database Management

```bash
# Connect to PostgreSQL
docker-compose exec postgres psql -U gazelle -d xdstar-client

# Backup database
docker-compose exec postgres pg_dump -U gazelle xdstar-client > backup.sql

# Restore database
docker-compose exec -T postgres psql -U gazelle -d xdstar-client < backup.sql
```

### JBoss Management

```bash
# Access JBoss CLI
docker-compose exec jboss /opt/jboss/bin/jboss-cli.sh --connect

# View JBoss logs
docker-compose exec jboss tail -f /opt/jboss/standalone/log/server.log

# Restart JBoss
docker-compose restart jboss
```

## Troubleshooting

### Check Service Health

```bash
# View service status
docker-compose ps

# Check container health
docker inspect gazelle-jboss --format='{{.State.Health.Status}}'
docker inspect gazelle-postgres --format='{{.State.Health.Status}}'
```

### Common Issues

#### Database Connection Errors

If JBoss cannot connect to PostgreSQL:

1. Verify PostgreSQL is running: `docker-compose ps postgres`
2. Check database logs: `docker-compose logs postgres`
3. Test connection: `docker-compose exec jboss psql -h postgres -U gazelle -d xdstar-client`

#### JBoss Startup Issues

1. Check available memory: `docker stats`
2. Review JBoss logs: `docker-compose logs jboss`
3. Verify Java version: `docker-compose exec jboss java -version`

#### Port Conflicts

If ports 8080 or 5432 are already in use:

```yaml
# Edit docker-compose.yml
services:
  jboss:
    ports:
      - "8081:8080"  # Change external port
  postgres:
    ports:
      - "5433:5432"  # Change external port
```

### Reset Everything

To start fresh:

```bash
# Stop and remove containers, networks, and volumes
docker-compose down -v

# Remove images
docker rmi gazelle-docker_jboss

# Rebuild and start
docker-compose up -d --build
```

## Architecture

### Network

All services run on a dedicated bridge network (`gazelle-network`) allowing:
- Service discovery by name (e.g., `postgres`, `jboss`)
- Isolated network environment
- Secure inter-service communication

### File System Layout

```
/opt/XDStarClient/
├── xsd/              # XML Schema files
├── uploadedFiles/    # Registered/uploaded files
├── tmp/              # Temporary upload directory
└── attachments/      # Attachment storage

/opt/jboss/
├── standalone/
│   ├── deployments/  # Application deployments
│   └── configuration/ # JBoss configuration
└── modules/          # JBoss modules (PostgreSQL driver)
```

## Requirements (from Official Documentation)

Based on the [official installation guide](https://connectathon.ihe-catalyst.net/gazelle-documentation/XDStar-Client/installation.html):

- **OS**: Debian Squeeze or Ubuntu 12.04/14.04 64-bit (containerized)
- **Java**: JDK 1.7
- **App Server**: JBoss AS 7.2.0.Final
- **Database**: PostgreSQL 9.4
- **Datasource**: XDStarClientDS (configured automatically)
- **Default URL**: http://localhost:8080/XDStarClient

## Development

### Building Custom Images

```bash
# Build with custom tags
docker-compose build --no-cache

# Build specific service
docker-compose build jboss
```

### Modifying Configuration

1. **JBoss Configuration**: Edit `standalone.xml` (if provided) or `datasource-config.cli`
2. **Database Initialization**: Edit `init-db.sql`
3. **Startup Behavior**: Edit `start-jboss.sh`
4. **Environment**: Edit `.env`

### Adding Custom Modules

To add custom JBoss modules:

```bash
# Copy module to container
docker cp my-module.jar gazelle-jboss:/opt/jboss/modules/

# Restart JBoss
docker-compose restart jboss
```

## Security Considerations

- Change default passwords in `.env` before production use
- Use strong passwords for `POSTGRES_PASSWORD` and `JBOSS_ADMIN_PASSWORD`
- Consider using Docker secrets for sensitive data in production
- Restrict network access using firewall rules
- Keep base images updated with security patches

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

This Docker setup is provided as-is for running Gazelle XDStarClient. Please refer to the official Gazelle documentation for licensing information about the XDStarClient application itself.

## References

- [Official Gazelle XDStarClient Installation Guide](https://connectathon.ihe-catalyst.net/gazelle-documentation/XDStar-Client/installation.html)
- [IHE Catalyst Connectathon](https://connectathon.ihe-catalyst.net/)
- [JBoss AS 7 Documentation](https://docs.jboss.org/author/display/AS7/Documentation)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/9.4/)

## Testing and Validation

See [TESTING.md](TESTING.md) for:
- Configuration validation results
- Testing checklist
- Expected behavior and log output
- Known limitations and potential issues
- Manual testing commands

All configuration files have been validated for syntax correctness. Runtime testing requires a Docker installation.

## Support

For issues related to:
- **This Docker setup**: Open an issue in this repository
- **Gazelle XDStarClient**: Refer to official IHE Catalyst documentation
- **Docker/Docker Compose**: See Docker documentation

## Changelog

### Version 1.0.0
- Initial Docker Compose setup
- PostgreSQL 9.4 database
- JBoss AS 7.2.0 with OpenJDK 7
- Automated datasource configuration
- Health checks and monitoring
- Persistent volume management
