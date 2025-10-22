# Dockerfile for Gazelle XDStar-Client on JBoss 7.2.0.Final with JDK 1.7
FROM ubuntu:14.04

# Set environment variables
ENV JBOSS_VERSION=7.2.0.Final \
    JBOSS_HOME=/opt/jboss-as-7.2.0.Final \
    JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64 \
    XDSTAR_HOME=/opt/XDStarClient \
    DEBIAN_FRONTEND=noninteractive

# Install required packages
RUN apt-get update && \
    apt-get install -y \
    openjdk-7-jdk \
    wget \
    curl \
    unzip \
    postgresql-client \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Download and install JBoss AS 7.2.0.Final
RUN cd /opt && \
    wget -q https://download.jboss.org/jbossas/7.1/jboss-as-7.2.0.Final/jboss-as-7.2.0.Final.tar.gz && \
    tar -xzf jboss-as-7.2.0.Final.tar.gz && \
    rm jboss-as-7.2.0.Final.tar.gz

# Create XDStarClient directories
RUN mkdir -p ${XDSTAR_HOME}/uploadedFiles && \
    mkdir -p ${XDSTAR_HOME}/tmp && \
    mkdir -p ${XDSTAR_HOME}/attachments && \
    mkdir -p ${JBOSS_HOME}/standalone/deployments && \
    mkdir -p ${JBOSS_HOME}/modules/system/layers/base/org/postgresql/main

# Download PostgreSQL JDBC driver
RUN cd ${JBOSS_HOME}/modules/system/layers/base/org/postgresql/main && \
    wget -q https://jdbc.postgresql.org/download/postgresql-9.4-1206-jdbc41.jar && \
    mv postgresql-9.4-1206-jdbc41.jar postgresql-9.4.jar

# Create PostgreSQL module.xml
RUN echo '<?xml version="1.0" encoding="UTF-8"?>' > ${JBOSS_HOME}/modules/system/layers/base/org/postgresql/main/module.xml && \
    echo '<module xmlns="urn:jboss:module:1.1" name="org.postgresql">' >> ${JBOSS_HOME}/modules/system/layers/base/org/postgresql/main/module.xml && \
    echo '    <resources>' >> ${JBOSS_HOME}/modules/system/layers/base/org/postgresql/main/module.xml && \
    echo '        <resource-root path="postgresql-9.4.jar"/>' >> ${JBOSS_HOME}/modules/system/layers/base/org/postgresql/main/module.xml && \
    echo '    </resources>' >> ${JBOSS_HOME}/modules/system/layers/base/org/postgresql/main/module.xml && \
    echo '    <dependencies>' >> ${JBOSS_HOME}/modules/system/layers/base/org/postgresql/main/module.xml && \
    echo '        <module name="javax.api"/>' >> ${JBOSS_HOME}/modules/system/layers/base/org/postgresql/main/module.xml && \
    echo '        <module name="javax.transaction.api"/>' >> ${JBOSS_HOME}/modules/system/layers/base/org/postgresql/main/module.xml && \
    echo '    </dependencies>' >> ${JBOSS_HOME}/modules/system/layers/base/org/postgresql/main/module.xml && \
    echo '</module>' >> ${JBOSS_HOME}/modules/system/layers/base/org/postgresql/main/module.xml

# Copy startup script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Expose ports
# 8080: HTTP
# 9990: Management Console
EXPOSE 8080 9990

# Set working directory
WORKDIR ${JBOSS_HOME}

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

# Start JBoss
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["standalone"]
