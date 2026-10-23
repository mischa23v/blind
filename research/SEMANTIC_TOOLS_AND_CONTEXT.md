# Semantic reads, stable profile and reported task progress

This checkpoint extends the existing local model's bounded read-only tool loop. It does not replace conversation with a feature-command menu. It does not certify recognition accuracy, on-device FoundationModels tool selection, physical guidance, VoiceOver behavior or all-day operation.

## Production changes

- Model-selected Saudi-note, isolated-colour, familiar-person and OCR reads reuse existing native controllers. Runtime availability, original release profiles, consent, foreground/privacy, capture pose/time and cancellation still gate them. No new recognizer, model weights, cloud provider or automatic gallery enrollment was added.
- Currency returns only the exact accepted denomination receipt. Unsupported rewritten values, totals and conflicting appendices are rejected. Colour is anonymous isolated-area appearance, not proof of the requested outfit. Familiar labels are tentative, with enable/gallery generation rechecked through playback. OCR is an attributed past snapshot.
- Generic and specialized reads share a bounded native-work exclusion. Native Vision retains its own permit even when its caller is cancelled. A late result cannot cancel the current goal. Speech depends only on visual receipts used by its sentence, not unrelated expired reads.
- `CompanionModelContext` reconstructs mandatory assistant identity, saved preferred name, audience and active goal/revision for every production model entry, retry and bookkeeping session. Required values are whole or the call fails explicitly; optional old context cannot displace them. Stable profile is edited in settings, never silently overwritten by game names or quoted names. Audience is a communication setting, not proof of age or supervision.
- The bounded open/close action ledger ingests direct reports before generation. Proposed, actually spoken, user-reported and sensor-confirmed are distinct; no sensor-confirmed constructor is exposed. A report such as opening the fridge retires the repeated suggestion without declaring the physical door state verified.
- Generic step progress uses a model-associated full direct user report plus the exact current step. This advances conversational bookkeeping only, not whole-goal completion or verified possession. Questions, negations, quoted/third-party/game speech and ambiguous bare “done” are rejected. Semantic association can still be wrong; the model's interpretation is explicitly unverified. Source deletion removes its association. This is not a universal action detector.
- Geometry runs as a DEBUG-only diagnostic after alert publication and skips urgent/unknown-monitoring frames. It never enters model facts, speech or route permissions. See `GROUND_GEOMETRY_EVIDENCE.md` for preserved holdout failures.

## Reproducible cloud checks

Run `swift test --package-path BlindCore -j 2` and `npm test` with `BLIND_SWIFTC` set to a compatible Swift compiler so extracted-source tests do not skip. Run `python3 tools/prepare-working-state-replay.py /tmp/new-working-state-replay` using a new directory, then the printed Swift command. That executes the exact platform-neutral application working-state source and its hosted test methods, not a rewritten toy state machine.

`tools/test` also includes source wiring assertions. Those are explicitly not Apple SDK compilation. `research/SEMANTIC_MEMORY_REPLAY.md` distinguishes authored inventory and recorded annotation injection from recognition. `tests/scenarios/companion` preserves input/rubric/result provenance, including failed usefulness criteria; its validator checks package integrity only.

## Actual native model batch route

The app-hosted `CompanionNativeReplayTests.testInputOnlyConversationBatch` invokes the actual `LocalImageAssistant.converse` context/tool/working-state path. It is outside the child UI. It does not read an oracle or expected answer. It replaces sensor reads with explicitly scripted receipts in the test process only.

In the Xcode test scheme, set:

- `BLIND_COMPANION_REPLAY_INPUT`: absolute readable input JSON path.
- `BLIND_COMPANION_REPLAY_OUTPUT`: absolute writable result JSON path.
- `BLIND_REPLAY_SOURCE_REVISION`: exact tested commit/configuration identifier.

Run only `BlindAssistTests/CompanionNativeReplayTests/testInputOnlyConversationBatch`, either using Xcode or the equivalent `xcodebuild test -project ios/BlindAssist.xcodeproj -scheme BlindAssist -destination '<your installed simulator destination>' -only-testing:BlindAssistTests/CompanionNativeReplayTests/testInputOnlyConversationBatch` after setting the test-scheme environment. Do not assume shell environment alone is forwarded to the test runner. Paths must be accessible inside that runner. Physical iPhone sandbox file placement needs a separate test-host setup; this is not claimed to be a turnkey phone-import UI.

Input schema: a JSON object with `episodes`, one to 500 entries. Each entry has `id` and `user`; optional `language` (`en`/`ar`), `preferredName`, `audience` (`general`/`adult`/`childWithGuardian`), `goal`, `priorUserReports`, and `receipts`. Each receipt has `capability`, optional `text`, `amount` and `ageSeconds`.

