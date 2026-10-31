# Stage82 — isolated ARKit mesh snapshot adapter candidate

No app/session wiring, movement authorization, localization or device execution.
Fresh implementation, not restored truncated history sampling. The existing
`NativeARObservationAdapter.sampleMesh` is a layout reference only; no sampling,
remapping or partial-prefix geometry from it is reused.

## Ownership and evidence contract

`ARKitMeshAdapter82.capture` runs synchronously within the serialized owning
anchor callback. It reads native descriptors and preflights positive counts,
checked arithmetic, complete spans, formats, triangle count, classification count,
vertex/face limits and combined input/decoded allocation budgets **before** any
`MTLBuffer.contents()` or buffer copy. Only CPU-accessible `.shared` storage is
accepted. Required geometry and present classification are complete or the entire
revision is an explicit `unknownGap` with owner metadata. Missing optional
classification remains missing; unknown class values retain decoder diagnostics.

Copying retains each source's referenced prefix (including offset and padding),
not the entire Metal allocation, and never truncates faces to satisfy a budget.
ARGeometrySource vertices use `.float3`, three components and their own offset and
stride; classification uses `.uchar`, one component and its independent layout.
ARGeometryElement triangles have packed 2/4-byte scalar indices, three per primitive;
there is no invented source offset/stride property. Normals are not needed/copied.
Immutable Swift value buffers are all that escape. No task/closure queues anchors,
Metal buffers or borrowed pointers. A buffer copy is not a claim that arbitrary
concurrent producer mutation is safe: serialized callback ownership and native
buffer validity must be established by integration/device review.

After callback return, `MeshSnapshot82.decode` may run on a worker using only owned
buffers. It calls the existing **stage81 decoder**, not duplicate geometry logic.
Local coordinates and the column-major anchor transform remain unchanged; the
future downstream owner applies the transform exactly once. Decoder errors become
unknown gaps, never empty/successful coverage or stale previous geometry. The
future lifecycle owner MUST invalidate the rejected revision's prior coverage and
handle removal, session reset, revision ordering and generation changes. This
stateless adapter does not claim to perform those lifecycle operations.

Session UUID, positive generation and revision are explicitly supplied by the
owner. Receipt uptime is finite/nonnegative and refers to callback receipt, not
mesh capture or freshness; `captureUptime` is always nil. AR anchor callbacks do
not prove a capture timestamp. No frame matching, tracking state, map binding,
room identity, localization, capture wall date or observation age is invented.

Budgets reuse stage81 defaults and logical accounting. They are per revision,
not global queue/RSS limits. Peak memory includes copied and decoded buffers,
allocator overhead and concurrent work. **Phone copy latency is unmeasured**.
Before runtime wiring, establish callback queue ownership, aggregate admission,
bounded latest-revision worker queues, hazard-first scheduling and main/hazard
callback latency under real phone load. Large synchronous copying can block the
producer even after byte preflight; caps alone do not prove hazard priority.
No copying on the main/hazard callback is authorized by this source increment.

## Upstream/API evidence

- Apple ARKit (system SDK, Apple platform terms, not a copied third-party algorithm):
  https://developer.apple.com/documentation/arkit/argeometrysource
  https://developer.apple.com/documentation/arkit/argeometryelement
  https://developer.apple.com/documentation/arkit/armeshgeometry/classification
  https://developer.apple.com/documentation/metal/mtlbuffer/contents()
- APIs reviewed 2026-10-27; exact compile target is Xcode27.0/iOS Simulator SDK27.0,
  arm64 iOS17 deployment. `ARGeometryElement` official docs specify count as
  primitives and the count × indices-per-primitive × bytes-per-index layout.
  Source format/layout properties match the existing native app adapter. Some
  Apple doc Markdown endpoints were unavailable to the web fetcher; actual SDK
  compilation is the remaining API acceptance gate, not a claimed local result.
- Existing stage81 `MeshBufferDecoder.swift` is pinned by SHA-256. Parent reports
  its exact published a2423071aa8804e31b881585d28dca04dc319d1b Apple run
  40542574937 succeeded; this does not validate stage82 native capture.

## Verification and publication handoff

`check_static.py` checks source pins, Python syntax, workflow proposal guards and
non-execution boundaries. It is **not Swift execution**. No local Swift installed.
`apple/ci.py` reuses stage81's bounded serial command runner, separately builds its
public module, builds stage82 with testing visibility and runs synthetic descriptor
and owned-buffer tests on macOS. It then builds both modules for iOS Simulator,
including the **actual ARKit/Metal source**, without launching a simulator/device.
Tests cover padding/unaligned offsets, both index widths, complete snapshots,
caller mutation isolation, transform/local-value preservation, classifications,
budget boundaries, malformed/overflow descriptors, context and decoder failures.
They do not construct or execute ARMeshAnchor, Metal or ARSession callbacks.

`apple/workflow-proposal.yml` is inert here. Parent may publish it as
`.github/workflows/arkit-mesh-adapter.yml` on the existing authorized review branch.
It uses the established pinned actions/read-only permissions/public repository
checks and short receipt retention. No workflow, decoder, app or shared tracker
outside this directory has been modified by this stage. Root owns tracker updates,
publication and exact-commit Apple verification. Host tests/native compilation and
all device/resource/hazard acceptance remain pending for this source.
