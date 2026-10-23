# Continuous companion: product intent and experience contract

Recorded 2026-10-23 from the user's product decisions. This is the canonical consolidated explanation of **why the companion exists and what the intended everyday experience must achieve**. It is a requirements document, not a statement that every capability works today, a release approval, or a guarantee of physical safety.

Read [PROJECT_VISION.md](PROJECT_VISION.md) for the overall direction. Use [EVERYDAY_COMPANION_ACCEPTANCE.md](EVERYDAY_COMPANION_ACCEPTANCE.md), [SPATIAL_COMPANION_ACCEPTANCE.md](SPATIAL_COMPANION_ACCEPTANCE.md), [CHILD_ASSISTANT_TEST_TRACKER.md](CHILD_ASSISTANT_TEST_TRACKER.md) and [ASSISTANT_FEATURE_CHECKLIST.md](ASSISTANT_FEATURE_CHECKLIST.md) for implementation and evidence. [TASKS.md](TASKS.md) owns the backlog; [PROGRESS.md](PROGRESS.md) records results; [SESSION_LOG.md](SESSION_LOG.md) preserves decisions; [MAC_HANDOFF.md](MAC_HANDOFF.md) orders native validation. Do not infer completion from this document or copy historical test counts into it.

## 1. The product is a personal companion, not a scanner menu

Build a free, local personal agent that a blind person can talk to naturally while living their life. Continuous camera and sensor information, memory, goals and tools extend the conversation. Navigation is one small part of this broader purpose, alongside reading, finding belongings, recognizing familiar people, choosing clothes, shopping, learning, conversation and companionship.

The aim is to reduce the information and effort gap between blind and sighted people. It is not to limit a blind person's interests, choices or understanding. The first interface and acceptance work target young children; broader adult use remains an important future direction. Claims of being the first or best are not a product requirement. Useful daily assistance matters more than novelty or a long feature list.

The local core must work without a paid API, subscription, developer key or runtime internet connection on supported hardware with required local assets available. Model and platform availability must be checked, not assumed. Network-dependent facts cannot be fabricated offline. A later Android implementation is a separate effort, not an existing capability.

## 2. Remove acquisition work, not just button presses

A voice command for each scanner is still a scanner menu. The normal experience must not require the child to choose a face/currency/product mode, find an invisible target, guess the camera angle, repeatedly take photographs, select their current room, or explain which sensor should run.

The intended ordinary loop is:

1. The permitted active session gathers useful observations without a separate capture request for each item.
2. It relates them to remembered places, objects, people, the conversation and the current goal.
3. It automatically invokes eligible specialist tools when the evidence and context justify them.
4. It verifies results before making claims and gives a brief useful answer or notice.
5. It retains the goal, relevant history and unfinished work through interruptions and room changes.

Saying “Where is my coat?” expresses a goal. It is not a request for the child to operate a camera system. Where coverage is insufficient, first use existing observations, memory and supported recovery. If a physical adjustment is genuinely necessary, give one brief, evidence-based instruction the person can follow, rather than an arbitrary “point your camera” loop. Do not pretend to see outside the camera's coverage or remember an object never observed.

A chest-worn phone is the intended arrangement. Capture framing, body versus camera heading, occlusion, orientation, movement and useful range must be tested in that arrangement. A held-phone demonstration does not prove the hands-free experience.

## 3. Continuous information means coordinated loops

An isolated photograph loses everything outside that moment and view. Everyday assistance needs ongoing observations together with out-of-view memory, current position and orientation, the user's objective and recent changes. The assistant should not forget a mapped exit because it is behind the user, or restart an entire room description whenever they move.

“Continuous” does not require every model to run on every frame. Use independent fast sensor/hazard processing, bounded asynchronous visual interpretation, persistent local memory, and an attention scheduler. Generation and ordinary speech must not block urgent valid hazard signals. Heavy work must be budgeted and cancellable; stale callbacks must not revive cancelled goals or become current facts.

“Always available” means the active, permitted session is ready for natural conversation and automatically eligible tools. It does not mean covert or unstoppable listening, bypassing an explicit off choice, continuous background camera operation contrary to iOS, or proven all-day reliability. Microphone mute, end session, separate camera awareness, permissions, model availability and operating-system lifecycle rules remain authoritative. Ordinary conversation should remain useful when a visual capability is unavailable.

