# Mac mini handoff

## Mac day — start here (2026-10-09)

**Get the code:** `git clone https://github.com/mischa23v/blind.git` (private). No archive is needed any more. `server/.env` (developer API keys) is not in Git; it is not needed on the Mac. The Anthropic test key pasted in chat on 2026-10-09 is for one week; revoke it in the Anthropic console afterwards.

**Where things stand:**
- **BlindCore** (all decision logic, matching rules, safety checks): builds with Swift 6.2 and **all 235 XCTests pass** in a Linux container (`artifacts/windows-stage/swift-test-3.log`), including 8 walking scenarios on the sourced OAS apartment plan (transcripts in `artifacts/windows-stage/home-walk-transcript-*.txt`).
- **iOS app files** pass a Swift syntax check only. The app target has **never been compiled**; expect a round of small fixes. An independent review already fixed the clearest issues.
- **Node relay/tools:** 54/54.
- Rules to keep (see AGENTS.md): free on-device model only; nothing leaves the phone; spatial safety rule; identity by image comparison, never by the model; speed first; minimum words while moving.

**Order for the first session:**
1. `node tools/mac-preflight.mjs --multimodal`, then `npm ci --ignore-scripts`, then `npm run mac:setup -- --multimodal --ui` (Xcode 27 / iOS 27 SDK). Fix compile errors until BlindCore, BlindMemory and the app build and their tests pass. Also build without `--multimodal` (Vision fallback).
2. On the iPhone 18 Pro Max, measure the **built-in model**: time to first words and total, with the compact guide prompt (`BlindCore/Sources/BlindCore/Resources/guide-prompt.txt`), using the existing signposts in Instruments.
3. Implement **speaking the first sentence early** (left for the Mac because the API needs checking): use the Foundation Models streaming response in `LocalImageAssistant`; as each complete sentence arrives, run `SpatialClaimGuard` on that sentence, keep within the word reservation, check the view is still current, and pass it to `Feedback`; stop the stream if the view, goal or room changes.
4. **Your eyes-open walk** (you, not your brother): scan two rooms; walk between them; check room recognition and the first-visit offer; "this is my cup" (turn it) then "where is my cup" from a different spot; "where is the exit sign" on a printed sign; a chair placed in the path; restart the app in a room and check it asks before giving directions; open Settings › Saved memory and delete an item and a room.
5. **Calibrate with your real rooms and objects** (values are placeholders until then):
   - `ios/BlindAssist/RoomRecall.swift`: `maxDistance` (feature-print scale), `borderline`, `verifiedScore`, the registration limits in `registers`, `learnInterval`.
   - `BlindCore/.../ItemAppearanceMatch.swift`: `acceptDistance`, `similarDistance`, `margin` (try two similar cups).
   - `BlindCore/.../RoomRecognizer.swift`: `strongImage`, `strongFurniture`, `strongLayout`, `competitorMargin`.
   - `ItemAppearance.swift`: `newViewDistance`; `NavigationModel` learning views (4) and timeout (25 s).
   - `GuidanceCadence` milestones (5/3/2/1 m), `BodyHeadingEstimator.minWalkDistance` (1.5 m), room settle time (2 s), answer window (5 s), offer window (14 s).

**Design pass (VoiceOver reads every word on screen when he swipes):**
- Shorten every on-screen help paragraph to a few words (Guide, Ask, Settings).
- Say "From the camera:" at most once, and not at all once the chest mount is set.
- Consider dropping "metres" while walking ("Door: ahead, 2"), keeping it when standing.
- Check offer and question wording with your brother; review the Arabic phrasing.

**Decided not to build:** family-phone detection and exact face recognition (dropped 2026-10-09). The consent people registry exists but is not wired. **Needs a decision later:** a bundled object detector for "where is the fork" (today: text and people), and DINOv2-S / ALIKED+LightGlue for stronger matching (on-device, need a download go-ahead).

