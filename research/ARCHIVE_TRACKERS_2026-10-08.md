# Archived tracker history

Moved here on 2026-10-09 so the live trackers stay short. Nothing was deleted; historical results stay as recorded at the time.

## From PROGRESS.md (before 2026-10-09)

## Current pause handoff — 2026-10-08

**Paused at the user's request. Resume from [CONTINUATION_HANDOFF](research/CONTINUATION_HANDOFF.md). The full assistant remains unfinished.** Latest recorded serial suite: **39 passed**, `artifacts/minimum-assistant/integration-tests.tap`, before additional category/map-note and native refinements. Current source is not fully tested. No functional suite was rerun for this handoff; project generation and archive verification are preparation only. Apple/device verification awaits the Mac; Docker and heavy builds remain off.

Prepared manual map-to-situation context, camera/body heading separation, offline package metadata restoration, anonymous Vision tracks, speech priorities, pending-question regeneration, bilingual controls, category preferences and historical map notes. New native/core tests are source only: 22 hosted native methods and six UI tests await the Mac. The continuation handoff records files, API provenance, known risks and exact next steps. The checklist remains 71 tasks: nine complete, 62 open. **Everything below is earlier checkpoint history.**

Updated 2026-10-08. **The latest authorized lightweight checks passed: 37 Node tests and 15/15 context-delivery scenarios. The full assistant remains unfinished.** See the [minimum checkpoint](research/MINIMUM_ASSISTANT_HANDOFF.md) for current source, evidence and remaining integrations. Apple/device verification awaits the Mac; Docker and heavy builds remain off.

## Latest minimum-assistant continuation

Implemented a GRDB speech-attempt journal with pending/completed/interrupted/unknown outcomes, source/snapshot/goal revisions, bounded history, profile isolation, restart recovery and deletion. Native actor dispatch keeps journal writes outside immediate alert delivery. Current-session/goal history enters prompts as prior output, never present-world evidence or proof of comprehension. Repeated VoiceOver announcement text has ambiguous callbacks and remains uncertain.

Fixed long follow-up retention (2,000 Unicode scalars per turn; six turns). Added hosted native community and actual context-adapter tests, memory failure/receipt tests, relay receipt/long-dialogue tests and independent-source topology checks. Regenerated the Xcode project with the new source and hosted test target. Swift/Apple tests are prepared, not run.

Executed `node --test --test-concurrency=1 server/test/*.test.mjs tools/test/*.test.mjs`: **37 passed, zero failed**, log `artifacts/minimum-assistant/node-tests.tap`. Executed the home evaluator without a model: **15/15 context checks**, `artifacts/home-awareness/minimum-core.json`. No new inference calls, installs, Docker or Apple builds. This verifies contracts/supplied context and SQL constraints, not real perception or physical navigation. Broad tasks remain open: 71 total, 9 complete, 62 open. The native map hierarchy/continuous localization, social change tracking and complete speech arbitration gaps are explicitly retained.

## Earlier community continuation — source prepared before latest tests

Before transfer, reviewed the user's `blindw.txt` Sol report and independently checked three primary research references. [Review and decisions](research/SOL_IDEAS_REVIEW.md) preserve the full source and add four open tasks (M11, E11, V07, V08), eight prepared SOL scenarios and usefulness metrics under Q07. Current checklist: **71 tasks, 9 complete, 62 open**. The framing/uncertainty/last-seen prompt refinements are source changes, not demonstrated model behavior. No tests were run.

Regenerated the base Xcode project to include the new native files. Source/data generation and handoff checksum checks are preparation only, not builds or software tests. Preserve the earlier native-memory archive; the newer archive contains this continuation and the supplied report. Local keep-out edits now mark a community route copy as modified rather than presenting it as an unchanged contributor revision.

Added a bounded versioned place-package envelope around existing room/map types, public GitHub Releases browsing/download, offline import/cache/review/removal, damaged-file isolation, explicit route-revision selection and reviewed export. Source dates, coverage, attribution and scoped contributor claims stay visible. No download establishes location or changes an active route. Community publication/authentication/ratings, private backup, measured-map assets and cross-device localization remain open.

Prepared a source-grounded apartment fixture from the already downloaded pinned OAS example, retaining explicit room/door references, units, license and known gaps. It is an authored preview with no generated route or current position, separate from the unrelated 3D mesh.

Added explicit local interests with GRDB persistence, removal, visible save failure and stale-answer cancellation. Photo context, the rich local adapter and known-evidence selection receive these preferences; current goals/questions take priority. No automatic inferred learning is claimed.

