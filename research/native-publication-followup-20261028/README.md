# Actual publication completion, follow-up to native 3aef

Status: applied, independently source-reviewed candidate; native execution pending. No local Swift compiler, native run, workflow launch or push. Root owns publication.

## Preserved first failure

The existing 3aef native run compiled and executed the earlier completion-fence stage. Its first result remained failing: 160 hosted cases, 149 passed, 5 failed, 6 skipped. The new three connected-owner integration cases passed; those are not physical navigation validation.

`3aef-first-failures.txt` preserves the exact existing job-log failure lines and journey phase window. DeleteWhileRestore's read was released; detached restore then waited **4.330961s** before starting, followed by catalog admission waiting **6.330477s**. Actual publication eventually fulfilled, but the original three-second test expectation had already failed. This is another functional test using a host scheduling deadline, not a demonstrated lost callback. Replace only that test's post-release condition wait with the already-reviewed real operation fence. Keep its queued stale-map deletion, tombstone and destination assertions unchanged. Do not touch the production journey runtime.

Four scene cases failed: goal/body generation fence, actual accumulator/restart, future timestamp rejection and worker/watchdog expiry. Their oracles used fixed sleeps/poll windows or a queue-to-main marker with a shared 1.2-second budget. Failures establish snapshots/plans were not available when asserted; unlike the journey trace, there are no detailed scene worker phase timings proving exactly which scheduler stage caused each delay.

## Exact scene completion receipt

DEBUG-only observability now creates one receipt **after** a frame is admitted and assigned its work ID. The real queue job captures that receipt. Its actual main-owner delivery callback finishes it in `defer`, before any weak-owner/work-ID/generation early return can bypass completion. Thus completion means that specific accepted job reached its real publication-or-rejection callback—not that an unrelated queue marker ran.

The receipt has one optional continuation and a finished bit. A second concurrent waiter throws; completion is idempotent and clears the continuation before resuming it. No work, already-completed work and synchronously rejected frames need no wait. Stopping/restarting preserves the existing occupied worker slot; its old completion still resolves. Repeated jobs in the same epoch receive distinct work-ID receipts. Task cancellation does not cancel the underlying scene job: the fence still resolves at its actual callback, rather than inventing completion. The queue strongly captures the receipt independently of the weak runtime owner, so deallocated/stale-owner exits also finish it.

All functional scene fixtures now await these real callbacks before checking their original assertions. The original **1.2-second budget remains an explicit latency assertion after the complete goal/body functional scenario**, with a metadata-only elapsed-time record. It may still fail. This is not a latency improvement and does not convert a slow completion into a timing pass. Other actual responsiveness and freshness checks remain unchanged; in particular the runtime's **0.5-second freshness window**, queue QoS, admission rules, epoch/goal/body checks and 1.6-second expiry fixture are unchanged.

## Validation limits

- 15 portable checks verify exact change scope, release-source identity, all original scene assertions, callback receipt placement and the retained latency assertion.
- 21 existing Node structural checks pass: observed scene, runtime phases, runtime priority and runtime buffer suites.
- `.before` files preserve all three exact preimages; `APPLIED.patch` records this stage only.
- These are source/provenance checks, **not Swift or concurrency execution**. The next already-authorized native CI must establish compilation and real behavior. No retry or widened timeout is requested.

Independent review by `/root/review_recorded_route_preview` found no remaining source-level blocker. Explicit caveat: if a worker or its main callback never executes, the functional continuation has no invented timeout/cancellation success; existing XCTest/job hang bounds remain the outer guard. This does not fix scheduler liveness.
