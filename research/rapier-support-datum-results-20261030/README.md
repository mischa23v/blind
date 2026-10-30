# Six-pose foot-datum diagnostic: explains some low contacts, not a general fix

**The controlled comparison completed: 48 Rapier calls and 96 VTK
pose/envelope/band queries.** No movement proposal was applied, no route was
followed, and no triangle was deleted or exempted as floor. The candidate foot
Y values were frozen before this native comparison. Body size, margins, yaw,
requested displacement and meshes stayed unchanged.

Source commit `71d1e68c65620106b2da97658951017420761c6a`; 3.807 s wall,
3.729 s aggregate CPU, 369,913,856 B peak observed aggregate RSS. Both child
process groups retired; all 110 pinned inputs remained unchanged. A zero worker
exit means the diagnostic completed, not that navigation passed.

## What the paired experiment shows

The table reports **original XYZ intent**. The two stationary endpoints retain
zero intent. Counts are intersecting mesh triangles, not distinct hazards.
`full / trimmed` means full cuboid versus the separately preserved lower-2mm
query exclusion. Whole-triangle heights below are not actual contact points.

| Original pose | Candidate Y shift | Nominal VTK contacts, before → after (full / trimmed) | Margin VTK contacts, before → after (full / trimmed) | Interpretation |
|---|---:|---|---|---|
| Conference table92→120, event960 | +2.334 mm | 0/0 → 0/0 | 14/6 → 6/6 | Nominal KCC's small near-foot response disappears, but margin intersections remain. |
| Conference table120→200, endpoint2051 | +17.947 mm | 15/15 → 0/0 | 25/25 → 0/0 | Authored foot datum explains these particular low intersections. Zero-input KCC lift ~14.7 mm becomes zero. |
| Conference table20→92, event1057 | +5.735 mm | 9/7 → 7/7 | 26/25 → 25/24 | Single-triangle tangent is insufficient. Nominal motion remains limited to roughly (2.46,1.14,8.47) mm rather than requested (16.67,0.69,16.67) mm. |
| Conference Varpu160→130, event966 | −2.419 mm | 0/0 → 0/0 | 5/5 → 15/5 | Lowered candidate adds ten full-height low intersections; five high intersections remain. Not a uniform improvement. |
| Coffee event630 | −13.981 mm | 0/0 → 0/0 | 9/9 → 9/9 | All nine higher margin-contact faces remain; changing foot height does not fix horizontal overlap. |
| Coffee endpoint1643 | +2.374 mm | 26/0 → 0/0 | 119/60 → 60/55 | Removes nominal sub-2mm intersections; KCC nominal zero-input lift 2.372 mm becomes zero. Higher margin overlaps remain. |

Zero-input cases are separately retained in `RESULTS.json` and compact rows.
For example, the Conference Varpu original stationary margin has zero full-height
intersections but its lowered candidate has six; that differs from the moving
case's five-to-fifteen count. Do not conflate static and swept queries.

## Higher geometry was retained, not cleared away

- Coffee event630's nine original contact faces span approximately **0.603–0.679 m**
  above the original foot; all nine remain after the datum change. KCC nevertheless
  returns the requested 16.667 mm X translation unchanged. This persists as a
  collision-semantics disagreement, **not evidence that the overlap is safe**.
- Conference Varpu's five moving-margin contact faces span approximately
  **1.331–1.523 m** above the original foot. All five remain after the change;
  the full-height query additionally sees low intersections.
- Coffee endpoint retains all **51** contact triangles whose entire height range
  was above 10 cm. The margin still has a large lateral depenetration proposal
  (about 8.6 cm), which was recorded, never applied.

Ten centimetres here is solely a descriptive reporting boundary for whole
triangles, not a hazard threshold or semantic classifier. All lower contacts,
all IDs, and both height-band queries are retained too. No retained higher-face
ID in that descriptive group disappeared in these paired queries.

## Concrete conclusion

**Some earlier low blockage is demonstrably sensitive to the authored foot
height, not the room being too narrow.** The endpoint comparison removes all its
low contacts without changing horizontal geometry or deleting surfaces. That is
a useful diagnosis of those specific poses.

**A single center triangle does not supply an adequate floor model for a whole
body footprint.** It leaves the table20→92 limitation, can add intersections when
it lowers a pose, and cannot remove true or conservative higher-surface overlap.
Every nominal corner in all six candidates extrapolated the selected triangle.
Nine sampled eligible hits do not establish continuous support. Neither scene
has confirmed semantic floor. The poses were chosen after earlier results, not
as held-out validation.

Do not adopt this candidate placement as production ground following, suppress
low contacts globally, raise bodies until they clear, or substitute KCC movement
for an overlap verdict. Next work should distinguish local support shape across
the footprint from retained raised geometry, and investigate the original
high-overlap faces/starting configuration separately. A full route requires
continuous support and obstacle checks, not isolated proposals. The two prior
analytic down-step failures also remain unresolved.

## Reproducible saved evidence

- `COMPACT_KCC.jsonl`: all 48 requested/proposed vectors and collision witnesses.
- `COMPACT_VTK.jsonl`: all 96 exact poses, inputs, bands and complete contact IDs.
- `CONTACT_TRIANGLES.json`: shared original vertex IDs and model height ranges;
  row-relative ranges are reconstructed by subtracting that row's foot Y.
- `RESULTS.json`: paired measurements, preserved higher IDs/counts, raw-file hashes,
  input integrity and explicit limitations. Complete raw records remain intact.
- `summarize.py`: stdlib-only regeneration and terminal-contract checks; no native
  engine import or rerun.

From the same workspace:

```
python -S research/rapier-support-datum-results-20261030/summarize.py <fresh-output-directory>
```

This is public dataset geometry, not private home/child captures. No app or
production map was changed; no physical safety or usable path claim follows.
