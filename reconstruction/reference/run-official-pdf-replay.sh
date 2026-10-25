#!/usr/bin/env bash
set -euo pipefail
repo="${1:?Pass the repository root}"
pdf="${2:?Pass the separately downloaded pinned official PDF outside the repository}"
work="${3:?Pass a NEW disposable private work directory outside the repository}"
stage="$(cd "$(dirname "$0")/../.." && pwd)"
[[ ! -e "$work" ]] || { echo 'Refusing to overwrite an existing workspace.' >&2; exit 2; }
mkdir -p "$work/BlindCore" "$work/logs" "$work/swift-cache" "$work/clang-cache" "$work/package-cache" "$work/config" "$work/security"
python3 "$stage/reconstruction/reference/official_pdf_replay.py" extract --pdf "$pdf" --private-output "$work/private"
cp -a "$repo/BlindCore/Package.swift" "$repo/BlindCore/Sources" "$repo/BlindCore/Tests" "$work/BlindCore/"
cp "$stage/BlindCore/Sources/BlindCore/CompanionReferenceReading.swift" "$work/BlindCore/Sources/BlindCore/"
cp "$stage/reconstruction/reference/OfficialManufacturerReferenceReplayTests.swift" "$work/BlindCore/Tests/BlindCoreTests/"
cp "$stage/reconstruction/reference/OfficialManufacturerLegacyFailureWitnessTests.swift" "$work/BlindCore/Tests/BlindCoreTests/"
export SWIFTPM_MODULECACHE_OVERRIDE="$work/swift-cache"
export CLANG_MODULE_CACHE_PATH="$work/clang-cache"
export BLIND_REFERENCE_REPLAY_INPUT="$work/private/official-reference-input.json"
export BLIND_REFERENCE_REPLAY_OUTPUT="$work/private/official-reference-output.json"
args=(--package-path "$work/BlindCore" --scratch-path "$work/build" --jobs 1 --cache-path "$work/package-cache" --config-path "$work/config" --security-path "$work/security")
set +e
swift test "${args[@]}" --filter OfficialManufacturerLegacyFailureWitnessTests > "$work/logs/01-official-fail-before.log" 2>&1
before=$?
set -e
[[ $before -ne 0 ]] && grep -q 'XCTAssertEqual failed' "$work/logs/01-official-fail-before.log" \
    && grep -q 'Executed 1 test, with 1 failure' "$work/logs/01-official-fail-before.log" \
    || { echo 'Expected real-source failure was not reproduced; inspect the log.' >&2; exit 3; }
swift test "${args[@]}" --filter OfficialManufacturerReferenceReplayTests 2>&1 | tee "$work/logs/02-official-core-replay.log"
python3 "$stage/reconstruction/reference/official_pdf_replay.py" redact --private-output "$work/private" --evidence-output "$work/official-pdf-redacted-evidence.json"
PYTHONDONTWRITEBYTECODE=1 python3 "$stage/reconstruction/reference/test_official_pdf_replay_adapter.py" 2>&1 | tee "$work/logs/03-adapter-rejection-checks.log"
echo 'Keep the PDF and private/ files outside publication. Only redacted evidence and tests are shareable. Native PDF adapter and actual audio playback remain unvalidated.'
