# Classification fixture-owned failure cleanup — isolated source candidate

## Actual failure, not a scheduling diagnosis

The [799 native job](https://github.com/mischa23v/blind/actions/runs/41025141290/job/123961371959) failed five ClassificationIngress callback cases at their original10-second deadline and the first RecordedRouteStore active-trip snapshot at5seconds. The bounded matching-query records show five waits beyond10seconds without completion delivery: two have not reached workerStarted; others are still in native work. The recorder read marker has not started. Method names are **not assigned to random query/runtime IDs by presumed ordering**. Clock scopes and exact extracted-log hashes are in OBSERVATIONS.json.

Classification uses asynchronous XCTest fulfillment, and neither fixture is MainActor-isolated. There is no demonstrated actor-waiter deadlock. Long native wall time versus low measured same-thread CPU does not identify a QoS cause. Recorder already stops/drains before reopening and retains storage if cleanup fails; it is unchanged here. Its queued read can also be behind an earlier offer/database load, which these records do not distinguish.

## Demonstrated ownership gap and narrow repair

On a thrown/timeout query, the test body skips its awaited discard; `defer { owner.stopAndDiscard {} }` requests a fence without awaiting actual native drain. Native75 serializes native work across owners. The candidate registers an asynchronous XCTest teardown immediately after each owner is constructed, so failure paths also await the existing discard helper. [Apple documents that registered teardown blocks run after passed or failed methods and can await async code](https://developer.apple.com/documentation/xctest/set-up-and-tear-down-state-in-your-tests). Crashed test processes remain outside that guarantee.

The cleanup wait creates a fresh standalone XCTestExpectation, enables overfulfill detection and retains the original10-second discard bound. Only the real discard callback marks the owner acknowledged; it is not inferred from `stop`, a callback timeout, or an elapsed timer. Already acknowledged success cleanup is not repeated. The original query helper and all nine existing test bodies are byte-for-byte unchanged, including every functional assertion and10-second query deadline. A late callback cannot turn the original failure into success.

A tiny locked **test-only** admission lease persists across this XCTest family’s case instances. If teardown itself times out, the next Classification owner fails admission until the earlier exact callback releases its token; it never borrows unfinished work, retries a query, or silently skips a test. A foreign, duplicate or old token cannot release a newer lease. Constructor failure releases only its reservation, before any geometry/query is admitted. This does not fence unrelated runtime callers or other XCTest families and is not a runtime scheduler change.

One additional Swift gate test is authored (not executed). Portable controls preserve all nine old methods and the whole query helper by hash, check25 source contracts and reject12 source mutations. These are source controls, **not Swift compilation or native success**. Original worker-delay failures remain open.

## Integration and zero-storage scope

Keep separate from the frozen74-file implementation batch. The fixture already belongs to the full hosted unit target; focused seated21 and classified71 identities do not change. Adoption requires a new additive reverse layer plus updates to current integrated/bench input pins; do not overwrite earlier failed evidence or historical layers. No production source, QoS, deadlines, runner, workflow or dependency is changed.

Only native-apple's three jobs match this packet on the review branch. Their existing public-repository guards and standard xcode-27 runner remain, and artifact uploads default off. No new service, cache, private payload or external capture is introduced. Root alone reviews, integrates and publishes; this packet has not run natively.
