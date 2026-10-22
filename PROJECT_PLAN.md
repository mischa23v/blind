# Blind Assist: persistent awareness and personal assistance

**Saudi money checkpoint, 2026-10-22:** Single-note recognition is being prepared with reuse of the official BankNote-Net encoder, a Saudi-specific trained head, Apple Vision/Core ML and conservative evidence/speech gates. No ready cleared Saudi model is bundled. V11 stays open until real data, conversion, held-out unknown/costly-confusion tests and phone acceptance pass. See [Saudi preparation](research/SAUDI_BANKNOTES.md).

**Current checkpoint — 2026-10-08:** paused for later continuation. [CONTINUATION_HANDOFF](research/CONTINUATION_HANDOFF.md) records manual map context, anonymous tracks, speech/control/preferences and unfinished work. Latest recorded suite: 39 passed before further edits; current source and Apple integration are unverified. Earlier evidence summaries below remain historical; the product requirements remain applicable.

Updated: 2026-10-08. **The relay and production-SQL checks pass; native memory/approval/recovery/dialogue/speech source is prepared for Mac verification. The complete assistant remains unfinished.** See [native handoff](research/NATIVE_MEMORY_HANDOFF.md) and PROGRESS for exact evidence and remaining work.

Latest continuation adds community packages, explicit interests, the optional Apple image adapter and a bounded speech-attempt journal. [Current evidence and minimum gaps](research/MINIMUM_ASSISTANT_HANDOFF.md): 37 Node tests and 15 context-delivery scenarios pass; Swift/Apple/device verification remains pending. These results do not demonstrate physical navigation or the complete assistant.

Start with [progress](PROGRESS.md), [task list](TASKS.md), [upstream review](research/ASSISTANT_UPSTREAM_REVIEW.md), [memory and speech engine](research/MEMORY_AND_INFORMATION_ENGINE.md), [community maps](research/COMMUNITY_MAPS.md), and [test preparation](research/ASSISTANT_TEST_PLAN.md).

## Product purpose

Give a blind person access to useful visual information across daily life: understanding places and people, discovering choices, participating socially, enjoying surroundings, avoiding danger, pursuing changing objectives, and returning from an outing. The assistant supplies information for the person's own reasoning and decisions. Do not treat blindness as a lack of understanding or assume a low information capacity. Mobility is one application of this shared information foundation.

The delivery order is explicit: **danger interrupts immediately; due mobility and orientation cues take priority next; rich awareness, discovery and description are the ongoing assistant experience**. This is an interruption order, not a ranking of product value or an instruction to postpone useful information until navigation is finished. The assistant selectively communicates useful parts of a broad world model, guided by danger, goals, changes and personal interests. [Attention and speech research](research/ATTENTION_AND_SPEECH.md) informs this design without imposing ordinary conversational speed on expert listeners.

The assistant remembers the person, familiar people and places, what happened on this outing, their current objective, and what it already communicated. Existing vision and language models supply understanding. Engineering effort focuses on evidence integration, memory, relevance, timing, and delivery. Do not build a new image-captioning model as the default approach.

The intended capability comes from connecting on-device models and processing, camera/depth/wearable evidence, orientation, durable memory, community/GitHub knowledge and optional Astra/Dot/computer assistance. Each has a different role: observations describe the present, maps provide spatial context, memory supplies continuity and preferences, and the engine chooses useful information to communicate. Verify provider/device capabilities at integration; keep this whole-system purpose even while individual components are unfinished.

## User requirements established in this conversation

