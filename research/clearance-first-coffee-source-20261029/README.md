# Clearance-first Coffee comparator — SOURCE ONLY, 2026-10-29

User priority: use a reasonable longer route to stay away from surrounding objects, not a shortest line hugging corners. This is an isolated candidate comparator, **not app integration or physical-clearance approval**. No Coffee/native import, build, install, or push occurred. After explicit test authorization, 26 bounded pure-SciPy controls passed; see CONTROL_RESULT.json. These exercise graph ranking and fail-closed Boolean adapters, not source-mesh collision/support.

## Existing evidence first

Frozen current Coffee mesh SHA256 `f10de085426143ad095fefc713b4966d22fdf08beda9ff9ead759019a0a8306a`; 51,965 vertices / 87,370 triangles. Current result SHA256 `4d8ed568da8497e1e39e14b08918616107e54192676389bcee3b1c5dec7c5558`. Canonical 20 paths SHA256 `52d100633b60e1d9063d3e7dcfb27d37473d5953026a89c2c30e53a6adb965a2`.

- 20 native proposals, 2.162–6.190 m long. This count is not 20 safe body routes.
- Retained endpoint residual **navmesh-wall** distances: 0: .233121 m; 1: .524139 m; 6: 0 m; 7: 0 m; 8: .121720 m. The native wall is an eroded navmesh boundary, not a measured object surface or rectangular-body clearance.
- Endpoint 6 horizontal association .092645 m and endpoint 7 .014113 m remain within original .10 m policy; their zero wall distances still require the same hard connector/body tests. No endpoint movement or policy widening is proposed.
- Recorded ground-follow body comparison: 12/20 ground classification unavailable; 8/20 stopped on non-ground candidate contact. No accepted complete full-body route was established. Its nine support rays are not full-footprint support.
- Full interior route clearance was not saved by the original run. Do not invent numerical current-vs-centered clearance gains before a newly admitted diagnostic.
- The actual tabletop missing from the mesh remains an independent visual rejection. No mesh-only no-hit result may override it.

## Reuse inspection and precise scope

Existing `blind-clearance-centered-loop-55/planner.py` already supplies a 5 cm native-grid sampler, bidirectional Detour segment checks, .15 m endpoint graph connections, .10 m requested-to-projected association limit, and inverse-clearance weighting. Its custom heap Dijkstra is **not used**. Existing `blind-tabletop-exclusion-planner-66/native_exclusion.py` is imported with `exclusion=False`, retaining all triangles and zero excluded spans; stage55 `build_graph` is reused unchanged. Default Recast radius .225 m / native height 1.75 m are retained as proposal settings, not substituted for the actual body .45 × .30 × 1.60 m plus separate .15 m horizontal margin.

