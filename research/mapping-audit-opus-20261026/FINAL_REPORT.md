# Final report — phone-only room mapping for blind navigation (2026-10-26)

Data: the public MuSHRoom recordings (CC BY 4.0, Xuqian Ren et al., doi:10.5281/zenodo.10230733). Two rooms were used:
- **Koivu**, used for development.
- **coffee_room**, used as a holdout.

Both were captured on an iPhone 12 Pro Max through Polycam. The FARO scan is used **only to score** results after the fact. No planner, controller or map ever received it, and it never corrected the phone map. No camera path was carved into free space. The person was not shrunk: the body is 0.45 × 0.30 × 1.60 m with a 0.15 m margin. Unknown support stays unknown. Every failed and aborted result is kept.

**Everything below is offline simulation on recorded data. None of it is live-device or physical-safety evidence for a blind child or adult.**

## 1. Answer in plain language

1. **The original mapping was wrong. It was not the iPhone.**
   - Depth units, the axial depth convention, intrinsics, pose axes and frame association all check out.
   - Three implementation defects made the maps unusable:
     - a min/max floor rule that turned the floor into an obstacle;
     - long-range noise read as drops;
     - the body counted twice (0.60 m erosion instead of 0.375 m).
   - Fixing these with the released OctoMap engine turned an unusable map into a routable one ([README](README.md), [CORRECT_APPROACH](CORRECT_APPROACH.md)).
2. **The remaining view-dependent floor height is pose drift, not depth noise.**
   - On Koivu, the floor offsets of the ±3 neighbouring frames explain R² = 0.74 of a frame's floor offset; its range explains R² = 0.007.
   - Two pose corrections passed held-out checks: a floor-constrained correction and colour ICP. A third, deleting inconsistent frames, was **rejected as unsafe**. It erased real overhangs and raised open-floor misses from 4 to 13 ([pose-consistency/](pose-consistency/)).
3. **The frozen v3 phone map was tested in the published v3 movement world.**
   - **Koivu: 29 of 100 episodes arrived cleanly**, with **0 actual-body contacts**.
   - **coffee_room: 0 of the 30 runnable episodes arrived**, with **0 actual-body contacts**. Its other 70 were route-unavailable: the phone map found only 6 of 20 routes.
   - Most runs that did not arrive stopped because a **5–11 mm floor-level facet** entered the 15 cm safety margin. That is not a body collision.
   - Next most common: a known conflict between two of the world's own fixed motion parameters.
   - One run's margin box touched a **38 mm vertical face**. No run touched the body.
4. **For blind users the map now errs toward blocking, not toward false clearance.**
   - It is still too conservative to be useful for longer routes: the reference room has 2–6 m routes at full margin, and the phone map found only 2.0–3.3 m.
   - The limiting factor is the foot band near furniture. At the median it is 40 cm (Koivu) and 66 cm (coffee_room) narrower than the reference, plus a 5–10 cm halo around obstacles.
   - Below 2.5 cm, the map cannot separate a low object from floor relief. The evaluator has the same blind spot below 3 cm. This matters for rug edges and cables, and only a device test with physical objects can settle it.

## 2. Every stage and its outcome

