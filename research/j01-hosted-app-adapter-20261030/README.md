# J01 actual hosted app adapter — narrow implementation, not executed acceptance

This adds an actual `NavigationModel.receiveCompanionUtterance` consumer for **three unchanged authored scripts**: REQ-SC02-1, -3 and -4. No generated reply is injected. The existing app controller invokes its real `LocalImageAssistant`, response authority, cancellation and silent Feedback queue. Input is checked byte-canonically against the three original scripts before constructing the controller; only the current utterance reaches the app, not future script/acceptance text.

The original 400-record ledger is untouched. The other 42 previously authored scripts and all 315 blocked domain scripts are unsupported by this adapter and refused, not passed. The implementation intentionally does not invoke arbitrary sensor/action requests or manufacture model availability.

## Boundary and evidence

Three additive DEBUG insertions in NavigationModel enable an explicit XCTest+ephemeral-simulator-only session/silent sink and bounded actual model-return metadata. Default/release behavior is unchanged. The hooks do not inject clock/pose/reply/tool outputs. Existing real model deadlines, generation IDs and admission checks remain unchanged. Provider availability is sampled before each actual dispatch; a provider reporting available can still return `generationFailed`. Actual return status/failure, cancelled/current-request state and text-presence are retained separately. Raw model text (bounded to4096 characters, with truncation labeled) remains only in `model_return`. `actual_reply` stays null unless the real accepted-display callback recorded a settled receipt matching the final controller current display’s request, session generation, lease, revision and exact nontruncated text. Streaming previews, replaced/retired/expired displays and raw current/cancelled returns cannot populate it. It is labeled accepted settled display, **not audio delivery**. The callback ledger is capped at64 and cap status is visible.

Event dispatch uses real monotonic offsets; snapshots before/after dispatch and a final bounded observation retain actual request IDs. The final model observation window is 20 seconds, shorter than the existing production deadline: a missing return remains unavailable/time-out, **not a model or journey pass**. Cancelled/retired replies remain evidence, never delivery. A result can contain text while its semantic quality is still unscored. Empty tool receipts mean **not instrumented**, not proof that no tool was called. Sink queue counts are not audible output. No actual speech is synthesized. Full model/native drain is not attested; process termination is not a cancellation acknowledgment.

799's separate historical tests reported provider available but generationFailed; this adapter does not assume that failure is fixed.

## Future authorized execution

No Swift/native/model execution occurred during preparation. Eleven Python controls ran (including negative subcases); they validate transport/source structure only. A fresh reviewed simulator build must include the new hosted test in the generated Xcode project. Use a dedicated empty simulator, no accounts/user memories, and a reviewed exact build receipt. The wrapper requires:

- `BLIND_J01_EXECUTE_PREBUILT=1`, `BLIND_J01_CONFIG=/absolute/config.json`;
- config `source_commit` (actual built commit, **not** the older 799 source closure), `simulator_udid`, `ephemeral_simulator_no_accounts:true`, `xctestrun_path`, `xctestrun_sha256`, and fresh `attempt_dir`;
- one request JSON line on stdin, `instrumented-app-jsonl-v1`, exact supported script, the same actual built source commit and all three constraints false.

`app_adapter.py` selects only `BlindAssistTests/HostedNonvisualJourneyTests/testExplicitHostedJSONLJourney` from one v2 prebuilt `.xctestrun`. It invokes test-without-building on the explicit simulator, no parallel tests; it can deploy the prebuilt test app to that simulator. It does not build, install dependencies, download models, run paid services or alter workflows. The descriptor hash is **not independent executable/source attestation**; preserve the reviewed build receipt. Response `claimedSourceCommit` and `sourceAttestation.verified:false` explicitly preserve that gap; protocol `source_commit` echo is correlation only and cannot be scored as source verification. No fabricated build commit is supplied by this packet.

The host runner observes a 55-second process budget and 8 MiB sampled log budget, with process-group termination on failure. This is not hard preemption of an individual native operation. The original research harness has a 30-second default transport limit: do not blindly invoke this wrapper through that default; a separately reviewed 60-second transport call is needed (existing `invoke` supports up to60). Native startup exceeding the bound stays failed/unavailable, not automatically retried. Attempt input, log, process metadata and produced response stay in the fresh private directory. No upload/publication occurs.

## Still incomplete

No model journey has run; no joke/homework correctness, actual microphone/VoiceOver/audio delivery, whole-family completion or safety is claimed. Runtime tool-call instrumentation and independent semantic observers remain missing. Actual local model failure may remain. These three scripts exercise typed nonvisual app requests and actual interruption/replacement; they do not cover persistent privacy deletion, virtual-time expiry, background speech attribution or delayed callback injection. Other scenario IDs remain blocked until their real adapter exists.

An additional authored XCTest exercises the actual receipt-selection helper against current, old-request, streaming, wrong-revision/lease/text/generation, truncated and retired fixtures; it has not been executed.

Integrator must apply the three small NavigationModel insertions, not overwrite concurrent source edits; add the test through canonical project generation. No production scheduler, permission, timeout, physical authority or user-data-retention change is introduced.
