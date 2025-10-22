# Gazelle XDStar-Client Docker Setup

Docker Compose setup for running IHE Gazelle XDStar-Client application based on the official installation documentation.

## Overview

This repository provides a complete Docker-based deployment for Gazelle XDStar-Client, an IHE testing tool. The setup includes:

- **PostgreSQL 9.4** - Database server with pre-configured `xdstar-client` database
- **JBoss AS 7.2.0.Final** - Application server with JDK 1.7
- **XDStarClient Application** - Ready for deployment

## Architecture

```
┌─────────────────────────────────────┐
│   Gazelle XDStar-Client Setup       │
├─────────────────────────────────────┤
│                                     │
│  ┌──────────────┐  ┌─────────────┐ │
│  │    JBoss     │  │ PostgreSQL  │ │
│  │  AS 7.2.0    │──│     9.4     │ │
│  │  (port 8080) │  │ (port 5432) │ │
│  └──────────────┘  └─────────────┘ │
│         │                           │
│    Application Data                 │
│    - uploadedFiles                  │
│    - tmp                            │
│    - attachments                    │
└─────────────────────────────────────┘
```

## Prerequisites

- Docker Engine 20.10+
- Docker Compose 1.29+
- At least 4GB of available RAM
- XDStarClient.ear file (see Deployment section)

## Quick Start

### 1. Clone the Repository

```bash
git clone <repository-url>
cd gazelle-docker
```

### 2. Environment Configuration

Copy the example environment file and customize if needed:

```bash
cp .env.example .env
```

### 3. Obtain the Application EAR File

You need to obtain `XDStarClient.ear`. You can either:

- **Download** from IHE's official source (if available)
- **Build from source** following the official documentation

Place the EAR file in the `deployments/` directory:

```bash
cp /path/to/XDStarClient.ear ./deployments/
```

### 4. Configure JBoss (First Time Setup)

The first time you run the setup, you need to configure the JBoss datasource:

#### Option A: Automated Configuration (Recommended)

Start the containers and extract the default configuration:

```bash
# Start only the database first
docker-compose up -d postgres

# Build the JBoss image
docker-compose build jboss

# Start JBoss temporarily
docker-compose up -d jboss

# Wait for JBoss to fully start (about 30 seconds)
sleep 30

# Copy the default standalone.xml
docker cp gazelle-jboss:/opt/jboss-as-7.2.0.Final/standalone/configuration/standalone.xml ./jboss-config/

# Stop the container
docker-compose stop jboss
```

Now edit `./jboss-config/standalone.xml`:

1. Find the `<datasources>` section
2. Add the XDStarClient datasource before `</datasources>`:

```xml
<datasource jndi-name="java:/XDStarClientDS" pool-name="XDStarClientDS" enabled="true" use-java-context="true">
    <connection-url>jdbc:postgresql://postgres:5432/xdstar-client</connection-url>
    <driver>postgresql</driver>
    <security>
        <user-name>gazelle</user-name>
        <password>gazelle</password>
    </security>
    <validation>
        <valid-connection-checker class-name="org.jboss.jca.adapters.jdbc.extensions.postgres.PostgreSQLValidConnectionChecker"/>
        <exception-sorter class-name="org.jboss.jca.adapters.jdbc.extensions.postgres.PostgreSQLExceptionSorter"/>
    </validation>
</datasource>
```

3. Find the `<drivers>` section and add:

```xml
<driver name="postgresql" module="org.postgresql">
    <xa-datasource-class>org.postgresql.xa.PGXADataSource</xa-datasource-class>
</driver>
```

4. Save the file

#### Option B: Use JBoss CLI (Advanced)

You can also configure the datasource using JBoss CLI after the container is running.

### 5. Start All Services

```bash
docker-compose up -d
```

### 6. Verify Deployment

Monitor the logs to ensure successful deployment:

```bash
# View all logs
docker-compose logs -f

# View only JBoss logs
docker-compose logs -f jboss

# View only PostgreSQL logs
docker-compose logs -f postgres
```

Wait for the message indicating successful deployment. You should see:
- PostgreSQL: `database system is ready to accept connections`
- JBoss: `JBoss AS 7.2.0.Final "Janus" started`
- Application: `XDStarClient.ear deployed`

### 7. Access the Application

Once deployed, access the application at:

- **XDStar-Client Application**: http://localhost:8080/XDStarClient
- **JBoss Management Console**: http://localhost:9990

## Directory Structure

```
gazelle-docker/
├── docker-compose.yml          # Main orchestration file
├── Dockerfile                  # JBoss + JDK 1.7 image
├── docker-entrypoint.sh        # JBoss startup script
├── .env.example                # Environment variables template
├── .gitignore                  # Git ignore rules
├── README.md                   # This file
├── deployments/                # Place XDStarClient.ear here
│   └── README.md
├── init-db/                    # PostgreSQL initialization scripts
│   └── 01-init-database.sql
└── jboss-config/               # JBoss configuration
    └── standalone.xml.template # Configuration reference
```

## Volumes

The setup uses Docker volumes for data persistence:

