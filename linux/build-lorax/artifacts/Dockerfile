# Dockerfile for building Fedora images with lorax
# Based on Fedora 41 to match current lorax version 41.3

FROM fedora:41

# Install lorax and dependencies
# Note: Some architecture-specific packages may not be available on all platforms
RUN dnf install -y \
    lorax \
    lorax-lmc-virt \
    lorax-templates-generic \
    anaconda \
    anaconda-tui \
    anaconda-install-env-deps \
    pykickstart \
    qemu-kvm \
    libvirt \
    virt-install \
    genisoimage \
    isomd5sum \
    grub2-efi-aa64 \
    grub2-efi-aa64-modules \
    shim-aa64 \
    systemd-container \
    dnf-plugins-core \
    && dnf clean all

# Create working directories
RUN mkdir -p /build/output /build/logs /build/cache

# Set working directory
WORKDIR /build

# Copy build script
COPY build.sh /build/

# Make script executable
RUN chmod +x /build/build.sh

# Default command
CMD ["/build/build.sh"]
