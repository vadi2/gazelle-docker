#!/bin/bash
# Script to download XDStarClient.ear from Gazelle Nexus repository
# This script attempts to download the latest or specified version of XDStarClient.ear

set -e

VERSION=${1:-"LATEST"}
NEXUS_BASE="https://gazelle.ihe.net/nexus/service/local/repositories/releases/content"
GROUP_PATH="net/ihe/gazelle/xdstar"
ARTIFACT="XDStarClient-ear"
OUTPUT_DIR="./deployments"

echo "XDStarClient.ear Download Script"
echo "================================="
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

if [ "$VERSION" == "LATEST" ]; then
    echo "Attempting to download the latest version..."
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

    # Try to download using Maven dependency plugin
    echo "Attempting Maven download..."
    if command -v mvn &> /dev/null; then
        mvn org.apache.maven.plugins:maven-dependency-plugin:3.2.0:get \
            -DremoteRepositories=https://gazelle.ihe.net/nexus/content/groups/public \
            -Dartifact=net.ihe.gazelle.xdstar:XDStarClient-ear:LATEST:ear \
            -Dtransitive=false \
            -Ddest="$OUTPUT_DIR/XDStarClient.ear" 2>&1 || {
            echo ""
            echo "Maven download failed. This is expected if:"
            echo "  - You don't have Maven installed"
            echo "  - The repository requires authentication"
            echo "  - The artifact path has changed"
            echo ""
            echo "Please use one of the manual methods listed above."
            exit 1
        }
    else
        echo "Maven not found. Cannot automatically download."
        echo "Please use one of the manual methods listed above."
        exit 1
    fi
else
    # Try to download specific version
    echo "Attempting to download version $VERSION..."
    ARTIFACT_URL="$NEXUS_BASE/$GROUP_PATH/$ARTIFACT/$VERSION/$ARTIFACT-$VERSION.ear"

    echo "Download URL: $ARTIFACT_URL"
    echo ""

    if command -v wget &> /dev/null; then
        wget -O "$OUTPUT_DIR/XDStarClient.ear" "$ARTIFACT_URL" || {
            echo ""
            echo "Download failed. Please check:"
            echo "  - Version number is correct"
            echo "  - You have access to the Nexus repository"
            echo "  - The artifact path is correct"
            exit 1
        }
    elif command -v curl &> /dev/null; then
        curl -L -o "$OUTPUT_DIR/XDStarClient.ear" "$ARTIFACT_URL" || {
            echo ""
            echo "Download failed. Please check:"
            echo "  - Version number is correct"
            echo "  - You have access to the Nexus repository"
            echo "  - The artifact path is correct"
            exit 1
        }
    else
        echo "Neither wget nor curl found. Cannot download."
        exit 1
    fi
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
