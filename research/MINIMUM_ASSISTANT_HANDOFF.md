# Minimum assistant checkpoint

**Historical checkpoint.** The newer [CONTINUATION_HANDOFF](CONTINUATION_HANDOFF.md) is the current resume point, including the 39-test record, later untested source edits, 22 prepared hosted native tests and remaining integration gaps. Keep the evidence below tied to its original source snapshot.

2026-10-08. Latest user authorization permits bounded serial Node/SQL/scenario checks now. Docker, heavy builds, dependency downloads and Apple/device execution remain deferred. This checkpoint prepares the Mac work; **the complete minimum assistant is not yet demonstrated, and remaining work includes integrations as well as bugs.**

## Implemented in this continuation

GRDB migration v3 adds a bounded, profile-isolated description journal. Accepted speech dispatch records its request, session, goal revision, snapshot and supporting input IDs. Platform callbacks record completed/interrupted/unknown outcomes. Restart converts unfinished entries to unknown. Late callbacks cannot overwrite a terminal outcome or resurrect cleared history. The last 20 descriptions are reviewable and deletable in Settings. Serial actor calls keep these database operations outside the immediate hazard callback.

Only the current session and goal's last four attempts enter model context. Prior output is not observation evidence. Platform completion is not proof of hearing or understanding, and no verified delivered-fact IDs are fabricated from generated prose. UIKit identifies announcement completions by text; repeated text is conservatively marked uncertain. Full multi-producer arbitration and its timing still need device work. This is a new domain adapter over GRDB/platform callbacks, not a transplanted or battle-tested Soundscape subsystem.

Longer conversation turns now retain up to 2,000 Unicode scalars without cutting off qualifications; six turns remain the bound. Local image output uses the same bound. Explicit preferences, reviewed room memory, community preview/cache and goal-change invalidation remain connected as described in the preceding handoffs. Model context is bounded; exceeding the local image adapter's 24 KB allowance causes fallback, not unlimited memory.

The generated Xcode scheme includes 14 hosted native tests (10 community storage/network cases and four actual situation-adapter cases), plus six UI tests. BlindMemory gains receipt lifecycle and additional transaction/isolation tests. These Swift tests are written but **not executed**. URLProtocol substitutes responses while the real URLSession byte reader runs; no public repository or credentials are needed for those tests.

## Evidence from this checkpoint

| Check | Result | What it establishes |
| --- | --- | --- |
| Serial Node suite | 37 passed, zero failed; [log](../artifacts/minimum-assistant/node-tests.tap) | Relay/schema behavior, actual SQLite schema constraints and project-generation contracts. It does not execute the Swift adapter. |
| Home-awareness evaluator | 15/15 context-delivery checks; [exact inputs/results](../artifacts/home-awareness/minimum-core.json) | Existing context fields survive the production relay validation/prompt path; danger rejects ordinary narration. Zero new model calls. |
| Independently authored apartment | Source hash and declared connections checked in Node suite | Four rooms plus explicit exterior, four doors, no invented direct bedroom/bathroom door, unknown floor/pose, preview only. It is not a measured scan or physical route. |
| Swift packages, hosted native tests, UI tests | Not run | Requires Mac/Apple toolchain. |
| Real images, VoiceOver, localization, obstacle response | Not run | Requires iPhone and controlled truth comparison. |

Commands already run: `node --test --test-concurrency=1 server/test/*.test.mjs tools/test/*.test.mjs` and `node tools/evaluate-home-awareness.mjs --label minimum-core`. Older 31-test and live model records remain historical evidence.

After bounding Mac build jobs, the four project/handoff tests were rerun and passed. Documentation links in 11 current entry-point documents resolve, and the checklist remains 71 tasks with nine completed research/baseline items. [Checkpoint hashes](../artifacts/minimum-assistant/checkpoint.json) retain the test-log, scenario-report and generated-project identities. Packaging integrity is separate from runtime verification.

## Minimum user journey: acceptance on the Mac/iPhone

