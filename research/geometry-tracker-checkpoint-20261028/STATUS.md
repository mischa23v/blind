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
