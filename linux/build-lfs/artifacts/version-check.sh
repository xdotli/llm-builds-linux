#!/bin/bash
# LFS Host System Requirements Check Script
# From LFS 12.4 - Chapter 2.2

export LC_ALL=C

echo "=== LFS Host System Requirements Check ==="
echo ""

# Bash version
echo -n "Bash: "
bash --version | head -n1 | cut -d" " -f2-4

# Binutils version
echo -n "Binutils: "
ld --version | head -n1 | cut -d" " -f3-

# Bison version
echo -n "Bison: "
bison --version | head -n1

# Coreutils version
echo -n "Coreutils: "
chown --version | head -n1 | cut -d")" -f2

# Diff version
echo -n "Diffutils: "
diff --version | head -n1

# Findutils version
echo -n "Findutils: "
find --version | head -n1

# Gawk version
echo -n "Gawk: "
gawk --version | head -n1

# GCC version
echo -n "GCC: "
gcc --version | head -n1

# G++ version
echo -n "G++: "
g++ --version | head -n1

# Grep version
echo -n "Grep: "
grep --version | head -n1

# Gzip version
echo -n "Gzip: "
gzip --version | head -n1

# Linux Kernel version (inside container, use uname)
echo -n "Linux Kernel: "
uname -r

# M4 version
echo -n "M4: "
m4 --version | head -n1

# Make version
echo -n "Make: "
make --version | head -n1

# Patch version
echo -n "Patch: "
patch --version | head -n1

# Perl version
echo -n "Perl: "
perl -V:version | cut -d"'" -f2

# Python version
echo -n "Python: "
python3 --version

# Sed version
echo -n "Sed: "
sed --version | head -n1

# Tar version
echo -n "Tar: "
tar --version | head -n1

# Texinfo version
echo -n "Texinfo: "
makeinfo --version | head -n1

# XZ version
echo -n "Xz: "
xz --version | head -n1

echo ""
echo "=== Symlink Verification ==="

# Check /bin/sh is bash
echo -n "/bin/sh -> "
readlink -f /bin/sh

# Check gawk link
if [ -h /usr/bin/awk ]; then
    echo -n "/usr/bin/awk -> "
    readlink -f /usr/bin/awk
fi

# Check yacc link
if [ -h /usr/bin/yacc ]; then
    echo -n "/usr/bin/yacc -> "
    readlink -f /usr/bin/yacc
fi

echo ""
echo "=== Compiler Tests ==="

# Test compiler can build a simple program
echo 'int main(){}' > dummy.c && gcc -o dummy dummy.c
if [ -x dummy ]; then
    echo "GCC compilation: OK"
    rm -f dummy.c dummy
else
    echo "GCC compilation: FAIL"
fi

# Test g++ can build
echo 'int main(){}' > dummy.cpp && g++ -o dummy dummy.cpp
if [ -x dummy ]; then
    echo "G++ compilation: OK"
    rm -f dummy.cpp dummy
else
    echo "G++ compilation: FAIL"
fi

echo ""
echo "=== Environment Variables ==="
echo "LFS=$LFS"
echo "LFS_TGT=$LFS_TGT"
echo "PATH=$PATH"

echo ""
echo "=== Check Complete ==="
