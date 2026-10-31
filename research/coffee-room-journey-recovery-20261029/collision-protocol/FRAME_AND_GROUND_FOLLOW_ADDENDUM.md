# Reviewed source option: rigid normalization and existing local ground-following

2026-10-29 follow-up to PLAN.md. Root requested examination of coordinate normalization, not stopping at unknown labels. This supersedes PLAN.md's empty-annotation-only first-stage recommendation **for the additional labelled comparison**, not its retained raw baseline. No native/VTK work executed. No new collision/support algorithm is proposed.

## Current paths now available and checked

Read-only JSON comparison establishes attempt002 current `RESULT.json` has exactly equal endpoint records and all 72 query records to the historical expected file, including accepted native point arrays. Current file SHA256: `4d8ed568da8497e1e39e14b08918616107e54192676389bcee3b1c5dec7c5558`.

`CURRENT_PATHS_20.json` is now the input freeze for collision preparation. It retains the historical freeze intact, adds this current receipt and normalization constants, and still has `yawProtocolFrozen=false`; collision admission still needs a frozen explicit motion schedule. This static JSON equality check is not VTK/native execution or a substitute for root's aggregate-run verification.

## A coordinate translation, not a geometry correction

Let `f=-1.6301633051396203` from the frozen original orientation audit. Define local coordinates `q = p - (0,f,0)` for EVERY source path point, requested endpoint and connector endpoint. A literal translation of all mesh vertices and these points would preserve distances, connectivity, slopes and all obstacles; it does not make the rippled floor flat.

**Smaller implementation with existing APIs:** keep the original mesh and original triangle IDs physically unchanged in memory. Pass the existing evaluator `model_to_reference` matrix T with unit rotation/scale and translation `(0,f,0)`. Feed local q into it. `contact_corners` maps query boxes through T back to the original mesh; `GroundSupport.from_scorer` uses inverse T to compute local patch heights/normals. This is algebraically equivalent to translating both query and geometry, avoids a second transformed mesh, and uses the adapter's existing positive-similarity/owner checks.

Freeze T, inverse, f and original source hash. Verify forward/inverse coordinate round trips and raw-contact invariance in controls, with explicit floating-point roundoff receipt; do not assert bit-exact arithmetic from a double translation. Use no rotation, fit, pointwise floor correction, source erasure or threshold growth. The identity raw baseline remains independently retained.

Now unchanged absolute support rays `[+.15,-.25]` and ground patch `[-.25,+.25]` have a meaningful **local** coordinate contract. They are not a guarantee every original Coffee support location lies in that window. Misses/out-of-window seeds remain failed coverage; never grow it after inspecting results. The offset is derived from the existing frozen global candidate floor statistic, not fit to successful collision outcomes or claimed camera alignment.

## Three separate conditions on the same 20 current accepted paths

### A. Original-frame raw source-contact baseline

Original mesh, identity transform, unchanged XYZ path/connector schedule, body .45×.30×1.60 m plus separately scored .15 m horizontal margin, original .002 m bottom exclusion. Use existing all-hit traversal with explicitly unknown/empty ground annotation. Keep raw counts and witnesses; every hit unclassified. This shows actual source-model overlap for the unchanged route geometry.

### B. Normalized-frame geometric ground annotation, no foot-height change

Same geometric path and body as A, represented through q/T. For each path, freeze its own initial yaw and initial nine raw probe results. Call existing `support_check(initialProbes)`; all nine hits, spread <=.02 m, maximum absolute height error <=.03 m about local zero are required. Only if this passes use all nine original source cell IDs in `GroundSupport.from_scorer(base, fullLocalRouteWithConnectors, seedIDs)`.

That unchanged function admits <=5° absolute-Y-normal triangles within the fixed route-XZ patch plus .8 m and local Y[-.25,+.25], shared-original-edge connected to all nine seeds. No welding, point-touch joining, component hopping or height-only admission. Bind component to original mesh owner/revision and T. Store seed IDs, component IDs/digest, slope/patch/component counts and every rejection reason. Query unchanged local path/connector positions with `GroundedReferenceContainer`.

Output each nominal/margin raw total `groundContactCount+nonGroundContactCount` AND its geometric-ground-candidate / non-ground partition. Compare raw totals with A per identical increment; investigate any discrepancy, never use changed labels to erase it. Non-ground is not automatically “confirmed furniture”; ground is not semantic proof. If seed/component construction fails, B reports failed geometric classification and uses A's retained unclassified raw result—no all-ground fallback, no new start, no scope expansion. Component membership can be local/per-path and must not become a universal room floor map.

