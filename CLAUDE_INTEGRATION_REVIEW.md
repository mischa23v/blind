# Claude integration review and acceptance boundary

Date: 2026-10-23. Source base: `30999a9ed0e921491ff62a1a93e073fe6af092ff`. Reviewed branch tip: `61001267dc0633c6b3cb941038b18dbb380cdc3d`. Shared ancestor: `d6d4236bf6d54ac0c0d9c6d18696bc743cac1e0e`.

## What was integrated

All seven branch commits were inspected, including 90 aggregate changed paths. Newer primary-branch assistant work was retained rather than replaced by the older branch. The branch added local Vision/ARKit reading and photo exploration, code-owned companion facts and search, Arabic/accessibility screens, optional Live Activity, firmware/tooling fixes and documentation. This is Seeing-AI-style functionality, not copied Seeing AI app source. Existing third-party attribution files were retained.

The assistant still has explicit mute/end, an independent camera toggle, opt-in supported background voice, the newer completion-accounted speech queue, evidence guards, executable read-only tools, memory correction/forgetting and audience preference. Unconditional never-off/background claims in old branch notes are superseded.

## Defects corrected during integration

1. Reader, currency, colour and scene work now switch through common cancellation. Per-session request tokens and owned task handles reject old results, including Stop followed by restarting the same reader. An old callback cannot clear a newer request's in-flight flag.
2. Page OCR is tracked until completion. Stable page polygons are not mistaken for device stillness: capture identity, full pose, portrait orientation, foreground, sensor state and freshness are checked separately. Accepted page text is a labelled frozen snapshot. Tokenized, completion-driven phrases fit the minimum word allowance; cancellation stops the owned active phrase and queued remainder.
3. Reader text is deduplicated only after admission. Overflow lines are not falsely marked read. QR/barcode output is bounded and never opens an encoded URL automatically. Product-name persistence does not claim success after a failed write.
4. Picture loading and exploration are cancelled/fenced on replacement, dismissal, background and session/request changes. Results are snapshots, not live-room evidence; photos remain in memory.
5. Search/target data uses capture time, not completion time, and cannot speak precise stale guidance. Grounding uses distinct frames. Removed the unjustified “within reach” assurance. Model hints pass the final spatial-claim guard; generic hazard fallback no longer promises sensor localization that may not exist.
6. Code-owned memory receipts and model replies preserve their distinct authority. The current model/tool/evidence architecture, original-record memory and completed-speech history remain intact.
7. Optional Live Activity is main-actor-isolated, serializes/coalesces request/update/end, exposes actual listening/camera state, ends when both stop and has a finite stale date. Its portable mock tests are not WidgetKit validation.
8. Known-invalid downward sensor returns invalidate floor evidence immediately, rather than retaining the previous good sample through a debounce window. Unproven bond-count pairing restrictions were removed. Watchdog documentation no longer guarantees an externally powered motor turns off on MCU reset.
9. Packaging uses NUL-delimited ignore checks, including Arabic/newline filenames, fails closed on Git errors and retains native source/prompt/notices. Public library pagination does not mistake filtered-empty pages for the end of results. Memory ordering retains row chronology despite wall-clock rollback.
10. Currency matching gained rejection-only evidence checks and honest development diagnostics. Explicit retries reserve a newer frame, expire after 30 seconds, permit at most two more attempts and cancel with task/attention changes. Only measured small/clipped/multiple evidence selects those prompts; unknown/stale/failure asks generically. Unavailable builds do not offer a capture loop. An expired pending prompt cannot block other work indefinitely.

## Portable verification

- BlindCore: **530/530** XCTest tests passed, Swift 6.4.1 on Linux.
- BlindMemory: **14/14** SQLite tests passed with matching headers/libraries.
- Node source/relay/integration tests: **216/216** passed on the final combined candidate, including reading, packaging, UI, clock, domain, currency and face contracts.
- MobilitySimulation: **17/17** synthetic cases passed, no model or physical sensors.
- Firmware C++17 protocol and C++11 failure tests passed; AddressSanitizer/UndefinedBehaviorSanitizer checked the failure suite, including 100,000 command frames. LeakSanitizer was explicitly disabled because the execution environment uses ptrace.
- All iOS Swift source parsed in default and combined optional configurations. Parsing does not typecheck Apple SDKs, expand Foundation Models macros, link native libraries or execute UI callbacks.
- Extracted adapter/evidence checks: 27/27. Mock ActivityKit lifecycle checks: 13/13. These are supplemental portable checks, not Apple device results.
- Currency source handoff independently passed Python **168/168** after the device-pack additions; shared metric tests previously passed **37/37**. Saved-evidence replay (699 decisions) is explicitly not fresh model inference; the diagnostic includes its distinct fresh runs and limitations.

