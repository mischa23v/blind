# Captured-page review — local candidate, 2026-10-25

Production baseline: checkpoint31 `853fe13e9d00880f29b0920b901e02f7007e1d56`. This is a bounded command-review increment, not native acceptance or a release claim.

## Behavior and limits

- Retain one bounded volatile captured source for the current interaction after reading, without a new photo or fixed playback expiry. Output remains uncertain captured text, never a current view or movement instruction.
- Exact English/Arabic commands: repeat current/last spoken part; previous/next part; read captured text again; forget this page. Simple repeat/كرر and the Home Repeat control prefer the page only while a source is retained; no-source generic behavior is unchanged. Generic again/continue remain owned by existing features. Private review requires existing trusted input; this does not add verified microphone identity.
- Repeat uses the current/last **actually started** part, falling back to the last completed part when no onset is available. Enqueue/admission alone is not heard speech. A repeated navigation request before onset does not skip unheard parts. Part navigation reads one part; reread starts the complete source again.
- Each playback attempt gets a new request/selection and phrase IDs. Prior terminal receipt is not renewed by a new request. Exact callback identity/text fences stale callbacks; interruption never fabricates completion. Completion wording refers to that reading, not necessarily the entire page or a real-world task.
- Early Repeat with no started/completed part preserves already-authorized queued reading and its budget wake; optional status rejection cannot strand the reader. Normal answer budgets and private output apply to quotations and short review guidance. There is at most one initial guidance opportunity per source, consumed before admission or successful explicit review, not a long tip after every part. A rejected guidance admission is not reported as delivered. No automatic hazard resumption. Ambient scene replacement is held while the page is retained; stop/forget/unrelated trusted request releases that hold. Independent hazard lanes are unchanged.
- Stop/forget, unrelated trusted input, source replacement/retirement, privacy/session/background/private-route boundaries clear ownership before cancellation callbacks. Historical review itself does not require fresh camera/pose; actual source/camera lifecycle retirement remains authoritative.
- No model interpretation, keyword search, menu price/item associations, persistence, OCR change, network service or dependency. OCR has line ordering, not verified menu layout/relationships.

## Reused foundations

Existing `CapturedTextReference` and `CompanionReferenceReading` source bounds/chunking, `CommandAuthority`, ordinary information admission and `Feedback` AVSpeech callbacks. `onRequestedSpeechStarted` is optional/default inert, emitted only for the exact synthesized utterance after permission checks. Cancellable synthesis remains the private transport with VoiceOver enabled; enqueue is never substituted for onset. No new recognizer, database, speech engine or third-party library.

## Verification scope

`CapturedTextReviewTests` and `CapturedTextReviewCommandTests` execute actual Core. `captured-text-review-native.test.mjs` executes extracted production NavigationModel methods and actual reading/authority policies, with explicit synthetic camera/session/budget/speech substitutes and an evidence DTO projection omitting an unrelated helper. It is not Apple SDK typechecking, real sound, real OCR, a participant journey, or a blind-user study. Source-contract tests separately check routing order, ordinary admission, exact onset and retention fences.

Final local counts and published artifact provenance are recorded by the integration owner. Historical unrelated test/evidence pins remain unchanged. Native acceptance remains required: exact app build, AVSpeech/VoiceOver interruption/onset/completion, minimum-budget waits, bilingual discoverability and privacy/background/source replacement on-device. Do not infer completed real-world menu/payment/navigation/help goals.
