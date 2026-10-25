#!/usr/bin/env bash
# Disposable public hosted CI only. Never run against a connected user's device.
set -euo pipefail
source_root=${1:?Immutable packet checkout required}
packet=$(cd "$(dirname "$0")" && pwd)
[[ ${GITHUB_ACTIONS:-} == true && ${GITHUB_REPOSITORY:-} == mischa23v/blind ]]
[[ ${RUNNER_ENVIRONMENT:-} == github-hosted ]]
[[ $(uname -s) == Darwin && -n ${GITHUB_SHA:-} ]]
[[ $(git -C "$source_root" rev-parse HEAD) == "$GITHUB_SHA" ]]
relative_packet=${packet#"$source_root"/}
[[ "$relative_packet" != "$packet" ]]
git -C "$source_root" diff --quiet HEAD -- "$relative_packet"
[[ -z $(git -C "$source_root" status --porcelain --untracked-files=all -- "$relative_packet") ]]
out=${RUNNER_TEMP:?Disposable runner required}/blind-selected-document-probe
[[ ! -e "$out" ]]
mkdir -p "$out/artifacts"
sim=''
cleanup() {
    local runner_status=$?
    trap - EXIT
    if [[ ! -f "$out/artifacts/receipt.json" ]]; then
        python3 "$packet/export-receipt.py" "$out" "$packet/source-pins.json" "$runner_status" || true
    fi
    if [[ -n "$sim" ]]; then
        xcrun simctl shutdown "$sim" || true
        xcrun simctl delete "$sim" || true
    fi
    exit "$runner_status"
}
trap cleanup EXIT
xcodebuild -version > "$out/artifacts/toolchain.txt"
[[ $(xcrun --sdk iphonesimulator --show-sdk-version) == 27.0 ]]
node "$packet/generate-project.mjs" "$out/project" > "$out/prepare.log" 2>&1
# Framework imports auto-link platform SDKs. No package resolution, resources,
# application entitlement, model or data-store target enters this host.
! grep -Eq 'XCLocalSwiftPackageReference|XCRemoteSwiftPackageReference|CODE_SIGN_ENTITLEMENTS|GRDB|NavigationModel.swift|Feedback.swift|BlindCore' "$out/project/SelectedDocumentProbe.xcodeproj/project.pbxproj"
sim=$(xcrun simctl create "SelectedPDFProbe-${GITHUB_RUN_ID}-${GITHUB_RUN_ATTEMPT}" \
    com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro-Max com.apple.CoreSimulator.SimRuntime.iOS-27-0 2> "$out/simulator.log")
printf '%s\n' "$sim" > "$out/artifacts/owned-simulator.txt"
xcrun simctl boot "$sim"
python3 - "$sim" <<'PY'
import subprocess,sys
subprocess.run(['xcrun','simctl','bootstatus',sys.argv[1],'-b'], check=True, timeout=120)
PY
status=0
python3 "$packet/run-once.py" "$out" "$sim" || status=$?
# Export only bounded text/metadata. Never publish DerivedData, PDF/font files,
# result bundles, arbitrary attachments, simulator directories or raw test logs.
python3 "$packet/export-receipt.py" "$out" "$packet/source-pins.json" "$status"
[[ "$status" == 0 ]]
