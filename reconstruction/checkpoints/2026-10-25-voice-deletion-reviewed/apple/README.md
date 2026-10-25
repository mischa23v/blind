# Isolated Apple compile and actor probe — not application activation

This narrowly path-triggered/manual workflow checks the two historical staged sources without connecting them to the Blind Assist application, capture pipeline, model, private history or authority. The host app is blank; enrollment source is compiled solely into the isolated XCTest bundle.

## Gates and failures

1. `typecheck.sh` compiles the untouched two-file checkpoint against the actual iOS device SDK in Swift language mode 5, target iOS 17. It must pass first. Darwin/protection/concurrency errors fail the workflow; a Linux build or an excluded `os(iOS)` branch is not a substitute.
2. `generate-project.mjs` checks both reviewed SHA-256 pins and creates a fresh disposable PBX project, following the repository's existing dependency-free generator style. No packages/tools/models are downloaded. No main project is changed.
3. A test-only projection adds `VOICE_ENROLLMENT_TESTING`-guarded initializer and one-shot pre-erase failure hook. The initializer is restricted to the current simulator application's temporary directory. Removing the two guarded blocks restores the exact historical actor source, checked by portable tests. The original initializer/production default path and security behavior are unchanged; the source backup is never rewritten.
4. `actor-tests.sh` uses an already-installed iOS 27.0 / iPhone 18 Pro Max runtime, creates its own disposable simulator and runs only two XCTest methods, serialized with two compiler jobs. It never resets another simulator. Exactly two passes and zero failures/skips must appear in the xcresult summary; an absent/incompatible summary fails rather than inventing success.

The workflow retains the existing repository-name/public-only guard and Xcode 27 runner/settings, has a separate concurrency group with `cancel-in-progress: false`, and triggers only on master pushes changing this workflow or its voice-deletion checkpoint (plus manual dispatch). Scripts stay within this checkpoint rather than `tools/ci/**`, avoiding the main native CI push filter. The workflow's job deadline is 25 minutes; actor step deadline is 18 minutes. Actor execution repeats the untouched-source typecheck so direct script invocation cannot bypass gate 1.

## Synthetic actor coverage

- Save, validated matching load, fresh actor recreation/load, and unchanged `mayIdentifyWearer == false`.
- Successful deletion removes selected record, hidden atomic orphan and nested orphan data; repeated deletion and recreation remain empty.
- Injected failure occurs only after durable marker verification and before erase. Existing bytes survive but current/fresh actor reads are withheld, stale saves reject, and a new helper setup cannot bypass pending deletion.
- Successful retry clears all data; the deleted-generation ticket stays invalid; explicit new setup can save and is deleted again.

All bytes and consent receipts are fabricated test fixtures. Nothing captures real audio or identifies a real person. Re-instantiation exercises lost actor/RAM state, not an actual process kill. Actor operations have one active owner at a time; ownership enforcement across clients/processes is still not implemented.

## Evidence boundaries

Prepared and locally validated: shell syntax, projection generation, all Swift source syntax with iOS branch/test flag selected, and four portable generator/guard tests. Apple SDK typecheck, project build and actual actor execution are **not locally executed** and remain pending the Apple workflow. A simulator failure to enforce or report file-protection/backup flags is a failure; there is no bypass or skip. Simulator success still does not establish physical-device protection, lock/unlock, backup behavior, sudden-power-loss durability, full-disk handling, UI failure/retry semantics, forensic erase, speaker accuracy or production readiness.

No artifacts or record data are uploaded. Only source hashes, bounded compiler/test diagnostics and counts are printed. Temporary project/derived data/test result bundle and this probe's simulator are removed on normal exit. A forced job termination may prevent cleanup; GitHub runner disposal is then the boundary, not a promise that the trap ran.

Portable validation command (with existing Node, from repository root):

```sh
node --test reconstruction/checkpoints/2026-10-25-voice-deletion-reviewed/apple/test-probe.mjs
```

The four portable tests are not the two pending native actor tests. Preserve these distinctions in reporting.
