#!/bin/bash
# LFS Build Orchestrator
# Main entry point for building Linux From Scratch

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LFS=/mnt/lfs

usage() {
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  check       - Check host system requirements"
    echo "  download    - Download all source packages"
    echo "  phase1      - Build cross-toolchain (Chapter 5)"
    echo "  phase2      - Build temporary tools (Chapter 6)"
    echo "  phase3      - Enter chroot, build tools (Chapter 7)"
    echo "  phase4      - Build full system (Chapter 8)"
    echo "  phase5      - Configure system (Chapters 9-10)"
    echo "  all         - Run all phases"
    echo "  docker      - Build and run Docker container"
    echo ""
    echo "Example:"
    echo "  $0 docker    # Start Docker build environment"
    echo "  $0 check     # Verify host requirements inside container"
    echo "  $0 download  # Get all source packages"
    echo "  $0 phase1    # Build cross-toolchain"
}

cmd_check() {
    echo "=== Checking Host System Requirements ==="
    $SCRIPT_DIR/version-check.sh
}

cmd_download() {
    echo "=== Downloading Source Packages ==="
    $SCRIPT_DIR/download-sources.sh
}

cmd_phase1() {
    echo "=== Phase 1: Cross-Toolchain ==="
    $SCRIPT_DIR/phase1/build-cross-toolchain.sh
}

cmd_phase2() {
    echo "=== Phase 2: Temporary Tools ==="
    if [ -f "$SCRIPT_DIR/phase2/build-temp-tools.sh" ]; then
        $SCRIPT_DIR/phase2/build-temp-tools.sh
    else
        echo "Phase 2 script not yet created"
        exit 1
    fi
}

cmd_phase3() {
    echo "=== Phase 3: Chroot Environment ==="
    if [ -f "$SCRIPT_DIR/phase3/setup-chroot.sh" ]; then
        $SCRIPT_DIR/phase3/setup-chroot.sh
    else
        echo "Phase 3 script not yet created"
        exit 1
    fi
}

cmd_phase4() {
    echo "=== Phase 4: Full System Build ==="
    if [ -f "$SCRIPT_DIR/phase4/build-system.sh" ]; then
        $SCRIPT_DIR/phase4/build-system.sh
    else
        echo "Phase 4 script not yet created"
        exit 1
    fi
}

cmd_phase5() {
    echo "=== Phase 5: System Configuration ==="
    if [ -f "$SCRIPT_DIR/phase5/configure-system.sh" ]; then
        $SCRIPT_DIR/phase5/configure-system.sh
    else
        echo "Phase 5 script not yet created"
        exit 1
    fi
}

cmd_docker() {
    echo "=== Building Docker Image ==="
    docker build -t lfs-builder "$SCRIPT_DIR"

    echo ""
    echo "=== Starting Container ==="
    echo "Inside the container, run:"
    echo "  ./build.sh check      # Verify environment"
    echo "  ./build.sh download   # Get sources"
    echo "  ./build.sh phase1     # Build cross-toolchain"
    echo ""

    docker run -it --rm \
        --privileged \
        -v "$SCRIPT_DIR:/mnt/lfs/artifacts:ro" \
        -v lfs-sources:/mnt/lfs/sources \
        -v lfs-tools:/mnt/lfs/tools \
        -v lfs-build:/mnt/lfs/build \
        -w /mnt/lfs \
        lfs-builder \
        /bin/bash
}

cmd_all() {
    echo "=== Full LFS Build ==="
    echo "This will take several hours..."
    cmd_check
    cmd_download
    cmd_phase1
    cmd_phase2
    cmd_phase3
    cmd_phase4
    cmd_phase5
    echo "=== LFS Build Complete ==="
}

case "${1:-}" in
    check)    cmd_check ;;
    download) cmd_download ;;
    phase1)   cmd_phase1 ;;
    phase2)   cmd_phase2 ;;
    phase3)   cmd_phase3 ;;
    phase4)   cmd_phase4 ;;
    phase5)   cmd_phase5 ;;
    all)      cmd_all ;;
    docker)   cmd_docker ;;
    *)        usage; exit 1 ;;
esac
