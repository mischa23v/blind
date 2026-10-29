# Navigation geometry: phase update and next acceptance gates

**Evidence assembled 2026-10-29 07:46 UTC; individual receipts retain their actual dates.** This supplements, rather than replaces, the earlier full audit and its negative cases. It is a source/aggregate status report, not a new test or release-readiness declaration.

## Decision

We now have executed released-engine baselines and explicit fixes, not just a list of repositories. **No tested method wins every relevant geometry metric, and none establishes safe navigation.** The next useful step is to audit how measured geometry becomes traversable space, then test complete routes against independent geometry. Another average-score variant alone will not answer whether a person can walk around the table or through the doorway.

N3's completed 265-frame reconstruction and unchanged held-out score are real. They do **not** justify replacing the existing candidate globally. Relative to C1_N2, N3 gains 484 paired rays, median improves 3.308→3.291 cm and ±5 cm agreement 65.050→65.263%, but p95 worsens 101.312→101.973 cm and ±10 cm agreement falls 81.882→81.648%. These are paired axial-depth metrics, not a percent of safely detected hazards. Exact-common-ray comparisons retain the far-tail regression; newly gained rays have median error 23.980 cm and p95 322.235 cm. Keep both candidates and the supplied-pose baseline as controls, not a declared winner.

## What actually ran, versus what was only inspected

| Component | Executed evidence | What cannot be claimed |
|---|---|---|
| Open3D 0.19.0 supplied-pose scalable TSDF | Koivu 265 train /29 excluded; fixed evaluator on all 1,335,885 scheduled held-out rays. Coffee 350 posed train /38 held-out, with 3 unposed excluded. | TSDF completion is not observed-free floor or hazard validation. Coffee's 2 complete queries are one 2.372 m corridor in both directions, not room-wide movement. |
| Open3D full registration/optimized-pose workflow A and controlled refusion B | Both completed and independently scored against the identical Koivu ray protocol. A/B paired-hit counts 236,213/477,400 versus supplied-pose 1,187,988; median errors 132.464/129.884 cm versus 3.404 cm. | These arms are worse here. This is not proof all pose refinement fails. A/B differ in calibration/truncation, share the estimated trajectory; B is not a corrected trajectory. |
| RTAB-Map fixed and graph arms; corrected RTAB + OctoMap | Each fixed/graph arm processed265 frames. Corrected WORLD-Z-up native occupancy run completed with ray clearing. | Its point-nearness/coverage metrics cannot be ranked directly against first-hit ray metrics. Ground labels are not support; observed-free occupancy is not certified walking floor. |
| Native Voxblox MergedTSDF | Full265 native run and identical held-out scoring; upstream test evidence retained. | Mixed improvement: pooled tails improved versus supplied-pose Open3D, but below4m tails and tight ±2cm band worsened. No blanket accuracy win. |
| Voxfield-derived D1/N2/N3 arms | Pinned native core build; independent synthetic checks; same-input prefix runs; recovered full265 B/C0/C1_N2 and fresh C1_N3 retry; independently recounted fixed-protocol scoring. | D1 zero-axis defect fix is not a measured room-level gain: B reproduces stock output bytes. N2/N3 synthetic/provider successes are not real normal ground truth. N3 stencil also changes support availability and is export-specific. |
| Recast/Detour + Apple native geometry adapters | Synthetic fixtures, saved geometry, recorded Coffee queries, strict endpoint cases and EDT margin cases actually executed. | A partial/projected route is not arrival. Two Apple corner successes are the same hall corner under two body profiles, not two independent locations. No complete live pipeline readiness established. |
| OpenUSD / Apple native import | Exact saved-file source transforms and import/export comparisons executed; source-floor versus visual solid packing errors isolated and repaired in limited fixtures. | Reader agreement and local fixtures do not establish physical room accuracy or live ARKit sensing. |
| InfiniTAM | Native CPU/calibration/capped-mesher plan and source inspected; build unrun. | Noncommercial-purpose license gate unresolved; not a failed score and not GPU-only. |
| nvblox v0.0.10; ElasticFusion; BundleFusion | Exact source/license/toolchain feasibility reviewed, no room execution. nvblox Apache2.0 pin7f4d5de… recovered. | CUDA/hardware blocks; ElasticFusion also noncommercial terms; BundleFusion official Windows/DirectX/CUDA recipe unavailable. Unrun is not inferior. |
| Kimera-VIO / Kimera-Semantics | Source/input compatibility reviewed. | Required synchronized IMU unavailable for VIO. Geometry-only Semantics relies on Voxblox, not an independent tested semantic mapper. |
| Nav2 collision monitor, elevation mapping, active-view planning, Dynablox, OMPL/DetourCrowd | Source/API/test-transfer reviews, not executed integration or phone tests. | Upstream test names do not prove our port. Vacuum motor/sensor coverage assumptions do not transfer to a walking person. |

Blender's installed build lacks USD import; Unity USD, USD-enabled Assimp/tinyusdz and Godot remain source/capability comparisons, not executed same-room reconstructions. These reader/game-engine tools cannot replace a calibrated reconstruction test.

