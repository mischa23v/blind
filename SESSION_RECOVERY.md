## Async map reconstruction update — 2026-10-25 05:19 UTC

The reviewed async map increment is applied and frozen for this checkpoint: **1,111 Core and 394 Node checks passed**, zero failures/skips. Focused actual-source checks cover bounded off-main storage, stale callback/revision rejection, deletion/rollback ordering, pending/failed map ownership and route-specific output retirement. Photo, observation, memory and clock source was preserved. Apple SDK/device behavior, real timing and a calibrated localization issuer remain unverified. Previous published source is `33f43635ed2411d3e85906e2ed808b447442500a`. See [checkpoint-10 evidence](research/rebuild-evidence/checkpoint-10/verification.json). This supersedes earlier async-map staged status below, not the remaining journey/place-memory/physical-release gaps.

## Observation-history reconstruction update — 2026-10-25 03:50 UTC

The bounded native observation-history increment is now applied and frozen for this checkpoint: **1,111 Core, 393 Node and 35 actual GRDB tests passed**, zero failures/skips. The prior Node run failed one stale lifecycle-prefix assertion; its original output and stronger cancellation/authority correction are retained. Raw observations use a separate incremental store and a provisional 128 KiB/60 s durable-payload budget with empty-start credit. Short sessions may remain volatile; oversized records are not silently truncated. This is not world mapping, localization or movement authority. Sensor accuracy, added ARKit workload, physical flash/battery costs and Apple runtime remain unverified. Previous published source is `41dd5d93ac1c7bc41e7b3bb8a0c7396b3b3cf640`. See [checkpoint-09 evidence](research/rebuild-evidence/checkpoint-09/verification.json). This supersedes earlier observation candidate status below; async map IO and connected journeys are still separate open work.

## Photo reconstruction verification update — 2026-10-25 03:38 UTC

The earlier photo aggregate failure recorded below has now been corrected and rerun: **1,057 Core and 391 Node checks passed**, zero failures/skips. Only two stale test-shape assertions changed during correction; stronger source ownership, cancellation ordering and negative mutation checks replaced them. The original failed run is retained. The 15-file selected-photo source integration plus two corrected contracts is frozen for this executable checkpoint. Photos/Vision/audio/Apple SDK and real device behavior remain unverified. The previous published tracker/source-archive checkpoint is `1937e92e72abd72212c60427e4a5362e13dc678a`. See [checkpoint-08 evidence](research/rebuild-evidence/checkpoint-08/verification.json). This update supersedes earlier photo aggregate status below, not other open feature gaps.

# Current reconstruction resume state — 2026-10-25

Latest verified published source: `978b506283b5ce9d1ea05ea120db8806f47754fe` (tree `750cd35b01a4e662a99797589afbbca53092a308`). This current feature snapshot supersedes earlier checkpoint snapshots retained below, including old sections headed “current.” See [REBUILD_FEATURE_STATUS.md](REBUILD_FEATURE_STATUS.md) for publication state, actual behavior, remaining gaps and dependency order. Original requirements and failures remain in [REBUILD_TRACKER.md](REBUILD_TRACKER.md) and [REBUILD_SCOPE_ADDENDUM.md](REBUILD_SCOPE_ADDENDUM.md).

## Resume without confusing source states

1. Confirm the latest remote source before editing; the last verified boundary here is `978b506283b5ce9d1ea05ea120db8806f47754fe`, tree `750cd35b01a4e662a99797589afbbca53092a308`. Preserve applied changes and compare source hashes/preimages before bringing in a staged patch.
2. Ordinary guards/reference Core are now published at 978b506 (Core 1023 / Node 379). Current source additionally includes the applied selected-photo increment: focused checks and Core 1057 passed; Node aggregate FAILED (391 total, 389 passed, 2 failed); test-only correction/full rerun and publication pending.
3. The published debug, memory, registered synchronous spatial and operation-owned clock increments are already implemented in source. Do not rebuild them as missing standalone foundations. Their actual Apple/device validation is still open.
4. Finalize the staged observation-budget archive after 81 cleared scoped source tests; it is not applied. Rebase frozen async map IO over final observation/privacy changes before application. Raw bounded history is not world memory or localization.
5. Finish applied trusted-picker verification and preserve it remotely. Additive journey Core remains staged/unwired; rebase its native quiet patch over current source before any apply. Native manual/PDF and full reference speech adapters remain missing even though reference Core is published.
6. The central spatial blocker is a calibrated native pose/body-heading/support issuer, followed by automatic world-map construction, uncertain relocalization, body calibration and complete cross-map return. Keep movement fail-closed until those dependencies produce valid evidence.
7. The real speaker verifier, original complete memory/ordinary/reference episodes, 400 distinct integrated scenarios and actual small-model/Apple/device accuracy/latency remain open. Do not infer acceptance from restored assets or portable counters.
8. After each verified source increment, record exact commands/logs/source hashes, remote SHA and remaining gaps in the tracker/progress/queue. Keep raw private recordings out of repository documentation and add no UI or automatic log uploads.

