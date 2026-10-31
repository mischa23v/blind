# Exact c210ca8 native stall: source-only diagnosis

2026-10-29. Source inspected with `git show c210ca8:<path>`, not inferred from current HEAD. Run 40948350087 attempt 1, native job 123709537027. No implementation changes, execution, build, install, rerun or publication. Existing **297 hosted cases / 283 passed / 12 failed / 2 skipped** remain unchanged (4 ingress, 5 model/conversation, 3 route-contact failures).

## Finding

**The initiating long build's cause is still unknown. Two subsequent requests demonstrably timed out before entering the shared worker.** This is more specific than “scheduler”: source and metadata show a backlog mechanism, but do not identify why an executing native build spent tens of seconds with little thread CPU. No evidence justifies QoS changes, larger timeouts, skips or asset-based attribution for these mesh stalls.

Read-only GitHub job-log retrieval recovered the bounded ingress marker block missing from the prior local selection. `ingress-timeout-correlation.json` retains only four query submit/wait pairs and four failure-duration lines. The outer GitHub timestamps are extraction time; they are **not event timestamps**. Runtime clocks are owner-relative, not comparable across owners without additional clock-origin metadata.

| Runtime prefix | State at waitFinished | Final worker evidence |
|---|---|---|
| 24D2229F | query waited 23,043 ms; requestEnqueued=2, workerStarted/nativeBuildBegin=4,363 | worker 36,041 ms / 64,935 us CPU; build 34,775 ms / 64,324 us; route 1,266 ms / 496 us; retired, no native failure |
| 8481FCAB | query waited 10,311 ms; requestEnqueued=212 only | worker starts at owner 17,311 ms, retires in 0 ms; no build |
| B678958B | query waited 10,053 ms; requestEnqueued=0 only | worker starts at owner 10,916 ms, retires in 0 ms; no build |
| 206898B1 | query waited 10,068 ms; requestEnqueued=0, workerStarted/nativeBuildBegin=834 | worker 15,464 ms / 55,304 us CPU; build 15,464 ms / 54,960 us; retires, no native failure |

The four failure durations are 23.094, 10.325, 10.301, 10.098 seconds, respectively for floor, legacy, non-floor, table tests. Their order and durations support matching the above rows in that order, **but markers do not explicitly carry test identity**, so the identity join is an inference, not a new verified key. Stage-level conclusions do not depend on that join. A nominal 10-second XCTest wait returning after 23 seconds also shows delay outside native work; it does not identify an OS cause.

## Exact execution path and boundaries

`RoomMeshCandidate.swift:190–203, 603–711` defines one static serial utility `blind.room-mesh.native` queue shared by runtime owners. `request` performs ingress validation/admission, queues a closure, checks lifecycle/owner and snapshots delivery metadata, then calls `owner.geometry` **before** nativeBuildBegin. Queue wait and this preparation cannot explain the measured build interval.

Between nativeBuildBegin and nativeBuildEnd (`:651–655`):

1. Evaluate `owner.geometrySupport(excluding:)` (`Bridge.swift:78–83`): sorted retained tiles, validate support count, append scalar roles. No actor, callback or wait.
2. `Native.init` (`Bridge.swift:137–213`): validate counts/finiteness/indexes, convert Double to Float, construct support bytes/config, enter buffer-pointer closures. Exclusion is nil on this request path.
3. Dispatch synchronously to `bn_build_classified` or `bn_build` for these ingress fixtures. Their owner constructor leaves seed-radius policy stock. General runtime optional branches can call classified seed-radius or envelope adapters; exclusion builds exist in Native but are not selected here.
4. All four C entry points delegate to `build_impl` in `Sources/CDetour/blind_detour_exclusion.cpp` (compiled via `clearance_adapter.cpp`): validate; initialize config/bounds/grid; allocate heightfield/compact/contours/poly/detail; create heightfield; classify walkability; rasterize; remap support; ledge/headroom filters; compact heightfield; optional exclusion; optional seed preparation; erosion; optional seed application; distance field; regions; contours; polygon mesh; detail mesh; create Detour data; allocate/init mesh and query; return handle. Stock ingress does not execute seed/envelope preparation/application or exclusions.
5. Local C BuildData/vector destructors free temporary build storage before return. Swift receives handle and sets nil optional receipts. Native handle destruction is later, outside the successful build interval.

