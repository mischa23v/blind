# Captured-page retained review: native component follow-up

Status: source prepared and independently reviewed against published checkpoint32 0caea7dc8b529724545de7affb9bb65006175304; native SDK compilation/execution is pending. Eight static contracts and JS/bash/Swift syntax checks pass. The successful checkpoint30 component probe and its earlier compile failure remain unchanged.

This separate test imports unchanged checkpoint32 Core and uses a test-owned AVSpeech bridge. Acquisition is an explicitly authored 40-word fixture, not camera/Vision. The fixture must prepare exactly two parts; any different count fails rather than changing the scenario.

## One fixed sequence, unchanged 480-second bound

1. Queue the first part. Repeat must fail before any real onset without treating queued text as heard.
2. Complete both original parts through actual AVSpeech didStart/didFinish. Retain the original source and the completed two-part receipt.
3. Request the previous part with a new request/selection/phrase identity, retaining the same source/revision and original timestamps.
4. At its actual didStart, request repeat with new playback identities, then ask the synthesizer to stop the old utterance. The actual old didCancel payload/context must be rejected by Core without advancing, pausing, withdrawing or replacing the new owner.
5. Complete the repeated first part; explicitly request next and complete the second part.
6. Clear source/cursor authority and verify review cannot revive it. Preserve the original completed receipt independently of later attempts.

Expected component evidence: five actual starts, four actual successful completions, one actual cancelled old utterance, and four playback attempts sharing one original source. All commands use the ordinary 30-word budget without resetting its ledger. Four real budget windows give a planning estimate of roughly four to five minutes; the 480-second test limit is only a termination bound, not a speech prediction, application budget increase or completion signal.

If cancellation races with actual finish, record that real outcome and fail the requested-cancellation expectation. Never fabricate cancellation, manually invoke delegate methods, retry until green or claim stale callback replay is real speech. The replaced-attempt receipt is an incomplete snapshot taken before cancellation; only the observed didCancel establishes the actual cancellation event.

## Scope and provenance

No production controller, Feedback, private AdmittedSpeech, camera, hazard, freshness or privacy gate is modified or bypassed. This is not acoustic intelligibility, comprehension, menu understanding, physical task completion or production lifecycle acceptance. The bridge's onset/callback handling and scheduler are test-owned, not the production implementations.

Attachments retain authored fixture/hash, every attempt's original source/revision and new selection/request/phrase IDs, exact actual callback/context IDs, ledger deadlines, completed/incomplete receipts, clear outcome and runtime/voice metadata. Source hash is actual UTF-8 fixture data, not an image hash. System voice metadata and callbacks do not establish installed assets or heard audio.

Use a fresh disposable preinstalled simulator, minimal scene host and unchanged local Core only. No model/runtime/voice asset downloads or new dependencies. The previous test-only synchronous AVAudioSession main-thread warning is not suppressed or claimed fixed here. One fixed invocation must preserve failures/timeouts and authored artifacts; the runner requires the exact reviewed checkpoint32 commit and clean Core checkout.
