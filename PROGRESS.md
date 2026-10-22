## Seeing AI-style reading tools — 2026-10-22 (follow-up)

The Seeing AI app source is not public. I compared its documented features and added the missing ones, all on-device and decided by Vision, ARKit and code:
- live text reading;
- page reading with framing guidance;
- barcode and QR scanning with ticks and saved product names;
- a light detector;
- explore a picture by touch.

Voice commands: "Read text", "Read the page", "Scan the barcode", "Call this …", "Is the light on?", "Stop reading". They also appear under Settings › Ask and goals › Reading tools, and as a stop action on the main reply. Details are in research/SEEING_AI_CODE_REFERENCES.md. npm test 130/130. Swift and device behaviour are unverified (no Swift toolchain here).

## Tracked target and instant acknowledgement — 2026-10-22 (follow-up)

- Added `TrackedTarget` (Touvigation pattern): once the sensors find an object, guidance is re-measured from LiDAR every frame, spoken at 3/2/1 m and on turns, "Within reach" at 0.6 m, refreshed by re-detection every 1.5 s, and ended with "lost sight" after 8 s. No model calls.
- Chat replies that haven't started within 1 s speak "One moment."
- Added `UnsupportedPremiseTests` (EgoBlind-style categories, our own cases) to the Mac real-model tests.
- The user's shortlist of related projects is recorded with licence limits in research/HALLUCINATION_REVIEW.md. No code copied.
- npm test 129/129. `TrackedTargetTests` is written but not run (no Swift toolchain here).

## Always-on companion, sensor-backed search, full code scan fixes — 2026-10-22 (cloud session, continued)

User direction: the companion must work like an always-on agent (OpenAI dots): always listening, never off, because any gap is a danger to the child; keep every function; keep the reply-only main screen with the bottom buttons; sort and make accessible all other screens; sensors and data are the source of truth. Reviewed the second-opinion review (Astra) and ran four parallel code scans (core app, other screens, Swift packages, server/tools/firmware). About 90 findings; verdicts and changes are in [research/HALLUCINATION_REVIEW.md](research/HALLUCINATION_REVIEW.md).

**Always on**
- Background audio and Bluetooth modes.
- BLE state restoration and saved pairings.
- The camera pause is announced and repeated every 30 s.
- Foreground return restarts everything.
- Camera failure and frame-loss restart.
- The microphone retries forever, including after permission or language-model gaps.
- No off switch: Restart replaces Stop, practice ends after 2 minutes, and the belt has Reconnect instead of Disconnect.
- A Siri/Action-button App Shortcut opens the app.

**Evidence**
- Live object search with an explicit result: found and measured from the current pose, seen but not measurable, or not located (never "not here").
- One constrained image-model hint, freshness-checked.
- Saved search record.
- Detector-only identity ("a cup", never "your cup").
- Absence, identity and unhedged-direction filters.
- Arabic object grounding.
- Strict 2-of-3 frame agreement.
- Wider spatial, chat and utterance coverage, with every scan-found miss added to the shared fixtures.
- The relay keeps a fixed "possible hazard visible" line.

**App fixes**
- Conversation not cancelled during calibration or lost monitoring; replies still spoken.
- Calibration feedback and the "monitoring active" announcement.
- Greeting before camera start.
- Conversational goals keep map alignment.
- Room descriptions no longer cancel requests.
- Item lookups protected.
- Echo window 3 s.
- Arabic restarts listening in the new language.
- Learned item descriptions grounded.
- Place deletion removes pictures and state.
- Room-recall index alignment; object lift capped.
- Duplicate-role wearable dropped.
- Scan announcements.
- Many Arabic messages.

**Screens**
- Main screen: only the reply, above the bottom tabs; VoiceOver actions for Yes/No, Repeat, Quiet, Restart, End practice and Write.
- Settings, Places, Routes, Ask, Camera, Saved memory, Interests, History, Community and Room detail are reorganised: headers, most-used first, item names in labels, short sentences, a voice-command help page, and confirmations before deleting or sharing.
- Private 3D map export removed (it can hold pictures).
- Home layout, journey and route exports need a helper confirmation.
- Public map drafts require a venue type and permission.
- Review links are https only.
- The precise location is rounded to about 1 km.
- The photo client is compiled only in developer builds.

**Swift packages**
- A lone map match against a strong rival clue now asks.
- Single-saved-item matching is stricter.
- Hazards are never dropped as invalid.
- NaN-time fixes, planner rounding, a storage size check and recency ordering.
- The AppleModelEvaluation `@main` file was renamed.

**Firmware**
- A weak floor frame is debounced.
- A lost floor while calibrated is treated as a possible drop with a kept baseline (recalibration after 5 s).
- "No target in range" is no longer a fault.
- Watchdogs added, the timer-wrap stop is fixed, and the belt has a 60 s pairing window.

**Server/tools**
- Recursive privacy test with `#if/#else` tracking.
- The handoff packager honours `.gitignore`.
- The relay refuses plain-HTTP LAN binding unless explicitly allowed.
- The API key is kept out of `ps`.
- Evaluation labelling fixed.

**Not changed**
- `GenerationOptions(samplingMode:)` stays: the scan said `sampling:`, but the earlier Mac build compiled with `samplingMode:`. Verify on Mac.
- Frame-retention pressure is noted only.
- A Live Activity needs a widget extension.
- Some remaining English-only strings in CommunityLibrary/BeltLink/OutdoorNavigator, and FamiliarPeopleView labels.

