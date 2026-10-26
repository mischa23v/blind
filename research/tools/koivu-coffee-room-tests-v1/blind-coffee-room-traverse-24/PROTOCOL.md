# Coffee fixed-map broad route availability check

Frozen before any Coffee native route result. Reuse the externally supplied b0be8628 coffee_floorfix split-0.7 mask; do not regenerate or change mapping. The original raw Coffee depth capture is absent locally. `pipeline2_out.npz` is read ONLY for lo, res, R and t; its reference arrays cannot be used by endpoint selection, native planning or rectangle validation.

## Deterministic shared endpoints

1. Use all phone `walk` cells, unmodified, 5 cm resolution. Compute padded-false EDT lower-bound clearance: EDT*0.05 - 0.05*sqrt(2)/2.
2. Shared candidate centres require at least 0.35 m lower-bound clearance. This is slightly above the half-diagonal of the largest 0.55 x 0.40 m footprint; it is an endpoint selection rule, not a sensor/occupancy threshold change or a claim of physical clearance. Do not lower it if none exist.
3. For the eight fixed grid-axis integer directions (+1,0), (+1,+1), (0,+1), (-1,+1), (-1,0), (-1,-1), (0,-1), (+1,-1), choose the candidate cell with greatest dot product of source IJ and direction; ties use greatest EDT lower bound, then lexicographic source IJ. Labels are grid directions, not geographic compass or semantic room regions. Deduplicate repeated source cells in first-direction order. Do not choose a connected component or change endpoints based on any route result.
4. Record the endpoints before native engines are built. Query every ordered pair of distinct endpoints for all three unchanged profiles. No retry or fallback endpoints. Original broad physical-room coverage is unknown; selected endpoints are broad extents of sufficiently clear supplied mask centres, not the room boundary.

Profiles are 45x30x160 cm, zero margin; same body with 5 cm horizontal margin each side (55x40 footprint); and abstract 28x30x160 cm, zero margin. Reuse pinned native025 Recast/Detour with proposal radii .225, .275, .150 m, 2.5 cm planner cells, native height1.75m and max250000cells. Preserve full original route and projection receipt. Require <=.10m horizontal native endpoint association, exact requested endpoint connectors, unchanged sampled rectangle segments and 5degree turns, plus exact segment endpoint heading tests. No body or occupancy tuning, new search algorithm or reference-guided planning.

Report all failures, accepted path lengths/displacements, low-unresolved sampled footprint exposure, raw-mask topology and selected endpoint span. Snapshot routes are not movement episodes. No FARO mesh is local for Coffee, no triangle scoring occurs, no synthetic or physical actor is advanced, no live safety validation is claimed. Height is recorded but this mask/path test is planar, not continuous swept-volume or head/foot/support proof. Existing mask still permits low-unresolved flags.

Bounds:120 CPU seconds,180 wallseconds,1GiB sampled RSS,30MiB total output,768MiB free reserve. No download or deletion. A bounded outcome is final for this endpoint policy; failures do not prove physical impossibility.
