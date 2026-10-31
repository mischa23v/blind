# Seated capture-to-candidate seam — source implementation, not execution evidence

2026-10-30. Implements the narrow seam identified in [source audit](../ios-floor-body-diagnostic-audit-20261030/README.md). **Not built or executed yet. No physical/iPhone readiness claim.** Root owns review, test admission and publication. Main remains untouched.

## Reuse and conventions

- Existing Apple ARKit callback copies only 16 camera matrix scalars, original uptime, frame UUID and exclusive bench-session UUID. No image/ARFrame/Metal buffer leaves its callback. Existing native ownership, fresh normal-frame lease, stop/background/drain and phone-monitoring warning remain.
- Core uses existing `NativeCameraTransform` rigid-matrix validation and `applying(to:)`, `SpatialRigidTransform` yaw math, and `LocalBodyProfile`/`ChestMountMetadata` validation. No new SLAM, floor detector, calibrator, recognizer or dependency.
- Helper declares all three mount offsets and separate session-world body yaw; no defaults or stature-to-mount inference. Mount coordinates are +right/+up/+forward from floor beneath body centre. World yaw 0 faces -Z, +90° faces -X. Convert mount forward to -Z, rotate that upright body-frame translation, then subtract it from the exact camera origin. Camera pitch/roll never rotates world-up mount height or supplies body yaw.
- Result is explicitly `UNVALIDATED`; `independentlyValidated` and physical guidance remain false. No conversion to registered localization, floor support, speech or haptic movement authority exists.

## Frozen snapshot, not 60 Hz starvation

Admission requires a camera capture no older than 0.5 seconds. The explicit request freezes its copied scalar values and a separate request identity. Ordinary later ARFrames update the latest cache but neither replace nor retire the request. Explicit recapture (including within the same ARFrame), mount/heading edits, refresh, session/lifecycle/geometry invalidation retire it. Historical display is bounded to eight seconds from the original capture; **this is not permission to speak eight-second-old physical guidance**. UI shows original timestamp and never claims current wearer location. Both admission and late delivery reject future/nonfinite/expired values.

Existing mesh-source currentness remains strict: snapshot identity is checked under ingress83's existing lock **before** query-token advance. This closes the race between a main-thread source check and a newer anchor revision. The query intentionally advances runtime revision; pre-query geometry identity and post-query native endpoint association stay separate. New source changes during native work still fail existing generation/token checks. No stale geometry is stabilized by pretending it is current.

## Presentation

Manual XYZ remains. New opt-in helper declaration mode uses the existing strict query; original camera, requested candidate foot and returned native source-associated start remain separate. Receipts show delta Y/XZ residual, requested versus projected goal and native endpoint-found/over-polygon bits. Yellow point marks requested candidate, cyan remains native diagnostic route; no connector or endpoint-height reset is fabricated. The line remains unavailable until the exact current source revision is inspected. No walking mode, normal camera restart, profile write, upload, permission or private data persistence added.

## Executable tests authored, not run

- `BlindCore/Tests/BlindCoreTests/DiagnosticBodyFootCandidateTests.swift`: eight cases covering identity and pitched camera/declared-yaw signs; absent versus zero mount; malformed/invalid/stale/future capture; absent/invalid/unconfirmed heading; capture/source session mismatch; changed capture/source/mount/heading and expiry before delivery; exact requested endpoint association and retained delta Y without overwriting the candidate.
- `MeshBenchHelperTests.swift`: two pure snapshot tests distinguish ordinary later frame from explicit replacement, including same-frame replacement; missing/session-changed/expired/invalid snapshots. One ingress test obtains an actual source snapshot, changes its geometry revision, and verifies pre-query refusal under the existing lock without submitting a native replan.
- Existing seated lifecycle/projection tests and classified-route fixtures are retained unchanged, including the four known c210 timeout failures. Current additions do not claim to fix those failures.

Proposed root-admitted commands, one worker, existing toolchain only:

```sh
swift test --package-path BlindCore --jobs 1 --filter DiagnosticBodyFootCandidateTests
swift test --package-path research/live-mesh-classified-bench-20261028 --jobs 1 --filter MeshBenchCameraSnapshotTests
swift test --package-path research/live-mesh-classified-bench-20261028 --jobs 1 --filter MeshBenchExpectedSourceTests
```

The latter package can compile native dependencies; parent must bound/admit execution. Apple CI must also compile DEBUG diagnostics and execute existing `SeatedMeshProjectionTests`, then exercise native classified ingress and the actual controller screen on a device. No Swift binary was available in this workspace at inspection. Only `git diff --check` has actually run for this implementation (no whitespace errors). CI collector tests executed by the separate CI agent are not native execution of these fixtures.

Two additional hosted `SeatedMeshProjectionTests` now exercise the actual controller via a narrow internal DEBUG backend/clock seam: actual owned classified floor goes through existing ingress83/runtime75, genuine snapshots/routes return, then the existing renderer publishes the route and requested-foot marker. Tests hold the real completion, update the ordinary latest-frame cache, verify unchanged request identity/endpoint delta/post-query revision, and reject explicit same-frame recapture or source removal. No ARFrame, Candidate or SourceSnapshot is fabricated. The production backend remains the existing exclusive ARSession owner. These tests are authored, not executed.

Open: Apple compilation and execution of these fixtures, actual seated latency/memory and refusal testing. Not completed: calibrated body pose, measured support, dynamic obstacles, collision clearance, walking routes or child trials. Private phone captures remain local.
