# Obsolete scene planning avoidance — source candidate

## Evidence and limited cause

Exact published source `2aded1605b11f8da273e01fe6677a0b3aafc8e73` failed the retained 1.2-second scene assertion at **3.090054958 seconds**, despite functional completion. [Original run evidence](../native-candidate-app-integration-85/integrated/evidence/run40659479406/README.md) remains unchanged. Goal worker wall time was 1.600089s, body worker 0.453911s and final body:nil worker 0.002446s; goal main handoff was 0.751055s. These are elapsed wall times, not CPU time or a proven Simulator explanation.

Source establishes one avoidable operation: `ObservedSceneRuntime.offer` always computed `planCurrent` for body-bearing work before checking the main owner's goal/body revisions, even when those revisions had already been retired while the queue was deliberately suspended. The final body:nil receipt does not isolate all potential causes, but confirms a different work path. No measured hot instruction inside Core is established. `LocalPlanner` builds a bounded per-current-frame height dictionary and support set, then scans its open set while planning; no replacement navigation algorithm or speculative data-structure rewrite is introduced.

This change avoids **obsolete not-yet-started plans only**. It does not prove valid plans are fast, fix the observed main handoff, or establish device latency. A separate `phase=validCurrent` receipt records actual current-frame planning in the new native fixture. There is no relaxed timing gate or acceptance-by-retry.

## Implementation boundaries

- Every accepted job captures one small, lock-protected plan-validity token. Begin, stop, tracking loss, goal/body retirement and live suspension invalidate that token synchronously.
- The serial worker still calls `setIntent` and `observe` before checking validity. Historical depth hits therefore remain available after a goal/body change; they never become current support.
- Only `planCurrent` is bypassed if the token is already invalid. The lock is not held during accumulation, planning, hooks, actor work or publication. An invalidation racing after the check is still protected by the existing main epoch/session/goal/body fences.
- `workID` and its token remain owned until the exact main callback retires the job. Busy frames still drop. No second worker, queue, backlog, QoS increase or freshness change is added.
- Original `.utility`, cadence 0.1s, freshness 0.5s, all original test bytes/assertions and the 1.2-second assertion remain. The original fence fixture gains only three plan-invocation assertions.

DEBUG timing now has seven fixed numeric slots: admission, worker start, observation finish, plan start, plan finish, worker finish, main delivery. Existing field names/prefixes remain; `observeWall`, `planInvoked`, `planWall` are appended. Skipped planning has absent start/finish values and `planInvoked=false`. Logging still occurs only in tests after completion, not in worker/main callbacks. The existing eight-line/1,500-character extractor is unchanged.

The DEBUG after-planning hook is captured at admission and normally nil. Its deterministic native regression holds the worker **after real planning completes, before main delivery**, invalidates goal/body, verifies busy rejection and no stale publication, then releases it and verifies a subsequent current plan. This tests an already-started operation's retirement; it does not claim to interrupt inside Core planner instructions. The hook is excluded from `planWall` but included in worker wall time when deliberately used by that fixture.

## Verification

- 14 bounded Node source contracts pass: five new mutation-sensitive scene contracts and nine existing contracts. These are not execution of Swift.
- Six existing bounded-extraction checks pass; helper source is untouched.
- All original scene test bytes are retained except three additive invocation assertions; two new native tests are added. They cover skipped old-goal/old-body planning, preserved historical hits, sparse-current unknown terrain, valid current planning, immutable receipts, and both goal/body late invalidation.
- Independent read-only review found no source-level locking/safety blocker. Its suggested test-name clarification was applied. Final name describes the actual post-computation/pre-delivery boundary.
- `git diff --check` passes for the candidate files.
- **Native Swift compile and XCTest execution are not run**: this executor has no Swift compiler or Apple SDK. No workflow, install, heavy build, new model, timeout or runtime activation occurred. No speed improvement, full-app pass or physical authority is claimed.

Preimages are retained here; `APPLIED.patch`, `MANIFEST.json`, `CHECK_RESULT.json` and `source-contracts.log` identify the source-only increment. Root owns publication and existing-CI validation.

## Other failures remain separate

**Recorder:** the two 5-second snapshot/clear timeout failures are retained. `RecordedRouteStoreTests.snapshot` serves many reads in ActiveTrip, so its one line-number timeout does not identify first-open, a particular iteration, database work or main delivery. Both failed methods are synchronous XCTest methods, not the previously repaired async MainActor waiter pattern. Proposed next diagnostic: bounded operation/index plus enqueue/start/database-finish/main-delivery timings, then compare an async fulfillment helper with the same 5-second assertions. Replace the clear fixture's arbitrary 50ms sleep with an explicit pending-worker gate only in a separately reviewed fixture change. No recorder source or timeout is changed here.

**Model:** five Swift Testing declarations failed because no reply completed. The job log includes `com.apple.UnifiedAssetFramework` Code 5000 / FM.Overrides asset-catalog messages despite availability being reported available. That is a correlated service diagnostic, **not established as the thrown response error or root cause**; the adapter's generic catch omits its error category. Minimum next evidence is an allowlisted typed error category/domain/code and monotonic invocation lifecycle, not model text or arbitrary error descriptions. No generation or asset-install experiment was performed.

The preserved internal timestamps put the XCTest suite end at 09:00:10.584, after the scene/recorder failures; observed model ExecuteRequest errors occur around 09:00:12.150–12.804. Thus these snippets do not support blaming simultaneous model inference for the preceding XCTest stalls. The full unit execution chronology is not preserved here.

`CommunityTests.swift` has four separate top-level `.serialized` suites. Apple documents that this trait serializes a suite's descendants, not unrelated suites ([parallelization](https://developer.apple.com/documentation/testing/parallelization?changes=la)). The existing native helper already uses `-parallel-testing-enabled NO`; do not add another serialization policy without observing actual overlap/configuration. `LocalImageAssistant` is a static async adapter, not an exclusive actor/lease, while the app's MainActor task orchestration has logical busy/cancellation gates. Actor isolation alone would not establish exclusive ownership across suspension. These are source observations, not proof that model calls overlapped in this run.
