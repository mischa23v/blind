## Same-frame room overlay candidate — 2026-10-28

After durable checkpoint `efdc2c1`, [SAME_FRAME_OVERLAY.md](SAME_FRAME_OVERLAY.md) describes the camera-only exact saved-room receipt, atomic inert archive event and historical top-down room/trace UI. This candidate is source-reviewed work, not native or device validation. The existing measured-alignment route overlay remains separate; no imported-map transform is invented.

## Current durable candidate

The initial volatile checkpoint below is historical (`26bfa69`). The later durable local save/reopen source and its still-pending native validation are documented in [DURABLE_IMPLEMENTATION.md](DURABLE_IMPLEMENTATION.md), with a separate `DURABLE_MANIFEST.json`. Do not confuse Python schema checks with executed Swift/GRDB tests.

---

# Planned route versus actual phone trajectory — local diagnostic increment

Request: user message `Sentinel_e1906dc3cd448191a1c05c713f079703` asks to track the paths they take in a future device test because reported arrivals and plotted routes can conceal table/wall crossings.

## Reuse, not another mapper

- `NativeARObservationAdapter.captureRoutePose` extracts a pose-only observation from the existing AR frame.
- `RecordedRouteStore.offer` samples that existing feed at no more than 5 Hz, retaining `RecordedRouteSample` through the existing private GRDB repository.
- `RecordedRouteSampler` retains tracking/frame/session/gap boundaries.
- New `BlindCore/NavigationTestRecording.swift` is a bounded diagnostic sidecar consuming those samples. It does not run capture, SLAM, localization or a navigation planner.

The sidecar preserves raw camera transforms and timestamp/tracking/map provenance. Planned points are stored separately with map, route and goal revisions. Supplied alignment retains evidence, calibration, registration revision, validity interval and transform. It does not verify that transform itself. Missing, expired, delayed-before-plan, wrong-frame or limited-tracking observations do not acquire a projected map position. No snap-to-path or automatic correction hides errors. Typed user problem markers reference the last recorded observation (not a fabricated tap-time position). Markers are reports, not independently confirmed collisions.

Overlay segments break at source discontinuities, registration/plan changes and missing map positions. Camera path is not body or feet ground truth. Arrival is not proof that a body avoided furniture. The map itself may be wrong; the raw source-frame path remains available for comparison.

## Privacy and lifecycle

Explicit Start is required. Stop fences subsequent samples. The session is bounded at 3,000 samples, 128 route revisions, 2,048 points per route, and 128 typed markers; reaching an accumulated count cap stops rather than silently dropping old evidence. An oversized individual route payload is rejected without ending the recording. There are no photos, audio, HealthKit fields, free-text personal notes, network calls or automatic exports. This increment is memory-only: process exit discards the diagnostic sidecar and never resumes recording. Existing private route history persistence is unchanged. Durable recovery/export/UI are not implemented here; do not advertise a completed live recording feature.

## Remaining app integration

1. Authored `NavigationTestRecordingView` has Record/Stop/Mark/Delete, status/counts and two explicit plot modes. It is linked from RoomDetail through NavigationModel’s existing bridge factory. Canonical native membership and compiled/UI acceptance remain pending at this source checkpoint.
2. Implemented source: store ingests already admitted samples under existing generation/continuity fences (no second capture). Bridge forwards explicit Start/Stop/Mark/Plan/Snapshot/Delete APIs. The view receives the existing bridge; Start also records the current code-owned plan snapshot.
3. Actual read-only owner route/goal/body/obstacle/artifact snapshots are forwarded on runtime changes and initial Start; repeated unchanged routes are deduplicated and cancellation records empty points. A measured registration producer is still absent, so source-to-map alignment stays nil.
4. Standalone view draws latest-source-frame camera dots separately from exact-map registered trajectory segments from the same latest plan revision plus that planned line. It does not show room/furniture geometry; it cannot alone establish wall/table collisions. Earlier source frames remain in the snapshot but are not selected in this first view.
5. Exercise this in the existing Apple CI/native build, then bench replay before any requested physical test.
6. Optional later local persistence must reuse existing storage and bounded retention, exclude backups, restore only as stopped historical evidence, and require explicit user action for any export. Public repository receives synthetic fixtures only.

## Validation status

Nine synthetic XCTest methods authored for stop/late callback, absent alignment, expired/limited/delayed data, continuous lines versus revision/unknown/tracking gaps, route cancellation, cap, invalid timestamps. Swift is unavailable locally, so these tests have **not run**. Existing Apple CI should execute `NavigationTestRecordingTests`; no new workflow/dependency is introduced. Source review is not a device performance or collision-accuracy result.

Independent source review caught an initially weak segmentation fixture (a new sampler made every sample a beginning) and a misleading latest-plan index on delayed pre-plan samples. The fixture now keeps a sampler across observations, asserts a positive two-point line then explicit gaps; delayed pre-plan entries retain no plan index. Native execution remains pending.

## Actual store integration increment

`RecordedRouteStore` owns the optional sidecar under its existing lock. Camera begin never starts a diagnostic recording; session replacement and stop end it; private-history deletion erases it synchronously. Rejected admitted samples are counted, and the next diagnostic sample carries an explicit break. Future-dated plan events are rejected so they cannot prevent stop using the current clock. Existing GRDB route storage behavior is not replaced. Four hosted `RecordedRouteStoreTests` methods exercise opt-in, admitted-sample identity, stop/late extraction, session replacement and deletion; authored, not executed locally.

Independent Store review found and fixed two lifecycle issues before publication: in-flight samples now require the same diagnostic recording ID captured at offer admission (including same-clock stop/restart), and rejected route changes stop the diagnostic rather than silently keep associating samples with an old plan. The view stops on disappearance/background; there is no hidden or automatic resumption. No UI or hosted tests have executed locally.

Independent view review caught a mixed-revision comparison: the initial map plot paired every historical same-map trajectory with only the latest plan. The plot now filters to that exact plan index, and raw-frame accessibility no longer describes a nonexistent planned line. Full-history inspection needs a future explicit revision/frame selector.

## Reachable source checkpoint

RoomDetail now links to the existing NavigationModel bridge factory; no second camera/bridge is created. NavigationModel preserves the original runtime change callback and records a read-only copy of existing SpatialRouteOwner nodes through Coordinator/Runtime only during explicit diagnostic recording. It does not call `next()` or replan. Body/obstacle revisions and artifact digest accompany route/goal/map IDs. Receipt timestamps are assigned under the recorder lock. No production registration is invented: plan and raw camera trajectory remain in separate frames. Nine Core and four hosted test methods are authored in this increment, none executed locally. Native membership is maintained separately by its canonical owner.

Durable save/reopen is the next separate stage, not part of this checkpoint. Current UI explicitly says temporary and no export; process termination discards this sidecar. It is not yet sufficient to preserve an entire user test for later sharing.
