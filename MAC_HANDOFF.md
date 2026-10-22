## CURRENT — always-on build to validate first (2026-10-22, cloud session)

Supersedes the "hallucination fix" section below as the starting point. The companion is now always on: no off switch, listening/speech/belt continue in the background, camera loss announced and restarted automatically. See PROGRESS (top entry), AGENTS.md "Always on", and research/HALLUCINATION_REVIEW.md (dots research and scan verdicts).

**Guardian setup on the phone:**
- Turn on Guided Access (Settings › Accessibility) so the app stays in front and the side button cannot lock it by accident.
- Allow microphone, speech, camera, Bluetooth and location.
- Optionally assign the Action button or Siri: "Open Blind Assist".

**First Mac steps:** follow TODO "Next — Mac and iPhone (always-on build)". Already verified in a Linux Swift 6.2 container: BlindCore 361/361, BlindMemory 14/14, and all app Swift files parse. Also verified: Node 131/131 and the firmware host tests. Unverified: the iOS app build, UI tests, the hardware builds and anything on a device.

**Project:** the checked-in `ios/BlindAssist.xcodeproj` is current. To test the optional Lock Screen status, run `node tools/generate-xcode-project.mjs --live-activity` (it adds the `BlindAssistLiveActivity` widget extension); run the generator without the flag to go back.

## CURRENT — hallucination fix to validate first (2026-10-22, cloud session)

This supersedes the "pause checkpoint" below for the next Mac session. Read [research/HALLUCINATION_REVIEW.md](research/HALLUCINATION_REVIEW.md).

**What changed (source only, not compiled here):**
- Code answers find requests and location reports from the child's own reports (`BlindCore/CompanionFacts.swift`).
- Model chat is checked by `ConversationClaimGuard` and `SpatialClaimGuard`.
- Image descriptions keep only objects the detectors agreed on in 2 of 3 frames, or hedged sentences (`VisualGrounding`).
- Sessions are prewarmed. The old model-written task state and the decorative agent ports were removed, along with `ios/ThirdParty`.
- The main screen shows only the current reply.
- Answering an offer no longer switches the microphone off.

**Model decision:** keep Apple's free on-device model. Gemini Nano is Android-only and the same size class. Gemma 3n is a possible side-by-side test, not a fix. Private Cloud Compute breaks the privacy and offline rules.

**Order on the Mac:**
1. Run `swift test` for BlindCore, including `CompanionEvidenceTests`.
2. Build the app with and without `--multimodal`, and fix compile errors.
3. Run the rewritten `LaunchTests` and the real-model `ConversationTests`/`TextChatScenarioTests`.
4. Retype the recorded failures in `--text-only`.
5. Do the timing and VoiceOver checks on a LiDAR iPhone.

Node is 125/125. Swift is unverified.

**Main screen access:** with VoiceOver, swipe up/down on the reply for Repeat, Write a message, Places, Routes, (People), Settings, and Yes/No when the assistant asked a question. Sighted helpers long-press the reply for the same menu. Magic tap repeats the reply. Other tabs keep the normal tab bar, so tap Assistant to return.

## Previous pause checkpoint for Claude review, 2026-10-22 (superseded by the section above)

**Combined source checkpoint:** newer master `694eccb499eb3b505386210c7a875abb85448821` was fetched through the GitHub connection and reconciled with the Mac work before pushing. Currency/reference-matching and clothing-colour integration are preserved. Two NavigationModel conflicts were resolved by retaining both the conversation timeout and currency/colour properties/cancellation resets. Existing remote documentation is retained below. The combined source has NOT had a fresh Apple SDK build or full scenario run; the user requested stopping for the night. Tomorrow validate the combined source first. The active generated AuraFace project is preserved, not regenerated; no model/photo/signing/tool-cache upload. The ZIP folder still has no Git metadata.

User requested saving/pushing the current work and continuing tomorrow. This is a work-in-progress checkpoint, NOT a working/accepted companion. Keep all local changes. Do not change model before diagnosing our Apple-model integration. Voice is paused; launch with `--text-only`. Do not regenerate the active AuraFace project. No physical iPhone is available for this checkpoint.

### What the app is meant to do

An eight-year-old blind child's conversational companion: understand the child's requests, keep goals/progress, respond to new observations and corrections, use available sensors/tools, and adapt when the child changes their mind. Normal interaction should not require Start/Talk/Repeat. Useful bottom tabs remain for people, maps and settings. Immediate sensor warnings must not wait for an LLM. Current work is typed chat first; continuous sensing, speech and 24-hour operation are NOT proven.

### Exact actual-app failures and comparison

