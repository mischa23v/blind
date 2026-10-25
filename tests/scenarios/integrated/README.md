# Current execution and publication boundary

The latest receipt catalog records **372 unique partial code sequences / 3,078 steps across multiple source snapshots**, not 400 complete scenarios. The final 32 (20 scoped memory, 12 attention) ran on the current post-checkpoint17 source snapshot on 2026-10-25, with exact source hashes and zero failing XCTest methods. This does not rerun the prior 340 against the latest source. Four additional frontier-plus-tool text episodes / 23 authored child turns were independently reviewed on their own earlier pinned source. Neither category is native/device validation.

Original eight Core recovery failures and native fail-before evidence remain unchanged. Four benign-refusal guard rejections in the frontier batch remain findings. Background cancellation in that batch was ignored by evaluator choice, not an attempted mutation rejected by the dispatcher. Wrong-item completion and stale output-dispatch attempts were not exercised in that four-episode batch.

Source-owned test input identities, RGB values, OCR strings, user utterances and state transitions are authored fixtures, not measured scene evidence. Public deterministic partition labels do not establish an independent held-out benchmark. See the publication manifest and receipt paths for exact provenance and limitations.

# Integrated episode reconstruction, staged

## Honest result boundary

This is **not 400 completed user episodes**. The requested full conversation pipeline remains unexecuted where actual local model, camera/perception, calibrated wearer localization, speech delivery and device availability are absent. Every absent LLM turn says `NOT RUN`; no authored assistant conversation is passed off as model output.

The surviving corpus is inventoried in `surviving-corpus-inventory.json`. It contains 53 family requirements, V3 12 multi-turn journeys (60 turns), 3 followups (12 turns), response fixtures and consumed development examples. Its historical ledger explicitly says production/native execution was not performed. Those turns and text responses are not added to the episode count below.

`coverage-obligations.json` provides 400 requested slots: 40 executable authored navigation cases and 360 planned requirement obligations. The latter are **plans, not concrete complete executable scenarios**, not passes, and not claimed distinct physical journeys. This deliberately preserves the actual deficit instead of filling it with generic model answers or fabricated maps. Supplementary recovery/feature sequences are separate.

## What the runner really executes

- Actual production `ConnectedJourneyCoordinator`, registered map hierarchy, existing route planner, collision checks, exact pose/ticket ownership, return question delivery ledger and persistence snapshot types.
- Actual unmodified native `ConnectedJourneyRuntime`, projected into the portable Swift test module; its existing helper tests lose only `@testable import BlindAssist` to compile in that module. Native runtime Foundation code runs, not Apple camera/audio/model frameworks.
- Actual contextual capability scheduler, color estimation, OCR text-selection and familiar encounter bookkeeping adapters. Inputs are authored flags/RGB/text/consented identity IDs, not verified perception.
- Existing authored fixture helpers construct three distinct registered maps, floor transformation and doorway/elevator portals. Every map/pose/support/obstacle datum is marked AUTHORED_PLUMBING. There are no invented photos or borrowed LiDAR.

Forty initial navigation sequences cross four destinations with ten behavior variants. All include goal/start, outbound progress, return-reference ambiguity and return or blocked-return outcome unless the trace explicitly stops at a failure. State and exact capture/session/goal/artifact/ticket identities are recorded per step; source hashes are pinned. Portal movement is withheld; test-input endpoint association is not physical traversal. Trusted-interface actions are selected by harness, not inferred by a model from utterances. In-memory persist callbacks test value transitions, not disk durability. The runtime regressions separately exercise real asynchronous owner IO with existing in-memory IO fixture.

Seeds select a reproducible development/held-out **partition only**. Fixture code is public and already used in prior development. This is not independent model-held-out accuracy, random real-world coverage or a statistical assurance claim. UUID ownership IDs are intentionally fresh on each run; compare semantics and source hashes, not byte-identical UUID strings.

## Preserved failures and acceptance distinction

Initial 40-case Core run: **32 passed, 8 failed**. Invalid support or camera-only heading correctly rejected input and retired output; fresh valid pose alone left no executable route. The failed originals remain unchanged in evidence/run-02. Eight supplementary explicit-replan sequences passed, proving only API recoverability, **not automatic native recovery**. They do not replace the failed cases.

