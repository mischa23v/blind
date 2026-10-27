# Buffered indoor IO observer — proposed bounded comparison

**Proposal only; no Apple execution or production fix established.** Root must review
and explicitly publish. `workflow-proposal.yml` is inert in this research folder.
Once installed at `.github/workflows/indoor-io-buffered-diagnostic.yml`, its push
trigger is limited to `codex/recovery-hazard-order-20261027` and changes under
`research/indoor-io-buffered-diagnostic/**` or that exact workflow path; manual
dispatch is retained. User authorization covers this bounded comparison. No changes to previous diagnostics, their results, or production IO.

## Why this observer

Run 40558970296 (source `e9e18d15fe1fdac1ff1487b3c2a8a2e731607427`, harness
`18d5820ae6dba990a8dc413d42e92d98c1fb3bab`) built but its original focused test failed;
the outer test command timed out. Its global logger held an NSLock during print,
with most timestamps sampled after logger acquisition. Therefore the approximately
11.459-second submit-to-drain and 18.724-second open-to-prior-return spans cannot
be assigned exclusively to dispatch or FileHandle. The approximately 1.9-microsecond
slot-lock acquisition was separately captured and does not implicate that lock.

Copied from the exact recovered published refined harness, including strict generated
GRDB resolution validation. This changes the observer, not history validation/storage.

## Predeclared experiment and stopping condition

Exactly two independent one-shot arms, same pinned source/toolchain/test/assertions:

1. `utility`: original queue QoS.
2. `userInitiated`: exactly one disposable source line changes queue QoS.

Both use this same buffered observer. Each matrix job has a fresh source checkout,
arm-specific DerivedData/evidence, a newly created simulator using the already
installed iPhone 18 Pro Max / iOS 27.0 device/runtime, and no warmups or retries.
The runner attempts simulator shutdown/deletion in bounded, best-effort cleanup;
outer job cancellation or runner loss can prevent its finally block from completing.
Cleanup is not guaranteed under outer cancellation. No downloads. Jobs
are serial (`max-parallel: 1`) to avoid deliberate mutual workload interference.
Host coldness, scheduling and system contention are not controlled guarantees.

Keep original 10-second XCTest wait, original assertions/callbacks, 1080-second
build and 360-second test-command budgets. Each arm retains its own failures,
coverage, integrity and capture result; one pass must not erase the other failure.
After these two outcomes, stop and review the evidence. One sample per arm does
not establish a QoS causal effect, general latency or a production fix. No storage
precheck, history-read bypass, timer increase, rewrite or production QoS adoption.

Runner invocation per independent disposable checkout:

```
python3 research/indoor-io-buffered-diagnostic/run.py SOURCE e9e18d15fe1fdac1ff1487b3c2a8a2e731607427 review utility
python3 research/indoor-io-buffered-diagnostic/run.py SOURCE e9e18d15fe1fdac1ff1487b3c2a8a2e731607427 review userInitiated
```

These are commands for two separate clean checkouts/jobs, not sequential invocations
against a single already-instrumented source tree.

## Recorder contract and privacy

- One fixed 256-slot optional-event array. Records hold only literal phase,
  process-local UUID, monotonic uptime, main-thread flag, insertion sequence.
  No map bytes, file paths, private IDs, errors, screenshots or system traces.
- Capture uptime before recorder locking/thread-dictionary resolution. Slot-lock
  boundary times remain captured around the production lock and recorded after
  unlocking. Recorder does no print, file IO, string formatting or sorting in emit.
- A small recorder lock protects slots/count. Thread-local context still correlates
  synchronous nested operations. Its allocations, runtime initialization and lock
  overhead remain perturbations; this is not an uninstrumented benchmark.
- Immediately after the **original** XCTest wait returns (also on expectation
  failure), record wait.end then close/snapshot the recorder. Flush outside the
  recorder lock, before the unchanged XCTUnwrap can throw. No periodic flushes.
- Snapshot closes permanently. Later worker events are censored and never printed;
  delayed older records that arrive after close are also censored. Output after the
  wait may affect ongoing work, so it is deliberately outside the observation window.
- Events print sorted by captured uptime, then insertion sequence. Sequence is
  insertion order, not timestamp order. The header reports snapshot-close cutoff,
  retained count and overflow; the footer verifies completed output.
- Missing snapshot/footer, overflow or inconsistent counts is incomplete capture,
  never diagnostic success. Termination before wait return may leave no trace.
  Missing events do not establish nonexecution or deadlock. `return` can be a
  throwing scope exit; `file.open.throw` records no error contents.

## Interpretation

Use fixture `test.action.begin` plus ensuing install/submit token to identify the
fixture. Startup restore tokens remain distinct. `drain.enter` and slot timestamps
use a worker-owner UUID; `job.taken` establishes its request token. Never merge
unrelated startup file-open spans with the fixture. `worker.already-running` means
its original worker was already admitted; it is not proof a prior job is executing.

Enqueue/start spans are wall-clock progress intervals, including scheduling and
remaining observer overhead, not CPU time. File-open entry/end-or-throw bounds
isolate that call's wall interval better, but still include thread descheduling and
exception handling; they do not prove OS/filesystem fault. If wait closes before an
operation returns, report its observed lower bound as right-censored. Actual success
still requires the original test's passing outcome and preserved assertions.

## Local validation (not Swift execution)

`verify.py` checks Python AST, pinned-source exact anchors, four-file scope,
unchanged wait/assertion/dispatch counts, atomic rejection of drift/reapplication,
unknown-arm rejection, and exactly one-line QoS difference between generated arms.
`verify_recorder.py` checks source contracts for capture-before-lock, fixed capacity,
no hot-path output, close-before-unlocked-flush, and deterministic tie ordering.
Its bounded-cap/order/close reference model is explicitly Python, not execution of
Swift or proof of concurrency behavior. `verify_resolution.py` preserves strict
known-public-pin and malformed/symlink rejection tests. Actual Swift compilation,
concurrency behavior, simulator execution and XCTest outcomes remain pending.
