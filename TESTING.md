# Testing and Validation Notes

## Configuration Validation

This document describes the validation performed on the Gazelle Docker setup.

### Static Analysis Results

**Date**: 2025-10-22

#### Files Validated

1. **docker-compose.yml**
   - Status: ✓ Valid YAML syntax
   - Validated using Python yaml.safe_load()
   - All service definitions properly structured
   - Health checks configured for both services
   - Volume and network definitions correct

2. **Dockerfile**
   - Status: ✓ Valid Dockerfile syntax
   - Issues fixed:
     - Removed invalid COPY command with shell redirection
     - Fixed add-user.sh parameter order
   - Base image: debian:jessie
   - Includes all required dependencies

3. **start-jboss.sh**
   - Status: ✓ Valid Bash syntax
   - Validated using `bash -n`
   - Includes proper error handling with `set -e`
   - Database connection retry logic implemented

4. **init-db.sql**
   - Status: ✓ Valid SQL syntax
   - PostgreSQL 9.4 compatible commands
   - Proper privilege grants

5. **datasource-config.cli**
   - Status: ✓ Valid JBoss CLI syntax
   - Configures XDStarClientDS datasource
   - Uses environment variables for connection parameters

6. **Makefile**
   - Status: ✓ Valid Makefile syntax
   - Updated to support both `docker-compose` and `docker compose`
   - Auto-detects available command

### Known Limitations

1. **No Runtime Testing**
   - Docker is not available in the validation environment
   - Runtime testing requires actual Docker installation
   - Configuration validated statically only

2. **XDStarClient.ear Required**
   - The actual application EAR file is not included
   - Must be obtained separately from IHE Catalyst
   - Deployment instructions provided in README

3. **Network Dependencies**
   - JBoss AS 7.2.0 download from jboss.org (line 22 in Dockerfile)
   - PostgreSQL JDBC driver download from jdbc.postgresql.org (line 46 in Dockerfile)
   - Debian Jessie apt repositories (may have SSL issues)

### Potential Issues and Solutions

#### Issue 1: Debian Jessie Repository Availability
**Problem**: Debian Jessie reached end-of-life and repositories moved to archive.debian.org

**Solution**: If build fails with repository errors, add this to Dockerfile before first apt-get:
```dockerfile
RUN sed -i 's/deb.debian.org/archive.debian.org/g' /etc/apt/sources.list && \
    sed -i 's|security.debian.org|archive.debian.org|g' /etc/apt/sources.list && \
    sed -i '/stretch-updates/d' /etc/apt/sources.list
```

#### Issue 2: OpenJDK 7 Availability
**Problem**: OpenJDK 7 is very old and may not be available in current repositories

**Solution**: Alternative base image or manual Java installation may be required
```dockerfile
# Alternative: Use adoptium/temurin images or manual installation
FROM debian:jessie
RUN wget https://cdn.azul.com/zulu/bin/zulu7.*.tar.gz
```

#### Issue 3: JBoss Download URL
**Problem**: JBoss AS 7.2.0 download URL may change or become unavailable

**Solution**: Mirror the file or use alternative download locations
- Verify URL: https://download.jboss.org/jbossas/7.1/jboss-as-7.2.0.Final/jboss-as-7.2.0.Final.zip
- Consider local file: `COPY jboss-as-7.2.0.Final.zip /opt/`

#### Issue 4: PostgreSQL JDBC Driver
**Problem**: Specific version URL may change

**Solution**:
- Current URL validated: https://jdbc.postgresql.org/download/postgresql-9.4-1206-jdbc41.jar
- Alternative: Use Maven Central or local file

### Testing Checklist

When testing this setup on a system with Docker:

- [ ] Verify Docker is installed: `docker --version`
- [ ] Verify Docker Compose is available: `docker compose version` or `docker-compose version`
- [ ] Run `make setup` to initialize environment
- [ ] Check .env file is created with correct values
- [ ] Run `make build` to build images
  - [ ] Verify JBoss AS downloads successfully
  - [ ] Verify PostgreSQL JDBC driver downloads
  - [ ] Verify OpenJDK 7 installs correctly
- [ ] Run `make up` to start services
  - [ ] Verify PostgreSQL container starts: `make status`
  - [ ] Verify PostgreSQL health check passes
  - [ ] Verify JBoss container starts
  - [ ] Check JBoss waits for PostgreSQL before starting
