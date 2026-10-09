# Assistant integration acceptance plan

Prepared 2026-10-08. **This is the full acceptance specification; only the relay subset recorded in PROGRESS has executable results.** Serial Node and bounded synthetic API testing were subsequently authorized. Docker and device testing have not occurred for this expansion. Results live in [TEST_STATUS.md](TEST_STATUS.md); track implementation in [TASKS.md](../TASKS.md).

## Execution constraints and evidence

Latest user instruction reauthorized bounded local scenario testing before Mac handoff. The [minimum checkpoint](MINIMUM_ASSISTANT_HANDOFF.md) records 37 Node passes, 15 context-delivery passes, native tests awaiting execution, and the adult/child trial sequence. Sol scenarios remain specifications where no executable result is identified. Apple/device checks await the Mac; Docker/heavy work remain off.

Wait for the user's later resource go-ahead before running Docker, builds or resource-heavy checks. Do not download weights or install services to prepare this plan. Inspect and adapt the existing harness before adding domain fixtures; reuse selected upstream tests for their own components.

Each result must record app/source revisions, upstream pins, platform/OS/device, fixture or physical setup, command, log, actual outcome and skipped checks. Record latency from detector event to dispatch and to actual output separately. Choose and review device-specific acceptance limits before trials; no invented universal safe latency or accuracy threshold.

## Memory scenarios

| ID | Scenario and required result | Tasks |
| --- | --- | --- |
| MEM-01 | Save explicit interests and independent detail/frequency; restart preserves values without changing VoiceOver speed. | M01,M02 |
| MEM-02 | Fail a migration or database write; retain a recoverable prior state and report failure rather than silently losing the profile. | M01,M07 |
| MEM-03 | Correct a name/preference/fact; retrieve the correction with provenance and distinguish event time from recording time. | M03,M05 |
| MEM-04 | Restart during an outing; recover goals/entrance history but not stale live pose, tracks or clearance. | M03,M04 |
| MEM-05 | Change shopping to dining, suspend a task, then request the exit; preserve the return intent and validate a current route. | M04,O07 |
| MEM-06 | Interrupt/drop an announcement; do not classify its entire content as delivered. Explicit repeat remains possible. | M06,E04 |
| MEM-07 | Export with active SQLite WAL and concurrent asset writes; restore a consistent snapshot or reject it clearly. Exercise key loss/revocation without exposing tokens. | M08,C06 |
| MEM-08 | Delete one person/profile and isolate another; cover indexes, reference photos, derived assets and export scope. | M05,M08 |

## First contextual information experience — required in M2

These scenarios evaluate what the person can understand or decide, not just safe movement or object-detection counts. Use recorded/controlled scenes with supported reference observations before user trials. Runtime code and device evaluation remain pending.

| ID | Scenario and required result | Tasks |
| --- | --- | --- |
| INF-01 | With no navigation destination, request a room description. Provide supported layout/relationships, appearance and activity at selected richness; follow-up questions use the same context. A list such as book/table/person does not satisfy the outcome. | V02,E09 |
| INF-02 | Show clothing or dining choices, including an alternative outside remembered preferences. Explain observable differences and source limits so the user can choose; do not require a valid route to compare them or choose on the user's behalf. | V02,E09,V06 |
| INF-03 | Revisit a scene with a meaningful change and a prior correction. Preserve useful context, apply the correction and explain the supported change without repeating every old detail. | M03,E07,E09 |
| INF-04 | Localisation or family identification is unavailable while visual evidence is fresh. Continue valid nonspatial descriptions and anonymous activity information; omit unsupported identity/direction claims. Danger/due mobility can preempt, then revalidated information remains available. | V02,E07,E09 |

## Priority, attention and speech scenarios

Use fake clock/evidence revisions and a speech lifecycle adapter for deterministic integration checks. Actual VoiceOver scheduling, interruptions and audio behavior still need device trials.

