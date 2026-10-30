# Prepared full-body comparison of all seven actually simplified chains

**Source-only. No simplified-chain body or VTK run has occurred.** Publication,
independent review and root admission are required before native execution.

## Exact actual route source; no second simplification

Actual paired proposal source: `dad87dcc75d86e3b170201e778ccef69c76ccca4`.
`conference-geos-simplification-attempt-001/comparison/PAIRS.json` SHA256:
`3b47960077f817b627b2868748204174020378832b50c3459c8bcdf35d73be47`.

That run produced seven corridor-eligible **provisional** chains. Corridor
eligibility does not establish body/margin contact absence, independent
coverage, support, physical acceptance or camera/body alignment. This stage
consumes its exact saved `geos025CenteredCandidate.chainXYZ` values; it does
not rerun GEOS, native route search or native segment eligibility checks.

| Request | Actual chain points | Authored events | Connector-inclusive length |
| --- | ---: | ---: | ---: |
| table_92_to_120 | 18 | 796 | 3.280008 m |
| table_120_to_200 | 23 | 1,101 | 5.113642 m |
| table_200_to_220 | 15 | 653 | 2.378718 m |
| table_220_to_20 | 20 | 889 | 4.049420 m |
| table_20_to_92 | 34 | 1,740 | 7.008670 m |
| varpu_130_to_160 | 23 | 1,145 | 5.455506 m |
| varpu_160_to_130 | 23 | 1,146 | 5.455506 m |
| **Total** | | **7,470** | **32.741471 m** |

All seven requests and their original source-pose associations remain. No
easiest-route subset or fallback is selected. Each candidate is reconstructed
from the exact retained source graph indices and checked against the saved
candidate. Requested endpoints, connectors, locked first/last graph edges and
all retained XYZ values are unchanged. The first/last three points must equal
the original chain; no floor/pose correction or further smoothing is allowed.

The original stop/turn/translate scheduler is reused unchanged: ≤25 mm 3D
translation and ≤1 degree yaw increments. The exact regenerated schedule hashes
are frozen in `ROUTES.json`. Initial yaw remains authored from the first
nonzero horizontal segment, not a measured body heading. Requests are
independent authored experiments, not a continuous physical journey.

## Unchanged geometry and physics

This worker imports the **same already-executed complete-ID callback kernel**
from `conference-contact-ids-source-20261030/oriented_ground_container_debug.py`.
It is not copied or modified here. Original all-hit VTK intersection and
contained-vertex calls, sweep enclosures and candidate traversal remain fixed.

The original 18,398 vertices / 29,366 faces use the exact historical registration
and executed-adapter Float32 coordinate values, losslessly promoted for VTK.
Required byte identities remain:

- Original OBJ: `79cfd017b9c88dca840c8ec969208a93593b03f600303d70cc6777b7c55438a1`.
- Registered vertices: `50557edee3f4f0b1432c21206f1cc4f3b4c1133f0c0e754db70268eca7c250eb`.
- Triangle indices: `2c5cb77f5548e12c2bcf59680b459389a097567cec0079f30526481d6e9b9324`.

Body **0.45×0.30×1.60 m**, separate **0.15 m per horizontal axis** margin,
existing **0.002 m** lower-body exclusion, and immutable **empty** ground-face
exemption set are unchanged. No ground labels, new physics, semantic relabeling,
support rays or height-following are introduced. Low source geometry remains
contact evidence, not assumed safe floor. The 2 mm trim can miss lower/tiny
geometry; no-contact is not complete detection or clearance.

## Separately named recorder for genuinely new trajectories

The earlier `FixedHitRecorder` and its exact-old-count baseline remain untouched.
Requiring old per-event counts on new trajectories would be incorrect.
`query_recorder.BoundedQueryHitRecorder` instead checks each completed query:

- Every recorded ID belongs to the original 0…29,365 range and is unique within
  that query; callback query/event ordering is exact.
- Recorded ID count equals the query's returned all-hit non-ground count;
  ground-exempted count must remain zero.
- First recorded ID equals the returned first witness; empty queries have no
  witness. The original nominal/margin separation is preserved.
