# Full report — Koivu mapping audit, second pass (2026-10-26)

Scope: independent response to the Windows-session audit (its text was supplied in chat; its files at `/C:/blind/research/mapping-audit-20261026` were not available to me, so its numbers are quoted as reported, not verified here). New experiments in this pass: a statistical low-band test and an orientation-aware route check, both on the public Koivu recording. **Still 0 of 100 movement episodes. FARO was downloaded by neither planner and used by no planner. Nothing here is device or safety evidence.**

## 1. Verdict

Both audits reach the same verdict independently: the mapping implementation has real defects (extremum floor rule, inherited into v2; permanent hits in v1; double body bound) and is over-conservative. Its failure is not evidence against the iPhone depth sensor.

Where this pass goes further: the remaining obstacle to movement is now quantified. It is **not** fusion, floor fit, units or body bounding. It is roughly **1,000 columns of ambiguous low-height evidence** (2–8 cm above the floor, mostly 1–4 cm) scattered through the aisles, plus about 1,200 columns whose low band was never adequately observed. Whether those are real objects or depth noise can only be decided by the evaluator reference, which neither session has run. Until then, no map that blocks all unresolved evidence yields a 2–6 m route in this room, and no honest fix exists that bypasses that question.

## 2. Point-by-point on the other session's findings

| # | Their finding | My position | Evidence |
|---|---|---|---|
| 1 | Geometry correct; repeated 4×4 depth blocks; "frame/scan counts are not multiplied by 16" | **Agree, and I correct my earlier wording.** v1 increments `views` once per frame per voxel and OctoMap updates each key once per scan, so frame counts were not inflated. What *is* inflated: v1 `hits` (×≈16) and the min/max extremes, since the 16 copies travel along slightly different rays (≤1.5 px, ≈0.5 cm at 3 m) | `a1.py` run-length check; `map_builder.accumulate` |
| 2 | Extremum floor/support rule is a major defect; v2 keeps it | **Agree.** This is the primary cause. v2's Recast build fails even at a 0.27 m disc | `a8.py`, `routes.py` |
| 3 | 1 cm object classified as ground; D1's ±2.5 cm layer has the same blind spot; 2.5 cm is a representation limit, not a hardware limit | **Agree on all three.** The statistical test below lowers, but does not remove, the floor | `lowband_stat.py` |
| 4 | Ray reduction loses 0.8–2.1 % free cells per frame; not dominant | **Agree.** Full 294-frame comparison: 5,738 vs 5,826 walkable columns | `discretize.py` |
| 5 | Double bound; single bound + 0.15 = 0.4204; rectangle at headings gives 1,213 centres permissive, 13 strict, 1 if far-only dips also blocked | **Agree, and thank you for running the rectangle test on D1.** Extended below to actual routes | `routes_rect.py` |
| 6 | Open3D TSDF ran: 3,139 supported, 565 clearance, **0 full-body fits**; 2,254 of 2,570 contacts within 3 cm of the foot plane | **Partly disagree with the reading.** A body container that starts 2 mm above a *fixed plane* and is intersected against an *estimated* mesh whose floor ripples ±2–3 cm will collide with the floor itself. That is the v1 extremum error re-expressed as a collision test. "0 fits on TSDF" therefore says little about the TSDF map and should not be cited as a second failure. The right test uses the local mesh floor as the foot plane and separates low-object contacts from floor-ripple contacts. The remark "disregarding low bands alone did not create fits" needs its exact exclusion and radius stated; at the 0.5324 radius nothing fits in any map | — (their data) |
| 7 | My D1 routes reproduce; depend on allowing flagged cells; too short for the 2–6 m requirement | **Agree.** Confirmed and sharpened below | `routes_rect.py` |
| 8 | Movement unmeasured; rejected placements are not invalid-start episodes | **Agree.** | — |

One further correction to my own first report: the MuSHRoom repo at HEAD `3f36dbf` uses Open3D TSDF in `kinect_tools/` and in `ns-export tsdf` (depth rendered from a trained model), not on raw iPhone depth. The other session's "authors' iPhone TSDF baseline" should be checked for file and line before being called a reproduction target.

## 3. New experiment A — statistical low-band test (all ranges)

