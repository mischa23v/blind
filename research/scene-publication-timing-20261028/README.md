# DEBUG scene publication timing — separate follow-on

Status: applied source candidate after the prior completion-fence stage was published as `adb8fd8f4fa16f0563bdd708635a12ba7888bcf3`. This stage does not rewrite the earlier evidence or claim faster processing. Native compilation/execution remains pending. Root owns publication; this agent launched no native workflow or rerun.

## What is measured

Each admitted DEBUG work receipt owns a fixed four-slot, lock-protected monotonic timing buffer:

1. Admission: after the existing admission checks and work ID assignment.
2. Worker start: first instrumentation point inside the actual serial queue closure.
3. Worker finish: after the real accumulator and plan computations, before main enqueue.
4. Main delivery: first instrumentation point inside the actual main callback, before stale-generation rejection/publication.

The goal/body/fresh fixtures capture separate immutable numeric snapshots immediately after each exact completion fence. Strings are formatted and printed **only after the total elapsed time is captured**, and only when the unchanged **1.2-second latency assertion fails**. No stdout, actor hop or unbounded history is introduced in worker/main callbacks. No positions, photos, maps, body parameters or raw observations enter these records: only synthetic job UUIDs and monotonic times.

### Attribution limits

- `queueAdmission` includes deliberate test queue suspension, enqueue/setup overhead and scheduling. It is **not pure scheduler latency**.
- `workerWall` is elapsed wall time across accumulator and planning work. It includes preemption and is **not a CPU-time measurement**.
- `mainHandoff` includes enqueue overhead and main scheduling, ending at callback entry. It is **not pure main-queue wait**, nor the time taken by all publication callbacks.
- Instrumentation itself costs timestamp reads, locks and small numeric snapshots. Avoidable string formatting and logging are outside the measured interval, but this is not observer-free performance measurement.

A failed latency result must remain a failure. The records support locating delay, not bypassing freshness, changing QoS, increasing a budget or declaring acceptable device latency.

## Bounded existing-CI extraction

The existing `tools/ci/native-apple.sh` unit-failure branch previously extracted ConnectedJourney traces only. This stage adds three lines to preserve exact `OBSERVED_SCENE_FENCE_PHASE`/`OBSERVED_SCENE_FENCE_LATENCY` prefixes, at most eight lines and 1,500 characters each, plus begin/end markers. No build/test command, workflow, native scope or exit status changes. Empty grep output does not abort the remaining failure report.

`check_extraction.py` executes **only that extraction fragment** on synthetic text. It checks line/character bounds, excludes unrelated/private/model prefixes, preserves status 65 and handles no matches. It does not run Apple CI.

## Checks and review

- 18 source/provenance checks pass; release runtime text is byte-identical after DEBUG removal.
- Nine existing observed-scene Node structural checks pass.
- Six extraction-fragment checks pass; `bash -n tools/ci/native-apple.sh` passes.
- Independent reviewer `/root/review_recorded_route_preview` approved the numeric-snapshot improvement and found no source-level concurrency/privacy blocker. Mutable timestamp slots are always locked; immutable snapshots are Sendable. Native Swift remains required. Final helper review also confirmed exactly three bounded extraction lines, no workflow/build changes and no source blocker; actual CI delivery remains unverified.
- Exact preimages and the initial Swift-only proposal are preserved. `APPLIED.patch` includes the final three-file change, including helper extraction.
