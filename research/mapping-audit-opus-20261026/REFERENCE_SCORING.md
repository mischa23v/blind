# Reference scoring and holdout — development room Koivu, holdout coffee_room (2026-10-26)

**Evaluator only.** The FARO reference entered no planner map. Everything labelled "REFERENCE-ONLY" is evaluator geometry used as a hypothetical perfect map to answer "could the requested routes exist at all?". **Still 0 of 100 movement episodes.** Reference caveats: cleaned/hole-completed, author registration (scale 1.0208 Koivu, 1.0096 coffee_room), captured at a different time from the phone (furniture may have moved). Scoring is by mesh vertex (mm spacing) per 5 cm column.

Pipeline: one script (`scripts/pipeline.py`) with thresholds fixed from the Koivu work **before** the holdout archive was opened; the holdout was chosen by a stated criterion (coffee shop = product-relevant public venue type), not by results. Receipts: `koivu_PIPELINE_RECEIPT.json`, `coffee_room_PIPELINE_RECEIPT.json`.

## 1. Registration sanity

| | Koivu | coffee_room |
|---|---:|---:|
| frames / LiDAR samples | 294 / 13.4 M | 388 / 17.7 M |
| phone floor tilt | 0.05° | 0.02° |
| per-frame vertical offset p95 / max | 1.1 / 3.5 cm | 1.25 / 3.9 cm |
| reference floor vs phone plane (p5/50/95) | −0.8 / 0.0 / +2.0 cm | −1.6 / −1.1 / +1.5 cm |
| phone high-obstacle columns confirmed by reference body-band geometry | 7,936 / 10,070 (79 %) | 3,155 / 4,469 (71 %; 663 without reference cover) |

Vertical registration agrees to about 1 cm in both rooms. The phone's large obstacles are mostly real.

## 2. Do the phone maps miss low objects? (safety view)

Share of planner-walkable columns where the reference has geometry 2.5 cm or more above the floor:

| Walkable set | Koivu | coffee_room |
|---|---:|---:|
| D1 permissive | 94 / 10,657 (0.9 %) | 25 / 6,246 (0.4 %) |
| D1 strict (near-only low band) | 25 / 3,595 (0.7 %) | 8 / 2,400 (0.3 %) |
| **Statistical clear only** | 54 / 8,426 (0.6 %) | **8 / 4,785 (0.17 %)** |
| Statistical object-blocked | 67 / 9,932 (0.7 %) | 11 / 5,824 (0.2 %) |

On Koivu, **all 87 (first pass) misses lie within 6 cm of a column the map already blocks**: they are the outer edge of objects the map has, not objects in open floor. None is beyond the 0.15 m margin. The statistical "clear" call is as safe as the near-range call, on both rooms, while resolving 5,300 (Koivu) and 2,800 (coffee_room) columns the near rule left unresolved.

## 3. Are the phone's "object" calls real?

| Class | Koivu real / called | coffee_room real / called |
|---|---:|---:|
| statistical `object` | 44 / 1,035 (4 %) | 21 / 500 (4 %) |
| isolated specks (≤3 columns) | **0 / 129** | **0 / 83** |
| D1 low-band positive (not high) | 68 / 604 (11 %) | — |

Pre-declared alternatives on Koivu (dev room, scored once): mean > 2.5 cm → 7 % real; mean > 4 cm → 12 % real, with recall falling from 36 % to 13 % of the 113 reference low objects in the candidate set. No threshold separates them. **The holdout confirms the pattern: with these rules, 96 % of low-object calls and 100 % of isolated specks are not real geometry, in both rooms.** Conversely, real low-only objects (Koivu: 380 columns, median 14 cm high) are mostly already blocked as part of larger obstacles.

The false obstacles are not flying pixels: only 288 of 1,722 false high-obstacle columns on Koivu are dominated by depth-discontinuity samples. They sit a median **7 cm** outside reference geometry, 99 hits per column (true obstacles: 315).

## 4. Why no 2–6 m route exists on any phone map, in either room

