## Continuous spatial companion follow-up — 2026-10-23

The clarified goal is passive foreground awareness plus private spatial/object history and goal continuity, not a collection of scanners. See [SPATIAL_COMPANION_ACCEPTANCE.md](SPATIAL_COMPANION_ACCEPTANCE.md) for the existing/implemented/pending matrix and whole-task scenarios. New connections retain detector boxes/capture provenance, saved-appearance candidates, private historical recall, paired RoomPlan/world-map frame provenance and bounded search resumption. Task cancellation no longer erases measured alignment. Camera position is no longer saved as an object's measured point.

No general detector artifact is bundled. Model import is explicit; native output/accuracy and model/license acceptance remain gates. Existing center-depth association is not validated, and physical-object guidance remains disabled rather than treating history as a present location. Apple SDK/device/model/VoiceOver and household-task acceptance are still required. This is not completion of every shopping/cooking/navigation capability.

## 2026-10-23 — Final coordinated child-assistant candidate

Reviewed and integrated all seven Claude commits without replacing the newer assistant-first primary source. Fixed reader/page/photo stale-work races, mutual tool cancellation, completed-speech accounting and foreground/pose/freshness fencing. Added bounded currency retries and separately authorized Debug-only private-pack device testing; Release remains unapproved. Simplified all tabs and made Home settled reply-only, with genuine live room-scan map/counts for a helper. Preserved hands-free eligible startup, explicit stop/mute/off and OS permission limits.

Integrated existing-model per-face batch matching and once-per-encounter tentative notices through attention and scoped cancellation. Enrollment is photos → name → confirmed save. Added clock evidence and bounded temperature/location/color routing. Withheld unvalidated object-interaction directions rather than presenting abstention as improved recognition accuracy. No private family details or runtime images are included.

Final source verification and open Mac/iPhone gates are in [CLAUDE_INTEGRATION_REVIEW.md](CLAUDE_INTEGRATION_REVIEW.md), [PROGRESS.md](PROGRESS.md), and the canonical [CHILD_ASSISTANT_TEST_TRACKER.md](CHILD_ASSISTANT_TEST_TRACKER.md). Earlier actual-model hallucination/latency failures stay open. Portable tests are not model, VoiceOver, recognition-accuracy or child-use proof.

# Blind Assist session log

This is a concise project history for future development sessions: what was discussed, why decisions changed, what was actually done, and what still needs proof. It is not a verbatim transcript or a substitute for test evidence.

Read [PROJECT_VISION.md](PROJECT_VISION.md) first for current product intent and [ASSISTANT_FEATURE_CHECKLIST.md](ASSISTANT_FEATURE_CHECKLIST.md) for the live companion capability review. Older entries and counts describe their own checkpoints only. A passing source test, Apple build or simulator run is not physical-device acceptance.

## 2026-10-23: Claude integration, accuracy fixes and Saudi currency follow-through

The user asked to review and fix Claude's work before adding it to the primary branch, explicitly emphasizing correctness and useful Saudi-note recognition/retake guidance. The seven-commit branch lacked the newer assistant-first milestone, so the integration preserved both instead of replacing current source with the branch tip.

The reviewed additions are Seeing-AI-style local accessibility features, not the Seeing AI app's proprietary source: live text, framed page OCR, barcode/QR, light feedback, picture exploration, Arabic status text and optional Lock Screen status. Fixes prevent old reader/photo/search results from speaking after Stop, restart, a changed goal, hazard, background transition or moved camera. Page reading is tracked and chunked under the existing word allowance. Photos remain in memory; their outputs are snapshots, never live-room evidence. Actual OCR/object accuracy remains unmeasured on the phone.

Saudi currency reference matching gained rejection-only policy hardening and reproducible development diagnostics, not new neural-model training. Explicit retry uses a newer camera frame, a 30-second window and at most two additional attempts; unavailable builds do not invite endless captures. Measurement-backed guidance distinguishes a small, clipped or multiple-note view from a generic unknown. Production calibration remains unset. A separately configured supervised developer device build is a follow-on, not a claim of production validation or complete Saudi paper/polymer coverage.