Connected Apple's documented image Attachment API behind `BLIND_APPLE_MULTIMODAL`, checked by `mac:setup --multimodal` for an iOS 27 SDK. The default project retains Vision evidence fallback. Actual image quality, language availability, SDK compatibility and sustained performance await the Mac/iPhone. Added package/preference/UI/project-selection test source; **none of these new tests has run**. The historical **31 passed** log below predates this work and does not verify it. The earlier checkpoint had 67 tasks; the Sol review above adds four explicit follow-up tasks.

## Native source checkpoint — awaiting Mac

Latest hardware steering: the user wants to exploit iPhone 18 Pro performance. Verified Apple's A20 Pro/2-nm/GPU information, recorded the [local processing and sustained benchmark plan](research/IPHONE_PERFORMANCE_PLAN.md), and added documented Apple timing signposts for sensor frames, scene responses, room memory/approval and alert dispatch. No desktop-equivalence claim or benchmark result is inferred. No profiling trace or Apple build has run.

The user confirmed the Mac is available but its keyboard/mouse are expected tomorrow. Prepared source and commands without running Apple builds. Added the exact GRDB 7.11.1 package dependency and license resource, migration/transaction adapter, room proposals/revision checks/history restoration, AI/manual description review, deletion markers and retry cleanup. Production SQL constraints passed four direct SQLite tests; Swift adapter tests are prepared but unrun.

Latest serial Node regression: **31 passed, 0 failed**, including first-launch context without invented place/floor and four production-SQL tests. Log: `artifacts/native-memory/node-tests.tap`. The checklist remains 67 tasks, 9 complete and 58 open; prepared native implementations do not meet their device acceptance gates yet.

Added bounded ARKit matching recovery, explicit goal and six-turn dialogue persistence, a native relay adapter that leaves unestablished location unknown, source/goal revalidation, rolling narration word accounting, independent frequency controls and opt-in automatic VoiceOver narration. Detailed moving descriptions are no longer reduced by a movement-only rule. The speech adapter has a bounded current-announcement lifecycle, not a complete delivered-information ledger or tested multi-producer engine.

Xcode project regenerated with BlindCore and BlindMemory. A no-build Mac preflight checks Swift >=6.1, Xcode, SDK and required files. `MAC_HANDOFF.md` now includes dependency install and both package tests after approval. Exact scope, source provenance and device scenarios: [NATIVE_MEMORY_HANDOFF](research/NATIVE_MEMORY_HANDOFF.md). No new model requests, package resolution, Docker, native mapping dependency build or device trials occurred. Implementation tasks remain unchecked pending their actual acceptance evidence.

## Earlier relay and map-review checkpoint

**Later user correction:** the earlier supplied-pose/room evaluations do not establish map grounding or physical localisation, and navigation acceptance is unmet. [MAP_GROUNDING_REVIEW](research/MAP_GROUNDING_REVIEW.md) records restart/new-place ambiguity, distinct homes, authoritative maps and user-approved room edits. Two pinned authored apartment plans were downloaded and audited; one bathroom has a source area conflict, retained for review. They are not measured scans. A new regression exposed unknown location retaining an old room/frame; the relay guard is fixed. General drafting/revision approvals and native recovery remain open (M10/O09).

Latest serial Node check: **26 passed, 0 failed**, `artifacts/home-awareness/node-tests-place-uncertainty.tap`. TASKS now has 67 items: 9 complete and 58 open. The existing room-type AI suggestion requires Confirm; general room-description drafting/edit approvals and undo are still to build. No new model requests or dependencies were added during this map/restart follow-up. No Docker started.

- Preserved 95 pre-edit source files with hashes in `artifacts/assistant-baselines/20261008-184236/BASELINE_MANIFEST.json` (D04 complete). No Git assumed.
- Reused pinned Ajv 8.20.0 for schema validation; added relay context for pose, room/floor hierarchy, map connections, people/source age, goal, interests, delivered history, bounded conversation and arrival. Added a per-request word allowance, preserved moving detail, and reject oversized provider answers without chopping their meaning.
- Original context-delivery evaluation improved from 1/11 to 11/11. Four later conversational-destination cases also pass. These figures measure supplied data reaching the prompt, not perception accuracy or percentage of product completed.
- Actual Sol answers cover entering the living room, people, possible seating, décor, personal interest, conversation change, next-room context, last-seen people, intermediate-bedroom/bathroom intent, unknown heading, changed computer goal and ambiguous destination. All 12 completed within the 100-word request allowance. Exact inputs/answers are saved locally.
- Learned preferences (M09) and conversational navigation/units/personal step calibration (O08) are now explicit tasks. Purpose survives entry into an intermediate room; new goals must invalidate queued directions. Native dialogue persistence, live sensor/map/image fusion, route dispatch, automatic VoiceOver and rolling words-per-time accounting remain open.
- Official ChatGPT plan access is supported for eligible apps, with account-specific model discovery; Apple documents local image prompting. Actual OAuth/native providers still need integration. Current test access used an environment API key, not ChatGPT sign-in or Dot.
- At the earlier relay checkpoint GRDB was source-only. The native checkpoint above now adds its pinned manifest and adapter; package resolution and Apple verification remain pending. No Swift/iPhone, real-image, physical navigation, Dot, booking or child trial results for this expansion.

