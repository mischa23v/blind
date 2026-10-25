#!/usr/bin/env bash
# One disposable public CI component run; never a connected user's device.
set -euo pipefail
source_root=${1:?Pinned checkout required}
packet=$(cd "$(dirname "$0")" && pwd)
[[ ${GITHUB_ACTIONS:-} == true && ${GITHUB_REPOSITORY:-} == mischa23v/blind ]]
[[ $(uname -s) == Darwin ]]
expected=96fd2d4048b010594a40f54bd533f2bcf8dbfaa8
[[ $(git -C "$source_root" rev-parse HEAD) == "$expected" ]]
git -C "$source_root" diff --quiet HEAD -- BlindCore
[[ -z $(git -C "$source_root" status --porcelain --untracked-files=all -- BlindCore) ]]
out=${RUNNER_TEMP:?Disposable runner required}/blind-reading-component
[[ ! -e "$out" ]]
mkdir -p "$out"
sim=''
cleanup() { if [[ -n "$sim" ]]; then xcrun simctl shutdown "$sim" || true; xcrun simctl delete "$sim" || true; fi; }
trap cleanup EXIT
xcodebuild -version > "$out/toolchain.txt"
[[ $(xcrun --sdk iphonesimulator --show-sdk-version) == 27.0 ]]
xcrun simctl list runtimes --json > "$out/runtimes.json"
xcrun simctl list devicetypes --json > "$out/device-types.json"
node "$packet/generate-project.mjs" "$source_root" "$out/project" > "$out/prepare.log" 2>&1
project="$out/project/ReadingComponent.xcodeproj"
! grep -Eq 'CODE_SIGN_ENTITLEMENTS|org.blindassist.mobility|GRDB|NavigationModel|Feedback.swift' "$project/project.pbxproj"
# Missing preinstalled runtime/device fails. No asset or runtime download fallback.
sim=$(xcrun simctl create "ReadingComponent-${GITHUB_RUN_ID}-${GITHUB_RUN_ATTEMPT}" \
 com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro-Max com.apple.CoreSimulator.SimRuntime.iOS-27-0)
printf '%s\n' "$sim" > "$out/created-simulator.txt"
xcrun simctl boot "$sim"
xcrun simctl bootstatus "$sim" -b
status=0
# One fixed invocation. XCTest's 480s bound terminates this component test only.
xcodebuild -project "$project" -scheme ReadingComponent -configuration Debug -jobs 2 \
 -derivedDataPath "$out/DerivedData" -disableAutomaticPackageResolution -skipPackageUpdates \
 -destination "platform=iOS Simulator,id=$sim" -destination-timeout 120 \
 -only-testing:ReadingComponentTests/CapturedTextNativeComponentTests \
 -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 \
 -resultBundlePath "$out/component.xcresult" CODE_SIGNING_ALLOWED=NO test > "$out/test.log" 2>&1 || status=$?
printf '%s\n' "$status" > "$out/test-exit-code.txt"
if [[ -d "$out/component.xcresult" ]]; then
 xcrun xcresulttool get test-results summary --path "$out/component.xcresult" > "$out/summary.json" || true
 xcrun xcresulttool export attachments --path "$out/component.xcresult" --output-path "$out/attachments" > "$out/export.log" 2>&1 || true
fi
tail -80 "$out/test.log"
[[ "$status" == 0 ]]
python3 - "$out/summary.json" <<'PY'
import json,sys
s=json.load(open(sys.argv[1]))
assert (s.get('totalTestCount'),s.get('passedTests'),s.get('failedTests'),s.get('skippedTests')) == (1,1,0,0),s
print('PASS: one Core plus test-owned AVSpeech component probe; not app/controller/Feedback/camera acceptance.')
PY