Portable integration results and remaining Apple/device tests are recorded in [CLAUDE_INTEGRATION_REVIEW.md](CLAUDE_INTEGRATION_REVIEW.md). Historical normal-app hallucination and latency failures remain open until the exact new app is tested. Primary publication and backup are coordinated separately; this source note itself does not establish a remote commit or deployed build.

## Current handoff: 2026-10-23

**Current product:** a free, on-device conversational companion for children first; adult support remains a future direction. Natural ongoing conversation is the first building block; visual accessibility and mobility tools extend it, rather than defining a navigation app with chat attached.

**Work authorized:** fix the identified gaps, compare the intended continuous-assistant behavior systematically, and preserve the vision and session history as repository Markdown. The source milestone and portable verification are recorded below; this does not declare the companion complete or the latest combined source Apple/device-tested.

**Most important known failure:** the normal app converted a last-reported cup location into certain present location. The last recorded normal-path first complete sentence took approximately 8.385 seconds in the Mac/simulator experiment. These are correctness and responsiveness failures, not minor wording issues.

**Preserve:** local-only private data; free core operation; independent sensor hazard handling; existing spatial/consent/freshness gates; Mac/backend work; the existing primary branch name `master`; and concurrent changes. Do not change the selected model simply to avoid diagnosing the app's context and execution pipeline.

**Next acceptance:** evidence-grounded multi-turn behavior in the normal app, then the supported physical-phone voice/tool loop. Record exact source revisions and fresh results. See [MAC_HANDOFF.md](MAC_HANDOFF.md) and [shareable companion evidence](ios/validation/companion-chat/text-chat-status.json).

## 2026-10-23: Child-first simplicity clarification

The user subsequently specified that only children are using the current release: Home should show only the assistant reply for VoiceOver; Rooms should show saved rooms and simple Start/Stop scanning, with the actual map and progress visible to a sighted helper; all other tabs/settings should be simple and screen-reader-friendly. They also requested familiar, direct workflows such as adding a person through multiple photos, a name and Save. This updates the current interface target without removing explicit stop/mute controls, sensor warnings, privacy or consent. Native VoiceOver/recognition acceptance remains open. The user further clarified that this is one continuous assistant using camera/sensor context, not separate tools the child must repeatedly start, and that fresh known-person arrivals should be announced proactively. Foreground sensing now defaults on while respecting saved off choices, permission denial and background limits; the all-face/gallery-arrival implementation is tracked separately from the existing single-face workflow.

## 2026-10-23: Companion-first clarification and durable project records

### Discussion and decision

The user clarified that the first building block is a free version of the assistant experience: adults or children can talk naturally, with a built-in local LLM and different tools. They explicitly rejected treating the goal as a navigation application plus chat.

The requested behavior includes remaining available throughout a voice session, responding to new turns, interruptions and changing topics, remembering useful context/goals, and doing real work through tools. “All the time” is an experience goal, not evidence that the platform supports unlimited background microphone/camera use.

The user asked to fix all gaps, list the expected assistant features and check that each exists, and add well-named Markdown records so later sessions understand both the work and its purpose.

### Result and current status

- Created [PROJECT_VISION.md](PROJECT_VISION.md) to establish the companion-first direction and its privacy, grounding, accessibility and safety boundaries.
- Created this session log to preserve decisions and failures without requiring future sessions to reconstruct a large chat transcript.
- A separate [ASSISTANT_FEATURE_CHECKLIST.md](ASSISTANT_FEATURE_CHECKLIST.md) tracks the complete gap review, implementation status, required tests and platform/device limits.
- The bounded source integration is complete for this checkpoint. New code and portable tests are separate from real Apple-model, voice and device results. No deployment or all-features-complete claim is made here.

### Source milestone and review

The integration base was verified as `d6d4236` on 2026-10-23. Integrated source changes include assistant-first conversation routing; explicit voice-session start/end and microphone mute; an independent camera toggle; bounded listening recovery; validated streamed-phrase speech; a small registered read-only tool loop; historical/current evidence checks; bounded original user reports with correction/forget controls; and task pause/resume/cancel state.