Use a surveyed, controlled room and a sighted observer's ground-truth record. Record expected facts before each trial; do not seed the assistant with the answer as a substitute for sensing. A pass requires useful information and correct withholding/recovery where evidence is missing. Refusing every question is not a successful assistant.

| Scenario | Required behavior | Current boundary |
| --- | --- | --- |
| Enter living room | Useful overview, observed people, possible seating, relevant obstruction and optional interesting detail; distinguish camera coverage and uncertainty | Image/goal adapters exist; real image quality, actual occupancy and timing unverified; family identity not implemented. |
| Ask about a painting/person | Answer the follow-up, preserve qualifications and current purpose; avoid repeating the whole room | Longer dialogue and native context tests prepared; live conversation unverified. |
| Person moves or approaches | Relevant current change, with age/uncertainty; no guessed identity or intention | Persistent tracks/change events remain missing. A repeated image prompt does not close this gap. |
| Bedroom is intermediate to bathroom | Preserve bathroom objective; no irrelevant tour or assumed arrival; directions require verified pose/body heading and connected doors | Supplied-context cases pass; native continuous hierarchy/pose/route fusion remains incomplete. |
| Leave through an occluded door | Use verified map alignment and live obstruction evidence; keep return context | Downloaded preview is available; portable anchors and reliable cross-device alignment remain open. |
| Restart in neighbor's house | Retain preferences/goal but reset live location; ask a specific clarification or request stationary evidence | Relay unknown-place rejection passes; native unknown snapshot tests prepared; real matching/recovery unverified. |
| Change goal while answer is pending | Cancel stale output/directions; current goal wins while return context is retained | Revision guards exist; device timing and complete outing history remain open. |
| Hazard during rich speech or storage | Immediate local warning; ordinary description interruption recorded; no model/network dependency | Source bypass and receipt adapter exist; measured interruption/latency required. |
| More/less information and repeat | Honor word/time and frequency controls independently of VoiceOver speed; requested repeats remain useful | Budget/source tests prepared; category/mode controls and comprehensive speech arbitration incomplete. |
| Approve or reject room change | Exact revision-bound approval, recoverable failure; never silently rewrite geometry or room identity | SQL tests pass; native transaction/UI tests await Mac. |

The shared understanding to build is: where we have evidence the person is, their purpose, what changed, what is known versus last seen, what has actually been communicated, and what remains uncertain. Optimize useful choices and fewer unnecessary follow-ups alongside latency and clutter. Do not infer expertise from VoiceOver rate or treat a companion as proof of clearance.

## Mac execution and staged trials

1. Verify the archive manifest. Run `node tools/mac-preflight.mjs`; select the correct full Xcode installation. For image support use `--multimodal` and the documented compatible SDK. No automatic Docker step is required.
2. After starting Mac verification, run `npm ci --ignore-scripts`, then `npm run mac:setup -- --ui` (add `--multimodal` for the image build). The script runs serial Node checks, both Swift packages, simulator/device builds and hosted/UI tests with parallel testing disabled. Keep failures and skipped capabilities visible. Native RTAB-Map dependencies are a separate larger build.
3. Adult iPhone trials begin **eyes open**, comparing every description and direction with surveyed truth, including network/storage/tracking failures. Use harmless simulated hazards. Record model, OS, app build, map revision, timestamps, unexpected speech, missed useful facts and recovery burden.
4. Test eyes-closed interaction **seated** first. Adult walking with eyes closed needs a separate sighted observer in a controlled area; do not use actual drops or stairs to discover failures.
5. The brother's first sessions are supervised seated descriptions and preference/word-budget feedback. Child mobility requires bench/adult results and the guardian/O&M-reviewed Q04–Q06 protocol. Independent mobility readiness has not been established.

Do not mark M2/M3 or the broad implementation tasks complete from these contract tests. The tracker retains localization/floor/body alignment, temporal people/object changes, full speech arbitration, return history and physical verification as explicit work.
