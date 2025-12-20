#!/bin/bash
# Build script for creating Fedora installation media with lorax
set -e
set -x

echo "========================================"
echo "Lorax Fedora Image Build Experiment"
echo "========================================"

# Configuration
FEDORA_VERSION="41"
PRODUCT_NAME="Fedora"
OUTPUT_BASE="/build/output"
OUTPUT_DIR="${OUTPUT_BASE}/lorax-output"
LOGS_DIR="${OUTPUT_BASE}/logs"
CACHE_DIR="/build/cache"

# Detect architecture
ARCH=$(uname -m)
echo "Detected architecture: ${ARCH}"

# Fedora mirrors - adapt to architecture
if [ "${ARCH}" = "aarch64" ]; then
    BASE_REPO="http://dl.fedoraproject.org/pub/fedora/linux/releases/${FEDORA_VERSION}/Everything/aarch64/os/"
    UPDATES_REPO="http://dl.fedoraproject.org/pub/fedora/linux/updates/${FEDORA_VERSION}/Everything/aarch64/"
else
    BASE_REPO="http://dl.fedoraproject.org/pub/fedora/linux/releases/${FEDORA_VERSION}/Everything/x86_64/os/"
    UPDATES_REPO="http://dl.fedoraproject.org/pub/fedora/linux/updates/${FEDORA_VERSION}/Everything/x86_64/"
fi

echo ""
echo "Build Configuration:"
echo "  Fedora Version: ${FEDORA_VERSION}"
echo "  Architecture: ${ARCH}"
echo "  Product Name: ${PRODUCT_NAME}"
echo "  Output Directory: ${OUTPUT_DIR}"
echo "  Base Repository: ${BASE_REPO}"
echo "  Updates Repository: ${UPDATES_REPO}"
echo ""

# Create base output, logs and cache directories
mkdir -p "${OUTPUT_BASE}" "${LOGS_DIR}" "${CACHE_DIR}"

# Remove lorax output directory if it exists (lorax requires it not to exist)
if [ -d "${OUTPUT_DIR}" ]; then
    echo "Removing existing lorax output directory..."
    rm -rf "${OUTPUT_DIR}"
fi

# Check if running with sufficient privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "WARNING: Not running as root. Lorax typically requires root privileges."
    echo "This may fail unless running in a privileged container."
fi

# Temporarily disable SELinux if it's enforcing (common requirement for lorax)
if command -v getenforce &> /dev/null; then
    if [ "$(getenforce)" == "Enforcing" ]; then
        echo "SELinux is enforcing, attempting to set to permissive..."
        setenforce 0 || echo "WARNING: Could not set SELinux to permissive"
    fi
fi

echo ""
echo "========================================"
echo "Step 1: Testing repository connectivity"
echo "========================================"

# Test if we can reach the repositories
echo "Testing base repository..."
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" "${BASE_REPO}/repodata/repomd.xml" || echo "Base repo check failed (may not be critical)"

echo "Testing updates repository..."
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" "${UPDATES_REPO}/repodata/repomd.xml" || echo "Updates repo check failed (may not be critical)"

echo ""
echo "========================================"
echo "Step 2: Running lorax to create boot.iso"
echo "========================================"

# Run lorax
# Options explained:
#   -p: Product name
#   -v: Version
#   -r: Release
#   -s: Source repository (can be specified multiple times)
#   --nomacboot: Don't create Mac bootable images (simplifies the build)
#   --noupgrade: Don't include upgrade support
#   --buildarch: Target architecture

lorax_cmd="lorax \
    -p \"${PRODUCT_NAME}\" \
    -v \"${FEDORA_VERSION}\" \
    -r \"${FEDORA_VERSION}\" \
    -s \"${BASE_REPO}\" \
    -s \"${UPDATES_REPO}\" \
    --nomacboot \
    --buildarch=${ARCH} \
    --logfile=${LOGS_DIR}/lorax.log \
    \"${OUTPUT_DIR}\""

echo "Running: ${lorax_cmd}"
echo ""

eval ${lorax_cmd} 2>&1 | tee "${LOGS_DIR}/lorax-console.log"

LORAX_EXIT_CODE=${PIPESTATUS[0]}

echo ""
echo "========================================"
echo "Step 3: Build Results"
echo "========================================"

if [ ${LORAX_EXIT_CODE} -eq 0 ]; then
    echo "SUCCESS: Lorax completed successfully!"
else
    echo "FAILED: Lorax exited with code ${LORAX_EXIT_CODE}"
fi

echo ""
echo "Output directory contents:"
ls -lah "${OUTPUT_DIR}" || echo "Could not list output directory"

echo ""
if [ -d "${OUTPUT_DIR}/images" ]; then
    echo "Images directory contents:"
    ls -lah "${OUTPUT_DIR}/images"

    if [ -f "${OUTPUT_DIR}/images/boot.iso" ]; then
        ISO_SIZE=$(du -h "${OUTPUT_DIR}/images/boot.iso" | cut -f1)
        echo ""
        echo "SUCCESS: boot.iso created!"
        echo "  Location: ${OUTPUT_DIR}/images/boot.iso"
        echo "  Size: ${ISO_SIZE}"

        # Verify ISO integrity
        echo ""
        echo "Verifying ISO integrity..."
        if command -v implantisomd5 &> /dev/null; then
            implantisomd5 "${OUTPUT_DIR}/images/boot.iso" || echo "WARNING: Could not implant MD5"
        fi

        if command -v checkisomd5 &> /dev/null; then
            checkisomd5 "${OUTPUT_DIR}/images/boot.iso" || echo "Note: ISO checksum verification skipped or failed"
        fi
    else
        echo "WARNING: boot.iso was not created"
    fi
else
    echo "WARNING: Images directory was not created"
fi

echo ""
echo "Log files:"
ls -lh "${LOGS_DIR}/" || echo "No logs found"

# Re-enable SELinux if we disabled it
if command -v getenforce &> /dev/null; then
    if [ "$(getenforce)" == "Permissive" ]; then
        echo ""
        echo "Re-enabling SELinux..."
        setenforce 1 || echo "Note: Could not re-enable SELinux"
    fi
fi

echo ""
echo "========================================"
echo "Build Complete"
echo "========================================"
echo "Exit code: ${LORAX_EXIT_CODE}"

exit ${LORAX_EXIT_CODE}