The user's later implementation/testing request authorizes bounded serial Node checks and synthetic API evaluation. It does not lift the Docker/heavy-build restriction. Only five small Ajv-related packages were installed, with lifecycle scripts disabled.

## Product direction to retain

The user clarified that information access is the product's foundation: the person uses it to understand, decide, enjoy, participate socially and move. The priority order below governs interruptions, not the product's scope or a requirement to finish routing before offering meaningful awareness. The first M2 assistant experience now explicitly includes V01/V02 and E09, with information-quality scenarios INF-01–INF-04. Anonymous social events no longer depend on completed family recognition; comparison/discovery no longer depend on completed outing routes.

Build a sighted AI assistant that bridges the information gap: **danger immediately; mobility/orientation next; rich awareness, discovery and description after that**. The user controls information amount, including words produced per time window, frequency and interests independently of their VoiceOver speed. Ordinary output budgets are enforced before generation and dispatch; danger bypasses and necessary mobility cues remain deliverable. Automatic speech must not require touching new text. Rich information remains available while moving; companions/guide dogs are context, not proof of clearance.

Room maps primarily provide orientation, including exits outside the camera view or behind furniture. Combine current images and sensor evidence with mapped position and body heading, retaining goal/conversation across rooms. Preserve local personal memory, people, interests, goals, entrance/return context and optional GitHub backups. Community members can publish versioned places for others to download, review and use offline. Dot/computer enrichment is optional; supported ChatGPT model access and separate Dot tools are distinct. Very young children are intended users; staged verification precedes child-facing mobility trials.

## Completed work

- Captured requirements, architecture, milestones and explicit implementation gaps in [PROJECT_PLAN](PROJECT_PLAN.md).
- Created one authoritative [task checklist](TASKS.md), a [next-action pointer](TODO.md), and session continuity instructions in [AGENTS](AGENTS.md).
- Specified [local memory and the eight-gate information engine](research/MEMORY_AND_INFORMATION_ENGINE.md), [orientation/community maps](research/COMMUNITY_MAPS.md), and [selective attention/fast speech evidence](research/ATTENTION_AND_SPEECH.md).
- Screened 19 upstream candidates: **18 source snapshots and one incomplete metadata-only screening**. Preserved commit IDs, license evidence, selected tests/manifests/workflows and downloaded-file hashes in the [upstream inventory](research/assistant-upstreams/INDEX.md) and [review](research/ASSISTANT_UPSTREAM_REVIEW.md). Presence of tests is not a passing test result.
- Inspected GRDB migration/concurrency examples; Soundscape callout history/state machine and CI; Graphiti temporal records; memory-engine storage/tests; event primitives and navigation references. Recorded actual reuse boundaries and license/toolchain gaps.
- Verified official NVDA/JAWS/VoiceOver rate controls, an adult ultra-fast speech study and task-dependent visual-attention research. Translated findings into explicit proposed policy, not claims of universal comprehension or validated navigation.
- Prepared [acceptance scenarios and future test commands](research/ASSISTANT_TEST_PLAN.md), including priority/preemption, missing speech callbacks, rich moving narration, occluded exits, cross-device map alignment, private/public data boundaries and child-facing readiness.
- Checked exposed tools and plugin discovery for Dot: no authenticated Dot account/memory connection available. No account access, integration test or account mutation occurred.

## Earlier research checkpoint (before implementation above)

Read-only inspection of current Swift/Node/firmware-related source, upstream GitHub metadata/raw files and primary documentation. Research downloader completed its source-hash/index checks. Final documentation checks cover local links, task IDs and recorded source inventory; these are document checks only.

At that earlier checkpoint, 11 project documents had no broken local links or duplicate task IDs; 62 tasks included 8 completed research deliverables. Later tasks and D04 completion are recorded in TASKS. `node tools/research-assistant-upstreams.mjs --index-only` verified cached evidence hashes and indexed all 19 records without executing upstream code. Confirmed the Soundscape race/TSan comment directly in the pinned workflow copy.

