# Review-branch publication note

Reviewed candidate only; not an Apple pass. Source app native checks remain pending. No master merge, deployment or physical guidance.

The app file uses the independently reviewed proposal with exactly one transport-added final LF removed; canonical baseline Git identity is verified. Original review/provenance hashes refer to original local copies, not the normalized app blob. The unchanged patch applies to the canonical public baseline. Evidence below is historical portable/component evidence; compiled binaries, module caches, private/raw data and intermediate rejected app copies are excluded. Reproduction commands describe the original local workspace, not a self-contained checkout test harness.

# Recovery hazard-ordering: corrected research-only patch proposal

Pinned repository: `mischa23v/blind`, commit `213dffa8fe983674bf1fbeec87b8335b87a9d5ce`.
`AGENTS.md`, required design/task context, NavigationModel, DepthSampler, HazardDetector and BodyCollisionWarning were fetched through the GitHub connector at that exact commit. Baseline files are evidence copies, not a checkout. No live app source, repository branch, external state or package75 was changed.

## Review correction (not an adopted app change)

The initial proposal is retained in `rejected-pre-review/` and **must not be adopted**. Independent review found its per-frame `journeys.breakTracking()` called the real runtime's `cameraRestarted()` and repeatedly retired pending clarification/output ownership. The original 25 stub assertions missed this. The corrected proposal withdraws journey authority **at each of the two actual recovery-entry assignments**, not on normal recovery frames. A successful `launch()` retains its existing reset behavior; explicit entry withdrawal also covers launch's early guard refusal. No `lastObservation` heuristic or inferred owner identity is used. Existing tracking-loss callback behavior is unchanged, so the claim is specifically no **new repeated normal-recovery-frame** restart, not elimination of all tracking-loss churn.

## Root cause and limits

The recovery branch at original NavigationModel lines 1213–1240 owns the whole callback rather than only saved-map matching. It exits before the depth sampler and both warning paths. Its automatic-recovery validation guard can also return **before** the original uncertainty publication. Consequently a mere move above the final return is insufficient: detection and publication must precede acceptance/rejection and furniture-history import.

This is a source control-flow defect, not a measured physical warning miss. `launch()` resets floor calibration, fixed mount, observation/session owners and route state. Calibration is disabled while awaiting a place. Thus the normal immediate restart/recovery state commonly cannot produce either existing depth warning. This proposal removes suppression of **otherwise admissible** warnings; it does not add new uncalibrated or camera-relative hazard sensing or solve recovery sensor coverage.

Both `HazardDetector.process` and `BodyCollisionWarning.assess` explicitly require normal tracking. The latter additionally requires fresh timestamps, valid matching full transform, explicit current fixed mount and valid recorded profile. An invalid/relocalizing pose cannot become valid by reordering calls, and a saved-room match is not calibration or current clearance. No gates are loosened. Existing RGB stairs and wearable arbitration in `publish()` remain independent.

## Minimal proposed change

`recovery-hazards.patch` changes only NavigationModel (research copy in `proposal/`).

- Extract existing legacy-first/body-second arbitration unchanged into `processDepthHazards` and reuse it from the ordinary path.
- Before recovery work, sample once and process with the same validity checks. Publish immediately, before the automatic-attempt rejection guard, map/history import and optional recovery appearance work. No calibration, inferred transform or mount is invented.
- Invalid tracking retires floor/mount/map-dependent state even if depth is also nil. Nil depth invalidates recent detector evidence and clears stale body assessment. Recovery never supplies a lastObservation, survey, live scene or journey progress; it invalidates live authority while retaining the recovery attempt/goal owners.
- Keep a validated urgent result; replace every nonurgent result with `.uncertain/.localizing`. The branch cannot overwrite an urgent result later. A no-intersection body result never proves clearance.
- Both manual and automatic recovery entries now call existing journey withdrawal immediately before assigning `awaitingPlace`, including when the following launch is refused. Leave launch itself, ARSession ownership, successful recovery state changes, retry budgets, session-generation defers and ordinary-path ordering intact. The exact recovery frame remains uncertain even if matching completes, unless a separately admitted urgent warning wins.

No new algorithm, package, model, network dependency, stored user data or physical guidance is introduced. The invalid-tracking cleanup can still call existing cancellation routines; the native owner/reset tests below are required before adoption.

## Executed evidence

Swift 6.4.1 Linux toolchain from `/workspace/shared/swift-toolchain/env.sh`.

