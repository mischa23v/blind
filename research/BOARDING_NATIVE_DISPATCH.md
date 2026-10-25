# Boarding reading native dispatch candidate

Staged final checkpoint21 rebase. NavigationModel preimage SHA256499deac264af7cec2c9a508f7527f247facc45217722e414cdb34d83e26eedd6. Child-readable history, camera preference, writer/voice/RGB and long-trip route-loss changes are preserved. Apply only manifest paths and exact patches; never overlay full snapshots or Package.swift.

## Architecture

Reuses current foreground contextual scheduler, semantic readText tool, explicit liveText/barcode callbacks, RGB ObjectViewCapture freshness/pose/session/request/perception checks, Feedback requested speech permission/completion callbacks, ordinary deliverCandidate budgets, and existing AdmittedSpeech.privateReference logging suppression. No new speech engine, public mode, first-tab UI, online lookup or URL execution.

All barcode observations are bounded (eight payloads, 4096 bytes each) before selection; multiple or malformed M candidates cannot reach CodeReading/product memory. Legacy code() abstains on multiple results. Semantic readText inspects barcode plus text from its original capture and dispatches private travel information directly, without returning flight/seat/gate data to a model. Language correction is disabled for these OCR reads. Semantic readText adds a barcode Vision request to its existing OCR capture, and explicit liveText changes fast OCR to accurate OCR. These are additional/costlier native work with unmeasured latency, thermal and energy effects; bounds and source tests do not prove performance. The separate currentObservation quarantine performs no additional Vision request.

Each callback keeps its pre-await original source/revision and RGB capture. New source selection cancels only the old exact speech ID. Stale callback/results cannot select themselves. One complete attributed answer fits the ordinary 30-word cap, checked again with native NLTokenizer. There is no unowned continuation queue: flight/seat information and unknown gate/year/validity qualify the same answer. For more detailed/multileg requests a specific flight designator is required. Not all requested fields are available offline.

OCR accepts ONE complete labelled observation with semicolon-separated fields. It never concatenates separate boxes/board rows or associates arbitrary OCR with a barcode. This deliberately misses common multi-line boarding-pass layouts rather than inventing associations. The printedPass enum is used internally only to allow explicit seat grammar; the native answer says captured text and never claims the physical source was a pass or airport sign. Printed versus sign attribution remains available in the reviewed Core API only when a future native adapter can establish that source.

Original wall/monotonic timestamp and source/leg receipt remain attached to the native answer; the short spoken answer says barcode/captured text, not a current authority. BCBP never supplies gate/year. All outputs explicitly disclaim current gate/flight validity as applicable. No arrival, route, motion, clearance, boarding permission or ticket authenticity follows.

## Lifecycle and privacy

Feedback alone queues/starts/stops speech. Permission checks revalidate native source, byte-exact text and current RGB lifecycle at queue/start and normal publish ticks. Trusted ordinary interruption, new request, reader Stop, source replacement and private-audio loss retire the reply; only the barcode-to-answer transition preserves its source. Explicit reader frames wait while the short answer speaks instead of repeatedly interrupting it. A late completion cannot clear a new ID. Source IDs are opaque UUIDs; raw payloads are neither retained, persisted, logged nor passed to product naming or the model.

## Evidence and limits

41 Swift XCTest cases pass: 23 reviewed parser/controller cases, seven dispatch cases and eleven cases executing the actual native method bodies with deterministic Feedback/capture/admission doubles. Only access control is relaxed in the extracted test class; its method-body hash is recorded. Framework doubles are not Apple/device validation. 46 exact native source contracts cover hook placement, three reading entry points, private admission, raw fallback suppression, bounds and lifecycle. Native swiftc syntax parse passes, not Apple SDK typecheck.

Original0852 and historical20f source candidates received independent review; final checkpoint21 rebase is now staged for final delta review. Pending: authorized live application, full live package/source-contract regression, Apple SDK compilation, actual Vision OCR/barcode accuracy and observation-row behavior, speech callbacks/VoiceOver, interruptions/thermal/timing with chest-worn camera, and real airport use. No airport navigation or feature-completeness claim.

## Apply scope

