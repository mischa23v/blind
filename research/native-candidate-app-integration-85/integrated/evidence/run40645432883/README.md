# Native run 40645432883 — both builds pass, native suite remains red

Exact source: `26365197e71bb650e02e302ce292821d008dd9ce`. Existing push-triggered workflow, attempt 1. No rerun, new workflow, runtime activation or timeout change. Source hashes were independently fetched from the immutable commit.

- Both default and diagnostics-flag-only Simulator builds passed, including the photo-trash implementation and canonical project registration. This is compilation, not on-device Trash/recovery validation.
- BlindCore: **1,395 executed; one skipped; zero failures**. Exact source has ten new `NativeLocalizationEvidenceGateTests` methods, and the aggregate increased by ten from fee8. Individual new gate statuses are not emitted by the bounded Core log; do not represent the aggregate as a separately exported per-case receipt. BlindMemory: 51 executed, zero failures.
- Hosted: **157 unique cases; 145 passed, 6 failed, 6 skipped**. Both Combine publisher fixtures and the original I/O regression passed. Five ConnectedJourneyRuntime cases timed out waiting for state publication. The previously passing queued-scene-fence case failed again (worker/main drain expectations and subsequent state assertions). These remain actual failures; their cause is not established by this receipt.
- UI: **18 cases; 14 passed, 1 failed, 3 skipped**. Practice explicit End cancellation passed with **5.534 seconds** elapsed upper bound, below 90 seconds; full case 21.988 seconds. The unchanged production expiry is 120 seconds.
- Dynamic Type audit still fails, unsuppressed. Callback evidence remains incomplete: camera-after missing and Ask not observed. Exact navigation-reachability status is not separately exported.

The bounded hosted-case artifact was 5,432 bytes, its SHA-256 matched GitHub, sole member was allowlisted, ZIP CRC passed, all 157 identifiers were unique and counts/provenance matched. UI artifact was listed, not downloaded. Only bounded text evidence is published, no full job logs, photos, raw archives or signed download URLs.

This does not establish full native acceptance, real-device performance, live localization, safe physical routing or child-facing readiness. It does not overwrite the earlier fee8 result.
