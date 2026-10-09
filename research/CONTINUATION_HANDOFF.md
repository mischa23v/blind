# Continuation handoff — paused 2026-10-08

The user asked to save a handoff and continue later. This is the current resume point. **The minimum assistant is unfinished. Latest source has untested changes; no Mac/iPhone readiness is claimed.** Preserve the older checkpoints as historical evidence.

## Resume order and constraints

Read `PROGRESS.md`, `TODO.md`, `PROJECT_PLAN.md`, the relevant `TASKS.md` entries, this file, and the accepted architecture in `MEMORY_AND_INFORMATION_ENGINE.md`, `ATTENTION_AND_SPEECH.md`, `COMMUNITY_MAPS.md` and `MAP_GROUNDING_REVIEW.md`. The checklist remains 71 tasks: nine completed research/baseline tasks and 62 open tasks. Do not mark integration tasks complete from source preparation.

No Docker, containers, heavy installs/builds or model weights on Windows. Bounded serial local Node/SQL/relay checks are authorized when work resumes. Apple compilation and device checks require the Mac and the user's testing go-ahead. No new functional tests were run just to prepare this handoff. The shared workspace has no Git rollback; re-read files before edits, preserve other sessions' changes, and do not initialize or publish a repository.

The product remains an information assistant: immediate local danger, then due mobility/orientation, then rich environment/social/choice information. Words per time, detail and frequency are independent; VoiceOver owns speed. Unknown location stays unknown; a downloaded map or remembered person never proves current clearance. Approval is bound to exact room/revision changes. Keep bathroom goals through bedroom transitions.

## What changed since the earlier minimum checkpoint

All native changes below are source preparation, not Apple-compiled or device-verified integration.

| Area | Current source | Boundary |
| --- | --- | --- |
| Map context | `ios/BlindAssist/IndoorSituation.swift` adapts the existing manually aligned indoor route and package hierarchy. Core Graphics polygon containment supplies candidate room context. `IndoorNavigator` can restore matching installed package metadata offline. | State is explicitly `manuallyAligned`, not automatic localization. Restart restores no live pose. Boundary/overlap ambiguity falls back to the floor. No geometry or owner is recognized from a name. |
| Camera/body direction | Session-only fixed-body-mount declaration, tracking/freshness invalidation, map/alignment revision checks and route cue deduplication. | A handheld camera does not establish body heading. Mount slip is not detected. Manual alignment and cue thresholds are unvalidated app policy. |
| Anonymous people | `PersonTrackingMonitor.swift` uses Apple's Vision human rectangles and object tracking with a serial worker, bounded tracks and short observation windows. | Temporary camera-relative tracks only. No family identity, approach intent, verified departure, seat occupancy or biometric memory. No Vision execution has occurred. |
| Speech | `SpeechPriority.swift` orders danger, mobility, status and information; `Feedback` tracks priority and idle callbacks. `PendingQuestion.swift` retains one current question for fresh regeneration after speech. | Old generated answers are not queued. UIKit same-text completion ambiguity and stale already-speaking descriptions still need review and device tests. |
| Conversation | `AssistantControl.swift` adds exact English/Arabic quiet, resume, repeat and detail/amount commands, plus explicit goal prefixes. Voice completion uses the same local command path. | Push-to-talk remains the input mode. Goal naming does not fabricate a route. Repeated descriptions are labelled historical and charged against the ordinary word allowance. |
| Preferences | Explicit social/signs/objects/decor/interests modes: automatic, on request or muted; older saved preferences remain decodable. Minimal detail can still receive automatic updates. | Rich model category adherence is prompt-guided, not deterministic semantic enforcement. No automatic preference learning is claimed. |
| Historical room notes | Approved descriptions and mapped features enter situation context with source/revision metadata; schema accepts `mapNotes`. | Historical descriptions are not current occupancy or proof of clearance. Preview-only packages with no route map are not yet connected to this assistant context adapter. |
| Evidence freshness | `AssistantSituation.aged` expires stale pose and tracks after preparation; pending questions and generated answers recheck relevant context. | Additional JPEG/network preparation and moving-user usefulness still need evaluation. Conservative delivery rejection can starve useful narration. |

The UI also includes a repeat control, category preferences and fixed-mount explanation. Goal changes stop stale route speech. Stopping ordinary descriptions preserves necessary mobility/hazard delivery. Community route activation installs the reviewed package offline before selecting it; it does not publish anything.

## Evidence, with exact limits

| Record | Result | Scope |
| --- | --- | --- |
| [Latest recorded serial suite](../artifacts/minimum-assistant/integration-tests.tap) | 39 passed, zero failed | Includes manually aligned pose and anonymous track contracts. Predates category modes, map notes and later native/control/pending-question refinements. **Does not verify the full current source.** |
| [Earlier minimum suite](../artifacts/minimum-assistant/node-tests.tap) | 37 passed | Historical relay/SQL/project checks. |
| [Earlier home context evaluator](../artifacts/home-awareness/minimum-core.json) | 15/15 context-delivery checks | Supplied text context, zero new model calls. Not real perception or physical localization. |
| Hosted native source | 22 test methods in `ios/BlindAssistTests/CommunityTests.swift` | Ten community cases, four situation-adapter cases and eight indoor/aging cases. Prepared, not run. Geometry examples are authored synthetic fixtures. |
| Swift package/UI source | Added priority, controls, pending question and preference tests; six UI tests remain | Prepared, not run. Requires the Apple toolchain for native targets. |

