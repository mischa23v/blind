# CI-only host/target SDK separation — pending root review

## Verified partial result, not full pipeline green

Original native-backend commit a8a810509f89745408c806bb92deca887991cbd6,
run 40467984623/job 122067927907. Artifact 12717691528 downloaded read-only;
ZIP digest verified as
b3f26d4c0da26ab64db28b05a567032a407a9a4de4d583ccae0d508f1300f776.
Nine JSON members inspected without extraction. All five host stage receipts
exit 0 with no timeout/scratch-cap exceedance. RESULT passed=true, 55 checks,
all true, 636 marked spans; RUNTIME_RESULT passed=true, 32 checks, all true.
The public client executed successfully. Simulator package exits 1 while
compiling the manifest: macOS target with iPhoneSimulator27.0 SDK supplied
twice; unable to load its standard library. No simulator client link or full
summary exists. PARTIAL_HOST_EVIDENCE.json records only this verified subset.
Both prior SIGXFSZ attempts remain failed; default SwiftBuild still unproven.

## Diagnosis supported by primary source

SwiftPM 6.4 constructs the package-description toolchain from hostSwiftSDK,
separately from the target toolchain's explicit custom SDK/triple:
https://github.com/swiftlang/swift-package-manager/blob/swift-6.4.0-RELEASE/Sources/CoreCommands/SwiftCommandState.swift
(lines 1038–1100). On macOS, hostSwiftSDK uses SDKROOT from the environment
before its macOS SDK lookup:
https://github.com/swiftlang/swift-package-manager/blob/swift-6.4.0-RELEASE/Sources/PackageModel/SwiftSDKs/SwiftSDK.swift
(lines 500–549). ManifestLoader adds the host toolchain SDK to its arguments:
https://github.com/swiftlang/swift-package-manager/blob/swift-6.4.0-RELEASE/Sources/PackageLoading/ManifestLoader.swift
(lines 872–890).

Observed simulator launcher `xcrun --sdk iphonesimulator swift build` is thus
consistent with the wrong host SDK selection; environment capture was not in
the original artifact, so the exact injected environment value was not directly
recorded. The contradictory manifest target/SDK arguments are directly proven.

## Minimal correction

Always launch SwiftPM through `xcrun --sdk macosx swift build`; explicitly set
its SDKROOT to the discovered macOS SDK. Keep --triple and --sdk target options
unchanged for both host and simulator products. Use the same scoped host
environment for build, help and --show-bin-path. The direct swiftc client
commands retain their target-specific SDK and triple. No global environment
mutation, native-backend change, algorithm/fixture/gate change or cap increase.
All existing budgets and sandbox behavior retained. A rerun must still prove
the simulator package/client link; this correction is not an Apple full pass.

Twelve tiny tests pass including both target commands' macOS launcher with
unchanged target SDK/triple, inherited simulator SDKROOT overridden only in a
copied child environment, and prior resource-limit/diagnostic tests. No local
Swift compilation, SDK download or module cache. Branch pins change only
apple/ci.py; manifest changes only helper and pin-file hashes.

Proposed publication replacements only:
- research/room-mesh-package-75/apple/ci.py <- ci.py
- research/room-mesh-package-75/APPLE_SOURCE_PINS.json <- APPLE_SOURCE_PINS.json
- research/room-mesh-package-75/MANIFEST.json <- MANIFEST.json

Root alone publishes. Other files are local review evidence. Original source,
prior variants and all failure artifacts remain untouched.
