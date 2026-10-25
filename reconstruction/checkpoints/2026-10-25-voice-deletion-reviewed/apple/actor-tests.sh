#!/bin/bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
test "$(uname -s)" = Darwin || { echo 'ERROR: actual Apple simulator host required' >&2; exit 1; }
# Always gate actor execution on untouched production-source Apple typechecking.
bash "$HERE/typecheck.sh"
SCRATCH="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/voice-enrollment-actor.XXXXXX")"
DEVICE=''
cleanup() {
  if [[ -n "$DEVICE" ]]; then
    xcrun simctl shutdown "$DEVICE" >/dev/null 2>&1 || true
    xcrun simctl delete "$DEVICE" >/dev/null 2>&1 || true
  fi
  rm -rf "$SCRATCH"
}
trap cleanup EXIT
node "$HERE/generate-project.mjs" "$SCRATCH/project"
xcrun simctl list runtimes --json > "$SCRATCH/runtimes.json"
xcrun simctl list devicetypes --json > "$SCRATCH/types.json"
python3 - "$SCRATCH" <<'PY'
import json, pathlib, sys
out = pathlib.Path(sys.argv[1])
runtime = next((r for r in json.loads((out/'runtimes.json').read_text())['runtimes']
    if r['identifier'] == 'com.apple.CoreSimulator.SimRuntime.iOS-27-0' and r.get('isAvailable')), None)
kind = next((d for d in json.loads((out/'types.json').read_text())['devicetypes']
    if d['name'] == 'iPhone 18 Pro Max'), None)
if not runtime or not kind:
    raise SystemExit('Required installed iOS 27.0 / iPhone 18 Pro Max unavailable; no download attempted.')
(out/'runtime').write_text(runtime['identifier'])
(out/'type').write_text(kind['identifier'])
PY
# Own a disposable simulator; never erase, shut down or cancel another CI job's device.
DEVICE="$(xcrun simctl create "VoiceEnrollmentProbe-$(uuidgen)" "$(cat "$SCRATCH/type")" "$(cat "$SCRATCH/runtime")")"
STATUS=0
xcodebuild -project "$SCRATCH/project/VoiceProbe.xcodeproj" -scheme VoiceProbe \
  -configuration Debug -jobs 2 -derivedDataPath "$SCRATCH/DerivedData" \
  -destination "platform=iOS Simulator,id=$DEVICE" -destination-timeout 120 \
  -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 \
  -only-testing:VoiceProbeTests -resultBundlePath "$SCRATCH/ActorTests.xcresult" \
  CODE_SIGNING_ALLOWED=NO test > "$SCRATCH/test.log" 2>&1 || STATUS=$?
if (( STATUS != 0 )); then
  grep -E -i 'error:|fatal|Test (Case|Suite).* failed|\*\* (BUILD|TEST) FAILED' "$SCRATCH/test.log" | head -100 || true
  tail -50 "$SCRATCH/test.log"
  exit "$STATUS"
fi
xcrun xcresulttool get test-results summary --path "$SCRATCH/ActorTests.xcresult" > "$SCRATCH/summary.json"
python3 - "$SCRATCH/summary.json" <<'PY'
import json, sys
s = json.load(open(sys.argv[1]))
keys = ('result','totalTestCount','passedTests','failedTests','skippedTests')
print('Actor XCTest result: ' + json.dumps({k:s.get(k) for k in keys}))
if (s.get('totalTestCount'), s.get('passedTests'), s.get('failedTests'), s.get('skippedTests')) != (2, 2, 0, 0):
    raise SystemExit('Expected exactly two passing actor tests and no skips; refusing inferred success.')
PY
echo 'PASS: synthetic iOS simulator actor tests only; protection APIs were not bypassed; no physical-device/privacy-lifecycle acceptance'
# Only bounded compiler/test diagnostics and counts are printed. No result bundle upload.
