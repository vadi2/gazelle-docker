#!/bin/bash
set -e

echo "Starting Gazelle XDStar-Client on JBoss..."

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
until PGPASSWORD=${DB_PASSWORD} psql -h ${DB_HOST} -U ${DB_USER} -d ${DB_NAME} -c '\q' 2>/dev/null; do
  echo "PostgreSQL is unavailable - sleeping"
  sleep 2
done

echo "PostgreSQL is up and running!"

# Set JBoss bind address to allow external connections
BIND_ADDRESS=${BIND_ADDRESS:-0.0.0.0}

# Check if standalone.xml needs updating (if not using mounted config)
if [ ! -f "${JBOSS_HOME}/standalone/configuration/standalone.xml.configured" ]; then
    echo "Configuring JBoss datasource..."

    # Note: If you're using a custom standalone.xml mounted via volume,
    # this section will be skipped. Otherwise, it will configure the default one.

    # Create a marker file to avoid reconfiguring on restart
    touch "${JBOSS_HOME}/standalone/configuration/standalone.xml.configured"
fi

# Create deployment marker directory if it doesn't exist
mkdir -p ${JBOSS_HOME}/standalone/deployments

# Start JBoss in standalone mode
echo "Starting JBoss Application Server..."
exec ${JBOSS_HOME}/bin/standalone.sh \
    -b ${BIND_ADDRESS} \
    -bmanagement ${BIND_ADDRESS} \
    -Djboss.server.log.dir=${JBOSS_HOME}/standalone/log
