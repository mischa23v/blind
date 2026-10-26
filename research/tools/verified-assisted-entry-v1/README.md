# Verified assisted entry; return remains unfinished

Stage51 demonstrates one controlled simulated entry:4.388010405m, full3D goalerror0.343921464m within frozen0.35m bound, stationary/drainedqueues. Same actor begins return, then stops on an untyped floor-support face. Total4.844523241m; no completed return. All371statesretain unresolvedlow-obstacle exposure. Manual evaluator-world sill/support assistance and zero-margin numericalbody are explicit. This is not autonomous phone navigation or human-safety validation.

Failedstage49protocolrun remains preserved. No completed result is retroactively attributed to it.

Archive SHA256: 875f2d08da1d904aeefd33e4621cc418481390a9af8cc8fe7de165de3e3e8642; 60 files plus manifest. Prior published checkpoints and hashed public raw inputs are required; this is not standalone.

## blind-known-riser-transition-49

# Stage49: entry-transition protocol failure, no complete saved journey

The bounded run advanced through the threshold and logged 4.256166 metres of committed movement at tick255. It subsequently entered the entry-arrival branch and attempted beginReturn, but the shared IPC validator rejected the acknowledgment because the historical controller omitted physicalAuthority:false. The strict boundary check was correct and was not disabled.

The process failed before serializing its terminal trajectory and result. Therefore this packet does NOT establish a fully verified entry arrival or return. Do not infer completed distance, zero-contact totals, or a successful journey from the progress log alone. The original frozen inputs, logs and failed execution receipt are retained. The run ended after183.28 wall seconds,185.02 CPU seconds and2.15GiB peak RSS, within its resource limits.

Stage51 is a separate protocol/reporting-only retry: restore the required explicit simulation-authority field in the return acknowledgment, retain the strict IPC validator, and flush each actual trace row to disk so an exception cannot discard completed positions. It must preserve the same geometry, source path, body, movement/support policy and collision guards. Stage49's 53 fixtures did not exercise the real subprocess beginReturn packet; the retry must add that regression.

This remains a manually assisted evaluator-world simulation, not automatic phone navigation or human-safety validation. See PROTOCOL.md, FROZEN.json and run-01/RUN_RECEIPT.json.


## blind-entry-return-protocol-retry-51

# Stage 51: assisted entry achieved; same-actor return incomplete

This is a controlled offline, manually assisted evaluator-world simulation, **not autonomous iPhone navigation or human safety validation**. The nominal body is 45 × 30 × 160 cm with zero horizontal margin. The horizontal source route, original reference triangles, support policy and motion policy are unchanged from stage 49. This retry fixes only the strict beginReturn acknowledgement contract and makes committed trace recording crash-preserving.

## Measured terminal result

| Measure | Result |
|---|---:|
| Entry arrival | Yes, tick 263 |
| Entry horizontal distance | 4.388010405 m |
| Entry full-3D goal error | 0.343921464 m (frozen 0.35 m arrival bound) |
| Entry stationary/drained controller and actuator queues | Yes |
| Same-actor return arrival | **No** |
| Total committed horizontal distance | 4.844523241 m |
| Total committed 3-D distance | 4.880940951 m |
| Recorded states | 371 |
| Executed body / margin / underbody contacts | 0 / 0 / 0 |
| Rejected predicted body / margin / underbody contacts | 0 / 0 / 0 |
| Largest actual 3-D substep | 0.020000008 m |
| Largest actual yaw substep | 1 degree |

After entry, the same actor moved along the frozen inside-room connector to the return-path start and began turning. It did **not** return through the doorway. No actor reset or teleport was used. Initial source-to-physics vertical settlement is separately recorded in `run-01/result/INITIAL_SETTLEMENT.json`.

The terminal status is `assistedStepRejected:unknown_mid_support`. All nine support rays hit geometry, but reference face **7253304** was not in the frozen gray-floor membership. Eight hits were gray floor and one was untyped; no ray was missing. Height-cap checks passed. This does not establish either that the face is a hazard or that it is harmless floor. Its classifier and source-image diagnosis is a separate post-run investigation; no frozen membership is changed here.

All 371 evaluated states retain unresolved low-obstacle exposure under the old phone-map diagnostic. Zero recorded contacts in this assisted run must not be reported as complete phone safety, a completed return, a completed table loop, or a successful human trial.

## Evidence and reproduction

- `FROZEN.json`: 507 pinned inputs, SHA-256 `30ab574ab49216c25b7b59eb60c1a4908eeb7c21016f27bdf82a5d641dfbe1b7`.
- `PROTOCOL.md`: complete declared policy and assistance boundary.
- `run-01/`: bounded-process resource receipt, logs and terminal result.
- `run-01/result/ACTUAL_TRACE_STREAM.csv`: flushed committed states, including initial settlement, preserved across exceptions.
- `run-01/result/ACTOR_TRACE.npz`: terminal exact trace.
- `postrun/ACTUAL_TRACE.csv`: exact original and registered-source coordinates with leg labels.
- `postrun/ACTUAL_SOURCE_MODEL_PATH.png`: **committed motion only** on registered original Polycam geometry. Orange is the return connector before the failed turn, not a completed return. No failed or proposed connector is drawn.
- `postrun/RECOUNT.json`: arithmetic, substep, macro-commit, goal and stream/trace consistency checks.
- `INDEPENDENT_RESULT_REVIEW.json`: independent reviewer recount and all input-pin verification.

The final source-model plot was visually inspected. Gray reconstructed geometry is not a free-space certification. 55 fixtures passed before freezing; independent review confirmed them. All 18 comparable progress records from failed stage 49 match the unchanged movement in stage 51. Stage 49 remains preserved as a protocol-failed run, not retrospectively credited with a terminal arrival.

Resource receipt: 274.719 seconds wall, 277.64 seconds CPU, peak sampled process-tree RSS 2,317,733,888 bytes; bounded run completed normally. The movement goal remains unfinished despite successful entry.


