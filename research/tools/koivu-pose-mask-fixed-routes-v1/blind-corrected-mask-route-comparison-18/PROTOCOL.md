# Paired fixed-objective route comparison

## Question and evidence boundary

Does the supplied nine-pose floor-corrected Koivu split-0.7 mask change the
outcome of the **same already requested objectives**? This is a known-provided,
unvalidated phone-derived model comparison. It is not live sensing, physical
clearance, a new reconstruction or a movement episode. No reference arrays or
geometry may enter the model/selector. The supplied NPZ metadata archive also
contains evaluator fields: the adapter must read only `R`, `t`, `lo`, `res`.

## Fixed comparisons

Run profiles in the original order:

1. 0.45 × 0.30 × 1.60 m body, zero added margin.
2. Same body, 0.05 m horizontal margin (0.55 × 0.40 m envelope).
3. Abstract 0.28 × 0.30 × 1.60 m body, zero margin.

Reuse the pinned native025 Recast/Detour library and the unchanged 2.5 cm
planner raster, 250,000-cell cap, proposal radii 0.225 / 0.275 / 0.15 m, and
sampled rectangle/turn policy. This phase does not repeat the old third-profile
0.125 m fallback or perform a new size/threshold sweep. Original 5 cm sensor-map
detail is unchanged; the planner raster creates no new sensor detail.

For each profile, compare old versus corrected maps at:

- The four original loop waypoint legs from its preserved width-variant result,
  in the original order, including the closing leg. No replacement compass
  point or target component is selected.
- Both original raw north/south camera-derived approach start and goal requests
  from the preserved two-approach artifact. These were controlled body-goal
  positions at original model Y=0, not measured camera/body extrinsics. No
  nearest-free-centre search or new anchor relocation is allowed in this phase.

Keep every failure, partial route, Detour status, native endpoint projection,
sampled rectangle/turn rejection and unresolved flag. Native association keeps
the existing horizontal bound; vertical differences are explicitly reported.
No actor is projected or snapped to the query endpoint.

## Common physical-coordinate association

Carry every original objective in full 3D through:

`old game → old level → original phone coordinates → new level → new game`.

The game/level conversion is the original proper rotation
`level = [gameX, -gameZ, gameY]`. Use the exact saved `R` and `t` on each side.
Keep transformed Y values, round-trip residuals and endpoint projection
differences; do not silently set the new request Y to zero. Original camera
positions, not their corrected exports, define the paired physical objective.

The central anchor/proxy is the original phone-derived target, not a semantically
verified table and not a new component selected from corrected/reference data.
If all fixed legs pass, check closure and winding around the same transformed
anchor before calling this construction a loop. Out-and-back is not a lap.

## Bounds and controls

Source and transform fixtures precede the single frozen batch. Maximum 36
fixed native queries (3 profiles × 2 maps × 6 objectives), with no additional
candidate retries. Use one serial process, 120 CPU / 180 wall seconds, 1 GiB
sampled or waited RSS, 16 MiB outputs, and preserve 768 MiB free disk. All
source, input, objective and native-library identities are checked before/after.
Old sources and arrays are never overwritten. No new dependency or build.

## Interpretation

A failure is a failure of these fixed objectives and proposal/fit rules in this
candidate map, **not proof that no table loop exists**. Compass-extreme goals
around an irregular old component can be needlessly restrictive. A separately
versioned flexible aisle-region search may follow, around the same anchor,
with multiple candidates and clearance-first ranking; it cannot be silently
substituted into this comparison. Successful candidates still require independent
swept-body/support scoring before any movement success claim or three-lap run.