| Stage | What was done | Outcome | Where |
|---|---|---|---|
| Input audit | Units, axial vs range, intrinsics, poses, frame association, v1 reproduction | All correct. v1 reproduced with identical counts. Depth PNGs are 4× nearest-neighbour upscales: 13.4 M real samples, not 215 M | [README §1](README.md) |
| Defect diagnosis | Floor extremum rule, far-range "drops", √2 body double-count, permanent single hits | Floor rule is the primary cause. v2 inherited it; Recast built **no polygons** even at the bare body circle | [README §2](README.md) |
| Smallest fix (policy D1) | OctoMap 1.10, LiDAR-native rays, measured level plane, ±2.5 cm floor layer, near/far trees, unresolved-low flag | 10,669 walkable columns versus 1. Synthetic 4 cm and 8 cm boxes rendered into the real rays were all retained | [README §3](README.md) |
| Second pass | Statistical low-band test, orientation-aware route check | About 1,000 ambiguous low columns quantified. No honest map yields 2–6 m routes without the reference question | [FULL_REPORT](FULL_REPORT.md) |
| Reference scoring (evaluator only) | FARO scoring of the frozen D1 map on Koivu and the coffee_room holdout | Statistical "object" calls were 96% not real geometry; specks 0% real. Walkable misses 0.2–0.9%, all at obstacle edges. The reference has 387 (Koivu) and 537 (coffee_room) 2–6 m routes at full margin | [REFERENCE_SCORING](REFERENCE_SCORING.md) |
| Variants | Open3D TSDF as occupancy, blob removal, threshold 0.8, ±3.75 cm band, 2.5 cm voxels, split 0.5/0.7 | All rejected as unsafe except the 0.5 support / 0.7 obstacle split, which passes on both rooms | [VARIANT_TESTS](VARIANT_TESTS.md) |
| Pose drift | Cause separation; Open3D pose graph (rejected twice); floor-constrained correction; colour ICP; frame gating | Floorfix and colour ICP accepted. Gating is unsafe. Koivu camera positions in blocked cells fell 39 → 17 | [POSE_EXPERIMENTS](pose-consistency/POSE_EXPERIMENTS.md) |
| v3 map | Colour-ICP poses, D1 bands, support = OctoMap 0.5 OR statistical floor layer, obstacles at 0.7 | Koivu: 4 open-floor misses; real floor wrongly blocked 957 columns (was 1,287) | [v3/maps](v3/maps/) |
| Width and scale | Passage width along the walked path; ceiling scale | Planner corridors are a median 7 cm (Koivu) and 9 cm (coffee_room) narrower than the reference. Ceiling 2.45 vs 2.48 m (Koivu) and 2.39 vs 2.43 m, about 1–2% short, as published for Apple depth | [WIDTH_SCALE_METHODS](research/WIDTH_SCALE_METHODS.md), [v3/widths](v3/widths/) |
| Movement game | 20 routes × 5 conditions per room in the master 7506ad9 v3 world | Section 3 | [v3/game](v3/game/) |

## 3. Movement game (frozen v3)

### Setup, fixed before any episode ([V3_FREEZE.json](v3/game/koivu/V3_FREEZE.json))

- **Map:** `occthres_statsplit0.7.npz`. Koivu SHA-256 `39df1037…65c3`. The game checks the hash and refuses to run if the map changed after the routes were frozen.
- **Planner:** Recast/Detour `9f4ce64` with a 0.375 m disc (lateral half-width 0.225 + 0.15 margin) and 0.05 m cells. Each route must also pass a swept 0.45 × 0.30 m rectangle check with the 0.15 m margin on the phone map.
- **Routes:**
  - Pairs 2–6 m on a 0.25 m lattice, seed 271828, each endpoint used at most twice.
  - The lattice is a **deviation** from the draft's 0.5 m, decided before any episode.
  - The reference was not queried during selection.
  - Koivu: 20 routes, 2.0–3.3 m.
  - coffee_room: 6 routes, 2.1–2.5 m. For the other 14 the phone map had no qualifying pair.
- **World:** reused unchanged from master `7506ad9`:
  - `OrientedReferenceContainer`: the actual oriented body and a separate 15 cm margin enclosure, 2 mm floor exclusion;
  - `GroundSupport` / `GroundedReferenceContainer`, ground-follow-v3: a seeded, connected low-slope ground; every other triangle stays an obstacle;
  - `impairments.py`: the five conditions baseline, delay, motion-scale, wrong-turn and combined.
  - The first contact, body or margin, ends a run. There is no repositioning and no route replacement.
- **Controller:** an in-process **Python substitute** for the Swift `SurfaceGameWorker`, which cannot be built in this container. It follows the Detour corridor on the frozen phone map and never sees reference geometry, contacts or support.
  - One bug was found and fixed before the counted runs: the actor steered back to `path[0]`.
  - The fix matches `game_model.follow_candidate`, which follows `points[1:]`.
  - It was verified kinematically: all 20 Koivu routes reach the goal in 85–173 ticks without the world.
- **Scorer:** a decision-equivalent fast path, `scripts/fast_container.py` (section 4).

### Koivu, 100 episodes

| Outcome | Episodes | Meaning |
|---|---:|---|
| **Clean arrival** | **29** | Routes 0, 8, 12, 18 under all 5 conditions; routes 2, 5, 9 under 3. Walked 1.68–2.90 m; goal error 0.20–0.34 m; 85–232 ticks |
| Actual-body contact | **0** | — |
| Margin contact, facet 3 mm–3 cm above the foot | 36 | Small tilted facets 5–11 mm above the floor plane entered the 15 cm margin (see below) |
| Margin contact, ≤ 3 mm | 6 | Floor mesh clipping the world's fixed 2 mm floor gap |
| Margin contact, > 3 cm | 1 | Route 2, delay: a 38 mm near-vertical face entered the margin box at 1.18 m. The body was not touched |
| Harness step-cap conflict | 18 | Motion-scale and combined conditions on 9 routes; stopped on the first step at 0 m |
| Invalid start | 10 | Route 6: a near-foot facet already inside the margin at the start (5). Route 19: no valid ground component (5) |

