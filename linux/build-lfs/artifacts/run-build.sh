#!/bin/bash
# LFS Build Orchestration Script
# Runs the LFS build inside Docker
#
# Usage: ./run-build.sh [stage]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[BUILD]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check for Docker
if ! command -v docker &> /dev/null; then
    error "Docker is not installed. Please install Docker first."
fi

# Build Docker image
log "Building Docker image..."
docker build -t lfs-builder .

# Create output directory
mkdir -p output

# Determine build stage
STAGE="${1:-all}"

log "Starting LFS build (stage: $STAGE)..."
echo ""

# Run the build
# --privileged is required for loop devices and chroot
docker run --rm \
    --privileged \
    -v "$(pwd)/output:/mnt/lfs/output" \
    -v "$(pwd)/build-lfs.sh:/usr/local/bin/build-lfs.sh:ro" \
    -e MAKEFLAGS="-j$(nproc)" \
    --name lfs-build \
    lfs-builder \
    /bin/bash -c "
        set -e
        echo '=== LFS Build Container Started ==='
        echo ''

        # First verify host requirements
        version-check.sh
        echo ''

        # Download packages if not already done
        if [ ! -f /mnt/lfs/sources/.download-complete ]; then
            echo 'Downloading LFS packages...'
            download-packages.sh
            touch /mnt/lfs/sources/.download-complete
        else
            echo 'Packages already downloaded.'
        fi
        echo ''

        # Run the build
        chmod +x /usr/local/bin/build-lfs.sh
        /usr/local/bin/build-lfs.sh $STAGE

        echo ''
        echo '=== Build Complete ==='
    "

log "Build completed!"
echo ""
echo "Check ./output for build artifacts."
