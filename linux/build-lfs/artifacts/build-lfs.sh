#!/bin/bash
# Main LFS Build Script
# Orchestrates the complete Linux From Scratch build process
#
# Usage: ./build-lfs.sh [stage]
# Stages: all, prepare, toolchain, chroot, system, config, kernel, bootloader
#
# This script must be run as root inside the Docker container

set -e
set -o pipefail

# Configuration
export LFS=/mnt/lfs
export LFS_TGT=$(uname -m)-lfs-linux-gnu
export LC_ALL=POSIX
export PATH=/usr/bin:/bin:$LFS/tools/bin
export CONFIG_SITE=$LFS/usr/share/config.site
export MAKEFLAGS="-j$(nproc)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[LFS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

stage() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  STAGE: $1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

# Track progress
PROGRESS_FILE=$LFS/build-progress.txt
mark_done() {
    echo "$1" >> $PROGRESS_FILE
}

is_done() {
    grep -q "^$1$" $PROGRESS_FILE 2>/dev/null
}

# Stage 1: Prepare the build environment
stage_prepare() {
    stage "PREPARATION"

    if is_done "prepare"; then
        log "Preparation already complete, skipping..."
        return 0
    fi

    log "Creating LFS directory structure..."
    mkdir -pv $LFS/{etc,var} $LFS/usr/{bin,lib,sbin}

    for i in bin lib sbin; do
        ln -sv usr/$i $LFS/$i 2>/dev/null || true
    done

    case $(uname -m) in
        x86_64) mkdir -pv $LFS/lib64 ;;
    esac

    mkdir -pv $LFS/tools

    log "Creating lfs user..."
    groupadd lfs 2>/dev/null || true
    useradd -s /bin/bash -g lfs -m -k /dev/null lfs 2>/dev/null || true

    chown -v lfs $LFS/{usr{,/*},lib,var,etc,bin,sbin,tools}
    case $(uname -m) in
        x86_64) chown -v lfs $LFS/lib64 ;;
    esac

    log "Setting up lfs user environment..."
    cat > /home/lfs/.bash_profile << "EOF"
exec env -i HOME=/home/lfs TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF

    cat > /home/lfs/.bashrc << "EOF"
set +h
umask 022
LFS=/mnt/lfs
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=/usr/bin
if [ ! -L /bin ]; then PATH=/bin:$PATH; fi
PATH=$LFS/tools/bin:$PATH
CONFIG_SITE=$LFS/usr/share/config.site
export LFS LC_ALL LFS_TGT PATH CONFIG_SITE
export MAKEFLAGS="-j$(nproc)"
EOF

    chown lfs:lfs /home/lfs/.bash_profile /home/lfs/.bashrc

    mark_done "prepare"
    log "Preparation complete!"
}

# Stage 2: Build cross-toolchain (Chapter 5)
stage_toolchain() {
    stage "CROSS-TOOLCHAIN (Chapter 5)"

    if is_done "toolchain"; then
        log "Toolchain already built, skipping..."
        return 0
    fi

    cd $LFS/sources

    # 5.2 Binutils Pass 1
    if ! is_done "binutils-pass1"; then
        log "Building Binutils Pass 1..."
        tar xf binutils-2.45.tar.xz
        cd binutils-2.45
        mkdir -v build && cd build
        ../configure --prefix=$LFS/tools \
            --with-sysroot=$LFS \
            --target=$LFS_TGT \
            --disable-nls \
            --enable-gprofng=no \
            --disable-werror \
            --enable-new-dtags \
            --enable-default-hash-style=gnu
        make
        make install
        cd $LFS/sources
        rm -rf binutils-2.45
        mark_done "binutils-pass1"
        log "Binutils Pass 1 complete!"
    fi

    # 5.3 GCC Pass 1
    if ! is_done "gcc-pass1"; then
        log "Building GCC Pass 1..."
        tar xf gcc-15.2.0.tar.xz
        cd gcc-15.2.0
        tar -xf ../mpfr-4.2.2.tar.xz
        mv -v mpfr-4.2.2 mpfr
        tar -xf ../gmp-6.3.0.tar.xz
        mv -v gmp-6.3.0 gmp
        tar -xf ../mpc-1.3.1.tar.gz
        mv -v mpc-1.3.1 mpc

        case $(uname -m) in
            x86_64)
                sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
            ;;
        esac

        mkdir -v build && cd build
        ../configure \
            --target=$LFS_TGT \
            --prefix=$LFS/tools \
            --with-glibc-version=2.42 \
            --with-sysroot=$LFS \
            --with-newlib \
            --without-headers \
            --enable-default-pie \
            --enable-default-ssp \
            --disable-nls \
            --disable-shared \
            --disable-multilib \
            --disable-threads \
            --disable-libatomic \
            --disable-libgomp \
            --disable-libquadmath \
            --disable-libssp \
            --disable-libvtv \
            --disable-libstdcxx \
            --enable-languages=c,c++
        make
        make install

        cd ..
        cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
            $(dirname $($LFS_TGT-gcc -print-libgcc-file-name))/include/limits.h

        cd $LFS/sources
        rm -rf gcc-15.2.0
        mark_done "gcc-pass1"
        log "GCC Pass 1 complete!"
    fi

    # 5.4 Linux API Headers
    if ! is_done "linux-headers"; then
        log "Installing Linux API Headers..."
        tar xf linux-6.16.1.tar.xz
        cd linux-6.16.1
        make mrproper
        make headers
        find usr/include -type f ! -name '*.h' -delete
        cp -rv usr/include $LFS/usr
        cd $LFS/sources
        rm -rf linux-6.16.1
        mark_done "linux-headers"
        log "Linux API Headers complete!"
    fi

    # 5.5 Glibc
    if ! is_done "glibc"; then
        log "Building Glibc..."
        tar xf glibc-2.42.tar.xz
        cd glibc-2.42

        case $(uname -m) in
            i?86)   ln -sfv ld-linux.so.2 $LFS/lib/ld-lsb.so.3 ;;
            x86_64) ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64
                    ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64/ld-lsb-x86-64.so.3 ;;
        esac

        patch -Np1 -i ../glibc-2.42-fhs-1.patch

        mkdir -v build && cd build
        echo "rootsbindir=/usr/sbin" > configparms
        ../configure \
            --prefix=/usr \
            --host=$LFS_TGT \
            --build=$(../scripts/config.guess) \
            --enable-kernel=5.4 \
            --with-headers=$LFS/usr/include \
            --disable-nscd \
            libc_cv_slibdir=/usr/lib
        make
        make DESTDIR=$LFS install

        sed '/RTLDLIST=/s@/usr@@g' -i $LFS/usr/bin/ldd

        # Sanity check
        log "Running toolchain sanity check..."
        echo 'int main(){}' | $LFS_TGT-gcc -xc -
        readelf -l a.out | grep ld-linux
        rm -v a.out

        cd $LFS/sources
        rm -rf glibc-2.42
        mark_done "glibc"
        log "Glibc complete!"
    fi

    # 5.6 Libstdc++ from GCC
    if ! is_done "libstdcxx"; then
        log "Building Libstdc++..."
        tar xf gcc-15.2.0.tar.xz
        cd gcc-15.2.0
        mkdir -v build && cd build
        ../libstdc++-v3/configure \
            --host=$LFS_TGT \
            --build=$(../config.guess) \
            --prefix=/usr \
            --disable-multilib \
            --disable-nls \
            --disable-libstdcxx-pch \
            --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/15.2.0
        make
        make DESTDIR=$LFS install
        rm -v $LFS/usr/lib/lib{stdc++{,exp,fs},supc++}.la
        cd $LFS/sources
        rm -rf gcc-15.2.0
        mark_done "libstdcxx"
        log "Libstdc++ complete!"
    fi

    mark_done "toolchain"
    log "Cross-toolchain complete!"
}

# Stage 3: Cross-compile temporary tools (Chapter 6)
stage_temp_tools() {
    stage "TEMPORARY TOOLS (Chapter 6)"

    if is_done "temp_tools"; then
        log "Temporary tools already built, skipping..."
        return 0
    fi

    cd $LFS/sources

    # M4
    if ! is_done "temp-m4"; then
        log "Building M4..."
        tar xf m4-1.4.20.tar.xz
        cd m4-1.4.20
        ./configure --prefix=/usr \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)
        make
        make DESTDIR=$LFS install
        cd $LFS/sources
        rm -rf m4-1.4.20
        mark_done "temp-m4"
    fi

    # Ncurses
    if ! is_done "temp-ncurses"; then
        log "Building Ncurses..."
        tar xf ncurses-6.5-20250809.tgz
        cd ncurses-6.5-20250809
        sed -i s/mawk// configure
        mkdir build
        pushd build
            ../configure
            make -C include
            make -C progs tic
        popd
        ./configure --prefix=/usr \
            --host=$LFS_TGT \
            --build=$(./config.guess) \
            --mandir=/usr/share/man \
            --with-manpage-format=normal \
            --with-shared \
            --without-normal \
            --with-cxx-shared \
            --without-debug \
            --without-ada \
            --disable-stripping
        make
        make DESTDIR=$LFS TIC_PATH=$(pwd)/build/progs/tic install
        ln -sv libncursesw.so $LFS/usr/lib/libncurses.so
        sed -e 's/^#if.*XOPEN.*$/#if 1/' -i $LFS/usr/include/curses.h
        cd $LFS/sources
        rm -rf ncurses-6.5-20250809
        mark_done "temp-ncurses"
    fi

    # Bash
    if ! is_done "temp-bash"; then
        log "Building Bash..."
        tar xf bash-5.3.tar.gz
        cd bash-5.3
        ./configure --prefix=/usr \
            --build=$(sh support/config.guess) \
            --host=$LFS_TGT \
            --without-bash-malloc \
            bash_cv_strtold_broken=no
        make
        make DESTDIR=$LFS install
        ln -sv bash $LFS/bin/sh
        cd $LFS/sources
        rm -rf bash-5.3
        mark_done "temp-bash"
    fi

    # Coreutils
    if ! is_done "temp-coreutils"; then
        log "Building Coreutils..."
        tar xf coreutils-9.7.tar.xz
        cd coreutils-9.7
        ./configure --prefix=/usr \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess) \
            --enable-install-program=hostname \
            --enable-no-install-program=kill,uptime
        make
        make DESTDIR=$LFS install
        mv -v $LFS/usr/bin/chroot $LFS/usr/sbin
        mkdir -pv $LFS/usr/share/man/man8
        mv -v $LFS/usr/share/man/man1/chroot.1 $LFS/usr/share/man/man8/chroot.8
        sed -i 's/"1"/"8"/' $LFS/usr/share/man/man8/chroot.8
        cd $LFS/sources
        rm -rf coreutils-9.7
        mark_done "temp-coreutils"
    fi

    # Diffutils
    if ! is_done "temp-diffutils"; then
        log "Building Diffutils..."
        tar xf diffutils-3.12.tar.xz
        cd diffutils-3.12
        ./configure --prefix=/usr \
            --host=$LFS_TGT \
            --build=$(./build-aux/config.guess)
        make
        make DESTDIR=$LFS install
        cd $LFS/sources
        rm -rf diffutils-3.12
        mark_done "temp-diffutils"
    fi

    # File
    if ! is_done "temp-file"; then
        log "Building File..."
        tar xf file-5.46.tar.gz
        cd file-5.46
        mkdir build
        pushd build
            ../configure --disable-bzlib \
                --disable-libseccomp \
                --disable-xzlib \
                --disable-zlib
            make
        popd
        ./configure --prefix=/usr --host=$LFS_TGT --build=$(./config.guess)
        make FILE_COMPILE=$(pwd)/build/src/file
        make DESTDIR=$LFS install
        rm -v $LFS/usr/lib/libmagic.la
        cd $LFS/sources
        rm -rf file-5.46
        mark_done "temp-file"
    fi

    # Findutils
    if ! is_done "temp-findutils"; then
        log "Building Findutils..."
        tar xf findutils-4.10.0.tar.xz
        cd findutils-4.10.0
        ./configure --prefix=/usr \
            --localstatedir=/var/lib/locate \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)
        make
        make DESTDIR=$LFS install
        cd $LFS/sources
        rm -rf findutils-4.10.0
        mark_done "temp-findutils"
    fi

    # Gawk
    if ! is_done "temp-gawk"; then
        log "Building Gawk..."
        tar xf gawk-5.3.2.tar.xz
        cd gawk-5.3.2
        sed -i 's/extras//' Makefile.in
        ./configure --prefix=/usr \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)
        make
        make DESTDIR=$LFS install
        cd $LFS/sources
        rm -rf gawk-5.3.2
        mark_done "temp-gawk"
    fi

    # Grep
    if ! is_done "temp-grep"; then
        log "Building Grep..."
        tar xf grep-3.12.tar.xz
        cd grep-3.12
        ./configure --prefix=/usr \
            --host=$LFS_TGT \
            --build=$(./build-aux/config.guess)
        make
        make DESTDIR=$LFS install
        cd $LFS/sources
        rm -rf grep-3.12
        mark_done "temp-grep"
    fi

    # Gzip
    if ! is_done "temp-gzip"; then
        log "Building Gzip..."
        tar xf gzip-1.14.tar.xz
        cd gzip-1.14
        ./configure --prefix=/usr --host=$LFS_TGT
        make
        make DESTDIR=$LFS install
        cd $LFS/sources
        rm -rf gzip-1.14
        mark_done "temp-gzip"
    fi

    # Make
    if ! is_done "temp-make"; then
        log "Building Make..."
        tar xf make-4.4.1.tar.gz
        cd make-4.4.1
        ./configure --prefix=/usr \
            --without-guile \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)
        make
        make DESTDIR=$LFS install
        cd $LFS/sources
        rm -rf make-4.4.1
        mark_done "temp-make"
    fi

    # Patch
    if ! is_done "temp-patch"; then
        log "Building Patch..."
        tar xf patch-2.8.tar.xz
        cd patch-2.8
        ./configure --prefix=/usr \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)
        make
        make DESTDIR=$LFS install
        cd $LFS/sources
        rm -rf patch-2.8
        mark_done "temp-patch"
    fi

    # Sed
    if ! is_done "temp-sed"; then
        log "Building Sed..."
        tar xf sed-4.9.tar.xz
        cd sed-4.9
        ./configure --prefix=/usr \
            --host=$LFS_TGT \
            --build=$(./build-aux/config.guess)
        make
        make DESTDIR=$LFS install
        cd $LFS/sources
        rm -rf sed-4.9
        mark_done "temp-sed"
    fi

    # Tar
    if ! is_done "temp-tar"; then
        log "Building Tar..."
        tar xf tar-1.35.tar.xz
        cd tar-1.35
        ./configure --prefix=/usr \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)
        make
        make DESTDIR=$LFS install
        cd $LFS/sources
        rm -rf tar-1.35
        mark_done "temp-tar"
    fi

    # Xz
    if ! is_done "temp-xz"; then
        log "Building Xz..."
        tar xf xz-5.8.1.tar.xz
        cd xz-5.8.1
        ./configure --prefix=/usr \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess) \
            --disable-static \
            --docdir=/usr/share/doc/xz-5.8.1
        make
        make DESTDIR=$LFS install
        rm -v $LFS/usr/lib/liblzma.la
        cd $LFS/sources
        rm -rf xz-5.8.1
        mark_done "temp-xz"
    fi

    # Binutils Pass 2
    if ! is_done "binutils-pass2"; then
        log "Building Binutils Pass 2..."
        tar xf binutils-2.45.tar.xz
        cd binutils-2.45
        sed '6009s/$add_dir//' -i ltmain.sh
        mkdir -v build && cd build
        ../configure \
            --prefix=/usr \
            --build=$(../config.guess) \
            --host=$LFS_TGT \
            --disable-nls \
            --enable-shared \
            --enable-gprofng=no \
            --disable-werror \
            --enable-64-bit-bfd \
            --enable-new-dtags \
            --enable-default-hash-style=gnu
        make
        make DESTDIR=$LFS install
        rm -v $LFS/usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes,sframe}.{a,la}
        cd $LFS/sources
        rm -rf binutils-2.45
        mark_done "binutils-pass2"
    fi

    # GCC Pass 2
    if ! is_done "gcc-pass2"; then
        log "Building GCC Pass 2..."
        tar xf gcc-15.2.0.tar.xz
        cd gcc-15.2.0
        tar -xf ../mpfr-4.2.2.tar.xz
        mv -v mpfr-4.2.2 mpfr
        tar -xf ../gmp-6.3.0.tar.xz
        mv -v gmp-6.3.0 gmp
        tar -xf ../mpc-1.3.1.tar.gz
        mv -v mpc-1.3.1 mpc

        case $(uname -m) in
            x86_64)
                sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
            ;;
        esac

        sed '/thread_header =/s/@.*@/gthr-posix.h/' \
            -i libgcc/Makefile.in libstdc++-v3/include/Makefile.in

        mkdir -v build && cd build
        ../configure \
            --build=$(../config.guess) \
            --host=$LFS_TGT \
            --target=$LFS_TGT \
            LDFLAGS_FOR_TARGET=-L$PWD/$LFS_TGT/libgcc \
            --prefix=/usr \
            --with-build-sysroot=$LFS \
            --enable-default-pie \
            --enable-default-ssp \
            --disable-nls \
            --disable-multilib \
            --disable-libatomic \
            --disable-libgomp \
            --disable-libquadmath \
            --disable-libsanitizer \
            --disable-libssp \
            --disable-libvtv \
            --enable-languages=c,c++
        make
        make DESTDIR=$LFS install
        ln -sv gcc $LFS/usr/bin/cc
        cd $LFS/sources
        rm -rf gcc-15.2.0
        mark_done "gcc-pass2"
    fi

    mark_done "temp_tools"
    log "Temporary tools complete!"
}

# Stage 4: Enter chroot and prepare virtual kernel filesystems (Chapter 7)
stage_chroot_prep() {
    stage "CHROOT PREPARATION (Chapter 7)"

    if is_done "chroot_prep"; then
        log "Chroot preparation already done, skipping..."
        return 0
    fi

    # Create directories
    mkdir -pv $LFS/{dev,proc,sys,run}

    # Create essential device nodes
    mount -v --bind /dev $LFS/dev
    mount -vt devpts devpts -o gid=5,mode=0620 $LFS/dev/pts
    mount -vt proc proc $LFS/proc
    mount -vt sysfs sysfs $LFS/sys
    mount -vt tmpfs tmpfs $LFS/run

    if [ -h $LFS/dev/shm ]; then
        install -v -d -m 1777 $LFS$(realpath /dev/shm)
    else
        mount -vt tmpfs -o nosuid,nodev tmpfs $LFS/dev/shm
    fi

    mark_done "chroot_prep"
    log "Chroot preparation complete!"
}

# Stage 5: Create directories and essential files in chroot
stage_chroot_dirs() {
    stage "CHROOT DIRECTORIES AND FILES (Chapter 7)"

    if is_done "chroot_dirs"; then
        log "Chroot directories already created, skipping..."
        return 0
    fi

    # This must be run inside chroot
    chroot "$LFS" /usr/bin/env -i \
        HOME=/root \
        TERM="$TERM" \
        PS1='(lfs chroot) \u:\w\$ ' \
        PATH=/usr/bin:/usr/sbin \
        MAKEFLAGS="-j$(nproc)" \
        /bin/bash --login << 'CHROOT_SCRIPT'

# Create standard directories
mkdir -pv /{boot,home,mnt,opt,srv}

mkdir -pv /etc/{opt,sysconfig}
mkdir -pv /lib/firmware
mkdir -pv /media/{floppy,cdrom}
mkdir -pv /usr/{,local/}{include,src}
mkdir -pv /usr/local/{bin,lib,sbin}
mkdir -pv /usr/{,local/}share/{color,dict,doc,info,locale,man}
mkdir -pv /usr/{,local/}share/{misc,terminfo,zoneinfo}
mkdir -pv /usr/{,local/}share/man/man{1..8}
mkdir -pv /var/{cache,local,log,mail,opt,spool}
mkdir -pv /var/lib/{color,misc,locate}

ln -sfv /run /var/run
ln -sfv /run/lock /var/lock

install -dv -m 0750 /root
install -dv -m 1777 /tmp /var/tmp

# Create essential files
ln -sv /proc/self/mounts /etc/mtab

cat > /etc/hosts << EOF
127.0.0.1  localhost $(hostname)
::1        localhost
EOF

cat > /etc/passwd << "EOF"
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/usr/bin/false
daemon:x:6:6:Daemon User:/dev/null:/usr/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/run/dbus:/usr/bin/false
systemd-journal-gateway:x:73:73:systemd Journal Gateway:/:/usr/bin/false
systemd-journal-remote:x:74:74:systemd Journal Remote:/:/usr/bin/false
systemd-journal-upload:x:75:75:systemd Journal Upload:/:/usr/bin/false
systemd-network:x:76:76:systemd Network Management:/:/usr/bin/false
systemd-resolve:x:77:77:systemd Resolver:/:/usr/bin/false
systemd-timesync:x:78:78:systemd Time Synchronization:/:/usr/bin/false
systemd-coredump:x:79:79:systemd Core Dumper:/:/usr/bin/false
uuidd:x:80:80:UUID Generation Daemon:/dev/null:/usr/bin/false
systemd-oom:x:81:81:systemd Out Of Memory Daemon:/:/usr/bin/false
nobody:x:65534:65534:Unprivileged User:/dev/null:/usr/bin/false
EOF

cat > /etc/group << "EOF"
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
cdrom:x:15:
adm:x:16:
messagebus:x:18:
systemd-journal:x:23:
input:x:24:
mail:x:34:
kvm:x:61:
systemd-journal-gateway:x:73:
systemd-journal-remote:x:74:
systemd-journal-upload:x:75:
systemd-network:x:76:
systemd-resolve:x:77:
systemd-timesync:x:78:
systemd-coredump:x:79:
uuidd:x:80:
systemd-oom:x:81:
wheel:x:97:
users:x:999:
nogroup:x:65534:
EOF

# Create initial log files
touch /var/log/{btmp,lastlog,faillog,wtmp}
chgrp -v utmp /var/log/lastlog
chmod -v 664  /var/log/lastlog
chmod -v 600  /var/log/btmp

echo "Chroot directories and files created!"
CHROOT_SCRIPT

    mark_done "chroot_dirs"
    log "Chroot directories complete!"
}

# Print usage
usage() {
    echo "Usage: $0 [stage]"
    echo ""
    echo "Stages:"
    echo "  all       - Run all stages (default)"
    echo "  prepare   - Create LFS directory structure and users"
    echo "  toolchain - Build cross-compilation toolchain (Chapter 5)"
    echo "  temp      - Build temporary tools (Chapter 6)"
    echo "  chroot    - Prepare and enter chroot environment (Chapter 7)"
    echo "  status    - Show build progress"
    echo ""
}

# Show status
show_status() {
    echo "=== LFS Build Status ==="
    echo ""
    if [ -f $PROGRESS_FILE ]; then
        echo "Completed stages:"
        cat $PROGRESS_FILE | while read line; do
            echo "  - $line"
        done
    else
        echo "No stages completed yet."
    fi
    echo ""
}

# Main
main() {
    case "${1:-all}" in
        all)
            stage_prepare
            stage_toolchain
            stage_temp_tools
            stage_chroot_prep
            stage_chroot_dirs
            ;;
        prepare)
            stage_prepare
            ;;
        toolchain)
            stage_toolchain
            ;;
        temp)
            stage_temp_tools
            ;;
        chroot)
            stage_chroot_prep
            stage_chroot_dirs
            ;;
        status)
            show_status
            ;;
        *)
            usage
            exit 1
            ;;
    esac

    echo ""
    log "Build script completed!"
    show_status
}

# Run as root check
if [ "$(id -u)" != "0" ]; then
    error "This script must be run as root"
fi

main "$@"
