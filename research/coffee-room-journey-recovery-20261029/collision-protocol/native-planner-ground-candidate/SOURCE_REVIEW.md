# Native planner eligibility comparator — SOURCE ONLY, not run

Explicit candidate mode: `recast-signed15-exact-xyz-v1`.
Triangle policy: `published-rcMarkWalkableTriangles-fixed15-initial-eligibility-v1`.

This is a **model-policy consistency experiment**, not an adopted relaxation, semantic-floor classifier or physical-support proof. Original original-ID 5° and exact-XYZ 5° source/results remain unchanged. Root alone owns publication and separate build/control/comparison admission.

## Why this comparator, not tuned 6°/6.7°

Pinned actual Coffee planner configuration is 15°. Published Recast uses signed normalized source Y **strictly greater** than `cosf(15/180*RC_PI)`, on float32 original vertices and winding. Saved blocker faces 27586, 28034 and 28076 are upward-facing at about 5.7154°, 6.6244° and 5.4088°: the custom absolute 5° component gate rejects them, while the planner's initial eligibility criterion admits them. This proposal calls the published native function rather than reimplementing its normal arithmetic in Python or choosing an angle to fit observed failures. See the exact-XYZ attempt's `SLOPE_POLICY_REVIEW.md` and evidence.

## Tiny native boundary

`native_planner_ground.cpp` wraps the existing published `rcMarkWalkableTriangles` at the fixed 15° value. The C ABI accepts original float32 vertices, original triangle indices and an output eligibility byte array; it does not alter source geometry or triangle order. No angle knob or Python substitute normal algorithm is exposed. See `WRAPPER_SOURCE_REVIEW.md` for the read-only symbol/link closure and source provenance.

`NativeTriangleEligibility` in `native_planner_ground.py` does not load a library at module import. Its explicit constructor requires a regular compiled library file and exact SHA256, verifies ABI version/fixed angle, then binds the C function. Classification validates original finite float64 point arrays and indices, converts to contiguous float32/int32 exactly as the planner input path does, and requires a boolean output mask. The float32 input copy does not rewrite original mesh coordinates. The future aggregate guard must bind the compiled wrapper hash **and the existing linked planner binary/dependencies**, including checking the produced wrapper before/after controls and comparison.

## Reused component/owner implementation

`NativePlannerGroundSupport` adapts the original pinned GroundSupport implementation without changing that source:

- Replace its Python absolute-normal 5° eligibility line with the native eligibility mask. Its copied adjacency/component selection, all-nine seeds and immutable original face-ID result remain the original implementation.
- Exact original float64 XYZ keys supply shared-edge adjacency, as in the separately reviewed exact-XYZ candidate. No tolerance, hole filling, point-only join, vertex mutation or face renumbering occurs.
- Retain the same fixed route patch and whole-triangle height-band test. Copied `from_scorer` still computes its legacy normal array for its existing shape contract; those values **do not gate the native mode**. Native classification uses original source-frame float32 coordinates/winding, not absolute transformed normals.
- Retain reference-owner, transform and mesh-revision binding; raw body/margin intersection code remains unchanged.
- Receipts explicitly identify native initial eligibility, signed winding, float32 conversion and maximum angle 15°. They explicitly deny final-walkability/semantic-floor authority.

`support_functions_native.py` copies the exact existing extracted functions and changes **only the diagnostic supportPolicy label** to name native signed 15 initial eligibility. Numerical nine-probe, 20 mm spread/height, two-half-segment 3D cap and rejection behavior are unchanged. This avoids the contradictory old `<=5 degree` text in a native 15 result. The original extracted helper remains untouched.

## Worker identity and raw evidence

`run_comparison_native_ground.py` is an isolated copy of the exact-XYZ worker with explicit native-classifier library/hash arguments, the native-class import and new helper import. It requires the new named mode and candidate manifest. Schema3 receipt records policy, wrapper hash/ABI, mode and candidate source pins; each compressed contact row carries the mode and policy. A remains raw identity/unknown ground. B still verifies raw body/margin counts equal A for every event; C changes only labelled support eligibility while retaining the already frozen XZ/yaw/vertical-follow rules. Raw counts and first witnesses remain recorded even if a contact becomes ground-labelled.

All twenty paths / 6,874 events remain selected. Existing local box/ray/triangle/output caps are unchanged. Original mesh, current-result packet, paths, schedule, body .45×.30×1.60 m, separate .15 m horizontal margin and .002 m bottom exclusion are unchanged. A new fresh work root is required; neither prior attempt may be overwritten.

## Authored controls, NOT results

The prepared controls runner retains the existing 47 original + 10 exact-XYZ controls, then adds 10 native-policy controls: **67 prepared, not passed**. New fixtures cover fixed 15° threshold straddling at 14.99°/15.01°; negative winding rejection; all three exact original blocker triangles with original 5° rejection preserved; exact-XYZ seam/stable face IDs; epsilon gap/point-only disconnection; stacked 1 cm layers; all-nine-seed/patch requirements; input immutability/invalid-input rejection; correct native support labels; and a 1 cm vertical riser retaining non-ground/raw contact plus owner retirement. Exact 15° floating-point boundary equality is governed by the published strict predicate, not an invented Python expected normal.

A finite 15° eligibility mask does not automatically connect stacked floors. Separate elevations have different exact edge keys; vertical risers fail native eligibility. Coincident separate sheets can still be ambiguous: no semantic separation is claimed. Negative winding is now deliberately ineligible rather than silently flipped; the signed-winding fixture guards that difference from the historical absolute-normal policy.

Five Python files AST-parse and static global-name checks find no unresolved references. The support helper AST was verified identical to the original after normalizing only the policy-label string. All three blocker fixture coordinates, original face/vertex IDs and winding were checked exactly against the hash-verified original OBJ. No source module, NumPy/SciPy/VTK, compiled wrapper or planner binary was loaded/called; no build or test ran during authoring. Source hashes/fixture provenance are frozen separately from any future binary/result.

## Required admission and limitations

Root must independently review/publish these sources, then prepare a separate aggregate manifest/guard with compile → all controls → comparison under the unchanged **120 aggregate CPU / 180 wall / 1 GiB observed RSS / 64 MiB output / one CPU** bounds. Compilation/linking, native imports, controls, eligibility, ground setup, comparison and final evidence all count. Full exact-XYZ 5° attempt used 118.97 CPU seconds: the new workload can legitimately exhaust the same budget; no cap increase, hidden retry or shortened path is authorized here.

Initial Recast marking is not final planner walkability. Rasterization, ledge/height filtering, erosion, regions/polygons and query checks follow elsewhere. Reusing its initial eligibility only tests a specific policy discrepancy. It cannot prove full-footprint support, distinguish every coincident sheet, recover omitted tabletops or validate actual navigation. The known mesh holes/tabletop omission and user's visually rejected table-corner route remain independent constraints. Neither a label change nor no-hit establishes a successful journey, 90% accuracy, safe guidance or an impassable room.