**Privacy check on device:** the app build has no picture-sending path (cloud scene request only with the developer flag `BLIND_DEVELOPER_CLOUD`, never set by the project generator). Confirm in Settings that no scene-service fields appear.

---

## Earlier handoff notes (history)

**Transfer checkpoint — 2026-10-08:** start with [CONTINUATION_HANDOFF](research/CONTINUATION_HANDOFF.md). The user requested a pause. Latest recorded suite has 39 passing checks, but subsequent changes are untested; 22 hosted native tests, six UI tests and expanded package tests await Apple execution. The full minimum is unfinished. Use the newest source archive containing that handoff. Earlier counts below describe historical checkpoints; setup commands remain preparation for the user's Mac testing go-ahead.

This is a development prototype for supervised evaluation. The Mac builds the iPhone app; the iPhone supplies camera, depth, motion and Bluetooth. No provider account is needed for offline monitoring, maps, text recognition or deterministic descriptions.

## Latest handoff — 2026-10-08

**Latest continuation: 37 lightweight Node tests and 15/15 context-delivery scenarios passed.** The [minimum checkpoint](research/MINIMUM_ASSISTANT_HANDOFF.md) records the speech journal, longer follow-ups, 14 prepared hosted native tests, six UI tests and exact remaining integrations. Swift/Apple tests have not run. Use the latest archive, preserving older archives as evidence. Community download/offline review, interests and the optional local image adapter are described in the [community handoff](research/COMMUNITY_IMPLEMENTATION_HANDOFF.md).

The user's Sol report is included as `research/user-notes/blindw.txt`, with [reviewed additions and verified research links](research/SOL_IDEAS_REVIEW.md). Four explicit follow-up tasks and eight prepared scenarios are now tracked; no broad product redesign or additional dependency is required before transfer.

For the image-model build, select **Xcode 27 / iOS 27 SDK** and use the following sequence after the user starts testing. The compile flag is explicit because Swift 6.3 alone does not establish availability of this API. Actual model/device/language availability is checked at runtime.

```sh
node tools/mac-preflight.mjs --multimodal
npm ci --ignore-scripts
npm run mac:setup -- --multimodal --ui
```

The commands below without `--multimodal` prepare the Vision/evidence fallback build. Neither build has been compiled here. Test both configurations before claiming fallback compatibility. The native mapping preparation also accepts `--multimodal`, but its dependencies remain a separate later build.

The Mac is available; the user is waiting for its keyboard and mouse, expected tomorrow. **Builds remain deferred until the user's go-ahead.** Start with the non-building check below. GRDB is pinned to 7.11.1 and requires **Swift 6.1 or later**; the optional Apple language model also needs its documented OS/device/language support. The new native changes have not been compiled or run on an Apple device.

```sh
node tools/mac-preflight.mjs
```

This only inspects installed tools and handoff files, then writes `artifacts/mac-checks/preflight.json`. It does not install packages, build, launch Docker or download models. If full Xcode/SDK/Swift checks fail, resolve those before starting builds.

After build approval, from the extracted project folder:

```sh
npm ci --ignore-scripts
npm run mac:setup -- --ui
```

The verification stage now runs both BlindCore and **BlindMemory** XCTest suites before app builds. New test sources cover approval/rejection/stale revisions, profile separation, deletion/import, dialogue persistence, unknown-place recovery and narration accounting. Windows SQLite tests execute the production SQL resources, but do not substitute for the GRDB/Swift tests. The first build resolves GRDB from its pinned package release; no package resolution has occurred here.

Read [the native implementation checkpoint](research/NATIVE_MEMORY_HANDOFF.md) for changes, exact verification boundaries and the device scenario order. Do not use earlier archives as the current source baseline. No new provider account or Dot access is needed for these first checks.

For the iPhone 18 Pro Max performance work, use [the hardware and benchmark plan](research/IPHONE_PERFORMANCE_PLAN.md). Native timing markers are ready for Instruments; CPU/GPU/Neural Engine utilization and sustained operation have not been measured. Profile concurrent camera, model, memory and speech work before tuning rates.

