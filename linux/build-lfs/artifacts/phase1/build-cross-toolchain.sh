#!/bin/bash
# LFS Phase 1: Cross-Toolchain Build
# Chapter 5 of LFS 12.4
# Modified to support ARM64 (aarch64)

set -e

export LFS=/mnt/lfs

# Detect architecture and set LFS_TGT accordingly
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        export LFS_TGT=x86_64-lfs-linux-gnu
        ;;
    aarch64|arm64)
        export LFS_TGT=aarch64-lfs-linux-gnu
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

export PATH=$LFS/tools/bin:$PATH

SOURCES=$LFS/sources
BUILD_DIR=$LFS/build

mkdir -p $BUILD_DIR
cd $BUILD_DIR

echo "=== LFS Phase 1: Cross-Toolchain ==="
echo "Host Architecture: $ARCH"
echo "LFS=$LFS"
echo "LFS_TGT=$LFS_TGT"
echo ""

#######################################
# 5.2 Binutils Pass 1
#######################################
build_binutils_pass1() {
    echo "=== Building Binutils Pass 1 ==="
    cd $SOURCES

    # Clean up any previous build
    rm -rf binutils-2.44
    tar xf binutils-2.44.tar.xz
    cd binutils-2.44

    mkdir -p build && cd build

    ../configure --prefix=$LFS/tools \
                 --with-sysroot=$LFS \
                 --target=$LFS_TGT   \
                 --disable-nls       \
                 --enable-gprofng=no \
                 --disable-werror    \
                 --enable-new-dtags  \
                 --enable-default-hash-style=gnu

    make -j$(nproc)
    make install

    cd $SOURCES
    rm -rf binutils-2.44

    echo "Binutils Pass 1: DONE"
}

#######################################
# 5.3 GCC Pass 1
#######################################
build_gcc_pass1() {
    echo "=== Building GCC Pass 1 ==="
    cd $SOURCES

    # Clean up any previous build
    rm -rf gcc-14.2.0
    tar xf gcc-14.2.0.tar.xz
    cd gcc-14.2.0

    # Extract and link GCC dependencies
    tar -xf ../mpfr-4.2.1.tar.xz
    mv -v mpfr-4.2.1 mpfr
    tar -xf ../gmp-6.3.0.tar.xz
    mv -v gmp-6.3.0 gmp
    tar -xf ../mpc-1.3.1.tar.gz
    mv -v mpc-1.3.1 mpc

    # Fix for cross-compilation (architecture specific)
    case $(uname -m) in
        x86_64)
            sed -e '/m64=/s/lib64/lib/' \
                -i.orig gcc/config/i386/t-linux64
        ;;
        aarch64)
            # ARM64 doesn't need this fix
            :
        ;;
    esac

    mkdir -p build && cd build

    ../configure                  \
        --target=$LFS_TGT         \
        --prefix=$LFS/tools       \
        --with-glibc-version=2.40 \
        --with-sysroot=$LFS       \
        --with-newlib             \
        --without-headers         \
        --enable-default-pie      \
        --enable-default-ssp      \
        --disable-nls             \
        --disable-shared          \
        --disable-multilib        \
        --disable-threads         \
        --disable-libatomic       \
        --disable-libgomp         \
        --disable-libquadmath     \
        --disable-libssp          \
        --disable-libvtv          \
        --disable-libstdcxx       \
        --enable-languages=c,c++

    make -j$(nproc)
    make install

    # Create limits.h
    cd ..
    cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
        $(dirname $($LFS_TGT-gcc -print-libgcc-file-name))/include/limits.h

    cd $SOURCES
    rm -rf gcc-14.2.0

    echo "GCC Pass 1: DONE"
}

#######################################
# 5.4 Linux API Headers
#######################################
build_linux_headers() {
    echo "=== Installing Linux API Headers ==="
    cd $SOURCES

    # Clean up any previous build
    rm -rf linux-6.12.6
    tar xf linux-6.12.6.tar.xz
    cd linux-6.12.6

    make mrproper
    make headers

    find usr/include -type f ! -name '*.h' -delete
    cp -rv usr/include $LFS/usr

    cd $SOURCES
    rm -rf linux-6.12.6

    echo "Linux Headers: DONE"
}

#######################################
# 5.5 Glibc
#######################################
build_glibc() {
    echo "=== Building Glibc ==="
    cd $SOURCES

    # Clean up any previous build
    rm -rf glibc-2.40
    tar xf glibc-2.40.tar.xz
    cd glibc-2.40

    # Create symlinks for LSB compliance (architecture specific)
    case $(uname -m) in
        x86_64)
            ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64
            ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64/ld-lsb-x86-64.so.3
        ;;
        aarch64)
            ln -sfv ../lib/ld-linux-aarch64.so.1 $LFS/lib64
        ;;
    esac

    # Apply patch if needed
    # patch -Np1 -i ../glibc-2.40-fhs-1.patch

    mkdir -p build && cd build

    echo "rootsbindir=/usr/sbin" > configparms

    ../configure                             \
          --prefix=/usr                      \
          --host=$LFS_TGT                    \
          --build=$(../scripts/config.guess) \
          --enable-kernel=4.19               \
          --with-headers=$LFS/usr/include    \
          --disable-nscd                     \
          libc_cv_slibdir=/usr/lib

    make -j$(nproc)
    make DESTDIR=$LFS install

    # Fix ldd script
    sed '/RTLDLIST=/s@/usr@@g' -i $LFS/usr/bin/ldd

    cd $SOURCES
    rm -rf glibc-2.40

    echo "Glibc: DONE"

    # Verify cross-toolchain
    echo "=== Verifying Cross-Toolchain ==="
    echo 'int main(){}' | $LFS_TGT-gcc -xc -
    readelf -l a.out | grep ld-linux
    rm -v a.out
}

#######################################
# 5.6 Libstdc++ from GCC
#######################################
build_libstdcxx() {
    echo "=== Building Libstdc++ ==="
    cd $SOURCES

    # Clean up any previous build
    rm -rf gcc-14.2.0
    tar xf gcc-14.2.0.tar.xz
    cd gcc-14.2.0

    mkdir -p build && cd build

    ../libstdc++-v3/configure           \
        --host=$LFS_TGT                 \
        --build=$(../config.guess)      \
        --prefix=/usr                   \
        --disable-multilib              \
        --disable-nls                   \
        --disable-libstdcxx-pch         \
        --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/14.2.0

    make -j$(nproc)
    make DESTDIR=$LFS install

    # Remove libtool archives
    rm -v $LFS/usr/lib/lib{stdc++{,exp,fs},supc++}.la

    cd $SOURCES
    rm -rf gcc-14.2.0

    echo "Libstdc++: DONE"
}

#######################################
# Main
#######################################

# Create required directories
mkdir -pv $LFS/usr/include
mkdir -pv $LFS/lib64

echo "Starting Phase 1 build..."
echo "This will take 30-60 minutes"
echo ""

build_binutils_pass1
build_gcc_pass1
build_linux_headers
build_glibc
build_libstdcxx

echo ""
echo "=== Phase 1 Complete ==="
echo "Cross-toolchain installed to: $LFS/tools"
echo ""
echo "Verify with:"
echo "  $LFS_TGT-gcc --version"
echo "  $LFS_TGT-ld --version"
