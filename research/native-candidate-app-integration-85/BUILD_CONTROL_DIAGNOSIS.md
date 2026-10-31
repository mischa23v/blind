# Actual unpatched/proposal control — 2026-10-27 20:18 UTC

Run `40576517541` at `c110c89c7d2ce17f71d5300a2a61a380a1acaec8` failed. Verified artifact `12765979356`, 19,132 bytes, SHA-256 `3fdab576f79f25c385bd08ff015443929a065f142199c587bb63f14eba93a72e`; exact receipts are in `evidence/run40576517541/`.

| Arm | Exit | Seconds | Result |
|---|---:|---:|---|
| Unpatched app | 65 | 2.855394 | Build service crash at CreateBuildDescription |
| Proposed app, diagnostics flag absent | 65 | 2.817584 | Same generic service crash |

The proposal is **not necessary to reproduce this failure under this harness**. This does not prove the proposal compiles, nor identify the service-crash mechanism. No source compiler diagnostic appears in either retained tail. Both arms used the same command apart from fresh derived-data paths. Fixed order/shared caches remain confounds. The source-byte/mode restoration passed for all three files, totaling 521,724 captured bytes. No automatic retry ran.

The complete 4,531-byte baseline log was inspected by the gate; it contained no recognized resource-stop marker. Neither arm produced a collected build-service crash report. Parent receipts show no timeout, direct signal or scratch cap overrun. **Child resource failure is still unknown**, not disproved. CPU300s, file128MiB, scratch2GiB, wall600s remained unchanged.

## Comparison with the existing native Apple app-build path

`tools/ci/native-apple.sh` uses this base invocation (substituting absolute project/output paths does not alter the intended project):

```
xcodebuild -project ios/BlindAssist.xcodeproj -scheme BlindAssist \
  -configuration Debug -jobs 2 -derivedDataPath "$out/DerivedData" \
  CODE_SIGNING_ALLOWED=NO -destination 'generic/platform=iOS Simulator' build
```

Stage85 differs in these explicit ways:

- Its package environment injects **SDKROOT pointing to macOS** into subsequent app commands. The command itself selects `-sdk iphonesimulator`; this conflict is a hypothesis, not an established cause.
- Explicit `CODE_SIGNING_REQUIRED=NO`, `ARCHS=arm64`, `ONLY_ACTIVE_ARCH=YES`, `ENABLE_DEBUG_DYLIB=NO`, `SWIFT_OPTIMIZATION_LEVEL=-Onone`, `SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG` are additional overrides absent from the existing path.
- One job instead of two; explicit exact resolved package checkout and disabled automatic resolution (these latter restrictions must remain for bounded reproducibility).
- Stage85 adds per-process CPU/file limits and measured scratch checks. The existing shell wrapper has no matching `ulimit` statements. Existing successful native builds therefore do not establish that those limits are compatible.
- Stage85 builds separate SwiftPM host/simulator graphs before the app. Those graphs pass; that does not establish the app environment or build-service backend works.

Recommended next diagnostic, **not executed or selected by this document**: use the existing minimal native-app invocation semantics, retain one-job/resource budgets and exact dependency controls, with the app environment copied from the process without injecting the host-package SDKROOT. Keep package environment separate. Compare the same two sources with fresh derived directories and existing failure/restoration guards. This is a bundled harness-normalization experiment; if it passes it distinguishes the harness configurations, not which individual override caused the crash. If it still fails, preserve the failure rather than increasing caps or repeatedly retrying. Do not replace current source/PBX based on these crash logs.
