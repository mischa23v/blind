## Body profile and terrain reconstruction update — 2026-10-25 08:01 UTC

Optional local age, gender, weight and height fields, reported/measured geometry provenance, chest-phone offsets, helper settings and bounded asynchronous persistence are applied and frozen. **1,181 Core and 395 Node checks passed**, zero failures/skips. Body/profile changes invalidate old evidence; old reports cannot silently replace newer measured bounds. Terrain no longer treats the prior9cm rise/drop or adjacent16cm difference as level geometry. Estimates and stored geometry do not grant physical clearance; missing uncertainty is not measured zero. Apple SDK/VoiceOver/device validation remains open, and the native CI run was skipped by its private-repository cost guard. Previous head is `8dbc7dfd26f47b6df9493990485a620f65945be6`. See [checkpoint-15 evidence](research/rebuild-evidence/checkpoint-15/verification.json).

## Native evidence bridge reconstruction update — 2026-10-25 07:19 UTC

The candidate-only native evidence bridge is applied and frozen for this checkpoint. **1,156 Core and 395 Node checks passed**, zero failures/skips, alongside 47 focused tests bound to actual native source. It selects the connected journey owner explicitly, preserves intent/replay history, rejects stale callbacks and withdraws only matching current evidence. The extraction dependency failure and exact-source fix are preserved. This does **not** enable physical guidance: calibrated body/pose/support/error providers, imported-map registration and Apple/device validation remain unavailable. Previous published checkpoint is `c28f0c77d66f9985451758fda9760869262b524f`. See [checkpoint-14 evidence](research/rebuild-evidence/checkpoint-14/verification.json).

## Automatic perception reconstruction update — 2026-10-25 06:45 UTC

Idle OCR and saved-label barcode discovery now have a reviewed path without selecting a scanner mode. Active/paused connected journeys and retained tasks keep attention; unsupported tasks are not treated as idle. **1,156 Core and 395 Node checks passed**, zero failures/skips. Exact four-path integration and source/scalar face replay evidence are retained. No image/model/runtime files are published. CPU face smoke is not accuracy acceptance: an independently captured photo missed one visible face and produced a below-threshold comparison, so no match was forced. Native/device validation, generic detector assets, neutral-fabric reliability and wider specialist availability remain open. See [checkpoint-13 evidence](research/rebuild-evidence/checkpoint-13/verification.json).

## Scoped memory reconstruction update — 2026-10-25 06:24 UTC

The typed scope/retrieval increment and reachable legacy deletion repair are applied and frozen for this checkpoint. **1,153 Core and 395 Node checks passed**, zero failures/skips. Reports/items retain source ownership and original time; wrong-scope retrieval cannot silently reuse another room/container. An independent native witness found deleted completion could return from a suspended goal; the minimal repair now clears those derived completions, with original failures preserved. A positive native room/container issuer, complete scoped review UI, atomic asynchronous durable deletion and Apple/device validation remain open. This is not automatic real-world fridge recognition or complete privacy durability. Previous published checkpoint is `775feaca221e21f51411fc48b9aa6674535797c0`. See [checkpoint-12 evidence](research/rebuild-evidence/checkpoint-12/verification.json).

## Connected journey reconstruction update — 2026-10-25 05:42 UTC

Connected journey intent/history, single-owner lifecycle, return choice, quiet/resume and privacy erase/retry are applied and frozen for this checkpoint. **1,142 Core and 395 Node checks passed**, zero failures/skips. Independent complete-code episodes found automatic recovery could stall after rejected pose evidence even when earlier aggregate tests passed; that production bug was fixed and the original failed traces are preserved. Fresh accepted endpoint evidence now replans automatically; an unknown mid-leg pose is still withheld. Connected blocked-way/manual-arrival controls, native portal import, calibrated sensor issuance and Apple/device validation remain open. Previous published source is `33cd18486e177e41d5c230b524f0e1e1651ceb81`. See [checkpoint-11 evidence](research/rebuild-evidence/checkpoint-11/verification.json). This is not completion of the400 end-to-end scenarios or hands-free physical guidance.

## Async map reconstruction update — 2026-10-25 05:19 UTC

The reviewed async map increment is applied and frozen for this checkpoint: **1,111 Core and 394 Node checks passed**, zero failures/skips. Focused actual-source checks cover bounded off-main storage, stale callback/revision rejection, deletion/rollback ordering, pending/failed map ownership and route-specific output retirement. Photo, observation, memory and clock source was preserved. Apple SDK/device behavior, real timing and a calibrated localization issuer remain unverified. Previous published source is `33f43635ed2411d3e85906e2ed808b447442500a`. See [checkpoint-10 evidence](research/rebuild-evidence/checkpoint-10/verification.json). This supersedes earlier async-map staged status below, not the remaining journey/place-memory/physical-release gaps.

