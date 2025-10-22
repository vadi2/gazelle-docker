#!/bin/bash
# Script to download XDStarClient.ear from Gazelle Nexus repository
# This script attempts to download the latest or specified version of XDStarClient.ear

set -e

VERSION=${1:-"3.1.0"}
NEXUS_BASE="https://gazelle.ihe.net/nexus/service/local/repositories/releases/content"
GROUP_PATH="net/ihe/gazelle/xdstar"
ARTIFACT="XDStarClient-ear"
OUTPUT_DIR="./deployments"

# Maven coordinates: net.ihe.gazelle.xdstar:XDStarClient:3.1.0
MAVEN_GROUP="net.ihe.gazelle.xdstar"
MAVEN_ARTIFACT="XDStarClient"

echo "XDStarClient.ear Download Script"
echo "================================="
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

if [ "$VERSION" == "LATEST" ]; then
    echo "Attempting to download the latest version (defaulting to 3.1.0)..."
    VERSION="3.1.0"
    echo ""
    echo "Note: This requires access to Gazelle Nexus repository."
    echo "If you don't have access, you have the following options:"
    echo ""
    echo "1. Use the installation script from Gazelle Jenkins:"
    echo "   wget https://gazelle.ihe.net/jenkins/job/XDStarClient/ws/install_xdstar_client.sh"
    echo ""
    echo "2. Download from Jenkins artifacts (if available):"
    echo "   Check: https://gazelle.ihe.net/jenkins/job/XDStarClient/lastSuccessfulBuild/artifact/"
    echo ""
    echo "3. Build from source using Maven:"
    echo "   - Clone the source repository"
    echo "   - Run: mvn clean install -Pproduction"
    echo "   - Find EAR in: XDStarClient-ear/target/XDStarClient.ear"
    echo ""
    echo "4. Contact IHE Gazelle team for access"
    echo ""

fi

# Try to download specific version
echo "Attempting to download version $VERSION..."
echo ""

# Try XDStarClient-ear artifact first
ARTIFACT_URL1="$NEXUS_BASE/$GROUP_PATH/XDStarClient-ear/$VERSION/XDStarClient-ear-$VERSION.ear"
ARTIFACT_URL2="$NEXUS_BASE/$GROUP_PATH/XDStarClient/$VERSION/XDStarClient-$VERSION.ear"

echo "Trying URL 1: $ARTIFACT_URL1"

DOWNLOAD_SUCCESS=0

if command -v wget &> /dev/null; then
    if wget -O "$OUTPUT_DIR/XDStarClient.ear" "$ARTIFACT_URL1" 2>/dev/null; then
        DOWNLOAD_SUCCESS=1
    else
        echo "  Failed. Trying alternative URL..."
        echo "Trying URL 2: $ARTIFACT_URL2"
        if wget -O "$OUTPUT_DIR/XDStarClient.ear" "$ARTIFACT_URL2" 2>/dev/null; then
            DOWNLOAD_SUCCESS=1
        fi
    fi
elif command -v curl &> /dev/null; then
    if curl -f -L -o "$OUTPUT_DIR/XDStarClient.ear" "$ARTIFACT_URL1" 2>/dev/null; then
        DOWNLOAD_SUCCESS=1
    else
        echo "  Failed. Trying alternative URL..."
        echo "Trying URL 2: $ARTIFACT_URL2"
        if curl -f -L -o "$OUTPUT_DIR/XDStarClient.ear" "$ARTIFACT_URL2" 2>/dev/null; then
            DOWNLOAD_SUCCESS=1
        fi
    fi
else
    echo "Neither wget nor curl found. Cannot download."
    exit 1
fi

if [ $DOWNLOAD_SUCCESS -eq 0 ]; then
    echo ""
    echo "Download failed from both URLs."
    echo "Please use one of the manual methods listed above."
    exit 1
fi

if [ -f "$OUTPUT_DIR/XDStarClient.ear" ]; then
    echo ""
    echo "✓ XDStarClient.ear downloaded successfully to $OUTPUT_DIR/"
    echo ""
    echo "You can now build and deploy with:"
    echo "  make build"
    echo "  make up"
    echo "  make deploy"
else
    echo ""
    echo "✗ Download failed."
    echo ""
    echo "Manual download options:"
    echo "========================"
    echo ""
    echo "Option 1: Use Gazelle web interface"
    echo "  - Visit: https://gazelle.ihe.net/nexus"
    echo "  - Search for: XDStarClient-ear"
    echo "  - Download the EAR file"
    echo "  - Place in: $OUTPUT_DIR/"
    echo ""
    echo "Option 2: Contact IHE Support"
    echo "  - Email: gazelle-support@ihe-europe.net"
    echo "  - Request access to XDStarClient artifacts"
    echo ""
    echo "Option 3: Build from source"
    echo "  - Contact IHE Gazelle team for repository access"
    echo "  - Build with: mvn clean install -Pproduction"
    exit 1
fi
