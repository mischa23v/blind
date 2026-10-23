# Blind Assist: a free, local conversational companion

Updated 2026-10-23. This document records the product direction and why it matters. It is a target, not a claim that the current app has achieved it. Read [SESSION_LOG.md](SESSION_LOG.md) for the decisions and failed experiments behind it, [ASSISTANT_FEATURE_CHECKLIST.md](ASSISTANT_FEATURE_CHECKLIST.md) for capability-by-capability status, and [MAC_HANDOFF.md](MAC_HANDOFF.md) before continuing Apple development.

## The first building block

Build a free assistant that adults and children can talk to naturally throughout a voice session, using a built-in on-device language model and local tools. Accessibility sensing extends that companion; this is **not a navigation app with chat added afterward**.

The user's comparison with Ella/dot describes the desired experience: an ongoing conversation, useful memory, changing topics, interrupted answers, retained goals, and tools that actually do useful work. It is not a request to reproduce private internals, a claim of access to them, or a promise that a small local model has the same capabilities or quality as a hosted assistant.

The motivation includes helping a blind child participate in ordinary conversation, make choices and understand the world, without recurring bills or technical account setup. The product must also respect adults' independence. Blindness is not a reason to limit the person to object labels, navigation instructions or simplified interests.

## What a good first experience feels like

- The user starts a clearly indicated voice session. After the necessary permissions, ordinary conversation does not require pressing Talk or Repeat for every turn.
- They can ask a question, follow up, correct a misunderstanding, interrupt an answer, change the subject, return to a previous goal, or stop listening entirely.
- The assistant speaks naturally and promptly, not as a transcript reader or a form that restates its extracted fields. Silence does not require filler or another question.
- It remembers relevant information and the current goal without flooding a small model with the entire history. A new topic does not automatically erase an unfinished task; an explicit cancellation does.
- It uses available tools, reports their actual outcomes, and distinguishes a suggestion from an action and an attempted action from a verified result.
- Conversation works independently of camera or LiDAR readiness. A missing visual capability limits that capability rather than making every conversation unavailable.
- Voice, text, VoiceOver and simple accessible controls provide alternatives. Quiet narration, microphone mute, session stop and camera stop must have clear, distinct effects.

“Always listening” means listening during a user-started, permissioned session with visible and accessible controls. It does not mean covert recording, uploading audio, an unstoppable microphone, or proven background/locked-screen operation. Sustained duration, battery, heat, audio interruptions and operating-system restrictions require measurement. Do not advertise literal unlimited or 24-hour operation.

## Product commitments

### Free and local by default

The core experience must not require a paid API, subscription, developer key or cloud account. The selected iPhone direction is Apple's on-device model and documented local platform APIs, subject to actual device, operating-system, language and installed-model availability. A later Android implementation is a separate workstream, not an existing port.

Verify offline behavior on supported hardware. Explain unavailable capabilities honestly on unsupported hardware; a deterministic fallback is not equivalent to a fully functioning local LLM. One-time model or platform asset installation, where needed, must not become an undisclosed runtime network dependency.

Camera frames, private room records, personal item references, family information and private conversation memory stay on the phone. Do not restore the older proposal to back up private memory to GitHub. Developer-only comparison code is not permission to upload personal data and must not become a required production path. Optional public-place downloads remain distinct from private memory.

### Conversation and agency before a larger feature catalogue

First make the ordinary companion coherent, grounded, interruptible and useful. Then connect reliable visual, memory, orientation and other tools through that same conversation. Do not postpone useful nonspatial descriptions until complete navigation exists, or use navigation work to avoid fixing basic dialogue.

The user chooses what to discuss and do. Use short next steps when pursuing a goal, allow more detail when asked, and avoid repeated unsolicited descriptions of familiar surroundings. Keep useful tabs and review/settings screens; hands-free interaction is not a reason to remove accessible controls.

### Evidence, not plausible completion

Every claim must preserve its source and time:

| Evidence kind | Meaning | Required boundary |
| --- | --- | --- |
| Fresh observation | A specific sensor or tool actually observed something, with freshness and coverage limits. | Revalidate after delay, movement, cancellation or a new request. |
| User report | The user said something, possibly about the past. | Retain attribution and time; do not silently promote it to observation. |
| Remembered information | A saved report, map or earlier observation. | Helpful context, not proof of the current scene. |
| Inference or proposal | A possible interpretation or next step. | Label uncertainty; do not treat it as an executed action or fact. |
| Unknown | Evidence is absent, stale, conflicting or insufficient. | Say what is unknown and offer a supported next step. |

The observed regression “I last left it on the kitchen table” → “Your cup is on the kitchen table” is unacceptable. Last reported location can guide a search; it does not establish present location. Likewise, no search result is not “not found,” losing a person from view is not proof they left, and a remembered map is not current clearance. Current external facts unavailable offline must not be invented.