Supported scripted receipts:
- `currentObservation` or `readText`: text becomes an attributed captured-view OCR candidate, not measured position.
- `savedMemory` or `navigationState`: historical text only.
- `saudiBanknote`: supported integer amount, still subject to exact receipt policy.
- `isolatedColor`: known colour enum string, anonymous appearance.
- `familiarPeople`: tentative enrolled-label string.
- `deviceClock` is deliberately not fabricated by this runner; separate production clock tests cover it.

Episodes are independent; prior reports are user context, not replayed earlier model outputs. This batch does not test camera acquisition, real image recognition, continuous multi-turn listening, live physical completion or native speech delivery. Availability/language skips are not passes. Result records include input hash, OS, source revision, pipeline status, actual requested tool calls and latency. Preserve first outputs before exposing hidden oracles or changing code. A text response test, a policy test and a live device test are separate evidence levels.

## Remaining device and product checks

First tab source remains one settled reply, no history, diagnostics, testing controls or token updates. Actual VoiceOver focus, speech arbitration, barge-in, background recovery and privacy changes must be observed on the device. Test the same meaning with changed wording and changed circumstances with different expected results; do not tune code solely to a known scenario catalog.

Known gaps remain: real Apple SDK compilation and model availability/quality; native timing and camera/sensor alignment; lexical memory retrieval without a general synonym/translation engine; incomplete map provenance retention; target association for garments/objects; measured safe movement and handling; general task completion beyond source-attributed reports; real perception stress tests and sustained battery/thermal performance. General conversation remains available but must not invent the physical world when sensor evidence is absent.

### Portable input-adapter batch (no model)

`swift run --package-path tools/semantic-input-replay CompanionInputReplay INPUT.json OUTPUT.json` accepts the same input schema. It executes the production Core context policy, exact exported production conversation instructions, direct action-report reducer, typed receipt validation and bounded tool runtime. Calls are deliberately scripted over advertised capabilities, not semantic model selection. Output records this limitation. More than three supplied capabilities hits the real per-turn call cap; a long user string used as scripted query can hit the real query cap. These are adapter observations, not evidence that the model would make those calls.

Regenerate the exact instruction assembly with `python3 tools/export-companion-replay-template.py` only when deliberately changing the candidate, then freeze its hash before selecting new held-out cases. Do not re-export a changed prompt halfway through a supposedly frozen run. Keep output collection and hidden-rubric grading separate. The same structured data can subsequently be supplied to the app-hosted native batch route.

## Post-first-200 correction candidate (not yet native acceptance)

The archived first-run candidate is unchanged. Its actual Core replay and cloud-response baseline revealed a presentation contract that required technical OCR/image-classification wrapper text to be spoken. New receipt construction uses concise English/Arabic uncertain snapshot wording, retaining the complete quote, source, timestamp, expiry and all physical/money rejection rules. This is not permission for arbitrary model paraphrases. The general conversation instruction now respects an acknowledged announcement or request not to repeat it while allowing a new explicit question. Its behavioral effectiveness requires a new frozen run, not a claim from the source change.

The consumed replay also collapsed descriptive scene ground truth and actual OCR into the same OCR receipt. Fresh spatial/action/clearance-containing descriptions were filtered and misleadingly called stale. Neither elapsed-time tuning nor removing risky clauses is an appropriate fix. The replay schema now supports explicit `payloadKind` values: `ocr`, `appearance` (only for currentObservation), and unsupported descriptive inputs, which yield no observation. Missing payloadKind retains the original legacyOCR behavior for reproducible comparisons and is explicitly reported in output. Use typed appearance only for an actual/simulated image-category candidate, never to bless sighted ground truth, route geometry, target association or clearance. Coverage limitations and unknown sensor fields belong in structured fixture metadata, not OCR strings. Do not rewrite the archived input or remove negations to obtain a passing result.

The new receipt-presentation tests verify bilingual full-quote preservation, exact evidence association, expiration, forbidden movement/money claims and resistance to rewritten/escaped quotes. These are production Core tests, not Apple model, recognition or VoiceOver measurements. All original response omissions, technical speech, repeated-person behavior and input-correction disclosures remain in the archived first-run report.

Tool failure status now distinguishes `rejectedEvidence` from `stale`. The former covers otherwise fresh policy/provenance/type/shape-invalid candidates; stale is reserved for receipts that satisfy the same validator at their original observation time and are now expired. This comparison does not renew any lease or expose rejected text. Mixed successful reads still contain only valid records. Nine focused tests cover malformed, future, invalid-lease, wrong-source, policy-invalid, genuinely old and mixed evidence. First-run statuses remain unmodified in their original results.

Post-correction regression receipt: 865/865 Core and 308/308 serial Node tests passed, with zero skipped Node tests. Default and DEBUG/familiar native syntax parsed; this is not Apple SDK typechecking. A rebuilt portable adapter executed five known smoke inputs covering both languages, OCR/appearance distinction, unsupported descriptive input and policy rejection. Previous regression logs retain the obsolete stale/source-string expectation failures; no independent behavioral improvement or native model result is inferred from these code tests.
