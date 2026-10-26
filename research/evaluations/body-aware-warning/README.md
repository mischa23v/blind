# Body-aware nearby warning — 2026-10-26

## Implemented

Saved full-body height/width/depth, equipment bounds and chest offsets now affect a supplemental nearby depth warning in the actual frame callback. No dimensions are guessed from age, weight or gender. Existing urgent detector results bypass the new work and remain unchanged.

The orientation-independent cylinder covers every yaw and the horizontal camera/body offset; camera heading is not body facing or travel direction. Existing depth projection uses the full AR matrix, including pitch/roll. The vertical reference is either retained level-floor calibration or explicitly reported camera-above-floor metadata—not fresh support. Missing dimension uncertainty/equipment remains explicit. The warning never gives range, bearing, a directional beacon/haptic, positive clearance or motion permission.

The private profile loads at startup and publishes only current successful transactions; save/delete withdraw old runtime geometry first. Mount/lifecycle changes retire supplemental state, and stale write callbacks cannot restore deleted data. The existing Body and chest holder view now exposes the **same** session-only mount binding as Route tools. It remains false after restart; it is not calibration certification. Protected, backup-excluded local storage is preserved.

## Executed checks

- **51 focused tests passed:** 11 body-warning Core, 15 prior profile, 16 exact unchanged detector, and 9 actual native-store tests. The blocked-write/delete observer regression checks that superseded callbacks never republish an old profile.
- **6 source-contract tests passed:** actual frame ordering, startup/current store token, lifecycle/mount retirement, no supplemental direction cue, full matrix/privacy and the shared UI binding. These inspect source, not Apple callbacks.
- **All 131 production Core Swift sources typechecked** together, with the existing SwiftPM-generated resource accessor supplied for compiler context. The preexisting `CompanionReportedStep` immutable-Codable warning remains.
- All six modified iOS Swift sources syntax-parsed. This is **not** an Apple SDK build, SwiftUI/VoiceOver execution or whole-repository test aggregate. The helper view remains English-only as in the baseline; Arabic helper UI is not verified.

A preserved failing-before arbitration regression showed a generic body warning could mask an equally urgent independent obstacle alert, losing its directional output. The old source fails one assertion; the corrected tie-break and both ordering/severity cases pass. Every prior non-body tie is preserved.

An authored synthetic counterexample executes the actual old detector: its 1.3m camera bands miss a 2.3m-high patch; an entered 2.5m body now adds a generic possible-obstacle warning. An actual legacy drop still wins. This is code behavior, not physical accuracy. Tests also cover short/tall/wide bodies, backpack/head extensions, offset signs, recorded uncertainty, unknowns, full-matrix rotations, freshness, duplicate depth points and mount loss.

## Limits and next evidence

This stage is **not navigation completion**. Calibrated body pose, current support/terrain, complete live collision coverage, mapped localization and supervised device acceptance remain open. No camera-to-body measured calibration provider is invented. Existing detector thresholds and known replay failures are retained.

The isotropic 0.7m nearby allowance plus 0.15m padding can warn beside walls that are not in the intended path; they are prototype warning settings, not measured error/stopping-distance guarantees. Evaluate warning fractions and continuous episodes, false alarms, misses and latency before calling it useful guidance. Recorded replay uses actual depth with explicitly hypothetical wearer profiles, not measured wearer truth; no ideal floor may be injected. No replay threshold tuning is included here.

Already-posted independent VoiceOver hazard announcements cannot be unsaid. State retirement prevents new stale supplemental issuance/repetition, but does not claim to retract system accessibility speech. Independent hazards are not cleared.

## Reproduce

From the checkout, run `bash research/evaluations/body-aware-warning/verification/run-tests.sh` with a supported Swift toolchain (bounded subset, jobs=2), then `node --test research/evaluations/body-aware-warning/verification/integration-contracts.mjs`. The nine native-store tests execute the real store's portable branch; iOS complete protection requires device verification.

The original focused logs and exact compiled inputs are retained in the review packet; `verification.json` records results and source hashes. Private recorded images, profile data, models and build outputs are not part of this source increment.
