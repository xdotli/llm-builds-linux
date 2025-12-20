#!/bin/bash
# LFS Phase 3: Chroot Environment Setup
# Wrapper script that calls the main chroot setup and build script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LFS=/mnt/lfs

echo "=== Starting Phase 3: Chroot Environment Setup ==="
echo "This phase will:"
echo "  1. Change ownership of LFS directories to root"
echo "  2. Prepare virtual kernel file systems"
echo "  3. Enter chroot environment"
echo "  4. Create directory structure"
echo "  5. Create essential files (/etc/passwd, /etc/group, etc.)"
echo "  6. Build additional temporary tools (Gettext, Bison, Perl, Python, Texinfo, Util-linux)"
echo ""

# Execute the main build script
$SCRIPT_DIR/build-chroot-tools.sh

echo ""
echo "=== Phase 3 Complete ==="
echo "The chroot environment is ready and additional tools have been built."
echo "Next step: Phase 4 - Build the full LFS system"