## What the fixes establish—and what remains unresolved

- Confirmed adapter/policy problems include floor classification that converted ordinary observation disagreement into permanent blockage, double body inflation, wrong input world-up contract, export index/reader failures, native source-floor packing/expansion, and retained cells violating the actual source-wall margin. Their specific fixes and failures are retained; not all downstream behavior is repaired.
- D1 fixes the isolated exact-zero ray-step defect. N2 makes previously numerically unavailable normal calculations available. N3 uses a support spacing suited to this repeated-depth export. None eliminates missing observations, drift, low-object ambiguity or changes in furniture.
- N3's original 159-frame attempt remains environment-interrupted with unknown cap compliance and no final mesh/resource receipt. The successful empty-map retry is separate. Earlier N2's 300-CPU-second batch failure likewise remains a failure with separately admitted recovered outputs.
- The reference has registration and editing/completion uncertainty. Shadows or colors are not physical obstacles, but visual resemblance does not identify the source of a particular 3D blockage. Each rejected route must be traced to actual source observations, coordinate transforms and policy—not explained away as “too narrow.”

## Next: geometry → traversability audit, then complete-route validation

1. **Freeze a small spatial test set before examining variant outcomes.** Use the disputed doorway, long corridors, table perimeter, floor transition and known low/overhead obstacles. Preserve original body profiles, clearances, endpoints and both failed and successful cases. Select exact source observations and reference eligibility separately; no hand-carving a path.
2. **Audit each conversion boundary.** Verify metre scale, camera/world transforms, floor orientation, triangle winding, map axes, cell origin, voxel/grid resolution, interpolation and body inflation once. Trace source geometry → imported geometry → floor/support evidence → obstacle volume → navmesh → connector → full swept body. Report which stage first creates or removes each blockage/contact.
3. **Separate support, obstacles and unknown space.** A fitted floor surface is not permission to erase toys or steps. Missing mesh triangles are not free space. Retain coherent raised objects, drops and overhangs; distinguish unsupported cells from occupied cells and measure false blockage without clearing them merely to improve completion.
4. **Use exact independent collision/support checks.** Check starts and end connectors plus every continuous swept-body segment, turn and full foot-support region against the original geometry/reference where observed. Verify actual wall clearance, not only eroded grid centres or navmesh edges. Prefer clearance-centered paths, but never claim a cost function guarantees clearance without checking it.
5. **Score task outcomes with full denominators.** Report invalid starts, partial routes, requested-endpoint arrivals, distance, contacts by floor/low/body/head band, missing support and unknown exposure. Preserve 20 frozen pairs ×5 perturbations as 100 attempts; do not count rejected starts as completed movement or repeated directions as independent places.
6. **Only after these pass, integrate and test causally.** Prefix-only recorded observations, tracking loss/relocalization, deviation detection and return path need measured tests. Then wire normal app route queries to the verified geometry and deterministic guidance, with fresh hazard checks independent of LLM conversation. Physical supervised adult trials are a later gate, not evidence supplied by these offline results.

The main app's automatic room reconstruction, hierarchical map selection, current pose/orientation, full-body local collision/support, normal route-query wiring, live obstacle refresh, accessible recovery and 400 end-to-end journeys remain open until their own current receipts establish otherwise. No new hosted-CI or phone run is asserted in this update.

## Evidence map and interpretation rules

The accompanying N3 score checkpoint is `research/voxfield-n3-full265-scoring-20261029/COMPARISON.md`; its independent recount covers300 primary groups,600 secondary coverage groups and2,400 secondary error subsets. It uses29 original held-out views and all1,335,885 scheduled rays. Full output-freeze SHA256: `bf3aca662bad7a77041d9b75dd2fef812d0d5abe840c76057e1bdc7017bf8940`.

Other retained evidence, identified by repository or local coordination path (not a claim every file has been publicly mirrored):
- `coordination/FOUR_MAPPER_SAME_PROTOCOL_COMPARISON.md` — full Open3D A/B and Voxblox common-ray comparison.
- `coordination/voxfield-recovered-full265-same-protocol-score/COMPARISON.md` — B/C0/C1_N2 fixed comparison.
- `research/rtabmap-same-data-benchmark-20261028/fresh-run/` and `octomap-stage/ZUP_RESULTS.md` — native fixed/graph and corrected occupancy evidence.
- `research/coffee-original-pose-tsdf-comparator-20261028/` — original-pose Coffee geometry and qualified queries.
- `coordination/remaining-mapping-baselines/PLAN.md` — pins/licenses and unexecuted engine constraints; its earlier Voxblox-not-built status is superseded by completed native evidence above.
- `coordination/robotics-improvement-review-20261029/IMPLEMENTATION_TRANSFER_AUDIT.md` and `coordination/accuracy-methods-review-20261029/README.md` — researched transfers, not execution claims.
- Native Apple receipts and the prior full audit retain exact fixtures, failures and CI cutoffs. No generic “all tests passed” statement replaces them.

No private dataset, raw photo, source frame, PLY or array cache is included. This update is not permission to mirror restricted data, enlarge resources or call a score a safety percentage.
