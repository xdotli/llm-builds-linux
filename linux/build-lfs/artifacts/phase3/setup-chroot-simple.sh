#!/bin/bash
# LFS Phase 3: Simplified Chroot Setup
# Focus on essential setup and simpler tools first

set -e

export LFS=/mnt/lfs

echo "=== LFS Phase 3: Essential Chroot Setup ==="
echo "LFS=$LFS"
echo ""

#######################################
# Step 1: Change ownership to root
#######################################
echo "=== Step 1: Changing Ownership ==="
chown -R root:root $LFS/{usr,lib,var,etc,bin,sbin,tools}
[ -e $LFS/lib64 ] && chown -R root:root $LFS/lib64 || true

#######################################
# Step 2: Prepare Virtual Kernel File Systems
#######################################
echo "=== Step 2: Preparing Virtual Kernel File Systems ==="

# Create mount points
mkdir -pv $LFS/{dev,proc,sys,run}

# Unmount if already mounted
for m in $LFS/dev/shm $LFS/dev/pts $LFS/proc $LFS/sys $LFS/run $LFS/dev; do
    mountpoint -q $m && umount $m 2>/dev/null || true
done

# Mount /dev
if ! mountpoint -q $LFS/dev; then
    mount -v --bind /dev $LFS/dev
fi

# Mount virtual kernel file systems
if ! mountpoint -q $LFS/dev/pts; then
    mount -vt devpts devpts -o gid=5,mode=0620 $LFS/dev/pts
fi

if ! mountpoint -q $LFS/proc; then
    mount -vt proc proc $LFS/proc
fi

if ! mountpoint -q $LFS/sys; then
    mount -vt sysfs sysfs $LFS/sys
fi

if ! mountpoint -q $LFS/run; then
    mount -vt tmpfs tmpfs $LFS/run
fi

# Handle /dev/shm
if [ -h $LFS/dev/shm ]; then
    install -v -d -m 1777 $LFS$(realpath /dev/shm) 2>/dev/null || true
else
    if ! mountpoint -q $LFS/dev/shm; then
        mount -vt tmpfs -o nosuid,nodev tmpfs $LFS/dev/shm
    fi
fi

echo "Virtual kernel file systems mounted successfully"

#######################################
# Step 3: Create directory structure and essential files
#######################################
echo "=== Step 3: Creating Directory Structure and Essential Files ==="

# Create script to run inside chroot
cat > $LFS/phase3-setup.sh << 'CHROOT_EOF'
#!/bin/bash
set -e

echo "=== Inside Chroot Environment ==="

# Create directory structure
mkdir -pv /{boot,home,mnt,opt,srv}
mkdir -pv /etc/{opt,sysconfig}
mkdir -pv /lib/firmware
mkdir -pv /media/{floppy,cdrom}
mkdir -pv /usr/{,local/}{include,src}
mkdir -pv /usr/lib/locale
mkdir -pv /usr/local/{bin,lib,sbin}
mkdir -pv /usr/{,local/}share/{color,dict,doc,info,locale,man}
mkdir -pv /usr/{,local/}share/{misc,terminfo,zoneinfo}
mkdir -pv /usr/{,local/}share/man/man{1..8}
mkdir -pv /var/{cache,local,log,mail,opt,spool}
mkdir -pv /var/lib/{color,misc,locate}

# Create symbolic links
ln -sfv /run /var/run
ln -sfv /run/lock /var/lock

# Create directories with special permissions
install -dv -m 0750 /root
install -dv -m 1777 /tmp /var/tmp

echo "Directory structure created"

# Create essential files and symlinks
echo "=== Creating Essential Files ==="

# Create /etc/mtab symlink
ln -sfv /proc/self/mounts /etc/mtab

# Create /etc/hosts
cat > /etc/hosts << EOF
127.0.0.1  localhost $(hostname)
::1        localhost
EOF

# Create /etc/passwd
cat > /etc/passwd << "EOF"
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/usr/bin/false
daemon:x:6:6:Daemon User:/dev/null:/usr/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/run/dbus:/usr/bin/false
uuidd:x:80:80:UUID Generation Daemon User:/dev/null:/usr/bin/false
nobody:x:65534:65534:Unprivileged User:/dev/null:/usr/bin/false
EOF

# Create /etc/group
cat > /etc/group << "EOF"
root:x:0:
bin:x:1:
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
input:x:24:
mail:x:34:
kvm:x:61:
uuidd:x:80:
wheel:x:97:
users:x:999:
nogroup:x:65534:
EOF

# Initialize log files
touch /var/log/{btmp,lastlog,faillog,wtmp}
chgrp -v utmp /var/log/lastlog
chmod -v 664  /var/log/lastlog
chmod -v 600  /var/log/btmp

echo "Essential files created"
echo ""
echo "=== Phase 3 Basic Setup Complete ==="
echo "Chroot environment is ready"
echo ""

CHROOT_EOF

chmod +x $LFS/phase3-setup.sh

# Execute the chroot script
echo "=== Entering Chroot for Setup ==="

chroot "$LFS" /usr/bin/env -i   \
    HOME=/root                  \
    TERM="$TERM"                \
    PS1='(lfs chroot) \u:\w\$ ' \
    PATH=/usr/bin:/usr/sbin     \
    /bin/bash /phase3-setup.sh

# Clean up the script
rm -f $LFS/phase3-setup.sh

echo ""
echo "=== Phase 3 Basic Setup Complete ==="
echo "Chroot environment is configured and ready"
echo "Note: Additional tools (Gettext, Bison, Perl, Python, Texinfo, Util-linux)"
echo "      will be built in Phase 4 as part of the full system build"
echo ""
