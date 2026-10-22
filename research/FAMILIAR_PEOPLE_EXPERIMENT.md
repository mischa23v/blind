# Opt-in familiar-person comparison experiment

**Current held-out photo evidence:** a fresh filename-label-disjoint Aberdeen calibration/held-out protocol used ten-person galleries. On held-out probes, the old SFace 0.363/0.1 baseline matched 82/82 known probes but falsely named 7/193 unknown probes, across four of twenty unknown people. Calibration-selected SFace 0.7/0.2 matched 76/82 known probes, abstained on six, and falsely named 0/193 unknown probes. Calibration-selected AuraFace 0.5/0.2 matched 82/82 known probes with 0/193 false names. Those model-specific calibrated thresholds are selected by the app build. Only twenty unknown people were tested; zero observed errors is not a proven sub-1% rate. The app's multi-example mean, Apple quality filters and optional Vision veto were not measured by this single-template photo benchmark.

**Earlier failure remains evidence:** the frozen twenty-person ORL SFace baseline falsely named 7/200 unknown probes, all from one unknown identity, and matched 178/180 known probes with two abstentions. Eleven of 400 images had no detected face. A large-known-face plus tiny-second-person composite returned one detected face and a name. One detected face is not proof only one person is present. Do not hide these failures. Current enrollment is consenting-adult laboratory work; later child-user feasibility concerns tentative hints about enrolled adults, not child enrollment or guardian authentication.

Status, 2026-10-22: source implementation and portable policy/source checks, NOT an Apple SDK build, device-verified system, or shippable identity feature. Default app build does not include native inference or model assets. A passing source check does not establish readiness or authorize a child trial.

## Intended assistive scope and evaluation goal

The intended output is a **tentative familiar-person hint**, not authentication or proof of guardianship. A child may later use the hint alongside asking the person to speak and their own recognition; it is not their only way to identify a parent. Guardian binding or an authentication-grade decision is not a prerequisite for this hint feature. No follow/trust/safety advice is produced.

The user's proposed target of **under 1% unknown-person false naming** is an engineering evaluation goal, not an achieved rate, acceptable-risk certification, or a claim about this prototype's child-use safety. Specify the evaluation denominator, sample independence, held-out protocol, confidence bounds, abstention rate and device conditions before interpreting a percentage. The earlier 7/200 baseline did not meet that goal; the later 0/193 result does not establish a population error rate below it. Apple/device behavior has not been measured.

Current enrollment is limited to consenting adults for laboratory work. Supervised child-user feasibility is a later stage after Mac/device runtime and accessible-usability checks; this distinction concerns the present test sequence, not a permanent authentication requirement.

## Scope and data flow

Settings → Familiar people · supervised experiment (enabled build only). User must acknowledge limitations and explicitly enable each screen visit. Start the existing live camera; stationary portrait rear-camera input is required. Enrollment requires a user-chosen label and an explicit per-attempt adult/self permission attestation (child enrollment disabled). Maximum 20 local people, each with one to six retained examples. New/replacement enrollment requires three to six; explicit individual deletions can leave fewer. Multiple detected faces abstain, but undetected bystanders remain a known limitation; the app cannot choose among a group. Unknown means insufficient gallery similarity, not “stranger” or a trust judgment.

One explicit request captures one current frame. `FamiliarInference` owns OpenCV serially off the main actor. Core Image applies rear-camera portrait `.right`; the Objective-C++ bridge converts CGImage RGBA pixels to BGR, resizes the longest edge to at most 1024, detects with YuNet, aligns the original detected frame using SFace `alignCrop`, extracts the build-selected 128-float SFace or optional 512-float AuraFace feature, and calls upstream `match(FR_COSINE)` against templates. No replacement face detector, landmark alignment, embedding model, training algorithm, or inference runtime is invented here. No generic crop is substituted for landmark alignment. Unlike the Python photo smoke script, this bridge additionally rejects clipped or out-of-frame face boxes before alignment; therefore smoke acceptance rates are not direct app acceptance rates. Both paths share model assets and inference APIs, not proven bit-for-bit preprocessing parity.