1. VoiceOver owns speech speed. The app does not read speed to infer expertise or change it.
2. The user chooses amount of information, frequency, interests, and whether updates are automatic. These are separate settings. Amount includes an adjustable words-per-time budget for ordinary narration, enforced before generation and delivery; faster VoiceOver alone does not control content production.
3. Important updates arrive without finding text, aiming for individual UI controls, or selecting a description mode every time.
4. Detailed descriptions remain available during movement. Motion changes relevance, timing, and freshness requirements; it does not silently override the user's detail preference.
5. Observe changes and announce what matters rather than rereading the whole scene on every frame.
6. An information engine checks evidence, people, position/orientation, maps, history, objectives, activity, preferences, and speech state before ordinary speech.
7. Danger alerts bypass ordinary information gates, word budgets and language generation. Existing detector freshness and validity still apply without a slow secondary review. Mobility/orientation cues are next and require current route/position evidence; rich awareness follows. Necessary mobility cues are not withheld because an ordinary narration budget is exhausted.
8. Room appearance, artwork, clothing, animals, social events, and opportunities to explore are first-class content.
9. Recognise consenting familiar people, keep identities separate from temporary tracking IDs, and distinguish current observations from last-known positions.
10. Remember entrance, route history, floor transitions, companions, meeting points, and return intent. A changed goal must not erase the way back.
11. Preferences support recommendations without hiding alternatives. A person may discover something they did not know to ask about.
12. Users and helpers can create private place scans. Add descriptions/photos to measured maps, preserve provenance, and support later visits.
13. Run the useful core locally without per-request API charges. Optional accounts/cloud/Dot can extend it. No promise of unlimited free remote inference or demonstrated 24-hour runtime.
14. Reuse maintained upstream code with tests and acceptable licenses before authoring replacements. Record what remains custom.
15. **Do not run Docker or heavy builds/tests until the user gives the later go-ahead.** Other sessions share this workspace. No mass edits, service restarts, dependency installation, model downloads, or account changes in this research phase.
16. The primary purpose of a room map is orientation: locate the person, maintain heading, and reach doors/destinations even when those landmarks are outside the camera view or occluded. Do not require a person to scan around blindly to rediscover a known doorway.
17. Support both local storage and optional GitHub backup/AI-assisted memory maintenance. They are complementary, not mutually exclusive.
18. Community members, venue owners and helpers can publish reusable maps. Other people can discover, review, download and use them offline without rescanning each place. Ratings, version-specific verification and reports of changes all belong in the product.
19. A family member or guide dog can provide context for richer descriptions during movement, but presence alone never proves clearance or disables danger alerts. Standing still is also not automatically a hazard-free state.
20. Very young children are intended early users. Complete bench/failure checks, controlled adult device trials and a guardian/specialist-reviewed supervised protocol before child-facing mobility trials; do not infer child listening needs from adult speech research.
21. Ordinary AI descriptions receive a coherent situation: user position/facing, room identity, containing home/store/mall/floor, connected rooms/exits, relevant people, current goal, preferences and delivered history. Camera and sensor observations are interpreted against that context; unknown fields remain unknown.
22. Discover personally meaningful details such as fish tanks, preferred clothing colors and décor, while preserving alternative choices. Explain useful relationships, activities and aggregate occupancy rather than enumerating every object.
23. With a verified supported connection, optional Dot actions may carry out a user-authorized restaurant reservation and hand its confirmed venue/time/party into the outing. Connect booking, arrival, seating assistance, menu reading, surroundings and departure without losing context. The reservation integration is planned, not available or tested here.

## Current implementation versus the intended system

| Area | Existing source evidence | Gap |
| --- | --- | --- |
| Speech | VoiceOver/fallback speech, bounded active announcement lifecycle, completion/failure/timeout handling and opt-in automatic narration | Device preemption, callback reliability and general multi-producer arbitration remain unverified. |
| Detail | Independent detail, interval and rolling word allowance; movement no longer forces a lower detail level | English/Arabic throughput, comprehension and actual delivery need device evaluation. |
| Local understanding | Vision known-ID selection plus optional `LocalImageAssistant` wrapping the documented Apple image API | Requires iOS 27 SDK opt-in and actual image/language/resource evaluation; source only. |
| Memories | GRDB room revisions/approvals, goal/dialogue, explicit interests and bounded speech-attempt journal with completion/uncertainty; private place/journey assets retained | Temporal fact/people/outing registries, learned preferences, verified delivered-fact association and native/device verification remain incomplete. |
| Place capture | RoomPlan, ARWorldMap, reviewed room revisions, labelled layouts and private reference photos | Reliable relocalisation, floor/body alignment and photo-to-landmark association remain incomplete. |
| Community maps | Versioned bounded package metadata, public release transport, offline preview/import/cache, explicit route revision and reviewed export | Asset/anchor exchange, proximity catalog, authenticated reviews, publishing, backup and cross-device navigation remain open. |
| Mapping/planning | RTAB-Map adapter, authored indoor graph and clearance checks | Saved map-to-live pose, scan-to-route generation and live obstacle fusion remain integration work. |
| People | Vision person counts | No verified enrolled identity, persistent track association, or approach/seat-change events. |
| Cloud | Photo relay plus native goal/dialogue/interests and historical selected-room inventory, per-request word allowance | Native location remains unknown without established alignment. No verified ChatGPT sign-in, Dot bridge, memory sync or processing service. |
| All-day use | Foreground camera sessions and local firmware loops | Background/lock behavior, thermal and battery measurements, resource scheduling and recovery must be evaluated. |

Source inspection is not device verification. Preserve the older results in [TEST_STATUS.md](research/TEST_STATUS.md); they do not validate this new design.

## Architecture decision

Use **local database + private asset folders + a speech decision engine**, with optional provider adapters. GRDB/SQLite is the preferred persistence candidate. Soundscape's history/state-machine source is the reference for callout lifecycle. Swift Async Algorithms is a candidate for ordinary event-stream composition, never for delaying urgent hazard delivery.

