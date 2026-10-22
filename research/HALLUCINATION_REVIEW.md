# On-device model hallucination review and fix — 2026-10-22

## Problem

The Mac simulator runs on 2026-10-22 showed the free built-in Apple model inventing facts:

- "I last left it on the kitchen table" was answered with "Your cup is on the kitchen table" (a historical report turned into a certain current location).
- "Help me find my cup" was answered with "Your cup is not found" or "Your cup is not here" (an invented search result).
- A leading suggestion ("near the table?") came from map records in the prompt, not from the child.
- In the direct image-model run, 4 of 11 stair photos left the stairs out, and other images had objects named that were not there.

Separately, the first complete sentence took 8–11 s.

## Causes found in our code (not only the model)

1. Nothing in code checked chat text for object-location, presence or absence claims. `SpatialClaimGuard` covers only hazards, distances, step counts and clear-path statements.
2. The model wrote task state. The `CompanionDecision` schema asked for "an object's current state", so a historical report was stored as current.
3. The prompt invited the guess. The instruction "ask where the child last had it" and a JSON context blob with long key names were pasted in as a pretend tool result; the tool was never registered with the session.
4. A new `LanguageModelSession` was created per message with no prewarm, so the whole prompt was re-processed every time (latency).
5. Image descriptions went straight from the model to speech. Nothing compared named objects with the phone's detectors, and the optional `Detector.mlmodelc` is not supplied.
6. The ported agent pieces (ROSA prompt rendering, SayCan affordance filter, LangGraph call/result ledger, BehaviorTree.CPP reactive sequence) added prompt text and code without changing behaviour. They have been removed together with `ios/ThirdParty`.

## Model comparison (sources below)

| Model | Where it runs | Size class | Evidence about hallucination |
| --- | --- | --- | --- |
| Apple Foundation Models (on-device) | iPhone with Apple Intelligence, free, offline | ~3B parameters, ~4K-token context | Apple: "not designed to be a chatbot for general world knowledge"; tuned for extraction, classification and summarisation with guided generation. iOS 27 adds image input and model-callable Vision tools (OCR, barcode). |
| Gemini Nano (ML Kit GenAI Prompt API) | Android only (e.g. Pixel 9+), not iPhone | Same small on-device class | No public hallucination comparison found. The API launched in alpha in October 2025. Inference fails in the background and is subject to per-app quotas. |
| Gemma 3n (open weights) | Can run on iPhone through Google's mobile runtimes | Same class | Multi-GB download, more memory and heat, and conflicts with "built-in, no setup". Worth one side-by-side run on our fixtures; not a cure. |
| Apple Private Cloud Compute model | Network | Larger | Free for Small Business Program apps per WWDC26. Sends data off the phone, so it breaks the privacy and offline rules. Not adopted. |

Conclusion: switching to another small model does not remove the failure class. The fix is architectural: code and sensors own every fact, and the model labels messages and talks.

## Implemented 2026-10-22 (source only; Apple build and device runs pending)

- `BlindCore/CompanionFacts.swift`: `CompanionUtterance.parse` (English/Arabic find requests and location reports, including "it", hedges and multi-sentence messages). `CompanionFactBook` stores each report with its time. Code-written replies keep the report historical: "You told me 10 minutes ago you last had your cup on the kitchen table. I don't know where it is now."
- `BlindCore/ConversationClaimGuard.swift`: model chat may not state current location, presence, absence or perception. Questions and past-tense attributions pass. Unsupported sentences are dropped; one retry; otherwise "I don't know that."
- `BlindCore/VisualGrounding.swift`: an unhedged model sentence naming an everyday object is spoken only when Vision classification, people detection or the optional detector agreed on that object in at least 2 of 3 frames about 150 ms apart. Hedged ("maybe…") sentences pass. Hazards stay sensor-only.
- `server/src/companion-guards.mjs` mirrors the three for Node. Shared fixture `BlindCore/Tests/BlindCoreTests/Fixtures/companion-evidence.json` includes the recorded failed replies. `server/test/companion-guards.test.mjs` and `BlindCore/Tests/BlindCoreTests/CompanionEvidenceTests.swift` run it.
- `ios/BlindAssist/LocalImageAssistant.swift`:
  - Code answers find requests and reports first, with no model.
  - Otherwise a `@Generable` intent label (find, report, new task, cancel, conversation). Copied words are checked against the message.
  - Chat uses plain short lines instead of JSON.
  - Sessions are prepared and prewarmed ahead of time (`CompanionSessions`); the app prewarms on launch.
  - The image prompt lists detector-confirmed objects.