The earlier research-only checkpoint involved no runtime changes or execution. The later relay/dependency/API-test work is described above; do not mistake the earlier checkpoint for current implementation status. No Docker, Apple build, device trial or weight download has occurred for this expansion.

## Decisions and unresolved evidence

| Area | Current decision / remaining work |
| --- | --- |
| iPhone memory | GRDB 7.11.1 exact package and adapter added; requires Swift 6.1. Mac preflight, package resolution, Swift tests and app build remain pending. |
| Callout lifecycle | Soundscape is a useful source reference. Its inspected iOS CI explicitly disables Thread Sanitizer pending an audio-engine race; do not transplant or call the whole audio engine verified. |
| Memory products | Graphiti, Mem0, Hindsight and Letta are alternatives, not a stack to install. Letta Code MemFS supplies a concrete Git-backed precedent; local iOS persistence remains separate. |
| Mapping | Preserve current RTAB-Map and Recast pins. Geometry, coordinate-frame alignment and live evidence remain essential; generated artwork is not measured clearance. |
| Models/licenses | InsightFace code permission does not clear its restricted model/data terms. Family identity model not selected. Existing firmware/transitive license questions remain tracked. |
| Secondary candidate | `open-indoor/openindoor6` source-tree request returned HTTP 403; metadata-only, not selected. Other research supports continuing the core work. |
| Dot | Official plan inference access verified; native sign-in and independent Dot tool integration still pending. A01 stays open. |
| Baseline | Workspace has no `.git` metadata. 95 pre-edit source files saved and hashed; restore reviewed individual files only. D04 complete. |
| Resources | User has not authorized lifting the Docker/heavy-work restriction. Other sessions share this workspace. |

## Continue here

Follow [TODO](TODO.md): native situation/conversation adapter and persistence, compatible on-device multimodal provider, supported optional plan sign-in, speech arbitration/rolling budget and route-context integration. Continue proven-source/toolchain checks. Develop orientation and downloadable-map work alongside meaningful rich awareness; do not revert to a navigation-only first demonstration.

The relay is a partial implementation of E01/E06/E10 and Q01; those end-to-end tasks remain open. Each completion must record actual upstream/API used, files changed, command/results and limitations. Do not interpret this checkpoint as the finished app, a safety certification, or permission to start Docker.


## Former TODO.md (before 2026-10-09)

# Next actions

**Latest — 2026-10-09 (later):** speed is the first requirement (TASKS E14). Next, in order: (1) compact model prompt (~400 tokens) and streaming first sentence; (2) Claude Haiku/Sonnet timing through the relay once an Anthropic key is available; (3) Q09 rerun on fast models with the new hot path; (4) Mac: compile BlindCore (CompanionAttention, SpatialClaimGuard, guidanceWords), run package tests, then measure Apple's on-device model on the iPhone 18 Pro Max. Node suite 51/51. Fable follow-ups FR-01–FR-20 tracked in TASKS.

**Current — 2026-10-09:** 40/40 Node tests pass on current source. The live loop (`ios/BlindAssist/NavigationModel.swift:317`) currently requests an ambient description every few seconds and only skips exact-text repeats. Next: (1) build the E02/E12/M12 decision engine as portable BlindCore Swift with scenario fixtures OFF-01–08 and OUT-01 decision steps; (2) Q09 real-data evaluation here with public LiDAR sequences and photos through the actual relay; (3) Mac: run BlindCore tests and build. No Swift toolchain on this PC and Docker stays off, so Swift tests run on the Mac.

**Current pause — 2026-10-08:** the user asked to save a handoff and continue later. Resume from [CONTINUATION_HANDOFF](research/CONTINUATION_HANDOFF.md), which supersedes the earlier pointers below. Reconcile latest category/map-note contracts, run the authorized bounded serial suite on resume, then compile and exercise prepared tests on the Mac after the testing go-ahead. Latest recorded result is 39 passed before further untested edits. The minimum remains unfinished; Docker/heavy work remain off here. TASKS remains the only checklist.

## Earlier next-action record

Updated: 2026-10-08. Full scope and status live in [TASKS.md](TASKS.md); do not maintain a second independent checklist here.

**Current phase:** minimum assistant integration and Mac verification. Latest bounded checks passed: 37 Node tests and 15/15 context-delivery scenarios. Read [the minimum checkpoint](research/MINIMUM_ASSISTANT_HANDOFF.md) first. Apple/device tests await the Mac; Docker and heavy builds remain off. The full minimum is not yet demonstrated, and the remaining work includes integrations as well as bugs.

