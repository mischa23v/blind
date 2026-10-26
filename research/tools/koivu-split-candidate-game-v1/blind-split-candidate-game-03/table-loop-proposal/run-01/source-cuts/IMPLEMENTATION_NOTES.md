# Source-only loop feasibility handoff

No fixture, connectivity calculation, recorded NPZ decode, native route query,
plot or actor episode has been run for this module. Existing game sources,
ground-follow variants and frozen short-route selections are unchanged.

## API

`table_loop.propose_loop(candidate_map)` requires the existing pinned, open
`CandidateMap` instance. Failed native queries retain their existing NaN
projected endpoints internally; `proposal_json(proposal)` explicitly serializes
those missing coordinates as null, never zero, while retaining the failed status.
No CLI or automatic data loader is provided. Run only through the
separately authorized 60 CPU / 90 wall / 512 MiB RSS / 8 MiB output worker with
768 MiB reserve. The caller must verify source/input hashes again on completion
and preserve failure evidence; this pure proposal adapter does not own a
process watchdog or write any output.

Possible success status is
`phoneModelLoopFeasibleSemanticTargetUnresolved`; it is **not permission to
start a lap episode**. The semantic central-table association remains a separate
review of existing phone-derived evidence, not an LLM coordinate decision.

## Deterministic interpretation of the protocol

- Source north means positive level-Y (negative game-Z). Side half-planes start
  at the target component's cell-edge bounding rectangle. The fixed target
  midpoint is offset by `0.375 + 0.05*sqrt(2)/2` m.
- Independently choose the first fitting candidate for each side, with the
  specified distance / `(i,j)` tie-break. If those four first choices duplicate,
  reject; do not silently skip to a better alternative. Four-connected walk
  labels are an early connectivity diagnostic, not a new route search.
- All four ordered native query results are retained even if one fails. The
  passed adapter already skips the projected start once; this module does not
  skip another point. It flattens only level-map candidate geometry to Y=0,
  never an actor pose.
- Each associated projected goal is connected explicitly to the unchanged exact
  waypoint within the inherited 0.1 m association limit. These short connectors
  are not native-searched routes and are identified separately; the combined
  path, connectors, all exact endpoints and closure turn must pass the source
  sampled rectangle checks. No teleport or physical pose adjustment follows.
- The approved pre-execution numerical amendment coalesces only consecutive
  candidate vertices within 1e-6 m horizontally. A numerically coincident native
  projected goal is replaced by the exact requested waypoint in the candidate
  path. Original native corners remain untouched in `nativeLegs`; every merge,
  residual and retained candidate point is recorded. This removes Float32
  sub-micrometre yaw artifacts without moving an actor/start/goal or deleting a
  substantive corner. All winding, sampled checks and budgets use the final
  candidate, not the pre-coalescing chain.
- The unchanged source sweep is called on the complete closed path plus its
  first outgoing segment, ensuring the last-to-first turn is checked. Exact
  endpoints and every vertex turn (including the seam) are also sampled at the
  original spacing/angle. This remains a finite model check, not continuous
  swept collision or measured floor support.
- Directed integer crossing counts must be the same +1 or -1 for every target
  cell centre. A centre on the path is rejected. This rules out an out-and-back
  masquerading as a lap, but does not establish a simple non-self-intersecting
  polygon; that limitation is explicit in the receipt.
- Flag diagnostics count planned sampled-pose visits separately from unique
  low-unresolved cells. Repeated endpoint/seam samples remain counted and their
  definition is disclosed. These are not executed actor visits. Far-only-dip
  conflict remains unavailable, not clear.

## Three-lap budget proposal

The result reports per-lap `ceil(length/0.02)` translation ticks, the diagnostic
sum of segment-wise ceilings, and the sum of `ceil(abs(turn)/1 degree)` across
all vertices including the closure seam. The proposed total is three times
translation plus turning plus **300 fixed allowance ticks per lap**, plus
**150 fixed terminal-drain ticks**. These allowances are declared before any
actor outcome; they do not extend the existing deadlock rule or authorize
post-stall budget changes. They must be reviewed/frozen with the actual loop
before reference scoring. Three laps retain actor state; there is no inherited
1,200-tick short-route cap and no reset or teleport.

## Next permitted work after slot release

Parent reviews source, then runs the tiny synthetic fixtures. The fixtures do
not import CandidateMap, load recorded inputs or invoke Detour. Only after
separate coordinated authorization should a bounded worker instantiate the
pinned CandidateMap, call the proposal once, serialize the result with its
source/input receipt, and optionally call
`write_phone_only_diagnostic(proposal, candidate_map, exclusive_png_path)` to
draw only the supplied phone mask/flags, target outline, fixed waypoints and
already-returned path. Matplotlib is imported lazily; importing this module
does not render. No three-lap physics/controller implementation or reference
call is included here.