- Add BoardingPassDispatch.swift and its authored tests after reviewed BoardingPassReading.swift is present unchanged.
- Apply patches/navigation.patch only as narrowly reconciled hunks after live voice-authority and RGB reader deltas. Explicit overlap: stopReadingTool, updateReadingTool, request/cancellation/permission hooks, semantic readText. Keep their updated source/current-frame freshness gates.
- Apply patches/vision.patch and patches/scheduler.patch after checking preimages and regression contracts. The scheduler reuses its existing action-only reading goal and permits a bounded barcode probe for that goal; bare flight/gate/boarding nouns do not authorize unrestricted OCR. Travel navigation retains its separate task/target intent; no new mode.
- Do NOT apply base/, standalone Package.swift, full native snapshots, generated harness, harness stubs, or stage build/cache files into the app. Keep evidence separately as needed. The test harness is review support, not runtime code.

Final source tightening adds a one-result-per-native-selection latch (including rejected admission) and a same-source replay regression. Passive travel delivery retains contextualCapabilities.beforeSpeech in addition to background/capture checks; withheld passive candidates do not count as successful spoken results. Explicit flight parsing requires a token boundary rather than accepting a prefix of a longer designator.

## Independent native review corrections

Passive travel quarantine now runs outside optional private-owner admission: unavailable/private-held/stale RGB capture can never send recognized travel text into general OCR logging or pass-shaped payloads into product handling. Case/leading-whitespace suspected M payloads are quarantined, not repaired; strict parser still rejects them. OCR size and label-spacing checks likewise prevent unsafe fallback.

Semantic leg selection comes only from the original trusted user question captured by the existing request/generation-owned conversation executor, propagated through tool helpers. Model-generated request.query and retained passive goal labels never select a flight. Exact extracted ingress expressions/guards execute counterexamples alongside call-chain source contracts. Unverified-microphone conversation still has no tools.

Passive discovery always carries goalRelevant=false, even when a lexical reading goal made the sensor eligible. It cannot bypass focused work or an unrelated moving route. An actual CompanionAttention replay initially failed three assertions on the overbroad relevance flag; failed-before log is preserved. Corrected tests cover moving/focused unrelated tasks, idle discovery and requested read. Source eligibility is not permission to interrupt.

Copied CompanionAttention/AssistantPreferences/SpeechPriority/NarrationBudget under test-support are exact existing live files used to execute attention policy, not additions/replacements for the app. Native extraction/harness sources remain test-only evidence. No existing source has been overwritten.

The adjacent currentObservation text-to-model boundary now quarantines its entire text batch when the bounded classifier sees a known labelled travel row, without extra Vision work. Exact extracted-boundary negative tests cover a flight/gate row and accompanying synthetic header; unrelated text remains eligible. This is a bounded known-travel classifier, not universal recognition of every unlabeled travel document. Failed speech admission now clears only its own exact pending ID; a synchronous reentrant newer-source test preserves the newer answer.

Authority correction: raw/unverified microphone onset may interrupt anonymous conversation, but cannot retire selected private boarding evidence or its speech. The actual interruptOrdinaryConversation path now requires changeGoal authority for boarding retirement, matching the existing selected-photo boundary. Actual CommandAuthority plus extracted full interruption-method test failed five assertions before repair and now verifies unverified/model/trusted origins separately. Direct lifecycle, private-route, camera and hazard invalidation remains authoritative. No verified-speaker backend is introduced: current microphone transcripts still cannot request action tools; automatic perception and trusted-interface read requests are the available native ingress. This increment does not claim general authenticated voice-command support.


## Live19 narrow rebase, 2026-10-25 09:24 UTC

Rebased only asserted hunks onto NavigationModel db0c0ff9573a86c363f9a98ed4d11a1e14e9ad65d873b0943decd082dd317cce. Current writer actor entry, anonymous-turn ownership, selected-photo authority, RGB-only reader acquisition/current-frame gates and raw reader tracking cancellation are retained. Seven exact reversible patches cover the three production files and four existing test dependencies. Full snapshots and standalone packages remain review-only.

