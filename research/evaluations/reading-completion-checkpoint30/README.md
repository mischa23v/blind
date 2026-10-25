# Checkpoint30 — finite captured-text playback completion

This repair separates obtaining one captured text source from finishing its spoken output. A validated immutable source no longer expires while waiting for the ordinary word budget or a slow speech callback. It does not become a fresh camera observation.

## Behavior and ownership

- Camera capture admission remains 0.5 seconds; unfulfilled acquisition remains bounded by the existing 60-second request deadline. The global reference-reading deadline for other callers is unchanged.
- Installed text remains finite under the existing source/phrase limits. One source-owned cancellable wake uses the real shared word-budget ledger's release deadline. It does not reserve extra words, invent expected speech duration, retry on every frame or complete an utterance.
- Changing the words-per-minute setting reschedules the same reader instead of discarding its unread text. Ordinary dispatch, urgent-hazard, foreground, privacy and source-epoch controls remain in force.
- Only exact successful speech callbacks advance the cursor. One session-bound terminal receipt retains random source/request identity and phrase counts, with completed or cancelled outcome. It contains no OCR text, image or hash. Empty/uninstalled sources cannot create a completion receipt.
- Explicit privacy/history deletion and session retirement clear retained terminal metadata. Retired acquisition and speech callbacks cannot recreate ownership. Stop/hazard may retain an incomplete result within the current eligible session.
- Acquisition informationReady remains separate from delivered output; neither automatically completes a real-world goal.

## Evidence interpretation

The frozen regression uses 100 authored words with a 30-word budget, a successful callback delayed beyond 60 seconds, explicit revocation and the extracted production pacing setter. The old source fails eight assertions across four checks; the lifecycle negative passes. Initial incomplete witness setup failed to compile before its support-copy path was corrected; that is not counted as a production regression.

The final focused suite includes 44 Swift checks, including unchanged global reference-reading regressions, metadata receipt outcomes and extracted native privacy/session methods. Eleven separate wake-ownership assertions exercise extracted native methods with explicit clock/task substitutes. Four Node checks include negative source mutations. These are portable/source-projection results, not actual device playback, OS timer scheduling or native Vision callbacks.

The first full Node run completed 491 checks: 490 passed, one extracted search-clue fixture failed compilation because it lacked the new captured-reader purge boundary. A four-line, two-fixture repair adds an explicitly substituted purge invocation counter and an assertion that conversation deletion calls it exactly once. This separate fixture is invocation coverage, not evidence of purge semantics; the dedicated extraction checks execute the actual purge and clear methods. Production bytes and the successful 1,291-test Core result are unchanged.

Final aggregate results and exact changed-file hashes are recorded separately. Raw local logs remain private; public summaries are selected/redacted evidence, not verbatim full logs or a workspace inventory.

## Native acceptance and remaining scope

On the exact reviewed app revision, read an authored page longer than one minimum-budget interval. Verify actual speech callbacks, complete ordered coverage, a slow callback beyond 60 seconds, pace changes while speaking and waiting, cancellation/replacement, hazard, background/private-route retirement and deletion followed by late callbacks. No elapsed timer alone may mark playback complete. Verify assistive-audio intelligibility and user pacing on a device.

Source-bound repeat/clarification after completion, menu interpretation and whole-document navigation remain separate work. This change does not connect retained page text to model understanding, authorize unrelated narration-history replay, add background sensing, persist source content or establish physical safety/task success.
