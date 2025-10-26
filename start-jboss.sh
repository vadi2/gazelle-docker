#!/bin/bash
set -e

echo "Starting Gazelle XDStarClient on JBoss AS 7.1.1..."

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
until PGPASSWORD=${POSTGRES_PASSWORD} psql -h ${POSTGRES_HOST} -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c '\q' 2>/dev/null; do
  echo "PostgreSQL is unavailable - sleeping"
  sleep 2
done
echo "PostgreSQL is ready!"

# Verify PostgreSQL module is properly configured
if [ ! -f "${JBOSS_HOME}/modules/org/postgresql/main/postgresql-9.4-1206-jdbc41.jar" ]; then
  echo "WARNING: PostgreSQL JDBC driver not found in modules directory!"
  echo "Expected location: ${JBOSS_HOME}/modules/org/postgresql/main/postgresql-9.4-1206-jdbc41.jar"
else
  echo "PostgreSQL JDBC driver found in modules directory"
fi

# Note: Skipping JBoss CLI configuration due to XML parser issues with JDK 7
# Admin user and datasource will need to be configured via the admin console after first start
echo "Note: Admin user and datasource need to be configured via the management console"
echo "Access the management console at: http://localhost:9990/console"

# Create standalone.xml from standalone-full.xml with increased deployment timeout
# Copy standalone-full.xml (which includes HornetQ messaging)
cp ${JBOSS_HOME}/standalone/configuration/standalone-full.xml ${JBOSS_HOME}/standalone/configuration/standalone.xml

# Increase deployment timeout from 60s to 300s for large EAR files (XDStarClient.ear is 94MB)
# Use Perl for reliable in-place editing
perl -i -pe 's|(<deployment-scanner[^>]+scan-interval="5000")/>|$1 deployment-timeout="300"/>|' ${JBOSS_HOME}/standalone/configuration/standalone.xml

# Verify the timeout was set
if grep -q 'deployment-timeout="300"' ${JBOSS_HOME}/standalone/configuration/standalone.xml; then
  echo "Deployment timeout set to 300 seconds"
else
  echo "WARNING: Failed to set deployment timeout!"
fi

# Increase JTA transaction timeout in standalone.xml (default is 300 seconds)
sed -i 's|<coordinator-environment>|<coordinator-environment default-timeout="600">|' ${JBOSS_HOME}/standalone/configuration/standalone.xml
echo "JTA transaction timeout set to 600 seconds"

# Add PostgreSQL datasource configuration
echo "Configuring PostgreSQL datasource..."

# Use sed to add PostgreSQL driver after the <drivers> opening tag
sed -i '/<drivers>/a\
                    <driver name="postgresql" module="org.postgresql">\
                        <xa-datasource-class>org.postgresql.xa.PGXADataSource</xa-datasource-class>\
                    </driver>' ${JBOSS_HOME}/standalone/configuration/standalone.xml

# Use a heredoc to create the datasource XML
cat > /tmp/postgres-ds.xml << EOF
                <datasource jndi-name="java:jboss/env/datasources/XDStarClientDS" pool-name="XDStarClientDS" enabled="true" use-java-context="true">
                    <connection-url>jdbc:postgresql://${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}</connection-url>
                    <driver>postgresql</driver>
                    <security>
                        <user-name>${POSTGRES_USER}</user-name>
                        <password>${POSTGRES_PASSWORD}</password>
                    </security>
                    <validation>
                        <validate-on-match>true</validate-on-match>
                        <background-validation>false</background-validation>
                    </validation>
                    <statement>
                        <prepared-statement-cache-size>32</prepared-statement-cache-size>
                        <share-prepared-statements>true</share-prepared-statements>
                    </statement>
                </datasource>
EOF

# Insert the datasource after the </datasource> closing tag of ExampleDS
sed -i '/<datasource jndi-name="java:jboss\/datasources\/ExampleDS"/,/<\/datasource>/{
    /<\/datasource>/r /tmp/postgres-ds.xml
}' ${JBOSS_HOME}/standalone/configuration/standalone.xml

# Verify datasource was added
if grep -q 'java:jboss/env/datasources/XDStarClientDS' ${JBOSS_HOME}/standalone/configuration/standalone.xml; then
  echo "PostgreSQL datasource 'XDStarClientDS' configured successfully at java:jboss/env/datasources/XDStarClientDS"