| ID | Scenario and required result | Tasks |
| --- | --- | --- |
| SPE-01 | Valid danger event arrives during rich narration with memory/model/network stalled. Local alert dispatch preempts; no dependency on the eight ordinary gates. | E03,E04 |
| SPE-02 | Danger, due mobility cue and décor candidate coexist. Deliver in that priority order, revalidating the route after interruption. | E03,E04,E07 |
| SPE-03 | A stale/invalid sensor packet arrives. Existing detector handling remains effective; urgency is not permission to assert unsupported danger or clearance. | E03 |
| SPE-04 | Quiet, changes-only, ordinary rate limiting and a full queue are active. They must not suppress a new valid danger event; repeated same-event handling must not hide escalation or a new hazard. | E03,E04 |
| SPE-05 | Continuous observations accumulate while speech is slower. Coalesce by subject/version and expire outdated content; memory and queue use stay bounded. | E02,E04 |
| SPE-06 | Completion/cancellation is missing, late or duplicated. No deadlock, duplicate replay or false delivered-history update. | E04,M06 |
| SPE-07 | VoiceOver is active. Enabled automatic awareness speaks without touching text or moving focus; deliberate screen-reader controls still work. | E05 |
| SPE-08 | Switch only detail, then only frequency, then move. Settings stay independent through local and optional remote text generation. | E06 |
| SPE-09 | Turn/move/change goals while text is generated. Revalidate before speaking; discard unsupported relative directions while retaining valid nonspatial facts. | E07 |
| SPE-10 | Walk with a family member or guide dog and request rich narration. Provide it when timing permits; presence never disables hazard handling or proves clearance. | E06,E09 |
| SPE-11 | Enter a familiar unchanged room, then something relevant changes. Avoid repeated full summaries; offer the change and honor repeat/more-detail. | E02,E08 |
| SPE-12 | Discover a restaurant unrelated to the current shop objective. Offer it according to preferences without losing the original task or hiding alternatives. | E09,V06 |
| SPE-13 | User asks a question during repeated routine route chatter. Avoid starvation while preserving danger and genuinely due mobility priority. | E04,E09 |
| SPE-14 | Run Arabic/English at different user-chosen rates and information settings. Evaluate comprehension and useful content without changing the person's speed or inferring ability from it. | E05,E06,Q07 |
| SPE-15 | Pause/resume/converse/repeat with speech input unavailable. Accessible alternative controls work; ordinary narration follows preference and urgent warnings remain independently dispatched. | E08 |
| SPE-16 | Several producers generate concurrently near a rolling-window boundary. Reserved plus dispatched ordinary words stay within the selected budget; no double spending or fixed-window double burst. Verify actual text when a provider exceeds its requested limit. | E10 |
| SPE-17 | Lower/raise the budget while speech and generation are pending. Release obsolete reservations and revalidate content; no old-backlog flood, uncontrolled interruption or silent budget override. A high budget does not force filler. | E10 |
| SPE-18 | Interrupt an ordinary announcement, repeat it, cancel a pending candidate and restart. Budget and delivery-history ledgers stay distinct; admitted speech is conservatively counted, unsubmitted reservations released, session time reset correctly. | E10,M06 |
| SPE-19 | Exhaust the word budget at both fast and slow user-selected VoiceOver rates. Danger bypasses immediately and necessary mobility remains deliverable; ordinary narration stays bounded. Arabic/English segmentation and complete-sentence shortening preserve meaning. | E03,E10 |

## Orientation, social context and community maps

