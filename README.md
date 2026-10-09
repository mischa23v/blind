# Blind Assist — offline mobility prototype

**Paused for later continuation (2026-10-08).** Start with [current handoff](research/CONTINUATION_HANDOFF.md). Latest recorded suite: 39 passed before further source changes; Apple/device tests have not run. The minimum assistant remains unfinished. Evidence summaries below describe earlier checkpoints.

Latest: [minimum assistant checkpoint](research/MINIMUM_ASSISTANT_HANDOFF.md), including community maps, interests, image adapter, conversation and speech-attempt history. **37 Node tests and 15 context-delivery cases passed.** Native tests are prepared; the app has not been built or verified on the Mac/iPhone. See [Mac handoff](MAC_HANDOFF.md) for the optional image build and remaining integration work.

The expanded sighted-assistant direction is tracked in [PROJECT_PLAN](PROJECT_PLAN.md), [TASKS](TASKS.md), [PROGRESS](PROGRESS.md) and [TODO](TODO.md). It covers immediate danger alerts, mobility/orientation, rich awareness, adjustable narration budgets, local memory and community maps. These documents distinguish planned work from the prototype below; Docker and heavy testing remain deferred at the user's request.

The relay validates room/pose/people/goal context, bounded dialogue and a per-request word allowance. New native source adds GRDB room revisions and review, unknown-place recovery, saved goals/dialogue and automatic narration controls; it awaits Apple compilation and device checks. [Native handoff](research/NATIVE_MEMORY_HANDOFF.md) separates this work from tested relay/SQL behavior. The [earlier home evaluation](artifacts/home-awareness/report.html) contains twelve real Sol 6.1 responses to supplied synthetic text context; it does not establish physical localisation or navigation. [Provider options](research/MODEL_PROVIDERS.md) include supported ChatGPT plan access and Apple multimodal APIs.

The design keeps camera/depth processing, personal maps, journeys, speech and wearable communication on the phone. The belt and wrist firmware run independent local range/haptic loops. Optional scene questions and outdoor map services require the user to enable network access.

Start with [hardware connections and power](hardware/CONNECTIONS.md) and the [Bluetooth protocol](hardware/PROTOCOL.md). They define which sensors connect to which controller and how the readings reach the phone.

For transfer and first launch, use [Mac mini setup](MAC_HANDOFF.md). The [three-layer architecture](research/THREE_LAYERS.md) distinguishes immediate sensing, the saved indoor venue and outdoor map selection.

See the [feature verification record](research/TEST_STATUS.md) for passed checks and untested features, and the [staged purchasing plan](hardware/BUYING_PLAN.md). The existing M1/16 GB Mac mini and iPhone 18 Pro Max are the starting development hardware; no full belt purchase is recommended before phone evaluation.

The belt remains a core part of the intended system. [Elevation and lighting research](research/ELEVATION_AND_LIGHTING.md) records robot cliff/terrain references, immediate-warning behavior and outstanding belt-attitude/coverage requirements. [Elevation evaluation](research/ELEVATION_EVALUATION.md) records upward/downward step scores, missed small steps and real-data calibration limits. [Real scan evaluation](maps/REAL_SCAN_EVALUATION.md) reproduces the downloaded Stanford/TUM apartment reconstruction inspection; it does not substitute for physical cliff tests.

## What is implemented

- iOS camera/LiDAR monitoring, explicit floor calibration, local text/person recognition and speech.
- Experimental local color-image stair warnings, with runtime label-support checks and stale/moved-view rejection. Images can add a warning, never clear a sensor hazard. Apple Vision accuracy is still untested.
- Denser depth sampling, cause-specific Arabic/English recovery hints, a repeat-status button and a recovery hold to reduce uncertainty/observing oscillation. Recent measured ground only informs rechecking; no invented floor clearance.
- BLE belt/wrist selection, hazard summaries and timestamped raw sensor fragments; stale/partial data rejection.
- ESP32-S3 belt firmware for two TFmini-S, eight VL53L5CX modules, one overhead VL53L1X, MB1040 PWM input, and eight haptic drivers.
- nRF52840 wrist firmware for a pointing VL53L1X and one haptic driver.
- Local journey recording with tracking-gap separation, export and deletion; RoomPlan/ARWorldMap place storage excluded from backup.
- Attention filtering with independent detail and narration frequency; richer moving descriptions remain possible when current-view and priority gates permit delivery. Urgent interruptions take priority. Native behavior awaits device checks.
- Native RTAB-Map integration adapter and reproducible preparation of its existing iOS project, pinned in `integration/rtabmap.lock.json`. This native app target still requires a Mac build and device validation.
- Authored indoor route graphs and optional outdoor MapKit search/Google Maps handoff. Google Maps data is not downloaded into the private SLAM database.
- Saved-map destination suggestions from questions, constrained to existing IDs; optional collision surfaces reject route legs without body/head clearance or known level floor. Imported graphs without surfaces remain explicitly graph-only.
- Guide, Ask, Places, Routes and Settings screens; on-device voice transcription where supported; selectable description focus; offline default; explicit one-photo cloud action.
- VoiceOver announcement output for app-selected text. Automatic VoiceOver image narration is not used for mobility. Optional ambient descriptions pause while VoiceOver is active, and urgent alerts preempt ordinary app speech.
- Experimental retracing within one continuous camera session, invalidated by tracking gaps or large position changes.
- RoomPlan scan coaching, projected 2D room plans, editable Arabic/English feature labels, SVG/JSON/USDZ export, private reference photos and optional on-device room-type suggestions. See [family mapping](maps/HOME_MAPPING.md).
- Continuous walking-survey preview showing the phone trail, actual observed floor cells and tracking status; no invented floor coverage or completion percentage.
- Saved per-floor [keep-out rectangles](maps/KEEP_OUT_AREAS.md), a parent/teacher setup screen, and route rejection with body clearance. Restrictions persist through map export/import. Physical vacuum tape detection and continuous boundary alarms are not implemented.

