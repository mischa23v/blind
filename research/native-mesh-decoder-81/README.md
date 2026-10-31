# Native mesh byte-buffer decoder — fresh stage81 candidate

Fresh implementation from published review-branch source, not a restoration of lost
work. **No prior 49-fixture result is reused or claimed.** This is an isolated
adapter candidate: no app, ARSession callback, Metal access, package75 integration,
speech, guidance, merge or deployment change.

## Contract

`MeshBufferDecoder.decode` accepts immutable owned `[UInt8]` snapshots with explicit
format/count/offset/stride, a positive revision token and a column-major anchor
transform. Bytes are little endian. Vertex count counts float3 records; index count
counts individual UInt16/UInt32 scalars (three per triangle). Nonzero offsets,
unaligned records and padding are supported without pointer rebinding/alignment
assumptions. A capture adapter must snapshot bytes under valid producer ownership;
this decoder cannot make a concurrently changing Metal buffer safe.

All required geometry is accepted together or rejected with an error; partial
vertices/triangles never escape. Index bounds are checked before issuance, including
UInt32 values above 65,535. Vertex components and all transform entries must be
finite. The affine bottom row must be exact; orthonormal proper rotations have a
1e-5 numerical tolerance, not a measurement uncertainty allowance. Local vertex
values and transform bits are preserved; the downstream owner applies the transform
**once**. Package75 already owns that conversion and remains only a candidate; this
increment neither calls it nor applies its conversion ahead of it.

Optional classification accepts UInt8 labels 0...7, retaining absent/malformed/
unknown-value diagnostics separately. A malformed label buffer is ignored in full,
not used as a partial per-face truth. Labels (including floor) never prove support,
free space, complete coverage or current clearance. The result exposes authority
false and coverage unknown; its initializer is unavailable to external clients.

Checked arithmetic validates descriptor end positions, count multiplication and
allocation accounting before output allocation. Defaults cap 200,000 vertices,
100,000 triangles, 16 MB input snapshots and 8 MB decoded logical allocation.
Accounting is 12 bytes/vertex, 4 bytes/index and a conservative 64 bytes/face for
optional labels/diagnostics. Exact caps are inclusive. This is **not** a hard RSS
cap: input snapshots already exist, arrays/allocator have overhead, transforms and
small fixed metadata are excluded, and callers can explicitly configure limits.
Revision ordering, session/generation/anchor identity, tracking freshness, removal,
eviction and revocation remain the downstream lifecycle owner's responsibility.
A validated token is not proof that its producer supplied all observed geometry.

## Provenance and evidence

This is minimal original decoding/validation glue over the documented Apple
ARGeometrySource / ARGeometryElement / ARMeshGeometry representation, not a new
SLAM, recognizer, map, navigation algorithm or buffer-capture implementation.
Platform references:
- https://developer.apple.com/documentation/arkit/argeometrysource
- https://developer.apple.com/documentation/arkit/argeometryelement
- https://developer.apple.com/documentation/arkit/armeshgeometry

The existing published package75 local-coordinate/transform contract is the reuse
boundary. No upstream source is copied and no new third-party code/model/data
license is introduced. References were reached on 2026-10-27; the web tool returned
JavaScript shells and could not fetch their Markdown representation. API/platform
compatibility must therefore be established by Apple compilation and later capture
integration, not claimed from this documentation lookup. Xcode27/SDK27 are pinned
by the existing workflow convention; actual toolchain version is recorded in CI.

## Verification

`python3 research/native-mesh-decoder-81/check_static.py` checks Python syntax,
workflow limits/permissions/branch, source pins, fixture markers and scope. These
are static checks, **not Swift execution**. The local container has no `swiftc`;
no installs, Swift build or fixture execution were attempted locally.

The additive `.github/workflows/native-mesh-decoder.yml` runs only on the same
review branch, public `mischa23v/blind`, with read-only contents permissions and
existing pinned checkout/upload actions. It builds an exported host Swift module,
compiles/runs a separate public-client synthetic fixture harness, checks that a
client cannot forge a validated result, and compiles the source for arm64 iOS17
Simulator with SDK27. No simulator launch, sensor access or app activation occurs.
Commands run serially, with per-command wall/CPU/file limits and stage-end scratch
accounting; workflow/job limits bound the overall run. The scratch check is not a
live disk quota or RAM limit. Only bounded JSON receipts are uploaded for three days.
`RESULT.json` is written only after every stage succeeds. Initializer rejection
must specifically diagnose access protection, not just an arbitrary compiler error.

Fixtures are entirely synthetic and newly authored, covering packed/padded/unaligned
vertices and indices, a high UInt32 index, multi-face padded labels, optional label
failures, finite/rigid checks, exact budgets, overflows and complete rejection of a
late-invalid component. Host execution and simulator compilation remain pending
until exact-commit GitHub Apple CI runs; device accuracy, buffer ownership, live
latency, localization, full physical coverage and supervised safety are unproven.