**Why.** D1 treats the 2.5–7.5 cm band as unresolved unless seen from ≤2 m, because single-voxel occupancy from 3 m is dominated by noise. But a 10 cm object produces a *systematic* height shift in every sample that hits it, while noise is zero-mean. With many samples, far-range evidence can resolve the band statistically. This is the sensor-model idea in ANYbotics `elevation_mapping` (BSD-3): per-cell height with range-dependent variance.

**Method (diagnostic thresholds, not frozen).**
- LiDAR-native samples; per-frame vertical bias removed (median floor offset per frame, ±1 cm, bursts 3.5 cm). *This is a declared pose refinement, not point deletion.*
- σ(range) from robust MAD over floor columns the near tier already resolved: **0.3 cm (<1 m), 0.7–0.9 cm (1–3.5 m), 1.1 cm (3.5–4.5 m), 3.0 cm (>4.5 m)**. Much smaller than the p95 residuals in the first report because bias is removed and MAD ignores the heavy tails.
- Per 5 cm column: weighted mean height m, standard error SE, and tail fraction above 2.5 cm + 2σ.
- `clear` if n ≥ 30, ≥ 3 frames, m + 3·SE < 2.5 cm, tail < 7 %. `object` if m − 3·SE > 1 cm or tail > 15 %. Otherwise `unresolved`.

**Results.**

| Column set | clear | object | unresolved |
|---|---:|---:|---:|
| D1 near-resolved walk (calibration) | 3,165 | **198** | 294 |
| D1 flagged (far-only) walk | **5,289** | 510 | 1,213 |
| D1 low-band positively occupied | 132 | 316 | 156 |

- 5,289 of 7,012 flagged columns are resolved clear by far-range statistics.
- 1,024 columns are called `object`: median height 1.8 cm, p90 4.4 cm; 168 blobs (90 single-column, 17 larger than 10 columns). 198 of them are columns the near tier called *clear* — a direct conflict whose truth is unknown.
- 1,213 remain unresolved (540 for lack of samples).

**Retention check.** The same four noise-free boxes (4 and 8 cm, near and far-only zones) were rendered into the real rays and the statistic re-run: **all four centre columns flip from `clear` to `object`**, means +3.6 / +7.5 / +4.0 / +8.3 cm, 6–9 of 9 neighbourhood columns flagged. So the test retains such objects at 3 m range using far evidence alone. It still cannot see below ≈2.5 cm, and noise-free boxes are not real-object detection evidence.

## 4. New experiment B — orientation-aware routes with the full margin

**Why.** The 0.45 × 0.30 person walking along an aisle needs 0.45 + 2 × 0.15 = 0.75 m, but a disc needs 0.84 m. D1's aisles pinch at ≈0.78–0.82 m. A disc planner cannot pass; the actual rectangle can.

**Method.** Recast/Detour corridor with disc = lateral half-width + margin = 0.375 m (nothing shrunk). Then an evaluator-side **swept-rectangle check** of the actual Detour path: inflated rectangle (0.375 lateral, 0.30 fore-aft half-extents, all margin kept), sampled every 2.5 cm along segments and at 5° during turns at corners. Start/goal must fit the rectangle at some heading. 60 seeded endpoints, all pairs, routes kept only if complete, associated within 10 cm and 2–6 m long.

| Map | disc-fit centres | complete routes | 2–6 m | **pass rectangle** | fail (turn / segment) |
|---|---:|---:|---:|---:|---|
| D1 permissive (flags allowed) | 642 | 615 | 103 | **28** (2.3–3.0 m, median 2.58) | 22 / 53 |
| D1 strict (near-only low band) | — | *no walkable polygons* | | | |
| Statistical: clear only | 405 | 552 | **0** | 0 | |
| Statistical: object-blocked only | 519 | 465 | **0** | 0 | |

Reading:
- With the full 0.15 m margin and the unchanged person, **28 routes of 2.3–3.0 m exist in this room if, and only if, the flagged/ambiguous low-band columns are allowed.** Most segment failures are Detour's string-pulled paths hugging corners; a wider corridor disc would centre them (not run: the parameter did not take effect, see `routes_rect2.py` note).
- Blocking the `object` columns fragments every aisle; no 2–6 m route survives. Those ≈1,000 columns are the gate.

