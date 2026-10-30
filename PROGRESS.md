## Actual navigation research checkpoint — 2026-10-30 01:16 UTC

This checkpoint is research/evidence only. App source remains `c210ca822ec4fdc339f808af58bc5b057fd98788`; main and live guidance are unchanged. Earlier dated entries remain historical evidence.

- Conference: all seven fixed route proposals were compared before and after released GEOS simplification. The complete body result is published at `8cd2459`. Authored events fell from 13,704 to 7,470, but nominal overlaps remain on five of seven routes and margin overlaps on all seven. Complete nominal triangle bounds remain near the authored foot plane (about -38 to +40 mm); margin contacts include higher geometry. Reduced events are not a safety/arrival improvement. See [complete result](research/conference-simplified-body-result-20261030/README.md).
- Coffee: the new centered route retains zero nominal modeled-body contacts but margin contacts and a ground-follow refusal remain. This is not a demonstrated usable journey. Mesh-to-camera calibration is still missing; the official dataset explicitly says its Polycam mesh is not aligned with camera poses.
- Released OctoMap read-only ray adapter: fresh build and all 38 controls passed (16 original, 22 new). The preceding compile failure is preserved. These are authored adapter controls. The subsequent frozen real-data run at source `a40cbd0` completed with the baseline map unchanged, but both held-out camera origins were unknown: all 18,904 valid rays were unscored and no depth residuals were obtained. Endpoint coverage is diagnostic evidence; depth accuracy was not tested/passed. See [ray controls](research/coffee-readonly-ray-controls-result-20261030/README.md) and retained held-out execution evidence.
- Released Rapier controller: the complete analytic comparison ran all 72 wrapper checks / 108 rows / 104 controller calls. Two unchanged assertions failed, both on the margin-envelope 1 cm down-step; the aggregate remains failed. Both mesh-flag arms gave identical movement/grounded outputs across all 54 paired probes. This is not room-navigation accuracy. See [complete analytic result](research/rapier-analytic-collectall-result-20261030/README.md).

Next are source-bound real-room controller diagnostics and diagnosis of held-out observation coverage, alongside the [proposed multi-representation map design](research/multi-representation-map-plan-20261030/README.md). No new floor exemption, obstacle removal, body/margin reduction, applied controller correction or physical authority follows. Original failed attempts remain retained. Apple c210ca8 hosted: 283 passed / 12 failed / 2 skipped; UI: 14 passed / 1 failed / 3 skipped. No device or child readiness claim.

---

## Actual navigation research checkpoints — 2026-10-29 22:42 UTC

Published and verified on codex/recovery-hazard-order-20261027 through f4683841e164ba54a92d22c42f990705ddfb3a5d. Main unchanged.

- Joint native/manual ranking actual attempt003: 35 controls plus comparison completed, 5.77654 CPU seconds / 5.790637 wall / 121,171,968 observed RSS. Manual extra residual 3.85→129.58mm, route 7.238872→7.502607m before connectors. Native-wall p10 proxy decreased. No uniformly improved physical-clearance claim.
- OctoMap actual rebuild from published source e996371: 12.197197 CPU seconds; 16 original controls passed. Corrected Stage B three frames completed. First attempt failed before insertion on overly strict 1e-12 default-probability check; preserved. The minimal 1e-7 guard matches original controls and float log-odds representation, changes no geometry.
- New native signed 15-degree ground-policy wrapper compiled and 67 controls passed; 20-path comparison terminated at 120.075956 CPU seconds under fixed 120-second budget. This is incomplete, not 20 route failures or 20 successful trials. Partial evidence is under review.
- Original Koivu archive recovered from official MuSHRoom public CC-BY4.0 source and matches expected SHA 68735cfa0758e1288a006c30dc8b95ffb4caa3392bc9c68c0c3ea6c111966518. No new conference movement result yet.

App source remains c210ca8; all later commits here are research/evidence, not new device-validated navigation. Raw private captures never uploaded. Two public-data diagnostic archives await explicit upload clarification after an automated upload block; do not claim those archives pushed.

---

## Actual Stage C003 passed; Stage B native pending — 2026-10-29 15:23 UTC

