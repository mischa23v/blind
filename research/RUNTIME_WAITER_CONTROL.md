# Inert publication-driven waiter control

Production and the ordinary hosted test file are unchanged. Before reading or substituting source or invoking Apple commands, the control requires `RUNNER_ENVIRONMENT == github-hosted`; missing, unknown or self-hosted values fail closed. The candidate lives outside the iOS target. The dedicated workflow checks out observed-failure source `de0da00424b5dd3cae9e98e67894eddcffc74447` into an isolated directory, verifies preimages, and substitutes only the reviewed test copy. The original waiter body and entire fixture/test tail (17 methods, all assertions) are byte-identical. Missing/invalid control mode fails closed.

## One fixed pair

Compile once; candidate `publication-v1` FIRST, original `original-v1` SECOND. Each arm uses a fresh owned simulator, separately measured boot readiness, a cold application, the same compiled app/test bundle, and exactly the same 17 selectors. Seventeen unique buffered mode records must prove each arm. Never retry or stop after the first functional failure. A pre-test infrastructure failure is not a test result. Both outcomes and original failures remain recorded. No asset downloads, warmup runs, production priority changes or timeout inflation.

Unchanged per-command bounds: build 1,200 seconds; boot 180 seconds per arm; tests 900 seconds per arm; cleanup commands 30 seconds each. The 65-minute job envelope includes both arms and cleanup (build/boot/test caps alone total 56 minutes); it does not extend any test assertion or audit deadline.

## Candidate semantics

Initial condition fast path is preserved. Otherwise one immutable `ContinuousClock` deadline is set to start + three seconds. The chained publication callback evaluates the original predicate, then samples the clock; late truth cannot pass, even if the deadline wake runs late. One checked continuation and lock-protected latch allow only one settlement. Exactly one inherited-priority deadline task sleeps to the absolute deadline. Cancellation and continuation resumption occur outside the lock; settlement before continuation/wake installation is supported. A defer restores the previous observer on every exit and cancels outstanding work. Cancellation propagates, and the final condition assertion remains.

All callback diagnostics remain in the bounded per-test buffer; no stdout in timed callbacks. Observation, deadline-wake and resumed-return timestamps are distinct. A delayed return does not retroactively make an on-time observation late; a late observation never becomes timely because of delayed return. MainActor scheduling can delay timeout return. This is not a wall-clock guarantee of prompt test completion.

## Interpretation limits

Existing failures include a 5.660-second detached queue-admission delay at observed task priority 25, not slow decoding, and a further 4.695-second delay after fulfillment before XCTest returned. This control cannot make such late publications timely. Candidate late failures would show XCTest fulfillment is not necessary for those failures. A pass/fail difference would be suggestive only: fixed candidate-first order, host load, OS caches and other scheduling differences remain confounders. Neither a pass nor a fixture repair establishes production latency, model capability or physical-device safety.

## Verification before native execution

Five mechanical source checks preserve the exact original waiter and all 17 test bodies, and ensure the standalone latch witness uses the actual candidate helper. Twelve synthetic infrastructure checks cover mode identity, fixed pair ordering/failure retention, cleanup, bounds, fingerprints and changed assertions. Swift 6.4.1 standalone latch execution covers exact deadline, late publication, delayed timeout, cancellation before installation, 100 fixed concurrent single-winner races and late wake cancellation. The actual extracted waiter also compiles against a minimal synthetic runtime and passes synchronous pre-install publication, cancelled parent, a real three-second timeout and observer restoration. This is not full hosted-target typechecking; actual Apple compilation and both native arms remain pending.

Portable witnesses reside beside the candidate. Run `source-witness.py`; compile `PublicationDeadlineLatch.swift` plus `LatchWitness.swift` with Swift 6. For the integration witness, run `make-integration-witness.py <writable-output.swift>`, then compile that output with the same latch. Use isolated writable compiler caches. The pinned baseline and candidate are intentionally not members of the ordinary iOS project.
