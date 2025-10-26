# Dockerfile for Gazelle XDStarClient with JBoss AS 7.1.1 and JDK 1.7
FROM debian:jessie

# Update sources to use Debian archive (Jessie is EOL)
RUN echo "deb http://archive.debian.org/debian/ jessie main" > /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian-security/ jessie/updates main" >> /etc/apt/sources.list && \
    echo "Acquire::Check-Valid-Until false;" > /etc/apt/apt.conf.d/99no-check-valid-until

# Install dependencies
RUN apt-get update && apt-get install -y --allow-unauthenticated \
    wget \
    unzip \
    zip \
    curl \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Install OpenJDK 7
RUN apt-get update && apt-get install -y --allow-unauthenticated openjdk-7-jdk \
    && rm -rf /var/lib/apt/lists/*

# Set JAVA_HOME
ENV JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64
ENV PATH=$JAVA_HOME/bin:$PATH

# Download and install JBoss AS 7.1.1.Final (7.2.0 binaries not officially available)
WORKDIR /opt
RUN wget https://sourceforge.net/projects/liferayarchi/files/Install/jboss-as-7.1.1.Final.tar.gz/download -O jboss-as-7.1.1.Final.tar.gz \
    && tar -xzf jboss-as-7.1.1.Final.tar.gz \
    && rm jboss-as-7.1.1.Final.tar.gz \
    && mv jboss-as-7.1.1.Final jboss

# Set JBoss environment variables
ENV JBOSS_HOME=/opt/jboss
ENV JBOSS7_HOME=/opt/jboss
ENV PATH=$JBOSS_HOME/bin:$PATH

# Fix XML parser issue by upgrading jboss-modules from 1.1.1.GA to 1.1.5.GA
# This resolves __redirected.__SAXParserFactory NullPointerException with OpenJDK 7
RUN wget https://repo1.maven.org/maven2/org/jboss/modules/jboss-modules/1.1.5.GA/jboss-modules-1.1.5.GA.jar \
    -O ${JBOSS_HOME}/jboss-modules.jar

# Create XDStarClient directories
RUN mkdir -p /opt/XDStarClient/xsd \
    /opt/XDStarClient/uploadedFiles \
    /opt/XDStarClient/tmp \
    /opt/XDStarClient/attachments

# Copy configuration files
COPY datasource-config.cli /opt/jboss/datasource-config.cli

# Download PostgreSQL JDBC driver and configure as JBoss module
# Note: The JDBC driver must be installed as a JBoss module, not deployed as a regular JAR
RUN mkdir -p ${JBOSS_HOME}/modules/org/postgresql/main && \
    wget https://jdbc.postgresql.org/download/postgresql-9.4-1206-jdbc41.jar \
    -O ${JBOSS_HOME}/modules/org/postgresql/main/postgresql-9.4-1206-jdbc41.jar && \
    echo '<?xml version="1.0" encoding="UTF-8"?>' > ${JBOSS_HOME}/modules/org/postgresql/main/module.xml && \
    echo '<module xmlns="urn:jboss:module:1.1" name="org.postgresql">' >> ${JBOSS_HOME}/modules/org/postgresql/main/module.xml && \
    echo '    <resources>' >> ${JBOSS_HOME}/modules/org/postgresql/main/module.xml && \
    echo '        <resource-root path="postgresql-9.4-1206-jdbc41.jar"/>' >> ${JBOSS_HOME}/modules/org/postgresql/main/module.xml && \
    echo '    </resources>' >> ${JBOSS_HOME}/modules/org/postgresql/main/module.xml && \
    echo '    <dependencies>' >> ${JBOSS_HOME}/modules/org/postgresql/main/module.xml && \
    echo '        <module name="javax.api"/>' >> ${JBOSS_HOME}/modules/org/postgresql/main/module.xml && \
    echo '        <module name="javax.transaction.api"/>' >> ${JBOSS_HOME}/modules/org/postgresql/main/module.xml && \
    echo '    </dependencies>' >> ${JBOSS_HOME}/modules/org/postgresql/main/module.xml && \
    echo '</module>' >> ${JBOSS_HOME}/modules/org/postgresql/main/module.xml && \
    echo "PostgreSQL module created successfully:" && \
    ls -la ${JBOSS_HOME}/modules/org/postgresql/main/

# Download XDStarClient.ear from Gazelle Nexus repository
# Maven coordinates: net.ihe.gazelle.xdstar:XDStarClient-ear:3.1.0
ARG XDSTARCLIENT_VERSION=3.1.0
RUN wget https://gazelle.ihe.net/nexus/content/repositories/releases/net/ihe/gazelle/xdstar/XDStarClient-ear/${XDSTARCLIENT_VERSION}/XDStarClient-ear-${XDSTARCLIENT_VERSION}.ear \
    -O ${JBOSS_HOME}/standalone/deployments/XDStarClient.ear || \
    echo "Warning: Could not download XDStarClient.ear automatically. Please place it manually in deployments/ directory."

# Remove the M2M SSO client JARs, update jboss-deployment-structure.xml, add components.xml, and repackage
RUN cd ${JBOSS_HOME}/standalone/deployments && \
    unzip -q XDStarClient.ear -d XDStarClient-temp && \
    cd XDStarClient-temp && \
    echo "Files before removal:" && ls -la *.jar | head -5 && \
    rm -v mbval-documentation-ejb.jar || echo "mbval JAR not found at root" && \
    echo "Files after removal:" && ls -la *.jar | head -5 && \
    sed -i ':a;N;$!ba;s|<module>[[:space:]]*<ejb>mbval-documentation-ejb.jar</ejb>[[:space:]]*</module>||g' META-INF/application.xml && \
    echo "Removed mbval module from application.xml" && \
    cd lib && \
    rm -fv m2m-v7-*.jar sso-*-v7-*.jar cas-client-v7-*.jar && \
    mkdir -p /tmp/usercontext-stub/net/ihe/gazelle/users && \
    echo 'package net.ihe.gazelle.users; public interface UserContext {}' > /tmp/usercontext-stub/net/ihe/gazelle/users/UserContext.java && \
    cd /tmp/usercontext-stub && \
    javac net/ihe/gazelle/users/UserContext.java && \
    jar cf ../usercontext-stub.jar net/ihe/gazelle/users/UserContext.class && \
    mv /tmp/usercontext-stub.jar ${JBOSS_HOME}/standalone/deployments/XDStarClient-temp/lib/ && \
    rm -rf /tmp/usercontext-stub && \
    mkdir -p /tmp/viewclassmanager-stub/net/ihe/gazelle/action && \
    mkdir -p /tmp/viewclassmanager-stub/net/ihe/gazelle/metamodel && \
    echo 'package net.ihe.gazelle.action; public abstract class ViewClassManager implements java.io.Serializable { public ViewClassManager() {} public abstract net.ihe.gazelle.metamodel.ClassesModel getAvailableClasses(); }' > /tmp/viewclassmanager-stub/net/ihe/gazelle/action/ViewClassManager.java && \
    echo 'package net.ihe.gazelle.metamodel; public class ClassesModel implements java.io.Serializable { public ClassesModel() {} }' > /tmp/viewclassmanager-stub/net/ihe/gazelle/metamodel/ClassesModel.java && \
    cd /tmp/viewclassmanager-stub && \
    javac net/ihe/gazelle/metamodel/ClassesModel.java && \
    javac net/ihe/gazelle/action/ViewClassManager.java && \
    jar cf ../viewclassmanager-stub.jar net/ihe/gazelle/action/ViewClassManager.class net/ihe/gazelle/metamodel/ClassesModel.class && \
    mv /tmp/viewclassmanager-stub.jar ${JBOSS_HOME}/standalone/deployments/XDStarClient-temp/lib/ && \
    rm -rf /tmp/viewclassmanager-stub && \
    cd ${JBOSS_HOME}/standalone/deployments/XDStarClient-temp && \
    echo '<jboss-deployment-structure>' > META-INF/jboss-deployment-structure.xml && \
    echo '	<ear-subdeployments-isolated>false</ear-subdeployments-isolated>' >> META-INF/jboss-deployment-structure.xml && \
    echo '	<deployment>' >> META-INF/jboss-deployment-structure.xml && \
    echo '		<dependencies>' >> META-INF/jboss-deployment-structure.xml && \
    echo '			<module name = "org.dom4j" export = "true" />' >> META-INF/jboss-deployment-structure.xml && \
    echo '			<module name = "org.apache.commons.collections" export = "true" />' >> META-INF/jboss-deployment-structure.xml && \
    echo '			<module name = "org.apache.commons.codec" export = "true" />' >> META-INF/jboss-deployment-structure.xml && \
    echo '			<module name = "org.apache.commons.beanutils" export = "true" />' >> META-INF/jboss-deployment-structure.xml && \
    echo '			<module name = "javax.faces.api" export = "true" />' >> META-INF/jboss-deployment-structure.xml && \
    echo '			<module name = "com.sun.jsf-impl" export = "true" />' >> META-INF/jboss-deployment-structure.xml && \
    echo '			<module name = "org.hibernate" export = "true" />' >> META-INF/jboss-deployment-structure.xml && \
    echo '			<module name = "org.infinispan" export = "true" />' >> META-INF/jboss-deployment-structure.xml && \
    echo '			<module name = "org.hibernate.validator" export = "true" />' >> META-INF/jboss-deployment-structure.xml && \
    echo '			<module name = "org.postgresql" export = "true" />' >> META-INF/jboss-deployment-structure.xml && \
    echo '			<module name = "org.apache.xerces" export = "true"/>' >> META-INF/jboss-deployment-structure.xml && \
    echo '			<module name = "org.jaxen" export = "true"/>' >> META-INF/jboss-deployment-structure.xml && \
    echo '			<module name="asm.asm" export="true"/>' >> META-INF/jboss-deployment-structure.xml && \
    echo '		</dependencies>' >> META-INF/jboss-deployment-structure.xml && \
    echo '	</deployment>' >> META-INF/jboss-deployment-structure.xml && \
    echo '</jboss-deployment-structure>' >> META-INF/jboss-deployment-structure.xml && \
    echo '<?xml version="1.0" encoding="UTF-8"?>' > components.xml && \
    echo '<components xmlns="http://jboss.com/products/seam/components"' >> components.xml && \
    echo '            xmlns:core="http://jboss.com/products/seam/core"' >> components.xml && \
    echo '            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"' >> components.xml && \
    echo '            xsi:schemaLocation="http://jboss.com/products/seam/components http://jboss.com/products/seam/components-2.3.xsd' >> components.xml && \
    echo '                                http://jboss.com/products/seam/core http://jboss.com/products/seam/core-2.3.xsd">' >> components.xml && \
    echo '    <!-- Configure JNDI pattern for JBoss AS 7 -->' >> components.xml && \
    echo '    <core:init jndi-pattern="java:app/#{ejbJarSimpleName}/#{ejbName}"/>' >> components.xml && \
    echo '    <!-- Disable SSO and optional components for standalone deployment -->' >> components.xml && \
    echo '    <component name="ssoClientRegister" installed="false"/>' >> components.xml && \
    echo '    <component name="AssertionWSProvider" installed="false"/>' >> components.xml && \
    echo '    <component name="DSUBModelBasedWS" installed="false"/>' >> components.xml && \
    echo '    <component name="WADOModelBasedWS" installed="false"/>' >> components.xml && \
    echo '    <component name="DSUBRecipientWS" installed="false"/>' >> components.xml && \
    echo '    <component name="KSAInitManager" installed="false"/>' >> components.xml && \
    echo '    <component name="ModelBasedValidationWS" installed="false"/>' >> components.xml && \
    echo '</components>' >> components.xml && \
    mkdir -p ejb-temp && \
    unzip -q XDStarClient-ejb.jar -d ejb-temp && \
    rm -fv ejb-temp/net/ihe/gazelle/xdstar/validator/ws/DSUBValidatorWS.class && \
    rm -fv ejb-temp/net/ihe/gazelle/xdstar/validator/ws/WADOValidatorWS.class && \
    rm -fv ejb-temp/net/ihe/gazelle/xdstar/validator/ws/XDSMetadataValidatorWS.class && \
    rm -fv ejb-temp/net/ihe/gazelle/xdsar/dsub/ws/DSUBRecipientWS.class && \
    rm -fv ejb-temp/net/ihe/gazelle/xdstar/testplan/action/KSAInitManager.class && \
    rm -fv ejb-temp/net/ihe/gazelle/xdstar/util/PUProviderExtended.class && \
    rm -fv ejb-temp/net/ihe/gazelle/xdstar/util/PUProviderExtendedLocal.class && \
    echo "Removed problematic validator WS, DSUB, KSA, and PUProvider classes" && \
    rm -f XDStarClient-ejb.jar && \
    cd ejb-temp && \
    jar cf ../XDStarClient-ejb.jar . && \
    cd .. && \
    rm -rf ejb-temp && \
    echo "Repacked XDStarClient-ejb.jar without problematic classes" && \
    unzip -q XDStarClient-war-*.war -d war-temp && \
    mkdir -p war-temp/WEB-INF && \
    cp components.xml war-temp/WEB-INF/ && \
    sed -i ':a;N;$!ba;s|<listener>\s*<listener-class>org.jasig.cas.client.session.SingleSignOutHttpSessionListener</listener-class>\s*</listener>||g' war-temp/WEB-INF/web.xml && \
    echo "Removed CAS listener from web.xml" && \
    sed -i 's|java:app/mbval-documentation-ejb/AssertionWSProvider,||g' war-temp/WEB-INF/web.xml && \
    echo "Removed AssertionWSProvider from resteasy.jndi.resources" && \
    cd war-temp && \
    zip -r -q ../XDStarClient-war-*.war . && \
    cd .. && \
    rm -rf war-temp components.xml && \
    cd .. && \
    rm -f XDStarClient.ear && \
    echo "Removed original EAR" && \
    cd XDStarClient-temp && \
    zip -r -q ../XDStarClient.ear . && \
    echo "Created new EAR without mbval" && \
    cd .. && \
    rm -rf XDStarClient-temp && \
    echo "Removed M2M/SSO/CAS client JARs and disabled SSO components for standalone deployment"

# Copy pre-configured standalone.xml with increased deployment timeout (300s instead of default 60s)
# This custom configuration is based on standalone-full.xml with HornetQ messaging
COPY standalone-custom.xml ${JBOSS_HOME}/standalone/configuration/standalone-custom.xml

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
