#!/usr/bin/env bash
# Execute the committed default project. Never regenerate it or enable feature flags.
set -euo pipefail
mode="${1:?Expected preflight, core, memory, build, unit, ui, or summary}"
out="${RUNNER_TEMP:?This helper expects a disposable CI runner}/blind-native-ci"
mkdir -p "$out"
project=ios/BlindAssist.xcodeproj
base=(-project "$project" -scheme BlindAssist -configuration Debug -jobs 2
      -derivedDataPath "$out/DerivedData" CODE_SIGNING_ALLOWED=NO)

run_logged() {
  local label="$1"; shift
  local status=0
  "$@" > "$out/$label.log" 2>&1 || status=$?
  echo "$label exit status: $status"
  # Inputs are committed public source and synthetic tests only; no secrets are supplied.
  # Avoid an environment dump or full build settings. Keep failure diagnostics bounded.
  if (( status != 0 )); then
    # Print real diagnostics before warnings; zero-failure summaries must not consume the cap.
    grep -E -i 'ACCESSIBILITY_AUDIT|error:|fatal|Test (Case|Suite).* failed (at|\()|Executed [0-9]+ tests?, with [1-9][0-9]* failures?|\*\* (BUILD|TEST) FAILED' "$out/$label.log" | head -120 || true
    grep -E 'warning:' "$out/$label.log" | head -20 || true
    tail -60 "$out/$label.log"
  else
    grep -E 'Executed |Test Suite .*passed|Test run with|\*\* (BUILD|TEST)' "$out/$label.log" | tail -35 || true
  fi
  return "$status"
}

case "$mode" in
  preflight)
    test "$(uname -s)" = Darwin
    test -d "$DEVELOPER_DIR"
    git rev-parse HEAD
    shasum -a 256 "$project/project.pbxproj" "$project/xcshareddata/xcschemes/BlindAssist.xcscheme" BlindCore/Package.swift BlindMemory/Package.swift
    xcodebuild -version
    xcrun swift --version
    sdk="$(xcrun --sdk iphonesimulator --show-sdk-version)"
    echo "Simulator SDK: $sdk"
    test "$sdk" = 27.0
    # Do not accidentally test a machine-specific optional project as the default.
    if grep -Eq 'BLIND_[A-Z_]+|opencv2|\.mlmodelc|\.mlpackage' "$project/project.pbxproj"; then
      echo 'Unexpected optional backend/model in default project; refusing to regenerate or override it.' >&2
      exit 1
    fi
    xcrun simctl list devices available --json > "$out/devices.json"
    python3 - "$out" <<'PY'
import json, pathlib, sys
out = pathlib.Path(sys.argv[1])
devices = json.loads((out / 'devices.json').read_text())['devices']
candidates = devices.get('com.apple.CoreSimulator.SimRuntime.iOS-27-0', [])
phone = next((d for d in candidates if d.get('isAvailable') and d['name'] == 'iPhone 18 Pro Max'), None)
if phone is None:
    raise SystemExit('Required installed iOS 27.0 / iPhone 18 Pro Max simulator not found; no runtime download attempted.')
(out / 'simulator-id').write_text(phone['udid'])
print('Simulator: iPhone 18 Pro Max / iOS 27.0')
PY
    ;;
  core)
    run_logged core xcrun swift test --package-path BlindCore --scratch-path "$out/BlindCore-build" --jobs 2
    ;;
  memory)
    # Existing exact GRDB 7.11.1 package dependency only; no weights/framework downloads.
    run_logged memory xcrun swift test --package-path BlindMemory --scratch-path "$out/BlindMemory-build" --jobs 2
    ;;
  build)
    run_logged build xcodebuild "${base[@]}" -destination 'generic/platform=iOS Simulator' build
    ;;
  unit|ui|ui-diagnostic)
    device="$(cat "$out/simulator-id")"
    target=BlindAssistTests
    if [[ "$mode" != unit ]]; then target=BlindAssistUITests; fi
    selector="$target"
    if [[ "$mode" = ui-diagnostic ]]; then selector="$target/LaunchTests/testAccessibilityAuditOfCameraAndAsk"; fi
    run_logged "$mode" xcodebuild "${base[@]}" -destination "platform=iOS Simulator,id=$device" \
      -destination-timeout 120 -parallel-testing-enabled NO \
      -maximum-concurrent-test-simulator-destinations 1 -only-testing:"$selector" \
      -resultBundlePath "$out/$mode.xcresult" test
    ;;
  summary)
    {
      echo '## Native Apple SDK checks'
      printf '\nSource: %s\n' "$(git rev-parse HEAD)"
      printf '\nCore: %s; Memory: %s; simulator build: %s; hosted tests: %s; UI tests: %s\n' \
        "$CORE_OUTCOME" "$MEMORY_OUTCOME" "$BUILD_OUTCOME" "$UNIT_OUTCOME" "$UI_OUTCOME"
      echo 'Default unsigned configuration only. Passing compilation/tests does not establish real model, sensor, VoiceOver, physical-guidance, battery or child-safety acceptance.'
    } >> "$GITHUB_STEP_SUMMARY"
    for suite in unit ui; do
      if [[ -d "$out/$suite.xcresult" ]]; then
        if xcrun xcresulttool get test-results summary --path "$out/$suite.xcresult" > "$out/$suite-summary.json" 2>/dev/null; then
          python3 - "$out/$suite-summary.json" "$suite" <<'PY'
import json, sys
summary = json.load(open(sys.argv[1]))
keys = ('result', 'totalTestCount', 'passedTests', 'failedTests', 'skippedTests', 'expectedFailures', 'startTime', 'finishTime')
# Only counts/status/times, never screenshots, recordings, attachments or device logs.
print(sys.argv[2] + ' xcresult: ' + json.dumps({k: summary[k] for k in keys if k in summary}))
PY
        else
          echo "$suite xcresult summary unavailable; consult bounded test output above."
        fi
      fi
    done
    git diff --exit-code -- ios BlindCore BlindMemory
    ;;
  *) echo "Unknown mode: $mode" >&2; exit 2 ;;
esac
