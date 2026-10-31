# Apple candidate evidence — 2026-10-30, terminal `457` / `b55`

**The isolated fixture repair worked, but the app runtime remains failing.** At `b55cf93428cc70f3b470a2a61e88a94044f19c2b`, classified macOS fixtures improved from 64/65 to **65/65 passed**. The flag-only seated controller class instead had **10 passed / 2 failed cases, with 9 assertion failures**. The full native job also finished **failed**. Compilation, synthetic host checks and Simulator execution are distinguished below; none establishes physical-device or child-safety acceptance.

## Exact source comparison

| Lane | First `457c3f33dae01b2f036d5a391f42aa444cd7d304` | Repair `b55cf93428cc70f3b470a2a61e88a94044f19c2b` |
|---|---|---|
| Classified macOS package | **64 passed / 1 failed case**, one assertion: the expected-source fixture could not unwrap its initially empty source snapshot. [Job](https://github.com/mischa23v/blind/actions/runs/40996828157/job/123871783536) | **65 passed / 0 failed**; exact collector passed. Five iOS session fixtures remain excluded. [Job](https://github.com/mischa23v/blind/actions/runs/41000267997/job/123883432485) |
| Flag-only compile / seated hosted class | Compile passed. **11 passed / 1 failed case**, two assertions: happy-path 10-second result timeout, then result unwrap. New retirement case passed on this revision. [Job](https://github.com/mischa23v/blind/actions/runs/40996828157/job/123871783531) | Compile passed. **10 passed / 2 failed cases**, nine assertions; exit 65; strict success collector unavailable. [Job](https://github.com/mischa23v/blind/actions/runs/41000267997/job/123883432048) |
| Core / Memory / default build | Core **1,463 total, 0 failures, 1 skipped**; Memory **58 passed**; unsigned Simulator build passed. | Core **1,463 total, 0 failures, 1 skipped**; Memory **58 passed**; unsigned Simulator build passed. |
| Full hosted unit suite | **297 cases: 286 passed / 9 failed / 2 skipped.** [Native job](https://github.com/mischa23v/blind/actions/runs/40996828157/job/123871783209) | **297 cases: 276 passed / 19 failed / 2 skipped.** Source-verified case/aggregate reconciliation passed, not the tests. [Native job](https://github.com/mischa23v/blind/actions/runs/41000267997/job/123883432346) |
| Focused seed-radius / strict controls | **14 passed**, exact collector passed. | **13 passed / 1 failed case**, two identified assertion failures; exit 65. Strict success collector unavailable; diagnostic also flags one unparsed failure record. |
| UI / accessibility | **18 cases: 14 passed / 1 failed / 3 skipped**, two Dynamic Type assertions in one audit case. | **18 cases: 14 passed / 1 failed / 3 skipped**, two Dynamic Type assertions in one audit case. |

First-revision [body-profile regression](https://github.com/mischa23v/blind/actions/runs/40996828227) and [owned mesh ingress integration](https://github.com/mischa23v/blind/actions/runs/40996828219) both completed successfully. Do not transfer those results to later revisions or promote them to full-suite success.

## Exact remaining blockers

- **Seated source admission:** `b55` happy-path case has five failed assertions: initial source predicate timeout, nil source/display state, result-wait timeout, missing submitted-start unwrap, and teardown-drain timeout. The retirement case has four: initial source predicate timeout, held-result timeout, missing result, and teardown-drain timeout. Nine assertions are **two failed cases**, not nine cases.
- **No path-worker speed conclusion:** the extractor scanned 607,039 bytes without cap hits, rejected records or output drops. It captured four PHASE records and zero WORKER records. Both wait-finished records have submission/callback/main times `-1` and empty stage lists; later records show only discard stages. No admitted path request, build/route-worker timing or valid CPU pair is evidenced. Source acquisition/delivery/render/controller admission remains under investigation; these logs do not isolate a definitive cause.
- **Broader `b55` hosted failures:** seven `ClassificationIngressTests` and four `ClassifiedRoomMeshTests` cases newly fail with 10-second callback waits and subsequent unavailable/unwrap errors. Five model-response case declarations and three original collision/standing-start route/journey cases remain failed. The previously failing observed-scene latency case passes on `b55`; its first-run failure, approximately 4.460 seconds versus the unchanged 1.2-second assertion, remains preserved. The 9→19 failed-case change is **11 newly failing identities and one previously failing identity now passing**, not proof of a single cause or source regression.
- **Seed-radius:** `SavedRoomStrictEndpointTests/testDefaultLegacyAndOptInStrictPreserveInsidePathAndVerticalAssociation` fails the 10-second native-result wait and result unwrap. `B55_SEED_RECEIPT.json` retains all 14 identities, the two parsed assertions, and the diagnostic's one unparsed failure record rather than silently declaring exhaustive assertion coverage.
- **Accessibility:** the failing case is `LaunchTests/testAccessibilityAuditOfCameraAndAsk`; two Dynamic Type assertions do not mean two failed cases. UI-device-identity and Practice-runtime evidence extraction also fail separately in both full jobs; these do not add test-case failures or erase the audit result.

Exact nonpassing identities are retained in `LOG_RECEIPTS.json`. First-run model failures include fourteen Swift Testing issues across parameterized inputs, not fourteen failed declarations. Repeated grep/tail presentations are deduplicated. For `b55` seated results, the bounded tail directly retains eight passed/two failed identities; the twelve-case aggregate with no skipped cases and the two failed identities gives the ten-pass/two-fail total. This is not a complete strict success receipt.

## Later focused source `561532e` — separate scope

At `561532e8dc302b190e3f34ab9546faf364e0905f`, the [room-mesh package proof](https://github.com/mischa23v/blind/actions/runs/41003352926/job/123892584491) passed **55 legacy, 32 runtime, 5 failure-commit and 19 discard checks**. These are separately named groups, not a newly summed count of independent tests. The macOS package/imported client executed; the Simulator package/client only compiled and linked. The default SwiftBuild backend, app project, ARKit execution and physical authority remain unproved/false in that receipt.

The [owned-ingress proof](https://github.com/mischa23v/blind/actions/runs/41003352916/job/123892584122) passed **83 original synthetic runtime checks plus 25 strict caller-policy checks**, with actual ARKit-boundary Simulator compilation. It did not execute the Simulator/device, activate the app or measure copy latency. Full native results for this later source are not included here.

## Storage exception and provenance

The three first-revision workflows and the terminal `b55` native workflow returned **empty artifact lists**, verified read-only. Their bounded job receipts report uploads disabled.

**The newly triggered `561` room-mesh workflow did upload one artifact:** `12954566763`, `candidate-room-mesh-75-receipts`, **16,630 bytes**, created 04:32:46 UTC and expiring 2026-11-02 04:32:44 UTC. This workflow was outside the original three gated workflows. Stored bytes are **not an observed monetary charge**. The artifact was neither downloaded nor deleted; its original expiry is unchanged. `561` ingress has no artifacts. Do not claim all `561` workflows had zero storage. The root-authorized room-mesh upload gate and bounded log-only receipts were subsequently published at [`276b1c522bd5ff4ff26df23ba83a7728bdce3df9`](https://github.com/mischa23v/blind/commit/276b1c522bd5ff4ff26df23ba83a7728bdce3df9), with remote source/tree verified by the publisher. This does not retroactively remove the existing artifact or establish the result of a later run.

Evidence files preserve bounded source receipts, exact links, six original log hashes, all nonpassing case identities, timing records and artifact metadata: `LOG_RECEIPTS.json`, `B55_SEED_RECEIPT.json`, `FOCUSED_561_RECEIPTS.json`, and the timestamped API snapshots. `parse_logs.py` reads existing public/synthetic logs only. No private imagery is included. These results do not establish live localization, wearer-foot calibration, physical collision-free guidance, phone performance/endurance or supervised safety acceptance.

## Reproduce the six-log receipt (no CI execution)

`parse_logs.py` requires explicit `--input-root` and `--output`. It validates exactly six expected filenames, pinned byte lengths and SHA-256 hashes before parsing, and only atomically replaces the explicitly named output after a complete bounded result exists. Missing, extra, altered or nonregular/symlink log inputs fail without touching the output. It has no default destination and does not fetch logs or run tests/builds.

Obtain the **job-log text**, not an artifact bundle, from each linked GitHub job or its authenticated `/repos/mischa23v/blind/actions/jobs/JOB_ID/logs` API endpoint. Save the original bytes without newline/BOM/encoding normalization under this layout (paths relative to the selected input root):

| Required relative path | Exact job ID | Run / job link |
|---|---:|---|
| `apple-candidate-457c3f3/classified-job.log` | `123871783536` | [GitHub job](https://github.com/mischa23v/blind/actions/runs/40996828157/job/123871783536) |
| `apple-candidate-457c3f3/native-job.log` | `123871783209` | [GitHub job](https://github.com/mischa23v/blind/actions/runs/40996828157/job/123871783209) |
| `apple-candidate-457c3f3/seated-job.log` | `123871783531` | [GitHub job](https://github.com/mischa23v/blind/actions/runs/40996828157/job/123871783531) |
| `apple-candidate-b55cf93/classified-job.log` | `123883432485` | [GitHub job](https://github.com/mischa23v/blind/actions/runs/41000267997/job/123883432485) |
| `apple-candidate-b55cf93/native-job.log` | `123883432346` | [GitHub job](https://github.com/mischa23v/blind/actions/runs/41000267997/job/123883432346) |
| `apple-candidate-b55cf93/seated-job.log` | `123883432048` | [GitHub job](https://github.com/mischa23v/blind/actions/runs/41000267997/job/123883432048) |

The exact six input lengths/hashes are pinned in `parse_logs.py` and repeated in `LOG_RECEIPTS.json`. If a later GitHub download differs in wrapper/encoding, the reproducer intentionally refuses it; do not normalize silently or replace the historical pins to manufacture agreement. Original raw logs are not included in this published packet.

From the repository root, after arranging these six files under `/path/to/logs`:

```sh
python3 -B research/apple-candidate-ci-results-20261030/test_parse_logs.py
python3 -B research/apple-candidate-ci-results-20261030/parse_logs.py \
  --input-root /path/to/logs --output /tmp/apple-ci-reproduced.json
cmp /tmp/apple-ci-reproduced.json \
  research/apple-candidate-ci-results-20261030/LOG_RECEIPTS.json
```

The original saved inputs reproduced the published receipt byte-for-byte: **65,668 bytes**, SHA-256 `2cdb62cb71d29bdbace26d45bb782dd555aa2e288536a7718c830ffe33063963`, six jobs. The separate seed diagnostic, later focused proof receipts and API snapshots are preserved observations, not additional outputs of this six-log parser. Thirteen stdlib-only reproducer regression tests passed; missing/hash-altered checks cover each of the six inputs and preserve an existing output. No native or CI execution was performed by this reproducer.
