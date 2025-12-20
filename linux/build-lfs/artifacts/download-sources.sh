#!/bin/bash
# Download all LFS 12.4 source packages
# This follows Chapter 3 of the LFS book

# Don't exit on error - we want to continue and report failures
set +e

LFS=${LFS:-/mnt/lfs}
SOURCES=$LFS/sources

mkdir -p $SOURCES
cd $SOURCES

# Remove zero-byte corrupted downloads
echo "Cleaning up failed downloads (0-byte files)..."
find . -maxdepth 1 -type f -size 0 -delete

# Use ftpmirror.gnu.org as backup
GNU_MIRROR="https://ftpmirror.gnu.org"

# LFS 12.4 Package list (core packages)
# Format: URL filename
# Using ftpmirror.gnu.org which auto-redirects to nearest mirror

PACKAGES=(
    # Chapter 5 - Cross-Toolchain
    "${GNU_MIRROR}/binutils/binutils-2.44.tar.xz binutils-2.44.tar.xz"
    "${GNU_MIRROR}/gcc/gcc-14.2.0/gcc-14.2.0.tar.xz gcc-14.2.0.tar.xz"
    "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.12.6.tar.xz linux-6.12.6.tar.xz"
    "${GNU_MIRROR}/glibc/glibc-2.40.tar.xz glibc-2.40.tar.xz"

    # GCC dependencies
    "${GNU_MIRROR}/gmp/gmp-6.3.0.tar.xz gmp-6.3.0.tar.xz"
    "${GNU_MIRROR}/mpfr/mpfr-4.2.1.tar.xz mpfr-4.2.1.tar.xz"
    "${GNU_MIRROR}/mpc/mpc-1.3.1.tar.gz mpc-1.3.1.tar.gz"

    # Chapter 6 - Temporary Tools
    "${GNU_MIRROR}/m4/m4-1.4.19.tar.xz m4-1.4.19.tar.xz"
    "${GNU_MIRROR}/ncurses/ncurses-6.5.tar.gz ncurses-6.5.tar.gz"
    "${GNU_MIRROR}/bash/bash-5.2.37.tar.gz bash-5.2.37.tar.gz"
    "${GNU_MIRROR}/coreutils/coreutils-9.5.tar.xz coreutils-9.5.tar.xz"
    "${GNU_MIRROR}/diffutils/diffutils-3.10.tar.xz diffutils-3.10.tar.xz"
    "https://astron.com/pub/file/file-5.45.tar.gz file-5.45.tar.gz"
    "${GNU_MIRROR}/findutils/findutils-4.10.0.tar.xz findutils-4.10.0.tar.xz"
    "${GNU_MIRROR}/gawk/gawk-5.3.1.tar.xz gawk-5.3.1.tar.xz"
    "${GNU_MIRROR}/grep/grep-3.11.tar.xz grep-3.11.tar.xz"
    "${GNU_MIRROR}/gzip/gzip-1.13.tar.xz gzip-1.13.tar.xz"
    "${GNU_MIRROR}/make/make-4.4.1.tar.gz make-4.4.1.tar.gz"
    "${GNU_MIRROR}/patch/patch-2.7.6.tar.xz patch-2.7.6.tar.xz"
    "${GNU_MIRROR}/sed/sed-4.9.tar.xz sed-4.9.tar.xz"
    "${GNU_MIRROR}/tar/tar-1.35.tar.xz tar-1.35.tar.xz"
    "https://github.com/tukaani-project/xz/releases/download/v5.6.3/xz-5.6.3.tar.xz xz-5.6.3.tar.xz"

    # Chapter 7 - Chroot environment
    "${GNU_MIRROR}/gettext/gettext-0.22.5.tar.xz gettext-0.22.5.tar.xz"
    "${GNU_MIRROR}/bison/bison-3.8.2.tar.xz bison-3.8.2.tar.xz"
    "https://www.cpan.org/src/5.0/perl-5.40.0.tar.xz perl-5.40.0.tar.xz"
    "https://www.python.org/ftp/python/3.12.8/Python-3.12.8.tar.xz Python-3.12.8.tar.xz"
    "${GNU_MIRROR}/texinfo/texinfo-7.1.1.tar.xz texinfo-7.1.1.tar.xz"
    "https://cdn.kernel.org/pub/linux/utils/util-linux/v2.40/util-linux-2.40.2.tar.xz util-linux-2.40.2.tar.xz"

    # Chapter 8 - Core packages (partial list - most important)
    "https://github.com/Mic92/iana-etc/releases/download/20241224/iana-etc-20241224.tar.gz iana-etc-20241224.tar.gz"
    "https://github.com/madler/zlib/releases/download/v1.3.1/zlib-1.3.1.tar.xz zlib-1.3.1.tar.xz"
    "https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz bzip2-1.0.8.tar.gz"
    "https://github.com/lz4/lz4/releases/download/v1.10.0/lz4-1.10.0.tar.gz lz4-1.10.0.tar.gz"
    "https://github.com/facebook/zstd/releases/download/v1.5.6/zstd-1.5.6.tar.gz zstd-1.5.6.tar.gz"
    "${GNU_MIRROR}/readline/readline-8.2.13.tar.gz readline-8.2.13.tar.gz"
    "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.44/pcre2-10.44.tar.bz2 pcre2-10.44.tar.bz2"
    "https://github.com/westes/flex/releases/download/v2.6.4/flex-2.6.4.tar.gz flex-2.6.4.tar.gz"
    "${GNU_MIRROR}/autoconf/autoconf-2.72.tar.xz autoconf-2.72.tar.xz"
    "${GNU_MIRROR}/automake/automake-1.17.tar.xz automake-1.17.tar.xz"
    "https://www.openssl.org/source/openssl-3.4.0.tar.gz openssl-3.4.0.tar.gz"
    "https://github.com/libffi/libffi/releases/download/v3.4.6/libffi-3.4.6.tar.gz libffi-3.4.6.tar.gz"
    "https://github.com/shadow-maint/shadow/releases/download/4.16.0/shadow-4.16.0.tar.xz shadow-4.16.0.tar.xz"
    "https://github.com/systemd/systemd/archive/v256.7/systemd-256.7.tar.gz systemd-256.7.tar.gz"
    "${GNU_MIRROR}/grub/grub-2.12.tar.xz grub-2.12.tar.xz"
)