For the detailed feature matrix and evidence links, use [REBUILD_FEATURE_STATUS.md](REBUILD_FEATURE_STATUS.md). The archived initial handoff below records the start of reconstruction, not present implementation status.

## Archived initial reconstruction handoff

Photo aggregate correction: Core 1,057 passed; Node finished with 391 total, 389 passed and 2 failed. Independent diagnosis identified stale source-contract count/prefix assertions. The test-only correction replaces them with stronger per-source ownership and cancellation-order checks; production source is unchanged. The aggregate remains FAILED until the corrected full rerun passes. Preserve the original failure and corrective diff; photo checkpoint 08 remains separate and unpublished.

# Blind reconstruction restart handoff

Prepared 2026-10-25. This document preserves technical requirements and evidence limits. It is not a claim that missing source bytes were restored.

## Current reconstruction state

- Initial documentation prepared: `REBUILD_TRACKER.md` and this handoff.
- Source implementation, builds, tests, benchmarks, commits and pushes require separately recorded evidence; documentation does not prove those activities occurred.
- Current implementation work areas: command-authority boundary, spatial-registry foundation and DEBUG recorder foundation. None establishes full native integration.
- First checkpoint should preserve these new documents promptly. Further requirements from the additional longer supplied history can be reconciled in an additive checkpoint.
- Before resuming, inspect the actual checkout and remote, compare current work against the latest checkpoint, and avoid duplicate implementation or overwriting newer changes.

## Product scope and constraints

1. Reconstruct the missing functionality from available source and the surviving requirements. Publish small verified checkpoints promptly instead of retaining all work locally until final completion.
2. Code, sensors, validated maps and measured evidence own physical guidance. The LLM handles conversation and request interpretation, not navigation facts, reaching instructions or movement authorization.
3. Maintain connected world/building/floor/room state, measured transforms, position, heading, partial-map learning, uncertainty and return continuity.
4. Background or uncertain speech cannot change guidance or the active task. Quiet mode preserves navigation and valid urgent hazards.
5. Debug logs are local and developer-only, with no new UI or automatic upload. Ordinary home navigation does not gain a new room-permission system; configured no-go zones remain navigation constraints.
6. Tests must exercise the actual combined map/pose/routing/collision system, preserve failing cases and trace real tools and outputs. Plausible conversation is not navigation evidence.
7. A complete review handoff includes architecture, changed files, dataset provenance, commands, outputs, failures, missing native integrations and precise Mac/iPhone checks.

## Evidence inventory and limits

The initial tracker uses owner-provided requirements and historical status reports, plus a read-only repository recovery assessment. Original private conversation exports are deliberately excluded from the repository. Their contents are converted here to impersonal product requirements and technical evidence limits.

A second, longer supplied history arrived after initial planning. It remains to be reconciled fully. This is an explicit coverage gap, not permission to postpone the first durable checkpoint. Additional technical contracts already provided from that history are recorded in the supplemental section of `REBUILD_TRACKER.md`.

The available historical record is incomplete. Missing context must not be inferred. Historical claims of tests, backups or source changes are leads for reconstruction, not authenticated current source or rerun evidence.

## Baseline and repository state

The supplied assessment inspected the complete GitHub tree and selected files at:

- Repository: `mischa23v/blind`.
- Pinned commit: `4b00872f1bbc4ea92dca55f47f008f33460c4e71`.
- Commit: https://github.com/mischa23v/blind/commit/4b00872f1bbc4ea92dca55f47f008f33460c4e71
- Assessed tree: 814 entries, not truncated. That assessment performed no implementation changes or tests.
- The latest repository check during reconstruction also reported this SHA, a private repository and primary branch `master`. Check again before later publication; this is not a permanent assumption about remote state.

Preserved according to the assessment: iOS app; task/conversation/local-memory/familiar-person/currency/color/OCR/photo foundations; IndoorMap; real 2.5D NavigationSurface; BodyEnvelope and swept clearance; no-go/sensor hazards; RoomPlan/world-map recovery; SavedWorldFrame; IndoorNavigator; ReturnTrail; RTAB-Map input/database adapter; listening/mute/headphone handling; CompanionMemoryRetrieval; actual CompanionClock; prior test, research and acceptance documents.

Specific assessed baseline limitations:

1. `NavigationModel.launch` at lines 646–679 stops return, invalidates indoor position and starts a new journey. Later connected restart continuity was not recovered.
2. `IndoorNavigator` requires manual level-change confirmation. `ReturnTrail` requires one uninterrupted current AR session.
3. The native RTAB adapter does not consume localization/occupancy output into the later connected spatial system.
4. Microphone `onFinished` forwards text into `receiveCompanionUtterance`; entry checks listening but not verified speaker (reported NavigationModel lines 594 and 2349–2356).
5. No later full debug-session logger or Soundscape-inspired headset-control implementation was identified. Existing narration history and headphone removal handling are not those missing features.

