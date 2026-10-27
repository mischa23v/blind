# One-shot indoor import phase diagnostic

## Question and source finding

The earlier `focused-indoor-io` run 40470002343 observed an actual first-invocation
10-second map-IO wait failure on both baseline and review, followed by passing
isolated/class executions. That does not prove a regression or a fix. Its
`source_clean_after: false` lacked the changed paths needed to interpret provenance.

The source chain at `e9e18d15fe1fdac1ff1487b3c2a8a2e731607427` is:

1. `IndoorNavigator.init` starts `RegisteredIndoorNavigation.restore`.
2. The synthetic test immediately calls `load`; `beginIO` invalidates the restore
   token and submits the import to the same serial `.utility` worker.
3. `SpatialMapIO.drain` prepares/decodes, reads prior durable bytes, writes, then
   enqueues main publication. A superseded restore may finish with an expected error.
4. Main publication checks current ownership, calls registered/navigator/test
   completion, then enqueues the worker acknowledgement and resumes draining.

No lost callback, deadlock or specific bottleneck was established by source review.
In particular, changing queue QoS or extending the wait would hide rather than
explain the observed failure. There is **no production fix in this directory**.

## Scope and containment

The dedicated workflow is limited to the same public repository and review branch,
read-only permissions, full-SHA-pinned checkout/upload actions and unsigned default
Apple Debug configuration. It applies exact-anchor markers to **four files in a
separate disposable source checkout**, not to committed app source. The source pin,
Xcode 27.0, simulator SDK 27.0 and already-installed iPhone 18 Pro Max are checked.
No dependency installation, simulator download, cloud/model backend, secret input,
private geometry, signing, device execution or runtime feature activation is added.

One original `testTrackingLossStillInvalidatesRetainedMapFrame` invocation follows
one unsigned build. There are no repeats or retries. The original XCTest assertions,
10-second waits, utility queue and production control flow remain intact. The
workflow wall limit is 30 minutes; build/test subprocess limits are 18/6 minutes,
with process-group termination on expiry. This is not a latency benchmark: the
bounded lock/print diagnostic itself can perturb scheduling.

## Reading the evidence

`single-1-phases.json` retains at most 256 markers, each <= 1000 characters. Markers
contain only a fixed phase name, monotonic uptime, main-thread boolean, sequence
number, and process-local random request UUID. They contain no map identifiers,
geometry, bytes, URL/path payloads or error descriptions. Decode the stage using the
ordered sequence and same token, not just the last globally printed line:

- `submit` / `worker.enqueue` without `job.taken`: admission/worker scheduling.
- `prepare.begin` without `prepare.end` or `job.error`: preparation/read/decode.
- `previous-read.begin` without end: prior durable-byte read.
- `write.begin` without end/error: actual storage write.
- `publish.enqueue` without `publish.main`: main publication scheduling.
- `publish.main` then `registered.callback` / `navigator.callback` but no
  `test.completion`: inspect callback ownership/result delivery.
- `test.completion` but no `test.wait.end`: waiter resumption.
- `publish.callback-returned` without `ack.worker`: worker acknowledgement scheduling.

Missing output is not proof that a stage never ran; process termination or output
capture can lose markers. A pass does not close the intermittent timeout. A failure
with useful markers narrows the next investigation; it is not automatically a
proven cause.

`provenance.json` records source/harness/helper hashes and exact Apple toolchain.
`source-before.json` and `source-after.json` cover every Git-tracked and unignored
untracked file by path/hash, without copying their contents. Symlinks are hashed as
link text, not traversed. `expected-instrumentation.json` records the four deliberate
changes; `summary.json` distinguishes all changes from pristine, unintended changes
relative to the instrumented state, and final porcelain paths. Ignored build output
is outside this source-integrity inventory. Any unintended source delta fails the
harness but remains visible rather than being erased or called an app regression.
Raw `.xcresult`, DerivedData, and full logs are not uploaded. Diagnostic log excerpts
are capped at 160 first matching lines plus 100 tail lines per phase (1000 chars each).

## Local validation and limits

Python AST parsing and disposable-file instrumentation were checked on this Linux
executor. All exact anchors matched; a second application was rejected; original
wait/assertion counts were preserved. No Swift compiler, Apple build or simulator
was run locally. Native compilation, execution and actual phase evidence await the
bounded Apple workflow. This diagnostic does not establish physical localization,
safe guidance, device acceptance or release readiness.