- `postgres-data` - PostgreSQL database files
- `xdstar-uploads` - Uploaded files from the application
- `xdstar-tmp` - Temporary files
- `xdstar-attachments` - Application attachments
- `jboss-logs` - JBoss server logs

## Configuration

### Database Configuration

Edit the `.env` file to modify database settings:

```env
POSTGRES_DB=xdstar-client
POSTGRES_USER=gazelle
POSTGRES_PASSWORD=gazelle
```

**Security Note**: Change the default password in production environments!

### JBoss Memory Configuration

Adjust Java memory settings in `.env`:

```env
JAVA_OPTS=-Xms512m -Xmx2048m -XX:MaxPermSize=512m
```

### Port Configuration

Default ports can be changed in `docker-compose.yml`:

- `8080` - HTTP (Application)
- `9990` - JBoss Management Console
- `5432` - PostgreSQL

## Common Operations

### Start Services

```bash
docker-compose up -d
```

### Stop Services

```bash
docker-compose down
```

### Restart Services

```bash
docker-compose restart
```

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f jboss
docker-compose logs -f postgres
```

### Redeploy Application

```bash
# Stop services
docker-compose down

# Replace the EAR file
cp /path/to/new/XDStarClient.ear ./deployments/

# Start services
docker-compose up -d
```

### Access PostgreSQL Database

```bash
docker-compose exec postgres psql -U gazelle -d xdstar-client
```

### Execute JBoss CLI

```bash
docker-compose exec jboss /opt/jboss-as-7.2.0.Final/bin/jboss-cli.sh --connect
```

### Backup Database

```bash
docker-compose exec postgres pg_dump -U gazelle xdstar-client > backup.sql
```

### Restore Database

```bash
docker-compose exec -T postgres psql -U gazelle xdstar-client < backup.sql
```

## Troubleshooting

### Application Won't Start

1. Check JBoss logs:
   ```bash
   docker-compose logs jboss
   ```

2. Verify the EAR file exists:
   ```bash
   ls -la deployments/
   ```

3. Check for deployment markers:
   ```bash
   ls -la deployments/*.{deployed,failed}
   ```

### Database Connection Issues

1. Verify PostgreSQL is running:
   ```bash
   docker-compose ps postgres
   ```

2. Test database connectivity:
   ```bash
   docker-compose exec jboss psql -h postgres -U gazelle -d xdstar-client
   ```

3. Check datasource configuration in `jboss-config/standalone.xml`

### Out of Memory Errors

Increase Java heap size in `.env`:

```env
JAVA_OPTS=-Xms1024m -Xmx4096m -XX:MaxPermSize=1024m
```

Then restart:
```bash
docker-compose restart jboss
```

### Port Conflicts

If ports 8080, 9990, or 5432 are already in use, modify them in `docker-compose.yml`:

```yaml
ports:
  - "8081:8080"  # Change host port to 8081
```

## Building from Source

To build XDStarClient from source:

1. Clone the source repository from IHE's GitLab
2. Compile using Maven with production profile:
   ```bash
   mvn clean install -Pproduction
   ```
3. The EAR file will be in the `target/` directory
4. Copy it to `deployments/`

## Production Deployment

For production use, consider these additional steps:

1. **Change Default Passwords**
   - Update PostgreSQL password in `.env`
   - Update datasource password in `jboss-config/standalone.xml`

2. **Enable HTTPS**
   - Configure SSL certificates in JBoss
   - Add reverse proxy (nginx/Apache) for SSL termination

3. **Resource Limits**
   - Add resource constraints in `docker-compose.yml`:
   ```yaml
   deploy:
     resources:
       limits:
         cpus: '2'
         memory: 4G
   ```

4. **Backup Strategy**
   - Implement automated database backups
   - Backup application data volumes

5. **Monitoring**
   - Add health check endpoints
   - Integrate with monitoring tools (Prometheus, Grafana)

## Technical Specifications

Based on [Gazelle XDStar-Client Installation Documentation](https://connectathon.ihe-catalyst.net/gazelle-documentation/XDStar-Client/installation.html):

- **PostgreSQL Version**: 9.4
- **JBoss Version**: AS 7.2.0.Final
- **Java Version**: JDK 1.7
- **Database Name**: xdstar-client
- **Datasource JNDI**: java:/XDStarClientDS
- **Application Version**: 3.1.1 (as per documentation)

## References

- [Official Installation Documentation](https://connectathon.ihe-catalyst.net/gazelle-documentation/XDStar-Client/installation.html)
- [User Manual](https://connectathon.ihe-catalyst.net/gazelle-documentation/XDStar-Client/user.html)
- [Release Notes](https://gazelle.ihe.net/gazelle-documentation/XDStar-Client/release-note.html)
- [IHE Gazelle Portal](https://gazelle.ihe.net/)

## License

This Docker setup is provided as-is. XDStar-Client is licensed under Apache 2.0 by IHE.

## Support

For issues related to:
- **Docker setup**: Open an issue in this repository
- **XDStar-Client application**: Refer to [IHE Gazelle documentation](https://gazelle.ihe.net/)
- **IHE Connectathon**: Visit [IHE Connectathon portal](https://connectathon.ihe-catalyst.net/)

## Contributing

Contributions are welcome! Please submit pull requests or open issues for improvements.
