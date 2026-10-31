# Frozen real-room Rapier probes — prepared, not executed

This is a separately reviewed **diagnostic comparison**, not controller adoption,
route acceptance or movement authorization. The completed analytic run retained
all 72 wrapper checks and failed two: the horizontal-margin cuboid's 1 cm down-step,
under both mesh-flag arms. Those failures remain; no slope/offset/fixture tuning
or assertion relaxation precedes this room diagnostic.

## Fixed inputs and questions

The earlier `rapier-analytic-comparator-source-20261030/REAL_ROOM_SELECTION.json`
selected 49 rows before Rapier outcomes: 7 Coffee rows and 6 rows for each of seven
Conference objectives. This packet retains all 49. Two exact Coffee C rows are
also recoverable: a zero-input probe at the saved accepted state before event 10,
and its rejected turn as unsupported rotation. No easier pose or new route is
selected. The Conference paths are the **original centered chains**, not the later
GEOS-smoothed variants. Every selected original VTK result remains attached.

Two scenes × two mesh-flag arms × two full cuboid profiles × two explicit input
arms produce 16 wrapper groups, 408 rows: 328 controller calls and 80 unsupported
turn records. Inputs are exact XYZ and separately labelled horizontal projection;
no pose is changed, no output is applied, and no result propagates to another row.
Initial/terminal/zero-input probes may report depenetration proposals but do not
execute them. KCC cannot validate rotation; retained VTK swept-turn evidence
remains authoritative only within that original diagnostic's stated limitations.

Compare requested versus proposed translation, collision witnesses/normals,
source-bound VTK overlap evidence, and raw versus internal-edge import behavior.
A difference is a diagnostic finding, not a corrected room or a safety score.
The accepted-surface model, unknown coverage, local support, missing mesh
surfaces and live physical state remain unresolved.

## Exact mesh/pose binding

`materialize.py` uses **stdlib only** to parse unchanged public MuSHRoom OBJ files
and saved logs. It never invokes Rapier, NumPy, VTK or a path planner. Original
triangles, winding and ordinal IDs are retained; no crop, triangle deletion,
epsilon weld, geometry repair or fitted floor is introduced.

- Coffee raw VTK arm uses original OBJ coordinates and identity transform, +Y up.
  Rapier receives those coordinates as Float32; the old VTK used Double. Maximum
  absolute Float32 conversion is 1.1920166009815603e-7 m, with no added exact XYZ
  aliases. Original 51965 vertices/87370 triangles retained.
- Conference reuses the exact historical estimated rigid registration, then the
  original `[levelX, levelZ, -levelY]` permutation. Stdlib Double arithmetic
  reproduces the already-executed Float32 vertex hash
  `50557edee3f4f0b1432c21206f1cc4f3b4c1133f0c0e754db70268eca7c250eb`
  and index hash `2c5cb77f5548e12c2bcf59680b459389a097567cec0079f30526481d6e9b9324`.
  VTK promoted those Float32 values to Double. Original 18398/29366 retained.
- Coffee C accepted event 9 is verified contact-free under its original grounded
  diagnostic and event 10 refused. The stored local state is mapped by the exact
  existing translation `[0,-1.6301633051396203, 0]`, and equals the receipt's
  `lastAcceptedSourcePosition`. Event 9 end yaw matches event 10 start yaw. The
  rejected proposed end is **not** substituted. Historical swept evidence is
  retained; a new static VTK query at the saved state is explicitly unknown.

Neither scene establishes calibrated camera-to-mesh localization. Source poses
are authored camera-derived anchors, not measured wearer-body poses. Source
frame mapping is a reproducible diagnostic contract, not physical calibration.

## Body, ground and numeric differences

Unchanged released adapter: 0.45 × 0.30 × 1.60 m body, separate 0.15 m horizontal-axis
margin, 15° climb/slide thresholds, 0.002 m controller offset, no autostep/snap,
no dynamic impulses. Full KCC cuboid includes the lower 2 mm omitted by the old
VTK query. This distinction appears in **every output row**. `computedGrounded`
is never promoted to support or 15° walkability. The 0.002 m controller offset is
additional numerical separation, not a replacement margin or lower exclusion.

`FIX_INTERNAL_EDGES_TWO_SIDED` can merge exactly duplicate vertices and reindex;
the unchanged comparator verifies every imported triangle ordinal/XYZ/winding
and retains mapping hashes. It does not create missing geometry. The analytic
fixture set showed no proposed-movement difference between flags; this test
asks whether those flags differ on the unchanged real meshes.

## Bounds and execution admission

Source prepared only; independent review, publication and root admission are
required. One CPU, 120 CPU seconds, 180 wall seconds, 1 GiB observed RSS, 16 MiB
output; Node old space 256 MiB. Same managed sandbox, sanitized environment,
scoped Node permissions, no namespace changes, process-group retirement and
before/after hashes. No hard network-airgap claim, no GPU, no installation.
The full package remains separately pinned outside Git. Private user scans are
not used or uploaded; only already-authorized public research data is consumed.

Reproduce source data with stdlib, into a **fresh** directory:

`python -I -B research/rapier-real-room-source-20261030/materialize.py --out <workspace>/rapier-real-room-inputs-001`

The prepared exact data directory already exists locally with its SHA-pinned
receipt. Eight stdlib preparation checks passed; those are not controller tests.
No JavaScript import or WASM initialization has occurred for this experiment.
After separate review/publication/admission:

`env -i PATH=/usr/bin:/bin LC_ALL=C HOME=/nonexistent PYTHONDONTWRITEBYTECODE=1 /opt/codex/runtimes/codex-primary-runtime/dependencies/python/bin/python3.12 -S <repo>/research/rapier-real-room-source-20261030/run_aggregate.py --admitted-source-commit <verified-published-HEAD>`

Use `-S`, not `-I`, for the pinned sibling guard helper. Exact work root is
`rapier-real-room-attempt-001`; it must not exist. Failure/partial records stay
preserved. There is no automatic retry, permission expansion or threshold tuning.

## Provenance and licenses

Rapier JS 0.21.0/core 0.36.0 official upstream remains Apache-2.0; the copied license
and original loader are unchanged. See the published analytic source packet for
full source evidence, hashes and upstream licenses. Public MuSHRoom source data
is CC-BY 4.0; attribution:
https://github.com/TUTvision/MuSHRoom and https://zenodo.org/records/10230733 .
Raw geometry/buffers/log archives stay local; this publication contains source,
small deterministic materialization receipts, hashes and explanatory text only.

All current selected deltas meet the frozen 2.5 cm bound. The worker rejects an inadmissible inventory rather than dropping oversized rows or inventing replacements.
