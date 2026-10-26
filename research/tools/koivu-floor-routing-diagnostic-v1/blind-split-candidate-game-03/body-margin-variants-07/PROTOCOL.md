# Explicit body-envelope sensitivity variants

Source readiness only. Run only after the serial slot is released and the new
0.025 m native-cell-size adapter cut is approved and pinned. The previous native
library rejects cell sizes below 0.05 m; do not silently fall back to it.

Fixed order and parameters:

| Public profile | Raw width | Raw forward depth | Raw height | Margin per horizontal side | Native max-half disc |
|---|---:|---:|---:|---:|---:|
| body45cmMargin0 | 0.45 m | 0.30 m | 1.60 m | 0 | 0.225 m |
| body45cmMargin5cm | 0.45 m | 0.30 m | 1.60 m | 0.05 m | 0.275 m |
| abstract28cmProfile | 0.28 m | 0.30 m | 1.60 m | 0 | 0.15 m |

The third profile is an abstract geometry sensitivity comparison, not validated
human dimensions. All profiles retain native height 1.75 m and source mask cells
0.05 m. Proposed native raster cells are 0.025 m for all three: this adds no
sensor detail and changes only the native working discretization. Record the
actual Float32 division and `ceil(radius / cell_size)` effective erosion radius.
`nativeProposalRadius` is an explicit parameter independent of body dimensions;
the currently proposed values equal `max(width/2, depth/2) + margin`. This disc is not the complete
rectangular body; exact unchanged rectangle/turn sampling remains required.
For the abstract profile it also overstates lateral half-width, so circle-based
failure cannot establish that an orientation-aware physical body cannot fit.
The earlier 0.20 m abstract width and lateral-only 0.10 m radius were superseded
before any fixture, data query or computation in this stage; they are not runs.

Maintainer-approved conditional fallback, preregistered before any query: run the
abstract28cmProfile primary 0.15 m proposal radius first. Only if that complete
fixed construction returns no full-loop candidate, run exactly one additional
0.125 m proposal-radius case, retaining the identical 0.28×0.30×1.60 m body,
zero margin and mandatory full rectangle/turn validation. Preserve both results;
do not replace or relabel the primary. A technical exception is not a no-loop
result and does not trigger fallback. The two 0.45 m-body variants have no radius
fallback. This is a proposal-discretization sensitivity, not body shrinkage.

Use the exact supplied split mask and metadata, unchanged permissive flags,
original 4,667-cell target and fixed nearest-centroid target cell. No reference
arrays, FARO, target substitution, path forcing or new search is permitted.
Reuse isolated namespaces of the pinned original `routes_rect.py` and
`table_loop.py`: parameterize only body half-extents/RB, disc radius and native
cell size, with independent source/input validation replacing the old
single-profile validator. Do not edit or mutate old modules or artifacts.

For each profile, run the same fixed four-side construction, native Detour legs,
association, sampled exact endpoints/closure turns and consistent ±1 winding
around every original target cell. Preserve original native points and the
reviewed candidate-only 1e-6 m numerical coalescing. Also report foreground-4 /
complement-8 topology of that profile's unchanged-formula centre eligibility,
separately from native feasibility. A topology hole is not a route or clearance
proof; a failed compass construction is not proof against every possible loop.

No movement runs are performed by this stage. Only a complete fixed full-loop
candidate can be considered for a separately frozen three-lap episode. Preserve
the 0.15 m-margin results and all rejected variants. No family, age, or tester
attributes enter sources or receipts.

API: `evaluate_variant(profile_name, native_directory, native_library_sha256)`.
The supplied directory must contain the separately approved C ABI library under
`libblind_detour.so`; its byte-identical existing Python binding is loaded from
that directory in a private namespace and loads its own sibling library. The original fixed map loader
is reused unchanged, its temporary original engine is closed, and all variant
queries use only the separately pinned native library.

Result schema: `profile`, `geometry`, `candidate` (existing target/waypoints,
`nativeLegs`, `closedPath`, initial yaw, winding, flags and three-lap tick proposal),
`discCentreTopology`, `rawWalkTopologyEvidence`, and source/native pins.
This protocol does not authorize a native build or reference run by itself.

## Final pre-execution numerical details

All three profiles use the separately verified native025 library: only the minimum-cell guard changes; source map remains 5 cm. Profile28 uses a 0.15 m primary circular proposal radius (30 cm diameter, not the actual 28×30 cm rectangle). ONLY if its primary fixed construction finds no loop, one preregistered 0.125 m proposal-only fallback is attempted; actual rectangle, turn tests and target are unchanged. No such fallback is used for45/55. This does not authorize navigation from the smaller circle.

The 28 cm width is not divisible by the 2.5 cm sample spacing. Its exact +14 cm edge/corners are appended to the existing sampled rectangle lattice; divisible45/55 lattices remain unchanged. This correction is fixed before any profile query, not tuned against outcomes.
