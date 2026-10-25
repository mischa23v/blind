# Native Apple SDK CI

Prepared 2026-10-25. This describes a workflow, not a successful native run. The actual Actions run and commit must be recorded before claiming Apple compilation or test success.

## Scope and cost guard

`.github/workflows/native-apple.yml` runs on relevant pushes to `master` or manual dispatch, only for the public `mischa23v/blind` repository. The job-level visibility/repository condition runs before runner allocation; a private repository or fork skips this job. Standard public macOS runners are free under GitHub's documented terms. No larger runner, billing setting, cache, artifact upload, signing account, deployment, secret, external model API or model/framework download is used. The existing exact GRDB 7.11.1 Swift package dependency is fetched normally.

The selected standard label is `xcode-27`, not a paid larger runner. Official image documentation inspected on 2026-10-25 lists macOS 27.0.1, image `20261012.0260.1`, default Xcode 27.0 build `27A266a`, iOS simulator SDK/runtime 27.0, and iPhone 18 Pro Max. The workflow selects `/Applications/Xcode_27.0.app/Contents/Developer`, verifies SDK 27.0 and the installed named simulator, and prints the actual toolchain and source revision. It fails rather than downloading a missing runtime or switching silently. The image label is a public preview and is not an immutable VM snapshot; GitHub's beta-image limitations apply.

Official sources:

- Runner terms, specifications and labels: https://docs.github.com/en/actions/reference/runners/github-hosted-runners#standard-github-hosted-runners-for-public-repositories
- Installed image/toolchain/SDK/runtime: https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md
- Official checkout v7.0.1 source pin: https://github.com/actions/checkout/commit/3d3c42e5aac5ba805825da76410c181273ba90b1
- Checkout credential persistence behavior: https://github.com/actions/checkout/tree/3d3c42e5aac5ba805825da76410c181273ba90b1

## Executed sequence when published

1. Check source/toolchain metadata, committed default project configuration and installed simulator.
2. Run `swift test` for BlindCore with two compiler jobs on macOS.
3. Run `swift test` for BlindMemory with two compiler jobs on macOS.
4. Build the committed default Debug iOS Simulator app unsigned with the actual Apple SDK.
5. Run the existing BlindAssistTests hosted iOS unit suite serially on the simulator.
6. Run the existing BlindAssistUITests UI/accessibility suite serially on the simulator.
7. Print bounded test-result counts/status from xcresult where available and ensure tracked iOS/package source has not changed.

The package suites and simulator build run independently after successful preflight, so an earlier package failure does not hide compiler errors. Hosted and UI tests require a successful app build, but a hosted-test failure does not suppress the UI suite. No failures are marked `continue-on-error`, no test is filtered out of either selected target, and no retry masks flaky results. Maximum job time is 65 minutes; each phase also has a shorter limit. One run per branch is active at a time; an active run is not cancelled by newer reconstruction pushes. GitHub may replace an older pending run with the latest pending commit. Every result remains tied to its exact source revision.

The helper does not invoke `tools/verify.mjs`, `tools/mac-setup.mjs` or the project generator, since those paths can regenerate the project. It reads the checked-in shared scheme and preserves default compile flags. Optional face/currency/OpenCV, multimodal and Live Activity variants are not covered. They require separately verified dependencies/configurations and disposable workspaces, not overwriting this project or enabling physical guidance.

The existing UI launch arguments disable camera awareness and background conversation. Tests use fresh runner/simulator state and committed synthetic fixtures, never family data or user photos. Compiler/test diagnostic excerpts are bounded. Full xcresult recordings, screenshots, environment variables and signing credentials are not published as artifacts. Only count/status/time fields from result summaries are printed; native result bundles live in disposable runner storage.

## Evidence limits

A green run would establish compilation/linking against the selected real Apple SDK, portable package execution on macOS, and whichever existing hosted/UI assertions actually execute successfully. Automated accessibility audits are not real VoiceOver listening/navigation acceptance.

It cannot establish physical LiDAR/RoomPlan tracking, BLE/wearables, camera/body mounting, real banknote/face/general-detector accuracy, calibrated object geometry, hazard timing, haptics, on-device Foundation Models quality/availability, real conversational latency, battery/thermal endurance, complete household journeys, or safety for blind children. A simulator does not replace supervised physical-device acceptance. Disabled/unavailable optional backends remain unavailable, not passed.

## Preparation validation

Linux preparation passed shell syntax parsing, YAML parsing/event/permissions/runner assertions, seven mocked helper dispatch modes, unsigned/test-target command assertions and propagation of a synthetic compiler failure (exit 42). Those are orchestration checks only. No Apple SDK command was executed during preparation. No GitHub write, Actions dispatch, access denial, signing, account or billing change was attempted by the preparer; publication and actual native results remain pending.

Source reviewed from the current rebuilt tree, identified by parent as executable checkpoint `0601e9fe` with source-backup checkpoint `c28f0c77`. The workflow records full `git rev-parse HEAD` at runtime rather than treating these abbreviated historical identifiers as native evidence.

SHA-256 of reviewed source files:

- ios/BlindAssist.xcodeproj/project.pbxproj: `bf3ea09dfa44e4c5e4d10a48d20a497239b780f0a2882501f86b2c26e97f3063`
- ios/BlindAssist.xcodeproj/xcshareddata/xcschemes/BlindAssist.xcscheme: `6b65f27032bc4f2f112e2e71da5483b949e443501b9a0cf2f92ffbc0ca0f65cb`
- BlindCore/Package.swift: `9db07d1d72ac8d224f873aaf47e51f63bf7e508355a1355426daf599d8f64b0f`
- BlindMemory/Package.swift: `119060ea110b7cd06a2c6b4f68c125b51489bc2d9a4385e1b1af53df30ef3115`
- BlindMemory/Package.resolved: `159a0bf93b792f403c70f7ec2cfea61686aff384e55c8c132946fb8980e26889`
