# Build Linux Distro with live-build

Build a Linux Mint-based distribution using Debian's `live-build` toolchain.

## Overview

| Metric | Value |
|--------|-------|
| Agent | Claude Opus 4.5 |
| Duration | ~4 hours |
| Sessions | 3 |
| Outcome | **PARTIAL** - Build infrastructure complete, blocked by live-config-upstart |
| Difficulty | Hard |

## Task

Build a custom Linux distribution based on Linux Mint, starting from "can you build a linux distro?" prompt.

## Results

- Created Docker-based build environment (Ubuntu 24.04, amd64)
- Configured live-build with Cinnamon desktop environment
- Solved syslinux symlink and gfxboot issues
- Build blocked by obsolete live-config-upstart package

## Files

```
artifacts/
├── Dockerfile                    # Build environment with syslinux fixes
├── build.sh                      # Container build script
├── run-build.sh                  # Host orchestration
├── auto/
│   ├── config                    # live-build configuration
│   ├── build                     # Build automation
│   └── clean                     # Cleanup script
└── config/
    ├── hooks/                    # Chroot customization hooks
    ├── bootloaders/              # Syslinux configuration
    └── package-lists/            # Package selections
trajectories/
├── SUMMARY.md                    # Detailed trajectory
└── session-build.jsonl           # Session log
```

## Quick Start

```bash
cd artifacts

# Build Docker image
docker build --platform linux/amd64 -t livebuild-builder .

# Run build (currently blocked by upstart)
docker run --platform linux/amd64 --privileged --rm \
    -v "$(pwd)/output:/output" livebuild-builder
```

## Blocking Issue

```
E: Unable to locate package live-config-upstart
```

This package was replaced by systemd in modern Ubuntu. Fix requires switching to Debian mode.

## Key Learnings

1. **live-build has poor error messages** - Failures surface late in build
2. **Ubuntu mode is problematic** - Many packages/themes are Ubuntu-specific
3. **Build time is a bottleneck** - 20-30 min builds make iteration slow
4. **Deprecated package references** - Tools reference obsolete packages
