# Paper-derived stair reference candidate

**Source draft only, not compiled/tested. Not app-integrated. Not official SensoryScape code.**

This partial Swift reference exposes published angular predicates and explicit experimental interpretations of underspecified details in Herdt et al.(2026), DOI https://doi.org/10.1038/s41598-026-73419-5 . Read `SPECIFICATION.md` first: P clauses are published; E choices are ours; unresolved U clauses remain unresolved. Independent specification review preceded source drafting. Source review is pending.

No mesh reconstruction, raycast generator, camera/ARKit session, speech/haptics, movement commands, clearance result, network call or recorded private imagery. Caller supplies typed same-frame ray intercepts, frame identity, monotonic time, gravity, camera forward and explicit pose acceptance. Floor Detector is supplied; its unspecified ray angle is never invented. Descending endpoint directions are required configuration. Ascending timing/confidence are not guessed. Per-ray median diagnostics are not fused into an invented floor estimate.

Synthetic tuples test only rule arithmetic and declared state-machine choices. Some steep ramp tuples match the paper's staircase angular rule; tests preserve that counterexample. No empirical perception score, runtime budget or92.5% reproduction follows from these fixtures. Published outcomes were separately audited111/120, but raw inputs were not released.

## Review / native handoff

1. Independently read source against frozen specification; inspect unknown/missing-input/cooldown behavior and numeric boundaries.
2. Root approves source cut and installed native toolchain execution separately. Then run `swift test --jobs 1` from this directory with no installs, containers, model weights or app target.
3. Retain stdout, exact Swift version, source hashes and pass/failure/skip counts. Until then every XCTest is **prepared, never run**. No native CI workflow installed/triggered by this package.
4. A real replay adapter requires the source/size/licence/calibration contract in `REAL_DATA_NEXT.md`. Do not interpret arbitrary-FPS180-frame cooldown as3seconds. Measure real warning timing and misses only with independently annotated recordings; no live walking/child trials here.

## Known restrictions versus source

All-pair negative-dot/span requirements are more restrictive than fully specified paper text and may increase misses. Unknown inputs reset persistence. Per-ray floor samples use fixed session anti-gravity and world origin; no confidence formula. Ascending is raw evidence, not a timed alert. Descending markers use180frame-index cooldown under nominal60Hz; cadence has explicit unknown/nominal-with-experimental-tolerance/different diagnostics, not time normalization. Derived nonfinite floor statistics are rejected explicitly. Unsupported original special cases are absent. No safety guarantee or production readiness.
