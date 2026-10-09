# iPhone 18 Pro performance and local processing

Updated 2026-10-08. User requirement: exploit the phone's CPU, GPU and on-device inference capacity; do not impose a weak-model ceiling simply because it is a phone. Preserve strong optional account models as well. No benchmarks were run here.

Apple confirms A20 Pro uses a 2-nanometer process, a seven-core GPU and upgraded Neural Engine and thermal design. Apple reports improvements relative to A19 Pro, including GPU and sustained-performance gains. These are manufacturer claims, not measurements of this app. The user's comparison with desktop graphics needs a named workload/device/API for a meaningful numerical comparison; no desktop-equivalence claim is recorded. [Apple announcement](https://www.apple.com/newsroom/2026/09/apple-debuts-iphone-18-pro-and-iphone-18-pro-max/), [specifications](https://www.apple.com/ca/iphone-18-pro/specs/).

## Use the hardware through established APIs

| Work | Existing integration / evaluation direction |
| --- | --- |
| Camera, depth, tracking and room capture | ARKit/RoomPlan manage platform acceleration. Measure current depth sampling alongside tracking and model inference before changing rates. |
| Visual recognition and local model inference | Vision and compatible Apple Foundation Models first; evaluate supported Core ML compute-unit choices. A custom local VLM remains a separate model/license/memory/accuracy decision. |
| Image processing and geometry display | Existing Core Image/RoomPlan paths; use Metal-backed established operations where profiling identifies a benefit. No bespoke rendering/inference engine needed. |
| Personal memory | GRDB/SQLite for compact structured records and revision history; large measured meshes/photos remain files. More GPU throughput does not justify copying whole maps into every prompt. |
| Optional remote reasoning | Keep supported strong provider models selectable. Compare quality, latency, availability and costs using the same cases; local computation and cloud reasoning can coexist. |

Xcode's model performance reports identify which operations use CPU, GPU or Neural Engine. Compare compute configurations rather than assuming every model fits or every operation uses the Neural Engine. [Core ML profiling](https://developer.apple.com/documentation/coreml/analyzing-a-core-ml-model-s-performance-in-xcode). Instruments can correlate graphics/thread activity and thermal state. [Metal performance analysis](https://developer.apple.com/documentation/xcode/analyzing-the-performance-of-your-metal-app/).

## Instrumented source, awaiting Apple verification

Added Apple's `OSSignposter` intervals using unique IDs and paired `defer` endings: `SensorFrame`, `SceneResponse`, `RoomMemoryRead`, `RoomApproval`, `AlertDispatch`. Subsystem: `org.blindassist.mobility`; category: `AssistantPerformance`. Labels contain no scene text, names, map data or credentials. These markers are source-only until the Apple build and trace are run. `AlertDispatch` measures app dispatch work, not when speech reaches the user's ear. [OSSignposter API](https://developer.apple.com/documentation/os/ossignposter).

## Q05 benchmark matrix after the user's build/test go-ahead

Record device/model, iOS, app revision, model/version, compute configuration, low-power mode, case/mount, ambient conditions, language and network state. Keep the phone stationary in the first bench run.

1. Measure monitoring alone, then monitoring with local perception, goal/memory retrieval and VoiceOver, then the complete supported combination. Measure room capture separately because the current capture workflow pauses phone hazard monitoring.
2. Repeat cold and warmed runs; use an initial bounded five-minute run, then a 30-minute sustained run if the first remains stable. Record p50/p95/p99 processing/response latency, dropped/stale frames, memory peak, thermal transitions, battery energy and cancelled/stale answers.
3. Correlate room reads/approval/export work with sensor callbacks. These adapters currently perform synchronous storage work from UI call sites; quantify main-thread stalls and move blocking work off the live path before claiming uninterrupted phone hazard latency. BLE/local firmware independence does not prove phone callback independence.
4. Compare low/high selected word rates at multiple VoiceOver rates. Measure relevant-information delivery and interruption recovery, not just tokens/second or graphics scores. Include English/Arabic and moving-view stale-answer rejection.
5. Retain only changes that improve measured useful output while preserving urgent response and tracking. Candidate adaptations are model compute configuration, image resolution, optional inference cadence and cached map features. Do not silently lower the user's requested information detail or suppress danger due to thermal load; communicate unavailable monitoring.

Hardware potential is a reason to evaluate richer local processing. It is not a substitute for map alignment, fresh sensor evidence, model grounding, supported APIs or verified energy/latency under simultaneous load.
