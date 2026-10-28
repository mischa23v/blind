# Classified callback stage receipts

## Finding and scope

Native run [40698547633](https://github.com/mischa23v/blind/actions/runs/40698547633), source `6fe9d5270f23954fa59fc3509cccf23445cefa51`, failed three Classified callbacks at the unchanged 10-second deadline. The test's boundary receipts were 12,702 / 10,064 / 10,008 ms; these include test scheduling and do not locate the delay. The bounded native helper did not retain standalone receipt lines.

Source inspection finds no main-queue dependency in this path: request work uses the shared serial utility worker, callbacks use a global utility queue, and the test awaits asynchronous fulfillment. This rules out the proposed explicit main-queue blocking wait in these files, not all possible Apple/CI scheduling problems. Native Recast work is synchronous on the worker. A terminal discard fences ingress but cannot interrupt admitted native work; its geometry-release block is scheduled after pending work drains. A timeout does not establish a permanent deadlock or a completed route.

**No runtime speed or correctness fix is claimed.** This change adds narrowly opted-in diagnostic evidence so the next native run can distinguish queueing, build, query, callback delivery and discard stages. The 10-second deadlines, dispatch queues/QoS, geometry, native calls, revision fences and test verdicts are unchanged.

## Candidate implementation

- `RoomMeshCandidateRuntime`: DEBUG-only synthetic-test convenience initializer and random receipt ID; at most 64 fixed-stage/numeric monotonic-time receipts per opted-in runtime. The clock and append happen under the existing short lock; no observer callback runs under it. Calls to record stages occur outside existing locked regions. Callback diagnostic recorders use weak ownership (or a noncapturing no-op when disabled) so they do not extend runtime lifetime. Regular initialization does not enable collection. Release preprocessing removes the diagnostic API/storage/calls entirely.
- `ClassifiedRoomMeshTests`: only these authored geometry tests opt in. Print bounded snapshots at callback, wait completion, and normal/failure discard completion. A fresh synthetic receipt ID associates snapshots without exposing session, anchor or room identity. The previous 10-second nil-result failure and terminal-discard request are retained.
- `native-apple.sh`: preserve only the closed event/stage grammar and synthetic UUID/numeric values, at most 40 lines and 1,500 characters per line, on either hosted-test outcome. No arbitrary errors, model output, geometry, source identity, screenshots, audio or logs are newly exported. The separately expanded six-report collector is unchanged by this timing work.
- Stage-85 integrated checker/pins: add one reversible helper layer before the unchanged recorder-timing and scene-timing layers. Preserve workflow hash `ba74cd55…` from the already published early-summary fix and every older source pin. The new inverse must recover exact helper `d798efee…` before reversing older layers.

The stage names are `requestEnqueued`, `workerStarted`, `nativeBuildBegin`, `nativeBuildEnd`, `routeBegin`, `routeEnd`, `nativeFailure`, `completionQueued`, `completionDelivered`, `discardRequested`, `discardWorkerStarted`, `discardReleased` and `discardCompletionDelivered`.

Build timing includes Swift/native argument preparation and native construction; it is not an internal Recast phase profile. Worker-start to build-begin also includes geometry extraction. A thrown build/query records `nativeFailure`; an absent successful-end marker alone is not a hang. Completion delivery and discard completion can race on separate global tasks: discard does not cancel callback delivery or prove system-memory erasure. Measurements describe this explicitly instrumented DEBUG test, not production performance. The diagnostic API does not cancel work, choose a route, change geometry, extend a wait, or grant physical authority.

## Local verification

`python3 research/classified-stage-timing-20261028/check.py`: **8 source/receipt contracts passed**. Includes lexical token equivalence of the Release-preprocessed runtime to the exact source baseline (comments/whitespace/semicolon separators ignored), unchanged test deadlines, bounded opt-in storage, helper inverse comparison, `bash -n`, and real bounded shell extraction over valid/invalid synthetic receipts. Also verifies all three helper inverse layers recover their exact hashes, the integrated checker changes only by adding the first inverse stage, and no unrelated/historical pins are changed. Initial source-check wording also matched an unchanged comment containing “diagnostic”; it was narrowed to the actual diagnostic symbols and rerun. No behavior assertion was relaxed.

These are not Swift compilation, XCTest, native timings, cleanup completion or performance measurements. The full integrated app inverse checker is not run in this partial checkout; its helper-only inverse chain was tested separately. No Swift/Xcode toolchain is available here. Native validation remains pending. Existing actual native failures remain preserved under `research/native-path-recovery-20261028/run40698547633/`.

Independent source review of final runtime `264a4495…` and test `46e2f7df…` found no compile/lock/actor/lifetime blocker and independently reran the eight contracts. The initially noted DEBUG callback ownership effect was removed with the weak recorder before freezing. Nine route Node source contracts also passed after that correction. None of these checks proves native callback latency or a passing Classified route.

## Files and provenance

The runtime/test/helper `.before` files are exact GitHub source at `6fe9d5270f23954fa59fc3509cccf23445cefa51`; integrated checker/pin `.before` files are from verified head `ed7fda1c1d6b0567cf7d2b5875d00780b3ac7e83` (including the current workflow pin). They are inert source evidence, not an alternative runtime. `publication-manifest.json` records the explicit local allowlist and hashes; `verification.txt` is the bounded local source-check output. Only the root owner may publish. No CI rerun, workflow dispatch, push or release claim was made here.
