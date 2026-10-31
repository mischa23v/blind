# One actual joint-centered Coffee 0→8 route — SOURCE ONLY

This packet does **not** rerun the previous twenty paths. It selects exactly `paths[start=0,goal=8].manualRepair.clearanceGrid.requestedConnectorChainXYZ` from `coffee-clearance-comparison-attempt-003/comparison/PROPOSALS.json`, SHA256 `7209ec5bd3f3f1e89ac7ecfba7ddb4c9b4551cbc183e7bb59238d1fd0d2e219e`.

144 points / **143 full XYZ segments**, including requested→native and native→requested connectors, remain unchanged. 142 native points have their original Y. Complete connector-chain 3D length is 7.540722257831744 m; the proposal's inner native-path length is 7.502607485320768 m. No vertex deletion, smoothing, shortcut, flattening, endpoint replacement or manual-window collision engine is added.

## Frozen authored replay

The existing stop/turn/translate convention remains: +X forward, positive yaw toward +Z; initial yaw is the first nonzero horizontal leg including the tiny first connector; pure vertical legs retain yaw; shortest turn with +π tie; ≤25 mm translation and ≤1° yaw. Heading is an authored replay condition, never measured body heading. The source-only freeze has **1,644 events: initial1, translation377, turn1,265, terminal1**. The six unchanged standard-library scheduling/reporting controls passed during compact-checkpoint review; the guard must rerun them at admission. This is separate from the still-unrun native route.

## Compact deterministic checkpoint

`SCHEDULE_0_8.json` is a derived artifact, not a required Git blob or publication file. Its **655,653 exact bytes** and SHA256 **`19bc3032e46b7218e62c1481d54be9a978c3233cbf19c19d1400ba4234d44d40`** remain pinned in both route/run manifests. `ROUTE_FREEZE.json` and the unchanged `schedule_source.py` remain committed source inputs.

Before creating the attempt directory or starting any source/native controls, the guard verifies the admitted commit and every repository source pin, then regenerates the original canonical JSON directly from the verified **committed** scheduler/freeze bytes. It requires the original event count, byte count and SHA256, and an exact byte-for-byte match to any existing schedule. If the artifact is absent it creates it exclusively; a conflicting, symlink or nonregular file is refused, never overwritten. Only this exact schedule path is exempt from Git-blob lookup. All 75 input pins, worker manifest checks and final rehash remain; derivation time counts against the unchanged aggregate budget. The receipt records the committed derivation sources, original schedule hash and whether it was materialized. This is a transport/storage change, not event reduction or route/collision acceptance.

## Reused 3D path and interpretation

`run_comparison_joint_route.py` is an isolated minimal adaptation of the pinned native-ground comparison worker. It imports the same VTK all-hit oriented body/margin scorer, exact-XYZ native signed15 eligibility and nine-probe support/vertical-follow functions unchanged. There is no fourth physics engine. Original native candidate/source manifests are checked in addition to the new route manifest and exact proposal hash. Original workers and all earlier evidence remain unchanged.

- **A:** raw source-frame body/margin contacts for every event of the exact XYZ/Y/connector/yaw schedule, even after contact; diagnostic scan, not travel.
- **B:** same original trajectory translated only by the existing frame transform, geometric labels only, with per-event raw-count equality to A. All nine initial support seeds and existing fixed route patch still required. If initial support/component cannot be established, retain A and explicitly refuse B/C; do not invent a floor.
- **C:** separately labelled existing vertical-follow trajectory. It preserves XZ/yaw but can adjust Y according to the unchanged nine-probe rule and 25 mm two-half-segment 3D cap. It does **not** preserve the original vertical connector trajectory or erase A/B contacts. Initial pose/support refusal is explicitly distinguished from a later proposed-increment contact/support rejection.

New receipt-only counters report attempted events, accepted modeled translation increments, accepted translation-only modeled 3D/XZ distance and refusal phase. Turn-associated Y excursions are recorded separately as acceptedTurnVerticalAdjustmentMetres and never count toward route progress. The small standard-library reporting helper has no geometry/state mutation or collision/support authority. A failed proposed sweep does not advance the accepted state/distance. Initial height correction is logged separately and is not route travel. `physicalTravelObserved=false`, `movementEpisode=false` and `arrivalClaimed=false` remain; completed source evaluation is not actual bodily travel. Original raw contact witnesses/counts and failed proposals remain in compressed evidence.

## Separate serial admission, unchanged resources

Root alone may execute after independent source/guard review and after the existing native job is retired. Native controls already passed67 in the earlier job, but that twenty-path aggregate exceeded120 CPU seconds and remains incomplete; it is not a successful full-route result. This separate one-pair admission repeats the same67 native controls and6 source-only scheduling/reporting controls, compiles the same tiny wrapper to a fresh owned output and applies the same pre-load ELF/dependency/hash checks. No old failure is overwritten or repeated to improve its score.

Fresh root: `coffee-joint-route-body-attempt-001`. Limits unchanged: **120 aggregate CPU / 180 wall seconds / 1 GiB observed RSS / 64 MiB output / one CPU**, counting source contracts, build, ELF checks, native controls, all A/B/C work and final evidence. Same worker query caps. No automatic retry, schedule reduction or cap increase. Worst-case A/B/C contact work scales to 13,152 body/margin box calls before any early C refusal, within the inherited55,000 box cap; time/rays/triangle count remain unmeasured, not guaranteed within budget.

After publication/review of the exact packet, from `blind`:

```sh
/opt/codex/runtimes/codex-primary-runtime/dependencies/python/bin/python3.12 -B \
  research/coffee-room-journey-recovery-20261029/collision-protocol/joint-route-body-candidate/run_aggregate_joint_route.py \
  --admitted-source-commit EXACT_REVIEWED_PUBLISHED_COMMIT
```

The native eligibility is initial Recast marking, not final walkability or semantic floor. Full-footprint support and missing-space coverage remain unknown. The two manual windows/circumscribed-circle checks are approximate diagnostic exclusions, not measured complete tabletops and not substitutes for this 3D check. Neither that2D result nor a same-incomplete-mesh3D no-hit proves clearance around the actual table, successful walking or physical safety.
