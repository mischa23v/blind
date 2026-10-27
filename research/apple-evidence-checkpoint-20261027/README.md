# Recovered verified GitHub artifact evidence

Recovered read-only from `mischa23v/blind` on 2026-10-27. These are preserved historical evidence bytes, not new test executions or repository source checkouts. No installations or new tests were performed during recovery. This checkpoint publishes the original ZIPs under `archives/`; extract each ZIP to inspect its original members. `artifact-provenance.json` records sizes, SHA-256, member CRC32, and run IDs. All three archives exactly match the expected SHA-256 and every ZIP member passed CRC verification.

## Apple package

- [Run 40470002271](https://github.com/mischa23v/blind/actions/runs/40470002271), artifact **12718625037**, 15,759 bytes, 11 JSON members.
- SHA-256: `3368440457e801f36fe3480cf1fca5b9ccf90ceeb00dfd002a057ebd077b1318`.
- `SUMMARY.json` reports source commit `e9e18d15fe1fdac1ff1487b3c2a8a2e731607427`, Apple Swift 6.4, native SwiftPM backend, macOS package build and public imported-client execution.
- 87 host checks = 55 `RESULT.json` checks + 32 `RUNTIME_RESULT.json` checks; all true. These are host checks, not iOS-device or simulator runtime checks.
- Simulator package/client compilation and linking only: `iOSSimulatorExecuted=false`. `appProjectBuilt=false`, `ARKitExecuted=false`, `physicalAuthority=false`, `publicExclusionUpdatesImplemented=false`.
- `defaultSwiftBuildBackendPassed=false`; do not report an unqualified default-backend pass. `RESULT.json` retains a Linux/static-fixture scope string; the Apple host provenance is established by `SUMMARY.json` and the host receipts, not by relabeling that original field.

## Focused indoor IO

[Run 40470002343](https://github.com/mischa23v/blind/actions/runs/40470002343).

| Artifact | Label / expected source SHA | ZIP bytes | First single test | Later tests |
|---|---|---:|---|---|
| 12718900690 | baseline / `106cc2ad9565513af578d9325110213216e8cc39` | 16,709 | failed, exit 65 | single-2, single-3, six-test class passed |
| 12719397419 | review / `8d878c86ab0b3a96d5fd44b31b418fbdc9bc5ed6` | 17,569 | wrapper timed out, exit -9 | single-2, single-3, six-test class passed |

- Baseline SHA-256: `41401d450e4aa935afc09798c93a2fc56fdc63564069076ca451e7cf68e2306f`.
- Review SHA-256: `1b564069e8caac002ec155841e59a855c490dc43ca93b5bf4aba20bd8f69d117`.
- Both original `single-1.txt` files contain an actual XCTest **10-second asynchronous fixture wait failure**, at `CommunityTests.swift:1172`, expectation `actual asynchronous indoor map IO without blocking its main owner`, in `testTrackingLossStillInvalidatesRetainedMapFrame`. The review result must not be described as merely an outer runner timeout: its log also records the actual fixture failure (baseline line 68, review line 65; repeated later in both logs).
- Both builds passed. Later passing repetitions do not erase the first failure or prove a fix, latency bounds, or physical navigation safety.
- **Both summaries report `source_clean_after=false` and `integrity_error="Candidate checkout changed during diagnostic"`. Changed paths are unknown from these retained artifacts.** Do not assert the changes were benign/generated or that clean-source test attribution was established.

## Verification limits

Only these three small artifacts were recovered here. Their byte integrity and ZIP CRCs were freshly checked; artifact statements are historical producer evidence, not independently rerun tests. This recovery does not reconstruct the prior workspace, large XCResult bundles, or missing changed-path diagnostics and does not authorize physical guidance.
