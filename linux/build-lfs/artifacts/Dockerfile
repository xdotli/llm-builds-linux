# LFS Build Environment - ARM64 Native
# Based on Ubuntu 24.04 which meets all LFS 12.4 host requirements
#
# Native ARM64 build to avoid QEMU emulation issues
# docker build -t lfs-builder-arm64 .
FROM ubuntu:24.04

LABEL maintainer="LFS Build Experiment"
LABEL description="Docker environment for building Linux From Scratch 12.4 - ARM64 Native"

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Install all required host packages for LFS build
RUN apt-get update && apt-get install -y \
    # Required build tools
    bash \
    binutils \
    bison \
    coreutils \
    diffutils \
    findutils \
    gawk \
    gcc \
    g++ \
    grep \
    gzip \
    m4 \
    make \
    patch \
    perl \
    python3 \
    sed \
    tar \
    texinfo \
    xz-utils \
    # Additional required packages
    bzip2 \
    file \
    wget \
    curl \
    # For disk operations
    parted \
    e2fsprogs \
    dosfstools \
    grub-efi-arm64-bin \
    grub-common \
    # For building kernel
    bc \
    flex \
    libelf-dev \
    libssl-dev \
    # Utilities
    nano \
    vim \
    less \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Ensure /bin/sh points to bash (LFS requirement)
RUN rm /bin/sh && ln -s /bin/bash /bin/sh

# Create symlinks required by LFS
RUN ln -sf /usr/bin/gawk /usr/bin/awk || true
RUN ln -sf /usr/bin/bison /usr/bin/yacc || true

# Create LFS directory structure
ENV LFS=/mnt/lfs
RUN mkdir -pv $LFS
RUN mkdir -pv $LFS/sources
RUN chmod -v a+wt $LFS/sources

# Create tools directory
RUN mkdir -pv $LFS/tools
RUN ln -sv $LFS/tools /

# Create lfs user for building
RUN groupadd lfs
RUN useradd -s /bin/bash -g lfs -m -k /dev/null lfs
RUN chown -v lfs $LFS/tools
RUN chown -v lfs $LFS/sources

# Set up lfs user environment
USER lfs
RUN echo 'set +h' >> ~/.bash_profile && \
    echo 'umask 022' >> ~/.bash_profile && \
    echo 'LFS=/mnt/lfs' >> ~/.bash_profile && \
    echo 'LC_ALL=POSIX' >> ~/.bash_profile && \
    echo 'LFS_TGT=$(uname -m)-lfs-linux-gnu' >> ~/.bash_profile && \
    echo 'PATH=/usr/bin' >> ~/.bash_profile && \
    echo 'if [ ! -L /bin ]; then PATH=/bin:$PATH; fi' >> ~/.bash_profile && \
    echo 'PATH=$LFS/tools/bin:$PATH' >> ~/.bash_profile && \
    echo 'CONFIG_SITE=$LFS/usr/share/config.site' >> ~/.bash_profile && \
    echo 'export LFS LC_ALL LFS_TGT PATH CONFIG_SITE' >> ~/.bash_profile && \
    echo 'export MAKEFLAGS="-j$(nproc)"' >> ~/.bash_profile

USER root

# Copy build scripts
COPY version-check.sh /usr/local/bin/
COPY download-packages.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/*.sh

# Set working directory
WORKDIR /mnt/lfs

# Default command - run version check
CMD ["/bin/bash", "-c", "version-check.sh && echo 'Host system meets LFS requirements!'"]