## Observation-history reconstruction update — 2026-10-25 03:50 UTC

The bounded native observation-history increment is now applied and frozen for this checkpoint: **1,111 Core, 393 Node and 35 actual GRDB tests passed**, zero failures/skips. The prior Node run failed one stale lifecycle-prefix assertion; its original output and stronger cancellation/authority correction are retained. Raw observations use a separate incremental store and a provisional 128 KiB/60 s durable-payload budget with empty-start credit. Short sessions may remain volatile; oversized records are not silently truncated. This is not world mapping, localization or movement authority. Sensor accuracy, added ARKit workload, physical flash/battery costs and Apple runtime remain unverified. Previous published source is `41dd5d93ac1c7bc41e7b3bb8a0c7396b3b3cf640`. See [checkpoint-09 evidence](research/rebuild-evidence/checkpoint-09/verification.json). This supersedes earlier observation candidate status below; async map IO and connected journeys are still separate open work.

## Photo reconstruction verification update — 2026-10-25 03:38 UTC

The earlier photo aggregate failure recorded below has now been corrected and rerun: **1,057 Core and 391 Node checks passed**, zero failures/skips. Only two stale test-shape assertions changed during correction; stronger source ownership, cancellation ordering and negative mutation checks replaced them. The original failed run is retained. The 15-file selected-photo source integration plus two corrected contracts is frozen for this executable checkpoint. Photos/Vision/audio/Apple SDK and real device behavior remain unverified. The previous published tracker/source-archive checkpoint is `1937e92e72abd72212c60427e4a5362e13dc678a`. See [checkpoint-08 evidence](research/rebuild-evidence/checkpoint-08/verification.json). This update supersedes earlier photo aggregate status below, not other open feature gaps.

## CURRENT EXECUTION QUEUE — 2026-10-25

Latest verified published source: `978b506283b5ce9d1ea05ea120db8806f47754fe` (tree `750cd35b01a4e662a99797589afbbca53092a308`). This current feature snapshot supersedes earlier checkpoint snapshots retained below, including old sections headed “current.” See [REBUILD_FEATURE_STATUS.md](REBUILD_FEATURE_STATUS.md) for publication state, actual behavior, remaining gaps and dependency order. Original requirements and failures remain in [REBUILD_TRACKER.md](REBUILD_TRACKER.md) and [REBUILD_SCOPE_ADDENDUM.md](REBUILD_SCOPE_ADDENDUM.md).

- [x] Publish bounded ordinary guards/reference Core at 978b506 with full Core 1023 / Node 379 evidence. Native manual/PDF/speech adapters remain missing.
- [ ] Finish the applied selected-photo candidate: focused verification and Core 1057 passed; Node aggregate FAILED (391 total, 389 passed, 2 failed); test-only correction/full rerun, final review and publication remain pending. Record exact source hashes and preserve failures.
- [ ] Finalize the staged raw-observation budget archive after its 81 cleared scoped source tests; application/full combined verification remain pending. Preserve the 128 KiB/60 s durability budget with 128 KiB burst, separate from volatile ingestion, privacy deletion, retained-row/reopen behavior, quota/drop semantics and failures.
- [ ] Rebase the staged async map IO over finalized observation/privacy hooks, then apply its reviewed diff and rerun controlled blocked-writer/main-control, CAS/stale-publication, rollback/delete and full aggregate checks. Published synchronous IO is not yet fixed.
- [ ] Complete actual Apple Photos/Vision/audio lifecycle checks for the applied trusted-picker flow when available; portable decoding/receipt tests cannot prove native accuracy.
- [ ] Rebase the staged native quiet/output patch before wiring additive journey Core. Preserve newer photo/clock/memory changes; do not equate an unwired Core candidate with an automatic trip.
- [ ] Implement a measured native position/body-heading/support issuer. Keep registered physical guidance unavailable without valid calibrated evidence.
- [ ] Connect automatic map building and uncertainty-aware relocalization, then complete body/collision, restart, world/building/floor/room journeys and obstacle-aware return. Raw observations and current authored-leg routing do not close this.
- [ ] Implement the native exact-model manual/PDF source adapter and connect source-owned reading delivery. Test intact blocks, at-most-35-word chunks, original 60-second deadline, exact withdrawal and no resumed expired answer.
- [ ] Close same-goal/different-fridge target-place binding and complete original memory/task/ordinary-language episodes with the actual smaller model.
- [ ] Verify real speaker/addressee identity or continue rejecting untrusted route/task commands. Do not mistake recognition, audio energy or transcription for authority.
- [ ] Execute 400 distinct whole episodes with the actual map/pose/route/collision/output stack, real/synthetic labels and original failure evidence. Restored public datasets and paraphrases do not count as completed episodes.
- [ ] Run Apple SDK/device/audio/VoiceOver, calibration/recognition accuracy, background lifecycle, storage protection and latency/endurance checks; then produce the complete exact-commit review handoff.