These were typed into the running iPhone simulator app, not inferred from keyword tests. Synthetic scene statements are child reports, NOT camera/LiDAR observations.

| Build/path | Input | Actual reply | Assessment |
| --- | --- | --- | --- |
| Earlier structured path | The fridge door is closed. | fridge door: The fridge door is closed.. | Our field-to-text rendering was poor; removed. |
| Revised context | The fridge door is open now. What changed? | The fridge door was closed, then it is open now. | Correct change after a preceding closed report; awkward wording. |
| Task request | Help me find my cup. | Your cup is not found. Would you like help searching? | No search occurred; redundant permission question. |
| Explicit missing-location workflow | Help me find my cup. | Your cup is not here. Where did you last have it? | Still invents absence. |
| Debug minimal plain conversation | Help me find my cup. | Where did you last have your cup? | Single-turn diagnostic passed. No old context or structured task output; does NOT validate normal app. |
| FINAL normal compact-context path | Help me find my cup. | Your task is to find your cup. Did you last have your cup near the table? | No absence assertion, but stiff wording and unsupported leading suggestion. |
| FINAL follow-up | I last left it on the kitchen table. | Your cup is on the kitchen table. | FAILED: historical report becomes certain current location. |

Desired final follow-up behavior: acknowledge that the table is the last reported location, keep current location unknown, and offer a useful next step only supported by available inputs. Example: “You last left it on the kitchen table. I don't know whether it's still there.” This is an example of the evidence distinction, not a phrase to hard-code.

Earlier normal revision: backpack replacement updated visible goal to `find my backpack`; cancellation removed visible goal. First cup goal extraction initially failed, later fixed by copying the entire explicit request. Final compact build displayed `Help me find my cup.`. Full switch/cancel regression was not rerun after the final context change.

### Timing and validation

- FINAL active Xcode `BuildProject`: PASSED,6.980 seconds. Isolated base simulator Apple-SDK build: PASSED. This is an actual iOS build, not syntax checking.
- FINAL affected privacy/spatial Node checks:6 passed. Earlier broader guard selection:17 passed. These checks do not catch all ungrounded conversational statements.
- FINAL normal first complete sentence:8.384551 seconds; natural reply finished9.141065 seconds, measured by app timing logs. FAILS responsiveness target. UI screenshots give looser upper bounds, not exact latency.
- Earlier compact attempts: roughly9–11 seconds to first sentence. Structured model-selected context tool round trip previously exceeded60 seconds and was removed.
- NOT RUN for final build: full scenario matrix, restart/correction/long-session reliability, real phone sensors/ARKit/LiDAR, voice/VoiceOver conversation, thermal/battery/24-hour operation, Gemma comparison.
- Older22 XCTest passes and other historical suites are NOT proof of the final conversational changes.

### Current implementation and what was tried

`ios/BlindAssist/LocalImageAssistant.swift`: short role; labeled original chronological child messages; saved name, goal, proposed step and reported progress; historical map records distinct from live inputs. Empty fields, old assistant replies, old extracted facts and duplicate copies of the current request are omitted from the prompt. All persisted data is retained. Current prompt window is bounded; general long-term retrieval is unfinished.

Normal path now streams a plain natural reply first, then performs a separate guided `CompanionDecision` task/fact extraction in the same native Apple session. Metadata cannot rewrite the answer. Spatial text checks remain. `--chat-baseline` is DEBUG-only and uses a minimal role plus latest typed message, without saved context or task updates. Final app was left in NORMAL `--text-only`, not baseline mode.

`NavigationModel.swift`: protected on-phone working state and name; records the user message before inference; validates request identity/goal revision; cancellation clears obsolete steps;30-second failure deadline preserves an already displayed reply. Structured extraction still depends on the model. Quote validation does not establish semantic truth. Full task suspension/resumption and sensor/action execution are missing.

Do not conclude Apple is simply a bad model: the minimal baseline answered correctly while the contextual path failed. Conversely, stronger instructions alone have not fixed the normal path. No switch to Gemini/Gemma, cloud calls or personal photo uploads occurred.

### Questions for Claude / next investigation

1. Which supplied context field or instruction causes unknown/last-reported locations to become present-tense claims? Compare one component at a time against the successful minimal baseline, using the same messages in the running app.
2. Is the conversation role still overloaded? How should facts, historical reports, goals, proposals and actual tool results be represented for this small local model?
3. Should conversational generation and state extraction use separate sessions, or another verified native transcript structure? Measure quality and delay instead of adding more prompt rules blindly.
4. How can temporal/source constraints be enforced without hard-coded replies or suppressing useful conversation? “Never hallucinate” is already requested but not sufficient.
5. How do we retain a task and useful memory across interruptions/restarts while excluding obsolete instructions? Add repeatable state/result assertions, then manually inspect replies; keyword-only tests previously missed failures.
6. Profile prefill, first useful sentence, metadata generation and thermal load. The current8.4 seconds is not instant; a Mac-backed simulator result is not an iPhone performance result.

