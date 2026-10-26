# Observed scene and recorded-return integration receipt

This checkpoint connects actual native depth observations to a bounded same-session surface-hit history, the existing current-observation `LocalPlanner`, and the existing `JourneyRecorder`/`ReturnTrail` target sequence. It does not replace observed camera position with a route target.

## Implemented source

- `BlindCore/Sources/BlindCore/ObservedScene.swift`: resource-bounded observed hits, revision/capture ownership, current-support planning, retained destination and recorded-return intent, continuity-reset behavior.
- `ReturnTrail.swift`: read-only current candidate target, preserving existing breadcrumb ordering.
- `ios/BlindAssist/ObservedSceneRuntime.swift`: one bounded off-main worker, completion freshness, goal/body/session fences and recovery after rejected timestamps.
- Native model/dashboard integration: actual frame feed after urgent hazard processing, lifecycle/deletion/watchdog retirement, local profile preview envelope and explicitly nonphysical helper progress.

Missing/withdrawn/invalid profile yields geometry without a candidate plan; no smaller generic envelope is substituted. Profile preview retains unknown dimensions/calibration. Historical invisible surfaces never fill missing current support. Nothing here issues physical localization authority or sends candidate directions to speech/beacons.

## Reproduce

From a complete merged checkout with Python 3, installed Swift 5.9+ and Node:

```sh
python3 research/evaluations/observed-scene/run-focused.py
```

The runner copies the actual required production Swift files and both actual test files into a small temporary Swift package, uses two jobs and local caches, then executes three Node source-contract files. It downloads nothing. The only shim is an unused `MapError` enum needed by the larger `NavigationSurface` source. `--work-dir PATH` retains a reusable build directory; `--overlay PATH --skip-source-contracts` permits an explicit pre-merge Swift source overlay. Tests print exact source hashes. This focused check does not replace the full package tests or an Apple build.

## Recorded verification

At this scoped checkpoint: **16 portable Swift tests passed**, including actual Foundation native runtime ownership/recovery; **9 observed-scene source contracts** and **32 existing spatial/contextual contracts** passed. Swift frontend native syntax parsing passed. These source checks do not execute ARKit, audio, rendered UI or native RTAB. See `receipt.json` for exact frozen source hashes and exclusions.

Preserved failures and corrections:

1. Initial default Clang module-cache access failed; workspace-local caches resolved the tool invocation without permission expansion.
2. Initial geometry fixture was **8/9**: the wall ended inside the sampled support grid, so the existing planner found an edge detour. Extending the fixture wall beyond the grid fixed the test; planner thresholds were not weakened.
3. Integration review found a false-green source-order comparison: a missing token returned `-1`, which compared earlier than the offer. The contract now requires both tokens to exist, covers both legacy and body-combined urgent assignment paths, and has negative mutations for removed detector calls, premature offers, missing urgent assignment and missing combination. Other source-order assertions likewise require token presence; their negative mutations remove all occurrences so a later unrelated guard cannot mask the intended missing-token failure.

A separate sequential recorded-data driver is being verified; full real-recorded journey results are **not** included in these counts. Provided dataset odometry is input, not independent localization truth. Mesh/annotations/future trajectory cannot be estimator inputs.

## Deliberate remaining boundary

This is growing hit history plus current-observation route/return candidates—not an RTAB free/support-grid map or measured localization release. The native downward-looking `DepthSampler` heading gate remains; a portable zero-heading test does not prove native ingestion. Whole-app Apple semantic build, empirical full-body calibration/error validation, physical journey performance and child trials are not established. The next concrete reuse bridge is described in `rtab-next.md`.

## Combined body and scene integration

The shared native frame callback now runs the existing detector, preserves its urgent result, applies the separately published body warning only otherwise, then submits the same observation to the bounded scene worker. Profile updates and mount changes fence queued plans before another frame. A new `recordedBoundsPreview()` uses only current reported/measured full dimensions: a newly loaded empty profile or estimates alone cannot silently supply generic body geometry. Oversized bounds never shrink to defaults. The original generic helper preview remains unchanged.

Merged verification passed 47 source contracts, 16 actual Core/Foundation scene tests, and 55 focused body/store tests including four new profile regressions. These overlapping focused suites are not a whole-repository aggregate. Project regeneration was byte-identical and modified native sources syntax-parsed; a full Apple SDK build of this merged stage remains pending. Body-only source `9fd57e9` separately passed its default Apple SDK build.

The first merged source-contract run was 44 passed / 2 failed. The original synchronous scan-cancellation prefix was restored before body-state retirement rather than weakening that contract. Obsolete detector-assignment literals were updated to the actual legacy/supplement branches with missing/reordered-token mutations. Negative ordering checks now reject missing tokens instead of accepting index -1. No hazard or calibration threshold was changed to satisfy the tests.

The final-source causal replay executed four variants of all 596 real timestamped depth frames (59.492 seconds). It built up to the configured 4,096 surface-hit cells, but floor calibration completed on zero frames and no candidate paths were produced. With the unchanged valid hypothetical profiles, plan outcomes were 250 needs-calibration, 52 needs-position and 294 without an owned return target. Return invalidated; the separate restart variant fenced the old return. The fixed hypothetical small profile warned on 521/596 frames across eight episodes; the wide profile on 562/596 across six. These are conditional warning-burden failures, not wearer accuracy or useful navigation. None is a completed journey.

Recorded odometry is supplied input, not our localization estimate. Source Z-up to app Y-up is a documented source-axis inference, not measured IMU calibration. Neither full mesh, future trajectory nor expected destinations construct the running scene. Exact calibration-gate diagnosis and the public reproducible driver are separate follow-on evidence; thresholds and fixed profile inputs were not tuned to pass.

All 132 production Core sources also passed a final combined typecheck; the preexisting immutable-Codable warning remains. This does not replace native SDK/device testing.

Replay-cut correction identified before publication: the recorded adapter used a 0.3 horizontal-forward gate, while native DepthSampler uses 0.25. One frame lies between those values, and steep-view availability also needs native nil-observation semantics rather than a zero-heading substitution. The numerical negative results above are retained evidence for that specific portable adapter cut, not exact native capture equivalence. A corrected, separately pinned replay is pending; production thresholds are unchanged.

A further replay-transport audit found that the reused history importer samples at stride 8, whereas native DepthSampler uses stride 2, confidence 2 and the native depth-range/cadence gates. Sparse returns can directly affect minimum calibration counts. The zero-calibration and warning-burden results are therefore a **sparse history-adapter failure**, not an established native calibration or navigation failure. The corrected replay must match sampling density, native frame cadence, nil-observation retirement and actual runtime delivery before attributing failures to production thresholds or the recording. All original results remain retained; no passing result is substituted.