Detection score 0.9, NMS 0.3 and top-K 5000 match the isolated photo smoke configuration. Portable legacy reference defaults retain cosine 0.363 and margin 0.1. The actual app now explicitly passes build-profile settings: SFace 0.7/0.2 or AuraFace 0.5/0.2, selected on separate Aberdeen calibration before held-out evaluation, not tuned on held-out outcomes. See AURAFACE_NATIVE_BACKEND.md and `tools/face-evaluation/fresh_benchmark.py` for provenance and denominators; do not transfer a single-template still-photo result to this multi-example/Vision/quality-gated phone path. The cosine threshold is an upstream LFW demo value; margin 0.1 is an arbitrary predeclared experiment value. Neither is calibrated for this app, children, family lookalikes, lighting, occlusions, devices, or open-set operation. A single enrolled template has no runner-up comparison. Enrollment quality and representativeness are not validated.

Output is only “Might be [saved label] … I could be wrong. Ask them to speak and confirm for yourself” or unknown/uncertain. Left/middle/right refers exclusively to the **camera image**. There is no depth, body heading, route, movement, guardian, trust or safe-to-follow inference. No names are injected into scene models, automatic narration, remembered locations or public maps. Results use accessible screen text and a short, explicit past-snapshot spoken hint through the existing speech system, never a FIFO of old names.

The original camera generation, monotonic capture time, newest frame time, normal tracking and portrait orientation are rechecked before storing or displaying. Maximum capture age 1.5 seconds; current-frame age 0.5 seconds. Movement over 10 cm or a 5-degree direction change rejects results. These are engineering freshness gates, not validated person-identity continuity. Published live results expire and are revalidated on processed frames. A short “Snapshot: might be [label]. Could be wrong. Ask them to speak” utterance can finish within a separately bounded 12-second snapshot window, with fresh frames, same session, stationary status and unchanged camera pose. This does not extend the live display/position claim. No direction is spoken in that sentence; movement, hazard, deletion, stop or cancellation interrupts it. Actual VoiceOver timing/interruption behavior remains a device gate. Current monitoring hazard other than observing, loss of the existing three-second stationary gate, stop/session loss/watchdog/cancel/gallery deletion and backgrounding invalidate work. Cancellation discards results; native work already executing may finish before releasing its in-memory pixels. The app does not claim secure zeroization.

## Multi-example enrollment and voice-first route

The real local PhotosPicker can import up to the remaining six-example bound. Selection uses Apple's accessible native picker; app voice commands open it but do not pretend to choose its photos. Only chosen files are loaded, at most 20 MB each, with EXIF-aware ImageIO thumbnailing to 1024 pixels. System Photos may download an existing iCloud original; the app performs no upload. Missing/unavailable/oversized/animated or unusable files are rejected. Each image must produce one usable face; detector count does not prove absence of bystanders.

Guided camera prompts request frontal, slight-left and slight-right views. They do not measure or verify head angle. Accepted aligned RGB previews exist only in the unfinished draft for a sighted helper's review; neither originals nor preview pixels persist. Exact duplicate descriptors are rejected, not a general near-duplicate detector. Every retained descriptor is normalized, their bounded mean is normalized, and upstream cosine compares that one per-person aggregate. This is not unlimited best-of-photo scoring. Optional Vision computes the arithmetic mean of distances to every expected example, with missing/incompatible prints causing abstention.

Real existing VoiceInput completion and manual question routing recognize explicit enrollment, capture, import, review, add, replace, delete, recognize, retry, cancel and stop commands. The bottom Speak/Finish/Cancel/Retry menu and VoiceOver magic tap use that same speech input. “Enroll person Mom,” followed by exact label/adult-consent readback and “confirm face action,” opens a draft. “Finish face enrollment” prompts a second review/confirmation before atomic save. Confirmation is one-shot, expires after 30 seconds, and cancellation/replacement invalidates it. Generic yes/no, quoted/compound or unknown commands never authorize a face action. Parser tests do not prove speech-transcription accuracy. English UI and bilingual parser still need real speech/VoiceOver tests and Arabic localization.

Photo-load callbacks bind to a unique enrollment token, not just a label; cancel/restart with the same label cannot commit an old picker result. Camera callbacks also bind generation and frame/session freshness. Review/add/replace/delete example controls are real; existing saved examples have metadata-only review because photos are not retained. Gallery schema 2 records model hashes, dimensions, per-example source/quality/time and versioned prints. Old or different-backend galleries fail closed and require explicit deletion/re-enrollment. Total encrypted size is checked before writing; the byte limit may be reached before the count limit.

