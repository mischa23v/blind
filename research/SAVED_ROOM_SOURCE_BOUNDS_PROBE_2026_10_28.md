# Saved-room source-bounds witness — 2026-10-28

## Verified progress; next failure is not yet diagnosed

The public reports from [run 40706611490](https://github.com/mischa23v/blind/actions/runs/40706611490)
at `43e33d4b8a59a2a0431ab514c8821fabcf622a08` verify the binary-plist repair:
Hallway2 has 13 metadata entries/13 meshes, Bedroom3 has 11/11, and both have zero
unmatched or unknown-feature meshes. Both adapters then fail
`sourceGeometryMismatch`. This is metadata/identity progress, not passing route,
guidance or collision evidence. The observation was made from the complete early
public diagnostic reports, not claimed as a terminal whole-workflow result.

The existing attachment contains no exported vertex coordinates, so it cannot
identify the first failed source-bounds predicate. No positive geometry repair
is justified by that attachment alone.

## Source inspection and hypotheses

`verifySourceBounds` transforms each exported world vertex back through the
original feature's rigid inverse. For each axis, it requires the result to lie
within the original polygon's local min/max, or +/- half the original dimensions
when there is no polygon, plus the existing Float32 arithmetic allowance.

The first original walls in both fixtures have `dimensions.z == 0`; all 13
Hallway2 surfaces and all eight Bedroom3 surfaces have zero source depth. An
exported nonzero wall thickness would therefore violate the Z-plane predicate,
even if the source plane and exported wall were otherwise aligned. A scene
origin/scale/transform change could also violate it. **Neither hypothesis is
proven without actual export coordinates.**

The column-major inverse in `NativeCameraTransform` was inspected at the exact
native source. Its rigid rotation transpose and translated inverse are correct.
192 independently calculated public-source bounding-corner forward/inverse
roundtrips remain inside the current numerical bound. That rules out a simple
source-corner/rigid-inverse inconsistency in this preparation; it is not a test of
Apple's exported coordinates.

Apple describes [CapturedRoom surfaces](https://developer.apple.com/documentation/roomplan/capturedroom/surface)
as 2D areas and their transform as position/orientation in the scene. The
[mesh export option](https://developer.apple.com/documentation/roomplan/capturedroom/usdexportoptions/mesh)
provides polygonal mesh output; those pages do not establish a numeric exported
wall thickness or permission to treat it as measured physical thickness.
[Model I/O globalTransform](https://developer.apple.com/documentation/modelio/mdltransformcomponent/globaltransform%28with%3Aattime%3A%29)
concatenates the mesh's ancestor transforms into the asset-root coordinate
space. That does not by itself prove equality to the original captured-room
world frame. The next witness records those transforms rather than guessing a
recentring offset.

## Narrow instrumentation, not a relaxed validator

- Production's existing calculations and comparisons are factored into
  `SourceBoundsAssessment`. `verifySourceBounds` still throws on exactly the
  first failing axis. Inverse math, source lower/upper bounds, scale term,
  `64 * Float.ulpOfOne * max(1, abs(scale))` allowance, and inclusive boundary
  comparisons are unchanged. No logging or diagnostic callback is added to the
  app. `originalFeatures` becomes internal so tests can use the same decoded
  Float32 source values instead of different raw-JSON arithmetic.
- The existing **test-only** inventory adds an optional `geometryProbe` only
  when the real adapter returned `sourceGeometryMismatch`. It records one first
  failed known-feature mesh/vertex/axis and its below/above predicate, original
  bounds, numerical epsilon and positive residual outside the original bound.
  It does not accept, move, flatten, inflate or omit any geometry.
- The witness includes original dimensions/transform/local and world bounding
  boxes; the exported failed mesh's world and original-feature-local bounding
  boxes; one mesh-local/world/source-local vertex; asset up axis; and mesh
  static-local, mesh-global, parent-global and root-global transforms. It reads
  all vertices of that one failed mesh to compute bounds, but emits no vertex
  list, indices or triangles. It stops geometric probing after the first failure.
- Admission is still the exact original public Hallway2/Bedroom3 fixture SHA
  guard before decoding/export. The node must be one of the first 128 sampled
  inventory nodes and resolve to a UUID from the original public feature list.
  Total inspected vertices across preceding meshes and the failed mesh are at
  most 200,000. Buffers/finite coordinates are validated before reading/output;
  coordinates and matrix entries are bounded by 10,000. The whole attachment
  remains limited to 131,072 bytes. Export files are temporary and removed.
- `sourceEncoding` is fixed to `capturedRoomFloat32`: source dimensions,
  transforms and polygon corners are Apple's decoded Float32 values copied to
  Double. The collector can bind them exactly to Float32-rounded original public
  JSON. `geometryProbeFailure` is a separate content-free existing failure code
  and is mutually exclusive with a witness. Prior reports without either field
  retain their original meaning.
- A sourceGeometryMismatch result must retain a witness (or explicitly fail the
  probe check); checks execute after attachment retention. The changed-original-
  SHA regression verifies that no geometry witness is produced on rejected input.

## Checks performed and pending

- Verified the two native inventory reports' 13/13 and 11/11 identities and the
  new failure, then inspected the source bounds/inverse and primary platform API
  descriptions. No exported vertex value was available or inferred.
- **192 public-source corner roundtrips passed** using independently calculated
  Float32-rounded source matrices in Python; no native export or localization
  claim is attached to that result.
- **14 lightweight source contracts passed**, including unchanged tolerance and
  scale, shared first-axis predicate, diagnostic-only failure gating, public-SHA
  admission, node/vertex budgets, exact originalFeatures reuse, unchanged
  attachment cap, rejection guard and no production logging.
- Added `testSourceBoundsProbeRetainsZeroDepthAndExactRoundoffPredicate`: tests
  the zero-depth plane, exact inclusive epsilon boundary and nextUp rejection,
  +/- 5 cm still rejected, and first-axis ordering. **Not run natively here.**
- Collector changes are separately owned and coordinated for the precise
  optional schema, original-fixture identity/source binding and finite numeric
  limits. A fresh Apple build/run must generate and validate the witness before
  any geometry adaptation is proposed.
- No Swift compiler/Xcode/Apple SDK is available in this executor. No install,
  new workflow, private upload, push or physical-guidance enablement occurred.

Next: inspect the first retained native vertex/predicate/bounds and transforms.
If exported wall thickness is actually demonstrated, separately review how the
2D source surface and exporter-provided solid should be validated without
misrepresenting generated thickness as measured clearance. Do not fix this by
widening epsilon, accepting an unknown coordinate frame or dropping mesh faces.
