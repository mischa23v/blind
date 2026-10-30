# One bounded released-height-following comparison — proposed, not implemented

Use the existing frozen native Recast build and released Detour operations,
not a new floor plane or a search for a higher collision-free body pose.

## Fixed scope

The first integration comparison uses two already frozen requests:
Conference `table_120_to_200` and Coffee `0_to_8`. They were selected because
this audit exposed their artificial endpoint-Y connectors, not because a new
height-following result passed. Keep all existing original requested goals,
start/goal association records and other requests in the report; unexecuted
routes remain explicitly unexecuted. Do not replace either selected request if
it fails. Historical original results remain unchanged. Label the new arm
`corrected-map-goal-association proposal`, not a replacement benchmark.

For those two routes keep the exact recorded XZ chain, authored headings and
original goal identity. Compare two arms:

1. **Historical authored replay:** unchanged original XYZ and connectors.
2. **Native support-datum proposal:** explicit map-destination association kept
   separate from proposed navigation foot state. Retain each original requested
   XYZ, projected XYZ, polygon reference and vertical association delta. At each
   existing <=25mm horizontal increment, use released `moveAlongSurface` within
   the retained corridor, then `getPolyHeight` on the resulting polygon. Preserve
   statuses/visited references; reject missing/partial height data. No invented
   prior-height fallback or cross-floor nearest-polygon substitution.

Use the original native geometry/build/configuration and original source-to-
planner transform, not the newer package's changed seed policy. No raw triangle
is removed. No Recast parameter or margin search.

## No relocation hidden in an association

An offline requested anchor is not measured body-foot position. Record its
native association as an association, **not** a physically traversed vertical
step. A proposed navmesh seed does not mean the person was teleported there.
The physical-start state remains unknown throughout this offline comparison.
Do not append a final downward connector merely to force the body's Y back to
a requested map anchor. Do not claim original exact-XYZ endpoint arrival when
only XZ/goal association is reached.

The same desired XZ samples are presented to both arms. If released surface
movement clamps or changes XZ beyond the documented Float32 numerical comparison
budget, record that step as not reproducing the frozen path; do not silently
accept an easier path. Fix the numerical budget and all limits in reviewed
source before execution. Retain unsupported turns as unsupported unless the
existing independent swept-turn oracle is run for those exact poses.

## Independent geometry still controls the verdict

Record navmesh height, proposed body-foot datum and collision-query offset as
three separate quantities. Use one fixed documented offset convention, not
repeatedly lift until contact disappears. Compare unchanged full-body and margin
against original raw geometry, with both untrimmed and historical2mm-trim audit
bands and no semantic floor exemptions. Describe near-foot intersections
separately from higher geometry but retain their exact IDs/heights. Native
height consistency is not fresh physical support, toy detection or stair safety.

The existing detail representation has25mm vertical cells and25mm detail error
configuration, so its height is not promised to agree with raw surfaces within
2mm. In particular, the interior table20→92 failure is not claimed fixed by this
endpoint association change. Retain low-obstacle/drop controls and prior known
Rapier down-step failures; do not score engine agreement as accuracy.

## Finite outcome

Prepare/review/publish one adapter and frozen protocol, build once per scene,
then run the two fixed original-vs-native-height comparisons serially under an
explicit aggregate query/resource budget. The existing schedules contain2,052
and1,644 events respectively; two arms and two envelopes/two bands imply at
most29,568 VTK envelope/band records before any reviewed deduplication (which
must remain visible). Exact native call bounds and measured resource feasibility
are prerequisites to execution; exceeding a frozen budget is a retained failure,
not permission to drop hard cases. Report every rejected association,
height lookup, XZ deviation, raw contact and unsupported step. Success for this
experiment means removing the artificial endpoint-Y reset and retaining a
consistent native height trace without losing higher geometry—not a safe or
usable human journey. No native execution is authorized by this proposal alone.