No production currency profile, raw reference images, trained weights or deployment are included. The explicitly configured Debug-only currency device-test path is now included in source, with a manifest hash pin and a separate test authorization. Default and Release remain without production approval; the private reference pack is not in this repository. The dataset's paper-only coverage and same-collection dependence are documented in `tools/currency-reference/DATASET_DIAGNOSTIC_20261023.md`.

## Required Apple and physical-device acceptance

Build the preserved app/project with the correct SDK flags, then test the default and selected optional variants. Run actual VoiceOver traversal, focus after transitions, double-talk/interruptions, route/headset/phone-call changes, background/lock recovery and endurance. Confirm reply-only Home does not announce streamed tokens/status and that stop/mute remains reachable elsewhere. Check real RoomPlan map/progress and scan cancellation/save. Run English/Arabic page, sign, barcode, light and photo exploration cases, including latency, wrong OCR, glare, cropping, multiple pages, rotation and stale capture.

Specifically exercise reader→money, money→reader, Stop→same-reader restart, page OCR→new goal, page speech→Stop, delayed photo load→dismiss, target loss and hazards during every tool. Verify currency attempts use new images, expire without blocking, never turn unavailable into repeated capture requests and do not emit an amount after cancellation. Saudi-only scope is not authenticity or scene-sum recognition; mixed foreign scenes must be interpreted under the declared task rather than relabelled as wrong Saudi denominations.

The earlier normal-app current-location hallucination and approximately 8.385-second response failure remain open until exact-build retesting. Portable passes do not establish Seeing AI parity, actual recognition accuracy, independent child-use suitability, all-day availability or mobility readiness.

## Latest child-facing safety delta

The newer requirement removes the old allowance for hedged language-model distances/directions to ordinary objects. Request and output gates withhold covered physical-action/geometry language; they do not certify arbitrary model semantics. New object tracking/reach guidance and saved-image-similarity geometry are **withheld** until a specific-instance/depth association is validated. Nonspatial visual candidates and explicitly historical item memory remain useful. This is a limitation/rejection change, not evidence of better recognition accuracy. Real wrong-object/knife substitution, wrong bounding-box depth, moving hands, stale target identity, conflicting sensors and repeated apparently correct answers followed by a rare dangerous case require independent supervised validation before broader child trials. Do not assume a disclaimer is understood.

The source also adds a fresh read-only device-clock tool, real-clock/timezone evidence, reply-only Home, simplified helper controls, actual RoomPlan scan map/counts, child-support first-run wording and permitted foreground camera awareness by default. Stored explicit off choices and OS permissions/background restrictions remain respected.

## Final family and routing integration

The eleven-file family packet is integrated with a foreground frame consumer, fresh capture checks, scoped cancellable arrival speech, and the existing attention/hazard path. Arrival is relevant during an ongoing goal, not permission to interrupt active speech, quiet/muted social preferences or hazards. Photos-first enrollment preserves the single-person capture gate; automatic recognition uses a separate bounded per-face native batch. No anonymous body track becomes a named person. See [FAMILY_RECOGNITION_HANDOFF.md](FAMILY_RECOGNITION_HANDOFF.md) for native tests and limits.

Local where/find requests can use existing saved-item/gallery/Vision routes without allowing exact identity, movement or pickup authority. Named-place/current-temperature requests have an honest unavailable-source response, not camera inference. “Which outfit is white?” goes to dedicated color inspection. These are covered bounded patterns, not a claim that every paraphrase is understood.

The combined run required updating two old assertions to the new intended behavior: enrollment no longer requires a name before photos, and the stricter model-output guard now withholds quoted Arabic physical geometry. Code-owned historical receipts retain provenance separately. Final combined checks passed after these changes. The active project SHA-256 remained `d860fb26ea20185e4c29d46ecfc78690a65caa8e92fe5e18cf41df479564a533`.

Use [CHILD_ASSISTANT_TEST_TRACKER.md](CHILD_ASSISTANT_TEST_TRACKER.md) as the canonical scenario/status checklist. Real-model and iPhone execution, face numerical parity, physical note recognition and audible response speed remain unrun.

An independent final face review found a saved-camera-off enrollment dead end. The entry now explicitly offers to turn the camera on, preserves off merely on screen entry, clears waiting after denial/restriction and reports unsupported/text-only capture. The helper camera toggle follows the same explicit preference. A new source regression covers this; real permission/UI execution remains pending.