## 4. Memory connects places, things and goals

Maintain useful local records at the appropriate level:

- Place/building or home, floor, room, mapped landmarks and functional connections.
- Observed objects, optional established personal-instance identity, appearance references and known associations.
- Observation source and time, capture coverage, uncertainty, and measured coordinates with their actual reference frame when available.
- User reports, corrections, preferences, lists and active/suspended goals, with attribution.

Unknown fields stay unknown. Coarse geographic location may suggest a building; it is not indoor pose. Coordinates from different maps cannot be mixed without validated alignment. Room appearance or a spoken room name does not establish the user's heading or current location within it.

Stable layout, such as a bed or television, should not be rebuilt or forgotten with every frame. Preserve useful map history and update supported changes. Movable belongings need last-seen histories and explicit ambiguity when similar objects exist. A finite cache is not a complete inventory of every item in every place. Durable maps, selected saved items and bounded observations have different retention responsibilities.

Automatically retrieve the relevant saved room/map and item context when supported recognition and localization permit it. Recovery should be bounded and should not trap the child in manual room-selection or repeated scanning. Uncertain recovery leaves useful conversation and nonspatial information available without inventing a position.

### Evidence must retain its meaning

- Fresh accepted observation can support only the claims its source, coverage, association and age justify.
- A remembered observation is a last-seen fact, not proof an item remains there.
- A user report remains “you told me,” not a camera finding.
- A proposed search location is a suggestion, not verified presence.
- Missing, conflicting or stale evidence means unknown. No detection does not mean absence, an empty room, a departed person or a clear path.

Memory makes a search useful beyond the current view. It never turns remembered geometry into current clearance or an old object location into safe reach/pickup authority.

## 5. Whole everyday journeys define success

### Coat, school and backpack

The user asks for a coat. The assistant retrieves an attributed observation of a coat on a bedroom hanger, even when that room is outside view. It can say that it remembers seeing the coat there and offer to help search. Unknown color must not block this useful history; an optional question can distinguish similar coats.

If the goal is preparing for school, retain it while the child asks the time, talks about something else or crosses another room. A relevant remembered backpack can become a suggested subtask, not an invented possession or purchase. Recheck live evidence before saying either item is present now. Any physical guidance requires validated target-specific position and route evidence. User cancellation ends the goal; casual conversation need not erase it.

### Exit beyond the current view

Use validated location, facing direction and mapped semantics to distinguish the room's functional exit from a cupboard or closet door. A hidden or out-of-view exit is not “no door.” A label of “door” alone does not establish where it leads. A stored doorway does not prove the current approach is clear, open or traversable. Missing semantic or alignment evidence stays unknown rather than sending the person toward a guessed exit.

### Money naturally enters the view

A supported banknote candidate in an active session should invoke the dedicated Saudi-note verifier automatically, without selecting a tab or first asking what the money is. A generic detector label, OCR number or language-model guess is not a denomination result.

Announce a denomination only after its evidence gates pass. If the observed capture explains the failure, give a short specific correction, such as bringing the note closer or improving illumination. Do not repeat useless instructions when the cause is unknown. Retry within a bounded current task and stop stale work. Identification does not establish authenticity, total money in the scene, payment, purchase or account balance. Supported Saudi notes are the initial scope; other currencies require their own assets and evaluation.

### Familiar people arrive

Known people include consenting friends and teachers as well as family. The child may not know someone is present and should not have to ask first. Process eligible faces from the ongoing feed, including multiple faces, and offer a brief accepted familiar-person hint once per meaningful encounter. Do not repeat it every few frames or merely because a timer expired. More detail or location can follow a question, subject to fresh evidence.

Unknown people remain unnamed. False matches, similar faces, occlusion, poor light, changed appearance and people leaving view must be evaluated. Clothing observed earlier may help maintain continuity of an already established track; it must never become independent identity proof or justify naming a person seen from behind. If identity cannot be established, a neutral suggestion to call the person may help obtain a better view without claiming it is a parent. Identity hints never authorize a child to leave with someone.

### Reading, products and shopping

Use the current goal to recognize when reading a page, label or product is useful. The assistant should first exploit the available view rather than demand manual framing before checking it. Keep a requested shopping list and relevant observations across the task; mention supported relevant sightings without narrating every shelf.

