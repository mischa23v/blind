# Native integration proposal, NOT implemented

## Reachable source paths inspected

- `ios/BlindAssist/VisionService.swift`: existing `textLines` backed by Apple Vision for image OCR; `NavigationModel.readWholePage` invokes the actual local reader and sorts lines.
- `ios/BlindAssist/NavigationModel.swift`: `readSpecializedCompanionTool(.readText)` supports short captured OCR; `readWholePage`, `documentReadingChunks`, `speakNextDocumentChunk`, `readingCaptureAllowed` and `feedback.onRequestedSpeechFinished` form the current document reading path. These methods are reachable, but are not an exact-model manual selector or PDF extractor.
- `BlindCore/Sources/BlindCore/CompanionEvidence.swift`: generic `CompanionToolRuntime` sanitizes and bounds model-facing evidence, including dropping whole oversized records. It is unsuitable as storage for the complete reference answer.
- `BlindCore/Sources/BlindCore/SpeechDeliveryLedger.swift` and native `Feedback.swift`: existing real speech lifecycle, exact attempt tokens, interruption and unknown completion handling. Timers never establish successful narration.

## Proposed minimal wiring

1. Keep the original request ID/generation and original system uptime when the user starts an explicit source read. Capture the exact selected source ID, revision, byte digest, media type and (for a manual) independently verified exact model. A name/model guessed by an LLM cannot fill these fields.
2. Have the existing local OCR reader produce complete ordered source blocks plus extraction-owned body ranges and source/page locators. Keep them in `CompanionReferenceSource` outside the model context. Do not feed the full source through `CompanionToolRuntime` and mistake its budget-limited return for the source. This proposal does not alter that runtime's other readers.
3. `CompanionReferenceReading.prepare` takes an exact requested search phrase and the original request timestamp. A heading-only phrase does not match. A body match retains ALL supplied blocks, not only matching sentences. Source selection/section completeness is an adapter responsibility and is not inferred by the core.
4. Dispatch only after existing ordinary-speech admission and word-budget checks permit the entire next attributed chunk. Use cancellable synthesized speech, the chunk's exact requested ID/text, and the existing speech ledger. Bridge the actual ledger `Completion` from `Feedback` to `complete`, then freshly check source, request/session, foreground, quiet/hazard and monotonic time before another dispatch. This is not wired here: `Feedback` currently exposes requested ID/text/outcome rather than the full `Completion` needed by the new Core API.
5. On interruption, quiet, hazard, source replacement, a new question, foreground loss or expiry, call `withdraw` and stop only its exact requested speech ID. Do not pause/resume, reconstruct with a new issued time, replay cancelled chunks, or stop independent sensor hazards. Revalidate during active playback and at dispatch/completion. Reaching the 60-second limit leaves the source intact but the reading withdrawn, not complete.
6. Keep original block/source/locator trace in local diagnostics; use simple spoken attribution. Never pass a quote to a route, reaching or control-operation API. Manual prose can only be reported as source text, not present appliance state or permission to act. No LLM paraphrase may replace any source block.

## Explicit missing adapters and validation

No exact-model manufacturer-manual/PDF selection/extraction adapter exists in the inspected native tree. The new Core class does not make that capability available. A validated local PDFKit/Apple Vision adapter, source-byte hashing and trusted model association are still required; do not add a new OCR recognizer/model or claim cloud replay is native execution. No native source changes are included because coordinated NavigationModel/Feedback work belongs to the main integration owner.

Native builds use the existing Apple `NLTokenizer` API for chunking and word counts, matching document admission. Portable builds reuse `SpeechDeliveryLedger`'s letter/number convention because NaturalLanguage is unavailable on Linux. The two platform branches still need Apple-device tests; portable passes do not verify the native branch. The current authored fixtures cover English/Arabic and hyphens, not all writing systems. The reconstruction itself is not battle-tested or a recognition accuracy result.
