#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export HOME="$ROOT/home" TMPDIR="$ROOT/tmp" XDG_CACHE_HOME="$ROOT/cache"
export CLANG_MODULE_CACHE_PATH="$ROOT/cache/clang" SWIFT_MODULECACHE_PATH="$ROOT/cache/swift" SWIFTPM_MODULECACHE_OVERRIDE="$ROOT/cache/swift"
export BLIND_SWIFTC=/workspace/shared/swift-toolchain/install/swift-6.4.1-RELEASE-debian13/usr/bin/swiftc
export BLIND_GRDB_PATH=/workspace/shared/blind-incremental-memory-build/checkouts/GRDB.swift
export SQLITE_TEST_SDK=/workspace/shared/sqlite-sdk-3.46.1
export BLIND_REGISTRATION_REPLAY_SCRATCH="$ROOT/replay" BLIND_TEST_SCRATCH="$ROOT/test-scratch"
export BLIND_RECORDED_TRAJECTORY=/workspace/shared/blind-rebuild-map-data/arkitscenes-47333462/originals/lowres_wide.traj
mkdir -p "$HOME" "$TMPDIR" "$XDG_CACHE_HOME" "$SWIFT_MODULECACHE_PATH" "$CLANG_MODULE_CACHE_PATH" "$BLIND_TEST_SCRATCH"
cd "$ROOT/validation"
"$(dirname "$BLIND_SWIFTC")/swift" test --package-path BlindCore --scratch-path "$ROOT/replay/.build" --cache-path "$ROOT/cache/spm" --config-path "$ROOT/cache/config" --security-path "$ROOT/cache/security" --jobs 2 > "$ROOT/evidence/core-aggregate.log" 2>&1
node --test --test-concurrency=1 server/test/*.test.mjs tools/test/*.test.mjs > "$ROOT/evidence/node-aggregate.log" 2>&1