- [ ] Check logs: `make logs`
  - [ ] PostgreSQL: Look for "database system is ready to accept connections"
  - [ ] JBoss: Look for "Started server" or similar
- [ ] Verify datasource configuration
  - [ ] Check XDStarClientDS is created in JBoss
  - [ ] Test database connection from JBoss
- [ ] Access services:
  - [ ] PostgreSQL: `make psql` (should connect successfully)
  - [ ] JBoss Admin Console: http://localhost:9990/console
  - [ ] JBoss HTTP: http://localhost:8080/
- [ ] Deploy XDStarClient.ear (if available)
  - [ ] Place EAR in deployments/ directory
  - [ ] Run `make deploy`
  - [ ] Monitor logs for successful deployment
  - [ ] Access: http://localhost:8080/XDStarClient
- [ ] Test volume persistence
  - [ ] Create test data
  - [ ] Run `make restart`
  - [ ] Verify data persists
- [ ] Test backup/restore
  - [ ] Run `make backup`
  - [ ] Verify backup file created in backups/
  - [ ] Test restore: `make restore FILE=backups/file.sql`

### Expected Behavior

#### Successful Startup Sequence

1. PostgreSQL container starts first
2. PostgreSQL initializes database with init-db.sql
3. PostgreSQL health check passes (pg_isready)
4. JBoss container starts (depends_on condition satisfied)
5. start-jboss.sh waits for PostgreSQL connection
6. PostgreSQL module created in JBoss
7. JDBC driver moved to modules directory
8. Datasource configuration applied via CLI script
9. JBoss standalone server starts on 0.0.0.0:8080
10. Both containers report healthy status

#### Expected Log Output

**PostgreSQL:**
```
PostgreSQL init process complete; ready for start up.
database system is ready to accept connections
Database initialization completed successfully
```

**JBoss:**
```
Starting Gazelle XDStarClient on JBoss AS 7.2.0...
Waiting for PostgreSQL to be ready...
PostgreSQL is ready!
Creating PostgreSQL module configuration...
Configuring XDStarClientDS datasource...
Starting JBoss AS 7.2.0...
JBOSS_HOME: /opt/jboss
Started server in XXXms
```

### Manual Testing Commands

```bash
# Test PostgreSQL connection
docker exec gazelle-postgres psql -U gazelle -d xdstar-client -c "SELECT version();"

# Test JBoss is running
curl http://localhost:8080/

# Check JBoss admin console
curl http://localhost:9990/console

# View JBoss deployments
docker exec gazelle-jboss ls -la /opt/jboss/standalone/deployments/

# Check datasource configuration
docker exec gazelle-jboss /opt/jboss/bin/jboss-cli.sh --connect --command="/subsystem=datasources:read-resource"

# Monitor JBoss server log
docker exec gazelle-jboss tail -f /opt/jboss/standalone/log/server.log
```

### Performance Expectations

- **Build Time**: 5-10 minutes (depends on network speed for downloads)
- **Startup Time**:
  - PostgreSQL: 10-30 seconds
  - JBoss: 60-120 seconds
- **Memory Usage**:
  - PostgreSQL: ~50-100 MB
  - JBoss: ~500 MB - 1 GB
- **Disk Space**: ~2-3 GB total

### Troubleshooting Common Issues

See README.md Troubleshooting section for detailed solutions.

### Validation Summary

- ✓ All configuration files have valid syntax
- ✓ Docker Compose configuration is properly structured
- ✓ Service dependencies correctly configured
- ✓ Health checks implemented
- ✓ Persistent volumes configured
- ✓ Environment variables properly templated
- ✓ Makefile supports both docker compose variants
- ✗ Runtime testing pending (requires Docker installation)
- ✗ XDStarClient.ear deployment pending (application file required)

### Recommendations

1. **Before First Use**: Test the build on your system to ensure all download URLs work
2. **Production Use**:
   - Change all default passwords in .env
   - Use Docker secrets for sensitive data
   - Pin specific versions for all base images
   - Consider mirroring JBoss and JDBC driver files locally
3. **Maintenance**:
   - Regularly update base images for security patches
   - Monitor JBoss and PostgreSQL logs
   - Implement regular backups
   - Document any custom configuration changes

### Version Information

- Docker Compose Format: 3.8
- PostgreSQL: 9.4
- JBoss AS: 7.2.0.Final
- Java: OpenJDK 7
- Base OS: Debian Jessie

### Contact

For issues related to this Docker setup, please open an issue in the repository.
