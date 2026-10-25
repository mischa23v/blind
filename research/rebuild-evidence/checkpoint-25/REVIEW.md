# Registration diagnostic checkpoint review

## Result
Seventeen source/test files are rebased onto verified checkpoint23 production blobs (master `3d22925028463000f203d2b02adac506fb6152fb`). Parent subsequently verified checkpoint24 `63dff7055f25c252da4c4c623b85fd3421716d40`; its changed files do not overlap these production/test files. No shared source or remote state was written.

The increment is diagnostic acquisition/history, NOT a positive room, floor, container, pose, navigation or handling authority. No new runtime dependency, matcher, calibration constant or inferred containment was introduced.

## Requirements and preserved boundaries
- Reuse actual RoomPlan/ARKit capture and existing saved-world recovery; capture original transforms, timestamps, scan/session receipts and hash-bound artifacts, bounded before feature expansion.
- Keep diagnosis/history local in the existing GRDB store and profile; exact room privacy deletion retires pending UI publication before delayed storage/purge work and tombstones reject late writes.
- Helpers explicitly select correspondence IDs. Category/equal identifiers/residual size cannot automatically identify a physical instance, set a current memory scope, or verify floors.
- Restore dated reports only, preserving provenance; selection/restart is not live localization.
- Keep urgent hazard work independent; bounded off-main preparation/storage with stale owner/revision publication rejection.
- Existing comparison-scan hazard interruption remains disclosed. Original recovery IO is not claimed off-main by this increment.

## Review corrections
1. The staged replay required ignored/uncommitted `BlindMemory/Package.resolved` and failed on a clean source projection. It now verifies the committed exact GRDB 7.11.1 declaration and reviewed revision `b83108d10f42680d78f23fe4d4d80fc88dab3212`; the runner does not download dependencies.
2. Independent reviewer identified save admission while a read remained held. Existing guard/UI checked only saving. New A031 executes both same-A and selected-B held reads. Before repair, it failed six assertions: Save returned success, replaced loading status and wrote durable bytes in both cases. The minimal repair checks loading as well as saving at MainActor admission and disables the Save button for either. A031 plus a UI contract preserve this behavior.

3. Full Node aggregate exposed an exact-prefix source contract that predated the new registration hook. The original synchronous loss-retirement regex is retained unchanged; the updated contract separately requires the exact synchronous registration hook after loss retirement and before throttle, with missing/asynchronous-hook mutation counterexamples. All 21 focused spatial review checks pass.

## Evidence
- `evidence/core-aggregate.log`: all 1,249 Core tests pass, zero skips, including the recorded trajectory case.
- `evidence/node-aggregate-before.log`: original full suite result is 435/439, with one obsolete exact-prefix contract and three ENOSPC compiler-output failures. This is not a passing aggregate. Own inactive generated compiler outputs were reclaimed, preserving all source/harnesses/logs.
- `evidence/rebase.json`: seven preimage Git blob hashes match remote tree; clean three-way rebase, seven additive files.
- `evidence/replay-first.log`: original ignored-lockfile failure.
- `evidence/replay-second.log`: default clang cache path was read-only, before tests ran. Corrected with writable scratch module-cache environment; no escalation or change to permission policy.
- `evidence/replay-third.log`: original 30 executable cases and five Node checks pass after durable runner correction.
- `evidence/held-read-before.log`: A031 six-assertion failure against uncorrected source; all preceding cases pass.
- `evidence/held-read-after.log`: 31 extracted/Core/real-GRDB-wrapped acquisition cases and six Node checks pass, zero failures/skips.
- `evidence/memory-final.log`: all 51 real-GRDB memory tests, including the three additive registration storage tests, pass with zero failures/skips.
- `evidence/native-parse.log`: changed native files parse under default, DEBUG, BLIND_FAMILIAR_PEOPLE, and combined DEBUG/BLIND_FAMILIAR_PEOPLE/developer-cloud flags. This is not Apple SDK compilation.
- Independent review by `registration_review` approved the exact fix/test strategy and found no further blocking implications.

## Remaining gates
- Apple SDK typecheck/build and actual UI/VoiceOver behavior are not exercised by Linux source extraction/parsing. Existing native CI should validate the integrated source.
- Actual `captureSession(_:didEndWith:error:)` builder-result publication block has source-contract checks only; extracted replay does not execute that native callback.
- Real-device capture latency/allocation/energy and failure ordering remain unmeasured.
- Positive identity remains blocked on independently validated relocalization/registration uncertainty, justified room/floor containment and independent target-instance correspondence. Authored two-fridge examples and same-frame residuals do not supply those facts.
- No new child/mobile trial, walking/handling guidance or production-readiness claim is supported.

## Combined footer candidate
Parent requested the separately diagnosed practice-footer repair in checkpoint25: `DashboardView.swift` plus its new source-contract test. Exact Dashboard preimage SHA256 was verified before overlay. Independent reviewer confirmed precisely four semantic font/wrap/alignment modifiers, unchanged English/Arabic safety text, unchanged native audit, and actual Apple failure naming this footer. This adds no Core change. Apple rerun remains required.

## Final extraction adapter
The second full suite passed 440/441 checks and exposed the previously ENOSPC-masked scoped-review harness dependency: its existing extraction range now includes actual `historicalReports(for:)`, but its authored prefix had no `SavedPlace` type. The fixture now defines only `SavedPlace.id: UUID`, matching production metadata, with no fake history implementation or changed assertions. Actual historical retrieval logic is covered by registration A012/A013 calling the actual extracted helper and Core factBook, preserving source/time/hedge/scope, no current location or goal mutation, and decoded history. Independent review approved the metadata-only seam. Original failure is retained in `evidence/node-aggregate-fixture-before.log`.

## Final aggregate result
After the reviewed test-adapter fixes and footer overlay, the final standard serial Node aggregate passes **441/441**, zero failures/skips. Full Core is **1,249/1,249** (including the original recorded trajectory case); real-GRDB memory is **51/51**. No Core/Memory production source changed after those passing suites. Final17 source hashes exactly match the tested projection. `evidence/node-aggregate.log` is the final pass; prior full failures remain named separately.