- `ios/BlindAssist/NavigationModel.swift`:
  - Find requests use the saved item (by look or saved place), then the child's report, then a live Vision/LiDAR search, before "I don't know".
  - Grounding runs before the spatial check on image answers.
- Main screen (`DashboardView.swift`) shows only the current reply, with no tab bar or navigation bar. Other screens are reached by VoiceOver actions or a long press on the reply; magic tap repeats. The typing control appears only with `--text-only`.
- `VoiceInput.swift`:
  - A manual or answer-window turn no longer switches continuous listening off. Previously, answering a yes/no offer turned the microphone off for good.
  - Recovery keeps retrying with back-off instead of giving up after three failures.

## Evidence and limits

- Node: 125/125 (`npm test`), including the shared-fixture mirror and new static checks that each model-to-speech path keeps these checks.
- Swift sources were not compiled here (no Swift toolchain; Docker not authorised for this session). BlindCore XCTests, the app build, the rewritten UI tests and the real-model conversation tests must run on the Mac.
- Lexical guards are conservative defences, not semantic proof. Novel paraphrases can pass, and some honest sentences can be dropped.
- Grounding is limited by the detectors. `VNClassifyImageRequest` is scene-level and misses small objects, so true objects can be dropped (reliability over richness, per AGENTS.md). Candidate detector to evaluate: an Apache-2.0 model such as RT-DETR; Ultralytics YOLO is AGPL. ARKit mesh classification (door, window, seat, table, floor) is a further source to add. Both need licence review and device measurement.
- Latency target (first sentence under ~1.5 s on iPhone) is unmeasured. Simulator timing is not phone timing.
- iOS does not allow the camera to run in the background or with the screen locked. All-day operation is therefore foreground-only; document and test that limit.

## Sources