Run `npm run simulate -- --docker` to generate the [fake café report](artifacts/simulation/report.html). Its 17 scenarios execute real core logic against synthetic inputs; scripted model IDs are explicitly labelled. On the Mac, `npm run evaluate:apple` runs the same prompts against Apple's actual on-device model and reports English/Arabic support. See [evaluation details](research/SIMULATION.md).

## Build and verify

Node 22 or later:

```sh
npm test
npm run project
npm run verify -- --docker
```

Docker verification uses `swift:6.2-noble` for the platform-independent Swift tests and actual C++ firmware-logic tests. `ios/BlindAssist.xcodeproj` is the phone/BLE target without RTAB-Map. Open it on a Mac, select a signing team and build for a LiDAR-capable iPhone. No signing credentials are stored here.

For native mapping:

```sh
npm run native:prepare
```

On an Apple Silicon Mac, build the dependencies using the pinned upstream `.tools/rtabmap/app/ios/RTABMapApp/install_deps.sh`, following [upstream installation instructions](https://github.com/introlab/rtabmap/wiki/Installation). Then build `.tools/rtabmap/app/ios/RTABMapApp.xcodeproj`. The preparation script installs our mobility screen into that target and enables `BLIND_RTABMAP`; it does not fabricate prebuilt native libraries. Enable “Build private 3D map” before monitoring. Upstream and dependency licenses remain applicable; upstream libraries must be installed once before offline runtime use.

Belt firmware:

```sh
uv run --with platformio pio run -d firmware/belt
```

Wrist firmware:

```sh
uv run --with platformio pio run -d firmware/wrist
```

Flashing is a separate physical step after selecting the correct board/port and checking wiring; these commands only compile. The wrist uses Seeed's Bluefruit-compatible core, not the mbed/ArduinoBLE core. Board/toolchain downloads need several GB of free space.

Verification results and remaining device checks are maintained in [TEST_STATUS.md](research/TEST_STATUS.md). Both firmwares restrict sensor notifications to encrypted links. Windows checks do not perform an Apple SDK build or verify radio pairing, actual sensor timing or physical operation. Build outputs are `firmware/belt/.pio/build/xiao_esp32s3/firmware.bin` and `firmware/wrist/.pio/build/xiao_nrf52840/firmware.hex` / `firmware.zip`; use the board-specific upload tooling rather than interchanging these formats.

## Work still required for everyday mobility

This is not a finished independent-navigation device. Native RTAB-Map map generation is not yet connected to a complete phone-native Nav2-equivalent navigation loop. Reliable saved-map localization, mesh-to-navigation conversion and live obstacle fusion remain integration work. Authored-map destination selection and manual blocked-leg rerouting work at the code level; they do not supply automatic localization. Current-session retracing is experimental; saved journeys are history, not executable routes after relaunch. `LocalPlanner.swift` is an isolated experimental terrain test, not the production navigation foundation.

Wearable-to-world-map fusion still requires synchronized clocks and calibrated relative poses. Wrist IMU/sonar, battery telemetry, authenticated physical device provisioning, complete place-bundle export, automatic venue loading and robust floor transitions are not complete. Rich offline visual question answering is not implemented; current local descriptions use Vision evidence and optional language-model ID selection. Hardware sensor placement, actual throughput/latency, LRA tuning, battery/thermal behavior, VoiceOver and the full iPhone build need device acceptance. Four Mac-only UI tests include an accessibility audit; they have not run here. Tests of Swift core and C++ logic cannot substitute for these.

When app backgrounding stops the phone camera session, the phone stops monitoring. The belt remains responsible for its local alerts. That limitation must be included in everyday-use design and trials.
