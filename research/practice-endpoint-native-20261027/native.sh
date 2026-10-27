#!/usr/bin/env bash
# Native lifetimes use GitHub step/job timeouts; no process-group runner or retries.
set -euo pipefail
mode="${1:?Expected setup, ui, or export}"
source_root="${GITHUB_WORKSPACE:?}/pinned-practice-source"
here="$GITHUB_WORKSPACE/research/practice-endpoint-native-20261027"
out="${RUNNER_TEMP:?}/blind-native-ci"
evidence="$RUNNER_TEMP/blind-practice-endpoint-native"
cd "$source_root"
case "$mode" in
  setup)
    device="$(cat "$out/simulator-id")"
    xcrun simctl list devices available --json > "$evidence/installed-devices-private.json"
    state="$(python3 - "$here" "$evidence/installed-devices-private.json" "$device" <<'PY'
import json,sys
from pathlib import Path
sys.path.insert(0,sys.argv[1])
from evidence import simulator_state
path=Path(sys.argv[2])
if path.stat().st_size>1024*1024:raise ValueError('Simulator listing exceeds 1 MiB')
print(simulator_state(json.loads(path.read_text()),sys.argv[3]))
PY
    )"
    if [[ "$state" = Shutdown ]]; then xcrun simctl boot "$device"; fi
    xcrun simctl bootstatus "$device" -b
    ;;
  ui)
    device="$(cat "$out/simulator-id")"
    # Same base/destination/test invocation as pinned native-apple.sh UI mode.
    # Only selected methods, log/bundle names and the existing layout opt-in differ.
    project=ios/BlindAssist.xcodeproj
    base=(-project "$project" -scheme BlindAssist -configuration Debug -jobs 2
          -derivedDataPath "$out/DerivedData" CODE_SIGNING_ALLOWED=NO)
    for size in large accessibility-extra-extra-extra-large; do
      selector=BlindAssistUITests/LaunchTests/testPracticeLayoutAtDefaultSize
      if [[ "$size" != large ]]; then selector=BlindAssistUITests/LaunchTests/testPracticeLayoutAtLargestAccessibilitySize; fi
      xcrun simctl ui "$device" content_size "$size"
      observed="$(xcrun simctl ui "$device" content_size)"
      python3 "$here/evidence.py" category "$source_root" "$size" "$observed"
      python3 "$here/evidence.py" execution "$source_root" "$size" started
      status=0
      TEST_RUNNER_BLIND_LAYOUT_DIAGNOSTIC=1 xcodebuild "${base[@]}" -destination "platform=iOS Simulator,id=$device" \
        -destination-timeout 120 -parallel-testing-enabled NO \
        -maximum-concurrent-test-simulator-destinations 1 -only-testing:"$selector" \
        -resultBundlePath "$out/$size.xcresult" test > "$out/$size.log" 2>&1 || status=$?
      python3 "$here/evidence.py" execution "$source_root" "$size" "$status"
      # Record the strict receipt even after native failure, then stop without a retry.
      receipt_status=0
      python3 "$here/evidence.py" receipt "$source_root" "$size" || receipt_status=$?
      printf 'PRACTICE_NATIVE size=%s nativeExit=%s receiptExit=%s\n' "$size" "$status" "$receipt_status"
      if (( status != 0 || receipt_status != 0 )); then
        if [[ "$size" = large ]]; then
          python3 "$here/evidence.py" not-run-after-predecessor "$source_root" accessibility-extra-extra-extra-large
        fi
        exit 1
      fi
    done
    ;;
  export)
    size="${2:?Expected exact endpoint size}"
    case "$size" in large|accessibility-extra-extra-extra-large) ;; *) exit 2 ;; esac
    status=1
    if [[ -d "$out/$size.xcresult" ]]; then
      status=0
      xcrun xcresulttool export attachments --path "$out/$size.xcresult" \
        --output-path "$evidence/export-private-$size" > "$evidence/export-private-$size.log" 2>&1 || status=$?
    fi
    python3 "$here/evidence.py" collect "$source_root" "$size" "$status"
    ;;
  *) exit 2 ;;
esac
