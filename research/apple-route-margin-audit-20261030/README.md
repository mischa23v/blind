# Read-only diagnosis of the three Apple route-test failures

Evidence: retained Apple CI native job report, commit
`457c3f33dae01b2f036d5a391f42aa444cd7d304`, 297 native test cases. This audit
reads retained `NATIVE_UNIT_CASE_STATUSES.routeDiagnosticEvidence`; it does not
rerun tests, change fixtures, adjust expectations or modify the current CI candidate.
All 13 attached source SHA-256 bindings match the local files inspected.

Throughout this report, **raw body** means the declared upright modeled cylinder,
not measured anatomy or a width/2 disc. Its radius is `hypot(width, depth)/2`;
margin is added once to radius and once to height. SceneKit collisionMargin is zero.

## Actual failure causes

| Failed test | Conflicting complete candidates | Saved evidence |
|---|---:|---|
| Original baseline | 1 conflicting complete candidate | `hall-corner`, nominal body: raw body clear; margin contacts two original wall surfaces on Detour segments 3–8. Initial pose and both requested/projection connectors are clear. |
| Separately registered 28 cm profile | 2 conflicting complete candidates | `bedroom-aisle`: initial margin overlaps bed and requested-start connector/first native segment contact bed. `hall-corner`: raw body clear; margin contacts the same two walls on native segments 2–5. |
| Supplied bed/chair/door/return journeys | 2 conflicting complete candidates | Both bed and chair supplied-standing connectors already overlap the **bed** margin envelope; neither has raw body contact. They stop before later bedroom stages. |

Do not conflate three failed test methods with three failed paths. Baseline has
12 scheduled rows (8 invalid starts, 2 no-contact model candidates, 1 contacting
candidate, 1 native-query failure). The 28 cm addendum has 6 rows (2 invalid starts,
2 no-contact model candidates, 1 contacting candidate, 1 native-query failure).
Journey has 16 rows: 4 invalid standing starts (including 2 intentional contained
controls), 9 not run after stop, 2 no-contact modeled stages and 1 expected withheld
outbound attempt. None is a physical arrival.

### Bedroom: supplied standing points versus original furniture

Bed ID `45597D99-3218-4419-A2E4-2ADFA824D033`; chair ID
`531A8ED6-A501-403D-B765-064236B96FC2`. The saved **chair** journey contacts the
**bed**, not evidence that the chair itself was ignored.

Original bed bound dimensions are 1.6728522 × 0.6448028 × 2.1749296 m.
Transforming the unchanged requested standing points into that oriented bound
and measuring horizontal distance gives:

| Authored standing point | Bed-bound clearance | Raw 28 cm-profile radius | Margin radius | Margin intrusion |
|---|---:|---:|---:|---:|
| Bedroom aisle | 0.202306 m | 0.172047 m | 0.322047 m | 0.119741 m |
| Supplied bed-rise | 0.202305 m | 0.172047 m | 0.322047 m | 0.119741 m |
| Supplied chair-rise | 0.252305 m | 0.172047 m | 0.322047 m | 0.069741 m |

This reproduces the raw-body-clear / margin-overlap distinction arithmetically
without a native run. The frozen profile is width 0.28, depth 0.20, height 1.20 m,
with radius `hypot(width,depth)/2` and 0.15 m margin added once. It is not a calibrated
child measurement. The baseline nominal radius is 0.270416 m before margin, which
also explains its body-overlapping aisle start. These are locally invalid authored
standing positions for those envelopes, not a demonstrated room-width limitation.

The native projection moves the supplied bed-rise start horizontally 0.132257 m
and chair-rise start 0.076864 m. These displacements are recorded and swept; they
are not accepted as silent relocation. Replay remains at each original standing
point after failure. Nine subsequent bedroom stages remain unexecuted.

### Hall: real margin violation and a small unresolved backend discrepancy

Contact IDs are original walls `0D0716C9-28D9-4F00-BE7C-E2A6FAFA36FA` and
`0CD2F73E-5F0B-444C-BE63-2F9855C59D47`. Retained packed Float32 triangle 0 ends
at the shared corner approximately `(4.0380621, y, 12.5905313)`.

A supplementary projected-wall-edge calculation on the exact retained packed
vertices and original route segments finds:

- Nominal segment 6 approaches the wall corner to **0.411871995 m**, against
  a margin radius **0.420416355 m**: approximately **8.544 mm overlap**. This
  supports the native margin-contact finding without invoking floor noise.
- The 28 cm segment 4 approaches to **0.323474209 m**, against radius
  **0.322046518 m**: approximately **1.428 mm positive gap**, while SceneKit
  reports contacts. That small disagreement remains unresolved. The arithmetic
  is not a replacement collision oracle and does not justify relabeling the run.
  Contact-phase/point/normal details are not retained per segment in this report.