The actual native regression then independently confirmed **two automatic-recovery failures**: wrong-support and camera-only-heading both recover a fresh exact-session capture but `next` throws `noRoute`. Runtime `accept` plans only when currentLeg is nil; rejected evidence removed the inner route while leaving that leg. No manual plan occurs in this acceptance regression. Root/reviewer/fix owner were informed. Product expectation is automatic useful recovery, not a hidden UI or harness plan. A separate unknown-mid-leg test requires withholding rather than inferring the old start.

Original Core run-02 is a historical contract-assumption replay, not a substitute for native acceptance. A conservative production fix may retire the itinerary and make the direct Core replay stop without arrival, which does not itself prove automatic recovery. Judge the native regression separately.

No production source changed in this stage. Expected outcomes are not rewritten to make production pass. Failures, rejected source input, unavailable adapters, missing audio, device/model not-run and exact command exits remain visible.

## Reproduce

Set PATH to an installed verified Swift 6.4.1 toolchain. No installs, Docker, weights or network are needed. From this directory:

    ./run.sh /path/to/reviewed/source /path/to/new-evidence

The runner copies source into a unique projection under TMPDIR (default /workspace/shared/blind-test-tmp), hashes input sources, uses private writable Swift caches and two compiler jobs, then writes logs plus JSON traces. It intentionally exits nonzero while the original failures persist. Never reuse an evidence directory, and never overlay a production tree.

To run only native acceptance, supply third argument:

    ./run.sh SOURCE NEW_OUTPUT 'ConnectedJourneyRuntimeTests.testIntegrated'

For actual-code feature traces:

    ./run.sh SOURCE NEW_OUTPUT 'IntegratedFeatureEpisodeTests'

Regenerate blocked coverage/inventory explicitly with:

    python3 build_coverage.py SOURCE OUTPUT

Raw ARKitScenes/OAS assets stay external. `dataset-provenance.json` pins their source metadata and clearly records nonuse. Their real/ authored provenance is unrelated to the synthetic navigation fixture. Never attach their images/poses to this fixture or claim the source camera trajectory is calibrated body localization.

## Remaining work before claiming 400 full episodes

1. Apply only independently reviewed source fixes; rerun native recovery with same expectations and old failure receipts.
2. Replace each blocked obligation with a concretely specified, multi-step, adapter-bound input sequence, expected result frozen before execution, and actual complete trace. Coverage slots alone do not satisfy this.
3. Wire actual local model/context/tool dispatch and record exact request and returned answer, source and age, retirement/delivery and outcome. No model response was run here.
4. Complete calibrated localization/source registration and real device/Apple perception/audio tests, with legitimate paired data, no guessed uncertainty/support/floor/body transforms.
5. Verify color, currency, familiar identity, OCR, household inventory, task/memory privacy, controls, offlining, unknown areas, physical handling and all 53 goals end-to-end. Portable adapter success is narrower.
6. Retain failure conditions and conduct supervised validation separately. No overall safety, recognition accuracy, physical task success or unsupervised-use claim follows from this suite.

## Later candidate check (not live integration)

`evidence/run-06-candidate-native-recovery` overlays only the reviewed worker's staged coordinator/runtime into the isolated original projection. Exact native acceptance expectations are unchanged. Both recovery branches pass, and the unknown-midleg negative remains withheld: 2 XCTest methods, 0 failures. This is not a final-live-source rerun or a change to the eight preserved Core outcomes. Candidate hashes are recorded in that run's input-hashes.txt. Await root-selected final integrated source for the next independent rerun.

`evidence/run-05-features-and-unknown` records the eight lease sequences and three content/encounter adapter sequences, plus unknown endpoint withholding, all passing actual code checks. Source age where no captured image exists is not applicable, not assumed fresh. Pixel/text/identity values are authored input only.


## Nonvisual goal-directed scenario specifications

[Five authored nonvisual goal journeys](nonvisual-goals/README.md) preserve independent actor/evaluator inputs and separate usefulness, safety and actual goal outcome. These are source-only fixtures: zero application, model or device executions. A safe abstention is not a completed task.