No new inference call, real image evaluation, VoiceOver trial, Apple build, install, model download or Docker execution occurred in this continuation. Historical API responses and older Swift/firmware runs do not validate the new adapters. The project is regenerated for packaging only; generation is not compilation.

## Next work, in order

1. Reconcile shared source with this handoff. Inspect the latest category-mode/map-note contracts and tests. Add missing map-note reference/bounds cases and preserve the existing unknown-pose behavior. The last log has 39 tests; additional source tests have not run.
2. Run the bounded serial suite on resume, retaining a new log: `node --test --test-concurrency=1 server/test/*.test.mjs tools/test/*.test.mjs`. Run the supplied-context evaluator only when relevant: `node tools/evaluate-home-awareness.mjs --label resumed-context`. These are not localization acceptance.
3. On the Mac, inspect tools first: `node tools/mac-preflight.mjs --multimodal`. After build authorization follow `MAC_HANDOFF.md`: `npm ci --ignore-scripts`, then `npm run mac:setup -- --multimodal --ui`. Omit `--multimodal` for the older-SDK evidence build. Verify the actual SDK/API availability rather than assuming it. Compile both packages, hosted native target and UI target before adding more native features.
4. Review Vision result casts/concurrency, Core Graphics containment, SwiftUI category pickers, metadata restore/matching and speech callback state. Run the prepared tests on the Mac and fix actual compiler/runtime findings.
5. Complete preview-only package context support without inventing a route. Keep map catalog/notes useful when location is unknown. Verify scalar-count limits for approved descriptions versus transport schema and bound relevant context within the existing 24 KB local allowance.
6. Exercise the minimum journey: living-room overview/people/seating/obstacles; conversation focus; bathroom goal across a bedroom; hidden exit orientation; changed goal and way back; unknown place after restart; mismatched/overlapping maps; stale tracks; danger during rich speech; questions during mobility speech; mute/detail/budget changes. Compare against independent ground truth, not supplied room IDs as proof of localization.

## Known implementation risks to inspect

- UIKit completion callbacks identify text, not our request IDs. An old callback for repeated text could release a newer speech slot early even when the journal correctly marks uncertainty.
- Map/alignment/goal checks protect pending answers; changing source while an answer is already speaking needs complete cancellation review. A repeat requested while busy may currently be declined rather than retained.
- Scene delivery's 0.5 m/30-degree movement limits and six-second track windows can discard useful responses during walking or slow model calls. Do not solve starvation by asserting stale spatial facts are current.
- Map room containment uses a 0.5 m candidate margin; route cues use an eight-second cadence and a near-one-meter key. These are provisional policy constants, not measured accuracy or safety results.
- Metadata matching and canonical encoding still perform main-actor work. Review latency separately from urgent local hazards.
- Swift grapheme-count bounds may differ from JSON Unicode-scalar bounds for map prose. Context packing can exceed the local adapter's allowance and fall back; adaptive relevant-room packing is not implemented.
- Category preferences are prompt hints in rich generation; evaluate conflicting explicit questions, fallback selection and muted categories.

## Remaining product gaps

Automatic/cross-device place and floor localization, verified body alignment, physical route/obstacle integration, family identity, a complete temporal world registry, learned reviewable preferences and full outing/return memory remain unfinished. Public release download/cache is present; authenticated publishing/reviews, private backup, ChatGPT account integration and Dot actions are not complete. Preview maps, stars, source tests and software builds do not establish independent mobility readiness.

Trial order remains Mac bench/failure checks, adult iPhone eyes-open ground-truth comparisons, seated eyes-closed interaction, then supervised brother sessions. Adult eyes-closed walking requires a separate sighted observer. Child mobility retains Q04–Q06, guardian involvement and qualified orientation-and-mobility review. Early hazards are simulated, never real drops or stairs.

## Reuse and provenance

The new adapters call documented Apple APIs; no new upstream implementation or model weights were copied/downloaded. New thresholds, policy and adapter code are not battle-tested. Preserve the pinned GRDB and other license/evidence records in `ASSISTANT_UPSTREAM_REVIEW.md` and earlier handoffs.

- [Core Graphics path containment](https://developer.apple.com/documentation/coregraphics/cgpath/contains(_:using:transform:)) supplies polygon containment.
- [Apple Vision tracking sample](https://developer.apple.com/documentation/vision/tracking-multiple-objects-or-rectangles-in-video), [sequence handler](https://developer.apple.com/documentation/vision/vnsequencerequesthandler) and [detected-object observation](https://developer.apple.com/documentation/vision/vndetectedobjectobservation) supply the documented tracking interfaces. Our integration has not run upstream sample tests or Apple/device checks.

## Transfer

Use the newest `artifacts/blind-assist-*.tar.gz` created with this handoff, its adjacent `.sha256`, and the included `HANDOFF_MANIFEST.json`. Verify the extracted tree using `node tools/check-handoff.mjs <extracted-folder>`. Earlier archives, logs and `artifacts/minimum-assistant/checkpoint.json` are historical snapshots and should not be overwritten. Packaging checks establish file integrity only.