**Tests**
- `npm test` 129/129.
- Firmware `protocol_test` and `failure_test` pass (g++ with ASan/UBSan).
- Swift not compiled in this container: BlindCore/BlindMemory XCTests, the app build, the rewritten UI tests and device behaviour (background audio, BLE restoration, camera interruption, VoiceOver) must be verified on the Mac and iPhone.
- Firmware has not been built for hardware (PlatformIO not run); the NimBLE pairing callback and watchdog APIs need a hardware build.

## Hallucination fix, reply-only main screen and microphone fixes — 2026-10-22 (cloud session, source only)

The user asked for a review of all handoff problems, focused on the Apple model inventing answers and objects, then approved the recommended fix. Full review, model comparison (Apple on-device vs Gemini Nano vs Gemma vs Private Cloud Compute) and sources: [research/HALLUCINATION_REVIEW.md](research/HALLUCINATION_REVIEW.md).

- **Code owns facts; the model only labels and talks.** New BlindCore `CompanionUtterance` / `CompanionFactBook` parse find requests and location reports (English/Arabic, "it", hedges, multi-sentence). Code answers them instantly and keeps reports historical with their time. Model chat passes the new `ConversationClaimGuard` (no current location, presence, absence or perception claims) plus `SpatialClaimGuard`, with one retry and then "I don't know that." The recorded failure "I last left it on the kitchen table" now produces "Got it. You last had your cup on the kitchen table. I'll remember that."
- **Image grounding.** `VisualGrounding`: unhedged model sentences naming an object are spoken only when the phone's detectors agreed on it in 2 of 3 frames about 150 ms apart. The image prompt lists confirmed objects.
- **Speed.**
  - Sessions are prepared and prewarmed ahead of time; the app prewarms at launch.
  - Plain-line context replaces the JSON blob and the pretend tool call.
  - The model-written `CompanionDecision` task state was removed.
  - The decorative ROSA/SayCan/LangGraph/BehaviorTree ports and `ios/ThirdParty` were removed.
- **Find requests** use the saved item (by look or saved place), then the child's report, then a live Vision/LiDAR search, before "I don't know".
- **Main screen** shows only the current reply (no tab bar, no navigation bar) so VoiceOver reads only that. Other screens are reached through VoiceOver actions or a long press on the reply; magic tap repeats. The typing control appears only with `--text-only`. UI tests were rewritten for this layout.
- **Microphone.**
  - Answering a yes/no offer no longer switches continuous listening off for good (it used to call the manual `start`, which cancelled continuous mode).
  - Recovery now retries with back-off instead of stopping after three failures.
  - Audio-session failures retry.
- **Tests:**
  - `npm test` 125/125 after installing the two small Node packages with `npm ci --ignore-scripts`.
  - New tests: the shared fixture `companion-evidence.json` in Node, and 5 static checks in `tools/test/companion-evidence.test.mjs`.
  - Two stale assertions were updated: microphone permission wording, and the currency `cancelDescription` regex.
- **NOT run:** Swift compilation, BlindCore XCTests (including new `CompanionEvidenceTests`), Apple SDK app build, UI tests, real-model conversation tests, phone timing and VoiceOver. There was no Swift toolchain in this container and Docker was not authorised. Nothing here is accepted until the Mac run.

## Final typed-chat diagnostic and remaining failure — 2026-10-22

A debug-only --chat-baseline in the running app, with a minimal role and no history/schema, answered Help me find my cup with Where did you last have your cup? This one turn passed; it does not validate the full app. Normal path was then separated into streamed natural reply followed by guided task extraction, preserving source reports and task state. Empty navigation records, previous model replies, duplicate current requests and older extracted facts were removed from prompt context; durable records were not erased. Cancellation cannot retain a proposed step, and metadata timeout cannot erase an already displayed answer.

Final actual UI: Help me find my cup -> Your task is to find your cup. Did you last have your cup near the table? Then I last left it on the kitchen table -> Your cup is on the kitchen table. Goal displayed correctly, but a historical report became a certain current-location claim: FAILED evidence handling. First complete sentence8.384551s, reply finished9.141065s: FAILED latency target. Earlier revision passed closed/open comparison and visible backpack switch/cancel; those were not all rerun on final build. Active Xcode BuildProject6.980s and isolated simulator Apple SDK build passed;6affected privacy/spatial checks passed. These checks do not catch all ungrounded conversational claims. Final app runs normal --text-only; diagnostic baseline off, UI session closed. No physical/voice/model-switch validation. Do not mark chat ready or blame the base model alone; full-context pipeline still fails where a minimal baseline succeeded.

Exact outputs and successive failures: ios/.validation-results/text-chat-status.json. Task acceptance: ios/.validation-results/interactive-agent-scenarios.json. Next work must isolate context contributions and enforce historical-versus-current evidence throughout conversation, then validate multiple scenarios/paraphrases; avoid further unsystematic prompt accumulation. Full sensor/tool execution, task suspension/resumption and long-session retrieval remain open.

## Interactive companion feedback correction — 2026-10-22