The final bounded additions provide early acoustic-energy onset with transcript fallback, private headset-removal pause, fresh on-demand read-only Vision candidates, an explicit local General/Adult/Child-support preference, and a single reduced-context overflow retry without replaying speech/tools. Acoustic energy is not speaker-aware/semantic VAD; selected mode is not verified age or guardian presence. Fresh visual evidence keeps its 0.5-second and pose gates rather than loosening them to make slow replies speak.

Fresh portable results: 455/455 BlindCore, 14/14 BlindMemory, 150/150 Node and 17/17 synthetic simulation cases passed; firmware protocol/failure sanitizers and Swift source parsing passed within the precise limits in [PROGRESS.md](PROGRESS.md). The active Mac Xcode project was not regenerated. Six definite source-review findings were corrected. These checks do not prove actual Apple-model/audio behavior, latency, all-day endurance or child-use suitability.

The user then requested pushing this completed bounded source milestone to the shared primary branch and moving next to currency. Publication must be nonforce, preserve concurrent changes and verify the resulting commit. The full residual list is in the feature checklist; remaining design work is not mislabeled as hardware-only.

### Why it matters

Feature breadth cannot compensate for a companion that misunderstands ordinary updates, forgets intent, cannot be interrupted or invents an action result. The first milestone is a coherent assistant, then reliable tools in that conversation. Future sessions must not drift back to a mobility-first interpretation merely because much existing code concerns sensors and maps.

## 2026-10-22: Public continuous-assistant research

Research findings were reported on 2026-10-22, including the evening review at approximately 21:12 UTC. This was research and source inspection, not adoption or validation of a complete replacement assistant.