| | Koivu | coffee_room |
|---|---:|---:|
| reference walkable (main region) | 10,805 col = 27.0 m² | 7,821 col = 19.6 m² |
| phone walkable (D1 permissive) | 10,695 | 6,250 |
| reference-walkable but phone-blocked | **1,791 (17 %)** | **1,695 (22 %)** |
| …distance from real geometry p50 / p90 | 0.11 / 0.43 m | 0.11 / 0.40 m |
| …further than 0.15 m from any real geometry | 754 | 775 |
| phone-walkable but reference not | 1,643 (a wing cut off in the reference by a door) | 120 |
| rectangle routes 2–6 m, full margin: any phone map | 0 | 0 |
| rectangle routes 2–6 m, full margin: **REFERENCE-ONLY** | **387** (median 3.5 m, max 6.0 m) | **537** (median 3.7 m, max 6.0 m) |

So the rooms admit the requested routes for the declared 0.45 × 0.30 person with the full 0.15 m margin, **if the map is right**. The phone maps have the right area but block about a fifth of the real floor: half of that is a 5–10 cm smear around real obstacles, half is scattered false blocks further out.

How much slack is there? Eroding the **reference** map uniformly:

| Reference obstacles inflated by | Koivu routes | coffee_room routes |
|---|---:|---:|
| 0 cm | 387 | 537 |
| 5 cm | 305 | 49 |
| 10 cm | **1** | 33 |
| 15 cm | 0 | 23 |

With this person and margin the aisles leave about **5–10 cm of slack**. Any map that inflates obstacles by one voxel, or sprinkles false blocks in aisles, removes the routes. That is the whole remaining problem, and it is a mapping-precision problem, not a sensing-coverage one.

## 5. Conclusions

1. **The phone's walkable calls are safe at the level this reference can test** (0.2–0.9 % of walkable columns touch reference low geometry, all at obstacle edges). Statistical far-range resolution of the low band holds on the holdout.
2. **The phone's obstacle calls are too generous**: ~17–22 % of real floor is blocked, by a 5–10 cm halo around real objects plus isolated false blocks that the reference says are empty in 100 % of speck cases on both rooms.
3. **The rooms allow the requested 2–6 m routes at the full margin only with ≤5 cm obstacle inflation.** The margin, the person and the room are compatible; the map's halo is not.
4. **Both earlier mappers were far worse than this**, but even the corrected diagnostic map is 5–10 cm too fat.

## 6. What this points to (not implemented)

- **Sub-voxel surfaces.** 5 cm occupancy voxels put every surface into a 5 cm slab, sometimes two. Open3D TSDF (v0.19.0, MIT) with 1–2 cm voxels gives surfaces at their measured position; its weight layer must be kept as coverage. This is the comparator both audits named; the erosion table shows why it matters.
- **Finer occupancy as a cheaper test**: OctoMap at 2.5 cm (8× leaves; Koivu would be ~2 M leaves, fine) measures how much of the halo is quantization.
- **A per-column obstacle statistic for the body band**, like the low-band one: columns with ~100 scattered hits versus ~300 coherent hits separate false from true obstacles here; the 100 %-false specks are the clearest case. Decide and freeze on Koivu, test on coffee_room, as done here.
- **Error budget, not margin cut.** If the frozen map is shown to inflate obstacles by x cm, that x belongs in the written error budget alongside localisation and controller error. Keep 0.15 m until that budget exists.
- **Reference confounds to record**: furniture moved between captures; reference cleaning may have removed cables and small items; one wing of Koivu is unreachable in the reference (closed door).

## 7. Status

| Item | Status |
|---|---|
| FARO evaluator scoring (Koivu) | run — development room |
| Holdout room with identical code/thresholds (coffee_room) | run — confirms the pattern |
| Reference-only feasibility of 2–6 m routes at full margin | run — 387 / 537 routes |
| Erosion sensitivity | run — 5–10 cm slack |
| Phone-map route at full margin, no reference leak | **0 in both rooms** |
| Open3D TSDF / finer-voxel map | not run |
| Frozen v3 map + 20 route pairs | not done |
| Movement episodes | **0 / 100** |
| Device evidence | none |
