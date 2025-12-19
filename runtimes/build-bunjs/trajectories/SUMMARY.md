# Building Bun from Source - Agent Trajectory Summary

## Overview

| Metric | Value |
|--------|-------|
| Agent | Claude Opus 4.5 |
| Duration | ~45 minutes |
| Sessions | 1 |
| Outcome | PARTIAL (0.6) |

## User Request

"Build Bun from source as an experiment for the llm-builds-linux benchmark"

## Approach

1. Research Bun's official build documentation
2. Create Docker environment with all dependencies
3. Iteratively fix issues as they arise
4. Document findings for benchmark purposes

## Key Steps

### Phase 1: Research (10 min)

1. Fetched Bun contributing documentation from https://bun.sh/docs/project/contributing
2. Identified key requirements:
   - LLVM 19 (must match WebKit version)
   - Rust, Go, Ruby, CMake, Ninja
   - Bun itself (bootstrapping requirement)
   - ~10GB disk space

### Phase 2: Docker Environment Setup (15 min)

1. Created Dockerfile based on Ubuntu 24.04
2. Added LLVM 19 installation via official LLVM script
3. Added all build dependencies
4. Installed Bun for bootstrapping
5. Created build.sh orchestration script

### Phase 3: First Build Attempt - Cargo.lock Failure (5 min)

1. Built Docker image successfully
2. **Build failed** with error:
   ```
   error: failed to parse lock file at: /build/bun/vendor/lolhtml/c-api/Cargo.lock
   Caused by: lock file version 4 requires `-Znext-lockfile-bump`
   ```
3. **Root cause**: Ubuntu 24.04's Rust 1.75 is too old for Cargo.lock v4 format
4. **Fix**: Replaced `apt install rustc cargo` with rustup installation

### Phase 4: Second Build Attempt - Progress! (15 min)

1. Rebuilt Docker image with rustup Rust
2. Build progressed significantly:
   - CMake configuration: SUCCESS
   - Downloaded 20+ dependencies (lolhtml, brotli, zstd, highway, etc.)
   - JavaScript module bundling: SUCCESS (1780kb, 136 modules)
   - C/C++ compilation: ~108 files compiled
3. **Build failed** at step 108/632:
   ```
   FAILED: bun-zig.o
   error: the following command terminated unexpectedly:
   /build/bun/vendor/zig/zig build-obj ... -target aarch64-linux-gnu.2.26 -mcpu cortex_a35
   ```

### Phase 5: Analysis

1. **Root cause**: Zig's `-mcpu native` detection fails in Docker ARM64 emulation
2. The Zig compiler detected `cortex_a35` which may not be correctly emulated
3. This is an environment limitation, not a code issue

## Artifacts Produced

| File | Lines | Description |
|------|-------|-------------|
| `artifacts/Dockerfile` | 85 | Complete build environment with LLVM 19, Rust, Go, etc. |
| `artifacts/build.sh` | 60 | Build orchestration script with verification |
| `README.md` | 116 | Comprehensive documentation of results |
| `EXPERIMENT.yaml` | 75 | Machine-readable experiment metadata |

## Metrics

| Metric | Value |
|--------|-------|
| Tool calls | ~50 |
| Files created | 4 |
| Docker images built | 3 |
| Build attempts | 3 |
| Dependencies resolved | 20+ |

## Where Agent Succeeded

1. **Dependency research**: Correctly identified all build requirements from docs
2. **Environment setup**: Created working Docker environment with complex dependencies
3. **Issue diagnosis**: Quickly identified Cargo.lock v4 issue and fixed it
4. **Progress**: Got build to 17% completion (108/632 steps)
5. **Documentation**: Comprehensive documentation of findings

## Where Agent Struggled

1. **Platform limitations**: Could not work around Docker ARM64 emulation issues
2. **Zig compiler issues**: Unable to debug internal Zig build failures

## Lessons for Agent Evaluation

1. **Version mismatches are common blockers**: Agents must be able to diagnose and fix version issues
2. **Docker emulation has limitations**: Native hardware may be required for some builds
3. **Partial progress is valuable**: Even 17% of a 632-step build demonstrates capability
4. **Bootstrapping is a real pattern**: Many tools require themselves to build
5. **Documentation quality matters**: Good error messages enable diagnosis

## Reproduction Steps

```bash
# Clone the repository
cd runtimes/build-bunjs/artifacts

# Build Docker image
docker build -t bun-build -f Dockerfile .

# Run build (will progress ~17% before Zig failure on emulated ARM64)
docker run --rm bun-build /build/build.sh

# For native ARM64 or x86_64, the build may complete successfully
```

## Recommendations for Future Attempts

1. Use native hardware instead of Docker emulation
2. Try x86_64 build instead of ARM64
3. Consider using Bun's official devcontainer configuration
4. Pre-download WebKit/JSC to avoid network delays
5. Increase available memory for Zig compilation
