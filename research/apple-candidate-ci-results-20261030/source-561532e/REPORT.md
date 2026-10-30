# Source `561532e`: terminal Apple CI addendum

**The full native job still failed.** At `561532e8dc302b190e3f34ab9546faf364e0905f`, the source-verified hosted suite had **287 passed / 8 failed / 2 skipped**, out of 297. The 11 classification callback cases that failed on `b55` passed again; this observation does not establish a single cause for the earlier failures. Seated controller tests remained **10 passed / 2 failed**, with **4 assertion failures**, before path submission.

This addendum is separate from the frozen `457`/`b55` report and receipts in the parent directory. It does not replace their failures or transfer later results backward.

## Exact terminal results

| Scope | Source `561` result |
|---|---|
| [Classified macOS fixtures](https://github.com/mischa23v/blind/actions/runs/41003352906/job/123894584687) | **65 passed / 0 failed**; exact collector passed; source clean before/after. Five iOS session fixtures remain excluded; Swift Testing's zero-test suite is not counted. |
| [Flag-only diagnostics / seated fixtures](https://github.com/mischa23v/blind/actions/runs/41003352906/job/123894584466) | Compile passed. **12 cases: 10 passed / 2 failed; 4 assertions**, command exit 65. Strict success receipt unavailable. |
| [Core / Memory / default app build](https://github.com/mischa23v/blind/actions/runs/41003352906/job/123894584882) | Core **1,463 total, 0 failures, 1 skipped**; Memory **58 passed**; unsigned Simulator build passed. |
| Same full job: hosted units | **297: 287 passed / 8 failed / 2 skipped.** Complete source-verified case/aggregate reconciliation succeeded; the suite did not. |
| Same full job: seed-radius / strict controls | **14 passed**, exact source-verified collector passed, command exit 0; diagnostic has zero assertion failures and zero unparsed failure records. |
| Same full job: UI / accessibility | **18: 14 passed / 1 failed / 3 skipped.** Two Dynamic Type assertions belong to one case: `LaunchTests/testAccessibilityAuditOfCameraAndAsk`. UI-device-identity and Practice-runtime evidence extraction also failed separately. |

All nine `ClassificationIngressTests`, five `ClassifiedRoomMeshTests` and eight `ObservedSceneRuntimeTests` cases passed in the complete hosted receipt. The remaining eight failed declarations are the same five model-response declarations and three saved-route/journey declarations retained from earlier runs:

- `ConversationTests/remembersNameWithoutRecitingHistory()`
- `TextChatScenarioTests/followsConversation(_:)`
- `TextChatScenarioTests/doesNotInventFloorClearance()`
- `SavedProfileConversationTests/suppliesNameWithoutOldHistory(corrected:)`
- `UnsupportedPremiseTests/repliesNeverAssertUnsupportedFacts(_:)`
- `SavedRoomRouteDiagnosticAppleTests/testPredeclaredApplePathsWaypointSinkAndIndependentFullBodySweeps()`
- `SavedRoomRouteDiagnosticAppleTests/testSeparatelyPreregistered28cmWidthDoesNotReplaceBaseline()`
- `SavedRoomRouteJourneyAppleTests/testPredeclaredSuppliedBedChairConnectorsAroundRoomDoorWithholdingAndReturn()`

The three saved-route/journey failures retain their original collision/standing-start assertions. Contacting candidates are failures, not successful safe stops. Parameterized model issues are not counted as additional failed declarations.

## Seated source/render timing — observation, not a root-cause proof

Each failing seated case has two assertions: its unchanged 10-second source-scene predicate wait expires, then a fail-fast `SCNScene` unwrap prevents subsequent path submission. The failing identities remain the happy declared-foot/historical-display case and the held-controller replacement/source-change case. The bounded tail retains eight passed and two failed identities; the twelve-case aggregate with no skips gives ten passed/two failed. It is not a complete strict success receipt.

The extractor scanned **608,497 bytes**, with no budget hit, rejected prefix or dropped valid record: **12 SOURCE + 4 PHASE + 0 WORKER records**. Repeated tail presentations are deduplicated in `LOG_RECEIPTS.json`.

| Recorded stage | Happy case | Replacement/source-change case |
|---|---:|---:|
| SOURCE request-relative native callback, success | 1,921 ms | 516 ms |
| SOURCE request-relative main/controller callback | 1,921 ms | 516 ms |
| SOURCE request-relative render enqueue / worker begin | 1,921 / 1,921 ms | 516 / 516 ms |
| Native owner-relative source enqueue | 10 ms | 0 ms |
| Native owner-relative source worker start / finish | 1,927 / 1,928 ms | 516 / 517 ms |
| Native owner-relative source delivery start / finish | 1,928 / 1,928 ms | 517 / 517 ms |
| Native owner-relative discard request / release | 13,123 / 14,841 ms | 10,037 / 11,966 ms |

SOURCE and native-stage columns use **different clock origins**; do not subtract across those clocks. No render-end or display-acceptance record was captured. Native source acquisition and delivery completed, and rendering began; the missing completion at the observation point narrows investigation to the subsequent render/display-dependent admission path. It does not prove the underlying cause of the missing render completion.

All query-submission/native-query-callback/main-held PHASE values remain **-1**. There are no path-worker records or valid CPU pairs, so no path-build speed, route-query speed or CPU-efficiency conclusion is supported. Missing measurements are unknown, not zero or success.

## Artifacts and later gate checkpoint

The terminal [source `561` native workflow](https://github.com/mischa23v/blind/actions/runs/41003352906) returned an **empty artifact list** at the 05:06 UTC read-only check. Its upload steps were skipped and log receipts report uploads disabled. This does **not** erase the separately recorded 16,630-byte room-mesh artifact from the same source checkpoint; see the parent report's storage exception. Stored bytes are not an observed monetary charge.

At the later gate-only commit `276b1c522bd5ff4ff26df23ba83a7728bdce3df9`, [room-mesh proof](https://github.com/mischa23v/blind/actions/runs/41004441091) and [owned ingress](https://github.com/mischa23v/blind/actions/runs/41004441011) completed successfully, each with an empty artifact list at 05:06 UTC. Thus the new room-mesh log-only/default-no-upload path has an observed successful checkpoint. The [native workflow](https://github.com/mischa23v/blind/actions/runs/41004440960) was still running: classified job succeeded; native and seated jobs were compiling. Its then-empty artifact list is only a snapshot, not a terminal outcome. The root publisher owns continued monitoring.

## Reproduce this addendum's bounded log receipt

The standalone parser reads exactly these three hash-pinned job logs, relative to `--input-root`. Other files, including the separately reported room-mesh/ingress logs, are not read. Original raw logs are not published here.

| Required path | Exact job ID |
|---|---:|
| `apple-candidate-561532e/classified-job.log` | `123894584687` |
| `apple-candidate-561532e/native-job.log` | `123894584882` |
| `apple-candidate-561532e/seated-job.log` | `123894584466` |

Retrieve job-log text from the linked jobs or `/repos/mischa23v/blind/actions/jobs/JOB_ID/logs`, preserving original bytes without encoding/newline normalization. All three fixed paths, byte sizes and SHA-256 hashes must match before parsing or output. Both CLI paths are required; failures preserve an existing output. Output replacement is atomic only after a complete bounded result exists.

```sh
python3 -B research/apple-candidate-ci-results-20261030/source-561532e/test_parse_logs.py
python3 -B research/apple-candidate-ci-results-20261030/source-561532e/parse_logs.py \
  --input-root /path/to/logs --output /tmp/apple561-reproduced.json
cmp /tmp/apple561-reproduced.json \
  research/apple-candidate-ci-results-20261030/source-561532e/LOG_RECEIPTS.json
```

Thirteen bounded stdlib reproducer tests passed. Actual saved logs reproduce **38,794 bytes**, SHA-256 `c9f27307552db05cc8239f53ba3b4f9f5232fb825e95091496161a09166f97f3`. `GITHUB_STATUS_0506.json` is a separate read-only API observation, not an output of the log parser. The original parent manifest/payload files remain unchanged.

No native execution, CI dispatch, artifact download/deletion or source publication was performed by this reporter. These synthetic/public-fixture and Simulator results do not establish live localization, wearer-foot calibration, physical collision-free guidance, phone performance/endurance or supervised safety acceptance.