- **By condition (arrivals):** baseline 7, delay 6, motion-scale 5, wrong-turn 7, combined 4.
- **Movement:** 72 episodes moved, a mean of 1.50 m each.
- **Wall time:** 3 parallel workers took 11,242 / 13,548 / 8,721 s.

### coffee_room holdout, 100 scheduled

| Outcome | Episodes |
|---|---:|
| Route unavailable (phone map found only 6 of 20 routes) | 70 |
| Clean arrival | **0** |
| Actual-body contact | **0** |
| Margin contact ≤ 3 mm (floor clipping) | 14 |
| Reference support unconfirmed during motion (routes 0 and 4, after 0.25–0.50 m) | 10 |
| Harness step-cap conflict | 6 |

- 24 episodes moved, a mean of 0.63 m. Wall time was 7,102 s.
- The holdout result is a **failure of the method in this room**:
  - the phone map supported too few routes;
  - none of the runnable routes reached its goal;
  - none of them contacted the body.

### Why the runs stopped ([CONTACT_TRIANGLES.txt](v3/game/CONTACT_TRIANGLES.txt))

Every first-contact reference triangle was mapped back into the phone level frame.

- **Koivu, 16 distinct triangles:**
  - 15 are tiny facets (5–27 mm²) tilted 21–63° from horizontal, 5–11 mm above the floor plane.
  - One is a 38.5 mm-high near-vertical face (88°), which is the single > 3 cm contact.
  - The facets are consistent with floor relief, the bottom edge of a rug or skirting, or mesh noise.
  - The data cannot say which. Whether a 1 cm edge is a trip hazard for a blind walker is a real question, and simulation cannot settle it.
- **coffee_room, 4 distinct triangles:**
  - All four are near-horizontal floor facets (3–23° tilt) **5–7.5 mm below** the phone floor plane and 2.0–2.3 mm above the actor's start foot.
  - They are floor outside the world's seeded connected-ground component, so the world counts them as obstacles once they rise above its 2 mm floor gap.
  - This is **evaluator floor ambiguity**, not evidence of a hazard. It is not evidence of safety either.
- **Step-cap conflict:**
  - The motion-scale profile multiplies the 0.02 m step by 1.25, giving exactly 0.025 m horizontally.
  - The world's 3D movement cap is 0.025000001 m, so any slope under the first step exceeds it.
  - These two published parameters are incompatible. It is not a navigation result.
  - It was left unchanged because the world is frozen. Why only some routes trip it was not investigated.
- **Reference support unconfirmed:** the reference mesh offered no accepted support under the actor's next pose. This is an evaluator limit, such as mesh holes or disconnected ground. It does not show a drop, and it does not show clearance.

## 4. Scorer speed and equivalence (VTK 9.7.1, not 9.3.1)

The original `GroundedReferenceContainer` took about 13 s per tick. Profiling found the same hotspot the other session reported (97.5% on master `9ae4d0c`): `vtkStaticCellLocator.FindCellsWithinBounds` on large boxes. `scripts/fast_container.py` keeps the decision identical:

1. **Ground removal.** Confirmed ground IDs (the same set as `GroundSupport.is_ground`) are removed before the per-triangle test. Ground-contact counts are therefore not computed and are reported as `null`.
2. **SAT prefilter.** A conservative separating-axis triangle/box test against the box inflated by 1 mm. It never drops a triangle that touches the box. VTK still decides every survivor, in the original order.
3. **Tiled broad phase.** Lookups use tiles of at most 0.25 units, taking the union of IDs. The decision is accepted only when the tiled pass finds no contact. **Any positive replays the original single native-order call**, so the reported first triangle is the original one.

Evidence:
- **Tiled lookup:** for 120 body and margin boxes along all 20 frozen Koivu routes, the tiled ID set was identical to the single call in 120 of 120 cases. It was 7.6× faster (260 s → 34 s) ([TILE_EQUIVALENCE_VTK971.json](v3/game/TILE_EQUIVALENCE_VTK971.json)).
- **Fast vs slow scorer:** contact flag and first cell matched at 12 random poses ([FAST_SCORER_EQUIVALENCE_12_RANDOM_POSES.log](v3/game/FAST_SCORER_EQUIVALENCE_12_RANDOM_POSES.log)). At poses where the candidate cap is exceeded, both paths raise.
- **In-run guard:** the aborted attempts ran a guard that compared the slow scorer on the first swept checks and aborted on any mismatch. It never fired. The counted runs had the guard off; the offline checks above are the evidence.
- This is equivalence on VTK 9.7.1. The other session's 5.65× result is on 9.3.1, which could not be installed on Python 3.13 here.