A barcode is an additional identity check, not a replacement for finding the product and not a mandatory child-operated scan mode. When visible geometry supports it, help obtain the code rather than making the person search blindly by trial and error. A decoded code, an actual product lookup, visual resemblance and a remembered name are different evidence. No matching database record means unknown identity, not an invented product. Never assume comprehensive Saudi product coverage.

### Light, appearance and everyday conversation

A relevant light change may matter at bedtime or when capture quality is inadequate; every change in brightness does not need narration. Distinguish measured illumination from assumptions about a room light switch.

Color and clothing assistance should distinguish supported observed appearance from uncertainty caused by lighting, material or segmentation. White versus pale gray matters when choosing a required outfit; do not certify it from an uncertain camera estimate. Broader wardrobe help can remember voluntarily supplied sizes and preferences and offer subjective styling suggestions. A size label does not prove fit. Descriptions should support the person's choices, not impose beauty judgments.

Homework, stories, time and ordinary conversation remain available without waiting for camera evidence they do not need. Current weather needs an actual weather source; local clock facts use the device clock and appropriate location/time context. Classify the question by what evidence it needs, not by forcing every answer through sensors or letting all answers bypass them.

### Cooking and household tasks

The long-term experience should connect a recipe, remembered cupboards, current ingredients, instructions and timers rather than require a separate scan of every object. It should remember where useful items were observed and the current step, while distinguishing historical location from current presence.

Heat, sharp objects, controls, food handling and reaching introduce distinct hazards. A visible oven or model description does not measure temperature, establish doneness or authorize touching a control. These workflows require their own supported sensing, safe task boundaries and acceptance. They are goals, not currently proven autonomous assistance.

## 6. Speak selectively; do not compete with the world

The information gate controls all ordinary assistant output, including automatic tools. Constant sensing must not become constant description. While pursuing a goal, provide only useful next information; when asked for a rich room description, offer it at the user's chosen level of detail. Preserve interests and preferences without distracting the person from their current objective.

Urgent valid hazard cues have independent priority. Ordinary narration must be interruptible, deduplicated and checked again at delivery for relevance and freshness. A child can interrupt repeatedly, change topics or ask where someone is; the assistant must not continue an obsolete instruction or confuse a partial utterance with task completion.

Coordinate app speech, VoiceOver, environmental listening and notifications instead of overlapping competing voices. The first tab presents settled assistant replies only, not a feed of technical status, streaming fragments or controls to traverse. Accessible helper/settings destinations retain necessary controls. Simplifying the primary screen must not remove stop/mute, privacy or recovery access.

## 7. Setup and exceptions must stay simple

Automatic normal behavior does not eliminate necessary setup, consent or user control:

- Adult/helper setup can install required local assets, configure supported hardware and review privacy without becoming the child's daily workflow.
- Familiar-person enrollment explains that local pictures will be used to recognize the person, obtains the applicable agreement, captures adequate views, names and saves the entry. Keep this understandable; do not burden a child with a technical dashboard or complex legal flow. Multiple photographs alone do not prove agreement. Entries are reviewable and deletable.
- During enrollment, prefer keeping the phone with the child and guiding the sighted subject into supported positions and angles. Do not casually take away the child's ongoing information source. If another mode necessarily reduces hazard coverage, report the actual limitation.
- A new room scan is deliberate work requiring movement and start/stop. Make it voice-accessible with explicit confirmation so discussing scanning with another person does not start it accidentally. Show the real evolving map and measured progress for a helper, not invented percentages.
- Community map downloads and any publication are explicit actions. Public-place geometry is separate from private home maps and personal memory; a rating does not establish alignment or present clearance.
- Honor explicit microphone mute, end session and camera-off choices. “Enabled by default” means eligible under those controls and actual permissions, assets and evidence gates, not forced operation.

## 8. Ground dangerous claims in real evidence, not fluent wording

The local LLM supplies language, context and supported tool use. It must not invent what the camera saw, physical distances, target locations or safe actions. Fresh target-specific evidence must support identity/measurement association, pose/frame, coverage, uncertainty and age, and must still be valid when delivered.

