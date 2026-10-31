# Native run 40644081432 — practice fix verified; suite remains red

Exact source: `fee8c7da4e85cb279d93cdedf881b4f016b384ad`. Existing push-triggered workflow, attempt 1. No rerun, new workflow, device activation or timeout widening. Immutable source hashes are recorded separately, avoiding newer local edits.

- Both default and diagnostics-flag-only Simulator builds passed.
- BlindCore: 1,385 executed, one skipped, zero failures. BlindMemory: 51 executed, zero failures.
- Hosted units: **157 unique cases; 149 passed, 2 failed, 6 skipped**. Both new Combine publisher-semantics fixtures passed. These use small fixtures, not direct NavigationModel notification measurements. The original map-I/O and queued scene-fence regressions passed.
- The two failed ConnectedJourneyRuntime cases expired their 3-second state-publication expectations. This is an unresolved regression/flakiness question, not classified as harmless timing. Exact cases and diagnostics are retained.
- UI: **18 cases; 14 passed, 1 failed, 3 skipped**. Practice cancellation explicitly tapped End and verified postconditions within **41.978 seconds**, below the frozen 90-second evidence limit and unchanged 120-second production expiry. Full case took 71.872 seconds. This establishes the tested interaction on this Simulator run, not a general latency guarantee or isolated root cause for the combined source changes.
- Dynamic Type audit remains failed and unsuppressed. Callback evidence is incomplete (camera-after missing; Ask not reached).
- The separate practice navigation-reachability case has no exact exported status; its pass is not independently claimed from aggregate totals.

`unit-case-statuses.json` came from the 5,423-byte ZIP whose SHA-256 matched GitHub, whose sole member was allowlisted, and whose CRC passed. Cases, counts and source provenance were checked. The 426,485-byte UI artifact was listed, not downloaded. Only bounded text evidence is included here; no full logs, photos, archive or signed download URL is published.

This is not full native acceptance, on-device accessibility validation, live navigation or child-safety evidence. The newer 2636519 run is separate and cannot retroactively change these results.