## 5. Failures and aborted attempts, all kept

| Attempt | What happened | Kept in |
|---|---|---|
| Slow scorer, Koivu and coffee_room | About 13 s per tick; killed as impractical | `v3/game/smoke-and-aborted/*slowScorer_killed` |
| Guard of 40 slow checks | Too slow; killed. No mismatch | `*_guard40_killed` |
| Guard of 5 | Killed; superseded by the offline equivalence checks | `*_guard5_killed` |
| Controller bug | The actor steered back to `path[0]`. All episodes were rerun after the fix; the bug runs are not counted | `*_controllerBug` |
| Smoke run, fixed-foot scorer | Before ground-follow-v3 | `smoke_fixedFoot_scorer_GAME_RESULTS.json` |
| Open3D pose graph v1 and v2 | Rejected: median pose change 27 cm, or 157 of 174 good frames made inconsistent | `pose-consistency/` |
| Frame gating | Unsafe: open-floor misses 4 → 13 | `pose-consistency/` |
| TSDF occupancy, blob removal, threshold 0.8, ±3.75 cm band | Unsafe | `VARIANT_TESTS.md` |

## 6. What this does and does not establish

**Established, offline on two public rooms:**
- The original failure was the implementation, not the iPhone.
- The corrected map keeps synthetic 4 cm boxes.
- Pose drift explains the floor variation.
- v3 reaches 29 of 100 Koivu goals with no body contact in the reference world.
- Scale is within about 1–2% at the ceiling.

**Not established:**
- Any behaviour on a live phone.
- Detection of real objects under 2.5 cm.
- Performance in other rooms. The holdout failed to produce arrivals.
- Routes longer than 3.3 m.
- The Swift worker's behaviour.
- Physical safety for anyone.

Independent use is not supported by this work. The AGENTS.md trial sequence still applies:
1. bench checks;
2. a sighted adult comparison;
3. a seated eyes-closed test;
4. a supervised session with an observer;
5. guardian and O&M review before any child mobility trial.

Hazards must be simulated only.

## 7. What I would do next, smallest first

1. **Harness:** the world's step cap should follow the actor profile, or the 1.25× profile should be measured horizontally. Otherwise 18 + 6 episodes per run say nothing. This is for the session that owns the world.
2. **Evaluator:** a person should look at the 20 contact triangles in the FARO scan and label each as relief or object. If they are floor relief, the near-foot category needs a documented rule. If they are rug edges, the phone map must learn to report them, because they matter to a blind walker.
3. **Map:** the remaining loss is the foot band near furniture plus the 5–10 cm halo. The safe next step is an SE(2) footprint check that turns only where the full rectangle fits, for example OMPL with this map as the collision checker. This recovers corridor width without shrinking the person. Shrinking the margin is the user's policy decision, not a mapping fix.
4. **Coverage:** coffee_room shows that a single walk-through leaves too few known-free foot-band columns. The app should ask for a short stationary look-around when it has no full-body route, rather than guess.
5. **Device:** the iPhone 18 Pro Max bench run with physical low objects (1, 2.5, 4 cm), simulated, never real, drops, and the AGENTS.md trial sequence.

## 8. Files and reproduction

- **Scripts:** `scripts/game100.py` (map, Detour, controller), `game_v3.py` (episode loop), `fast_container.py`, `game_analyse.py` (merge and categories), `tile_check.py`, `ctl_sim.py` (kinematic controller check) and `contact_tris.py`. Paths come from the `SCRATCH` environment variable, and the master `7506ad9` world tools are expected under `$SCRATCH/split3/research/tools/koivu-split-candidate-game-v1`.
- **Results:**
  - `v3/game/koivu/GAME_RESULTS_part_*.json` and `GAME_MERGED.json`;
  - `v3/game/coffee_room/GAME_RESULTS.json` and `GAME_MERGED.json`;
  - the worker logs.
- **Run commands:**
  - Koivu: `ROUTE_SUBSET=0-6|7-13|14-19 python game_v3.py <run_dir> occthres_statsplit0.7.npz <routes_dir> <recast_dir> <icp_iphone.json> <gt_mesh.ply>`
  - coffee_room: the same command without `ROUTE_SUBSET`.
  - Then run `python game_analyse.py <routes_dir> <label>` for each room.
- **Environment:** Python 3.13, VTK 9.7.1, numpy 2.5.3, Recast `9f4ce64` built with g++ 13.3. Runs were serial within each worker with `OPENBLAS_NUM_THREADS=1`. Peak memory was not instrumented.
