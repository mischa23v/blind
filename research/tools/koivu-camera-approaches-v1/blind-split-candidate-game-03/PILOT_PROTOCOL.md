# First actual split-map A-to-B episode

This is one simulation-only, permissive provided-phone-map diagnostic in Koivu,
not live clearance, a production Swift body permit or 100 completed journeys.
The 0.7 threshold was selected after outcomes in the external audit. Preserve
the old strict-map failures: both rooms' statistical-clear 2–6 m route counts
are zero. Low-unresolved exposure remains admitted and logged; far-only-dip
conflict cannot be reconstructed from supplied D masks and remains unassessed.

## Fixed model and route

Source commit 57fdf25f2c17b3f1cf6c5aba1156756c1e808eee. Use exact
koivu_5cm_occthres_split0.7.npz with matching koivu_5cm_v2_pipeline2_out.npz
lo/R/t/res metadata. No `ref_*` or `refWalk` enters the controller or selection.
Support is the source 0.5 mask; the source 0.7 classification applies to low,
body, deep and near-dip evidence. Known scores below 0.7 become model-free;
this is not sensor confidence or new physical evidence.

Reuse the pinned actual Recast/Detour library, upstream two-triangle cell export,
and exact upstream sampled rectangle feasibility for selecting a first route.
Use source-index candidate order, seed 11, 60 endpoints, first eligible 2–6 m
path. Record every preceding rejected pair; do not consult reference geometry
or replace the selected route after its world initialization/outcome. The old
sampled feasibility is only a selection filter, not a continuous contact proof.
Game coordinates are [levelX,height,-levelY], a proper +Y-up transform.

## Actor and geometry

Nominal body: forward depth 0.30 m, lateral width 0.45 m, height 1.60 m.
Margin is 0.15 m once per horizontal side, producing a 0.60×0.75 m margin
rectangle; Recast corridor radius is 0.375 m, followed by rectangle checks.
Do not replace that rectangle with a second circumscribed circle/square. Actual
body-surface contacts and margin-buffer contacts are reported separately.

The existing code follower consumes actual native candidate points. Independent
physics applies at 15 Hz, nominal translation≤0.02 m/tick (0.30 m/s), absolute
translation≤0.025 m/tick, yaw≤1 degree/tick. No snapping to route/navmesh/goal.
Only delivered simulated physics poses update controller position. Pilot uses
the existing impairment queue with baseline settings; lag variants come later.

At each applied increment, a midpoint-yaw oriented box enclosing the entire
translation and yaw sweep is checked using upstream VTK triangle/hex intersection
plus contained-vertex checks. Rotation pad is 2*r*sin(abs(deltaYaw)/4) on each
horizontal axis; half projected translation is added, and full vertical sweep
is retained. Margin and actual envelopes are distinct. First body or margin
contact terminates failure; reference prevention is not hidden controller help.

## Independent floor setup and support

The reference is allowed to define simulator ground contact, never steering,
route choice or a better start. At the unchanged selected X/Z/yaw, probe centre,
four oriented quadrant centres and four actual-footprint corners using existing
VTK first-hit rays in nominal height interval [−0.25,+0.15] m. Require all nine
hits, spread≤0.02 m and max absolute nominal height≤0.03 m. Otherwise retain an
invalid-start/support outcome, without replacement.

Initialize the simulated foot Y to the maximum of those reference heights;
this is explicit world setup before tick zero, not a change to the phone map.
Keep that settled foot anchor fixed for this first episode. Existing 2 mm
ordinary-floor numerical exclusion remains; no larger height band is deleted.
Mid-step and end-step finite support probes must stay within±0.02 m of the
settled foot and spread≤0.02 m, otherwise stop as uncertain support. These
finite probes never establish continuous measured support. A first returned
contact triangle confined to≤3 cm above the foot is reported separately as
floor/low-geometry ambiguity and still terminates; it does not establish that
all intersecting geometry is low, and is not relabelled clear or physical obstacle.

## Endpoints and resource bounds

One baseline episode, maximum 1,200 ticks; 150 stationary ticks is deadlock.
Arrival requires actual horizontal goal error≤0.35 m, delivered-pose goal stop,
zero applied motion and drained actuator commands, plus nonzero traversed route.
Categories remain initialization failure, no path, unknown support, no-motion
stop/deadlock, actual-body contact, margin contact, ambiguous near-floor contact,
timeout and arrival. No standstill pass. Preserve actual and attempted distance.

Serial budget: 1,800 CPU s / 2,700 wall s, aggregate process RSS 3 GiB, outputs
64 MiB, free reserve 768 MiB. Exact source/input/route pins and bounded geometry
fixtures must be frozen before the episode. A top-down planned/actual trace
plot follows the terminal result, not before launch. Physical authority stays
false; a separate controller process receives no FARO/support/contact data.
