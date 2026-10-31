# Released Detour height-following: two fixed authored routes

**Prepared source only. No native execution or physical guidance.**

This is an association/foot-datum comparison, not a new mapping algorithm and not
an attempt to fit the body by repeatedly raising it until contacts disappear.
The historical Conference table_120_to_200 and Coffee 0_to_8 source trajectories
remain unchanged in one arm. A separate native-height arm asks whether official
Detour detail-height following removes artificial endpoint-Y resets while
retaining the same desired XZ route and authored headings.

## Frozen comparison

- Exact original 2,052 Conference and 1,644 Coffee events, including all authored
  turns and tiny connector XZ residuals. No resampling, shortcut, easier goal or
  heading change. Original goal XYZ/identity and all seven Conference requests
  are recorded; the other six are unexecuted here, not failures or omissions.
- Original raw Float32 mesh buffers and triangle ordinals are unchanged. Coffee
  is raw Y-up; Conference uses the existing estimated registration, not a newly
  verified camera/body calibration. No semantic ground exemptions.
- Historical native Recast builder and non-exclusion configuration: radius
  0.225m, height1.75m, cell width/height0.025m, max climb0.025m, max slope15deg,
  maxcells250000/maxnodes4096. Build once per scene; no tuning or exclusion.
- Native arm keeps active polygon reference and last native position. It calls
  released `moveAlongSurface` then `getPolyHeight`, retaining statuses and visited
  polygon IDs. This is **local polygon-state traversal**, not a new global path,
  and not a claim that the entire dtPathCorridor controller is reproduced.
- Initial nearest-poly association uses existing (0.2,0.3,0.2)m search extents.
  Its requested and projected XYZ are separate records. The proposed navmesh
  start is NOT a measured body pose or physical relocation.
- XZ numerical budget is frozen at **1e-6m** before execution. Actual native XZ
  is recorded; only sub-budget Float32 discrepancy can be represented using the
  original desired XZ for exact paired geometric queries. This is a numerical
  comparison convention, NOT a clearance/safety tolerance. Larger clamps,
  invalid/partial/missing height or visited-buffer exhaustion invalidate the
  corrected continuation; no nearest-poly recovery, fallback height or replan.
- Body-foot Y equals returned native detail Y: **zero added vertical offset**.
  Destination requested Y remains association metadata; no forced downward
  endpoint connector. Native source floor approximation is not physical support.
- Original arm retains ALL XYZ connectors. Native arm retains each connector's
  original XZ/timing index but uses detail Y, not the requested anchor's Y. Thus
  no exact-original-XYZ arrival can be claimed for the native arm.

## Independent collision audit

Use the unchanged released VTK-backed all-hit swept-body kernel. Query both
original and valid native events, both nominal0.45x0.30x1.60m and15cm horizontal
margin, and both **untrimmed** and original **2mm lower trim** independently.
Retain every intersected triangle ID, with shared source vertex/height evidence.
Existing swept-turn enclosure is used at the identical authored yaw/dyaw; no
claim that this matches a person's unmeasured turning motion.

A failed native lookup does not erase the original event: it is recorded as
unavailable for the corrected arm, and original collision auditing continues.
Every low contact remains a contact, but is not automatically declared a toy or
obstacle; equally, no near-foot triangle is automatically safe floor. Higher
furniture contacts must remain visible. Prior Rapier down-step failures remain
failed and are not superseded by this test. Nothing is moved in the app or map.

## Resource bounds / honest incompletion

One CPU, aggregate120 CPU seconds/180wall seconds/1GiB observed RSS. Compile,
height tracing and VTK audit run serially in that aggregate. No native execution
before source publication and root admission. Up to29,568 VTK envelope/band
records,30million triangle candidates,64MiB aggregate output. Abort and retain
partial records if any cap is hit, without selecting only easier events.

Feasibility evidence (not a promise): prior all-seven complete-ID audit queried
27,408 boxes/8.71M candidates in67.13s; simplified14,940 boxes/4.65M in36.71s.
Historical native build receipt reports7.79s. Thus this two-route comparison is
plausible within the existing envelope, but changed floor contacts and compile
cost can still exhaust it. No limit increase or hidden stage reset is implied.

## Interpretation

This asks whether consistent released detail-height association explains some
false low intersections. It does not establish continuous observed floor,
drop/stair/toy detection, physical collision-free movement, relocalization,
iPhone runtime performance or child safety. Body sizing, map/source alignment
and sensor freshness remain independent uncertainties. A geometric contact
reduction is NOT navigation accuracy or an arrival.

**Critical low-object limitation:** navmesh detail Y may be above the raw floor
by its voxel/detail approximation. A raised virtual foot can omit real low
objects from the queried body even when no extra offset was added. The audit
must retain both complete contact-ID sets so lost IDs can be derived exactly,
and the vertical band between original and
native foot at both ends of every event. A newly contact-free box is not evidence
that this uncovered band is safe, nor that the wearer actually has that foot Y.
