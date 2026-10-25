#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export HOME="$ROOT/test-scratch/home"
export TMPDIR="$ROOT/test-scratch/tmp"
export XDG_CACHE_HOME="$ROOT/test-scratch/cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT/test-scratch/modules"
export CLANG_MODULE_CACHE_PATH="$ROOT/test-scratch/clang-cache"
export BLIND_TEST_SCRATCH="$ROOT/test-scratch"
export BLIND_SWIFTC=/workspace/shared/swift-toolchain/install/swift-6.4.1-RELEASE-debian13/usr/bin/swiftc
mkdir -p "$HOME" "$TMPDIR" "$XDG_CACHE_HOME" "$SWIFTPM_MODULECACHE_OVERRIDE" "$CLANG_MODULE_CACHE_PATH"
cd "$ROOT/validation-worktree"
node --test --test-concurrency=1 server/test/*.test.mjs tools/test/*.test.mjs