Relevant research: [Inner Monologue](https://innermonologue.github.io/) demonstrates scene/success feedback, changed goals, resumption and stop; [tau2-bench](https://github.com/sierra-research/tau2-bench) evaluates human/agent shared-state coordination; Anthropic [agent patterns](https://www.anthropic.com/engineering/building-effective-agents) and [context engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) emphasize simple loops and relevant context. These do not prove our integration. The bounded ROSA/SayCan/LangGraph/BehaviorTree ports listed at the time were removed later on 2026-10-22 (they did not change behaviour); see research/HALLUCINATION_REVIEW.md.

Detailed local evidence is in `ios/.validation-results/text-chat-status.json`, `interactive-agent-scenarios.json`, and `companion-prompt-research.txt`; shareable snapshots accompany this checkpoint under `ios/validation/companion-chat/`. Preserve failed examples. No further model/setup work tonight.



# Mac mini handoff

## Current currency and colour addition — 2026-10-22

Preserve the Mac fixes recorded below. This combined source preserves `c4f7a26` and the subsequent `295ca393` transfer record and adds no-new-training currency comparison plus requested clothing-colour appearance. Currency remains explicitly unavailable because no independently validated reference pack is selected. A folder or successful build does not activate it. Do not start the dormant classifier-training route.

Colour commands include “What colour is this shirt?”, “Check the colour”, “ما لون هذا القميص” and “وش لونها”. Results describe captured appearance, not certified fabric reflectance; white/gray/cream and school acceptance stay uncertain. Two-item comparison is still unfinished. Test real fabrics, masking/background spill, lighting and interrupted/repeated requests on the phone.

Fresh recovery checks: core 349/349, Node 116/116, reconstructed portable mechanics 55/55, strict Clang/GCC header syntax, and 40 app Swift files parsed in three configurations. This is not a combined Apple SDK build or phone test. Prior Mac face/UI results below cover their own checkout. The source recovery and lost original photo-evaluation evidence are explicitly documented; no old accuracy claim is inherited by reconstructed code.

After default setup, generate the optional currency native build with:

```sh
node tools/generate-xcode-project.mjs --currency-reference --opencv-framework /absolute/path/opencv2.framework
```

Use the pinned official OpenCV 4.14.0 framework from the face workflow. It lacks arm64 simulator support, so use the device build on M1. Existing face options may be combined; OpenCV is linked once. Reference images remain private and are not supplied. See `research/CURRENCY_REFERENCE_MATCHING.md`, `research/CLOTHING_COLOR.md` and the runtime pack contract. Before enabling money, require audited denomination/side/material coverage, independent costly-confusion/unknown/multiple-note tests, actual composite rejection, native parity, adult device tests and a reviewed immutable profile. No authenticity or summing feature exists.


## Mac validation update — 2026-10-22

Local pre-currency ZIP testing completed on M1/8 GiB with Xcode 27.1: base simulator/device, optional multimodal device, and signed AuraFace device builds passed. XS Max installation succeeded and the user confirmed launch. Hosted iOS tests passed 22/22; the latest UI batch passed 5/6, with a remaining Dynamic Type audit failure. See PROGRESS for exact scope and unresolved Xcode AppKit layout crashes. These results do not validate the later Saudi-banknote code or all device scenarios.

XS Max can launch the app and exercise simulation, but has no LiDAR. The current live-monitoring and familiar-face camera capture gates require scene depth. Use a LiDAR-capable physical iPhone for those acceptance checks. The base iPhone 18 Pro Max simulator passed tab navigation and simulation start/stop; it does not validate real LiDAR or AuraFace. Preserve the physical AuraFace configuration and keep the optional Vision veto off initially. Do not regenerate the default project after selecting the backend.

For local development installation, select full Xcode command-line tools, sign in privately to Xcode and select the development team. Enable Developer Mode on the phone, confirm after restart, unlock it during preparation, and complete developer-profile trust/online verification when prompted. These device setup steps are separate from compiler errors. No signing credentials, model assets or machine-specific generated project should be committed.

## Primary master branch — current familiar-person handoff (2026-10-22)

This section supersedes the older status counts below. This is an opt-in experimental assistive hint, not a production release, Face ID, or permission to follow someone. Linux checks do not compile Apple SDK code. Mac/Xcode and physical iPhone checks are still required before supervised use.

The shared primary branch is named `master`, not `main`; do not rename it. The completed face work is integrated there at the user’s request. Future authorized changes to this repository should reconcile the current remote head and integrate without force, so cooperating tools share one primary version. This is a collaboration workflow, not a production-readiness claim. If you downloaded an older master ZIP, obtain a fresh copy after this update. Do not overwrite local edits.

Use a separate checkout so existing local work is untouched:

```sh
git clone --branch master https://github.com/mischa23v/blind.git blind-familiar-review
cd blind-familiar-review
npm ci --ignore-scripts
npm run mac:setup -- --ui
```

That setup command regenerates the DEFAULT project. Run it first, not after selecting the experimental backend. Finish Xcode setup and select its command-line tools first. Use a current stable Xcode compatible with the phone's installed iOS. No developer cloud keys are needed.

Next obtain the exact OpenCV framework and external models documented in `research/FAMILIAR_PEOPLE_EXPERIMENT.md`, `research/AURAFACE_NATIVE_BACKEND.md` and `ios/BlindAssist/FamiliarNative/MODEL_NOTICES.txt`. Keep them outside the checkout. The supplied model-assets ZIP contains YuNet and SFace only; AuraFace is a separate 260.7 MB official pinned download. Do not substitute a similarly named checkpoint. The generator checks the selected model hashes and OpenCV version.

For the optional AuraFace experiment:

```sh
node tools/generate-xcode-project.mjs --familiar-people --familiar-backend auraface --opencv-framework /absolute/path/opencv2.framework --familiar-models /absolute/path/models
xcodebuild -project ios/BlindAssist.xcodeproj -scheme BlindAssist -configuration Debug -jobs 2 -destination 'generic/platform=iOS' -derivedDataPath artifacts/xcode-familiar-device CODE_SIGNING_ALLOWED=NO build
open ios/BlindAssist.xcodeproj
```

Replace both absolute paths with actual local asset paths. Choose `--familiar-backend sface` for the smaller alternative. Model galleries are backend-specific and cannot be carried between these two models. The pinned prebuilt OpenCV framework contains arm64 iPhone and x86_64 simulator slices, but NOT arm64 simulator. On an M1 Mac, use the device build for this experiment; default simulator UI checks do not test the face engine. A compatible custom XCFramework is a separate, unverified build path.

Select the app target, signing team and connected LiDAR-capable iPhone in Xcode. Resolve signing and device development prompts yourself. Start existing monitoring and calibrate it, then open Settings → Familiar people. Enable the experiment explicitly. Enroll consenting adults under your own labels using imported local photos or guided camera capture; review at least three and at most six examples before confirming. Photo selection uses Apple's accessible picker, not custom voice control inside that picker. The two-pipeline Vision veto is optional and uncalibrated; keep it off for the initial single-backend comparison.

The child-use design assumes a chest-worn rear camera, but actual framing, orientation, field of view and usable face size need checking at that height. A person looking toward the wearer may still be outside the camera. The current capture gate requires a steady, tracked portrait view; reliable walking recognition has not been demonstrated. Short hints remain uncertain and must not replace listening or adult supervision.

Device acceptance must include actual enrollment/import/review/deletion, interrupted and cancelled actions, speech and VoiceOver, unknown/lookalike faces, no face, multiple people, turning away/back, stale/out-of-order results, tracking loss, hazards, foreground/background transitions, model load, Apple pixel/orientation parity, memory, latency and thermal/battery behavior. A passing photograph benchmark is not a pass for these app scenarios. No 24-hour/background-camera operation is promised. Use simulated hazards, not real drops or stairs, during initial checks.

## Mac day — start here (2026-10-09)

**Get the code:** `git clone https://github.com/mischa23v/blind.git` (private). No archive is needed any more. `server/.env` (developer API keys) is not in Git; it is not needed on the Mac. The Anthropic test key pasted in chat on 2026-10-09 is for one week; revoke it in the Anthropic console afterwards.

**Where things stand:**
- **BlindCore** (all decision logic, matching rules, safety checks): builds with Swift 6.2 and **all 235 XCTests pass** in a Linux container (`artifacts/windows-stage/swift-test-3.log`), including 8 walking scenarios on the sourced OAS apartment plan (transcripts in `artifacts/windows-stage/home-walk-transcript-*.txt`).
- **iOS app files** (historical, 2026-10-09) passed a Swift syntax check only at that time; the app has since been built on the Mac (see sections above). An independent review already fixed the clearest issues.
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