- [Apple WWDC26 iOS developer guide](https://developer.apple.com/wwdc26/guides/ios/) (image input, Vision tools, Language Model protocol, Evaluations framework, Private Cloud Compute access)
- [Callstack: on-device AI after WWDC 2026](https://callstack.com/blog/on-device-ai-after-wwdc-2026-whats-new)
- [Apple Intelligence Foundation Language Models Tech Report 2025](https://arxiv.org/abs/2507.13575) and [Apple ML research page](https://machinelearning.apple.com/research/apple-foundation-models-tech-report-2025)
- [ML Kit GenAI Prompt API alpha (Gemini Nano)](https://android-developers.googleblog.com/2025/10/ml-kit-genai-prompt-api-alpha-release.html), [Gemini Nano on Android](https://developer.android.com/ml/aicore), [Capacitor local LLM limits](https://capacitorjs.com/docs/apis/local-llm)
- [Gemma 3n](https://deepmind.google/models/gemma/gemma-3n/), [Gemma mobile integration](https://ai.google.dev/gemma/docs/integrations/mobile)

## Second review (Astra, at d6d4236) and what was done — 2026-10-22

| Astra point | Verdict | Change |
| --- | --- | --- |
| A remembered report became a current fact; absence was claimed without a search | Agree | Fixed in the first pass (`CompanionFacts`, `ConversationClaimGuard`). |
| The failing chat had no live vision or search tools | Agree | With the camera running, a find request now starts a real sensor search (`ObjectSearch`) instead of chat. |
| Detector not in the repo; a failed locate fell back to a free generative answer | Agree | Fallback removed. The search keeps looking with Vision/detector plus LiDAR for up to 20 s. The image model may give one constrained yes/no plus side hint, worded by code as uncertain ("I might see something like a cup…"). Time up gives "I haven't located your cup… That doesn't mean it isn't nearby." |
| Latency; speech waited for a metadata call; stale scene results | Agree | Metadata call removed earlier. The 6 s scene expiry is kept (not extended). Search results are measured from the person's current pose to the fixed world point and discarded when older than 1 s or after a new request. |
| Keep the attention system | Agree | Unchanged; the ambient description pauses while a search runs. |
| Combined build not validated | Agree | Still true: Swift has not been compiled in these cloud sessions. |
| Evidence status per fact | Agree | Seen now: sensor search found, spoken immediately with a measurement. Seen earlier: `SearchRecord` located / saved `ItemMemory`, spoken with time. Reported by the child: `CompanionFact`, attributed and historical. Inferred: the model hint, always "might / not sure". Unknown: `CompanionFact.unknown`, or "not located". |
| Identity: "a cup" is not "your cup" | Agree | Detector results use the detector label. `VisualGrounding` drops "your <object>" sentences from image answers. Only image comparison with saved views (`findItemByLook`) says "your". |
| No detection must not become "it isn't here" | Agree | `VisualGrounding` drops absence sentences ("there are no stairs", "I can't see a cup"). The search result says "not located". |
| Model should select observation IDs, validated before rendering | Partly | For find/report the model is removed from the facts entirely; code renders them, which is stricter and faster on the small model. The existing `OfflineSummary` ID-selection path is kept. Free image descriptions use detector grounding instead of IDs. A full ID-selection schema for image answers remains a possible later step if grounding proves too lossy. |
| Cloud Gemini hybrid for richer questions | Not now | Camera pictures may not leave the phone (privacy rule). A text-only optional cloud path is a later, opt-in decision. |
| Background camera interruption must be announced | Agree | `suspendExperience` already says "Camera and listening stopped outside the app."; device test pending. |

## How "always on" works for OpenAI dots and ChatGPT, and what that means on iPhone — 2026-10-22

- **OpenAI dots** (launched 29 September 2026) are always-on agents that run on their own cloud computer. They keep working after the app is closed, reach out when they need attention, and are reached through the ChatGPT app (including on iPhone), Slack/Teams, or a voice call. They are not an on-device sensor loop. ([Al Jazeera](https://www.aljazeera.com/economy/2026/9/30/openai-launches-dots-personal-ai-assistant-built-to-handle-everything), [Axios](https://www.axios.com/2026/09/29/openai-dots-ai-assistant-devday), [MindStudio](https://www.mindstudio.ai/blog/chatgpt-dots-explained), [OpenAI help](https://help.openai.com/fr-fr/articles/20001530))
- **ChatGPT voice on iPhone** keeps listening with the screen locked or in another app through iOS background audio. A Live Activity in the Dynamic Island shows it is still listening (the "Background Conversations" setting), and an Action-button shortcut starts it. ([Thurrott](https://www.thurrott.com/a-i/338971/chatgpts-voice-mode-now-supports-live-activities-on-ios), [BGR](https://www.bgr.com/tech/chatgpt-voice-just-got-a-big-privacy-upgrade-for-background-conversations/), [iPhoneIslam](https://iphoneislam.com/en/2025/12/use-chatgpt-as-your-iphones-action-button-assistant/162307), [Unity Vivox iOS requirements](https://docs.unity.com/en-us/vivox-core/developer-guide/ios/ios-requirements))
- **iPhone limits:**
  - Third-party apps cannot run the camera in the background or with the screen locked ([Apple](https://developer.apple.com/documentation/AVFoundation/AVCaptureSession/InterruptionReason/videoDeviceNotAvailableInBackground)).
  - They cannot use an always-on wake word.
  - A cloud agent would break the privacy and offline rules for camera pictures.
- **Adopted:**
  - Background audio keeps the microphone and speech running.
  - `bluetooth-central` with state restoration and saved pairings keeps the belt connected.
  - The camera loss is announced at once and every 30 s, with automatic restart on return.
  - Camera failures and frame loss restart the session.
  - The screen is kept awake, and Guided Access is recommended for guardians.
  - App Shortcuts ("Hey Siri, open Blind Assist", the Action button) bring the app back.
  - No off switch.
- **Later:** a Live Activity (needs a widget extension target, not in the generated project yet) to show listening status on the Lock Screen and in the Dynamic Island.
- **Not adopted:** a cloud dot for perception. Pictures stay on the phone.