| ID | Scenario and required result | Tasks |
| --- | --- | --- |
| MAP-01 | Download a map recorded by another phone; establish floor, frame and heading before relative route claims. Unknown alignment gets an honest recovery flow. | O01,O02,C01 |
| MAP-02 | The mapped exit is outside view or occluded by a cupboard. Localise and explain its relation to the person without requiring visual rediscovery; route around measured obstructions. | O03,O04,O06 |
| MAP-03 | Rotate the phone without rotating the body. Do not equate camera heading with person-facing orientation. | O03 |
| MAP-04 | Cross floors, lose tracking, restart, or encounter similar corridors. No guessed continuation from old pose; maintain useful itinerary memory. | O02,O05,O07 |
| MAP-05 | Return path or entrance is blocked. Preserve exit intent and request/compute only a supported alternative; historical traversal is not current clearance. | O06,O07 |
| MAP-06 | Unknown floor/elevation/head clearance. Map popularity or a generated room mesh cannot convert unknown geometry into a traversable route. | O06,A03 |
| MAP-07 | Corrupt/oversized/unsupported package, interrupted download, invalid transform or missing asset. Reject or stage safely; never partially activate. Use proven archive/path validation. | O01,C01 |
| MAP-08 | An update arrives during navigation; revision-specific verification differs and later the version is withdrawn. Explicit active revision, safe transition, rollback and report behavior. | C01,C04,C05 |
| MAP-09 | Export a public venue package from a device holding family photos and personal episodes. Only selected public map assets are included; preview precedes publication. | C03,C05 |
| MAP-10 | Offline public-map use and revoked GitHub backup access. Local memory/orientation remains available; status is accurate and retry bounded. | C01,C06 |
| SOC-01 | Two people cross/occlude each other. Identity does not swap silently; unknown and last-seen states are preserved. | V03,V04 |
| SOC-02 | A person approaches, sits elsewhere or leaves view. Announce supported events without invented intent or assuming disappearance means departure. | V05 |
| SOC-03 | A map lists a restaurant but the live sign differs. Distinguish sources, allow correction and do not present a remembered listing as current observation. | M03,V06 |
| EXT-01 | Optional provider times out, authorization is revoked or a job returns incompatible/generated geometry. Local urgent operation continues; import is validated and measured geometry retained. | A01–A04 |

## Connected restaurant experience

Specifications only. Use synthetic provider responses and controlled recorded scenes first; do not make real bookings or expose participants to navigation trials to create these fixtures. The connected experience spans milestones: M2 supplies contextual information, M3/M4 supply demonstrated routing/social capabilities, and M5 adds the optional supported action bridge.

| ID | Scenario and required result | Tasks |
| --- | --- | --- |
| DIN-01 | User authorizes a specific reservation. A supported provider response supplies venue/branch/time/party and confirmation. Preserve these fields in the outing; account connection or a mere preference must not trigger a reservation. | A05,M04 |
| DIN-02 | Provider times out after possible submission, returns a failure, or changes availability. Reconcile status before retry; no duplicate booking, false confirmation or silent substitution of venue/time. | A05 |
| DIN-03 | Enter the restaurant within a mall. Context retains restaurant/floor/zone, current facing when established, entrance/return intent and companion. Describe supported surroundings without requiring every landmark to be visible. | E01,O05,O07,V06 |
| DIN-04 | User likes aquariums and a particular clothing color. Offer supported matching observations when relevant, preserve other choices, and distinguish a map-listed aquarium from a current sighting. | M02,E02,V06 |
| DIN-05 | Only part of the dining room is visible; some tables appear unoccupied. Summarise that observed area, separate occupancy from seating availability, and describe supported décor rather than enumerate all chairs. | V02,V06 |
| DIN-06 | Read a menu, handle a comparison/follow-up, then a tracked person approaches. Preserve menu context; describe the approach/role only as supported, prioritise relevant changes and resume useful content within the word budget. | E01,E04,V05,V06 |
| DIN-07 | User changes plans, leaves, or asks about a reservation's status. Preserve companion/exit context, verify current route conditions and distinguish a status query from an authorized cancellation. | A05,M04,O07 |

## Conversational destination and orientation

| ID | Scenario and required result | Tasks |
| --- | --- | --- |
| CON-01 | User requests the bathroom inside their bedroom, then enters the bedroom. Keep the bathroom goal, briefly acknowledge entry, and use the next validated route cue; do not start a décor tour. | M04,E01,O08 |
| CON-02 | Phone rotates while body heading is unknown. Preserve intent but do not invent left/right, measured distance or steps from a graph or image. | O03,O08 |
| CON-03 | User changes from bathroom to computer or bed while a response is pending. Supersede the old goal and invalidate its queued directions; offer information relevant to the new destination. | M04,E07,O08 |
| CON-04 | “Take me there” follows two destinations. Ask one short clarification rather than choosing silently; keep the resolved destination across later room transitions. | E08,O08 |
| CON-05 | Change units or enable personal step estimates. Use the navigation adapter's measured route distance, calibrated stride and uncertainty; no generic stride guessing or long open-loop step command. | O06,O08 |
| CON-06 | Familiar bedroom, open-plan space or two similar doors; map/image/sensor alignment is uncertain. Preserve useful context, describe the uncertainty and recover localisation without treating a room label or old assistant utterance as proof. | E01,O02,O08 |

