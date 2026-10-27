# Native Apple verification at 8c264cf

[Run 40575978143](https://github.com/mischa23v/blind/actions/runs/40575978143) completed with failures at commit `8c264cfe9b641918c813405ef2b27771f56a944f`.

## Exact original import regression: passed

The new bounded exporter executed on Apple. It verified actual HEAD, clean tracked sources, scoped untracked files, and both generated exact GRDB 7.11.1 locks. All 155 case records reconcile with aggregate xcresult counts. `IndoorGoalContinuityTests/testTrackingLossStillInvalidatesRetainedMapFrame()` has exactly one Passed record and the full unit log contains its exact started→passed sequence. Its test source remains SHA-256 `24930b5106810a9a6929e08243ce4164cb0cb40693259e5e93a788cc593cf7b6`; the foreground SpatialMapIO candidate remains `f044ff2aa869cf0ea3ab8a2ff8d4c6ba7fc7fcd9915fe1fed59109219a3c548c`. Assertions and original deadline were unchanged. This is one native regression pass, not proof of device latency or that every queue stall is fixed.

## Remaining failures and unavailable coverage

Core: 1,385 total, 1 skipped, 0 failures. Memory: 51 passed. Default Simulator build passed. Hosted units: 155 total, 148 passed, 1 failed, 6 skipped. The simulator reports modelNotReady this run, so existing model-availability gates skip their integrations; this is not new model acceptance and does not erase the prior run's asset failures.

The one failed declaration is `ObservedSceneRuntimeTests.testGoalAndBodyChangesFenceQueuedPlansWithoutRetiringScene`: snapshot nil at line 84 and status waitingForBodyObservation rather than bodyEnvelopeUnavailable at line 85, after 10.619 seconds. Source inspection shows its sole final observation can be dropped while older work retains the bounded worker slot; fixed 100 ms sleeps do not establish drain. Alternatively the final admitted completion could arrive late. The current log does not distinguish those causes. No scene threshold, timeout or assertion was changed, and the failure was not retried away.

UI: 17 total, 13 passed, 1 failed, 3 skipped. The unchanged unsuppressed Dynamic Type audit flags the Practice footer (raw 65536). Camera-after/Ask evidence remains absent because the audit threw.

## Integrity and limits

Both unit-status and synthetic UI artifact ZIPs were checked against GitHub-provided sizes/SHA-256 and ZIP CRC. The unit artifact was independently recounted and its source hashes checked. See ARTIFACT_RECEIPT.json. Full logs/ZIPs/screenshots remain preserved locally; this compact publication retains the complete 155-case status file, summaries and relevant failure evidence. No real sensor or child-safety claim follows.