## Optional two-pipeline face-only veto (implemented source; Apple execution pending)

The user's later request adds the image-similarity approach used for personal objects to face comparison. Reused primitives are `VNGenerateImageFeaturePrintRequest`, secure `VNFeaturePrintObservation` archiving and `computeDistance`, not ItemAppearance's foreground-object masks, OCR, clothes, background or whole-scene comparisons. `FamiliarVisionComparison.swift` receives ONLY the exact 112×112 SFace-aligned crop from the native engine. BGR is converted to RGB without another crop or alignment, then Vision receives an upright image with `.scaleFill`. Baseline SFace inference is unchanged; crop export and all Vision work are skipped when the toggle is off.

“Also require Apple image-similarity agreement” is OFF by default and resets on departure/background. Consent explicitly covers the additional encrypted face-only feature print. Enrollment in this mode saves both descriptors from the same capture. The old face-only archive remains readable, but optional comparison cannot use missing prints: every person in the gallery must have a valid secondary reference. Delete and re-enroll adults in this mode; comparisons never create additional enrollment or silently bypass a missing rival.

Feature-print metadata includes schema structure, request revision 2, `sface-align112-rgb-up-scaleFill-v1` crop contract, and exact operating-system version string. Cross-revision, cross-crop, cross-OS, corrupt or missing prints abort the secondary comparison and report no candidate. Secure archives are limited to less than 65,536 bytes each; final encrypted archive must be under 512,000 bytes before an atomic write. Pixels are ephemeral, not archived.

The secondary rule is deliberately only a veto: first the selected face-model threshold/margin must produce a candidate; then the complete Vision gallery must have that same unique winner within experimental maximum distance **0.3** and runner-up separation **0.1**. These two generic-image parameters are arbitrary, declared laboratory settings, not Apple facial calibration or confidence. A one-person gallery has no rival margin. Neither a low distance nor agreement establishes identity. A synthetic counterexample explicitly demonstrates that two agreeing but wrong pipelines retain the wrong candidate. Correlated errors remain possible, and the standard aligned crop can still include hair/edge context; no clothing/background invariance is claimed.

Official API evidence checked directly (2026-10-22; Apple Markdown fallback retrieved when the web renderer could not load JavaScript):

- Image similarity sample: https://developer.apple.com/documentation/vision/analyzing-image-similarity-with-feature-print
- Feature request and crop option: https://developer.apple.com/documentation/vision/vngenerateimagefeatureprintrequest
- Distance API: https://developer.apple.com/documentation/vision/vnfeatureprintobservation/computedistance(_:to:) . Smaller distances indicate more similar prints; Apple does not state this is family identity verification.
- Observation request revision must match: https://developer.apple.com/forums/thread/732876?answerId=757495022 (Apple engineer response).
- Face capture quality: https://developer.apple.com/documentation/vision/vndetectfacecapturequalityrequest and https://developer.apple.com/documentation/vision/vnfaceobservation/facecapturequality-2o4xv . This describes capture properties and helps compare captures of the same face. Its 0–1 value is not identity accuracy, liveness, or an open-set acceptance threshold. Enrollment now uses an explicitly uncalibrated quality cutoff of 0.25 on the exact aligned face, plus an 80-pixel minimum detector box width and height. This may reject every face on a device and requires Apple evaluation; it is not identity confidence. The Swift property is Float?, not NSNumber.

No Vision distance was produced in Linux; no OpenCV surrogate is presented as an Apple result. **No measured fusion improvement exists yet. These arbitrary veto settings may reject every face.** Required Mac/phone comparison must preserve the frozen SFace-only baseline and evaluate the same held-out known/unknown adult captures in both modes, recording false names, abstentions, latency and OS/request versions. Include agreeing-wrong examples, background/lighting/pose changes, missing/corrupt/revision-mismatched prints, mixed galleries, oversized archive failure, cancel/delete/mode changes during inference, and replay attacks. Test exact native crop RGB order/orientation before interpreting any Vision scores. Record thresholds before inspecting held-out outcomes, and report regressions rather than tuning them away. Additional processing may exceed the existing 1.5-second freshness limit, in which case it must abstain rather than relax freshness.