Text-only supplied-snapshot coverage exists for CON-01/02/04 and the revised-goal part of CON-03. It does not test a persistent dialogue loop, native routing, dispatch invalidation, physical orientation or step calibration. See integration status for exact results.

## Sol-report additions — prepared scenarios, not results

Read [the reviewed report and primary evidence](SOL_IDEAS_REVIEW.md). These scenarios must use controlled/recorded material and selected upstream/framework APIs; they do not authorize a new recognition, tracking or localization algorithm.

| ID | Scenario and required result | Tasks |
| --- | --- | --- |
| SOL-01 | A menu price or appliance label is cropped/blurred. Preserve readable text, state the specific missing portion, and do not complete digits, ingredients or instructions from context. Repeat does not convert a guess into evidence. | V07 |
| SOL-02 | The user asks about an object outside the view or an unreadable control panel. Ask for one supported stationary camera view when useful; if no direction is established, do not invent “left/right/closer”. Preserve the objective and offer clarification or user-controlled help without claiming an integration or making a call. | V07,E08 |
| SOL-03 | User explicitly remembers headphones on a desk; restart elsewhere, then ask where they are. Supply last-seen time/source/place with current status unknown. A partial new view does not prove absent; fresh confirmation is a distinct record. Correct/delete the record and verify no resurrection. | M11 |
| SOL-04 | A familiar room is viewed from another angle/lighting with half the furniture occluded. Do not claim moved furniture or “room unchanged” without comparable coverage. Label unobserved regions and uncertainty; keep usable observed details available. | V08 |
| SOL-05 | A chair has actually moved beside a verified doorway. Announce its supported current relationship when relevant to the goal; no automatic approved-room overwrite or invented safe alternate route. A pending answer from the old revision is discarded. | V08,M10,E07 |
| SOL-06 | One person wants automatic décor/interest detail; another requests those categories only on demand. Both can change words/minute independently of VoiceOver speed. Asking directly about a muted category still gets an answer. Danger/due mobility priorities remain intact. | E11,E10 |
| SOL-07 | In a harmless living-room/art/shop scene, compare user-selected delivery modes. Record wanted information delivered/missed, useful choices made, unnecessary repetition, follow-up burden, spatial recall and preference. More/fewer words are not success criteria by themselves. | Q07 |
| SOL-08 | During a supported conversation or while listening for a familiar environmental cue, ordinary narration should yield to user control and resume only relevant fresh context. Offer uncertainty/help without taking over. Evaluate speech audibility and autonomy separately from hazard detection. | E04,E08,Q07 |

## Goal-led companion behaviour — user direction 2026-10-09

The user's model: a sighted person ignores most of a familiar room and goes straight to the computer, TV, bed, bathroom or closet because they already know where things are and what is in the way. The assistant should behave the same way. Familiar maps and memory are silent background knowledge used to reach goals. Room description is for new places, waiting time, or on request. Hazards never wait for an offer or a goal. These are prepared scenarios, not results.

| ID | Scenario and required result | Tasks |
| --- | --- | --- |
| OFF-01 | First entry to an unvisited room. Offer once, briefly ("New room, a kitchen. Want a description?"). Yes gives a book-style description; silence or no counts as declined. No repeated offer for that room in the session. | E12,M12 |
| OFF-02 | Entry to a familiar room (bedroom) with no relevant change. Say nothing ordinary. A relevant change (chair moved into the usual path) is said briefly. | E12,M12,V08 |
| OFF-03 | Room identity uncertain after restart. Ask one specific question ("Is this your bedroom?"). The answer is recorded as user-stated; directions still wait for established alignment. | E12,O09 |
| OFF-04 | User declines bedroom descriptions repeatedly. The assistant stops offering and records a reviewable, removable hint. An explicit request still gets a full description. | E12,M09 |
| OFF-05 | Goal set to "find a seat" in a café while a description is due. Seat information (free seat, direction, what is in the way) is delivered first; the description waits or is dropped. | E12,E02,O08 |
| OFF-06 | Obstacle in the path during an offer or description. The obstacle cue interrupts at once; the pending offer is not re-asked automatically unless still relevant. | E03,E04,E12 |
| OFF-07 | Morning in the bedroom with a learned routine. A short, removable suggestion ("Want help picking an outfit?") is offered at most once; declining is respected. | E12,M12,V06 |
| OFF-08 | User asks for a remembered item (braille book, pot, device). Give last-seen place/time and, when alignment is established, route with obstacles; otherwise say it is last-seen information. | M11,O04,O08 |

