# Durable local recording candidate — 2026-10-28

Follows reachable source checkpoint `26bfa69e8fb7a9f32df6d4c581477d91e95dfaed`. Implemented source and independently reviewed; **Swift compilation, GRDB execution and device/UI validation are still pending**.

## What changed

- Existing `RecordedRouteRepository` now has a forward `private-navigation-test-v1` migration in the same private `RecordedRoutes/routes.sqlite` database. No new database, cloud service, model or camera session.
- Typed Core events retain every admitted diagnostic sample's original transform, capture/receipt times, tracking, source session/frame, route association and plan/goal/body/obstacle/artifact provenance. Marker order and lifecycle events are retained.
- Store writes bounded batches of at most 64 events on its existing utility queue. Camera extraction and hazard delivery do not perform SQLite writes or whole-archive rewrites. Active writes are batched at 25 events or five seconds when the queue/snapshot is serviced; markers, plan changes and stop request a flush. These are implementation bounds, **not measured durability latency or device-performance guarantees**.
- Start opts into local diagnostic saving. A previously open recording cannot be silently replaced. Close is allowed only after saving finishes; explicit Delete can discard a recording and its unsaved tail.
- A failed append stops diagnostics and keeps its unsaved events in memory, with explicit saved/pending counts and Retry. No dropped tail is called saved. App termination can lose uncommitted events.
- Reopen validates bounded pages, contiguous sequences, typed event invariants and stored terminal state. It reconstructs only the committed prefix as historical, stopped evidence. An interrupted prefix has no invented stop time. It cannot resume recording or acquire guidance authority.
- Store generation fences, repository trip/erase epochs and serial deletion prevent pending writes from recreating erased diagnostics. Normal breadcrumb quota retirement does not delete saved diagnostic samples.

## Bounds and retention

Existing diagnostic sample/plan/marker/route-point limits remain. Added caps: three retained sessions, 16 MiB accounted payload per session and 32 MiB total; at most 3,257 events including terminal state, with a 262,144-byte maximum encoded event. Metadata has schema version 1. Repository accounting charges at least 256 bytes per event.

**These are configured accounted-payload limits, not exact physical SQLite/WAL file-size ceilings or validated ideal defaults.** SQLite metadata, journal and free-page overhead are additional. No automatic eviction: when full, the user explicitly deletes an older recording before retrying or starting another. Logical deletion is not a forensic overwrite claim.

## Actual screen controls

The existing RoomDetail → NavigationModel bridge entry point is retained. The diagnostic view now provides:

- Start, Stop, committed/pending status and failure Retry.
- Close saved recording without deleting it.
- A local saved-session list, refresh, historical Open and explicit Delete.
- Typed problem markers and the existing raw-source versus exact-plan-revision plot modes.
- Stable `navigationTest.*` accessibility identifiers while preserving localized VoiceOver names.

No permission auto-grant, camera restart, background recording, sharing or export was added. Leaving the screen/backgrounding stops capture for this diagnostic; pending disk work may be interrupted by process termination. Reopening never starts capture. Full private spatial-history deletion also deletes diagnostic tables through the existing repository cascade.

## Important limitations preserved

- Phone trajectory is a camera-pose estimate, not body/feet ground truth or evidence of avoiding furniture.
- Current production plan feed supplies no source-to-map registration; alignment remains nil. Raw camera and map plots stay separate. A separately reviewed known-SavedWorldFrame association is distinct future work and is not physical guidance approval.
- Plot has no wall/furniture mesh. A successful save or displayed path is not a collision test or navigation-arrival proof.
- Historical archive version 1 does not retain the live rejected-sample/rejected-plan counters. UI explicitly reports that omission rather than displaying zero as a measured count. Admitted samples/events are preserved exactly.
- Saved-room/camera data remains private on the phone and excluded from backup using the existing directory policy. There is no export API or automatic GitHub upload.
- No physical user trial is requested by this checkpoint.

## Evidence and reproducibility

Independent source reviews inspected repository transactions/quotas, erase races, admitted-event ordering, stopped replay, failure-tail handling and actual controls. Review fixes include: refusing reopen during pending private erase; definite in-flight create/delete fixture; and a multi-transaction test rather than only short archives.

Authored tests, **not run here**:

- `NavigationTestRecordingTests`: 12 methods total, including three new archive/restore/corruption methods.
- `RecordedRouteStoreTests`: ten diagnostic methods (six new durability methods), within 21 total methods in the file. They cover exact reopen, interrupted prefix, quota failure with retained tail and explicit retry, queued/in-flight erase fencing, corrupt typed archive refusal, and 101 ordered events across multiple transactions. A DEBUG-only functional save fence awaits successor batches; it makes no latency claim.
- `RecordedRouteRepositoryTests`: seven new diagnostic methods, within 17 total methods. These cover session/erase identity, exact/idempotent rows, transactional bounds, pagination, terminal handling, corruption and cross-session payload quota.

Actually executed locally:

```sh
python3 research/navigation-test-recording-20261028/check_durable_schema.py
```

Nine SQLite schema/constraint/cascade checks passed, recorded in `DURABLE_SCHEMA_CHECK.json`. This exercises Python SQLite against the actual SQL files, **not the Swift repository methods**. Targeted whitespace checks also passed. No dependencies installed; no native compiler was available.

Next acceptance: existing Apple CI compilation and Core/Memory/hosted tests, then built-app local save/close/reopen/delete and VoiceOver/lifecycle checks. Only those results can establish actual native persistence behavior.