After each coherent increment: focused test, final affected aggregate, clear limitations, verified push and restart-note update. Do not bundle every remaining feature into another uncheckpointed package.

### Earlier to-do/checkpoint snapshots — retained history

### Conversation and reference-reading increment — 2026-10-25

Previous source checkpoint `cd368af9` is verified on master. Narrow ordinary-conversation repairs now permit the documented abstract/science/language cases without permitting mixed physical instructions. Reference Core retains complete source blocks outside model budgets, preserves qualifiers and source identity, and advances only on exact completed speech receipts before the original deadline. Fresh merged checks: **1,023/1,023 Core** and **379/379 Node**, zero failures/skips. The official-manual extracted-text replay passes5/5 with synthetic playback; raw manual text is not published. Native manual/PDF and speech adapters remain missing, so this is not a completed native manual-reading feature. Evidence: [checkpoint-07](research/rebuild-evidence/checkpoint-07/verification.json).

### Operation-owned clock increment — 2026-10-25

Previous source checkpoint `1ae0b80` is verified on master. Legacy and model-selected time reads now use the original acquisition and code-rendered output through partial/final display, speech and repeat; model prose cannot replace a selected clock result or renew an expired read. Failed first reads remain unavailable, and final text stays behind the existing proposal gate. Fresh full checks: **988/988 Core**, **377/377 Node**, with zero failures/skips; extracted callback scenarios are included in the verification, not added again to totals. No-tool wording detection remains bounded; actual Apple runtime and compound-response behavior still require validation. Evidence: [checkpoint-06](research/rebuild-evidence/checkpoint-06/verification.json).

### Registered spatial integration increment — 2026-10-25

Previous source checkpoint `7682086` is verified on master. Registered-map storage, current-leg collision checks, typed route tickets and exact speech/beacon retirement are now connected to native controller paths. Fresh checks: **973/973 Core**, **367/367 Node**, and **58 isolated spatial runtime tests**. An aggregate run caught accidental reversion of three memory tests; those were restored exactly, and the original failure plus corrective diff are retained. This is not restored live navigation: no calibrated native pose/heading/support issuer exists, map IO remains synchronous, and Apple SDK/device checks remain open. A bounded async/CAS persistence increment is required so slow IO cannot delay warnings. Evidence: [checkpoint-05](research/rebuild-evidence/checkpoint-05/verification.json).

### Task and memory repair increment — 2026-10-25

Previous source checkpoint `0c38d674` is verified on master. Repeated goals now retain progress, dated corrections resist older replay, original request wording remains separate from canonical labels, and generic completion cannot finish an unrelated target. Historical records without timestamps remain unknown-age. Fresh verification: **940/940 Core**, **364/364 Node**, plus **25 extracted actual native-state tests**; zero failures/skips in the final aggregate. Original failures are preserved. Same-goal movement between different physical fridges remains a known context-binding gap; Apple/model/device validation is not established. Evidence: [checkpoint-04](research/rebuild-evidence/checkpoint-04/verification.json).

### Native debug integration increment — 2026-10-25

Previous source checkpoint `6945dc7` and unfinished source snapshots `0aaa637` are verified on master. DEBUG-only local diagnostics are now connected to native input, model, tool, evidence/gate and speech paths, with privacy purge hooks and no diagnostic UI or uploads. Fresh verification: **927/927 Core**, **362/362 Node**, and **18/18 executable assertions** on the exact extracted Foundation helper. Two brittle source assertions were narrowed after preserving their failures; behavior and cancellation checks remain. Native syntax parsing is not Apple SDK/runtime validation. Spatial integration, full clock-tool coverage and broader reconstruction remain open. Evidence: [checkpoint-03](research/rebuild-evidence/checkpoint-03/verification.json).

### Direct-clock increment — 2026-10-25

