# Smallest next Apple check — research only, not executed

## First gate: standalone two-file Apple SDK typecheck

No app integration is needed for the next useful check. On a Mac with the selected Xcode/iOS SDK, typecheck only `source/VoiceEnrollment.swift` and `source/ProtectedVoiceEnrollmentStore.swift` as one temporary module. The repository iOS project inspected for planning uses iOS 17 and Swift language mode 5; verify those settings against the chosen current checkout before running. A command outline is:

```sh
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
xcrun --sdk iphoneos swiftc -typecheck -parse-as-library -swift-version 5   -target arm64-apple-ios17.0 -sdk "$SDK"   -module-name VoiceEnrollmentCompileProbe   source/VoiceEnrollment.swift source/ProtectedVoiceEnrollmentStore.swift
```

Keep compiler caches in the authorized scratch directory. Capture Xcode/compiler/SDK versions, exact source hashes, full diagnostics and exit status. This activates the `os(iOS)` branch and can detect Darwin/protection API and actor-isolation/exclusivity errors that Linux syntax parsing cannot. It does not run storage operations, request permissions, capture audio, write enrollment, or require signing. A separate strict-concurrency diagnostic pass may follow; neither pass is device acceptance. Any repairs require updated focused tests and review, not silent changes to this historical backup.

## Only after a passing Apple typecheck

The smallest host integration is a test-only target/module containing these two sources, with no production call sites. Before executing the actual actor, add reviewed injectable temporary-directory/file-operation seams so tests cannot touch a real app's enrollment folder. Use only synthetic bytes; cover process/store recreation after failed erase, hidden/nested orphan cleanup, disk/permission failure, marker verification failure and late saves. Test single-owner lifecycle and memory invalidation explicitly. Current actor init selects Application Support automatically and must not be casually run against a populated user app container.

Real-device protection/backup/lock behavior and UI deletion-failure handling remain separate acceptance. No embedding extractor, microphone capture, helper enrollment UI or matcher should be connected as part of this compile probe. `VoiceAuthority` and private-history capability issuers are outside this change and must remain unchanged. No archive/build/test command above has been executed on Apple hardware here.
