#!/usr/bin/env bash
set -euo pipefail
# Bounded serial Swift-only replay in a fresh disposable workspace. No downloads,
# model calls, native-device claims, credentials, live source edits or publication.
repo="${1:?Pass the source repository root}"
work="${2:?Pass a NEW disposable writable work directory}"
stage="$(cd "$(dirname "$0")/../.." && pwd)"
[[ ! -e "$work" ]] || { echo 'Refusing to overwrite an existing workspace.' >&2; exit 2; }
mkdir -p "$work/BlindCore" "$work/logs" "$work/swift-cache" "$work/clang-cache" "$work/package-cache" "$work/config" "$work/security"
cp -a "$repo/BlindCore/Package.swift" "$repo/BlindCore/Sources" "$repo/BlindCore/Tests" "$work/BlindCore/"
export SWIFTPM_MODULECACHE_OVERRIDE="$work/swift-cache"
export CLANG_MODULE_CACHE_PATH="$work/clang-cache"
swift --version > "$work/logs/toolchain.txt"
cp "$stage/reconstruction/reference/ReferenceLegacyFailureWitnessTests.swift" "$work/BlindCore/Tests/BlindCoreTests/"
set +e
swift test --package-path "$work/BlindCore" --scratch-path "$work/build" --jobs 1 \
    --cache-path "$work/package-cache" --config-path "$work/config" --security-path "$work/security" \
    --filter ReferenceLegacyFailureWitnessTests > "$work/logs/01-fail-before.log" 2>&1
before=$?
set -e
[[ $before -ne 0 ]] && grep -q 'XCTAssertEqual failed' "$work/logs/01-fail-before.log" \
    && grep -q 'Executed 1 test, with 1 failure' "$work/logs/01-fail-before.log" \
    || { echo 'Expected long-reference loss was not reproduced; inspect the log, do not claim it passed.' >&2; exit 3; }
# Keep the EXPECTED-FAILURE witness and output, but outside the passing test target.
# The generic path is deliberately not repaired: the direct source lane avoids it.
mv "$work/BlindCore/Tests/BlindCoreTests/ReferenceLegacyFailureWitnessTests.swift" "$work/ReferenceLegacyFailureWitnessTests.swift"
cp "$stage/BlindCore/Sources/BlindCore/CompanionReferenceReading.swift" "$work/BlindCore/Sources/BlindCore/"
cp "$stage/BlindCore/Tests/BlindCoreTests/CompanionReferenceReadingTests.swift" "$work/BlindCore/Tests/BlindCoreTests/"
cp "$stage/BlindCore/Tests/BlindCoreTests/Fixtures/reference-reading-authored.json" "$work/BlindCore/Tests/BlindCoreTests/Fixtures/"
swift test --package-path "$work/BlindCore" --scratch-path "$work/build" --jobs 1 \
    --cache-path "$work/package-cache" --config-path "$work/config" --security-path "$work/security" \
    --filter 'CompanionReferenceReadingTests|SpeechDeliveryLedgerTests|ReadingToolsTests|ReadingWorkSessionTests|CompanionEvidenceTests' \
    2>&1 | tee "$work/logs/02-focused-and-affected.log"
swift test --package-path "$work/BlindCore" --scratch-path "$work/build" --jobs 1 \
    --cache-path "$work/package-cache" --config-path "$work/config" --security-path "$work/security" \
    2>&1 | tee "$work/logs/03-full-portable-package.log"
echo 'Portable Core verification only. Native exact-model manual adapter and real speech callbacks remain unintegrated.'
