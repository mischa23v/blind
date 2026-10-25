#!/usr/bin/env bash
# Fixed-count diagnostic, not retry-until-green. No test assertions/bounds changed.
set -euo pipefail
test "$(uname -s)" = Darwin
test -d "${DEVELOPER_DIR:?Apple toolchain must be selected}"
out="${RUNNER_TEMP:?Disposable runner required}/blind-runtime-stress"
mkdir -p "$out"
device="$(cat "$RUNNER_TEMP/blind-native-ci/simulator-id")"
base=(-project ios/BlindAssist.xcodeproj -scheme BlindAssist -configuration Debug -jobs 2
      -derivedDataPath "$out/DerivedData" CODE_SIGNING_ALLOWED=NO
      -destination "platform=iOS Simulator,id=$device" -destination-timeout 120
      -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1
      -only-testing:BlindAssistTests/ConnectedJourneyRuntimeTests)
source_sha="$(git rev-parse HEAD)"
echo "NATIVE_RUNTIME_STRESS source=$source_sha fixed_attempts=5"
echo 'Synthetic hosted runtime class only. CI load is uncontrolled; five passes do not establish a repaired root cause or device timing.'
printf 'attempt\texit_status\n' > "$out/results.tsv"

build_status=0
xcodebuild "${base[@]}" build-for-testing > "$out/build.log" 2>&1 || build_status=$?
echo "NATIVE_RUNTIME_STRESS build_exit=$build_status"
if (( build_status != 0 )); then
  grep -E 'error:|fatal|\*\* BUILD' "$out/build.log" | head -80 || true
  echo 'NATIVE_RUNTIME_STRESS completed=0 not_run=5 reason=build-failed'
  exit "$build_status"
fi

failures=0
diagnostic_errors=0
for attempt in 1 2 3 4 5; do
  log="$out/attempt-$attempt.log"
  result="$out/attempt-$attempt.xcresult"
  status=0
  xcodebuild "${base[@]}" -resultBundlePath "$result" test-without-building > "$log" 2>&1 || status=$?
  printf '%s\t%s\n' "$attempt" "$status" >> "$out/results.tsv"
  echo "NATIVE_RUNTIME_STRESS attempt=$attempt exit=$status"
  # Failure windows are emitted per attempt, so later passes cannot erase them.
  if ! python3 tools/ci/extract-native-unit-failures.py "$log"; then diagnostic_errors=$((diagnostic_errors + 1)); fi
  grep -E 'error:|Test (Case|Suite).* failed|Executed [0-9]+ tests|\*\* TEST' "$log" | head -100 || true
  if (( status != 0 )); then failures=$((failures + 1)); fi
  if [[ -d "$result" ]] && xcrun xcresulttool get test-results summary --path "$result" > "$out/attempt-$attempt-summary.json" 2>/dev/null; then
    if ! python3 - "$out/attempt-$attempt-summary.json" "$attempt" "$status" <<'PY'
import json, sys
summary = json.load(open(sys.argv[1]))
keys = ('result', 'totalTestCount', 'passedTests', 'failedTests', 'skippedTests', 'expectedFailures', 'startTime', 'finishTime')
print('NATIVE_RUNTIME_STRESS_RESULT attempt=' + sys.argv[2] + ' ' + json.dumps({k: summary[k] for k in keys if k in summary}))
counts = [summary.get(k) for k in ('totalTestCount', 'passedTests', 'failedTests', 'skippedTests')]
assert all(type(value) is int and value >= 0 for value in counts), 'Missing or invalid test counts'
total, passed, failed, skipped = counts
assert total > 0 and skipped == 0 and total == passed + failed, 'Runtime class must execute without skips'
if sys.argv[3] == '0':
    assert summary.get('result') == 'Passed' and failed == 0 and passed == total, 'Exit zero conflicts with test results'
PY
    then
      diagnostic_errors=$((diagnostic_errors + 1))
      echo "NATIVE_RUNTIME_STRESS_RESULT attempt=$attempt summary=invalid"
    fi
  else
    diagnostic_errors=$((diagnostic_errors + 1))
    echo "NATIVE_RUNTIME_STRESS_RESULT attempt=$attempt summary=unavailable"
  fi
done
echo "NATIVE_RUNTIME_STRESS completed=5 failed_attempts=$failures diagnostic_errors=$diagnostic_errors"
cat "$out/results.tsv"
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo '## Fixed-count runtime-class diagnostic'
    echo "Source: $source_sha; attempts completed: 5; failed attempts: $failures."
    echo 'No timeout/assertion changes. This is neither a device-latency benchmark nor proof of root-cause repair.'
    echo '```'
    cat "$out/results.tsv"
    echo '```'
  } >> "$GITHUB_STEP_SUMMARY"
fi
if (( failures != 0 || diagnostic_errors != 0 )); then exit 1; fi