Previous source checkpoint `9af6e77` is verified on master. The direct read-only clock lane is now integrated before task mutation, with original monotonic five-second freshness and exact reply/session/time-zone binding. Fresh full verification: **927/927 Core** and **342/342 Node**, zero failures or skips. Default and DEBUG/familiar native syntax parse passed; Apple SDK/device behavior is unverified. Legacy/model-selected clock delivery remains open. Evidence: [checkpoint-02](research/rebuild-evidence/checkpoint-02/verification.json). This incremental source awaits the commit containing this entry; it does not close the whole reconstruction.

## CURRENT RECONSTRUCTION — 2026-10-25

This is the current ordered queue. Earlier entries below are preserved historical records, not evidence that today's build passes. Full scope and acceptance IDs: [REBUILD_TRACKER.md](REBUILD_TRACKER.md) and [REBUILD_SCOPE_ADDENDUM.md](REBUILD_SCOPE_ADDENDUM.md). Results: [PROGRESS.md](PROGRESS.md).

### Preserve and verify the current increment

- [x] Restore the 717-file baseline exactly and preserve the first reconstruction documentation checkpoint on GitHub (`20af33fe`). This does not restore the missing later source.
- [x] Install signature-verified official Swift 6.4.1 and execute the full Core suite: 910/910 passed, including all 45 new cases; 0 failed. This is portable Core verification, not Apple/device acceptance.
- [x] Complete the Swift-enabled aggregate Node run: 338/338 passed, 0 failed, 0 skipped, exit 0; extracted native-method checks executed. Source-review fixes are included and frozen code inputs have not drifted.
- [x] Syntax-parse all iOS Swift in default and DEBUG + BLIND_FAMILIAR_PEOPLE configurations; both exited 0. This does not establish Apple SDK typechecking/linking.
- [ ] Publish the verified current code and updated task/progress/scope documents in small checkpoints. Read back the exact remote commit before reporting push success; report skipped or blocked tests explicitly.

### Safety and spatial integration next

- [ ] Prove every task/route mutation rejects untrusted speech before state changes; keep real hands-free speaker identification explicitly unavailable until implemented and validated.
- [ ] Separate perception evidence authority from task/route revision. Quiet/cancel/new goals preserve fresh hazards while obsolete queued/started route cues are withdrawn by exact cue ID.
- [ ] Integrate the Swift-tested standalone spatial registry and localization lease with actual maps/sessions, world/building/floor/room transitions and uncertainty. GPS/appearance alone cannot grant pose authority.
- [ ] Connect native mapping observations/localization/occupancy; retain unknown areas, reject old map/floor/session data and preserve atomic state on rejected updates, write failures and restarts.
- [ ] Integrate live/static geometry with conservative swept-body collision, sensor-to-body calibration, changing dimensions, blocked returns and map/camera restart continuity.
- [ ] Complete actual-stack outbound/return and conversational return journeys, including English/Arabic clarification, read-only previews and actual narration completion records.

### Conversation, debug and everyday workflows

- [ ] Wire DEBUG recording into native model/tool/evidence/narration events without UI or uploads; verify 8 MiB/session, 32 MiB retention, fail-stop/no silent eviction and privacy purge plus disable.
- [ ] Reproduce and repair memory provenance, cup/keys/pronouns, correction chronology, original timestamps, repeated-request progress and completion-before-reply ordering.
- [ ] Preserve code-owned clock's original monotonic five-second freshness and wall/time-zone checks without task cancellation; preserve reference source blocks in at-most-35-word chunks with the original 60-second deadline and no invalid resume/renewal.
- [ ] Re-run real photo/label/manual sequences and harmless arithmetic/story/rainbow/joke answers without weakening physical safeguards.
- [ ] Reconcile existing visual/depth separation, identity/profile/roleplay, current-reply-only VoiceOver and denomination integrity before duplicating preserved hardening.
- [ ] Reproduce recorded stair-up/drop, belt-height and slope cases. Keep unknown blind spots, child/adult hazard rules and surface/object risks explicit; no unvalidated universal safe-height cutoff.

### Finish with evidence, not counts

- [ ] Expand distinct whole-episode everyday scenarios using the actual map/pose/route/collision/output stack. All future 400-scenario coverage remains incomplete; turns/rephrasings do not inflate scenario count.
- [ ] Re-run the longer experimental mapper and keep its recorded accuracy failure open until measured evidence meets a declared threshold.
- [ ] Inventory and implement missing native adapters before calling them only device-testing work; then run Apple build, on-device small-model, microphone, VoiceOver, timing and supervised sensor validation.
- [ ] Produce a clean-copy package and independent-review handoff with exact commits, commands, fixtures, provenance, failures and remaining gaps. Cloud/source-contract checks cannot certify safe independent use.

