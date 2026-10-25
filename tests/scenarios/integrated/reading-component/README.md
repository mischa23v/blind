# Captured text: Core + actual AVSpeech component probe

Status: source prepared and independently reviewed. Five local static contracts, JavaScript/shell syntax and Swift syntax parsing pass. Native SDK compilation/execution is not yet established.

This is **not an app/controller/Feedback/camera test**. It imports unchanged pinned BlindCore, installs an explicitly authored 100-word source, admits phrases through the unchanged CompanionAttention/NarrationBudget policies at 30 words per minute, and uses a test-owned AVSpeechSynthesizer delegate bridge. No NavigationModel is instantiated, no private AdmittedSpeech constructor is exposed and no application gate is modified.

The repaired CapturedTextReference must remain owned across actual rolling-budget windows beyond 60 seconds. Exact utterance object, text and phrase ID mapping is consumed only by real AVSpeech didFinish/didCancel callbacks. No test invokes delegate callbacks or sleeps to declare speech finished. Completion requires all ordered installed-source slices and the metadata-only terminal receipt. A single cancellable test wake uses the actual Core ledger deadline. It is not the production controller's wake implementation.

The source's SHA-256 is computed from authored UTF-8 fixture bytes. It is not an image hash or evidence of OCR. The attachment records the installed source/revision/phrase identities, authored slices, actual callback events and timestamps, ledger deadlines, terminal counts, runtime and selected system voice. System voice enumeration plus callbacks does not prove installed assets, acoustic audibility or comprehension.

## Isolation and one-run boundary

The minimal scene-backed host follows the existing native actor-host project convention, with a separate bundle identity and only a local pinned BlindCore package. It does not link the app controller, Feedback, camera, microphone, BLE, memory database or model adapters. No asset/runtime/model download APIs or third-party dependencies are added. Speech-daemon networking is not observed; no global no-network claim is made.

One fixed test invocation runs on a fresh disposable preinstalled iOS 27.0 simulator. Missing SDK/runtime/voice, compile failure, cancellation, skipped test or missing callback fails; no substitute success is created. The eight-minute XCTest limit terminates this component test only. It does not extend any application budget/deadline and cannot create a completed receipt. Logs, result bundle and authored attachments remain available on success or failure. The runner shuts down/deletes only its own simulator.

## Not covered

Actual NavigationModel/Feedback admission and wakes, real camera/Vision acquisition, foreground/private-route lifecycle, hazard interruption, an individual speech callback lasting over 60 seconds, assistive-audio intelligibility, source-bound follow-up and menu understanding remain unproven by this component probe. The component's total playback exceeds 60 seconds through real budget waiting; that does not claim every utterance or wait lasts 60 seconds.

Physical camera/Vision acceptance still requires the normal app on real hardware with an authored page and unchanged gates. Component callback evidence is not that acceptance.
