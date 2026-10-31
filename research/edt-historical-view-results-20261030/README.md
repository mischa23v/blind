# Historical EDT comparator: terminal result, 30 October 2026

**Run [41011080206](https://github.com/mischa23v/blind/actions/runs/41011080206)
completed successfully at `e418290ac2a70f93c4250bb094091082408f7093`.**
The exact historical source view reproduced all 50 original controls and 51
native hook checks. The 25-request candidate met its fixed declared goals.
Artifact upload was skipped and the terminal artifact API returned zero artifacts.

## Correction: what geometry was actually used?

Calling this wholly a “synthetic geometry comparator” was inaccurate. It uses
**Apple's public prescanned RoomPlan Hallway2 and Bedroom3 CapturedRoom models**, via
previously exported/imported and packed final-adapter geometry. It uses neither
Coffee nor the conference-room dataset. These are parametric saved room models,
not fresh raw RGB/depth sequences or independently surveyed real-world truth.

The original public source is Apple's
[Merging Multiple Scans sample](https://developer.apple.com/documentation/roomplan/merging-multiple-scans-into-a-single-structure).
`APPLE_FIXTURE_PROVENANCE.json` preserves archive identity, license and individual
CapturedRoom hashes. Packed vertices are original-world, Y-up metres encoded as
Float32 bit patterns; triangle feature IDs, floor classifications and furniture
bounds are retained. Room geometry is not newly invented for this experiment.
**Starts, destinations, body profiles and journeys are supplied diagnostic inputs**;
there is no camera localization, actual person movement or new room capture.

The 25 requests comprise **12 Hallway2 and 13 Bedroom3 requests**: 18 frozen route
queries and seven previously executed journey queries. Nine originally stopped
journey stages remain unrun; they were not filled in as successes. Source and
request hashes, all fixed acceptance IDs and profile dimensions are recorded in
`PROTOCOL_SCOPE.json`.

## What “candidateGoalsMet” actually means

It is **not 25 successful routes** and not a navigation accuracy percentage.
The exact frozen Swift predicate requires all of the following:

| Required candidate outcome | Count |
|---|---:|
| Retain previously complete, no-obstacle-contact corridors | 6 |
| Complete the two targeted hall-corner routes without body or margin obstacle contacts | 2 |
| Retain typed strict endpoint refusals | 3 |
| Preserve other original route failures, with no returned route points | 14 |

In addition, every candidate must preserve the original input/profile and initial
contact receipt, and match the complete expected native layout. All 50 original
legacy/strict controls must reproduce before candidate execution is permitted.
The 51 hook checks must pass before the route executable runs.

The six-plus-two route predicate requires native success and completeness,
nonempty points/segments, strict requested-XZ endpoint admission, both endpoints
found over polygons, no initial modeled body or margin obstacle contact, and no
modeled body or margin obstacle contact on any scored connector/route segment.
The three refusal predicate specifically retains unsuccessful strict admission
with no route points, native status zero and a supplied start not over a polygon.
The remaining 14 must stay unsuccessful with no route points; this does not prove
the real rooms are impassable.

These group counts are **logically implied by the pinned source predicate plus
the retained true result flag**. The artifact-disabled run exposed aggregate
metadata and hashes, not the full per-request result rows. We have not downloaded
or independently re-scored those rows. This distinction is enforced by the
saved-evidence verifier.

## Collision and support meaning

The unchanged SceneKit oracle sweeps a full upright modeled cylinder and checks
initial and terminal overlaps. It scores the requested-start-to-projection and
projection-to-requested-goal connectors as well as intermediate path segments.
Both raw-body and margin-expanded profiles are queried against packed obstacle
surfaces and furniture bounds. Physics shape collision margin is zero; the
explicit profile itself supplies the additional margin.

The nominal profile has radius about 0.270416 m and height 1.60 m, expanded to
0.420416 m and 1.75 m. The 28 cm supplied profile uses the circumscribed radius of
a 0.28 × 0.20 m footprint, about 0.172047 m, expanded to 0.322047 m; height grows
from 1.20 to 1.35 m. Thus “28 cm” is not a 14 cm collision radius. The wider profile
and all exact values are preserved in `PROTOCOL_SCOPE.json`.

Floor contacts are queried and recorded separately, **not counted as obstacle
contacts**. A floor contact does not establish whole-footprint support. The
protocol explicitly leaves all these false: full-footprint support verified,
continuous source-clearance guarantee, centered-clearance objective implemented,
iOS validated, app activation and physical authority. It does not validate stairs,
drops, dynamic obstacles, real body dimensions or live navigation safety.

## Provenance and previous failure

Actual workflow checkout: `e418290ac2a70f93c4250bb094091082408f7093`.
Historical protocol/input source: `5a6ad0ad5c64879a9e95bae9212054ab9daf950d`.
All 58 historical inputs were verified: 55 exact current inputs and three explicit
historical overrides. The source view is verified before every original command;
actual repository/ref/checkout authorization remains separate and unchanged.
This tests the historical implementation, **not the newer optional seed-veto or
envelope native additions**.

The first run, `41008743162` at `7bb0532`, remains a failed source-pin-gate attempt,
with no native controls executed and no result file. `PREVIOUS_FAILED_RUN.json`
preserves that failure. The later run does not erase or relabel it.

| Retained terminal evidence | Value |
|---|---|
| Result byte count | 385,447 |
| Result SHA-256 | `4debf8286fd2fc2892767fb3ded89e836909730f3f6cd2bc1806490505f1521a` |
| Receipt byte count | 81,271 |
| Receipt SHA-256 | `fa274bdb1e8829767bd83fa475b210fda542faf6f93fab7992211342fca9ff99` |
| Artifact count | 0 |

`BOUNDED_LOG.txt` contains the exact retained public provenance/metadata log lines.
`TERMINAL_EVIDENCE.json` records their parsed contents and retrieval limitations.
The whole raw receipt/result bytes are not bundled or claimed as retrieved.

## Reproduce the evidence check, not the native experiment

```
python3 -B research/edt-historical-view-results-20261030/verify_saved_evidence.py
```

This fails closed on altered/missing packet files, changed source identity,
inconsistent log metadata, incorrect control/candidate counts, altered acceptance
predicates or loss of the prior failure. It reads saved evidence only: no native
execution, artifact download, source changes or rerun. The historical native
experiment's separately reviewed command remains documented in
`research/native-edt-historical-view-20261030/README.md`.