## Privacy and deletion

`FamiliarFaceStore` is separate from conversation and place memory. It stores labels, consent attestations/dates, version/model identity and templates only, never photos. AES-GCM authentication/encryption uses a 256-bit key in non-synchronizable Keychain storage with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. The Application Support subdirectory and archive are backup-excluded; directory and file use complete file protection. Save errors never produce a success message. Missing keys/corrupt archives/model incompatibility fail closed.

Individual deletion rewrites the encrypted gallery. Delete-all removes the archive and key and works even if the archive cannot be decoded. Failures are surfaced. Flash storage cannot be securely overwritten, so deletion is not a forensic-erasure guarantee. Device Keychain, file-protection behavior, backup exclusion, restore and reinstall behavior still require real-device tests. Screen leaving/background disables the experiment; templates are intentionally retained until deleted. Both Settings and Saved Memory link to review/delete controls. No network, export, cloud sync, analytics or photograph persistence path exists in these files.

## Verified upstream provenance

- OpenCV 4.14.0, Apache-2.0 core: https://github.com/opencv/opencv/tree/4.14.0
- API: https://github.com/opencv/opencv/blob/4.14.0/modules/objdetect/include/opencv2/objdetect/face.hpp
- Recognition implementation: https://github.com/opencv/opencv/blob/4.14.0/modules/objdetect/src/face_recognize.cpp
- Reference pipeline: https://github.com/opencv/opencv/blob/4.14.0/samples/dnn/face_detect.cpp
- Official iOS static framework ZIP: https://github.com/opencv/opencv/releases/download/4.14.0/opencv-4.14.0-ios-framework.zip
- Verified ZIP size: 75,208,871 bytes. SHA-256: `f4f428fa9270adf95b3ed4705eb18ba3028ed2c2777a4f1a002739b869986a6a`.
- Actual archive inspected: static `opencv2.framework`; armv7/armv7s/arm64 device and x86_64 simulator. **No arm64 simulator slice.** Do not embed the static framework. Link UIKit, Accelerate, CoreGraphics, QuartzCore and libc++. No Apple binary was executed in Linux.
- YuNet: `face_detection_yunet_2023mar.onnx`, SHA-256 `8f2383e4dd3cfbb4553ea8718107fc0423210dc964f9f4280604804ed2552fa4`, upstream model-directory MIT license.
- SFace: `face_recognition_sface_2021dec.onnx`, SHA-256 `0ba9fbfa01b5270c96627c4ef784da859931e02f04419c829e83484087c34e79`, upstream model-directory Apache-2.0 license.
- Model sources: https://github.com/opencv/opencv_zoo/tree/main/models/face_detection_yunet and https://github.com/opencv/opencv_zoo/tree/main/models/face_recognition_sface . Models and source licenses are distinct from training-data and portrait-image rights. See the isolated evaluation report for its dataset limitations.

The bridge checks exact OpenCV version at compile time. The project generator checks model SHA-256 and framework header version; the runtime rechecks both model hashes. A header-version check does not authenticate an arbitrary binary: verify the official archive hash separately before extracting. No model weights or framework binaries belong in Git. Exact template model ID prevents silent cross-model comparisons.

OpenCV reputation, supplied tests and upstream example code are not proof of this adapter's correctness. Our changes are camera conversion, error handling, single-face bounds checks, state/consent/storage gates and an experimental decision policy. Apple image-to-embedding parity remains unverified. Preserve complete dependency notices before any app redistribution; the checked model notices are included as an enabled-build resource, but a full static-framework transitive-license audit is still a release gate.

## Mac commands, after required artifacts are available

Prerequisites: full Xcode selected with `xcode-select`, the source snapshot, reviewed model-only artifact unpacked to `$FACE_MODELS` (two exact .onnx files at its root), and the official verified ZIP extracted so `$OPENCV_FRAMEWORK` points at `opencv2.framework`. Do not paste an unverified download script or install a different package. Keep these external assets outside source control.

