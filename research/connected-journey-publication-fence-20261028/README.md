# Connected journey publication waits: first failure and completion-fence proposal

**Status: reviewed patch applied to the two owned canonical Swift files after parent coordination, 2026-10-28. Native validation remains pending.**
No Swift compiler is available locally. No new native workflow, rerun, installation or GitHub push was performed by this investigation. The parent owns integration/publication. Native validation remains pending.

## Preserved failure, not a successful rerun

Exact existing GitHub Actions run **40644081432**, job **122668728565**, commit **fee8c7da4e85cb279d93cdedf881b4f016b384ad** failed both cases:

- `testAutomaticRecoveryKeepsCurrentConservativeRestrictions`
- `testDeleteRestartCannotReimportSameRevisionAndForgetRestrictions`

`fee8-first-failure-traces.txt` preserves the existing job's bounded metadata-only failure sections. They contain synthetic fixture test names, operation IDs, phase timestamps and queue counts, not private map or camera data. The existing parent evidence directory retains overall run/case results. `BASELINE.json` records local source hashes; these hashes are not independently fetched remote-source provenance.

## What the trace establishes

The first failure occurs during **fixture setup**, before the conservative-restriction scenario:

| First empty restore phase | Uptime seconds |
|---|---:|
| Detached job queued | 858.035625625 |
| Detached job starts | 861.948612083 |
| Detached job ends | 861.948777167 |
| Main owner resumes | 861.950451625 |
| `onChange` fulfills condition | 861.965325958 |

Worker admission takes **3.912986 seconds**; actual empty restore work takes **0.000165 seconds**. The unchanged three-second XCTest expectation has already failed. The helper subsequently returns after 12.464798 seconds with the condition fulfilled. Its eventual fulfillment does not undo the failure.

The second failure is also fixture setup, at `installed()`'s catalog wait. The outer main-owner task enters at 893.348175833 and queues its detached catalog at 893.348184583. There is **no detached-begin event before teardown**. At return after 4.778082 seconds, `maps=2`, `writes=0`, `publications=0`. The retained trace reports no buffer drops; post-teardown work is deliberately uncaptured.

These observations locate delay before detached work begins. They **do not prove why the host scheduler delayed that work**, a permanent deadlock, lost callback, map-validation bug or production latency guarantee. They do not justify changing floor mapping, priority or map policy. The first callback did arrive; the second worker had not yet reached any callback publication step.

## Proposed narrow change

`PROPOSED.patch` adds DEBUG-only completion observation to the real `ConnectedJourneyRuntime` outer restore, catalog and write tasks. It does not replace an executor, bypass map validation or synthesize results.

The test seam awaits the **outer task**, not merely `io.write()` or detached validation. Thus the fence includes main-owner publication. It then drains successor catalog/write tasks already scheduled by completion. Handles are keyed by the actual operation ID; missing/mismatched handles or a completed task leaving its same ID active throw instead of being retried. Completed handles are not cleared by old task defers, so an old completion cannot erase its successor handle. Storage is bounded to three handles.

Only shared `installed()` fixture setup and the two affected functional scenarios switch to the explicit completion helper. The helper asserts idle state, no storage error and durability. All original domain assertions and test names are retained. The existing three-second `until` helper is byte-identical, as are the held-IO/cancellation scenarios. Existing suite/job hang ceilings are not changed.

**This separates functional completion from a host-scheduling deadline. It does not make the historical three-second latency failure pass, and it is not proof that application responsiveness is acceptable.** Keep that result as failed/unresolved latency evidence. Do not use the fence while intentionally held IO is unreleased. Do not blanket-replace every condition waiter.

## Local checks / acceptance still required

`python3 research/connected-journey-publication-fence-20261028/check_proposal.py` records 17 portable source/provenance checks. `git apply --check .../PROPOSED.patch` succeeds against the recorded local baseline. These checks establish patch scope and preserved evidence, not Swift execution.

Independent review and parent ownership coordination completed. Exact preimages are retained as `.swift.before` files and match `BASELINE.json`. The applied source matches the reviewed `.swift.proposed` files byte-for-byte. Nineteen applied portable source/provenance checks and twelve existing Node structural regressions passed. Use the next already-authorized native branch CI to compile and exercise the actual two cases, all existing runtime cases, DEBUG/release boundaries and successor-drain behavior. Preserve its first result regardless of outcome. No retries or timeout increases are part of this proposal.

## Later pre-patch native result: 2636519

Run **40645432883** tests the earlier 2636519 source, not this applied fence. Its preserved evidence is in `../native-candidate-app-integration-85/integrated/evidence/run40645432883/`. It reports five ConnectedJourney publication-wait failures: CancelIsSynchronous, DeleteWhileRestore, DormantNativeRuntime, FailedSaveNewCommand, and IntegratedAutomaticRecovery. The first bounded trace shows Cancel failing during installed() restore setup (worker admission 3.081149s), then its actual blocked-writer/cancellation scenario completes. DeleteWhileRestore and Dormant traces stop after detached restore admission was queued, without a begin event before timeout. The last two failure windows were omitted by the existing three-window extractor cap; do not invent phase diagnoses for them.

The newer run also fails a separate ObservedScene queued-fence case. That source is outside this patch. The original three-second helper and held-IO test bodies remain untouched; this narrow change is not a claim that all newer failures are solved. No latency improvement is claimed.
