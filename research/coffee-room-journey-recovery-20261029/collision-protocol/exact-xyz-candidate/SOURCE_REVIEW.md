# Exact-XYZ ground adjacency candidate — author self-review, NOT RUN

Mode identity: `exact-xyz-shared-edge-v1`. This is a separately named candidate, not a correction to historical receipts or a new default. Independent review, committed source binding and root's separate aggregate-run admission remain required.

## Motivation and scope

The saved-output topology diagnosis reproduced all twenty original ground-availability states and exactly all eight original accepted ground-ID sets. Eight start-1/start-7 failures become nine-seed connected under exact-coordinate edge equivalence; four start-0 failures remain because seed face 27586 has slope 5.7154°, exceeding the unchanged 5° gate. See `../attempt001-review/TOPOLOGY_REVIEW.md`.

This candidate changes **only adjacency keys**, from original vertex indices to equality of all three original float64 XYZ coordinates. `np.unique(..., axis=0, return_inverse=True)` supplies exact key IDs. Mesh coordinates, faces, VTK locator, original triangle IDs, transforms, normals, slope threshold, patch, support rays, all-nine-seed rule, body and margin are unchanged. No epsilon, snapping, geometry welding, added triangle, point-only join, low-height exemption or floor inference is introduced.

`exact_xyz_ground_support.py` subclasses the unchanged imported `GroundSupport`:

- `from_candidates` maps original triangle vertices to exact-coordinate keys and delegates all slope/patch/nine-seed/component selection to **the original `GroundSupport.from_candidates`**. Returned IDs remain original face IDs, not canonical vertex IDs.
- `from_scorer` is copied verbatim from the pinned upstream method except its one call-site addition `vertex_coordinates=points`. This exact one-line delta was checked via AST-extracted source text. Ownership, immutable ID arrays, transform binding, mesh revision checks and original candidate cap remain inherited.
- Candidate receipts explicitly say no mesh coordinate changes/welding, stable original face IDs, exact adjacency mode and inability to disambiguate coincident separate sheets.

Original `ground_support.py`, original worker/controls, SOURCE_PINS, BODY_RUN_PINS, mesh, query results, schedule and attempt001 output are unchanged. All original 32 run pins were independently rehashed after authoring.

## Isolated worker and identity

`run_comparison_exact_xyz.py` is an isolated copy of the admitted comparison worker. Its only changes are candidate/protocol path setup, candidate manifest verification, required `--ground-adjacency-mode exact-xyz-shared-edge-v1`, the explicit candidate-class import, and output identity. The new receipt has `schema: 2`, `groundAdjacencyMode`, `candidatePinsSHA256` and `originalDefaultPolicyUnmodified`. Every compressed contact row and stdout summary carries the mode. The original source manifest is still verified independently.

A remains raw/unknown-ground identity. B applies the candidate labels in translated coordinates while checking raw counts against A at every event. C uses the unchanged vertical-follow/support logic with the candidate labels. Explicit mode identity does not imply A's raw geometry changed.

No old result is overwritten or relabelled. A future aggregate manifest must select a **fresh** attempt root, e.g. `coffee-body-exact-xyz-attempt-001`, and bind both original and candidate inputs before/after to the admitted source commit.

## Prepared controls — not passing results

`run_controls_exact_xyz.py` retains the original five modules / **47 controls** unchanged and adds **10 authored candidate controls**. The historical controller remains unimported: the same pinned extracted `support_functions` module is installed as `run_ground_pilot` before tests are loaded.

New authored cases cover:

1. Exact duplicated-coordinate, UV-style seam joins in candidate only; original policy still rejects mixed seeds; no source coordinate mutation.
2. A 1e-12-separated edge remains disconnected (no tolerance).
3. Duplicate-coordinate vertex-only touch does not join.
4. Stacked layers separated by 1 cm remain separate.
5. A 1 cm riser and its top do not enter the floor component.
6. Eight seeds remain invalid and the observed 5.7154° slope remains rejected.
7. Stable original face IDs and unchanged patch filtering/read-only result.
8. Nonfinite and non-float64 coordinates rejected rather than silently rounded.
9. Existing VTK contact scorer still reports a 1 cm riser as non-ground contact under candidate binding.
10. Mesh mutation retires candidate ownership.

**57 is the prepared control count, not a passing count.** Four Python files AST-parse; no authored module, NumPy, SciPy or VTK was imported, and no control/native query was executed during authoring.

## Required next gate

Root must independently review this source, publish exact hashes, and adapt the already reviewed serial aggregate guard to select this controls runner then this worker. Controls require original SOURCE_PINS SHA256 and candidate CANDIDATE_PINS SHA256. Worker additionally requires the explicit mode, original mesh/current-result paths and a fresh owned output directory. Original manifest and candidate manifest pins must both be present in the new aggregate input list; runtime NumPy/VTK/SciPy metadata pins remain necessary. The original aggregate supervisor must not be silently repurposed or the historical BODY_RUN_PINS changed.

Retain the existing **120 aggregate CPU / 180 wall / 1 GiB observed RSS / 64 MiB output / one CPU** bounds and failure preservation. Native imports, original and new controls, ground construction, comparison and evidence all count. More available B/C paths can increase work relative to attempt001; exhaustion is incomplete/unknown, not permission to grow the cap or skip difficult paths. The full twenty frozen paths and all 6,874 schedule events remain selected, without route repair.

## Remaining limitations

Exact coincidence can join distinct coincident sheets; this adapter does not claim semantic disambiguation. The source diagnosis showed large component growth, so review new cross-index joins/non-manifold ambiguity before treating the candidate as anything beyond a diagnostic experiment. Stacked noncoincident layers are separately tested, but that fixture cannot establish the identity of coincident sheets in the real mesh.

The four slope-ineligible start-0 cases are expected to remain unavailable; this is not a reason to relax 5°. Nine probes are not complete-footprint support. Candidate labels cannot remove the known missing tabletop, override the visually rejected longest route, turn conservative overlap into a real collision claim, establish an impassable room or demonstrate 90% navigation accuracy. No app activation or physical guidance follows from these sources.

## Independent review repair

The independent reviewer identified a missing `hashlib` import used by the copied `from_scorer` receipt digest. Added that standard-library import only; the copied method and all geometry/adjacency behavior are unchanged. Refreshed candidate/publication hashes. This source repair was AST-checked, not natively executed.
