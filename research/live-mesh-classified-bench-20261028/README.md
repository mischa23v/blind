# Classified live-mesh bench integration candidate

2026-10-28. **Implemented as a standalone source target, not linked or activated in the app.** This is a deliberately nonwalking derivative of the frozen [earlier bench proposal](../live-mesh-bench-proposal-20261028/README.md). The earlier proposal, app, dependency source, project generator, workflows and physical-output gates are unchanged. Source inspected against `a7143d4bb5bdf861105dbec1fd8b787b3ad4aa75`; the exact GitHub blob receipts and local hashes are retained here. Publication is owned by the root task.

## What this increment changes

- `LiveMeshBenchIngress` explicitly constructs the **existing** `MeshCandidateIngress83(supportPolicy: .classifiedFloorOnly)`. The already adopted83→75 role plumbing is used unchanged. Only ARKit label2 is candidate floor; other/missing labels retain their geometry as obstacles, and unknown classes retain the existing sticky delivery gap. Source classification is not measured supporting-floor or current-clearance evidence.
- `LiveMeshBenchSession` requires Apple's existing `.meshWithClassification` capability and configures that mode directly. A device that supports only unclassified mesh is refused instead of silently falling back to slope-based candidate support.
- `Package.swift` exposes `LiveMeshClassifiedBench` using the existing four local packages. The actual synchronous `ARKitMeshAdapter82.capture` call, owned-value decode, anchor updates/removals and existing75 geometry/native store are retained. No new mapper, SLAM, planner, collider, app hook or public forged-snapshot initializer is added.
- Fifteen authored dependency fixtures cover the previous eight lifecycle/copy cases plus nonfloor/missing labels, obstacle retention/removal, unknown replacement/recovery, a new terminal owner with the same anchor UUID, refused removal, rotated/translated metric geometry and scale/reflection rejection. Five copied iOS-only ownership fixtures use an actual **never-run** ARSession. All20 Swift fixtures are **unexecuted** on this candidate.

`classified-consumer.patch` shows the exact five-file change relative to the frozen proposal. Native session lifecycle behavior is deliberately unchanged. The new consumer additionally refuses all incomplete-source candidate results at callback and display checks.

## Geometry and lifecycle contract

The producer uses one existing, explicitly handed-off ARSession and a dedicated serial callback queue. It copies at most one mesh revision per callback, rotates selection, admits at most128 callback anchors/identities and one outstanding copy/decode slot, and sends every omission as unknown. A copy is complete-or-rejected, bounded at32,000 vertices,32,000 faces and1.5MB input/1.5MB logical decoded size;75 imposes its independent mailbox/map bounds. These are admission bounds, not measured whole-process memory or latency guarantees.

82 retains ARKit-local vertices and the column-major anchor transform;83 carries them unchanged;75 transposes representation then applies the transform exactly once into **metres, +Y-up session world**. The anchor UUID, wrapper epoch, monotonically increasing local revision and receipt uptime fence results. Receipt uptime is **not mesh capture time** (`captureUptime` remains nil). Session coordinates are not saved-room/building coordinates or measured body position.

Updates retire candidate tokens before copy. Exact removal carries the anchor UUID/tombstone and removes that tile; it does not declare free space. Decode failure or omitted updates can leave old geometry only as an explicitly incomplete nonphysical candidate. This consumer refuses every result with `sourceDeliveryComplete == false` or any `unknownCoverage`, including a route that75 can still build from retained old tiles. It cannot expose that retained geometry as a current preview. Unknown delivery is sticky until a distinct fresh owner/session; valid classifications can replace a previous unknown/obstacle revision but cannot erase historical delivery gaps. Stop/background/interruption/tracking loss, owner replacement and deinit retire outputs; draining retains the stopped producer until owned/native work has returned. Delegate restoration is exact-owner-only and never restarts the camera.