Applied source-informed agent patterns to the local text adapter, preserving voice pause and original project/backend. Simplified chronological context, removed duplicate latest request and generated subject/value reply rendering, and moved the natural answer before structured bookkeeping. Actual UI closed/open comparison now answers correctly. Timing-only app logs: first sentences10.546s and9.281s; total generation12.585s and10.304s. These fail the response-time target. Cup request failed to create a visible goal and produced an unsupported not-found statement plus unnecessary permission question. Backpack replacement and cancellation changed the visible goal correctly, but replies remained poor. Follow-up fix copies whole explicit task request as goal, distinguishes unknown from a failed search, starts requested help without redundant permission, and prevents cancellation from retaining a proposed step. Active Xcode build passed7.193s and isolated simulator build passed; actual UI follow-up pending. No all-pass claim. Privacy/spatial17 checks passed before follow-up; affected6 checks passed after it.

Reviewed Inner Monologue (human goal changes, success/scene feedback), tau2-bench (dual-control and final-state evaluation), Anthropic context/agent guidance, WorldScribe and streaming evaluations. These are research/adapter patterns, not full imported agent runtimes. Source links and limitations: ios/.validation-results/companion-prompt-research.txt. Actual UI evidence: ios/.validation-results/text-chat-status.json. Scenario acceptance criteria: ios/.validation-results/interactive-agent-scenarios.json. Full suspended-task resumption, fresh sensor/action tools, long-session memory retrieval and physical continuous-use acceptance remain open. No Gemma install/model change, uploads, project regeneration or push.

## Actual chat failures and researched role/context correction — 2026-10-22

User explicitly rejected automated passes as acceptance and required actual typing in the running app. UI reproduced transcript leakage and contradictory recall twice despite prior fixture passes. Adapter now excludes malformed historical assistant replies as examples without deleting stored user history and refuses transcript-reciting/oversized outputs. Actual follow-up What is my name returned Alex. Goal change to tea and milk follow-up were relevant, but closed/open fridge updates produced irrelevant tea instructions and repeated What should you do next. These are failures, not an all-pass result.

Saved-name UI initially failed because profile was not an accepted MemoryStore namespace. Corrected to supported preferences/preferred-name. Actual Maya save, restart persistence and model recall over old Alex history passed. Forget restored original empty profile; personal data preserved. Recall still appended an unnecessary question.

User requested researched startup role plus durable goals, task progress and change criteria. Consulted Apple FoundationModels prompting, instructions, context and session docs. Replaced accumulated prompt patches with three paragraphs covering companion purpose, child independence, available capabilities/evidence, task changes/completion, and question versus update behavior. Moved user-controlled profile into prompt data. Text adapter now receives structured saved goal/preferences/historical map and existing navigation checkpoint state, explicitly unverified live location and no available action tools. This is NOT a general persistent task tracker or continuous sensor integration. Full task state, confirmed-fact retention beyond six turns and token-aware rollover remain gaps. Evidence/research: ios/.validation-results/companion-prompt-research.txt and text-chat-status.json.

Latest simulator build succeeded; active Xcode BuildProject succeeded7.299s. Final actual closed/open pair with researched prompt FAILED: both single inputs yielded The fridge door is now open. What should you do next? Closed input contradicted; follow-up repetitive. Stable UI is not correct conversation. Saved-name persistence passed; general chat remains unacceptable. User now prioritizes established robotics-style LLM supervisor, persistent task state and sensor/action tools; references recorded in ios/.validation-results/companion-prompt-research.txt. No new automated tests launched after user's correction; prior suite was deliberately interrupted. App running --text-only; microphone off. No push or physical device validation.

## Text chat first and saved preferred name — 2026-10-22 (local)

User paused voice because it is slow and repetitive, then explicitly required hands-on typed conversation in the running app instead of treating automated passes as acceptance. Added --text-only: no automatic microphone/camera startup, no speech dispatch, no spatial-audio initialization, manual microphone entry points guarded. Operation replies remain visible. Existing normal mode retained. Added preferred-name Settings save/forget using existing private memory namespace profile/preferred-name, separate from six-turn dialogue; pass saved name into every local text conversation session. Corrections in current conversation take precedence for that reply; durable changes use Settings.

Real-model fixtures initially passed keyword checks but manual output review found an invented Lily greeting. Tightened prompt and checks; revised seven cases passed in 57.250s with concise fruit/fridge answers. This does not prove general conversation correctness. Latest Xcode BuildProject passed 10.731s; simulator built and 22 existing iOS unit tests passed; six privacy/spatial checks passed. Expanded final run was deliberately interrupted at user request during saved-profile tests to prioritize hands-on typing. Saved-profile restart behavior is not yet verified. Simulator launched --text-only for UI verification; results pending. No push, microphone restart, physical sensor/image validation, or 24-hour claim. Evidence: ios/.validation-results/text-chat-status.json and text-profile-interrupted.log.

## Simulator microphone recovery and conversation regression — 2026-10-22

User requires testing on Mac; physical iPhone unavailable. AirPods Pro connected as default input/output. Simulator speech failure was first a missing unpacked mini.json; full772MB Apple model existed in Restore. Extracting that exact package caused local speech service crashes because H19.bundle was incompatible with runtime requirements (intel/universal/jit). That extraction was rolled back and preserved under /private/tmp/blind-recovered-speech-files. A reversible simulator-only compatibility trial using the already-installed older Mac English model (build13M300771,447MB) allowed listening to initialize and remain active. User confirmed a live reply beginning Hello Alex. This is not a redistributable app model or device validation; manifest ios/.validation-results/speech-mac-model-test.json.