Evidence: [verification summary](research/rebuild-evidence/checkpoint-01/verification.json), [Core log](research/rebuild-evidence/checkpoint-01/core-tests.log), [Node log](research/rebuild-evidence/checkpoint-01/node-tests.log), [tested source hashes](research/rebuild-evidence/checkpoint-01/source-hashes.json).

### Historical to-do records

## Context-driven capability integration — 2026-10-23

## Pre-device hardening update

See [PRE_DEVICE_HARDENING.md](PRE_DEVICE_HARDENING.md) for the latest source fixes, evidence distinctions and unfinished capability/device/resource backlog. This supersedes older central-colour, depth-only camera startup and passive-first scheduling descriptions. Final portable regression passed: 770/770 BlindCore, 16/16 BlindMemory, 306/306 Node with zero skips, and 16/16 extracted working-state tests. Both default and DEBUG/familiar native sources syntax-parse. Disposable aggregate verification passed and regenerated the identical Xcode project. This source follows primary 63861923f4ff67556e274d284e761ee56f76d901; use the repository revision containing this update, not a synthetic local Git HEAD. No native Apple SDK or device acceptance is claimed.


Historical contextual-capability checkpoint below follows primary `2377a0fee9a799394e5696f59d1bda081ae72d5c`; the pre-device section above supersedes it. Read [CONTINUOUS_COMPANION_DESIGN.md](CONTINUOUS_COMPANION_DESIGN.md) for the consolidated product requirements and [CONTEXTUAL_CAPABILITIES_ACCEPTANCE.md](CONTEXTUAL_CAPABILITIES_ACCEPTANCE.md) for current wiring and exact limitations. Eligible foreground capabilities no longer all require feature-mode selection: bounded passive Saudi reference verification, task-relevant OCR/saved-barcode/light/central-item colour, first-session eligible consented familiar gallery, and voice-confirmed room scanning are connected. Explicit off/end, model/profile availability, fresh evidence, attention and physical-safety gates remain. This is not full autonomous feature coverage or Apple/device acceptance.

Portable validation: **704/704 BlindCore**, **16/16 BlindMemory**, **288/288 Node** (zero skips), **16/16 extracted working-state tests**, and **33 extracted familiar lifecycle checks** passed. Default and DEBUG/familiar iOS sources syntax-parse; firmware protocol and ASan/UBSan failure injection passed (LeakSanitizer excluded under executor tracing). These are not Apple SDK/device/model/VoiceOver/latency or endurance acceptance. Aggregate verification passed in a disposable source copy; the generated Xcode project was byte-identical. Historical counts below belong to their named checkpoints.

## Everyday companion integration — 2026-10-23

Portable validation for this increment: **647 BlindCore**, **16 BlindMemory**, **273 Node** tests passed; **16 extracted working-state tests** passed. Default and DEBUG/familiar-person iOS sources parse; firmware protocol and ASan/UBSan failure injection passed (LeakSanitizer excluded under executor tracing). Aggregate verify passed in a disposable source copy and generated a byte-identical Xcode project. These are not Apple SDK, model, physical-device, VoiceOver or latency acceptance.

This checkpoint follows primary `366c31b69d183f39a9736900a1aaf027c1aa6cd1`. See [EVERYDAY_COMPANION_ACCEPTANCE.md](EVERYDAY_COMPANION_ACCEPTANCE.md) for the scope, tests and remaining gaps. The existing read-only memory tool now retrieves dated observed history, saved belongings/places, relevant preferences and explicit checklist records. Bounded task routing reuses existing evidence-gated domain adapters; English/Arabic shopping-list records retain original user provenance. Automatic saved-room recovery tries bounded candidates without treating appearance as pose and defers new resets during requested conversation/reading.

This is general assistant integration, not a navigation-first product or proof of a complete autonomous agent. Actual Apple build/device/model/VoiceOver/latency acceptance, general semantic planning, automatic cross-tool retries, routine learning and safe physical interaction remain pending. No new detector/model artifact or private images are included. Earlier checkpoint counts below remain historical.

## Continuous spatial companion follow-up — 2026-10-23