```sh
shasum -a 256 opencv-4.14.0-ios-framework.zip
# Expected: f4f428fa9270adf95b3ed4705eb18ba3028ed2c2777a4f1a002739b869986a6a
export FACE_MODELS="/absolute/path/to/models"
export OPENCV_FRAMEWORK="/absolute/path/to/opencv2.framework"
node tools/generate-xcode-project.mjs --familiar-people \
  --opencv-framework "$OPENCV_FRAMEWORK" --familiar-models "$FACE_MODELS"
xcodebuild -project ios/BlindAssist.xcodeproj -scheme BlindAssist \
  -destination 'generic/platform=iOS' -derivedDataPath artifacts/familiar-device \
  CODE_SIGNING_ALLOWED=NO build
# Optional Intel simulator compile only; the official archive has no ARM simulator slice.
xcodebuild -project ios/BlindAssist.xcodeproj -scheme BlindAssist \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  ARCHS=x86_64 ONLY_ACTIVE_ARCH=NO -derivedDataPath artifacts/familiar-intel-simulator \
  CODE_SIGNING_ALLOWED=NO build
# Restore normal project configuration after experimental bench work:
node tools/generate-xcode-project.mjs
```

A device build without signing does not install/run the app. For adult-device testing, select the experiment target on a supported iPhone in Xcode, set an authorized development team and run; do not weaken security settings or enroll credentials without consent. Intel simulator compilation cannot test ARKit, camera capture, real biometric performance, protected storage or phone thermal latency. On Apple Silicon, use a real device, or build a reviewed OpenCV 4.14.0 XCFramework with the official `platforms/apple/build_xcframework.py` route and separately adapt/review the generator; this generator intentionally targets the inspected legacy framework only.

## Scenario evidence and outstanding acceptance gates

Completed here:

- 37 portable Swift policy cases, plus seven command-parser, five bounded-search-budget and nine one-shot confirmation-state cases: inclusive threshold/margin, one-label gallery, unknown, lookalike tie, invalid/zero/nonfinite/wrong-dimension features, duplicate IDs, gallery bounds, stale/future timestamps.
- Thirteen familiar-feature Node source-contract/generator cases (aggregate counts reported separately). They verify configured gates exist, not runtime iOS behavior.
- Generator verified against actual checked external model hashes and OpenCV 4.14.0 header.
- Swift parser accepted opt-in source. Parsing does not resolve Apple types, compile bridging headers or link native libraries.
- Separate real-photo Linux OpenCV evaluation exists, not an iOS preprocessing/parity test or child-safety evidence.

Required **before anyone relies on this feature**, in order:

1. Compile default and opt-in app configurations in Xcode; run existing package/unit/UI suites, inspect warnings and fix bridge/importer/concurrency/link failures. No source-only result can substitute.
2. Add/run an Apple-hosted adapter parity fixture using the same permissioned public pixels as the Linux reference: verify portrait rotation and mirrored input, RGBA-to-BGR channel order, detector count/box/landmarks, resized dimensions, `alignCrop` output and 128-feature/cosine scores within a documented tolerance. Test rotated/scaled/color-pattern fixtures so accidental flips/channel swaps cannot hide behind one correct face. Do not upload family pictures to obtain parity.
3. Real-device storage: enroll only consenting test adults; lock/unlock mid-read/write; background/foreground; stop/restart camera; corrupt or missing model; stale key; cancel while inference runs; delete one/all while a comparison is pending; kill/relaunch; verify no stale result or deleted person reappears. Confirm backup exclusion and key nonmigration under actual Apple backup/restore tooling. Verify failure UI remains usable with VoiceOver.
4. Seated adult identity tests with consented held-out captures: known vs unknown, adult family lookalikes, glasses/mask/occlusion, side/back face, low light, motion blur, print/photo/video replay, zero/two/crossing faces, clipped faces, absent gallery, changed phone orientation, long inference and overheating. Report false-name rates/abstentions/latencies, not just successful demos. Replay/spoof resistance is not implemented, so never use output to authenticate someone.
5. VoiceOver audit: enable disclosure, name entry, per-attempt consent, capture, unknown/multiface/cancel states, focus after updates, delete and delete-all; no stale result announced after expiration. English-only experiment strings need Arabic localization/review before Arabic trials.
6. After adult bench/device runtime and accessible-usability checks, agree a guardian-involved supervised child-user feasibility protocol for tentative hints about consenting enrolled adults. Initial interaction is seated, with a sighted adult checking results and the child asking the person to speak and deciding for themselves. No authentication or guardian-binding feature is required for the hint. Any later child mobility trial still requires qualified O&M review; no unsupported mobility, stairs, separation or independent child use. A working build alone does not close these gates.