Thrown Swift/native-refusal paths go to nativeFailure and have no nativeBuildEnd. Both long build pairs returned a handle, completed a route, then failed currentness after timeout/discard, explaining `retired=true` without `native_failed=true`. End-stage CPU/wall samples are taken before that stage's diagnostic lock; the begin lock wait is in the build interval. Measured ingress diagnostic-lock waits max 20 us cannot explain these intervals. Other uninstrumented runtime/library/allocator waits are not thereby ruled out.

## Blocking hypotheses checked

- **Deliberate test blocking:** hosted ClassificationIngressTests has no semaphore/sleep/native-worker injection. Its `queue.sync {}` drains each private decoder before query; XCTest `await fulfillment` waits for callback, not inside Native. The separate standalone/package fixtures do contain intentional worker/decoder semaphore gates (room-mesh-package-75/tests, mesh-candidate-ingress-83/tests, live-mesh-classified-bench tests), but are not the ingress library Sources target and are not imported as hosted test sources. Their existence is not evidence a gate ran in this process/build interval.
- **Undrained cross-test work:** confirmed available mechanism. Query timeout calls `owner.stopAndDiscard {}` then throws; test defer also requests discard without waiting. Normal success calls awaited discard. Stop fences but cannot cancel a synchronous C call already executing. Shared-worker jobs retain owners until return. Consequently subsequent tests can enqueue behind a previous timed-out build; the two no-build retired records directly prove delayed queued requests. Exact predecessor identity is not carried by the bounded markers, so do not claim an absolute cross-owner timeline.
- **Main-thread synchronization / actors / ModelIO:** no such hop appears in this build call graph, nor an application resource lease. Ingress runtime completion is dispatched globally at utility QoS, then locks ingress, constructs result and calls the test callback off-lock. It does not require main queue. `main_thread=false` in marker lines alone is not actor proof. Other hosted tests use ModelIO and gates, but those are not calls made by this build path.
- **Native allocator/test hook:** Recast/Detour default allocators are malloc/free; custom allocator setter calls found in separate standalone C++ allocation-failure fixtures, not this hosted ingress path. Build's rcContext(false) disables its logging/timing hooks. Source contains no explicit native mutex/semaphore/sleep/thread dispatch in this path. System allocation, page faults, runtime contention, process suspension or scheduling remain unmeasured possibilities, not established diagnoses.

## Minimum next evidence, not a fix

For one separately authorized Apple diagnostic execution, preserve unchanged assertions/timeouts and add only synthetic, bounded, opt-in scalar diagnostics:

1. A process-relative monotonic origin plus request sequence, fixed fixture/test code, and shared-worker job sequence for offer/query/discard start/end. This yields an exact timeout→outstanding-job→next-test join and drain acknowledgement without geometry/session IDs. Keep owner/query IDs and thread identity.
2. Split build into support packing, Swift conversion, C entry, heightfield/rasterize/filter/compact, erosion/distance/regions/contours/poly/detail, Detour creation and temporary cleanup/return, each with wall + current-thread CPU begin/end. Store fixed-size records in memory; publish after job return on existing bounded diagnostic queue. No stdout or locks inside timed inner loops. Mark failures and truncation explicitly; retain defaults/stock policy.
3. If wall/CPU separation recurs, capture a bounded native worker thread stack **during the stall** plus OS thread-state/wait reason (approved profiler/sample). Phase clocks alone locate delay but cannot distinguish suspension from allocator/runtime/kernel waits. Record runner/process resource observations separately; do not equate low CPU with scheduler starvation.

No native run was authorized here. Existing job exposes extracted bounded logs, not live worker stacks or a complete source-time test/job timeline. That is the causal-evidence blocker. Read-only GitHub retrieval supplied the bounded log evidence.
