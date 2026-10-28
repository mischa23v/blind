# Callback-path measurement repair

After run40780118332, remove synchronous diagnostic output, formatting and receipt snapshots from both hosted callback helpers. The result callback only writes its locked result box and fulfills XCTest. Normal discard only fulfills XCTest. Diagnostic snapshots are emitted after the existing async wait returns, labeled `waitFinished` even for discard so a timed-out drain cannot be mislabeled completed. Failure cleanup still requests terminal discard and throws; no late success is inferred.

Both 10-second deadlines and all assertion lines are unchanged. No runtime, QoS, native algorithm, fixture, warmup or sleep changes. Existing runtime `completionQueued` and `completionDelivered` stages retain the queue handoff evidence. A post-wait snapshot is not a callback-time snapshot; its main-thread flag describes the emitting thread, not callback actor isolation.

This removes observer work from the completion critical path, but **does not establish the cause or fix of the eight observed timeouts**. In the seven ingress failures the result box was nil; printing after `box.put` alone cannot explain that. Direct-runtime first-query evidence showed workerStarted at11519ms, after discardRequested at10064ms. The new ingress timing marker was not exported by the prior CI whitelist, so its earlier stage receipts are unavailable. Preserve the fixed metadata-only marker in CI before interpreting the next run.

CALLBACK_REPAIR_RESULT.json pins the two changed test sources and records source-only checks. No native tests were executed for this repair locally. Previous SOURCE_RESULT.json and instrumentation.patch remain historical snapshots, not current-source pass claims.
