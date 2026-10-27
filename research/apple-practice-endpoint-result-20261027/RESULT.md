# Endpoint control stopped before either UI test

Verified 2026-10-27. [Run 40581825973](https://github.com/mischa23v/blind/actions/runs/40581825973), job `122462937267`, is terminal **failure**. Workflow commit: `8a657fc9f1610466cb990aa94b6c2883d965469c`; full-app source: `fb879d235f38a3f0121b69b023e8ee14c0ded61c`.

## What actually ran

- The Apple runner passed all **42 portable source/receipt fixtures**.
- Xcode 27.0 (27A266a), simulator SDK 27.0, and the owned iPhone 18 Pro Max simulator were selected. Boot completed in 148.987 seconds.
- `build-for-testing` hit its unchanged **600-second limit**. Its receipt records `timedOut=true` and `sentSIGTERM=true`; the bounded progress tail ends with `** BUILD INTERRUPTED **` during app compilation. It contains no recorded compiler error, but is not a successful build.
- Large and AX5 selectors both remain `infrastructure_not_run`. There are **zero endpoint receipts and zero PNGs**. Footer-end reachability is still unknown; actual footer-end pixels cannot be inspected from this run.

## Two distinct tooling blockers

1. **Cleanup evidence is incomplete.** Build cleanup raised `PermissionError` after SIGTERM had been sent. The command record has no `leaderReaped`, `ownedGroupCleanup`, `elapsedSeconds`, or `exitCode`. Simulator shutdown separately hit its 30-second limit and raised `PermissionError` with the same missing final fields. The owned simulator delete command succeeded in 11.956 seconds. Therefore top-level `cleanup=passed` means deletion succeeded; it does **not** establish that build/shutdown process groups were absent. The code allows an error from `killpg`/its existence probe to escape before reaping and final receipt updates. The artifact does not identify the exact failing call or errno, so the platform cause remains unknown. A small mocked reproduction confirms that permission errors can skip leader reaping and status recording; it does not recreate the native platform condition.

2. **Post-run source provenance failed.** Default `git status --porcelain` returned the collapsed untracked directory `?? ios/BlindAssist.xcodeproj/project.xcworkspace/`, while the validator allows only the exact generated `Package.resolved` file path. The generated-lock receipt folds this already-false source status into `generatedLock.valid`, so its `false` value does not independently establish malformed lock contents. The raw 388-byte lock and a complete untracked listing were not preserved. Source integrity must stay failed/unknown, not be retroactively marked passed. A temporary synthetic Git repository confirms default directory collapse and that `--untracked-files=all` returns the exact file path.

## Verified artifact and provenance

[Artifact 12770593353](https://github.com/mischa23v/blind/actions/runs/40581825973/artifacts/12770593353): **3,495 bytes**, SHA-256 `60689a9583cb2e56c6b71aef8af7ed7dcb06d68f770a180aefa1406671aeb387`. Digest matches both GitHub artifact metadata and the upload log. ZIP CRC and relative member paths pass. The two JSON files expand to 16,965 bytes and are preserved byte-for-byte here. There are no image members.

The four harness Python files fetched at the exact workflow commit match their artifact provenance SHA-256 values and the local files. The source receipt names the expected app/test/exporter hashes and `productionEdits=false`, but its final `sourceIntegrityPassed=false` remains authoritative. Full details and per-file checksums are in `VERIFICATION.json`; native receipts are under their original artifact paths.

## Narrow next step; not executed

Before any native retry, repair and independently test the harness only: preserve primary timeout/error and final command records even if group probing/signaling fails; always attempt bounded leader reaping; distinguish simulator deletion from process-group cleanup; fail closed on unknown groups; collect a complete untracked-file listing; separate lock-content validity from source-status validity. Add EPERM and collapsed-directory fixtures. Keep app/test source, selectors, audit behavior, build/test budgets and image caps unchanged. Do not infer permission to increase the build budget from this timeout.

No native retry, production layout change, audit suppression, GitHub write, merge, or device activation was performed during this verification. Existing unsuppressed Dynamic Type findings and Ask contrast/clipping findings remain separate open failures; this infrastructure failure neither validates nor refutes them.
