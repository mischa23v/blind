#!/usr/bin/env bash
# Only the dedicated public CI workflow; NEVER a connected user device.
set -euo pipefail
source_root=${1:?Pinned source checkout required}
packet=$(cd "$(dirname "$0")" && pwd)
base_packet=$(cd "$packet/../native-workflows" && pwd)
out=${RUNNER_TEMP:?Disposable CI runner required}/blind-search-clue-native
[[ ${GITHUB_ACTIONS:-} == true && ${GITHUB_REPOSITORY:-} == mischa23v/blind ]]
[[ $(uname -s) == Darwin ]]
expected_commit=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["commit"])' "$packet/accessible-source-pins.json")
[[ "$expected_commit" =~ ^[a-f0-9]{40}$ ]]
[[ $(git -C "$source_root" rev-parse HEAD) == "$expected_commit" ]]
[[ ! -e "$out" ]]
mkdir -p "$out"
sim=''
cleanup() { if [[ -n "$sim" ]]; then xcrun simctl shutdown "$sim" || true; xcrun simctl delete "$sim" || true; fi; }
trap cleanup EXIT
xcodebuild -version > "$out/toolchain.txt"
[[ $(xcrun --sdk iphonesimulator --show-sdk-version) == 27.0 ]]
python3 "$packet/prepare_accessible.py" "$source_root" "$out/host" "$base_packet"
node "$out/host/tools/generate-xcode-project.mjs" > "$out/generate.log"
project="$out/host/ios/BlindAssist.xcodeproj"
! grep -Eq 'CODE_SIGN_ENTITLEMENTS|org.blindassist.mobility|BLIND_DEVELOPER_CLOUD' "$project/project.pbxproj"
grep -q 'org.blindassist.searchcluespeechtests' "$project/project.pbxproj"
base=(-project "$project" -scheme BlindAssist -configuration Debug -jobs 2
      -derivedDataPath "$out/DerivedData" -clonedSourcePackagesDirPath "$out/packages" CODE_SIGNING_ALLOWED=NO)
# Only existing exact GRDB dependency. No frameworks, runtime, model or asset installs.
xcodebuild "${base[@]}" -resolvePackageDependencies > "$out/resolve.log" 2>&1
python3 - "$out" <<'PY'
import pathlib,json,sys
out=pathlib.Path(sys.argv[1]); pins=[]
for p in (out/'host').rglob('Package.resolved'):
 d=json.loads(p.read_text()); pins.extend(d.get('pins',d.get('object',{}).get('pins',[])))
assert pins, 'No resolved dependency evidence'
for pin in pins:
 assert pin.get('identity',pin.get('package','')).lower() in ('grdb.swift','grdb'), pin
 assert pin['state']['version']=='7.11.1', pin
 assert pin['state']['revision']=='b83108d10f42680d78f23fe4d4d80fc88dab3212', pin
(out/'resolved-pins.json').write_text(json.dumps(pins,indent=2))
PY
# simctl create fails if either installed identifier is unavailable; no download fallback.
sim=$(xcrun simctl create "BlindAccessible-${GITHUB_RUN_ID}-${GITHUB_RUN_ATTEMPT}" \
  com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro-Max com.apple.CoreSimulator.SimRuntime.iOS-27-0)
printf '%s\n' "$sim" > "$out/created-simulator-id.txt"
xcrun simctl boot "$sim"
xcrun simctl bootstatus "$sim" -b
status=0
xcodebuild "${base[@]}" -disableAutomaticPackageResolution -skipPackageUpdates \
  -destination "platform=iOS Simulator,id=$sim" -destination-timeout 120 \
  -only-testing:BlindAssistTests/NativeSearchClueSpeechTests \
  -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 \
  -resultBundlePath "$out/accessible.xcresult" test > "$out/test.log" 2>&1 || status=$?
printf '%s\n' "$status" > "$out/test-exit-code.txt"
# Never turn missing result, skip, missing test, compile error or failure into success.
if [[ -d "$out/accessible.xcresult" ]]; then
 xcrun xcresulttool get test-results summary --path "$out/accessible.xcresult" > "$out/summary.json" || true
 xcrun xcresulttool export attachments --path "$out/accessible.xcresult" --output-path "$out/attachments" > "$out/export.log" 2>&1 || true
fi
tail -100 "$out/test.log"
[[ "$status" == 0 ]]
python3 - "$out/summary.json" <<'PY'
import json,sys
s=json.load(open(sys.argv[1])); print(json.dumps(s,indent=2))
assert s.get('totalTestCount') == 1 and s.get('passedTests') == 1, 'Exactly one bounded search-clue callback probe must execute/pass'
assert s.get('failedTests') == 0 and s.get('skippedTests') == 0, 'No failure/skip allowed'
assert s.get('expectedFailures',0) == 0, 'No expected-failure masking'
PY