The clarified goal is passive foreground awareness plus private spatial/object history and goal continuity, not a collection of scanners. See [SPATIAL_COMPANION_ACCEPTANCE.md](SPATIAL_COMPANION_ACCEPTANCE.md) for the existing/implemented/pending matrix and whole-task scenarios. New connections retain detector boxes/capture provenance, saved-appearance candidates, private historical recall, paired RoomPlan/world-map frame provenance and bounded search resumption. Task cancellation no longer erases measured alignment. Camera position is no longer saved as an object's measured point.

No general detector artifact is bundled. Model import is explicit; native output/accuracy and model/license acceptance remain gates. Existing center-depth association is not validated, and physical-object guidance remains disabled rather than treating history as a present location. Apple SDK/device/model/VoiceOver and household-task acceptance are still required. This is not completion of every shopping/cooking/navigation capability.

## Historical coordinated source checkpoint — 2026-10-23

This section records an earlier source checkpoint; the everyday-companion checkpoint above and canonical scenario tracker supersede its status and counts. Integration preserves primary `30999a9` and incorporates the reviewed seven-commit Claude branch through `61001267`, plus the coordinated Saudi device-test and familiar-person work. It is source integration, not a deployment or Apple/device acceptance.

**Canonical acceptance tracker:** [CHILD_ASSISTANT_TEST_TRACKER.md](CHILD_ASSISTANT_TEST_TRACKER.md). It records the goal, provenance rules, 24 child-style scenarios, three response paths (ordinary chat, independent hazards, evidence-gated physical requests), and executed versus still-pending checks. Use [CLAUDE_INTEGRATION_REVIEW.md](CLAUDE_INTEGRATION_REVIEW.md) for fixes and evidence, [PROJECT_VISION.md](PROJECT_VISION.md) for product intent, and [SESSION_LOG.md](SESSION_LOG.md) for decisions.

Final portable checks: **530/530 BlindCore**, **14/14 BlindMemory**, **216/216 Node**, **17/17 synthetic MobilitySimulation**; firmware protocol and sanitized failure tests plus native face-slot C++ tests passed. All iOS Swift source parses in default and combined optional configurations. Aggregate verify passed in a disposable copy; the active project was not regenerated. Parsing/source contracts do not replace Apple SDK typechecking, native linking, actual model behavior, audible latency or VoiceOver testing.

The first tab is settled assistant replies only; helper/settings tabs retain accessible mute/end/setup. Foreground startup starts an idle conversation and permitted sensing after setup, respecting saved camera-off and explicit mute/end on foreground return. Rooms show real RoomPlan layout/counts during start/stop scanning. Family enrollment uses photos, then name, then confirmed save. Consented foreground recognition checks bounded face batches and proposes one tentative saved-person notice per encounter; no position, follow or authentication claim. Actual recognition accuracy remains unmeasured here.

Saudi recognition is functional only in an explicitly configured **Debug device-test build**, with the private 16-reference pack pinned by manifest hash. Default/Release has no approved production profile. See [tools/currency-reference/DEVICE_TEST.md](tools/currency-reference/DEVICE_TEST.md); preserve existing face/model/framework options when generating that test variant. No reference images or weights are committed. Dataset diagnostics are not independent phone accuracy.

Physical object direction/reach/pickup guidance remains withheld because specific-target/depth binding is not validated. Typed find tools can gather fresh nonspatial candidates and attributed historical memory; the LLM cannot self-authorize a physical instruction. Bounded lexical guards are not exhaustive semantic proof. Current temperature/weather requests cannot be answered from camera or model memory: this build has no live weather/thermometer tool. A real fresh device-clock tool is included.

**Next, in order:** build the exact selected configuration on the Mac; run the tracker with real model and recorded provenance; measure first audible reply, interruption and hazard-preemption timing; run native camera/currency/family/reading and VoiceOver cases with a sighted adult. Retain the earlier hallucination and latency failures as open until exact-build retests pass. Broader child trials, native hardware acceptance, all-day operation and independent unsupervised use are not validated by these checks.

## Current integration checkpoint: 2026-10-23

This checkpoint integrates the seven commits ending at `61001267dc0633c6b3cb941038b18dbb380cdc3d` onto primary `master` source `30999a9ed0e921491ff62a1a93e073fe6af092ff`, not onto the older shared ancestor. The assistant-first voice, evidence, executable-tool, memory, audience and cancellation work remains. Older “no off switch”, unconditional background listening, confirmed device behavior and test counts below are historical, **not current requirements or evidence**. Explicit mute/end, independent camera control and opt-in supported background voice remain. The latest child-first direction defaults active foreground camera awareness on, respecting a saved off choice and OS permission/background limits; old camera-off-default notes below are superseded.