1. **25 assertions passed** in an executable projection containing the exact two proposed helper method bodies, with instrumented adapter stubs. Covers three legacy urgent classes, legacy-before-body short circuit, supplemental positive warning, uncertainty for every nonurgent state, no retained live observation, invalid tracking resets, nil depth, nil-depth plus tracking loss, no stale warning reuse, and the real restart's uncalibrated/unmounted state.
2. Source wiring checks: original baseline fails expected pre-recovery dispatch condition; proposal passes lifecycle/freshness gates, before-recovery dispatch, no subsequent overwrite, and urgent-before-optional geometry ordering.
3. **Real-owner regression passed:** the exact pinned `ConnectedJourneyRuntime.swift` is compiled and executed with the pre-existing BlindCore binary (actual coordinator, route leases and speech ledger), synthetic existing map fixtures, and the exact old/new helper bodies. A live authored route is initially permitted; entry withdrawal invalidates it while retaining a nonnil destination. A newly pending return clarification is then subjected to eight normal recovery frames. The rejected helper reproduces eight runtime changes and lost clarification delivery. The corrected helper emits no such changes, retains the clarification's completed delivery, retains goal/references, and cannot revive the old route ticket. Journey behavior is NOT stubbed in this witness; sensor/ARKit and other adapters still are.
4. Source checks additionally cover exactly two nonnil recovery entries, retirement before each assignment and launch, no per-frame helper restart, and byte-identical pre-existing tracking-loss callback preamble.
5. Patch dry-run applies cleanly against the pinned research baseline.

Real-owner binary provenance: reused `/workspace/shared/blind-rebuild/BlindCore/.build/out/Products/Debug-linux-x86_64/BlindCore.o` and its module; no full core rebuild. The relevant coordinator source SHA matches `/workspace/shared/current-core-verified-build-manifest.json` and the audited snapshot. This is not a claim that every dependency was rebuilt from current master. `real-owner/PROVENANCE.json` pins inputs/binary/results. Reproduce via `bash blind-recovery-hazard-research/real-owner/run.sh`; it reuses the existing research module cache.

These are **portable projection/source plus real-owner component tests**, not native callback tests. Detector and body-assessor algorithms remain stubbed; their actual Swift implementation was inspected but not re-executed here. ARKit, SwiftUI, actual app typechecking, speech/haptic delivery, real sensor validity, latency, hardware accuracy and physical safety were not tested. No suite-wide pass is claimed.

An initial compiler invocation failed because the default Clang cache was read-only. Re-running with an explicit writable research-local module-cache path succeeded. One transient exec transport disconnect recovered on one normal retry. Neither was a permission denial; no escalation or install occurred.

Reproduce (small local compile, no install/build of app):

```sh
python3 blind-recovery-hazard-research/prepare_projection.py
. /workspace/shared/swift-toolchain/env.sh
swiftc -module-cache-path "$PWD/blind-recovery-hazard-research/module-cache" \
  blind-recovery-hazard-research/RecoveryProjection.swift \
  -o blind-recovery-hazard-research/recovery-projection
blind-recovery-hazard-research/recovery-projection
python3 blind-recovery-hazard-research/check_wiring.py
```

Baseline NavigationModel SHA-256: `d544f6f992b75d2a3a136cae4e651c440f026dbddce42d2501a417eafb09965f`.
Proposed NavigationModel SHA-256: `18eb1c63011e6c44cc55b0e31d52aa1eea7f5fb2589ced1aa7ece4d02e8a89ad`.

## Required regression acceptance before adopting

Use existing native NavigationModel/AR callback testing seams; do not present arbitrary struct construction as genuine ARFrame. Run existing `BodyCollisionWarningTests`, `HazardDetector` tests, `RoomRecoveryCoordinatorTests` and saved-frame/ownership suites against the final revision. Then add native callback injection fixtures or a minimal instrumented adapter seam for these cases:

| Fixture | Required assertion |
| --- | --- |
| Fresh normally tracked recovery frame + already-admissible positive body intersection | Urgent published before recovery resolver/history/RGB memory; no route progress or clearance. Explicitly author the mount/profile, do not pretend restart retained them. |
| Fresh calibrated drop/overhead/obstacle fixture | Legacy result and fields preserved; body assessment not invoked; no recovery localizing overwrite. This is an injected contract fixture, not a reachable calibrated-after-launch claim. |
| Recovery attempt rejected/expired on this same frame | Urgent publication occurs despite guard return; no matching owner or goal accepted. |
| Recovery succeeds on this same frame | Urgent not overwritten; furniture import occurs after publication; same frame grants no route authority. |
| Relocalizing/limited/unavailable tracking, with and without depth | No pose-dependent positive warning or clearance; mount/floor/held body/live observation/scene/route authority retired; goal and bounded attempt preserved. |
| Normal tracking but malformed transform, stale/future/duplicate timestamp, low-confidence depth | Existing validity rejection persists; stale/future frames never reach sampling; watchdog handles unavailable callbacks. No synthetic valid-pose substitution. |
| Nil depth followed by normal recovery | Old held alert/body assessment cannot replay; RGB history remains separately fenced; optional callbacks cannot resurrect withdrawn route authority. |
| New restart with reset detector/mount | Localizing remains truthful; no positive depth-warning expectation without evidence. Existing fresh wearable/RGB warnings still arbitrate independently. |
| Mute/end, background, camera off, scan, simulation, session replacement | Existing admission gates and generation defers remain effective; no new sensing restart. |
| Urgent frame with pending optional speech/OCR/history | Actual speech/haptic sink receives alert before optional work; measure latency; older route cancellation cannot stop new alert. |

The independent reviewer accepted the correction at source level; final consistency review is recorded separately. A read-only Mac/device review is still required to select the real native fixture seam and measure behavior. No device trial, deployment or unsafe walking is authorized by this patch.
