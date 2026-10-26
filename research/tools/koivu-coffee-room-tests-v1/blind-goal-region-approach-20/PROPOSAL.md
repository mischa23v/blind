# Same-tolerance northern goal-region approach — not executed

The original fixed-point test remains a failure. Corrected-mask native goal
projections were 17.39 cm, 22.09 cm and 11.59 cm from the original north request
for the 45 cm, 55 cm-envelope and abstract 28 cm profiles. None was silently
accepted under the unchanged 10 cm fixed-point association rule.

This separate proposal uses the **existing 35 cm task-arrival region** instead
of insisting on association to its exact camera-derived centre. It changes the
goal representation, not the body dimensions, margin, task tolerance or start.

## Frozen physical objective

- Preserve the original north start and task-goal requests from stage11, in
  original phone coordinates. They are controlled body-goal points at the
  original model floor, not measured camera/body extrinsics.
- Map them to each supplied map using exact old/new level transforms. Keep the
  full XYZ mapping and all projected endpoint differences.
- Never relocate or snap the actual start. If its existing association/fit
  checks fail, report that failure.

## Candidate steering goals

- Consider only existing 5 cm mask-cell centres inside the same 0.35 m task
  region, measured in the original common horizontal frame. Also report full
  3-D physical-coordinate distance and any vertical plane mismatch.
- Keep the original mask's flags and uncertainty. Require a complete native
  route, the unchanged exact-endpoint connector, sampled rectangle translations
  and turns, and a feasible final heading for the same profile.
- Order candidates by conservative phone-mask clearance first, then distance
  to the original task goal, then source-cell index. Test at most 32 centres
  per profile/map. No new candidate may be selected after reference scoring.
- Retain every attempted centre, native failure, association displacement,
  fit rejection and unresolved exposure. Report whether the candidate cap was
  reached; finite search failure does not prove the region is unreachable.

## Do not compound tolerances

There are two separate coordinates:

1. **Task goal:** the unchanged original requested position and its 0.35 m
   arrival test.
2. **Steering goal:** one frozen feasible centre inside that task region.

The actor must still be scored against the **original task goal**. Applying
another 0.35 m tolerance around the steering goal could allow a 0.70 m miss and
is prohibited. No pose is teleported to either point. The existing bounded
incremental integrator, queued-command drainage, support and swept-body contact
checks remain authoritative for the simulated episode.

## Execution boundary

This file is a proposal, not a candidate or movement result. The bounded
phone-only selector can compare old/new masks with up to 192 queries
(32 centres × 3 profiles × 2 maps), after source/fixture review and frozen inputs.
Only a selected route may then be scored independently against reference
geometry. Any such result is an offline provided-map simulation, not current
sensor clearance or an iPhone walking demonstration.