Pinned sources for re-inspection:

- https://github.com/mischa23v/blind/blob/4b00872f1bbc4ea92dca55f47f008f33460c4e71/BlindCore/Sources/BlindCore/NavigationSurface.swift
- https://github.com/mischa23v/blind/blob/4b00872f1bbc4ea92dca55f47f008f33460c4e71/BlindCore/Sources/BlindCore/IndoorMap.swift
- https://github.com/mischa23v/blind/blob/4b00872f1bbc4ea92dca55f47f008f33460c4e71/BlindCore/Sources/BlindCore/ReturnTrail.swift
- https://github.com/mischa23v/blind/blob/4b00872f1bbc4ea92dca55f47f008f33460c4e71/ios/BlindAssist/NavigationModel.swift#L646-L679
- https://github.com/mischa23v/blind/blob/4b00872f1bbc4ea92dca55f47f008f33460c4e71/ios/BlindAssist/NativeMapping.swift
- https://github.com/mischa23v/blind/blob/4b00872f1bbc4ea92dca55f47f008f33460c4e71/ios/BlindAssist/IndoorNavigator.swift#L198-L200

## Honest test and recovery status

No new test result is established by this handoff. The tracker marks historical counts as unavailable evidence, including the final recorded 1,629 Core and 500 repository tests. That count does not authenticate missing source, prove the current checkout passes, or establish final package completion.

Explicitly unfinished outcomes:

- 400 distinct integrated scenarios. Supplemental detail reports 15 catalog IDs partially bound, 385 without binding and 397 without complete new whole-episode bindings; none is a current pass count.
- Real verified hands-free speaker identity and intended-addressee verification.
- Longer experimental mapper accuracy: recorded approximately 1.12 m p95 error across 34 m, failing thresholds, without a final pass.
- Some native integrations, explicitly missing rather than merely awaiting phone tests.
- Live iPhone navigation/microphone validation and final combined package review.

The short 100-frame mapping success and later synthetic integrated journeys do not remove these limits. Claims that all 400 passed, safe iPhone use is established, native integration is finished or missing source is restored require new evidence.

Historical source/test backups were reported but not recovered by this documentation task. Missing from available inputs does not mean permanently destroyed. If a backup is recovered later, check integrity, source content and tests before merging it with reconstruction. Do not overwrite newer work.

## Technical contracts that must survive interruption

- Perception-revision UUID is separate from task/route `stateRevision`. Cancel, quiet and a new goal do not expire fresh hazards. Map, session, geometry and acquisition changes rotate perception authority. Withdraw queued/started route cues by exact cue ID, preserving the hazard channel.
- Clock is read-only, does not cancel goals, and uses the original monotonic five-second freshness cap plus wall/time-zone consistency checks.
- Reference/manual delivery preserves source blocks and qualifiers in chunks of at most 35 words. The original 60-second deadline cannot be renewed or resumed after invalidating interruptions.
- DEBUG logs use explicit launch opt-in, no UI/upload, 8 MiB per-session and 32 MiB retention caps, fail-stop without silent eviction, and purge plus disable on privacy clear.
- These contracts are historical requirements, not assertions that the current source implements or passes them.

## Restart checklist

1. Read this handoff and the tracker. Inspect current source status, prior checkpoint and any already prepared changes before implementation.
2. Locate the selected checkout, read its repository/run instructions, record working-tree changes, branch and base commit, and inspect current remote safely. Never assume the historical baseline is still the latest head.
3. Preserve original failure evidence outside published documentation. Reconcile the longer supplied history and any newly recovered source without rewriting historical failures into successes.
4. Continue the smallest open checkpoint: authority guardrails, safety-state lifetime, frame identity, uncertain recovery, mapping/persistence, swept collision, return, memory/reference/debug integration, then broader whole-episode coverage.
5. Record exact commands, exit codes, logs and source SHA for every checkpoint. Run focused tests immediately and affected aggregate checks after the final edits. A blocked run is not run, not passed.
6. Publish verified small checkpoints through the authorized repository workflow. Verify exact remote commit presence and CI before reporting success. Do not force-push or overwrite newer work.
7. Keep the 400-scenario catalog visibly incomplete. Implementation, isolated checks, integrated replay, native integration and live device validation are distinct milestones.
8. Do not add UI, automatic log uploads, new room permissions or LLM physical-guidance shortcuts.
9. Update these documents with actual completed commits and artifact references. Keep the next concrete open checkpoint and verified blockers explicit.

## Per-checkpoint handoff template

- Changes and tracker IDs:
- Exact tested commit and relevant files:
- Verified tests: command, environment, exit code, artifact:
- Failures and tests not run:
- Real measured data / synthetic connections / trusted replay / live iPhone:
- Missing native integrations and safety constraints:
- Local commit, remote branch and verified remote SHA:
- Next smallest checkpoint and exact blocker, if any:
