# Navigation-first reconciliation — 2026-10-27 19:54 UTC

This is a dated, incomplete checkpoint, not the final result of the 100-episode matrix or the project. The implementation baseline is review-branch commit [`0babd78`](https://github.com/mischa23v/blind/commit/0babd78d14eafe8b818e3b15be1ebe84aaf04caf), on [draft PR #2](https://github.com/mischa23v/blind/pull/2). No merge, deployment, live guidance activation or human-trial readiness is claimed.

## Verified component progress

- Fresh decoder81 passed **51 synthetic host checks**, protected-construction compilation checks and Simulator compilation in [run40542574937](https://github.com/mischa23v/blind/actions/runs/40542574937). These are new checks, not the earlier lost 49 authored fixtures.
- ARKit owned snapshot adapter82 passed **36 host synthetic checks** plus actual ARKit API compilation in [run40543469837](https://github.com/mischa23v/blind/actions/runs/40543469837). It is no longer untested; live callbacks, capture and copy latency remain unvalidated.
- Mesh ingress83 originally passed **55 actual-runtime host checks** and API compilation in [run40545204872](https://github.com/mischa23v/blind/actions/runs/40545204872). A later acknowledged terminal-discard increment passed **111 package checks** in [run40560344601](https://github.com/mischa23v/blind/actions/runs/40560344601) and **83 ingress checks** in [run40560344668](https://github.com/mischa23v/blind/actions/runs/40560344668). These revised totals supersede, rather than add to, their earlier totals. [Verified owned-discard evidence](../apple-owned-discard-results-20261027/README.md) was published at [`dc56e65`](https://github.com/mischa23v/blind/commit/dc56e6515319db694fdf8277a8340c6f8decedde). This is bounded owner/lifecycle evidence, not whole-app memory zeroization or live sensing acceptance.
- Stage85 supplies the real local SwiftPM dependency graph. Its default-off app wiring remains an **unapplied proposal**. Host/Simulator graph and 83 host fixtures passed; [run40571313055](https://github.com/mischa23v/blind/actions/runs/40571313055) failed the flag-absent app build and its one narrowly permitted retry at an Xcode build-service crash during build-description creation. Flag-enabled app compilation was not reached. Do not treat the standalone graph as a successful app build or enable live copying.

## Foreground IO and full-app acceptance

The production SpatialMapIO change in commit 0babd78 changes only the shared queue priority from utility to userInitiated. Original deadlines, assertions, serialized ownership and safety gates are unchanged. In the preceding [buffered two-arm diagnostic40564108627](https://github.com/mischa23v/blind/actions/runs/40564108627), the utility arm failed and the userInitiated arm passed the original fixture. This is one comparison on different fresh CI hosts, not proof of exclusive causality or measured phone performance.

[Current-source BodyProfileStore run40571313226](https://github.com/mischa23v/blind/actions/runs/40571313226) passed **55 unique XCTest cases**: nine BodyProfileStore, 11 collision-warning, 19 body-profile and 16 detector checks, with zero failures/skips. Independent artifact verification matched all 27 compiled-input hashes, including the current SpatialMapIO SHA-256 `f044ff2aa869cf0ea3ab8a2ff8d4c6ba7fc7fcd9915fe1fed59109219a3c548c`. [Preserved evidence](../apple-body-profile-current-20261027/README.md) records the exact scope. [Full native run40571313138](https://github.com/mischa23v/blind/actions/runs/40571313138) is under review. No full-app green result is claimed. Historical IO failures remain preserved.

The Dynamic Type failure remains open. App-effective category tracing in [run40564108538](https://github.com/mischa23v/blind/actions/runs/40564108538) showed all three observed roles traversing the requested categories and returning to Large; both audits still failed. A pinned-Large environment was not supported by that run. No speculative font fix or audit suppression is accepted.

## Frozen movement matrix: partial, not 100 completed trials

The local ledger snapshot in [MATRIX_SNAPSHOT.json](MATRIX_SNAPSHOT.json) contains **14 actual simulated arrivals, one interrupted/unknown episode, one marked running and 84 not run**. The marked-running producer's liveness is under investigation; the ledger label is not a heartbeat guarantee. Episode 8 remains unknown and is not counted as a pass, a zero-distance trial or a known navigation failure. Arrival indices are listed explicitly; these are conditions across route pairs, not 14 rooms or 14 distinct routes.

The original 20 ordered pairs and five conditions remain frozen. The source-only route reconstruction accepted all 20 proposals; source proposals are not executed arrivals. The first-five historical report and evaluator code were published at [`64cafe6`](https://github.com/mischa23v/blind/commit/64cafe6a411e5e32ebfb7d526d5f98a19f8a5b28). This snapshot does not claim the later traces or the separate source84 archive are published.

The actor uses recorded real-room geometry, supplied poses, reference/manual-floor support, a reference-world veto, a manual unknown tabletop region and **zero body margin**. Floor contacts are exempt/unmeasured. Reference vetoes are evaluator assistance, not phone obstacle detection. Temporal jitter and synthetic tracking interruption do not establish metric visual localization or real ARKit relocalization. These results cannot pass live-hazard, device or human-safety acceptance.

## Ordered remaining work

1. Establish the active matrix producer state, preserve partial/unknown outcomes and complete the frozen matrix without tuning physics, routes or acceptance thresholds after results. Recount traces and publish bounded evidence with the original failures.
2. Preserve the verified exact-source BodyProfileStore results and complete full native result review. Diagnose stage85's build-service failure using saved evidence before another execution. Keep its app patch unapplied until actual flag-absent and flag-enabled app builds pass.
3. Resolve Dynamic Type using actual measured app behavior, not weaker audits or guessed layout changes. Review temporary CI triggers before any separately authorized merge.
4. Establish fresh live floor-to-head hazard coverage and warning lead time, body/camera calibration, metric localization/heading/deviation, checked route-entry connectors, live changes and loss/restart/return. Saved geometry is never current clearance.
5. Complete the broader 400 actual-stack journeys, supervised device/VoiceOver/resource checks and staged participant/O&M acceptance. Component test totals are not a completion percentage. Secondary image retention and visual-verification backlog remains recorded, not substituted for navigation work.

Earlier tracker entries retain their original checkpoint scope and failures. This update supersedes stale current-status wording, not scientific results or safety requirements.