## Target architecture and behavior

These are required responsibilities, not a claim that every component is connected today:

1. **Session and turn control:** explicit session lifecycle, local listening, end-of-turn handling, cancellation, interruption, audio-route recovery and prevention of the app hearing its own speech as a new user command.
2. **Bounded conversation and memory:** relevant chronological context; editable local preferences; source/time-aware records; correction and deletion; controlled context rollover rather than unlimited transcript growth.
3. **Goal and task state:** active, suspended, completed, cancelled and failed/unknown outcomes; retain the user's latest intent, useful progress and supported next step. A change of room or a casual question is not automatically a new task.
4. **Tool execution and verification:** capability discovery, validated arguments, required consent, request/goal identity, pending/result/error states and verified completion. Stale or cancelled callbacks cannot revive an old goal or overwrite a new answer.
5. **Evidence-aware response:** answer the actual question with supported facts, preserve uncertainty, stream only eligible output and avoid claiming an action succeeded before its result exists.
6. **Accessible output arbitration:** current hazards interrupt immediately; necessary movement/orientation cues follow; ordinary conversation and descriptions remain interruptible and respect the user's information preferences.

Reuse maintained upstream implementations and documented platform APIs where they fit. Record exact revisions, source/model/data licenses and local adapter changes. A well-known dependency, paper or passing upstream test does not validate this integration. Do not invent a new database, inference runtime, recognizer or navigation system merely to fill a checklist box.

## Accessibility tools extend the companion

The intended phone arrangement includes a chest-worn rear camera. Actual framing, body versus camera heading, field of view, movement, clothing occlusion and useful target size must be tested in that arrangement, not assumed from handheld or simulator use.

Useful tools include reading text, describing surroundings and choices, finding requested items, recalling approved private information, and using measured spatial evidence for orientation. Familiar-person hints require consent and tentative identification; currency requires a validated reference pack and costly-confusion evaluation; clothing appearance is not certified fabric color. Retain each feature's own availability and acceptance gates.

Public community maps may provide reviewed geometry and place information for offline use. They must exclude private homes, personal photos and family memory. A map rating, downloaded mesh or room name does not establish current location, alignment or a safe route.

### Safety boundaries remain independent of the model

- Immediate valid local hazard alerts must not wait for the LLM, memory lookup or network.
- Hazard distance, direction, height, up/down, step counts and clearance come only from valid measured evidence and code. A model may identify a visible hazard or what it is near, not invent its geometry or declare a path safe.
- Ordinary object-location estimates, when permitted, must sound approximate and must not bypass the stricter hazard rules. Calibrated step estimates come from code, not a population-average stride invented by a model.
- Requested-answer and narration controls must not suppress urgent hazards. Richer ordinary information remains available at the user's chosen detail and frequency; VoiceOver speed is not an ability score.
- Child-facing mobility is a later supervised acceptance stage after bench/failure checks, controlled adult device trials, guardian involvement and qualified orientation-and-mobility review. Begin with simulated hazards, never real drops or stairs.

## Acceptance sequence

1. **Grounded typed companion:** run actual multi-turn conversations, corrections, temporal reports, topic changes, cancellation and restart cases. Inspect meanings and final state, not just keywords or successful compilation.
2. **Natural voice session:** prove repeated listening, useful end-of-turn timing, speech interruption, echo handling, stop/mute behavior, VoiceOver coexistence and recovery on a supported physical phone.
3. **Local tool loop:** demonstrate real execution and verified outcomes, including unavailable tools, failures, stale results, changed goals and safe cancellation.
4. **Sustained accessible use:** measure time to first useful output, total turn time, memory growth, interruptions, thermal/battery behavior and supported session duration. Simulator timing is not phone timing.
5. **Grounded sensing and supervised mobility:** validate the actual sensor/model/native combination, chest-mounted use and failure conditions before any claim of everyday independent use.

Some work can proceed in parallel, but later features do not excuse a failed first building block. The current priority is fixing the ordinary companion's evidence handling and session behavior. The capability checklist and dated evidence determine what is complete; this vision alone does not.

## Keeping future sessions aligned

Start with this vision and the latest session entry. Use [TASKS.md](TASKS.md) for the detailed work backlog, [PROGRESS.md](PROGRESS.md) for historical implementation evidence, and the capability checklist for the companion-first gap review. Older “offline mobility prototype,” private-cloud-backup and press-to-talk descriptions do not override the newer direction recorded here.

For every meaningful change, record what was requested, what changed, what actually ran, what failed, and what remains device-pending. Preserve failed examples. Distinguish source implementation, portable tests, Apple builds, actual app behavior and physical-device acceptance. Integrate with the existing `master` branch without force or overwriting concurrent work; publication is not deployment or release acceptance.
