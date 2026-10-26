# Verified assisted doorway round trip

One deterministic controlled simulation completes entry and same-actor return:8.431984068m horizontal,686states, both stationary/drained arrival gates within frozen0.35m tolerance. Nominal45x30x160cm body with zero horizontal margin. All actual/predicted contact counters zero. Manual evaluator-world sill/support assistance remains explicit; all686statesretain unresolvedlow-obstacle exposure. NOT phone-only navigation, human safety,100trials or fulltableloop.

Return now begins from delivered actual arrival using only unchanged sourcePolycam/Recast geometry and parameters. No disputed floorface was cleared. Separate diagnosis packet preserves uncertainty near the baseboard.

Archive SHA256: b3358995c9438be36256008119f38e888d81f1e9040a2513de652bc7253efcd9; 47 files plus manifest. Prior published dependencies/public raw inputs required.

## blind-actual-arrival-return-replan-54

# Stage54: same-actor assisted doorway entry and return completed

**One controlled offline simulation completed entry into the adjoining room and return to the original outside goal region, with no recorded contacts.** This is an explicitly manually assisted evaluator-world result—not phone-only obstacle detection, human walking validation or a real-device safety claim.

## Measured result

| Measure | Entry | Return | Total |
|---|---:|---:|---:|
| Arrival | Yes | Yes | Both |
| Horizontal distance | 4.388010405 m | 4.043973663 m | **8.431984068 m** |
| Arrival tick | 263 | 685 | 686 recorded states |
| Full-3D goal error | 0.343921464 m | 0.344307103 m | Frozen tolerance 0.35 m |
| Stationary and queues drained at arrival | Yes | Yes | No actor reset |

Total 3-D travel: **8.507299542 m**. Executed body, margin and supplementary underbody contact counts: **0 / 0 / 0**. Predicted collision rejections: **0 / 0 / 0**. Largest executed 3-D substep: 0.020000011 m; largest yaw substep: 1 degree. Independent arithmetic recount matched every committed state to its accepted macro and matched the flushed CSV exactly to the terminal trace. Initial vertical settlement is separately recorded; no post-start pose reset or teleport occurred.

## What changed—and what did not

Stage51 reached the entry goal but unnecessarily advanced to a deeper old reverse-route endpoint before turning back, then stopped at untyped support face7253304. This variant does **not** relabel or remove that face. At the actual delivered, validated entry arrival, it makes one source-only native Recast/Detour return query from that pose to the unchanged original outside goal. It uses the same Polycam geometry, rigid registration, radius, climb, slope and association checks. No reference mesh, failure-face information, collision feedback or support classification is supplied to the planner. The small native start association is walked through normal full-body sweeps, not snapped.

Entry and all physics/support/geometry policies remain unchanged from51. The actor remains a nominal45×30×160cm box with **zero horizontal margin**. The same actor and actuator queues persist across the transition. Manually typed evaluator-world sill geometry still drives bounded support placement; original structural geometry remains collidable. The exact return query and route are saved in `run-01/result/SOURCE_ONLY_RETURN_QUERY.json`.

This corrects a return-path initialization defect. It does not solve automatic floor/sill perception, uncertainty estimation, general room mapping, latency/jitter robustness, child-body validation or physical navigation. All **686** evaluated ticks retain unresolved low-obstacle exposure under the old phone-map diagnostic. The result covers **one deterministic assisted round trip**, not 100 journeys or a full table loop.

## Evidence

- Frozen manifest SHA-256: `89a9f5550c21b8cc34263206b53f7455dee8aa5dd01a6e691867aa4324858d9c`; 522 pinned inputs.
- `PROTOCOL.md`: declared source-only return rule, assistance boundary and resource limits.
- 59 pre-run fixtures passed, including real subprocess return querying, stale/busy rejection and failure acknowledgement accounting.
- `run-01/RUN_RECEIPT.json`: valid bounded process; 425.078s wall,429.41s CPU,peak sampled/waited process-treeRSS2,329,743,360bytes;16MiB output cap and768MiB disk reserve retained.
- `run-01/result/RESULT.json`: complete measured terminal result and both stationary arrival receipts.
- `run-01/result/ACTOR_TRACE.npz` and `ACTUAL_TRACE_STREAM.csv`: original committed states.
- `postrun/ACTUAL_TRACE.csv`: exact original and registered-source coordinates, leg labels and cumulative distance.
- `postrun/ACTUAL_SOURCE_MODEL_PATH.png`: committed entry solidblue and committed return dashedorange on registered original source geometry, with no proposed or failed connectors. Gray source geometry is not a clearance certification.
- `postrun/RECOUNT.json`: arithmetic, arrival, phase, substep and stream consistency checks.

All earlier failed variants are preserved. This report does not retrospectively convert them into successes.


## blind-return-support-diagnosis-52

# Post-run diagnosis of stage51 return stop

No motion, mesh change, floor relabeling or classifier relaxation is performed here. Stage51 remains immutable.

The rejected midpoint probe hit original FARO face **7253304**, at approximately original-game XZ (4.86465, 0.09973). All nine rays hit geometry; this was not an unobserved-support hole. The exact original triangle was read directly from the binary PLY, with the same float32 vertex quantization and pinned world transform as the collision evaluator.

- Absolute-Y normal slope: **19.93484°**, outside the ≤5° training rule, within the ≤45° recovery guard.
- Saved assigned local-plane residuals at the three original vertices: **+2.72772, +1.49923, +1.42949 mm**.
- The first vertex fails the existing **2 mm every-vertex** recovery criterion. This is an exact eligibility rejection; we have not separately rerun the full adjacency component calculation.
- Broad active gray-plane residuals: −1.26570, −2.51967, −2.54609 mm.
- The recorded midpoint support spread and height-cap checks pass, but the frozen semantic membership does not.

## Source photographs

`project_face_views.py` projects the exact triangle centroid through the original game-to-phone transform and original camera poses, not the corrected display frame. It requires visibility and a source-depth median within 10 cm of predicted axial depth; this is an association check, not a clearance or identity guarantee.

Frames **00145** and **00126** were selected and visually inspected. The projected point is close to the far wall/baseboard and a small pale strip or object at floor level, not an unambiguous central patch of empty carpet. RGB and reference captures can disagree; this evidence does **not** justify automatically declaring the face noise or free space. Exact camera/UV/depth association values and source-image hashes are in `SOURCE_VIEW_ASSOCIATION.json`.

## Independent controller issue

Stage51 starts its return by first moving from the accepted arrival pose to the old precomputed reverse route's deeper starting waypoint. This is unnecessary if a return route can instead be queried from the actual delivered arrival pose. A new source-only planner variant can test that without relabeling this disputed face. Such a test must preserve the current mesh, collision, body, goal and support rules and report any new route separately.