This applies to reaching for a cup as well as walking through a doorway. Category recognition plus a depth sample cannot distinguish a safe intended item from another nearby object. A tentative phrase such as “maybe” does not make an unverified physical instruction safe. Historical recall, nonspatial conversation and safe supported alternatives remain useful when an actionable claim is withheld.

No claim of zero hallucination, exact perception, unlimited operation, safe solo child use or sighted-person parity follows from architecture or passing tests. Child trust makes failures particularly consequential. Validation must precede child-facing physical trials, not use children to discover dangerous failures.

## 9. Privacy and future online delegation

Core perception, private images, room fingerprints, personal belongings, enrolled people and private memory stay on the phone. Do not restore online backup of private household data. Public community maps and developer-only tests are separate scoped flows, not permission to upload personal observations.

A future optional extension could let the user deliberately delegate selected tasks to their dot specifically, as a tool-enabled assistant authorized to act: restaurant or flight arrangements, sending approved messages, work or coding. A generic chat/completion API is not an equivalent integration. Voice-based writing should support composing, spoken review, targeted edits, undo and explicit authorization to send, not just speech-to-text. This is a roadmap idea only. No verified public dot integration API or working connection is claimed. It requires research, explicit opt-in, user-selected outbound information, clear recipient and task authorization, and separate privacy/security design. It must not silently export the continuous feed or become a prerequisite for the free offline core. The current work remains the already agreed local companion scope.

## 10. Acceptance measures the experience, not feature counts

Build a broad scenario corpus from blind people's everyday experiences, accessibility research and qualified orientation-and-mobility practice. Respect source and participant privacy. Internet examples expand coverage; they cannot prove every possible situation is handled.

Test complete journeys, not only isolated recognizer accuracy or keywords:

- Tasks begin without choosing a feature mode; count unnecessary UI actions, aiming requests, repeated prompts and manual recovery.
- Remembered and currently observed facts remain distinct across rooms, similar objects, moved items, restarts and changed goals.
- Ordinary questions bypass irrelevant sensor waits; physical questions cannot bypass their evidence requirements.
- Automatic candidates invoke the right verifier, with no false denomination, identity or product claim from an unverified candidate.
- Repeated interruptions, cancellation, late callbacks and audio-route changes do not produce obsolete replies or resurrect ended work.
- Hazards remain responsive during reading, memory retrieval, recognition, generation and long speech; uncertainty is never announced as clearance.
- Measure first useful response, end-to-end task time, notice before a person leaves view, interruption latency, completion and useful fallback, not merely raw recognition speed.
- Test chest mounting, orientation, limited field of view, darkness, occlusion, no depth, tracking loss, missing models, offline use, permissions, foreground/background transitions, VoiceOver and explicit off/end behavior.
- Measure sustained heat, battery, memory, backpressure and throttling on supported physical devices. Configured scheduling rates and simulator timings are not measured phone performance.

Preserve an evidence ladder: source review → deterministic/synthetic policy tests → actual model and recorded-data evaluation → native build/integration → controlled physical-device tests → supervised usability and physical-task acceptance. Record model/assets, revisions, conditions, failures and remaining gaps. High performance on a curated benchmark does not establish deployment accuracy; report harmful false positives, abstentions and missed opportunities separately.

Start physical validation with bench and simulated failures, then controlled adult trials and appropriate expert review before supervised child trials. Keep independent-use claims out of the release until supported by the necessary evidence. Reuse maintained upstream components and documented platform APIs, recording licenses and adapter differences; reputation and upstream tests do not certify our integration.

## 11. Continuation rule for future sessions

Before adding a new screen or tool, ask: does this remove work from the person, preserve their context, and cooperate with the ongoing assistant, or does it make them operate another scanner?

Before claiming progress, ask: is it designed, implemented, portable-tested, native-built, device-measured, or accepted for the intended use? State the actual stage in the linked trackers. Never mark a whole everyday journey complete because its individual components compile.

Architecture references: [memory and information engine](research/MEMORY_AND_INFORMATION_ENGINE.md), [attention and speech](research/ATTENTION_AND_SPEECH.md), [community maps](research/COMMUNITY_MAPS.md), and [upstream review](research/ASSISTANT_UPSTREAM_REVIEW.md). This intent document explains the destination; those records and the acceptance trackers determine the supported next step.
