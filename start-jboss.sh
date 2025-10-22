#!/bin/bash
set -e

echo "Starting Gazelle XDStarClient on JBoss AS 7.2.0..."

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
until PGPASSWORD=${POSTGRES_PASSWORD} psql -h ${POSTGRES_HOST} -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c '\q' 2>/dev/null; do
  echo "PostgreSQL is unavailable - sleeping"
  sleep 2
done
echo "PostgreSQL is ready!"

# Create PostgreSQL module directory structure if it doesn't exist
mkdir -p ${JBOSS_HOME}/modules/org/postgresql/main

# Create module.xml for PostgreSQL driver if it doesn't exist
if [ ! -f "${JBOSS_HOME}/modules/org/postgresql/main/module.xml" ]; then
  echo "Creating PostgreSQL module configuration..."
  cat > ${JBOSS_HOME}/modules/org/postgresql/main/module.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<module xmlns="urn:jboss:module:1.1" name="org.postgresql">
    <resources>
        <resource-root path="postgresql-9.4-1206-jdbc41.jar"/>
    </resources>
    <dependencies>
        <module name="javax.api"/>
        <module name="javax.transaction.api"/>
    </dependencies>
</module>
EOF
fi

# Move PostgreSQL JDBC driver to module directory if not already there
if [ -f "${JBOSS_HOME}/standalone/deployments/postgresql-9.4-1206-jdbc41.jar" ] && [ ! -f "${JBOSS_HOME}/modules/org/postgresql/main/postgresql-9.4-1206-jdbc41.jar" ]; then
  mv ${JBOSS_HOME}/standalone/deployments/postgresql-9.4-1206-jdbc41.jar ${JBOSS_HOME}/modules/org/postgresql/main/
fi

# Configure datasource if not already configured
if ! grep -q "XDStarClientDS" ${JBOSS_HOME}/standalone/configuration/standalone.xml; then
  echo "Configuring XDStarClientDS datasource..."
  ${JBOSS_HOME}/bin/jboss-cli.sh --file=/opt/jboss/datasource-config.cli
fi

# Start JBoss in standalone mode
echo "Starting JBoss AS 7.2.0..."
exec ${JBOSS_HOME}/bin/standalone.sh -b 0.0.0.0 -bmanagement 0.0.0.0
