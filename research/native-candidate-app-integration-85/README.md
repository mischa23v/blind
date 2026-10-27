# Stage85 — default-off app build integration proposal

This increment supplies **actual local SwiftPM products** for the existing source
chain `MeshBufferDecoder81 → MeshSnapshot82 → MeshCandidateIngress83`, with the
existing stage75 `BlindRoomMesh` native package. No algorithm is copied. The two
ARKit-only source files are conditionally compiled with `os(iOS) && canImport(ARKit)` so the
same packages can build on macOS; simulator builds include the actual ARKit seam.
The deployment floor remains iOS17/macOS13. The mesh-only graph uses local
dependencies; the optional app compile resolves the existing exact GRDB dependency
in disposable Apple CI as described below.

## App proposal, not activation

`app-integration.patch` is reviewable, not applied to the shared app. It adds the
bridge source, PBX local package/product/source references and existing
NavigationModel callbacks. `proposal/MeshCandidateDiagnostics.swift` is the exact
new bridge in the patch. Root owns application, publication and exact-source CI.

Every bridge declaration, reference and callback is under
`#if DEBUG && BLIND_MESH_CANDIDATE_DIAGNOSTICS`. Normal project build settings do
not define this symbol. Even an explicitly symbol-enabled Debug build starts
`enabled = false`, allocates no mesh owner before an explicit developer-only
`setMeshCandidateDiagnosticsEnabled(true)`, and never persists that opt-in.
The PBX dependency is linkable in normal builds but no diagnostic bridge API is
compiled there; runtime/native initialization must not be inferred from linking.
No UI, routes, route requests, speech, haptics, images, network or persistence are
introduced. No new ARSession, delegate replacement, queue reassignment or geometry
configuration is introduced. NavigationModel remains the existing main owner.

**Live copying is refused unconditionally**, not hidden behind fake gate booleans.
Added/updated mesh callbacks count bounded scalar events and stop the owner to
fence any old result; they never call ingest/capture, inspect geometry or queue an
anchor. Removal passes only the exact UUID and receipt uptime to the existing
owner. After a refused update the owner is stopped and may reject removals: this
is conservative diagnostic behavior, NOT a functioning live mesh pipeline.
Counters saturate; only three event categories are retained. Receipt time is not
capture time. No frame/anchor history or candidate result is kept by the bridge.

Before any future copying: establish valid native producer ownership under the
actual existing main callback, measure copy/main/hazard latency on the phone,
review bounded admission and device memory, and obtain the separate device gate.
Do not move the complete NavigationModel delegate to a background queue, replace
it, construct another ARSession, or turn this diagnostic seam into movement
approval. Existing stage83 worker ownership constraints are not satisfied merely
by compiling this app proposal.

## Lifecycle placements

- Launch: fresh diagnostic epoch before `session.run(...resetTracking...)`.
- Camera stop: stop at entry before RoomPlan cancellation and `session.pause()`.
- Tracking loss: stop at the top of frame callback, before existing throttling.
- Watchdog: stop for >0.5s callback loss before the later expiry and camera-recovery
  branches. Existing early retry/automatic-recovery calls (and a possible launch)
  precede this hook; their ordering is unchanged.
- Error/interruption/end of interruption: stop before existing recovery actions.
- Scan start: fresh epoch then stop immediately before `places.startScan`.
- Scan finish: fresh stopped epoch even if not running; if restarting, another
  fresh epoch immediately before `session.run`. Two distinct diagnostic epochs
  here deliberately fence both completion and restart.
- Ordinary stop/reset reuses the **same** stage83 owner and its outstanding slots.
- Explicit `discardMeshCandidateDiagnostics(completion:)` is terminal. It calls
  acknowledged stage83 discard; the bridge cannot allocate a replacement owner.
  This is not wired to ordinary camera pause, nor claimed to erase camera/OS or
  caller-owned memory. Completion is asynchronous; it is not a main-thread callback.

## Verification and outstanding evidence

`check_static.py` verifies patch applicability, source pins, compile guards,
no-copy bridge boundary, launch-before-run and tracking-loss-before-throttle source
ordering in the reconstructed proposal, other hook presence and the local package
chain. Static
checks are not Swift compilation, callback execution or safety evidence.

`apple/ci.py` / `apple/workflow-proposal.yml` are bounded serial Apple build
proposals. They build the real SwiftPM graph for host and iOS simulator and execute
existing synthetic stage83 host fixtures. The optional app-proposal mode applies
the patch only in the disposable CI checkout, compiling Debug flag absent then
present; no app launch, simulator launch, signing, install or deployment occurs.
The compile-enabled variant still has runtime opt-in false and no copying.
The existing native SwiftPM compatibility build system is used; this is not a
claim that the default SwiftBuild backend passes.

This Linux host has no Swift toolchain (`command -v swift` returned no path).
No install or local Swift build was attempted. Apple compilation, real callbacks,
copy latency, memory, hazard priority and device safety remain pending until their
specific evidence exists. The prior stage75/stage83 acknowledgement publication
`eb0fc673a72d1c9003cbceb5ef0f68c60e4f5563` awaiting CI is not treated as a pass here.

### Clean app dependency resolution and build bounds

The app depends on BlindMemory → GRDB; the preceding mesh-only package graph does
not resolve that dependency. Before the optional app build, the CI runner seeds a
disposable version2 `Package.resolved` containing only the already-reviewed GRDB
7.11.1 revision `b83108d10f42680d78f23fe4d4d80fc88dab3212` from the selected upstream
evidence. It runs a bounded explicit resolution with
`-onlyUsePackageVersionsFromResolvedFile`, then requires the exact lock identity,
URL, version, revision and checked-out Git HEAD before either app build. An
unexpected pre-existing lockfile or any additional/changed dependency fails closed.
Both subsequent builds retain `-disableAutomaticPackageResolution`; no default
upgrade is allowed. Resolution can require network access on the Apple runner.

The app commands retain the shared runner's **128 MiB per-file limit and 300-second
CPU limit**, with explicit 600-second app-command wall timeout and 2 GiB stage-end
scratch accounting. A sparse CAS/cache file exceeding that per-file cap may fail
the app build; the receipt must report that failure rather than calling it a
compile pass. These limits are not live disk/RSS quotas, phone resource evidence,
or runtime-memory proof. No cap has been silently raised.

### First exact-commit Apple run: host platform condition failure

Run [40562846752](https://github.com/mischa23v/blind/actions/runs/40562846752),
commit `929be18186ca9290d5ac64dd3ad01060dbb10bad`, failed the first
`host-swiftpm-graph` command (exit1;22.73s). The actual macOS27 SDK admitted the
`canImport(ARKit)` branch and attempted to compile the iOS-native mesh adapter;
the retained compiler tail reports contextual `.uchar`/`.shared` failures. The
bounded tail does not retain earlier diagnostics, so it is not claimed to identify
every compiler error. The intended host product must exclude this iOS-only seam,
not infer mesh API availability merely from module importability. Both native
seams now explicitly require `os(iOS) && canImport(ARKit)`. The iOS Simulator
branch still compiles the actual native source; no SDK errors are suppressed.

Receipt evidence:70,212,973 bytes scratch, largest file10,921,328 bytes; no timeout,
file-limit signal or exceeded scratch cap. No cap change was made. Host fixtures,
simulator graph, exact GRDB resolution and both app compile flag phases were
**not reached**. The correction requires a new exact-source Apple run; local
static success is not a build pass. The original bounded receipt is retained in
`evidence/run-40562846752-host-swiftpm-graph-receipt.json`.
