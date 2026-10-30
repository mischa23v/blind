# Conference: prepared raw full-body enclosure comparison

**Source-only; no VTK body comparison has been executed here.** Root review,
publication, exact-commit admission and the aggregate supervisor are required.
The actual native/centered-grid proposal run was source
`719ec504901639f65767b717f7f7dc817a482640`, attempt 002. Its seven proposals are
not body-validated, observed travel, support evidence or camera/body poses.

## Frozen input and authored motion

The selected arm is exactly `clearanceGrid.requestedConnectorChainXYZ` for every
request in `conference-native-comparison-attempt-002/comparison/PROPOSALS.json`
(SHA256 `0f50fbbd52df3fa4369c0784579a93a2461b6c765b052acb2daf51d15f5f290f`).
There is no easiest-route choice, baseline fallback, distance-grid fallback,
smoothing or connector removal. Unavailable source requests would be retained
as unavailable. All seven are present in this actual input.

| Request | Chain points | Authored events | Length including connectors |
| --- | ---: | ---: | ---: |
| table_92_to_120 | 59 | 1,844 | 3.403184 m |
| table_120_to_200 | 96 | 2,052 | 5.217547 m |
| table_200_to_220 | 44 | 1,530 | 2.480559 m |
| table_220_to_20 | 72 | 1,555 | 4.114779 m |
| table_20_to_92 | 127 | 2,863 | 7.130919 m |
| varpu_130_to_160 | 98 | 1,923 | 5.542600 m |
| varpu_160_to_130 | 98 | 1,937 | 5.542600 m |

Total: **13,704 authored increments, 27,408 nominal/margin box queries.**
The scheduler is the existing joint-route stop/turn/translate policy with only
its 144-point/single-route shape restriction generalized. Every original edge
and both connectors survive. Translation increments are at most 25 mm in 3D;
turn increments at most 1 degree. Positive yaw turns +X forward toward +Z;
180-degree ties choose +pi. Initial yaw is the first nonzero horizontal segment,
including tiny connectors, not a measured camera or body heading. Every request
starts independently; no loop continuity, arrival or traversed path is claimed.

`ROUTES.json` is a compact committed route/schedule hash freeze. The worker
regenerates each schedule with stdlib code and verifies its exact digest; no
large generated schedule blob is required for execution or publication.

## Exact historical registered mesh, not a guessed pose/floor

The original Koivu OBJ is pinned at
`79cfd017b9c88dca840c8ec969208a93593b03f600303d70cc6777b7c55438a1`
(18,398 vertices, 29,366 original triangles). The exact scene adapter source,
registration JSON and mesh receipt are inputs. The worker uses its same
float64 arithmetic:

```
level = obj @ rotationOBJToLevel.T + translationOBJToLevel
vertices = column_stack(level.x, level.z, -level.y)
```

The resulting contiguous little-endian float32 vertices must equal SHA256
`50557edee3f4f0b1432c21206f1cc4f3b4c1133f0c0e754db70268eca7c250eb`;
little-endian int32 original triangle indices must equal
`2c5cb77f5548e12c2bcf59680b459389a097567cec0079f30526481d6e9b9324`.
VTK receives those exact executed-adapter float32 values promoted losslessly
to float64. Original vertex/triangle IDs are preserved and checked. No welding,
mesh deletion, decimation, hole fill, floor shift or pose correction occurs.

This remains the **historical estimated comparator frame**, not validated
camera-mesh alignment or calibrated body/phone geometry. Original/public source
and provenance are recorded in the existing conference input inventory and
scene-source recovery records. No new download is part of this work.

## Existing all-hit kernel and retained 2 mm lower-body exclusion

Unchanged pinned `oriented_container.sweep_enclosure` and
`GroundedReferenceContainer.contact_corners` from the existing collision
protocol own continuous conservative OBB enclosure and VTK all-hit contacts.
`GroundSupport` contains an immutable **empty** face-ID set. No ground component
is computed and no face is exempted. Native Recast/Detour is not imported or
called in this stage. Existing SciPy imports are inherited but no support
component calculation or support ray is invoked.

Body: **0.45 m width × 0.30 m depth × 1.60 m height**. A separate enclosure adds
**0.15 m per horizontal axis**; there is no vertical margin. The existing
default `floor_contact_exclusion=0.002` is retained unchanged from Coffee.
The lower 2 mm of the body query is therefore excluded; a surface below that
bound can be missed. This is neither semantic ground classification nor a
promise to detect all tiny objects. No additional floor-face exemption occurs.
A zero-exclusion sensitivity arm could be prepared separately later; it is not
part of this attempt and no second heavy run is proposed here.

Output includes both raw face counts, contact-event totals and the first
locator-order witness for each envelope. Whole-triangle heights are reported
in registered coordinates and relative to the authored start/end foot heights.
The optional ±25 mm first-witness reporting flag means only that the *whole
first witness triangle* lies near the authored start foot plane. It is not a
semantic floor test, an all-hit height histogram, a contact-point measurement,
or an exemption. A first floor-like witness can coexist with additional upper
contacts; an authored control explicitly retains that all-hit count.

Conservative enclosures can overcount exact contact. Closed-solid containment,
missing mesh surfaces, complete footprint support, registration accuracy,
measured body pose and safe real-world clearance remain unestablished. Raw
floor overlap does not authorize movement and is not automatically an obstacle
failure classification either.

## Bounded execution and preparation evidence

`run_aggregate.py` is the passed conference supervisor adapted only for the
source-control command, raw-body terminal contract and requested 64 MiB output
cap. Process groups, serial CPU affinity, aggregate CPU/wall accounting,
observed RSS checks, no-follow input/output hashing, stable terminal inventory,
exact admitted git bytes, failure retention and the receipt reserve are reused.
`GUARD_ADAPTATION.diff` makes these changes reviewable.

The entire attempt shares **120 CPU seconds / 180 wall seconds / 1 GiB observed
aggregate RSS / 64 MiB output**, one CPU. RSS polling is not a hard cgroup bound.
Inherited worker caps are 55,000 boxes / 30 million candidate triangles, plus
64 MiB logical log output. A two-envelope native call can exceed the candidate
budget by at most 58,732 triangles before the subsequent check. A limit abort
leaves retained partial evidence; unattempted work is not passed or failed
movement. No retry, budget increase, event removal or threshold loosening is
authorized by this preparation.

Coffee's preceding 6,618-query worker took 20.2068 wall seconds. Naive query-rate
scaling gives **83.7 worker seconds** here, before controls/guard overhead. This
is a source-only estimate, not a performance measurement or a promise to fit:
mesh density, floor contacts and locator candidate counts can change cost.

Executed preparation: six stdlib-only source fixtures passed in 0.122 seconds;
all eight Python sources parsed successfully. No scientific library, body
kernel, native planner or new build executed during preparation. Prepared
aggregate controls are the existing 20 oriented-enclosure + nine all-hit
controls and three added explicit-trim/raw-contact fixtures (**32**, not yet run).

## Root-only next command

Publish/review all source and freeze files first. Then, in the exact published
checkout and only after independent review/admission:

```sh
PYTHONDONTWRITEBYTECODE=1 python \
  research/conference-body-source-20261029/run_aggregate.py \
  --admitted-source-commit <exact-published-HEAD>
```

The frozen work root is the fresh workspace directory
`conference-body-comparison-attempt-001`; it must not already exist. The guard
runs six source controls, 32 kernel controls, then all seven raw comparisons.
It refuses to equate a zero exit or a no-contact result with physical clearance,
support, semantic floor, arrival, validated alignment or movement.
