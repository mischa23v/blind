# Live application update — 2026-10-25

The three reference Core/source/fixture files and supporting reconstruction evidence were applied after verifying every target path was absent. No existing Core or native file was overwritten. Production Core remains byte-identical to the reviewed source. Diagnostic-only authored test assertions were changed to boolean checks so failures cannot print unexpected source text or speech objects. The original reviewed archive and initial failure logs are preserved.

Fresh merged-snapshot verification passed 75/75 focused Core checks, 5/5 real-PDF Core replay checks and 4/4 adapter rejection checks; the expected real-source generic-path failure was reproduced and retained. Source and support files are frozen. Verification is recorded separately in `merged-apply-verification.json` and `logs/merged-apply/`. Native exact-model manual/PDF and real speech-receipt adapters remain absent. These focused results are distinct from the merged aggregate recorded in research/rebuild-evidence/checkpoint-07/verification.json.

## Original staged verification record

# Reference reading restoration checkpoint

Status: **staged Core implementation, portable tests passed; native integration incomplete**. No live repository source was changed by this work. No commit or push was performed. These are newly authored reconstruction results, not recovered historical source or the historical 237-reference-test result.

## What is staged

- `BlindCore/Sources/BlindCore/CompanionReferenceReading.swift`: exact selected source/revision/digest/media/model binding; extraction-owned body ranges that exclude heading-only relevance; complete ordered source records retained outside the model budget; byte-preserving attributed chunks of at most 35 words; original monotonic 60-second lifetime; existing `SpeechDeliveryLedger` attempt/completion fencing; terminal withdrawal on interruption, quiet, hazard, source replacement, new question, lifecycle loss or expiry. No resume/renewal, model paraphrase, source recognition model, or physical-guidance API.
- `BlindCore/Tests/BlindCoreTests/CompanionReferenceReadingTests.swift`: 23 authored synthetic Core tests. They call the real Core ledger with simulated completion outcomes, not native audio callbacks or live sensors.
- `BlindCore/Tests/BlindCoreTests/Fixtures/reference-reading-authored.json`: complete invented washer-text fixture, explicitly not manufacturer content or historical input.
- This folder: exact failure witness, native integration proposal, reproduction script, snapshot hashes, test logs and machine-readable verification.

## Executed evidence

Toolchain: Swift 6.4.1, x86_64 Linux, serial `--jobs 1`, separate disposable source/scratch/module caches. Final reruns also route package/config/security caches into writable dedicated directories.

1. `ReferenceLegacyFailureWitnessTests`: **1 test, 1 expected failure, exit 1**. The untouched generic model-tool runtime retained only 1 of 4 authored full reference blocks. Raw output: `logs/01-fail-before.log`. This witness is intentionally preserved outside the final passing target; the generic model-context budget remains unsuitable for full reference delivery.
2. Final focused and affected checks: **75 tests, 0 failures, exit 0**, including the 23 new reference tests. Raw output: `logs/05-final-focused-and-affected.log`.
3. Final full portable package snapshot: **963 XCTest tests, 0 failures, exit 0**. Raw output: `logs/06-final-full-portable-package.log`. These are tests in the copied source snapshot identified by `TESTED_SNAPSHOT_SHA256SUMS.txt`, not a claim about a later merged tree, native app, live microphone, recognition accuracy, or 400 integrated scenarios.
4. `bash -n reconstruction/reference/reproduce.sh`: exit 0. Individual commands were executed as logged; the final wrapper script itself was syntax-checked, not rerun from scratch after assembly.
5. Scoped independent source review found two issues before final testing: retained metadata was not fully bounded, and a blank/control-only model label could pass. Both were fixed with regression tests. Final reviewed Core SHA-256: `5d4ae5c5d13ecb7889e20369b61b971ac645e721fd1396c5a50bf09ebdb4422f`. The final attributed chunk text is independently recounted before acceptance.

Earlier successful logs are retained to show the actual progression; they do not supersede the final runs. No failures were changed to passes by weakening the legacy witness.

## Official PDF extension

The source-only checkpoint was protected before this extension. A pinned official Bosch WAT28400UC PDF was extracted locally, checked against its exact cover model and visually reviewed page, then passed through actual Core reference/ledger code. All 699 original section bytes survived five attributed chunks; 5/5 optional Swift replay tests and 4/4 Python adapter rejection checks passed. The real-source generic-path witness retained 0/1 records and failed as expected. Playback callbacks/timing are synthetic. Raw PDF/full quotations remain outside the source tree; only adapter/tests and redacted hashes/counts are included. See `OFFICIAL_PDF_REPLAY.md`.

## Still missing, explicitly

- No native exact-model manufacturer-manual/PDF selector or extractor is present in the inspected source. This is NOT a completed R39/R40 native restoration. Existing Apple Vision OCR and document speech paths are reachable and documented in `NATIVE_INTEGRATION_PROPOSAL.md`, but this Core sequence has not been wired into them.
- Source-byte SHA-256, independently verified model association, complete-section extraction and body-range correctness are adapter responsibilities. Equality of supplied identity metadata is not independent proof of those inputs.
- `Feedback` currently exposes requested ID/text/outcome rather than the complete ledger receipt needed by this interface. A reviewed native bridge and exact-ID cancellation wiring are still required.
- Apple `NLTokenizer` is reused conditionally on native platforms; Linux uses the existing speech-ledger word convention. Apple tokenization, SDK typechecking, admission budgets, real callback ordering, interruption latency, VoiceOver and device behavior were not run.
- One bounded official manufacturer PDF text-layer replay has now run: 5/5 Core checks, with simulated playback, plus a separately preserved real-source failure witness. See `OFFICIAL_PDF_REPLAY.md`. No photograph/OCR accuracy replay or on-device model run was performed. No source/model weights or dependencies were installed.
- The complete original source remains retained if reading expires, but undelivered chunks are not counted as spoken. There is no automatic resume; an explicit new request must create a new operation.
- A quoted manual is not current appliance state, control identity, reachability, safe operation or physical movement authority. Independent sensor hazards are not cleared by reference withdrawal.

## Integration and protection

Overlay only the three new `BlindCore` files after review. Preserve the evidence folder as documentation. Do not overwrite coordinated native files, model/runtime budgeting, memory, spatial or clock patches. Rerun the focused tests and whole merged package on the final integration source. The supplied tree has no Git metadata, so no tested commit is claimed; use source hashes until the main workflow assigns and verifies a commit.

The package contains authored source, fixtures and text evidence only: no binaries/build cache, downloaded PDF, private image, credentials, user data or long manufacturer quotations. The initial source-only WIP ZIP remains separately preserved; this checkpoint supersedes its untested status without changing that earlier artifact.