| Reference | Useful direction | Limit or decision |
| --- | --- | --- |
| [WorldScribe](https://github.com/HumanAILab/worldscribe) | Continuous visual description; server-side frame identity, cancellation and freshness patterns. | MIT source; incomplete system and server-oriented architecture. Not a ready local iPhone companion. |
| [CMU AR/OD/LLM indoor navigation](https://github.com/CMU-TBD/ar-od-llm-indoor-navigation) | Separation of client, perception, language and navigation responsibilities. | Inspected server is MIT; client README says “coming soon.” Azure Spatial Anchors dependency is retired. Not a complete reusable phone app. |
| [Touvigation paper](https://arxiv.org/html/2609.21828v1) | Target tracking and task-oriented visual guidance research. | Paper evidence; no verified matching implementation was established in this review. Do not invent a code-adoption claim. |
| [NaviGPT](https://github.com/PSU-IST-CIL/NaviGPT) | Concrete accessible-navigation interaction reference. | CC BY-NC 4.0 is not unrestricted reuse. Inspected code uses an outdated model endpoint and a prompt asking the model whether it is safe to walk. Do not adopt that clearance behavior. |
| [EgoBlind](https://github.com/doc-doc/EgoBlind) | Temporal and false-premise evaluation ideas for assistive visual conversation. | Noncommercial dataset restrictions apply. A benchmark is not a navigation application or proof of this app's safety. |

**Conclusion:** reuse specific licensed components or tested patterns when they fit, not an assumed complete architecture. Keep model freshness, source/time attribution, cancellation and result verification explicit. None of these sources demonstrates the full free local companion required here.

## 2026-10-22: Actual companion conversation failed despite builds and fixtures

### What was requested and tried

The intended interaction moved from a Start/Talk/Repeat-focused dashboard to an ongoing hands-free companion, while preserving useful people/maps/settings controls. Early microphone recovery allowed a spoken response in a simulator-specific setup, but conversation quality remained unacceptable. That workaround was a local diagnostic, not a redistributable speech model or a phone pass.

The user then paused voice because it was slow and repetitive and required actual typed interaction in the running app. `--text-only` disabled automatic microphone/camera startup and speech for diagnosis. The work retained the original local model and active AuraFace project rather than replacing the backend or regenerating away local configuration.

Several context and prompt revisions were tried. The final normal path streamed a natural answer before separate structured task/fact extraction. Old assistant replies, empty fields and duplicate current input were excluded from prompt context; stored private history was not erased. Request/goal revision checks and a failure deadline protected against obsolete or late results.

### What the actual app showed

- A minimal debug baseline answered “Help me find my cup” with a sensible last-location question. This one turn did not exercise the normal context/task pipeline.
- The normal path still offered an unsupported leading suggestion about a table.
- After “I last left it on the kitchen table,” it answered “Your cup is on the kitchen table.” **Failed:** a historical user report became certain current evidence.
- An earlier revision handled a closed/open fridge update and changed/cancelled a visible backpack goal, but the whole regression set was not rerun after the last context change.
- Preferred-name save/restart/recall was demonstrated in an earlier actual-app revision after correcting the storage namespace. That narrow result did not establish general long-term memory.

### Evidence and limits

The final recorded active Xcode build passed in 6.980 seconds; an isolated base simulator Apple SDK build also passed. Six affected privacy/spatial checks passed after the last changes; an earlier broader selection had 17 passes. These checks did not detect the conversational grounding failure.

The normal first complete sentence took 8.384551 seconds and the reply finished at 9.141065 seconds. Earlier structured tool/context round trips exceeded 60 seconds and were removed. None of these timings is physical-iPhone performance evidence.

The later Mac source checkpoint was published as `d6d4236`; source reconciliation preserved the currency/color work. The combined checkpoint had not received a fresh complete Apple build or scenario run when work stopped. Historical successful builds must not be attached to that combined source as though they were rerun.

Sources: [Mac handoff](MAC_HANDOFF.md), [progress record](PROGRESS.md), [actual chat results](ios/validation/companion-chat/text-chat-status.json), [scenario acceptance](ios/validation/companion-chat/interactive-agent-scenarios.json), and [prompt/source review](ios/validation/companion-chat/companion-prompt-research.txt).

### Carry forward

Isolate context contributions, preserve temporal/source distinctions and inspect actual answers across paraphrases. Do not blame the model alone when the minimal path and normal path differ. Prompt instructions and keyword tests are insufficient. Full task suspension/resumption, fresh sensor/action tools, long-session retrieval, voice/VoiceOver behavior and physical sensing remain acceptance work.

## 2026-10-22: Familiar-person, currency and clothing work

### Decisions and source work

- Familiar-person identification is an opt-in, consented, on-device experimental hint. Use tentative wording and unknown/lookalike abstention. It is not Face ID, identity proof or permission to follow someone.
- Currency comparison reuses local OpenCV reference matching with geometric/competing-label checks. **No validated reference pack is selected, so the normal app reports unavailable rather than guessing a denomination.**
- Requested clothing color estimates the captured appearance of a selected patch. It does not certify school-white fabric or reliably distinguish white, gray and cream under unknown illumination.
- Existing cancellation, freshness, privacy and hazard gates remain. Source publication preserves concurrent Mac fixes; it is not deployment.

The published checkpoint `cfda9143` preserved the Mac work and recorded these integrations. Later checkpoints supersede its source state, not the need for its device acceptance.

### Verification boundaries

The reconstructed currency/color checkpoint recorded 349/349 BlindCore tests, 116/116 Node checks and 55/55 portable reference-mechanics checks, plus C++ syntax and Swift parsing checks. These verify software mechanics and source contracts, not Apple native linking, real money accuracy or physical color recognition.

The historical reference experiment included an unsafe front/back composite acceptance. It must remain a recorded failure; the actual composite was not freshly retested through the Apple Vision/native path. Independent denominations, unknowns, lookalikes, costly confusions and adult phone trials remain required.

Earlier Mac base/multimodal/AuraFace builds and an XS Max launch were recorded, with 22 hosted iOS tests passing and an outstanding accessibility-audit issue. The XS Max lacks LiDAR; a launch or simulator run cannot validate the depth-gated live features. These results concern their specific earlier source configurations, not every later combined change.

Sources: [familiar-person experiment](research/FAMILIAR_PEOPLE_EXPERIMENT.md), [AuraFace backend](research/AURAFACE_NATIVE_BACKEND.md), [currency matching](research/CURRENCY_REFERENCE_MATCHING.md), [clothing color](research/CLOTHING_COLOR.md), and [PROGRESS.md](PROGRESS.md).

## 2026-10-08 to 2026-10-09: Foundation decisions retained today

These entries summarize earlier repository records, not a new validation run:

- The product expanded beyond obstacle labels to selective, useful visual information, social/environmental awareness, personal interests and choices. Danger governs interruption priority, not the full scope of the assistant.
- Local memory, explicit goals, corrections, room/outing continuity and evidence freshness were designed as shared foundations. Saved layout and past observations must not become current location or clearance after restart.
- The user established free on-device operation and offline core use. Private images, room/item references and family memory must not leave the phone. The earlier optional private GitHub backup proposal was withdrawn.
- Identity is established by consented on-device comparison with uncertainty, not a language-model description. Public-place map distribution is separate from private home/family information.
- Hazard geometry and clearance are sensor/code responsibilities; ordinary model-estimated object locations have a separate uncertain wording rule. Short, relevant output and response latency matter while pursuing a goal.
- Reuse proven upstream components, but verify the local adapter and its actual operating conditions. Research, implementation, portable tests, Apple compilation and physical acceptance are different milestones.
- Initial trial order is bench/failure checks, controlled adult phone checks, seated interaction, then supervised child evaluation with guardian and qualified mobility review. Software passes do not authorize independent child mobility.

Sources: [AGENTS.md](AGENTS.md), [project plan](PROJECT_PLAN.md), [memory/information design](research/MEMORY_AND_INFORMATION_ENGINE.md), [attention/speech design](research/ATTENTION_AND_SPEECH.md), and [acceptance plan](research/ASSISTANT_TEST_PLAN.md). Where an older design still mentions private cloud backup or broader home sharing, the later local-only/public-place-only decisions above control.

## How to add a session

Add a dated entry for a meaningful request, decision, implementation checkpoint or acceptance result. Keep it compact and include:

1. What the user wanted and why it matters to the product.
2. The decision, including what was rejected or superseded.
3. Files or behavior actually changed and the exact source checkpoint when known.
4. Tests actually run, their result and what they do not establish.
5. Failures, device-pending work and the next concrete acceptance step.

Do not replace a failure with a later plan, copy old test counts onto new code, or mark a feature complete because its source exists. Preserve unrelated edits and reconcile `master` before an authorized publication; do not force-push or treat a source commit as a release.

### Everyday-goal acceptance example

The user emphasized ongoing help such as preparing for school and finding a backpack through remembered rooms/pictures, rather than isolated feature buttons. They also want a known-person notice once, with more detail on request. Preserve last-seen/current distinctions, a continuing cross-room goal, existing private item/map memory and measured navigation boundaries. This is a required realistic acceptance scenario; room navigation and face recognition are not considered device-validated by source tests.

### General ability and safety clarification

The user emphasized that homework, current time, distance to a destination, people and scene descriptions are examples of a general conversational assistant, not a closed feature menu. The current release defaults to child-support wording without asserting that an adult is present. A missing read-only clock capability was identified for a small tool addition. Mobility-affecting claims must be checked against actual fresh relevant sensor/camera/map data before speech, including queued replies. Unknown or stale data is not permission to guess; source tests cannot establish complete real-world safety.

Portable verification for this follow-on: 592/592 BlindCore (whole suite), 15/15 BlindMemory, 257/257 Node, default and DEBUG/familiar-person Swift parsing, firmware protocol and address/undefined-sanitized failure injection passed. LeakSanitizer could not run under this executor's tracing; leak detection was disabled for the address/undefined sanitizer rerun. Aggregate verification passed in a disposable source copy with existing dependencies; reviewed generated Debug flags were copied into the checked-in project. No Apple SDK build, device test or accuracy result is claimed.
