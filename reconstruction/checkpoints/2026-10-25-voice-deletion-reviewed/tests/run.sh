#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SWIFTC="${1:?Pass existing swiftc path; no install/download is performed}"
mkdir -p "$ROOT/tmp" "$ROOT/evidence"
export TMPDIR="$ROOT/tmp"
"$SWIFTC" -module-cache-path "$ROOT/tmp/cache" "$ROOT/source/VoiceEnrollment.swift" "$ROOT/tests/main.swift" -o "$ROOT/tmp/enrollment-test" > "$ROOT/evidence/build.log" 2>&1
"$ROOT/tmp/enrollment-test" | tee "$ROOT/evidence/result.log"