Raw tracking loss now additionally retires boarding source/speech before throttling, including a barcode result transferred after the reader mode closed. An exact extracted raw callback test failed four assertions before this line and passes afterward; old source callbacks cannot revive output. Final standalone suite has 41 cases (23 pure, seven dispatch, eleven extracted-native) and 43 source contracts. The separate live19 mirror checks existing clock, scoped-memory and RGB-reader integration; inspect its terminal evidence rather than conflating these suites with Apple execution.

The current clock replay generator receives the original request query parameter and a no-boarding-source collaborator; the scoped-memory review fixture receives the same clear collaborator. Production methods are still extracted verbatim, not replaced with test implementations. The clock source contract now asserts its call exists before checking order, avoiding the old negative-index false pass.

Passive semantic repeat remains open. The existing contextualLastSpoken map is a global string/time map without selected travel-source identity. This rebase does not add private text to that cache or confuse an equal rendered flight label with physical source identity. Ordinary attention and capability cadence still apply, but fresh passive captures can repeat the same content. A future bounded source-owned repeat policy needs a reviewed source-lifetime contract. Known-label quarantine is likewise not universal travel-document detection.

The current checkpoint19 exact pre-throttle source contract is extended, not replaced: its entire prefix now also requires synchronous boarding retirement, with missing and Task-delayed boarding mutations. All 21 spatial-review contracts pass. The old expectation failure is preserved separately.


## Ordered automatic-history rebase, 2026-10-25 09:29 UTC

After independent clearance of live19 rebase22fd046a, automatic-history applied first. Replayed identical asserted boarding hunks onto its exact Navca3d0d6700748fe125463be005ce50bd6d24336450dd981d7c2298485c4dbda9; LocalImageAssistant8e9e88bd remains untouched. routeOrdinaryHistoricalLocation remains byte-identical and its call still precedes unknown locate. No reader/dispatcher functionality changed in this second rebase. Seven exact forward/reverse proofs refreshed; added exact preservation contracts and run the existing 22-case automatic-history replay against the combined candidate. Earlier historical failed-before logs remain labelled by their original scope. Final integration status is recorded in the terminal log, not inferred from the preceding packet.

Final ordered-rebase integration terminal result: 48 Node checks passed, zero failures or skips, including the existing executable 22-case automatic-history replay, 21-case clock replay and scoped-memory/RGB/spatial regressions. Standalone boarding41 and source/preservation43 also pass. This is not a whole-app Apple build or device validation.


## Final checkpoint21 ordered rebase, 2026-10-25 11:09 UTC

Identical reviewed boarding behavior is narrowly rebased after child-readable history, camera preference and long-trip history. Current clock fixture64f94eb5 is retained with only query/no-source collaborator plumbing. Spatial contractdc504426 retains all route-loss mutations and gains the boarding mutations; extractor33c8fc3b is untouched. The raw native callback keeps nativeObservations.trackingLost synchronous before boarding retirement. Both history route methods and camera preference initialization are byte-identical to the current base. Seven exact forward/reverse proofs are refreshed. Historical rebase sections above are evidence chronology, not current apply preconditions.

Current checkpoint21 automatic-history replay has26 cases after the child-readable accessibility repair, not the22 cases in the historical earlier rebase. The current clock replay retains21 cases; exact current terminal run evidence follows in rebase-integration.log.

Final checkpoint21 terminal result:50 Node checks passed with zero failures/skips, including actual26 child-readable history cases and21 clock cases. Boarding41 and preservation/source46 pass. These current results supersede prior rebase counts for the apply decision. Parent owns full aggregate22 and Apple validation.


## Aggregate22 travel-goal correction, 2026-10-25

The original bare flight/gate/boarding lexical addition was too broad. It changed the existing negative case “flight friendship highlighting” from otherTask to reading and could also turn navigation or finding a pass into unrestricted document reading. That addition is removed rather than changing the expected negative result. Explicit English/Arabic reading actions still admit bounded barcode probes; idle automatic discovery and semantic direct dispatch are unchanged. Varied English/Arabic navigation, waiting and bare travel nouns remain nonreading; target discovery is preserved where independently supported. This is a bounded lexical distinction, not general natural-language intent understanding.