Conversation remained incorrect: history recitation and contradictory name recall. Local dialogue comparison found no substantial similarity between the last user turns and preceding assistant output, so echo is not established as the cause. Changed LocalImageAssistant conversation from serialized/labelled history in a user prompt to FoundationModels Transcript prompt/response entries; retain bounded existing history, local-only inference and SpatialClaimGuard. Added focused real-model Swift Testing regression for Alex name recall without transcript recitation. Xcode device build passed8.428s before adding regression; simulator regression now running. Earlier whole-suite results do not cover these changes. No24hour claim and no push.

## First conversation test — 2026-10-22 (local, in progress)

User narrowed the acceptance target to opening the app, hearing a greeting, and keeping a spoken conversation alive with supplied test inputs. Continuous microphone code now distinguishes an open stream from an active utterance; ordinary speech is no longer blocked merely by listening. A camera-independent Foundation Models conversation fallback uses the existing bounded six-turn dialogue and applies SpatialClaimGuard before speech. No remote service is used. Updated microphone purpose text. Camera/model/physical operation remains unproven; supported-phone calibration and background stop behavior remain unresolved. Old UI tests still target superseded controls.

Validation so far: Xcode device build-for-testing passed (12.708 s); isolated base simulator build passed; focused privacy/spatial checks 6/6. Simulator two-turn check pending. No audio, sustained-runtime, recorded-image-in-conversation or 24-hour pass is claimed. Detailed local result: ios/.validation-results/conversation-first-test.json. Do not push or regenerate the active face-backend project.

## Continuous companion correction and source review — 2026-10-22

User explicitly corrected the product: persistent visual/depth/audio awareness and hands-free conversation, not press-to-talk tools. Keep useful features accessible through simple bottom tabs; voice-guided setup; settings/wearables in Settings; quiet reduces narration without disabling awareness. The prior Stop/Start/Repeat-focused home is not the accepted final UX. Current code does not meet continuous operation: microphone ends each utterance/20-second window, backgrounding stops ARKit, XS Max live start is depth-gated. No claim of all-day operation.

Inspected pinned BankNote-Net training/prediction code, Seeing AI team's audio-description engine, Psi continuous-speech/live-recorded pipeline examples and historical currency example. No upstream source adopted or executed. Source evidence and full review: ios/.reference-materials/review-694eccb/CONTINUOUS_COMPANION_REVIEW.txt. Real Apple image-model Mac run returned 12/12 responses using the compact project prompt (4.19–10.94 s, median 6.13); seven of eleven stair-labelled frames mentioned steps, four omitted visible stairs. This is a direct local-model experiment, not phone app integration or a reliability benchmark. Eight text-model scenarios failed strict JSON parsing; diagnostic exposed fenced JSON. Three Arabic cases unsupported. New replay runs reproduced prior failures. VoiceOver audio, all-day runtime and physical lock/camera tests remain unverified; phone unavailable. No source changes/push in this review.

## Simple home and automatic startup — 2026-10-22 (local, not pushed)

The user rejected the technical dashboard and requested a child-usable assistant that starts on opening, speaks short next steps, and keeps optional wearable details in Settings. Added an everyday home with Talk, Repeat, Quiet/Speak again while running, Stop/Start and More. Maps, typed questions, Settings and explicit practice are reached through More; wearable pairing/calibration/status is only in Settings. No peripheral is required to open/use the everyday UI. Extra tools retain their existing detailed controls; they are not claimed fully redesigned.

Opening/returning to the foreground attempts live startup on supported hardware, with explicit camera permissions and level-floor readiness still required. Explicit Stop prevents automatic resume within that app session. New installs default to automatic surroundings descriptions; existing quiet preferences are preserved. Voice capture remains local and starts only on explicit Talk/magic-tap or the existing opted-in answer window. It now finishes after two seconds without a changed partial transcript, retains the explicit Done control and overall timeout, and reports permission/unavailable/empty-input errors through the existing speech gate. Real microphone timing and VoiceOver listening behavior remain untested. No danger, spatial-evidence, identity-consent or privacy gates were weakened. XS Max still cannot provide scene depth; unsupported startup says so and practice is explicit, never a live-sensing substitute.

Validation: Node 88/88; final signed AuraFace iPhone build-for-testing passed; isolated base simulator build passed using the saved original project (active backend project never regenerated). Latest full UI batch: 8/10 passed; after fixes, the maps/settings return test passed on targeted rerun. New everyday-home Apple accessibility audit, hidden-wearable check, practice start/stop and other existing functional UI tests passed. The remaining detailed Guide/Ask audit fails on contrast for the disabled map-destination button; no new suppression was added. Guide audit passed. This is not whole-app accessibility certification. The physical phone disconnected before updated runtime tests; no new device launch, real recognition, LiDAR, child-use or end-to-end speech result is claimed. Logs and precise results: ios/.validation-results/voice-home-summary.json.



## Currency reference matching and clothing colour — 2026-10-22

