# CI-only diagnostic correction (not an Apple pass)

Original immutable failure: repository mischa23v/blind, branch
codex/recovery-hazard-order-20261027, commit
8d878c86ab0b3a96d5fd44b31b418fbdc9bc5ed6, run 40463262362,
job 122052575033. Artifact 12714564487 ZIP SHA256
11cabd77b6eaed09aa75e24c8d12076a9f5af794351b116ad23593e5f5ee7035.
Parent supplied receipt: host-package exitCode -25, timedOut false,
wallSeconds 11.9046, scratchBytesAfterCommand 3582714.
Read-only job-log retrieval independently confirms host-package failed after
planning deferred tasks, before client/fixture stages. No original log, artifact,
or receipt is overwritten. No claim that a particular compiler/cache file was
identified: original artifact contains no largest-file inventory.

Apple XNU defines signal 25 as SIGXFSZ, exceeded file-size limit:
https://github.com/apple-oss-distributions/xnu/blob/main/bsd/sys/signal.h
The unchanged helper set RLIMIT_FSIZE to 128 MiB for every child. A low scoped
scratch count does not disprove SIGXFSZ: previous global caches and temporary
files were outside its accounting; a failed expansion need not leave a file at
the cap. This is infrastructure evidence, not an algorithm failure or proof of
which file caused it.

## Change and limits

- Keep 128 MiB per-file, 512 MiB aggregate stage-end scratch, 300-second CPU,
  existing wall-time limits, jobs=1, workflow timeout and sandbox unchanged.
- Scope SwiftPM shared cache and local manifest cache under out; explicitly
  route Swift/Clang module caches and TMPDIR under out. Do not change HOME,
  SDK, build backend, optimization flags, source/fixtures, checks or gates.
- Verify the required SwiftPM options appear in the Apple toolchain's help;
  upstream option definitions verified at:
  https://github.com/swiftlang/swift-package-manager/blob/main/Sources/CoreCommands/Options.swift
  https://github.com/swiftlang/swift/blob/main/include/swift/Option/Options.td
  https://clang.llvm.org/docs/ClangCommandLineReference.html#cmdoption-clang-fmodules-cache-path
- Add signal name/file-size-signal classification, recorded budgets, bounded
  log tail (8192 bytes, 35 lines), and top 8 relative filenames/sizes to existing
  receipt upload. Scan at most 20000 entries without following symlinks;
  fail closed on an incomplete scan. No whole-home inventory or file contents.
- Explicitly label scratch accounting stage-end only, NOT a live disk quota.
  Scoping requested caches does NOT establish all toolchain internal files
  honor those paths; a rerun might still fail and that must remain a failure.
- No cap increase. Any proposed later increase requires explicit budget review.

## Validation and publication

Nine tiny Python tests PASS: success/temp scope/budgets, nonzero exit,
real SIGXFSZ using a test-only 1 KiB limit, timeout, symlink avoidance,
scratch threshold/bounded log tail, cache arguments, scan-error fail-closed,
and top-eight ordering. Production constants are
unchanged. No Swift build, SDK download or module cache created locally.
Apple support/actual file culprit remain unverified until diagnostic rerun.

Prepared publication replacements ONLY:
- research/room-mesh-package-75/apple/ci.py <- ci.py
- research/room-mesh-package-75/APPLE_SOURCE_PINS.json <- APPLE_SOURCE_PINS.json
- research/room-mesh-package-75/MANIFEST.json <- MANIFEST.json

Pins are based on branch override, retaining all other pins, including the
branch-only workflow pin and the deliberate omission of two .build pins.
MANIFEST changes only helper/pin-file hashes. Original source directory is
untouched. test_ci.py, ci.patch and this note are local review evidence unless
root explicitly selects them for publication. Root alone publishes.
