## Current checkpoint: one controlled arrival; phone-map floor barriers still open

**2026-10-26 — navigation remains the first priority. Live sensor clearance and physical navigation remain UNPROVEN.**

### Verified and published
- [Fixed supplied-map simulation checkpoint](research/tools/koivu-split-candidate-game-v1/README.md): three preserved attempts on the same short phone-derived route. The fixed-foot attempt stopped after 0.175 m on a near-ground margin contact; the raw-ground-following attempt stopped after 0.315 m on ground classification. The separately declared planar-ground world model reached the goal after **1.715355 m / 108 ticks**, with **0 body contacts and 0 margin contacts**, ending **0.322712 m** from the goal within the predeclared **0.35 m** tolerance. All 108 ticks retained unresolved low-obstacle exposure. This is an offline provided-map component result, not live obstacle avoidance.
- The simulator ground repair does **not** establish that the phone routing mask correctly separates floor, low objects and unknown support. The supplied mask still requires a separate, phone-only floor/coverage diagnosis. Failed loop construction is not proof that the physical room is impassable.
- [Author-configured Open3D baseline and exact comparators](tools/tsdf-baseline-comparators/README.md), [matching-height reference audit](research/tools/koivu-reference-height-audit-v1/README.md), [recorded 12/17 input comparison](tools/recent-iphone-depth-comparison/README.md), and [coverage/ARKit acquisition research](research/coverage-mapping-20261026/RESEARCH_AND_ACQUISITION_COACH.md) are preserved with source and evidence limits. None is a navigation-safety pass.
- [Original Koivu phone and reference archives](https://github.com/mischa23v/blind/releases/tag/navigation-test-data-20261026) are Release assets, not automatically extracted repository folders.

### Next acceptance work, in order
1. Verify room units, transforms, effective body/planner dimensions and the exact map barriers against original phone observations. Compare the recorded camera trajectory without treating camera centres as body centres or carving them into free space. Isolate phone-map floor/low-band and missing-support defects; preserve genuinely unresolved observations.
2. Correct only justified mapping defects using phone inputs. Smooth verified ground, not arbitrary low objects; preserve obstacle residuals, boundaries, slopes, drops and coverage provenance. Keep evaluator/reference geometry out of mapper correction and route selection.
3. Complete the requested **three-lap** challenge if a frozen phone-only around-table route exists. Compare the explicitly declared numerical body/margin variants without silently shrinking geometry, moving furniture or counting no-path results as successful movement. Record actual body contacts, margin contacts, stops, invalid starts, support uncertainty and true lap completion separately.
4. Freeze the corrected map, route pairs, conditions, source/input hashes and evaluator assumptions before the **20 routes × 5 conditions** benchmark. The three developmental attempts are not that benchmark: **the frozen 100-run suite has not run; no completed room lap is established in this checkpoint.**
5. Integrate useful tested components only with these evidence boundaries intact. Actual localization, progressive/live sensing, dynamic obstacles, floor-to-head coverage, warning lead time and supervised device validation remain open. No physical trial is represented here.

Earlier tracker content is retained below as history and constraints, not an override of this checkpoint.

---

## Earlier checkpoint: real-phone map and 100-run development test

**2026-10-26 — navigation remains first; live sensing/obstacle-avoidance acceptance remains UNPROVEN.** The latest requested development step is a compact map, object/container and collision game built from genuine recorded iPhone geometry, followed by **100 reproducible schedules (20 fixed routes × 5 movement conditions)**. This explicitly resumes that bounded real-scene simulation work; it does not reopen unrelated features or close the live-safety gate below.

### Completed evidence
- [Real-room comparison, code, fixtures and preserved failures](research/koivu-reference-comparison/README.md): eight MuSHRoom Koivu iPhone 12 Pro Max processed-depth frames, 368,520 scheduled rays; 334,334 paired with the separate author-processed FARO reference and 34,186 reference-no-hit rays retained as unknown. Paired median absolute disagreement 5.055 cm, MAE 9.638 cm, 95th percentile 35.616 cm. These combine exported depth, fixed author registration and edited reference effects; they are not raw sensor accuracy or obstacle recall.
- Full reference geometry was not simplified. The first evaluator exhausted its 600 CPU-second budget without frame metrics; the corrected existing-library query backend completed all eight frames in 48.51 seconds wall / 49.56 CPU seconds. Both source cuts and outcomes are retained.
- [Original licensed archives mirrored and checksum-verified on GitHub](https://github.com/mischa23v/blind/releases/tag/navigation-test-data-20261026). This experimental data release is not an app or safety release.

### Current blocker and next work
- The first frozen phone-only mapper used all 294 pose-matched depth frames: 215,670,168 positive pixels produced 811,806 occupied 5 cm voxels. Of 2,637 modeled support cells, 2,623 also contained body-height hits; only 13 qualified as unblocked candidates and one met the finite sampled-clearance rule. **This map is not usable for the requested routes; the 100 runs have not launched.**
- Diagnose pose/depth association and multi-view accumulation using phone inputs only. Keep this failed map and its criteria. Do not erase potential low hazards by widening the floor band, discard inconsistent points as safe, use FARO to tune the mapper, or replace difficult routes merely to improve results.
- The offline level-floor model and ±3 cm floor ambiguity do not establish low-object/toy detection. Preserve residual protrusions, unknown support, thresholds, slopes and drops. A 1 cm collision fixture tests the scorer after geometry exists, not whether a phone senses a real 1 cm object. Stair detection remains unproven.
- Freeze corrected map/source hashes, route list, seeds, body envelope and movement conditions before reference scoring. The phone-derived model is planner input; FARO is a separate, cleaned-reference-relative collision/support evaluator, never privileged planner geometry. Recorded poses and processed depth lack source confidence/tracking and do not become live sensor authority.
- Report collision-run count, contact events, clean arrivals, stops, no-path/timeouts, invalid starts and support uncertainty separately. A first swept-body contact ends that schedule as a failure. No motion, no route or a rejected start is not successful avoidance. Current proposed nominal game speed is 0.30 m/s, not ordinary-walking validation.
- Integrate useful tested pieces into the map engine only with their evidence boundary preserved. Physical guidance remains withheld; saved maps cannot replace fresh floor-to-head and reachable-body coverage.

---

## Gate 0: evidence and sensing feasibility first

**FIRST — UNPROVEN.** [Gate 0 contract and source references](REBUILD_TRACKER.md#gate-0-real-sensor-evidence-before-navigation-completion) supersede the implementation order below: research → preregistered genuine phone sensing/obstacle-avoidance feasibility → pathing/maps/unknown mapping/return completion → other features. Preserve the detailed navigation and independent fresh-safety requirements.

- [ ] Review real-phone and robotics experiments and verify usable released code, repository/version, license, hardware, dependencies and reproducible builds. Record limitations and unavailable artifacts; do not treat papers or pending research as an implemented solution.
- [ ] Freeze the protocol before more tests: actual device/configuration and source provenance, licenses, byte hashes, confidence, timestamps/synchronization, tracking, intrinsics/extrinsics and coordinate/scale metadata. Separate missing dataset fields from hardware infeasibility.
- [ ] Preregister independent hazard/coverage labels, warning lead-time and miss/false-warning metrics, denominators, pass bounds and held-out cases/seeds. Cover floor-to-head, near-feet/sideways, thin/low objects, toys, slopes/drops, changes and sensor/privacy loss without cane/person/dog-dependent assumptions.
- [ ] Run and label genuine iPhone sensor feasibility evidence only under that protocol. Keep synthetic rendering, fixed real recordings and live actual-device execution distinct. Recorded sensing is not counterfactual human closed-loop proof; a mesh rendering is not phone sensor output.
- [ ] Decide measured phone-baseline capabilities and gaps, then the needed belt/additional sensors, placement changes, gimbal or redesign. Phone-only is not the final requirement; a newer chip is not proof that coverage or misses improve. Verify additions rather than assuming they work.
- [ ] Close Gate 0 only for its measured operating envelope; preserve unknowns and all failures. No component count, provided-map baseline or synthetic A-to-B success closes it. After a bounded pass, resume completion of the detailed map/path/return checklist below, then secondary features and later supervised utility/adoption gates.

---

## Navigation-first delivery checklist

**Priority 1 — do this before expanding reading or other secondary features.** Deliver useful indoor A-to-B navigation through rooms, to the kitchen or an exit, and back. The detailed source of truth is [Navigation first: purpose, architecture and acceptance](REBUILD_TRACKER.md#navigation-first-purpose-architecture-and-acceptance). Zero collisions **and** arrival within a preregistered time are required; stopping, no motion, deadlock or stopping short is not success.

- [ ] Enforce the hard historical-map boundary: saved scans, floors and navmesh may propose destinations/routes only, never current clearance or support. Release movement only with fresh live coverage of the reachable swept body/equipment, head and ground/footprint, including sideways and near-feet regions plus delay/reaction/stopping motion. No cane-dependent safety mode or assumption is allowed: independently check floor-to-head coverage, including thin/low objects, toys, slopes, drops and sideways motion; a cane, person or dog never reduces required coverage/warnings or grants clearance. Equipment protrusions are geometry only. Missing coverage means withheld movement, not cached permission; supported stationary orientation/scanning/replanning may continue.
- [ ] Continuously reconcile available, authorized live camera/sensor evidence with moved furniture, closed doors, people and small floor objects/toys. Retire affected route/map revisions and queued commands. Require fresh positive observed-clear coverage before reopening a path; absence, occlusion and stale feeds are not clearance. Test missed cane sweeps, delayed reactions, side steps, missing ground/head coverage and sensor/background/privacy loss. Provided-map arrival remains only a route/controller baseline, not this fresh-safety acceptance.
- [ ] Repair the goal-aware route horizon/controller boundary and reproduce/broaden the limited favorable provided-map baseline (159 ticks, 3.20 m, zero contacts, 0.30 m goal error under the declared 0.35 m tolerance; fixed mount/no noise only). This is not fresh-safety acceptance. Preserve the authored 300-tick result (2.725 m, zero collisions, 0.787 m short) and Recast comparator (3 m, zero collisions, 0.5 m short) as failed goal-completion controls; do not weaken collision or arrival rules.
- [ ] Run the actor through independent physical/kinematic motion and swept body/equipment collision checks. Count blocked collision attempts as failures/health loss; never snap or teleport the actor to a navmesh or route target. The evaluator may own the hidden mesh; the navigation code must not secretly receive it in progressive-sensing mode.
- [ ] Implement and verify the code-owned place/building/floor/room/object/container hierarchy, portals, transforms, capture times, units, uncertainty, provenance and revisions. Separate static, dynamic, observed, stale and unknown layers; do not fill fog-of-war with LLM guesses or infer free space from missing returns.
- [ ] Connect current full-body/head/limb/equipment bounds, phone offset and stance/body heading to intermediate-path collision and stopping calculations. Distinguish estimates/reports from individual measurements; optical axis is not body heading. Exercise short/tall/wide users, low mounts, turning, slip and incomplete support without generic smaller-body fallback.
- [ ] Retain goals across room transitions and replan through obstacles and changes. Test queued/stale commands, delays, jitter, overshoot, undershoot, wrong turns, dynamic obstacles, tracking loss, stop/resume, return and restart. Bound commands by stopping distance and remaining route, not an unqualified fixed distance beyond the goal.
- [ ] Finish actual upstream mapping/localization bridge build and runtime integration using tested existing code. Published bridge source through `c8aa872` and the separately built Recast library's 12 passing tests are dependency evidence, not app/device or journey proof. Keep supplied odometry/ideal-pose baselines distinct from own localization.
- [ ] Extend the same actual mapper/planner/controller/detector paths from a valid provided-map baseline to empty-map progressive sensing and causal recorded sensors. No synthetic stationary prefix, future trajectory, hidden full mesh or ideal floor may repair missing evidence in a real-data trial.
- [ ] Validate authored rooms/houses and furnished real scans, including actual iPhone captures with verified device, license, metric units and completeness. Keep the invalid raw real-mesh starter as a failed fixture; ARKitScenes must not be labelled iPhone data.
- [ ] Preregister holdout layouts/topology and noise/delay seeds. Report collision attempts, arrival, time, path quality, interventions, recoveries and deadlocks; retain failures and source/input hashes. Separate simulation, recorded sensors, provided-map assumptions and physical-device evidence.
- [ ] Close the raw-prose authority gap: conversation/comfort/request interpretation may use an LLM; map geometry, detections/containers, clearance, navigation state, route progress and arrival remain structured code-owned. OCR labels may support identity/orientation, not replace getting to the destination.
- [ ] Test a nearby safe-destination journey with the usual mobility aid unavailable/broken, without weakening any independent app safety rule or giving the app credit for a cane/escort preventing its misses. Withheld unsafe directions and assistance are separate outcomes, not completed navigation.
- [ ] Complete supervised blind-participant journeys and evaluate actual usefulness, effort, correction and continued adoption. Do not close complete-journey requirements with component counts or safety abstention alone.

---

## Causal scene, body-bound planner and return integration — 2026-10-26

- [x] Connect actual frame observations to a bounded scene worker and the existing LocalPlanner; retain unknown/occluded terrain rather than treating hit history as free space.
- [x] Use actual JourneyRecorder/ReturnTrail breadcrumbs for same-session candidate return, never teleport camera poses to route targets. Fence candidates by session, capture, goal and recorded body bounds.
- [x] Preserve original urgent sensors and exact scan cancellation ordering. Empty/estimated-only body profiles no longer create implicit generic planner bounds.
- [ ] Complete the real upstream RTAB local-grid/corrected-pose bridge, measured localization/body/support validation and actual useful outbound/return journeys. Full recorded replay is evidence to diagnose, not automatic navigation acceptance.

[Implemented scope and checks](research/evaluations/observed-scene/README.md). This stage supplies observed geometry and candidate planning, not released physical walking guidance.

---

## Body-aware sensor-warning integration — 2026-10-26

- [x] Connect local full-body/equipment bounds and chest offsets to supplemental nearby depth warnings. Use full camera transforms and an orientation-independent envelope, never camera heading as walking/body direction; retain reported/unknown measurement provenance. Preserve every existing urgent detector result.
- [x] Load current private profile on startup; withdraw stale geometry before save/delete and on mount/lifecycle changes. Expose the same session-only mount setting inside Body and chest holder. No new calibration authority, body dimensions inferred from demographics, directional cue, or clearance result.
- [ ] Measure warning burden, misses and useful detection under actual chest mounting; current recorded replay uses conditional hypothetical wearers, not body ground truth. Complete calibrated pose/support/collision integration and independent supervised device acceptance before physical guidance.

Portable focused results and boundaries: [body-warning receipt](research/evaluations/body-aware-warning/README.md). This is a supplemental warning increment, **not completion of navigation**.

---

## 2026-10-25 — Selected-PDF page reader source increment

Implemented a bounded, private selected-file page quotation lane in existing controls, separate from exact-model manuals and existing photo/camera contracts. Selection, page request, native resource lease and real speech receipt are separately owned. Reviewed direct polite commands and one terminal punctuation mark retain the same trusted/private gates. Invalid requests stop old reading; valid-source corrections need no new picker. See [scope and evidence](research/evaluations/selected-document/README.md).

Actual [Apple run for `6d6954b`](https://github.com/mischa23v/blind/actions/runs/40243450535/job/121319972133) executed the fourteen PDF fixture methods: **9 passed, 5 failed**. Repair the failed source/page sentinel, oversized extraction and permission fixtures without weakening production limits or permission gates, then rerun the exact corrected source. Real picker security-grant/cancel races, actual speech/VoiceOver, minimum-budget interruption and supervised useful-reading acceptance remain open. Exact-model manual binding, interpretation, visual completeness and appliance control remain unimplemented/unvalidated. **Do not mark R39 or R40 complete from portable/source checks.** The same native job remains red, including the Practice Dynamic Type audit. Physical-device/real blind-participant acceptance and 400 distinct complete journeys remain open.

---

## Explicit menu-reading alias increment — 2026-10-25

- [x] Exact raw whole-request English/Arabic imperative and ordinary polite aliases reuse existing captured-document acquisition/playback/review; no semantic menu lane or new speech.
- [x] Fail-before parser regressions, trusted-route contracts, source privacy/review and unchanged attempt semantics; independent source review.
- [ ] Exact native app/OCR/audio and supervised nonvisual usefulness; not hands-free task authority, complete menu reading or goal completion.

[Verification receipt](research/evaluations/menu-reading-aliases/README.md).

---

## Captured-page review increment (2026-10-25 candidate)

- [x] Local bounded volatile source review, distinct attempts/receipts, exact onset and stale-callback ownership, English/Arabic parser, ordinary-budget/private gates.
- [x] Core execution and independently reviewed production boundaries; see candidate evidence for extracted-controller limitations.
- [ ] Exact native build/audio and supervised nonvisual usability acceptance. No menu interpretation or completed real-world goal claim.

[Scope, semantics and verification limits](research/evaluations/captured-page-review/README.md).


---

## Checkpoint 31 acceptance update — search-clue retry boundary

- [x] Repair code-only history/clue/clarification after exhausted find adapter attempts without resetting retries or starting more sensor work; preserve checkpoint-30 reader behavior.
- [x] Execute real coordinator-route portable regression: 34/34 repaired cases; retain source-29 failed-before replay and native failure evidence.
- [x] Complete final combined serial 75-file Node aggregate: 499/499, zero skips/failures, unchanged source hashes; retain separate first aggregate's 497/499 result and reviewed source-contract corrections.
- [ ] Rerun unchanged native source-29 speech probe assertions against published repaired production. Do not accept a generic unavailable reply or question state `none` instead of the frozen room/area question and real speech completion.
- [ ] Validate actual forget acknowledgment in a separately reviewed operation-owned speech probe; current isolated harness observes state clearing only. Nonvisual actor comprehension and actual physical find success remain unproven; no complete-journey count added.


---

## Checkpoint30 — bounded captured-text completion

- [x] Keep installed immutable text alive through ordinary budget waits and slow exact callbacks, without extending capture/acquisition or other reference deadlines.
- [x] Reschedule one source-owned budget wake on pacing changes; preserve existing cancellation, foreground, privacy and hazard controls.
- [x] Retain a bounded metadata-only completed/cancelled playback receipt; purge it on explicit privacy/history deletion and session retirement. Do not auto-complete real-world goals.
- [ ] Verify real device speech/timer/Vision callbacks, minimum-budget full-page coverage, pacing changes and late-callback privacy retirement.
- [ ] Implement separately reviewed source-bound repeat/clarification and menu understanding; neither is provided by this repair.

Evidence: [checkpoint30](research/evaluations/reading-completion-checkpoint30/README.md). Historical checklist follows unchanged.

---
## Checkpoint29: provisional search-area continuation (source verified)

Trusted short answers to the delivered room/area question now remain attributed provisional search clues, with source-bound corrections, same-goal continuity, scoped privacy retirement, and brief budget-checked acknowledgments. They are not current-location facts, navigation geometry, physical clearance or completed goals.

Verification: 1,280 Core tests and 474 Node checks pass; 29 extracted controller source-projection flows are **not native/audio journeys**. The latest-parent diagnostic-only overlay separately passes 26 Node and 6 Python checks. Earlier failed cuts and test-only integration repairs are retained in the evidence receipt. No new dependency/model is introduced.

Native acceptance remains pending: real question/acknowledgment callbacks, Arabic/correction and privacy flows, minimum speech-budget checks, assistive-audio intelligibility, and separately grounded physical retrieval. Historical native producer pins remain unchanged and require reviewed rebase before stage29 use. Unverified microphone ownership and the separate “the/your fridge” naming issue are not changed.

See [checkpoint29 evidence](research/evaluations/search-area-clue-checkpoint29/README.md). The complete prior public body is preserved below.

---

## 2026-10-25 — Checkpoint28 candidate: useful search clarification and faithful reported history

Executable baseline is checkpoint27 `452b9ebac628efd5d61290174cac52318f6b7890`; integration parent is `550b845abce842719251017c3e3a09d8e95408d7`. This receipt is prepared before publication; earlier historical candidate notes below are unchanged.

- Unknown and unsuccessful searches now ask for a room/area clue, not where the person last possessed the fridge. Existing memory evidence remains first. English history no longer turns “saw”/“was” into “last had”; Arabic retains reported uncertainty. No room guess, camera result, clearance or task completion is invented.
- **1,264 Core tests and 457 Swift-enabled serial Node checks pass, zero final failures/skips; 987 source hashes unchanged.** The original 18-assertion-failure regression and first dataset-env skip remain disclosed. After overlaying later diagnostic-only changes, **30 affected Node checks and 10 exporter tests pass**; three native test files pass syntax parse, not SDK typechecking. Production bytes did not change between these cuts; this is not a second full aggregate.
- **Next:** verify the actual native three-turn answer and audible/nonvisual outcome; implement and review a separately owned provisional raw search-clue continuation for natural short answers. That binder is not implemented here. Safe abstention, a state test and a useful question do not establish a completed find goal. Existing determiner/ownership naming remains a separate gap.

Evidence: `research/evaluations/find-clarification-checkpoint28/README.md`, seven-file hash manifest and explicitly redacted selected test output. No complete workspace inventory or private raw transcript is included.

## 2026-10-25 — Captured-view text receipt, portable-tested checkpoint27 candidate

Published executable baseline is checkpoint26 `f9f70ea33faff728bc418aeed3720498614d95f9`; final diagnostic-only parent is `79f1b9d547030474142322856e8513b7fdbbc011`. This staged increment is not yet published at the time of this receipt.

- Explicit text/document reading now freezes one bounded in-memory RGB view, hashes actual image bytes and preserves complete OCR blocks in a `.capturedText` reference receipt. Fresh limited-VIO frames may supply captured text without granting pose, motion, current-location or physical authority. Output stays an uncertain quotation, not page-alignment instructions; no pictures or OCR are uploaded/persisted.
- Source epoch, timestamp/orientation, request/session and cancellation ownership are rechecked. Source interruption/restart/starvation, stop/new question, background/private-route/urgent events retire work. One noncancellable native OCR lease prevents stacked work; the original 0.5-second result admission and 60-second request deadline remain conservative bounds, not measured latency guarantees. Each command reads one captured view, not an unlimited stream.
- Exact speech callbacks own completion. English/Arabic slices retain all original text within the minimum 30-word budget. Typed boarding text retains its original stricter pose-owned dispatcher. Barcode/light/color/familiar/currency/spatial gates and passive-repeat ownership remain unchanged.
- **1,263 Core tests and 457 serial Swift-enabled Node checks pass, zero final failures/skips.** Core production source stayed unchanged through later source-contract/diagnostic fixes. Initial Node 449/452 and the separate reading-contract failure are preserved; narrow test updates retain exact color/spatial retirements and add negative mutations against broad captured-text exceptions. Independent source and merge review found no remaining blocking issue.
- Seventeen extracted native admission checks and twelve passive callback/ownership projection checks pass; these use stub containers, not actual ARKit/Vision/audio. Native syntax parse passes, not Apple SDK typechecking. The final diagnostic-only layout successor was applied after the full aggregate: seven affected Node checks, ten exporter tests and LaunchTests syntax parse pass separately; those are not a second full aggregate.
- Apple compilation, actual camera/OCR/audio callbacks, limited-tracking image usability/latency, simultaneous producer interruption, minimum-budget Arabic playback and supervised device acceptance remain open. This does not complete the tracker, establish calibration or approve independent child use.

Evidence: `research/evaluations/captured-text-receipts-20261025/README.md`, exact source manifest and preserved logs. Historical records below remain unchanged.

## 2026-10-25 — Bounded evidence-owned automatic repeat suppression, portable-tested candidate

Executable baseline: checkpoint25 `a5a76f1802de4720cb774ff1cbad65477529b1d9`; full aggregate source cut checked through `50d503f03b126c8b6e1533b794dee54c8e35f920` (archival voice-probe changes only). This candidate changes four passive source/test paths and one diagnostic-only source-contract test and has not yet been published at the time this receipt was prepared.

- Automatic scene novelty now uses bounded normalized Vision OCR/detection/classification content and existing multi-frame detector agreement, never generated answer wording or capture timestamps. Empty independent evidence cannot mint an automatic revision. This is exact normalized observation comparison, **not general semantic equivalence or perceptual accuracy**.
- Novelty is committed only by the exact narration's completed playback callback under current session/camera/room-visit/map/preferences ownership. Interrupted, rejected or ambiguous delivery stays retryable under unchanged companion frequency, budget, quiet, focus and priority gates. Explicit questions/repeats and independent hazards remain separate.
- Full same-source portable verification: **1,257 Core tests and 444 serial Swift-enabled Node checks; zero failures/skips**. Focused composition uses actual CompanionAttention and SpeechDeliveryLedger; exact native-block projection has 12 assertions with stubbed containers, not Apple audio execution. Native syntax parse passed. Independent scoped review found no blocking defect and verified raw Vision provenance.
- Final projection preserves the seven diagnostic-only successor paths from publication parent `7980bd1649810c6e89f1cbd90674cf27355c8ad6`. Its outdated blanket continuation assertion was repaired: only layout recording may continue, the unsuppressed audit always runs, and final failure propagation/artifact errors remain mandatory. Six negative mutations plus **16 affected Node checks and 10 exporter tests** pass. The original 15/16 failed projection is retained. This is a separate test-only source cut, not a second full aggregate; app/Core production hashes remain unchanged.
- Original empty-evidence/generated-paraphrase failure, initial default-cache error and corrected test-only enum compile failure remain preserved. No thresholds, calibration, assets, physical-release gates or voice authority changed.
- Full Apple SDK typecheck/build, VoiceOver/audio/device acceptance, calibrated localization/authority and complete everyday scenario coverage remain open. This does not finish the tracker or approve independent child use.

Evidence: `research/evaluations/passive-scene-delivery-20261025/README.md` and associated exact-source manifests/logs. Historical records below are preserved unchanged.

## Current continuation — reviewed registration diagnostics, checkpoint25 candidate, 2026-10-25

Verified published parent is `efa9e8ca87f66e1e28e8639e5fc5a7ea01be27f9` (isolated voice Apple-probe/backup successor after executable checkpoint24 `63dff7055f25c252da4c4c623b85fd3421716d40`). The reviewed registration increment acquires bounded, hash-bound RoomPlan comparison measurements and explicitly selected correspondences, saves local diagnostic history, and retires matching review data at privacy-deletion admission. It does **not** establish current room/floor/container identity or enable physical guidance. Independent review found a held-read/save admission race; the new regression reproduced six failed assertions, and the minimal guard/UI repair passes without weakening expectations. The durable runner also no longer requires an ignored local lockfile. Full regression prompted an exact bounded-hook source-contract update that preserves all original loss-retirement assertions and adds mutation checks; resource-exhaustion failures are retained separately. A newly adjacent helper required a metadata-only SavedPlace seam in the scoped-review harness; original compile failure is preserved and actual history logic remains tested.

**1,249 Core, 51 real-GRDB memory and 441 Node checks passed, zero final failures/skips.** Node includes 31 extracted registration acquisition cases; four changed-native syntax configurations also pass. Core includes the original 100 recorded ARKitScenes trajectory rows, not live localization. Original failures are preserved. Apple SDK/native callback execution, VoiceOver, device cost and independently validated containment/instance authority remain open; source extraction and parsing do not close them. See [checkpoint25 verification](research/rebuild-evidence/checkpoint-25/verification.json).

The same source candidate includes the separately diagnosed practice-footer Dynamic Type repair: four semantic font/wrap/alignment modifiers, preserving English/Arabic safety text and the native audit. The actual Apple footer failure is retained; a source-contract pass is not a native audit pass.

Next: publish the reviewed candidate, verify the exact remote commit and complete Apple workflows. Keep voice-deletion work a separate reviewed increment. Do not infer current checkpoint Apple success from earlier runs or from these portable results.

## Current continuation — checkpoint24 candidate, 2026-10-25

Verified published baseline is `3d22925028463000f203d2b02adac506fb6152fb` (checkpoint23). This narrow test/CI increment converts the six continuity fixtures to nonblocking MainActor async map IO while preserving their assertions and ten-second bound. Fourteen unexplained runtime failures receive phase/timing diagnostics only; the practice-label failure receives a bounded action-log excerpt only. No app behavior, safety timer, accessibility audit or test expectation is weakened. **10 focused Node checks passed, zero failures/skips**, with assertion-preservation and shell exit-status/bounded-output witnesses. These are source/synthetic-shell results, not Apple runtime acceptance; no unrelated Core rebuild was run. Exact-commit full Apple rerun is required after publication. See [checkpoint24 verification](research/rebuild-evidence/checkpoint-24/verification.json).

Next: publish the reviewed candidate, verify its exact remote commit, then inspect the complete native workflow. Keep prior checkpoint22 hosted 17 failures and UI2 failures as historical evidence, not assumed checkpoint23/24 outcomes. Runtime scheduling and practice timing remain unproven until native results identify their cause.

## Current continuation — checkpoint23 candidate, 2026-10-25

Latest verified published baseline is `3d6330e064f7e754a5b454f79732f12f532ccb7a` (checkpoint22). This top note supersedes older “current” snapshot tables below; their evidence remains historical. The new candidate combines the practice-heading Dynamic Type repair with optional familiar Mac build/notice packaging. **429 Node checks passed, zero failures/skips**, including executable Swift harnesses; familiar membership is 13/13. The first run omitted the Swift selection; a second exposed two read-only cache failures; corrected writable-cache replay passed without changing assertions. Full Core was not rerun for this UI/generator increment. Publication and exact-commit Apple CI remain pending. See [verification](research/rebuild-evidence/checkpoint-23/familiar-verification.json).

- Implemented locally: adaptive practice heading; pinned familiar assets/build membership; exact app notice/model packaging checks. Default/non-familiar project generation remains unchanged. Native packaging and Dynamic Type outcome are not yet passed.
- Already integrated through checkpoint21: bounded persistent recorded path history, not calibrated physical retracing. Do not reapply its older staged source.
- Next: verify this candidate's remote commit and Apple workflows; rebase/review staged registration diagnostics against current NavigationModel. Voice enrollment/PCM scaffolding remains staged; durable failed-deletion intent, host lifecycle and calibrated authority remain missing.
- Open: measured native position/body-heading/support, independently validated room/container identity, automatic world mapping/relocalization and safe cross-map guidance, 400 complete integrated scenarios, signed-device accuracy/endurance/accessibility and supervised acceptance. No source/test count closes those gates.

## Boarding and diagnosed accessibility repair update — 2026-10-25 12:01 UTC

**1,249 Core and 413 Node checks passed**, zero local failures/skips. Boarding fields now use bounded code-owned parsing and private source ownership; printed/pass data is not live gate verification or airport navigation. The full aggregate caught a real regression where bare travel nouns granted reading relevance; it is repaired with unchanged original expectation and English/Arabic counterexamples. The actual Apple audit identified the practice button; its label now supports scalable multiline layout without suppressing the audit, pending the new native run. A brittle currency helper test boundary was repaired without changing that helper or reference-verifier safety. See [checkpoint22 evidence](research/rebuild-evidence/checkpoint-22/verification.json).

## Persistent recorded-path reconstruction update — 2026-10-25 10:47 UTC

**1,217 Core, 48 GRDB memory and 411 Node checks passed**, zero final local failures/skips. The Core rerun includes100 actual recorded ARKitScenes trajectory rows; original optional-data skip and extractor dependency failure remain preserved. Actual path chronology now persists through bounded paginated storage with active-trip identity, pinned observed start/entrance/meeting references, explicit dropped ranges, and stale/lost/limited-frame fences. This is recorded history/preview, not proof of physical retrace, calibrated multi-map guidance or dense all-day device performance. Latest native20app and hosted test jobs passed; UI audit remains separate. See [checkpoint21 evidence](research/rebuild-evidence/checkpoint-21/verification.json).

## Useful historical recall and Apple test repair update — 2026-10-25 10:12 UTC

**1,203 Core and 411 Node checks passed**, zero failures/skips. Ordinary item questions can now retrieve a labelled original last-report clue without opening a helper screen; competing contexts ask rather than merge. First-tab VoiceOver text and spoken output use the same short complete clue, plain date/attribution and current-location uncertainty, never technical IDs or ISO timestamps. Targeted room queries no longer omit a late-listed matching room. Actual Apple failures prompted correct NO/YES preference handling, nonblocking XCTest waits, exact runtime completion observation and honest model-availability acceptance gates. Dynamic Type remains open with diagnostics, not suppressed. Prior19app/optional-face compilation passed, but hosted124/132 and UI12/14 were incomplete; this new source still needs Apple rerun. See [checkpoint20 evidence](research/rebuild-evidence/checkpoint-20/verification.json).

## RGB reader and family enrollment reconstruction update — 2026-10-25 09:15 UTC

**1,194 Core and 409 Node checks passed**, zero failures/skips, after two stale exact-text source contracts were strengthened rather than removed. Explicit text/document/barcode/light readers can use fresh coherent RGB evidence without depth, while raw tracking loss retires their output before throttling. Child enrollment has an exact-action helper attestation path and stale-token protection; this is not verified guardianship or validated child recognition. Prior checkpoint18 now compiles in real Xcode for the default simulator; its hosted unit stage failed and UI testing is still running. Separate optional face arm64 device compilation passed at4aa39bf, not signed-device/accuracy acceptance. This newer source still needs Apple execution. See [checkpoint19 evidence](research/rebuild-evidence/checkpoint-19/verification.json).

## Voice ownership and native build repair update — 2026-10-25 08:54 UTC

**1,194 Core and 407 Node checks passed**, zero failures/skips, after preserving and fixing two stale aggregate source contracts. Immutable one-use voice delivery and anonymous-turn isolation are connected, without claiming wearer/addressee authentication. Actual Apple failures prompted explicit Unicode-scalar validation, documented ARKit Swift array access, unique mesh pointers and correct memory-writer actor ownership; the permanent writer replay no longer masks isolation under a MainActor test class. Fresh Apple SDK execution is still required. A separate pinned optional familiar-face unsigned-device CI recipe is now included, not yet validated. Historical full conversation report and372 partial scenario sequences are preserved separately from the unfinished400 complete-scenario goal. Long-trip retrace remains a source-only WIP backup. See [checkpoint18 evidence](research/rebuild-evidence/checkpoint-18/verification.json).

## Scoped review and persistence reconstruction update — 2026-10-25 08:30 UTC

Reviewed26-path native memory increment is applied and frozen. **1,187 Core, 404 Node and 38 GRDB memory tests passed**, zero failures/skips. Source-bound correction/deletion and atomic bounded off-main dialogue/state saves retain identity/revision fences; historical speech uses the owned delivery queue. Physical room/container scope identification is still incomplete, and unrelated synchronous database users may contend. The real Apple15 run passed Memory35 but failed two Core tests and two native adapter compiler checks. Those failures are preserved and repairs are staged; this is not a native/device pass. See [checkpoint17 evidence](research/rebuild-evidence/checkpoint-17/verification.json).

## Scoped recall reconstruction update — 2026-10-25 08:22 UTC

Narrow native lookup repair is applied and frozen: current-scope checks now cover item and sensor fallback consumers, and explicit historical recall retains source attribution rather than becoming a current-location claim. **1,181 Core and 397 Node checks passed**, zero failures/skips. Broad review, asynchronous writer and owned historical speech remain staged. No positive room/container localization issuer is established. Checkpoint15 is pushed at `eb6972295f3c81009daff79f3c7eb1cf6c7aef88`; its real Apple run40176063205 is now executing after the repository became public. Its macOS Core stage failed; diagnosis and remaining build stages are pending. Do not interpret Linux or focused passes as Apple acceptance. See [checkpoint16 evidence](research/rebuild-evidence/checkpoint-16/verification.json).

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

## Historical checkpoint-07 feature snapshot — 2026-10-25

Snapshot source: `978b506283b5ce9d1ea05ea120db8806f47754fe` (tree `750cd35b01a4e662a99797589afbbca53092a308`). The table below is retained history, not a live queue: its staged/unpublished labels were superseded by later receipts. The bounded [current reconciliation](REBUILD_TRACKER.md#current-feature-progress) pins public `36f57456`, published app `6d6954b`, and actual native failures. The older [REBUILD_FEATURE_STATUS.md](REBUILD_FEATURE_STATUS.md) is also a historical snapshot. Original requirements and failures remain in [REBUILD_TRACKER.md](REBUILD_TRACKER.md) and [REBUILD_SCOPE_ADDENDUM.md](REBUILD_SCOPE_ADDENDUM.md).

| Workstream | Actual state | Next required outcome |
| --- | --- | --- |
| Command authority | Published native origin gate; portable behavior verified | Real verifier and Apple/live-mic acceptance remain open; do not grant uncertain speech authority. |
| Task/memory | Published partial correction/progress/completion repairs | Fix same-goal target/place binding; complete original whole conversations. |
| Clock | Published direct/legacy/selected-tool code-owned delivery | Actual Apple/model/audio and compound-response validation. |
| DEBUG logs | Published native source hooks and privacy deletion | Device callback/storage-protection/performance validation; no UI/upload. |
| Registered spatial/collision | Published current-leg controller, exact tickets and synchronous map storage | Calibrated native pose/body-heading/support issuer; automatic maps/relocalization/return. |
| Ordinary guards + reference Core | Published at 978b506; portable scope verified | Real small-model behavior and native exact-model manual/PDF/speech adapters remain missing or unverified. |
| Raw observations | Staged budget candidate cleared 81 scoped source tests; archive/application pending | Final candidate archive and privacy/reopen proof; never label raw history learned world memory. |
| Async map IO | Staged, not applied | Rebase after observation/privacy repair; blocked-writer/CAS/rollback/delete and full aggregate. |
| Selected-photo flow | Applied, unpublished; focused checks and Core 1057 passed | Node aggregate FAILED (391 total, 389 passed, 2 failed); test-only correction/full rerun and publication pending; actual Apple lifecycle and accuracy remain open. |
| Journey Core / quiet output | Staged additive Core remains unwired; native quiet patch needs rebase | No automatic cross-map journey or return; integrate only after fresh preimage and issuer/dependency checks. |
| 400 episodes and device readiness | Incomplete | Actual-stack episodes plus real small-model/Apple/device accuracy, accessibility and latency. |

No broad task is closed by a source snapshot or test count. Keep native source hookup, portable execution, actual Apple runtime, measured physical accuracy and completed user journey as separate acceptance states.

### Earlier task/checkpoint snapshots — retained history

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

This section supersedes historical status below. It records the current rebuild, not the missing later checkpoint or a claim of complete recovery. Preserve all earlier entries as history.

**Durable scope:** [REBUILD_TRACKER.md](REBUILD_TRACKER.md) contains the checkpoint plan and preserved/rebuild/missing-evidence ledger. [REBUILD_SCOPE_ADDENDUM.md](REBUILD_SCOPE_ADDENDUM.md) adds earlier visual, accessibility, identity, hazard and everyday-workflow requirements. [TODO.md](TODO.md) is the immediate execution queue; [PROGRESS.md](PROGRESS.md) records actual results; [SESSION_RECOVERY.md](SESSION_RECOVERY.md) is the restart handoff.

| Workstream | Current status | Completion evidence still required |
| --- | --- | --- |
| Baseline and durable requirements | Baseline restored: 717 files matched exactly. Initial documentation pushed as `20af33fe`. | Save subsequent verified source/document checkpoints promptly and verify each remote SHA. Later unpushed source is not recovered by restoring the baseline. |
| Command-authority boundary | PARTIAL: default-untrusted command gate implemented with native entry hookup; source-review defects corrected. | All new Swift cases now pass. Apple SDK compilation and actual microphone/typed authority-path testing remain pending. Real speaker verification remains unfinished. |
| Independent safety state | OPEN: preserve code-only guidance and fresh hazards across quiet, cancellation and new goals. | Distinct perception/task revisions, exact cue withdrawal and hazard-channel continuity through actual integration. |
| Spatial registry and localization authority | PARTIAL: standalone frame-registry and pose-lease foundation exists. Not wired into the app. | Synthetic Swift foundation tests pass; measured relocalization, map adapters and continuous world/building/floor/room app integration remain pending. |
| Mapping, collision and return | OPEN: baseline components survive; later combined integration remains to rebuild. | Transactional map updates, dynamic/full-body swept collision, stale-map rejection, restart continuity and complete outbound/return journeys. |
| Local DEBUG recorder | PARTIAL: standalone foundation exists. Not wired into native session/events. | Foundation Swift tests pass. Native event/evidence integration and device validation of retention/privacy behavior remain pending; no UI or uploads. |
| Conversation, memory, clock and references | OPEN: original failures and exact safety contracts are in the tracker. | Provenance/corrections, task completion, fresh code-owned clock, full reference blocks, harmless-answer regressions and real photo/manual sequences. |
| Expanded everyday/accessibility/hazard scope | OPEN: addendum R54–R81 captures requirements. | Inspect preserved hardening before rebuilding; verify profile/roleplay/VoiceOver, depth-independent visual help, numeric integrity and stair/slope failures. |
| Executable verification and review | PARTIAL acceptance: full Core 910/910 and aggregate Node 338/338 passed, both 0 failed; Node 0 skipped. All 45 new Core cases executed. | Default and DEBUG + BLIND_FAMILIAR_PEOPLE iOS syntax parsing both exited 0, not Apple SDK compilation. Node also executed extracted native-method checks through Swift; native Apple/device acceptance and full spatial/debug integration remain pending. |
| 400 scenarios, native/device acceptance and handoff | OPEN, incomplete. | Whole-episode actual-stack evidence, measured/synthetic separation, missing native adapters, live iPhone checks and complete reproducible handoff. No safe-use/readiness claim. |

**Checkpoint rule:** implement a small coherent increment, reproduce the relevant failure, run focused and affected regression checks, review the final diff, commit and verify it on GitHub. A local change, source-contract pass, prepared test or historical count is not completed native functionality. Do not wait for all 400 scenarios before preserving verified work.

**Product constraints:** code owns all physical guidance; untrusted speech cannot redirect/cancel tasks; quiet preserves valid hazards; no new UI, automatic debug upload or room-permission system. Unknown/stale evidence never becomes clearance. The longer mapping replay, real speaker verification, native gaps and all unexecuted scenarios remain open.

Evidence: [verification summary](research/rebuild-evidence/checkpoint-01/verification.json), [Core log](research/rebuild-evidence/checkpoint-01/core-tests.log), [Node log](research/rebuild-evidence/checkpoint-01/node-tests.log), [tested source hashes](research/rebuild-evidence/checkpoint-01/source-hashes.json).

### Historical task records

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

## Current continuous-assistant acceptance — 2026-10-23

The complete 44-capability checklist and concrete scenarios now live in [ASSISTANT_FEATURE_CHECKLIST.md](ASSISTANT_FEATURE_CHECKLIST.md). Source fixes are not acceptance: Apple compilation/model evaluation, physical audio/background/accessibility/latency/endurance, semantic grounding, age-sensitive safety, model-aware context compaction and broader scene/action tool coverage remain open. Product intent and session decisions: [PROJECT_VISION.md](PROJECT_VISION.md), [SESSION_LOG.md](SESSION_LOG.md).

<!-- Historical Claude-branch entries below; current integration status above supersedes old controller and test claims. -->
## Always-on and full-scan follow-ups — 2026-10-22 (source written; Mac/device verification pending)

- [ ] **H07 — Always on.** Background listening, speech and belt; the camera pause is announced every 30 s; restart on return, failure or frame loss; no off switch; practice auto-ends. Exit: iPhone test with the screen locked, app switching, a phone call, Siri, Bluetooth off/on and a belt power cycle; listening is never lost silently.
- [ ] **H08 — Sensor-backed object search.** Exit: found/measured, seen-without-depth and not-located results on device; the hint stays fresh while turning.
- [ ] **H09 — Accessible screens.** Exit: VoiceOver walkthrough of every tab by a blind tester; accessibility audits pass; every delete and share is confirmed.
- [ ] **H10 — Firmware robustness.** Exit: PlatformIO builds; a hardware test of the debounced floor loss, no-target behaviour, watchdog reset with the motor off, and the pairing window.
- [ ] **H12 — Reading tools (Seeing AI-style).** Live text, page reading with guidance, barcode/QR with product names, light detector, explore by touch. Exit: `ReadingToolsTests` pass on the Mac; device tests with real pages, signs, products, QR codes, dark and bright rooms, and a VoiceOver explore-by-touch session.

- [ ] **H11 — Live Activity / Lock Screen status.** Source and the opt-in `--live-activity` generator target are written; the project test passes. Exit: the extension builds on the Mac; on the iPhone the Lock Screen shows listening and camera state, VoiceOver reads it in one swipe, and it updates when the app goes to the background and returns.
- [ ] **H13 — Describe a library photo and Arabic statuses.** Exit: on the iPhone, pick photos with text, people and none of either and check the regions and overview; switch to Arabic and check the Devices, Routes, Places and Community maps status lines.

## Conversation evidence rule — 2026-10-22 (source written; Mac verification pending)

- [ ] **H01 — Code-owned object facts.** `CompanionUtterance`/`CompanionFactBook` answer find requests and location reports without the model; reports stay historical with time. Exit: BlindCore `CompanionEvidenceTests` pass on the Mac, and the recorded cup failure is answered correctly in the running app.
- [ ] **H02 — Chat claim guard on every chat path.** `ConversationClaimGuard` plus `SpatialClaimGuard` before partial and final text; retry once, then refuse. Exit: shared fixture passes in Swift (Node 125/125 already) and actual typed scenarios show no invented location, absence or perception.
- [ ] **H03 — Image grounding.** `VisualGrounding` 2-of-3-frame detector agreement before an object is named as fact. Exit: recorded-image comparison and device check. Add a licence-cleared detector and ARKit mesh labels.
- [ ] **H04 — Reply-only main screen.** Exit: VoiceOver reads only the reply; actions and long press reach every tab; rewritten UI tests and accessibility audit pass.
- [ ] **H05 — Latency with prewarmed sessions.** Exit: first sentence under ~1.5 s on the target iPhone, measured with signposts or logs.
- [ ] **H06 — Continuous microphone survives offers and interruptions.** Exit: device test of offer answer, phone call/Siri interruption and recovery.

## Interactive task-agent acceptance — 2026-10-22

- [ ] Natural typed requests start a useful response and persist the requested goal without redundant permission questions.
- [ ] Changed/cancelled goals retire pending steps; reported completion is separate from measured completion.
- [ ] Corrections, ambiguous references, interruption, restart and suspended-task resumption pass actual conversation checks.
- [ ] Meet first-useful-response target on the actual target hardware; current simulator first-sentence timing9–11s fails.

Sources and executable/manual boundary: ios/.validation-results/interactive-agent-scenarios.json. Closed/open pair now correct in actual UI; no full acceptance gate closed. Voice and fresh camera/depth tools remain separate unfinished work.

## Current acceptance correction — 2026-10-22

- [ ] Continuous hands-free companion: persistent camera/depth/audio input, goal-aware conversation and interruptible output; no Talk/Repeat/Start requirement for everyday use.
- [ ] Voice-guided setup and simple bottom tabs preserving feature access; quiet does not disable perception.
- [ ] Same app pipeline accepts recorded images/maps/depth/audio for a kitchen/fridge conversation walkthrough and injected failures.
- [ ] Correct fenced-JSON Apple response handling; retain strict ID/evidence validation.
- [ ] Physical foreground/background/lock, audio interruptions, recovery, battery/thermal and sustained-operation evidence. Simulator and direct Mac model results cannot close this gate.

Review complete; implementation/acceptance items above remain open. Evidence: ios/.reference-materials/review-694eccb/CONTINUOUS_COMPANION_REVIEW.txt. Earlier home UI remains local work, not approved final UX.

## Local usability revision — 2026-10-22

User priority: normal use should start on opening, prompt through speech, and never expose wearable diagnostics on the child home. Simple home/More/Settings separation and automatic startup are implemented. Final signed device build-for-testing and isolated simulator build pass; Node 88/88. Home audit and functional navigation/stop checks pass; detailed Ask contrast audit, real speech/VoiceOver, physical startup and child usability remain open. No acceptance gate is closed merely by this UI change. See PROGRESS and ios/.validation-results/voice-home-summary.json.



# Implementation task checklist

**Mac validation — 2026-10-22:** Build/UI fixes published with local evidence in PROGRESS. Base simulator/device, optional multimodal device and signed AuraFace device builds passed; XS Max launch confirmed by user. Hosted iOS tests 22/22; latest UI batch 5/6 with Dynamic Type audit still failing. Simulator tab navigation and simulation start/stop passed. Real recognition, sensor/VoiceOver/thermal and child-use gates stay open. These Mac results cover the pre-currency checkout; combined master needs validation.

**Cloud review and primary-branch handoff — 2026-10-22:** Regression fixes, additive private-memory migration, opt-in multi-example familiar-person/AuraFace/voice flow and centralized speech admission are implemented. Final portable checks: Node 88/88, BlindCore 306/306, BlindMemory 14/14, MobilitySimulation 17/17; see PROGRESS for research and source-check distinctions. All 75 named acceptance scenarios are inventoried, but only executable portable/synthetic suites have run. Do not close Apple SDK, VoiceOver/device, real sensor, thermal or child-use gates from Linux parsing. The user authorized integrating the completed work into the existing shared primary master branch after the portable checks. No force update, branch rename, deployment or production-readiness claim.


**End of Windows stage — 2026-10-09:** BlindCore 235/235 XCTests pass (Swift 6.2 container); app target not yet compiled; see the "Build-out 2026-10-09" table and MAC_HANDOFF. Earlier: 40/40 Node tests passed on current source (`artifacts/windows-stage/node-tests-20261009.tap`). Gap review against the user's goal-led companion model added E12, M12 and Q09 (74 tasks: 9 complete, 65 open). Priority order for this stage: E02 decision engine with E12/M12 (say/offer/save/drop, room familiarity, goal priority), Q09 real-data evaluation on Windows, then Mac verification. Scenarios OFF-01–08 and OUT-01 are in ASSISTANT_TEST_PLAN.

**Pause checkpoint — 2026-10-08:** [CONTINUATION_HANDOFF](research/CONTINUATION_HANDOFF.md) is the current resume point. E01/E04/E05/E08/E11, O03/O08 and V03/V05 have additional partial source for context, speech, controls, manual alignment and anonymous tracks. This does not close their acceptance gates. Latest recorded suite: 39 passed before further edits; 22 hosted native tests and expanded package tests are prepared, unrun. Checklist unchanged: 71 tasks, nine complete, 62 open. Earlier checkpoint paragraphs below are historical.

Updated: 2026-10-08. This is the single checklist source of truth. Check a task only when its stated deliverable exists; implementation tasks require their verification evidence. Tasks completed for research are not completed product features. All runtime implementation tasks below remain open.

Native implementation checkpoint: [NATIVE_MEMORY_HANDOFF](research/NATIVE_MEMORY_HANDOFF.md) records source now present for M01/M02/M04/M07/M10, E01/E04–E07/E10 and O09. These are partial implementations awaiting Swift/Apple/device verification, not completed tasks. The Mac is available, awaiting keyboard/mouse; heavy builds remain deferred.

Latest [minimum checkpoint](research/MINIMUM_ASSISTANT_HANDOFF.md): 37 Node tests and 15 context-delivery cases passed. M06 now has a GRDB attempt/completion/uncertainty journal and native wiring; verified fact association, Apple callback behavior and full arbitration remain open. Hosted native and additional package tests are prepared, not executed. Current task count remains 71 (9 complete, 62 open).

See [progress](PROGRESS.md), [next actions](TODO.md), [plan](PROJECT_PLAN.md), [engine design](research/MEMORY_AND_INFORMATION_ENGINE.md), [community maps](research/COMMUNITY_MAPS.md), [source review](research/ASSISTANT_UPSTREAM_REVIEW.md), and [test plan](research/ASSISTANT_TEST_PLAN.md).

## R — Research and durable requirements

- [x] **R01 — Record the complete product vision.** Deliverable: PROJECT_PLAN and AGENTS; include selective attention, mobility/orientation priority, rich awareness, children, memory, community sharing and user speech controls.
- [x] **R02 — Inspect candidate upstreams before choosing code.** Deliverable: pinned inventory with 18 source snapshots plus one explicitly incomplete screening; actual licenses, manifests, selected tests/workflows and known limits. No runtime-readiness claim.
- [x] **R03 — Compare memory storage and AI-memory engines.** Deliverable: local GRDB preference, optional Graphiti/Mem0/Hindsight/Letta alternatives, Git-backed option and asset/database boundaries.
- [x] **R04 — Specify the pre-speech information engine.** Deliverable: gates, urgent bypass, evidence/context versions, user controls and delivered-history semantics.
- [x] **R05 — Specify orientation and community packages.** Deliverable: occluded-door scenario, cross-device localisation, download/publish/verification/reviews and private backup separation.
- [x] **R06 — Check available Dot access.** Deliverable: no authenticated Dot tool exposed; plugin discovery yielded no Dot connection. Supported integration remains a future task; no account access claimed.
- [x] **R07 — Prepare tracked acceptance scenarios and continuity files.** Deliverable: test plan, TASKS/TODO/PROGRESS/AGENTS with Docker/resource restriction retained.
- [x] **R08 — Research selective attention and fast speech.** Deliverable: ATTENTION_AND_SPEECH with official screen-reader controls, primary adult speech/visual-attention evidence, limits and explicit danger/mobility/awareness policy. Preserve the user's adjustable words-per-time requirement separately from VoiceOver speed.

## D — Dependency selection and integration provenance

- [ ] **D01 — Establish the actual Apple toolchain and pin compatible releases.** Depends: R02; sources: GRDB, Async Algorithms, MLX manifests. Inspect existing Mac evidence without installing anything first. Exit: version/SDK compatibility matrix and chosen pins; no unreviewed head upgrade.
- [ ] **D02 — Resolve Soundscape reuse boundary.** Depends: R02; sources: callout history/state machine and iOS workflow. Trace dependencies and the documented audio race/TSan exclusion. Exit: small reuse/adaptation inventory with retained MIT notices; no wholesale unsafe audio-engine transplant.
- [ ] **D03 — Close source, transitive and model/data licensing gaps.** Depends: R02; source: existing LICENSE_REVIEW plus pinned notices. Exit: exact selected components cleared/documented; unresolved InsightFace weights and firmware notices stay excluded from distribution.
- [x] **D04 — Establish a reproducible source baseline.** Completed: 95 hashed source files saved before adapter changes in `artifacts/assistant-baselines/20261008-184236/BASELINE_MANIFEST.json`. Restore only individually reviewed files and handle newly added files separately; no Git rollback or directory replacement assumed. See PROGRESS.

## M — Local memory foundation

- [ ] **M01 — Add the GRDB persistence adapter.** Depends: D01,D03,D04; upstream: GRDB. Proposed integration: separate persistence target or iOS adapter, keeping portable BlindCore independent of Apple-only requirements. Exit: migration/transaction/reopen/error tests and protected file layout.
- [ ] **M02 — Store explicit user preferences and communication settings.** Depends: M01. Separate detail, words-per-time budget, frequency, interests, automatic mode and quiet state. Exit: edit/restart/Arabic-English/clear flows; no reading or changing VoiceOver speed.
- [ ] **M03 — Store timestamped facts, episodes and corrections.** Depends: M01; reference: Graphiti temporal fields. Exit: provenance, valid/recorded times, supersession, profile isolation and live-versus-historical retrieval cases pass.
- [ ] **M04 — Persist outing, objective and return context.** Depends: M03. Record entrance, companions, visited landmarks, goal changes and suspended tasks. Exit: change shopping to dining without losing return intent; restart never restores an old live pose as current.
- [ ] **M05 — Add people and place registries.** Depends: M01,M03. Reuse existing place assets; model family relationships only from user input. Exit: stable IDs, consent/enrollment metadata, duplicate names and deletion work; no face recogniser claimed yet.
- [ ] **M06 — Add a delivered-information ledger.** Depends: M01,D02. Track attempted/completed/interrupted utterances and source revisions. Exit: an interrupted or dropped statement is not silently treated as heard.
- [ ] **M07 — Migrate existing Places/Journeys without data loss.** Depends: M01,M05. Exit: idempotent migration, recovery from partial asset writes and preservation of existing originals until verified.
- [ ] **M08 — Implement review, correction, export and complete deletion.** Depends: M02–M07. Exit: database/index/assets and any optional export records handled; tokens remain in Keychain; WAL-safe snapshot export and understandable retention controls.

- [ ] **M09 — Learn revisable attention preferences from requests.** Depends: M02,M03,M08. Record repeated requests/corrections as sourced, scoped hints with recency and user review/disable/delete controls. Explicit current requests override habits; a one-off question or silence is not a permanent preference. Exit: repeat-interest, correction, changed-context, reject-suggestion and deletion fixtures; no inferred sensitive traits or capability labels.

- [ ] **M10 — Add editable room drafts and revision-bound approvals.** Depends: M01,M03,M08. User can type room information or request an AI draft; show exact old/new change, source and unresolved gaps; user can edit/approve/reject. Commit only the approved room/base revision, preserve history/undo, reject stale/cross-room/replayed approvals, and separate semantic labels from measured geometry. Existing room-type Confirm button is only a partial precedent. Model-generated approval flags cannot authorize writes.

- [ ] **M11 — Remember selected objects and answer last-seen queries.** Depends: M03,M05,M08,V03. Reuse GRDB and established observation/tracking sources. Explicit save/review/correction/delete; retain observation time, source, place/frame and uncertainty separately from current perception. No silent permanent recording or claim that an occluded item departed. Exit: SOL-03 plus restart, moved object, duplicate object identity, expired record and deletion; a current confirmation requires fresh evidence.

- [ ] **M12 — Track room familiarity and routine context.** Depends: M03,M09. Per room: visits, last visit, described-before, user-confirmed identity (a confirmed name is not geometry or clearance). Routines (time of day + place + repeated request) are reviewable, removable hints that may produce at most one offer; never inferred sensitive traits. Exit: new versus familiar room, restart, wrong-home, disable/delete fixtures supporting OFF-01/02/07.

Latest source progress for M02: explicit, removable interest/shopping/food/description preferences persist through GRDB and are passed to native context and local evidence selection. Save errors are visible and preference changes cancel pending answers. M09 inferred learning is not implemented. New tests are prepared, not run; M02 remains open.

## E — Information engine and hands-free speech

- [ ] **E01 — Build a versioned situation snapshot adapter.** Depends: M03,M04; upstream: current ARKit/motion/map sources. Exit: model input binds user/body/camera pose, room/venue/floor hierarchy, connected rooms/exits, relevant people, goals/action status, preferences, delivered history and timestamped observations to coherent source revisions; missing fields stay unknown. Follow the situation contract in MEMORY_AND_INFORMATION_ENGINE.
- [ ] **E02 — Connect candidate producers to the eight gates.** Depends: E01,M02,M06,D02. Reuse inspected callout/event primitives. Exit: say/defer/coalesce/discard with explainable reasons; no custom perception/planning algorithms.
- [ ] **E03 — Preserve an independent immediate danger path.** Depends: E02 integration contract only; no runtime dependency on its gates. Reuse existing detector/policy. Exit: danger preempts during slow memory/model/network operations and bypasses ordinary budgets/preferences, while existing detector validity remains effective; due mobility is next, rich awareness after it.
- [ ] **E04 — Implement bounded, completion-aware speech arbitration.** Depends: E02,E03,D02; upstream: Soundscape lifecycle and UIKit announcements. Exit: ordinary speech does not continually interrupt itself; stale pending updates are replaced; missing callbacks cannot deadlock speech.
- [ ] **E05 — Enable automatic VoiceOver awareness with user controls.** Depends: E04. Touchpoints: Feedback, NavigationModel, DashboardView. Exit: no touch required for enabled updates, accessibility focus remains usable, pause/repeat/resume work.
- [ ] **E06 — Decouple detail from movement and frequency end to end.** Depends: M02,E04. Touchpoints: AttentionPolicy, SceneContext, local selection limit, server prompt policy. Exit: detailed mode stays detailed while moving when fresh content can be delivered; frequency is independent.
- [ ] **E07 — Revalidate after generation and before speech.** Depends: E01,E04. Exit: rotation, position/track loss, map update or goal change invalidate affected claims; useful nonspatial description remains possible.
- [ ] **E08 — Add natural controls and respectful child/adult phrasing.** Depends: E05,E06,E10. Reuse voice input/platform accessibility. Exit: quiet, changes-only, repeat, more/less detail, more/less information per minute and interest focus work with accessible alternatives; no assumed always-on microphone capability.
- [ ] **E09 — Deliver the first contextual awareness and discovery experience in M2.** Depends: R08,E02,E05,E06,E07,E10,V02. Exit: meaningful room description, relevant change, observed choices, follow-up and correction preserve context and user agency; INF-01–INF-04 pass. Do not defer this until complete routing/family recognition. Avoid starving questions or due navigation; companion presence does not disable danger handling or prove clearance.
- [ ] **E10 — Enforce a user-adjustable words-per-time budget.** Depends: M02,E04,E06; reuse platform word segmentation and inspected clock/event primitives. Exit: reserve before generation, verify complete text length, account for pending/dispatched words, rolling window and live setting changes; no fixed-window burst, oversized response or interrupted speech evades accounting. Danger bypasses budget, necessary mobility remains deliverable, and Arabic/English cases pass. A prompt instruction alone is insufficient.

Implementation progress: relay context and per-request word limits are tested. Native goal/dialogue and historical inventory dispatch, GRDB persistence, rolling word accounting, goal/map revalidation and automatic VoiceOver source now exist; Apple verification remains pending. Full pose/venue/floor fusion, delivered-history tracking and general speech arbitration remain open. No source-only change closes a task.

- [ ] **E11 — Configure delivery by ordinary information category.** Depends: M02,E02,E04,E08. Add automatic/on-request/muted choices for social, interests, décor and other ordinary categories with changes-only/explore/quiet controls. Preserve the independent word/frequency controls and current question override. No automatic expertise label, sensor-hazard suppression or assumption of a companion's coverage. Exit: SOL-06 and English/Arabic restart, mode change during speech and explicit request for a muted category.

- [ ] **E12 — Goal-led proactive offers and short confirmations.** Depends: E02,E04,E08,M03,M12. Familiar maps and memory act as silent background knowledge for goals; descriptions are for new places, waiting time or requests. First-visit room description defaults to a brief offer (setting: offer/automatic/never); later visits describe only on request or relevant change. Offers include room identity questions when uncertain, outfit help, remembered-item directions. A single yes/no via gesture or a short listen window after the offer; silence means no; declined offers are not repeated in that context and become reviewable M09 hints. Goal-relevant information (seat, door, item, route obstacle) precedes description. Hazards and necessary mobility never wait for an offer. Exit: OFF-01–OFF-08 and the decision steps of OUT-01 in ASSISTANT_TEST_PLAN.

## O — Orientation, maps and route continuity

- [ ] **O01 — Define and validate the portable place package.** Depends: R05,D03. Reuse IMDF/GeoJSON/USDZ conventions and proven archive/schema tooling. Exit: schema, units, transforms, floors, doors, assets, anchors, coverage and provenance contract; current point-only importer not misrepresented.
- [ ] **O02 — Establish cross-device saved-map localisation.** Depends: O01,D01; upstream: ARKit/RTAB-Map, NavCog as reference only. Exit: second-phone/new-day entry aligns to a known frame; uncertain/ambiguous alignment has bounded recovery and no invented pose.
- [ ] **O03 — Maintain person-facing orientation.** Depends: O02,E01. Exit: distinguish phone heading from body/known mounting, support explicit calibration and turns; stale or unknown heading is represented accurately.
- [ ] **O04 — Find an occluded or out-of-view mapped doorway.** Depends: O02,O03. Exit: room location and a supported route can be explained without first pointing the camera at the door; a blocking cupboard changes the route, not the stored door location.
- [ ] **O05 — Connect rooms, floors and destinations.** Depends: O01,O02; upstream: existing map graph/RTAB-Map/Recast adapter. Exit: verified door connections and floor transitions, correctly named alternatives and a recorded entry/exit context.
- [ ] **O06 — Integrate measured geometry and live obstacle changes.** Depends: O05,D03; upstream: Recast/Detour and current sensors. Exit: no unknown ground treated as clearance, body/head envelope applied, changed paths invalidate affected route cues.
- [ ] **O07 — Complete outing and return behavior.** Depends: O04–O06,M04,E07. Exit: home/mall itinerary and revised return route; lost tracking, blocked entrance and floor changes do not produce guessed retracing.

- [ ] **O08 — Carry conversational destinations through intermediate rooms.** Depends: M04,E01,E07,O03,O05,O06. Distinguish room entry from target arrival; retain bathroom/computer/bed goals and support interruption, correction and one short clarification when ambiguous. Reuse the established navigation adapter for measured route distance and fresh relative directions. User-selectable units; optional personal calibrated step estimates with uncertainty, never average-stride guesses. Exit: CON-01–CON-06 including goal change while generating and unknown body heading, then device verification.

- [ ] **O09 — Recover place identity after restart and ambiguity.** Depends: O01–O03,M05,E08. Reuse ARKit/RTAB-Map saved-map matching; reset live pose/current room/queued directions per session. Distinguish home/relative/neighbor and venue/floor/room hierarchy. No GPS-only, walked-distance-only or appearance-only certainty. Ask specific clarification or offer stationary evidence gathering; no match is unresolved, not automatically new. Exit: independently sourced maps, restart elsewhere, competing matches, unknown room, tracking loss, doorway alternatives and physical device evidence; no supplied-ID shortcut.

Latest O01/C01–C04 preparation: `PlacePackage`, public-release client, protected offline library, accessible preview/import/export and pinned route selection are now source. The OAS fixture retains authored room/door references without supplying location or a route. Mesh/anchor packaging, physical alignment, vicinity discovery, publishing and review authentication remain unfinished. See [continuation handoff](research/COMMUNITY_IMPLEMENTATION_HANDOFF.md); all new tests are deferred.

## V — Visual, social and interest-based understanding

- [ ] **V01 — Select the local multimodal provider through a thin adapter.** Depends: D01,D03; sources: Apple frameworks and MLX Swift LM. Exit: capability/language/resource matrix on the target device; no model training or new inference runtime.
- [ ] **V02 — Connect rich observations to engine evidence in M2.** Depends: V01,E01. Exit: clothing, room appearance, art, signs, animals, supported relationships and activity have source/time/uncertainty; descriptions offer understanding beyond object labels and do not manufacture geometry. Valid nonspatial information remains available without a working route.
- [ ] **V03 — Select and integrate maintained person/object tracking.** Depends: D03,V02. Apple Vision first; ByteTrack is an older reference only. Exit: occlusion, crossing tracks and reacquisition handled; observed approach separated from inferred intent.
- [ ] **V04 — Select a legally usable on-device family-identity model.** Depends: D03,M05,V03. Exit: model provenance/license, enrollment, false matches/unknown people and deletion tested. InsightFace weights are not approved merely because code is MIT.
- [ ] **V05 — Connect social events to memory and speech.** Depends: V03,E02,M05; named recognition additionally requires V04. Exit: anonymous arrival/approach/seat-change can work before family recognition; use current/last-seen wording, lost sight does not imply departed, bios are user supplied.
- [ ] **V06 — Add shopping/dining/personal-interest assistance.** Depends: V02,E09,M04; route execution additionally requires O07. Exit: distinguish map-listed shops from observed signs; read/describe/compare menus and clothing; offer relevant fish tanks/colors/décor and alternatives; communicate observed occupancy with coverage limits; preserve changed goals/companions/return intent. Information and choice assistance do not wait for full outing navigation. DIN-03–DIN-06 cover the dining information experience.

- [ ] **V07 — Add camera framing and exact-reading recovery.** Depends: V01,V02,E08. Reuse Apple Vision OCR/region evidence and documented capture APIs. Distinguish cropping, unreadable text, coverage gaps and localization uncertainty; never complete missing labels/prices/ingredients from plausibility. Ask for one supported stationary camera adjustment without guessed direction or exploratory walking. Exit: SOL-01/02 with crop/blur/glare, unsupported adjustment, complete versus partial label, and harmless control-panel fixtures.
- [ ] **V08 — Detect relevant changes against comparable observations.** Depends: M03,M05,V03,E01,E07. Reuse selected tracking/mapping source revisions; compare stable layout, movable objects and transient activity separately. Require sufficient common coverage and aligned frame before a moved/new/unchanged claim. Lighting/viewpoint/occlusion or missing observations do not prove a change or no change. No automatic map overwrite. Exit: SOL-04/05, repeated visits, wrong home, tracking loss, changed lighting and user correction.

Latest V01/V02 preparation: `LocalImageAssistant` wraps Apple's documented image Attachment API behind the explicitly selected iOS 27 SDK flag. Vision/evidence fallback remains available. Existing speech validity/word gates apply; no image inference or Apple build has run. Actual capabilities and reliability remain unknown until device evaluation.

## C — Community maps and optional GitHub backup

- [ ] **C01 — Implement local import, preview and offline download cache.** Depends: O01,M05. Exit: versioned package validation, interrupted download recovery, quota control and rollback without partial activation.
- [ ] **C02 — Add an accessible community venue catalog.** Depends: C01. Reuse GitHub public releases/assets as an initial transport, with provider-neutral catalog records. Exit: name/vicinity search, spoken coverage/review/size, no GitHub account needed to download public maps.
- [ ] **C03 — Add a contributor author/review/export workflow.** Depends: O01,C01,D03. Exit: private/public preview and explicit publish action; personal people/history assets never slip into public place bundles.
- [ ] **C04 — Add ratings, scoped verification and change reports.** Depends: C02,C03. Exit: per-revision reviewer/date/scope, usefulness stars distinct from tested alignment/route claims, stale-map notices and abuse/report handling.
- [ ] **C05 — Add repository publishing and update/withdrawal.** Depends: C03,C04. Reuse supported GitHub authentication and Releases APIs. Exit: least needed permissions, revoked auth handling, versioned artifacts, pinned active routes and withdrawal/rollback flows. No automatic personal-account creation.
- [ ] **C06 — Add optional private GitHub memory backup and restore.** Depends: M08,D03. Reuse established encryption/Keychain/storage APIs. Exit: encrypted snapshot/key recovery design, offline operation, explicit readable export option, restore and revision-history deletion behavior communicated.
- [ ] **C07 — Add user-reviewed AI memory maintenance.** Depends: M08,C06. Reference: Letta MemFS or one evaluated backend. Exit: proposed deduplication/summaries preserve sources, corrections and rollback; no silent changes to identity, maps or user-stated preferences.

## A — Optional accounts and Dot

- [ ] **A01 — Integrate supported account access and verify app eligibility.** Depends: R06. Official ChatGPT plan-usage flow and account-specific model discovery verified in MODEL_PROVIDERS; native sign-in/session lifecycle and eligibility still untested. Exit: supported auth flow/scopes, model listing, streaming completion, expiry/revocation/quota handling; no internal cookies or assumption of inherited Dot memory. Strong models remain available when the account permits.
- [ ] **A02 — Expose narrowly scoped memory/place tools.** Depends: A01,M08,O01. Reuse official plugin/MCP/auth SDKs. Exit: explicit per-user permissions, no arbitrary file access, revoked/expired authorization tested.
- [ ] **A03 — Add computer/Dot room-enhancement jobs.** Depends: A02,C01; reuse Open3D/established processing tools where appropriate. Exit: observed versus generated fields, source revision, bounded upload, progress/cancel, validated import and no replacement of measured clearance by generated decoration.
- [ ] **A04 — Evaluate at most one optional semantic memory backend.** Depends: M03,M08. Compare Graphiti/Mem0/Hindsight/Letta using the same fixtures and actual costs/latencies. Exit: recorded win or justified decision to remain local; no mandatory cloud for orientation.
- [ ] **A05 — Connect authorized reservations to outing context.** Depends: A01,M04,V06; route execution additionally requires O07. First verify an actual supported Dot/provider reservation tool and reuse its documented integration; no invented endpoint. Exit: respect the user's venue/branch/time/party/action scope, distinguish requested/pending/confirmed/failed/unknown states, prevent duplicate retries, preserve confirmation/status/cancellation reference and update the outing without losing return context. DIN-01/DIN-02/DIN-07 pass; no booking is authorized merely by account connection.

## Q — Verification and child-facing readiness

- [ ] **Q01 — Turn acceptance scenarios into executable fixtures.** Depends: selected interfaces in M/E/O. Reuse upstream test harnesses; add only integration/domain cases. Exit: deterministic fake clock, source/pose revisions, speech completion simulation; placeholders never reported as tests.
- [ ] **Q02 — Run portable and relevant upstream checks after resource go-ahead.** Depends: Q01 and user's later authorization. Exit: logs, exact revisions, failures and skipped platform checks recorded; low concurrency, no automatic Docker startup.
- [ ] **Q03 — Build and audit the real iOS app.** Depends: Q02,D01. Exit: Apple SDK typecheck, actual VoiceOver/Arabic-English/accessibility operation; Swift syntax checks are insufficient.
- [ ] **Q04 — Complete bench and controlled adult trials.** Depends: Q03,O07. Exit: recorded sensor faults, pose failures, occluded exits, missed/late/false alerts, recovery, and stopping rules; children are not initial hazard testers.
- [ ] **Q05 — Measure sustained operation and failure modes.** Depends: Q03. Exit: device/runtime/memory/heat/battery measurements, lock/background/camera loss and optional-provider outages; no 24-hour claim without evidence.

Q05 implementation preparation: [iPhone performance plan](research/IPHONE_PERFORMANCE_PLAN.md) records the user's A20 Pro acceleration requirement, verified Apple hardware sources, local-framework reuse and simultaneous-load benchmark matrix. Native timing signposts are added; no Apple build or benchmark has run. Account models remain an option; phone capability does not impose a small-model ceiling.
- [ ] **Q06 — Prepare and review the supervised child protocol.** Depends: Q04,Q05. Intended users include very young children. Guardian involvement and qualified orientation-and-mobility review; controlled environment, immediate adult intervention, age-appropriate instructions, opt-out and data minimisation. Exit: documented review and explicit limited trial scope.
- [ ] **Q07 — Evaluate usefulness and information control with intended users.** Depends: Q06 for children. Exit: task success, discoveries, comprehension, repetition burden, pace/detail preferences and distress/stop observations inform changes; no extrapolation from adult results alone. Include SOL-07/08: requested information supplied/missed, unnecessary interruptions, follow-up effort, room-connection understanding, useful decisions and audibility of environmental cues. Compare user-selected automatic/change-triggered/on-request modes; record hazard results separately. Neither fewer words nor more object labels alone means better assistance.
- [ ] **Q08 — Review release and independent-use claims.** Depends: Q02–Q07,D03. Exit: actual demonstrated capabilities and limitations documented; upstream tests, stars and nice demos never substituted for system evidence.

- [ ] **Q09 — Windows real-data feasibility evaluation.** Depends: Q01 interfaces; authorized 2026-10-09. Public iPhone/iPad LiDAR sequences (frames, depth, recorded ARKit poses) and licensed photos through the actual relay and model. Score description accuracy against frames/annotations, orientation against recorded poses, changes-only narration across a sequence, word budget, offer behaviour and latency; reviewer checks answers against the images. Exit: report with dataset source/license/revision and limits stated (recorded poses are not live localization; the cloud model is not the on-device model).

## FR — Independent Fable review follow-ups (2026-10-09)

Full findings and status: [FABLE_REVIEW_2026-10-09](research/FABLE_REVIEW_2026-10-09.md). Each item also maps to its owning task above; close the FR line when its fix and test land.

- [ ] **FR-01** Test compile fix (mutating call on a temporary). **FR-07** offer window from spoken time; withdraw without decline on room change/interruption. **FR-08** doorway flicker must not inflate visits; last-visit date. **FR-18** silence does not feed hints; document ordering/caller interrupt; prune delivered. **FR-19** missing engine scenarios.
- [ ] **FR-02** Engine wired into the live loop; timer narration retired. **FR-03** user confirmation/relocalised place as `established` for familiarity only. **FR-04** hands-free yes/no answer channel. **FR-06** single word ledger with release.
- [ ] **FR-05** Coarse change detection (people count, sign text, obstacle in usual path). **FR-12** home world map with room polygons and bounded recovery. **FR-13** body heading from walking direction plus mount-slip check. **FR-14** local vs cloud on the same Q09 frames. **FR-15** trigger-based model calls. **FR-16** speaking priority from Feedback; unknown outcome not delivered. **FR-17** foreground/Guided Access/battery plan.
- [ ] **FR-09** Git decision from the user. **FR-10** archive historical tracker layers; reconcile counts. **FR-11** optional Windows Swift toolchain (needs user go-ahead).

## E13 — Spatial rule enforcement (user rule, 2026-10-09)

- [ ] **E13 — Positions, directions, distances and routes only from sensors/measured maps.** Code renders spatial facts; every model answer (cloud and on-device) passes a shared spatial-claim check before speech and is not spoken if it contains person-relative direction, distance, step count or movement instruction. One shared fixture tested by Node and Swift; a static test confirms the check sits on every model-to-speech path; a Claude Code hook re-runs that test after edits to the guarded files. Exit: fixture cases pass in both languages; relay retries once then refuses; app drops the answer and still speaks code-rendered facts.

## E14 — Reaction-time budget (user, 2026-10-09)

The user's framing: like reaction time in a game, every second of delay is time the person no longer has to react; lag in guidance or information is itself a safety issue, and children lose interest quickly.

- [ ] **E14 — Meet latency targets per tier and remove avoidable delay.** Targets: hazards (drop, stairs, obstacle in path, approaching person) under 100 ms from sensors with no model, gate, network or budget on the path (already the design; measure on device). Mobility cues and code-rendered sensor facts under 300 ms. A requested location ("where is the fork / lamp") answered first from on-device detection plus LiDAR depth by code in under 1 s, with richer model detail following. Model descriptions stream and speak the first sentence as soon as it passes the per-sentence spatial check (target under 1.5 s), instead of waiting for the whole answer. Measured 2026-10-09 (`artifacts/windows-stage/q09/latency.json`): network handshake ~0.3 s; gpt-6.1-sol 3.9–4.9 s model time; gpt-5.4-mini 0.85–1.0 s; low image detail saves 0.3–0.6 s; spatial check 8.5 µs; prompt input ~2,900 tokens per call. Work: shorten the instruction prompt (~400 tokens) for on-device prefill; per-sentence filtering instead of whole-answer retries on the hot path; keep-alive connection; low image detail; fast models by default with the large model on request; relay rate limit only for cost control, never on the phone's live path; measure Apple Foundation Models (official 2024: ~30 tok/s, 0.6 ms/prompt token on iPhone 15 Pro; third-party estimate 70–86 tok/s on iPhone 17 Pro) on the iPhone 18 Pro Max; Claude Haiku/Sonnet speed needs an Anthropic API key. Exit: per-tier latency logged on device with signposts; hazard and requested-location targets met.

## Build-out 2026-10-09 — source written, verification on the Mac

The user asked for implementation to be finished before the Mac so Mac time goes to design, testing and fixing. Everything below is source only (no Swift toolchain on Windows); each owning task stays unchecked until compiled and verified. Node suite 54/54 at this point.

| Area | Source | Owning tasks |
| --- | --- | --- |
| Goal-led engine wired into the live loop; offers, spoken/tapped yes-no, short listen window after a question | `CompanionAttention.swift`, `NavigationModel.swift`, `VoiceInput.swift`, `DashboardView.swift` | E02, E12, FR-02, FR-04 |
| Room recognition from agreeing clues: map match, saved pictures per facing direction (Vision feature prints, pinned revision), object cut-out prints, part-by-part check of borderline matches (Vision homographic registration), furniture labels, movement through mapped doors, user answer; asks when unsure or for look-alike rooms | `RoomRecognizer.swift`, `RoomRecall.swift`, `NavigationModel.swift` | O09, M12, FR-03, FR-12 |
| Coarse phone location saved with each place; start tries the nearest saved place | `PlaceStore.swift`, `NavigationModel.swift` | O09 |
| Body heading from walking direction; declared-mount offset; mount-slip notice | `BodyHeading.swift`, `IndoorNavigator.swift` | O03, FR-13 |
| Orientation from matched furniture (2D rigid fit, fallback/cross-check to ARKit) | `LandmarkPose.swift` (not yet wired: needs object positions from a detector) | O02, O04 |
| Change detection in familiar rooms (newcomers, no longer in view, new signs) | `SceneChangeDetector.swift` | V08, FR-05 |
| Remembered items: "remember my X here", "where is my X", "forget my X"; guided "this is my cup" saving several views + marks + on-phone description; "is this my cup?"; identity by image comparison with look-alike margin, never by the model | `ItemMemory.swift`, `ItemAppearanceMatch.swift`, `ItemAppearance.swift` | M11 |
| Sensor-measured phrases (confident) and instant "where is the X" via Vision text/people boxes (+ optional detector) and LiDAR depth | `SpatialFacts.swift`, `LocateCommand.swift`, `VisionService.swift`, `DepthSampler.swift` | E13, E14 |
| Consent-based people registry (self/guardian consent, delete any time, anonymous unless enrolled and clearly matched) | `PeopleRegistry.swift`; face embedding model not yet selected (OpenCV Zoo SFace has the clearest weights licence; training-data question open); not wired | V04, V05 |
| Privacy: no picture-sending path in the app build (developer flag only); public place library only on GitHub | `NavigationModel.swift`, `DashboardView.swift`, `tools/test/privacy-rule.test.mjs` | C03, C05, C06 (withdrawn) |
| Shared on-device guide prompt and compact situation | `GuidePrompt.swift`, `Resources/guide-prompt.txt`, `LocalImageAssistant.swift` | V01, E14 |

Calibration on the iPhone: feature-print distance scale, registration limits, item/person thresholds, settle times. Object-matching upgrades researched (DINOv2-S, ALIKED+LightGlue, OpenCV) need a model download go-ahead; see PROGRESS.

## Later features requested by the user (2026-10-09) — all on-device, free, offline

- [ ] **V09 — Colour.** Requested centre-object appearance is implemented with local foreground masking, code-based Lab samples, qualified speech and explicit near-neutral uncertainty. No model colour guesses or certified-white/school-acceptance claims. Remaining: Apple build/real-fabric validation under varied lighting and two-item comparison. See research/CLOTHING_COLOR.md.
- [ ] **V10 — Lights on/off.** ARKit light estimate (ambient intensity) plus brightness by region: "the lights are off", "the lamp on your left is on". Exit: on/off and lamp cases in real rooms.
- [ ] **V11 — Money.** Current direction is no-new-training Saudi reference-image matching, never OCR digits/colour/LLM guessing. Actual OpenCV matching, geometric competition, full-frame proposal veto and voice gates are implemented; no validated reference pack is selected, so the app reports unavailable. The previous training route is dormant. Remaining: audited eight-denomination/side/issue/material coverage, independent whole-frame costly-confusion and unknown/multiple-note tests, native parity and adult phone trials. No summing/authenticity claim. See research/CURRENCY_REFERENCE_MATCHING.md.
- [ ] **V12 — Supermarket products.** Built-in barcode detection plus label reading; product names from an offline product list on the phone (licence to check, e.g. Open Food Facts ODbL). Exit: barcode and label cases offline.
- [ ] **E15 — Voice-first quick actions (user design, 2026-10-09).** One gesture starts listening (VoiceOver Magic Tap, the iPhone Action Button, Back Tap); the person then asks in their own words — "what colour is this book?", "is the light on?", "is that my cup?", "read the document in front of me", "describe the scene", "what's this product?", "who's in front of me?" — and the app routes to the right tool. Routing: instant keyword rules in code first; only unclear wording goes to the free built-in model's tool selection (Foundation Models tool calling), offline. Tools keep their own rules: colour from pixels, identity by image comparison, distances from LiDAR, people described anonymously unless the later consent design says otherwise. Exit: each request answered in one step with VoiceOver on; English and Arabic phrasings; unclear requests get one short clarifying question.

## Completion rule

Every implementation completion entry must name the adapted upstream/API, exact source/release, changed files, new integration behavior, test command/result/log, and remaining device limitations. Update PROGRESS and TODO at the same time. If testing is deferred, leave the implementation task unchecked and say "implemented, verification pending" in PROGRESS.

## Mac transfer — 2026-10-22

- [x] Package and upload all available Windows scenarios, room fixtures, pictures, recorded LiDAR/depth, maps, replay data, reports, source snapshot and Git history for private Mac testing; verify archive and uploaded SHA-256 digests. [Transfer release](https://github.com/mischa23v/blind/releases/tag/mac-transfer-20261022). Transfer integrity only; no iOS/device task closed.
- [ ] Verify download/extraction on the Mac mini and scan the user's actual rooms on the iPhone; recorded source places do not establish live home alignment.

- [x] Transfer the user-supplied 7sys44td9c-1.zip unchanged to private GitHub assets in four parts, with original/part checksums and Mac instructions. [Download](https://github.com/mischa23v/blind/releases/tag/currency-transfer-20261022). Transfer only; V11 implementation/training/device gates stay open.

- [x] Upload hello.zip privately and record all eleven user-listed Seeing AI/related code repositories with pinned evidence and licence limits. [References](research/SEEING_AI_CODE_REFERENCES.md). Research/transfer only; D03/V11 integration and device checks remain open.


## Semantic context and read-only capability checkpoint
- Implemented typed specialized reads through the existing local tool runtime, mandatory stable profile/task context, source-attributed action progress, bounded memory replay and native batch-test entry point. See research/SEMANTIC_TOOLS_AND_CONTEXT.md.
- Imported preserved scenario inputs, hidden rubrics, raw results and native checklist under tests/scenarios/companion. Integrity validation is not behavioral/model success; first-pass usefulness misses remain visible.
- Pending: actual Apple SDK build, native model selection/latency, VoiceOver/device sensor behavior and open-ended held-out adaptation. Do not describe this source checkpoint as all features validated.

## Independent floor-routing review - 2026-10-26

- [x] Review 7506ad9 against 57fdf25 using exact packet/source identities, three original-depth reprojections and saved-array/pose/floor-row checks. Evidence: research/mapping-audit-20261026/README.md and REVIEW_7506AD9_CHECKS.json. Diagnostic verification only.
- [ ] Implement and validate local observed-support classification with low objects, steps and unknown support retained; distinguish pose/depth inconsistency using held-out surface checks.
- [ ] Complete actual movement evaluation with independently scored outcomes. This review ran zero movement episodes; existing unfinished approach tests are not marked complete.

- [x] Execute and preserve the first local-support implementation experiment: all 294 frames processed, 13 adapter fixtures passed, 100 frozen admission attempts executed. Result failed: 100 invalid starts, zero motion. Evidence: research/koivu-local-support-attempt/README.md. This does not close the local-support or movement tasks above.
- [x] Run and preserve three fixed-scale non-floor Open3D ICP diagnostics. Poor initial overlap and unreliable corrections; no transforms adopted, no pose-quality claim.