### OUT-01 — family café outing, end to end

One continuous goal chain. Each step: what the assistant does, what it keeps quiet about, and what changes the goal. Pass requires every step plus pause/resume and questions at any point.

| Step | Situation | Required behaviour |
| --- | --- | --- |
| 1 | Family is going out; user is in the bedroom | Goal "change outfit to go out". Route to the closet; no bedroom tour. |
| 2 | At the closet | Help choose the outfit on request: describe options, colours, matching; the user decides. |
| 3 | Leaving the bedroom | Goal "leave the house". Route to the bedroom door, then the house door, with obstacles in the way. |
| 4 | Outside the house | Steps/stairs announced as mobility; then where the car is. |
| 5 | Arriving at the café | Route to the café door, with obstacles. |
| 6 | Seated, waiting for coffee | New place: offer or give the first-visit description (user is waiting, so this is the right moment). |
| 7 | Talking with family | User pauses narration at any time; hazards remain active; resume brings only fresh relevant context. |
| 8 | "Where is the bathroom?" | Route with obstacles; sink/hand-washing area; how to exit the bathroom. |
| 9 | Back to the table | Goal "return to my family's table": route back using the remembered table location, with current obstacles. |
| 10 | Leaving the café | Route to the exit, avoid obstacles, small steps outside, then to the car. |
| 11 | Arriving home | Find the house door; say how the house was identified (map match, user confirmation) without guessing; steps to the door. |
| 12 | Inside the house | Route through familiar rooms to the bedroom silently, except obstacles or relevant changes. |
| 13 | Changing into home clothes | Find the closet; help pick pyjamas and colour on request. |

Bench and Windows stages can exercise the decision logic and model answers for each step with recorded data. Steps involving walking, stairs and the car require the staged device and supervised trials (Q04–Q06); stairs in early trials are simulated.

## Resource and physical-device stages

1. Review fixtures, pin compatible released dependencies and preserve a rollback baseline before app edits.
2. After resource permission, run relevant portable checks serially, then selected upstream checks. Do not introduce several databases/services at once.
3. On a Mac, compile the real Apple targets and run integration checks. Verify UIKit/VoiceOver callbacks, user focus, fallback speech, audio conflicts, permissions and Arabic/English on the target iPhone.
4. Bench-test sensor loss, stale frames, disconnected wearables, localisation failures and competing output. Measure sustained battery/thermal/memory behavior, camera suspension, lock/unlock and optional-cloud outages.
5. Conduct controlled adult mobility trials with documented intervention/stopping rules. Do not expose a participant to an untested physical drop or assume the app replaces their established mobility support.
6. Before very young children participate, obtain guardian involvement and a qualified orientation-and-mobility review of a supervised, age-appropriate controlled protocol with immediate adult intervention and opt-out. Record actual readiness evidence; adults' high-speed speech results cannot be extrapolated to children.
7. Measure task completion, orientation recovery, useful discoveries, descriptions, comprehension, repetition burden, missed/late alerts and user choice. Release/independent-use claims require separate evidence review.

## Prepared commands — not executed

The existing `package.json` defines the Node tests below. Review test side effects and current scripts again when permission arrives. These commands exercise existing suites; they do not magically implement the scenarios above.

```text
node --test --test-concurrency=1 server/test/*.test.mjs tools/test/*.test.mjs
swift test --package-path BlindCore --scratch-path artifacts/swift-macos --jobs 1
```

The Swift command belongs on the confirmed Mac toolchain. Inspect `MAC_HANDOFF.md`, `tools/mac-setup.mjs` and generated-project settings before choosing the actual iOS build command/device target. Do not run `tools/verify.mjs` merely to inspect readiness: it executes tests and generates the Xcode project, and its Docker path builds containers. `tools/mac-setup.mjs --print` is the documented inspection path; running setup without that option is work, not inspection.

Store new outcomes alongside the exact implemented scenario IDs in PROGRESS and TEST_STATUS. A source-only review, prepared command, historical result or mocked speech callback must never be reported as a successful new device test.
