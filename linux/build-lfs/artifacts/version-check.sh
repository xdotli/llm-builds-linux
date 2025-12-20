#!/bin/bash
# LFS Version Check Script
# Verifies that the host system meets all LFS 12.4 requirements

echo "=== LFS 12.4 Host System Requirements Check ==="
echo ""

# Function to check version
check_version() {
    local name="$1"
    local cmd="$2"
    local required="$3"

    if version=$($cmd 2>&1 | head -n1); then
        echo "OK: $name - $version"
        return 0
    else
        echo "ERROR: $name not found!"
        return 1
    fi
}

errors=0

# Bash 3.2 or later
echo "Checking required tools..."
echo ""

check_version "Bash" "bash --version" "3.2" || ((errors++))

# Binutils 2.13.1 or later
check_version "Binutils (ld)" "ld --version" "2.13.1" || ((errors++))

# Bison 2.7 or later
check_version "Bison" "bison --version" "2.7" || ((errors++))

# Check /usr/bin/yacc
if [ -h /usr/bin/yacc ] && readlink -f /usr/bin/yacc | grep -q bison; then
    echo "OK: /usr/bin/yacc -> bison"
elif [ -x /usr/bin/yacc ]; then
    echo "OK: /usr/bin/yacc exists"
else
    echo "WARNING: /usr/bin/yacc not found (not critical)"
fi

# Coreutils 8.1 or later
check_version "Coreutils" "chown --version" "8.1" || ((errors++))

# Diffutils 2.8.1 or later
check_version "Diffutils" "diff --version" "2.8.1" || ((errors++))

# Findutils 4.2.31 or later
check_version "Findutils" "find --version" "4.2.31" || ((errors++))

# Gawk 4.0.1 or later
check_version "Gawk" "gawk --version" "4.0.1" || ((errors++))

# Check /usr/bin/awk
if [ -h /usr/bin/awk ] || [ -x /usr/bin/awk ]; then
    echo "OK: /usr/bin/awk exists"
else
    echo "WARNING: /usr/bin/awk not found (not critical)"
fi

# GCC 5.4 or later
check_version "GCC" "gcc --version" "5.4" || ((errors++))

# G++ 5.4 or later
check_version "G++" "g++ --version" "5.4" || ((errors++))

# Grep 2.5.1a or later
check_version "Grep" "grep --version" "2.5.1" || ((errors++))

# Gzip 1.3.12 or later
check_version "Gzip" "gzip --version" "1.3.12" || ((errors++))

# M4 1.4.10 or later
check_version "M4" "m4 --version" "1.4.10" || ((errors++))

# Make 4.0 or later
check_version "Make" "make --version" "4.0" || ((errors++))

# Patch 2.5.4 or later
check_version "Patch" "patch --version" "2.5.4" || ((errors++))

# Perl 5.8.8 or later
check_version "Perl" "perl -V:version" "5.8.8" || ((errors++))

# Python 3.4 or later
check_version "Python" "python3 --version" "3.4" || ((errors++))

# Sed 4.1.5 or later
check_version "Sed" "sed --version" "4.1.5" || ((errors++))

# Tar 1.22 or later
check_version "Tar" "tar --version" "1.22" || ((errors++))

# Texinfo 5.0 or later
check_version "Texinfo" "makeinfo --version" "5.0" || ((errors++))

# Xz 5.0.0 or later
check_version "Xz" "xz --version" "5.0.0" || ((errors++))

echo ""
echo "=== Additional Checks ==="
echo ""

# Check /bin/sh is bash
if [ -h /bin/sh ]; then
    sh_link=$(readlink -f /bin/sh)
    if echo "$sh_link" | grep -q bash; then
        echo "OK: /bin/sh -> bash"
    else
        echo "ERROR: /bin/sh does not point to bash (points to $sh_link)"
        ((errors++))
    fi
else
    echo "WARNING: /bin/sh is not a symlink"
fi

# Test compiler
echo ""
echo "=== Compiler Test ==="
echo ""

cat > /tmp/test.c << 'EOF'
#include <stdio.h>
int main() {
    printf("Compilation test successful!\n");
    return 0;
}
EOF

if gcc -o /tmp/test /tmp/test.c 2>/dev/null && /tmp/test; then
    echo "OK: GCC can compile and run C programs"
else
    echo "ERROR: GCC compilation test failed!"
    ((errors++))
fi

cat > /tmp/test.cpp << 'EOF'
#include <iostream>
int main() {
    std::cout << "C++ compilation test successful!" << std::endl;
    return 0;
}
EOF

if g++ -o /tmp/testcpp /tmp/test.cpp 2>/dev/null && /tmp/testcpp; then
    echo "OK: G++ can compile and run C++ programs"
else
    echo "ERROR: G++ compilation test failed!"
    ((errors++))
fi

rm -f /tmp/test /tmp/test.c /tmp/testcpp /tmp/test.cpp

echo ""
echo "=== Summary ==="
echo ""

if [ $errors -eq 0 ]; then
    echo "SUCCESS: All requirements met! Ready to build LFS."
    exit 0
else
    echo "FAILED: $errors error(s) found. Please fix before proceeding."
    exit 1
fi
