# Build the face-enabled app on a Mac

## What is established

The separate SFace configuration compiled successfully for unsigned generic iOS device on Xcode 27, arm64, at checkpoint19 commit `4e51133ab2d23d07eb11af70979f28edec04c145`: [run 40180050774](https://github.com/mischa23v/blind/actions/runs/40180050774), job 121128991680. Exact logs include compilation of FamiliarEnrollmentConsent.swift and the familiar Swift/native files; commit-pinned sources contain the guardian token and shown-button binding. This was compilation, not camera execution, signing, installation, recognition accuracy, or a child trial. Separate default-app runtime/UI test failures remain unresolved acceptance failures; optional compilation does not override them. The new notice-packaging/build-membership changes in this handoff require their own native build. The default project remains unchanged; this path generates a separate project using the existing generator.

The three assets are the official OpenCV 4.14.0 iOS framework, YuNet 2023mar and SFace 2021dec. The existing script verifies exact byte counts and SHA-256, including cached files, before generating anything. Downloads total 114,137,813 bytes, before extraction and Xcode DerivedData. Use a private local directory outside the repository with room for extraction and build output; do not commit it. No user photographs are required or uploaded by setup. There is no arm64 simulator framework slice: use an actual device target, not simulator as a substitute.

## Mac preparation and unsigned build

Use a reviewed checkout containing the current guardian-consent source and the full OpenCV notice bundle. Install full Xcode 27 with its iOS SDK and Node 22 or newer from their official sources. Launch Xcode to finish its required setup. Select that Xcode in Settings > Locations > Command Line Tools, or set DEVELOPER_DIR to the actual selected Xcode application. Do not blindly reuse another machine's application path.

From the checkout root:

```sh
node --version
xcodebuild -version
xcrun --sdk iphoneos --show-sdk-version
export FAMILIAR_CI_ASSETS="$HOME/Library/Caches/BlindAssist-Familiar-Pinned"
bash tools/ci/familiar-device.sh
```

Despite its CI name, this is the same bounded Mac script used by the successful native job. It downloads only the three pinned official assets, generates `ios/BlindAssistFamiliarBench.xcodeproj`, verifies build membership and current guardian source contract, builds unsigned for generic iOS device with two jobs, then checks that the app contains exact model and notice resources. It preserves `ios/BlindAssist.xcodeproj/project.pbxproj` byte-for-byte. Failure is not permission to skip a hash, notice, consent-source or compiler check. `npm run mac:setup` is a different default-project path and does not enable this backend.

The generator explicitly includes BLIND_FAMILIAR_PEOPLE in Swift and native compilation, BAFaceEngine.mm and bridging header, the local BlindCore consent type, both pinned models and model/OpenCV notices. No AuraFace, Saudi reference, generic object model, or multimodal flag is silently enabled. Source/flag checks are not proof of UI or runtime behavior.

## Guardian's on-device handoff

After the unsigned build succeeds, open `ios/BlindAssistFamiliarBench.xcodeproj` in Xcode. Choose the BlindAssist scheme and the physically connected iPhone, not an iOS simulator. The owner selects their own signing team and provisioning settings in Xcode and completes any account, device-trust or Developer Mode prompts themselves. No signing credentials, phone identifier, team identifier or paid account is supplied or created by this recipe. Build and Run from Xcode to make a signed local development app. The unsigned CI app itself cannot be installed as a signed app. Do not regenerate while preserving manual Xcode signing edits without recording them privately; regeneration rebuilds the separate project.

Before use, verify camera/microphone permission behavior, foreground/background interruption, mute/end/camera-off behavior, private audio, VoiceOver and the actual consent prompts on the phone. These remain device acceptance gates, not tasks already passed by compilation. Use consenting adult supervised checks first; do not use a tentative hint as evidence that a person is a guardian, is safe, or should be followed.

The child-facing flow does not need a scanner-mode or recognition-start button. In the enabled build, the familiar preference defaults on when absent, and existing consented saved people are checked during permitted foreground camera operation. An explicitly stopped preference stays stopped. The guardian adds examples through People > Add person. Adult enrollment requires that adult's consent; the separate child path requires the parent/legal guardian's exact helper-screen attestation. It is not identity verification of the guardian. Obtain three to six suitable examples, review the intended same person, name and save with the separate final confirmation. Voice confirmation alone cannot authorize child consent. Cancellation, changes, expiry and old helper buttons must not authorize a new action.

A gallery containing the new guardian-child consent category is intentionally not readable by older adult-only app versions. Do not downgrade expecting those templates to migrate automatically; older versions fail closed, and no recipe silently deletes the gallery. Keep this compatibility limit in the guardian handoff.

After enrollment, leave the helper workflow and return to ordinary foreground camera use. The optional manual comparison control is a helper diagnostic, not a required trigger for automatic encounters. Unknown or low-confidence faces must remain unnamed. Multiple faces, movement, lighting, missed detections, lookalikes and photo-derived templates can still cause errors or abstention. There is no validated child recognition rate. Do not change calibrated thresholds to make a demonstration name someone.

## Distribution boundary

Keep framework, models, app, DerivedData and personal gallery outside the public source repository. The generated app must retain MODEL_NOTICES.txt and OPENCV_NOTICES.txt. Read the notice audit coverage manifest and resolve any explicit open item before redistributing an app; a successful compiler job is not legal or release clearance. This setup neither uploads a binary nor changes App Store/TestFlight, signing-account, privacy or security configuration. Gallery templates remain local; do not upload personal examples or biometric templates to debug a build.
