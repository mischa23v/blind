# Worker CPU versus wall-time diagnostic — opt-in only

## Why

Run40785234872/cb1 measured first ingress query worker wait7.237s, nativeBuildBegin7244ms, and no build end at waitFinished24050ms. Four later owners timed out with only requestEnqueued. This localizes the delay to an in-flight native build and the shared serial worker, but does not distinguish CPU consumption from blocking/descheduling. It is not a transform failure or evidence that a longer test timeout is appropriate.

## Source change and unchanged behavior

This checkpoint starts from published strict-endpoint default-off ceaaa source (RoomMeshCandidate.swift SHA d4684b7d…); `.before` files preserve that baseline. Only existing DEBUG synthetic timing is extended. The release token stream of75/83 is unchanged; normal initializers and production callback paths are untouched. Tests retain real82/83/75/native algorithms, the same fixtures, assertions and10-second deadlines. No warmup, sleep, QoS change, cancellation bypass, fixture reduction or retry-until-pass is introduced.

Existing timing receipts optionally sample `clock_gettime(CLOCK_THREAD_CPUTIME_ID)` and current thread identity at worker, build and route boundaries. Sampling is guarded by the existing explicit synthetic opt-in. Darwin and Glibc paths are conditional; unsupported clocks/platforms produce nil, never assumed zero. Numeric conversion is bounded against Int64 overflow.

Apple's own [Libc clock implementation](https://github.com/apple-oss-distributions/Libc/blob/main/gen/clock_gettime.c) implements this clock using the calling thread's CPU usage. The source deployment targets are iOS17/macOS13; actual Swift/SDK compilation still must run. Linux/Glibc availability does not establish an Apple compile pass.

## Late completion without contaminating the callback

A DEBUG-only `syntheticTimingCompletion` parameter defaults to nil. The hosted synthetic tests opt in with closures capturing no runtime, owner, geometry or session. At worker exit, scalar snapshots are copied and offered to a separate utility diagnostic queue, never invoked on the timed worker or under runtime locks. Original result callbacks still only store/fulfill. Request-retirement and worker-finished metadata preserve late completion after a failed test has requested terminal discard.

Bounds remain64 stored stage records/owner; at most8 completion deliveries/owner and16 pending diagnostic deliveries process-wide. Full buffers/queues may omit receipts; omission is unknown, not proof of cancellation or zero CPU. The late sink does not delay cancellation acknowledgement to wait for diagnostic delivery. There is no promised diagnostic delivery deadline or flush; process termination can omit the final row.

## Output and interpretation

`CLASSIFICATION_WORKER_CPU` emits only random diagnostic UUID, lane, owner-relative worker start, wall/CPU durations, matching-thread validity, retired/native-failed flags and record count. It does not print thread IDs, source identities, geometry or arbitrary error text. CI must use the exact closed grammar and bounded output, including new old-marker stages `workerFinished` and `requestRetired`.

Each CPU pair requires both endpoints, matching worker thread identity and nondecreasing CPU time. Different GCD jobs can use different threads: never subtract counters across jobs or owners. Missing end, unsupported clock or identity mismatch yields cpu=-1/pair_valid=false, not zero. Wall time may remain known when the CPU pair is invalid. Native failure does not fabricate nativeBuildEnd/routeEnd; worker totals may still be measured.

For a valid pair, high wall with low CPU indicates time not spent executing that thread (blocking/descheduling); it does not by itself identify an OS scheduler defect. Similar wall and CPU suggests computational cost, not which Recast substage caused it. Worker totals include bookkeeping and diagnostic sampling; build/route pairs bracket the real synchronous calls. Cancellation remains a fence, not a claim native computation was preempted. The final late snapshot need not include result-callback delivery, which can race worker exit.

## Verification

`check_source.py` performs13 bounded source checks and hashes the four edited Swift files; it is not a Swift parser or native test. `SOURCE_RESULT.json` and `instrumentation.patch` record the exact candidate. Independent source review, explicit CURRENT pin updates, strict marker extraction and exact-source public Apple execution are required before interpreting results. No local Swift compiler is installed and no native pass is claimed here.
