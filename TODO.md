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