`selector.py` delegates directed positive-weight CSR graph search to released installed **SciPy 1.17.0** `scipy.sparse.csgraph.dijkstra`. BSD-3-Clause; no vendored solver change. Existing `collision-protocol/BODY_RUN_PINS.json` records installed SciPy distribution metadata/RECORD hashes; not complete shared-library attestation. [Official 1.17.0 API](https://docs.scipy.org/doc/scipy-1.17.0/reference/generated/scipy.sparse.csgraph.dijkstra.html) documents nonnegative edges and returned predecessor reconstruction. Multiple tied paths may vary by runtime; pin the actual environment and preserve outputs. No upstream tests were executed for this preparation.

Recast/Detour source remains pinned to existing `9f4ce64458dfae86e1239c525ddc219c4e9e06f1` (existing source receipt; zlib license). [Official Detour API](https://recastnav.com/classdtNavMeshQuery.html) distinguishes polygon path, straight/funnel path, wall-distance query and walkability raycast. These do not certify swept rectangular-body support or missing obstacles. Changing polygon cost alone would not prevent straight-path corner hugging inside a corridor.

Existing Maurer/EDT work was inspected: it qualifies squared-distance threshold masks on a flat single layer, not route centering or full-body clearance. Its local adaptation derives from an ITK development pin, not a released navigation planner. No Voronoi navigation graph was found in the recovered Coffee code; its `Voronoi` references concern distance-transform envelope construction. Neither is silently relabeled an available human route planner.

## Bounded objective and limitations

1. Compare original funnel path, shortest native-grid path, and clearance-ranked native-grid path, all with exact frozen requested start/goal and connector geometry.
2. Find shortest grid length; provisional research detour ceiling is `1.5 × shortest_grid_length + .5 m`. This is a declared comparator setting, **not a user-approved production preference or proof of optimal resource-constrained routing**.
3. Raise the interior residual-clearance tier in .025 m increments up to 1.50 m while a shortest route remains within the ceiling. Discrete tier optimum only. Endpoint-incident connectors are exempt from this *ranking threshold*, never from hard validation. Their clearance is still reported.
4. Within the highest retained tier, use stage55 inverse-clearance exposure cost to keep centering even when unavoidable minima pin the tier. If weighted path exceeds the ceiling, fall back to the shortest path at that tier. This is a bounded heuristic comparator, not exact lexicographic optimization over every feasible bounded-length route.
5. No funnel/string-pull smoothing afterward. Smooth turns are not optimized in this first slice; all emitted corners require unchanged continuous body/margin turn checks before acceptance. No potential-field/local steering solver exists here; graph search establishes goal connectivity.
6. Edge residual proxy subtracts half edge length from the minimum endpoint wall distance. This is deliberately **not certified continuous clearance** across filtered/layered native geometry. Candidate geometry must be independently checked, including every requested connector, translations and turns, full height and complete footprint support.
7. `acceptance` is only a fail-closed interface fixture; no hard-validator adapter or live authority is wired. Unknown body/support/coverage/depth status cannot pass. Actual full-footprint oracle remains unavailable (`full-footprint-support-plan-20261029`); therefore this slice cannot output an accepted safe Coffee route.

## Prepared controls and next admission

`fixtures.py` now passes 26 controls: genuine interior clearance tier, detour ceiling, zero endpoint with centered interior, U-shaped graph, disconnected/no invented diagonal edge, coincident anchor, removal of other-anchor shortcuts, every Boolean hard gate false/unknown, malformed policy/indices/duplicates and disconnected/empty-candidate veto. Final recorded run: .290 s wall, 48,664 KiB peak RSS, under 10 CPU seconds / 20 wall seconds / 512 MiB address-space cap. Initial runpy invocation failed module lookup from the wrong working directory before importing the selector; corrected explicitly, not hidden. These are graph/control tests, **not actual geometric ceiling/table/turn/support tests**. Independent review found seven issues; sampling now uses global-arclength intervals, all grid arms export coordinates, empty candidates cannot pass, interior/zero-edge controls were added, graph arguments validated, and import/binary pins added. Re-review pending.

`SOURCE_PINS.json` freezes 24 source/data/runtime inputs, including existing rebuilt Coffee002 binary `a0b6c3d84d20b1396a3239918abfafcc1d6fa613c5c390847cba92502a634c4a`. `run_aggregate.py` adapts the existing Coffee collision guard without any compile command. Root must review, publish exact source and admit the matching HEAD. Worker checks pins before importing NumPy/native code, preserves exact endpoint projections and pairs, then emits all three route arms plus uniformly sampled wall-distance diagnostics. No body/support acceptance is claimed.

Runnable entry points after root review/admission only (`WORKSPACE` is the executor workspace root, `PROTOCOL` is this source directory; the manifest uses equivalent `@WORKSPACE@`/`@PROTOCOL@` expansion):

```
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 python fixtures.py
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 python prepare_coffee.py \
  --replay-root "$WORKSPACE/coffee-native-replay-prepared-002" \
  --canonical-paths "$PROTOCOL/../coffee-room-journey-recovery-20261029/collision-protocol/CURRENT_PATHS_20.json" \
  --out <fresh-owned-output> --pins-sha256 <frozen-manifest-sha256>
```

Do not execute these commands yet. Prepared outer envelope: one CPU, 120 CPU seconds / 180 wall seconds, 1 GiB observed aggregate RSS, 16 MiB output, fresh output, all imported source/native dependency hashes frozen before and checked after. The prepared guard and manifest need independent/root review before admission. After publication only: `python run_aggregate.py --admitted-source-commit <exact HEAD>`; it cannot compile/install and refuses existing output. Graph cap 100,010 nodes / 900,000 directed edges; there are at most 62 single-source solves per query ×20, with no all-pairs predecessor allocation. Existing stage55 sampling up to 100k positions may itself exceed practical time; stop as incomplete under guard, never loosen limits silently.

Next useful evidence is an admitted **candidate-only** baseline/clearance measurement, followed by unchanged modeled body/turn veto. Missing footprint/coverage evidence remains blocked; raw depth retention is separate. No build or active app change is needed to prepare this slice.

## Final guarded source extension

Current manifest freezes **29 inputs**, including independent `proposal_windows.py`, its GEOS adapter, predeclared manual-window JSON, and installed GEOS 3.13.1 library bytes. For pair 0→8 only, each of the three route arms receives the same independent manual-window distance/contact diagnostic, including requested connector chains. These manually defined windows are **not measured table outlines** and never grant clearance. No obstacle is removed or added to native Coffee geometry; this is a separate rejection diagnostic, not a hidden planner retune.

The guard sets a fresh owned `PYTHONPYCACHEPREFIX` in addition to disabling bytecode writes; pinned source cannot be silently replaced by an existing local `.pyc`. Original seven independent-review findings were fixed and reviewed; final manual-window/fresh-cache additions receive a narrow re-review before root admission. Source freeze initially referenced an absent GEOS 3.11.1 pathname, failed before writing the manifest, then corrected to the inspected installed 3.13.1 path; no library import occurred in that failed freeze.