## Latest continuation and tomorrow's checks

Before transfer, [Sol's supplied report was reviewed](research/SOL_IDEAS_REVIEW.md), three primary references checked, and M11/E11/V07/V08 plus SOL-01–08 recorded. Current checklist is 71 tasks (9 complete, 62 open). The raw report is retained in the handoff; it does not replace the user's priorities or establish tested capabilities.

**The user's subsequent instruction authorized bounded scenario testing now.** Serial Node/SQL/relay checks are complete. Community, image, speech-journal and native context Swift tests still need the Mac. Read the minimum checkpoint and [community handoff](research/COMMUNITY_IMPLEMENTATION_HANDOFF.md) before continuing. No Docker, installs, heavy builds or model downloads today.

On the Mac after the user starts testing, use `node tools/mac-preflight.mjs --multimodal`, then `npm ci --ignore-scripts` and `npm run mac:setup -- --multimodal --ui` with Xcode/iOS 27 SDK support. Omit `--multimodal` for the older-SDK evidence build. Run the new package/preference/UI tests and fault scenarios in that handoff, then continue the still-open integrations below. Regenerate or restore individual shared files carefully; no Git rollback exists.

## Remaining work packages

**Priority correction from the user:** close the map grounding/restart/approval gaps in [MAP_GROUNDING_REVIEW](research/MAP_GROUNDING_REVIEW.md). Supplied-ID fixtures do not satisfy navigation acceptance. Native room drafts/versioned approval and bounded ARKit recovery code now exist, but Apple/device verification is pending. Automatic place discovery, verified floor/frame/body alignment and reliable physical routing remain unfinished. The two authored apartment examples remain unready for live navigation.

1. **D01/Q02/Q03:** on the Mac run `node tools/mac-preflight.mjs` first. After the user's build go-ahead, follow MAC_HANDOFF: `npm ci --ignore-scripts`, then `npm run mac:setup -- --ui`. Verify GRDB 7.11.1's Swift 6.1 requirement, both package suites and both Apple targets. Compare shared changes before restoring any baseline files.
2. **D02/D03:** narrow the Soundscape reuse boundary and resolve selected notices. Its CI currently disables Thread Sanitizer for an audio race; do not copy that audio engine as a proven subsystem.
3. **M01–M04/M09/M10:** verify the new GRDB transaction/migration adapter and accessible revision review before extending temporal facts, people, learned preferences and outing history. Exercise reopen/stale approval/deletion failures with existing scans; preserve originals until verified.
4. **E01–E10 with V01/V02/O08:** verify native dialogue/context dispatch, rolling word accounting and automatic VoiceOver on device. Then complete coherent map/floor/body-pose fusion, delivered-history ledger, multi-producer arbitration and conversation-driven routes. Current context intentionally keeps location unknown when alignment is unavailable; no guessed floor is inserted. Test image models on device; text fixtures do not establish their performance.
5. **O01–O04/C01 alongside the information experience:** establish portable map import and cross-device localisation, then the occluded-door orientation scenario. Keep valid descriptions and place previews useful before routing is ready. Anonymous social information need not wait for family identification, and item/restaurant comparisons need not wait for complete outing navigation.

## Testing handoff

The [test plan](research/ASSISTANT_TEST_PLAN.md) and minimum checkpoint contain remaining scenarios. Latest serial Node check: **37 passed, 0 failed**, `artifacts/minimum-assistant/node-tests.tap`; 15/15 context-only cases are in `artifacts/home-awareness/minimum-core.json`. Earlier real API runs remain historical evidence. No Apple/device or upstream-library suite was run for these changes. Live runs require explicit `--cases` selection of at most eight. No camera image is sent by this evaluator.

## Unresolved integrations

- Supported ChatGPT plan-usage research is in [MODEL_PROVIDERS](research/MODEL_PROVIDERS.md). Integrate actual sign-in, account model discovery, streaming completion and expiry/revocation. API-key test success is not OAuth success. Dot tool access remains separate and unavailable here (A01).
- No family-identity model/weights selected yet (V04).
- Public GitHub release download and offline map preview/cache source now exists (C01–C04 partial, unverified). Vicinity catalog search, authenticated publishing/reviews, private backup and cross-device map use remain open. No GitHub account/repository was created or published.
- One secondary upstream screening (`openindoor6`) has an HTTP 403 source-tree fetch; it is not selected. Research elsewhere is sufficient to continue core work.
- Child-facing mobility trials require Q04–Q06 first. Very young children are intended users, not substitutes for bench/adult validation.