## 5. What is actually unknown, and how to close it

The gate is a single empirical question: **are the 1,024 `object` columns, the 104 isolated specks and the 198 near/far conflicts real low objects or depth-noise tails?** Two facts argue for noise in part: median height 1.8 cm; 90 blobs are single columns. Two argue for caution: 17 blobs exceed 10 columns; the test caught every injected box. Only the evaluator can decide.

The correct procedure (neither session has done it):
1. **Score, don't tune, on Koivu.** Run the existing FARO evaluator over the frozen D1 columns and the statistical labels. Report by class: real-contact rate of `object`, `clear`, `unresolved`, and the 104 specks. The planner never sees FARO. Koivu becomes the *development* room.
2. **Pre-register on a holdout.** Fix σ-model, thresholds, margin and the flag policy in writing, then test on a second MuSHRoom room (same CC BY 4.0 release; choose it by a stated criterion such as largest floor area, not by looking at results). Only holdout numbers count as results.
3. **Then** freeze that map and 20 route pairs and run the 20 × 5 game.

A capture fact to record: 66 % of D1's walkable columns were never viewed within 2 m in the low band. The scanner held the phone at ≈1.4 m and pointed at surfaces, not at the floor ahead. That is a property of this Polycam recording, not of the sensor, and the app's chest mount tilted down changes it.

## 6. What I would do differently from the other session

- **Run the evaluator now** on the frozen diagnostic maps instead of concluding "no tested fix exists". The FARO archive is extracted; the scoring code exists in `koivu-offline-game-v1`.
- **Do not test estimated meshes with a fixed-plane container.** Use the local mesh floor and separate floor-ripple contacts from object contacts; otherwise TSDF (or any fusion) fails by construction.
- **Resolve the low band statistically, not by proximity alone.** Proximity (D1) throws away two-thirds of the evidence; the statistic uses it and still retains injected objects.
- **Plan with the rectangle, not a disc.** Disc planners cannot pass a 0.8 m aisle with this person and margin; the rectangle can. Keep the margin.
- **Use a holdout room.** Both sessions have now looked at Koivu results many times; any threshold chosen next is contaminated unless tested elsewhere.
- **Measure the recording's floor coverage** before judging the mapper or the hardware.

Where I would do the same: keep every failed map; keep the margin until an error budget exists; keep unresolved cells visible as a separate class; never let a flag become clearance silently; report movement outcomes separately; no FARO in the planner.

## 6b. Addendum — reference scoring and holdout (run after this report)

The FARO evaluator was then run on Koivu and, with identical code and pre-fixed thresholds, on a holdout room (coffee_room). Results in [`REFERENCE_SCORING.md`](REFERENCE_SCORING.md): the ~1,000 `object` calls are 96 % not real geometry and the specks 100 % not, in both rooms; walkable calls touch real low geometry in 0.2–0.9 % of columns, all at obstacle edges; the rooms admit 387 / 537 rectangle routes of 2–6 m at the full margin from reference geometry, but only with ≤5 cm obstacle inflation, and the phone maps inflate by 5–10 cm plus scattered false blocks. Movement episodes still 0 / 100.

## 7. Status

| Item | Status |
|---|---|
| v1 reproduced from released data | yes, identical counts |
| OctoMap 1.10 baseline, full rays, 294 frames | run |
| Floor error model (range, incidence, per-frame) | measured |
| D1 policy map, body-fit table, Detour routes | run (diagnostic) |
| Statistical low-band test + injected-box retention | run (diagnostic) |
| Swept-rectangle route validation at full margin | run (diagnostic) |
| Open3D TSDF comparator | not run here (other session reports a run; its collision test disputed above) |
| FARO evaluator scoring of any corrected map | **not run by either session** |
| Holdout room | not selected |
| Movement episodes | **0 / 100**; arrivals, collisions, stops, invalid starts unmeasured |
| Device evidence | none |

Scripts for this pass: `scripts/lowband_stat.py`, `scripts/inject_points.py`, `scripts/routes_rect.py`. Numbers: `RESULTS.json` → `secondPass`.
