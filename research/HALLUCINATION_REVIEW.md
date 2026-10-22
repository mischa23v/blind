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
