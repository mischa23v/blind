# Pose experiments: cause separated, one safe partial correction, two rejected methods (2026-10-26)

Follows `README.md` in this folder. Phone data only for every estimate; the FARO reference is used only to score safety at the end. **Movement episodes: still 0 / 100.** No device evidence.

## 1. Cause: pose drift in runs of frames (now separated) — `scripts/range_vs_time.py`

The other session's published review (`493f836`, `research/mapping-audit-20261026/README.md`) left the cause open: pose drift, depth/calibration bias, or real surface variation. The research report (`../research/WIDTH_SCALE_METHODS.md`) suggested a discriminator: depth bias grows with range, while pose drift clusters in time.

| Room | Frames with floor fit | Floor offset explained by the frame's floor range (R²) | Explained by its ±3 neighbouring frames (R²) | corr(offset, camera height) |
|---|---:|---:|---:|---:|
| Koivu | 251 | **0.007** (slope −0.27 cm/m) | **0.740** | −0.07 |
| coffee_room | 190 | 0.077 (+0.69 cm/m) | 0.460 | +0.19 |

The literature agrees: Apple depth bias is always toward the camera, 1–2 % of range (Zea & Hanebeck, JAIF 2022), so it cannot produce both +5 cm and −3 cm runs. Together with the non-floor ICP evidence in `README.md`, the cause on Koivu is **pose drift in runs of frames**. Depth bias is at most a minor contributor. Real floor shape is not supported for the inspected passage.

## 2. Joint pose-graph refinement — **rejected twice** — `scripts/posegraph.py`, `scripts/posegraph_v1_rejected.py`, `scripts/validate_poses.py`

Open3D 0.20.0 multiway registration recipe, run on 294 frames. Registration used only points 0.20–2.2 m above the floor, so the floor was held out as an independent check. The graph had 293 point-to-plane ICP odometry edges (7 fell back to the recorded relative pose) and 522 loop edges, optimised with Levenberg–Marquardt.

Acceptance was fixed in advance: the floor offset spread improves, ≤ 2 % of previously consistent frames become inconsistent, and ≥ 80 % of loop edges are kept.

| Version | Change | Outcome |
|---|---|---|
| v1 | as above | pose change median 27 cm, p90 1.1 m, max rotation 21° — trajectory wandered (wall ICP slides along flat surfaces). **Rejected** before validation |
| v2 | + recorded relative pose as a prior on every consecutive pair (σ 1°, 5 cm) | after removing the harmless global rigid shift: median 11 cm / 2.3° per frame. Floor |offset| median **0.89 → 2.91 cm**; inconsistent frames 77 → 232; **157 of 174 good frames became inconsistent**. Drifted frames overshot (61: +5.4 → −4.9 cm; 118: −3.5 → +6.0 cm). **Rejected** |

Joint ICP-based pose optimisation is not reliable on this processed recording. Both receipts and the v2 poses are kept (`poses/koivu_posegraph_v2_REJECTED_*`).

## 3. Floor-constrained per-frame correction, validated on held-out walls/furniture — `scripts/floorfix.py`

Rules were fixed before running:
- A frame is flagged when its own floor plane has |offset| > 2.5 cm or tilt > 1.2°.
- The candidate correction is a 3-DOF rigid motion (roll, pitch about the floor centroid, vertical shift). There is no yaw or horizontal change, because a floor cannot observe those.
- The correction is accepted only if the frame's **non-floor** points (0.20–2.2 m) then sit closer to non-floor points of unflagged frames ≥ 25 frames away: ≥ 10 % and ≥ 2 mm improvement in median nearest-neighbour distance.
- Unflagged frames are never changed.

| Room | Flagged | Corrected (passed held-out check) | Kept as recorded, flagged pose-inconsistent | No floor fit |
|---|---:|---:|---:|---:|
| Koivu | 77 | **9** (incl. 61, 62, 63, 119) | 68 | 43 |
| coffee_room | 76 | 1 | 75 | 198 |

Frame 62's walls moved 49 → 30 mm from the rest of the map, and frame 63's 52 → 39 mm. Corrected frames still sit 27–39 mm off on walls, compared with 10–15 mm typical. That residual is horizontal error the floor cannot reveal.

## 4. Maps rebuilt from corrected poses, safety-first — `poses/`, `runs/`

All maps use the unchanged pipeline (`pipeline2.py`, 5 cm) and the candidate split rule (floor support at OctoMap 0.5, obstacles at 0.7, `occthres.py`). Open-floor miss = a walkable column with real low or overhang geometry more than 0.15 m from any blocked column (see `../VARIANT_TESTS.md`).

| Map | Open-floor misses (must not rise) | Edge misses | Real floor still blocked | Camera centres in blocked cells | 2–6 m rectangle routes, full margin |
|---|---:|---:|---:|---:|---:|
| Koivu, recorded poses (before) | 4 | 359 | 1,287 / 10,805 | 39 / 294 (20 low-obstacle, 13 no support) | 97 |
| **Koivu, floor-corrected poses, all frames** | **4** | 363 | **1,030** / 10,828 | **17 / 294 (1 low-obstacle, 11 no support)** | 93 |
| Koivu, corrected, 68 inconsistent frames excluded (gate-as-delete) | **13** | 454 | — | — | 28 |
| coffee_room, recorded poses | 0 | 157 | 1,218 / 7,821 | — | 21 |
| coffee_room, floor-corrected poses | 0 | 154 | 1,220 / 7,823 | — | 22 |

Real-floor columns blocked are for the split-0.7 map; at the plain D1 (0.5) rule Koivu goes 1,791 → 1,538.

Reading:
- **The floor-constrained correction is safe on both rooms and removes the false low obstacles on the walked path** (camera positions blocked by low obstacles: 20 → 1). It does not lengthen the 2–6 m routes, which remain limited by the obstacle halo (horizontal) and by missing support.
- **Excluding inconsistent frames is unsafe**: real overhangs at 110–138 cm disappear, and open-floor misses rise 4 → 13. Their evidence must stay, as unresolved where it conflicts, never deleted.
- coffee_room barely changes: only 1 frame passes the held-out check, and half its frames see too little floor to fit.

## 5. What is still blocked, and what would fix it

- **11 camera-path cells with no floor support.** They need the local-support layer: support observed per patch with uncertainty, no extrapolation. Pose correction cannot help.
- **The 5–10 cm horizontal obstacle halo.** It is partly residual horizontal pose error (the 27–39 mm wall residuals) and partly voxel quantization. The floor cannot correct horizontal error, and wall-only ICP proved unreliable here. The candidates are colored ICP using RGB (Open3D), and RTAB-Map offline reprocessing as an independent second refinement (`../research/WIDTH_SCALE_METHODS.md`, items 1 and 4). Each must pass the same held-out acceptance.
- **Measuring passage width honestly**: a distance field with unknown treated as occupied and as free (OctoMap `dynamicEDT3D`, already in the octomap we use), measured along the medial axis at foot, body and head heights, reported as a range. This is our combination of released parts, not an established method; it needs checking against FARO and tape-measured passages.

## Status

| Item | Status |
|---|---|
| Cause of view-dependent floor height | separated on Koivu: pose drift in runs (R² 0.74 time vs 0.007 range) |
| Joint pose-graph refinement | rejected twice (receipts kept) |
| Floor-constrained correction with held-out validation | run on both rooms; safe; partial |
| Gate by deleting inconsistent frames | rejected (unsafe) |
| Local support layer | not implemented |
| Horizontal pose correction (colored ICP / RTAB-Map) | not run |
| Frozen v3 map, 20 route pairs | not done |
| Movement episodes | **0 / 100** |
