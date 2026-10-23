# Continuous spatial companion: implementation and acceptance

## Purpose

The assistant should gather useful visual information during ordinary foreground use, remember previously observed things and rooms, maintain the person's goal through conversation and room changes, and answer without first requiring the person to aim at an object they cannot find. A camera has a limited field of view; historical observation is not omniscience or proof that a movable object remains there. This checkpoint adds missing connections, not a claim of complete autonomous assistance.

## Existing foundation and gaps identified

| Capability | Starting state | This checkpoint | Remaining gate |
| --- | --- | --- | --- |
| Foreground camera, depth, independent hazards | Existing | Preserved; passive work asynchronous and bounded | Physical latency/thermal/drop tests |
| Room appearance and explicit item memory | Existing, separate from object observations | Passive localized-category and saved-appearance candidate history in existing private GRDB store | Actual matcher accuracy and useful coverage |
| General-object boxes | Optional detector; no bundled asset | Retain boxes/source/capture time/frame; cached model; incompatible outputs fail closed | Licensed compatible model artifact and phone evaluation |
| Previously seen object outside camera view | Only explicit reports/saves | Historical recall before another current-view search; room/time retained | Precise instance identity and validated object/depth association |
| Saved RoomPlan/world-map frame | Saved separately; no durable provenance bridge | New scans pair artifact hashes and origin anchor; ARKit recovery gates frame reuse | Apple build and physical relocalization/drift tests; legacy scans have no new binding |
| Imported authored maps | Manual measured alignment | Remain separate; never assume same frame as RoomPlan | Measured cross-frame transform before automatic use |
| Goal through interruption | Goal survived; active search did not | Capture original search at voice onset; resume remaining lifetime only after ordinary reply | Actual speech/onset/timeout testing |
| Goal change/cancel | Cleared route and valid measured alignment | Retires route without erasing location; tracking loss still invalidates pose | Native route/room trials |
| Relevant observation notice | No passive object source | Once per active focused goal after freshness/pose checks, completion-accounted | Audible dedupe/interruption tests |
| Privacy and review | Existing local encrypted/protected store | New bounded namespace, clear/delete controls, no image export | Device backup/file-protection inspection |

## Whole-task test matrix

1. A localized backpack candidate is observed in a bedroom without a find command. Later, outside its current view, a find request recalls the dated bedroom observation, not “it is there now.”
2. A person has two similar cups. Same-category observations remain ambiguous; a saved appearance candidate never becomes ownership or pickup authority.
3. A validated identity moves to another measured site in a synthetic fixture. Newer identity evidence supersedes old history. Generic category observations cannot silently do this.
4. A new AR session or lost tracking preserves historical notes but invalidates live geometry. A room name/user confirmation alone cannot restore a metric frame.
5. A saved map with missing/tampered artifact hash, wrong origin marker, stale frames, wrong session or absent relocalization transition cannot restore frame association.
6. A real paired map passes synthetic lifecycle checks; unrelated authored-map coordinates remain unaligned.
7. A 20-second object search is interrupted by an ordinary question and another question. It retains its original start/attempts and cannot extend forever.
8. Pause, cancel, changed goal, ended/muted session, expired search or generation change prevents restoration.
9. Moving into an intermediate room does not cancel the conversational goal. Goal replacement clears the old route, not valid measured position.
10. A focused object's fresh candidate prompts one short notice. Repeated frames do not narrate everything; interrupted notices are not marked fully heard. Hazards still take priority.
11. An object is absent from a later frame. No detector miss proves absence; history remains explicitly historical.
12. No depth, unknown body heading, unvalidated association or stale pose means no physical direction/reach/pickup instruction. Ordinary conversation remains available.
13. Clear sighting history, restart, and reopen an older map. The old scan is not automatically resurrected as sighting history. Explicit room/item deletion removes associated history.
14. No compatible detector is bundled. The helper screen reports the capability gap; saved-item appearance comparison remains available. No empty detector result is represented as proof of an empty room.

## Not completed by this checkpoint

- Production-quality general-object recognition, personal-instance identification or target-mask/depth calibration.
- Automatic safe indoor routing across arbitrary rooms, cupboards, unseen areas or imported maps.
- A complete shopping-list/product database, cooking workflow, heat/doneness sensor or household manipulation system.
- Native Apple compilation, actual Foundation Models behavior, VoiceOver delivery, real camera accuracy, all-day battery/thermal performance or independent child-use acceptance.

The physical-object guidance validation gate remains false. Source policy tests cannot justify changing it. Frame provenance enables correct plumbing and future measured validation; it is not itself physical correctness.

## Reused components

Existing Apple Vision/Core ML detection and foreground feature prints, ARKit/RoomPlan world maps, the existing GRDB 7.11.1 store, BodyHeadingEstimator, SpatialFacts and centralized attention/speech admission are reused. No new database, SLAM system, recognizer, navigation algorithm or inference runtime was introduced. See research/SAVED_WORLD_FRAME_BRIDGE.md and the detector import contract for sources, artifact requirements and native acceptance.

