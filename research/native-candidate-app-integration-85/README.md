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

### Second exact-commit Apple run: dependency fetch failure

Run [40564108510](https://github.com/mischa23v/blind/actions/runs/40564108510),
commit `1c53f27b2a3b9497bec269af1fd9a843d6fe7600`, **passed the actual local host
SwiftPM graph, all83 existing host fixtures, actual iOS Simulator SwiftPM graph,
and app patch check/application**. It failed the explicit GRDB resolution command
(exit74,38.39s): the full-history fetch reported114,085objects, reached123.25MiB,
then `fatal: fetch-pack: invalid index-pack output`. Both app flag compile phases
were **not reached**. All seven original bounded receipts are retained under
`evidence/run-40564108510/`.

The receipt reports no direct parent file-limit signal or exceeded scratch cap;
a child index-pack hitting the inherited128MiB cap is plausible but **not proven**
by the available tail. No cap is increased and no fetch error is suppressed.
Instead, the corrected resolver first makes a bounded shallow bare clone of only
`v7.11.1`, requires the peeled tag and HEAD to equal the already-pinned revision,
then supplies a process-local Git URL rewrite from the canonical dependency URL
to that verified seed. SwiftPM still resolves the unchanged exact lock and actual
source; the checked-out HEAD and resulting lock are verified afterward. This is
an **exact shallow-seeded resolution variant**, not a pass of the original
full-history fetch. No global Git configuration, application dependency manifest,
version constraint, cap or algorithm is changed. If the runner does not honor the
scoped rewrite or the bounded seed fails, the stage fails rather than falling back
to arbitrary source or claiming the app compiled. This correction awaits its own
exact-source Apple run.

### Third exact-commit Apple run: app build-service crash

Run [40566037160](https://github.com/mischa23v/blind/actions/runs/40566037160),
commit `316e112136c0dfbee8baad709d9069bed5a1d39f`, passed the real package graphs,
83host fixtures, shallow exact-tag seed, canonical locked GRDB resolution and
post-resolution revision verification. The first flag-absent app build failed
(exit65,8.38s) at build-description creation: Xcode reported that its build system
crashed and explicitly instructed “Build again to continue.” No source compiler
error or crash-report exception cause is established by the retained tail. The
flag-enabled app build was not reached. The original nine receipts are preserved
under `evidence/run-40566037160/`;334,596,833 bytes scoped scratch and no direct
parent file-limit signal, timeout or exceeded scratch cap were reported.

The harness now preserves the first failure and allows **one identical-command
retry only for that exact retry-directed service-crash marker**, exit65 and
non-cap/non-timeout conditions. It does not retry source errors, relax limits,
delete caches, change SDK/build settings, or claim the first attempt passed.
A persistent failure remains a failure. Recent matching macOS build-service
DiagnosticReports are summarized on each failure (first256directory entries,
at most6reports,2MiB input per
report; exception/termination fields only, no raw report upload). Missing or late
crash reports are inconclusive. Those summaries can distinguish an internal service
failure from an indirect limit signal on a later run without guessing now.

#### Retry classifier hardening

Retry admission inspects the **complete app build log up to4MiB**, not just its
last35lines; a larger/incomplete log refuses retry. Exactly one standalone known
service-crash error line is allowed. Any other error/fatal diagnostic line,
observed child SIGXFSZ/SIGXCPU/EXC_RESOURCE (including Darwin signal numbers24/25),
parent termination, timeout, file-limit or scratch-limit evidence refuses retry.
The diagnostic collector returns its summary to this decision; it is not merely
logging evidence after making the choice. Absent/unparsed reports remain
**unknown**, not proof that child resource limits were not involved. That unknown
is explicitly recorded in a separate retry-decision summary. The same-command
single retry and original failure receipt remain unchanged.

`python3 research/native-candidate-app-integration-85/tests/retry_policy.py` runs
17pure Python policy fixtures: exact-marker admission, mixed compiler/linker/fatal
error refusal, child file/CPU/resource termination, parent limits/timeouts, missing
or duplicate markers and incomplete logs. These are harness-policy tests, not
Swift, Apple build, crash recovery or app execution results.

Three additional collector-to-policy fixtures create real fake IPS files with
numeric-only SIGNAL24/25 metadata, execute the collector, round-trip its serialized
summary and assert retry refusal. A symlink fixture asserts that a matching report
name pointing outside the diagnostic directory is skipped and leaves evidence
unknown. The collector classifies only raw allowed exception/termination metadata
before string conversion or truncation, retains the boolean observation, skips
symlink entries and uses `O_NOFOLLOW` for reads to reject a symlink swap. These
20local Python fixtures do not execute Apple's build service.

### Fourth run and bounded planning-only comparison

[Run 40571313055](https://github.com/mischa23v/blind/actions/runs/40571313055)
at `0babd78` passed both package graphs, 83 host synthetic fixtures, patch checking
and exact dependency resolution. Both the flag-absent build and its one allowed
service retry failed during `CreateBuildDescription`, before an app compiler
error. The bounded crash-report collections were empty. Resource-limit cause is
still unknown. [Verified receipts](evidence/run40571313055/README.md) preserve both
failures; neither is an app pass.

The next workflow mode is `--planning-comparison`, not another identical retry.
It requires the installed Apple `xcodebuild -help` to document `-dry-run` as doing
everything except running commands. If that primary tool capability contract is
missing or ambiguous, the comparison refuses to run. The help output itself is
bounded and the matched line is retained. This capability has not been verified
on Apple for this new diagnostic yet.

After the same actual package graph checks and exact dependency resolution, the
harness temporarily reverses the proposal only in its disposable checkout. It
verifies the original NavigationModel and project hashes and absence of the new
bridge, then plans the unpatched app. A `finally` block restores and verifies all
three proposed source hashes. If the first arm did not hit a resource/timeout or
harness failure, it plans the proposal in a separate fresh derived-data directory.
The two commands differ only in that directory. Both retain the existing SDK,
flag-absent configuration, environment, one job, exact dependency and original
128 MiB file/300 CPU-second/2 GiB stage-end scratch limits; each planning command
has a tighter 180-second wall timeout. There is no automatic retry of either arm,
no fallback to a real build, and no changes to production source or runtime gates.

`PLANNING_COMPARISON.json` records each executed arm, its source hashes and receipt,
including failures. A planning pass is not compilation, linking, app execution,
or device acceptance. Both failures would point toward a broader harness/tool
problem; baseline success plus proposal failure would isolate the added graph as
a trigger under this harness, not prove an underlying Xcode defect. Fixed arm
order and shared dependency/host caches remain explicit confounds. A successful
comparison still leaves the actual two-configuration app compile proof open.

Portable verification: 54 pure planning-policy/transaction checks exercise the
installed-help gate, command equivalence, exact old compile-command preservation,
resource stops, and byte-identical restoration after failures. Existing 20 retry
and collector checks remain passing. These are Python fixtures, not Apple runs.

Independent review hardened the cleanup and continuation boundary before Apple
execution. The mutating reverse is now inside the protected try/finally region.
Three bounded original source byte arrays and modes are captured first; cleanup
atomically restores them directly, without depending on a shared runner that may
reject commands after detecting a pre-existing scratch cap. This changes no build
limits and launches no cleanup build. Any restoration failure is recorded and
fails closed before the second arm. Injected post-execution reverse failures and
atomic-restoration failures are covered by portable fixtures.

Before a second planning arm, the harness now inspects the complete baseline log
up to 4 MiB plus its receipt and crash summaries for resource signals. Missing,
unreadable, symlinked or oversized logs stop the comparison. Explicit child
SIGXFSZ/SIGXCPU evidence cannot disappear merely because no IPS report was found.


### Planning-capability probe after run40574538504

At commit `65906d1`, both package graphs and 83 synthetic fixtures passed again,
but the installed-help guard rejected the available text before either planning
arm ran. The retained help receipt contains only the generic final help lines,
not the option section, so the exact reason (absent option versus wording/parser
mismatch) is not established. No baseline/proposal comparison was performed.

The next workflow is deliberately `--planning-capability`: it runs only bounded
Apple tool/version/source preflight and `xcodebuild -help`, with no dependency
resolution, graph build, patch application or app command. It preserves the entire
help output only when it is within256KiB, its hash, exact relevant option excerpts,
and the acceptance/rejection reason. The same capability check has moved before
all expensive graph work for future `--planning-comparison` calls. The existing
parser is not relaxed without observing the primary installed-tool evidence.
A successful probe means the help was inspected, not that a build passed.

### Installed help result and bounded actual-build control (2026-10-27 20:13 UTC)

Help-only run `40575670457`, commit `a22b8fdfd5fa41070cce6b234b7a044a1ff8476e`, completed successfully **only as a metadata probe**. Its complete 24,847-byte installed Xcode 27 help is preserved under `evidence/run40575670457/`, together with the receipt, rejection diagnostic and verified artifact identity. It documents no `-dry-run` or equivalent build-planning-only command; `-showBuildSettings` and `-enumerate-tests` are not substitutes. The prior rejection was not a parser wording mismatch. This is not an app build pass. No undocumented option will be tried.

The next proposed workflow uses `--build-control`: one actual unpatched app build followed, only if complete logs/receipts show no resource stop and exact source restoration succeeds, by one actual proposed **flag-absent** app build. Each uses the previously published 600-second wall budget, unchanged inherited CPU/file/scratch limits, one job, exact pinned GRDB dependency, separate derived directories, the same environment and all existing code-signing/network-resolution restrictions. No automatic retries. This reuses the independently reviewed bounded source-byte restoration and full baseline resource-log gate. Both arms remain disposable CI-only; no app launch, signing, install, symbol acceptance, flag-enabled build or runtime activation is implied. Missing/incomplete baseline logs and resource signals suppress the second arm. An ordinary exit65 can permit the second arm solely to distinguish whether the proposal is necessary to reproduce the crash.

`BUILD_CONTROL.json` records exact source hashes, commands/receipts, budgets and whether both builds completed. Fixed order and shared dependency/host caches are explicit confounds; a difference is diagnostic, not proof of the crash mechanism. Original service-failure evidence remains unchanged. The control itself is **not yet executed**. Local Python-only transaction/policy fixtures pass 96 checks; retry/collector fixtures pass 20. No Apple commands were run locally.

### Normalized native-app invocation proposal (20:20 UTC)

The actual control above failed in **both** arms; see `BUILD_CONTROL_DIAGNOSIS.md` and the preserved `run40576517541` receipts. The selected `--build-control` now prepares a **bundled harness compatibility change**, not an isolated-cause experiment: use the existing `tools/ci/native-apple.sh` minimal app invocation semantics, retaining one job, exact resolved dependency controls and all existing limits. Remove the host-package SDKROOT from a copied app environment only after both package graphs; app dependency resolution and both app builds use that copied environment. The host SwiftPM environment remains unchanged. Keep CODE_SIGNING_ALLOWED=NO; omit the extra SDK/architecture/Swift/debug-dylib overrides. No retry, budget increase, runtime activation or source/PBX correction. A passing result would establish compatibility for this changed harness, not identify which override caused the old failures. This variant is not yet executed.106 pure command/environment/control checks pass locally; no Apple execution was performed locally.
