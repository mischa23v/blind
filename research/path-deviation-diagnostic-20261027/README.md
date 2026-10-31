# Offline route-deviation diagnostic

This is a supplied-pose arithmetic evaluator, **not localization, navigation, collision checking or guidance**. No application, frozen movement trial, map or upstream source is changed. It never chooses another segment, alters a pose, snaps a person onto a path, or outputs movement authority. Body heading is always unavailable.

## What it computes

For an explicitly supplied directed horizontal route segment, consistent supplied frame/revision/floor/session/clock identifiers and a fresh supplied pose:

- Signed horizontal cross-track metres, positive LEFT in X/Z with Y up.
- Along-polyline horizontal metres and unclamped selected-segment fraction.
- Distance to that same segment.
- Camera-heading error in [-pi,pi), positive left. A zero/near-vertical camera vector has unavailable heading rather than a fabricated turn.

Overlap, crossings, adjacent turn endpoints or another nearby segment within the explicitly supplied association radius return ambiguity with segment IDs. Beyond-segment, stale/future, mismatched-frame, invalid-geometry and unsupported nonplanar paths return explicit reasons. Ambiguity is not an obstacle/blockage finding. The caller's radius and age limit are diagnostic policy inputs, not measured uncertainty or safety limits. Actual caller frame/provenance truth is not certified by matching strings.

## Reuse and provenance

Actual checked-in [Recast/Detour](https://github.com/recastnavigation/recastnavigation/tree/9f4ce64458dfae86e1239c525ddc219c4e9e06f1) sources are compiled unchanged. Local `detour_metrics.cpp` is only a C ABI adapter over `dtDistancePtSegSqr2D`, `dtVdot2D`, `dtVperp2D`, `dtVsub` and `dtVdot`. Original upstream Zlib notices are retained in `tools/navigation-recast/upstream/License.txt` and source headers. The existing `tools/navigation-recast/UPSTREAM_MANIFEST.json` pins43 original files; the runner verifies every file before compilation and hashes its complete selected source/header closure before testing.

This reuses the established library, not a new planner/SLAM implementation. `SpatialRouteOwner.validateLeg` supplies the existing app's explicit-leg/no-guessed-join policy reference; this evaluator is separate and does not change or claim to test that runtime. The ongoing matrix uses a different actuator yaw convention; callers must supply an actual XYZ camera-forward vector rather than passing its scalar yaw unchanged.

Detour uses float geometry. Coordinates and forward-vector components are limited to +/-1000, with the minimum horizontal segment checked both before and after float conversion. Returned digits do not establish physical precision. Route Y must be planar; pose Y is intentionally not a floor/support measurement and is ignored in the horizontal diagnostic. No covariance/error bounds, floor support, live evidence coverage, obstacle avoidance, body calibration, arrival or false-acceptance rate is established.

## Verification and usage

Run `python3 research/path-deviation-diagnostic-20261027/run_checks.py` from a checkout with installed Python3 and g++. No download/install occurs. A serial small C++ shared-library build and Python synthetic tests execute in a temporary directory under declared CPU/address-space/file/wall limits. The library is discarded afterward; no executable is published. Each invocation preserves a new immutable-attempt source freeze, compile/fixture logs and result rather than overwriting failures.

First execution:56 synthetic unittest cases passed, zero failures/skips. Actual upstream adapter compile0.666 seconds wall; fixture process0.119 seconds wall. All input source hashes unchanged. See `FROZEN_01.json`, `ATTEMPT_01.json` and logs. These test analytic fixtures only; no actual recorded or device poses were executed. A test count is not an accuracy claim.

Next useful evaluation, separate from this increment: freeze independently estimated pose outputs, associated map/route segments and evaluator-only truth, then compare cross-track/along-path/camera-angle errors and unavailable/ambiguous coverage over time. Keep estimator inputs blind to reference truth. Do not retune the ongoing100-episode matrix or treat its supplied poses as independently measured localization.

Independent review then found diagnostic reporting, quantization and runner bookkeeping gaps. They were corrected without widening the domain into guidance. The revised source passed62 synthetic fixtures, zero failures/skips (compile0.444s; fixture process0.162s). `FROZEN_02.json` and `ATTEMPT_02.json` identify the current source. ATTEMPT01 is historical, not a current-source pass. See `REVIEW.md` for all findings and limits. Cleanup-on-timeout source was reviewed but no timeout actually occurred in these successful runs.