## Start on the Mac

For your M1 Mac mini (16 GB RAM, 256 GB storage) and iPhone 18 Pro Max, use the existing hardware first. Apple lists the M1 mini as [compatible with macOS 27](https://support.apple.com/en-us/127255). Install a stable Xcode release that supports the iPhone's installed iOS, following [Apple's current Xcode requirements](https://developer.apple.com/xcode/system-requirements/). The setup script records memory, architecture and available workspace space in `artifacts/mac-checks/machine.json`. Start with the base build; defer the larger native mapping dependencies until that passes. Total native build storage has not been measured on this Mac.

Install full Xcode with its iOS SDK and an iPhone simulator runtime. Open Xcode once and finish its setup. Select it under Xcode Settings > Locations > Command Line Tools. Install Node.js 22 or newer. Extract the handoff archive into a writable folder and open Terminal there.

```sh
npm run mac:setup -- --ui
open ios/BlindAssist.xcodeproj
```

The setup command runs Node tests, Swift XCTest, C++ protocol tests, unsigned iOS Simulator and device builds, and simulator UI tests. It stops on the first failure and saves logs and a report under `artifacts/mac-checks`. These Apple SDK checks have not been run on Windows. A successful Swift syntax parse is not an iOS build.

In Xcode select the BlindAssist app target, your signing team, a unique bundle identifier if required, and your connected LiDAR-capable iPhone. Enable Developer Mode on the phone when requested, then Run. Use a current Xcode SDK to compile the optional Foundation Models path. Older supported systems fall back to deterministic descriptions. Model availability and on-device speech availability also depend on the device, installed assets and language.

The simulator supports interface and synthetic-reading tests. It cannot validate LiDAR, RoomPlan, physical BLE, body-mounted camera behavior or real haptics.

After downloading the public stair subset with `uv run python tools/download-stairs.py`, run `npm run evaluate:images` to test Apple's actual image classifier on the 12 RGB frames. The JSON report records supported labels and per-image scores. No matching runtime stair labels means the built-in model cannot supply this feature; it is not a passing result. Add ordinary-floor and stair-poster negative examples before estimating false alarms. This command is separate from the language-model evaluation and makes no cloud calls.

For the fake café evaluation, run `npm run simulate` and open `artifacts/simulation/report.html`. Then run `npm run evaluate:apple` to test the real on-device model's English and Arabic ID selection on a supported Mac. This makes no cloud calls. See `research/SIMULATION.md`; model unavailability or unsupported Arabic is explicitly reported, not treated as a passing test.

## Native 3D mapping build

The base project does not include native RTAB-Map. On an Apple Silicon Mac with CMake installed:

```sh
npm run mac:setup -- --native --install-native-deps
open .tools/rtabmap/app/ios/RTABMapApp.xcodeproj
```

The preparation script downloads the pinned upstream revision, adds the app sources and local Swift package, and removes upstream signing identities. The dependency build needs internet, disk space and time. Read the pinned upstream `install_deps.sh` and [RTAB-Map iOS installation instructions](https://github.com/introlab/rtabmap/wiki/Installation) if its toolchain requirements change. Set your signing team on this target too. Enable “Build private 3D map on next start” before starting monitoring.

This adapter saves a local database. Extracting a navigable collision surface from that database and establishing reliable localization in a previously saved map are still unfinished; the native build does not make those features automatic.

## Optional photo assistant

Copy `server/.env.example` to `server/.env` on the machine hosting the service. Set a provider key, image-capable model identifier, and a long random service access token. Run `npm run server`. Put the relay behind HTTPS reachable from the phone; its default localhost binding is deliberately not a phone-accessible public endpoint. In app Settings, enter the HTTPS URL and service token, enable network access, then check the connection. The provider key stays on the server.

The connection check confirms service configuration and access, not provider billing or model availability. Each photo request requires the in-app send action; its confirmation includes the photo, question, goal, saved interests, up to six recent conversation turns and matched-room inventory. Full map geometry and journeys are not sent. Server unit tests use fake providers; twelve earlier bounded Sol 6.1 API-key evaluations used synthetic text context, not an iPhone image or plan sign-in. Do not put credentials into the handoff archive.

## First device session

Add the offline import/corruption/revision/export, preference persistence, real-image and SDK-fallback cases from the [latest continuation](research/COMMUNITY_IMPLEMENTATION_HANDOFF.md). The supplied apartment package is a preview-only authored drawing, not the user's home or an indoor navigation trial.

1. Verify VoiceOver can reach Guide, Ask, Places, Routes and Settings, with large text and English/Arabic layout. Check that all controls announce their purpose.
2. Run the labelled simulation. Check urgent interruption, repeat, stop descriptions and stop monitoring.
   Test the new repeat-monitoring-status button and cause-specific English/Arabic hints. Brief observing frames during uncertainty must not repeatedly restart guidance; recovery requires one continuous second, while a new rise/drop must interrupt immediately. Verify the image-check status reports supported/unavailable honestly. Measure depth-loop latency, memory, battery and heat with the denser sampler and concurrent RGB classification.
3. On a level supervised test area, start monitoring and calibrate. Check loss of camera tracking, covered camera, backgrounding and restart. Phone monitoring stops in the background.
4. Use the wiring and power instructions in `hardware/CONNECTIONS.md`. Build/upload only the matching board firmware, then pair belt and wrist individually. Check disconnects, stale readings and independent belt haptics. No physical hardware checks have been performed here.
5. Test text/person descriptions and on-device voice questions. Interrupt a pending answer with a hazard; turn or move before an answer returns and confirm the stale view is discarded. Check microphone/audio-session recovery.
6. Import `maps/center.example.json` as a format example only. Replace it with surveyed landmarks and verified connections for the real venue. Select a known start, plan, and align at each landmark. Do not use the example coordinates in a real building.
7. Test current-session retracing only while tracking remains continuous. Saved journey history is not a localized route after relaunch.
8. In the native build, test map growth, stop/save, relaunch, export and deletion. Measure battery, heat, memory and frame latency on the actual phone.
9. Open Places > Walk-through mapping progress. Verify trail and measured floor cells separately, then deliberately cover the camera while stationary and check that lost tracking clears the preview. RoomPlan capture is a separate mode.
10. In a fictional route map, add a keep-out area around a landmark and confirm the old route/alignment is cleared, planning avoids or rejects that area, and export/import retains it. Check removal confirmation with VoiceOver. Do not use a real stair edge to test this. Physical tape detection and continuous boundary alarms are not implemented.

Work with the brother's or school's orientation-and-mobility specialist on wording, mounting, alert intensity and supervised trial tasks. The tests do not establish suitability for independent travel.

## Contents and remaining connections

The archive contains source, tests, example maps, firmware configuration and documentation, plus the generated synthetic café report when available. The [elevation evaluation](research/ELEVATION_EVALUATION.md) includes real-data download/replay commands and records missed up/down steps and room-control failures. Raw and derived external datasets are not bundled; their separate license and attribution records are regenerated by the download tools. Dependency caches, compiled output, credentials and personal map databases are excluded. Native dependencies download on first setup. From the extracted folder run `node tools/check-handoff.mjs` to check every packaged file against its SHA-256 manifest before editing.

See `research/THREE_LAYERS.md` for the architecture and the exact implemented/unfinished connections; `research/ASSISTANT_POLICY.md` for evidence and speech policy. No custom model has been trained. Rich offline visual question answering, automatic venue loading, reliable saved-map localization, live obstacles fused into the venue collision layer, and validated multi-floor navigation remain development work.

Use `maps/SCHOOL_MAPPING.md` for a supervised school mapping workflow. Review `research/LICENSE_REVIEW.md` before a public source/binary release; the dependency review is incomplete and includes a concrete conflicting-notice finding.