- The current currency route reuses actual local OpenCV 4.14.0 SIFT/ORB/AKAZE comparison, reviewed reference boundaries/hashes, competing-label/geometric gates and a full-frame Vision polygon veto. It is not a newly trained classifier or an LLM. No validated reference pack is selected; the default app explicitly reports unavailable and never guesses money. Earlier classifier/training code is dormant. No photos, weights or descriptors are published.
- Requested clothing colour uses local foreground pixels and Lab appearance, qualified captured-view speech, neutral uncertainty and no school-white certification. It does not use a language model to decide colour. Both requested visual paths retain attention/hazard/cancel/freshness gates and now use the same strict full optical-direction pose gate (<10 cm, <5 degrees), including pitch. Review identified and fixed a dormant currency pitch-only stale-view gap; synthetic regression tests cover that case.
- Recovery reconciles primary `295ca393` (including the Mac fixes in `c4f7a26`), preserving its Mac simulator/UI fixes. Eight source/doc files were recovered with exact Git blob verification; native source was replayed from recorded writing commands; missing integration and portable Python files were reconstructed. The final pose extraction/test and native formatting correction are explicit later edits. Original private photo inputs/detailed experiment artifacts are lost, so historical comparison observations are not fresh validation of reconstructed source.
- Fresh final checks: **BlindCore 349/349**, **Node 116/116**, **portable reference mechanics 55/55**; strict C++17 header syntax with Clang 17 and GCC 14; all 40 app Swift sources parsed in default, currency and combined currency/AuraFace/multimodal configurations. Core/native/app source hashes were unchanged during checks. The actual verified OpenCV framework passed the currency generator; the default project was restored without machine paths/assets. These are software/plumbing/syntax checks, not Apple SDK typechecking, native linking, real currency accuracy or device acceptance.
- The historical 17-query experiment reported three acceptable matches, thirteen abstentions and one unsafe front/back composite acceptance per prepared-reference method. The actual composite has not been retested through Apple Vision/native code. Modern 1/20, broad issues/backs, independent negatives and phone trials remain missing. No release winner, high-accuracy rate, authenticity, summing or child-use claim is made. See [current currency handoff](research/CURRENCY_REFERENCE_MATCHING.md), [reconstruction evidence](tools/currency-reference/RECOVERY.md) and [colour handoff](research/CLOTHING_COLOR.md).
- Shared OpenCV setup uses once-only process-wide initialization; existing face models, alignment and thresholds are otherwise unchanged. This source update is not deployment. V09/V11 remain open for their physical acceptance and remaining scope.

## Mac validation and fixes — 2026-10-22

## Private Mac transfer — 2026-10-22