[Apple run 40895152519](https://github.com/mischa23v/blind/actions/runs/40895152519), exact source `9a3aeee70c235c33954760388770809478ca9f79`: 31 native commands completed, 15 observer groups reported passed, all 50 legacy/strict controls reproduced, all 25 candidate criteria met. **8 requests completed without modeled body or margin contacts: 6 retained corridors + 2 corrected corners; 17 requests remain refused/unsuccessful.** The long-hall fixture is approximately 5.85 m including connectors. Fixture labels/profile duplicates are not independent rooms, full bed/table loops or 100 movement trials. Attempts 001/002 remain failed historical attempts.

The bounded flat-single-layer seed-radius veto excludes cells after unchanged stock erosion; it does not relax body dimensions, safety margins or the collision oracle. The result is not continuous physical-clearance/full-support proof. No live app activation or navigation authority follows.

Stage B policy/wrapper and hosted tests are published at `4b51e4273817bd7fa1d8830041bafdf302c11aee`; [native run 40900894239](https://github.com/mischa23v/blind/actions/runs/40900894239) is pending at this checkpoint. The next gate is the exact 8 selected Apple methods, then separately reviewed qualified caller wiring and real temporal sensor/full-body/support/current-hazard validation. Stock remains default. All older dated entries below remain preserved.

---

## Geometry evidence checkpoint — 2026-10-28 17:40 UTC

The independent Apple comparison confirms a representation-validation defect; fresh Open3D reconstruction and held-out reference scoring are complete, with substantial residual tails. Neither establishes navigation readiness. See the [current geometry-first status and open acceptance](research/geometry-tracker-checkpoint-20261028/STATUS.md). The older dated entries below remain unchanged historical evidence.

---

## Apple route failures isolated before movement — 2026-10-28 13:25 UTC

Rechecked published commit `dc32a9bad9a75566f27924fb9f7aa8fe50a46e95` and native run 40677832625. Hosted tests: 218 total, 198 passed, 18 failed, 2 skipped. The exact collected reports contain 12 baseline and 6 width-28 route outcomes plus 16 supplied-pose journey stages, all `unsupported-geometry / missingMetadata`. No route was admitted by these reports. Six collision-oracle tests fail the mandatory bidirectional thin-plane backend control. Neither failure proves that the actual rooms lack space.

The adapter combines several metadata failures into one error, so current evidence cannot distinguish decoding from ModelIO node association. The collision control aborts before later controls are measured. Stage-specific diagnostics and a bounded backend control matrix are being prepared; neither is a verified repair yet. A classified-mesh test also times out at its original ten-second deadline; its cause remains unmeasured.

The previous local checkout is unavailable in the resumed environment. Published source is being restored from exact dc32a9; unpublished candidates are not claimed recovered or pushed. The full unfamiliar-place live mapping/localization/collision/guidance loop remains unfinished.

[Source-bound native evidence](research/native-path-recovery-20261028/native-run-40677832625-evidence.json).

---

## Native recorder checkpoint result — 2026-10-28 08:37 UTC

Native run 40653113122 at `26bfa69` is terminal: both builds passed; Core 1,411 executed, zero failures, one skip; Memory 51 passed. Hosted 175: 168 passed, one failed, six skipped. All fifteen RecordedRouteStore tests and all three connected-navigation bench fixtures passed; all ConnectedJourney tests passed. The remaining hosted failure is ObservedScene actual-accumulator/abandoned-completion on the source before the later `adb8fd8` completion-fence changes.

UI 18: thirteen passed, two failed, three skipped. Practice explicit End upper bound 8.086 seconds passed. The Camera audit now completes and reaches Ask; Ask then fails contrast without an identified element. A separate DescribeFocusAndStopControl test times out on an element snapshot before Stop interaction. Do not call all accessibility green or attribute the timeout to Stop. [Exact native evidence](research/native-candidate-app-integration-85/integrated/evidence/run40653113122/).

This validates the volatile recorder checkpoint, not the later private-durability or saved-frame association increments. Latest published `adb8fd8` includes those later increments and is running in existing native CI. A further reviewed DEBUG timing receipt distinguishes queue admission, worker wall time and main handoff while retaining the original 1.2-second latency assertion; it does not improve speed or change release policy. Original whole-room geometry plus same-frame historical camera overlay is still being implemented and reviewed.

---

## Published recording and camera-frame checkpoints — 2026-10-28 08:31 UTC

Verified remote head `adb8fd8f4fa16f0563bdd708635a12ba7888bcf3` on `codex/recovery-hazard-order-20261027`; draft PR remains unmerged. Checkpoints:

- `26bfa69`: reachable explicit path recorder, existing camera feed, code-owned route snapshot, canonical test membership. No snapping or fabricated map registration.
- `4cd2540`: exact-capture same-saved-frame CAMERA association receipt and loss/session fencing; Rooms entry does not require a previously saved room. This receipt is not body/support guidance authority; no geometry overlay consumer was included.
- `efdc2c1`: private incremental GRDB diagnostic persistence, bounded retention, explicit save/retry/delete and stopped/interrupted reopen. Nine SQLite checks actually passed; twelve Core, ten hosted diagnostic and seven repository tests were authored, not yet natively executed on this revision. No automatic sharing or quiet eviction.
- `adb8fd8`: actual DEBUG scene-job completion fences for functional tests, one post-release journey waiter correction, and helper-aware hazard source contracts. Original 1.2-second latency assertion remains. No speed improvement claimed.

Completed native result at `3aef695`: both builds passed; Core 1,402 executed, zero failures, one skipped; Memory 51 passed. Hosted 160: 149 passed, five failed, six skipped. All three connected-navigation bench fixtures passed. One delayed restore case and four scene tests failed. UI 18: 14 passed, one Dynamic Type failure, three skipped; practice explicit End upper bound 5.316 seconds. That revision did not contain the eager Camera layout or recorder. [Exact evidence](research/native-candidate-app-integration-85/integrated/evidence/run40652145912/).

At this checkpoint `26bfa69` native run 40653113122 has passed both build modes and Core/Memory steps; hosted step failed and UI remains running. Individual recorder results await terminal export. Intermediate queued `64709e5`, `4cd2540` and `efdc2c1` runs were replaced by GitHub concurrency before validation; this is not a passing result. `adb8fd8` run 40657202187 is pending. Do not transfer results across revisions.

Current work: original whole-document CapturedRoom geometry and exact saved-frame camera-track overlay, without the registration matcher's feature cap or rendering-inflated wall thickness; bounded archive compatibility; native remaining failures and phase timing evidence. Geometry is historical RoomPlan measurement, camera path is not feet/body ground truth, and missing objects remain unknown. The full live localization/obstacle/routing loop, doorway return/deviation/recovery device validation, 400 complete user journeys and final reproducible package remain open. No child trial or live physical release is established.

---

## Preview compiler repair — 2026-10-28 07:47 UTC

Checkpoint `3aef69509a2d287204f16f52e9c5e819e63046ad` was pushed and remote-verified. It fixes the preview reload handler's caught `error` shadowing the Boolean property by explicitly assigning `self.error`. Native run `40651360959` at the earlier preview source failed both app builds on that line; Core passed 1,402 executed with zero failures and one skip, and Memory 51 passed. Hosted/UI did not execute. This repair is not yet native-verified. The intervening fence source still contains that compile error; do not conflate source revisions.

The next recorder checkpoint has a reachable local screen and read-only actual code-owned plan feed, independently source-reviewed. Raw camera positions remain unchanged and registration is nil until a measured producer exists. This is a temporary in-memory diagnostic, not saved/exportable evidence or a collision guarantee. Canonical membership and existing package linkage for its hosted storage tests are being completed before publication.

---

## Published navigation checkpoints — 2026-10-28 07:42 UTC

Remote branch `codex/recovery-hazard-order-20261027` verified at `8767fa0e4696ce8b7d5562fe623783cd137c55ee`. Prior checkpoint `0e7fc50992bd538864365782242e65b2718b3e4e` publishes the bounded recorded-route preview, canonical native membership, actual-owner hosted bench fixtures and both native evidence packages. The preview is diagnostic archived geometry, not current-room localization or physical guidance.

Latest completed native validation at `2636519`: both builds passed; Core 1,395 executed, zero failures, one skip; Memory 51 passed. Hosted 157: 145 passed, six failed, six skipped. UI 18: 14 passed, one Dynamic Type failure, three skipped. Practice explicit End passed with 5.534 seconds elapsed upper bound. Five journey publication waits and the queued-scene-fence regression remain pre-fix failures. [Exact source-bound evidence](research/native-candidate-app-integration-85/integrated/evidence/run40645432883/).

Checkpoint `8767fa0` adds a DEBUG actual-task completion fence for functional test setup, retaining original responsiveness limits and release behavior. Nineteen source/provenance checks and twelve Node checks passed; native validation has not yet accepted this fix. Preview run `40651360959` is active; fence run `40651563267` is pending behind it at this checkpoint. These are separate source revisions, not interchangeable results.

Next: finish reachable opt-in trajectory recording controls and a read-only code-owned plan feed, preserving raw phone samples without snapping or fabricated registration; finish native failure diagnosis and validate exact source. The source-level recorder remains local and uncompiled until its separate checkpoint. No automatic private upload, workflow activation, merge, deployment or child trial is authorized by these changes.

---

## Native evidence and preview integration — 2026-10-28 07:04 UTC

Exactfee8c7d native validation is terminal: both builds passed;157 hosted cases comprise149 passed,2 failed,6 skipped. Both new publisher-semantics fixtures passed. The practice Stop UI test now passes with explicit End and41.978s elapsed upper bound below90s. UI14 passed/1 Dynamic Type failure/3 skipped. The two hosted failures are separate map-recovery publication waits, under investigation; full-app acceptance remains open. [Exact evidence](research/native-candidate-app-integration-85/integrated/evidence/run40644081432/).

The next reviewed source connects a local recorded-route preview to the app and registers actual-owner integration fixtures. It displays archived Recast coordinates/hierarchy in a bounded ephemeral2D X/Z viewer, not a3D obstacle model or current-room route. No pose, floor, physical authority or LLM directions are fabricated. Portable source/artifact checks passed; new Swift tests, file-picker lifecycle and preview UI require native validation. N00 connected live navigation is still unfinished. Current263 native run40645432883 is testing the prior photo/localization/project stage.

The user's local visual-claim checker and complete world→building→floor/room→pose/body→route→goal flow are recorded below. Editable labelled body estimates are allowed for setup/replay; mapping/pathing defects in wide areas must be diagnosed separately. Local planned-vs-phone-trajectory test recording with problem markers is requested and under implementation, with no automatic private upload. A usable connected navigation build precedes a walking handoff.

---

## Connected navigation handoff priority — 2026-10-28 06:34 UTC

The user requires a connected usable build before walking-test handoff: place/building map → floor/room → established pose/direction → code planner → current support/hazard validation → code-owned output. Do not substitute an LLM path or ask the user to discover missing basic integration during a walk. **N00 connected recorded replay is the next integration slice**, using existing owners and a nonphysical replay sink; supplied replay poses/support are not live calibration. See the [dependency-linked reconciliation](research/tracker-reconciliation-20261028/README.md).

The final100-schedule package is published at4eb51bd. Historical separately assisted one-/three-lap records do exist; the final100 matrix is not a lap test and neither establishes live phone-only navigation. The practice-presentation fix is published atfee8c7d; existing native run40644081432 is in progress, not a passing UI result. New photo-retention and localization-test checkpoints are locally reviewed but await publication/native validation. New workflow activation and raw archive approval remain separate. Jev/similar verifier implementation stays deferred; the user requested deeper decision-model research only, preserved in the [review](research/JEV_IMAGE_VERIFICATION_REVIEW.md).

---

## Status update — 2026-10-28 06:24 UTC

The complete frozen schedule accounting is published at `4eb51bd`: [final audited report](research/journey-benchmark-readiness-84/final-20261028-0325/README.md). **100 attempts accounted, 94 completed movement episodes: 90 arrivals, three support stops, one predicted-underbody rejection, five interrupted unknowns and one CPU-limited partial.** None of the six incomplete attempts was rerun or counted as success. Completed distance551.244139m;14/20 directed pairs arrived under all five conditions. Supplied poses, reference support/collision veto, zero-margin body, assisted source exclusions and unmeasured ground contacts prevent treating this as phone-only accuracy, safe guidance or a table-lap test.

The reviewed simulation-presentation/cancellation candidate below remains native-verification pending. The last tested003 revision retained two UI failures. Jev and similar visual-verifier work are **deferred** by the user, research retained only. Navigation, localization, image-retention and native accessibility work continue in separated workstreams; no full tracker,400-journey or device acceptance claim. New workflow activations and source84 raw archive remain separately unapproved; ordinary source/evidence publication to the named review branch was explicitly approved.

---

## Status update — 2026-10-27 23:37 UTC

Native `003788a` is terminal: both builds passed; hosted units149 passed/6 skipped/0 failed; UI13 passed/3 skipped/2 failed. The practice split still failed before End with no sub-90-second witness; Dynamic Type remains open. [Verified evidence](research/native-candidate-app-integration-85/integrated/evidence/run40598054378/).

A separately reviewed candidate now avoids identical **simulation-only** detection/progress publications while retaining every detector, continuity, hazard, expiry and feedback tick; live publication is unchanged. A practice-only status is adjacent to End, retaining the top banner, explicit tap, camera-off postcondition, both90s guards and120s expiry. Portable contracts and mutations pass; native compile/UI and two authored publisher-semantics fixtures remain pending. No root-cause or actual-model notification-count proof is claimed. [Candidate, exact reversible source layers and limits](research/practice-cancellation-test-review-20261027/production-diagnosis/FINDINGS.md).

The [first50 frozen outcomes](research/journey-benchmark-readiness-84/checkpoint-20261027-2335/README.md) independently recount43 simulated arrivals,3 support stops and4 interrupted/unknowns. Remaining schedules continue without retuning or rerunning unknowns. Supplied-pose/reference-assisted/zero-margin and unmeasured-ground-contact limitations remain unchanged. The full tracker, live localization/sensing, physical acceptance and400 journeys remain unfinished; pending new-workflow/archive approvals remain separate.

---

## Status update — 2026-10-27 23:19 UTC

Navigation remains the engineering priority. Earlier dated sections below retain historical results, not current completion claims.

- Exact `38ac458` native evidence is now verified: both app compilation modes passed; hosted units **149 passed, zero failed, six skipped**; UI **12 passed, two failed, three skipped**. The scene-fence repair passed. Dynamic Type and the practice test's active-state precondition failed. [Source-bound evidence](research/native-candidate-app-integration-85/integrated/evidence/run40583132225/).
- `003788a` separates practice reachability from explicit cancellation, retaining the production 120-second expiry and two sub-90-second cancellation guards. Existing [run40598054378](https://github.com/mischa23v/blind/actions/runs/40598054378) has passed both compilation modes and its hosted-unit step; UI checks remain in progress. No terminal UI verdict or exact new case count is credited yet. [Repair and coverage trade-off](research/practice-cancellation-test-review-20261027/).
- [Frozen recovery04 checkpoint](research/journey-benchmark-readiness-84/checkpoint-20261027-2318/README.md): first **46 scheduled outcomes = 39 arrivals, three support stops and four interrupted/unknowns** (8,15,31,45). Episode46 resumed after the prior deadline plus grace and unchanged-evidence checks. No unknown was rerun, no frozen rule changed. Supplied poses, reference support/collision veto, zero margin, assisted source exclusions and unmeasured ground contacts remain explicit limitations; this is not live phone avoidance or a completed table lap.
- [Offline route-deviation diagnostic](research/path-deviation-diagnostic-20261027/README.md), published `25244fb`: unchanged pinned Detour geometry, **62 synthetic fixtures passed**, zero failures/skips. Measures supplied-pose cross-track, along-path and camera-heading error; ambiguous association remains unavailable. No localization, body-heading, physical accuracy or runtime guidance claim.
- The actual mesh bridge remains diagnostic-flag fenced, default-off and no-copy/no-ingest. Origin-lease and new endpoint workflow proposals remain inactive pending their specifically requested activation approval. The source84 archive has a separate pending upload approval. Ordinary code publication does not resolve either gate; no master merge or deployment.

Next: complete the unchanged matrix and current native review; establish independently estimated map-relative pose, measured body/mount calibration, live support/hazard coverage, checked path entry/deviation and recovery before physical guidance. The 400 actual-stack journeys and staged supervised acceptance remain open.

---

## Status update — 2026-10-27 21:19 UTC

Latest published repair `38ac458` has passed both app compilation modes and its hosted-unit step in [run40583132225](https://github.com/mischa23v/blind/actions/runs/40583132225). Exact case-count verification and the terminal accessibility result remain pending; this is not full-app acceptance. The mesh connection remains default-off/no-copy, with no physical guidance authority. The dated checkpoint below retains its earlier status and evidence scope.

---

## 2026-10-27 21:01 UTC — Published integration compiles; later revision awaits native verification

Stage85 integration is pushed at `1658cf`; [published receipt](https://github.com/mischa23v/blind/blob/1658cf/research/native-candidate-app-integration-85/integrated/README.md). Both normal and diagnostic-enabled app compilation passed [run40580300632](https://github.com/mischa23v/blind/actions/runs/40580300632). Its hosted-unit step passed, while exact count verification and terminal UI outcome remain pending at this snapshot. The earlier “unapplied until compilation passes” sequencing is superseded; the actual bridge remains DEBUG/diagnostic-flag fenced, process-default-off and no-copy/no-ingest, with no guidance authority. The established native workflow's budgets are distinct from the failed experimental harness's limits, whose failures remain preserved.

The later critical-retirement ordering layer and deterministic scene fixture are published at `38ac458`; see [current integrated receipt](research/native-candidate-app-integration-85/integrated/README.md). Portable verification passed 35 source checks, 43 targeted contracts and 14 additional privacy/recovery/handoff checks. Native [run40583132225](https://github.com/mischa23v/blind/actions/runs/40583132225) is pending. The earlier integration's compile result must not be presented as a native pass for this later source.

The [20:59 saved-evidence checkpoint](research/journey-benchmark-readiness-84/checkpoint-20261027-2059/README.md) covers 30 scheduled outcomes: 28 completed simulated movement episodes, comprising 25 arrivals and three support-uncertainty stops, plus two interrupted/unknown outcomes (8 and 15). No frozen path, threshold, geometry, cache or physics changed. Supplied poses, evaluator support/veto, zero margin, assisted exclusions and unmeasured ground contacts remain limits. This is not live phone sensing or a table-lap result.

The exact original indoor-import test passed with a positive witness on the `8c` evidence revision; its public evidence is preserved at [8a657fc](https://github.com/mischa23v/blind/commit/8a657fc), not inferred from a later retry alone. The [body-profile evidence](research/apple-body-profile-current-20261027/README.md) separately verifies 55 unique XCTest passes, zero failures/skips and 27 matching compiled-input hashes. Full native `0babd78` model-asset/UI failures remain historical failures. No full-app green, latest-source native pass or participant acceptance is claimed.

---

## 2026-10-25 — Local selected-PDF page quotation

The existing conversation controls now offer Choose a PDF, one-based file-page selection, Read and Forget, with equivalent trusted English/Arabic typed commands. A bounded whole-request grammar also accepts terminal sentence punctuation and reviewed direct polite English/Arabic commands, not general natural-language intent. Selection is separate from reading. One bounded immutable source is hashed from its actual bytes and read locally through PDFKit's accessibility-permitted text layer; no PDF content, filename, path or hash enters models, histories, stores or diagnostics.

A separate always-private owner preserves the original 60-second page acquisition/install deadline, then permits finite installed quotation through ordinary budget waits. Existing manual/photo deadlines remain unchanged. Exact callbacks own completion; lifecycle/privacy/hazard interruption cannot revive old work. Correctable page errors retire only page work while retaining a valid file for an explicit retry. Display revisions protect newer identical-text replies. No exact-model appliance binding, control advice, automatic next page or hands-free authorization is added.

Portable results, original failures, independent review and native limits are recorded in the [selected-PDF receipt](research/evaluations/selected-document/README.md) and [verification](research/evaluations/selected-document/verification.json). Actual Apple PDFKit/system-picker/audio/VoiceOver and participant acceptance remain pending. **R39/R40 remain partial.**

---

## 2026-10-25 — Explicit menu-reading aliases (portable source increment)

Exact imperative and ordinary polite English/Arabic menu-reading requests now select the existing captured-document lane through trusted task routing. Output retains uncertain captured-text framing and existing same-source review/private/ordinary-budget gates. No menu interpretation, item/price/allergen association, complete coverage or real-world completion claim is added; no new model/dependency/persistence.

**1,312 Core tests and 531 serial Node checks passed, zero failures/skips; 790 relevant input hashes unchanged during final Node.** Final source reconciles with the published test/tool repairs rather than claiming the older local scaffold included all later inputs. Portable results and native limits: [menu alias receipt](research/evaluations/menu-reading-aliases/README.md). Native OCR/audio, hands-free authority and supervised nonvisual usefulness remain separate and unverified. Existing generic visual fallback for non-alias requests and terminal coordinator restart semantics are unchanged.

---

## 2026-10-25 — Captured-page review local candidate

One bounded volatile page can now be explicitly repeated, navigated by part, reread or forgotten through exact English/Arabic commands. New playback identities preserve prior receipt semantics; actual start/completion, ordinary budgets and existing trusted/private gates remain authoritative. No interpretation, new camera requirement for historical quotation, persistence or new dependency.

Portable verification: 1,303 Core tests passed with no failures/skips. Extracted controller witnesses and final serial Node aggregate are recorded in the candidate evidence; they are not native audio or participant validation. Native app acceptance remains separate and pending. See [scope and semantics](research/evaluations/captured-page-review/README.md).


---

## Checkpoint 31 — code-only find continuation survives exhausted sensor retries (2026-10-25)

- Preserved real native source-29 failure: run `40220809616` compiled and executed one test, with two failed assertions and zero skips. Five real AVSpeech completion receipts were inspected. The post-forget query said “I couldn't finish that check yet. We can try something else.” rather than asking a new room/area question. Typed forget cleared state; its acknowledgment was outside the isolated harness speech lane, not evidence of production speech failure.
- Repaired the actual controller without reopening sensor attempts: exhausted same-target finds may use attributed history, retained raw clues or a code-owned clarification; no new capture, appearance lookup, locate/continueSearch or measured-geometry output is admitted. Longer item names declined by the clarification parser cannot reset the exhausted budget. Reader checkpoint-30 changes are preserved.
- Upgraded the portable replay to execute the actual coordinator route instead of its earlier simplified stub. Published-29 baseline executes 34 cases with 32 assertion failures across five cases; repaired/reader-rebased replay passes 34/34. The failed reader-fixture merge compile was preserved and the existing reader boundary stub restored.
- First complete combined serial per-file aggregate: 75 files, 499 tests, 497 passed and two failed exact-source expectations. Reviewed updates retain all original scope/geometry/ordering constraints and additionally require the new sensor-work guard. Separate final-source aggregate: 75 files, 499/499 passed, zero failures/skips/cancellations/todos; source hashes unchanged throughout each run. These are combined serial aggregates, not a single Node invocation.
- Evidence: `research/rebuild-evidence/search-clue-retry/verification.json`, with failed-native output receipts and failed-first-aggregate history retained. Native speech acceptance on the repaired production is still PENDING: rerun the unchanged room/area and actual-speech question-delivery assertions after publication. No claim of all-six audible turns, audibility/comprehension, physical fridge retrieval, model-selected actions or a completed connected journey.


---

## Checkpoint30: finish one bounded captured-text source

Validated captured text no longer expires while waiting for the ordinary word budget or a slow exact speech callback. A single source-owned budget wake preserves the unread cursor, including across user pacing changes. Capture admission and unfulfilled acquisition deadlines remain unchanged; installed reference text grants no live-camera or physical authority.

A metadata-only session receipt now distinguishes completed playback from cancellation. Only exact successful callbacks can complete nonempty installed text; privacy/history deletion and session retirement clear the receipt. Acquisition informationReady is not delivered completion or real-world goal completion.

**1,291 Core tests and 491 final serial Node checks pass**, with zero final failures/skips. The first Node fixture-compile failure and focused fail-before evidence remain disclosed. Portable verification and known failed cuts are documented in [checkpoint30 evidence](research/evaluations/reading-completion-checkpoint30/README.md). Actual native audio/timer/Vision acceptance remains pending. Source-bound repeat, clarification and menu understanding are separate work, not solved by this reading repair.

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

Evidence: `research/evaluations/captured-text-receipts-20261025/README.md`, exact source manifest and preserved logs. Historical records below are preserved except for the explicitly disclosed historical local-path redaction.

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

## CURRENT FEATURE PROGRESS — 2026-10-25

Latest verified published source: `978b506283b5ce9d1ea05ea120db8806f47754fe` (tree `750cd35b01a4e662a99797589afbbca53092a308`). This current feature snapshot supersedes earlier checkpoint snapshots retained below, including old sections headed “current.” See [REBUILD_FEATURE_STATUS.md](REBUILD_FEATURE_STATUS.md) for publication state, actual behavior, remaining gaps and dependency order. Original requirements and failures remain in [REBUILD_TRACKER.md](REBUILD_TRACKER.md) and [REBUILD_SCOPE_ADDENDUM.md](REBUILD_SCOPE_ADDENDUM.md).

### What is actually published

- `0c38d674`: DEBUG source integration now covers native input/model/tool/evidence/gate/speech plus privacy purge/disable. This is no longer merely a standalone recorder; real Apple callback/storage/endurance acceptance remains open.
- `7682086`: repeated goals, dated reports, original request wording, target-specific completion and unknown-age history repaired. Same-goal movement between different physical fridges still needs binding work.
- `1ae0b806`: registered map storage/current-leg collision, native controllers, exact route tickets and speech/beacon retirement connected. This is no longer merely a standalone registry, but it lacks calibrated native pose/body-heading/support and automatic journeys. Map IO at this boundary is synchronous.
- `cd368af98dcce0e0b1ab82e8983a5f9d373e753e`: direct, legacy and model-selected clock output is operation-owned, code-rendered and bound to original freshness. Real Apple/compound-response acceptance is pending.

- Published at `978b506`: bounded ordinary guard repairs and reference-reading Core/support. Full published evidence is Core 1023 / Node 379; the native manual/PDF and full native reference speech adapters remain missing.

### What is not yet published or integrated

- Applied, unpublished: 15-file selected-photo increment, focused verified. Current full Core 1057 passed; Node aggregate FAILED (391 total, 389 passed, 2 failed); test-only correction/full rerun and next remote SHA pending.
- Staged, not applied: raw observation budget candidate with 81 scoped source tests cleared but final archive pending; asynchronous map IO frozen awaiting observation/privacy rebase. Additive journey Core remains unwired and its native quiet patch needs rebase.
- Still missing: calibrated native position/body-heading/support issuer, automatic world-map learning/relocalization and full cross-map return, native manual/PDF adapter, verified speaker identity and complete 400-episode coverage.

### Evidence boundary

Last published checkpoint evidence is [checkpoint 07](research/rebuild-evidence/checkpoint-07/verification.json): **1,023 Core / 379 Node**, zero failures/skips. The official-manual extracted-text replay passed with synthetic playback, not native PDF/audio delivery. These are that checkpoint's results, not a current-photo-candidate rerun. Extracted callback checks overlap aggregate totals. Syntax parsing is not Apple SDK typechecking or execution; public replay datasets are test inputs, not native accuracy proof. Preserve [checkpoint 05](research/rebuild-evidence/checkpoint-05/verification.json)'s original merged failure/correction as well as prior memory/debug failures.

Applied photo candidate: **Core 1,057 passed; Node aggregate FAILED: 391 total, 389 passed, 2 failed; corrected full rerun pending**. Next publication SHA: **pending**. Record the final pair only after the applied source is frozen and tested; do not mix a candidate Core count with the prior published Node total or staged focused results.

### Earlier progress/checkpoint snapshots — retained history

Photo aggregate correction: Core 1,057 passed; Node finished with 391 total, 389 passed and 2 failed. Independent diagnosis identified stale source-contract count/prefix assertions. The test-only correction replaces them with stronger per-source ownership and cancellation-order checks; production source is unchanged. The aggregate remains FAILED until the corrected full rerun passes. Preserve the original failure and corrective diff; photo checkpoint 08 remains separate and unpublished.

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

This section is the current reconstruction snapshot and supersedes older status below. Historical counts remain attached to their historical checkpoints; they are not rerun evidence for this build. Scope: [REBUILD_TRACKER.md](REBUILD_TRACKER.md), [REBUILD_SCOPE_ADDENDUM.md](REBUILD_SCOPE_ADDENDUM.md). Work queue: [TASKS.md](TASKS.md), [TODO.md](TODO.md).

### Verified preservation and current source scope

- **Baseline:** 717 files restored and checked for exact agreement with the preserved repository baseline `4b00872f1bbc4ea92dca55f47f008f33460c4e71`. This is not recovery of the missing later unpushed increment.
- **Published:** initial reconstruction documentation is verified on GitHub at `20af33fe`. This is a documentation checkpoint, not a new integrated-app result.
- **Implemented locally:** command-authority boundary with native entry hookup. Standalone spatial-frame/localization-authority and DEBUG-recorder foundations also exist, but are **not wired into the app**.
- **Review:** identified defects in these new source increments were corrected. Frozen source inputs show no code drift; only the current documentation sections changed. Review does not replace platform/device validation.
- **This documentation update:** current task list, immediate to-do queue and expanded scope prepared for the next reviewed checkpoint. Its publication is pending until a new remote SHA is recorded.

### Actual current verification

| Check | Current result | Meaning and limit |
| --- | --- | --- |
| Aggregate Node tests | **338/338 passed; 0 failed, 0 skipped; exit 0** | Swift-enabled rerun completed in 14.656 seconds, including extracted native-method execution. This is not a complete Apple runtime, native app or phone acceptance test. |
| Full portable Core suite | **910/910 passed; 0 failed; exit 0** | Includes 865 baseline cases and all 45 new reconstruction cases. New tests actually executed; synthetic foundation checks are not native app integration or real-world localization evidence. |
| Official Swift toolchain | **Swift 6.4.1 installed; official signature verified** | Used for the successful Core execution. No Apple SDK is supplied by this Linux toolchain. |
| iOS Swift syntax parsing | **Default and DEBUG + BLIND_FAMILIAR_PEOPLE configurations both exited 0** | Parsing only, not Apple SDK typechecking, macro expansion, linking or execution. Command entry hookup exists; spatial/debug event integration and Apple/device validation remain incomplete. |
| 400 whole-episode scenarios | **Incomplete; no new complete coverage result recorded here** | Historical catalog binding counts and prior claims are not current passes. |

### Open gaps and next checkpoint

Next: publish the verified code, current documentation and test logs in the first small source checkpoint, then read back its exact GitHub SHA. The first code checkpoint is not yet recorded as pushed in this snapshot. Continue native spatial/debug integration and the remaining tracker work after preserving it. Updated task/scope documents can be checkpointed separately rather than waiting for the entire rebuild.

Still open: perception-versus-task evidence lifetime; full connected-map/native mapper/collision/return integration; native debug-event wiring; memory, clock, reference and photo repairs; expanded identity/accessibility/everyday/hazard cases; long-mapper accuracy; real speaker verification; missing native adapters; complete 400-scenario execution and live iPhone validation. No completed product, safe-navigation, recovered-latest-source or full native integration claim is made.

**Do not carry forward as current:** the historical 1,629 Core / 500 repository checkpoint is missing-source/test-history context only. Prepared tests, source review, synthetic replays, native integration and device acceptance are distinct states. No UI, automatic debug uploads or room-permission additions are part of this reconstruction.

Evidence: [verification summary](research/rebuild-evidence/checkpoint-01/verification.json), [Core log](research/rebuild-evidence/checkpoint-01/core-tests.log), [Node log](research/rebuild-evidence/checkpoint-01/node-tests.log), [tested source hashes](research/rebuild-evidence/checkpoint-01/source-hashes.json).

### Historical progress records

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

## Earlier coordinated publication checkpoint — 2026-10-23

This is the preceding publication record; the spatial follow-on above is newer. Integration preserves primary `30999a9` and incorporates the reviewed seven-commit Claude branch through `61001267`, plus the coordinated Saudi device-test and familiar-person work. It is source integration, not a deployment or Apple/device acceptance.

**Canonical acceptance tracker:** [CHILD_ASSISTANT_TEST_TRACKER.md](CHILD_ASSISTANT_TEST_TRACKER.md). It records the goal, provenance rules, 24 child-style scenarios, three response paths (ordinary chat, independent hazards, evidence-gated physical requests), and executed versus still-pending checks. Use [CLAUDE_INTEGRATION_REVIEW.md](CLAUDE_INTEGRATION_REVIEW.md) for fixes and evidence, [PROJECT_VISION.md](PROJECT_VISION.md) for product intent, and [SESSION_LOG.md](SESSION_LOG.md) for decisions.

Final portable checks: **530/530 BlindCore**, **14/14 BlindMemory**, **216/216 Node**, **17/17 synthetic MobilitySimulation**; firmware protocol and sanitized failure tests plus native face-slot C++ tests passed. All iOS Swift source parses in default and combined optional configurations. Aggregate verify passed in a disposable copy; the active project was not regenerated. Parsing/source contracts do not replace Apple SDK typechecking, native linking, actual model behavior, audible latency or VoiceOver testing.

The first tab is settled assistant replies only; helper/settings tabs retain accessible mute/end/setup. Foreground startup starts an idle conversation and permitted sensing after setup, respecting saved camera-off and explicit mute/end on foreground return. Rooms show real RoomPlan layout/counts during start/stop scanning. Family enrollment uses photos, then name, then confirmed save. Consented foreground recognition checks bounded face batches and proposes one tentative saved-person notice per encounter; no position, follow or authentication claim. Actual recognition accuracy remains unmeasured here.

Saudi recognition is functional only in an explicitly configured **Debug device-test build**, with the private 16-reference pack pinned by manifest hash. Default/Release has no approved production profile. See [tools/currency-reference/DEVICE_TEST.md](tools/currency-reference/DEVICE_TEST.md); preserve existing face/model/framework options when generating that test variant. No reference images or weights are committed. Dataset diagnostics are not independent phone accuracy.

Physical object direction/reach/pickup guidance remains withheld because specific-target/depth binding is not validated. Typed find tools can gather fresh nonspatial candidates and attributed historical memory; the LLM cannot self-authorize a physical instruction. Bounded lexical guards are not exhaustive semantic proof. Current temperature/weather requests cannot be answered from camera or model memory: this build has no live weather/thermometer tool. A real fresh device-clock tool is included.

**Next, in order:** build the exact selected configuration on the Mac; run the tracker with real model and recorded provenance; measure first audible reply, interruption and hazard-preemption timing; run native camera/currency/family/reading and VoiceOver cases with a sighted adult. Retain the earlier hallucination and latency failures as open until exact-build retests pass. Broader child trials, native hardware acceptance, all-day operation and independent unsupervised use are not validated by these checks.

## Current integration checkpoint: 2026-10-23

This checkpoint integrates the seven commits ending at `61001267dc0633c6b3cb941038b18dbb380cdc3d` onto primary `master` source `30999a9ed0e921491ff62a1a93e073fe6af092ff`, not onto the older shared ancestor. The assistant-first voice, evidence, executable-tool, memory, audience and cancellation work remains. Older “no off switch”, unconditional background listening, confirmed device behavior and test counts below are historical, **not current requirements or evidence**. Explicit mute/end, independent camera control and opt-in supported background voice remain. The latest child-first direction defaults active foreground camera awareness on, respecting a saved off choice and OS permission/background limits; old camera-off-default notes below are superseded.

See [CLAUDE_INTEGRATION_REVIEW.md](CLAUDE_INTEGRATION_REVIEW.md) for the reviewed scope, fixes, portable checks and exact remaining acceptance scenarios. No Apple SDK build, actual model/phone accuracy test, firmware board build, deployment or device readiness is claimed.

## Continuous local assistant source milestone — 2026-10-23

Integrated from shared `master` at `d6d4236bf6d54ac0c0d9c6d18696bc743cac1e0e`, preserving the Mac changes and active generated Xcode project. Publication is a source checkpoint, not deployment or acceptance of all 44 capabilities. [PROJECT_VISION.md](PROJECT_VISION.md), [SESSION_LOG.md](SESSION_LOG.md), [ASSISTANT_FEATURE_CHECKLIST.md](ASSISTANT_FEATURE_CHECKLIST.md) and [MAC_HANDOFF.md](MAC_HANDOFF.md) now provide the durable continuation record.

Implemented assistant-first ordinary/visual/control routing; independent camera, microphone mute/end and opt-in background audio; generation-fenced cancellation/recovery; acoustic-energy onset with transcript fallback; bounded streamed TTS and completion-accounted history; private-route-loss pause; bounded original-report retrieval/correction/deletion and task suspension; real read-only Foundation Models tools with provenance/deadlines; fresh on-demand Vision candidates; explicit audience preference; and one reduced-context overflow retry with no tool replay. Natural colour/money inspection cannot fall through to a bare free-form model answer. The historical cup-location/8.385-second actual-app failures remain unclosed until the exact new app is retested.

### Historical verification for the earlier checkpoint

- **455/455 BlindCore XCTest tests passed**, official Swift 6.4.1 Linux toolchain; includes session, dialogue, acoustic onset, capture recovery, speech delivery, evidence/tool runtime, context overflow, audience and scoped domain policies.
- **14/14 BlindMemory SQLite tests passed** with matching official Debian SQLite headers/libraries.
- **150/150 Node tests passed** (server behavior and source/integration contracts, not actual Apple UI/audio/model tests).
- **17/17 MobilitySimulation cases passed**, synthetic fixtures and scripted responses, no actual LLM/sensors.
- Firmware protocol test passed. Failure-injection test passed under AddressSanitizer and UndefinedBehaviorSanitizer, including 100,000 command frames. LeakSanitizer itself cannot run under this executor's ptrace; leak detection was explicitly disabled, not claimed as passed.
- All iOS app/hosted/UI-test Swift sources parsed; combined optional `BLIND_RTABMAP`, `BLIND_APPLE_MULTIMODAL`, `BLIND_FAMILIAR_PEOPLE` syntax parsed. **Parsing is not Apple SDK typechecking, macro expansion, native linking or execution.**
- `tools/verify.mjs --multimodal` passed in an isolated copy, including project generation; the actual integration project's SHA-256 remained unchanged. Swift/C++ were run separately because that script skips them on non-Mac without Docker.
- A separate extracted-source Swift run passed **39/39** checks: 20 evidence, 10 context/retry, eight actual working-state cases and one real-role byte-budget case across all six audience/language combinations. The eight state tests are also appended to the existing hosted iOS test file, awaiting Apple execution.
- Independent source review closed six definite integration issues: missing assistant context, stale queued evidence, foreground invalidation hang, premature visual heard-history, garment/money bypass, and quiet/resume compatibility. Final added-path review also corrected tool-controller main-actor isolation, acoustic-release queue wakeup, and SDK27 overflow-error build-flag coupling. Supplemental synthetic helper checks do not establish device timing or model quality.

### What is not complete

SDK27+ base/text-only builds require the explicit `BLIND_FOUNDATION_MODELS_V2` condition described in MAC_HANDOFF; the checked-in project does not auto-detect it. No Apple SDK build, actual Foundation Models conversation/tool/macro run, physical microphone/AEC/double-talk/route/background/lock/VoiceOver run, battery/thermal endurance, latency retest, or child-use acceptance was possible in this Linux workspace. Acoustic-energy thresholds are prototype policy, not measured phone latency or speaker identity. The role preference is not age verification or a child-safety enforcement system. Lexical grounding/domain guards cannot certify arbitrary model truth. Fresh Vision returns only uncertain OCR and a narrow anonymous category vocabulary; current evidence still expires after 0.5 seconds and must be withheld if generation/delivery is too slow. No general consequential action tools are exposed.

Remaining source/design gaps, distinct from device testing: semantic end-of-turn detection and slower-turn adaptation; word-aligned mid-phrase heard-prefix accounting; a full stopped-answer resume protocol; model-token-aware compaction beyond bounded original-record retrieval/one retry; broader scene/action coverage with authority; and shared-device profile isolation. All 44 rows retain explicit current status and acceptance scenarios. No private dot parity, guaranteed all-day availability, certified currency/colour accuracy or independent child mobility is claimed.

<!-- Historical Claude-branch entries below; current integration status above supersedes old controller and test claims. -->
## Photo library, Arabic statuses, optional Live Activity, Linux Swift results — 2026-10-22 (follow-up)

- **Describe a photo from my library** (Seeing AI "describe photos"): Explore a picture › "Describe a photo from my library" opens Apple's Photos picker. The photo is read in memory only (never saved or sent). It gets the same touch-explorable Vision regions (text, people, page, detector objects), plus a hedged overview from `VNClassifyImageRequest` categories with confidence ≥ 0.5 ("The photo may show: …"). No language model is involved.
- **Arabic for the remaining status lines.** `StatusText` translates the wearable, outdoor-route, private 3D map, community-library and first indoor-route status lines where they are shown, so a language switch applies at once. Room-change comparison results are now spoken in Arabic. The experimental adult-only familiar-people lab screen stays English.
- **Optional Lock Screen / Dynamic Island status** (H11): `node tools/generate-xcode-project.mjs --live-activity` adds a WidgetKit extension (`ios/BlindAssistLiveActivity/`) and `BLIND_LIVE_ACTIVITY`. It shows only "Assistant is listening" and whether the camera is on, with no replies, places or people, because anyone near the Lock Screen can read it. There is no push token. The default build has no extension target. A node test covers both project variants.
- The checked-in Xcode project was regenerated; it was missing the newer Swift files.
- **Verified here, in a disposable Linux Swift 6.2 container** (authorised bounded builds):
  - BlindCore `swift test`: **361/361 pass**.
  - BlindMemory: **14/14 pass**.
  - All app, test and extension Swift files pass `swiftc -parse` with the default, `BLIND_DEVELOPER_CLOUD` and `BLIND_LIVE_ACTIVITY`+`BLIND_APPLE_MULTIMODAL` flags.
  - `npm test`: **131/131 pass**.
  This supersedes the "no Swift toolchain here" notes in the three entries below for BlindCore and BlindMemory, including `CompanionEvidenceTests`, `TrackedTargetTests` and `ReadingToolsTests`.
- Two defects these runs found are fixed: a type-checker timeout in the page-area code, and expired hazard warnings still being spoken.
- **Not verified:** the iOS app build and type-check (the Linux container has no UIKit, ARKit, Vision or SwiftUI), UI tests, device behaviour and the widget extension build all need the Mac.

## Seeing AI-style reading tools — 2026-10-22 (follow-up)

The Seeing AI app source is not public. I compared its documented features and added the missing ones, all on-device and decided by Vision, ARKit and code:
- live text reading;
- page reading with framing guidance;
- barcode and QR scanning with ticks and saved product names;
- a light detector;
- explore a picture by touch.

Main screen (user request): the five tools are large buttons above the bottom tab buttons, under the reply, and a running tool's button becomes its Stop button. Voice commands: "Read text", "Read the page", "Scan the barcode", "Call this …", "Is the light on?", "Stop reading". They also appear under Settings › Ask and goals › Reading tools, and as a stop action on the main reply. Details are in research/SEEING_AI_CODE_REFERENCES.md. npm test 130/130. Swift and device behaviour are unverified (no Swift toolchain here).

## Tracked target and instant acknowledgement — 2026-10-22 (follow-up)

- Added `TrackedTarget` (Touvigation pattern): once the sensors find an object, guidance is re-measured from LiDAR every frame, spoken at 3/2/1 m and on turns, "Within reach" at 0.6 m, refreshed by re-detection every 1.5 s, and ended with "lost sight" after 8 s. No model calls.
- Chat replies that haven't started within 1 s speak "One moment."
- Added `UnsupportedPremiseTests` (EgoBlind-style categories, our own cases) to the Mac real-model tests.
- The user's shortlist of related projects is recorded with licence limits in research/HALLUCINATION_REVIEW.md. No code copied.
- npm test 129/129. `TrackedTargetTests` is written but not run (no Swift toolchain here).

## Always-on companion, sensor-backed search, full code scan fixes — 2026-10-22 (cloud session, continued)

User direction: the companion must work like an always-on agent (OpenAI dots): always listening, never off, because any gap is a danger to the child; keep every function; keep the reply-only main screen with the bottom buttons; sort and make accessible all other screens; sensors and data are the source of truth. Reviewed the second-opinion review (Astra) and ran four parallel code scans (core app, other screens, Swift packages, server/tools/firmware). About 90 findings; verdicts and changes are in [research/HALLUCINATION_REVIEW.md](research/HALLUCINATION_REVIEW.md).

**Always on**
- Background audio and Bluetooth modes.
- BLE state restoration and saved pairings.
- The camera pause is announced and repeated every 30 s.
- Foreground return restarts everything.
- Camera failure and frame-loss restart.
- The microphone retries forever, including after permission or language-model gaps.
- No off switch: Restart replaces Stop, practice ends after 2 minutes, and the belt has Reconnect instead of Disconnect.
- A Siri/Action-button App Shortcut opens the app.

**Evidence**
- Live object search with an explicit result: found and measured from the current pose, seen but not measurable, or not located (never "not here").
- One constrained image-model hint, freshness-checked.
- Saved search record.
- Detector-only identity ("a cup", never "your cup").
- Absence, identity and unhedged-direction filters.
- Arabic object grounding.
- Strict 2-of-3 frame agreement.
- Wider spatial, chat and utterance coverage, with every scan-found miss added to the shared fixtures.
- The relay keeps a fixed "possible hazard visible" line.

**App fixes**
- Conversation not cancelled during calibration or lost monitoring; replies still spoken.
- Calibration feedback and the "monitoring active" announcement.
- Greeting before camera start.
- Conversational goals keep map alignment.
- Room descriptions no longer cancel requests.
- Item lookups protected.
- Echo window 3 s.
- Arabic restarts listening in the new language.
- Learned item descriptions grounded.
- Place deletion removes pictures and state.
- Room-recall index alignment; object lift capped.
- Duplicate-role wearable dropped.
- Scan announcements.
- Many Arabic messages.

**Screens**
- Main screen: only the reply, above the bottom tabs; VoiceOver actions for Yes/No, Repeat, Quiet, Restart, End practice and Write.
- Settings, Places, Routes, Ask, Camera, Saved memory, Interests, History, Community and Room detail are reorganised: headers, most-used first, item names in labels, short sentences, a voice-command help page, and confirmations before deleting or sharing.
- Private 3D map export removed (it can hold pictures).
- Home layout, journey and route exports need a helper confirmation.
- Public map drafts require a venue type and permission.
- Review links are https only.
- The precise location is rounded to about 1 km.
- The photo client is compiled only in developer builds.

**Swift packages**
- A lone map match against a strong rival clue now asks.
- Single-saved-item matching is stricter.
- Hazards are never dropped as invalid.
- NaN-time fixes, planner rounding, a storage size check and recency ordering.
- The AppleModelEvaluation `@main` file was renamed.

**Firmware**
- A weak floor frame is debounced.
- A lost floor while calibrated is treated as a possible drop with a kept baseline (recalibration after 5 s).
- "No target in range" is no longer a fault.
- Watchdogs added, the timer-wrap stop is fixed, and the belt has a 60 s pairing window.

**Server/tools**
- Recursive privacy test with `#if/#else` tracking.
- The handoff packager honours `.gitignore`.
- The relay refuses plain-HTTP LAN binding unless explicitly allowed.
- The API key is kept out of `ps`.
- Evaluation labelling fixed.

**Not changed**
- `GenerationOptions(samplingMode:)` stays: the scan said `sampling:`, but the earlier Mac build compiled with `samplingMode:`. Verify on Mac.
- Frame-retention pressure is noted only.
- A Live Activity needs a widget extension.
- Some remaining English-only strings in CommunityLibrary/BeltLink/OutdoorNavigator, and FamiliarPeopleView labels.

**Tests**
- `npm test` 129/129.
- Firmware `protocol_test` and `failure_test` pass (g++ with ASan/UBSan).
- Swift not compiled in this container: BlindCore/BlindMemory XCTests, the app build, the rewritten UI tests and device behaviour (background audio, BLE restoration, camera interruption, VoiceOver) must be verified on the Mac and iPhone.
- Firmware has not been built for hardware (PlatformIO not run); the NimBLE pairing callback and watchdog APIs need a hardware build.

## Hallucination fix, reply-only main screen and microphone fixes — 2026-10-22 (cloud session, source only)

The user asked for a review of all handoff problems, focused on the Apple model inventing answers and objects, then approved the recommended fix. Full review, model comparison (Apple on-device vs Gemini Nano vs Gemma vs Private Cloud Compute) and sources: [research/HALLUCINATION_REVIEW.md](research/HALLUCINATION_REVIEW.md).

- **Code owns facts; the model only labels and talks.** New BlindCore `CompanionUtterance` / `CompanionFactBook` parse find requests and location reports (English/Arabic, "it", hedges, multi-sentence). Code answers them instantly and keeps reports historical with their time. Model chat passes the new `ConversationClaimGuard` (no current location, presence, absence or perception claims) plus `SpatialClaimGuard`, with one retry and then "I don't know that." The recorded failure "I last left it on the kitchen table" now produces "Got it. You last had your cup on the kitchen table. I'll remember that."
- **Image grounding.** `VisualGrounding`: unhedged model sentences naming an object are spoken only when the phone's detectors agreed on it in 2 of 3 frames about 150 ms apart. The image prompt lists confirmed objects.
- **Speed.**
  - Sessions are prepared and prewarmed ahead of time; the app prewarms at launch.
  - Plain-line context replaces the JSON blob and the pretend tool call.
  - The model-written `CompanionDecision` task state was removed.
  - The decorative ROSA/SayCan/LangGraph/BehaviorTree ports and `ios/ThirdParty` were removed.
- **Find requests** use the saved item (by look or saved place), then the child's report, then a live Vision/LiDAR search, before "I don't know".
- **Main screen** shows only the current reply (no tab bar, no navigation bar) so VoiceOver reads only that. Other screens are reached through VoiceOver actions or a long press on the reply; magic tap repeats. The typing control appears only with `--text-only`. UI tests were rewritten for this layout.
- **Microphone.**
  - Answering a yes/no offer no longer switches continuous listening off for good (it used to call the manual `start`, which cancelled continuous mode).
  - Recovery now retries with back-off instead of stopping after three failures.
  - Audio-session failures retry.
- **Tests:**
  - `npm test` 125/125 after installing the two small Node packages with `npm ci --ignore-scripts`.
  - New tests: the shared fixture `companion-evidence.json` in Node, and 5 static checks in `tools/test/companion-evidence.test.mjs`.
  - Two stale assertions were updated: microphone permission wording, and the currency `cancelDescription` regex.
- **NOT run:** Swift compilation, BlindCore XCTests (including new `CompanionEvidenceTests`), Apple SDK app build, UI tests, real-model conversation tests, phone timing and VoiceOver. There was no Swift toolchain in this container and Docker was not authorised. Nothing here is accepted until the Mac run.

## Final typed-chat diagnostic and remaining failure — 2026-10-22

A debug-only --chat-baseline in the running app, with a minimal role and no history/schema, answered Help me find my cup with Where did you last have your cup? This one turn passed; it does not validate the full app. Normal path was then separated into streamed natural reply followed by guided task extraction, preserving source reports and task state. Empty navigation records, previous model replies, duplicate current requests and older extracted facts were removed from prompt context; durable records were not erased. Cancellation cannot retain a proposed step, and metadata timeout cannot erase an already displayed answer.

Final actual UI: Help me find my cup -> Your task is to find your cup. Did you last have your cup near the table? Then I last left it on the kitchen table -> Your cup is on the kitchen table. Goal displayed correctly, but a historical report became a certain current-location claim: FAILED evidence handling. First complete sentence8.384551s, reply finished9.141065s: FAILED latency target. Earlier revision passed closed/open comparison and visible backpack switch/cancel; those were not all rerun on final build. Active Xcode BuildProject6.980s and isolated simulator Apple SDK build passed;6affected privacy/spatial checks passed. These checks do not catch all ungrounded conversational claims. Final app runs normal --text-only; diagnostic baseline off, UI session closed. No physical/voice/model-switch validation. Do not mark chat ready or blame the base model alone; full-context pipeline still fails where a minimal baseline succeeded.

Exact outputs and successive failures: ios/.validation-results/text-chat-status.json. Task acceptance: ios/.validation-results/interactive-agent-scenarios.json. Next work must isolate context contributions and enforce historical-versus-current evidence throughout conversation, then validate multiple scenarios/paraphrases; avoid further unsystematic prompt accumulation. Full sensor/tool execution, task suspension/resumption and long-session retrieval remain open.

## Interactive companion feedback correction — 2026-10-22

Applied source-informed agent patterns to the local text adapter, preserving voice pause and original project/backend. Simplified chronological context, removed duplicate latest request and generated subject/value reply rendering, and moved the natural answer before structured bookkeeping. Actual UI closed/open comparison now answers correctly. Timing-only app logs: first sentences10.546s and9.281s; total generation12.585s and10.304s. These fail the response-time target. Cup request failed to create a visible goal and produced an unsupported not-found statement plus unnecessary permission question. Backpack replacement and cancellation changed the visible goal correctly, but replies remained poor. Follow-up fix copies whole explicit task request as goal, distinguishes unknown from a failed search, starts requested help without redundant permission, and prevents cancellation from retaining a proposed step. Active Xcode build passed7.193s and isolated simulator build passed; actual UI follow-up pending. No all-pass claim. Privacy/spatial17 checks passed before follow-up; affected6 checks passed after it.

Reviewed Inner Monologue (human goal changes, success/scene feedback), tau2-bench (dual-control and final-state evaluation), Anthropic context/agent guidance, WorldScribe and streaming evaluations. These are research/adapter patterns, not full imported agent runtimes. Source links and limitations: ios/.validation-results/companion-prompt-research.txt. Actual UI evidence: ios/.validation-results/text-chat-status.json. Scenario acceptance criteria: ios/.validation-results/interactive-agent-scenarios.json. Full suspended-task resumption, fresh sensor/action tools, long-session memory retrieval and physical continuous-use acceptance remain open. No Gemma install/model change, uploads, project regeneration or push.

## Actual chat failures and researched role/context correction — 2026-10-22

User explicitly rejected automated passes as acceptance and required actual typing in the running app. UI reproduced transcript leakage and contradictory recall twice despite prior fixture passes. Adapter now excludes malformed historical assistant replies as examples without deleting stored user history and refuses transcript-reciting/oversized outputs. Actual follow-up What is my name returned Alex. Goal change to tea and milk follow-up were relevant, but closed/open fridge updates produced irrelevant tea instructions and repeated What should you do next. These are failures, not an all-pass result.

Saved-name UI initially failed because profile was not an accepted MemoryStore namespace. Corrected to supported preferences/preferred-name. Actual Maya save, restart persistence and model recall over old Alex history passed. Forget restored original empty profile; personal data preserved. Recall still appended an unnecessary question.

User requested researched startup role plus durable goals, task progress and change criteria. Consulted Apple FoundationModels prompting, instructions, context and session docs. Replaced accumulated prompt patches with three paragraphs covering companion purpose, child independence, available capabilities/evidence, task changes/completion, and question versus update behavior. Moved user-controlled profile into prompt data. Text adapter now receives structured saved goal/preferences/historical map and existing navigation checkpoint state, explicitly unverified live location and no available action tools. This is NOT a general persistent task tracker or continuous sensor integration. Full task state, confirmed-fact retention beyond six turns and token-aware rollover remain gaps. Evidence/research: ios/.validation-results/companion-prompt-research.txt and text-chat-status.json.

Latest simulator build succeeded; active Xcode BuildProject succeeded7.299s. Final actual closed/open pair with researched prompt FAILED: both single inputs yielded The fridge door is now open. What should you do next? Closed input contradicted; follow-up repetitive. Stable UI is not correct conversation. Saved-name persistence passed; general chat remains unacceptable. User now prioritizes established robotics-style LLM supervisor, persistent task state and sensor/action tools; references recorded in ios/.validation-results/companion-prompt-research.txt. No new automated tests launched after user's correction; prior suite was deliberately interrupted. App running --text-only; microphone off. No push or physical device validation.

## Text chat first and saved preferred name — 2026-10-22 (local)

User paused voice because it is slow and repetitive, then explicitly required hands-on typed conversation in the running app instead of treating automated passes as acceptance. Added --text-only: no automatic microphone/camera startup, no speech dispatch, no spatial-audio initialization, manual microphone entry points guarded. Operation replies remain visible. Existing normal mode retained. Added preferred-name Settings save/forget using existing private memory namespace profile/preferred-name, separate from six-turn dialogue; pass saved name into every local text conversation session. Corrections in current conversation take precedence for that reply; durable changes use Settings.

Real-model fixtures initially passed keyword checks but manual output review found an invented Lily greeting. Tightened prompt and checks; revised seven cases passed in 57.250s with concise fruit/fridge answers. This does not prove general conversation correctness. Latest Xcode BuildProject passed 10.731s; simulator built and 22 existing iOS unit tests passed; six privacy/spatial checks passed. Expanded final run was deliberately interrupted at user request during saved-profile tests to prioritize hands-on typing. Saved-profile restart behavior is not yet verified. Simulator launched --text-only for UI verification; results pending. No push, microphone restart, physical sensor/image validation, or 24-hour claim. Evidence: ios/.validation-results/text-chat-status.json and text-profile-interrupted.log.

## Simulator microphone recovery and conversation regression — 2026-10-22

User requires testing on Mac; physical iPhone unavailable. AirPods Pro connected as default input/output. Simulator speech failure was first a missing unpacked mini.json; full772MB Apple model existed in Restore. Extracting that exact package caused local speech service crashes because H19.bundle was incompatible with runtime requirements (intel/universal/jit). That extraction was rolled back and preserved under [historical local recovery directory]. A reversible simulator-only compatibility trial using the already-installed older Mac English model (build13M300771,447MB) allowed listening to initialize and remain active. User confirmed a live reply beginning Hello Alex. This is not a redistributable app model or device validation; manifest ios/.validation-results/speech-mac-model-test.json.

Conversation remained incorrect: history recitation and contradictory name recall. Local dialogue comparison found no substantial similarity between the last user turns and preceding assistant output, so echo is not established as the cause. Changed LocalImageAssistant conversation from serialized/labelled history in a user prompt to FoundationModels Transcript prompt/response entries; retain bounded existing history, local-only inference and SpatialClaimGuard. Added focused real-model Swift Testing regression for Alex name recall without transcript recitation. Xcode device build passed8.428s before adding regression; simulator regression now running. Earlier whole-suite results do not cover these changes. No24hour claim and no push.

## First conversation test — 2026-10-22 (local, in progress)

User narrowed the acceptance target to opening the app, hearing a greeting, and keeping a spoken conversation alive with supplied test inputs. Continuous microphone code now distinguishes an open stream from an active utterance; ordinary speech is no longer blocked merely by listening. A camera-independent Foundation Models conversation fallback uses the existing bounded six-turn dialogue and applies SpatialClaimGuard before speech. No remote service is used. Updated microphone purpose text. Camera/model/physical operation remains unproven; supported-phone calibration and background stop behavior remain unresolved. Old UI tests still target superseded controls.

Validation so far: Xcode device build-for-testing passed (12.708 s); isolated base simulator build passed; focused privacy/spatial checks 6/6. Simulator two-turn check pending. No audio, sustained-runtime, recorded-image-in-conversation or 24-hour pass is claimed. Detailed local result: ios/.validation-results/conversation-first-test.json. Do not push or regenerate the active face-backend project.

## Continuous companion correction and source review — 2026-10-22

User explicitly corrected the product: persistent visual/depth/audio awareness and hands-free conversation, not press-to-talk tools. Keep useful features accessible through simple bottom tabs; voice-guided setup; settings/wearables in Settings; quiet reduces narration without disabling awareness. The prior Stop/Start/Repeat-focused home is not the accepted final UX. Current code does not meet continuous operation: microphone ends each utterance/20-second window, backgrounding stops ARKit, XS Max live start is depth-gated. No claim of all-day operation.

Inspected pinned BankNote-Net training/prediction code, Seeing AI team's audio-description engine, Psi continuous-speech/live-recorded pipeline examples and historical currency example. No upstream source adopted or executed. Source evidence and full review: ios/.reference-materials/review-694eccb/CONTINUOUS_COMPANION_REVIEW.txt. Real Apple image-model Mac run returned 12/12 responses using the compact project prompt (4.19–10.94 s, median 6.13); seven of eleven stair-labelled frames mentioned steps, four omitted visible stairs. This is a direct local-model experiment, not phone app integration or a reliability benchmark. Eight text-model scenarios failed strict JSON parsing; diagnostic exposed fenced JSON. Three Arabic cases unsupported. New replay runs reproduced prior failures. VoiceOver audio, all-day runtime and physical lock/camera tests remain unverified; phone unavailable. No source changes/push in this review.

## Simple home and automatic startup — 2026-10-22 (local, not pushed)

The user rejected the technical dashboard and requested a child-usable assistant that starts on opening, speaks short next steps, and keeps optional wearable details in Settings. Added an everyday home with Talk, Repeat, Quiet/Speak again while running, Stop/Start and More. Maps, typed questions, Settings and explicit practice are reached through More; wearable pairing/calibration/status is only in Settings. No peripheral is required to open/use the everyday UI. Extra tools retain their existing detailed controls; they are not claimed fully redesigned.

Opening/returning to the foreground attempts live startup on supported hardware, with explicit camera permissions and level-floor readiness still required. Explicit Stop prevents automatic resume within that app session. New installs default to automatic surroundings descriptions; existing quiet preferences are preserved. Voice capture remains local and starts only on explicit Talk/magic-tap or the existing opted-in answer window. It now finishes after two seconds without a changed partial transcript, retains the explicit Done control and overall timeout, and reports permission/unavailable/empty-input errors through the existing speech gate. Real microphone timing and VoiceOver listening behavior remain untested. No danger, spatial-evidence, identity-consent or privacy gates were weakened. XS Max still cannot provide scene depth; unsupported startup says so and practice is explicit, never a live-sensing substitute.

Validation: Node 88/88; final signed AuraFace iPhone build-for-testing passed; isolated base simulator build passed using the saved original project (active backend project never regenerated). Latest full UI batch: 8/10 passed; after fixes, the maps/settings return test passed on targeted rerun. New everyday-home Apple accessibility audit, hidden-wearable check, practice start/stop and other existing functional UI tests passed. The remaining detailed Guide/Ask audit fails on contrast for the disabled map-destination button; no new suppression was added. Guide audit passed. This is not whole-app accessibility certification. The physical phone disconnected before updated runtime tests; no new device launch, real recognition, LiDAR, child-use or end-to-end speech result is claimed. Logs and precise results: ios/.validation-results/voice-home-summary.json.



## Currency reference matching and clothing colour — 2026-10-22

- The current currency route reuses actual local OpenCV 4.14.0 SIFT/ORB/AKAZE comparison, reviewed reference boundaries/hashes, competing-label/geometric gates and a full-frame Vision polygon veto. It is not a newly trained classifier or an LLM. No validated reference pack is selected; the default app explicitly reports unavailable and never guesses money. Earlier classifier/training code is dormant. No photos, weights or descriptors are published.
- Requested clothing colour uses local foreground pixels and Lab appearance, qualified captured-view speech, neutral uncertainty and no school-white certification. It does not use a language model to decide colour. Both requested visual paths retain attention/hazard/cancel/freshness gates and now use the same strict full optical-direction pose gate (<10 cm, <5 degrees), including pitch. Review identified and fixed a dormant currency pitch-only stale-view gap; synthetic regression tests cover that case.
- Recovery reconciles primary `295ca393` (including the Mac fixes in `c4f7a26`), preserving its Mac simulator/UI fixes. Eight source/doc files were recovered with exact Git blob verification; native source was replayed from recorded writing commands; missing integration and portable Python files were reconstructed. The final pose extraction/test and native formatting correction are explicit later edits. Original private photo inputs/detailed experiment artifacts are lost, so historical comparison observations are not fresh validation of reconstructed source.
- Fresh final checks: **BlindCore 349/349**, **Node 116/116**, **portable reference mechanics 55/55**; strict C++17 header syntax with Clang 17 and GCC 14; all 40 app Swift sources parsed in default, currency and combined currency/AuraFace/multimodal configurations. Core/native/app source hashes were unchanged during checks. The actual verified OpenCV framework passed the currency generator; the default project was restored without machine paths/assets. These are software/plumbing/syntax checks, not Apple SDK typechecking, native linking, real currency accuracy or device acceptance.
- The historical 17-query experiment reported three acceptable matches, thirteen abstentions and one unsafe front/back composite acceptance per prepared-reference method. The actual composite has not been retested through Apple Vision/native code. Modern 1/20, broad issues/backs, independent negatives and phone trials remain missing. No release winner, high-accuracy rate, authenticity, summing or child-use claim is made. See [current currency handoff](research/CURRENCY_REFERENCE_MATCHING.md), [reconstruction evidence](tools/currency-reference/RECOVERY.md) and [colour handoff](research/CLOTHING_COLOR.md).
- Shared OpenCV setup uses once-only process-wide initialization; existing face models, alignment and thresholds are otherwise unchanged. This source update is not deployment. V09/V11 remain open for their physical acceptance and remaining scope.

## Mac validation and fixes — 2026-10-22

## Private Mac transfer — 2026-10-22

Uploaded the Windows project snapshot, Git history and all recorded workspace test assets to the [private transfer release](https://github.com/mischa23v/blind/releases/tag/mac-transfer-20261022). Seven assets, approximately 987 MB total: 9,635 workspace files, including the unchanged 826,767,360-byte CA-1M capture (2,988 PNG images inside), 205 image files outside that archive, all scenarios, room fixtures, maps, point clouds, replay inputs, historical reports and transcripts. Verified 9,634 project-archive entries against individual SHA-256 hashes, 36 stair originals against publisher hashes, the Git bundle, and all seven uploaded asset digests. Credentials and platform build/dependency caches excluded. No app/model/iOS tests run for this transfer. Newer Mac source was preserved; the Windows snapshot is reference material, not a replacement for the current checkout. Mac download/extraction and real iPhone room scanning remain to be verified. Windows originals retained. Read research/MAC_TRANSFER_2026-10-22.md for restore steps.


The user authorized testing the existing ZIP despite its unverified source revision, then authorized publishing these fixes. The three modified source/test files were compared against current master; their pre-edit backups exactly match the corresponding blobs at `a2633a1`. The fixes apply on top of that head without replacing the Saudi banknote work. Results below describe the local pre-currency checkout, not validation of the combined latest master.

- Fixed Debug simulator architecture selection (`ONLY_ACTIVE_ARCH=YES`, Release `NO`), black text on the yellow prominent buttons, scalable wrapping for the map-destination label, and UI queries that work without a TabBar ancestor. The cloud control assertion accepts its absence in production. The accessibility contrast exception applies only to the disabled retrace control; all other findings remain enabled.
- Environment: M1 Mac, 8 GiB RAM, Xcode 27.1 (27A9275), iOS SDK 27.1, Swift 6.4, Node 22.23.4. Full Xcode command-line selection was corrected.
- Passed locally: Node 88/88; BlindCore 306/306; BlindMemory 14/14; face-policy JS 16/16; Python harness 28/28; C++ protocol/failure sanitizers including 100,000 frames; MobilitySimulation 17/17 (synthetic inputs, real core logic, no LLM).
- Apple builds passed: base simulator and device; build-for-testing after architecture fix; optional multimodal device; AuraFace device with pinned model/framework hashes checked and bundled model hashes rechecked. The final AuraFace build was signed, installed on iPhone XS Max/iOS 18.7.9, and the user confirmed launch after Developer Mode and trust setup. Signing identity, local paths, model assets and generated projects are not published.
- Hosted iOS tests: 22/22 passed. Latest six-test UI batch: 5 passed, 1 accessibility audit failed. After the map label adjustment, targeted audit still failed on the scalable Wearables heading. Dynamic Type audit remains unresolved, not suppressed or reported passed.
- Existing base build launched on iPhone 18 Pro Max simulator: Guide/Ask/Places/Routes/Settings navigation and simulation start/stop passed; no app crash observed. Simulation displayed the insufficient-ground stop message; individual hazard UI outcomes, actual speech and haptics were not verified.
- Xcode itself crashed twice with EXC_BREAKPOINT/SIGTRAP in AppKit window/view layout. Exact trigger remains unknown; serial CLI builds and devicectl installation avoided the GUI path, but do not establish an Xcode repair.
- Not run: full physical acceptance, real face accuracy/enrollment workflow, Apple pixel/orientation parity, VoiceOver, sensor/belt behavior, thermal/battery/endurance, or currency recognition. XS Max has no LiDAR; current monitoring/live face capture requires scene depth. AuraFace itself does not inherently require LiDAR. No trained Saudi model was validated. No child-use or release gate is closed.

## Historical trained-model preparation — 2026-10-22 (superseded by reference matching)

- Added local Apple Vision/Core ML adapter and explicit no-model status, eight-denomination/unknown policy, English/Arabic intent and measured-framing responses, strict snapshot freshness and existing attention/speech cancellation integration. Generic scene/OCR and learned descriptions cannot use common cash-value/authenticity outputs as a fallback.
- This is **not installed working recognition**. No dataset inspection, Saudi-trained weights, real recognition accuracy, Core ML conversion/runtime parity or phone test is claimed. The selected profile is nil. V11 stays open. No image/weight redistribution, merge or deployment performed.
- Portable checks: BlindCore 315/315 and Node 92/92 passed; all iOS Swift sources parse in default, familiar-person and AuraFace configurations. These are synthetic/source tests, not Apple SDK typechecking or currency accuracy. Training 32/32 and evaluation 37/37 synthetic harness tests also pass. These are not model-accuracy results.
- Dataset is being downloaded by the user. Next: local VOC/data/group inventory, real encoder/head training, calibration and held-out whole-frame costly-confusion/unknown tests, then Mac/iPhone validation. See [Saudi handoff](research/SAUDI_BANKNOTES.md).

# Project progress and continuation record

## Cloud review, familiar-person experiment and speech wiring — 2026-10-22

Reviewed upstream `master` at `7da0ce1fe19a2003418612efd5d0ddd8bb0e1e39`; 240 first-party/relevant files matched their Git blob hashes, with all 391 tracked paths inventoried. Baseline passed Node 54/54, BlindCore 235/235, BlindMemory 11/11 and 17 synthetic MobilitySimulation cases using direct Linux Swift 6.2. Docker rootless setup was blocked by host prerequisites; Linux never substituted for an iOS build.

Implemented regression fixes: shared English/Arabic spatial-guard fixtures expanded from 39 to 107; relay hazard context preserved; stale locate/item callbacks invalidated; queued private-image writes cannot resurrect deleted records; voice/UI deletion shares throwing cleanup; unresolved room identity/tracking/depth gaps clear stale trust; unsupported inferred door crossings and OCR ambiguity override removed. Private-memory v4 migration accepts the actual companion/items/room-recall/item-appearance namespaces, preserves old records and enforces per-namespace bounds. Privacy UI tests and microphone disclosure match the build; new installs default follow-up listening off.

The opt-in familiar-person source flow is complete for Mac testing: actual local multi-photo selection, guided rear-camera collection, three to six reviewed enrollment examples, explicit user labels/consent, encrypted backup-excluded gallery, add/replace/delete, voice commands/confirmation/cancel and accessible controls. SFace remains the explicit-feature default; AuraFace is a separate build-selected backend. A named search has a 20-second/six-check limit, one initial failed-attempt prompt, quiet retries, target-only tentative hint and fresh/session/goal/cancel/hazard gates. First-attempt success does not announce a failure first. Current recognition needs a steady tracked portrait view; walking recognition and chest-height framing remain device tests. Vision's optional aligned-face veto is off by default and uncalibrated.

All app-authored speech now reaches one private sink through CompanionAttention admission. Existing hazards, mobility, requested answers, ordinary budgets and goal rules remain; already-admitted offers/changes are not charged twice. A focused-task flag suppresses unrelated room/clothing information during stationary named search. Explicit current-operation confirmations/progress have a bounded <=80-word, <=30-second policy classification, no descriptive-content exemption and no delayed replay. Hazard dispatch cancels obsolete face work, questions and offers. Intrinsic system VoiceOver reading and actual audio interruption behavior still require Apple-device verification.

Final available checks: Node 88/88; BlindCore 306/306; BlindMemory 14/14; MobilitySimulation 17/17; synthetic face-policy JS 16/16; Python evaluation harness 28/28. All 39 iOS Swift files parsed in three configurations, with the separate native integration source also parsed; model configuration typechecked for both backends. Actual model hashes/framework version passed both experimental generators; default project restored without machine paths or model assets. Info.plist parses and includes required camera/microphone/speech/Bluetooth/location disclosures. C++ protocol/failure tests and 100,000 command frames passed Address/UndefinedBehavior sanitizers with leak detection disabled: LeakSanitizer itself cannot run under this host's ptrace environment. A stale source-contract test naming the old speech sink was updated to enforce the same spatial guard before gated delivery; final rerun is fully passing. Diff whitespace check clean.

Research evidence is separate from software tests. Preserved ORL SFace baseline: 178/180 known correct, 7/200 unknown photos falsely named, clustered in one unknown person. Fresh Aberdeen protocol used identity-disjoint calibration before the held-out run. Selected SFace .7/.2: 76/82 known correct, six abstentions, 0/193 unknown false names. Selected AuraFace .5/.2: 82/82 known correct, 0/193 unknown false names. Only 20 held-out unknown people were represented; this does not demonstrate below-1% population error. App multi-example aggregation and Apple checks differ from this single-template benchmark. Exact split, hashes and all 50 aggregate rows are in `tools/face-evaluation/ABERDEEN_RESULTS.md` and companion metadata; no images, weights or vectors are committed.

The user subsequently authorized integration into the existing shared primary `master` branch. The completed face commit is retained in history, with a non-force, expected-head primary update and these handoff corrections. Future authorized repository changes reconcile current remote work before primary integration; the branch is not renamed. No deployment or production-readiness claim is implied. Follow the current top section of `MAC_HANDOFF.md`: default `mac:setup` first, then generate the experimental project. The pinned OpenCV framework lacks arm64 simulator support, so use the physical-device build on M1. No Apple SDK build, native image parity, Keychain/PhotosPicker/VoiceOver runtime, real sensor replay, battery/thermal or 24-hour operation result is claimed. The existing idealized elevation sweep still recognizes only 16/42 cases; no sensor safety claim is solved by these changes. All physical and child-use acceptance gates remain open.

## Current — 2026-10-09 (end of Windows stage)

Next session is on the Mac mini: start with [MAC_HANDOFF](MAC_HANDOFF.md) "Mac day — start here". BlindCore builds with Swift 6.2 and all 235 XCTests pass in a Linux container (including 8 walking scenarios); iOS files pass a syntax check but the app target has never been compiled; Node 54/54. Latest pushed commit is on the private GitHub repo.

## Windows feasibility stage — 2026-10-09

Resumed from the continuation handoff. Ran `node --test --test-concurrency=1 server/test/*.test.mjs tools/test/*.test.mjs` on the current source: **40 passed, 0 failed**, log `artifacts/windows-stage/node-tests-20261009.tap`. This covers the Node relay/SQL/tool contracts including edits made after the earlier 39-test record; Swift/Apple sources remain uncompiled.

The user set the direction: the first slice is continuous, filtered, automatic narration with map-based orientation (not point-and-ask), sized for a fast screen-reader listener (high default density, most important information first, skip control, book-style first-entry room description then changes only, learned skips reviewable). Heat/battery are treated as measured-in-passing on device, not open questions. Next: a feasibility evaluation here using real public LiDAR/video sequences and photos through the actual relay and model, then Mac mini, then iPhone.

Gap review against the user's goal-led companion model: familiar places are silent background knowledge for goals; descriptions are for new places, waiting time or requests; first-visit description is offered, not forced; offers cover room identity, outfits and remembered items; hazards never wait. The current live loop requests an ambient description every few seconds and skips only exact-text repeats, so the E02 decision engine is the main missing piece. Added tasks E12 (offers/confirmations), M12 (room familiarity/routines) and Q09 (real-data evaluation), and scenarios OFF-01–08 plus OUT-01 (family café outing, 13 steps) to ASSISTANT_TEST_PLAN. Checklist: 74 tasks, 9 complete, 65 open. No Swift toolchain here; Swift scenario tests run on the Mac.

Spatial safety rule (user, 2026-10-09; AGENTS.md, task E13): hazard geometry (stairs/steps/drops/edges/curbs/holes/obstacles — distance, direction, step count, height, up/down, clear-path) only from sensors; step counts only from code with calibrated stride; model estimates for everyday objects allowed but must sound uncertain; sensor facts spoken confidently. Implemented `server/src/spatial-guard.mjs` (relay retries once then refuses), `BlindCore/SpatialClaimGuard.swift` (app drops non-compliant model text, speaks a short notice for requests), shared fixture `spatial-claims.json` (31 blocked/allowed cases, English and Arabic), static path test `tools/test/spatial-rule.test.mjs`, and a Claude Code PostToolUse hook (`.claude/settings.json` → `tools/hooks/spatial-rule-hook.mjs`) that reruns them after edits to guarded files. Model instructions rewritten accordingly. `node --test --test-concurrency=1 server/test/*.test.mjs tools/test/*.test.mjs`: **48 passed, 0 failed** (`artifacts/windows-stage/node-tests-spatial.tap`). Swift guard/test and engine are source only until the Mac.

Q09 first results (real CA-1M bedroom frames through the actual relay; `artifacts/windows-stage/q09/`): descriptions graded by viewing the frames were accurate (bed, headboard, bedding, picture, bedside chest, lamp, remotes, bean bag; door "right side, beside the wardrobe, partly open, hallway beyond" matches the frame and the measured +15° bearing; "no door in this view" when the door was measured 0.9 m behind). Code-rendered facts from the recorded pose gave the out-of-view door correctly. Dataset labels omit the bed (label gap). Claude Haiku and Sonnet (via subagents, quality only) were equally accurate; three of their sentences exposed an over-broad "edge" hazard term, now narrowed to drop edges in both Node and Swift with the real sentences added to the shared fixture. Latency (`latency.json`): handshake ~0.3 s; gpt-6.1-sol 3.9–4.9 s model time; gpt-5.4-mini 0.85–1.0 s; low image detail saves 0.3–0.6 s; prompt ~2,900 input tokens; spatial check 8.5 µs. Our own costs found and removed from the hot path: relay rate limit (config), whole-answer retries (now per-sentence drop and whole-sentence budget fit; retry only as last resort), auto image detail (now low except text/room). User direction recorded: speed is the first requirement; while moving toward a goal, fewest words (≈3 fast, 6 normal, 12 slow, full when still or asked) and only what is in the path. `AttentionPolicy.guidanceWords` and smoothed speed added (Swift, unrun). Node suite: **51 passed, 0 failed** (`artifacts/windows-stage/node-tests-e14.tap`). Next: compact on-device prompt (~400 tokens), streaming first sentence, on-device model timing on the Mac/iPhone, Claude timing once an Anthropic key is available.

Compact role prompt (`SYSTEM_COMPACT`, "You are the guide…") added for quick answers and moving guidance; the full prompt stays for detailed descriptions and map/people context. It halves input tokens (2,938→1,327 on gpt-5.4-mini; 2,247→636 on gpt-6.1-sol) but cloud time barely changed, so its main gain is expected on the on-device model. Claude timing via the official SDK (`@anthropic-ai/sdk` 0.132.1, pinned, installed with `--ignore-scripts`; key verified, stored in git-ignored `server/.env`), streaming, same frames and compact prompt (`latency-claude*.json`): **Sonnet 5.5 first words ~1.05 s (two frames), total ~2.0 s**; Haiku 5.5 first words 1.4–2.4 s; Opus 5.5 first words 2.1–2.5 s. All three described the bedroom accurately and passed the spatial check. Streaming the first sentence makes Sonnet the fastest cloud option measured; sub-second still needs the on-device model. Node suite 51/51.

Free on-device default made permanent (AGENTS.md): blind children and struggling families cannot pay API bills or manage keys, and many have home Wi-Fi only, so every core feature must run on the free built-in model offline; cloud is optional. On-device path corrected: `LocalImageAssistant` previously sent ~800 tokens of older instructions plus up to 24 KB of situation JSON, which would overflow the built-in model's ~4,096-token window; it now uses `GuidePrompt` (BlindCore) reading the shared `Resources/guide-prompt.txt` — the same file the relay's `SYSTEM_COMPACT` loads — and `GuidePrompt.compactSituation` capped at 4 KB (bulk dropped first: places, entities, map notes, conversation). `Package.swift` declares the resource. Swift `GuidePromptTests` prepared (unrun). Node suite 51/51 (`node-tests-ondevice.tap`). Git initialised locally at the user's go-ahead; `server/.env` and `research/datasets/` confirmed ignored.

Build-out toward a Mac day of design and testing only (user direction): see the TASKS "Build-out 2026-10-09" table for every module and its owning task. Helper agents wrote BodyHeading, SceneChangeDetector, ItemMemory, SpatialFacts, RoomRecognizer and LandmarkPose (each with XCTest files, confined to their own files); the app wiring, RoomRecall, ItemAppearance, LocateCommand, GuidePrompt, ItemAppearanceMatch and PeopleRegistry were written in the main session. User rules recorded in AGENTS.md: privacy (pictures and personal data never leave the phone; app build has no picture-sending path), public place library only on GitHub, consent for people recognition, identity decisions by image comparison not by the model. Object-matching research: Apple feature prints + foreground cut-outs + homographic registration now; DINOv2-S (Apache) and ALIKED+LightGlue (BSD/Apache) as on-device upgrades after a download go-ahead; avoid SuperPoint weights, MASt3R, MobileCLIP weights, SALAD (GPL), unlicensed repos. Baseline pushed to the private GitHub repo. Node suite 54/54 (`node-tests-items.tap`). No Swift compiled.

Independent Fable review recorded in `research/FABLE_REVIEW_2026-10-09.md` (FR-01–FR-20, tracked in TASKS). Dataset for Q09: CA-1M val capture 42898570 (Apple, CC BY-NC-ND 4.0, iPad Pro LiDAR, 996 frames at ~10 Hz, 1024×768 RGB, depth, per-frame pose, 99 labelled objects incl. door, door frame, walls, closet, TV, nightstand), downloaded to `research/datasets/ca1m-val-42898570/` (sha256 4fe2251d…c5c6). Recorded device poses test reasoning over real sensor data, not live localisation.

Older progress history (2026-10-02 to 2026-10-08) is in [research/ARCHIVE_TRACKERS_2026-10-08.md](research/ARCHIVE_TRACKERS_2026-10-08.md).

## Currency dataset transfer — 2026-10-22

At the user's request, uploaded the existing Downloads/7sys44td9c-1.zip to the [private currency transfer release](https://github.com/mischa23v/blind/releases/tag/currency-transfer-20261022): 6,752,380,788 bytes, split into four binary parts with reassembly instructions and original/part SHA-256 checksums. All eight uploaded assets match GitHub SHA-256 digests. The outer ZIP contains 7sys44td9c-1/Saudi Currency.zip. No dataset extraction, training, dependency installation, model download or app tests performed. Dataset licence, labels, training suitability and Mac extraction remain unverified. Original ZIP retained in Downloads. This records transfer only; V11 remains open.

## Seeing AI references and hello.zip — 2026-10-22

Uploaded the user-supplied hello.zip unchanged (9,420,989 bytes; three Read/Describe/More UI screenshots) to the [private reference release](https://github.com/mischa23v/blind/releases/tag/hello-seeing-ai-20261022). All five asset SHA-256 digests verified against GitHub. Saved research/SEEING_AI_CODE_REFERENCES.md and research/SEEING_AI_REPOSITORY_EVIDENCE.json covering all eleven repositories supplied by the user, exact source revisions, README/licence hashes and test/build source paths. Licence texts and READMEs retained in the release evidence ZIP. No complete Seeing AI app source verified as public; internal-app reference is not public access. No upstream execution, model download, training, integration or app tests. Source licences, model/data terms and offline suitability remain separate. User screenshots are private developer references only; no production privacy rule changed.


Portable verification for this follow-on: 592/592 BlindCore (whole suite), 15/15 BlindMemory, 257/257 Node, default and DEBUG/familiar-person Swift parsing, firmware protocol and address/undefined-sanitized failure injection passed. LeakSanitizer could not run under this executor's tracing; leak detection was disabled for the address/undefined sanitizer rerun. Aggregate verification passed in a disposable source copy with existing dependencies; reviewed generated Debug flags were copied into the checked-in project. No Apple SDK build, device test or accuracy result is claimed.