See [CLAUDE_INTEGRATION_REVIEW.md](CLAUDE_INTEGRATION_REVIEW.md) for the reviewed scope, fixes, portable checks and exact remaining acceptance scenarios. No Apple SDK build, actual model/phone accuracy test, firmware board build, deployment or device readiness is claimed.

## Current next gate — 2026-10-23

Build the integrated continuous-assistant source in the preserved Mac project, then run the exact real-model and device scenarios in [ASSISTANT_FEATURE_CHECKLIST.md](ASSISTANT_FEATURE_CHECKLIST.md). Source now separates conversation/camera, adds session controls, partial-onset cancellation, streamed completion-accounted speech, bounded memory/tasks and executable read-only tools. The earlier current-location hallucination and 8.385-second response failure remain **unclosed actual-app failures**, not overwritten by portable test passes.

<!-- Historical Claude-branch entries below; current integration status above supersedes old controller and test claims. -->
## Next — Mac and iPhone (always-on build)

1. Build BlindCore/BlindMemory and run their XCTests on macOS. They already pass on Linux: 361/361 and 14/14. Build the app and fix compile errors, then build once with `--live-activity` as well. Check `GenerationOptions(samplingMode:)` versus `sampling:` against the installed SDK.
2. On the iPhone, verify always-on:
   - Lock the screen and switch apps: speech warns at once and every 30 s, and listening continues.
   - Return: the camera restarts.
   - Phone call or Siri interruption: listening recovers.
   - Bluetooth off/on and a belt power cycle: the belt reconnects by itself.
3. Try the reading tools, "Describe a photo from my library" and the Arabic status lines. Retype the recorded chat failures. Run "help me find my cup" with the camera on (search result types) and with it off (code reply).
4. Do a VoiceOver walkthrough of every tab, run the rewritten UI tests and the accessibility audits.
5. Firmware: run the PlatformIO builds, then hardware tests of the debounced floor loss, no-target behaviour and the watchdog.

## Next — Mac validation of the hallucination fix (2026-10-22)

1. Build BlindCore and run XCTests, including `CompanionEvidenceTests` (shared fixture must match Node). Then build the app (`--text-only` and normal) and fix any compile errors in `LocalImageAssistant.swift`, `NavigationModel.swift`, `DashboardView.swift`, `VisionService.swift` and `VoiceInput.swift`.
2. Retype the recorded failures in the running app:
   - "Help me find my cup." should be answered by code: "I don't know where your cup is yet. Where did you last have it?"
   - "I last left it on the kitchen table." should be acknowledged as history.
   - Then try the closed/open fridge pair, a goal switch and a cancel. Record exact replies and timings.
3. Measure the label and first-sentence timing with prewarm on the iPhone (target under ~1.5 s), and with VoiceOver confirm that the main screen reads only the reply.
4. Image path: compare grounded and ungrounded descriptions on the recorded stair and room images; evaluate an Apache-2.0 detector and ARKit mesh classification as extra grounding sources.

## Latest actual result — chat still not accepted

Compact role and separated reply/state extraction compile, but final real UI promotes I last left it on the kitchen table into Your cup is on the kitchen table. First sentence8.385s. Fix evidence interpretation and isolate context contributions before broadening features or comparing another model. Minimal plain diagnostic answered the initial cup request correctly; do not confuse it with full-path success. Exact evidence in ios/.validation-results/text-chat-status.json.

## Current priority — typed interactive companion

Finish actual-app task request/replacement/cancellation retest, then correction, progress and restart cases in ios/.validation-results/interactive-agent-scenarios.json. Closed/open understanding improved; latency9–11s to first complete sentence remains unacceptable. Keep Apple model and voice off while isolating context/inference overhead. No model comparison yet. See current PROGRESS entry and text-chat-status.json; do not treat build or guard passes as conversation acceptance.



## Mac follow-up — 2026-10-22

