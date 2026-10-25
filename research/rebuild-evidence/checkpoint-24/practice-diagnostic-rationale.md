# Practice label failure — diagnostic candidate only

Base: `3d6330e064f7e754a5b454f79732f12f532ccb7a`, repository `mischa23v/blind`.
Run: https://github.com/mischa23v/blind/actions/runs/40191454924
Native job: `121163136313`.

## Established

- Exact run fails `LaunchTests.testPracticeIsAnnouncedAndCanStop`, line 101, waiting for `SIMULATION · generated readings`. The test took **192.675 seconds**. Its earlier launch-camera-off and return-to-Assistant assertions passed because `continueAfterFailure = false`.
- Exact remote `NavigationModel.swift:4361–4380` sets simulation true, starts the watchdog and schedules automatic `endPractice()` at **120 seconds**. Ending practice clears simulation and does not enable a disabled camera preference.
- Shared baseline `DashboardView.swift:284–286` renders the expected literal as standalone Text when simulation is true; no combined accessibility label or special identifier hides it. Start from settings calls `startSimulation()` and switches to the Assistant tab. This is separate from the Practice section heading Dynamic Type failure/candidate.
- The shared baseline watchdog runs every 0.1 seconds and writes published simulation/calibration/detection state. This creates a plausible XCTest idleness issue, but the available trace does not prove it caused the failure.
- `reveal` uses two eight-iteration `for ... where !element.isHittable` loops. These continue querying even after the element is visible. This is unnecessary query overhead but not proven to cause this failure.
- The Actions artifact API returned an empty list for this run. The CI wrapper prints only error summaries and the last 60 log lines, which belong to a later test, so practice start/action chronology is unavailable.

## Conclusion

**Root cause remains unconfirmed.** Timer expiry during slow UI automation is the leading timing hypothesis, not a proven app defect or proven brittle label query. A 192.675-second total includes setup and pre-practice navigation; it alone does not establish the practice elapsed duration. Background lifecycle cancellation or another state transition cannot be excluded. No production behavior, label assertion, timer, timeout or accessibility audit should be changed on this evidence.

## Prepared change

`diagnostic-only.patch` changes only `tools/ci/native-apple.sh`: on a failing UI run, preserve the last 240 lines of this one synthetic practice test's existing action log. No new UI calls or instrumentation alter timing; all app code, assertions and safety behavior remain unchanged. Exact remote base and candidate copies accompany the patch. No files in the shared baseline were edited; nothing was pushed.

Checks passed: `bash -n` and a small actual-awk fixture confirming the selected practice block is retained and neighboring test output excluded. No Apple build/UI tests were run. Linux executor has no `xcodebuild`.

## Next action / blocker

Review and, under the parent's existing publication authority, publish this diagnostic together with independently justified repairs; run the existing native workflow and inspect the practice action timeline. If delay exceeds the production timer, diagnose the recurring publication/idleness or navigation-query cost without extending the timer. If practice ends early, inspect lifecycle cause before changing behavior. If simulation remains true and the text query alone fails, inspect the accessibility hierarchy.

Blocked action: execute exact native UI test here. Target: iOS 27.0 / iPhone 18 Pro Max simulator. Reason/status: this is Linux with no Apple SDK/xcodebuild; no connected Apple executor supplied. Required route is authorized existing Apple CI or a connected Mac. This is an environment limitation, not an approval denial; no bypass attempted.
