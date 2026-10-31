# Exact scored-chain evidence follow-up

2026-10-28 source-only validator follow-up. No native path result is claimed and
no prior test report or protocol byte is rewritten. The initial exporter review
manifest and logs in the parent directory remain unchanged historical records.

## Accepted additive baseline schema 1 fields

The baseline and separately labeled width addendum keep their fixed 12 + 6
schedules, original protocol/source hashes and report names. Successful native
route rows may additionally contain all three fields together:

- `scoredChainContinuous`: exactly `true`.
- `scoredChainIncludesRequestedGoal`: exactly `nativeComplete` as a Boolean.
- `sourceFloorSupportAlongScoredChain`: exactly `unverified-full-footprint`.

When those row fields are present, every scored segment must additionally contain
all three fields together:

- `floorContactIDs`: existing allowlisted public-fixture UUID array, included in
  the row's aggregate floor contact IDs.
- `fullFootprintSupportVerified`: exactly `false`.
- `sourceFloorSupport`: exactly `unverified-full-footprint`.

No positive floor/support claim is accepted. The journey producer remains
unchanged and does not accept those baseline-only additive fields. Failure and
unexecuted records keep their existing schemas and outcomes.

## Exact-chain verification

For every native-success row, the validator independently derives only the
expected edge identities/endpoints from the report's already-recorded values:

1. Requested start to projected start, including a zero-length edge.
2. Projected start to first Detour point, only if the points differ exactly.
3. Every consecutive Detour edge in its original order.
4. Last Detour point to projected goal, only for a complete route and only if the
   points differ exactly.
5. Projected goal to requested goal, only for a complete route, including a
   zero-length edge.

It compares the complete ordered `kind/from/to` sequence without tolerances,
snapping, synthesized report segments or route repair. Partial routes stop at the
last native point; they cannot bridge to either goal. Missing, reordered, repeated,
extra or altered edges fail collection. Aggregate body/margin contact must equal
the recorded initial contact OR any corresponding scored segment contact; a
connector collision cannot disappear behind a no-contact outcome label.

Schema-1 records without the new optional fields still parse when their actual
scored chain is complete. An older missing-gap record is not silently promoted
to a validated no-contact report. Its original bytes remain unchanged; it needs
separately explicit legacy/gap-only handling, not a relaxed live collector.

This is bookkeeping of reported evidence, not a new navigation, geometry,
collision or floor-support algorithm. It never proves physical clearance,
get-up movement, person localization or successful live arrival.

## Verification

Standard-library bounded tests only; no dependencies, builds or native execution:

- `python3 tools/ci/test-native-unit-statuses.py`: 31 pass.
- `python3 tools/ci/test-native-route-diagnostic-evidence.py`: 35 pass.
- `python3 research/roomplan-route-result-views-20261028/test_render_results.py`:
  28 pass against the updated validator (renderer is owned separately).

Independent review reran the 31 + 35 exporter/status checks and found no remaining
strict-collector blocker. Negative fixtures include both endpoint discrepancies,
missing/extra/reordered edges, partial-goal bridging, false/ill-typed continuity
flags, mixed support metadata, claimed positive floor support, missing aggregate
floor IDs and hidden connector collisions. Existing artifact size, privacy,
source provenance, test statuses and exit semantics remain unchanged.
