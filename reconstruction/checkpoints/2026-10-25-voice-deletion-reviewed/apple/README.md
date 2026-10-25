# Isolated Apple compile and actor probe — not application activation

This narrowly path-triggered/manual workflow checks the staged sources (original Foundation contract plus native-v2 actor) without connecting them to the Blind Assist application, capture pipeline, model, private history or authority. The host app is blank; enrollment source is compiled solely into the isolated XCTest bundle.

## Gates and failures

1. `typecheck.sh` compiles the uninstrumented native-v2 actor plus original Foundation contract against the actual iOS device SDK in Swift language mode 5, target iOS 17. It must pass first. Darwin/protection/concurrency errors fail the workflow; a Linux build or an excluded `os(iOS)` branch is not a substitute.
2. `generate-project.mjs` checks both reviewed SHA-256 pins and creates a fresh disposable PBX project, following the repository's existing dependency-free generator style. No packages/tools/models are downloaded. No main project is changed.
3. A test-only projection adds `VOICE_ENROLLMENT_TESTING`-guarded initializer and one-shot pre-erase failure hook. The initializer is restricted to the current simulator application's temporary directory. Removing the test-only guarded blocks restores the exact uninstrumented native-v2 actor source, checked by portable tests. The original initializer/production default path and security behavior are unchanged; the source backup is never rewritten.
4. `actor-tests.sh` uses an already-installed iOS 27.0 / iPhone 18 Pro Max runtime, creates its own disposable simulator and runs three XCTest methods (two actor scenarios plus attribute-decoding regression), serialized with two compiler jobs. It never resets another simulator. Exactly three passes and zero failures/skips must appear in the xcresult summary; an absent/incompatible summary fails rather than inventing success.

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

The four portable tests are not the three pending native tests. Preserve these distinctions in reporting.

## First Apple run and scene-host correction

Run `40204850113` at commit `efa9e8ca87f66e1e28e8639e5fc5a7ea01be27f9` passed untouched-source iOS SDK typechecking on Xcode 27.0 / iOS SDK 27.0. The projected XCTest bundle and host built, but actor assertions did not execute: the old blank UIKit host crashed before XCTest bootstrap because this SDK requires UIScene lifecycle adoption. This is a probe-host failure, not an enrollment test pass or enrollment assertion failure.

The generator now uses a blank SwiftUI `App` / `WindowGroup` scene with generated scene/launch manifests. Portable regression checks require that scene lifecycle. No enrollment code, hooks, protection logic or production source changed. That correction awaited a native rerun; the following section records the subsequent failed actor execution. The original local-validation receipt documents the first candidate; `evidence/scene-host-repair.json` documents this correction.

## Second Apple run: real guard rejection, diagnostics pending

Run `40205942187` at `f09b2689a1e31a0be1becb1b5ef093371ffc918b` passed untouched-source SDK typechecking and executed both native XCTest methods. **Both failed**, throwing `invalidRecord` at the guard requiring backup exclusion and complete protection. There is no actor workflow pass. The scene-host correction worked; failure occurs before the intended save/delete scenarios complete.

A test-only diagnostic prints only `excluded`, `typedComplete`, `rawComplete` booleans and the Foundation attribute's type whenever the original typed-cast comparison would reject a synthetic fixture. This includes corrected successful raw-string cases, making representation differences observable. No path, record, contents or identity metadata is printed. The native-v2 source selection and three-test criteria below supersede the original pins/count; security requirements and both actor-scenario assertions remain intact.

Apple documents the protection attribute value as NSString: https://developer.apple.com/documentation/foundation/fileattributekey/protectionkey . This makes the direct FileProtectionType cast a candidate mismatch, not yet proof of the observed runtime cause. The diagnostic distinguishes this from unsupported simulator protection or backup flags. A missing/weaker value must remain failure. This diagnostic was prepared before the native-v2 source correction below; it does not bypass the simulator. Historical receipts remain evidence of their exact older revisions.

## Native-v2 source selection

The probe now selects `../source-native-v2/ProtectedVoiceEnrollmentStore.swift` plus unchanged `../source/VoiceEnrollment.swift`, with exact revised hash pins. The historical `source/` actor/71-check receipt are untouched. The new helper uses documented raw-value conversion for NSString/String protection metadata, still requiring exact complete protection and independent backup exclusion. No missing/weaker property is tolerated. The native test count deliberately becomes **3**: both original actor scenario methods unchanged plus a representation/negative-input test. The exact no-skip success gate is 3 passed / 0 failed / 0 skipped. No native-v2 execution result exists yet. See the source-native-v2 README and evidence/native-v2-repair.json.
