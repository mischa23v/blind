# Navigation and testing status

**Snapshot: 2026-10-29 00:38 UTC. Latest published source: `b398c26b2ac4862b5440a31649a108a09011938c`; native results below are bound to `ceaaa1c1fc685b043934c4be1ade75653227e1bf` on `codex/recovery-hazard-order-20261027`.** This updates current status without rewriting earlier dated evidence or closing the existing task definitions. It is a documentation update, not a new test run or navigation-readiness approval.

## What improved and what still fails

**The original Apple floor-import blockage is repaired and native-verified. Strict endpoint admission now also has native evidence. Neither resolves the remaining corner margin contacts or completes live navigation.** The Coffee second-scene test shows that useful connectivity is still limited; a few complete diagnostic corridors must not be presented as room-wide navigation.

| Area | Latest durable evidence | Current conclusion |
| --- | --- | --- |
| Historical Apple floor import | Run `40773062534`, source `49a9878`, passes the floor/source-geometry regression checks after the bounded Earcut bridge and witnessed duplicate normalization | Earlier `invalidMesh` blockage is no longer the current explanation for every route failure. Historical support is not live floor coverage. |
| Strict endpoint policy | macOS probe `40791907324` reproduces all 25 pairs: 11 legacy complete corridors become 8 retained corridors plus 3 specified projected-start refusals; retained paths/contact results match | Native non-vacuous admission improvement, not 8 safe journeys. Both corner margin contacts remain. |
| iOS strict fixtures | Run `40791907265`: all 3 `SavedRoomStrictEndpointTests` pass | Native verification of the declared fixtures. The strict policy remains opt-in; legacy behavior remains default. |
| Corner clearance | Frozen erosion trace reproduces native paths and establishes a retained cell and a raw-contour point inside the requested margin around an actual source-wall point | The local deficit already exists before contour simplification. Reducing simplification alone did not fix it. No radius/body shrink or oracle relaxation is justified. |
| EDT Phase A | Exact-distance diagnostic against recorded planar grid seeds removes relevant offending cells; navigation was not executed | Useful candidate diagnosis only. Source-surface clearance and a corrected route are not established. Phase B captures are approved but not yet executed at this snapshot. |
| Coffee original-pose TSDF | 350 training frames; 38 official test frames and 3 unposed frames excluded. Actual mesh: 136,847 vertices and 268,806 faces | Real second-scene source reconstruction, not an untouched holdout or live scan. |
| Coffee fixed route comparison | 20 reference-qualified queries: source yields 2 complete, 16 partial and 2 endpoint-association failures | The 2 completions are one approximately 2.372 m corridor in opposite directions, not two independent journeys. Reference control completes all 20. |
| Coffee reference samples | 244,306 sampled rays independently recounted: zero sampled raised-body contacts; 2 missing floor rays on partial source paths | Missing floor remains unknown. Discrete zero-contact counts do not establish continuous body clearance, full support or safe guidance. |
| Main hosted suite | Exact `ceaaa1c`, run `40791907265`: 251 cases = 241 passed, 8 failed, 2 skipped | Not green. Five conversation/model failures and three existing route/journey failures remain. Classification tests pass in this run. |
| Accessibility and timing | Current ceaaa UI is terminal: 18 cases = 14 passed, 1 failed, 3 skipped; Ask still fails Dynamic Type. Prior classifier timing evidence shows first native-build wall stall and serial queue effects | Fresh default/largest label captures do not clear the full audit. CPU attribution remains pending; a current classifier pass does not prove the earlier delay fixed. |

## Changes not yet adopted or verified

- Strict endpoint admission is an explicitly selected candidate. It is not wired as normal `NavigationModel` route-query behavior, and no physical-guidance authority was activated.
- The EDT diagnostic compares distances to recorded grid seeds, not a measured continuous-wall clearance field. It must be tested through the bounded subsequent stages without changing the frozen body/margin or declaring removed cells a successful route.
- The reviewed CPU/identity instrumentation packet was pushed and remote-verified as `b398c26`; actual native measurement remains pending. It is intended to distinguish CPU work, wall delay and queue effects; instrumentation is not itself a performance repair.
- The five aggregate conversation/model failures cover 14 fixture invocations with nil generated text. Logs report model availability followed by missing-asset errors; they do not demonstrate five hallucinated answers. Successful generation and behavioral acceptance remain unverified. These remain failed/not-evaluated acceptance, not accepted skips or navigation evidence.
- The normal pipeline still needs current map-relative location and body heading, calibrated phone/body association, live mesh ownership and updates, current full-footprint support and obstacle coverage, checked connectors, deviation/recovery and timely code-owned guidance. Supplied poses, archived maps and diagnostic paths do not establish these.

## Next tests in dependency order

The existing [geometry-first checklist](../geometry-tracker-checkpoint-20261028/STATUS.md) and [TASKS](../../TASKS.md) remain authoritative; no historical checkbox is changed by this status page.

1. **Geometry and clearance — GEO01–GEO04:** complete the approved bounded EDT capture/attribution stage; retain original source geometry, both native corner contacts and continuous collision checks. Demonstrate a corrected useful route, not only rejection or removal. Continue fixed Coffee source-span/filter attribution instead of tuning radius, slope or climb until the answer looks favorable.
2. **Native regressions — Q03 and GEO gates:** retain the current UI terminal evidence and all eight hosted failures. Collect actual CPU/identity instrumentation from the verified `b398c26` run. Keep old timing failures visible even when a later run happens to pass.
3. **Routes and journey chain — NAV01–NAV04 and N00:** test starts, goals, connectors, complete paths, actual body/margin contacts and support separately; include doorway exit/return and the user's reported visual wall/furniture contradictions. A projected start or partial path must not become an arrival.
4. **Connected device behavior — N00, Q04–Q06:** establish live localization, heading, calibration, freshness, updates, loss/restart recovery and accessible guidance before physical testing. The 400 complete journeys and final end-to-end reproducible review remain open. No child/independent-use readiness follows from this checkpoint.

## Evidence pointers and publication boundary

These are exact retained evidence locators, not a claim that every local result has been published:

- Native run pages: [strict probe](https://github.com/mischa23v/blind/actions/runs/40791907324), [hosted and UI](https://github.com/mischa23v/blind/actions/runs/40791907265), [floor repair](https://github.com/mischa23v/blind/actions/runs/40773062534).
- `research/native-floor-import-repair-20261028/NATIVE_FLOOR_REPAIR_RESULT.json`.
- `research/native-floor-import-repair-20261028/native-strict-result-40791907324/RESULT.json` and `IOS_HOSTED_RESULT_40791907265.json`.
- `research/native-floor-import-repair-20261028/erosion-trace/RESULTS.md` and `edt-diagnostic/RESULT.json`.
- Local `merge-readiness-audit/run40791907265/HOSTED_RESULT.json`, bound to the source checkpoint above.
- Local `research/coffee-original-pose-tsdf-comparator-20261028/qualified-results-v1/README.md` and `reference-route-evaluator-v1/PATH_EVIDENCE_SCORE.json`.

The new 114-file benchmark payload and diagnostic chart still have separate publication approvals pending. This update does not contain or authorize those payloads. It contains only aggregate status and pointers—no raw coordinates, private photographs, personal information or bulk numeric records. Earlier coordination notes include stale pending fields; actual source-bound receipts above take precedence for these results.
