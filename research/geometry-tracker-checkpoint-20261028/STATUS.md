# Current geometry-first navigation tracker

**Current status: 2026-10-29, 05:57 UTC.** Original priority unchanged: establish faithful room geometry and observed support, then independently check paths/full-body collision, then finish localization, live mapping and guidance in the actual app. New real-stair dataset tests are an additional workstream, not a replacement for that original task. **No project completion, live-navigation readiness or overall accuracy percentage is claimed.**

## Verified completed checkpoints

- Released-engine comparisons have actual results, but **no overall winner**. The comparable Voxblox result is mixed; full Open3D estimated-pose variants performed worse than the supplied-pose baseline on this recording. Source-only, incompatible and resource-blocked methods remain distinct from executed failures. See the [full audit](https://github.com/mischa23v/blind/blob/a077a52/research/full-audit-20261029/FULL_AUDIT.md); its dated figures remain specific to those runs.
- [D1 exact-zero ray candidate](https://github.com/mischa23v/blind/blob/a077a52/research/voxfield-zero-direction-candidate-20261029/RESULT.md): 28 strict and four observational synthetic traces matched; the original control's 17 mismatches remain retained. This is a narrow ray-traversal correction, not a room-quality or native-invalid-input safety result.
- [N2 normal candidate](https://github.com/mischa23v/blind/blob/a077a52/research/voxfield-numerical-normal-candidate-20261029/RESULT.md): 1,382 provider assertions and 18 coarse synthetic gates passed. More numerically available normals did **not** improve the paired close-plane coverage result. Small two/four-centimetre objects remain unresolved; coarse queries are not independent full-surface safety evidence.
- [Recorded three-frame prefix](https://github.com/mischa23v/blind/blob/a077a52/research/voxfield-recorded-prefix-20261029/RESULT.md): 36 pre-engine validators passed; B/C0/C1 each received the same 1,296,420 admitted points. All 20,783 unavailable normals retained their points. This establishes bounded ingestion/numerical-state behavior only: no mesh export, ground-truth scoring, accuracy ranking or full 265-frame result.
- Native Apple source-floor repair, strict endpoint and EDT diagnostics have bounded successes recorded in the full audit. The two corner-profile successes are the **same Hallway corner**, not two independent places. Complete support, localization and app-level acceptance are still open.

## Active priorities and completion gates

- [ ] **GEO-01/02 — Complete native geometry parity and representation acceptance.** Preserve source scale, boundaries, openings, identities and distinct obstacle/support geometry; do not infer full correctness from bounding boxes or selected fixture passes.
- [ ] **GEO-03 — Full D1+N2 B/C0/C1 comparison.** A full 265-frame experiment is planned, **not run at this cutoff**. Freeze the protocol/resources and appropriate controls first; preserve original masks/poses, unknowns and failure tails. Do not treat historical unpatched stock as a matched corrected control. Mesh quality and hazard misses require separate evaluation.
- [ ] **GEO-04 — Resolve practical geometry failures.** Continue floor/support, small/overhead geometry, occlusion and boundary tests. Keep unresolved data separate from fake obstacles; do not clear spaces merely to obtain paths.
- [ ] **NAV-01/02 — Paths and full-body acceptance.** Recheck fixed routes, exact requested/projected endpoints, connectors, foot/body/head collisions and complete-footprint support against independent evidence. Retain refusals, partial paths and contacts; arrival counts alone are insufficient.
- [ ] **NAV-03/04 — Actual app integration.** Room/building/floor association, orientation/localization, route entry/deviation, fresh geometry, hazard-first guidance, tracking loss/restart and return routes remain open. LLM conversation must not invent movement authority. Device runtime and accessibility failures still require their own passing evidence.
- [ ] **End-to-end acceptance.** The full 400 actual-stack journeys, complete accessibility acceptance and supervised physical validation remain unfinished. Simulator/synthetic checks do not close these requirements.

## New real-stair recordings — parallel workstream

- Two ScaleMaster staircase archives have been privately downloaded and hash-checked. This is acquisition/integrity evidence, **not** verified depth calibration, successful mapping or a stair detector result.
- The other 23 recordings are to be staged after the initial tests under the user's requested sequence; they are **not marked acquired or tested here**.
- Dataset licence remains unverified: **no raw public mirror**. Keep private source archives and any unapproved derived payloads out of GitHub.
- [ ] Inspect actual depth encoding/invalid values, camera and depth calibration, pose axes, RGB/depth/IMU synchronization, timing and tracking validity before adapting.
- [ ] Separate provided/optimized poses from independent ground truth. Establish what reference and hazard labels actually exist; no implied ground-truth coverage or readiness.
- [ ] Run bounded adapter and geometry tests, then separately reviewed stair/support tests. Missing inputs remain explicit; no invented gravity, timing or success-rate denominator.

Checkpoint source above was verified on published revision `a077a52`. This tracker update is source/aggregate prose only. It does not publish archives, private identities, raw recordings or pending benchmark geometry, and does not authorize an unbounded next run.

---

## Historical checkpoint — 2026-10-28 17:40 UTC (preserved verbatim)

The following is dated evidence, **not current completion status**. In particular its ongoing RTAB work and older native failure counts must not be read as today's latest results.

# Geometry-first navigation checkpoint

**2026-10-28, 17:40 UTC.** This index supersedes older tracker descriptions of the current blockers; it does not alter their historical receipts. The next engineering priority is independently verified room geometry, then unchanged path/body/collision acceptance, then the complete current-sensing/localization/guidance chain. No navigation, physical-use or whole-project completion is claimed.

Published evidence: [full 19-finding audit at caf1e02](https://github.com/mischa23v/blind/blob/caf1e0229d677b4fa62a501ce2bf344783dfc8cb/research/geometry-independent-audit-20261028/FULL_REPORT.md), [fresh Open3D addendum at 3f01d4a](https://github.com/mischa23v/blind/blob/3f01d4a285878c0cba5d307fd3ae2920de7a79b7/research/geometry-independent-audit-20261028/UPDATE_1732.md).

## Completed evidence, with bounded scope

- [x] Repair and verify actual Apple binary-property-list metadata decoding; retain all original feature identities.
- [x] Independently compare two exact retained Apple diagnostic USDZs using official OpenUSD. All 24 reference feature transforms and 133 source-anchor distances preserve the original Float32 source values; native numerical parity is verified only for the first rejected wall of each fixture. This is internal file consistency, not surveyed physical accuracy.
- [x] Identify our incorrect source-plane-versus-exported-solid/outline containment rule. The exported floor also expands beyond its original polygon; a wider epsilon or thickness-only patch is not a valid fix.
- [x] Reproduce the declared Open3D Koivu baseline on 265 training frames, with an unchanged 29-view exclusion set. Fresh mesh and initialization cloud match prior output bytes.
- [x] Complete all-29-view registered-reference scoring and independent numeric review. All 1,335,885 rays are accounted for; paired median residual is 3.40 cm, MAE 18.65 cm and P95 113.83 cm. Large disagreement tails and missing returns remain. This is a completed comparison, **not** a navigation/clearance pass or accuracy percentage.
- [x] Verify the narrow synthetic collision query separation repair, hosted classification fixtures and explicit test-target linkage repair. These do not close real-world geometry, support or movement requirements.

## First: geometry correction and comparable baselines

- [ ] **GEO-01 — Complete same-file native all-feature parity.** Compare every feature's actual world-space vertex and triangle geometry, identity, orientation and counts with the same exact reference export. Keep missing faces, filled openings, doubled transforms, scale/axis errors and duplicate/drop mutations visible. Bounding-box agreement is insufficient.
- [ ] **GEO-02 — Correct the Apple representation adapter and verify natively.** Keep raw exported solids separate from the original source-bounded historical support polygon. Code review also found all triangles carrying a floor UUID become support, including slab sides/underside; the existing rejection masks this next defect. Use a released tessellator with source-boundary/area/concavity tests; do not invent or expand floor support, trim obstacles to obtain a path, or apply guessed extrusion constants. [Published design and regression gates](https://github.com/mischa23v/blind/blob/3f01d4a285878c0cba5d307fd3ae2920de7a79b7/research/roomplan-support-contract-proposal-20261028/PROPOSAL.md). Design/source work is not a tested correction.
- [ ] **GEO-03 — Finish compatible reconstruction comparisons.** Open3D is measured above. RTAB-Map preparation/execution is ongoing with separately approved resource limits; no RTAB result is established at this checkpoint. InfiniTAM CPU feasibility is under review, not an executed reconstruction. Keep blocked/incompatible methods separate from poor geometry scores; use the same input hashes and frozen holdout when a method can consume them faithfully.
- [ ] **GEO-04 — Explain spatial errors before simplification.** Investigate registered residual tails, omitted/extra returns and the user's visible wall/furniture crossings against exact source/frame/body/path evidence. Neither shadows nor physical obstruction is established by these symptoms alone. Test preserved scale, boundary, topology, gaps and small/overhead geometry before claiming a simplified mesh is acceptable.

## Then: unchanged path and full-body acceptance

- [ ] **NAV-01 — Rerun the frozen Apple routes and supplied-pose stages after geometry gates pass.** Retain original route pairs, requested/projected endpoints, body profiles and margins. Report invalid starts, actual movement, stops, arrivals and contacts separately. Current native evidence still has 18 route outcomes and 16 journey stages blocked by source geometry; no successful route is claimed by those reports.
- [ ] **NAV-02 — Verify complete path connectors and independent full-body collision/support.** Register the displayed raw scene, routing geometry, actor envelope and actual samples. Check doorway and return connectors, foot/head/body contacts, floor boundaries and support under the complete footprint. A floor contact or centre-point support is not full support; an oracle using the same omitted geometry cannot validate that omission.
- [ ] **NAV-03 — Connect current room-relative localization and live geometry.** Establish room/floor association, position, body heading and phone-to-body calibration; handle new/moved obstacles, missing near-feet/head coverage, timestamp/pose mismatch, tracking loss, departure from route and restart. Historical map identity does not establish current pose or clearance.
- [ ] **NAV-04 — Verify the assembled app before a walking handoff.** Current sensor/geometry owners, map selection, route planning, hazard-first output and recovery must work together. LLM narration cannot supply movement authority. Measure real device latency, resource use and failure behavior separately from cloud/simulator results.

## Other acceptance still open

The 400 complete actual-stack journeys, accessibility acceptance, broader tracker backlog and supervised physical validation remain open. Current exact native c4ffa28 run has 236 hosted cases: 223 passed, seven failed and six skipped; UI has 18 cases: 14 passed, one contrast failure and three skipped. Earlier dated tracker entries preserve their own source-specific results, not current passes.

Keep private captures on device. Publish only authorized source and public/synthetic evidence at each reviewed checkpoint and verify the remote commit. The Open3D text packet does not contain the optional derived mesh/array package or raw inputs; its reproduction limits remain explicit. No new workflow activation, merge or deployment is requested by this tracker update.