Keep the device's current pose, hazard state, and transient people tracks outside long-term LLM memory. A persisted episode can describe an old observation, but cannot become a live obstacle position after restart. Retrieval provides relevant context; the app's state and geometry decide which spatial facts are current.

Optional Graphiti, Mem0, Hindsight or Letta integrations are alternatives to evaluate, not four services to install. The iPhone remains usable when any optional provider is unavailable. The core personal memory does not depend on a GitHub account.

## Delivery milestones

Develop the information experience alongside mobility from M2 onward. The first complete assistant demonstration must include meaningful environmental understanding, user-controlled richness and a choice the user can make from the supplied information. A stream of obstacle warnings or isolated object labels does not satisfy M2. Lack of route readiness must not block supported descriptions, item comparisons or map-based previews; only claims that depend on current localisation require it.

| Milestone | Deliverable | Exit condition |
| --- | --- | --- |
| M0 Research and specification | Source evidence, component choices, explicit gaps, tasks and acceptance scenarios | Every proposed component has a source/decision; no unverified feature marked done. This session's deliverable. |
| M1 Local memory foundation | GRDB adapter, migrations, explicit preferences, people/place metadata, outing/objective journal, deletion/export | Restart, correction, temporal expiry, transaction failure, and profile isolation scenarios pass. |
| M2 First contextual assistant experience | Existing multimodal provider adapter, grounded rich observations, memory retrieval, discovery, versioned context, gates, VoiceOver, word/time budget and delivered history | Describe a room meaningfully, explain a relevant change, offer observed choices and handle follow-up/correction without resetting context. Automatic delivery, budget control and danger/due-mobility preemption pass. Scope includes V01/V02 and E09; it does not wait for M3 routing. |
| M3 Place orientation and community-map pilot | Downloadable place package, localisation anchors, connected doors/floors, remembered entrances and return intent | A user in a new room can orient toward an occluded mapped exit after localisation without first visually rediscovering the door; unknown position gets useful recovery. |
| M4 Extended social understanding and complete outings | Extend M2 awareness with persistent tracking, reviewed family enrollment, shopping/dining tasks and connected routes | English/Arabic home and mall scenarios pass including companions, descriptions, changed goals, floor changes and blocked return path. Rich awareness already exists from M2. |
| M5 Community publishing, backup and optional Dot | Verified supported auth, public venue catalog/reviews, private memory backup, scoped enhancement jobs | Download/rollback, contributor verification, revoke/offline behavior and restore pass; personal memory is never bundled into public maps by default. |
| M6 Device endurance and user evaluation | Sustained-use results and user-driven refinements | Measured latency, heat, memory, battery, comprehension, usefulness, and control; no assumed performance from chip specifications. |

## Success criteria

The restaurant scenario is a complete experience: select a venue using the person's stated interests; optionally carry out their authorized reservation; retain its actual confirmation; locate the restaurant within the mall; guide the supported route; explain the dining area's layout and observed occupancy; identify relevant companions/staff when supported; offer personally interesting features such as an aquarium; read and compare menu choices; report useful changes while seated; and retain the way back. An unoccupied-looking table is distinct from a table the host can assign. Useful nonspatial information remains available when live routing is uncertain. See DIN-01–DIN-07 in the acceptance plan.

Measure whether the person understands more and can choose and accomplish more: knows available shops/restaurants, finds a familiar person, enjoys a room description, compares an outfit, changes plans, and returns to the intended exit. Track missed useful opportunities, irrelevant/repeated speech, outdated statements, interruption burden, and correction effort alongside navigation behavior.

Assess information quality through supported relationships, activities, appearance, changes and relevant choices, rather than the number of object nouns spoken. Ask whether the user can explain the scene and make an informed choice. The assistant may recommend using remembered preferences, but must preserve alternatives and the person's control.

Relay and native source now preserve selected detail while moving when fresh content can be delivered. The native implementation still needs actual device verification. `research/ASSISTANT_POLICY.md` records the policy and earlier evidence.

## Collaboration and change ownership

This directory currently has no Git repository metadata. Do not pretend a clean `git status` or rollback commit exists. Re-read shared files before editing and preserve another session's work. Earlier source snapshots and archives are preserved; subsequent native implementation changes app, package, tests and generated Xcode files as recorded in PROGRESS. The initial research-only phase is no longer the current source state.

Before implementation, choose a compatible released version and pin the dependency. Research snapshots record inspected commits, not automatic upgrade instructions. Check source and model/data licenses separately, preserve notices, and use upstream tests plus app-specific acceptance scenarios.