else
  echo "WARNING: Failed to configure PostgreSQL datasource!"
fi

# Create application configuration file expected by XDStarClient
# The application looks for /opt/gazelle/cas/XDStarClient.properties
echo "Creating application configuration..."
mkdir -p /opt/gazelle/cas
cat > /opt/gazelle/cas/XDStarClient.properties << EOF
# Application configuration for standalone XDStarClient deployment
# Disable CAS/SSO authentication for standalone mode
cas_enabled=false
# Allow IP-based login (optional)
ip_login=true
ip_login_admin=.*
# Database is configured via JBoss datasource
EOF
echo "Application configuration created at /opt/gazelle/cas/XDStarClient.properties"

# Start JBoss in standalone mode
# Set JAVA_OPTS to work around XML parser issues with OpenJDK 7
export JAVA_OPTS="$JAVA_OPTS -Djavax.xml.parsers.SAXParserFactory=com.sun.org.apache.xerces.internal.jaxp.SAXParserFactoryImpl"
export JAVA_OPTS="$JAVA_OPTS -Djavax.xml.parsers.DocumentBuilderFactory=com.sun.org.apache.xerces.internal.jaxp.DocumentBuilderFactoryImpl"
export JAVA_OPTS="$JAVA_OPTS -Djavax.xml.transform.TransformerFactory=com.sun.org.apache.xalan.internal.xsltc.trax.TransformerFactoryImpl"

# Increase memory and timeouts for large application
export JAVA_OPTS="$JAVA_OPTS -Xms512m -Xmx1024m -XX:MaxPermSize=512m"
# Increase JTA transaction timeout to 10 minutes
export JAVA_OPTS="$JAVA_OPTS -Dcom.arjuna.ats.arjuna.coordinator.defaultTimeout=600"

# Set Hibernate and database properties for XDStarClient
# Note: These properties are used by persistence.xml for property substitution
# The actual connection uses the JBoss datasource configured above
export JAVA_OPTS="$JAVA_OPTS -Dhibernate.dialect=org.hibernate.dialect.PostgreSQLDialect"
export JAVA_OPTS="$JAVA_OPTS -Dhibernate.hbm2ddl.auto=create"
export JAVA_OPTS="$JAVA_OPTS -Dhibernate.show_sql=true"
# Add HTTP client timeouts to make M2M fail faster
export JAVA_OPTS="$JAVA_OPTS -Dhttp.connection.timeout=5000"
export JAVA_OPTS="$JAVA_OPTS -Dhttp.socket.timeout=5000"
export JAVA_OPTS="$JAVA_OPTS -Djdbc.connection.url=jdbc:postgresql://${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}"
export JAVA_OPTS="$JAVA_OPTS -Djdbc.driver.class=org.postgresql.Driver"
export JAVA_OPTS="$JAVA_OPTS -Djdbc.user=${POSTGRES_USER}"
export JAVA_OPTS="$JAVA_OPTS -Djdbc.password=${POSTGRES_PASSWORD}"
export JAVA_OPTS="$JAVA_OPTS -Dmin.pool.size=1"
export JAVA_OPTS="$JAVA_OPTS -Dmax.pool.size=30"
export JAVA_OPTS="$JAVA_OPTS -Dseam.debug=false"
export JAVA_OPTS="$JAVA_OPTS -Dfacelets.skipcomments=true"
# Increase deployment timeout to handle slow operations
export JAVA_OPTS="$JAVA_OPTS -Djboss.as.management.blocking.timeout=600"
# Disable M2M/SSO features for standalone deployment
export JAVA_OPTS="$JAVA_OPTS -Dgazelle.m2m.enabled=false"
export JAVA_OPTS="$JAVA_OPTS -Dm2m.enabled=false"
# Make Seam components install asynchronously to avoid blocking
export JAVA_OPTS="$JAVA_OPTS -Dorg.jboss.seam.core.init.debug=false"
# Configure Seam JNDI pattern for JBoss AS 7
export JAVA_OPTS="$JAVA_OPTS -Dorg.jboss.seam.core.init.jndiPattern=#{ejbName}/no-interface"

echo "Starting JBoss AS 7.1.1 with full profile (includes messaging)..."
exec ${JBOSS_HOME}/bin/standalone.sh -b 0.0.0.0 -bmanagement 0.0.0.0