## Execution record

Pending final coordinated test counts are recorded in PROGRESS.md only after completion. Tests of synthetic observations and state transitions are distinct from recognition accuracy and the physical iPhone scenario run.

### Latest whole-task cases and scope
- Coat-on-hanger → room → school, with a backpack subtask and casual interruptions: retain the primary goal and source-attributed object-location report. A color question is optional; unknown color must not block a saved-location search. A generic detector that lacks a coat class cannot pass recognition by guessing.
- Mapped functional exit outside the current view vs cupboard door: use authored map semantics when available, not a visual label of “door.” Occlusion does not prove absence or clearance. Missing semantic distinctions remain unknown. Authored map alignment and validated traversability remain separate from saved RoomPlan frame recovery.
- Across houses/floors/rooms: records have optional place/floor/room labels, original measured frame coordinates, source and time. Current authored-map context supplies known hierarchy; a standalone room scan does not invent its building/floor. Queries search all recorded places and retain ambiguity among similar objects.
- A phone/laptop in a closet cannot be inferred from an old room picture. Use prior attributed observations/reports as search alternatives, explicitly historical. No detection is never “not there.”
- Every task run counts unnecessary aiming/scanning prompts, repeated instructions, discarded context, interruptions handled, useful fallbacks and actual completion. A child should not need to operate each sensor tool manually.
- Continuous foreground capture is implemented subject to consent, OS lifecycle, thermal/battery budget and model availability. This is not proof of 24/7 background camera operation or all-day native reliability.

Historical-spot orientation is a developer-only supervised path, not a child-facing toggle. Exact hash-bound saved-map RoomPlan points may be approved by an empirical, expiring DEBUG receipt. Current body pose, frame recovery, point ID, uncertainty and sector boundaries are checked. It never enables identity, physical reach, clearance or navigation. See research/RECORDED_SPOT_DEVICE_ACCEPTANCE.md for the acceptance procedure. No receipt or native pass is supplied in this milestone.

### Continuous-observation cadence
The AR/depth/hazard path is capped at 15 Hz and is not stopped by LLM generation, speech, currency or object-search busy flags. Passive visual inference is asynchronous, one request in flight and at most once per three seconds. These are scheduler settings, not measured device rates. Test actual sensor latency during every tool, simultaneous interruptions and long speech, overload/backpressure, thermal throttling, low battery and camera interruptions. Depth/tracking loss keeps hazard status uncertain while RGB-only passive candidates can still be saved with capture time but no room, frame, position or geometry authority. Their results never trigger spatial or proactive current-location speech. RoomPlan scanning/relocalization likewise does not claim normal obstacle guidance.

The normal child loop is goal expression and conversation, not mode selection, manual room selection or repeated scanning instructions. Those operations do not count as successful whole-task completion. Adult setup/calibration, privacy controls and actual OS permissions remain necessary. The earlier saved-place-choice fallback is no longer the normal automatic path. The current bounded coordinator tries up to three attributed candidates, defers new resets during requested tasks, and leaves conversation/live RGB available on exhaustion without a manual-selection loop. Adult/manual recovery controls remain exceptional tools. Robust real-device multi-room recovery, thresholds and coverage are still unvalidated, not solved by passing policy tests. See EVERYDAY_COMPANION_ACCEPTANCE.md.

Stable furniture/layout history is not re-created from each frame. It remains source-attributed map history; actual changed-object observations are separate candidates until supported association can update them. Reading/color/light/familiar-person adapters exist with their own gates. Interpreting waves, offered hands, pointing destinations, aesthetic descriptions and social expressions is a remaining contextual capability, not implemented or validated by this milestone. A visible expression is not certain emotion, and a pointed destination cannot authorize movement without measured geometry.

Future adult wardrobe/shopping scenario: remember user-provided sizes, fit and preferences; describe supported observed color/pattern/cut and retrieve known clothing. Styling suggestions are subjective and need not infer skin tone/body type. A size label is not proof of fit, and uncertain lighting cannot establish an exact color. This roadmap does not change the child-first scope or claim a new styling engine.

The observation cache is bounded to 256 records/256 KiB. Up to 64 newest dated RoomPlan furniture observations are reserved against transient-candidate churn; the absolute byte cap still takes precedence. This is a useful bounded history, not a complete inventory of every object in every home. Durable saved maps remain separate. No category-site compression claims that two sightings are the same personal object.

Portable verification for this follow-on: 592/592 BlindCore (whole suite), 15/15 BlindMemory, 257/257 Node, default and DEBUG/familiar-person Swift parsing, firmware protocol and address/undefined-sanitized failure injection passed. LeakSanitizer could not run under this executor's tracing; leak detection was disabled for the address/undefined sanitizer rerun. Aggregate verification passed in a disposable source copy with existing dependencies; reviewed generated Debug flags were copied into the checked-in project. No Apple SDK build, device test or accuracy result is claimed.
