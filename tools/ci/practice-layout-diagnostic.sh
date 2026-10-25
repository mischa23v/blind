#!/usr/bin/env bash
# Synthetic UI test only. Own simulator; no production or existing audit modifications.
set -euo pipefail
out="${RUNNER_TEMP:?}/blind-practice-layout"
mkdir -p "$out/screenshots"
device=""
cleanup() {
  local original_status=$?
  trap - EXIT
  if [[ -n "$device" ]]; then
    xcrun simctl shutdown "$device" || echo 'PRACTICE_LAYOUT simulator shutdown unavailable; attempting deletion'
    if ! xcrun simctl delete "$device"; then
      echo "PRACTICE_LAYOUT cleanup failed: could not delete owned simulator $device" >&2
      original_status=1
    fi
  fi
  exit "$original_status"
}
trap cleanup EXIT
xcrun simctl list devicetypes --json > "$out/device-types.json"
type="$(python3 - "$out/device-types.json" <<'PY'
import json,sys
matches=[d['identifier'] for d in json.load(open(sys.argv[1]))['devicetypes'] if d['name']=='iPhone 18 Pro Max']
assert len(matches)==1, 'Required installed phone type is not unique'
print(matches[0])
PY
)"
device="$(xcrun simctl create "Blind-Practice-Layout-${GITHUB_RUN_ID:-local}-${GITHUB_RUN_ATTEMPT:-1}" "$type" com.apple.CoreSimulator.SimRuntime.iOS-27-0)"
xcrun simctl boot "$device"
xcrun simctl bootstatus "$device" -b
printf 'PRACTICE_LAYOUT source=%s simulator=%s\n' "$(git rev-parse HEAD)" "$device"
# Fail with installed help if this Xcode lacks the command; never substitute defaults writes.
xcrun simctl help ui > "$out/simctl-ui-help.txt"
status=0
for size in large accessibility-extra-extra-extra-large; do
  selector=testPracticeLayoutAtDefaultSize
  if [[ "$size" != large ]]; then selector=testPracticeLayoutAtLargestAccessibilitySize; fi
  xcrun simctl ui "$device" content_size "$size"
  printf 'PRACTICE_LAYOUT requested=%s observed=' "$size"
  xcrun simctl ui "$device" content_size
  result=0
  TEST_RUNNER_BLIND_LAYOUT_DIAGNOSTIC=1 xcodebuild -project ios/BlindAssist.xcodeproj -scheme BlindAssist -configuration Debug -jobs 2 \
    -derivedDataPath "$out/DerivedData" CODE_SIGNING_ALLOWED=NO \
    -destination "platform=iOS Simulator,id=$device" -destination-timeout 120 \
    -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 \
    -only-testing:"BlindAssistUITests/LaunchTests/$selector" \
    -resultBundlePath "$out/$size.xcresult" test > "$out/$size.log" 2>&1 || result=$?
  printf 'PRACTICE_LAYOUT size=%s exit=%s\n' "$size" "$result"
  grep -E 'PRACTICE_LAYOUT|error:|Test Case .* (passed|failed)|Executed .*failure' "$out/$size.log" | tail -100 || true
  if (( result != 0 )); then status=1; fi
  if ! grep -q "PRACTICE_LAYOUT afterReveal.*role=footer" "$out/$size.log"; then
    echo "PRACTICE_LAYOUT incomplete: footer evidence missing for $size"
    status=1
  fi
  if [[ -d "$out/$size.xcresult" ]]; then
    if xcrun xcresulttool export attachments --path "$out/$size.xcresult" --output-path "$out/attachments-$size"; then
      # Fail closed unless all three exact test-authored role screenshots exist.
      if ! python3 tools/ci/export-practice-layout-screenshots.py "$out/attachments-$size" "$out/screenshots" "$size"; then
        status=1
      fi
    else
      echo 'PRACTICE_LAYOUT attachment export failed'
      status=1
    fi
  fi
  if [[ ! -d "$out/$size.xcresult" ]]; then
    echo "PRACTICE_LAYOUT missing xcresult for $size"
    status=1
  fi
  printf 'PRACTICE_LAYOUT final category='; xcrun simctl ui "$device" content_size
 done
exit "$status"