- Exact seven-route event counts total 7,470, so completion requires **14,940
  box queries**. Candidate counts are recorded, not forced to the old values.

Caps are checked before appending/accepting output: **200,000 hit occurrences
globally**, at most 29,366 IDs per query, **8 MiB logical ID log**, and **64 MiB
combined raw+ID logical logs**. A cap or count mismatch aborts incomplete; no
hit is truncated and silently presented as complete. Recorded face sets and
contact totals are bounded by the same global occurrence cap. The inherited
256 KiB receipt bound remains; excess receipt evidence also aborts rather than
loosening a bound.

## Honest old-versus-new comparison

`BASELINE.json` freezes the source-bound completed original-chain results from
source `e9bfe8deefd7b91494aec0c77afb5787f3913712` and its text-only complete-ID
recount. It retains each route's contact events, repeated hit occurrences,
unique face counts and sorted original IDs. The old baseline has 13,704
authored events, 1,019 nominal and 5,284 margin contact events, and globally
62 nominal / 1,015 margin unique source faces. **New contact outcomes are
unknown until the actual body comparison executes.**

The new receipt will report raw old/new counts and added/removed/shared source
face sets for each route and envelope, using identical face identities. It
explicitly records `safetyImprovementEstablished=false` and
`contactEventPercentagesCalculated=false`. A reduction in event count or
contact-event percentage is **not** evidence of safer movement: fewer turns
change the sampling/enclosure schedule and denominator. Unique face-set changes
are descriptive evidence, not a hazard ranking or proof of support.

First-witness whole-triangle heights continue to be logged, and complete IDs
allow later all-hit height-band accounting without another native query. No
semantic floor classification or geometry deletion is proposed.

## Aggregate budget and preparation evidence

The same **120 CPU seconds / 180 wall seconds / 1 GiB observed aggregate RSS /
64 MiB output / one CPU** limits cover controls plus worker. Process-group
retirement, exact admitted git bytes, before/after input pins, stable output
inventory, explicit receipt-manifest identity, exact-byte-checked terminal selection
loading, no-follow hashing and failed-attempt retention are inherited from
the existing aggregate guard. Worker caps remain 55,000 boxes / 30 million
triangle candidates. RSS polling remains observational, not a hard cgroup bound.

The earlier actual worker took ~63.58 wall seconds for 13,704 events. Scaling
by query count alone suggests ~34.66 seconds for 7,470 events, but this is not a
measurement: candidate density and contacts on the new segments are unknown.
There is no automatic retry, budget increase, profile relaxation or route drop.

Preparation executed only stdlib work: exact route/baseline freezing, AST parse
of six Python sources, and **nine passing** source fixtures (0.156 seconds).
Fixtures cover all-seven identity, connector/XYZ preservation, increment caps,
changed-connector refusal, legitimately changed counts, missing/duplicate IDs,
backwards query and first-witness mismatch rejection,
hard caps, full synthetic new-schedule accounting and no-percentage comparison.
No NumPy, SciPy, GEOS or VTK worker was executed during this preparation.

Prepared aggregate commands run 3 isolated-import, 6 original schedule,
6 unchanged baseline-recorder, 9 new candidate/recorder source controls, then
the unchanged 35 kernel controls and the new seven-route worker. The native
controls and worker are **not yet run** for this source checkpoint.

## Review/publication handoff

Manifest SHA256:
`4ace6a45b6693ec6b64daed25e6e3965b4328812fa42828d7b21cbb7e622f774`.

All 46 original complete-ID execution input hashes were rechecked unchanged.
`RECORDER_ADAPTATION.diff`, `WORKER_ADAPTATION.diff` and
`GUARD_ADAPTATION.diff` show the source deltas. No kernel delta exists.

Fresh intended output: `conference-simplified-body-attempt-001`.
Only after publication, independent review and explicit root admission:

```sh
python -B -I research/conference-simplified-body-source-20261030/run_aggregate_simplified.py \
  --admitted-source-commit <exact-reviewed-published-HEAD>
```

Publication metadata uses an explicit text suffix allowlist and excludes all
cache directories and binaries. Raw meshes/contact archives remain local.
This preparation is not movement authorization or a physical pass.
