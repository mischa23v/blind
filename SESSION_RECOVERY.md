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