**Physical authority remains false; phone monitoring is explicitly unavailable in this exclusive mode.** No speech, beacon, route ticket, clearance output, persistence or network path is supplied. This is not simultaneous live navigation, and the presence of a warning constant is not evidence that a warning was delivered.

**Important usability limit:** a callback with multiple mesh anchors necessarily omits all but one revision under the frozen budget. Those explicit gaps make this consumer refuse previews for the remainder of that owner. It does not silently recover complete room coverage merely because later updates arrive. A reviewed loss/accounting/recovery or geometry/status presentation contract is still needed; this stage is not a usable complete-room live preview. The concrete [next bounded recovery design](BOUNDED_RECOVERY_DESIGN.md) identifies the existing83/75 APIs, smallest shared-file patch, real reacquisition requirement and acceptance cases. Permanent refusal due only to our budget is an unresolved defect, not the final solution.

## Bounded checks and next authorized execution

Run the source-only checks here:

```sh
python3 research/live-mesh-classified-bench-20261028/check_source.py
python3 -m unittest discover -s research/live-mesh-classified-bench-20261028 -p 'test_*.py' -v
```

`SOURCE_RESULT.json` records their final counts and limitations. They do not parse/typecheck Swift, execute Recast, or run Apple APIs. No Swift/Xcode exists in this workspace, and the existing private-repository CI guard must not be changed merely to run this stage.

On an already authorized Apple host with this complete checkout and its installed toolchain, the dependency fixtures are prepared for:

```sh
swift test --package-path research/live-mesh-classified-bench-20261028 --jobs 1
```

This command has **not** run. The five conditional native ownership fixtures additionally need a reviewed iOS-hosted XCTest target importing this package; macOS tests omit them. No hosted target membership or new workflow was added. Retain original timeouts/failures; do not replace actual native refusal with a stale/admission failure or call source checks a native pass.

## What still prevents a usable app feature

See [the current source-backed gap audit](GAP_AUDIT.md) and [the exact activation handoff](ACTIVATION_HANDOFF.md). Critical remaining work:

1. An app-owned exclusive mode must synchronously retire normal camera/recovery/watchdog/RoomPlan restart sources, deliver and confirm the monitoring-unavailable warning, and own stop/cancel/background/restore without silent restart. The staged initializer cannot prove those app preconditions.
2. A bounded immutable geometry snapshot/display seam is absent; this package currently returns only candidate routes. The private75 geometry store is not connected to either the independent saved-room collision oracle or fresh whole-body/ground support sensing.
3. The inherited producer-queue watchdog cannot expire a blocked producer independently. `isCurrent` checks ownership/revision, not a wall-clock display lease. No hard0.5-second display or hazard-delay bound is promised.
4. Native callback generation after session reset, Metal buffer stability, original frame clock association, latency, thermal behavior and memory must be measured on the exact supported SDK/phone. New UUIDs or `.shared` memory do not prove those contracts.
5. Live body/map localization, camera-to-body calibration, target-specific swept-body/head/ground coverage and physical acceptance are still missing. LLMs remain outside all movement authority.

## Reused evidence and licenses

The four existing packages are pinned unchanged in `INPUT_PINS.json`, including the existing Recast/Detour source and `LICENSE-Recast.txt` (Zlib-style). No new library or redistributed research runtime is added. Existing75/83 test histories are separate from this candidate's unexecuted fixtures; upstream reputation does not certify the adapter.

Apple's documented [mesh-with-classification option](https://developer.apple.com/documentation/arkit/arconfiguration/scenereconstruction/meshwithclassification) provides an approximate scene representation, and its [mesh classifications](https://developer.apple.com/documentation/arkit/armeshclassification) identify source face categories. Neither API is a physical support certificate. The [earlier bench proposal](../live-mesh-bench-proposal-20261028/README.md#primary-api-evidence-inspected2026-10-28) retains the prior queue/buffer freshness investigation; this increment does not claim to resolve its native assumptions.
