# Full-footprint source-support oracle: bounded next-code plan

2026-10-29; source review only. Checkout observed: `006a698dc7f1eabc4122369bd73fc5562fae0429`. No implementation, install, build, test execution, spending, push, or physical-motion authority. This plan does not replace the existing contact evaluator.

## Decision

**Reuse CGAL Nef Boolean operations for a tiny offline reference oracle, not as a claimed drop-in human-navigation solver.** The essential predicate is complete demand-set inclusion in height-qualified source support; checking contact, endpoints, centerline, or sampled perimeter points cannot establish it. Exactness is relative to frozen input coordinates and a declared support policy, not sensor truth.

There are two separate blockers:

1. A source triangle union can preserve holes that exist in that source, but cannot discover a hole missing from the source representation.
2. Nef sets are polyhedral. They cannot represent the current circular cylinder footprint exactly. A polygon experiment is not an exact replacement for that cylinder. An explicitly approved proven outer enclosure can supply a **sufficient** disk-support certificate; its failure is inconclusive for the disk. No automatic extra radius, altered profile, or polygon substitution is authorized here. A complete exact circular-footprint/ramp decision procedure remains an upstream gap, not a solved feature.

## Verified existing source limitations

`ios/BlindAssist/SavedRoomRouteMeshAdapter.swift`:

- `Feature.polygonCorners` (line 19) is one array of corners, not an outer ring plus inner rings.
- `originalFeatures` requires `room.floors.count == 1` (line 571).
- `tessellateHistoricalFloor` (410–447) validates a single simple planar ring and passes flattened XY coordinates to `HistoricalPolygonTriangulation.indices(xy:)`; no hole-ring argument is provided.
- Historical support is made from those tessellated semantic floor polygons (389–398), not raw exported floor slab surfaces. Its source cannot encode an interior hole via this adapter contract. This is a limitation of **this code path**, not a claim that every Apple API or every real room lacks holes.
- Snapshot explicitly sets `actualWorldCoverageKnown` and `physicalAuthority` false.

`ios/BlindAssistTests/SavedRoomRouteCollisionOracle.swift:192–213` sweeps `SCNCylinder`, checks initial/terminal overlap, and separates category queries. Its comment explicitly denies that floor contact proves whole-footprint support; mixed-scene evidence also sets `fullFootprintSupportVerified = false` (line 445). Preserve those distinctions.

## Smallest exact polygon-domain experiment

Use one closed rational convex footprint P, one linear center trajectory c(t), t in [0,1], and original source triangles with provenance. Evaluate **each** route leg and actual-start/goal-association connector, including stationary legs. No connector is silently projected or skipped.

A particularly small Nef-only formulation uses coordinates (x,z,t), not physical XYZ:

- Demand D: `0 <= t <= 1` and `(x-c_x(t), z-c_z(t)) in P`.
- Each admitted source floor triangle i has its unchanged projected triangular domain T_i and affine height h_i(x,z). Reject vertical/degenerate projections or unsupported source classification.
- Freeze an affine support-reference height g(x,z,t) and allowed vertical mismatch interval [-down,+up]. For each triangle form Q_i from `t in [0,1]`, `(x,z) in T_i`, and `-down <= h_i(x,z)-g(x,z,t) <= up`.
- Let S be the union of Q_i from only the eligible source layer/component. Compute `R = D.difference(S)` and accept **modeled support under this policy** iff `R.is_empty()`.

All these constraints are affine halfspaces, so CGAL owns intersection/union/difference and exact emptiness. Use an extended exact kernel for direct halfspace construction (e.g. documented Extended_homogeneous with exact integer coefficients after clearing rational denominators); the ordinary EPECK halfspace constructor is not a valid shortcut for unbounded intermediates. This is proposed, unbuilt domain glue around upstream set operations—not an upstream-tested support solver. Exact Float32/64 binary rationals must be preserved; do not round decimal exports or add geometric epsilon.

**Why (x,z,t):** each footprint location is checked against the floor height at the same trajectory parameter. This avoids a spatial-union implementation accidentally borrowing support from another time or layer. Nef preserves lower-dimensional residuals; never regularize R or test only residual volume/area.

**Ramp semantics must be fixed before code:** `g=c_y(t)` demands coverage within a band around a horizontal reference. Zero tolerance will reject a nonzero-width footprint on a ramp, correctly for that definition. A fixed ramp-following affine g can express a different declared geometric coverage policy without flattening the source. A plane-changing transition needs separately frozen pieces and endpoint checks; arbitrary rotation/nonlinear gait is outside this slice. Vertical bands, slope eligibility, connected-layer provenance and step/connector limits must not be invented to obtain a pass. Coverage is not load-bearing capacity, foot placement, balance, gait, or permission to traverse a height discontinuity. A union of surfaces alone does not prove traversability.