2026-10-22: Download the [complete private test-data transfer](https://github.com/mischa23v/blind/releases/tag/mac-transfer-20261022) on the Mac; verify SHA256SUMS and follow RESTORE_ON_MAC.md. Preserve the current Mac source. Then scan your own rooms on the iPhone; recorded datasets remain repeatable test inputs.


- Resolve the remaining Dynamic Type accessibility audit failure; latest six-test UI batch was 5 passed / 1 failed.
- Investigate Xcode's repeated AppKit layout crash; use serial command-line builds/tests while the IDE failure is unresolved.
- Validate combined current master, including the separately added currency preparation. Local Mac results in PROGRESS cover the pre-currency checkout only.
- Complete physical familiar-person, VoiceOver, pixel/orientation, latency and thermal tests on a LiDAR-capable iPhone. XS Max launch is confirmed, but its current live-monitoring/face-capture gate cannot run without scene depth.

## Currency and clothing colour: current next steps

- Keep `SaudiBanknoteReferenceProfile.selected = nil` until a rights-reviewed, human-audited reference pack and independent whole-frame/device acceptance exist. No new classifier training is part of the current direction.
- Inventory the user's locally downloaded data when available, preserving labels/attribution and physical-note/capture groups. Fill modern 1/20, both sides, issues/materials, negative/overlap/fold/blur/lighting gaps. Do not publish photographs or reference packs.
- Validate the actual native matcher, polygon/proposal veto, preprocessing parity, interruptions and costly confusions on Mac/iPhone. Small development outcomes are not held-out accuracy; original private image-evaluation artifacts are unavailable after workspace loss. Adult controlled trials before child use. See [currency handoff](research/CURRENCY_REFERENCE_MATCHING.md).
- Build and test the colour path with physical fabrics and varied lighting, including white/light-gray/cream/pale tints, masks, background spill and phone movement. Keep neutral uncertainty and no school-certification claim. Two-item comparison remains unfinished. See [colour handoff](research/CLOTHING_COLOR.md).

# Next actions

**2026-10-22 — Mac test handoff.** Portable checks pass on the completed regression fixes, multi-photo/guided-camera/voice familiar-person flow, optional AuraFace configuration and centralized speech gate. The next gate is actual Apple compilation/runtime, not more face-model research. Follow the current top section of `MAC_HANDOFF.md`: default setup first, explicit experimental generator second, generic iOS/device build for the M1 because the checked OpenCV framework has no arm64 simulator slice. Verify native model/pixel parity, capture/import/consent/cancel/delete, short speech/VoiceOver, stale/hazard suppression and memory/thermal behavior. The completed face work now belongs on the shared primary master branch at the user’s request. Primary integration does not constitute deployment or child-ready certification.

Keep source code and metadata separate from external models, images, embeddings and benchmark output. Preserve original benchmark results; any threshold calibration uses a separate identity partition and reports held-out false names and coverage. Tentative familiar-person hints are not guardian authentication or safe-to-follow instructions. Less than 1% false naming is an aspirational engineering goal, not a demonstrated rate or reason to conceal limitations. Test on consenting adults first and verify the actual device/VoiceOver flow before supervised child-user trials. Continuous 24-hour camera/inference and battery/thermal behavior are untested.

The earlier 2026-10-09 notes below are historical.

**2026-10-09 — next session on the Mac mini.** Follow [MAC_HANDOFF](MAC_HANDOFF.md) › "Mac day — start here":
1. Build (`mac:setup`, with and without `--multimodal`) and fix compile errors until BlindCore, BlindMemory and the app pass.
2. Measure the free built-in model on the iPhone 18 Pro Max (time to first words, total) with the compact guide prompt.
3. Speak the first sentence early (streaming, per-sentence spatial check).
4. Eyes-open walk by the user; then calibrate thresholds with real rooms and objects.
5. Design pass: shorten on-screen text (VoiceOver reads every word), wording review with supervised participants.

TASKS.md is the work index; CHILD_ASSISTANT_TEST_TRACKER.md is the canonical scenario/evidence checklist; PROGRESS.md records checkpoints. Older pointers are archived in [research/ARCHIVE_TRACKERS_2026-10-08.md](research/ARCHIVE_TRACKERS_2026-10-08.md).

Currency data: download all eight assets from the [private currency transfer](https://github.com/mischa23v/blind/releases/tag/currency-transfer-20261022), verify/reassemble using RESTORE_CURRENCY_ON_MAC.md, then inspect licence/labels on the Mac before training.

Seeing AI learning: read research/SEEING_AI_CODE_REFERENCES.md on the Mac and download hello.zip from the [private reference release](https://github.com/mischa23v/blind/releases/tag/hello-seeing-ai-20261022). Start currency source review with BankNote-Net; keep licence/model/data and offline checks open.


### After semantic context checkpoint
- Run the app-hosted input-only model replay on the Mac with the frozen source revision, then grade saved outputs separately. Keep absent FoundationModels and unsupported language as unavailable, not passing.
- Execute the iPhone checklist with real sensor/voice conditions; first tab must remain reply-only. Check consent/gallery disable while a familiar hint is queued.
- Investigate held-out usefulness omissions without fabricating tools or unsafe physical advice. Preserve initial failures before any change.
