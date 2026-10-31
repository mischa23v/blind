# Native Apple result: run 40710093281

**Terminal failure**, exact source `9284719fe477135d4bcd85b2cbd2a587609ed428`, tree `57bd101dee4360477f80907494e9a60de94d3e36`. Completed 2026-10-28 15:20:55 UTC. Read-only observation: no rerun, dispatch, push or test-gate change by this observer.

[Run](https://github.com/mischa23v/blind/actions/runs/40710093281) · [Native job](https://github.com/mischa23v/blind/actions/runs/40710093281/job/122897894788)

## Verified results

| Stage | Actual result |
|---|---|
| BlindCore | 1,434 executed; 1 skipped; zero failures |
| BlindMemory | 58 passed |
| Default unsigned iOS Simulator build | Passed |
| Separate diagnostics-flag compile | Passed |
| Hosted units | 224 cases: **211 passed, 7 failed, 6 skipped** |
| Collision oracle tests | All 8 passed |
| Classified mesh tests | All 5 passed |
| UI | 18 cases: **14 passed, 1 failed, 3 skipped** |

Early and final case-status JSON are complete, exact-source verified, aggregate-count matched, and semantically identical. All six requested public/synthetic reports were collected. Named report files are semantic reserializations; report-manifest.json hashes refer to original attachment bytes, not those reserializations.

## Mixed-scene collision repair verified within synthetic scope

| Fixed geometry/query configuration | Controls |
|---|---|
| Wall only, combined query | 6 / 6 passed |
| Wall + floor, combined query | 4 / 6 passed |
| Wall only, separated queries | 6 / 6 passed |
| Wall + floor, separated queries | 6 / 6 passed |

The legacy combined wall-plus-floor cell still misses the wall in both sweep directions, returning the floor ID instead. The separated category queries return both wall and floor IDs while retaining endpoint floor contact. Geometry, renderer and speed remain fixed in this witness. The original thin-wall sweep test also passes both directions on this source. This demonstrates the narrow mixed-query failure and candidate repair on Apple Simulator; it does not establish full-footprint support or physical clearance. The separate 4-by-10 startup matrix remains unchanged from the prior source.

## Route/geometry blocker unchanged

The plist mapping repair remains effective: both fixtures have zero unmatched/unknown meshes. Both still reject source bounds as `sourceGeometryMismatch`. All 12 baseline + 6 width-addendum route outcomes and all 16 supplied-pose journey stages remain unsupported geometry. The seven remaining hosted failures are two route scenarios, one supplied-pose journey and four Apple mesh fixture cases. No completed candidate route or production guidance formatter/cadence replay is established.

## Timing evidence: native build dominates the slow queries

The unchanged 10-second callback checks pass on this run. Ten query IDs have callback, wait-finished and discard-completed stage receipts. Callback delivery ranges from 55 to 9,948 ms; queue wait is at most 356 ms, and queued-to-delivered handoff at most 1 ms. For the slowest query, worker starts at 167 ms, native build ends at 9,948 ms (9,781 ms inside build), route rejection and callback delivery occur at 9,948 ms. Another callback at 7,358 ms includes 7,350 ms native build. Native build, not main-queue handoff, dominates these observed slow queries.

All ten retained discard receipts show completion, 0–80 ms after discard request. Times are integer milliseconds relative to each query and include scheduling; this is one simulator run, not sustained latency proof. Collected stage lines identify queries by UUID but do not include scenario names; do not invent per-test assignment. A nativeFailure stage can be an expected conservative negative-control result, not a failing test. See classified-stage-receipts.txt and the derived classified-timing-summary.json.

## UI contrast target now identified

The camera/Ask audit fails Contrast in Ask at LaunchTests.swift:373. Original callback metadata identifies disabled button `local-answer`, label **Ask about the camera view**, frame `{{20, 624.33333333333326}, {400, 52}}`. Camera before/after evidence is complete; Ask after-shot is absent because the audit failed, so evidence extraction remains incomplete. The prior clipping issue is not reported on this run; absence of that callback is not a comprehensive contrast/accessibility pass. Exact bounded synthetic metadata and screenshots are in ui-audit/.

## Provenance and surrounding runs

- Unit artifact 12826173332, ZIP 16,300 bytes, SHA256 `ad54a4c3df7a64d69eaa9fa7a2db13a46909f6b39f969e65f83e834120c194a9`.
- Exact early JSON: 147,325 bytes, SHA256 `82f8efdbb4487145f752a41d6f28fb4a44475806fd6a64bae5ac039c0d74a867`.
- UI artifact 12826114961, ZIP 808,100 bytes, SHA256 `0290ee0e5282378e43625f3f2a235238981a940808a25884ba892644efefc1bf`.
- ed7fda1 source Native run 40708027633 was cancelled while pending, with no jobs; it was not executed. This 928 source includes its collision/UI changes plus DEBUG timing instrumentation.
- Separate proof runs 40710093419 and 40710093201 failed before build/test on a Bridge.swift APPLE_SOURCE_PINS.json assertion; their bounded receipts are in separate run directories. Those failures are not a Native compile failure and no repaired-pin result is claimed here.

This observation is complete. Source geometry validation, disabled-button contrast and near-deadline native build time remain actionable. Actual-device localization, sustained spoken guidance, full-footprint support and independent child use remain unproven.