echo "=== Downloading LFS 12.4 Sources ==="
echo "Destination: $SOURCES"
echo ""

FAILED_DOWNLOADS=()

for entry in "${PACKAGES[@]}"; do
    url=$(echo $entry | cut -d' ' -f1)
    filename=$(echo $entry | cut -d' ' -f2)

    # Check if file exists and has non-zero size
    if [ -f "$filename" ] && [ -s "$filename" ]; then
        echo "[SKIP] $filename already exists"
    else
        # Remove zero-byte file if it exists
        [ -f "$filename" ] && rm -f "$filename"
        echo "[GET] $filename"
        if wget --timeout=60 --tries=3 -c "$url" -O "$filename"; then
            # Verify download succeeded and file is not empty
            if [ ! -s "$filename" ]; then
                echo "FAILED: $filename (empty file)"
                rm -f "$filename"
                FAILED_DOWNLOADS+=("$filename")
            fi
        else
            echo "FAILED: $filename"
            rm -f "$filename"
            FAILED_DOWNLOADS+=("$filename")
        fi
    fi
done

echo ""
echo "=== Download Summary ==="

if [ ${#FAILED_DOWNLOADS[@]} -gt 0 ]; then
    echo "FAILED DOWNLOADS (${#FAILED_DOWNLOADS[@]}):"
    for f in "${FAILED_DOWNLOADS[@]}"; do
        echo "  - $f"
    done
else
    echo "All downloads completed successfully!"
fi

echo ""
echo "Files in $SOURCES:"
ls -la $SOURCES

echo ""
echo "Total size:"
du -sh $SOURCES
