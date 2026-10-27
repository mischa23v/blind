# BlindRoomMesh candidate package (stage75)

Reviewed candidate prepared for review branch `codex/recovery-hazard-order-20261027` only. Not an Apple pass. Source app native checks remain pending; no master merge, deployment, physical guidance, or device acceptance.

The portable FROZEN.json is unchanged historical evidence (including its original cache metadata pins). Publication omits build/cache files and rejected intermediate sources. APPLE_SOURCE_PINS.json is regenerated for the branch-only workflow and omits two cache metadata files. The historical INDEPENDENT_APPLE_WORKFLOW_REVIEW.json covers the original workflow, not these trigger/guard changes; independent workflow-only review is required before publication. No algorithm or portable source pin changed.

## Implemented

- Separate Swift package, iOS17/macOS13 minimum, CDetour C++11 target and public
  Swift candidate API. Pinned native sources match stage71 except header path.
  Explicit `-ffp-contract=off` is retained. No dependency on BlindCore or app UI.
- Packed owned anchor-local arrays and column-major ARKit-format transform
  conversion, exactly once to +Y-up metre coordinates. Rotation validation
  allows1e-5 numerical orthogonality/determinant error for Float32 transforms;
  prior1e-10 replay tolerance rejected ordinary Float32 rotations. This is not
  a spatial error budget or floor/pose correction.
- Session/generation and per-anchor revision ledger supports add/replacement,
  duplicate/stale/conflict, removal, eviction, incomplete and invalid events.
  Removal/truncation/invalid/overflow coverage remains unknown until reset;
  no omitted triangle certifies free space.
- Bounded mailbox: eight pending events/queries and900,000 queued scalar values
  per runtime. Existing ledger caps remain64tiles,256records,200,000vertices,
  100,000triangles. No global bound across arbitrarily many runtimes is claimed.
- Route revisions retire at ingress, including before queued native builds
  finish. Native work runs on one serial utility queue across package instances
  because the C adapter has global error text. Native handles never escape.
- Explicit body radius/height and session-local start/goal required. A new query
  revokes older goal/body snapshots. Tracking/hazard callers can invalidate or
  stop. Completion executes asynchronously outside the native queue. Callers
  must check `isCurrent` at use; immutable historical objects cannot be revoked
  after they have been copied by a consumer.
- Every output has physical authority false, world coverage unknown, independent
  raw-depth veto true. No raw-depth implementation, speech, haptic or motion API.

## Tested so far

`tests/main.swift` combines the unchanged55 geometry/native/reference checks
with32 portable lifecycle/mailbox checks. It uses the existing public real
Polycam-derived fixture (no new fixture copy) and separately built LinuxClang21
native library from the verified stage71 contraction variant. The last run
passed all87 checks. This verifies source behavior, not a built SwiftPM product
or ARKit execution. `PACKAGE_DUMP.json` confirms SwiftPM parses the manifest.
The final pinned rerun and independent review passed.

Build tests use standalone Swift compilation and existing shared module cache,
not a large SwiftPM rebuild. Native source geometry is unchanged. Source package
size is under2MiB including the temporary local test executable; no installs.

## Deliberate limitations

**This public package cannot yet reproduce the assisted three-lap tabletop exclusion.**
The public runtime does not yet accept tabletop exclusion updates. The reviewed
static exclusion helper stays internal for retained parity tests; there is no
public method that can silently clear a known exclusion. It supports only
session-local geometry, not building/floor registration, persistent maps,
relocalization, support certification or live obstacle clearance. The low-level
map can still propose a path through unknown coverage; output explicitly retains
that uncertainty and cannot authorize movement.

No callbacks are wired to NavigationModel. App producers must copy ARKit Metal
buffers safely, assign revisions, provide all anchor lifecycle events and fence
tracking/background/deletion before this can consume live data. Count checks
are not a hard real-time latency or total RSS guarantee; no phone benchmark
has been performed. Missing/overflow evidence can block useful completeness
until reset, deliberately rather than treating an incomplete room as clear.

## Prepared isolated Apple CI (not yet executed)

1. Add a dedicated public/read-only CI job for this package path, not old UI tests.
2. Build the SwiftPM product for macOS with the existingXcode27 runner; compile
   a separate client importing public `BlindRoomMesh` to check module visibility.
3. Run the87 portable checks against the package-built native object/library and
   preserved fixture, retaining strict1e-5 cross-platform reference comparator.
4. Unsigned iOS Simulator compile/link of the package and an adapter probe.
   No simulator sensor claim or deployment. Keep existing stage71 evidence.
5. Only after independent package/API review, modify the Xcode project generator
   and add the bounded ARKit capture adapter/runtime wiring. Existing app tests
   remain separate; no known failing hosted/UI test is hidden by this package.

Final standalone compile took4.03s; fixture run0.82s; maximum child RSS179,956KiB. These are Linux development measurements, not phone timings. The first frozen runner invocation resolved the swiftc symlink to swift-driver and failed before compilation; runner-failure-1 preserves that failure and old freeze. Keeping the swiftc invocation name fixed it; no package source or tests changed in that correction.


The prepared workflow is `apple/native-room-mesh-package.yml`, proposed root
path `.github/workflows/native-room-mesh-package.yml`. It triggers only its own
research package/workflow paths or dispatch, uses the existing public xcode-27
runner, read-only credentials and18-minute cap. It builds the actual SwiftPM
product, links/runs an ordinary public `import BlindRoomMesh` client, runs the
87 fixtures through a separate `@testable import` client linked to package-built
objects, then builds/links the Simulator product/client without launching it.
It does not edit NavigationModel, project generator, app tests or deployment.

A focused local Linux exported-module build passed the ordinary public client
and all87 imported-module fixtures. This is stronger than same-module source
compilation, but still not a SwiftPM product build or Apple package proof.
Apple CI uses the same native contraction-off package flags plus explicitO1.
Post-command512MiB scratch checks are not hard live RAM/system-cache caps.

Independent prepared Apple workflow review passed; execution remains pending.

## 2026-10-27 late offer-failure lifecycle correction (Apple execution pending)

The offer worker previously checked ownership before applying a packet but set
`gap` unconditionally on a thrown failure. A reset between those two points
could let retired work contaminate the replacement lifecycle. The catch now
commits through a locked lifecycle/session/generation fence. It intentionally
ignores ordinary query/event revision changes: a missed current-lifecycle event
must still leave delivery unknown. No public interface or physical authority
changes.

Five additional deterministic failure-commit checks exercise the exact internal
helper used by that catch: generation reset, session reset, ABA reset, current
failure after revision changes, and a later valid packet not clearing the gap.
The helper can only mark a matching lifecycle incomplete; it cannot fabricate
geometry or clear a gap. This avoids adding an injectable native worker or
public testing authority. These are commit-boundary witnesses, not execution of
a paused native-apply race. Existing invalid-packet coverage still exercises the
actual catch in the same lifecycle. The original 55 geometry and 32 runtime
checks remain unchanged; Apple CI requires those plus the five new checks.

Only current `APPLE_SOURCE_PINS.json` is updated. Frozen historical manifests,
receipts and results retain their original source hashes and are not evidence
for this change; the historical `run_portable.py` remains frozen-input-only.
No local Swift build or test was run for this correction. The existing isolated
Apple workflow must establish compilation/execution before a passing claim.
