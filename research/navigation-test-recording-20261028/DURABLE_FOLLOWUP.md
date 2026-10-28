# Durable private navigation diagnostics — proposed follow-on

2026-10-28. Design only: **not implemented, compiled, benchmarked or validated**. This file is deliberately outside the frozen reachable-recorder manifest. Do not describe current volatile recordings as surviving app termination.

## Existing owner and inspected evidence

- `BlindMemory/Sources/BlindMemory/RecordedRouteRepository.swift` owns a private GRDB `DatabaseQueue`, using pinned GRDB 7.11.1 from `BlindMemory/Package.swift`.
- Its existing `private-recorded-route-v1` migration loads `BlindMemory/Sources/BlindMemory/SQL/recorded_routes.sql` through `MemoryStore.sql`.
- Ordinary history uses 64-row append/page bounds, a 4,096-byte sample payload bound, a 256 MiB default payload quota and trip/erase epochs. Those are existing implementation constants, not measured device performance.
- `ios/BlindAssist/RecordedRouteStore.swift` owns the serial utility queue and opens `RecordedRoutes/routes.sqlite`. `openRepository()` excludes the directory from backup and applies the existing iOS `completeUntilFirstUserAuthentication` file-protection policy. Reuse these paths and policies; do not create a cloud backup or another persistence engine.
- Ordinary breadcrumb quota retirement can delete unpinned samples. Therefore saved diagnostic sessions must store their exact typed camera sample payloads, not merely references to rows that may disappear.
- Current diagnostic sidecar is deliberately volatile. It records full source transforms, source timestamps, map/plan association and typed problem markers, but currently has no durable recovery or export.

## Proposed schema: same repository and database

Register a new forward migration without changing the existing migration's contents:

1. `navigationTestState(profile, eraseEpoch)` fences old queued writes after private-history deletion.
2. `navigationTestSession(profile, id, eraseEpoch, schemaVersion, lifecycle, terminationReason, lastCommittedSequence, eventCount, chargedBytes, ...)` stores bounded archive metadata.
3. `navigationTestEvent(profile, sessionID, sequence, kind, encodedBytes, payload)` stores typed pose, plan, marker and lifecycle events with a unique session/sequence key and foreign-key cascade to its diagnostic session.

Do not attach diagnostic events to `recordedRouteSample` with a cascading dependency: normal breadcrumb eviction must not destroy a saved test. Explicit private spatial-history deletion must delete diagnostic sessions too, update their erase generation atomically, and fence queued appends before disk work. Session-list reads must not load all payloads.

Keep the storage layer generic and bounded; BlindMemory should not acquire a new dependency on BlindCore merely to decode app geometry. BlindCore/app validation remains responsible for typed sample and plan invariants, while repository validation enforces row types, lengths, sequence ownership and transactional accounting.

## Proposed quotas — product defaults to validate, not proven limits

- Preserve current per-session 3,000-sample, 128-plan, 128-marker and 2,048-point-per-plan bounds.
- Proposed additional disk bounds: **16 MiB per diagnostic session, 32 MiB total, at most three retained sessions**. These are conservative initial design choices, not measured requirements or guarantees. They apply in addition to, not instead of, event-count limits; a session can reach its byte cap first.
- Proposed bounded append and keyset read pages: at most 64 events. Bound payload bytes separately per event kind before fetching/decoding; pose rows need their wrapper allowance beyond the existing sample's 4,096-byte cap. Plan payloads need an independently validated bound for 2,048 finite points and metadata.
- **Do not automatically evict a user's older tests.** Require explicit deletion when capacity is full. Stop the active diagnostic at its cap with a visible reason, preserving its committed history.
- Reuse the existing bounded utility queue/write-budget pattern. Do not place SQLite writes or whole-archive encoding on the AR/hazard/main callback.

Every admitted raw sample must remain unchanged in the archive. A bounded pending queue must not overwrite old pending samples when full: stop admitting diagnostic recording, retain its unsaved tail in memory, and report storage/backpressure failure. Explicit retry may flush that tail; do not silently label it saved. The ordinary navigation/hazard system must remain independent of diagnostic disk failure.

## Lifecycle and recovery

Explicit Start is permission for this local diagnostic recording; camera startup alone never starts one. Incremental event commits make a recoverable prefix available during recording. Commit event rows and last-committed sequence/count/byte metadata in the same transaction.

On reopen:

- Read bounded metadata/pages and validate schema, IDs, indices, finite transforms/timestamps, byte counts and event ordering before exposing data.
- Return only the committed prefix as stopped historical evidence. A session persisted as recording becomes **interrupted**, never automatically active.
- Preserve original source transforms and capture times. Do not retimestamp old observations, apply a new map alignment, or fabricate a stop time, position or missing continuation.
- Distinguish the original archived data from the derived restored lifecycle state. A reboot's new uptime must not be compared as if it belonged to the original clock/session.
- No route ticket, current position, live clearance or physical-guidance authority survives restoration.
- Storage errors, failed flushes and unsaved-tail counts stay explicit. Uncommitted process-crash data is lost; do not claim otherwise.

Expose local saved-session listing, reopen and explicit deletion. No export/share/upload is included in this follow-on. If export is later requested, it needs a separate explicit user action and privacy review; public GitHub receives only synthetic fixtures/source, never user test captures.

## Exact first implementation/test slice

Start with **storage plus a validated stopped archive round-trip**, before background autosaving or UI changes:

1. Add diagnostic tables/migration and bounded create/append/finalize/list/page/delete APIs within `RecordedRouteRepository`.
2. Add a typed, size-bounded archive event codec and restored-stopped reader around the existing Core recorder types. Existing synthesized Codable nested values do not replace full archive validation.
3. Add repository tests for transactional append accounting, idempotent/conflicting append, quota rejection, bounded pagination, close/reopen and session deletion/erase fencing.
4. Add Core tests for exact raw sample/plan/marker round-trip; invalid schema, references, nonfinite values and oversized payloads; interrupted restore with no recording/guidance authority.
5. Only after that slice is built/tested in the existing Apple environment, connect incremental writes and flush receipts to the Store's already admitted-sample path; preserve recording-ID and camera-generation fences.
6. Then add hosted tests for delayed writes across Stop/Start/Delete, app interruption, save failure and pending-tail retry, plus local saved-session UI. No new capture session, model or workflow.

Minimum files for the first slice:

- `BlindMemory/Sources/BlindMemory/RecordedRouteRepository.swift`
- new `BlindMemory/Sources/BlindMemory/SQL/navigation_test_recordings.sql`
- `BlindMemory/Tests/BlindMemoryTests/RecordedRouteRepositoryTests.swift` (or a clearly named new repository test file)
- Core recorder archive codec and its Core tests

Subsequent app slice:

- `RecordedRouteStore.swift`, `NativeARObservationBridge.swift`, `NavigationTestRecordingView.swift`
- existing `RecordedRouteStoreTests.swift`
- canonical native target changes only if new app/test basenames are introduced, coordinated with its owner

## Required evidence before claiming usable persistence

- Native compilation and real GRDB repository tests, not source grep alone.
- Byte-identical raw sample recovery and preserved plan/goal/body/obstacle/digest provenance.
- Normal breadcrumb quota eviction leaves saved diagnostic samples intact.
- Interrupted transaction never exposes a partial event or inflated committed count.
- Old delayed writes cannot resurrect an explicitly deleted session.
- Capacity failure stops diagnostics without blocking hazard processing or silently erasing prior evidence.
- Reopen always stopped; neither app launch nor camera restart resumes recording.
- Local list/delete/reopen UI and VoiceOver checks on an actual build.

This proposal does not yet establish durable test capture, device cost, safe movement, collision accuracy or suitability for children.

## Separate registration backlog: coordinate association is not movement permission

Do not conflate a known camera coordinate frame with calibrated physical guidance:

- **Same captured/saved AR frame:** `SavedWorldFrame` can explicitly associate a RoomPlan capture using the shared AR session with ARWorldMap restoration. Once the existing exact-frame recovery gate passes, a future diagnostic adapter may be able to display registered *camera coordinates* in that known frame. That requires checking the real descriptor/session/frame ownership and recovery evidence; it is not a guessed identity transform from a room label. It does not establish body/feet position, observed floor support, obstacle completeness or physical guidance authorization.
- **Imported/other-frame map (including the Koivu research artifact):** no such same-frame relationship follows from opening the file. A separately evidenced source-frame-to-map registration is required; until supplied, keep raw camera and map plots separate with alignment nil.

This distinction is backlog/design only. The current frozen recorder still supplies nil alignment; no recovery gate, body/support validator or physical-release rule has been relaxed. A later coordinate-association implementation needs separate fixtures for valid same-frame recovery, wrong descriptor/session/revision, lost recovery and imported-map rejection, while guidance authority remains false in every diagnostic case.