### C. Existing connected-ground vertical-follow comparison (additional trajectory)

Reuse the published functions, not the old episode/controller:

- `source/run_pilot.py: support_check`, SHA256 of whole file `8dba7dedf09e74dda80a035c3b7d404ebafeea09e953fcb968d75a8a2396ff64`.
- `ground-follow-v2/run_ground_pilot.py: connected_support, proposed_ground_motion`, SHA256 `679851a99466803d8390b38433a165ec409d52a4df266ff7e3651855370793de`.

Both under the same c79 pinned packet recorded in PLAN.md. `run_ground_pilot.py` imports an old Koivu controller/data-loading stack through run_pilot; **do not invoke its main()/episode() or that controller** on Coffee. Minimal source-preparation glue may copy these exact three function bodies verbatim into an isolated module, record their whole-source pins plus function-body hashes, and supply existing imported math/NumPy/scorer dependencies. This is reviewed extraction, not a changed rule; avoid expanding to historical controller, FARO or Koivu assets.

Exact existing behavior:

1. After the initial nine-hit check and successful ground component, set comparison start Y to the maximum of the nine measured model heights; preserve/report its correction from requested start. XZ/yaw stay fixed.
2. For each authored increment form a midpoint; probe at midpoint yaw; require nine hits, height spread <=.02 m, each height within .02 m of previous foot Y, and every hit's original face ID in the frozen component. Set midpoint Y to maximum probe height.
3. Probe endpoint at endpoint yaw with the same rules relative to adjusted midpoint Y; set endpoint Y to maximum height. Preserve the midpoint excursion even when end height returns to the start height.
4. Compute full 3D distance of both half segments. If >.025000001 m, reject the increment. Do not increase the cap or silently subdivide a failing increment after results. Sweep both half segments with the unchanged scorer and their explicit half-yaw intervals; record full raw and annotated counts separately.
5. Missing, disconnected, too-high/low or overly dispersed support returns unavailable. Stop that C path at the failure; do not jump to the next point, re-seed, repair a missing footprint or rebase to a disconnected low object. Original A/B still evaluate their unchanged schedules.

C is a new, explicitly labelled simulation vertical trajectory, **not** the original native route or recorded bodily motion. Retain requested/native heights and every adjusted midpoint/endpoint in source coordinates after inverse conversion. It does not preserve the original connector's vertical motion; disclose that difference and preserve A/B as the exact-connector comparison. If a terminal height differs from the requested goal, report it, never claim endpoint arrival. All XZ vertices/connectors remain fixed; no shortening or replacing the route.

A local ground-follow pass is NOT full-footprint support: nine probes can miss an interior hole/low object, a large corner gap, or an intervening support defect. Maximum-of-probes can raise the modeled foot over an unobserved small obstacle. The unchanged raw A/B contacts, exact height offsets, unknown coverage and low-object controls therefore remain essential; C cannot clear an A/B obstacle warning or establish safe walking. Existing `contact_status` uses first-triangle whole-height heuristics for a near-foot label; do not reuse that as a semantic obstacle/floor classifier.

## Preparation/admission extension

Prepare all three condition manifests/schedules before any execution. Preserve nominal/margin dimensions and 2 mm exclusion in every condition. Check mixed floor + 1 cm detached top, 1 cm riser, wall/head, missed seed, disconnected seeds, smooth ripple, drop, step-limit failure and equal-raw-count frame invariance controls. Existing source tests cover many of these; they are not newly passed here. Pin any added coordinate/adaptation controls.

Use a single root-reviewed serial aggregate budget; C and B increase workload, so count/preflight the complete proposal before root admission rather than assume PLAN.md's first-stage budget covers it. A proposed <=10,000 increments is a total cap across admitted conditions, not per condition; two-half-sweep C calls must be counted. If full 20-path conditions exceed cap, report the preflight block and propose a separately frozen serial tranche—never silently omit routes. No concurrent native work or automatic retries.

Filesystem inspection also verified SciPy1.17.0's installed LICENSE.txt contains BSD-three-clause-style terms; preserve its bundled notices along with NumPy/VTK. Wrapper redistribution-license caveat from PLAN.md remains. No new native execution, dependencies, money, push or physical guidance is authorized by this addendum.