No claim of production readiness, verified identity, safe-to-follow advice, liveness/PAD, children-specific accuracy, or safe unsupervised use is supported by current evidence.

### Additional Apple acceptance scenarios for the new route

- Native PhotosPicker multi-select, cancel, denied/unavailable item, iCloud-offline item, EXIF rotation, HEIC/JPEG, oversized/animated input, two people, and one large plus missed small bystander. Cancel while transfer loads; restart the same label and verify the old transfer cannot append.
- Frontal/left/right prompts, small/blurred/low-light capture rejection, duplicate example, fewer than three, six-example limit, add/replace rollback, review/delete one/last/all, backend switch and encrypted size overflow. Confirm no original or aligned photo persisted.
- Spoken label misrecognition (Mom versus another label), interrupted consent, expired/wrong/repeated confirmation, generic yes/no, ambiguous/compound speech, speech permission denial, cancel/stop while native work or Photos transfer runs, and VoiceOver magic tap with focus changes. Native picker selection remains an accessible UI fallback.
- Verify low-priority progress can be replaced by the final hint without interrupting mobility/danger; short snapshot sentence must be intelligible, and any context invalidation must cancel it. Do not infer that parsing or a source-contract check tested this interaction.

Recognition is explicitly one-shot, not continuous identity/face-switch tracking. A fresh request clears the old hint before capture. No/unusable/multiple faces cannot retain a prior name or infer that a parent turned away. Retake guidance says: “I can’t get a clear face view. You can call out to the person you’re looking for and ask them to look toward you. Then try again.” Repeated spoken retake guidance has an eight-second cooldown; accessible text remains. For a rear-facing chest strap this wording avoids requiring the child to locate a camera, but looking toward the child does not guarantee a face is in the chest-height field of view. Chest-mount ergonomics, pitch, motion and intelligibility remain real-device usability tests.

### Bounded named-person search

“Find person Mom” (or the corresponding exact-label UI action) uses only an enrolled label. “Parent” is not resolved to Mom or Dad unless literally saved under that label. One brief initial message says “Can’t identify Mom yet. Try calling Mom.” The controller then quietly waits for fresh, calibrated, stationary portrait frames: at most six actual comparisons spaced at least two seconds, ten bounded polls, and a separate 20-second cancellation deadline. Missing faces, unusable pose, other identities and ambiguity remain quiet. A fresh target match produces one tentative snapshot hint and ends the search. It never reports that a missing match proves absence.

A new request, cancel/stop, deletion, changed gallery/mode/session, backgrounding, urgent hazard or deadline invalidates pending results. Native inference already executing may finish internally after cancellation, but cannot publish. The existing three-second stationary gate is retained: this is not moving-child or continuous identity tracking. A name-switch between checks is not continuously detected. Actual chest-mounted, voice-first timing and usability still require Xcode and iPhone testing.


## Single speech admission route

All app speech, including UI actions and VoiceOver cancellation acknowledgements, enters `NavigationModel` and the existing `CompanionAttention` policy. The private raw `Feedback` sink requires an admitted capability; ordinary callers cannot construct it. Hazard and necessary mobility priorities retain immediate precedence. Requested descriptions, repeats and identity hints retain normal word budgets. Essential current-operation consent, confirmation, error and bounded progress use an explicit policy classification capped at 80 words and a 30-second validity window, without ordinary narration-budget charge; they cannot interrupt higher-priority speech and are not queued for later replay. Already-admitted room offers and scene-change candidates are delivered without a second admission charge.

Named-person search marks an explicit focused task even while stationary, suppressing unrelated room/clothing narration without falsifying movement state. It clears pending room offers and old question work. Its initial “Looking” status is UI-only; the first unusable, unavailable or nonmatching attempt can produce one brief “Can’t identify [label] yet. Try calling [label].” Later retries are quiet. A first-attempt match emits only the tentative snapshot hint. Actual hazards invalidate face work and stale offers even when no new AR frame arrives. New explicit goals/questions, stop, deletion and cancellation do not resume old answer text. Speech/VoiceOver priority, interruption and cancellation behavior still require Apple device verification; source contracts are not audio-runtime tests.