Uploaded the Windows project snapshot, Git history and all recorded workspace test assets to the [private transfer release](https://github.com/mischa23v/blind/releases/tag/mac-transfer-20261022). Seven assets, approximately 987 MB total: 9,635 workspace files, including the unchanged 826,767,360-byte CA-1M capture (2,988 PNG images inside), 205 image files outside that archive, all scenarios, room fixtures, maps, point clouds, replay inputs, historical reports and transcripts. Verified 9,634 project-archive entries against individual SHA-256 hashes, 36 stair originals against publisher hashes, the Git bundle, and all seven uploaded asset digests. Credentials and platform build/dependency caches excluded. No app/model/iOS tests run for this transfer. Newer Mac source was preserved; the Windows snapshot is reference material, not a replacement for the current checkout. Mac download/extraction and real iPhone room scanning remain to be verified. Windows originals retained. Read research/MAC_TRANSFER_2026-10-22.md for restore steps.


The user authorized testing the existing ZIP despite its unverified source revision, then authorized publishing these fixes. The three modified source/test files were compared against current master; their pre-edit backups exactly match the corresponding blobs at `a2633a1`. The fixes apply on top of that head without replacing the Saudi banknote work. Results below describe the local pre-currency checkout, not validation of the combined latest master.

- Fixed Debug simulator architecture selection (`ONLY_ACTIVE_ARCH=YES`, Release `NO`), black text on the yellow prominent buttons, scalable wrapping for the map-destination label, and UI queries that work without a TabBar ancestor. The cloud control assertion accepts its absence in production. The accessibility contrast exception applies only to the disabled retrace control; all other findings remain enabled.
- Environment: M1 Mac, 8 GiB RAM, Xcode 27.1 (27A9275), iOS SDK 27.1, Swift 6.4, Node 22.23.4. Full Xcode command-line selection was corrected.
- Passed locally: Node 88/88; BlindCore 306/306; BlindMemory 14/14; face-policy JS 16/16; Python harness 28/28; C++ protocol/failure sanitizers including 100,000 frames; MobilitySimulation 17/17 (synthetic inputs, real core logic, no LLM).
- Apple builds passed: base simulator and device; build-for-testing after architecture fix; optional multimodal device; AuraFace device with pinned model/framework hashes checked and bundled model hashes rechecked. The final AuraFace build was signed, installed on iPhone XS Max/iOS 18.7.9, and the user confirmed launch after Developer Mode and trust setup. Signing identity, local paths, model assets and generated projects are not published.
- Hosted iOS tests: 22/22 passed. Latest six-test UI batch: 5 passed, 1 accessibility audit failed. After the map label adjustment, targeted audit still failed on the scalable Wearables heading. Dynamic Type audit remains unresolved, not suppressed or reported passed.
- Existing base build launched on iPhone 18 Pro Max simulator: Guide/Ask/Places/Routes/Settings navigation and simulation start/stop passed; no app crash observed. Simulation displayed the insufficient-ground stop message; individual hazard UI outcomes, actual speech and haptics were not verified.
- Xcode itself crashed twice with EXC_BREAKPOINT/SIGTRAP in AppKit window/view layout. Exact trigger remains unknown; serial CLI builds and devicectl installation avoided the GUI path, but do not establish an Xcode repair.
- Not run: full physical acceptance, real face accuracy/enrollment workflow, Apple pixel/orientation parity, VoiceOver, sensor/belt behavior, thermal/battery/endurance, or currency recognition. XS Max has no LiDAR; current monitoring/live face capture requires scene depth. AuraFace itself does not inherently require LiDAR. No trained Saudi model was validated. No child-use or release gate is closed.

## Historical trained-model preparation — 2026-10-22 (superseded by reference matching)

- Added local Apple Vision/Core ML adapter and explicit no-model status, eight-denomination/unknown policy, English/Arabic intent and measured-framing responses, strict snapshot freshness and existing attention/speech cancellation integration. Generic scene/OCR and learned descriptions cannot use common cash-value/authenticity outputs as a fallback.
- This is **not installed working recognition**. No dataset inspection, Saudi-trained weights, real recognition accuracy, Core ML conversion/runtime parity or phone test is claimed. The selected profile is nil. V11 stays open. No image/weight redistribution, merge or deployment performed.
- Portable checks: BlindCore 315/315 and Node 92/92 passed; all iOS Swift sources parse in default, familiar-person and AuraFace configurations. These are synthetic/source tests, not Apple SDK typechecking or currency accuracy. Training 32/32 and evaluation 37/37 synthetic harness tests also pass. These are not model-accuracy results.
- Dataset is being downloaded by the user. Next: local VOC/data/group inventory, real encoder/head training, calibration and held-out whole-frame costly-confusion/unknown tests, then Mac/iPhone validation. See [Saudi handoff](research/SAUDI_BANKNOTES.md).

# Project progress and continuation record

## Cloud review, familiar-person experiment and speech wiring — 2026-10-22

Reviewed upstream `master` at `7da0ce1fe19a2003418612efd5d0ddd8bb0e1e39`; 240 first-party/relevant files matched their Git blob hashes, with all 391 tracked paths inventoried. Baseline passed Node 54/54, BlindCore 235/235, BlindMemory 11/11 and 17 synthetic MobilitySimulation cases using direct Linux Swift 6.2. Docker rootless setup was blocked by host prerequisites; Linux never substituted for an iOS build.

Implemented regression fixes: shared English/Arabic spatial-guard fixtures expanded from 39 to 107; relay hazard context preserved; stale locate/item callbacks invalidated; queued private-image writes cannot resurrect deleted records; voice/UI deletion shares throwing cleanup; unresolved room identity/tracking/depth gaps clear stale trust; unsupported inferred door crossings and OCR ambiguity override removed. Private-memory v4 migration accepts the actual companion/items/room-recall/item-appearance namespaces, preserves old records and enforces per-namespace bounds. Privacy UI tests and microphone disclosure match the build; new installs default follow-up listening off.

The opt-in familiar-person source flow is complete for Mac testing: actual local multi-photo selection, guided rear-camera collection, three to six reviewed enrollment examples, explicit user labels/consent, encrypted backup-excluded gallery, add/replace/delete, voice commands/confirmation/cancel and accessible controls. SFace remains the explicit-feature default; AuraFace is a separate build-selected backend. A named search has a 20-second/six-check limit, one initial failed-attempt prompt, quiet retries, target-only tentative hint and fresh/session/goal/cancel/hazard gates. First-attempt success does not announce a failure first. Current recognition needs a steady tracked portrait view; walking recognition and chest-height framing remain device tests. Vision's optional aligned-face veto is off by default and uncalibrated.

All app-authored speech now reaches one private sink through CompanionAttention admission. Existing hazards, mobility, requested answers, ordinary budgets and goal rules remain; already-admitted offers/changes are not charged twice. A focused-task flag suppresses unrelated room/clothing information during stationary named search. Explicit current-operation confirmations/progress have a bounded <=80-word, <=30-second policy classification, no descriptive-content exemption and no delayed replay. Hazard dispatch cancels obsolete face work, questions and offers. Intrinsic system VoiceOver reading and actual audio interruption behavior still require Apple-device verification.

Final available checks: Node 88/88; BlindCore 306/306; BlindMemory 14/14; MobilitySimulation 17/17; synthetic face-policy JS 16/16; Python evaluation harness 28/28. All 39 iOS Swift files parsed in three configurations, with the separate native integration source also parsed; model configuration typechecked for both backends. Actual model hashes/framework version passed both experimental generators; default project restored without machine paths or model assets. Info.plist parses and includes required camera/microphone/speech/Bluetooth/location disclosures. C++ protocol/failure tests and 100,000 command frames passed Address/UndefinedBehavior sanitizers with leak detection disabled: LeakSanitizer itself cannot run under this host's ptrace environment. A stale source-contract test naming the old speech sink was updated to enforce the same spatial guard before gated delivery; final rerun is fully passing. Diff whitespace check clean.

Research evidence is separate from software tests. Preserved ORL SFace baseline: 178/180 known correct, 7/200 unknown photos falsely named, clustered in one unknown person. Fresh Aberdeen protocol used identity-disjoint calibration before the held-out run. Selected SFace .7/.2: 76/82 known correct, six abstentions, 0/193 unknown false names. Selected AuraFace .5/.2: 82/82 known correct, 0/193 unknown false names. Only 20 held-out unknown people were represented; this does not demonstrate below-1% population error. App multi-example aggregation and Apple checks differ from this single-template benchmark. Exact split, hashes and all 50 aggregate rows are in `tools/face-evaluation/ABERDEEN_RESULTS.md` and companion metadata; no images, weights or vectors are committed.

The user subsequently authorized integration into the existing shared primary `master` branch. The completed face commit is retained in history, with a non-force, expected-head primary update and these handoff corrections. Future authorized repository changes reconcile current remote work before primary integration; the branch is not renamed. No deployment or production-readiness claim is implied. Follow the current top section of `MAC_HANDOFF.md`: default `mac:setup` first, then generate the experimental project. The pinned OpenCV framework lacks arm64 simulator support, so use the physical-device build on M1. No Apple SDK build, native image parity, Keychain/PhotosPicker/VoiceOver runtime, real sensor replay, battery/thermal or 24-hour operation result is claimed. The existing idealized elevation sweep still recognizes only 16/42 cases; no sensor safety claim is solved by these changes. All physical and child-use acceptance gates remain open.

## Current — 2026-10-09 (end of Windows stage)

Next session is on the Mac mini: start with [MAC_HANDOFF](MAC_HANDOFF.md) "Mac day — start here". BlindCore builds with Swift 6.2 and all 235 XCTests pass in a Linux container (including 8 walking scenarios); iOS files pass a syntax check but the app target has never been compiled; Node 54/54. Latest pushed commit is on the private GitHub repo.

## Windows feasibility stage — 2026-10-09

Resumed from the continuation handoff. Ran `node --test --test-concurrency=1 server/test/*.test.mjs tools/test/*.test.mjs` on the current source: **40 passed, 0 failed**, log `artifacts/windows-stage/node-tests-20261009.tap`. This covers the Node relay/SQL/tool contracts including edits made after the earlier 39-test record; Swift/Apple sources remain uncompiled.

The user set the direction: the first slice is continuous, filtered, automatic narration with map-based orientation (not point-and-ask), sized for a fast screen-reader listener (high default density, most important information first, skip control, book-style first-entry room description then changes only, learned skips reviewable). Heat/battery are treated as measured-in-passing on device, not open questions. Next: a feasibility evaluation here using real public LiDAR/video sequences and photos through the actual relay and model, then Mac mini, then iPhone.

Gap review against the user's goal-led companion model: familiar places are silent background knowledge for goals; descriptions are for new places, waiting time or requests; first-visit description is offered, not forced; offers cover room identity, outfits and remembered items; hazards never wait. The current live loop requests an ambient description every few seconds and skips only exact-text repeats, so the E02 decision engine is the main missing piece. Added tasks E12 (offers/confirmations), M12 (room familiarity/routines) and Q09 (real-data evaluation), and scenarios OFF-01–08 plus OUT-01 (family café outing, 13 steps) to ASSISTANT_TEST_PLAN. Checklist: 74 tasks, 9 complete, 65 open. No Swift toolchain here; Swift scenario tests run on the Mac.

Spatial safety rule (user, 2026-10-09; AGENTS.md, task E13): hazard geometry (stairs/steps/drops/edges/curbs/holes/obstacles — distance, direction, step count, height, up/down, clear-path) only from sensors; step counts only from code with calibrated stride; model estimates for everyday objects allowed but must sound uncertain; sensor facts spoken confidently. Implemented `server/src/spatial-guard.mjs` (relay retries once then refuses), `BlindCore/SpatialClaimGuard.swift` (app drops non-compliant model text, speaks a short notice for requests), shared fixture `spatial-claims.json` (31 blocked/allowed cases, English and Arabic), static path test `tools/test/spatial-rule.test.mjs`, and a Claude Code PostToolUse hook (`.claude/settings.json` → `tools/hooks/spatial-rule-hook.mjs`) that reruns them after edits to guarded files. Model instructions rewritten accordingly. `node --test --test-concurrency=1 server/test/*.test.mjs tools/test/*.test.mjs`: **48 passed, 0 failed** (`artifacts/windows-stage/node-tests-spatial.tap`). Swift guard/test and engine are source only until the Mac.

Q09 first results (real CA-1M bedroom frames through the actual relay; `artifacts/windows-stage/q09/`): descriptions graded by viewing the frames were accurate (bed, headboard, bedding, picture, bedside chest, lamp, remotes, bean bag; door "right side, beside the wardrobe, partly open, hallway beyond" matches the frame and the measured +15° bearing; "no door in this view" when the door was measured 0.9 m behind). Code-rendered facts from the recorded pose gave the out-of-view door correctly. Dataset labels omit the bed (label gap). Claude Haiku and Sonnet (via subagents, quality only) were equally accurate; three of their sentences exposed an over-broad "edge" hazard term, now narrowed to drop edges in both Node and Swift with the real sentences added to the shared fixture. Latency (`latency.json`): handshake ~0.3 s; gpt-6.1-sol 3.9–4.9 s model time; gpt-5.4-mini 0.85–1.0 s; low image detail saves 0.3–0.6 s; prompt ~2,900 input tokens; spatial check 8.5 µs. Our own costs found and removed from the hot path: relay rate limit (config), whole-answer retries (now per-sentence drop and whole-sentence budget fit; retry only as last resort), auto image detail (now low except text/room). User direction recorded: speed is the first requirement; while moving toward a goal, fewest words (≈3 fast, 6 normal, 12 slow, full when still or asked) and only what is in the path. `AttentionPolicy.guidanceWords` and smoothed speed added (Swift, unrun). Node suite: **51 passed, 0 failed** (`artifacts/windows-stage/node-tests-e14.tap`). Next: compact on-device prompt (~400 tokens), streaming first sentence, on-device model timing on the Mac/iPhone, Claude timing once an Anthropic key is available.

Compact role prompt (`SYSTEM_COMPACT`, "You are the guide…") added for quick answers and moving guidance; the full prompt stays for detailed descriptions and map/people context. It halves input tokens (2,938→1,327 on gpt-5.4-mini; 2,247→636 on gpt-6.1-sol) but cloud time barely changed, so its main gain is expected on the on-device model. Claude timing via the official SDK (`@anthropic-ai/sdk` 0.132.1, pinned, installed with `--ignore-scripts`; key verified, stored in git-ignored `server/.env`), streaming, same frames and compact prompt (`latency-claude*.json`): **Sonnet 5.5 first words ~1.05 s (two frames), total ~2.0 s**; Haiku 5.5 first words 1.4–2.4 s; Opus 5.5 first words 2.1–2.5 s. All three described the bedroom accurately and passed the spatial check. Streaming the first sentence makes Sonnet the fastest cloud option measured; sub-second still needs the on-device model. Node suite 51/51.

Free on-device default made permanent (AGENTS.md): blind children and struggling families cannot pay API bills or manage keys, and many have home Wi-Fi only, so every core feature must run on the free built-in model offline; cloud is optional. On-device path corrected: `LocalImageAssistant` previously sent ~800 tokens of older instructions plus up to 24 KB of situation JSON, which would overflow the built-in model's ~4,096-token window; it now uses `GuidePrompt` (BlindCore) reading the shared `Resources/guide-prompt.txt` — the same file the relay's `SYSTEM_COMPACT` loads — and `GuidePrompt.compactSituation` capped at 4 KB (bulk dropped first: places, entities, map notes, conversation). `Package.swift` declares the resource. Swift `GuidePromptTests` prepared (unrun). Node suite 51/51 (`node-tests-ondevice.tap`). Git initialised locally at the user's go-ahead; `server/.env` and `research/datasets/` confirmed ignored.

Build-out toward a Mac day of design and testing only (user direction): see the TASKS "Build-out 2026-10-09" table for every module and its owning task. Helper agents wrote BodyHeading, SceneChangeDetector, ItemMemory, SpatialFacts, RoomRecognizer and LandmarkPose (each with XCTest files, confined to their own files); the app wiring, RoomRecall, ItemAppearance, LocateCommand, GuidePrompt, ItemAppearanceMatch and PeopleRegistry were written in the main session. User rules recorded in AGENTS.md: privacy (pictures and personal data never leave the phone; app build has no picture-sending path), public place library only on GitHub, consent for people recognition, identity decisions by image comparison not by the model. Object-matching research: Apple feature prints + foreground cut-outs + homographic registration now; DINOv2-S (Apache) and ALIKED+LightGlue (BSD/Apache) as on-device upgrades after a download go-ahead; avoid SuperPoint weights, MASt3R, MobileCLIP weights, SALAD (GPL), unlicensed repos. Baseline pushed to the private GitHub repo. Node suite 54/54 (`node-tests-items.tap`). No Swift compiled.

Independent Fable review recorded in `research/FABLE_REVIEW_2026-10-09.md` (FR-01–FR-20, tracked in TASKS). Dataset for Q09: CA-1M val capture 42898570 (Apple, CC BY-NC-ND 4.0, iPad Pro LiDAR, 996 frames at ~10 Hz, 1024×768 RGB, depth, per-frame pose, 99 labelled objects incl. door, door frame, walls, closet, TV, nightstand), downloaded to `research/datasets/ca1m-val-42898570/` (sha256 4fe2251d…c5c6). Recorded device poses test reasoning over real sensor data, not live localisation.

Older progress history (2026-10-02 to 2026-10-08) is in [research/ARCHIVE_TRACKERS_2026-10-08.md](research/ARCHIVE_TRACKERS_2026-10-08.md).

## Currency dataset transfer — 2026-10-22

At the user's request, uploaded the existing Downloads/7sys44td9c-1.zip to the [private currency transfer release](https://github.com/mischa23v/blind/releases/tag/currency-transfer-20261022): 6,752,380,788 bytes, split into four binary parts with reassembly instructions and original/part SHA-256 checksums. All eight uploaded assets match GitHub SHA-256 digests. The outer ZIP contains 7sys44td9c-1/Saudi Currency.zip. No dataset extraction, training, dependency installation, model download or app tests performed. Dataset licence, labels, training suitability and Mac extraction remain unverified. Original ZIP retained in Downloads. This records transfer only; V11 remains open.

## Seeing AI references and hello.zip — 2026-10-22

Uploaded the user-supplied hello.zip unchanged (9,420,989 bytes; three Read/Describe/More UI screenshots) to the [private reference release](https://github.com/mischa23v/blind/releases/tag/hello-seeing-ai-20261022). All five asset SHA-256 digests verified against GitHub. Saved research/SEEING_AI_CODE_REFERENCES.md and research/SEEING_AI_REPOSITORY_EVIDENCE.json covering all eleven repositories supplied by the user, exact source revisions, README/licence hashes and test/build source paths. Licence texts and READMEs retained in the release evidence ZIP. No complete Seeing AI app source verified as public; internal-app reference is not public access. No upstream execution, model download, training, integration or app tests. Source licences, model/data terms and offline suitability remain separate. User screenshots are private developer references only; no production privacy rule changed.
