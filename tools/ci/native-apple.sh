#!/usr/bin/env bash
# Execute the committed default project. Never regenerate it or enable feature flags.
set -euo pipefail
mode="${1:?Expected preflight, core, memory, build, diagnostics-build, unit, ui, or summary}"
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
  if [[ "$label" = core ]]; then
    # Fixed public synthetic class and case/status grammar only; no assertion payload.
    # Evidence only: preserve original command, exit status, aggregates and failures.
    echo 'MODEL_RESPONSE_AUTHORITY_CASES_BEGIN (at most 64 lines; 700 characters each)'
    grep -E "^Test Case '(-\\[(BlindCoreTests\\.)?ModelResponseAuthorityTests test[A-Za-z0-9_]+\\]|(BlindCoreTests\\.)?ModelResponseAuthorityTests\\.test[A-Za-z0-9_]+)' (started\\.|(passed|failed|skipped) \\([0-9]+(\\.[0-9]+)? seconds\\)\\.)$" "$out/$label.log" | head -64 | cut -c 1-700 || true
    echo 'MODEL_RESPONSE_AUTHORITY_CASES_END'
  fi

  if [[ "$label" = unit ]]; then
    # Fixed test labels, allowlisted public availability and numeric runtime only.
    echo 'MODEL_AVAILABILITY_BEGIN (first 80 lines; 600 characters each)'
    grep -E '^MODEL_AVAILABILITY fixture=' "$out/$label.log" | head -80 | cut -c 1-600 || true
    echo 'MODEL_AVAILABILITY_END'
    # Synthetic test-only receipt: closed stage/event names and numeric monotonic
    # timing. No geometry, source/session identity, arbitrary errors or model text.
    # Keep this on both pass/fail paths; it never changes the test exit status.
    echo 'CLASSIFIED_QUERY_STAGE_TIMING_BEGIN (at most 40 lines; 1500 characters each)'
    local stage='(requestEnqueued|workerStarted|nativeBuildBegin|nativeBuildEnd|routeBegin|routeEnd|nativeFailure|completionQueued|completionDelivered|discardRequested|discardWorkerStarted|discardReleased|discardCompletionDelivered|workerFinished|requestRetired)'
    grep -E "^CLASSIFIED_QUERY_STAGE_RECEIPT id=[0-9A-F-]{36} event=(callback|waitFinished|failureDiscardCompleted|discardCompleted) stages=($stage:[0-9]+;)*$stage:[0-9]+$" "$out/$label.log" | head -40 | cut -c 1-1500 || true
    echo 'CLASSIFIED_QUERY_STAGE_TIMING_END'
    # Exact synthetic ingress fields only; no source IDs, geometry or free text.
    echo 'CLASSIFICATION_INGRESS_TIMING_BEGIN (at most 80 lines; 1800 characters each)'
    grep -E "^CLASSIFICATION_INGRESS_TIMING query=[0-9A-F-]{36} runtime=[0-9A-F-]{36} event=(submitted|waitFinished) elapsed_ms=[0-9]+ main_thread=(true|false) stages=(($stage:[0-9]+;)*$stage:[0-9]+)?$" "$out/$label.log" | head -80 | cut -c 1-1800 || true
    echo 'CLASSIFICATION_INGRESS_TIMING_END'
    # Closed synthetic worker CPU summary, optional unavailable values are -1.
    echo 'CLASSIFICATION_WORKER_CPU_BEGIN (at most 64 lines; 2000 characters each)'
    local cpuNumber='(-1|[0-9]+)'
    grep -E "^CLASSIFICATION_WORKER_CPU id=[0-9A-F-]{36} worker_begin_ms=$cpuNumber lane=(ingress83|runtime75) worker_wall_ms=$cpuNumber worker_cpu_us=$cpuNumber worker_pair_valid=(true|false) build_wall_ms=$cpuNumber build_cpu_us=$cpuNumber build_pair_valid=(true|false) route_wall_ms=$cpuNumber route_cpu_us=$cpuNumber route_pair_valid=(true|false) retired=(true|false) native_failed=(true|false) records=([0-9]|[1-5][0-9]|6[0-4])$" "$out/$label.log" | head -64 | cut -c 1-2000 || true
    echo 'CLASSIFICATION_WORKER_CPU_END'
  fi
  if [[ "$label" = ui ]]; then
    python3 tools/ci/extract-ask-layout-trace.py "$out/$label.log" || true
  fi
  if [[ "$label" = unit ]]; then
    grep -E '^CLASSIFICATION_DIAGNOSTIC_LOCK lane=(ingress83|runtime75) records=([0-9]|[1-5][0-9]|6[0-4]) max_wait_us=[0-9]{1,15}$' "$out/$label.log" | head -64 | cut -c 1-200 || true
  fi
  # Inputs are committed public source and synthetic tests only; no secrets are supplied.
  # Avoid an environment dump or full build settings. Keep failure diagnostics bounded.
  if (( status != 0 )); then
    # Print real diagnostics before warnings; zero-failure summaries must not consume the cap.
    grep -E -i 'ACCESSIBILITY_AUDIT|error:|fatal|Test (Case|Suite).* failed (at|\()|Executed [0-9]+ tests?, with [1-9][0-9]* failures?|\*\* (BUILD|TEST) FAILED' "$out/$label.log" | head -120 || true
    if [[ "$label" = unit ]]; then
      # Swift Testing issues otherwise disappear before the final tail. Fixture
      # comments contain only synthetic IDs and app-owned status, not model text.
      echo 'SWIFT_TESTING_ISSUES_BEGIN (first 80 matching lines, at most 1200 characters each)'
      grep -E 'Test .* recorded an issue|MODEL_FIXTURE .* status=' "$out/$label.log" | head -80 | cut -c 1-1200 || true
      echo 'SWIFT_TESTING_ISSUES_END'
      # Keep bounded windows belonging to FAILING tests, not the last successful tests.
      # Only synthetic test start/end and metadata-only phase records are admitted.
      python3 tools/ci/extract-native-unit-failures.py "$out/$label.log" || true
      echo 'OBSERVED_SCENE_TIMING_BEGIN (at most 8 metadata lines; 1500 characters each)'
      grep -E '^OBSERVED_SCENE_FENCE_(PHASE|LATENCY) ' "$out/$label.log" | head -8 | cut -c 1-1500 || true
      echo 'OBSERVED_SCENE_TIMING_END'
      echo 'RECORDED_ROUTE_TIMING_BEGIN (at most 8 metadata lines; 1500 characters each)'
      grep -E '^RECORDED_ROUTE_WAIT_FAILURE ' "$out/$label.log" | head -8 | cut -c 1-1500 || true
      echo 'RECORDED_ROUTE_TIMING_END'
    fi
    # The finite practice session can expire while XCTest waits for UI idleness.
    # Preserve its synthetic action chronology without changing the app or assertions.
    if [[ "$label" = ui ]]; then
      echo 'PRACTICE_TRACE_BEGIN (last 240 lines of this synthetic UI test only)'
      awk '/Test Case .*testPracticeIsAnnouncedAndCanStop.*started/ { practice = 1 }
           practice { print }
           /Test Case .*testPracticeIsAnnouncedAndCanStop.*(passed|failed)/ { practice = 0 }' "$out/$label.log" | tail -240
      echo 'PRACTICE_TRACE_END'
    fi
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
    # Explicit OS provenance only; never dump environment or machine identity.
    host_version="$(sw_vers -productVersion 2>/dev/null || true)"
    host_build="$(sw_vers -buildVersion 2>/dev/null || true)"
    [[ "$host_version" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]] || host_version=unknown
    [[ "$host_build" =~ ^[0-9]+[A-Z][0-9]+[a-z]?$ ]] || host_build=unknown
    echo "MODEL_HOST_PROVENANCE macOS=$host_version build=$host_build"
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
  diagnostics-build)
    # Compile only in an isolated CI job. No launch, test, install or runtime opt-in.
    run_logged diagnostics-build xcodebuild "${base[@]}" \
      -destination 'generic/platform=iOS Simulator' \
      'SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) DEBUG BLIND_MESH_CANDIDATE_DIAGNOSTICS' build
    ;;
  diagnostics-unit)
    # Exact synthetic projection/ownership class only; no camera/model/live session activation.
    device="$(cat "$out/simulator-id")"
    status=0
    run_logged diagnostics-unit xcodebuild "${base[@]}" \
      -destination "platform=iOS Simulator,id=$device" -destination-timeout 120 \
      -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 \
      '-only-testing:BlindAssistTests/SeatedMeshProjectionTests' \
      'SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) DEBUG BLIND_MESH_CANDIDATE_DIAGNOSTICS' \
      -resultBundlePath "$out/diagnostics-unit.xcresult" test || status=$?
    printf '{"exit_code":%s}\n' "$status" > "$out/diagnostics-unit-exit.json"
    exit "$status"
    ;;
  seed-radius-unit)
    # Fixed three strict controls plus five disk and six envelope optional-policy tests.
    # Default configuration; no caller activation, camera or model work.
    device="$(cat "$out/simulator-id")"
    status=0
    run_logged seed-radius-unit xcodebuild "${base[@]}" \
      -destination "platform=iOS Simulator,id=$device" -destination-timeout 120 \
      -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 \
      '-only-testing:BlindAssistTests/SavedRoomStrictEndpointTests' \
      '-only-testing:BlindAssistTests/SeedRadiusVetoAppleTests' \
      '-only-testing:BlindAssistTests/SeedRadiusEnvelopeAppleTests' \
      -resultBundlePath "$out/seed-radius-unit.xcresult" test || status=$?
    printf '{"exit_code":%s}\n' "$status" > "$out/seed-radius-unit-exit.json"
    exit "$status"
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
        if python3 tools/ci/export-native-unit-statuses.py --summary "$out/$suite.xcresult" "$out/$suite-summary.json"; then
          :
        else
          echo "$suite xcresult summary unavailable; consult bounded test output above."
        fi
      fi
    done
    # Preserve positive as well as failing case statuses; never alter test verdicts.
    python3 tools/ci/export-native-unit-statuses.py "$out/unit.xcresult" "$out/unit.log" "$out/unit-case-statuses.json" || true
    git diff --exit-code -- ios BlindCore BlindMemory
    ;;
  *) echo "Unknown mode: $mode" >&2; exit 2 ;;
esac
