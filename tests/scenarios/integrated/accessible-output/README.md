# Native accessible-output producer probe

Prepared source, not a completed actor trial. Native compilation/runtime acceptance is pending. This adds **zero full journeys** and makes no physical, acoustic-audibility or listener-comprehension claim.

## Actual path

Authored typed backpack report, correction and historical query enter `NavigationModel.receiveCompanionUtterance`. Code-owned replies retain the real conversation ownership queue, attention budget, priority, freshness and private-route checks before `Feedback` creates and submits its own `AVSpeechUtterance`. The test never creates an utterance, reads a text-only snapshot aloud, calls delegate methods, or fabricates completion.

The observer is nil by default and exists only under `DEBUG && BLIND_WORKFLOW_TESTS && BLIND_ACCESSIBLE_OUTPUT_TESTS`. Admission is recorded at the real enqueue call; start is recorded after actual delegate ownership checks; completion is emitted only after `SpeechDeliveryLedger` reports completed for `AVSpeech.didFinish` and the original controller callback returns. Cancellation/timeouts remain noncompletion. The test requires matching admission, start, destination, token and exact text for each actual completion. A 40-second expectation timeout fails; it never supplies a completion.

## Isolation

Global `textOnly` stays true, retaining camera/microphone startup guards. A separate per-instance opt-in permits only an exact active **trusted, code-owned, requested answer** through the otherwise disabled test speech gate. Narration, untracked output, visual-source readers, mobility, spatial routes and hazards gain no permission. Session setup calls the real `AssistantSession.start()` policy method, not microphone/camera startup.

The separate `org.blindassist.accessibleworkflowtests` host has an empty App view, disabled Bluetooth manager/connect path and no shared entitlements. The three LocalImageAssistant model entry methods (converse, spot and describe) fail closed before inference; the ordinary controller model lane is also blocked. Offline mode remains enabled. An app URL-loading protocol rejects participating HTTP(S) requests and reports attempts. That tripwire is **not proof of global network isolation**: OS speech/asset-daemon traffic is not observed or controlled here.

Preflight enumerates system-advertised voices, checks the selected en-US voice is listed, activates a real playback-only session and requires an output route. It calls no voice download, asset installation, microphone authorization or Personal Voice authorization API. A listed voice alone is not installation or successful-delivery proof; matching real callbacks remain required. Missing voice, route or callback is a blocker/failure, with no fake route, fallback transport or download retry. [Apple documents available-voice enumeration](https://developer.apple.com/documentation/avfaudio/avspeechsynthesisvoice/speechvoices()) and [on-device speech synthesis](https://developer.apple.com/documentation/avfoundation/speech-synthesis).

Private code-owned requested output deliberately uses synthesis even with VoiceOver enabled. This probe does **not** test VoiceOver announcement delivery.

## Actor boundary and evidence

`AccessibleActorOutput-ONLY-COMPLETED-OUTPUT` contains only actual completed output text, callback time and receipt identity. Raw callback, availability and authored-input artifacts are separate and must not be supplied to a nonvisual actor. Inputs in this probe are authored—not actor/model decisions. A later fresh actor may receive only actual accessible output plus their own goal/knowledge, never fixtures, code state, maps, visual observations or expected answers.

A successful probe establishes a bounded native-callback producer, not that a blind person heard, understood or completed a task. Clarity, timeliness, followability, correction/repeat/goal change, usefulness and independently observed goal outcome still require separate evaluation. Safe abstention is not mission completion.

## Reproduction and source ownership

The standalone CI workflow uses a fresh disposable simulator, separate noncancelling concurrency and public-repository guard. It pins application source `6925e21e4fef039b43ab6f4158aa37fd704b258e`, verifies relevant app and base-recipe blobs, derives an isolated current-source recipe without editing the existing three-test suite, and preserves failures/attachments. Only existing exact GRDB 7.11.1 resolution is allowed; no new dependencies, model weights, assets, frameworks or simulator runtimes are installed by the runner.

`prepare_accessible.py SOURCE NEW_OUTPUT BASE_RECIPE` performs source projection only; original production source and the older three-test recipe remain unchanged. Public files belong in `tests/scenarios/integrated/accessible-output/`, with the workflow in `.github/workflows/native-accessible-output.yml`. Do not install this host on a user's physical device or under the production bundle identity.