The frozen planner does pass the effective radius and height to Recast; source
uses `ceil(radius/cellSize)` erosion at 2.5 cm cells. No evidence here establishes
that the entire room is narrow, that scale is globally wrong, or exactly which
raster/contour/query/backend step causes the hall discrepancy.

## Foot datum and the Coffee/conference comparison

All returned native points in each affected Apple route use a constant Y:
Bedroom -1.44098508358 m, Hallway -1.39929413795 m. Authored floor positions are
respectively -1.46598494053 and -1.42429411411 m: roughly **25 mm lower**.
The tests explicitly append the source-floor → projection association and the
projection → requested-goal connector, and score both. The journey assigns
`current = goal` only after the entire chain passes, including that final connector.
This is a declared source-floor/native-height change between stage endpoints,
not the unscored repeated Y reset inside every movement tick found in the earlier
Coffee/conference analysis.

More importantly, `hasObstacleContact` is defined only by nonfloor surface or
furniture-bound IDs. Floor IDs are recorded separately. Hall conflicts occur
inside constant-native-Y segments, away from the endpoint connectors. Bedroom
initial bed overlap is already present at the original floor Y, and persists in
the first native segment. **A support-datum fix is not established as a fix for
these three failures.** Neither floor contact nor absence of nonfloor contact
establishes full-footprint support.

## Roles are explicit, not inferred from cameras

- Positions are original fixture floor-local coordinates transformed once into
  the source's saved world. Different room frames are never joined.
- Furniture IDs name modeled bed/chair context, not detected people or body poses.
- Standing point and heading are authored inputs. Camera localization and get-up
  kinematics are explicitly untested; no camera pose is being used as a foot pose.
- The independent oracle positions a cylinder centre at `foot.y + height/2`.
- Map destinations remain requested floor points. Recast projected endpoints are
  separate receipts, not permission to relocate a user.
- Guidance strings are generated before scoring in a test-only sink with physical
  authority false; this is not a live collision-approved guidance release.

Public provenance: Apple's `MergingMultipleScansIntoASingleStructure.zip`, exact
Hallway2 and Bedroom3 CapturedRoom JSONs pinned by the fixture manifest. These are
historical parametric room models, not fresh RGB/depth recordings of users.

## Minimal next diagnostic, not a silently changed passing test

1. Preserve all original schedules/outcomes. Record each failing sweep's initial,
   swept and terminal contact phases with feature IDs, contact point/normal and
   distance if exposed by the Apple API. This distinguishes the small 28 cm hall
   disagreement from the independently supported nominal overlap.
2. On those same hall segments, compare the exact exported triangles and actual
   SceneKit cylinder convention against a separate bounded analytic clearance
   control. Do not remove walls, shrink the profile or hide the failure.
3. Keep authored invalid bedroom starts as negative cases. Any additional
   reachable standing-pose fixture must be separately registered, selected from
   source geometry with the same margin, and labeled an added pose diagnostic;
   it cannot replace these results or claim real get-up/localization.

No corrective change is proven by this read-only audit. Original expectations,
geometry, paths and current CI files remain untouched.

## Reproduce this audit

From repository root, run `python research/apple-route-margin-audit-20261030/analyze.py`
and `python research/apple-route-margin-audit-20261030/wall_edge_check.py`.
These are standard-library-only calculations over saved evidence. `RESULTS.json`
retains original outcome fields and exact contacting segments; no native imports.

## Packet provenance and arithmetic limitations

`INPUT_EVIDENCE.json` contains the unchanged parsed first three outcome reports
and exact packed routing-geometry report selected from the CI collector output.
It retains the source commit, all 13 source hashes, original log hash, status-line
hash and collector-reported original attachment hashes. Reserialization changes
attachment bytes: the original attachment SHA fields are provenance supplied by
the collector, not independently recomputed attachment hashes here. The packet
manifest pins the selected serialized evidence and scripts. No private imagery
or external downloads are included.

`analyze.py` verifies all 13 current repository source hashes and reproduces
`RESULTS.json` exactly without writing it. Use the original pinned sources if
later changes cause the identity check to fail; do not relax the check.
`wall_edge_check.py` prints a supplementary projected-distance calculation, not
another native collision test. It considers edges of the two identified wall
features with overlapping vertical ranges. It measures finite projected line
segments (endpoint-to-segment minima), not arbitrary swept 3D cylinders, contact
penetration depths or a complete triangle-intersection oracle. The two relevant
walls are vertical and this observed route remains outside their projected edges.
Do not generalize this arithmetic to intersecting segments, arbitrary furniture,
slopes or floor support. Its approximately 1.43 mm discrepancy is a reason to
inspect the actual SceneKit contact phases/shapes, not a passing clearance claim.

No room-wide reconstruction accuracy, sensor accuracy, live localization,
physical child-safety rate or real movement has been measured by this audit.
