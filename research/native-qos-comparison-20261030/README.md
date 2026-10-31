# Isolated native request QoS diagnostic — draft, not executed

Parent review required before publication or execution. No shared application files changed.
Base 08ebe14065cfb286c7a6d99fd53b7b377c2ad287. Source-only patch and copies; not compiled.

## Hypothesis and limits

Hosted e418 held-render native build: 38,217 ms wall / 68,678 µs thread CPU, valid pair; later same fixture family builds 147 ms /70,594 µs CPU. These do not prove throttling or QoS causality. Source queue/delivery delays also occur and are deliberately NOT changed here. No images, models, devices, motion authority or paid resources.

## Design

One isolated XCTest method; direct existing RoomMeshCandidateRuntime with classified 6×6m two-triangle synthetic floor, strict endpoint policy, fresh owner each arm; radius0.3m/height1.7m fixed. This is a small runtime scheduling comparator, not full ingress83/controller acceptance. Order fixed utility/userInitiated/userInitiated/utility; first cold arm retained. No retry, warmup or geometry change. Test source is absent unless both DEBUG and BLIND_QOS_COMPARISON compile flags apply.

Runtime override is DEBUG-only, inactive by default, configured explicitly before any offer/pending work. The isolated test additionally requires BLIND_QOS_COMPARISON. This avoids assuming app flags propagate into SwiftPM dependencies; normal Debug scheduling stays at the existing default unless this explicit diagnostic API is called. Release contains no override API. Request closure stays on the EXISTING single static serial native worker. Both arms use DispatchWorkItem flags .enforceQoS. The utility arm is an explicitly enforced experimental work item, not a byte-identical untreated measurement of the normal nil-override async call; do not treat it as a measured normal-app baseline. Queue serialization remains required by process-global native error text. Source acquisition, anchor application, result delivery and discard QoS are unchanged. Effective Darwin qos_class_self is sampled inside the native work item, not inferred from requested flags. Apple permits queues to affect work-item QoS; effective values and carry-over/order effects must be reported. The experiment cannot establish scheduling causality alone, especially if the actual QoS does not differ or source admission prevents query submission.

## Budget and failures

Each arm has original 10s source,10s query,10s normal drain deadlines. Every violation explicitly XCTFails and remains failed. Source failure skips query (does not manufacture a query success). Query refusal, missing/stale route or incomplete route fails. Next arm starts only after actual stopAndDiscard acknowledgment.

If normal drain times out, observe a DIFFERENT standalone expectation for at most45s. Eventual acknowledgment allows next arm but never removes original failure; lack of acknowledgment aborts the remaining arms. All expectations are standalone XCTestExpectation with explicit over-fulfillment checks, avoiding registered-but-unwaited testcase expectations.

Maximum sum of waits:4×(10+10+10+45)=300s. Propose additional60s synchronous/setup/reporting allowance, with lane process watchdog360s after the exact XCTest-start log marker is observed; watchdog expiry is an explicit incomplete failure, never a timing sample/pass. Build/setup outside this budget requires separately bounded free CI job allowance. No execution approved yet. The start marker is stdout-observed, not an exact execution clock: buffering/backlog can cause a launch-observation timeout. That is an incomplete diagnostic, not proof XCTest itself started late.

## Receipts

NATIVE_QOS_DEADLINE records each normal deadline verdict; NATIVE_QOS_LATE_DRAIN only eventual acknowledgment. NATIVE_QOS_ARM records requested/effective QoS, source/query/discard stages, worker/build/route wall+thread CPU pairs, original-vs-late drain result. Missing or mismatched CPU pairs are -1,false. NATIVE_QOS_SOURCE records source callback and process-relative arm offset. Logs have only fixed labels/synthetic timing, no captured geometry/identities.

Keep source and delivery delay in results. Do not pool invalid/missing/cold/retired samples into successful latency averages. A run missing an arm is incomplete, not a faster implementation. An isolated QoS result does not fix or pass existing seated/native fixtures.

## CI isolation proposal

Dedicated narrowly push-triggered diagnostic-only lane; compile the test with BLIND_QOS_COMPARISON in Debug, select only NativeQoSComparisonTests/testIsolatedUtilityUserInitiatedABBA, disable distributed/parallel tests. Do not put flag in default app project or normal acceptance lane. Root reviews test flag propagation and test discovery before running. Assert exactly one selected test and expected four arms or explicit abort. Preserve .xcresult/raw logs and all failures; diagnostic artifacts are NOT ordinary acceptance receipts.

Official API: https://developer.apple.com/documentation/dispatch/dispatchworkitem/init%28qos%3Aflags%3Ablock%3A%29

## Combined seated failure evidence export

This checkpoint also includes the independently reviewed three-file seated diagnostic exporter. It adds an always-run, bounded metadata export before the unchanged strict seated collector. Exact 18-case identities, source checks, original assertions, and acceptance rules are unchanged. Failure categories from separate origins are not summed; raw assertion text, photos, and geometry are not exported. These diagnostics cannot turn a failed test into a pass. The exporter has 51 portable controls; the unchanged strict collector has 53. Together with the 61 QoS controls, the combined packet has 165 portable controls, not Apple execution evidence.

All combined current inputs are restored through the same outer reversible layer before prior historical checks. The mapped-destination 21-case proposal is not included. Normal app behavior remains unchanged; the scheduling override requires explicit diagnostic opt-in.
