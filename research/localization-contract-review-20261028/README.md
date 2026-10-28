# Native localization capture/evidence contract — 2026-10-28

## Result and limits

Added **10 direct XCTest methods** against the shipped `NativeLocalizationEvidenceGate`, rather than a parallel model of its logic. Production code and physical-guidance authority are unchanged. These are synthetic contract fixtures, not measured localization, collision, calibration or navigation accuracy.

**Swift is absent in this workspace. The XCTest suite is authored but has NOT run here.** Existing Core CI must compile/run it after publication. The bounded Python check passed nine source/fixture integrity assertions; that result must never be reported as ten passing Swift tests.

The actual map-relative localization producer remains **open**: the app issuer retains candidates at `missingCalibration`. There is no shipped independently validated provider for camera/body calibration, current floor/support coverage or total metric/angular error. No guessed bounds, BodyHeading confidence, recovered origin anchor or LLM result was substituted for those missing measurements.

## Coverage added

`BlindCore/Tests/BlindCoreTests/NativeLocalizationEvidenceGateTests.swift` covers:

1. A structurally valid **test-only** validator yields an exact owner/session/map/capture/support-bound pair, earliest evidence expiry, single-use completion, and `physicalReleaseNotApproved`.
2. Missing calibration, support and error records each reach their own named rejection, then consume the attempted completion.
3. Expired, future-dated and malformed-digest records reject before validator success can authorize anything.
4. Wrong calibration revision, mismatched support/error observation time, unknown floor and inadequate/nonfinite positional error reject distinctly as invalid evidence.
5. Structurally valid records still reject as unvalidated or out of domain according to the validator.
6. Retaining a capture UUID while changing its camera matrix cannot substitute a pose; rejection leaves the genuine pending candidate available.
7. A late completion for A cannot consume newer B in the same owner epoch.
8. Changing the mount revision rejects and consumes old pending work.
9. Diagnostic withdrawal preserves the same owner's replay timestamp high-water.
10. Completion time cannot refresh an expired original capture timestamp.

Each completion rejection test first successfully calls the real `begin` and checks its owner and state. Assertions check the exact rejection enum, not merely that some earlier prerequisite failed. Test numbers are fabricated fixture inputs and not deployable calibration recommendations.

## Seams inspected and why this matters

- `NativeLocalizationIssuer`: keeps the gate behind bench preparation, never calls capture acceptance. Original ARFrame time is retained and watchdog freshness/ownership invalidation exists.
- `NativeLocalizationEvidenceGate`: references are structural inputs to a future validator, not independent accuracy proof. Successful fixture preparation is explicitly bench-only.
- `PlaceStore` world-map recovery: exact saved artifacts/origin association is not measured physical alignment accuracy.
- `SpatialRouteOwner`: route legs require current pose/support binding and collision checks; a relocalization label is not enough to unlock them.
- `BodyHeading`: walking/mount heuristics and confidence do not establish metric/angular errors.

No visibility was relaxed. No app owner, tracker, map, evidence record, stored calibration, privacy policy, runtime validator or release switch was changed. No dependency/download/native workflow was added or run. No denial was encountered; the only execution blocker is the absent Swift toolchain under the no-install scope.

## Reproduce

From repository root:

```sh
python3 research/localization-contract-review-20261028/check_source_contract.py
# In the existing authorized Swift/Core CI environment, not run locally here:
cd BlindCore
swift test --filter NativeLocalizationEvidenceGateTests
```

`SOURCE_RECEIPT.json` pins inspected sources and records exactly which limited checks ran. It intentionally distinguishes source checks from Swift execution and physical evidence.

## Still required, not closed by this patch

A real retained/calibrated capture producer and independently checked validator; camera/body convention and mount-slip measurements; full-footprint live support coverage; measured pose/heading error across declared conditions; stale/restart/relocalization device trials; path-deviation and turn latency measurements; supervised adult trials before any child use. A test validator returning `independentlyValidated` is only a branch-exercise mechanism in the test target and is never evidence for these items.
