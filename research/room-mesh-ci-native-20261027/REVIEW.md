# Proposed controlled native-backend variant — pending root review

## Preserve both failures

1. Commit 8d878c86ab0b3a96d5fd44b31b418fbdc9bc5ed6; run 40463262362,
   job 122052575033. Artifact 12714564487; ZIP SHA256
   11cabd77b6eaed09aa75e24c8d12076a9f5af794351b116ad23593e5f5ee7035.
2. Diagnostic commit 45e879734acfdf6b6e5d23790dc613fc8b4f93e9;
   run 40465081544, job 122058420701. Artifact 12715583800; ZIP SHA256
   27735da889d682d918e045ad4d653be5968e6ccb83cac6f326a66dd7c05fe3c9.

Both returned SIGXFSZ during SwiftBuild planning. Parent reports the second
receipt's scoped metadata scan was complete; largest file was the ~3.09 MB
input, then ~341 KB manifest; other files under 128 KB. Neither failure
identifies the file whose expansion triggered the signal. Existing evidence
and prior variant are untouched. No default-backend pass is claimed.

## Primary-source explanation: plausible, not identified cause

LLVM's CAS MappedFileRegionArena implementation first resizes a backing file
sparsely to its maximum mapping capacity, typically several GB, and maps it.
The implementation explicitly distinguishes logical file size from allocated
storage, and may shrink the mapping on close. A failed resize can leave a
small file; large allocation is not a prerequisite for exceeding RLIMIT_FSIZE.
Thus the small stage-end inventory does not exclude a sparse-file expansion
failure. It also does not prove CAS was responsible or where the file lived.
Source (comments lines 11–37 and resize code lines 225–236):
https://github.com/llvm/llvm-project/blob/main/llvm/lib/CAS/MappedFileRegionArena.cpp

The pinned Apple binary's exact CAS implementation has not been matched to
that upstream revision. Do not claim an identified CAS database, memory
failure, geometry defect, or an actual 128 MiB disk allocation from this.

## Recommended next experiment

Use explicitly supported `swift build --build-system native`, retaining ALL
other compiler flags, SDKs/triples, sandboxing, source/fixture pins and checks.
The official SwiftPM 6.4 release notes recommend this compatibility fallback
when the default SwiftBuild backend fails:
https://github.com/swiftlang/swift-package-manager/blob/swift-6.4.0-RELEASE/Sources/PackageManagerDocs/Documentation.docc/ReleaseNotes/6.4.md
The release's option implementation supports native for single-architecture
builds, which both existing target commands are:
https://github.com/swiftlang/swift-package-manager/blob/swift-6.4.0-RELEASE/Sources/CoreCommands/Options.swift

Native is a legacy/deprecated backend, not a permanent default-backend fix.
No claim that it eliminates every CAS use. This changes one build-engine
variable rather than guessing a larger cap. Both build and --show-bin-path
query use the same explicit backend. Summary adds swiftPMBuildSystem=native
and defaultSwiftBuildBackendPassed=false; receipts retain exact commands.

Unchanged budgets: 128 MiB per file, 512 MiB scoped logical scratch measured
at stage end, 300 CPU seconds, original wall times, jobs=1, workflow timeouts.
No new live disk-quota guarantee. No sandbox disable or cap change.

If this still fails SIGXFSZ, do not repeat identical variants. The next decision
would require stronger file-operation evidence or a prospectively reviewed
budget/watchdog design accounting for logical sparse sizes AND allocated disk
blocks (with scoped polling and process-group termination, explicitly not a
hard disk quota). No larger-cap variant is prepared or authorized here.

## Validation / proposed publication replacements

Ten tiny Python tests PASS; no local compiler build, SDK or module cache.
Pins differ from the prior branch diagnostic only at apple/ci.py; manifest
changes only helper and pin-file hashes. Native backend actual Apple execution
remains pending. No sources, pose gates, native workflow or fixture changed.

Only these three replacements are prepared for root to review and publish:
- research/room-mesh-package-75/apple/ci.py <- ci.py
- research/room-mesh-package-75/APPLE_SOURCE_PINS.json <- APPLE_SOURCE_PINS.json
- research/room-mesh-package-75/MANIFEST.json <- MANIFEST.json

ci.patch, test_ci.py and this note are local evidence, not selected publication
payload. Root alone publishes; no external write performed by this worker.