## Why retain the glide finding, but do not require it first

Official CGAL 6.1.1 documentation includes `Minkowski_sum_3/glide.cpp`, constructing a polyline Nef with `Polylines_tag` and sweeping fixed geometry using `minkowski_sum_3`. It is a reusable translation-sweep reference, not a rotating/articulated human solver. Its documented restrictions require bounded input and convex, hole-free lower-dimensional facets; nonconvex lower-dimensional facets/holes are ignored. Do not feed a holed floor surface to that operation. It can modify nonconvex inputs, so retain/copy audited inputs. The Nef-only halfspace construction above avoids adding Minkowski decomposition to the first experiment.

## Frozen next implementation/test slice (not executed)

1. Isolated research executable only; no app caller, routing activation, source-floor repair, Apple profile changes, or widening acceptance thresholds. Pin CGAL v6.1.1 source and dependency/license manifest before any authorized build. Review license/distribution and resource plan before adopting into the app.
2. Fixture manifest: source digest, exact coordinates, triangle IDs/classification, layer/component, P, all segment/connector endpoints, g, vertical bounds, boundary-inclusion policy, expected result and reason. Start with <=32 triangles, <=4 legs, <=16 footprint sides. These are input caps, not proofs of bounded CGAL allocation; hard process memory/time caps need separate authorization and enforcement. Exceeding any limit is `unknown`, never `supported`.
3. Planned controls: full rectangle pass; interior hole under footprint but away from centerline; narrow slit between endpoint samples; outer edge overhang; supported endpoints with unsupported mid-leg; unsupported initial/terminal connector; stationary footprint over hole; exact seam and boundary contact with explicit inclusion marks; removed line/point residual (must not vanish by regularization); overlapping floor layers at wrong height; mismatched layer provenance; ramp both directions; ramp-to-flat transition; height discontinuity; malformed/nonfinite/degenerate geometry and exhausted budget.
4. Representation control: same synthetic hole retained in triangle input versus absent from a single outer-ring semantic input. The latter must be reported as **source coverage unknown**, even if modeled inclusion passes. Do not claim the oracle detected what the input omitted.
5. Disk limitation control: any approved outer polygon reports its enclosure proof separately; an outer-only unsupported corner returns disk `unknown`, never disk failure. Keep the unchanged cylinder collision result alongside support, not merged into one safety flag.
6. Receipt separates `modeledSupport: supported/unsupported/unknown`, `sourceCoverage: unknown/qualified`, contact result, resource status and `physicalAuthority: false`. Reproducible nonempty residual/fixture ID is diagnostic evidence; no room geometry in public logs. Stop the first code slice at these fixture results and an independent source review; do not advance a journey actor on missing coverage.

## Primary sources verified in this review

- [CGAL v6.1.1 Nef header](https://raw.githubusercontent.com/CGAL/cgal/v6.1.1/Nef_3/include/CGAL/Nef_polyhedron_3.h): SPDX `GPL-3.0-or-later OR LicenseRef-Commercial`; `difference` lines 1414–1427 calls the Boolean DIFF operation without regularization.
- [Nef 6.1 manual](https://doc.cgal.org/6.1/Nef_3/index.html): exact point-set semantics, extended kernels for unbounded halfspaces, and explicit regularization as a separate operation. [API](https://doc.cgal.org/6.1/Nef_3/classCGAL_1_1Nef__polyhedron__3.html): halfspace/polygon/polyline constructors, subset predicates, difference and emptiness.
- [Minkowski 6.1.1 manual](https://doc.cgal.org/6.1.1/Minkowski_sum_3/index.html): restrictions, mutation warning and embedded glide example. [Official package license listing](https://doc.cgal.org/6.1/Manual/packages.html): Minkowski is GPL and depends on Nef/convex decomposition. [CGAL license overview](https://www.cgal.org/license.html) and [v6.1.1 GPL text](https://raw.githubusercontent.com/CGAL/cgal/v6.1.1/Installation/LICENSE.GPL). No commercial purchase or app-license conclusion is made here.
- [Official 6.1.1 release announcement](https://www.cgal.org/2026/01/26/cgal611/). This is the researched pin, not a claim it is the newest release.

Access limits: raw v6.1.1 Minkowski header and standalone glide example requests returned web cache misses; embedded official 6.1.1 manual code was readable. Therefore the Nef header license is checked at the source tag, while the Minkowski license is checked at the official package listing, not that unavailable header. No shell network escalation was attempted. No upstream tests or integration builds were run; no denial was bypassed.
