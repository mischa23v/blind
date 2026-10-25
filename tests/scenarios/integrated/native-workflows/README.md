# Authored native-controller workflow regressions

**Prepared and source-reviewed; native compilation and execution remain NOT RUN.** Three XCTest methods are prepared. A fourth OCR replacement workflow remains specification-only. This adds zero completed journeys to the 400-journey tracker and makes no model, camera, microphone, audio, physical-task or safety claim.

## Fixed source and scope

The source baseline is `452b9ebac628efd5d61290174cac52318f6b7890`. Nine relevant source blobs are pinned in `remote-source-pins.json`. The runner checks the exact checkout commit; the preparation script verifies those blobs and records relative hashes of copied source. Test-only adaptations are explicit, not production fixes.

The tests call the real `NavigationModel.receiveCompanionUtterance` trusted-interface dispatcher and observe actual task/memory state at the code-owned reply boundary. Backpack correction and fridge completion use the real memory writer and reopen a new controller after acknowledged database commit. This is not process-kill or power-loss durability. Authored trusted text and injected detector state are fixtures, not model-selected tool actions or sensor observations.

An unexpected model lane is blocked and fails the zero-invocation assertion. The “quiet versus cancel” test checks retained goal, cancellation, and unchanged injected hazard state; it does not establish warning playback. The frozen outcomes preserve the distinction between in-memory “noted” and durable “saved.” Writer revisions and pending/error status are recorded; confirmed persistence is checked before reopen.

## Isolated host

The preparation script only writes a new destination outside its input checkout. `DEBUG && BLIND_WORKFLOW_TESTS` guards the observation seam, empty test App host, and suppression of the Bluetooth manager/connect path. Default production behavior is unchanged. The generated app uses `org.blindassist.workflowtests`, separate test bundle IDs and no shared app-group/keychain entitlements. Text-only XCTest execution prevents live camera/microphone/audio startup. Do not install under the production app identity or run on a user's physical device.

The separate manually dispatched CI workflow runs only in the public canonical repository, has its own noncancelling concurrency group, creates a fresh simulator, and deletes only that simulator afterward. It permits normal resolution of the existing GRDB 7.11.1 dependency and verifies revision `b83108d10f42680d78f23fe4d4d80fc88dab3212`. No new dependencies, model weights, assets, frameworks or simulator runtimes are installed.

## Evidence and remaining work

`run-native.sh` requires exactly three executed passes, zero failures, zero skips and no expected-failure masking. Compile errors, missing results, missing tests and assertion failures remain failures. Logs and xcresult are preserved separately from ordinary native CI. Do not rewrite frozen outcomes to match observed behavior.

Python/shell/Node syntax and isolated project generation were checked. Source review is not native compilation proof. Passing these authored controller regressions would remain narrower than actual local-model tool selection, real perception, speech delivery or full connected journeys.

Reader27 code is present, but the fourth OCR workflow still lacks a reviewed native capture/Vision-completion injection seam preserving real selection, epoch, request and output-callback ownership. No placeholder pass/skip or direct Core-only substitute counts it complete. Original freeze is retained in `frozen-expectations-v1.json`; current expectations additionally observe persistence and check fridge reopen after confirmed commit.
