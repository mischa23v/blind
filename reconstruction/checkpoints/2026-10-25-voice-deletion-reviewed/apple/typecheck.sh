#!/bin/bash
set -euo pipefail
# Standalone SDK check only. Do not substitute a macOS compile with os(iOS) excluded.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
test "$(uname -s)" = Darwin || { echo 'ERROR: actual Apple SDK host required' >&2; exit 1; }
xcodebuild -version
xcrun --sdk iphoneos swiftc --version
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
xcrun --sdk iphoneos --show-sdk-version
for SOURCE in VoiceEnrollment.swift ProtectedVoiceEnrollmentStore.swift; do
  test -f "$ROOT/source/$SOURCE"
  shasum -a 256 "$ROOT/source/$SOURCE"
done
SCRATCH="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/voice-enrollment-typecheck.XXXXXX")"
trap 'rm -rf "$SCRATCH"' EXIT
xcrun --sdk iphoneos swiftc -typecheck -parse-as-library -swift-version 5 \
  -target arm64-apple-ios17.0 -sdk "$SDK" \
  -module-cache-path "$SCRATCH/module-cache" \
  -module-name VoiceEnrollmentCompileProbe \
  "$ROOT/source/VoiceEnrollment.swift" "$ROOT/source/ProtectedVoiceEnrollmentStore.swift"
echo 'PASS: standalone iOS SDK typecheck only; no actor execution, app integration or device acceptance'
