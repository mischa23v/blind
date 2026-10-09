# Independent Fable review — 2026-10-09

Read-only review by a Fable agent at the user's request. Nothing was edited, run or downloaded by the reviewer. Items are tracked in TASKS.md as FR-01–FR-20 (and mapped to existing tasks where they belong). Status column is updated as work lands.

## Overall view (reviewer's words, condensed)

The direction is clearly written down; the policy engine exists as portable Swift (`CompanionAttention.swift`) with scenario tests mapped to OFF-01–08 and OUT-01; the Node relay is green (40/40); the hazard path stays independent of the engine. Research, implemented, tested and device-verified are kept apart.

Odds: the first home slice (own iPhone, own home: hazard cues, user-confirmed or relocalised rooms, offer-gated first-visit descriptions, silent familiar rooms, push-to-talk questions) is reachable within a few weeks of Mac time. The fuller vision rests on automatic room identity, which has no turnkey iPhone implementation: today `IndoorSituation.swift` names a room only during a manually aligned route on an imported package, and ARWorldMap relocalisation is one user-selected place at a time (O02/O09). Cross-device community maps, occluded-door routing, outing return and family identity are later layers. High odds for a useful companion in the brother's home this year; moderate odds for cross-venue autonomy as a later milestone. No Swift has compiled yet; the first Mac build is the next real information.

## Strengths noted

- Priority model is small and right: `SpeechPriority.canInterrupt`, `NarrationBudget` rolling window, hazards dispatched in `NavigationModel.publish` straight to `feedback.alert` without memory, model or budget.
- `CompanionAttention` shape: value type, one immutable moment per decision, explainable reasons, no FIFO of stale text, requested beats muted/quiet, `confirmRoom` never becomes a habit, memory excludes session timing.
- Relay: Ajv schema refuses unknown location carrying a pose; word budget via `Intl.Segmenter`; bounded concurrency.
- `readScene` revalidates goal/map/alignment/tracks/sensor/view before speaking.
- Records and handoffs make multi-session work survivable without Git.

## Findings and tracked items

| ID | Item | Maps to | Status |
| --- | --- | --- | --- |
| FR-01 | Compile: `CompanionAttentionTests.swift:31` calls mutating `decide` on a temporary. Use a `var`. | E02 | source fixed (awaits Mac compile) |
| FR-02 | Wire the engine into the live loop; retire timer narration at `NavigationModel.swift:317`. Producers: room entry, mobility cue, requested question, first-visit offer; dispatch through `Feedback` on the watchdog tick. | E02,E12 | source wired: room tick, offers, automatic descriptions gated by engine (awaits Mac) |
| FR-03 | Interim room identity: user confirmation ("I'm in the kitchen", yes to `confirmRoom`) and relocalised `SavedPlace` count as `established` for familiarity only; geometry stays separate. | M12,O09 | partial: manual-alignment room or recognised saved place counts as established for familiarity; confirmRoom answer recorded |
| FR-04 | Answer channel for offers: push-to-talk cannot hear "yes". Choose a short listen window after the offer finishes speaking, a gesture (double tap / Watch tap) or a VoiceOver action. Route replies through `AssistantControl.offerAnswer`. | E12,E08 | partial: spoken yes/no via push-to-talk + on-screen Yes/No; short listen window open |
| FR-05 | Change detection (V08) makes familiar-room silence valuable: start coarse — person-count change, sign/text change, obstacle in the usual path. | V08 | open |
| FR-06 | One word ledger: engine charges at decision time, `readScene` charges its own `narrationBudget`. Make the engine the owner; add `release(key:)` for undelivered items. | E10 | partial: release(key) added; single ledger open |
| FR-07 | Offer lifecycle: answer window measured from when the offer is spoken; withdraw without decline on mobility interruption, room change or out-of-band hazard. | E12 | done in source: window from spoken time; room change withdraws without decline |
| FR-08 | Visit counting: dwell time and last-visit date (M12 asks for last visit); a doorway flicker must not inflate visits. | M12 | flicker/blip done in source (2 s settle, visit continues); last-visit date open |
| FR-09 | Ask the user about Git; several sessions share the tree with no rollback. | process | asked |
| FR-10 | Archive historical layers of PROGRESS/TODO/TASKS; task counts differ between places (71 vs 74). | process | open |
| FR-11 | With an install go-ahead, the swift.org Windows toolchain could compile/test BlindCore here (Foundation-only; check corelibs differences such as `folding`). | Q02 | needs user decision |
| FR-12 | Room identity/localisation: one world map per home with room polygons in that frame; bounded start-up recovery across the home's maps; user confirmation as fallback. | O02,O09 | open |
| FR-13 | Body heading: use ARKit translation over the last ~2 m as body heading while walking; compare with camera yaw to notice mount slip; confirm at landmarks. | O03 | open |
| FR-14 | On-device model quality: Q09 through the relay first, then the same frames on device (local vs cloud); keep Vision fallback; length from the engine reservation. | V01,Q09 | open |
| FR-15 | Continuous capture cost: call the model on triggers (room entry, change, request, idle wait), not a timer; measure with existing signposts. | Q05,E02 | open |
| FR-16 | Speech arbitration: feed `CompanionMoment.speaking` from `Feedback`'s active priority; treat `unknown` outcomes as not delivered (bump revision); device-test VoiceOver callbacks (keyed by text, 120 s timeout) early. | E04,M06 | open |
| FR-17 | iOS foreground limits: ARKit stops on lock/background; chest-mounted phone must stay foreground (Guided Access, idle timer already disabled, battery plan). | Q05 | open |
| FR-18 | Engine logic: silence must not feed learned hints (M09: silence is not a preference); decisions return in priority order (document); requested answers wait behind ambient speech (caller interrupts first — document); prune `delivered` per session. | E12,M09 | done in source: silence not a habit; ordering/caller documented; delivered capped |
| FR-19 | Missing engine scenarios: `.describe` mode, `onRequest` category, `.offerFirst`, `.invalid` inputs, `.itemDirections`, mobility cutting an offer, room change with pending offer, flicker, non-monotonic clock, restored hint suppressing offers in a new engine, offer words charged to budget. | Q01 | done in source: 7 new scenario tests |
| FR-20 | Next three steps from the reviewer: (1) FR-01/07/19; (2) adapter FR-02/04; (3) on the Mac compile BlindCore, run package tests, then the eyes-open home walk with the owner before any brother session; ask about Git. | — | in progress |
