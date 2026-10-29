# Recovered terminal Apple evidence — 2026-10-29

Independent recovery from GitHub run/job APIs, decoded job logs and three downloaded artifact ZIPs; no CI rerun, install, build or test execution. These are historical results, not results for the current branch tip.

Source: `6d1a5d60511071e572ed586c7132af6f7805a869`.

| Run | Outcome |
|---|---|
| [Apple 40922810808](https://github.com/mischa23v/blind/actions/runs/40922810808) | completed, failure |
| [Package 40922810679](https://github.com/mischa23v/blind/actions/runs/40922810679) | completed, success |
| [Owned ingress 40922810652](https://github.com/mischa23v/blind/actions/runs/40922810652) | completed, success |
| [Historical fixed EDT 40922810789](https://github.com/mischa23v/blind/actions/runs/40922810789) | completed, failure before candidate execution: source pin mismatch for `research/room-mesh-package-75/BlindRoomMesh/Sources/CDetour/blind_detour_exclusion.cpp` |

## Exact Apple results

- Focused optional-policy hosted fixtures: **14 passed, 0 failed/skipped**, including **6 SeedRadiusEnvelopeAppleTests**. Artifact verifies source identity; this does not activate callers or grant physical authority.
- Full hosted suite: **297 cases = 280 passed + 15 failed + 2 skipped**. Recounted artifact identities agree with xcresult aggregate.
- UI suite: **18 cases = 14 passed + 1 failed + 3 skipped**. Two assertion failures belong to the single failed camera/Ask accessibility case; do not count these as two failed cases.
- Apple package steps and unsigned simulator build succeeded. Classified-mesh bench and diagnostics-compile jobs succeeded. Full hosted/UI steps failed. UI device identity and Practice runtime extraction steps also failed; they are not successful device evidence.

### Hosted failures retained

- **6 ClassificationIngressTests**: 10-second callback waits expire, followed by unavailable results.
- **1 RecordedRouteStoreTests**: 5-second snapshot wait expires.
- **3 saved-room route cases**: original-model body/margin contact or invalid-standing-start assertions. These remain failed proposed movements, not successful stops.
- **5 model-generation test identities**: conversation greeting, conversation scenarios, floor-clearance answer, saved-profile answer and unsupported-premise answers. Parameterized issues are not extra top-level test identities. Logs report model availability `available`, absent replies, and `generationFailed`. **Missing assets is an unverified causal lead**, not independently established by this recovered log.
- Exact failure and skip identities are retained in `hosted-case-statuses.json`.

### Ask audit

The callback artifact reports Dynamic Type partially unsupported for `local-answer-unavailable-reason`; the second unsupported-size issue has no available element snapshot. These are callback observations, not a historical failure-state reconstruction. Do not infer a fixed font or exact cause solely from the callbacks. Screenshots are not republished here.

## Minimal diagnostics repair proposal (not implemented)

1. In DEBUG-only `RoomMeshCandidateRuntime.recordDiagnosticStage`, capture monotonic wall time adjacent to the worker CPU sample **before entering the owner lock**. Append that captured scalar under the existing lock with the existing 64-record bound. Keep release behavior, callback scheduling, ownership and all safety policies unchanged. Current wall timestamp is sampled inside the lock while CPU is sampled before it; lock wait can distort the wall/CPU interpretation. Do not relabel the observed long wall times as proven native computation or proven starvation.
2. Preserve the existing opt-in `ASK_LAYOUT_TRACE` in `tools/ci/native-apple.sh` for UI mode on both success and failure. Use a closed grammar for schema, bounded sequence, numeric uptime/frame, known event/role/category and exact provenance; keep an explicit truncation marker and a bounded line/count budget. Do not print raw UI logs or arbitrary labels. Existing trace is DEBUG-only, requires `--ui-testing` plus `--ask-layout-trace`, and is capped at 64; UI setup supplies the flag, but current CI filters do not select its prefix. No trace was recovered in the job log; missing output is not proof the callback never ran.
3. Before any later authorized run, review the source-only diff and prepare fixture checks for valid/invalid trace lines, bounds, preserved exit status, and pre-lock timing sampling. Do not raise timeouts, skip failures, weaken contact assertions, activate optional policies or claim a runtime fix based on this diagnostics change.

## Provenance and limits

`artifact-hashes.json` records GitHub artifact IDs, SHA-256 digests independently matched to downloaded ZIP bytes, and member hashes. `diagnostic-source-hashes.json` hashes exact pinned source bytes. `focused-policy-statuses.json` retains receipt fixture/query hashes; `hosted-case-statuses.json` retains the query/source hashes. `runs.json`, `native-jobs.json` and `aggregate-log-excerpts.txt` retain bounded status evidence. No raw private paths, signed download URLs, environment dumps, model text, room geometry or screenshots are included.

All full-suite failures remain open. This evidence is not physical-iPhone validation, release readiness, safe movement authorization or evidence of independent use.
