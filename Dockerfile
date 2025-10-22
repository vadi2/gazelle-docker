# Dockerfile for Gazelle XDStarClient with JBoss 7.2.0 and JDK 1.7
FROM debian:jessie

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    curl \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Install OpenJDK 7
RUN apt-get update && apt-get install -y openjdk-7-jdk \
    && rm -rf /var/lib/apt/lists/*

# Set JAVA_HOME
ENV JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64
ENV PATH=$JAVA_HOME/bin:$PATH

# Download and install JBoss AS 7.2.0.Final
WORKDIR /opt
RUN wget https://download.jboss.org/jbossas/7.1/jboss-as-7.2.0.Final/jboss-as-7.2.0.Final.zip \
    && unzip jboss-as-7.2.0.Final.zip \
    && rm jboss-as-7.2.0.Final.zip \
    && mv jboss-as-7.2.0.Final jboss

# Set JBoss environment variables
ENV JBOSS_HOME=/opt/jboss
ENV JBOSS7_HOME=/opt/jboss
ENV PATH=$JBOSS_HOME/bin:$PATH

# Create XDStarClient directories
RUN mkdir -p /opt/XDStarClient/xsd \
    /opt/XDStarClient/uploadedFiles \
    /opt/XDStarClient/tmp \
    /opt/XDStarClient/attachments

# Create JBoss admin user (will be overridden by environment variables)
RUN ${JBOSS_HOME}/bin/add-user.sh --silent admin admin123

# Copy configuration files
COPY datasource-config.cli /opt/jboss/datasource-config.cli

# Download PostgreSQL JDBC driver
RUN wget https://jdbc.postgresql.org/download/postgresql-9.4-1206-jdbc41.jar \
    -O ${JBOSS_HOME}/standalone/deployments/postgresql-9.4-1206-jdbc41.jar

# Download XDStarClient.ear from Gazelle Nexus repository
# Maven coordinates: net.ihe.gazelle.xdstar:XDStarClient:3.1.0
# Try multiple possible artifact names (XDStarClient-ear or XDStarClient)
ARG XDSTARCLIENT_VERSION=3.1.0
RUN wget https://gazelle.ihe.net/nexus/service/local/repositories/releases/content/net/ihe/gazelle/xdstar/XDStarClient-ear/${XDSTARCLIENT_VERSION}/XDStarClient-ear-${XDSTARCLIENT_VERSION}.ear \
    -O ${JBOSS_HOME}/standalone/deployments/XDStarClient.ear || \
    wget https://gazelle.ihe.net/nexus/service/local/repositories/releases/content/net/ihe/gazelle/xdstar/XDStarClient/${XDSTARCLIENT_VERSION}/XDStarClient-${XDSTARCLIENT_VERSION}.ear \
    -O ${JBOSS_HOME}/standalone/deployments/XDStarClient.ear || \
    echo "Warning: Could not download XDStarClient.ear automatically. Please place it manually in deployments/ directory."

# Copy startup script
COPY start-jboss.sh /opt/jboss/start-jboss.sh
RUN chmod +x /opt/jboss/start-jboss.sh

# Expose ports
# 8080 - HTTP
# 9990 - Management console
EXPOSE 8080 9990

WORKDIR /opt/jboss

# Start JBoss
CMD ["/opt/jboss/start-jboss.sh"]
